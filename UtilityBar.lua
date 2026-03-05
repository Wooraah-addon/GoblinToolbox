-- UtilityBar.lua
-- Utility bar: secure action buttons for Mobile Banking, Mailbox, Hearthstones, etc.

local addonName, addon = ...

-----------------------------------------------------------------------
-- Secure confirmation frame for mailbox (with real secure button)
-----------------------------------------------------------------------

local mailboxConfirmFrame
local function GetMailboxConfirmFrame()
    if mailboxConfirmFrame then
        return mailboxConfirmFrame
    end

    -- Create a StaticPopup-styled confirmation dialog with secure button
    local f = CreateFrame("Frame", "GoblinToolbox_MailboxConfirmFrame", UIParent, "BackdropTemplate")
    f:SetSize(320, 100)
    f:SetPoint("CENTER")

    -- Use standard StaticPopup backdrop
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    f:SetFrameStrata("DIALOG")
    f:Hide()

    -- Text (StaticPopup style)
    local text = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("TOP", 0, -24)
    text:SetWidth(290)
    text:SetJustifyH("CENTER")
    text:SetText("Summon mailbox now?\nThis starts a cooldown.")
    f.text = text

    -- Yes button (SECURE, using standard button template)
    local yesBtn = CreateFrame("Button", nil, f, "SecureActionButtonTemplate, UIPanelButtonTemplate")
    yesBtn:SetSize(128, 21)
    yesBtn:SetPoint("BOTTOM", -64, 16)
    yesBtn:SetText(YES)
    -- Don't override RegisterForClicks - let SecureActionButtonTemplate handle it

    -- Post-click script to hide frame (runs in insecure context after secure action)
    yesBtn:SetScript("PostClick", function()
        f:Hide()
    end)

    f.yesBtn = yesBtn

    -- Cancel button (normal, using standard button template)
    local cancelBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    cancelBtn:SetSize(128, 21)
    cancelBtn:SetPoint("BOTTOM", 64, 16)
    cancelBtn:SetText(CANCEL)

    cancelBtn:SetScript("OnClick", function()
        f:Hide()
    end)

    f.cancelBtn = cancelBtn

    -- ESC to close
    f:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:Hide()
        end
    end)
    f:EnableKeyboard(true)

    mailboxConfirmFrame = f
    return f
end

-----------------------------------------------------------------------
-- Secure confirmation frames for Logout and Reload
-----------------------------------------------------------------------

local logoutConfirmFrame
local function GetLogoutConfirmFrame()
    if logoutConfirmFrame then
        return logoutConfirmFrame
    end

    local f = CreateFrame("Frame", "GoblinToolbox_LogoutConfirmFrame", UIParent, "BackdropTemplate")
    f:SetSize(320, 90)
    f:SetPoint("CENTER")
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    f:SetFrameStrata("DIALOG")
    f:Hide()

    local text = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("TOP", 0, -24)
    text:SetWidth(290)
    text:SetJustifyH("CENTER")
    text:SetText("Log out now?")

    local yesBtn = CreateFrame("Button", nil, f, "SecureActionButtonTemplate, UIPanelButtonTemplate")
    yesBtn:SetSize(128, 21)
    yesBtn:SetPoint("BOTTOM", -64, 16)
    yesBtn:SetText(YES)
    yesBtn:SetAttribute("type", "macro")
    yesBtn:SetAttribute("macrotext", "/logout")
    yesBtn:SetScript("PostClick", function() f:Hide() end)
    f.yesBtn = yesBtn

    local cancelBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    cancelBtn:SetSize(128, 21)
    cancelBtn:SetPoint("BOTTOM", 64, 16)
    cancelBtn:SetText(CANCEL)
    cancelBtn:SetScript("OnClick", function() f:Hide() end)

    f:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then self:Hide() end
    end)
    f:EnableKeyboard(true)

    logoutConfirmFrame = f
    return f
end

local reloadConfirmFrame
local function GetReloadConfirmFrame()
    if reloadConfirmFrame then
        return reloadConfirmFrame
    end

    local f = CreateFrame("Frame", "GoblinToolbox_ReloadConfirmFrame", UIParent, "BackdropTemplate")
    f:SetSize(320, 90)
    f:SetPoint("CENTER")
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    f:SetFrameStrata("DIALOG")
    f:Hide()

    local text = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("TOP", 0, -24)
    text:SetWidth(290)
    text:SetJustifyH("CENTER")
    text:SetText("Reload UI now?")

    local yesBtn = CreateFrame("Button", nil, f, "SecureActionButtonTemplate, UIPanelButtonTemplate")
    yesBtn:SetSize(128, 21)
    yesBtn:SetPoint("BOTTOM", -64, 16)
    yesBtn:SetText(YES)
    yesBtn:SetAttribute("type", "macro")
    yesBtn:SetAttribute("macrotext", "/reload")
    yesBtn:SetScript("PostClick", function() f:Hide() end)
    f.yesBtn = yesBtn

    local cancelBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    cancelBtn:SetSize(128, 21)
    cancelBtn:SetPoint("BOTTOM", 64, 16)
    cancelBtn:SetText(CANCEL)
    cancelBtn:SetScript("OnClick", function() f:Hide() end)

    f:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then self:Hide() end
    end)
    f:EnableKeyboard(true)

    reloadConfirmFrame = f
    return f
end


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
        -- Move the anchor (parent's parent), not the visual frame
        local anchor = parent:GetParent()
        if anchor then
            anchor:StartMoving()
        end
    end)

    handle:SetScript("OnDragStop", function(self)
        -- Stop moving the anchor
        local anchor = parent:GetParent()
        if not anchor then return end
        anchor:StopMovingOrSizing()
        addon._utilityMovedThisSession = true

        -- Persist position using growth-based anchoring
        local db = addon.db and addon.db.profile
        if not db then
            return
        end

        -- Save anchor position (not visual frame position)
        local point, relativeTo, relativePoint, xOfs, yOfs = anchor:GetPoint(1)
        if point then
            db.utilityBarPos = db.utilityBarPos or {}
            db.utilityBarPos.point = point
            db.utilityBarPos.relPoint = relativePoint or "BOTTOMLEFT"
            db.utilityBarPos.x = xOfs
            db.utilityBarPos.y = yOfs
        end
    end)

    -- Hover behavior
    handle:SetScript("OnEnter", function(self)
        -- Always show on hover
        self:SetAlpha(1)

        -- Tooltip
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if addon.db and addon.db.profile and addon.db.profile.lockFrame then
            GameTooltip:SetText("Frame Locked", 1, 0.2, 0.2)
            GameTooltip:AddLine("Unlock via lock icon or by deselecting \"Lock Frames\" in the /gtb menu", 0.8, 0.8, 0.8, true)
        else
            GameTooltip:SetText("Drag to Move", 0.2, 1, 0.2)
            GameTooltip:AddLine("Lock frames using the lock icon or by selecting \"Lock Frames\" in the /gtb menu", 0.8, 0.8, 0.8, true)
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
    logout = {
        key         = "logout",
        label       = "Logout",
        kind        = "macro",
        macroText   = "/logout",
        iconTexture = 3565717,  -- Ability_revendreth_demonhunter
    },

    reload = {
        key         = "reload",
        label       = "Reload",
        kind        = "macro",
        macroText   = "/reload",
        iconTexture = 3565720,  -- Ability_revendreth_mage
    },

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
            addon.CONST.ITEMS.MOLL_E,
        },
    },

    tradersBrutosaur = {
        key         = "tradersBrutosaur",
        label       = "Auction House",
        kind        = "mount",
        spellID     = 465235, -- Trader's Gilded Brutosaur
    },

    vendorMount = {
        key         = "vendorMount",
        label       = "Vendor Mount",
        kind        = "mount",
        -- spellID resolved dynamically from priority list
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

    classQuickTravel = {
        key      = "classQuickTravel",
        label    = "Class Travel",
        kind     = "dynamicSpell",
    },

    housingTeleport = {
        key             = "housingTeleport",
        label           = "Housing",
        kind            = "housing",
        iconTexture     = 7252953,  -- Ui_homestone-64
        cooldownSpellID = 1233637,  -- Teleport Home spell ID for cooldown tracking
    },

    resetInstances = {
        key         = "resetInstances",
        label       = "Reset Instances",
        kind        = "macro",
        macroText   = "/run ResetInstances()",
        iconTexture = 236393,  -- Achievement_bg_wineos_underxminutes
    },
}

