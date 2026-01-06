-- UtilityBar.lua
-- Utility bar: secure action buttons for Mobile Banking, Mailbox, Hearthstones, etc.

local addonName, addon = ...

-----------------------------------------------------------------------
-- Drag handle indicator (Hardware LED design)
-----------------------------------------------------------------------

local function CreateDragHandle(parent)
    -- Create button with larger invisible hitbox
    local handle = CreateFrame("Button", nil, parent)
    handle:SetSize(10, 10)  -- Visual size
    handle:SetPoint("TOPLEFT", parent, "TOPLEFT", 2, -2)
    handle:SetFrameLevel(parent:GetFrameLevel() + 5)

    -- Expand hitbox slightly beyond visual (easier to grab, but not obtrusive)
    handle:SetHitRectInsets(-2, -2, -2, -2)

    -- Ring layer (dark background circle)
    local ring = handle:CreateTexture(nil, "BACKGROUND")
    ring:SetSize(10, 10)
    ring:SetPoint("CENTER")
    ring:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")  -- Has circular masks
    ring:SetTexCoord(0.25, 0.5, 0, 0.25)  -- Yellow circle (we'll color it dark)
    ring:SetVertexColor(0.15, 0.15, 0.15, 0.6)  -- Dark gray ring
    handle.ring = ring

    -- Fill layer (colored indicator)
    local fill = handle:CreateTexture(nil, "ARTWORK")
    fill:SetSize(8, 8)  -- Slightly smaller than ring for inset effect
    fill:SetPoint("CENTER")
    fill:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    fill:SetTexCoord(0.25, 0.5, 0, 0.25)  -- Same circular mask
    handle.fill = fill

    -- Initially hide (will show on hover or when unlocked)
    handle:SetAlpha(0)

    -- Enable dragging from the handle
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")

    handle:SetScript("OnDragStart", function(self)
        if addon.db and addon.db.profile and addon.db.profile.lockFrame then
            return
        end
        parent:StartMoving()
    end)

    handle:SetScript("OnDragStop", function(self)
        parent:StopMovingOrSizing()
        addon._utilityMovedThisSession = true

        -- Persist position using the same schema as the rest of UtilityBar.lua
        local db = addon.db and addon.db.profile
        if not db then
            return
        end

        local point, _, relPoint, xOfs, yOfs = parent:GetPoint(1)
        if not point then
            return
        end

        db.utilityBarPos = db.utilityBarPos or {}
        db.utilityBarPos.point = point
        db.utilityBarPos.relPoint = relPoint
        db.utilityBarPos.x = xOfs
        db.utilityBarPos.y = yOfs
    end)

    -- Hover behavior
    handle:SetScript("OnEnter", function(self)
        -- Always show on hover
        self:SetAlpha(1)

        -- Tooltip
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if addon.db and addon.db.profile and addon.db.profile.lockFrame then
            GameTooltip:SetText("Frame Locked", 1, 0.2, 0.2)
            GameTooltip:AddLine("Click the lock icon to unlock", 0.8, 0.8, 0.8, true)
        else
            GameTooltip:SetText("Drag to Move", 0.2, 1, 0.2)
        end
        GameTooltip:Show()
    end)

    handle:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        -- Return to default visibility state
        self:UpdateVisibility()
    end)

    -- Update color based on lock state
    handle.UpdateColor = function(self)
        if addon.db and addon.db.profile and addon.db.profile.lockFrame then
            -- Red when locked
            self.fill:SetVertexColor(0.9, 0.2, 0.2, 0.75)
        else
            -- Green when unlocked
            self.fill:SetVertexColor(0.2, 0.9, 0.2, 0.85)
        end
    end

    -- Update visibility based on lock state
    handle.UpdateVisibility = function(self)
        if addon.db and addon.db.profile and addon.db.profile.lockFrame then
            -- Locked: visible but subdued (you can see it's there)
            self:SetAlpha(0.5)
        else
            -- Unlocked: clearly visible (frames are moveable)
            self:SetAlpha(0.95)
        end
    end

    handle:UpdateColor()
    handle:UpdateVisibility()

    return handle
end

-----------------------------------------------------------------------
-- Utility action definitions
-----------------------------------------------------------------------

local UTILITY_ACTIONS = {
    mobileBank = {
        key         = "mobileBank",
        label       = "Mobile Banking",
        kind        = "spell",
        spellID     = addon.CONST.SPELLS.MOBILE_BANKING,
        iconTexture = "Interface\\Icons\\achievement_guildperk_mobilebanking",
    },

    mailbox = {
        key      = "mailbox",
        label    = "Portable Mailbox",
        kind     = "item",
        mailboxCandidates = {
            addon.CONST.ITEMS.KATY_STAMPWHISTLE,
            addon.CONST.ITEMS.OHUNA_PERCH,
            239693, -- Radiant Lynx Whistle (shared CD with Katy/Ohuna)
            addon.CONST.ITEMS.MOLL_E,
        },
    },

    tradersBrutosaur = {
        key     = "tradersBrutosaur",
        label   = "Auction House",
        kind    = "spell",
        spellID = 465235, -- Trader's Gilded Brutosaur
    },

    vendorMount = {
        key   = "vendorMount",
        label = "Vendor Mount",
        kind  = "spell",
        -- spellID is resolved dynamically based on collected mounts
    },

    warbandBank = {
        key         = "warbandBank",
        label       = "Warband Bank",
        kind        = "spell",
        spellID     = addon.CONST.SPELLS.WARBAND_BANK_INHIBITOR,
        iconTexture = "Interface\\Icons\\inv_cosmicvoid_orb",
    },

    hearthstone = {
        key         = "hearthstone",
        label       = "Hearthstone",
        kind        = "item",
        itemID      = 6948,  -- Standard Hearthstone item
        iconTexture = "Interface\\Icons\\inv_misc_rune_01",
        allowToyFallback = true,
        hearthSpellID = 8690, -- Used as *fallback* heuristic only
    },

    dalaranHS = {
        key      = "dalaranHS",
        label    = "Dalaran Hearthstone",
        kind     = "item",
        itemID   = addon.CONST.ITEMS.DALARAN_HS,
    },

    garrisonHS = {
        key      = "garrisonHS",
        label    = "Garrison Hearthstone",
        kind     = "item",
        itemID   = addon.CONST.ITEMS.GARRISON_HS,
    },
}

local UTILITY_ORDER = {
    "mobileBank",
    "mailbox",
    "tradersBrutosaur",
    "vendorMount",
    "warbandBank",
    "hearthstone",
    "dalaranHS",
    "garrisonHS",
}

-----------------------------------------------------------------------
-- Helper functions
-----------------------------------------------------------------------

local function NormalizeEnabled(v)
    if v == true then return 1 end
    if v == false then return 0 end
    if type(v) == "number" then return v end
    return 1
end

-- TWW/11.x compatibility: GetSpellCooldown removed; use C_Spell.GetSpellCooldown (returns table)
local function GetSpellCooldownCompat(spellID)
    if C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(spellID)
        if not info then
            return 0, 0, 0
        end
        local start = info.startTime or 0
        local duration = info.duration or 0
        local enabled = info.isEnabled and 1 or 0
        return start, duration, enabled
    end

    -- Legacy fallback (pre-11.0)
    if _G.GetSpellCooldown then
        local start, duration, enabled = _G.GetSpellCooldown(spellID)
        return start or 0, duration or 0, NormalizeEnabled(enabled)
    end

    return 0, 0, 0
end

local function IsToyOwnedAndUsable(itemID)
    if not itemID then
        return false
    end

    local owned = false

    if PlayerHasToy and PlayerHasToy(itemID) then
        owned = true
    elseif GetItemCount and GetItemCount(itemID, true) > 0 then
        owned = true
    end

    if not owned then
        return false
    end

    if C_ToyBox and C_ToyBox.IsToyUsable then
        return C_ToyBox.IsToyUsable(itemID)
    end

    return true
end

local function IsToyOwned(itemID)
    if not itemID then
        return false
    end
    if PlayerHasToy and PlayerHasToy(itemID) then
        return true
    end
    return false
end

local function HasItemAnywhere(itemID)
    if not itemID or not GetItemCount then
        return false
    end
    return (GetItemCount(itemID, true) or 0) > 0
end

local function IsToyUsableNow(itemID)
    if not itemID then
        return false
    end
    if C_ToyBox and C_ToyBox.IsToyUsable then
        return C_ToyBox.IsToyUsable(itemID)
    end
    return true
end

local function IsItemUsableNow(itemID)
    if not itemID then
        return false
    end
    if IsUsableItem then
        local usable = IsUsableItem(itemID)
        return usable == true
    end
    return true
end

local function PickMailboxToyID()
    local def = UTILITY_ACTIONS.mailbox
    if not def or not def.mailboxCandidates then
        return nil
    end

    -- Pass 1: Prefer collected toys that are currently usable.
    for _, itemID in ipairs(def.mailboxCandidates) do
        if IsToyOwned(itemID) and IsToyUsableNow(itemID) then
            return itemID
        end
    end

    -- Pass 2: If all collected toys are on cooldown, still return the first collected toy.
    for _, itemID in ipairs(def.mailboxCandidates) do
        if IsToyOwned(itemID) then
            return itemID
        end
    end

    -- Pass 3: Fall back to physical items in bags.
    for _, itemID in ipairs(def.mailboxCandidates) do
        if HasItemAnywhere(itemID) and IsItemUsableNow(itemID) then
            return itemID
        end
    end

    -- Pass 4: Any physical item, even if currently unusable.
    for _, itemID in ipairs(def.mailboxCandidates) do
        if HasItemAnywhere(itemID) then
            return itemID
        end
    end

    return nil
end

-----------------------------------------------------------------------
-- Mount helpers (Auction House / Vendor mounts)
-----------------------------------------------------------------------

local function IsMountCollectedBySpell(spellID)
    if not spellID then
        return false
    end

    if C_MountJournal and C_MountJournal.GetMountFromSpell and C_MountJournal.GetMountInfoByID then
        local mountID = C_MountJournal.GetMountFromSpell(spellID)
        if mountID then
            local _, _, _, _, _, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(mountID)
            return isCollected == true
        end
    end

    -- Fallback: spell-known heuristic
    if IsSpellKnown and IsSpellKnown(spellID) then
        return true
    end

    return false
end

local VENDOR_MOUNT_PRIORITY = {
    { spellID = 264058, label = "Mighty Caravan Brutosaur" },
    { spellID = 457485, label = "Grizzly Hills Packmaster" },
    { spellID = 122708, label = "Grand Expedition Yak" },
}

local function GetTundraMammothSpellByFaction()
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    if faction == "Horde" then
        return 61447 -- Traveler's Tundra Mammoth (Horde)
    end
    return 61425 -- Traveler's Tundra Mammoth (Alliance/default)
end

local function ResolveVendorMountSpellID()
    for _, entry in ipairs(VENDOR_MOUNT_PRIORITY) do
        if IsMountCollectedBySpell(entry.spellID) then
            return entry.spellID
        end
    end

    local mammothSpell = GetTundraMammothSpellByFaction()
    if IsMountCollectedBySpell(mammothSpell) then
        return mammothSpell
    end

    return nil
end

-----------------------------------------------------------------------
-- Availability checking functions
-----------------------------------------------------------------------

local function IsMobileBankingAvailable()
    -- Check if player is in a guild
    if not IsInGuild() then
        return false, "Not in a guild"
    end

    local guildName = GetGuildInfo("player")
    if not guildName then
        return false, "Not in a guild"
    end

    -- Find guild faction in reputation list to check standing
    -- Mobile Banking requires Friendly (5) or higher
    if C_Reputation and C_Reputation.GetNumFactions then
        local numFactions = C_Reputation.GetNumFactions()
        for i = 1, numFactions do
            local factionData = C_Reputation.GetFactionDataByIndex(i)
            if factionData and not factionData.isHeader and factionData.name == guildName then
                -- factionData.reaction: 1=Hated, 2=Hostile, 3=Unfriendly, 4=Neutral, 5=Friendly, 6=Honored, 7=Revered, 8=Exalted
                local standingID = factionData.reaction
                if standingID and standingID < 5 then
                    return false, "Requires Friendly guild reputation"
                end
                return true, nil
            end
        end
    end

    -- Fallback: if we can't check reputation, assume available if in guild
    return true, nil
end

local function IsWarbandBankAvailable()
    -- Check if the spell is actually usable by this character
    local spellID = addon.CONST.SPELLS.WARBAND_BANK_INHIBITOR
    
    if C_Spell and C_Spell.IsSpellUsable then
        local usable = C_Spell.IsSpellUsable(spellID)
        if usable then
            return true, nil
        end
    end
    
    if IsSpellKnown and IsSpellKnown(spellID) then
        return true, nil
    end
    
    if C_PlayerInfo and C_PlayerInfo.HasAccountInventoryLock then
        local hasLock = C_PlayerInfo.HasAccountInventoryLock()
        if not hasLock then
            return true, nil
        end
    end
    
    return false, "Complete Gadgetzan questline to unlock"
end

local function IsMailboxAvailable()
    -- Check if we have any mailbox candidate (toy collected or item in bags)
    local def = UTILITY_ACTIONS.mailbox
    if not def or not def.mailboxCandidates then
        return false, "No mailbox toys configured"
    end

    for _, itemID in ipairs(def.mailboxCandidates) do
        if IsToyOwned(itemID) or HasItemAnywhere(itemID) then
            return true, nil
        end
    end

    return false, "Requires mailbox toy (Katy/Ohuna/Radiant/MOLL-E)"
end

local function IsTradersBrutosaurAvailable()
    local spellID = UTILITY_ACTIONS.tradersBrutosaur and UTILITY_ACTIONS.tradersBrutosaur.spellID
    if spellID and IsMountCollectedBySpell(spellID) then
        return true, nil
    end
    return false, "Requires Trader's Gilded Brutosaur mount"
end

local function IsVendorMountAvailable()
    local spellID = ResolveVendorMountSpellID()
    if spellID then
        return true, nil
    end
    return false, "Requires a vendor mount (Brutosaur/Packmaster/Yak/Mammoth)"
end

local function IsHearthstoneAvailable()
    return true, nil
end

local function IsDalaranHSAvailable()
    local itemID = addon.CONST.ITEMS.DALARAN_HS
    
    if not (PlayerHasToy and PlayerHasToy(itemID)) then
        return false, "Don't own Dalaran Hearthstone toy"
    end
    
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        if not C_QuestLog.IsQuestFlaggedCompleted(44663) then
            return false, "Complete Legion intro quest to unlock"
        end
    end
    
    return true, nil
end

local function IsGarrisonHSAvailable()
    local itemID = addon.CONST.ITEMS.GARRISON_HS
    
    if not (PlayerHasToy and PlayerHasToy(itemID)) then
        return false, "Don't own Garrison Hearthstone toy"
    end
    
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        if not C_QuestLog.IsQuestFlaggedCompleted(34378) then
            return false, "Complete WoD garrison quests to unlock"
        end
    end
    
    return true, nil
end

-- Map utility keys to their availability check functions
local AVAILABILITY_CHECKS = {
    mobileBank        = IsMobileBankingAvailable,
    mailbox           = IsMailboxAvailable,
    tradersBrutosaur  = IsTradersBrutosaurAvailable,
    vendorMount       = IsVendorMountAvailable,
    warbandBank       = IsWarbandBankAvailable,
    hearthstone       = IsHearthstoneAvailable,
    dalaranHS         = IsDalaranHSAvailable,
    garrisonHS        = IsGarrisonHSAvailable,
}

-----------------------------------------------------------------------
-- Hearthstone resolver
-----------------------------------------------------------------------

-- Known hearthstone toys (from RandomHearth; robust in practice)
local KNOWN_HEARTHSTONE_TOYS = {
    184353, 183716, 180290, 182773, 54452, 64488, 93672, 142542,
    162973, 163045, 165669, 165670, 165802, 166746, 166747, 168907,
    172179, 193588, 188952, 200630, 190237, 190196, 209035, 208704,
    206195, 212337, 210455, 228940, 235016, 236687, 245970, 246565,
    263489,
}

local hearthstoneCache = {
    lastScan = 0,
    resolvedID = nil,
}

local toyNameCache = {}

local function HasItemInBags(itemID)
    if not itemID or not GetItemCount then
        return false
    end
    local count = GetItemCount(itemID, false, false, false)
    return (count or 0) > 0
end

local function IsHearthstoneToyItemBySpell(itemID, hearthSpellID)
    if not itemID or not hearthSpellID or not GetItemSpell then
        return false
    end
    local _, spellID = GetItemSpell(itemID)
    return spellID == hearthSpellID
end

local function FindHearthstoneToyID()
    for _, toyID in ipairs(KNOWN_HEARTHSTONE_TOYS) do
        if IsToyOwnedAndUsable(toyID) then
            return toyID
        end
    end

    if not (C_ToyBox and C_ToyBox.GetNumToys and C_ToyBox.GetToyFromIndex and C_ToyBox.GetToyInfo) then
        return nil
    end

    local def = UTILITY_ACTIONS.hearthstone
    local hearthSpellID = (def and def.hearthSpellID) or 8690

    local numToys = C_ToyBox.GetNumToys()
    if not numToys or numToys <= 0 then
        return nil
    end

    local bestNonFav = nil

    for i = 1, numToys do
        local toyItemID = C_ToyBox.GetToyFromIndex(i)
        if toyItemID and IsToyOwnedAndUsable(toyItemID) then
            if IsHearthstoneToyItemBySpell(toyItemID, hearthSpellID) then
                local _, _, isFavorite = C_ToyBox.GetToyInfo(toyItemID)
                if isFavorite then
                    return toyItemID
                end
                if not bestNonFav then
                    bestNonFav = toyItemID
                end
            end
        end
    end

    return bestNonFav
end

local function PickHearthstoneResolvedID()
    local def = UTILITY_ACTIONS.hearthstone
    if not def then
        return nil
    end

    local now = (GetTime and GetTime()) or 0
    if hearthstoneCache.lastScan and (now - hearthstoneCache.lastScan) < 0.75 then
        return hearthstoneCache.resolvedID
    end
    hearthstoneCache.lastScan = now

    if HasItemInBags(def.itemID) then
        hearthstoneCache.resolvedID = def.itemID
        return def.itemID
    end

    if def.allowToyFallback then
        local toyID = FindHearthstoneToyID()
        hearthstoneCache.resolvedID = toyID
        return toyID
    end

    hearthstoneCache.resolvedID = nil
    return nil
end

local function GetToyNameCached(itemID)
    if not itemID then
        return nil
    end

    if toyNameCache[itemID] then
        return toyNameCache[itemID]
    end

    if GetItemInfo then
        local name = GetItemInfo(itemID)
        if name and name ~= "" then
            toyNameCache[itemID] = name
            return name
        end
    end

    if Item and Item.CreateFromItemID then
        local item = Item:CreateFromItemID(itemID)
        if item and item.ContinueOnItemLoad then
            item:ContinueOnItemLoad(function()
                local name = item:GetItemName()
                if name and name ~= "" then
                    toyNameCache[itemID] = name
                end
                if addon and addon.UpdateUtilityBar and not InCombatLockdown() then
                    addon:UpdateUtilityBar()
                end
            end)
        end
    end

    return nil
end

local function GetUtilityIcon(def, resolvedItemID)
    if def.iconTexture then
        return def.iconTexture
    end

    if def.kind == "spell" then
        local tex = addon.API.GetSpellTexture(def.spellID)
        if tex then return tex end

        if def.spellName then
            tex = addon.API.GetSpellTexture(def.spellName)
            if tex then return tex end
        end
    elseif def.kind == "item" then
        local itemID = resolvedItemID or def.itemID
        if itemID then
            return addon.API.GetItemIcon(itemID)
        end
    end

    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

-----------------------------------------------------------------------
-- Button creation
-----------------------------------------------------------------------

local function CreateUtilityButton(parent, index, size)
    local name = "GoblinToolboxUtilityButton" .. index
    local btn = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
    btn:SetSize(size, size)

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetAllPoints(true)

    btn.overlay = btn:CreateTexture(nil, "OVERLAY")
    btn.overlay:SetAllPoints(btn.icon)
    btn.overlay:SetColorTexture(0, 0, 0, 0.6)
    btn.overlay:Hide()

    btn.cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    btn.cooldown:SetAllPoints(true)
    btn.cooldown:SetDrawEdge(true)
    btn.cooldown:SetHideCountdownNumbers(false)
    btn.cooldown:SetFrameLevel(btn:GetFrameLevel() + 1)

    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")

    btn:RegisterForClicks("AnyDown")
    if not InCombatLockdown() then
        btn:SetAttribute("pressAndHoldAction", true)
    end

    btn:SetScript("OnEnter", function(selfBtn)
        local title = selfBtn.tooltipTitle or selfBtn.tooltip
        if not title then
            return
        end

        GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 1, 1, 1, true)

        if selfBtn.tooltipSubtext then
            GameTooltip:AddLine(selfBtn.tooltipSubtext, 0.8, 0.8, 0.8, true)
        end
        
        if selfBtn.unavailableReason then
            GameTooltip:AddLine(" ", 1, 1, 1)
            GameTooltip:AddLine("|cffff4444Not Available:|r " .. selfBtn.unavailableReason, 1, 0.5, 0.5, true)
        end

        GameTooltip:AddLine("Shift+Right-Click to remove", 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    btn:SetScript("OnMouseUp", function(selfBtn, mouseButton)
        if mouseButton == "RightButton" and IsShiftKeyDown() and selfBtn.utilityKey then
            if addon.db and addon.db.profile and addon.db.profile.utilityButtons then
                addon.db.profile.utilityButtons[selfBtn.utilityKey] = false

                local def = UTILITY_ACTIONS[selfBtn.utilityKey]
                local label = def and def.label or selfBtn.utilityKey
                print("|cff00ff00Goblin Toolbox:|r Removed " .. label .. " from Utility Bar")

                addon:UpdateUtilityBar()
            end
        end
    end)

    btn.utilDef = nil
    btn.itemID = nil
    btn.spellKey = nil
    btn.spellID = nil
    btn.utilityKey = nil
    btn.tooltip = nil
    btn.tooltipTitle = nil
    btn.tooltipSubtext = nil
    btn.unavailableReason = nil
    btn._lastStart = nil
    btn._lastDuration = nil

    return btn
end

-----------------------------------------------------------------------
-- Cooldown handling
-----------------------------------------------------------------------

local function GetCooldownForUtilityButton(btn)
    if not btn or not btn.utilDef then
        return 0, 0, 0
    end

    local def = btn.utilDef

    if def.kind == "spell" then
        local spellID = btn.spellID or def.spellID
        if not spellID then
            return 0, 0, 0
        end
        return GetSpellCooldownCompat(spellID)
    end

    if def.kind == "item" then
        local itemID = btn.itemID
        if not itemID then
            return 0, 0, 0
        end

        if btn.isToy and C_ToyBox and C_ToyBox.GetToyCooldown then
            local tStart, tDur, tEnabled = C_ToyBox.GetToyCooldown(itemID)
            tStart = tStart or 0
            tDur = tDur or 0
            tEnabled = NormalizeEnabled(tEnabled)
            return tStart, tDur, tEnabled
        end

        if C_Item and C_Item.GetItemCooldown then
            local start, duration, enabled = C_Item.GetItemCooldown(itemID)
            return start or 0, duration or 0, NormalizeEnabled(enabled)
        end

        if GetItemCooldown then
            local start, duration, enabled = GetItemCooldown(itemID)
            return start or 0, duration or 0, NormalizeEnabled(enabled)
        end

        return 0, 0, 0
    end

    return 0, 0, 0
end

local function UpdateUtilityButtonCooldown(btn)
    if not btn or not btn.cooldown or not btn.utilDef then
        return
    end

    local start, duration, enabled = GetCooldownForUtilityButton(btn)
    local valid = (enabled == 1 and start > 0 and duration and duration > 1.5)

    if valid then
        if btn._lastStart ~= start or btn._lastDuration ~= duration then
            btn._lastStart = start
            btn._lastDuration = duration
            btn.cooldown:SetCooldown(start, duration)
            btn.cooldown:Show()
        end
    else
        if btn.cooldown:IsShown() then
            if btn.cooldown.Clear then
                btn.cooldown:Clear()
            else
                btn.cooldown:SetCooldown(0, 0)
            end
            btn.cooldown:Hide()
        end
        btn._lastStart = nil
        btn._lastDuration = nil
    end
end

-----------------------------------------------------------------------
-- Button setup
-----------------------------------------------------------------------

local function SetupUtilityButton(btn, def, resolvedItemID, resolvedSpellID)
    btn.utilDef = def
    btn.itemID = nil
    btn.spellKey = nil
    btn.spellID = nil
    btn.utilityKey = def.key
    btn.unavailableReason = nil

    local checkFunc = AVAILABILITY_CHECKS[def.key]
    local isAvailable = true
    local unavailableReason = nil
    
    if checkFunc then
        isAvailable, unavailableReason = checkFunc()
    end
    
    if isAvailable then
        btn.icon:SetDesaturated(false)
        if btn.overlay then
            btn.overlay:Hide()
        end
        btn.unavailableReason = nil
    else
        btn.icon:SetDesaturated(true)
        if btn.overlay then
            btn.overlay:Show()
        end
        btn.unavailableReason = unavailableReason
    end

    local icon, tip

    if def.kind == "spell" then
        local spellID = resolvedSpellID or def.spellID
        local spellName = addon.API.GetSpellName(spellID)
        local key = spellName or spellID

        if not InCombatLockdown() then
            btn:SetAttribute("type", "spell")
            btn:SetAttribute("typerelease", "spell")
            btn:SetAttribute("spell", key)
            btn:SetAttribute("toy", nil)
            btn:SetAttribute("item", nil)
        end

        btn.spellKey = key
        btn.spellID = spellID
        icon = addon.API.GetSpellTexture(spellID) or GetUtilityIcon(def)
        tip = spellName or def.label or "Spell"

    elseif def.kind == "item" then
        local itemID = resolvedItemID or def.itemID
        btn.itemID = itemID

        local isToy = (itemID and PlayerHasToy and PlayerHasToy(itemID)) or false
        btn.isToy = isToy

        if not InCombatLockdown() then
            btn:SetAttribute("type", nil)
            btn:SetAttribute("typerelease", nil)
            btn:SetAttribute("spell", nil)

            if isToy then
                btn:SetAttribute("type", "toy")
                btn:SetAttribute("typerelease", "toy")
                btn:SetAttribute("toy", itemID)
                btn:SetAttribute("item", nil)
            else
                btn:SetAttribute("type", "item")
                btn:SetAttribute("typerelease", "item")
                btn:SetAttribute("item", itemID)
                btn:SetAttribute("toy", nil)
            end
        end

        icon = GetUtilityIcon(def, itemID)

        if isToy then
            local name = GetToyNameCached(itemID)
            tip = name or def.label or "Toy"
        else
            if itemID and GetItemInfo then
                local name = GetItemInfo(itemID)
                tip = name or def.label or "Item"
            else
                tip = def.label or "Item"
            end
        end
    else
        if not InCombatLockdown() then
            btn:SetAttribute("type", nil)
            btn:SetAttribute("typerelease", nil)
            btn:SetAttribute("toy", nil)
            btn:SetAttribute("item", nil)
            btn:SetAttribute("spell", nil)
        end
        icon = "Interface\\Icons\\INV_Misc_QuestionMark"
        tip = def.label or "Utility"
    end

    btn.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    btn.tooltip = nil
    btn.tooltipTitle = nil
    btn.tooltipSubtext = nil

    -- Tooltip UX: keep Hearthstone button semantics consistent even when a toy is used.
    if def.key == "vendorMount" then
        btn.tooltipTitle = "Vendor Mount"
        btn.tooltipSubtext = tip
    elseif def.key == "tradersBrutosaur" then
        btn.tooltipTitle = "Auction House"
        btn.tooltipSubtext = tip
    elseif def.key == "hearthstone" then
        btn.tooltipTitle = "Hearthstone"
        if btn.itemID == 6948 then
            btn.tooltipSubtext = "Uses Hearthstone"
        else
            btn.tooltipSubtext = "Uses an available Hearthstone toy"
        end
    else
        btn.tooltip = tip
    end

    UpdateUtilityButtonCooldown(btn)
end

-----------------------------------------------------------------------
-- Position persistence
-----------------------------------------------------------------------

addon._utilityMovedThisSession = false

local function SaveUtilityBarPosition()
    local db = addon.db and addon.db.profile
    local bar = addon.utilityBar
    if not db or not bar then return end

    local point, _, relPoint, xOfs, yOfs = bar:GetPoint(1)
    if not point then return end

    db.utilityBarPos = db.utilityBarPos or {}
    db.utilityBarPos.point = point
    db.utilityBarPos.relPoint = relPoint
    db.utilityBarPos.x = xOfs
    db.utilityBarPos.y = yOfs
end

local function Utility_DeferredApply()
    local db = addon.db and addon.db.profile
    local bar = addon.utilityBar
    if not db or not bar then return end

    local pos = db.utilityBarPos
    if pos and pos.point and pos.relPoint and pos.x and pos.y and not addon._utilityMovedThisSession then
        bar:ClearAllPoints()
        bar:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    end
end

-----------------------------------------------------------------------
-- Utility bar creation
-----------------------------------------------------------------------

function addon:CreateUtilityBar()
    if self.utilityBar then
        return
    end

    local f = CreateFrame("Frame", "GoblinToolboxUtilityBar", UIParent, "BackdropTemplate")
    self.utilityBar = f

    f:SetSize(200, 34)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")

    f:SetScript("OnDragStart", function(frame)
        if addon.db and addon.db.profile and addon.db.profile.lockFrame then
            return
        end
        frame:StartMoving()
    end)

    f:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        addon._utilityMovedThisSession = true
        SaveUtilityBarPosition()
    end)

    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile     = true, tileSize = 16, edgeSize = 2,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    f:SetBackdropBorderColor(0.2, 0.25, 0.35, 1)

    if addon.HUD and addon.HUD.frame then
        f:SetPoint("TOPLEFT", addon.HUD.frame, "BOTTOMLEFT", 0, -8)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, -120)
    end

    Utility_DeferredApply()

    f.dragHandle = CreateDragHandle(f)
    f.buttons = {}

    self:UpdateBackground()
