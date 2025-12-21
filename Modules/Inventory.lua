-- Modules/Inventory.lua
-- Inventory & Currency module: bag slots, bag value, warband access indicator

local addonName, addon = ...

local Inventory = {}
addon:RegisterModule("Inventory", Inventory)

-----------------------------------------------------------------------
-- Bag slot calculation
-----------------------------------------------------------------------

function Inventory:GetBagSlots()
    if not C_Container then
        return 0, 0, 0, 0
    end

    local normalTotal = 0
    local normalUsed = 0
    local reagentTotal = 0
    local reagentUsed = 0

    -- Normal bags (0-4)
    for bag = 0, NUM_BAG_SLOTS do
        local n = C_Container.GetContainerNumSlots(bag) or 0
        normalTotal = normalTotal + n

        for slot = 1, n do
            local itemID = C_Container.GetContainerItemID(bag, slot)
            if itemID then
                normalUsed = normalUsed + 1
            end
        end
    end

    -- Reagent bag
    if Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag then
        local bag = Enum.BagIndex.ReagentBag
        local n = C_Container.GetContainerNumSlots(bag) or 0
        reagentTotal = reagentTotal + n

        for slot = 1, n do
            local itemID = C_Container.GetContainerItemID(bag, slot)
            if itemID then
                reagentUsed = reagentUsed + 1
            end
        end
    end

    local normalFree = math.max(normalTotal - normalUsed, 0)
    local reagentFree = math.max(reagentTotal - reagentUsed, 0)
    
    return normalFree, normalTotal, reagentFree, reagentTotal
end

-----------------------------------------------------------------------
-- TSM price source handling
-----------------------------------------------------------------------

