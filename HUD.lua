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
    frame:SetScale(addon.db.global.scale or 1.0)

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

function addon:RestoreHUDPosition()
    local frame = self.HUD and self.HUD.frame
    if not frame then return end

    local db = self.db.profile
    if db.point and db.relPoint and db.xOfs and db.yOfs then
        frame:ClearAllPoints()
        frame:SetPoint(db.point, UIParent, db.relPoint, db.xOfs, db.yOfs)
    else
        -- No saved position, use default
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10, -120)
    end

    -- Also restore width if available
    if db.hudWidth then
        frame:SetWidth(db.hudWidth)
    end
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
        if addon.db.profile.lockFrame or HUD.minimized then
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
                addon:SafeLayoutHUD(true)  -- Immediate layout for user action completion
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
        addon:SafeLayoutHUD(true)  -- Immediate layout for user action
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

    if key == "Character" then
        -- Create invisible tooltip button for Shard ID line
        section.shardTooltipBtn = CreateFrame("Button", nil, frame)
        section.shardTooltipBtn:SetSize(1, 1)
        section.shardTooltipBtn:Hide()
        section.shardTooltipBtn:EnableMouse(true)

        section.shardTooltipBtn:SetScript("OnEnter", function(self)
            if HUD.minimized then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Shard ID", 1, 1, 1)
            GameTooltip:AddLine("WoW splits busy zones into multiple parallel instances ('shards'). This shows which one you're on. If ShardID shows as \"Unknown\", click on an NPC to update it.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        section.shardTooltipBtn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
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
            if HUD.minimized then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Reset Session")
            GameTooltip:AddLine("Resets session start gold and timer.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        section.sessionResetBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        section.sessionResetBtn:SetScript("OnClick", function()
            addon:ResetSession()
            addon:UpdateGoldSection()
            addon:SafeLayoutHUD(true)  -- Immediate layout for user action
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
            if HUD.minimized then return end
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
            addon:SafeLayoutHUD(true)  -- Immediate layout for user action
        end)

        section.UpdatePauseButtonTexture = UpdatePauseButtonTexture
        UpdatePauseButtonTexture()

        -- Create timer display fontstring (positioned to left of pause button)
        section.sessionTimerDisplay = frame:CreateFontString(nil, "OVERLAY")
        section.sessionTimerDisplay:SetFontObject(addon:GetBodyFont())
        section.sessionTimerDisplay:SetJustifyH("RIGHT")
        section.sessionTimerDisplay:Hide()

        -- Create invisible tooltip button for token line
        section.tokenTooltipBtn = CreateFrame("Button", nil, frame)
        section.tokenTooltipBtn:SetSize(1, 1)  -- Will be resized in layout
        section.tokenTooltipBtn:Hide()
        section.tokenTooltipBtn:EnableMouse(true)

        section.tokenTooltipBtn:SetScript("OnEnter", function(self)
            if HUD.minimized then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("WoW Token Price", 1, 1, 1)

            local tokenPrice = addon.token and addon.token.lastPrice or 0
            local lastUpdated = addon.token and addon.token.lastUpdated or 0

            if tokenPrice > 0 then
                GameTooltip:AddLine(string.format("Current: %s", addon:FormatMoney(tokenPrice)), 1, 1, 1)

                if lastUpdated > 0 then
                    local ago = time() - lastUpdated
                    local agoMin = math.floor(ago / 60)
                    if agoMin < 1 then
                        GameTooltip:AddLine("Updated: just now", 0.8, 0.8, 0.8)
                    elseif agoMin < 60 then
                        GameTooltip:AddLine(string.format("Updated: %dm ago", agoMin), 0.8, 0.8, 0.8)
                    else
                        GameTooltip:AddLine(string.format("Updated: %dh %dm ago", math.floor(agoMin / 60), agoMin % 60), 0.8, 0.8, 0.8)
                    end
                end

                local Gold = addon:GetModule("Gold")
                if Gold then
                    local trend = Gold:GetTokenTrend()
                    if trend == "up" then
                        GameTooltip:AddLine("|cff00ff00▲ Price trending up|r", 1, 1, 1)
                    elseif trend == "down" then
                        GameTooltip:AddLine("|cffff4444▼ Price trending down|r", 1, 1, 1)
                    else
                        GameTooltip:AddLine("Price stable", 0.8, 0.8, 0.8)
                    end
                end

                GameTooltip:AddLine(" ", 1, 1, 1)
                GameTooltip:AddLine("Trend compares avg of last 3 vs previous 3 token updates.", 0.6, 0.6, 0.6, true)
            else
                GameTooltip:AddLine("Price not available", 0.8, 0.8, 0.8)
            end

            GameTooltip:Show()
        end)
        section.tokenTooltipBtn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        -- Create invisible tooltip button for Earned line
        section.earnedTooltipBtn = CreateFrame("Button", nil, frame)
        section.earnedTooltipBtn:SetSize(1, 1)
        section.earnedTooltipBtn:Hide()
        section.earnedTooltipBtn:EnableMouse(true)

        section.earnedTooltipBtn:SetScript("OnEnter", function(self)
            if HUD.minimized then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Session Earned", 1, 1, 1)
            GameTooltip:AddLine("Tracks gold gained during the current session from all sources (quest rewards, vendor sales, mail, etc.). Only positive gold changes are counted.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        section.earnedTooltipBtn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        -- Create invisible tooltip button for Looted line
        section.lootedTooltipBtn = CreateFrame("Button", nil, frame)
        section.lootedTooltipBtn:SetSize(1, 1)
        section.lootedTooltipBtn:Hide()
        section.lootedTooltipBtn:EnableMouse(true)

        section.lootedTooltipBtn:SetScript("OnEnter", function(self)
            if HUD.minimized then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Looted Value", 1, 1, 1)

            local priceSource = "vendor"
            if TSM_API and TSM_API.GetCustomPriceValue and addon.Inventory then
                priceSource = addon.Inventory:ResolveTSMLabel()
            end

            if priceSource == "vendor" then
                GameTooltip:AddLine("Tracks the estimated value of items you loot during the current session. Using vendor sell price (no TSM price source configured).", 0.8, 0.8, 0.8, true)
            else
                GameTooltip:AddLine(string.format("Tracks the estimated value of items you loot during the current session. Using TSM price source: %s. Falls back to vendor sell price when TSM price unavailable.", priceSource), 0.8, 0.8, 0.8, true)
            end

            GameTooltip:Show()
        end)
        section.lootedTooltipBtn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        -- Create invisible tooltip button for Posted Auctions line
        section.postedTooltipBtn = CreateFrame("Button", nil, frame)
        section.postedTooltipBtn:SetSize(1, 1)
        section.postedTooltipBtn:Hide()
        section.postedTooltipBtn:EnableMouse(true)

        section.postedTooltipBtn:SetScript("OnEnter", function(self)
            if HUD.minimized then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Posted Auctions", 1, 1, 1)
            GameTooltip:AddLine("Displays the total buyout value and count of your currently active auctions. Updates when you open the auction house or post new auctions. Uses Blizzard's auction data API.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        section.postedTooltipBtn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        -- Create invisible tooltip button for Session header line
        section.sessionHeaderTooltipBtn = CreateFrame("Button", nil, frame)
        section.sessionHeaderTooltipBtn:SetSize(1, 1)
        section.sessionHeaderTooltipBtn:Hide()
        section.sessionHeaderTooltipBtn:EnableMouse(true)

        section.sessionHeaderTooltipBtn:SetScript("OnEnter", function(self)
            if HUD.minimized then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Session Tracking", 1, 1, 1)
            GameTooltip:AddLine("Click the pause button to pause or resume session tracking. When paused, the icon turns red and tracking stops for both gold gains and looted item values. Configure auto-reset on logout or session persistence in the options menu.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        section.sessionHeaderTooltipBtn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    if key == "Inventory" then
        -- Create invisible tooltip button for Bag Value line
        section.bagValueTooltipBtn = CreateFrame("Button", nil, frame)
        section.bagValueTooltipBtn:SetSize(1, 1)
        section.bagValueTooltipBtn:Hide()
        section.bagValueTooltipBtn:EnableMouse(true)

        section.bagValueTooltipBtn:SetScript("OnEnter", function(self)
            if HUD.minimized then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Bag Value", 1, 1, 1)

            local priceSource = "vendor"
            if TSM_API and TSM_API.GetCustomPriceValue and addon.Inventory then
                priceSource = addon.Inventory:ResolveTSMLabel()
            end

            if priceSource == "vendor" then
                GameTooltip:AddLine("Total estimated value of all items in your bags. Using vendor sell price (no TSM price source configured).", 0.8, 0.8, 0.8, true)
            else
                GameTooltip:AddLine(string.format("Total estimated value of all items in your bags. Using TSM price source: %s. Falls back to vendor sell price when TSM price unavailable.", priceSource), 0.8, 0.8, 0.8, true)
            end

            GameTooltip:Show()
        end)
        section.bagValueTooltipBtn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)


        -- Create invisible tooltip button for bag slots line
        section.bagSlotsTooltipBtn = CreateFrame("Button", nil, frame)
        section.bagSlotsTooltipBtn:SetSize(1, 1)  -- Will be resized in layout
        section.bagSlotsTooltipBtn:Hide()
        section.bagSlotsTooltipBtn:EnableMouse(true)
        
        section.bagSlotsTooltipBtn:SetScript("OnEnter", function(self)
            if HUD.minimized then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Free Normal Bag Slots / Free Reagent Bag Slots", 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        section.bagSlotsTooltipBtn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        -- Create invisible tooltip button for Warbank Access indicator line
        section.warbankTooltipBtn = CreateFrame("Button", nil, frame)
        section.warbankTooltipBtn:SetSize(1, 1)
        section.warbankTooltipBtn:Hide()
        section.warbankTooltipBtn:EnableMouse(true)

        section.warbankTooltipBtn:SetScript("OnEnter", function(self)
            if HUD.minimized then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Warbank Access Indicator", 1, 1, 1)
            GameTooltip:AddLine("The Warband Bank is shared across your Battle.net account. If you are logged in on multiple WoW clients simultaneously, this indicator will clearly show which of your clients has access to the Warband Bank.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        section.warbankTooltipBtn:SetScript("OnLeave", function()
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
        addon:SafeLayoutHUD(true)  -- Immediate layout for user action
    end)

    CreateResizeGrip(frame)

    -- Character now has 3 lines (Line 1 = Name + Realm + Account Label, Line 2 = Shard + Move Speed, Line 3 = Note)
    CreateSection(frame, "Character",   "Character",            3)
    CreateSection(frame, "Gold",        "Gold & Economy",       7)
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
    local opacity = self.db.global.backgroundOpacity or 0.30
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
                    if section.sessionTimerDisplay then
                        section.sessionTimerDisplay:Hide()
                    end
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
                if section.sessionTimerDisplay then
                    section.sessionTimerDisplay:Hide()
                end
            end

            if collapsed then
                for _, fs in ipairs(section.lines) do
                    fs:Hide()
                end
                if key == "Gold" and section.sessionResetBtn and section.sessionPauseBtn then
                    section.sessionResetBtn:Hide()
                    section.sessionPauseBtn:Hide()
                    if section.sessionTimerDisplay then
                        section.sessionTimerDisplay:Hide()
                    end
                end
                if key == "Character" then
                    if section.shardTooltipBtn then section.shardTooltipBtn:Hide() end
                end
                if key == "Gold" then
                    if section.postedTooltipBtn then section.postedTooltipBtn:Hide() end
                    if section.tokenTooltipBtn then section.tokenTooltipBtn:Hide() end
                    if section.sessionHeaderTooltipBtn then section.sessionHeaderTooltipBtn:Hide() end
                    if section.earnedTooltipBtn then section.earnedTooltipBtn:Hide() end
                    if section.lootedTooltipBtn then section.lootedTooltipBtn:Hide() end
                end
                if key == "Inventory" then
                    if section.bagValueTooltipBtn then section.bagValueTooltipBtn:Hide() end
                    if section.bagSlotsTooltipBtn then section.bagSlotsTooltipBtn:Hide() end
                    if section.warbankTooltipBtn then section.warbankTooltipBtn:Hide() end
                end
            else
                for i, fs in ipairs(section.lines) do
                    local text = fs:GetText()
                    if text and text ~= "" then
                        fs:Show()
                        fs:SetFontObject(bodyFont)
                        fs:ClearAllPoints()
                        fs:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, y)

                        local rightPad = -6

                        if key == "Gold" and i == 4 and section.sessionResetBtn and section.sessionPauseBtn then
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

                                -- Position timer display to the left of pause button
                                if section.sessionTimerDisplay then
                                    section.sessionTimerDisplay:Show()
                                    section.sessionTimerDisplay:SetFontObject(bodyFont)
                                    section.sessionTimerDisplay:ClearAllPoints()
                                    section.sessionTimerDisplay:SetPoint("RIGHT", section.sessionPauseBtn, "LEFT", -6, 0)
                                    section.sessionTimerDisplay:SetPoint("CENTER", fs, "CENTER", 0, 0)
                                end

                                local totalButtonWidth = section.sessionResetBtn:GetWidth() + section.sessionPauseBtn:GetWidth() + 4
                                rightPad = -(6 + totalButtonWidth + 6)
                            else
                                section.sessionResetBtn:Hide()
                                section.sessionPauseBtn:Hide()
                                if section.sessionTimerDisplay then
                                    section.sessionTimerDisplay:Hide()
                                end
                            end
                        end

                        fs:SetPoint("RIGHT", frame, "RIGHT", rightPad, 0)

                        -- Position Character tooltip buttons
                        if key == "Character" then
                            local elem = db.elements or {}

                            -- Shard ID tooltip (Line 2, only if ShardID or MoveSpeed is shown)
                            if i == 2 and section.shardTooltipBtn and (elem.charShardID ~= false or elem.charMovespeed ~= false) then
                                section.shardTooltipBtn:ClearAllPoints()
                                section.shardTooltipBtn:SetPoint("TOPLEFT", fs, "TOPLEFT", 0, 0)
                                section.shardTooltipBtn:SetPoint("BOTTOMRIGHT", fs, "BOTTOMRIGHT", 0, 0)
                                section.shardTooltipBtn:Show()
                            end
                        end

                        -- Position Inventory tooltip buttons
                        if key == "Inventory" then
                            local elem = db.elements or {}

                            -- Bag Value tooltip (Line 1)
                            if i == 1 and section.bagValueTooltipBtn and elem.invBagValue ~= false then
                                section.bagValueTooltipBtn:ClearAllPoints()
                                section.bagValueTooltipBtn:SetPoint("TOPLEFT", fs, "TOPLEFT", 0, 0)
                                section.bagValueTooltipBtn:SetPoint("BOTTOMRIGHT", fs, "BOTTOMRIGHT", 0, 0)
                                section.bagValueTooltipBtn:Show()
                            end

                            -- Bag Slots tooltip (Line 2)
                            if i == 2 and section.bagSlotsTooltipBtn and elem.invBagSlots ~= false then
                                section.bagSlotsTooltipBtn:ClearAllPoints()
                                section.bagSlotsTooltipBtn:SetPoint("TOPLEFT", fs, "TOPLEFT", 0, 0)
                                section.bagSlotsTooltipBtn:SetPoint("BOTTOMRIGHT", fs, "BOTTOMRIGHT", 0, 0)
                                section.bagSlotsTooltipBtn:Show()
                            end

                            -- Warbank Access tooltip (Line 3)
                            if i == 3 and section.warbankTooltipBtn and elem.invWarbank ~= false then
                                section.warbankTooltipBtn:ClearAllPoints()
                                section.warbankTooltipBtn:SetPoint("TOPLEFT", fs, "TOPLEFT", 0, 0)
                                section.warbankTooltipBtn:SetPoint("BOTTOMRIGHT", fs, "BOTTOMRIGHT", 0, 0)
                                section.warbankTooltipBtn:Show()
                            end
                        end

                        -- Position Gold tooltip buttons
                        if key == "Gold" then
                            local elem = db.elements or {}
                            local isDetailed = (db.goldViewMode == "detailed")

                            -- Posted Auctions tooltip (Line 2 always)
                            if i == 2 and section.postedTooltipBtn and elem.goldPostedAuctions ~= false then
                                section.postedTooltipBtn:ClearAllPoints()
                                section.postedTooltipBtn:SetPoint("TOPLEFT", fs, "TOPLEFT", 0, 0)
                                section.postedTooltipBtn:SetPoint("BOTTOMRIGHT", fs, "BOTTOMRIGHT", 0, 0)
                                section.postedTooltipBtn:Show()
                            end

                            -- Token tooltip (Line 3 always)
                            if i == 3 and section.tokenTooltipBtn and elem.goldToken ~= false then
                                section.tokenTooltipBtn:ClearAllPoints()
                                section.tokenTooltipBtn:SetPoint("TOPLEFT", fs, "TOPLEFT", 0, 0)
                                section.tokenTooltipBtn:SetPoint("BOTTOMRIGHT", fs, "BOTTOMRIGHT", 0, 0)
                                section.tokenTooltipBtn:Show()
                            end

                            -- Session header tooltip (Line 4 always)
                            if i == 4 and section.sessionHeaderTooltipBtn and elem.goldSession ~= false then
                                section.sessionHeaderTooltipBtn:ClearAllPoints()
                                section.sessionHeaderTooltipBtn:SetPoint("TOPLEFT", fs, "TOPLEFT", 0, 0)
                                section.sessionHeaderTooltipBtn:SetPoint("BOTTOMRIGHT", fs, "BOTTOMRIGHT", 0, 0)
                                section.sessionHeaderTooltipBtn:Show()
                            end

                            -- Earned tooltip (Line 5 in simple, Line 6 in detailed)
                            local earnedLine = isDetailed and 6 or 5
                            if i == earnedLine and section.earnedTooltipBtn and elem.goldSession ~= false then
                                section.earnedTooltipBtn:ClearAllPoints()
                                section.earnedTooltipBtn:SetPoint("TOPLEFT", fs, "TOPLEFT", 0, 0)
                                section.earnedTooltipBtn:SetPoint("BOTTOMRIGHT", fs, "BOTTOMRIGHT", 0, 0)
                                section.earnedTooltipBtn:Show()
                            end

                            -- Looted tooltip (Line 7 always)
                            if i == 7 and section.lootedTooltipBtn and elem.goldLootedValue ~= false then
                                section.lootedTooltipBtn:ClearAllPoints()
                                section.lootedTooltipBtn:SetPoint("TOPLEFT", fs, "TOPLEFT", 0, 0)
                                section.lootedTooltipBtn:SetPoint("BOTTOMRIGHT", fs, "BOTTOMRIGHT", 0, 0)
                                section.lootedTooltipBtn:Show()
                            end
                        end

                        local lineSpacing = 2
                        -- Add extra spacing for Inventory section
                        if key == "Inventory" then
                            lineSpacing = 4
                        end
                        -- Add extra spacing between Token (line 3) and Session (line 4) in Gold section
                        if key == "Gold" and i == 3 then
                            lineSpacing = 8
                        end

                        y = y - fs:GetStringHeight() - lineSpacing
                    else
                        fs:Hide()
                    end
                end
            end

            if key == "Gold" and section.sessionResetBtn and section.sessionPauseBtn then
                local elem = db.elements or {}
                local sessionText = section.lines[4] and section.lines[4]:GetText() or ""
                local showButtons = (elem.goldSession ~= false) and (not collapsed) and (sessionText ~= "")
                if not showButtons then
                    section.sessionResetBtn:Hide()
                    section.sessionPauseBtn:Hide()
                    if section.sessionTimerDisplay then
                        section.sessionTimerDisplay:Hide()
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
            if key == "Gold" and section.sessionResetBtn and section.sessionPauseBtn then
                section.sessionResetBtn:Hide()
                section.sessionPauseBtn:Hide()
                if section.sessionTimerDisplay then
                    section.sessionTimerDisplay:Hide()
                end
            end
            if key == "Character" then
                if section.shardTooltipBtn then section.shardTooltipBtn:Hide() end
            end
            if key == "Gold" then
                if section.postedTooltipBtn then section.postedTooltipBtn:Hide() end
                if section.tokenTooltipBtn then section.tokenTooltipBtn:Hide() end
                if section.sessionHeaderTooltipBtn then section.sessionHeaderTooltipBtn:Hide() end
                if section.earnedTooltipBtn then section.earnedTooltipBtn:Hide() end
                if section.lootedTooltipBtn then section.lootedTooltipBtn:Hide() end
            end
            if key == "Inventory" then
                if section.bagValueTooltipBtn then section.bagValueTooltipBtn:Hide() end
                if section.bagSlotsTooltipBtn then section.bagSlotsTooltipBtn:Hide() end
                if section.warbankTooltipBtn then section.warbankTooltipBtn:Hide() end
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
        HUD.frame:Hide()
        if self.trackerFrame then self.trackerFrame:Hide() end
        if self.currencyFrame then self.currencyFrame:Hide() end
        self:SetSecureFrameVisible(self.utilityBar, false)
        return
    end

    HUD.frame:Show()

    if self.trackerFrame then
        if db.showTracker ~= false then
            self.trackerFrame:Show()
        else
            self.trackerFrame:Hide()
        end
    end

    if self.currencyFrame then
        if db.showCurrencyTracker ~= false then
            self.currencyFrame:Show()
        else
            self.currencyFrame:Hide()
        end
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