end

-----------------------------------------------------------------------
-- Utility bar update
-----------------------------------------------------------------------

function addon:UpdateUtilityBar()
    local db = self.db and self.db.profile
    local bar = self.utilityBar

    if not db then
        return
    end

    if not bar then
        self:CreateUtilityBar()
        bar = self.utilityBar
        if not bar then
            return
        end
    end

    local wantEnabled = db.enabled and db.modules and db.modules.Utility ~= false

    local hide = false
    if wantEnabled then
        if db.hideInCombat and UnitAffectingCombat("player") then
            hide = true
        end
        if db.hideInInstances then
            local inInstance, instanceType = IsInInstance()
            if inInstance and instanceType ~= "none" then
                hide = true
            end
        end
    else
        hide = true
    end

    self:SetSecureFrameVisible(bar, not hide)

    if hide then
        return
    end

    if bar.dragHandle and bar.dragHandle.UpdateColor then
        bar.dragHandle:UpdateColor()
    end
    if bar.dragHandle and bar.dragHandle.UpdateVisibility then
        bar.dragHandle:UpdateVisibility()
    end

    if InCombatLockdown() then
        self._needsUtilityRefresh = true
        return
    end

    bar.buttons = bar.buttons or {}

    local size = addon.CONST.BUTTON_SIZE_SMALL
    local spacing = addon.CONST.SPACING_SMALL
    local padding = addon.CONST.PADDING

    local shown = 0

    for _, key in ipairs(UTILITY_ORDER) do
        local def = UTILITY_ACTIONS[key]
        local enabled = db.utilityButtons and db.utilityButtons[key]
        if enabled == nil and (key == "tradersBrutosaur" or key == "vendorMount") then
            enabled = true
        end

        if def and enabled then
            if key == "mailbox" then
                local mailboxItemID = PickMailboxToyID()
                if mailboxItemID then
                    shown = shown + 1
                    local btn = bar.buttons[shown]
                    if not btn then
                        btn = CreateUtilityButton(bar, shown, size)
                        bar.buttons[shown] = btn
                    end
                    SetupUtilityButton(btn, def, mailboxItemID)
                end

            elseif key == "tradersBrutosaur" then
                local spellID = def.spellID
                if spellID and IsMountCollectedBySpell(spellID) then
                    shown = shown + 1
                    local btn = bar.buttons[shown]
                    if not btn then
                        btn = CreateUtilityButton(bar, shown, size)
                        bar.buttons[shown] = btn
                    end
                    SetupUtilityButton(btn, def, nil, spellID)
                end

            elseif key == "vendorMount" then
                local spellID = ResolveVendorMountSpellID()
                if spellID then
                    shown = shown + 1
                    local btn = bar.buttons[shown]
                    if not btn then
                        btn = CreateUtilityButton(bar, shown, size)
                        bar.buttons[shown] = btn
                    end
                    SetupUtilityButton(btn, def, nil, spellID)
                end

            elseif key == "hearthstone" then
                local hsID = PickHearthstoneResolvedID()
                shown = shown + 1
                local btn = bar.buttons[shown]
                if not btn then
                    btn = CreateUtilityButton(bar, shown, size)
                    bar.buttons[shown] = btn
                end
                SetupUtilityButton(btn, def, hsID)

            else
                shown = shown + 1
                local btn = bar.buttons[shown]
                if not btn then
                    btn = CreateUtilityButton(bar, shown, size)
                    bar.buttons[shown] = btn
                end
                SetupUtilityButton(btn, def, nil, nil)
            end
        end
    end

    for i = 1, #bar.buttons do
        local btn = bar.buttons[i]
        if btn then
            if i <= shown then
                btn:ClearAllPoints()
                if i == 1 then
                    btn:SetPoint("LEFT", bar, "LEFT", padding, 0)
                else
                    btn:SetPoint("LEFT", bar.buttons[i - 1], "RIGHT", spacing, 0)
                end
                btn:Show()
                UpdateUtilityButtonCooldown(btn)
            else
                btn:Hide()
            end
        end
    end

    if shown == 0 then
        self:SetSecureFrameVisible(bar, false)
        return
    end

    local width = padding * 2 + shown * size + (shown - 1) * spacing
    local height = size + padding * 2
    bar:SetSize(width, height)
end

-----------------------------------------------------------------------
-- Cooldown updates
-----------------------------------------------------------------------

function addon:UpdateUtilityCooldowns()
    local bar = self.utilityBar
    if not bar or not bar.buttons then
        return
    end

    for _, btn in ipairs(bar.buttons) do
        if btn and btn:IsShown() then
            UpdateUtilityButtonCooldown(btn)
        end
    end
end
