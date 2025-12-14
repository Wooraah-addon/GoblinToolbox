local addonName, addon = ...

local function CreateCheckButton(parent, label, tooltip, x, y)
    local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    cb.Text:SetText(label)
    if tooltip then
        cb.tooltipText = tooltip
    end
    return cb
end

local function CreateSlider(parent, label, minVal, maxVal, step, x, y)
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    _G[slider:GetName() .. "Low"]:SetText(tostring(minVal))
    _G[slider:GetName() .. "High"]:SetText(tostring(maxVal))
    _G[slider:GetName() .. "Text"]:SetText(label)
    return slider
end

local function RefreshPanel(panel)
    local db = addon.db.profile

    panel.enableCB:SetChecked(db.enabled)
    panel.hideCombatCB:SetChecked(db.hideInCombat)
    panel.hideInstanceCB:SetChecked(db.hideInInstances)
    panel.headersCB:SetChecked(db.showHeaders)

    panel.scaleSlider:SetValue(db.scale or 1.0)
    panel.fontSlider:SetValue(db.fontSize or 12)

    panel.charCB:SetChecked(db.modules.Character ~= false)
    panel.goldCB:SetChecked(db.modules.Gold ~= false)
    panel.invCB:SetChecked(db.modules.Inventory ~= false)
    panel.profCB:SetChecked(db.modules.Professions ~= false)
    panel.utilCB:SetChecked(db.modules.Utility ~= false)
end

local function ApplyPanel(panel)
    local db = addon.db.profile

    db.enabled = panel.enableCB:GetChecked()
    db.hideInCombat = panel.hideCombatCB:GetChecked()
    db.hideInInstances = panel.hideInstanceCB:GetChecked()
    db.showHeaders = panel.headersCB:GetChecked()

    db.scale = panel.scaleSlider:GetValue()
    db.fontSize = panel.fontSlider:GetValue()

    db.modules.Character = panel.charCB:GetChecked()
    db.modules.Gold = panel.goldCB:GetChecked()
    db.modules.Inventory = panel.invCB:GetChecked()
    db.modules.Professions = panel.profCB:GetChecked()
    db.modules.Utility = panel.utilCB:GetChecked()

    -- Update UI
    addon.HUD.frame:SetScale(db.scale)
    addon.HUD.groups.Character.header:SetShown(db.showHeaders)
    addon.HUD.groups.Gold.header:SetShown(db.showHeaders)
    addon.HUD.groups.Inventory.header:SetShown(db.showHeaders)
    addon.HUD.groups.Professions.header:SetShown(db.showHeaders)
    addon.HUD.groups.Utility.header:SetShown(db.showHeaders)

    -- reset font cache
    _G["GoblinToolboxFont"] = nil

    addon:RelayoutHUD()
    addon:UpdateAllModules()
    addon:UpdateVisibility()
end

local function CreateOptionsPanel()
    local panel = CreateFrame("Frame", "GoblinToolboxOptionsPanel", InterfaceOptionsFramePanelContainer)
    panel.name = "Goblin Toolbox"

    panel:Hide()
    panel:SetScript("OnShow", function(self)
        if not self.initialized then
            local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
            title:SetPoint("TOPLEFT", 16, -16)
            title:SetText("Goblin Toolbox")

            local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
            sub:SetText("Lightweight gold making HUD. Most settings take effect immediately.")

            local y = -60

            panel.enableCB = CreateCheckButton(panel, "Enable HUD", nil, 16, y)
            y = y - 30
            panel.hideCombatCB = CreateCheckButton(panel, "Hide in combat", nil, 16, y)
            y = y - 30
            panel.hideInstanceCB = CreateCheckButton(panel, "Hide in instances", nil, 16, y)
            y = y - 30
            panel.headersCB = CreateCheckButton(panel, "Show group headers", nil, 16, y)

            y = -60
            panel.scaleSlider = CreateSlider(panel, "HUD scale", 0.5, 2.0, 0.05, 260, y)
            y = y - 50
            panel.fontSlider = CreateSlider(panel, "Font size", 8, 18, 1, 260, y)

            y = y - 80
            local modulesLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
            modulesLabel:SetPoint("TOPLEFT", 16, y)
            modulesLabel:SetText("Modules")

            y = y - 24
            panel.charCB = CreateCheckButton(panel, "Character line", nil, 32, y)
            y = y - 24
            panel.goldCB = CreateCheckButton(panel, "Gold & Economy", nil, 32, y)
            y = y - 24
            panel.invCB = CreateCheckButton(panel, "Inventory & Currency", nil, 32, y)
            y = y - 24
            panel.profCB = CreateCheckButton(panel, "Professions", nil, 32, y)
            y = y - 24
            panel.utilCB = CreateCheckButton(panel, "Utility buttons", nil, 32, y)

            panel.okay = function(self)
                ApplyPanel(self)
            end
            panel.default = function(self)
                GoblinToolboxDB = nil
                addon.db = addon:GetDB()
                RefreshPanel(self)
                ApplyPanel(self)
            end
            panel.refresh = function(self)
                RefreshPanel(self)
            end

            self.initialized = true
        end

        RefreshPanel(self)
    end)

    InterfaceOptions_AddCategory(panel)
end

-- Create the panel when the addon loads
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    CreateOptionsPanel()
end)
