-- HUD.lua
-- Main HUD frame: sections, layout engine, visibility control

local addonName, addon = ...

-----------------------------------------------------------------------
-- HUD structure
-----------------------------------------------------------------------

local HUD = {
    order    = { "Character", "Gold", "Inventory", "Professions" },
    sections = {},
    frame    = nil,
    titleBar = nil,
    minimized = false,
}
addon.HUD = HUD

-----------------------------------------------------------------------
-- Position management
-----------------------------------------------------------------------

local function ApplyScaleAndPosition(frame)
    local db = addon.db.profile
    frame:SetScale(db.scale or 1.0)

    if db.point and db.relPoint and db.xOfs and db.yOfs then
        frame:ClearAllPoints()
        frame:SetPoint(db.point, UIParent, db.relPoint, db.xOfs, db.yOfs)
    else
        frame:ClearAllPoints()
        frame:SetPoint("TOP", UIParent, "TOP", 0, -200)
    end
end

local function SaveFramePosition(frame)
    local db = addon.db.profile
    local point, _, relPoint, xOfs, yOfs = frame:GetPoint(1)
    db.point    = point
    db.relPoint = relPoint
    db.xOfs     = xOfs
    db.yOfs     = yOfs
end

local function StartDragging(frame)
    if addon.db.profile.lockFrame then
        return
    end
    frame:StartMoving()
end

local function StopDragging(frame)
    frame:StopMovingOrSizing()
    SaveFramePosition(frame)
end

-----------------------------------------------------------------------
-- Section toggle (collapse/expand)
-----------------------------------------------------------------------

local function SetToggleTextures(section)
    if not section.toggle then
        return
    end
    local prefix = section.collapsed and "UI-PlusButton" or "UI-MinusButton"
    section.toggle:SetNormalTexture("Interface\\Buttons\\" .. prefix .. "-Up")
    section.toggle:SetPushedTexture("Interface\\Buttons\\" .. prefix .. "-Down")
    section.toggle:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
end

-----------------------------------------------------------------------
-- Section creation
-----------------------------------------------------------------------

local function CreateSection(frame, key, headerText, numLines)
    local section = {}
    section.key = key

    section.toggle = CreateFrame("Button", nil, frame)
    section.toggle:SetSize(12, 12)

    section.header = frame:CreateFontString(nil, "OVERLAY")
    section.header:SetJustifyH("LEFT")
    section.header:SetFontObject(addon:GetHeaderFont())
    section.header:SetText(headerText)

    section.lines = {}
    for i = 1, numLines do
        local fs = frame:CreateFontString(nil, "OVERLAY")
        fs:SetJustifyH("LEFT")
        fs:SetFontObject(addon:GetBodyFont())
        section.lines[i] = fs
    end

    section.collapsed = addon.db.profile.collapsed[key] or false
    SetToggleTextures(section)

    section.toggle:SetScript("OnClick", function()
        section.collapsed = not section.collapsed
        addon.db.profile.collapsed[key] = section.collapsed
        SetToggleTextures(section)
        addon:LayoutHUD()
    end)

    HUD.sections[key] = section
end

-----------------------------------------------------------------------
-- HUD frame creation
-----------------------------------------------------------------------

