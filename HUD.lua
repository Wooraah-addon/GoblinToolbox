-- HUD.lua
-- Main HUD frame: sections, layout engine, visibility control, resize functionality

local addonName, addon = ...

-----------------------------------------------------------------------
-- HUD structure
-----------------------------------------------------------------------

local HUD = {
    -- Professions intentionally omitted for now (module paused).
    order = { "Character", "Gold", "Inventory" },
    sections = {},
    frame    = nil,
    titleBar = nil,
    resizeGrip = nil,
    minimized = false,
}

addon.HUD = HUD

-----------------------------------------------------------------------
-- Resize constraints
-----------------------------------------------------------------------

local MIN_WIDTH = 200
local MAX_WIDTH = 600
local MIN_HEIGHT = 60  -- Will be overridden by content

-----------------------------------------------------------------------
-- Position management
-----------------------------------------------------------------------

local function ApplyScaleAndPosition(frame)
    local db = addon.db.profile
    frame:SetScale(db.scale or 1.0)

    -- Apply saved width if available
    local width = db.hudWidth or addon.CONST.HUD_WIDTH
    frame:SetWidth(width)

    if db.point and db.relPoint and db.xOfs and db.yOfs then
        frame:ClearAllPoints()
        frame:SetPoint(db.point, UIParent, db.relPoint, db.xOfs, db.yOfs)
    else
        -- Default position: top-left, below the character frame area
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10, -120)
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

local function SaveFrameWidth(frame)
    local db = addon.db.profile
    db.hudWidth = frame:GetWidth()
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
-- Resize grip creation and management
-----------------------------------------------------------------------

local function CreateResizeGrip(frame)
    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    grip:SetFrameLevel(frame:GetFrameLevel() + 10)

    local gripTexture = grip:CreateTexture(nil, "OVERLAY")
    gripTexture:SetAllPoints(true)
    gripTexture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip.texture = gripTexture

    local highlightTexture = grip:CreateTexture(nil, "HIGHLIGHT")
    highlightTexture:SetAllPoints(true)
    highlightTexture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")

    grip:SetScript("OnEnter", function(self)
        if addon.db.profile.lockFrame then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:SetText("Drag to resize", 1, 1, 1)
        GameTooltip:Show()
    end)

    grip:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    grip:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and not addon.db.profile.lockFrame then
            self.texture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
            frame:StartSizing("BOTTOMRIGHT")
            self.isResizing = true
        end
    end)

    grip:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            self.texture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
            if self.isResizing then
                frame:StopMovingOrSizing()
                SaveFrameWidth(frame)
                SaveFramePosition(frame)
                self.isResizing = false
                addon:SafeLayoutHUD()
            end
        end
    end)

    HUD.resizeGrip = grip
    return grip
end

