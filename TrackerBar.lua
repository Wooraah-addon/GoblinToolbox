-- TrackerBar.lua
-- Item tracker bar: displays tracked item icons with bag counts

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
        local db = addon.db and addon.db.profile
        if not db then
            return
        end
        local point, _, relPoint, xOfs, yOfs = parent:GetPoint(1)
        if point and relPoint and xOfs and yOfs then
            db.trackerPoint, db.trackerRelPoint, db.trackerXOfs, db.trackerYOfs =
                point, relPoint, xOfs, yOfs
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
-- Tracker frame creation
-----------------------------------------------------------------------

function addon:CreateTrackerFrame()
    if self.trackerFrame then
        return
    end

    local f = CreateFrame("Frame", "GoblinToolboxTracker", UIParent, "BackdropTemplate")
    self.trackerFrame = f

    f:SetSize(260, 34)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    
    f:SetScript("OnDragStart", function(frame)
        if addon.db.profile.lockFrame then
            return
        end
        frame:StartMoving()
    end)
    
    f:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        local db = addon.db and addon.db.profile
        if not db then
            return
        end
        local point, _, relPoint, xOfs, yOfs = frame:GetPoint(1)
        if point and relPoint and xOfs and yOfs then
            db.trackerPoint, db.trackerRelPoint, db.trackerXOfs, db.trackerYOfs =
                point, relPoint, xOfs, yOfs
        end
    end)

    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile     = true, tileSize = 16, edgeSize = 2,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    f:SetBackdropBorderColor(0.2, 0.3, 0.2, 1)  -- Green-grey tint for item tracker bar

    -- FIXED: Default anchor should be below Utility Bar (if exists), else below HUD
    -- Order: HUD -> Utility -> Tracker -> Currency
    local db = addon.db.profile
    if db.trackerPoint and db.trackerRelPoint and db.trackerXOfs and db.trackerYOfs then
        f:SetPoint(db.trackerPoint, UIParent, db.trackerRelPoint, db.trackerXOfs, db.trackerYOfs)
    elseif self.utilityBar and self.utilityBar:IsShown() then
        f:SetPoint("TOPLEFT", self.utilityBar, "BOTTOMLEFT", 0, -8)
    elseif addon.HUD and addon.HUD.frame then
        f:SetPoint("TOPLEFT", addon.HUD.frame, "BOTTOMLEFT", 0, -8)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    f.buttons = {}

    -- Enable item drag-and-drop
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnReceiveDrag", function(self)
        local infoType, itemID = GetCursorInfo()
        if infoType == "item" and itemID then
            ClearCursor()
            addon:AddTrackedItem(tostring(itemID))
        end
    end)

    -- Create "add" button - always visible, 70% size of regular buttons, 50% opacity
    f.addButton = CreateFrame("Button", nil, f)
    local buttonSize = addon.CONST.BUTTON_SIZE_SMALL
    local addButtonSize = buttonSize * 0.7
    f.addButton:SetSize(addButtonSize, addButtonSize)
    f.addButton:SetPoint("LEFT", f, "LEFT", 4, 0)
    f.addButton:SetAlpha(0.5)  -- 50% opacity
    
    local addIcon = f.addButton:CreateTexture(nil, "ARTWORK")
    addIcon:SetAllPoints(true)
    addIcon:SetTexture("Interface\\Buttons\\UI-PlusButton-Up")
    addIcon:SetVertexColor(0.2, 1, 0.2)  -- Bright green tint
    f.addButton.icon = addIcon
    
    f.addButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Goblin Toolbox: Add Items to Track", 1, 1, 1)
        GameTooltip:AddLine("Drag items from bags onto this icon to add to tracking", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("Or use: /gtb add [item link]", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    
    f.addButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    f.addButton:SetScript("OnClick", function()
        -- Insert chat command template
        local editBox = ChatEdit_ChooseBoxForSend()
        ChatEdit_ActivateChat(editBox)
        editBox:SetText("/gtb add ")
    end)
    
    -- Enable drag-and-drop on the add button too
    f.addButton:SetScript("OnReceiveDrag", function(self)
        local infoType, itemID = GetCursorInfo()
        if infoType == "item" and itemID then
            ClearCursor()
            addon:AddTrackedItem(tostring(itemID))
        end
    end)
    
    f.addButton:Hide()  -- Start hidden, will be shown in UpdateTrackedBar

    -- Create drag handle indicator
    f.dragHandle = CreateDragHandle(f)

    self:UpdateBackground()
    self:UpdateTrackedBar()
end

-----------------------------------------------------------------------
-- Tracker bar update
-----------------------------------------------------------------------

function addon:UpdateTrackedBar()
    local db = self.db and self.db.profile
    if not db or db.showTracker == false then
        if self.trackerFrame then
            self.trackerFrame:Hide()
        end
        return
    end

    if not self.trackerFrame then
        return
    end

    local f = self.trackerFrame

    -- Respect global HUD visibility settings
    if not db.enabled then
        f:Hide()
        return
    end

    -- Check if we should hide due to combat/instances
    if db.hideInCombat and UnitAffectingCombat("player") then
        f:Hide()
        return
    end

    if db.hideInInstances then
        local inInstance, instanceType = IsInInstance()
        if inInstance and instanceType ~= "none" then
            f:Hide()
            return
        end
    end

    f:Show()
    
    -- Update drag handle color if it exists
    if f.dragHandle and f.dragHandle.UpdateColor then
        f.dragHandle:UpdateColor()
    end

    f.buttons = f.buttons or {}

    local tracked = db.trackedItems or {}
    local numTracked = #tracked

    if numTracked == 0 then
        for _, b in ipairs(f.buttons) do
            b:Hide()
        end
        -- Show add button and resize to just fit it
        if f.addButton then
            f.addButton:Show()
            local padding = addon.CONST.PADDING
            local addButtonSize = addon.CONST.BUTTON_SIZE_SMALL * 0.7
            f:SetSize(padding * 2 + addButtonSize, padding * 2 + addButtonSize)
        end
        return
    end

    -- Always show add button when tracking items
    if f.addButton then
        f.addButton:Show()
    end

    local buttonSize = addon.CONST.BUTTON_SIZE_SMALL
    local spacing = addon.CONST.SPACING_SMALL
    local padding = addon.CONST.PADDING

    for i = 1, numTracked do
        if not f.buttons[i] then
            local btn = CreateFrame("Button", nil, f)
            btn:SetSize(buttonSize, buttonSize)

            btn.icon = btn:CreateTexture(nil, "ARTWORK")
            btn.icon:SetAllPoints(true)

            btn.count = btn:CreateFontString(nil, "OVERLAY")
            btn.count:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
            btn.count:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
            btn.count:SetTextColor(1, 1, 1)
            btn.count:SetShadowOffset(1, -1)
            btn.count:SetShadowColor(0, 0, 0, 1)

            btn:RegisterForClicks("AnyUp")

            btn:SetScript("OnEnter", function(selfBtn)
                if not selfBtn.itemID then
                    return
                end
                GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
                GameTooltip:SetItemByID(selfBtn.itemID)
                GameTooltip:Show()
            end)

            btn:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)

            btn:SetScript("OnMouseUp", function(selfBtn, mouseButton)
                if mouseButton == "RightButton" and IsShiftKeyDown() and selfBtn.itemID then
                    addon:RemoveTrackedItem(selfBtn.itemID)
                end
            end)

            f.buttons[i] = btn
        end
    end

    for i = numTracked + 1, #f.buttons do
        f.buttons[i]:Hide()
    end

    -- Calculate width: padding + add button + spacing + items
    local addButtonSize = buttonSize * 0.7
    local totalWidth = padding + addButtonSize + spacing + (numTracked * buttonSize) + ((numTracked - 1) * spacing) + padding
    f:SetSize(totalWidth, buttonSize + padding * 2)

    local prev = f.addButton  -- Start positioning after the add button
    for i, itemID in ipairs(tracked) do
        local btn = f.buttons[i]
        btn.itemID = itemID

        btn:ClearAllPoints()
        btn:SetPoint("LEFT", prev, "RIGHT", spacing, 0)
        prev = btn

        local icon = addon.API.GetItemIcon(itemID)
        btn.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")

        local count = 0
        if addon.trackedCounts and addon.trackedCounts[itemID] then
            count = addon.trackedCounts[itemID]
        end
        btn.count:SetText(count > 0 and tostring(count) or "")

        btn:Show()
    end
end

-----------------------------------------------------------------------
-- Tracking list management
-----------------------------------------------------------------------

function addon:AddTrackedItem(input)
    if not input or input == "" then
        print("Goblin Toolbox: usage /gtb add [item link or currency name]")
        return
    end

    -- First try as an item
    local itemID
    if tonumber(input) then
        itemID = tonumber(input)
    else
        itemID = select(1, GetItemInfoInstant(input))
    end

    -- If we found an item, add it to item tracker
    if itemID then
        local list = self.db.profile.trackedItems
        for _, id in ipairs(list) do
            if id == itemID then
                print("Goblin Toolbox: already tracking that item.")
                self:UpdateTrackedBar()
                return
            end
        end

        table.insert(list, itemID)
        print("Goblin Toolbox: tracking item", itemID)
        self:UpdateTrackedBar()
        return
    end

    -- Not an item, try as a currency
    self:AddTrackedCurrency(input)
end

function addon:RemoveTrackedItem(itemID)
    if not itemID then
        return
    end
    local list = self.db.profile.trackedItems
    for i, id in ipairs(list) do
        if id == itemID then
            table.remove(list, i)
            print("Goblin Toolbox: stopped tracking item", itemID)
            break
        end
    end
    self:UpdateTrackedBar()
end