local function CreateHUD()
    if HUD.frame then
        return
    end

    local frame = CreateFrame("Frame", "GoblinToolboxHUD", UIParent, "BackdropTemplate")
    HUD.frame = frame

    frame:SetSize(addon.CONST.HUD_WIDTH, addon.CONST.HUD_DEFAULT_HEIGHT)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetUserPlaced(false)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", StartDragging)
    frame:SetScript("OnDragStop", StopDragging)

    frame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = nil,
        tile     = true, tileSize = 16, edgeSize = 0,
        insets   = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    ApplyScaleAndPosition(frame)

    -- Title bar
    local tb = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    HUD.titleBar = tb
    tb:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    tb:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    tb:SetHeight(addon.CONST.TITLEBAR_HEIGHT)
    tb:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = nil,
        tile     = true, tileSize = 16, edgeSize = 0,
        insets   = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    tb:SetBackdropColor(0, 0, 0, 0.8)
    tb:EnableMouse(true)
    tb:RegisterForDrag("LeftButton")
    tb:SetScript("OnDragStart", function() StartDragging(frame) end)
    tb:SetScript("OnDragStop", function() StopDragging(frame) end)

    tb.title = tb:CreateFontString(nil, "OVERLAY")
    tb.title:SetFontObject(addon:GetHeaderFont())
    tb.title:SetPoint("LEFT", tb, "LEFT", 6, 0)
    tb.title:SetText("Goblin Toolbox")

    local btnSize = 16

    -- Close button
    tb.close = CreateFrame("Button", nil, tb, "UIPanelCloseButton")
    tb.close:SetPoint("RIGHT", tb, "RIGHT", -2, 0)
    tb.close:SetScale(0.7)
    tb.close:SetScript("OnClick", function()
        addon.db.profile.enabled = false
        addon:UpdateVisibility()
    end)

    -- Menu button
    tb.menu = CreateFrame("Button", nil, tb)
    tb.menu:SetSize(btnSize, btnSize)
    tb.menu:SetPoint("RIGHT", tb.close, "LEFT", -2, 0)
    tb.menu:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
    tb.menu:SetHighlightTexture("Interface\\Buttons\\UI-OptionsButton")
    tb.menu:SetScript("OnClick", function() addon:OpenConfig() end)

    -- Lock button
    tb.lock = CreateFrame("Button", nil, tb)
    tb.lock:SetSize(btnSize, btnSize)
    tb.lock:SetPoint("RIGHT", tb.menu, "LEFT", -2, 0)

    local function UpdateLockTexture()
        if addon.db.profile.lockFrame then
            tb.lock:SetNormalTexture("Interface\\Buttons\\LockButton-Locked-Up")
            tb.lock:SetPushedTexture("Interface\\Buttons\\LockButton-Locked-Down")
        else
            tb.lock:SetNormalTexture("Interface\\Buttons\\LockButton-Unlocked-Up")
            tb.lock:SetPushedTexture("Interface\\Buttons\\LockButton-Unlocked-Down")
        end
        tb.lock:SetHighlightTexture("Interface\\Buttons\\CheckButtonHilight")
    end

    HUD.UpdateLockTexture = UpdateLockTexture
    UpdateLockTexture()

    tb.lock:SetScript("OnClick", function()
        addon.db.profile.lockFrame = not addon.db.profile.lockFrame
        UpdateLockTexture()
    end)

    -- Minimize button
    tb.minimize = CreateFrame("Button", nil, tb)
    tb.minimize:SetSize(btnSize, btnSize)
    tb.minimize:SetPoint("RIGHT", tb.lock, "LEFT", -2, 0)
    tb.minimize:SetNormalTexture("Interface\\Buttons\\UI-Panel-HideButton-Up")
    tb.minimize:SetPushedTexture("Interface\\Buttons\\UI-Panel-HideButton-Down")
    tb.minimize:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
    tb.minimize:SetScript("OnClick", function()
        HUD.minimized = not HUD.minimized
        addon:LayoutHUD()
    end)

    -- Create sections
    CreateSection(frame, "Character",   "Character",            1)
    CreateSection(frame, "Gold",        "Gold & Economy",       3)
    CreateSection(frame, "Inventory",   "Inventory & Currency", 3)
    CreateSection(frame, "Professions", "Professions",          1)

    addon:UpdateBackground()
    addon:UpdateTitleBar()
    addon:LayoutHUD()
end

-----------------------------------------------------------------------
-- Background and title bar visibility
-----------------------------------------------------------------------

function addon:UpdateBackground()
    local show = self.db.profile.showBackground
    local alpha = show and 0.30 or 0.0

    if HUD.frame then
        HUD.frame:SetBackdropColor(0, 0, 0, alpha)
    end
    if self.trackerFrame then
        self.trackerFrame:SetBackdropColor(0, 0, 0, alpha)
    end
    if self.utilityBar then
        self.utilityBar:SetBackdropColor(0, 0, 0, alpha)
    end
    if self.currencyFrame then
        self.currencyFrame:SetBackdropColor(0, 0, 0, alpha)
    end
end

function addon:UpdateTitleBar()
    if not HUD.frame or not HUD.titleBar then
        return
    end
    if self.db.profile.showTitleBar then
        HUD.titleBar:Show()
    else
        HUD.titleBar:Hide()
    end
    self:LayoutHUD()
end

-----------------------------------------------------------------------
-- Layout engine
-----------------------------------------------------------------------