local function UpdateResizeGripVisibility()
    if not HUD.resizeGrip then
        return
    end

    if addon.db.profile.lockFrame then
        HUD.resizeGrip:Hide()
    else
        HUD.resizeGrip:Show()
    end
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

    local db = addon.db and addon.db.profile
    db.collapsed = db and (db.collapsed or {}) or {}
    section.collapsed = (db and db.collapsed and db.collapsed[key]) or false

    section.toggle = CreateFrame("Button", nil, frame)
    section.toggle:SetSize(12, 12)
    section.toggle:SetScript("OnClick", function()
        local p = addon.db and addon.db.profile
        if not p then
            return
        end
        p.collapsed = p.collapsed or {}
        section.collapsed = not section.collapsed
        p.collapsed[key] = section.collapsed
        SetToggleTextures(section)
        addon:SafeLayoutHUD()
    end)

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

    if key == "Gold" then
        section.sessionResetBtn = CreateFrame("Button", nil, frame)
        section.sessionResetBtn:SetSize(14, 14)
        section.sessionResetBtn:Hide()
        section.sessionResetBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        section.sessionResetBtn:SetNormalAtlas("common-icon-undo")
        section.sessionResetBtn:SetPushedAtlas("common-icon-undo")
        section.sessionResetBtn:SetHighlightAtlas("common-icon-undo")

        section.sessionResetBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Reset Session")
            GameTooltip:AddLine("Resets session start gold and timer.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        section.sessionResetBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        section.sessionResetBtn:SetScript("OnClick", function()
            addon:ResetSession()
            addon:UpdateGoldSection()
            addon:SafeLayoutHUD()
        end)

        section.sessionPauseBtn = CreateFrame("Button", nil, frame)
        section.sessionPauseBtn:SetSize(14, 14)
        section.sessionPauseBtn:Hide()
        section.sessionPauseBtn:SetHighlightTexture(130757)

        local function UpdatePauseButtonTexture()
            local s = addon.state
            if s.sessionPaused then
                section.sessionPauseBtn:SetNormalTexture(130866)
                section.sessionPauseBtn:SetPushedTexture(130866)
            else
                section.sessionPauseBtn:SetNormalTexture(137047)
                section.sessionPauseBtn:SetPushedTexture(137047)
            end
        end

        section.sessionPauseBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local s = addon.state
            if s.sessionPaused then
                GameTooltip:SetText("Resume Session")
                GameTooltip:AddLine("Click to resume tracking", 0.8, 0.8, 0.8, true)
            else
                GameTooltip:SetText("Pause Session")
                GameTooltip:AddLine("Click to pause tracking", 0.8, 0.8, 0.8, true)
            end
            GameTooltip:Show()
        end)
        section.sessionPauseBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        section.sessionPauseBtn:SetScript("OnClick", function()
            addon:TogglePauseSession()
            UpdatePauseButtonTexture()
            addon:UpdateGoldSection()
            addon:SafeLayoutHUD()
        end)

        section.UpdatePauseButtonTexture = UpdatePauseButtonTexture
        UpdatePauseButtonTexture()
    end

    if key == "Inventory" then
        -- Create invisible tooltip button for bag slots line
        section.bagSlotsTooltipBtn = CreateFrame("Button", nil, frame)
        section.bagSlotsTooltipBtn:SetSize(1, 1)  -- Will be resized in layout
        section.bagSlotsTooltipBtn:Hide()
        section.bagSlotsTooltipBtn:EnableMouse(true)
        
        section.bagSlotsTooltipBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Free Normal Bag Slots / Free Reagent Bag Slots", 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        section.bagSlotsTooltipBtn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    SetToggleTextures(section)
    HUD.sections[key] = section
    return section
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
    frame:SetResizable(true)
    frame:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT, MAX_WIDTH, 800)
    frame:SetUserPlaced(false)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", StartDragging)
    frame:SetScript("OnDragStop", StopDragging)

    frame:SetScript("OnSizeChanged", function(self, width, height)
        if HUD.resizeGrip and HUD.resizeGrip.isResizing then
            if not self.layoutPending then
                self.layoutPending = true
                C_Timer.After(0.05, function()
                    self.layoutPending = false
                    addon:SafeLayoutHUD()
                end)
            end
        end
    end)

    frame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = nil,
        tile     = true, tileSize = 16, edgeSize = 0,
        insets   = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    ApplyScaleAndPosition(frame)

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

    tb.close = CreateFrame("Button", nil, tb, "UIPanelCloseButton")
    tb.close:SetPoint("RIGHT", tb, "RIGHT", -2, 0)
    tb.close:SetScale(0.7)
    tb.close:SetScript("OnClick", function()
        addon.db.profile.enabled = false
        addon:UpdateVisibility()
    end)

    tb.menu = CreateFrame("Button", nil, tb)
    tb.menu:SetSize(btnSize, btnSize)
    tb.menu:SetPoint("RIGHT", tb.close, "LEFT", -2, 0)
    tb.menu:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
    tb.menu:SetHighlightTexture("Interface\\Buttons\\UI-OptionsButton")
    tb.menu:SetScript("OnClick", function() addon:OpenConfig() end)
    tb.menu:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Open Menu Settings", 1, 1, 1)
        GameTooltip:Show()
    end)
    tb.menu:SetScript("OnLeave", function() GameTooltip:Hide() end)

    tb.lock = CreateFrame("Button", nil, tb)
    tb.lock:SetSize(20, 20)
    tb.lock:SetPoint("RIGHT", tb.menu, "LEFT", -4, 0)

    tb.lock:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if addon.db.profile.lockFrame then
            GameTooltip:SetText("Unlock Frames", 1, 1, 1)
            GameTooltip:AddLine("Click to unlock all frame positions", 0.8, 0.8, 0.8, true)
        else
            GameTooltip:SetText("Lock Frames", 1, 1, 1)
            GameTooltip:AddLine("Click to lock all frame positions", 0.8, 0.8, 0.8, true)
        end
        GameTooltip:Show()
    end)
    tb.lock:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local function UpdateLockTexture()
        if addon.db.profile.lockFrame then
            tb.lock:SetNormalTexture("Interface\\Buttons\\LockButton-Locked-Up")
            tb.lock:SetPushedTexture("Interface\\Buttons\\LockButton-Locked-Down")
        else
            tb.lock:SetNormalTexture("Interface\\Buttons\\LockButton-Unlocked-Up")
            tb.lock:SetPushedTexture("Interface\\Buttons\\LockButton-Unlocked-Down")
        end
        tb.lock:SetHighlightTexture("Interface\\Buttons\\CheckButtonHilight")
        UpdateResizeGripVisibility()

        if addon.utilityBar and addon.utilityBar.dragHandle then
            if addon.utilityBar.dragHandle.UpdateColor then addon.utilityBar.dragHandle:UpdateColor() end
            if addon.utilityBar.dragHandle.UpdateVisibility then addon.utilityBar.dragHandle:UpdateVisibility() end
        end
        if addon.trackerFrame and addon.trackerFrame.dragHandle then
            if addon.trackerFrame.dragHandle.UpdateColor then addon.trackerFrame.dragHandle:UpdateColor() end
            if addon.trackerFrame.dragHandle.UpdateVisibility then addon.trackerFrame.dragHandle:UpdateVisibility() end
        end
        if addon.currencyFrame and addon.currencyFrame.dragHandle then
            if addon.currencyFrame.dragHandle.UpdateColor then addon.currencyFrame.dragHandle:UpdateColor() end
            if addon.currencyFrame.dragHandle.UpdateVisibility then addon.currencyFrame.dragHandle:UpdateVisibility() end
        end
    end

    HUD.UpdateLockTexture = UpdateLockTexture
    UpdateLockTexture()

    tb.lock:SetScript("OnClick", function()
        addon.db.profile.lockFrame = not addon.db.profile.lockFrame
        UpdateLockTexture()
    end)

    tb.minimize = CreateFrame("Button", nil, tb)
    tb.minimize:SetSize(btnSize, btnSize)
    tb.minimize:SetPoint("RIGHT", tb.lock, "LEFT", -2, 0)
    tb.minimize:SetNormalTexture("Interface\\Buttons\\UI-Panel-HideButton-Up")
    tb.minimize:SetPushedTexture("Interface\\Buttons\\UI-Panel-HideButton-Down")
    tb.minimize:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
    tb.minimize:SetScript("OnClick", function()
        HUD.minimized = not HUD.minimized
        addon:SafeLayoutHUD()
    end)

    CreateResizeGrip(frame)

    -- Character now has 2 lines (Line 2 = Shard + Move Speed)
    CreateSection(frame, "Character",   "Character",            2)
    CreateSection(frame, "Gold",        "Gold & Economy",       3)
    CreateSection(frame, "Inventory",   "Inventory & Currency", 3)

    addon:UpdateBackground()
    addon:UpdateTitleBar()
    addon:SafeLayoutHUD()
