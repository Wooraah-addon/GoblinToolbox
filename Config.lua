-- Config.lua
-- Configuration panel for /gtb command

local addonName, addon = ...

-----------------------------------------------------------------------
-- Config frame state
-----------------------------------------------------------------------

local configFrame
local OPT_TITLE_FONT, OPT_BODY_FONT

-----------------------------------------------------------------------
-- TSM source options
-----------------------------------------------------------------------

local tsmSourceList = {
    { value = "dbmarket",          text = "dbmarket" },
    { value = "dbregionmarketavg", text = "dbregionmarketavg" },
    { value = "dbregionsaleavg",   text = "dbregionsaleavg" },
    { value = "dbrecent",          text = "dbrecent" },
    { value = "custom",            text = "Custom (below)" },
}

-----------------------------------------------------------------------
-- Font setup
-----------------------------------------------------------------------

local function EnsureOptionFonts()
    if OPT_TITLE_FONT and OPT_BODY_FONT then
        return
    end

    OPT_TITLE_FONT = CreateFont("GoblinToolboxOptTitle")
    OPT_TITLE_FONT:SetFont("Fonts\\ARIALN.TTF", 16, "OUTLINE")
    OPT_TITLE_FONT:SetTextColor(0.97, 0.86, 0.29)

    OPT_BODY_FONT = CreateFont("GoblinToolboxOptBody")
    OPT_BODY_FONT:SetFont("Fonts\\ARIALN.TTF", 13, "")
    OPT_BODY_FONT:SetTextColor(0.9, 0.9, 0.9)
end

-----------------------------------------------------------------------
-- Config frame creation
-----------------------------------------------------------------------