local UTILITY_ORDER = {
    "logout",
    "reload",
    "mobileBank",
    "mailbox",
    "tradersBrutosaur",
    "vendorMount",
    "warbandBank",
    "hearthstone",
    "dalaranHS",
    "garrisonHS",
    "classQuickTravel",
    "housingTeleport",
    "resetInstances",
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
-- Note: In Midnight (12.0+), cooldown info fields are "secret values" in instanced content
-- that cannot be used in boolean tests, comparisons, or arithmetic. Use pcall to handle this.
local function GetSpellCooldownCompat(spellID)
    if C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(spellID)
        if not info then
            return 0, 0, 1
        end
        -- Use pcall to handle secret values in Midnight 12.0+ (can appear in instances, not just combat)
        local success, start, duration, enabled = pcall(function()
            local s = info.startTime or 0
            local d = info.duration or 0
            local e = info.isEnabled and 1 or 0
            return s, d, e
        end)
        if success then
            return start, duration, enabled
        else
            return 0, 0, 1
        end
    end

    -- Legacy fallback (pre-11.0)
    if _G.GetSpellCooldown then
        local start, duration, enabled = _G.GetSpellCooldown(spellID)
        return start or 0, duration or 0, NormalizeEnabled(enabled)
    end

    return 0, 0, 0
end

local function GetOverrideSpellCompat(baseSpellID)
    if not baseSpellID then return nil end
    
    if C_Spell and C_Spell.GetOverrideSpell then
        local override = C_Spell.GetOverrideSpell(baseSpellID)
        return (override and override ~= 0) and override or baseSpellID
    end
    
    if C_SpellBook and C_SpellBook.FindSpellOverrideByID then
        local override = C_SpellBook.FindSpellOverrideByID(baseSpellID)
        return (override and override ~= 0) and override or baseSpellID
    end

    if _G.FindSpellOverrideByID then
        local override = _G.FindSpellOverrideByID(baseSpellID)
        return (override and override ~= 0) and override or baseSpellID
    end

    return baseSpellID
end

local function IsToyOwnedAndUsable(itemID)
    if not itemID then
        return false
    end

    local owned = false

    if PlayerHasToy and PlayerHasToy(itemID) then
        owned = true
    elseif addon.API.GetItemCount(itemID, true) > 0 then
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

local function PickMailboxToyID()
    local def = UTILITY_ACTIONS.mailbox
    if not def or not def.mailboxCandidates then
        return nil
    end

    for _, itemID in ipairs(def.mailboxCandidates) do
        if IsToyOwnedAndUsable(itemID) then
            return itemID
        end
    end

    return nil
end

local function ResolveClassQuickTravel()
    local _, classFile = UnitClass("player")
    local baseSpellID
    
    if classFile == "DRUID" then
        baseSpellID = 193753 -- Dreamwalk
    elseif classFile == "MONK" then
        baseSpellID = 126892 -- Zen Pilgrimage
    elseif classFile == "DEATHKNIGHT" then
        baseSpellID = 50977 -- Death Gate
    end

    -- Use Dreamwalk icon (1391708) as placeholder for unsupported classes
    local dreamwalkID = 193753
    
    if not baseSpellID then
        return dreamwalkID, addon.API.GetSpellTexture(dreamwalkID), nil, false, "Druid / Death Knight / Monk only"
    end

    local isLearned = addon.API.IsSpellKnown(baseSpellID)

    if not isLearned then
        local name = addon.API.GetSpellName(baseSpellID) or "Class Travel"
        return baseSpellID, addon.API.GetSpellTexture(baseSpellID), name, false, "Spell not learned"
    end

    local effectiveSpellID = GetOverrideSpellCompat(baseSpellID)
    local name = addon.API.GetSpellName(effectiveSpellID) or addon.API.GetSpellName(baseSpellID) or "Class Travel"
    local icon = addon.API.GetSpellTexture(effectiveSpellID) or addon.API.GetSpellTexture(baseSpellID)

    return effectiveSpellID, icon, name, true, nil
end

-----------------------------------------------------------------------
-- Mount helpers
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
    if addon.API.IsSpellKnown(spellID) then
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
    return 61425 -- Traveler's Tundra Mammoth (Alliance)
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
-- Housing helpers
-----------------------------------------------------------------------

-- Hidden secure buttons for Housing (uses native "teleporthome" / "returnhome" action types)
local housingTeleportBtn = CreateFrame("Button", "GTB_HousingTeleport", UIParent, "SecureActionButtonTemplate")
housingTeleportBtn:SetSize(1, 1)
housingTeleportBtn:SetPoint("BOTTOMRIGHT", UIParent, "TOPLEFT", -1, -1)
housingTeleportBtn:RegisterForClicks("AnyDown", "AnyUp")

local housingReturnBtn = CreateFrame("Button", "GTB_HousingReturn", UIParent, "SecureActionButtonTemplate")
housingReturnBtn:SetSize(1, 1)
housingReturnBtn:SetPoint("BOTTOMRIGHT", UIParent, "TOPLEFT", -2, -2)
housingReturnBtn:RegisterForClicks("AnyDown", "AnyUp")

-- Set up return button immediately (no house data needed)
if not InCombatLockdown() then
    housingReturnBtn:SetAttribute("type", "returnhome")
end

local function SetHousingTeleportAttributes(neighborhoodGUID, houseGUID, plotID)
    if InCombatLockdown() then
        housingTeleportBtn._pendingData = { neighborhoodGUID, houseGUID, plotID }
        housingTeleportBtn:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    if neighborhoodGUID and houseGUID and plotID then
        housingTeleportBtn:SetAttribute("type", "teleporthome")
        housingTeleportBtn:SetAttribute("house-neighborhood-guid", neighborhoodGUID)
        housingTeleportBtn:SetAttribute("house-guid", houseGUID)
        housingTeleportBtn:SetAttribute("house-plot-id", plotID)
    end
end

housingTeleportBtn:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_ENABLED" and self._pendingData then
        SetHousingTeleportAttributes(unpack(self._pendingData))
        self._pendingData = nil
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    end
end)

-- Track whether we're in a housing zone for dual-mode button
local isInHousingZone = false