end

-----------------------------------------------------------------------
-- Background and title bar visibility
-----------------------------------------------------------------------

function addon:UpdateBackground()
    local show = self.db.profile.showBackground
    local opacity = self.db.profile.backgroundOpacity or 0.30
    local alpha = show and opacity or 0.0

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

    UpdateResizeGripVisibility()

    if HUD.minimized then
        for _, key in ipairs(HUD.order) do
            local section = HUD.sections[key]
            if section then
                if section.header then section.header:Hide() end
                if section.toggle then section.toggle:Hide() end
                for _, fs in ipairs(section.lines) do
                    fs:Hide()
                end
                if key == "Gold" and section.sessionResetBtn and section.sessionPauseBtn then
                    section.sessionResetBtn:Hide()
                    section.sessionPauseBtn:Hide()
                end
            end
        end

        local h = HUD.titleBar and HUD.titleBar:IsShown() and HUD.titleBar:GetHeight() or addon.CONST.TITLEBAR_HEIGHT
        frame:SetHeight(h + 4)

        if HUD.resizeGrip then
            HUD.resizeGrip:Hide()
        end
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

            if key == "Gold" and section.sessionResetBtn then
                section.sessionResetBtn:Hide()
            end

            if collapsed then
                for _, fs in ipairs(section.lines) do
                    fs:Hide()
                end
                if key == "Gold" and section.sessionResetBtn and section.sessionPauseBtn then
                    section.sessionResetBtn:Hide()
                    section.sessionPauseBtn:Hide()
                end
                if key == "Inventory" and section.bagSlotsTooltipBtn then
                    section.bagSlotsTooltipBtn:Hide()
                end
            else
                for i, fs in ipairs(section.lines) do
                    local text = fs:GetText()
                    if text and text ~= "" then
                        fs:Show()
                        fs:SetFontObject(bodyFont)
                        fs:ClearAllPoints()
                        fs:SetPoint("TOPLEFT", frame, "TOPLEFT", db.showHeaders and 18 or 6, y)

                        local rightPad = -6

                        if key == "Gold" and i == 2 and section.sessionResetBtn and section.sessionPauseBtn then
                            local elem = db.elements or {}
                            local showButtons = (elem.goldSession ~= false)

                            if showButtons then
                                if section.UpdatePauseButtonTexture then
                                    section.UpdatePauseButtonTexture()
                                end

                                section.sessionResetBtn:Show()
                                section.sessionPauseBtn:Show()

                                section.sessionResetBtn:ClearAllPoints()
                                section.sessionResetBtn:SetPoint("RIGHT", frame, "RIGHT", -6, 0)
                                section.sessionResetBtn:SetPoint("CENTER", fs, "CENTER", section.sessionResetBtn:GetWidth() / 2, 0)

                                section.sessionPauseBtn:ClearAllPoints()
                                section.sessionPauseBtn:SetPoint("RIGHT", section.sessionResetBtn, "LEFT", -4, 0)

                                local totalButtonWidth = section.sessionResetBtn:GetWidth() + section.sessionPauseBtn:GetWidth() + 4
                                rightPad = -(6 + totalButtonWidth + 6)
                            else
                                section.sessionResetBtn:Hide()
                                section.sessionPauseBtn:Hide()
                            end
                        end

                        fs:SetPoint("RIGHT", frame, "RIGHT", rightPad, 0)

                        -- Position Inventory tooltip button over Line 2 (bag slots)
                        if key == "Inventory" and i == 2 and section.bagSlotsTooltipBtn then
                            local elem = db.elements or {}
                            if elem.invBagSlots ~= false then
                                section.bagSlotsTooltipBtn:ClearAllPoints()
                                section.bagSlotsTooltipBtn:SetPoint("TOPLEFT", fs, "TOPLEFT", 0, 0)
                                section.bagSlotsTooltipBtn:SetPoint("BOTTOMRIGHT", fs, "BOTTOMRIGHT", 0, 0)
                            end
                        end

                        local lineSpacing = 2
                        -- Add extra spacing for Inventory section
                        if key == "Inventory" then
                            lineSpacing = 4
                        end

                        y = y - fs:GetStringHeight() - lineSpacing
                    else
                        fs:Hide()
                    end
                end
            end

            if key == "Gold" and section.sessionResetBtn and section.sessionPauseBtn then
                local elem = db.elements or {}
                local sessionText = section.lines[2] and section.lines[2]:GetText() or ""
                local showButtons = (elem.goldSession ~= false) and (not collapsed) and (sessionText ~= "")
                if not showButtons then
                    section.sessionResetBtn:Hide()
                    section.sessionPauseBtn:Hide()
                end
            end

            y = y - 4
        elseif section then
            section.header:Hide()
            section.toggle:Hide()
            for _, fs in ipairs(section.lines) do
                fs:Hide()
            end
            if key == "Gold" and section.sessionResetBtn and section.sessionPauseBtn then
                section.sessionResetBtn:Hide()
                section.sessionPauseBtn:Hide()
            end
            if key == "Inventory" and section.bagSlotsTooltipBtn then
                section.bagSlotsTooltipBtn:Hide()
            end
        end
    end

    local bottomPadding = 6
    if not db.lockFrame and HUD.resizeGrip then
        bottomPadding = 18
    end

    local totalHeight = math.abs(y) + bottomPadding
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
        if self.trackerFrame then self.trackerFrame:Hide() end
        if self.currencyFrame then self.currencyFrame:Hide() end
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
        self:SetSecureFrameVisible(HUD.frame, false)
        self:SetSecureFrameVisible(self.trackerFrame, false)
        self:SetSecureFrameVisible(self.currencyFrame, false)
        self:SetSecureFrameVisible(self.utilityBar, false)
        return
    end

    self:SetSecureFrameVisible(HUD.frame, true)

    if self.trackerFrame then
        self:SetSecureFrameVisible(self.trackerFrame, db.showTracker ~= false)
    end

    if self.currencyFrame then
        self:SetSecureFrameVisible(self.currencyFrame, db.showCurrencyTracker ~= false)
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
