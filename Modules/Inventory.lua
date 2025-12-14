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
        return 0, 0
    end

    local totalSlots = 0
    local usedSlots = 0

    for bag = 0, NUM_BAG_SLOTS do
        local n = C_Container.GetContainerNumSlots(bag) or 0
        totalSlots = totalSlots + n

        for slot = 1, n do
            local itemID = C_Container.GetContainerItemID(bag, slot)
            if itemID then
                usedSlots = usedSlots + 1
            end
        end
    end

    -- Include reagent bag
    if Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag then
        local bag = Enum.BagIndex.ReagentBag
        local n = C_Container.GetContainerNumSlots(bag) or 0
        totalSlots = totalSlots + n

        for slot = 1, n do
            local itemID = C_Container.GetContainerItemID(bag, slot)
            if itemID then
                usedSlots = usedSlots + 1
            end
        end
    end

    local freeSlots = math.max(totalSlots - usedSlots, 0)
    return freeSlots, totalSlots
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
    if not addon.db.profile.modules.Inventory then
        return
    end

    local sec = addon.HUD and addon.HUD.sections and addon.HUD.sections.Inventory
    if not sec or not sec.lines then
        return
    end

    local free, total = self:GetBagSlots()
    if sec.lines[1] then
        sec.lines[1]:SetText(string.format("Free bag slots: %d / %d", free, total))
        sec.lines[1]:Show()
    end

    if sec.lines[2] then
        local label = "vendor"
        if TSM_API and TSM_API.GetCustomPriceValue then
            label = self:ResolveTSMLabel()
        end
        sec.lines[2]:SetText(string.format("Bag value (%s): %s", label, addon:FormatMoney(addon.state.bagValue or 0)))
        sec.lines[2]:Show()
    end

    if sec.lines[3] then
        local isEnabled, hasLock = self:GetWarbandAccessInfo()

        local text
        if hasLock == true then
            text = "Warbank: |cff44ff44●|r"
        elseif hasLock == false then
            text = "Warbank: |cffff4444●|r"
        elseif isEnabled == false then
            text = "Warbank: |cffff4444Needs Quest|r"
        else
            text = "Warbank:"
        end

        sec.lines[3]:SetText(text)
        sec.lines[3]:Show()
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