local function UpdateHousingZoneState()
    local wasReturn = isInHousingZone

    -- CanReturnAfterVisitingHouse = true when visiting another player's house
    -- (the only scenario where "Return to Previous Location" applies)
    local canReturn = C_HousingNeighborhood
        and C_HousingNeighborhood.CanReturnAfterVisitingHouse
        and C_HousingNeighborhood.CanReturnAfterVisitingHouse()
        or false

    isInHousingZone = canReturn

    -- Refresh utility bar if state changed (swaps icon/macro)
    if wasReturn ~= isInHousingZone and addon.UpdateUtilityBar then
        addon:UpdateUtilityBar()
    end
end

function addon:IsInHousingZone()
    -- Always check live state (covers reload-in-zone and missed events)
    if C_HousingNeighborhood
        and C_HousingNeighborhood.CanReturnAfterVisitingHouse
        and C_HousingNeighborhood.CanReturnAfterVisitingHouse() then
        return true
    end
    return isInHousingZone
end

-- Housing zone event listener
local housingZoneFrame = CreateFrame("Frame")
housingZoneFrame:RegisterEvent("HOUSE_PLOT_ENTERED")
housingZoneFrame:RegisterEvent("HOUSE_PLOT_EXITED")
housingZoneFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
housingZoneFrame:SetScript("OnEvent", function()
    UpdateHousingZoneState()
end)

-- Called from GoblinToolbox.lua on PLAYER_LOGIN
function addon:InitHousingCache()
    if not C_Housing or not EventUtil then
        return
    end

    -- Set return button attribute if we missed the initial setup (combat at load)
    if not InCombatLockdown() then
        housingReturnBtn:SetAttribute("type", "returnhome")
    end

    pcall(function()
        EventUtil.RegisterOnceFrameEventAndCallback("PLAYER_HOUSE_LIST_UPDATED", function(houseList)
            if houseList and houseList[1] then
                local h = houseList[1]
                if h.neighborhoodGUID and h.houseGUID and h.plotID then
                    SetHousingTeleportAttributes(h.neighborhoodGUID, h.houseGUID, h.plotID)
                end
            end
        end)
        C_Housing.GetPlayerOwnedHouses()
    end)

    -- Check initial housing zone state
    UpdateHousingZoneState()
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
    -- (Better to show it and have it fail than hide it when it should work)
    return true, nil
end

local function IsWarbandBankAvailable()
    -- Check if the spell is actually usable by this character
    local spellID = addon.CONST.SPELLS.WARBAND_BANK_INHIBITOR
    
    -- Method 1: Check if spell is usable (most reliable)
    if C_Spell and C_Spell.IsSpellUsable then
        local usable = C_Spell.IsSpellUsable(spellID)
        if type(usable) == "boolean" and usable then
            return true, nil
        end
    end
    
    -- Method 2: Check if spell is known (fallback)
    if addon.API.IsSpellKnown(spellID) then
        return true, nil
    end
    
    -- Method 3: Legacy check for account lock (secondary fallback)
    if C_PlayerInfo and C_PlayerInfo.HasAccountInventoryLock then
        local hasLock = C_PlayerInfo.HasAccountInventoryLock()
        if not hasLock then
            return true, nil
        end
    end
    
    return false, "Complete Gadgetzan questline to unlock"
end

local function IsMailboxAvailable()
    -- Check if we have any usable mailbox toy
    local def = UTILITY_ACTIONS.mailbox
    if not def or not def.mailboxCandidates then
        return false, "No mailbox toys configured"
    end

    for _, itemID in ipairs(def.mailboxCandidates) do
        if IsToyOwnedAndUsable(itemID) then
            return true, nil
        end
    end
    
    return false, "Requires mailbox toy (Katy/Ohuna/MOLL-E)"
end

local function IsHearthstoneAvailable()
    -- Hearthstone is always available (everyone has access)
    return true, nil
end

local function IsDalaranHSAvailable()
    local itemID = addon.CONST.ITEMS.DALARAN_HS
    
    -- Check 1: Do we own the toy?
    if not (PlayerHasToy and PlayerHasToy(itemID)) then
        return false, "Don't own Dalaran Hearthstone toy"
    end
    
    -- Check 2: Did we complete "In the Blink of an Eye" quest?  (Quest ID: 44663)
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        if not C_QuestLog.IsQuestFlaggedCompleted(44663) then
            return false, "Complete Legion intro quest to unlock"
        end
    end
    
    return true, nil
end

local function IsGarrisonHSAvailable()
    local itemID = addon.CONST.ITEMS.GARRISON_HS
    
    -- Check 1: Do we own the toy?
    if not (PlayerHasToy and PlayerHasToy(itemID)) then
        return false, "Don't own Garrison Hearthstone toy"
    end
    
    -- Check 2: Did we complete "Establish Your Garrison" quest? (Quest ID: 34378)
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        if not C_QuestLog.IsQuestFlaggedCompleted(34378) then
            return false, "Complete WoD garrison quests to unlock"
        end
    end
    
    return true, nil
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

local function IsHousingTeleportAvailable()
    if not (C_Housing and C_Housing.TeleportHome) then
        return false, "Housing not unlocked"
    end
    return true, nil
end

local function IsResetInstancesAvailable()
    -- Check if in combat
    if InCombatLockdown() then
        return false, "Not available in combat"
    end

    -- Check if in group and not leader
    if IsInGroup() and not UnitIsGroupLeader("player") then
        return false, "Party leader required"
    end

    return true, nil
end

-- Map utility keys to their availability check functions
local AVAILABILITY_CHECKS = {
    mobileBank       = IsMobileBankingAvailable,
    mailbox          = IsMailboxAvailable,
    tradersBrutosaur = IsTradersBrutosaurAvailable,
    vendorMount      = IsVendorMountAvailable,
    warbandBank      = IsWarbandBankAvailable,
    hearthstone      = IsHearthstoneAvailable,
    dalaranHS        = IsDalaranHSAvailable,
    garrisonHS       = IsGarrisonHSAvailable,
    housingTeleport  = IsHousingTeleportAvailable,
    resetInstances   = IsResetInstancesAvailable,
}

-----------------------------------------------------------------------
-- Hearthstone resolver
--
-- Practical fix:
-- 1) Prefer item 6948 if in bags (reliable).
-- 2) Otherwise, prefer any owned/usable hearthstone toy from a known list
--    (sourced from RandomHearth's rhToys list).
-- 3) If none found, fallback to a ToyBox scan using GetItemSpell == 8690,
--    which is NOT universal but may help on some clients.
-----------------------------------------------------------------------

-- Known hearthstone toys (from RandomHearth; robust in practice)
local KNOWN_HEARTHSTONE_TOYS = {
    184353, -- Kyrian Hearthstone
    183716, -- Venthyr Sinstone
    180290, -- Night Fae Hearthstone
    182773, -- Necrolord Hearthstone
    54452,  -- Ethereal Portal
    64488,  -- The Innkeeper's Daughter
    93672,  -- Dark Portal
    142542, -- Tome of Town Portal
    162973, -- Greatfather Winter's Hearthstone
    163045, -- Headless Horseman's Hearthstone
    165669, -- Lunar Elder's Hearthstone
    165670, -- Peddlefeet's Lovely Hearthstone
    165802, -- Noble Gardener's Hearthstone
    166746, -- Fire Eater's Hearthstone
    166747, -- Brewfest Reveler's Hearthstone
    168907, -- Holographic Digitalization Hearthstone
    172179, -- Eternal Traveler's Hearthstone
    193588, -- Timewalker's Hearthstone
    188952, -- Dominated Hearthstone
    200630, -- Ohn'ir Windsage's Hearthstone
    190237, -- Broker Translocation Matrix
    190196, -- Enlightened Hearthstone
    209035, -- Hearthstone of the Flame
    208704, -- Deepdweller's Earthen Hearthstone
    206195, -- Path of the Naaru
    212337, -- Stone of the Hearth
    210455, -- Draenic Hologem
    228940, -- Notorious Thread's Hearthstone
    235016, -- Redeployment Module
    236687, -- Explosive Hearthstone
    245970, -- P.O.S.T Master's Express Hearthstone
    246565, -- Cosmic Hearthstone
    263489, -- Naaru's Enfold
}