function Inventory:ResolveTSMLabel()
    local db = addon.db and addon.db.profile
    if not db then
        return "dbmarket"
    end

    local src = db.tsmSource or "dbmarket"

    if src == "custom" then
        local custom = (db.tsmCustomSource or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if custom ~= "" then
            return custom
        end
        return "dbmarket"
    end

    return src
end

function Inventory:GetItemPrice(itemLink)
    if not itemLink then
        return 0
    end

    local price = 0

    if TSM_API and TSM_API.GetCustomPriceValue then
        local sourceLabel = self:ResolveTSMLabel()
        local itemString = itemLink

        if TSM_API.ToItemString then
            local ok, s = pcall(TSM_API.ToItemString, itemLink)
            if ok and s then
                itemString = s
            end
        end

        local ok, value = pcall(TSM_API.GetCustomPriceValue, sourceLabel, itemString)
        if ok and value and value > 0 then
            price = value
        end
    end

    -- Fallback to vendor price
    if price <= 0 then
        local vendor = select(11, GetItemInfo(itemLink)) or 0
        price = vendor
    end

    return price
end

-----------------------------------------------------------------------
-- Bag scanning and value calculation
-----------------------------------------------------------------------

local bagValuePending = false

local function ScanBag(bag, countByID, totalValue)
    local numSlots = C_Container.GetContainerNumSlots(bag)
    if not numSlots or numSlots <= 0 then
        return totalValue
    end

    for slot = 1, numSlots do
        local itemID = C_Container.GetContainerItemID(bag, slot)
        if itemID then
            local itemLink = C_Container.GetContainerItemLink(bag, slot)
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local count = (info and info.stackCount) or 1

            countByID[itemID] = (countByID[itemID] or 0) + count

            if itemLink then
                local price = Inventory:GetItemPrice(itemLink)
                totalValue = totalValue + price * count
            end
        end
    end

    return totalValue
end

function Inventory:RecalculateBagValue()
    bagValuePending = false

    if not C_Container then
        addon.state.bagValue = 0
        addon.trackedCounts = {}
        self:Update()
        addon:UpdateTrackedBar()
        return
    end

    local total = 0
    local countByID = {}

    for bag = 0, NUM_BAG_SLOTS do
        total = ScanBag(bag, countByID, total)
    end

    if Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag then
        total = ScanBag(Enum.BagIndex.ReagentBag, countByID, total)
    end

    addon.state.bagValue = total
    addon.trackedCounts = countByID

    self:Update()
    addon:UpdateTrackedBar()
end

function Inventory:QueueRecalc()
    if bagValuePending then
        return
    end
    bagValuePending = true
    C_Timer.After(addon.CONST.BAG_SCAN_DELAY, function()
        Inventory:RecalculateBagValue()
    end)
end

-----------------------------------------------------------------------
-- Warband access indicator
-----------------------------------------------------------------------

function Inventory:GetWarbandAccessInfo()
    local isEnabled = nil
    if C_PlayerInfo and C_PlayerInfo.IsAccountBankEnabled then
        isEnabled = C_PlayerInfo.IsAccountBankEnabled()
    end

    local hasLock = nil
    if C_PlayerInfo and C_PlayerInfo.HasAccountInventoryLock then
        hasLock = C_PlayerInfo.HasAccountInventoryLock()
    end

    return isEnabled, hasLock
end


-----------------------------------------------------------------------
-- Section update (called by HUD)
-----------------------------------------------------------------------

function Inventory:Update()
    if not addon.db or not addon.db.profile or not addon.db.profile.modules then
        return
    end
    -- Treat nil as enabled, older saved variables may not have the key.
    if addon.db.profile.modules.Inventory == false then
        return
    end

    local sec = addon.HUD and addon.HUD.sections and addon.HUD.sections.Inventory
    if not sec or not sec.lines then
        return
    end

    local db = addon.db.profile
    local elem = db.elements or {}

    -- Line 1: Bag value
    if sec.lines[1] then
        if elem.invBagValue ~= false then
            local label = "vendor"
            if TSM_API and TSM_API.GetCustomPriceValue then
                label = self:ResolveTSMLabel()
            end
            sec.lines[1]:SetText(string.format("Bag value (%s): %s", label, addon:FormatMoney(addon.state.bagValue or 0)))
        else
            sec.lines[1]:SetText("")
        end
    end

    -- Line 2: Normal and Reagent bag slots (both on one line)
    if sec.lines[2] then
        if elem.invBagSlots ~= false then
            local normalFree, normalTotal, reagentFree, reagentTotal = self:GetBagSlots()
            
            local iconSize = 16
            local normalIcon = "Interface\\Icons\\INV_Misc_Bag_08"
            local reagentIcon = "Interface\\Icons\\INV_Misc_Bag_BigBagOfEnchantments"
            
            -- Normal bags
            local normalIconMarkup = string.format("|T%s:%d:%d:0:0|t", normalIcon, iconSize, iconSize)
            local normalIsFull = (normalFree == 0 and normalTotal > 0)
            local normalColor = normalIsFull and "|cffff4444" or ""
            local normalColorEnd = normalIsFull and "|r" or ""
            local normalText = string.format("%s %s%3d / %3d%s", normalIconMarkup, normalColor, normalFree, normalTotal, normalColorEnd)
            
            -- Reagent bags
            local reagentIconMarkup = string.format("|T%s:%d:%d:0:0|t", reagentIcon, iconSize, iconSize)
            local reagentIsFull = (reagentFree == 0 and reagentTotal > 0)
            local reagentColor = reagentIsFull and "|cffff4444" or ""
            local reagentColorEnd = reagentIsFull and "|r" or ""
            local reagentText = string.format("%s %s%3d / %3d%s", reagentIconMarkup, reagentColor, reagentFree, reagentTotal, reagentColorEnd)
            
            sec.lines[2]:SetText(normalText .. "   " .. reagentText)
            
            -- Show tooltip button if it exists
            if sec.bagSlotsTooltipBtn then
                sec.bagSlotsTooltipBtn:Show()
            end
        else
            sec.lines[2]:SetText("")
            -- Hide tooltip button
            if sec.bagSlotsTooltipBtn then
                sec.bagSlotsTooltipBtn:Hide()
            end
        end
    end

    -- Line 3: Warband bank access indicator
    if sec.lines[3] then
        if elem.invWarbank ~= false then
            local isEnabled, hasLock = self:GetWarbandAccessInfo()

            local text
            local iconSize = 13
            local iconTexture = "Interface\\Icons\\INV_Misc_FlawlessPearl"

            if hasLock == true then
                -- Green tinted icon + "Warbank Available" in green
                local icon = string.format("|T%s:%d:%d:0:0:64:64:4:60:4:60:100:255:100|t", 
                    iconTexture, iconSize, iconSize)
                text = icon .. " |cff44ff44Warbank Available|r"
            elseif hasLock == false then
                -- Red tinted icon + "Warbank Locked" in red
                local icon = string.format("|T%s:%d:%d:0:0:64:64:4:60:4:60:255:100:100|t", 
                    iconTexture, iconSize, iconSize)
                text = icon .. " |cffff4444Warbank Locked|r"
            else
                -- Fallback if state is unknown
                text = "Warbank: Unknown"
            end

            sec.lines[3]:SetText(text)
        else
            sec.lines[3]:SetText("")
        end
    end
end

-----------------------------------------------------------------------
-- Expose module to addon for backward compatibility
-----------------------------------------------------------------------

function addon:UpdateInventorySection()
    Inventory:Update()
end

function addon:QueueBagValueRecalc()
    Inventory:QueueRecalc()
end

-- Expose for direct access if needed
addon.Inventory = Inventory
