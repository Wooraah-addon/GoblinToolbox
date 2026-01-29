-- CurrencyBar.lua
-- Currency tracker bar: displays tracked currencies with icons and counts

local addonName, addon = ...

-----------------------------------------------------------------------
-- Drag handle indicator (Hardware LED design)
-----------------------------------------------------------------------

local function CreateDragHandle(parent)
    -- Create button with larger invisible hitbox
    local handle = CreateFrame("Button", nil, parent)
    handle:SetSize(10, 10)  -- Visual size
    handle:SetPoint("TOPLEFT", parent, "TOPLEFT", 2, -2)
    handle:SetFrameLevel(1000)  -- Very high level to appear above Blizzard action bars

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

        local db = addon.db and addon.db.profile
        if not db then
            return
        end
        -- Save anchor position (not visual frame position)
        local point, relativeTo, relativePoint, xOfs, yOfs = anchor:GetPoint(1)
        if point then
            db.currencyPoint = point
            db.currencyRelPoint = relativePoint or "BOTTOMLEFT"
            db.currencyXOfs = xOfs
            db.currencyYOfs = yOfs
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
        -- Always ensure mouse is enabled
        self:EnableMouse(true)

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
-- Currency bar frame creation
-----------------------------------------------------------------------

function addon:CreateCurrencyFrame()
    if self.currencyFrame then
        return
    end

    -- Create unscaled anchor frame (position container)
    local anchor = CreateFrame("Frame", "GoblinToolboxCurrencyAnchor", UIParent)
    self.currencyAnchor = anchor
    anchor:SetSize(1, 1)
    anchor:SetMovable(true)
    anchor:SetClampedToScreen(true)
    -- Never scale the anchor

    -- Create scaled visual frame (content container)
    local f = CreateFrame("Frame", "GoblinToolboxCurrencyTracker", anchor, "BackdropTemplate")
    self.currencyFrame = f

    f:SetSize(260, 34)
    f:SetFrameStrata("MEDIUM")  -- Same as Blizzard action bars
    -- Don't clamp visual frame - anchor handles clamping
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")

    f:SetScript("OnDragStart", function(frame)
        if addon.db.profile.lockFrame then
            return
        end
        -- Move the anchor, not the visual frame
        anchor:StartMoving()
    end)

    f:SetScript("OnDragStop", function(frame)
        -- Stop moving the anchor
        anchor:StopMovingOrSizing()
        local db = addon.db and addon.db.profile
        if not db then
            return
        end
        -- Save anchor position (not visual frame position)
        local point, relativeTo, relativePoint, xOfs, yOfs = anchor:GetPoint(1)
        if point then
            db.currencyPoint = point
            db.currencyRelPoint = relativePoint or "BOTTOMLEFT"
            db.currencyXOfs = xOfs
            db.currencyYOfs = yOfs
        end
    end)

    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile     = true, tileSize = 16, edgeSize = 2,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    f:SetBackdropBorderColor(0.35, 0.3, 0.2, 1)  -- Yellow-grey tint for currency tracker bar

    -- Position anchor frame from saved vars
    local db = addon.db.profile
    local growX = db.currencyGrowX or "RIGHT"
    local growY = db.currencyGrowY or "DOWN"
    local anchorPoint = db.currencyPoint or addon:GetAnchorFromGrowth(growX, growY)
    local relativePoint = db.currencyRelPoint or "BOTTOMLEFT"

    if db.currencyXOfs and db.currencyYOfs then
        anchor:SetPoint(anchorPoint, UIParent, relativePoint, db.currencyXOfs, db.currencyYOfs)
    else
        -- No saved position, use default (top-left corner of screen with offset)
        anchor:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10, -530)
    end

    -- Anchor visual frame to anchor container at growth corner
    local visualAnchor = addon:GetAnchorFromGrowth(growX, growY)
    f:ClearAllPoints()
    f:SetPoint(visualAnchor, anchor, visualAnchor, 0, 0)

    f.buttons = {}

    -- Create "add" button - always visible, 70% size of regular buttons, 50% opacity
    f.addButton = CreateFrame("Button", nil, f)
    local buttonSize = addon.CONST.BUTTON_SIZE_SMALL
    local addButtonSize = buttonSize * 0.7
    f.addButton:SetSize(addButtonSize, addButtonSize)
    f.addButton:SetPoint("LEFT", f, "LEFT", 4, 0)
    f.addButton:SetAlpha(0.5)  -- 50% opacity
    f.addButton:RegisterForDrag("LeftButton")  -- Enable drag to move bar

    local addIcon = f.addButton:CreateTexture(nil, "ARTWORK")
    addIcon:SetAllPoints(true)
    addIcon:SetTexture("Interface\\Buttons\\UI-PlusButton-Up")
    addIcon:SetVertexColor(1, 1, 0)  -- Pure yellow (full red, full green, no blue)
    f.addButton.icon = addIcon
    
    f.addButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("|cffffd100Goblin Toolbox: Add Currencies to Track|r")
        GameTooltip:AddLine("|cffd0d0d0Type in chat to add currencies to track: /gtb add [currency link]|r", 1, 1, 1, true)
        GameTooltip:AddLine("|cffd0d0d0Shift+Right-Click a tracked icon to remove it|r", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    
    f.addButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Drag to move bar
    f.addButton:SetScript("OnDragStart", function(self)
        -- Don't move if locked
        if addon.db and addon.db.profile and addon.db.profile.lockFrame then
            return
        end
        -- Move the anchor, not the visual frame
        anchor:StartMoving()
        self._gtbDidMove = true
    end)

    f.addButton:SetScript("OnDragStop", function(self)
        -- Stop moving the anchor
        anchor:StopMovingOrSizing()

        -- Save anchor position
        local db = addon.db and addon.db.profile
        if not db then
            return
        end

        -- Save anchor position (not visual frame position)
        local point, relativeTo, relativePoint, xOfs, yOfs = anchor:GetPoint(1)
        if point then
            db.currencyPoint = point
            db.currencyRelPoint = relativePoint or "BOTTOMLEFT"
            db.currencyXOfs = xOfs
            db.currencyYOfs = yOfs
        end
    end)

    f.addButton:SetScript("OnClick", function(self)
        -- Prevent click after drag
        if self._gtbDidMove then
            self._gtbDidMove = false
            return
        end

        -- Insert chat command template
        local editBox = ChatEdit_ChooseBoxForSend()
        ChatEdit_ActivateChat(editBox)
        editBox:SetText("/gtb add ")
    end)
    
    f.addButton:Hide()  -- Start hidden, will be shown in UpdateCurrencyBar

    -- Create drag handle indicator
    f.dragHandle = CreateDragHandle(f)

    self:UpdateBackground()
    self:UpdateCurrencyBar()
end

function addon:RestoreCurrencyBarPosition()
    local anchor = self.currencyAnchor
    local f = self.currencyFrame
    if not anchor or not f then return end

    local db = self.db.profile
    local growX = db.currencyGrowX or "RIGHT"
    local growY = db.currencyGrowY or "DOWN"
    local anchorPoint = db.currencyPoint or addon:GetAnchorFromGrowth(growX, growY)
    local relativePoint = db.currencyRelPoint or "BOTTOMLEFT"

    -- Restore anchor position
    if db.currencyXOfs and db.currencyYOfs then
        anchor:ClearAllPoints()
        anchor:SetPoint(anchorPoint, UIParent, relativePoint, db.currencyXOfs, db.currencyYOfs)
    else
        -- No saved position, use fixed default
        anchor:ClearAllPoints()
        anchor:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10, -530)
    end

    -- Anchor visual frame to anchor container at growth corner
    local visualAnchor = addon:GetAnchorFromGrowth(growX, growY)
    f:ClearAllPoints()
    f:SetPoint(visualAnchor, anchor, visualAnchor, 0, 0)

    -- Initialize anchor cache to prevent unnecessary re-anchoring
    f._gtbLastDesiredAnchor = visualAnchor