function addon:LayoutHUD()
    if not HUD.frame then
        return
    end

    local frame = HUD.frame
    local db = self.db.profile

    -- Minimized state: hide all sections
    if HUD.minimized then
        for _, key in ipairs(HUD.order) do
            local section = HUD.sections[key]
            if section then
                if section.header then section.header:Hide() end
                if section.toggle then section.toggle:Hide() end
                for _, fs in ipairs(section.lines) do
                    fs:Hide()
                end
            end
        end
        local h = HUD.titleBar and HUD.titleBar:IsShown() and HUD.titleBar:GetHeight() or addon.CONST.TITLEBAR_HEIGHT
        frame:SetHeight(h + 4)
        return
    end

    local bodyFont = self:GetBodyFont()
    local headerFont = self:GetHeaderFont()

    local y = -6
    if HUD.titleBar and HUD.titleBar:IsShown() then
        y = -HUD.titleBar:GetHeight() - 6
    end

    for _, key in ipairs(HUD.order) do
        local section = HUD.sections[key]
        local enabled = db.modules[key] ~= false

        if section and enabled then
            local collapsed = section.collapsed and db.showHeaders

            if db.showHeaders then
                section.toggle:Show()
                section.header:Show()
                section.header:SetFontObject(headerFont)

                section.toggle:ClearAllPoints()
                section.toggle:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, y)

                section.header:ClearAllPoints()
                section.header:SetPoint("LEFT", section.toggle, "RIGHT", 2, 0)

                local headerHeight = section.header:GetStringHeight()
                y = y - headerHeight - 2
            else
                section.header:Hide()
                section.toggle:Hide()
                collapsed = false
            end

            if collapsed then
                for _, fs in ipairs(section.lines) do
                    fs:Hide()
                end
            else
                for _, fs in ipairs(section.lines) do
                    local text = fs:GetText()
                    if text and text ~= "" then
                        fs:Show()
                        fs:SetFontObject(bodyFont)
                        fs:ClearAllPoints()
                        fs:SetPoint("TOPLEFT", frame, "TOPLEFT", db.showHeaders and 18 or 6, y)
                        fs:SetPoint("RIGHT", frame, "RIGHT", -6, 0)
                        y = y - fs:GetStringHeight() - 2
                    else
                        fs:Hide()
                    end
                end
            end

            y = y - 4
        elseif section then
            section.header:Hide()
            section.toggle:Hide()
            for _, fs in ipairs(section.lines) do
                fs:Hide()
            end
        end
    end

    local totalHeight = math.abs(y) + 6
    frame:SetHeight(totalHeight)
end

-----------------------------------------------------------------------
-- Visibility control
-----------------------------------------------------------------------

function addon:UpdateVisibility()
    if not HUD.frame then
        return
    end

    local db = self.db.profile

    if not db.enabled then
        HUD.frame:Hide()
        if self.trackerFrame then
            self.trackerFrame:Hide()
        end
        if self.currencyFrame then
            self.currencyFrame:Hide()
        end
        self:SetSecureFrameVisible(self.utilityBar, false)
        return
    end

    local hideAll = false

    if db.hideInCombat and UnitAffectingCombat("player") then
        hideAll = true
    end

    if db.hideInInstances then
        local inInstance, instanceType = IsInInstance()
        if inInstance and instanceType ~= "none" then
            hideAll = true
        end
    end

    if hideAll then
        HUD.frame:Hide()
        if self.trackerFrame then
            self.trackerFrame:Hide()
        end
        if self.currencyFrame then
            self.currencyFrame:Hide()
        end
        self:SetSecureFrameVisible(self.utilityBar, false)
        return
    end

    HUD.frame:Show()

    if self.trackerFrame and db.showTracker then
        self.trackerFrame:Show()
    elseif self.trackerFrame then
        self.trackerFrame:Hide()
    end

    if self.currencyFrame and db.showCurrencyTracker then
        self.currencyFrame:Show()
    elseif self.currencyFrame then
        self.currencyFrame:Hide()
    end

    if db.modules and db.modules.Utility then
        self:UpdateUtilityBar()
    else
        self:SetSecureFrameVisible(self.utilityBar, false)
    end
end

-----------------------------------------------------------------------
-- Update all sections
-----------------------------------------------------------------------

function addon:UpdateAllSections()
    self:UpdateCharacterSection()
    self:UpdateGoldSection()
    self:UpdateInventorySection()
    self:UpdateProfessionsSection()
    self:UpdateTrackedBar()
    self:UpdateCurrencyBar()
    self:LayoutHUD()
end

-----------------------------------------------------------------------
-- Initialize HUD (called from main file)
-----------------------------------------------------------------------

function addon:InitializeHUD()
    CreateHUD()
end