local function CreateConfigFrame()
    if configFrame then
        return
    end

    EnsureOptionFonts()

    local f = CreateFrame("Frame", "GoblinToolboxConfig", UIParent, "BackdropTemplate")
    configFrame = f

    f:SetSize(440, 580)
    f:SetPoint("CENTER")
    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile     = true, tileSize = 16, edgeSize = 1,
        insets   = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    f:SetBackdropColor(0, 0, 0, 0.9)
    f:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()

    -- Title
    local title = f:CreateFontString(nil, "OVERLAY")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetFontObject(OPT_TITLE_FONT)
    title:SetText("Goblin Toolbox")

    -- Subtitle
    local sub = f:CreateFontString(nil, "OVERLAY")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    sub:SetFontObject(OPT_BODY_FONT)
    sub:SetText("A Lightweight goldmaking HUD")

    -- Close button
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, -2)

    -- Helper: create checkbox
    local function CreateCheck(label, x, y)
        local cb = CreateFrame("CheckButton", nil, f, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", x, y)
        cb.Text:SetFontObject(OPT_BODY_FONT)
        cb.Text:SetText(label)
        return cb
    end

    local y = -70

    -- General options
    f.enableCB     = CreateCheck("Enable HUD", 16, y);              y = y - 24
    f.hideCombatCB = CreateCheck("Hide in combat", 16, y);          y = y - 24
    f.hideInstCB   = CreateCheck("Hide in instances", 16, y);       y = y - 24
    f.headerCB     = CreateCheck("Show group headers", 16, y);      y = y - 24
    f.titlebarCB   = CreateCheck("Show title bar", 16, y);          y = y - 24
    f.bgCB         = CreateCheck("Show background", 16, y);         y = y - 28
    f.wbBankDefaultCB = CreateCheck("Prefer Warband Bank when visiting bankers", 16, y)
    y = y - 28

    -- TSM source dropdown
    local tsmLabel = f:CreateFontString(nil, "OVERLAY")
    tsmLabel:SetPoint("TOPLEFT", 16, y)
    tsmLabel:SetFontObject(OPT_BODY_FONT)
    tsmLabel:SetText("Bag value source (TSM)")
    y = y - 20

    f.tsmDropdown = CreateFrame("Frame", "GoblinToolboxTSMDropdown", f, "UIDropDownMenuTemplate")
    f.tsmDropdown:SetPoint("TOPLEFT", 8, y)
    UIDropDownMenu_SetWidth(f.tsmDropdown, 220)

    UIDropDownMenu_Initialize(f.tsmDropdown, function(self, level)
        local info
        local current = addon.db.profile.tsmSource or "dbmarket"
        for _, entry in ipairs(tsmSourceList) do
            info = UIDropDownMenu_CreateInfo()
            info.text = entry.text
            info.arg1 = entry.value

            info.func = function(_, value)
                addon.db.profile.tsmSource = value
                UIDropDownMenu_SetText(f.tsmDropdown, entry.text)
                addon:UpdateInventorySection()
                addon:LayoutHUD()
                addon:QueueBagValueRecalc()
            end

            info.checked = (current == entry.value)
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    y = y - 40

    -- Custom TSM source input
    f.customLabel = f:CreateFontString(nil, "OVERLAY")
    f.customLabel:SetPoint("TOPLEFT", 16, y)
    f.customLabel:SetFontObject(OPT_BODY_FONT)
    f.customLabel:SetText("Custom TSM source")

    f.customEdit = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    f.customEdit:SetPoint("TOPLEFT", f.customLabel, "BOTTOMLEFT", 0, -4)
    f.customEdit:SetSize(240, 20)
    f.customEdit:SetAutoFocus(false)
    f.customEdit:SetFontObject(OPT_BODY_FONT)

    y = y - 50

    -- Modules section
    local modLabel = f:CreateFontString(nil, "OVERLAY")
    modLabel:SetPoint("TOPLEFT", 16, y)
    modLabel:SetFontObject(OPT_BODY_FONT)
    modLabel:SetText("Modules")
    y = y - 24

    f.charCB    = CreateCheck("Character line", 32, y);             y = y - 24
    f.goldCB    = CreateCheck("Gold & Economy", 32, y);             y = y - 24
    f.invCB     = CreateCheck("Inventory & Currency", 32, y);       y = y - 24
    f.profCB    = CreateCheck("Professions", 32, y);                y = y - 24
    f.utilCB    = CreateCheck("Utility Bar", 32, y);                y = y - 28

    -- Bars section
    local barLabel = f:CreateFontString(nil, "OVERLAY")
    barLabel:SetPoint("TOPLEFT", 16, y)
    barLabel:SetFontObject(OPT_BODY_FONT)
    barLabel:SetText("Tracker Bars")
    y = y - 24

    f.trackerCB  = CreateCheck("Item Tracker Bar", 32, y);          y = y - 24
    f.currencyCB = CreateCheck("Currency Tracker Bar", 32, y);      y = y - 24

    -----------------------------------------------------------------------
    -- Refresh function (populate checkboxes from saved settings)
    -----------------------------------------------------------------------

    local function Refresh()
        local db = addon.db.profile

        f.enableCB:SetChecked(db.enabled)
        f.hideCombatCB:SetChecked(db.hideInCombat)
        f.hideInstCB:SetChecked(db.hideInInstances)
        f.headerCB:SetChecked(db.showHeaders)
        f.titlebarCB:SetChecked(db.showTitleBar)
        f.bgCB:SetChecked(db.showBackground)
        f.wbBankDefaultCB:SetChecked(db.preferWarbandBankOnOpen)

        f.customEdit:SetText(db.tsmCustomSource or "")

        local srcText = db.tsmSource or "dbmarket"
        for _, entry in ipairs(tsmSourceList) do
            if entry.value == srcText then
                srcText = entry.text
                break
            end
        end
        UIDropDownMenu_SetText(f.tsmDropdown, srcText)

        f.charCB:SetChecked(db.modules.Character ~= false)
        f.goldCB:SetChecked(db.modules.Gold ~= false)
        f.invCB:SetChecked(db.modules.Inventory ~= false)
        f.profCB:SetChecked(db.modules.Professions ~= false)
        f.utilCB:SetChecked(db.modules.Utility ~= false)

        f.trackerCB:SetChecked(db.showTracker ~= false)
        f.currencyCB:SetChecked(db.showCurrencyTracker ~= false)
    end

    -----------------------------------------------------------------------
    -- Apply function (save checkboxes to settings and update UI)
    -----------------------------------------------------------------------

    local function Apply()
        local db = addon.db.profile

        db.enabled           = f.enableCB:GetChecked()
        db.hideInCombat      = f.hideCombatCB:GetChecked()
        db.hideInInstances   = f.hideInstCB:GetChecked()
        db.showHeaders       = f.headerCB:GetChecked()
        db.showTitleBar      = f.titlebarCB:GetChecked()
        db.showBackground    = f.bgCB:GetChecked()
        db.preferWarbandBankOnOpen = f.wbBankDefaultCB:GetChecked()

        db.tsmCustomSource   = f.customEdit:GetText() or ""

        db.modules.Character   = f.charCB:GetChecked()
        db.modules.Gold        = f.goldCB:GetChecked()
        db.modules.Inventory   = f.invCB:GetChecked()
        db.modules.Professions = f.profCB:GetChecked()
        db.modules.Utility     = f.utilCB:GetChecked()

        db.showTracker         = f.trackerCB:GetChecked()
        db.showCurrencyTracker = f.currencyCB:GetChecked()

        addon:UpdateBackground()
        addon:UpdateTitleBar()
        if addon.HUD and addon.HUD.UpdateLockTexture then
            addon.HUD.UpdateLockTexture()
        end
        addon:QueueBagValueRecalc()
        addon:UpdateAllSections()
        addon:UpdateUtilityBar()
        addon:UpdateVisibility()
    end

    f:SetScript("OnShow", Refresh)

    -- Hook checkboxes to apply on click
    local function Hook(cb)
        cb:SetScript("OnClick", Apply)
    end

    Hook(f.enableCB)
    Hook(f.hideCombatCB)
    Hook(f.hideInstCB)
    Hook(f.headerCB)
    Hook(f.titlebarCB)
    Hook(f.bgCB)
    Hook(f.wbBankDefaultCB)
    Hook(f.charCB)
    Hook(f.goldCB)
    Hook(f.invCB)
    Hook(f.profCB)
    Hook(f.utilCB)
    Hook(f.trackerCB)
    Hook(f.currencyCB)

    f.customEdit:SetScript("OnEnterPressed", function()
        f.customEdit:ClearFocus()
        Apply()
    end)
end

-----------------------------------------------------------------------
-- Open config (toggle)
-----------------------------------------------------------------------

function addon:OpenConfig()
    CreateConfigFrame()
    if configFrame:IsShown() then
        configFrame:Hide()
    else
        configFrame:Show()
    end
end