end

-----------------------------------------------------------------------
-- Currency info helpers
-----------------------------------------------------------------------

-- Get currency info by ID
-- Returns: name, count, icon (or nils if invalid)
local function GetCurrencyData(currencyID)
    if not currencyID then
        return nil, nil, nil
    end

    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
        if info then
            return info.name, info.quantity, info.iconFileID
        end
    end

    return nil, nil, nil
end

-- Search for currency by name (partial match)
-- Returns currencyID or nil
local function FindCurrencyByName(searchName)
    if not searchName or searchName == "" then
        return nil
    end

    searchName = searchName:lower()

    -- First, try using the currency list the player has
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyListSize and C_CurrencyInfo.GetCurrencyListInfo then
        local numCurrencies = C_CurrencyInfo.GetCurrencyListSize()
        for i = 1, numCurrencies do
            local info = C_CurrencyInfo.GetCurrencyListInfo(i)
            if info and info.name and not info.isHeader then
                if info.name:lower():find(searchName, 1, true) then
                    -- Get the actual currency ID from the link
                    if info.currencyTypesID then
                        return info.currencyTypesID
                    end
                end
            end
        end
    end

    -- Fallback: brute force search through common currency ID ranges
    -- Try modern currency range first (3000-5000)
    for currencyID = 3000, 5000 do
        local name = GetCurrencyData(currencyID)
        if name and name:lower():find(searchName, 1, true) then
            return currencyID
        end
    end
    
    -- Try older currency range (1-3000)
    for currencyID = 1, 3000 do
        local name = GetCurrencyData(currencyID)
        if name and name:lower():find(searchName, 1, true) then
            return currencyID
        end
    end

    return nil
