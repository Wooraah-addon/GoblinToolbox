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
    local normalFree = 0

    -- Normal bags (0-4)
    for bag = 0, NUM_BAG_SLOTS do
        local n = C_Container.GetContainerNumSlots(bag) or 0
        normalTotal = normalTotal + n
        local free = C_Container.GetContainerNumFreeSlots(bag) or 0
        normalFree = normalFree + free
    end

    -- Reagent bag
    local reagentTotal = 0
    local reagentFree = 0
    if Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag then
        local bag = Enum.BagIndex.ReagentBag
        reagentTotal = C_Container.GetContainerNumSlots(bag) or 0
        reagentFree = C_Container.GetContainerNumFreeSlots(bag) or 0
    end

    return normalFree, normalTotal, reagentFree, reagentTotal
end

-----------------------------------------------------------------------
-- Reagent rank detection (Blizzard API only)
-----------------------------------------------------------------------

function Inventory:GetReagentRank(itemLink, itemID)
    -- Try to get rank from C_TradeSkillUI API (works for crafting reagents)
    if C_TradeSkillUI and C_TradeSkillUI.GetItemReagentQualityByItemInfo then
        local rank = nil
        if itemLink then
            rank = C_TradeSkillUI.GetItemReagentQualityByItemInfo(itemLink)
        end
        if not rank and itemID then
            rank = C_TradeSkillUI.GetItemReagentQualityByItemInfo(itemID)
        end
        return rank  -- Returns 1, 2, or 3 for quality tiers, or nil if not a reagent
    end
    return nil
end

-----------------------------------------------------------------------
-- Number formatting helper
-----------------------------------------------------------------------

function Inventory:FormatCount(count)
    if not count or count == 0 then
        return "0"
    end

    if count >= 1000000 then
        return string.format("%.2fm", count / 1000000)
    elseif count >= 1000 then
        return string.format("%.1fk", count / 1000)
    else
        return tostring(count)
    end
end

-----------------------------------------------------------------------
-- TSM price source handling
-----------------------------------------------------------------------

