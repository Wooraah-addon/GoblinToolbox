-- TrackerBar.lua
-- Item tracker bar: displays tracked item icons with bag counts

local addonName, addon = ...

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
        edgeFile = nil,
        tile     = true, tileSize = 16, edgeSize = 0,
        insets   = { left = 0, right = 0, top = 0, bottom = 0 },
    })

    local db = addon.db.profile
    if db.trackerPoint and db.trackerRelPoint and db.trackerXOfs and db.trackerYOfs then
        f:SetPoint(db.trackerPoint, UIParent, db.trackerRelPoint, db.trackerXOfs, db.trackerYOfs)
    elseif addon.HUD and addon.HUD.frame then
        f:SetPoint("TOPLEFT", addon.HUD.frame, "BOTTOMLEFT", 0, -8)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    f.buttons = {}

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
    f:Show()

    f.buttons = f.buttons or {}

    local tracked = db.trackedItems or {}
    local numTracked = #tracked

    if numTracked == 0 then
        for _, b in ipairs(f.buttons) do
            b:Hide()
        end
        f:SetSize(260, 34)
        return
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
            btn.count:SetFontObject(GameFontNormalSmall)
            btn.count:SetTextColor(1, 1, 1)

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

    local totalWidth = padding * 2 + numTracked * buttonSize + (numTracked - 1) * spacing
    f:SetSize(totalWidth, buttonSize + padding * 2)

    local prev
    for i, itemID in ipairs(tracked) do
        local btn = f.buttons[i]
        btn.itemID = itemID

        btn:ClearAllPoints()
        if not prev then
            btn:SetPoint("LEFT", f, "LEFT", padding, 0)
        else
            btn:SetPoint("LEFT", prev, "RIGHT", spacing, 0)
        end
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
        print("Goblin Toolbox: usage /gtb add [item link]")
        return
    end

    local itemID
    if tonumber(input) then
        itemID = tonumber(input)
    else
        itemID = select(1, GetItemInfoInstant(input))
    end

    if not itemID then
        print("Goblin Toolbox: could not identify item from input.")
        return
    end

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