end

-----------------------------------------------------------------------
-- Helper to re-anchor frame based on current growth settings
-----------------------------------------------------------------------

local function UpdateAnchorFromGrowth(visualFrame, db)
    local growX = db.currencyGrowX or "RIGHT"
    local growY = db.currencyGrowY or "DOWN"
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
-- Currency bar update
-----------------------------------------------------------------------

function addon:UpdateCurrencyBar()
    local db = self.db and self.db.profile
    if not db then
        return
    end

    -- Check if currency tracker is enabled
    if db.showCurrencyTracker == false then
        if self.currencyFrame then
            self.currencyFrame:Hide()
        end
        return
    end

    if not self.currencyFrame then
        return
    end

    local f = self.currencyFrame

    -- Respect global HUD visibility settings
    if not db.enabled then
        f:Hide()
        return
    end

    -- Check hide in combat/instances/groups
    local shouldHide = false
    if db.hideInCombat and UnitAffectingCombat("player") then
        shouldHide = true
    end
    if db.hideInInstances then
        local inInstance, instanceType = IsInInstance()
        if inInstance and instanceType ~= "none" then
            shouldHide = true
        end
    end
    if db.hideWhenGrouped and IsInGroup() then
        shouldHide = true
    end

    if shouldHide then
        f:Hide()
        return
    end

    f:Show()
    
    -- Update drag handle color if it exists
    if f.dragHandle and f.dragHandle.UpdateColor then
        f.dragHandle:UpdateColor()
    end

    f.buttons = f.buttons or {}

    local tracked = db.trackedCurrencies or {}
    local numTracked = #tracked

    -- Get growth settings and update anchor if needed
    local growX = db.currencyGrowX or "RIGHT"
    local growY = db.currencyGrowY or "DOWN"
    UpdateAnchorFromGrowth(f, db)
    local anchorPoint = addon:GetAnchorFromGrowth(growX, growY)

    -- Buttons-per-row setting
    local buttonsPerRow = db.currencyButtonsPerRow or 30

    if numTracked == 0 then
        for _, b in ipairs(f.buttons) do
            b:Hide()
        end
        -- Show add button and resize to just fit it
        if f.addButton then
            f.addButton:Show()
            local padding = addon.CONST.PADDING
            local buttonSize = addon.CONST.BUTTON_SIZE_SMALL
            local addButtonSize = buttonSize * 0.7
            -- Use full buttonSize for both width and height so frame is square and doesn't shift when items are added
            f:SetSize(padding * 2 + buttonSize, buttonSize + padding * 2)

            -- Center the add button in the square frame
            local centerOffset = (buttonSize - addButtonSize) / 2
            f.addButton:ClearAllPoints()
            f.addButton:SetPoint("CENTER", f, "CENTER", 0, 0)
        end
        return
    end

    -- Always show add button when tracking currencies
    if f.addButton then
        f.addButton:Show()
    end

    local buttonSize = addon.CONST.BUTTON_SIZE_SMALL
    local spacing = addon.CONST.SPACING_SMALL
    local padding = addon.CONST.PADDING
    local addButtonSize = buttonSize * 0.7

    -- Create buttons as needed
    for i = 1, numTracked do
        if not f.buttons[i] then
            local btn = CreateFrame("Button", nil, f)
            btn:SetSize(buttonSize, buttonSize)

            btn.icon = btn:CreateTexture(nil, "ARTWORK")
            btn.icon:SetAllPoints(true)

            btn.count = btn:CreateFontString(nil, "OVERLAY")
            btn.count:SetPoint("CENTER", btn, "CENTER", 0, 0)
            btn.count:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
            btn.count:SetTextColor(1, 1, 1)
            btn.count:SetShadowOffset(1, -1)
            btn.count:SetShadowColor(0, 0, 0, 1)

            btn:RegisterForClicks("AnyUp")

            btn:SetScript("OnEnter", function(selfBtn)
                if not selfBtn.currencyID then
                    return
                end
                GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
                GameTooltip:SetCurrencyByID(selfBtn.currencyID)
                GameTooltip:Show()
            end)

            btn:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)

            btn:SetScript("OnMouseUp", function(selfBtn, mouseButton)
                if mouseButton == "RightButton" and IsShiftKeyDown() and selfBtn.currencyID then
                    addon:RemoveTrackedCurrency(selfBtn.currencyID)
                end
            end)

            f.buttons[i] = btn
        end
    end

    -- Hide excess buttons
    for i = numTracked + 1, #f.buttons do
        f.buttons[i]:Hide()
    end

    -- Grid layout calculation
    -- Total slots = 1 (add button) + numTracked
    local nSlots = 1 + numTracked
    local bpr = math.min(buttonsPerRow, nSlots)  -- Clamp to actual slot count
    local cols = math.min(bpr, nSlots)
    local rows = math.ceil(nSlots / bpr)

    -- Frame size
    local step = buttonSize + spacing
    local frameWidth = padding * 2 + (cols * buttonSize) + ((cols - 1) * spacing)
    local frameHeight = padding * 2 + (rows * buttonSize) + ((rows - 1) * spacing)
    f:SetSize(frameWidth, frameHeight)

    -- Offset signs based on anchor
    local xSign = (anchorPoint:find("LEFT") and 1) or -1
    local ySign = (anchorPoint:find("TOP") and -1) or 1

    -- Position add button (slot 0) - centered in its cell since it's smaller
    local addRow = math.floor(0 / bpr)
    local addCol = 0 % bpr
    local addOffset = (buttonSize - addButtonSize) / 2  -- Center offset
    local addX = xSign * (padding + addCol * step + addOffset)
    local addY = ySign * (padding + addRow * step + addOffset)
    f.addButton:ClearAllPoints()
    f.addButton:SetPoint(anchorPoint, f, anchorPoint, addX, addY)

    -- Position and update currency buttons (slots 1+)
    for i, currencyID in ipairs(tracked) do
        local btn = f.buttons[i]
        btn.currencyID = currencyID

        local slot = i  -- Slot 1 is the first currency
        local row = math.floor(slot / bpr)
        local col = slot % bpr
        local x = xSign * (padding + col * step)
        local y = ySign * (padding + row * step)

        btn:ClearAllPoints()
        btn:SetPoint(anchorPoint, f, anchorPoint, x, y)

        local name, count, icon = GetCurrencyData(currencyID)

        btn.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")

        -- Format count (abbreviate large numbers)
        local countText = ""
        if count then
            if count >= 1000000 then
                countText = string.format("%.1fM", count / 1000000)
            elseif count >= 10000 then
                countText = string.format("%.0fK", count / 1000)
            elseif count >= 1000 then
                countText = string.format("%.1fK", count / 1000)
            elseif count > 0 then
                countText = tostring(count)
            end
        end
        btn.count:SetText(countText)

        btn:Show()
    end
