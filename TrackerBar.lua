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
        parent:StartMoving()
    end)
    
    handle:SetScript("OnDragStop", function(self)
        parent:StopMovingOrSizing()
        local db = addon.db and addon.db.profile
        if not db then
            return
        end
        -- Get current screen position and re-anchor to TOPLEFT
        local left = parent:GetLeft()
        local top = parent:GetTop()
        if left and top then
            -- Re-anchor frame to TOPLEFT so it grows right from fixed position
            parent:ClearAllPoints()
            parent:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
            -- Save position for persistence
            db.trackerPoint = "TOPLEFT"
            db.trackerRelPoint = "BOTTOMLEFT"
            db.trackerXOfs = left
            db.trackerYOfs = top
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
-- Tracker frame creation
-----------------------------------------------------------------------

function addon:CreateTrackerFrame()
    if self.trackerFrame then
        return
    end

    local f = CreateFrame("Frame", "GoblinToolboxTracker", UIParent, "BackdropTemplate")
    self.trackerFrame = f

    f:SetSize(260, 34)
    f:SetFrameStrata("MEDIUM")  -- Same as Blizzard action bars
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
        -- Get current screen position and re-anchor to TOPLEFT
        local left = frame:GetLeft()
        local top = frame:GetTop()
        if left and top then
            -- Re-anchor frame to TOPLEFT so it grows right from fixed position
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
            -- Save position for persistence
            db.trackerPoint = "TOPLEFT"
            db.trackerRelPoint = "BOTTOMLEFT"
            db.trackerXOfs = left
            db.trackerYOfs = top
        end
    end)

    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile     = true, tileSize = 16, edgeSize = 2,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    f:SetBackdropBorderColor(0.2, 0.3, 0.2, 1)  -- Green-grey tint for item tracker bar

    -- Default position: always use TOPLEFT anchor so bar grows right from fixed position
    local db = addon.db.profile
    if db.trackerXOfs and db.trackerYOfs then
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", db.trackerXOfs, db.trackerYOfs)
    else
        f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10, -475)
    end

    f.buttons = {}

    -- Enable item drag-and-drop
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnReceiveDrag", function(self)
        local infoType, itemID, itemLink = GetCursorInfo()
        if infoType == "item" and itemLink then
            ClearCursor()
            addon:AddTrackedItem(itemLink)
        elseif infoType == "item" and itemID then
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
    f.addButton:RegisterForDrag("LeftButton")  -- Enable drag-and-drop

    local addIcon = f.addButton:CreateTexture(nil, "ARTWORK")
    addIcon:SetAllPoints(true)
    addIcon:SetTexture("Interface\\Buttons\\UI-PlusButton-Up")
    addIcon:SetVertexColor(0.2, 1, 0.2)  -- Bright green tint
    f.addButton.icon = addIcon
    
    f.addButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("|cffffd100Goblin Toolbox: Add Items to Track|r")
        GameTooltip:AddLine("|cffd0d0d0Drag items from bags onto this icon to add to tracking|r", 1, 1, 1, true)
        GameTooltip:AddLine("|cffd0d0d0Or use: /gtb add [item link]|r", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    
    f.addButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    f.addButton:SetScript("OnClick", function(self, button)
        -- Check if there's an item on the cursor (drag-and-drop)
        local cursorType, itemID, itemLink = GetCursorInfo()
        if cursorType == "item" then
            -- Handle drag-and-drop
            if itemLink then
                ClearCursor()
                addon:AddTrackedItem(itemLink)
            elseif itemID then
                ClearCursor()
                addon:AddTrackedItem(tostring(itemID))
            end
        else
            -- No item on cursor, open chat with command template
            local editBox = ChatEdit_ChooseBoxForSend()
            ChatEdit_ActivateChat(editBox)
            editBox:SetText("/gtb add ")
        end
    end)

    -- Also handle OnReceiveDrag for completeness
    f.addButton:SetScript("OnReceiveDrag", function(self)
        local infoType, itemID, itemLink = GetCursorInfo()
        if infoType == "item" then
            if itemLink then
                ClearCursor()
                addon:AddTrackedItem(itemLink)
            elseif itemID then
                ClearCursor()
                addon:AddTrackedItem(tostring(itemID))
            end
        end
    end)

    f.addButton:Hide()  -- Start hidden, will be shown in UpdateTrackedBar

    -- Create source indicator text below the add button
    f.sourceIndicator = f:CreateFontString(nil, "OVERLAY")
    f.sourceIndicator:SetPoint("TOP", f.addButton, "BOTTOM", 0, 2)
    f.sourceIndicator:SetFont("Fonts\\FRIZQT__.TTF", 7, "OUTLINE")
    f.sourceIndicator:SetTextColor(0.7, 0.7, 0.7)
    f.sourceIndicator:SetShadowOffset(1, -1)
    f.sourceIndicator:SetShadowColor(0, 0, 0, 1)
    f.sourceIndicator:Hide()  -- Start hidden, will be shown/updated in UpdateTrackedBar

    -- Create drag handle indicator
    f.dragHandle = CreateDragHandle(f)

    self:UpdateBackground()
    self:UpdateTrackedBar()
end

function addon:RestoreTrackerBarPosition()
    local f = self.trackerFrame
    if not f then return end

    local db = self.db.profile
    if db.trackerXOfs and db.trackerYOfs then
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", db.trackerXOfs, db.trackerYOfs)
    else
        -- No saved position, use fixed default
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10, -475)
    end