local hearthstoneCache = {
    lastScan = 0,
    resolvedID = nil,
}

local toyNameCache = {}

local function HasItemInBags(itemID)
    if not itemID then
        return false
    end
    local count = addon.API.GetItemCount(itemID, false, false, false)
    return (count or 0) > 0
end

local function IsHearthstoneToyItemBySpell(itemID, hearthSpellID)
    if not itemID or not hearthSpellID then
        return false
    end
    local _, spellID = addon.API.GetItemSpell(itemID)
    return spellID == hearthSpellID
end

local function FindHearthstoneToyID()
    -- 1) Prefer known list (fast + reliable)
    for _, toyID in ipairs(KNOWN_HEARTHSTONE_TOYS) do
        if IsToyOwnedAndUsable(toyID) then
            return toyID
        end
    end

    -- 2) Fallback: scan ToyBox for matching spell (not universal)
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

    local name = addon.API.GetItemInfo(itemID)
    if name and name ~= "" then
        toyNameCache[itemID] = name
        return name
    end

    -- Asynchronous load; when ready, refresh the bar (out of combat only).
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
-- Secure attribute guards
-----------------------------------------------------------------------

-- Disables secure actions for non-left buttons and modifier combinations.
-- MUST use false (not nil) to prevent fallback to the generic type attribute.
local function ApplySecureAttributeGuards(btn)
    if InCombatLockdown() then
        return
    end

    -- Disable non-left mouse buttons
    btn:SetAttribute("type2", false)      -- Right button
    btn:SetAttribute("type3", false)      -- Middle button
    btn:SetAttribute("type4", false)      -- Extra button 1
    btn:SetAttribute("type5", false)      -- Extra button 2

    -- Disable Shift + all buttons
    btn:SetAttribute("shift-type", false)
    btn:SetAttribute("shift-type1", false) -- Shift+Left
    btn:SetAttribute("shift-type2", false) -- Shift+Right (critical for removal)
    btn:SetAttribute("shift-type3", false) -- Shift+Middle
    btn:SetAttribute("shift-type4", false)
    btn:SetAttribute("shift-type5", false)

    -- Disable Ctrl + all buttons
    btn:SetAttribute("ctrl-type", false)
    btn:SetAttribute("ctrl-type1", false)  -- Ctrl+Left
    btn:SetAttribute("ctrl-type2", false)  -- Ctrl+Right
    btn:SetAttribute("ctrl-type3", false)  -- Ctrl+Middle
    btn:SetAttribute("ctrl-type4", false)
    btn:SetAttribute("ctrl-type5", false)

    -- Disable Alt + all buttons
    btn:SetAttribute("alt-type", false)
    btn:SetAttribute("alt-type1", false)   -- Alt+Left
    btn:SetAttribute("alt-type2", false)   -- Alt+Right
    btn:SetAttribute("alt-type3", false)   -- Alt+Middle
    btn:SetAttribute("alt-type4", false)
    btn:SetAttribute("alt-type5", false)
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

    -- Desaturation overlay (grey out unavailable buttons)
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

    -- IMPORTANT: Toys are much more reliable when the secure click is processed on mouse down.
    btn:RegisterForClicks("AnyDown")
    if not InCombatLockdown() then
        btn:SetAttribute("pressAndHoldAction", true)
    end

    -- Apply initial secure attribute guards
    ApplySecureAttributeGuards(btn)

    btn:SetScript("OnEnter", function(selfBtn)
        local title = selfBtn.tooltipTitle or selfBtn.tooltip
        if not title then
            return
        end

        GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
        GameTooltip:SetText("|cffffd100" .. title .. "|r", 1, 1, 1, 1, true)

        if selfBtn.tooltipSubtext then
            GameTooltip:AddLine("|cffd0d0d0" .. selfBtn.tooltipSubtext .. "|r", 1, 1, 1, true)
        end
        
        -- Show unavailability reason if present (keep red as it's a warning)
        if selfBtn.unavailableReason then
            GameTooltip:AddLine(" ", 1, 1, 1)
            GameTooltip:AddLine("|cffff4040Not Available:|r " .. selfBtn.unavailableReason, 1, 0.5, 0.5, true)
        end

        GameTooltip:AddLine("|cffd0d0d0Shift+Right-Click to remove|r", 1, 1, 1, true)
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    btn:SetScript("OnMouseUp", function(selfBtn, mouseButton)
        if mouseButton == "RightButton" and IsShiftKeyDown() then
            -- Prevent secure frame modification during combat
            if InCombatLockdown() then
                print("|cff00ff00Goblin Toolbox:|r Cannot modify Utility Bar during combat")
                return
            end

            -- Handle custom button removal
            if selfBtn.isCustomSlot and selfBtn.customIndex then
                if addon.db and addon.db.profile and addon.db.profile.customUtilitySlots then
                    table.remove(addon.db.profile.customUtilitySlots, selfBtn.customIndex)
                    print("|cff00ff00Goblin Toolbox:|r Removed custom button")
                    addon:UpdateUtilityBar()
                end
                return
            end

            -- Handle standard button removal
            if selfBtn.utilityKey and addon.db and addon.db.profile and addon.db.profile.utilityButtons then
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
    btn.itemName = nil
    btn.spellKey = nil
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
    if not btn then
        return 0, 0, 0
    end

    -- Custom buttons may not have utilDef but can have cooldown info
    if btn.cooldownSpellID then
        return GetSpellCooldownCompat(btn.cooldownSpellID)
    end

    -- Custom toys
    if btn.isCustomSlot and btn.customKind == "toy" and btn.itemID then
        -- Try C_Container.GetItemCooldown first (works for toys)
        if C_Container and C_Container.GetItemCooldown then
            local start, duration, enabled = C_Container.GetItemCooldown(btn.itemID)
            if start and duration then
                return start, duration, NormalizeEnabled(enabled)
            end
        end

        -- Fallback to C_Item
        if C_Item and C_Item.GetItemCooldown then
            local start, duration, enabled = C_Item.GetItemCooldown(btn.itemID)
            return start or 0, duration or 0, NormalizeEnabled(enabled)
        end

        return 0, 0, 0
    end

    -- Standard utility buttons need utilDef
    if not btn.utilDef then
        return 0, 0, 0
    end

    local def = btn.utilDef

    if def.kind == "spell" or def.kind == "mount" then
        local spellID = def.spellID
        if not spellID then
            return 0, 0, 0
        end
        return GetSpellCooldownCompat(spellID)
    end

    if def.kind == "housing" then
        -- No cooldown display in return mode
        if btn.housingReturnMode then
            return 0, 0, 0
        end
        local spellID = def.cooldownSpellID
        if spellID then
            return GetSpellCooldownCompat(spellID)
        end
        return 0, 0, 0
    end

    if def.kind == "item" then
        local itemID = btn.itemID
        if not itemID then
            return 0, 0, 0
        end

        if PlayerHasToy and PlayerHasToy(itemID) and C_ToyBox and C_ToyBox.GetToyCooldown then
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
    if not btn or not btn.cooldown then
        return
    end

    -- Custom buttons don't have utilDef but may have cooldown info
    if not btn.utilDef and not btn.isCustomSlot then
        return
    end

    local start, duration, enabled = GetCooldownForUtilityButton(btn)

    -- Filter out short cooldowns during combat for hearthstone-type items
    -- (prevents spurious GCD swirlies from appearing on hearthstone icons)
    local def = btn.utilDef
    local minDuration = 1.5
    if def and InCombatLockdown() and def.kind == "item" then
        local isHearthstoneType = (def.key == "hearthstone" or def.key == "dalaranHS" or def.key == "garrisonHS")
        if isHearthstoneType then
            minDuration = 3.0  -- Require at least 3s cooldown during combat to filter out GCD noise
        end
    end

    local valid = (enabled == 1 and start > 0 and duration and duration > minDuration)

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

local function IsProfessionSpell(spellID)
    -- Check if this spell ID corresponds to a profession the player knows.
    -- Returns: isProfession, professionName, baseSkillLineID
    if not spellID or not C_TradeSkillUI then
        return false, nil, nil
    end

    -- Resolve the spell name to match against profession names
    local spellInfo = C_Spell.GetSpellInfo(spellID)
    if not spellInfo or not spellInfo.name then
        return false, nil, nil
    end
    local spellName = spellInfo.name

    -- Check against the player's known professions
    local tradeSkillLines = C_TradeSkillUI.GetAllProfessionTradeSkillLines()
    if tradeSkillLines then
        for _, skillLineID in ipairs(tradeSkillLines) do
            local profInfo = C_TradeSkillUI.GetProfessionInfoBySkillLineID(skillLineID)
            if profInfo and profInfo.professionName then
                -- Match if spell name equals or contains the profession name
                -- (handles expansion-prefixed names like "Khaz Algar Leatherworking")
                -- Match against both expansion name ("Midnight Enchanting") and
                -- parent name ("Enchanting") for reliable detection
                local profName = profInfo.parentProfessionName or profInfo.professionName
                if spellName == profName
                    or spellName:find(profName, 1, true)
                    or profName:find(spellName, 1, true) then
                    -- parentProfessionID is the base skill line ID (e.g., 333 for
                    -- Enchanting, 165 for Leatherworking) that OpenTradeSkill() expects
                    local baseSkillLineID = profInfo.parentProfessionID or skillLineID
                    return true, profName, baseSkillLineID
                end
            end
        end
    end

    return false, nil, nil
end

local function ConfigureCustomButton(btn, kind, id, index)
    -- Clear standard utility properties
    btn.utilDef = nil
    btn.itemID = nil
    btn.itemName = nil
    btn.spellKey = nil
    btn.utilityKey = nil
    btn.unavailableReason = nil
    btn.cooldownSpellID = nil

    -- Clear kind-specific properties from previous custom configuration
    -- (critical when buttons are reused between different custom types)
    btn.isProfession = nil
    btn.professionName = nil
    btn.professionSkillLineID = nil
    btn.mountJournalID = nil
    btn.petSpeciesID = nil

    -- Clear stale typerelease from previous button configuration to prevent
    -- double-fire (action on press + duplicate action on release) which causes
    -- toggle spells (professions, racials) to open then immediately close.
    if not InCombatLockdown() then
        btn:SetAttribute("typerelease", nil)
    end

    local icon, name

    if kind == "spell" then
        local info = C_Spell.GetSpellInfo(id)
        name = info and info.name or "Spell " .. id
        icon = info and info.iconID or GetSpellTexture(id) or "Interface\\Icons\\INV_Misc_QuestionMark"

        -- Check if this is a profession spell
        local isProfession, professionName, skillLineID = IsProfessionSpell(id)

        if isProfession and professionName and skillLineID then
            -- Use C_TradeSkillUI.OpenTradeSkill(baseSkillLineID) via /run macro.
            -- /cast doesn't work for all professions (e.g., Leatherworking, Inscription).
            -- Uses same proven /run macro pattern as resetInstances and housingTeleport.
            if not InCombatLockdown() then
                btn:SetAttribute("type", "macro")
                btn:SetAttribute("macrotext", "/run C_TradeSkillUI.OpenTradeSkill(" .. skillLineID .. ")")
                btn:SetAttribute("spell", nil)
                btn:SetAttribute("toy", nil)
                btn:SetAttribute("item", nil)
                btn:SetAttribute("mount", nil)
            end
            btn.isProfession = true
            btn.professionName = professionName
            btn.professionSkillLineID = skillLineID
        else
            -- Regular spell (no typerelease - prevents double-fire on toggle spells)
            if not InCombatLockdown() then
                btn:SetAttribute("type", "spell")
                btn:SetAttribute("spell", name)
                btn:SetAttribute("toy", nil)
                btn:SetAttribute("item", nil)
                btn:SetAttribute("mount", nil)
            end
            btn.cooldownSpellID = id
        end

    elseif kind == "toy" then
        local _, toyName, toyIcon = C_ToyBox.GetToyInfo(id)
        name = toyName or "Toy " .. id
        icon = toyIcon or "Interface\\Icons\\INV_Misc_QuestionMark"

        if not InCombatLockdown() then
            btn:SetAttribute("type", "toy")
            btn:SetAttribute("toy", id)
            btn:SetAttribute("spell", nil)
            btn:SetAttribute("item", nil)
            btn:SetAttribute("mount", nil)
        end

        btn.itemID = id

    elseif kind == "mount" then
        -- Mount links contain spell IDs, not mount journal IDs
        -- Need to convert: spell ID -> mount journal ID -> mount info
        local mountJournalID = nil
        local mountName, mountSpellID, mountIcon = nil, nil, nil

        if C_MountJournal and C_MountJournal.GetMountFromSpell then
            mountJournalID = C_MountJournal.GetMountFromSpell(id)
        end

        if mountJournalID and C_MountJournal.GetMountInfoByID then
            mountName, mountSpellID, mountIcon = C_MountJournal.GetMountInfoByID(mountJournalID)
        end

        name = mountName or "Mount " .. id
        icon = mountIcon or "Interface\\Icons\\INV_Misc_QuestionMark"

        if mountName and not InCombatLockdown() then
            btn:SetAttribute("type", "spell")
            btn:SetAttribute("spell", mountName)
            btn:SetAttribute("toy", nil)
            btn:SetAttribute("item", nil)
            btn:SetAttribute("mount", nil)
        end

        btn.spellKey = mountName
        btn.cooldownSpellID = mountSpellID or id  -- Use mount's spell ID if available, else original ID
        btn.mountJournalID = mountJournalID  -- Store for availability check

    elseif kind == "pet" then
        -- Battle pet handling - id is species ID
        local petName, petIcon = C_PetJournal.GetPetInfoBySpeciesID(id)
        name = petName or "Pet " .. id
        icon = petIcon or "Interface\\Icons\\INV_Misc_QuestionMark"

        -- Pets are summoned via macro that calls the pet by name
        if petName and not InCombatLockdown() then
            local macroText = "/summonpet " .. petName
            btn:SetAttribute("type", "macro")
            btn:SetAttribute("macrotext", macroText)
            btn:SetAttribute("toy", nil)
            btn:SetAttribute("item", nil)
            btn:SetAttribute("spell", nil)
            btn:SetAttribute("mount", nil)
        end

        btn.petSpeciesID = id  -- Store for availability check
    end

    btn.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    btn.customName = name or "Custom Button"
    btn.tooltipTitle = name or "Custom Button"

    -- Set appropriate subtext
    if btn.isProfession then
        btn.tooltipSubtext = "Profession"
    else
        btn.tooltipSubtext = "Custom " .. kind
    end

    btn.tooltip = nil

    -- Availability checks and grey-out for custom buttons
    local isAvailable = true
    local unavailableReason = nil

    if kind == "spell" then
        -- Use IsPlayerSpell for both profession and regular spells.
        -- GetAllProfessionTradeSkillLines() returns ALL skill lines in the game,
        -- so IsProfessionSpell matching doesn't guarantee the character has it.
        if not IsSpellKnown(id) and not IsPlayerSpell(id) then
            isAvailable = false
            unavailableReason = btn.isProfession and "Profession not learned" or "Spell not known"
        end
    elseif kind == "toy" then
        if not PlayerHasToy(id) then
            isAvailable = false
            unavailableReason = "Toy not owned"
        end
    elseif kind == "mount" then
        -- Check if mount is collected using the mount journal ID
        if btn.mountJournalID then
            local _, _, _, _, _, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(btn.mountJournalID)
            if not isCollected then
                isAvailable = false
                unavailableReason = "Mount not collected"
            end
        else
            -- Couldn't find mount in journal
            isAvailable = false
            unavailableReason = "Mount not found"
        end
    elseif kind == "pet" then
        -- Check if player owns this pet species (filter-independent check)
        local ownsSpecies = false
        if btn.petSpeciesID and C_PetJournal then
            -- Use C_PetJournal.GetOwnedBattlePetString which is filter-independent
            -- Returns a string like "1:2:1" indicating owned pet counts, or nil if not owned
            local ownedString = C_PetJournal.GetOwnedBattlePetString(btn.petSpeciesID)
            ownsSpecies = (ownedString ~= nil)
        end

        if not ownsSpecies then
            isAvailable = false
            unavailableReason = "Pet not owned"
        end
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

    ApplySecureAttributeGuards(btn)
    UpdateUtilityButtonCooldown(btn)
end

local function SetupUtilityButton(btn, def, resolvedItemID)
    btn.utilDef = def
    btn.itemID = nil
    btn.itemName = nil
    btn.spellKey = nil
    btn.utilityKey = def.key
    btn.unavailableReason = nil
    btn.cooldownSpellID = nil

    -- Clear custom button properties (important when reusing buttons)
    btn.isCustomSlot = nil
    btn.customIndex = nil
    btn.customKind = nil
    btn.customID = nil

    -- Check availability for this button type
    local checkFunc = AVAILABILITY_CHECKS[def.key]
    local isAvailable = true
    local unavailableReason = nil
    
    if def.kind == "dynamicSpell" then
        local effectiveSpellID, iconTexture, spellName, isSpellAvailable, reason = ResolveClassQuickTravel()
        
        isAvailable = isSpellAvailable
        unavailableReason = reason
        
        if isAvailable then
            if not InCombatLockdown() then
                btn:SetAttribute("type", "spell")
                btn:SetAttribute("typerelease", "spell")
                btn:SetAttribute("spell", spellName)
                btn:SetAttribute("toy", nil)
                btn:SetAttribute("item", nil)
            end
            btn.spellKey = spellName
            btn.cooldownSpellID = effectiveSpellID
        else
            if not InCombatLockdown() then
                btn:SetAttribute("type", nil)
                btn:SetAttribute("typerelease", nil)
                btn:SetAttribute("spell", nil)
                btn:SetAttribute("toy", nil)
                btn:SetAttribute("item", nil)
            end
            btn.cooldownSpellID = nil
        end
        
        btn.icon:SetTexture(iconTexture)
        btn.tooltipTitle = "Class Travel"
        btn.tooltipSubtext = spellName
        
        -- Apply visuals
        if isAvailable then
            btn.icon:SetDesaturated(false)
            if btn.overlay then btn.overlay:Hide() end
        else
            btn.icon:SetDesaturated(true)
            if btn.overlay then btn.overlay:Show() end
        end
        btn.unavailableReason = unavailableReason

        ApplySecureAttributeGuards(btn)
        UpdateUtilityButtonCooldown(btn)
        return -- Handled completely by dynamicSpell branch
    end
    
    if checkFunc then
        isAvailable, unavailableReason = checkFunc()
    end
    
    -- Update desaturation overlay
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

    if def.kind == "mount" then
        -- Mount-specific path: use Mount Journal as source of truth
        local spellID = resolvedItemID or def.spellID  -- resolvedItemID repurposed for mount spellID

        if spellID and C_MountJournal and C_MountJournal.GetMountFromSpell and C_MountJournal.GetMountInfoByID then
            local mountID = C_MountJournal.GetMountFromSpell(spellID)
            if mountID then
                local mountName, mountSpellID, mountIcon = C_MountJournal.GetMountInfoByID(mountID)

                if mountName and mountIcon then
                    if not InCombatLockdown() then
                        btn:SetAttribute("type", "spell")
                        btn:SetAttribute("typerelease", "spell")
                        btn:SetAttribute("spell", mountName)  -- Use localized mount name
                        btn:SetAttribute("toy", nil)
                        btn:SetAttribute("item", nil)
                    end

                    btn.spellKey = mountName
                    icon = mountIcon  -- Use icon from Mount Journal
                    tip = mountName or def.label or "Mount"
                end
            end
        end

        -- Fallback if Mount Journal fails
        if not icon then
            icon = "Interface\\Icons\\INV_Misc_QuestionMark"
            tip = def.label or "Mount"
        end

    elseif def.kind == "macro" then
        -- Macro button: executes macro text
        if def.macroText and not InCombatLockdown() then
            btn:SetAttribute("type", "macro")
            btn:SetAttribute("macrotext", def.macroText)
            btn:SetAttribute("toy", nil)
            btn:SetAttribute("item", nil)
            btn:SetAttribute("spell", nil)
        end

        icon = def.iconTexture or "Interface\\Icons\\INV_Misc_QuestionMark"
        tip = def.label or "Macro"

    elseif def.kind == "housing" then
        -- Housing button: dual-mode (teleport home / return from housing)
        local returnMode = addon:IsInHousingZone()
        if not InCombatLockdown() then
            btn:SetAttribute("type", "macro")
            if returnMode then
                btn:SetAttribute("macrotext", "/click GTB_HousingReturn")
            else
                btn:SetAttribute("macrotext", "/click GTB_HousingTeleport")
            end
            btn:SetAttribute("toy", nil)
            btn:SetAttribute("item", nil)
            btn:SetAttribute("spell", nil)
        end

        btn.housingReturnMode = returnMode
        if returnMode then
            icon = nil  -- Will use atlas below
            tip = "Return to Previous Location"
        else
            icon = def.iconTexture or 7252953  -- Ui_homestone-64
            tip = "Teleport Home"
        end

    elseif def.kind == "spell" then
        local spellName = addon.API.GetSpellName(def.spellID)
        local key = spellName or def.spellID

        if not InCombatLockdown() then
            btn:SetAttribute("type", "spell")
            btn:SetAttribute("typerelease", "spell")
            btn:SetAttribute("spell", key)
            btn:SetAttribute("toy", nil)
            btn:SetAttribute("item", nil)
        end

        btn.spellKey = key
        icon = GetUtilityIcon(def)
        tip = spellName or def.label or "Spell"

    elseif def.kind == "item" then
        local itemID = resolvedItemID or def.itemID
        btn.itemID = itemID

        local isToy = (itemID and PlayerHasToy and PlayerHasToy(itemID)) or false

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
                -- For physical items, must use item name (not ID)
                local itemName = addon.API.GetItemInfo(itemID)
                if itemName then
                    btn:SetAttribute("type", "item")
                    btn:SetAttribute("typerelease", "item")
                    btn:SetAttribute("item", itemName)
                    btn:SetAttribute("toy", nil)
                end
            end
        end

        icon = GetUtilityIcon(def, itemID)

        if isToy then
            local name = GetToyNameCached(itemID)
            tip = name or def.label or "Toy"
        else
            local name = nil
            if itemID then
                name = addon.API.GetItemInfo(itemID)
                tip = name or def.label or "Item"
            else
                tip = def.label or "Item"
            end
            -- Store item name for secure attribute (needed for physical items)
            btn.itemName = name
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

    -- Only set texture if icon is provided (nil means atlas was already set, e.g., housing return mode)
    if icon then
        btn.icon:SetTexture(icon)
    elseif icon == false then
        -- Explicitly set fallback
        btn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end
    -- Housing return mode: distinct icon (Spell_Dalaran_Teleport - man with flag)
    if btn.housingReturnMode then
        btn.icon:SetTexture(236350)
    end
    btn.tooltip = nil
    btn.tooltipTitle = nil
    btn.tooltipSubtext = nil

    -- Tooltip UX: special handling for certain button types
    if def.key == "tradersBrutosaur" then
        btn.tooltipTitle = "Auction House"
        btn.tooltipSubtext = tip  -- Mount name
    elseif def.key == "vendorMount" then
        btn.tooltipTitle = "Vendor Mount"
        btn.tooltipSubtext = tip  -- Resolved mount name
    elseif def.key == "housingTeleport" then
        if addon:IsInHousingZone() then
            btn.tooltipTitle = "Housing"
            btn.tooltipSubtext = "Return to Previous Location"
        else
            btn.tooltipTitle = "Housing"
            btn.tooltipSubtext = "Teleport Home"
        end
    elseif def.key == "hearthstone" then
        btn.tooltipTitle = "Hearthstone"
        local bindLoc = GetBindLocation()
        if bindLoc and bindLoc ~= "" then
            btn.tooltipSubtext = "Returns you to " .. bindLoc
        elseif btn.itemID == 6948 then
            btn.tooltipSubtext = "Uses Hearthstone"
        else
            btn.tooltipSubtext = "Uses an available Hearthstone toy"
        end
    else
        btn.tooltip = tip
    end

    -----------------------------------------------------------------------
    -- Confirmation logic for sensitive actions (ONLY when enabled)
    -- When confirmation is OFF, we do nothing here - buttons work normally
    -- via their secure attributes set earlier in this function.
    -----------------------------------------------------------------------
    local db = addon.db and addon.db.profile
    local confirmEnabled = db and db.utilityConfirmSensitiveActions
    local isSensitive = (def.key == "logout" or def.key == "reload" or def.key == "mailbox")

    if confirmEnabled and isSensitive and not InCombatLockdown() then
        -- Confirmation is ON: clear secure attributes and use OnClick handler instead
        btn:SetAttribute("type", nil)
        btn:SetAttribute("typerelease", nil)
        btn:SetAttribute("macrotext", nil)
        btn:SetAttribute("item", nil)
        btn:SetAttribute("toy", nil)
        btn:SetAttribute("spell", nil)

        btn:SetScript("OnClick", function(self, button)
            if button ~= "LeftButton" then return end
            if IsShiftKeyDown() then return end
            if self.unavailableReason then return end
            if InCombatLockdown() then
                print("Cannot do that in combat.")
                return
            end

            if def.key == "logout" then
                GetLogoutConfirmFrame():Show()
            elseif def.key == "reload" then
                GetReloadConfirmFrame():Show()
            elseif def.key == "mailbox" and self.itemID then
                local isToy = (PlayerHasToy and PlayerHasToy(self.itemID)) or false
                local itemName = self.itemName or addon.API.GetItemInfo(self.itemID)
                local confirmFrame = GetMailboxConfirmFrame()

                if not InCombatLockdown() then
                    confirmFrame.yesBtn:SetAttribute("type", nil)
                    confirmFrame.yesBtn:SetAttribute("toy", nil)
                    confirmFrame.yesBtn:SetAttribute("item", nil)

                    if isToy then
                        confirmFrame.yesBtn:SetAttribute("type", "toy")
                        confirmFrame.yesBtn:SetAttribute("toy", self.itemID)
                    elseif itemName then
                        confirmFrame.yesBtn:SetAttribute("type", "item")
                        confirmFrame.yesBtn:SetAttribute("item", itemName)
                    else
                        print("Error: Mailbox item name not found")
                        return
                    end
                    confirmFrame:Show()
                else
                    print("Cannot configure mailbox confirmation in combat.")
                end
            end
        end)
    end
    -- When confirmation is OFF (or button is not sensitive): do nothing here.
    -- The secure attributes were already set correctly by the kind-specific code above.

    -- Apply secure attribute guards to prevent accidental activation with modifiers/non-left-clicks
    ApplySecureAttributeGuards(btn)

    UpdateUtilityButtonCooldown(btn)
end

-----------------------------------------------------------------------
-- Position persistence (minimal, stable)
-----------------------------------------------------------------------

addon._utilityMovedThisSession = false

local function SaveUtilityBarPosition()
    local db = addon.db and addon.db.profile
    local anchor = addon.utilityAnchor
    if not db or not anchor then return end

    local point, _, relPoint, xOfs, yOfs = anchor:GetPoint(1)
    if not point then return end

    db.utilityBarPos = db.utilityBarPos or {}
    db.utilityBarPos.point = point
    db.utilityBarPos.relPoint = relPoint
    db.utilityBarPos.x = xOfs
    db.utilityBarPos.y = yOfs
end

local function Utility_DeferredApply()
    local db = addon.db and addon.db.profile
    local anchor = addon.utilityAnchor
    local bar = addon.utilityBar
    if not db or not anchor or not bar then return end

    local pos = db.utilityBarPos
    if pos and pos.point and pos.relPoint and pos.x and pos.y and not addon._utilityMovedThisSession then
        anchor:ClearAllPoints()
        anchor:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)

        -- Anchor visual frame to anchor container at growth corner
        local growX = db.utilityGrowX or "RIGHT"
        local growY = db.utilityGrowY or "DOWN"
        local visualAnchor = addon:GetAnchorFromGrowth(growX, growY)
        bar:ClearAllPoints()
        bar:SetPoint(visualAnchor, anchor, visualAnchor, 0, 0)
    end
end

function addon:RestoreUtilityBarPosition()
    local anchor = self.utilityAnchor
    local bar = self.utilityBar
    if not anchor or not bar then return end

    local db = self.db.profile
    local pos = db.utilityBarPos
    if pos and pos.point and pos.relPoint and pos.x and pos.y then
        anchor:ClearAllPoints()
        anchor:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        -- No saved position, use fixed default (no auto-snapping)
        anchor:ClearAllPoints()
        anchor:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10, -420)
    end

    -- Anchor visual frame to anchor container at growth corner
    local growX = db.utilityGrowX or "RIGHT"
    local growY = db.utilityGrowY or "DOWN"
    local visualAnchor = addon:GetAnchorFromGrowth(growX, growY)
    bar:ClearAllPoints()
    bar:SetPoint(visualAnchor, anchor, visualAnchor, 0, 0)

    -- Initialize anchor cache to prevent unnecessary re-anchoring
    bar._gtbLastDesiredAnchor = visualAnchor
end

-- Public API: Save utility bar position on logout
-- Exposes the local SaveUtilityBarPosition() for PLAYER_LOGOUT handler
function addon:SaveUtilityBarPositionOnLogout()
    SaveUtilityBarPosition()
end

-----------------------------------------------------------------------
-- Utility bar creation
-----------------------------------------------------------------------

function addon:CreateUtilityBar()
    if self.utilityBar then
        return
    end

    -- Create unscaled anchor frame (position container)
    local anchor = CreateFrame("Frame", "GoblinToolboxUtilityAnchor", UIParent)
    self.utilityAnchor = anchor
    anchor:SetSize(1, 1)
    anchor:SetMovable(true)
    anchor:SetClampedToScreen(true)
    -- Never scale the anchor

    -- Create scaled visual frame (content container)
    local f = CreateFrame("Frame", "GoblinToolboxUtilityBar", anchor, "BackdropTemplate")
    self.utilityBar = f

    f:SetSize(200, 34)
    f:SetFrameStrata("MEDIUM")  -- Same as Blizzard action bars, won't block quest dialogs
    -- Don't clamp visual frame - anchor handles clamping
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")

    f:SetScript("OnDragStart", function(frame)
        if addon.db and addon.db.profile and addon.db.profile.lockFrame then
            return
        end
        -- Move the anchor, not the visual frame
        anchor:StartMoving()
    end)

    f:SetScript("OnDragStop", function(frame)
        -- Stop moving the anchor
        anchor:StopMovingOrSizing()
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

    -- Default position: fixed position below HUD default area (no auto-snapping)
    anchor:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10, -420)

    -- Anchor visual frame to anchor container at growth corner
    local db = addon.db.profile
    local growX = db.utilityGrowX or "RIGHT"
    local growY = db.utilityGrowY or "DOWN"
    local visualAnchor = addon:GetAnchorFromGrowth(growX, growY)
    f:ClearAllPoints()
    f:SetPoint(visualAnchor, anchor, visualAnchor, 0, 0)

    Utility_DeferredApply()

    f.dragHandle = CreateDragHandle(f)

    f.buttons = {}

    self:UpdateBackground()
end

-----------------------------------------------------------------------
-- Helper to re-anchor frame based on current growth settings
-----------------------------------------------------------------------

local function UpdateAnchorFromGrowth(visualFrame, db)
    local growX = db.utilityGrowX or "RIGHT"
    local growY = db.utilityGrowY or "DOWN"
    local desiredAnchor = addon:GetAnchorFromGrowth(growX, growY)

    -- Only re-anchor if growth settings actually changed
    if visualFrame._gtbLastDesiredAnchor == desiredAnchor then
        return
    end

    -- Growth changed - re-point visual frame to new corner of anchor
    -- No coordinate conversion needed - visual stays at (0,0) relative to anchor
    local anchor = visualFrame:GetParent()
    if anchor then
        visualFrame:ClearAllPoints()
        visualFrame:SetPoint(desiredAnchor, anchor, desiredAnchor, 0, 0)
        visualFrame._gtbLastDesiredAnchor = desiredAnchor
    end
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
        if db.hideWhenGrouped and IsInGroup() then
            hide = true
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
                    SetupUtilityButton(btn, def, spellID)  -- Pass spellID as resolvedItemID
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
                    SetupUtilityButton(btn, def, spellID)  -- Pass resolved spellID
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
                SetupUtilityButton(btn, def, nil)
            end
        end
    end

    -- Custom utility slots (positioned at right end of bar)
    bar.customButtons = bar.customButtons or {}
    local customSlots = db.customUtilitySlots or {}
    local hideCustom = db.hideCustomButtons or false

    if not hideCustom then
        for i, slot in ipairs(customSlots) do
            shown = shown + 1
            local btn = bar.buttons[shown]
            if not btn then
                btn = CreateUtilityButton(bar, shown, size)
                bar.buttons[shown] = btn
            end

            -- Mark as custom button
            btn.isCustomSlot = true
            btn.customIndex = i
            btn.customKind = slot.kind
            btn.customID = slot.id

            -- Configure the button
            ConfigureCustomButton(btn, slot.kind, slot.id, i)

        end
    end

    local hideUnavail = db.hideUnavailableButtons or false

    -- Get growth settings and update anchor if needed
    local growX = db.utilityGrowX or "RIGHT"
    local growY = db.utilityGrowY or "DOWN"
    UpdateAnchorFromGrowth(bar, db)
    local anchorPoint = addon:GetAnchorFromGrowth(growX, growY)

    -- Buttons-per-row setting
    local buttonsPerRow = db.utilityButtonsPerRow or 12

    if shown == 0 then
        self:SetSecureFrameVisible(bar, false)
        return
    end

    -- Count visible buttons (excluding hidden unavailable ones)
    local visible = 0
    for i = 1, shown do
        local btn = bar.buttons[i]
        if btn and not (hideUnavail and btn.unavailableReason) then
            visible = visible + 1
        end
    end

    if visible == 0 then
        self:SetSecureFrameVisible(bar, false)
        return
    end

    -- Grid layout calculation
    local bpr = math.min(buttonsPerRow, visible)  -- Clamp to visible button count
    local cols = math.min(bpr, visible)
    local rows = math.ceil(visible / bpr)

    -- Frame size
    local step = size + spacing
    local width = padding * 2 + (cols * size) + ((cols - 1) * spacing)
    local height = padding * 2 + (rows * size) + ((rows - 1) * spacing)
    bar:SetSize(width, height)

    -- Offset signs based on anchor
    local xSign = (anchorPoint:find("LEFT") and 1) or -1
    local ySign = (anchorPoint:find("TOP") and -1) or 1

    -- Position buttons using grid layout
    local visSlot = 0
    for i = 1, #bar.buttons do
        local btn = bar.buttons[i]
        if btn then
            if i <= shown and not (hideUnavail and btn.unavailableReason) then
                local row = math.floor(visSlot / bpr)
                local col = visSlot % bpr
                local x = xSign * (padding + col * step)
                local y = ySign * (padding + row * step)

                btn:ClearAllPoints()
                btn:SetPoint(anchorPoint, bar, anchorPoint, x, y)
                btn:Show()
                UpdateUtilityButtonCooldown(btn)
                visSlot = visSlot + 1
            else
                btn:Hide()
            end
        end
    end
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