end

-----------------------------------------------------------------------
-- Currency tracking management
-----------------------------------------------------------------------

function addon:AddTrackedCurrency(input)
    if not input or input == "" then
        print("Goblin Toolbox: usage /gtb addcurrency [currency name or ID]")
        print("Tip: You can shift-click a currency in your Currency tab, or use the ID number")
        return
    end

    local currencyID

    -- Try to extract currency ID from a currency link
    local linkID = input:match("currency:(%d+)")
    if linkID then
        currencyID = tonumber(linkID)
    end

    -- Check if input is a number (currency ID)
    if not currencyID and tonumber(input) then
        currencyID = tonumber(input)
    end

    -- If we have an ID, validate and add it
    if currencyID then
        local name = GetCurrencyData(currencyID)
        if not name then
            print("Goblin Toolbox: currency ID", currencyID, "not found.")
            print("Tip: Open your Currency tab to find the exact currency name or ID")
            return
        end

        -- Initialize tracked currencies if needed
        local db = self.db.profile
        db.trackedCurrencies = db.trackedCurrencies or {}

        -- Check if already tracking
        for _, id in ipairs(db.trackedCurrencies) do
            if id == currencyID then
                print("Goblin Toolbox: already tracking", name or currencyID)
                return
            end
        end

        -- Add to tracked list
        table.insert(db.trackedCurrencies, currencyID)
        print("Goblin Toolbox: now tracking", name or currencyID)
        self:UpdateCurrencyBar()
        return
    end

    -- Try name search as last resort
    currencyID = FindCurrencyByName(input)
    if not currencyID then
        print("Goblin Toolbox: could not find currency matching '" .. input .. "'")
        print("Tip: Try using the currency ID number instead (e.g., /gtb addcurrency 3008)")
        return
    end

    -- Initialize tracked currencies if needed
    local db = self.db.profile
    db.trackedCurrencies = db.trackedCurrencies or {}

    -- Check if already tracking
    for _, id in ipairs(db.trackedCurrencies) do
        if id == currencyID then
            local name = GetCurrencyData(currencyID)
            print("Goblin Toolbox: already tracking", name or currencyID)
            return
        end
    end

    -- Add to tracked list
    table.insert(db.trackedCurrencies, currencyID)
    local name = GetCurrencyData(currencyID)
    print("Goblin Toolbox: now tracking", name or currencyID)

    self:UpdateCurrencyBar()
end

function addon:RemoveTrackedCurrency(currencyID)
    if not currencyID then
        return
    end

    local db = self.db.profile
    db.trackedCurrencies = db.trackedCurrencies or {}

    for i, id in ipairs(db.trackedCurrencies) do
        if id == currencyID then
            local name = GetCurrencyData(currencyID)
            table.remove(db.trackedCurrencies, i)
            print("Goblin Toolbox: stopped tracking", name or currencyID)
            break
        end
    end

    self:UpdateCurrencyBar()
end

-----------------------------------------------------------------------
-- List tracked currencies (helper command)
-----------------------------------------------------------------------

function addon:ListTrackedCurrencies()
    local db = self.db.profile
    local tracked = db.trackedCurrencies or {}

    if #tracked == 0 then
        print("Goblin Toolbox: not tracking any currencies.")
        print("  Use /gtb addcurrency [name or ID] to add one.")
        return
    end

    print("Goblin Toolbox: tracked currencies:")
    for _, currencyID in ipairs(tracked) do
        local name, count = GetCurrencyData(currencyID)
        if name then
            print(string.format("  [%d] %s: %s", currencyID, name, count or 0))
        else
            print(string.format("  [%d] (unknown currency)", currencyID))
        end
    end
end
