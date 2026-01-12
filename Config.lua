-- Config.lua
-- Configuration panel for /gtb command

local addonName, addon = ...

-----------------------------------------------------------------------
-- Addon metadata
-----------------------------------------------------------------------

-- Pull metadata from the TOC where possible (Version, Author, etc.).
-- Fallbacks avoid nil concatenation if metadata is unavailable for any reason.
local function GetAddonMeta(field, fallback)
    local name = addonName or "GoblinToolbox"
    local v

    -- Prefer modern API if present
    if C_AddOns and type(C_AddOns.GetAddOnMetadata) == "function" then
        v = C_AddOns.GetAddOnMetadata(name, field)
        if (v == nil or v == "") and name ~= "GoblinToolbox" then
            v = C_AddOns.GetAddOnMetadata("GoblinToolbox", field)
        end
    end

    -- Legacy fallback
    if (v == nil or v == "") and type(GetAddOnMetadata) == "function" then
        v = GetAddOnMetadata(name, field)
        if (v == nil or v == "") and name ~= "GoblinToolbox" then
            v = GetAddOnMetadata("GoblinToolbox", field)
        end
    end

    if v == nil or v == "" then
        return fallback
    end
    return v
end


local ADDON_VERSION = GetAddonMeta("Version", "0.0.0")
local ADDON_AUTHOR  = GetAddonMeta("Author", "Unknown")

-----------------------------------------------------------------------
-- Config frame state
-----------------------------------------------------------------------

local configFrame
local OPT_TITLE_FONT, OPT_BODY_FONT, OPT_SECTION_FONT, OPT_SMALL_FONT

-----------------------------------------------------------------------
-- Preset button styling (green tint)
-----------------------------------------------------------------------

local function StylePresetButton(btn)
    -- Get all texture regions
    local regions = {btn:GetRegions()}

    for _, region in ipairs(regions) do
        if region:GetObjectType() == "Texture" then
            local texturePath = region:GetTexture()

            -- Check if it's a button texture (not the text or other decorations)
            if texturePath and type(texturePath) == "string" then
                local lower = texturePath:lower()
                if lower:find("button") then
                    -- Apply green tint to button textures
                    region:SetVertexColor(0.25, 0.75, 0.25, 1.0)
                end
            elseif texturePath and type(texturePath) == "number" then
                -- Texture is set but as atlas - tint it
                region:SetVertexColor(0.25, 0.75, 0.25, 1.0)
            end
        end
    end

    -- Also set the highlight with ADD blend
    local h = btn:GetHighlightTexture()
    if h then
        h:SetVertexColor(0.35, 0.90, 0.35, 0.3)
        h:SetBlendMode("ADD")
    end
end

-----------------------------------------------------------------------
-- Option lists
-----------------------------------------------------------------------

local tsmSourceList = {
    { value = "dbmarket",          text = "DBMarket" },
    { value = "dbregionmarketavg", text = "DBRegionMarketAvg" },
    { value = "dbregionsaleavg",   text = "DBRegionSaleAvg" },
    { value = "dbrecent",          text = "DBRecent" },
    { value = "vendor",            text = "Vendor Price" },
    { value = "custom",            text = "Custom (below)" },
}

-----------------------------------------------------------------------
-- Default positions (for reset)
-----------------------------------------------------------------------

local DEFAULT_HUD_POSITION = {
    point = "TOPLEFT",
    relPoint = "TOPLEFT",
    xOfs = 10,
    yOfs = -120,
}

-----------------------------------------------------------------------
-- Font setup
-----------------------------------------------------------------------

local function EnsureOptionFonts()
    if OPT_TITLE_FONT and OPT_BODY_FONT and OPT_SECTION_FONT and OPT_SMALL_FONT then
        return
    end

    OPT_TITLE_FONT = CreateFont("GoblinToolboxOptTitle")
    OPT_TITLE_FONT:SetFont("Fonts\\ARIALN.TTF", 18, "OUTLINE")
    OPT_TITLE_FONT:SetTextColor(0.97, 0.86, 0.29)

    OPT_SECTION_FONT = CreateFont("GoblinToolboxOptSection")
    OPT_SECTION_FONT:SetFont("Fonts\\ARIALN.TTF", 14, "OUTLINE")
    OPT_SECTION_FONT:SetTextColor(0.85, 0.75, 0.25)

    OPT_BODY_FONT = CreateFont("GoblinToolboxOptBody")
    OPT_BODY_FONT:SetFont("Fonts\\ARIALN.TTF", 13, "")
    OPT_BODY_FONT:SetTextColor(0.9, 0.9, 0.9)

    OPT_SMALL_FONT = CreateFont("GoblinToolboxOptSmall")
    OPT_SMALL_FONT:SetFont("Fonts\\ARIALN.TTF", 11, "")
    OPT_SMALL_FONT:SetTextColor(0.6, 0.6, 0.6)
end

-----------------------------------------------------------------------
-- Collapsible section system
-----------------------------------------------------------------------

local sectionStates = {}

local function CreateSectionHeader(parent, key, title, yOffset)
    local section = {
        key = key,
        collapsed = sectionStates[key] or false,
        children = {},
    }

    local header = CreateFrame("Button", nil, parent)
    header:SetSize(390, 22)
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, yOffset)
    section.header = header

    local toggle = header:CreateTexture(nil, "ARTWORK")
    toggle:SetSize(12, 12)
    toggle:SetPoint("LEFT", header, "LEFT", 0, 0)
    section.toggle = toggle

    local titleText = header:CreateFontString(nil, "OVERLAY")
    titleText:SetFontObject(OPT_SECTION_FONT)
    titleText:SetPoint("LEFT", toggle, "RIGHT", 6, 0)
    titleText:SetText(title)
    section.title = titleText

    local sep = header:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("LEFT", titleText, "RIGHT", 10, 0)
    sep:SetPoint("RIGHT", header, "RIGHT", -4, 0)
    sep:SetColorTexture(0.4, 0.4, 0.4, 0.5)

    local function UpdateToggle()
        if section.collapsed then
            toggle:SetTexture("Interface\\Buttons\\UI-PlusButton-Up")
        else
            toggle:SetTexture("Interface\\Buttons\\UI-MinusButton-Up")
        end
    end

    local function UpdateChildren()
        for _, child in ipairs(section.children) do
            if section.collapsed then
                child:Hide()
            else
                child:Show()
            end
        end
    end

    section.UpdateVisibility = function()
        UpdateToggle()
        UpdateChildren()
    end

    header:SetScript("OnClick", function()
        section.collapsed = not section.collapsed
        sectionStates[key] = section.collapsed
        section.UpdateVisibility()
    end)

    header:SetScript("OnEnter", function()
        titleText:SetTextColor(1, 0.9, 0.3)
    end)
    header:SetScript("OnLeave", function()
        titleText:SetTextColor(0.85, 0.75, 0.25)
    end)

    UpdateToggle()

    section.AddChild = function(self, element)
        table.insert(self.children, element)
        if self.collapsed then
            element:Hide()
        end
    end

    return section
end

-----------------------------------------------------------------------
-- UI element helpers
-----------------------------------------------------------------------

local function CreateCheckbox(parent, label, x, y)
    local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    cb.Text:SetFontObject(OPT_BODY_FONT)
    cb.Text:SetText(label)
    return cb
end

local function CreateSlider(parent, label, x, y, minVal, maxVal, step)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(360, 24)
    container:SetPoint("TOPLEFT", x, y)

    local sliderLabel = container:CreateFontString(nil, "OVERLAY")
    sliderLabel:SetFontObject(OPT_BODY_FONT)
    sliderLabel:SetPoint("LEFT", 0, 0)
    sliderLabel:SetText(label)
    container.label = sliderLabel

    local slider = CreateFrame("Slider", nil, container, "OptionsSliderTemplate")
    slider:SetPoint("RIGHT", container, "RIGHT", -50, 0)
    slider:SetSize(150, 17)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    container.slider = slider

    slider.Low:SetText(tostring(minVal))
    slider.High:SetText(tostring(maxVal))

    local valueText = container:CreateFontString(nil, "OVERLAY")
    valueText:SetFontObject(OPT_BODY_FONT)
    valueText:SetPoint("LEFT", slider, "RIGHT", 10, 0)
    container.valueText = valueText

    return container
end

-----------------------------------------------------------------------
-- Horizontal checkbox row helper
-----------------------------------------------------------------------