function Inventory:ResolveTSMLabel()
    if not addon.db or not addon.db.global then
        return "dbregionmarketavg"
    end

    local src = addon.db.global.tsmSource or "dbregionmarketavg"

    if src == "custom" then
        local custom = (addon.db.global.tsmCustomSource or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if custom ~= "" then
            return custom
        end
        return "dbregionmarketavg"
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
        local vendor = addon.API.GetVendorSellPrice(itemLink)
        price = vendor
    end

    return price
end

function Inventory:GetUnitPrice(itemLink, itemID)
    -- Get unit price from TSM (no vendor fallback)
    -- Returns nil if TSM not available or price is 0/unknown
    if not itemLink and not itemID then
        return nil
    end

    if TSM_API and TSM_API.GetCustomPriceValue then
        local sourceLabel = self:ResolveTSMLabel()
        local itemString = itemLink

        -- If we have an itemLink, convert it to TSM format
        if itemLink and TSM_API.ToItemString then
            local ok, s = pcall(TSM_API.ToItemString, itemLink)
            if ok and s then
                itemString = s
            end
        -- If no itemLink but we have itemID, try converting itemID to itemString
        elseif not itemLink and itemID then
            -- Try to get itemLink from itemID, then convert
            local name, link = addon.API.GetItemInfo(itemID)
            if link then
                if TSM_API.ToItemString then
                    local ok, s = pcall(TSM_API.ToItemString, link)
                    if ok and s then
                        itemString = s
                    else
                        itemString = link
                    end
                else
                    itemString = link
                end
            else
                -- Fallback: try using "i:" prefix format that TSM understands
                itemString = "i:" .. tostring(itemID)
            end
        end

        local ok, value = pcall(TSM_API.GetCustomPriceValue, sourceLabel, itemString)
        if ok and value and value > 0 then
            return value
        end
    end

    return nil
end

-----------------------------------------------------------------------
-- Bag scanning and value calculation
-----------------------------------------------------------------------

local bagValuePending = false

local function ScanBag(bag, countByID, countByKey, totalValue)
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

            -- Track by base itemID (for rank 0 / unranked items)
            countByID[itemID] = (countByID[itemID] or 0) + count

            -- Track by itemID:rank key (for rank-aware tracking)
            local rank = Inventory:GetReagentRank(itemLink, itemID)
            if rank and rank > 0 then
                -- Ranked item: track by itemID:rank
                local key = tostring(itemID) .. ":" .. tostring(rank)
                countByKey[key] = (countByKey[key] or 0) + count
            else
                -- Unranked item: track by itemID:0
                local key = tostring(itemID) .. ":0"
                countByKey[key] = (countByKey[key] or 0) + count
            end

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
        addon.trackedCountsByKey = {}
        self:Update()
        addon:UpdateTrackedBar()
        return
    end

    local total = 0
    local countByID = {}
    local countByKey = {}

    for bag = 0, NUM_BAG_SLOTS do
        total = ScanBag(bag, countByID, countByKey, total)
    end

    if Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag then
        total = ScanBag(Enum.BagIndex.ReagentBag, countByID, countByKey, total)
    end

    addon.state.bagValue = total
    addon.trackedCounts = countByID
    addon.trackedCountsByKey = countByKey

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
-- Player bank scanning and cache management
-----------------------------------------------------------------------

local playerBankScanPending = false

local function ScanPlayerBank()
    -- Only scan if we have access to bank containers
    if not C_Container then
        return
    end

    local countByKey = {}
    local totalItems = 0

    -- Use fallback bag IDs (Enum values may be nil in some WoW versions)
    local bankBagID = (Enum and Enum.BagIndex and Enum.BagIndex.Bank) or -1
    local firstBankBag = (Enum and Enum.BagIndex and Enum.BagIndex.BankBag_1) or 5

    -- Scan main bank container (bag -1)
    local bag = bankBagID
    local numSlots = C_Container.GetContainerNumSlots(bag)

    if numSlots and numSlots > 0 then
        for slot = 1, numSlots do
            local itemID = C_Container.GetContainerItemID(bag, slot)
            if itemID then
                local itemLink = C_Container.GetContainerItemLink(bag, slot)
                local info = C_Container.GetContainerItemInfo(bag, slot)
                local count = (info and info.stackCount) or 1

                -- Track by itemID:rank key (same as bag scan)
                local rank = Inventory:GetReagentRank(itemLink, itemID)
                local key
                if rank and rank > 0 then
                    key = tostring(itemID) .. ":" .. tostring(rank)
                else
                    key = tostring(itemID) .. ":0"
                end

                countByKey[key] = (countByKey[key] or 0) + count
                totalItems = totalItems + 1
            end
        end
    end

    -- Scan bank bags (BankBag_1 through BankBag_7, typically bags 5-11)
    for i = 0, 6 do  -- 7 bank bags
        local bag = firstBankBag + i
        local numSlots = C_Container.GetContainerNumSlots(bag)

        if numSlots and numSlots > 0 then
            for slot = 1, numSlots do
                local itemID = C_Container.GetContainerItemID(bag, slot)
                if itemID then
                    local itemLink = C_Container.GetContainerItemLink(bag, slot)
                    local info = C_Container.GetContainerItemInfo(bag, slot)
                    local count = (info and info.stackCount) or 1

                    -- Track by itemID:rank key (same as bag scan)
                    local rank = Inventory:GetReagentRank(itemLink, itemID)
                    local key
                    if rank and rank > 0 then
                        key = tostring(itemID) .. ":" .. tostring(rank)
                    else
                        key = tostring(itemID) .. ":0"
                    end

                    countByKey[key] = (countByKey[key] or 0) + count
                    totalItems = totalItems + 1
                end
            end
        end
    end

    -- Persist to cache (character-specific saved variable)
    local charCache = addon:GetCharacterCache()
    if charCache then
        charCache.playerBankItemCounts = countByKey
        charCache.playerBankLastUpdate = time()
    end

    playerBankScanPending = false
end

function Inventory:QueuePlayerBankScan()
    if playerBankScanPending then
        return
    end
    playerBankScanPending = true
    -- Small delay to ensure container data is loaded
    C_Timer.After(0.5, function()
        ScanPlayerBank()
        -- Update tracker bar after scan completes
        if addon.UpdateTrackedBar then
            addon:UpdateTrackedBar()
        end
    end)
end

function Inventory:GetPlayerBankCountForKey(key)
    -- Returns cached player bank count for a given itemID:rank key
    local charCache = addon:GetCharacterCache()
    if not charCache or not charCache.playerBankItemCounts then
        return 0
    end
    return charCache.playerBankItemCounts[key] or 0
end

-----------------------------------------------------------------------
-- Warband bank scanning and cache management
-----------------------------------------------------------------------

local warbandScanPending = false

local function ScanWarbandBank()
    -- Only scan if warband bank is accessible
    if not C_Bank or not C_Bank.CanUseBank or not Enum.BankType then
        return
    end

    if not C_Bank.CanUseBank(Enum.BankType.Account) then
        -- Bank not accessible, use cached counts
        return
    end

    local countByKey = {}

    -- Scan all purchased warband bank tabs
    -- Account bank uses bag IDs starting from Enum.BagIndex.AccountBankTab_1
    if Enum.BagIndex and Enum.BagIndex.AccountBankTab_1 then
        for i = 0, 4 do  -- 5 tabs (0-4)
            local bag = Enum.BagIndex.AccountBankTab_1 + i
            local numSlots = C_Container.GetContainerNumSlots(bag)

            if numSlots and numSlots > 0 then
                for slot = 1, numSlots do
                    local itemID = C_Container.GetContainerItemID(bag, slot)
                    if itemID then
                        local itemLink = C_Container.GetContainerItemLink(bag, slot)
                        local info = C_Container.GetContainerItemInfo(bag, slot)
                        local count = (info and info.stackCount) or 1

                        -- Track by itemID:rank key (same as bag scan)
                        local rank = Inventory:GetReagentRank(itemLink, itemID)
                        local key
                        if rank and rank > 0 then
                            key = tostring(itemID) .. ":" .. tostring(rank)
                        else
                            key = tostring(itemID) .. ":0"
                        end

                        countByKey[key] = (countByKey[key] or 0) + count
                    end
                end
            end
        end
    end

    -- Persist to cache (account-wide saved variable)
    local db = addon.db
    if db and db.warband then
        db.warband.itemCountsByKey = countByKey
        db.warband.itemsLastUpdate = time()
    end

    warbandScanPending = false
end

function Inventory:QueueWarbandScan()
    if warbandScanPending then
        return
    end
    warbandScanPending = true
    -- Small delay to ensure container data is loaded
    C_Timer.After(0.5, function()
        ScanWarbandBank()
        -- Update tracker bar after scan completes
        if addon.UpdateTrackedBar then
            addon:UpdateTrackedBar()
        end
    end)
end

function Inventory:GetWarbandCountForKey(key)
    -- Returns cached warband count for a given itemID:rank key
    local db = addon.db
    if not db or not db.warband or not db.warband.itemCountsByKey then
        return 0
    end
    return db.warband.itemCountsByKey[key] or 0
end

-----------------------------------------------------------------------
-- Total count accessor (bags + player bank + warband)
-----------------------------------------------------------------------

function Inventory:GetTotalCountForKey(key)
    -- Get settings from profile
    local db = addon.db and addon.db.profile
    if not db then
        return 0
    end

    local totalCount = 0

    -- Add inventory (bags) count if enabled (default on)
    if db.trackerIncludeInventory ~= false then
        local bagCount = addon.trackedCountsByKey and addon.trackedCountsByKey[key] or 0
        totalCount = totalCount + bagCount
    end

    -- Add player bank count if enabled
    if db.trackerIncludePlayerBank == true then
        local playerBankCount = self:GetPlayerBankCountForKey(key)
        totalCount = totalCount + playerBankCount
    end

    -- Add warband bank count if enabled
    if db.trackerIncludeWarbandBank == true then
        local warbandCount = self:GetWarbandCountForKey(key)
        totalCount = totalCount + warbandCount
    end

    return totalCount
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
-- Helper to get count for a tracked entry
-----------------------------------------------------------------------

function Inventory:GetCountForTrackedEntry(entry)
    -- entry can be a simple itemID (number) or a structured {itemID, rank} table
    local itemID, rank

    if type(entry) == "table" then
        itemID = entry.itemID
        rank = entry.rank or 0
    else
        itemID = entry
        rank = 0
    end

    if not itemID then
        return 0
    end

    -- Ensure tables exist
    addon.trackedCounts = addon.trackedCounts or {}
    addon.trackedCountsByKey = addon.trackedCountsByKey or {}

    -- If rank > 0, use rank-specific count
    if rank > 0 then
        local key = tostring(itemID) .. ":" .. tostring(rank)
        return addon.trackedCountsByKey[key] or 0
    end

    -- Otherwise use base itemID count (aggregates all ranks)
    return addon.trackedCounts[itemID] or 0
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