end

-----------------------------------------------------------------------
-- Helper to ensure frame is anchored at TOPLEFT (so it grows right)
-----------------------------------------------------------------------

local function EnsureLeftAnchor(frame)
    local left = frame:GetLeft()
    local top = frame:GetTop()
    if left and top then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    end
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

    -- Update source indicator text
    local function UpdateSourceIndicator()
        if not f.sourceIndicator then
            return
        end

        local includeInv = db.trackerIncludeInventory ~= false
        local includePlayer = db.trackerIncludePlayerBank == true
        local includeWarband = db.trackerIncludeWarbandBank == true

        local text = ""
        if includeInv and not includePlayer and not includeWarband then
            text = "B"
        elseif includeInv and includePlayer and not includeWarband then
            text = "B+P"
        elseif includeInv and not includePlayer and includeWarband then
            text = "B+W"
        elseif includeInv and includePlayer and includeWarband then
            text = "B+P+W"
        elseif not includeInv and includePlayer and not includeWarband then
            text = "P"
        elseif not includeInv and not includePlayer and includeWarband then
            text = "W"
        elseif not includeInv and includePlayer and includeWarband then
            text = "P+W"
        else
            text = "NONE"
        end

        f.sourceIndicator:SetText(text)

        -- Update tooltip for source indicator
        if not f.sourceIndicator.hasTooltip then
            f.sourceIndicator.hasTooltip = true
            f.sourceIndicator:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("|cffffd100Item Count Sources|r")
                GameTooltip:AddLine("|cffd0d0d0B = Player Bags|r", 1, 1, 1, true)
                GameTooltip:AddLine("|cffd0d0d0P = Player Bank|r", 1, 1, 1, true)
                GameTooltip:AddLine("W = Warband Bank", 0.8, 0.8, 0.8, true)
                GameTooltip:AddLine(" ", 1, 1, 1)
                GameTooltip:AddLine("Configure in /gtb options", 0.6, 0.6, 0.6, true)
                GameTooltip:Show()
            end)
            f.sourceIndicator:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
        end

        f.sourceIndicator:Show()
    end

    if numTracked == 0 then
        for _, b in ipairs(f.buttons) do
            b:Hide()
        end
        -- Show add button and resize to just fit it
        if f.addButton then
            f.addButton:Show()
            UpdateSourceIndicator()
            local padding = addon.CONST.PADDING
            local buttonSize = addon.CONST.BUTTON_SIZE_SMALL
            local addButtonSize = buttonSize * 0.7
            -- Re-anchor to TOPLEFT before resize so bar grows right from fixed position
            EnsureLeftAnchor(f)
            -- Use full buttonSize for height so frame doesn't shift vertically when items are added
            f:SetSize(padding * 2 + addButtonSize, buttonSize + padding * 2)
        end
        return
    end

    -- Always show add button when tracking items
    if f.addButton then
        f.addButton:Show()
        UpdateSourceIndicator()
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

            -- Count text (center of icon, to avoid overlap with rank)
            btn.count = btn:CreateFontString(nil, "OVERLAY")
            btn.count:SetPoint("CENTER", btn, "CENTER", 0, 0)
            btn.count:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
            btn.count:SetTextColor(1, 1, 1)
            btn.count:SetShadowOffset(1, -1)
            btn.count:SetShadowColor(0, 0, 0, 1)

            -- Rank overlay (top-left)
            btn.rank = btn:CreateFontString(nil, "OVERLAY")
            btn.rank:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
            btn.rank:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
            btn.rank:SetTextColor(1, 1, 1)
            btn.rank:SetShadowOffset(1, -1)
            btn.rank:SetShadowColor(0, 0, 0, 1)

            -- Value text (bottom)
            btn.value = btn:CreateFontString(nil, "OVERLAY")
            btn.value:SetPoint("BOTTOM", btn, "BOTTOM", 0, 2)
            btn.value:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
            btn.value:SetTextColor(1, 0.82, 0)
            btn.value:SetShadowOffset(1, -1)
            btn.value:SetShadowColor(0, 0, 0, 1)

            btn:RegisterForClicks("AnyUp")

            btn:SetScript("OnEnter", function(selfBtn)
                if not selfBtn.entry then
                    return
                end
                local itemID = type(selfBtn.entry) == "table" and selfBtn.entry.itemID or selfBtn.entry
                if itemID then
                    GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
                    GameTooltip:SetItemByID(itemID)
                    GameTooltip:Show()
                end
            end)

            btn:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)

            btn:SetScript("OnMouseUp", function(selfBtn, mouseButton)
                if mouseButton == "RightButton" and IsShiftKeyDown() and selfBtn.entry then
                    addon:RemoveTrackedItem(selfBtn.entry)
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
    -- Re-anchor to TOPLEFT before resize so bar grows right from fixed position
    EnsureLeftAnchor(f)
    f:SetSize(totalWidth, buttonSize + padding * 2)

    local prev = f.addButton  -- Start positioning after the add button
    for i, entry in ipairs(tracked) do
        local btn = f.buttons[i]
        btn.entry = entry

        btn:ClearAllPoints()
        btn:SetPoint("LEFT", prev, "RIGHT", spacing, 0)
        prev = btn

        -- Parse entry (can be itemID or {itemID, rank})
        local itemID, rank
        if type(entry) == "table" then
            itemID = entry.itemID
            rank = entry.rank or 0
        else
            itemID = entry
            rank = 0
        end

        -- Set icon
        local icon = addon.API.GetItemIcon(itemID)
        btn.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")

        -- Get count using new total count accessor
        local key = tostring(itemID) .. ":" .. tostring(rank)
        local count = 0

        if addon.Inventory and addon.Inventory.GetTotalCountForKey then
            count = addon.Inventory:GetTotalCountForKey(key)
        else
            -- Fallback to old method if new method not available
            count = addon.Inventory and addon.Inventory:GetCountForTrackedEntry(entry) or 0
        end

        -- Format and set count text (center)
        local countText = addon.Inventory and addon.Inventory:FormatCount(count) or tostring(count)
        btn.count:SetText(countText)

        -- Keep count text white (visual indicator shows what's included)
        btn.count:SetTextColor(1, 1, 1)

        -- Set rank overlay (top-left)
        if rank > 0 and C_Texture and C_Texture.GetCraftingReagentQualityChatIcon then
            local rankIcon = C_Texture.GetCraftingReagentQualityChatIcon(rank)
            btn.rank:SetText(rankIcon or "")
        else
            btn.rank:SetText("")
        end

        -- Set value overlay (bottom)
        if db.showTrackedItemValue and count > 0 then
            -- Try to get an itemLink for better TSM price resolution
            local itemLink = nil
            if rank > 0 then
                -- For ranked items, try to construct or find a link with rank
                -- This is approximate - real itemLink from bags would be better, but harder to find
                itemLink = select(2, GetItemInfo(itemID))
            else
                -- For unranked items, get the base itemLink
                itemLink = select(2, GetItemInfo(itemID))
            end

            local unitPrice = addon.Inventory and addon.Inventory:GetUnitPrice(itemLink, itemID)
            if unitPrice and unitPrice > 0 then
                local totalValue = unitPrice * count
                local goldValue = math.floor(totalValue / 10000)
                local goldIcon = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:-4:0|t"
                local silverIcon = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:-4:0|t"
                local valueText
                if goldValue >= 1000 then
                    valueText = string.format("%.1fk%s", goldValue / 1000, goldIcon)
                elseif goldValue > 0 then
                    valueText = string.format("%d%s", goldValue, goldIcon)
                else
                    local silverValue = math.floor((totalValue % 10000) / 100)
                    valueText = string.format("%d%s", silverValue, silverIcon)
                end
                btn.value:SetText(valueText)
            else
                btn.value:SetText("N/A")
            end
        else
            btn.value:SetText("")
        end

        btn:Show()
    end
end

-----------------------------------------------------------------------
-- Tracking list management
-----------------------------------------------------------------------

function addon:AddTrackedItem(input)
    if not input or input == "" then
        print("Goblin Toolbox: usage /gtb add [item link]")
        return
    end

    -- First try as an item
    local itemID
    local itemLink = input

    if tonumber(input) then
        itemID = tonumber(input)
        itemLink = nil
    else
        itemID = select(1, GetItemInfoInstant(input))
    end

    -- If we found an item, add it to item tracker
    if itemID then
        -- Detect rank if available
        local rank = addon.Inventory and addon.Inventory:GetReagentRank(itemLink, itemID) or nil

        -- Create entry
        local entry
        if rank and rank > 0 then
            entry = { itemID = itemID, rank = rank }
        else
            entry = { itemID = itemID, rank = 0 }
        end

        -- Check if already tracking this exact entry
        local list = self.db.profile.trackedItems
        for _, existingEntry in ipairs(list) do
            local existingItemID, existingRank
            if type(existingEntry) == "table" then
                existingItemID = existingEntry.itemID
                existingRank = existingEntry.rank or 0
            else
                existingItemID = existingEntry
                existingRank = 0
            end

            if existingItemID == itemID and existingRank == (rank or 0) then
                print("Goblin Toolbox: already tracking that item" .. (rank and " (Rank " .. rank .. ")" or "") .. ".")
                self:UpdateTrackedBar()
                return
            end
        end

        table.insert(list, entry)
        print("Goblin Toolbox: tracking item " .. itemID .. (rank and " (Rank " .. rank .. ")" or ""))
        self:UpdateTrackedBar()
        return
    end

    -- Not an item, try as a currency
    self:AddTrackedCurrency(input)
end

function addon:RemoveTrackedItem(entry)
    if not entry then
        return
    end

    -- Parse the entry to remove
    local targetItemID, targetRank
    if type(entry) == "table" then
        targetItemID = entry.itemID
        targetRank = entry.rank or 0
    else
        targetItemID = entry
        targetRank = 0
    end

    local list = self.db.profile.trackedItems
    for i, existingEntry in ipairs(list) do
        local existingItemID, existingRank
        if type(existingEntry) == "table" then
            existingItemID = existingEntry.itemID
            existingRank = existingEntry.rank or 0
        else
            existingItemID = existingEntry
            existingRank = 0
        end

        if existingItemID == targetItemID and existingRank == targetRank then
            table.remove(list, i)
            print("Goblin Toolbox: stopped tracking item " .. targetItemID .. (targetRank > 0 and " (Rank " .. targetRank .. ")" or ""))
            break
        end
    end
    self:UpdateTrackedBar()
end
