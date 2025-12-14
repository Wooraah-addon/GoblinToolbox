-- CurrencyBar.lua
-- Currency tracker bar: displays tracked currencies with icons and counts

local addonName, addon = ...

-----------------------------------------------------------------------
-- Currency bar frame creation
-----------------------------------------------------------------------

function addon:CreateCurrencyFrame()
    if self.currencyFrame then
        return
    end

    local f = CreateFrame("Frame", "GoblinToolboxCurrencyTracker", UIParent, "BackdropTemplate")
    self.currencyFrame = f

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
            db.currencyPoint, db.currencyRelPoint, db.currencyXOfs, db.currencyYOfs =
                point, relPoint, xOfs, yOfs
        end
    end)

    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = nil,
        tile     = true, tileSize = 16, edgeSize = 0,
        insets   = { left = 0, right = 0, top = 0, bottom = 0 },
    })

    -- Position: check saved, else anchor below tracker or HUD
    local db = addon.db.profile
    if db.currencyPoint and db.currencyRelPoint and db.currencyXOfs and db.currencyYOfs then
        f:SetPoint(db.currencyPoint, UIParent, db.currencyRelPoint, db.currencyXOfs, db.currencyYOfs)
    elseif self.trackerFrame then
        f:SetPoint("TOPLEFT", self.trackerFrame, "BOTTOMLEFT", 0, -8)
    elseif addon.HUD and addon.HUD.frame then
        f:SetPoint("TOPLEFT", addon.HUD.frame, "BOTTOMLEFT", 0, -8)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, -60)
    end

    f.buttons = {}

    self:UpdateBackground()
    self:UpdateCurrencyBar()
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

    -- Iterate through known currency IDs
    -- Note: This is a simplified approach. A more robust solution would
    -- cache or iterate through all valid currency IDs.
    -- For now, we'll check a reasonable range.
    for currencyID = 1, 3000 do
        local name = GetCurrencyData(currencyID)
        if name and name:lower():find(searchName, 1, true) then
            return currencyID
        end
    end

    return nil
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
    f:Show()

    f.buttons = f.buttons or {}

    local tracked = db.trackedCurrencies or {}
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

    -- Create buttons as needed
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

    -- Size the frame
    local totalWidth = padding * 2 + numTracked * buttonSize + (numTracked - 1) * spacing
    f:SetSize(totalWidth, buttonSize + padding * 2)

    -- Position and update buttons
    local prev
    for i, currencyID in ipairs(tracked) do
        local btn = f.buttons[i]
        btn.currencyID = currencyID

        btn:ClearAllPoints()
        if not prev then
            btn:SetPoint("LEFT", f, "LEFT", padding, 0)
        else
            btn:SetPoint("LEFT", prev, "RIGHT", spacing, 0)
        end
        prev = btn

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
        return
    end

    local currencyID

    -- Check if input is a number (currency ID)
    if tonumber(input) then
        currencyID = tonumber(input)
        -- Validate it exists
        local name = GetCurrencyData(currencyID)
        if not name then
            print("Goblin Toolbox: currency ID", currencyID, "not found.")
            return
        end
    else
        -- Search by name
        currencyID = FindCurrencyByName(input)
        if not currencyID then
            print("Goblin Toolbox: could not find currency matching '" .. input .. "'")
            return
        end
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
