-- UtilityBar.lua
-- Utility bar: secure action buttons for Mobile Banking, Mailbox, Hearthstones, etc.

local addonName, addon = ...

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
            addon.CONST.ITEMS.MOLL_E,
        },
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
        kind        = "spell",
        spellID     = addon.CONST.SPELLS.HEARTHSTONE,
        spellName   = "Hearthstone",
        iconTexture = "Interface\\Icons\\inv_misc_rune_01",
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

    btn.cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    btn.cooldown:SetAllPoints(true)
    btn.cooldown:SetDrawEdge(true)
    btn.cooldown:SetHideCountdownNumbers(false)
    btn.cooldown:SetFrameLevel(btn:GetFrameLevel() + 1)

    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    btn:RegisterForClicks("AnyUp")

    btn:SetScript("OnEnter", function(selfBtn)
        if not selfBtn.tooltip then
            return
        end
        GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
        GameTooltip:SetText(selfBtn.tooltip, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    btn.utilDef = nil
    btn.itemID = nil
    btn.spellKey = nil
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
        local spellID = def.spellID
        local start, duration, enabled = addon.API.GetSpellCooldown(spellID or btn.spellKey)
        return start, duration, NormalizeEnabled(enabled)
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

            if tStart > 0 and tDur > 0 then
                return tStart, tDur, 1
            end
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

local function SetupUtilityButton(btn, def, resolvedItemID)
    btn.utilDef = def
    btn.itemID = nil
    btn.spellKey = nil

    local icon, tip

    if def.kind == "spell" then
        local spellName = addon.API.GetSpellName(def.spellID)
        if not spellName and def.spellName then
            spellName = def.spellName
        end

        local key = def.spellID or spellName

        -- Secure attributes: only touch them out of combat.
        if not InCombatLockdown() then
            btn:SetAttribute("type", "spell")
            btn:SetAttribute("spell", key)
        end

        btn.spellKey = key
        icon = GetUtilityIcon(def)
        tip = spellName or def.label or "Spell"

    elseif def.kind == "item" then
        local itemID = resolvedItemID or def.itemID
        btn.itemID = itemID

        if not InCombatLockdown() then
            btn:SetAttribute("type", "item")
            if itemID then
                btn:SetAttribute("item", "item:" .. itemID)
            else
                btn:SetAttribute("item", nil)
            end
        end

        icon = GetUtilityIcon(def, itemID)

        if itemID and GetItemInfo then
            local name = GetItemInfo(itemID)
            tip = name or def.label or "Item"
        else
            tip = def.label or "Item"
        end
    else
        if not InCombatLockdown() then
            btn:SetAttribute("type", nil)
        end
        icon = "Interface\\Icons\\INV_Misc_QuestionMark"
        tip = def.label or "Utility"
    end

    btn.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    btn.tooltip = tip

    UpdateUtilityButtonCooldown(btn)
end

-----------------------------------------------------------------------
-- Position persistence
-----------------------------------------------------------------------

addon._utilityMovedThisSession = false

local function Utility_SaveNormalizedCenter()
    if not addon.db or not addon.db.profile or not addon.utilityBar then
        return false
    end

    local db = addon.db.profile

    local w, h = UIParent:GetSize()
    if not w or not h or w <= 0 or h <= 0 then
        return false
    end

    local cx, cy = addon.utilityBar:GetCenter()
    if not cx or not cy then
        return false
    end

    local cxFrac = cx / w
    local cyFrac = cy / h

    -- Sanity gate: accept slight out-of-range due to clamping/scale, but reject extreme values.
    if cxFrac < -0.25 or cxFrac > 1.25 or cyFrac < -0.25 or cyFrac > 1.25 then
        return false
    end

    db.utilityCXFrac = cxFrac
    db.utilityCYFrac = cyFrac
    return true
end

local function SaveUtilityBarPosition()
    if not addon.db or not addon.db.profile or not addon.utilityBar then
        return
    end

    local db = addon.db.profile

    -- Prefer normalized center persistence
    Utility_SaveNormalizedCenter()

    -- Keep legacy point-based values as fallback
    local point, _, relPoint, xOfs, yOfs = addon.utilityBar:GetPoint(1)
    if point and relPoint and xOfs and yOfs then
        db.utilityPoint    = point
        db.utilityRelPoint = relPoint
        db.utilityXOfs     = xOfs
        db.utilityYOfs     = yOfs
    end
end

local function ApplyUtilityBarPosition()
    if not addon.db or not addon.db.profile or not addon.utilityBar then
        return false
    end

    local db = addon.db.profile

    -- Preferred: restore via normalized center coords (resolution/UI scale safe)
    if db.utilityCXFrac and db.utilityCYFrac then
        local w, h = UIParent:GetSize()
        if w and h and w > 0 and h > 0 then
            local cx = db.utilityCXFrac * w
            local cy = db.utilityCYFrac * h

            -- Clamp into UIParent bounds
            if cx < 0 then cx = 0 end
            if cy < 0 then cy = 0 end
            if cx > w then cx = w end
            if cy > h then cy = h end

            addon.utilityBar:ClearAllPoints()
            addon.utilityBar:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx, cy)
            return true
        end
    end

    -- Fallback: legacy anchor tuple
    if db.utilityPoint and db.utilityRelPoint and db.utilityXOfs and db.utilityYOfs then
        addon.utilityBar:ClearAllPoints()
        addon.utilityBar:SetPoint(db.utilityPoint, UIParent, db.utilityRelPoint, db.utilityXOfs, db.utilityYOfs)
        return true
    end

    return false
end

local function Utility_DeferredApply()
    if not addon.utilityBar then
        return
    end

    -- Two-phase apply: UIParent dims can be unstable right after login/loading.
    if C_Timer and C_Timer.After then
        C_Timer.After(0.10, function()
            ApplyUtilityBarPosition()
        end)
        C_Timer.After(0.50, function()
            ApplyUtilityBarPosition()
        end)
    else
        ApplyUtilityBarPosition()
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
        edgeFile = nil,
        tile     = true, tileSize = 16, edgeSize = 0,
        insets   = { left = 0, right = 0, top = 0, bottom = 0 },
    })

    -- Default anchor near HUD or tracker
    if addon.HUD and addon.HUD.frame then
        if addon.trackerFrame then
            f:SetPoint("TOPLEFT", addon.trackerFrame, "BOTTOMLEFT", 0, -8)
        else
            f:SetPoint("TOPLEFT", addon.HUD.frame, "BOTTOMLEFT", 0, -8)
        end
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, -120)
    end

    Utility_DeferredApply()

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

    -- Combat-safe visibility
    self:SetSecureFrameVisible(bar, not hide)

    -- If hidden, do not rebuild buttons.
    if hide then
        return
    end

    -- In combat: do not change secure attributes or rebuild.
    if InCombatLockdown() then
        self._needsUtilityRefresh = true
        return
    end

    bar.buttons = bar.buttons or {}

    local size = addon.CONST.BUTTON_SIZE
    local spacing = addon.CONST.BUTTON_SPACING
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

-----------------------------------------------------------------------
-- Save position on logout
-----------------------------------------------------------------------

function addon:SaveUtilityBarPositionOnLogout()
    if self._utilityMovedThisSession then
        SaveUtilityBarPosition()
    end
end