local function CreateHorizontalCheckboxRow(parent, x, y, maxWidth)
    local row = {
        x = x,
        y = y,
        currentX = x,
        currentY = y,
        maxWidth = maxWidth or 380,
        checkboxes = {},
        containers = {},  -- Row containers for visibility
    }
    
    -- Create first row container
    local currentRowContainer = CreateFrame("Frame", nil, parent)
    currentRowContainer:SetPoint("TOPLEFT", x, y)
    currentRowContainer:SetSize(row.maxWidth, 22)
    table.insert(row.containers, currentRowContainer)
    row.currentRowContainer = currentRowContainer
    
    row.AddCheckbox = function(self, key, label, width)
        width = width or 100
        
        -- Check if we need to wrap to next row
        if self.currentX + width > self.x + self.maxWidth then
            self.currentY = self.currentY - 22
            self.currentX = self.x
            
            -- Create new row container
            local newRowContainer = CreateFrame("Frame", nil, parent)
            newRowContainer:SetPoint("TOPLEFT", self.x, self.currentY)
            newRowContainer:SetSize(self.maxWidth, 22)
            table.insert(self.containers, newRowContainer)
            self.currentRowContainer = newRowContainer
        end
        
        local cb = CreateFrame("CheckButton", nil, self.currentRowContainer, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", self.currentX - self.x, 0)
        cb:SetScale(0.85)
        cb.Text:SetFontObject(OPT_BODY_FONT)
        cb.Text:SetText(label)
        cb.Text:SetTextColor(0.8, 0.8, 0.8)
        
        cb.key = key
        self.checkboxes[key] = cb
        self.currentX = self.currentX + width
        
        return cb
    end
    
    row.GetHeight = function(self)
        return math.abs(self.currentY - self.y) + 22
    end
    
    row.GetAllContainers = function(self)
        return self.containers
    end
    
    return row
end

-----------------------------------------------------------------------
-- Module checkbox with children
-----------------------------------------------------------------------

local function CreateModuleCheckbox(parent, section, moduleKey, label, x, y, childDefs, Apply)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(390, 24)
    container:SetPoint("TOPLEFT", x, y)
    
    -- Main module checkbox
    local mainCB = CreateFrame("CheckButton", nil, container, "InterfaceOptionsCheckButtonTemplate")
    mainCB:SetPoint("TOPLEFT", 0, 0)
    mainCB.Text:SetFontObject(OPT_BODY_FONT)
    mainCB.Text:SetText(label)
    mainCB.moduleKey = moduleKey
    
    local result = {
        container = container,
        mainCB = mainCB,
        childRow = nil,
        childCheckboxes = {},
        totalHeight = 24,
    }
    
    -- Create child checkboxes in horizontal row
    if childDefs and #childDefs > 0 then
        local childY = y - 24
        local childRow = CreateHorizontalCheckboxRow(parent, x + 24, childY, 360)
        
        for _, def in ipairs(childDefs) do
            local cb = childRow:AddCheckbox(def.key, def.label, def.width or 100)
            result.childCheckboxes[def.key] = cb
            
            -- Hook child checkbox to Apply
            cb:SetScript("OnClick", function()
                if Apply then Apply() end
            end)
        end
        
        result.childRow = childRow
        result.totalHeight = 24 + childRow:GetHeight()
        
        -- Add all child row containers to section
        for _, rowContainer in ipairs(childRow:GetAllContainers()) do
            section:AddChild(rowContainer)
        end
    end
    
    -- Main checkbox click handler - cascade to children
    mainCB:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        
        -- Cascade to all children
        for _, cb in pairs(result.childCheckboxes) do
            cb:SetChecked(checked)
        end
        
        if Apply then Apply() end
    end)
    
    section:AddChild(container)
    
    return result
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

    f:SetSize(460, 720)
    f:SetPoint("CENTER")
    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile     = true, tileSize = 16, edgeSize = 1,
        insets   = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    f:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    f:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("DIALOG")
    f:Hide()

    -- Title
    local title = f:CreateFontString(nil, "OVERLAY")
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetFontObject(OPT_TITLE_FONT)
    title:SetText("Goblin Toolbox")

    -- Version and author
    local versionText = f:CreateFontString(nil, "OVERLAY")
    versionText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    versionText:SetFontObject(OPT_SMALL_FONT)
    versionText:SetText(string.format("v%s by %s", ADDON_VERSION, ADDON_AUTHOR))

    -- Subtitle
    local subtitle = f:CreateFontString(nil, "OVERLAY")
    subtitle:SetPoint("TOPLEFT", versionText, "BOTTOMLEFT", 0, -2)
    subtitle:SetFontObject(OPT_BODY_FONT)
    subtitle:SetTextColor(0.7, 0.7, 0.7)
    subtitle:SetText("A modular goldmaking HUD for WoW goblins")

    -- Close button
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, -2)

    -----------------------------------------------------------------------
    -- Scroll frame
    -----------------------------------------------------------------------

    local scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -70)
    scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 50)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(420, 1000)
    scrollFrame:SetScrollChild(scrollChild)
    f.scrollChild = scrollChild

    local y = 0
    local SECTION_GAP = 12
    local ITEM_HEIGHT = 26
    local INDENT = 20

    -- Forward declare Apply
    local Apply

    -----------------------------------------------------------------------
    -- Section 1: General
    -----------------------------------------------------------------------

    local generalSection = CreateSectionHeader(scrollChild, "general", "General", y)
    y = y - 26

    -- Three checkboxes on one horizontal line
    f.enableCB = CreateCheckbox(scrollChild, "Enable HUD", INDENT, y)
    generalSection:AddChild(f.enableCB)

    f.hideCombatCB = CreateCheckbox(scrollChild, "Hide in combat", INDENT + 120, y)
    f.hideCombatCB:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Hide in Combat", 1, 1, 1)
        GameTooltip:AddLine("Automatically hides the HUD when entering combat to reduce screen clutter.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    f.hideCombatCB:SetScript("OnLeave", function() GameTooltip:Hide() end)
    generalSection:AddChild(f.hideCombatCB)

    f.hideInstCB = CreateCheckbox(scrollChild, "Hide in instances/raids", INDENT + 260, y)
    f.hideInstCB:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Hide in Instances/Raids", 1, 1, 1)
        GameTooltip:AddLine("Automatically hides the HUD when inside dungeons, raids, scenarios, delves, and arenas.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    f.hideInstCB:SetScript("OnLeave", function() GameTooltip:Hide() end)
    generalSection:AddChild(f.hideInstCB)

    y = y - ITEM_HEIGHT - SECTION_GAP

    -----------------------------------------------------------------------
    -- Section 2: Appearance
    -----------------------------------------------------------------------

    local appearanceSection = CreateSectionHeader(scrollChild, "appearance", "Appearance Settings", y)
    y = y - 26

    -- Add tooltip to appearance section header
    appearanceSection.header:SetScript("OnEnter", function()
        appearanceSection.title:SetTextColor(1, 0.9, 0.3)
        GameTooltip:SetOwner(appearanceSection.header, "ANCHOR_RIGHT")
        GameTooltip:SetText("Appearance Settings", 1, 1, 1)
        GameTooltip:AddLine("Account-wide settings - these apply globally to all characters and profiles.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    appearanceSection.header:SetScript("OnLeave", function()
        appearanceSection.title:SetTextColor(0.85, 0.75, 0.25)
        GameTooltip:Hide()
    end)

    -- Three checkboxes on one horizontal line
    f.headerCB = CreateCheckbox(scrollChild, "Show headers", INDENT, y)
    f.headerCB:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Show Group Headers", 1, 1, 1)
        GameTooltip:AddLine("Displays collapsible section headers (Character, Gold, Inventory) with +/- toggle buttons.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    f.headerCB:SetScript("OnLeave", function() GameTooltip:Hide() end)
    appearanceSection:AddChild(f.headerCB)

    f.titlebarCB = CreateCheckbox(scrollChild, "Show Title Bar", INDENT + 130, y)
    f.titlebarCB:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Show Title Bar", 1, 1, 1)
        GameTooltip:AddLine("Displays the title bar with addon name, settings button, lock button, and minimize button.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    f.titlebarCB:SetScript("OnLeave", function() GameTooltip:Hide() end)
    appearanceSection:AddChild(f.titlebarCB)

    f.bgCB = CreateCheckbox(scrollChild, "Show Background", INDENT + 270, y)
    f.bgCB:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Show Background", 1, 1, 1)
        GameTooltip:AddLine("Displays a semi-transparent dark background behind the HUD for better readability.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    f.bgCB:SetScript("OnLeave", function() GameTooltip:Hide() end)
    appearanceSection:AddChild(f.bgCB)

    y = y - ITEM_HEIGHT - 4

    f.opacityContainer = CreateSlider(scrollChild, "HUD Background Opacity", INDENT, y, 0.0, 1.0, 0.05)
    appearanceSection:AddChild(f.opacityContainer)
    f.opacityContainer:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("HUD Background Opacity", 1, 1, 1)
        GameTooltip:AddLine("Controls the transparency of the HUD background.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("|cff00ff00Account-wide:|r This setting applies to all characters and profiles.", 0.6, 1, 0.6, true)
        GameTooltip:Show()
    end)
    f.opacityContainer:SetScript("OnLeave", function() GameTooltip:Hide() end)
    y = y - 28

    f.scaleContainer = CreateSlider(scrollChild, "UI Scale", INDENT, y, 0.5, 2.0, 0.05)
    appearanceSection:AddChild(f.scaleContainer)
    f.scaleContainer:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("UI Scale", 1, 1, 1)
        GameTooltip:AddLine("Adjusts the size of all Goblin Toolbox frames.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("|cff00ff00Account-wide:|r This setting applies to all characters and profiles.", 0.6, 1, 0.6, true)
        GameTooltip:Show()
    end)
    f.scaleContainer:SetScript("OnLeave", function() GameTooltip:Hide() end)
    y = y - 28

    f.fontContainer = CreateSlider(scrollChild, "Font Size", INDENT, y, 10, 16, 1)
    appearanceSection:AddChild(f.fontContainer)
    f.fontContainer:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Font Size", 1, 1, 1)
        GameTooltip:AddLine("Adjusts the text size in the HUD.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("|cff00ff00Account-wide:|r This setting applies to all characters and profiles.", 0.6, 1, 0.6, true)
        GameTooltip:Show()
    end)
    f.fontContainer:SetScript("OnLeave", function() GameTooltip:Hide() end)
    y = y - 28 - SECTION_GAP

    -----------------------------------------------------------------------
    -- Section 3: Profiles
    -----------------------------------------------------------------------

    local profileSection = CreateSectionHeader(scrollChild, "profiles", "Profiles", y)

    -- Add tooltip to profile section header
    profileSection.header:SetScript("OnEnter", function()
        profileSection.title:SetTextColor(1, 0.9, 0.3)
        GameTooltip:SetOwner(profileSection.header, "ANCHOR_RIGHT")
        GameTooltip:SetText("Profiles", 1, 1, 1)
        GameTooltip:AddLine("Profiles control what content is displayed, tracked items, and per-character settings.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("Appearance settings (scale, font, opacity) are account-wide and not affected by profiles.", 0.6, 1, 0.6, true)
        GameTooltip:Show()
    end)
    profileSection.header:SetScript("OnLeave", function()
        profileSection.title:SetTextColor(0.85, 0.75, 0.25)
        GameTooltip:Hide()
    end)

    y = y - 26

    -- Profile dropdown
    local profileLabel = scrollChild:CreateFontString(nil, "OVERLAY")
    profileLabel:SetPoint("TOPLEFT", INDENT, y)
    profileLabel:SetFontObject(OPT_BODY_FONT)
    profileLabel:SetText("Active Profile:")
    profileSection:AddChild(profileLabel)

    f.profileDropdown = CreateFrame("Frame", "GoblinToolboxProfileDropdown", scrollChild, "UIDropDownMenuTemplate")
    f.profileDropdown:SetPoint("TOPLEFT", INDENT + 90, y + 3)
    UIDropDownMenu_SetWidth(f.profileDropdown, 160)
    profileSection:AddChild(f.profileDropdown)
    y = y - 32

    -- Profile management buttons (all on one line)
    local buttonWidth = 55
    local buttonSpacing = 4
    local buttonY = y

    f.newProfileBtn = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
    f.newProfileBtn:SetSize(buttonWidth, 22)
    f.newProfileBtn:SetPoint("TOPLEFT", INDENT, buttonY)
    f.newProfileBtn:SetText("New")
    profileSection:AddChild(f.newProfileBtn)

    f.copyProfileBtn = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
    f.copyProfileBtn:SetSize(buttonWidth, 22)
    f.copyProfileBtn:SetPoint("TOPLEFT", INDENT + (buttonWidth + buttonSpacing) * 1, buttonY)
    f.copyProfileBtn:SetText("Copy")
    profileSection:AddChild(f.copyProfileBtn)

    f.renameProfileBtn = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
    f.renameProfileBtn:SetSize(buttonWidth + 10, 22)
    f.renameProfileBtn:SetPoint("TOPLEFT", INDENT + (buttonWidth + buttonSpacing) * 2, buttonY)
    f.renameProfileBtn:SetText("Rename")
    profileSection:AddChild(f.renameProfileBtn)

    f.deleteProfileBtn = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
    f.deleteProfileBtn:SetSize(buttonWidth, 22)
    f.deleteProfileBtn:SetPoint("TOPLEFT", INDENT + (buttonWidth + buttonSpacing) * 3 + 10, buttonY)
    f.deleteProfileBtn:SetText("Delete")
    profileSection:AddChild(f.deleteProfileBtn)

    y = y - 28

    -- Profile dropdown initialization
    UIDropDownMenu_Initialize(f.profileDropdown, function(self, level)
        local profiles = addon:GetProfileNames()
        local currentProfile = addon:GetActiveProfileName()

        for _, profileName in ipairs(profiles) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = profileName
            info.arg1 = profileName
            info.func = function(_, name)
                addon:SwitchProfile(name)
                UIDropDownMenu_SetText(f.profileDropdown, name)
            end
            info.checked = (currentProfile == profileName)
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    -- Profile button handlers
    f.newProfileBtn:SetScript("OnClick", function()
        addon.ShowNewProfileDialog()
    end)

    f.copyProfileBtn:SetScript("OnClick", function()
        StaticPopup_Show("GOBLINTOOLBOX_COPY_PROFILE")
    end)

    f.renameProfileBtn:SetScript("OnClick", function()
        local currentProfile = addon:GetActiveProfileName()
        if currentProfile == "Default" then
            print("|cffff4444Goblin Toolbox:|r Cannot rename the Default profile")
            return
        end
        StaticPopup_Show("GOBLINTOOLBOX_RENAME_PROFILE")
    end)

    f.deleteProfileBtn:SetScript("OnClick", function()
        local currentProfile = addon:GetActiveProfileName()
        if currentProfile == "Default" then
            print("|cffff4444Goblin Toolbox:|r Cannot delete the Default profile")
            return
        end

        local profileCount = 0
        for _ in pairs(addon.db.profiles) do
            profileCount = profileCount + 1
        end
        if profileCount <= 1 then
            print("|cffff4444Goblin Toolbox:|r Cannot delete the last profile")
            return
        end

        StaticPopup_Show("GOBLINTOOLBOX_DELETE_PROFILE", currentProfile)
    end)

    -- Copy positions subsection
    y = y - 18
    local copyPosLabel = scrollChild:CreateFontString(nil, "OVERLAY")
    copyPosLabel:SetPoint("TOPLEFT", INDENT, y)
    copyPosLabel:SetFontObject(OPT_BODY_FONT)
    copyPosLabel:SetText("Copy frame positions from:")
    profileSection:AddChild(copyPosLabel)
    y = y - 22

    f.copyPosDropdown = CreateFrame("Frame", "GoblinToolboxCopyPosDropdown", scrollChild, "UIDropDownMenuTemplate")
    f.copyPosDropdown:SetPoint("TOPLEFT", INDENT - 16, y)
    UIDropDownMenu_SetWidth(f.copyPosDropdown, 140)
    profileSection:AddChild(f.copyPosDropdown)

    local copyPosBtn = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
    copyPosBtn:SetSize(120, 22)
    copyPosBtn:SetPoint("LEFT", f.copyPosDropdown, "RIGHT", -10, 2)
    copyPosBtn:SetText("Copy Positions")
    copyPosBtn:SetScript("OnClick", function()
        local sourceProfile = f.copyPosDropdown.selectedProfile
        if not sourceProfile then
            print("|cffff4444Goblin Toolbox:|r Please select a source profile first")
            return
        end

        local currentProfile = addon:GetActiveProfileName()
        if sourceProfile == currentProfile then
            print("|cffff4444Goblin Toolbox:|r Cannot copy positions from the same profile")
            return
        end

        -- Get positions from source profile
        local sourcePositions = addon:GetProfilePositions(sourceProfile)
        if not sourcePositions then
            print("|cffff4444Goblin Toolbox:|r Failed to read positions from source profile")
            return
        end

        -- Copy to current profile
        addon:CopyPositionsToProfile(currentProfile, sourcePositions)

        -- Restore positions to apply immediately
        addon:RestoreHUDPosition()
        addon:RestoreUtilityBarPosition()
        addon:RestoreTrackerBarPosition()
        addon:RestoreCurrencyBarPosition()

        print("|cff00ff00Goblin Toolbox:|r Copied frame positions from '" .. sourceProfile .. "'")
    end)
    profileSection:AddChild(copyPosBtn)
    f.copyPosBtn = copyPosBtn

    y = y - 32

    -----------------------------------------------------------------------
    -- Section 4: Modules
    -----------------------------------------------------------------------

    local modulesSection = CreateSectionHeader(scrollChild, "modules", "Modules", y)
    y = y - 26

    -- Character module with sub-elements
    f.charModule = CreateModuleCheckbox(scrollChild, modulesSection, "Character", "Character & Server", INDENT, y, {
        { key = "charIcon", label = "Char Icon", width = 75 },
        { key = "charClassIcon", label = "Class Icon", width = 80 },
        { key = "charName", label = "Name", width = 65 },
        { key = "charRealm", label = "Realm", width = 65 },
        { key = "charAccountLabel", label = "Account Label", width = 100 },
        { key = "charShardID", label = "Shard ID", width = 75 },
        { key = "charMovespeed", label = "MoveSpeed", width = 80 },
    }, function() Apply() end)

    -- Add tooltip for Account Label
    if f.charModule.childCheckboxes.charAccountLabel then
        f.charModule.childCheckboxes.charAccountLabel:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Account Label", 1, 1, 1)
            GameTooltip:AddLine("Shows a custom bracketed identifier (e.g., [WOW1]) under your character name. Saved account-wide.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        f.charModule.childCheckboxes.charAccountLabel:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    -- Add tooltip for Shard ID
    if f.charModule.childCheckboxes.charShardID then
        f.charModule.childCheckboxes.charShardID:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Shard ID", 1, 1, 1)
            GameTooltip:AddLine("WoW splits busy zones into multiple parallel instances ('shards'). This shows which one you're on—handy for coordinating farms or troubleshooting sharding/phasing.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        f.charModule.childCheckboxes.charShardID:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    y = y - f.charModule.totalHeight - 4

    -- Add input box for Account Label text
    local accountLabelText = scrollChild:CreateFontString(nil, "OVERLAY")
    accountLabelText:SetPoint("TOPLEFT", INDENT + 20, y)
    accountLabelText:SetFontObject(OPT_SMALL_FONT)
    accountLabelText:SetText("Label Text:")
    y = y - 18

    f.accountLabelEdit = CreateFrame("EditBox", nil, scrollChild, "InputBoxTemplate")
    f.accountLabelEdit:SetPoint("TOPLEFT", INDENT + 24, y)
    f.accountLabelEdit:SetSize(180, 20)
    f.accountLabelEdit:SetAutoFocus(false)
    f.accountLabelEdit:SetFontObject(OPT_BODY_FONT)
    f.accountLabelEdit:SetMaxLetters(16)
    f.accountLabelEdit:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    f.accountLabelEdit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    f.accountLabelEdit:SetScript("OnEditFocusLost", function(self)
        local text = self:GetText() or ""
        text = text:trim()
        addon.db.global.accountLabel = text
        self:SetText(text)
        if addon.Character and addon.Character.Update then
            addon.Character:Update()
        end
        addon:SafeLayoutHUD()
    end)
    y = y - 28

    -- Gold & Economy module with sub-elements
    f.goldModule = CreateModuleCheckbox(scrollChild, modulesSection, "Gold", "Gold & Economy", INDENT, y, {
        { key = "goldCharacter", label = "Char", width = 60 },
        { key = "goldWarband", label = "Warband", width = 85 },
        { key = "goldGuild", label = "Guild", width = 70 },
        { key = "goldSession", label = "Session", width = 80 },
        { key = "goldToken", label = "Token", width = 70 },
        { key = "goldLootedValue", label = "Looted Value", width = 105 },
        { key = "goldPostedAuctions", label = "Posted", width = 70 },
    }, function() Apply() end)

    -- Add tooltip for Looted Value
    if f.goldModule.childCheckboxes.goldLootedValue then
        f.goldModule.childCheckboxes.goldLootedValue:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Looted Value", 1, 1, 1)
            GameTooltip:AddLine("Tracks the estimated value of items you loot during the current session. Uses your configured pricing source when available; otherwise falls back to vendor sell price.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        f.goldModule.childCheckboxes.goldLootedValue:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    -- Add tooltip for Posted Auctions
    if f.goldModule.childCheckboxes.goldPostedAuctions then
        f.goldModule.childCheckboxes.goldPostedAuctions:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Posted Auctions", 1, 1, 1)
            GameTooltip:AddLine("Displays the total buyout value and count of your currently active auctions. Updates when you open the auction house or post new auctions. Uses Blizzard's auction data API.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        f.goldModule.childCheckboxes.goldPostedAuctions:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    y = y - f.goldModule.totalHeight - 4

    -- Inventory module with sub-elements
    f.invModule = CreateModuleCheckbox(scrollChild, modulesSection, "Inventory", "Inventory", INDENT, y, {
        { key = "invBagValue", label = "Bag Value", width = 95 },
        { key = "invBagSlots", label = "Bag Slots", width = 90 },
        { key = "invWarbank", label = "Warbank Access Indicator", width = 135 },
    }, function() Apply() end)

    -- Add tooltip for Bag Value
    if f.invModule.childCheckboxes.invBagValue then
        f.invModule.childCheckboxes.invBagValue:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Bag Value", 1, 1, 1)
            GameTooltip:AddLine("Shows the total estimated value of items in your bags. Uses TSM price source when available; falls back to vendor sell price.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        f.invModule.childCheckboxes.invBagValue:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    -- Add tooltip for Warbank Access Indicator
    if f.invModule.childCheckboxes.invWarbank then
        f.invModule.childCheckboxes.invWarbank:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Warbank Access Indicator", 1, 1, 1)
            GameTooltip:AddLine("The Warband Bank is shared across your Battle.net account. If you are logged in on multiple WoW clients simultaneously, this indicator will clearly show which of your clients has access to the Warband Bank.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        f.invModule.childCheckboxes.invWarbank:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    y = y - f.invModule.totalHeight - 4

    -- Utility Bar module with individual button checkboxes
    f.utilModule = CreateModuleCheckbox(scrollChild, modulesSection, "Utility", "Utility Bar", INDENT, y, {
        { key = "logout", label = "Logout", width = 70 },
        { key = "reload", label = "Reload", width = 70 },
        { key = "mobileBank", label = "Mobile Bank", width = 105 },
        { key = "mailbox", label = "Mailbox", width = 85 },
        { key = "tradersBrutosaur", label = "AH Mount", width = 95 },
        { key = "vendorMount", label = "Vendor Mount", width = 110 },
        { key = "warbandBank", label = "Warband", width = 85 },
        { key = "hearthstone", label = "Hearthstone", width = 105 },
        { key = "dalaranHS", label = "Dalaran HS", width = 95 },
        { key = "garrisonHS", label = "Garrison HS", width = 100 },
        { key = "housingTeleport", label = "Housing", width = 75 },
    }, function() Apply() end)
    y = y - f.utilModule.totalHeight - SECTION_GAP

    -----------------------------------------------------------------------
    -- Section 4: Item Tracker Bar
    -----------------------------------------------------------------------

    local itemTrackerSection = CreateSectionHeader(scrollChild, "itemtracker", "Item Tracker Bar", y)
    y = y - 26

    f.trackerCB = CreateCheckbox(scrollChild, "Enable Item Tracker Bar", INDENT, y)
    itemTrackerSection:AddChild(f.trackerCB)
    y = y - ITEM_HEIGHT

    f.showTrackedItemValueCB = CreateCheckbox(scrollChild, "Show tracked item value", INDENT, y)
    f.showTrackedItemValueCB:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Show Tracked Item Value", 1, 1, 1)
        GameTooltip:AddLine("Displays an estimated gold value under each tracked item. Requires a supported pricing addon.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    f.showTrackedItemValueCB:SetScript("OnLeave", function() GameTooltip:Hide() end)
    itemTrackerSection:AddChild(f.showTrackedItemValueCB)
    y = y - ITEM_HEIGHT - 8

    -- Subsection: Items to include in Tracker Totals (horizontal layout like Utility Bar)
    local trackerSourcesLabel = scrollChild:CreateFontString(nil, "OVERLAY")
    trackerSourcesLabel:SetPoint("TOPLEFT", INDENT, y)
    trackerSourcesLabel:SetFontObject(OPT_BODY_FONT)
    trackerSourcesLabel:SetText("Items to include in Tracker Totals:")
    itemTrackerSection:AddChild(trackerSourcesLabel)
    y = y - 24

    -- Create horizontal row of checkboxes (matching Utility Bar style)
    local trackerSourceRow = CreateHorizontalCheckboxRow(scrollChild, INDENT + 24, y, 360)

    f.trackerIncludeInventoryCB = trackerSourceRow:AddCheckbox("inventory", "Player Bags", 110)
    f.trackerIncludeInventoryCB:SetScript("OnClick", function() Apply() end)
    f.trackerIncludeInventoryCB:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Include Player Bags", 1, 1, 1)
        GameTooltip:AddLine("Counts items in your character's bags (normal + reagent).", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("This is updated in real-time as you loot/move items.", 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    f.trackerIncludeInventoryCB:SetScript("OnLeave", function() GameTooltip:Hide() end)

    f.trackerIncludePlayerBankCB = trackerSourceRow:AddCheckbox("playerbank", "Player Bank", 110)
    f.trackerIncludePlayerBankCB:SetScript("OnClick", function() Apply() end)
    f.trackerIncludePlayerBankCB:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Include Player Bank", 1, 1, 1)
        GameTooltip:AddLine("Counts items in your character's personal bank (character-specific).", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("Bank contents are scanned when you visit a banker and cached until your next visit.", 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    f.trackerIncludePlayerBankCB:SetScript("OnLeave", function() GameTooltip:Hide() end)

    f.trackerIncludeWarbandBankCB = trackerSourceRow:AddCheckbox("warbandbank", "Warband Bank", 125)
    f.trackerIncludeWarbandBankCB:SetScript("OnClick", function() Apply() end)
    f.trackerIncludeWarbandBankCB:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Include Warband Bank", 1, 1, 1)
        GameTooltip:AddLine("Counts items in your account-wide warband bank.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("Bank contents are scanned when you visit a banker and cached until your next visit.", 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    f.trackerIncludeWarbandBankCB:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Add row containers to section
    for _, rowContainer in ipairs(trackerSourceRow:GetAllContainers()) do
        itemTrackerSection:AddChild(rowContainer)
    end

    y = y - trackerSourceRow:GetHeight() - SECTION_GAP

    -----------------------------------------------------------------------
    -- Section 5: Currency Tracker Bar
    -----------------------------------------------------------------------

    local currencyTrackerSection = CreateSectionHeader(scrollChild, "currencytracker", "Currency Tracker Bar", y)
    y = y - 26

    f.currencyCB = CreateCheckbox(scrollChild, "Enable Currency Tracker Bar", INDENT, y)
    currencyTrackerSection:AddChild(f.currencyCB)
    y = y - ITEM_HEIGHT - SECTION_GAP

    -----------------------------------------------------------------------
    -- Section 6: Gold & Economy Options
    -----------------------------------------------------------------------

    local goldOptsSection = CreateSectionHeader(scrollChild, "goldoptions", "Gold & Economy Options", y)
    y = y - 26

    local tsmLabel = scrollChild:CreateFontString(nil, "OVERLAY")
    tsmLabel:SetPoint("TOPLEFT", INDENT, y)
    tsmLabel:SetFontObject(OPT_BODY_FONT)
    tsmLabel:SetText("Gold value source:")
    goldOptsSection:AddChild(tsmLabel)
    y = y - 18

    f.tsmDropdown = CreateFrame("Frame", "GoblinToolboxTSMDropdown", scrollChild, "UIDropDownMenuTemplate")
    f.tsmDropdown:SetPoint("TOPLEFT", INDENT - 16, y)
    UIDropDownMenu_SetWidth(f.tsmDropdown, 180)
    f.tsmDropdown:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Gold Value Source", 1, 1, 1)
        GameTooltip:AddLine("Price source for bag value and looted item value calculations.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("|cff00ff00Account-wide:|r This setting applies to all characters and profiles.", 0.6, 1, 0.6, true)
        GameTooltip:Show()
    end)
    f.tsmDropdown:SetScript("OnLeave", function() GameTooltip:Hide() end)
    goldOptsSection:AddChild(f.tsmDropdown)
    y = y - 32

    local customLabel = scrollChild:CreateFontString(nil, "OVERLAY")
    customLabel:SetPoint("TOPLEFT", INDENT, y)
    customLabel:SetFontObject(OPT_BODY_FONT)
    customLabel:SetText("Custom TSM price string:")
    goldOptsSection:AddChild(customLabel)
    y = y - 18

    f.customEdit = CreateFrame("EditBox", nil, scrollChild, "InputBoxTemplate")
    f.customEdit:SetPoint("TOPLEFT", INDENT + 4, y)
    f.customEdit:SetSize(220, 20)
    f.customEdit:SetAutoFocus(false)
    f.customEdit:SetFontObject(OPT_BODY_FONT)
    f.customEdit:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Custom TSM Price Source", 1, 1, 1)
        GameTooltip:AddLine("1. Select 'Custom (below)' from the TSM price source dropdown above", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("2. Enter the name of a custom price source you've created in TSM", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("3. Press Enter to apply the change", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("Example: If you created a TSM price source named 'myprice', enter 'myprice' here.", 0.6, 0.8, 1, true)
        GameTooltip:Show()
    end)
    f.customEdit:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    goldOptsSection:AddChild(f.customEdit)
    y = y - 28

    local viewModeLabel = scrollChild:CreateFontString(nil, "OVERLAY")
    viewModeLabel:SetPoint("TOPLEFT", INDENT, y)
    viewModeLabel:SetFontObject(OPT_BODY_FONT)
    viewModeLabel:SetText("Gold tracking view:")
    goldOptsSection:AddChild(viewModeLabel)
    y = y - 18

    f.goldViewDropdown = CreateFrame("Frame", "GoblinToolboxGoldViewDropdown", scrollChild, "UIDropDownMenuTemplate")
    f.goldViewDropdown:SetPoint("TOPLEFT", INDENT - 16, y)
    UIDropDownMenu_SetWidth(f.goldViewDropdown, 180)
    f.goldViewDropdown:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Gold Tracking View", 1, 1, 1)
        GameTooltip:AddLine("Simple: Compact session display with time and net gold.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("Detailed: Adds start/current gold and earned/spent breakdown.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    f.goldViewDropdown:SetScript("OnLeave", function() GameTooltip:Hide() end)
    goldOptsSection:AddChild(f.goldViewDropdown)
    y = y - 32

    f.sessionPersistCB = CreateCheckbox(scrollChild, "Keep session data on logout", INDENT, y)
    f.sessionPersistCB:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Keep Session Data", 1, 1, 1)
        GameTooltip:AddLine("When enabled, session gold tracking persists across logout. When disabled, session resets each time you log in.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("|cff00ff00Account-wide:|r This setting applies to all characters and profiles.", 0.6, 1, 0.6, true)
        GameTooltip:Show()
    end)
    f.sessionPersistCB:SetScript("OnLeave", function() GameTooltip:Hide() end)
    goldOptsSection:AddChild(f.sessionPersistCB)
    y = y - ITEM_HEIGHT - SECTION_GAP

    -----------------------------------------------------------------------
    -- Section 7: Tooltip IDs
    -----------------------------------------------------------------------

    local tooltipSection = CreateSectionHeader(scrollChild, "tooltipids", "Tooltip IDs", y)
    y = y - 26

    f.tooltipEnabledCB = CreateCheckbox(scrollChild, "Show IDs in tooltips (requires reload)", INDENT, y)    tooltipSection:AddChild(f.tooltipEnabledCB)
    y = y - ITEM_HEIGHT

    -- Create horizontal checkbox row for ID types
    local tooltipTypesRow = CreateHorizontalCheckboxRow(scrollChild, INDENT + 20, y, 360)
    
    -- Add checkboxes for each ID type
    if addon.TOOLTIP_ID_TYPE_ORDER then
        for _, idType in ipairs(addon.TOOLTIP_ID_TYPE_ORDER) do
            local label = addon.TOOLTIP_ID_TYPES and addon.TOOLTIP_ID_TYPES[idType] or idType
            local cb = tooltipTypesRow:AddCheckbox(idType, label, 95)
            cb:SetScript("OnClick", function()
                if Apply then Apply() end
            end)
        end
    end
    
    -- Add all tooltip row containers to section
    for _, container in ipairs(tooltipTypesRow:GetAllContainers()) do
        tooltipSection:AddChild(container)
    end
    
    y = y - tooltipTypesRow:GetHeight() - SECTION_GAP

    -----------------------------------------------------------------------
    -- Section 8: Behavior
    -----------------------------------------------------------------------

    local behaviorSection = CreateSectionHeader(scrollChild, "behavior", "Behavior", y)
    y = y - 26

    f.wbBankDefaultCB = CreateCheckbox(scrollChild, "Prefer Warband Bank on bank visit (may conflict with bag addons)", INDENT, y)
    f.wbBankDefaultCB:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Prefer Warband Bank", 1, 1, 1)
        GameTooltip:AddLine("Automatically switches to the Warband Bank tab when you open a bank.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("|cffff8800Warning:|r May conflict with bag addons like Bagnon or AdiBags that manage bank windows.", 1, 0.5, 0.5, true)
        GameTooltip:Show()
    end)
    f.wbBankDefaultCB:SetScript("OnLeave", function() GameTooltip:Hide() end)
    behaviorSection:AddChild(f.wbBankDefaultCB)
    y = y - ITEM_HEIGHT - SECTION_GAP

    -- Store sections
    f.sections = {
        generalSection,
        appearanceSection,
        modulesSection,
        trackersSection,
        goldOptsSection,
        tooltipSection,
        behaviorSection,
    }

    -----------------------------------------------------------------------
    -- Bottom buttons
    -----------------------------------------------------------------------

    local resetPosBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    resetPosBtn:SetSize(130, 24)
    resetPosBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 14)
    resetPosBtn:SetText("Reset Positions")
    resetPosBtn:SetScript("OnClick", function()
        addon:ResetAllPositions()
        print("|cff00ff00Goblin Toolbox:|r Frame positions reset to defaults.")
    end)

    local resetAllBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    resetAllBtn:SetSize(130, 24)
    resetAllBtn:SetPoint("LEFT", resetPosBtn, "RIGHT", 8, 0)
    resetAllBtn:SetText("Reset All Settings")
    resetAllBtn:SetScript("OnClick", function()
        StaticPopup_Show("GOBLINTOOLBOX_RESET_ALL")
    end)

    local reloadBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    reloadBtn:SetSize(100, 24)
    reloadBtn:SetPoint("LEFT", resetAllBtn, "RIGHT", 8, 0)
    reloadBtn:SetText("Reload UI")
    reloadBtn:SetScript("OnClick", function()
        ReloadUI()
    end)

    StaticPopupDialogs["GOBLINTOOLBOX_RESET_ALL"] = {
        text = "Reset ALL Goblin Toolbox settings to defaults?\n\n|cffff8800This cannot be undone.|r\n\n(Character gold history will be preserved)",
        button1 = "Reset",
        button2 = "Cancel",
        OnAccept = function()
            addon:ResetAllSettings()
            if configFrame:IsShown() then
                configFrame:Hide()
                C_Timer.After(0.1, function()
                    configFrame:Show()
                end)
            end
            print("|cff00ff00Goblin Toolbox:|r All settings reset to defaults.")
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    -----------------------------------------------------------------------
    -- TSM Dropdown init
    -----------------------------------------------------------------------

    UIDropDownMenu_Initialize(f.tsmDropdown, function(self, level)
        local current = addon.db.global.tsmSource or "dbregionmarketavg"
        for _, entry in ipairs(tsmSourceList) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = entry.text
            info.arg1 = entry.value
            info.func = function(_, value)
                addon.db.global.tsmSource = value
                UIDropDownMenu_SetText(f.tsmDropdown, entry.text)
                addon:UpdateInventorySection()
                addon:SafeLayoutHUD()
                addon:QueueBagValueRecalc()
            end
            info.checked = (current == entry.value)
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    -----------------------------------------------------------------------
    -- Gold View Dropdown init
    -----------------------------------------------------------------------

    local goldViewModes = {
        { value = "simple", text = "Simple" },
        { value = "detailed", text = "Detailed" },
    }

    UIDropDownMenu_Initialize(f.goldViewDropdown, function(self, level)
        local current = addon.db.profile.goldViewMode or "simple"
        for _, entry in ipairs(goldViewModes) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = entry.text
            info.arg1 = entry.value
            info.func = function(_, value)
                addon.db.profile.goldViewMode = value
                UIDropDownMenu_SetText(f.goldViewDropdown, entry.text)
                addon:UpdateGoldSection()
                addon:SafeLayoutHUD()
            end
            info.checked = (current == entry.value)
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    -----------------------------------------------------------------------
    -- Copy Positions Dropdown init
    -----------------------------------------------------------------------

    UIDropDownMenu_Initialize(f.copyPosDropdown, function(self, level)
        local currentProfile = addon:GetActiveProfileName()
        local profiles = addon:GetProfileNames()

        for _, profileName in ipairs(profiles) do
            -- Skip current profile
            if profileName ~= currentProfile then
                local info = UIDropDownMenu_CreateInfo()
                info.text = profileName
                info.arg1 = profileName
                info.func = function(_, name)
                    f.copyPosDropdown.selectedProfile = name
                    UIDropDownMenu_SetText(f.copyPosDropdown, name)
                end
                info.checked = (f.copyPosDropdown.selectedProfile == profileName)
                UIDropDownMenu_AddButton(info, level)
            end
        end
    end)

    -----------------------------------------------------------------------
    -- Refresh
    -----------------------------------------------------------------------

    local function Refresh()
        local db = addon.db.profile

        -- Update profile dropdown
        if f.profileDropdown then
            UIDropDownMenu_SetText(f.profileDropdown, addon:GetActiveProfileName())
        end

        -- Update copy positions dropdown (reset selection on profile change)
        if f.copyPosDropdown then
            f.copyPosDropdown.selectedProfile = nil
            UIDropDownMenu_SetText(f.copyPosDropdown, "Select Profile")
        end

        -- Ensure elements table exists
        db.elements = db.elements or {}
        local elem = db.elements

        f.enableCB:SetChecked(db.enabled)
        f.hideCombatCB:SetChecked(db.hideInCombat)
        f.hideInstCB:SetChecked(db.hideInInstances)
        f.headerCB:SetChecked(db.showHeaders)
        f.titlebarCB:SetChecked(db.showTitleBar)
        f.bgCB:SetChecked(db.showBackground)
        f.wbBankDefaultCB:SetChecked(db.preferWarbandBankOnOpen)
        f.sessionPersistCB:SetChecked(addon.db.global.sessionPersistOnLogout or false)

        local opacity = addon.db.global.backgroundOpacity or 0.30
        f.opacityContainer.slider:SetValue(opacity)
        f.opacityContainer.valueText:SetText(string.format("%.0f%%", opacity * 100))

        local scale = addon.db.global.scale or 1.0
        f.scaleContainer.slider:SetValue(scale)
        f.scaleContainer.valueText:SetText(string.format("%.0f%%", scale * 100))

        local fontSize = addon.db.global.fontSize or 13
        f.fontContainer.slider:SetValue(fontSize)
        f.fontContainer.valueText:SetText(tostring(fontSize))

        f.customEdit:SetText(addon.db.global.tsmCustomSource or "")

        -- Load account label text
        if f.accountLabelEdit and addon.db.global then
            f.accountLabelEdit:SetText(addon.db.global.accountLabel or "")
        end

        local srcText = addon.db.global.tsmSource or "dbregionmarketavg"
        for _, entry in ipairs(tsmSourceList) do
            if entry.value == srcText then
                srcText = entry.text
                break
            end
        end
        UIDropDownMenu_SetText(f.tsmDropdown, srcText)

        local viewMode = db.goldViewMode or "simple"
        local viewModeText = viewMode == "detailed" and "Detailed" or "Simple"
        UIDropDownMenu_SetText(f.goldViewDropdown, viewModeText)

        -- Module checkboxes
        f.charModule.mainCB:SetChecked(db.modules.Character ~= false)
        f.goldModule.mainCB:SetChecked(db.modules.Gold ~= false)
        f.invModule.mainCB:SetChecked(db.modules.Inventory ~= false)
        f.utilModule.mainCB:SetChecked(db.modules.Utility ~= false)

        -- Character sub-elements
        if f.charModule.childCheckboxes.charIcon then
            f.charModule.childCheckboxes.charIcon:SetChecked(elem.charIcon ~= false)
        end
        if f.charModule.childCheckboxes.charClassIcon then
            f.charModule.childCheckboxes.charClassIcon:SetChecked(elem.charClassIcon ~= false)
        end
        if f.charModule.childCheckboxes.charName then
            f.charModule.childCheckboxes.charName:SetChecked(elem.charName ~= false)
        end
        if f.charModule.childCheckboxes.charRealm then
            f.charModule.childCheckboxes.charRealm:SetChecked(elem.charRealm ~= false)
        end
        if f.charModule.childCheckboxes.charAccountLabel then
            f.charModule.childCheckboxes.charAccountLabel:SetChecked(elem.charAccountLabel ~= false)
        end
        if f.charModule.childCheckboxes.charShardID then
            f.charModule.childCheckboxes.charShardID:SetChecked(elem.charShardID ~= false)
        end
        if f.charModule.childCheckboxes.charMovespeed then
            f.charModule.childCheckboxes.charMovespeed:SetChecked(elem.charMovespeed ~= false)
        end

        -- Gold sub-elements
        if f.goldModule.childCheckboxes.goldCharacter then
            f.goldModule.childCheckboxes.goldCharacter:SetChecked(elem.goldCharacter ~= false)
        end
        if f.goldModule.childCheckboxes.goldWarband then
            f.goldModule.childCheckboxes.goldWarband:SetChecked(elem.goldWarband ~= false)
        end
        if f.goldModule.childCheckboxes.goldGuild then
            f.goldModule.childCheckboxes.goldGuild:SetChecked(elem.goldGuild ~= false)
        end
        if f.goldModule.childCheckboxes.goldSession then
            f.goldModule.childCheckboxes.goldSession:SetChecked(elem.goldSession ~= false)
        end
        if f.goldModule.childCheckboxes.goldToken then
            f.goldModule.childCheckboxes.goldToken:SetChecked(elem.goldToken ~= false)
        end
        if f.goldModule.childCheckboxes.goldLootedValue then
            f.goldModule.childCheckboxes.goldLootedValue:SetChecked(elem.goldLootedValue ~= false)
        end
        if f.goldModule.childCheckboxes.goldPostedAuctions then
            f.goldModule.childCheckboxes.goldPostedAuctions:SetChecked(elem.goldPostedAuctions ~= false)
        end

        -- Inventory sub-elements
        if f.invModule.childCheckboxes.invBagSlots then
            f.invModule.childCheckboxes.invBagSlots:SetChecked(elem.invBagSlots ~= false)
        end
        if f.invModule.childCheckboxes.invBagValue then
            f.invModule.childCheckboxes.invBagValue:SetChecked(elem.invBagValue ~= false)
        end
        if f.invModule.childCheckboxes.invWarbank then
            f.invModule.childCheckboxes.invWarbank:SetChecked(elem.invWarbank ~= false)
        end

        -- Utility button sub-elements
        if f.utilModule.childCheckboxes.logout then
            f.utilModule.childCheckboxes.logout:SetChecked(db.utilityButtons.logout ~= false)
        end
        if f.utilModule.childCheckboxes.reload then
            f.utilModule.childCheckboxes.reload:SetChecked(db.utilityButtons.reload ~= false)
        end
        if f.utilModule.childCheckboxes.mobileBank then
            f.utilModule.childCheckboxes.mobileBank:SetChecked(db.utilityButtons.mobileBank ~= false)
        end
        if f.utilModule.childCheckboxes.mailbox then
            f.utilModule.childCheckboxes.mailbox:SetChecked(db.utilityButtons.mailbox ~= false)
        end
        if f.utilModule.childCheckboxes.tradersBrutosaur then
            f.utilModule.childCheckboxes.tradersBrutosaur:SetChecked(db.utilityButtons.tradersBrutosaur ~= false)
        end
        if f.utilModule.childCheckboxes.vendorMount then
            f.utilModule.childCheckboxes.vendorMount:SetChecked(db.utilityButtons.vendorMount ~= false)
        end
        if f.utilModule.childCheckboxes.warbandBank then
            f.utilModule.childCheckboxes.warbandBank:SetChecked(db.utilityButtons.warbandBank ~= false)
        end
        if f.utilModule.childCheckboxes.hearthstone then
            f.utilModule.childCheckboxes.hearthstone:SetChecked(db.utilityButtons.hearthstone ~= false)
        end
        if f.utilModule.childCheckboxes.dalaranHS then
            f.utilModule.childCheckboxes.dalaranHS:SetChecked(db.utilityButtons.dalaranHS ~= false)
        end
        if f.utilModule.childCheckboxes.garrisonHS then
            f.utilModule.childCheckboxes.garrisonHS:SetChecked(db.utilityButtons.garrisonHS ~= false)
        end
        if f.utilModule.childCheckboxes.housingTeleport then
            f.utilModule.childCheckboxes.housingTeleport:SetChecked(db.utilityButtons.housingTeleport ~= false)
        end

        -- Tracker bars
        f.trackerCB:SetChecked(db.showTracker ~= false)
        f.currencyCB:SetChecked(db.showCurrencyTracker ~= false)
        f.showTrackedItemValueCB:SetChecked(db.showTrackedItemValue ~= false)

        -- Tracker source toggles
        f.trackerIncludeInventoryCB:SetChecked(db.trackerIncludeInventory ~= false)
        f.trackerIncludePlayerBankCB:SetChecked(db.trackerIncludePlayerBank == true)
        f.trackerIncludeWarbandBankCB:SetChecked(db.trackerIncludeWarbandBank == true)

        -- Tooltip IDs
        db.tooltipIDs = db.tooltipIDs or {}
        f.tooltipEnabledCB:SetChecked(db.tooltipIDs.enabled ~= false)
        
        -- Tooltip ID type checkboxes
        if addon.TOOLTIP_ID_TYPE_ORDER and tooltipTypesRow then
            for _, idType in ipairs(addon.TOOLTIP_ID_TYPE_ORDER) do
                local cb = tooltipTypesRow.checkboxes[idType]
                if cb then
                    cb:SetChecked(db.tooltipIDs[idType] ~= false)
                end
            end
        end

        for _, section in ipairs(f.sections) do
            section.UpdateVisibility()
        end
    end

    -----------------------------------------------------------------------
    -- Apply
    -----------------------------------------------------------------------

    Apply = function()
        local db = addon.db.profile
        
        -- Ensure elements table exists
        db.elements = db.elements or {}
        local elem = db.elements

        db.enabled              = f.enableCB:GetChecked()
        db.hideInCombat         = f.hideCombatCB:GetChecked()
        db.hideInInstances      = f.hideInstCB:GetChecked()
        db.showHeaders          = f.headerCB:GetChecked()
        db.showTitleBar         = f.titlebarCB:GetChecked()
        db.showBackground       = f.bgCB:GetChecked()
        db.preferWarbandBankOnOpen = f.wbBankDefaultCB:GetChecked()
        addon.db.global.sessionPersistOnLogout = f.sessionPersistCB:GetChecked()
        addon.db.global.tsmCustomSource = f.customEdit:GetText() or ""

        -- Modules
        db.modules.Character    = f.charModule.mainCB:GetChecked()
        db.modules.Gold         = f.goldModule.mainCB:GetChecked()
        db.modules.Inventory    = f.invModule.mainCB:GetChecked()
        db.modules.Utility      = f.utilModule.mainCB:GetChecked()

        -- Character sub-elements
        if f.charModule.childCheckboxes.charIcon then
            elem.charIcon = f.charModule.childCheckboxes.charIcon:GetChecked()
        end
        if f.charModule.childCheckboxes.charClassIcon then
            elem.charClassIcon = f.charModule.childCheckboxes.charClassIcon:GetChecked()
        end
        if f.charModule.childCheckboxes.charName then
            elem.charName = f.charModule.childCheckboxes.charName:GetChecked()
        end
        if f.charModule.childCheckboxes.charRealm then
            elem.charRealm = f.charModule.childCheckboxes.charRealm:GetChecked()
        end
        if f.charModule.childCheckboxes.charAccountLabel then
            elem.charAccountLabel = f.charModule.childCheckboxes.charAccountLabel:GetChecked()
        end
        if f.charModule.childCheckboxes.charShardID then
            elem.charShardID = f.charModule.childCheckboxes.charShardID:GetChecked()
        end
        if f.charModule.childCheckboxes.charMovespeed then
            elem.charMovespeed = f.charModule.childCheckboxes.charMovespeed:GetChecked()
        end

        -- Gold sub-elements
        if f.goldModule.childCheckboxes.goldCharacter then
            elem.goldCharacter = f.goldModule.childCheckboxes.goldCharacter:GetChecked()
        end
        if f.goldModule.childCheckboxes.goldWarband then
            elem.goldWarband = f.goldModule.childCheckboxes.goldWarband:GetChecked()
        end
        if f.goldModule.childCheckboxes.goldGuild then
            elem.goldGuild = f.goldModule.childCheckboxes.goldGuild:GetChecked()
        end
        if f.goldModule.childCheckboxes.goldSession then
            elem.goldSession = f.goldModule.childCheckboxes.goldSession:GetChecked()
        end
        if f.goldModule.childCheckboxes.goldToken then
            elem.goldToken = f.goldModule.childCheckboxes.goldToken:GetChecked()
        end
        if f.goldModule.childCheckboxes.goldLootedValue then
            elem.goldLootedValue = f.goldModule.childCheckboxes.goldLootedValue:GetChecked()
        end
        if f.goldModule.childCheckboxes.goldPostedAuctions then
            elem.goldPostedAuctions = f.goldModule.childCheckboxes.goldPostedAuctions:GetChecked()
        end

        -- Inventory sub-elements
        if f.invModule.childCheckboxes.invBagSlots then
            elem.invBagSlots = f.invModule.childCheckboxes.invBagSlots:GetChecked()
        end
        if f.invModule.childCheckboxes.invBagValue then
            elem.invBagValue = f.invModule.childCheckboxes.invBagValue:GetChecked()
        end
        if f.invModule.childCheckboxes.invWarbank then
            elem.invWarbank = f.invModule.childCheckboxes.invWarbank:GetChecked()
        end

        -- Utility button sub-elements
        if f.utilModule.childCheckboxes.logout then
            db.utilityButtons.logout = f.utilModule.childCheckboxes.logout:GetChecked()
        end
        if f.utilModule.childCheckboxes.reload then
            db.utilityButtons.reload = f.utilModule.childCheckboxes.reload:GetChecked()
        end
        if f.utilModule.childCheckboxes.mobileBank then
            db.utilityButtons.mobileBank = f.utilModule.childCheckboxes.mobileBank:GetChecked()
        end
        if f.utilModule.childCheckboxes.mailbox then
            db.utilityButtons.mailbox = f.utilModule.childCheckboxes.mailbox:GetChecked()
        end
        if f.utilModule.childCheckboxes.tradersBrutosaur then
            db.utilityButtons.tradersBrutosaur = f.utilModule.childCheckboxes.tradersBrutosaur:GetChecked()
        end
        if f.utilModule.childCheckboxes.vendorMount then
            db.utilityButtons.vendorMount = f.utilModule.childCheckboxes.vendorMount:GetChecked()
        end
        if f.utilModule.childCheckboxes.warbandBank then
            db.utilityButtons.warbandBank = f.utilModule.childCheckboxes.warbandBank:GetChecked()
        end
        if f.utilModule.childCheckboxes.hearthstone then
            db.utilityButtons.hearthstone = f.utilModule.childCheckboxes.hearthstone:GetChecked()
        end
        if f.utilModule.childCheckboxes.dalaranHS then
            db.utilityButtons.dalaranHS = f.utilModule.childCheckboxes.dalaranHS:GetChecked()
        end
        if f.utilModule.childCheckboxes.garrisonHS then
            db.utilityButtons.garrisonHS = f.utilModule.childCheckboxes.garrisonHS:GetChecked()
        end
        if f.utilModule.childCheckboxes.housingTeleport then
            db.utilityButtons.housingTeleport = f.utilModule.childCheckboxes.housingTeleport:GetChecked()
        end

        -- Tracker bars
        db.showTracker          = f.trackerCB:GetChecked()
        db.showCurrencyTracker  = f.currencyCB:GetChecked()
        db.showTrackedItemValue = f.showTrackedItemValueCB:GetChecked()

        -- Tracker source toggles
        db.trackerIncludeInventory    = f.trackerIncludeInventoryCB:GetChecked()
        db.trackerIncludePlayerBank   = f.trackerIncludePlayerBankCB:GetChecked()
        db.trackerIncludeWarbandBank  = f.trackerIncludeWarbandBankCB:GetChecked()

        -- Tooltip IDs
        db.tooltipIDs = db.tooltipIDs or {}
        db.tooltipIDs.enabled = f.tooltipEnabledCB:GetChecked()
        
        -- Tooltip ID type checkboxes
        if addon.TOOLTIP_ID_TYPE_ORDER and tooltipTypesRow then
            for _, idType in ipairs(addon.TOOLTIP_ID_TYPE_ORDER) do
                local cb = tooltipTypesRow.checkboxes[idType]
                if cb then
                    db.tooltipIDs[idType] = cb:GetChecked()
                end
            end
        end

        addon:UpdateBackground()
        addon:UpdateTitleBar()
        if addon.HUD and addon.HUD.UpdateLockTexture then
            addon.HUD.UpdateLockTexture()
        end
        addon:QueueBagValueRecalc()
        addon:UpdateAllSections()
        addon:UpdateUtilityBar()
        addon:UpdateTrackedBar()
        addon:UpdateVisibility()
    end

    f:SetScript("OnShow", Refresh)

    -- Hook standard checkboxes
    local function HookCheckbox(cb)
        cb:SetScript("OnClick", Apply)
    end

    HookCheckbox(f.enableCB)
    HookCheckbox(f.hideCombatCB)
    HookCheckbox(f.hideInstCB)
    HookCheckbox(f.headerCB)
    HookCheckbox(f.titlebarCB)
    HookCheckbox(f.bgCB)
    HookCheckbox(f.wbBankDefaultCB)
    HookCheckbox(f.sessionPersistCB)
    HookCheckbox(f.trackerCB)
    HookCheckbox(f.currencyCB)
    HookCheckbox(f.showTrackedItemValueCB)
    -- Tracker source checkboxes already have OnClick handlers set
    HookCheckbox(f.tooltipEnabledCB)

    f.opacityContainer.slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value * 20 + 0.5) / 20
        f.opacityContainer.valueText:SetText(string.format("%.0f%%", value * 100))
        addon.db.global.backgroundOpacity = value
        addon:UpdateBackground()
    end)

    f.scaleContainer.slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value * 20 + 0.5) / 20
        f.scaleContainer.valueText:SetText(string.format("%.0f%%", value * 100))
        addon.db.global.scale = value
        addon:ApplyScale()
    end)

    f.fontContainer.slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        f.fontContainer.valueText:SetText(tostring(value))
        addon.db.global.fontSize = value
        addon:ResetFontCache()
        addon:UpdateAllSections()
        addon:SafeLayoutHUD()
    end)

    f.customEdit:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        Apply()
    end)

    -- Expose Refresh for external use (profile switching, etc.)
    addon.Config = addon.Config or {}
    addon.Config.Refresh = Refresh
end

-----------------------------------------------------------------------
-- Reset functions
-----------------------------------------------------------------------

function addon:ResetAllPositions()
    local db = self.db.profile

    db.point = DEFAULT_HUD_POSITION.point
    db.relPoint = DEFAULT_HUD_POSITION.relPoint
    db.xOfs = DEFAULT_HUD_POSITION.xOfs
    db.yOfs = DEFAULT_HUD_POSITION.yOfs
    db.hudWidth = nil

    db.trackerPoint = nil
    db.trackerRelPoint = nil
    db.trackerXOfs = nil
    db.trackerYOfs = nil

    db.currencyPoint = nil
    db.currencyRelPoint = nil
    db.currencyXOfs = nil
    db.currencyYOfs = nil

    -- Clear utility bar position (both old and new formats)
    db.utilityBarPos = nil
    db.utilityPoint = nil
    db.utilityRelPoint = nil
    db.utilityXOfs = nil
    db.utilityYOfs = nil
    db.utilityCXFrac = nil
    db.utilityCYFrac = nil

    if self.HUD and self.HUD.frame then
        self.HUD.frame:ClearAllPoints()
        self.HUD.frame:SetPoint(db.point, UIParent, db.relPoint, db.xOfs, db.yOfs)
        self.HUD.frame:SetWidth(self.CONST.HUD_WIDTH)
    end

    -- Fixed default positions (no auto-snapping)
    if self.utilityBar then
        self.utilityBar:ClearAllPoints()
        self.utilityBar:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10, -420)
    end

    if self.trackerFrame then
        self.trackerFrame:ClearAllPoints()
        self.trackerFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10, -475)
    end

    if self.currencyFrame then
        self.currencyFrame:ClearAllPoints()
        self.currencyFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10, -530)
    end

    self:SafeLayoutHUD()
end

function addon:ResetAllSettings()
    local characters = self.db.characters
    local guilds = self.db.guilds

    self.db.profile = {
        enabled             = true,
        scale               = 1.0,
        fontSize            = 13,
        lockFrame           = false,
        hideInCombat        = true,
        hideInInstances     = true,
        showHeaders         = true,
        showTitleBar        = true,
        showBackground      = true,
        backgroundOpacity   = 0.30,
        preferWarbandBankOnOpen = false,
        goldViewMode        = "simple",

        modules = {
            Character   = true,
            Gold        = true,
            Inventory   = true,
             Utility     = true,
        },

        elements = {
            charIcon      = true,
            charClassIcon = true,
            charName      = true,
            charRealm     = true,
            charShardID   = false,
            charMovespeed = false,
            goldCharacter = true,
            goldWarband   = true,
            goldGuild     = true,
            goldSession   = true,
            goldToken     = true,
            goldLootedValue = true,
            goldPostedAuctions = false,
            invBagSlots   = true,
            invBagValue   = true,
            invWarbank    = true,
        },

        collapsed           = {},
        tsmSource           = "dbregionsaleavg",
        tsmCustomSource     = "",
        trackedItems        = {},
        showTracker         = true,
        showCurrencyTracker = true,
        showTrackedItemValue = true,
        trackerIncludeInventory = true,
        trackerIncludePlayerBank = false,
        trackerIncludeWarbandBank = false,

        utilityButtons = {
            logout            = false,
            reload            = false,
            mobileBank        = true,
            mailbox           = true,
            tradersBrutosaur  = true,
            vendorMount       = true,
            warbandBank       = true,
            hearthstone       = true,
            dalaranHS         = true,
            garrisonHS        = true,
            housingTeleport   = false,
        },

        point    = DEFAULT_HUD_POSITION.point,
        relPoint = DEFAULT_HUD_POSITION.relPoint,
        xOfs     = DEFAULT_HUD_POSITION.xOfs,
        yOfs     = DEFAULT_HUD_POSITION.yOfs,
        hudWidth = nil,

        trackedCurrencies = {},
    }

    self.db.characters = characters
    self.db.guilds = guilds

    -- Reset current session state (in-memory only, character cache untouched)
    self.state.sessionStartGold = nil
    self.state.sessionStartTime = nil
    self.state.sessionPaused = false
    self.state.pauseStartTime = nil
    self.state.pausedDuration = 0

    self:ApplyScale()
    self:ResetFontCache()
    self:ResetAllPositions()
    self:UpdateBackground()
    self:UpdateTitleBar()
    self:UpdateAllSections()
    self:UpdateUtilityBar()
    self:UpdateVisibility()
end

-----------------------------------------------------------------------
-- Scale application
-----------------------------------------------------------------------

function addon:ApplyScale()
    local scale = self.db.global.scale or 1.0

    if self.HUD and self.HUD.frame then
        self.HUD.frame:SetScale(scale)
    end
    if self.trackerFrame then
        self.trackerFrame:SetScale(scale)
    end
    if self.currencyFrame then
        self.currencyFrame:SetScale(scale)
    end
    if self.utilityBar then
        self.utilityBar:SetScale(scale)
    end
end

-----------------------------------------------------------------------
-- Custom New Profile Dialog (with preset selection)
-----------------------------------------------------------------------

local newProfileDialog = nil

local function ShowNewProfileDialog()
    if newProfileDialog then
        newProfileDialog:Show()
        newProfileDialog.nameEdit:SetText("")
        newProfileDialog.nameEdit:SetFocus()
        newProfileDialog.selectedPreset = nil
        newProfileDialog:UpdateButtons()
        return
    end

    -- Create custom dialog frame
    local f = CreateFrame("Frame", "GoblinToolboxNewProfileDialog", UIParent, "BackdropTemplate")
    f:SetSize(400, 315)
    f:SetPoint("CENTER")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetFrameLevel(100)
    f:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 16, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    f:SetBackdropColor(0.05, 0.05, 0.05, 1)  -- Dark solid background
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()

    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -20)
    title:SetText("Create New Profile")

    -- Name label and editbox
    local nameLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLabel:SetPoint("TOPLEFT", 30, -50)
    nameLabel:SetText("Profile Name:")

    local nameEdit = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    nameEdit:SetSize(330, 30)
    nameEdit:SetPoint("TOPLEFT", 30, -70)
    nameEdit:SetAutoFocus(false)
    nameEdit:SetScript("OnEnterPressed", function() f:TryCreate() end)
    nameEdit:SetScript("OnEscapePressed", function() f:Hide() end)
    nameEdit:SetScript("OnTextChanged", function() f:UpdateButtons() end)
    f.nameEdit = nameEdit

    -- Preset label
    local presetLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    presetLabel:SetPoint("TOPLEFT", 30, -110)
    presetLabel:SetText("Choose Starting Template:")

    -- Preset buttons (5 buttons in a row)
    local presets = {"Default", "Essentials", "Farmer", "Flipper", "Everything"}
    local presetTooltips = {
        Default = {"Balanced configuration with all main modules enabled.", "Good for general use with essential tracking features."},
        Essentials = {"Streamlined display: Character info and core gold tracking.", "No headers, no trackers - clean and simple."},
        Farmer = {"Optimized for raw farming: Movement speed, looted value,", "detailed gold tracking, and bag tracking enabled."},
        Flipper = {"Optimized for AH operations: Posted auctions, token price,", "inventory tracking across bags, player bank, and warband bank."},
        Everything = {"All modules, elements, and trackers enabled.", "Includes all utility buttons and tooltip IDs."},
    }

    f.presetButtons = {}
    f.selectedPreset = nil

    local btnWidth = 70
    local btnSpacing = 3
    local startX = 10

    for i, presetName in ipairs(presets) do
        local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        btn:SetSize(btnWidth, 24)
        btn:SetPoint("TOPLEFT", startX + (i-1)*(btnWidth+btnSpacing), -135)
        btn:SetText(presetName)
        StylePresetButton(btn)

        btn.presetName = presetName
        btn:SetScript("OnClick", function(self)
            f.selectedPreset = self.presetName
            f:UpdateButtons()
        end)

        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.presetName .. " Preset", 0.25, 0.75, 0.25)
            local tooltipLines = presetTooltips[self.presetName]
            for _, line in ipairs(tooltipLines) do
                GameTooltip:AddLine(line, 0.8, 0.8, 0.8, true)
            end
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        f.presetButtons[presetName] = btn
    end

    -- Copy positions checkbox
    local copyPosCheck = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    copyPosCheck:SetPoint("TOPLEFT", 30, -170)
    copyPosCheck:SetSize(24, 24)
    copyPosCheck:SetChecked(true)  -- Default to checked
    f.copyPositionsCheck = copyPosCheck

    local copyPosLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    copyPosLabel:SetPoint("LEFT", copyPosCheck, "RIGHT", 5, 0)
    copyPosLabel:SetText("Copy frame positions from current profile")
    copyPosLabel:SetTextColor(0.8, 0.8, 0.8)

    copyPosCheck:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Copy Frame Positions", 1, 1, 1)
        GameTooltip:AddLine("If checked, the new profile will inherit the current frame positions (HUD, Utility, Tracker, Currency bars).", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("If unchecked, frames will use default positions for the selected preset.", 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    copyPosCheck:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Create button
    local createBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    createBtn:SetSize(100, 24)
    createBtn:SetPoint("BOTTOM", -55, 20)
    createBtn:SetText("Create")
    createBtn:SetScript("OnClick", function() f:TryCreate() end)
    f.createBtn = createBtn

    -- Cancel button
    local cancelBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    cancelBtn:SetSize(100, 24)
    cancelBtn:SetPoint("BOTTOM", 55, 20)
    cancelBtn:SetText("Cancel")
    cancelBtn:SetScript("OnClick", function() f:Hide() end)

    -- Update button states based on selection
    function f:UpdateButtons()
        local hasName = self.nameEdit:GetText():trim() ~= ""
        local hasPreset = self.selectedPreset ~= nil
        self.createBtn:SetEnabled(hasName and hasPreset)

        -- Highlight selected preset
        for presetName, btn in pairs(self.presetButtons) do
            if presetName == self.selectedPreset then
                btn:LockHighlight()
            else
                btn:UnlockHighlight()
            end
        end
    end

    -- Try to create profile
    function f:TryCreate()
        local name = self.nameEdit:GetText():trim()
        local preset = self.selectedPreset
        local copyPositions = self.copyPositionsCheck:GetChecked()

        if name == "" or not preset then
            return
        end

        -- Save current positions if we need to copy them
        local savedPositions = nil
        if copyPositions then
            savedPositions = addon:GetCurrentProfilePositions()
        end

        local success, result = addon:CreateProfileFromPreset(preset, name)
        if success then
            -- Copy positions to new profile if requested
            if copyPositions and savedPositions then
                addon:CopyPositionsToProfile(result, savedPositions)
            end

            addon:ApplyProfileAndRefresh("Created profile '" .. result .. "' from " .. preset .. " preset")
            self:Hide()
        else
            print("|cffff4444Goblin Toolbox:|r " .. result)
        end
    end

    f:UpdateButtons()
    newProfileDialog = f
    f:Show()
    nameEdit:SetFocus()
end

addon.ShowNewProfileDialog = ShowNewProfileDialog

-----------------------------------------------------------------------
-- StaticPopup dialogs for profile management
-----------------------------------------------------------------------

StaticPopupDialogs["GOBLINTOOLBOX_NEW_PROFILE"] = {
    text = "Enter a name for the new profile:",
    button1 = "Create",
    button2 = "Cancel",
    hasEditBox = true,
    OnShow = function(self)
        self.EditBox:SetText("")
        self.EditBox:SetFocus()
    end,
    OnAccept = function(self)
        local name = self.EditBox:GetText()
        local success, result = addon:CreateProfile(name)
        if success then
            addon:ApplyProfileAndRefresh("Created and switched to profile '" .. result .. "'")
        else
            print("|cffff4444Goblin Toolbox:|r " .. result)
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["GOBLINTOOLBOX_COPY_PROFILE"] = {
    text = "Enter a name for the profile copy:",
    button1 = "Copy",
    button2 = "Cancel",
    hasEditBox = true,
    OnShow = function(self)
        local currentProfile = addon:GetActiveProfileName()
        self.EditBox:SetText(currentProfile .. " Copy")
        self.EditBox:HighlightText()
        self.EditBox:SetFocus()
    end,
    OnAccept = function(self)
        local name = self.EditBox:GetText()
        local success, result = addon:CreateProfile(name)
        if success then
            addon:ApplyProfileAndRefresh("Created and switched to profile '" .. result .. "'")
        else
            print("|cffff4444Goblin Toolbox:|r " .. result)
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["GOBLINTOOLBOX_RENAME_PROFILE"] = {
    text = "Enter new name for the profile:",
    button1 = "Rename",
    button2 = "Cancel",
    hasEditBox = true,
    OnShow = function(self)
        local currentProfile = addon:GetActiveProfileName()
        self.EditBox:SetText(currentProfile)
        self.EditBox:HighlightText()
        self.EditBox:SetFocus()
    end,
    OnAccept = function(self)
        local oldName = addon:GetActiveProfileName()
        local newName = self.EditBox:GetText()
        local success, result = addon:RenameProfile(oldName, newName)
        if success then
            addon:ApplyProfileAndRefresh("Renamed profile to '" .. result .. "'")
        else
            print("|cffff4444Goblin Toolbox:|r " .. result)
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["GOBLINTOOLBOX_DELETE_PROFILE"] = {
    text = "Delete profile '%s'?\n\nThis cannot be undone.",
    button1 = "Delete",
    button2 = "Cancel",
    OnAccept = function(self)
        local profileName = addon:GetActiveProfileName()
        local success, result = addon:DeleteProfile(profileName)
        if success then
            addon:ApplyProfileAndRefresh("Deleted profile '" .. profileName .. "' and switched to Default")
        else
            print("|cffff4444Goblin Toolbox:|r " .. result)
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["GOBLINTOOLBOX_APPLY_PRESET"] = {
    text = "Apply preset '%s' to the current profile?\n\nThis will overwrite multiple settings.",
    button1 = "Apply",
    button2 = "Cancel",
    OnAccept = function(self)
        local presetName = self.data
        if presetName then
            addon:ApplyPreset(presetName)
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-----------------------------------------------------------------------
-- Open config
-----------------------------------------------------------------------

function addon:OpenConfig()
    CreateConfigFrame()
    if configFrame:IsShown() then
        configFrame:Hide()
    else
        configFrame:Show()
    end
end

-----------------------------------------------------------------------
-- Metadata
-----------------------------------------------------------------------

function addon:GetVersion()
    return ADDON_VERSION
end

function addon:GetAuthor()
    return ADDON_AUTHOR
end