-- GoblinToolbox.lua
-- Core for Goblin Toolbox (12.0) - Utility Bar cleanup pass

local addonName, addon = ...

-----------------------------------------------------------------------
-- Saved variables and defaults
-----------------------------------------------------------------------

GoblinToolboxDB = GoblinToolboxDB or {}

local function CopyDefaults(src, dst)
    if type(dst) ~= "table" then
        dst = {}
    end
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

local DEFAULTS = {
    profile = {
        enabled          = true,
        scale            = 1.0,
        fontSize         = 13,   -- Arial Narrow
        lockFrame        = false,
        hideInCombat     = true,
        hideInInstances  = true,
        showHeaders      = true,
        showTitleBar     = true,
        showBackground   = true,
        preferWarbandBankOnOpen = false,

        modules = {
            Character   = true,
            Gold        = true,
            Inventory   = true,
            Professions = true,
            Utility     = true,
        },

        collapsed       = {},
        tsmSource       = "dbmarket",
        tsmCustomSource = "",
        trackedItems    = {},   -- list of itemIDs

        showTracker     = true,

        -- Utility bar state
        utilityButtons = {
            mobileBank   = true,   -- Mobile Banking spell
            mailbox      = true,   -- Portable mailbox toy (Katy > others)
            warbandBank  = true,   -- Warband Bank Distance Inhibitor
            hearthstone  = true,   -- Primary Hearthstone
            dalaranHS    = true,   -- Dalaran Hearthstone
            garrisonHS   = true,   -- Garrison Hearthstone
        },

        utilityPoint     = nil,
        utilityRelPoint  = nil,
        utilityXOfs      = nil,
        utilityYOfs      = nil,


        -- Utility Bar robust persistence (normalized center coordinates)
        utilityCXFrac    = nil,
        utilityCYFrac    = nil,
        trackerPoint     = nil,
        trackerRelPoint  = nil,
        trackerXOfs      = nil,
        trackerYOfs      = nil,
    },

    characters = {},
    guilds     = {},
}

function addon:GetDB()
    GoblinToolboxDB = CopyDefaults(DEFAULTS, GoblinToolboxDB)
    return GoblinToolboxDB
end

addon.db = addon:GetDB()

addon.trackedCounts  = addon.trackedCounts or {}
addon.trackerButtons = addon.trackerButtons or {}
addon.utilityButtons = addon.utilityButtons or {}

-----------------------------------------------------------------------
-- Shared helpers
-----------------------------------------------------------------------

local COPPER_PER_GOLD = 10000

local function GetCharacterKey()
    local name, realm = UnitFullName("player")
    return string.format("%s-%s", realm or "Unknown", name or "Unknown")
end

local function FormatMoney(amount)
    amount = amount or 0
    local gold = math.floor(amount / COPPER_PER_GOLD + 0.5)
    local text = BreakUpLargeNumbers(gold)
    local icon = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
    return text .. icon
end

local function GetWarbandBankGold()
    if C_Bank and Enum and Enum.BankType and Enum.BankType.Account then
        local ok, value = pcall(C_Bank.FetchDepositedMoney, Enum.BankType.Account)
        if ok and type(value) == "number" then
            return value
        end
    end
    return 0
end

-- For secure frames (Utility Bar), never call Show/Hide in combat.
local function SetSecureFrameVisible(frame, wantVisible)
    if not frame then
        return
    end

    if InCombatLockdown() then
        if wantVisible then
            frame:SetAlpha(1)
            frame:EnableMouse(true)
        else
            frame:SetAlpha(0)
            frame:EnableMouse(false)
        end
        return
    end

    if wantVisible then
        frame:SetAlpha(1)
        frame:EnableMouse(true)
        frame:Show()
    else
        frame:SetAlpha(0)
        frame:EnableMouse(false)
        frame:Hide()
    end
end

-----------------------------------------------------------------------
-- Tracked items bar (icons + counts)
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

    local buttonSize = 28
    local spacing = 4
    local padding = 4

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

        local icon
        if C_Item and C_Item.GetItemIconByID then
            icon = C_Item.GetItemIconByID(itemID)
        end
        if not icon and GetItemIcon then
            icon = GetItemIcon(itemID)
        end
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
-- Utility Bar metadata
-----------------------------------------------------------------------

local UTILITY_ACTIONS = {
    mobileBank = {
        key         = "mobileBank",
        label       = "Mobile Banking",
        kind        = "spell",
        spellID     = 83958,
        iconTexture = "Interface\\Icons\\achievement_guildperk_mobilebanking",
    },

    mailbox = {
        key      = "mailbox",
        label    = "Portable Mailbox",
        kind     = "item",   -- toys, /use itemID works
        mailboxCandidates = {
            156833, -- Katy's Stampwhistle
            194885, -- Ohuna Perch
            40768,  -- MOLL-E
        },
    },

    warbandBank = {
        key         = "warbandBank",
        label       = "Warband Bank",
        kind        = "spell",
        spellID     = 460905,  -- Warband Bank Distance Inhibitor
        iconTexture = "Interface\\Icons\\inv_cosmicvoid_orb",
    },

    hearthstone = {
        key         = "hearthstone",
        label       = "Hearthstone",
        kind        = "spell",
        spellID     = 8690, -- base spell shared cooldown
        spellName   = "Hearthstone",
        iconTexture = "Interface\\Icons\\inv_misc_rune_01",
    },

    dalaranHS = {
        key      = "dalaranHS",
        label    = "Dalaran Hearthstone",
        kind     = "item",
        itemID   = 140192,
    },

    garrisonHS = {
        key      = "garrisonHS",
        label    = "Garrison Hearthstone",
        kind     = "item",
        itemID   = 110560,
    },
}

local UTILITY_ORDER = {
    "mobileBank",
    "mailbox",
    "warbandBank",
    "hearthstone",
    "dalaranHS",
    "garrisonHS",
}

local function NormalizeEnabled(v)
    if v == true then return 1 end
    if v == false then return 0 end
    if type(v) == "number" then return v end
    return 1
end

local function IsToyOwnedAndUsable(itemID)
    if not itemID then
        return false
    end

    local owned = false

    if PlayerHasToy and PlayerHasToy(itemID) then
        owned = true
    elseif GetItemCount and GetItemCount(itemID, true) > 0 then
        owned = true
    end

    if not owned then
        return false
    end

    if C_ToyBox and C_ToyBox.IsToyUsable then
        return C_ToyBox.IsToyUsable(itemID)
    end

    return true
end

local function PickMailboxToyID()
    local def = UTILITY_ACTIONS.mailbox
    if not def or not def.mailboxCandidates then
        return nil
    end

    for _, itemID in ipairs(def.mailboxCandidates) do
        if IsToyOwnedAndUsable(itemID) then
            return itemID
        end
    end

    return nil
end

local function GetUtilityIcon(def, resolvedItemID)
    if def.iconTexture then
        return def.iconTexture
    end

    if def.kind == "spell" then
        if GetSpellTexture then
            if def.spellID then
                local tex = GetSpellTexture(def.spellID)
                if tex then return tex end
            end
            if def.spellName then
                local tex = GetSpellTexture(def.spellName)
                if tex then return tex end
            end
        end

        if GetSpellInfo then
            if def.spellID then
                local _, _, tex = GetSpellInfo(def.spellID)
                if tex then return tex end
            end
            if def.spellName then
                local _, _, tex = GetSpellInfo(def.spellName)
                if tex then return tex end
            end
        end
    elseif def.kind == "item" then
        local itemID = resolvedItemID or def.itemID
        if itemID and GetItemIcon then
            return GetItemIcon(itemID)
        end
    end

    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

-----------------------------------------------------------------------
-- Session tracking
-----------------------------------------------------------------------

addon.state = addon.state or {
    sessionStartGold = nil,
    sessionStartTime = nil,
    sessionPaused    = false,
    pauseStartTime   = nil,
    pausedDuration   = 0,
    bagValue         = 0,
}

function addon:ResetSession()
    self.state.sessionStartGold = GetMoney()
    self.state.sessionStartTime = time()
    self.state.sessionPaused    = false
    self.state.pauseStartTime   = nil
    self.state.pausedDuration   = 0
end

function addon:TogglePauseSession()
    local s = self.state
    if not s.sessionStartTime then
        self:ResetSession()
        return
    end

    if s.sessionPaused then
        s.sessionPaused = false
        if s.pauseStartTime then
            s.pausedDuration = s.pausedDuration + (time() - s.pauseStartTime)
        end
        s.pauseStartTime = nil
        print("Goblin Toolbox: session resumed.")
    else
        s.sessionPaused  = true
        s.pauseStartTime = time()
        print("Goblin Toolbox: session paused.")
    end
end

local function GetSessionStats()
    local s = addon.state
    if not s.sessionStartTime or not s.sessionStartGold then
        return 0, 0, 0
    end

    local now = time()
    local elapsed = now - s.sessionStartTime

    if s.sessionPaused and s.pauseStartTime then
        elapsed = s.pauseStartTime - s.sessionStartTime
    else
        elapsed = elapsed - (s.pausedDuration or 0)
    end

    if elapsed < 1 then
        elapsed = 1
    end

    local net = GetMoney() - s.sessionStartGold
    local gph = net * 3600 / elapsed

    return elapsed, net, gph
end

local function UpdateCharacterGoldCache()
    local key = GetCharacterKey()
    local db  = addon.db
    db.characters[key] = db.characters[key] or {}
    db.characters[key].gold = GetMoney()
end

-----------------------------------------------------------------------
-- WoW Token tracking (price + simple trend)
-----------------------------------------------------------------------

addon.token = addon.token or {
    lastPrice   = 0,
    lastUpdated = 0,
    history     = {},
}

local function TokenHistoryPush(priceCopper)
    if not priceCopper or type(priceCopper) ~= "number" or priceCopper <= 0 then
        return
    end

    local t = addon.token
    local hist = t.history or {}
    t.history = hist

    if hist[#hist] == priceCopper then
        return
    end

    table.insert(hist, priceCopper)
    while #hist > 20 do
        table.remove(hist, 1)
    end
end

function addon:GetTokenTrend()
    local hist = self.token and self.token.history
    if not hist or #hist < 6 then
        return "flat"
    end

    local function Avg(startIndex, endIndex)
        local sum = 0
        local n = 0
        for i = startIndex, endIndex do
            local v = hist[i]
            if type(v) == "number" and v > 0 then
                sum = sum + v
                n = n + 1
            end
        end
        if n == 0 then return 0 end
        return sum / n
    end

    local n = #hist
    local prevAvg = Avg(n - 5, n - 3)
    local lastAvg = Avg(n - 2, n)

    if prevAvg <= 0 or lastAvg <= 0 then
        return "flat"
    end

    local delta = lastAvg - prevAvg
    local threshold = 10000 * 10000 -- 10,000g in copper

    if delta > threshold then
        return "up"
    elseif delta < -threshold then
        return "down"
    end

    return "flat"
end

function addon:RequestTokenPrice()
    if C_WowTokenPublic and C_WowTokenPublic.UpdateMarketPrice then
        C_WowTokenPublic.UpdateMarketPrice()
        return true
    end
    return false
end

function addon:ReadTokenPrice()
    if C_WowTokenPublic and C_WowTokenPublic.GetCurrentMarketPrice then
        local price = C_WowTokenPublic.GetCurrentMarketPrice()
        if type(price) == "number" and price > 0 then
            return price
        end
    end
    return nil
end

function addon:UpdateTokenCache()
    local price = self:ReadTokenPrice()
    if not price then
        return false
    end

    self.token.lastPrice = price
    self.token.lastUpdated = time()
    TokenHistoryPush(price)
    return true
end

addon._tokenTicker = addon._tokenTicker or nil
function addon:StartTokenTicker()
    if self._tokenTicker then
        return
    end

    self:RequestTokenPrice()

    self._tokenTicker = C_Timer.NewTicker(300, function()
        if not addon or not addon.db or not addon.db.profile then
            return
        end
        if not addon.db.profile.enabled then
            return
        end
        addon:RequestTokenPrice()
    end)
end

-----------------------------------------------------------------------
-- Session ticker
-----------------------------------------------------------------------

addon._sessionTicker = addon._sessionTicker or nil
function addon:StartSessionTicker()
    if self._sessionTicker then
        return
    end

    self._sessionTicker = C_Timer.NewTicker(1.0, function()
        if not addon or not addon.db or not addon.db.profile then
            return
        end

        local db = addon.db.profile
        if not db.enabled then
            return
        end
        if not addon.HUD or not addon.HUD.frame or not addon.HUD.frame:IsShown() then
            return
        end
        if not db.modules or db.modules.Gold == false then
            return
        end

        addon:UpdateGoldSection()
        addon:LayoutHUD()
    end)
end

-----------------------------------------------------------------------
-- Guild bank tracking
-----------------------------------------------------------------------

local function UpdateGuildGoldFromBank()
    local guildName = GetGuildInfo("player")
    if not guildName then
        return
    end

    local money = GetGuildBankMoney()
    if money == nil then
        return
    end

    local db = addon.db
    db.guilds[guildName] = db.guilds[guildName] or {}
    db.guilds[guildName].gold       = money
    db.guilds[guildName].lastUpdate = time()
end

local function GetGuildGold()
    local guildName = GetGuildInfo("player")
    if not guildName then
        return nil, nil, nil
    end

    local data = addon.db.guilds[guildName]
    if data and type(data.gold) == "number" then
        return data.gold, guildName, data.lastUpdate
    end

    return nil, guildName, data and data.lastUpdate
end

-----------------------------------------------------------------------
-- HUD: sections, fonts, layout
-----------------------------------------------------------------------

local HUD = {
    order    = { "Character", "Gold", "Inventory", "Professions" },
    sections = {},
}
addon.HUD = HUD

local BODY_FONT
local HEADER_FONT

local function GetBodyFont()
    if BODY_FONT then
        return BODY_FONT
    end
    local size = addon.db.profile.fontSize or 13
    local f = CreateFont("GoblinToolboxFontBody")
    f:SetFont("Fonts\\ARIALN.TTF", size, "")
    f:SetTextColor(0.9, 0.9, 0.9)
    BODY_FONT = f
    return f
end

local function GetHeaderFont()
    if HEADER_FONT then
        return HEADER_FONT
    end
    local size = (addon.db.profile.fontSize or 13) + 1
    local f = CreateFont("GoblinToolboxFontHeader")
    f:SetFont("Fonts\\ARIALN.TTF", size, "OUTLINE")
    f:SetTextColor(0.97, 0.86, 0.29)
    HEADER_FONT = f
    return f
end

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

local function SetToggleTextures(section)
    if not section.toggle then
        return
    end
    local prefix = section.collapsed and "UI-PlusButton" or "UI-MinusButton"
    section.toggle:SetNormalTexture("Interface\\Buttons\\" .. prefix .. "-Up")
    section.toggle:SetPushedTexture("Interface\\Buttons\\" .. prefix .. "-Down")
    section.toggle:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
end

local function CreateSection(frame, key, headerText, numLines)
    local section = {}
    section.key = key

    section.toggle = CreateFrame("Button", nil, frame)
    section.toggle:SetSize(12, 12)

    section.header = frame:CreateFontString(nil, "OVERLAY")
    section.header:SetJustifyH("LEFT")
    section.header:SetFontObject(GetHeaderFont())
    section.header:SetText(headerText)

    section.lines = {}
    for i = 1, numLines do
        local fs = frame:CreateFontString(nil, "OVERLAY")
        fs:SetJustifyH("LEFT")
        fs:SetFontObject(GetBodyFont())
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

function addon:UpdateBackground()
    local show = self.db.profile.showBackground

    if HUD.frame then
        local alpha = show and 0.30 or 0.0
        HUD.frame:SetBackdropColor(0, 0, 0, alpha)
    end
    if self.trackerFrame then
        local alpha = show and 0.30 or 0.0
        self.trackerFrame:SetBackdropColor(0, 0, 0, alpha)
    end
    if self.utilityBar then
        local alpha = show and 0.30 or 0.0
        self.utilityBar:SetBackdropColor(0, 0, 0, alpha)
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

local function CreateHUD()
    if HUD.frame then
        return
    end

    local frame = CreateFrame("Frame", "GoblinToolboxHUD", UIParent, "BackdropTemplate")
    HUD.frame = frame

    frame:SetSize(360, 120)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetUserPlaced(false)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", StartDragging)
    frame:SetScript("OnDragStop",  StopDragging)

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
    tb:SetHeight(22)
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
    tb:SetScript("OnDragStop",  function() StopDragging(frame) end)

    tb.title = tb:CreateFontString(nil, "OVERLAY")
    tb.title:SetFontObject(GetHeaderFont())
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

    CreateSection(frame, "Character",   "Character",            1)
    CreateSection(frame, "Gold",        "Gold & Economy",       3)
    CreateSection(frame, "Inventory",   "Inventory & Currency", 3)
    CreateSection(frame, "Professions", "Professions",          1)

    addon:UpdateBackground()
    addon:UpdateTitleBar()
    addon:LayoutHUD()
end

-----------------------------------------------------------------------
-- Separate tracker frame
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
    elseif HUD.frame then
        f:SetPoint("TOPLEFT", HUD.frame, "BOTTOMLEFT", 0, -8)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    self:UpdateBackground()
    self:UpdateTrackedBar()
end

-----------------------------------------------------------------------
-- Utility Bar (clean, single implementation)
-----------------------------------------------------------------------

local function CreateUtilityButton(parent, index, size)
    local name = "GoblinToolboxUtilityButton" .. index
    local btn = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
    btn:SetSize(size, size)

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetAllPoints(true)

    btn.cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    btn.cooldown:SetAllPoints(true)
    btn.cooldown:SetDrawEdge(true)
    btn.cooldown:SetHideCountdownNumbers(false)
    btn.cooldown:SetFrameLevel(btn:GetFrameLevel() + 1)

    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    btn:RegisterForClicks("AnyUp")

    btn:SetScript("OnEnter", function(selfBtn)
        if not selfBtn.tooltip then
            return
        end
        GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
        GameTooltip:SetText(selfBtn.tooltip, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    btn.utilDef = nil
    btn.itemID = nil
    btn.spellKey = nil
    btn._lastStart = nil
    btn._lastDuration = nil

    return btn
end

local function GetCooldownForUtilityButton(btn)
    if not btn or not btn.utilDef then
        return 0, 0, 0
    end

    local def = btn.utilDef

    if def.kind == "spell" then
        local spellID = def.spellID

        if spellID and C_Spell and C_Spell.GetSpellCooldown then
            local info = C_Spell.GetSpellCooldown(spellID)
            if info then
                return info.startTime or 0, info.duration or 0, NormalizeEnabled(info.isEnabled)
            end
        end

        if GetSpellCooldown then
            local start, duration, enabled = GetSpellCooldown(spellID or btn.spellKey)
            return start or 0, duration or 0, NormalizeEnabled(enabled)
        end

        return 0, 0, 0
    end

    if def.kind == "item" then
        local itemID = btn.itemID
        if not itemID then
            return 0, 0, 0
        end

        if PlayerHasToy and PlayerHasToy(itemID) and C_ToyBox and C_ToyBox.GetToyCooldown then
            local tStart, tDur, tEnabled = C_ToyBox.GetToyCooldown(itemID)
            tStart = tStart or 0
            tDur = tDur or 0
            tEnabled = NormalizeEnabled(tEnabled)

            if tStart > 0 and tDur > 0 then
                return tStart, tDur, 1
            end
        end

        if C_Item and C_Item.GetItemCooldown then
            local start, duration, enabled = C_Item.GetItemCooldown(itemID)
            return start or 0, duration or 0, NormalizeEnabled(enabled)
        end

        if GetItemCooldown then
            local start, duration, enabled = GetItemCooldown(itemID)
            return start or 0, duration or 0, NormalizeEnabled(enabled)
        end

        return 0, 0, 0
    end

    return 0, 0, 0
end

local function UpdateUtilityButtonCooldown(btn)
    if not btn or not btn.cooldown or not btn.utilDef then
        return
    end

    local start, duration, enabled = GetCooldownForUtilityButton(btn)
    local valid = (enabled == 1 and start > 0 and duration and duration > 1.5)

    if valid then
        if btn._lastStart ~= start or btn._lastDuration ~= duration then
            btn._lastStart = start
            btn._lastDuration = duration
            btn.cooldown:SetCooldown(start, duration)
            btn.cooldown:Show()
        end
    else
        if btn.cooldown:IsShown() then
            if btn.cooldown.Clear then
                btn.cooldown:Clear()
            else
                btn.cooldown:SetCooldown(0, 0)
            end
            btn.cooldown:Hide()
        end
        btn._lastStart = nil
        btn._lastDuration = nil
    end
end

local function SetupUtilityButton(btn, def, resolvedItemID)
    btn.utilDef = def
    btn.itemID = nil
    btn.spellKey = nil

    local icon, tip

    if def.kind == "spell" then
        local spellName
        if def.spellID and GetSpellInfo then
            spellName = GetSpellInfo(def.spellID)
        end
        if not spellName and def.spellName then
            spellName = def.spellName
        end

        local key = def.spellID or spellName

        -- Secure attributes: only touch them out of combat.
        if not InCombatLockdown() then
            btn:SetAttribute("type", "spell")
            btn:SetAttribute("spell", key)
        end

        btn.spellKey = key
        icon = GetUtilityIcon(def)
        tip = spellName or def.label or "Spell"

    elseif def.kind == "item" then
        local itemID = resolvedItemID or def.itemID
        btn.itemID = itemID

        if not InCombatLockdown() then
            btn:SetAttribute("type", "item")
            if itemID then
                btn:SetAttribute("item", "item:" .. itemID)
            else
                btn:SetAttribute("item", nil)
            end
        end

        icon = GetUtilityIcon(def, itemID)

        if itemID and GetItemInfo then
            local name = GetItemInfo(itemID)
            tip = name or def.label or "Item"
        else
            tip = def.label or "Item"
        end
    else
        if not InCombatLockdown() then
            btn:SetAttribute("type", nil)
        end
        icon = "Interface\\Icons\\INV_Misc_QuestionMark"
        tip = def.label or "Utility"
    end

    btn.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    btn.tooltip = tip

    UpdateUtilityButtonCooldown(btn)
end

-- Utility Bar position persistence
-- Root issue addressed: point-based anchors can be transient during login/load screens or while hidden/clamped,
-- which can overwrite good saved values. We persist normalized center coordinates and restore after UI settles.

addon._utilityMovedThisSession = addon._utilityMovedThisSession or false

local function Utility_SaveNormalizedCenter()
    if not addon or not addon.db or not addon.db.profile or not addon.utilityBar then
        return false
    end

    local db = addon.db.profile

    local w, h = UIParent:GetSize()
    if not w or not h or w <= 0 or h <= 0 then
        return false
    end

    local cx, cy = addon.utilityBar:GetCenter()
    if not cx or not cy then
        return false
    end

    local cxFrac = cx / w
    local cyFrac = cy / h

    -- Sanity gate: accept slight out-of-range due to clamping/scale, but reject extreme values.
    if cxFrac < -0.25 or cxFrac > 1.25 or cyFrac < -0.25 or cyFrac > 1.25 then
        return false
    end

    db.utilityCXFrac = cxFrac
    db.utilityCYFrac = cyFrac
    return true
end

local function SaveUtilityBarPosition()
    if not addon or not addon.db or not addon.db.profile or not addon.utilityBar then
        return
    end

    local db = addon.db.profile

    -- Prefer normalized center persistence
    Utility_SaveNormalizedCenter()

    -- Keep legacy point-based values as fallback/debug breadcrumb
    local point, _, relPoint, xOfs, yOfs = addon.utilityBar:GetPoint(1)
    if point and relPoint and xOfs and yOfs then
        db.utilityPoint    = point
        db.utilityRelPoint = relPoint
        db.utilityXOfs     = xOfs
        db.utilityYOfs     = yOfs
    end
end

local function ApplyUtilityBarPosition()
    if not addon or not addon.db or not addon.db.profile or not addon.utilityBar then
        return false
    end

    local db = addon.db.profile

    -- Preferred: restore via normalized center coords (resolution/UI scale safe)
    if db.utilityCXFrac and db.utilityCYFrac then
        local w, h = UIParent:GetSize()
        if w and h and w > 0 and h > 0 then
            local cx = db.utilityCXFrac * w
            local cy = db.utilityCYFrac * h

            -- Clamp into UIParent bounds
            if cx < 0 then cx = 0 end
            if cy < 0 then cy = 0 end
            if cx > w then cx = w end
            if cy > h then cy = h end

            addon.utilityBar:ClearAllPoints()
            addon.utilityBar:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx, cy)
            return true
        end
    end

    -- Fallback: legacy anchor tuple
    if db.utilityPoint and db.utilityRelPoint and db.utilityXOfs and db.utilityYOfs then
        addon.utilityBar:ClearAllPoints()
        addon.utilityBar:SetPoint(db.utilityPoint, UIParent, db.utilityRelPoint, db.utilityXOfs, db.utilityYOfs)
        return true
    end

    return false
end

local function Utility_DeferredApply()
    if not addon or not addon.utilityBar then
        return
    end

    -- Two-phase apply: UIParent dims can be unstable right after login/loading.
    if C_Timer and C_Timer.After then
        C_Timer.After(0.10, function()
            ApplyUtilityBarPosition()
        end)
        C_Timer.After(0.50, function()
            ApplyUtilityBarPosition()
        end)
    else
        ApplyUtilityBarPosition()
    end
end

function addon:CreateUtilityBar()
    if self.utilityBar then
        return
    end

    local f = CreateFrame("Frame", "GoblinToolboxUtilityBar", UIParent, "BackdropTemplate")
    self.utilityBar = f

    f:SetSize(200, 34)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")

    f:SetScript("OnDragStart", function(frame)
        if addon.db and addon.db.profile and addon.db.profile.lockFrame then
            return
        end
        frame:StartMoving()
    end)

    f:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        addon._utilityMovedThisSession = true
        SaveUtilityBarPosition()
    end)

    f:SetBackdrop({
        bgFile   = "Interface\Buttons\WHITE8x8",
        edgeFile = nil,
        tile     = true, tileSize = 16, edgeSize = 0,
        insets   = { left = 0, right = 0, top = 0, bottom = 0 },
    })

    -- Default anchor near HUD or tracker. Saved position will override this once UIParent dims settle.
    if HUD and HUD.frame then
        if addon.trackerFrame then
            f:SetPoint("TOPLEFT", addon.trackerFrame, "BOTTOMLEFT", 0, -8)
        else
            f:SetPoint("TOPLEFT", HUD.frame, "BOTTOMLEFT", 0, -8)
        end
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, -120)
    end

    Utility_DeferredApply()

    f.buttons = {}
    self:UpdateBackground()
end

function addon:UpdateUtilityBar()
    local db = self.db and self.db.profile
    local bar = self.utilityBar

    if not db then
        return
    end

    if not bar then
        self:CreateUtilityBar()
        bar = self.utilityBar
        if not bar then
            return
        end
    end

    local wantEnabled = db.enabled and db.modules and db.modules.Utility ~= false

    local hide = false
    if wantEnabled then
        if db.hideInCombat and UnitAffectingCombat("player") then
            hide = true
        end
        if db.hideInInstances then
            local inInstance, instanceType = IsInInstance()
            if inInstance and instanceType ~= "none" then
                hide = true
            end
        end
    else
        hide = true
    end

    -- Combat-safe visibility
    SetSecureFrameVisible(bar, not hide)

    -- If hidden, do not rebuild buttons.
    if hide then
        return
    end

    -- In combat: do not change secure attributes or rebuild.
    if InCombatLockdown() then
        self._needsUtilityRefresh = true
        return
    end

    bar.buttons = bar.buttons or {}

    local size = 32
    local spacing = 6
    local padding = 4

    local shown = 0

    for _, key in ipairs(UTILITY_ORDER) do
        local def = UTILITY_ACTIONS[key]
        local enabled = db.utilityButtons and db.utilityButtons[key]

        if def and enabled then
            if key == "mailbox" then
                local mailboxItemID = PickMailboxToyID()
                if mailboxItemID then
                    shown = shown + 1
                    local btn = bar.buttons[shown]
                    if not btn then
                        btn = CreateUtilityButton(bar, shown, size)
                        bar.buttons[shown] = btn
                    end
                    SetupUtilityButton(btn, def, mailboxItemID)
                end
            else
                shown = shown + 1
                local btn = bar.buttons[shown]
                if not btn then
                    btn = CreateUtilityButton(bar, shown, size)
                    bar.buttons[shown] = btn
                end
                SetupUtilityButton(btn, def, nil)
            end
        end
    end

    for i = 1, #bar.buttons do
        local btn = bar.buttons[i]
        if btn then
            if i <= shown then
                btn:ClearAllPoints()
                if i == 1 then
                    btn:SetPoint("LEFT", bar, "LEFT", padding, 0)
                else
                    btn:SetPoint("LEFT", bar.buttons[i - 1], "RIGHT", spacing, 0)
                end
                btn:Show()
            else
                btn:Hide()
            end
        end
    end

    if shown == 0 then
        SetSecureFrameVisible(bar, false)
        return
    end

    local width = padding * 2 + shown * size + (shown - 1) * spacing
    local height = size + padding * 2
    bar:SetSize(width, height)
end

function addon:UpdateUtilityCooldowns()
    local bar = self.utilityBar
    if not bar or not bar.buttons then
        return
    end

    for _, btn in ipairs(bar.buttons) do
        if btn and btn:IsShown() then
            UpdateUtilityButtonCooldown(btn)
        end
    end
end

-----------------------------------------------------------------------
-- Layout
-----------------------------------------------------------------------

function addon:LayoutHUD()
    if not HUD.frame then
        return
    end

    local frame = HUD.frame
    local db    = self.db.profile

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
        local h = HUD.titleBar and HUD.titleBar:IsShown() and HUD.titleBar:GetHeight() or 22
        frame:SetHeight(h + 4)
        return
    end

    local bodyFont   = GetBodyFont()
    local headerFont = GetHeaderFont()

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
-- Section updates
-----------------------------------------------------------------------

function addon:UpdateCharacterSection()
    if not self.db.profile.modules.Character then
        return
    end
    local sec = HUD.sections.Character
    if not sec then
        return
    end
    local name, realm = UnitFullName("player")
    sec.lines[1]:SetText(string.format("%s - %s", name or "Unknown", realm or "Unknown"))
end

function addon:UpdateGoldSection()
    if not self.db.profile.modules.Gold then
        return
    end
    local sec = HUD.sections.Gold
    if not sec then
        return
    end

    UpdateCharacterGoldCache()

    local charGold    = GetMoney()
    local warbandGold = GetWarbandBankGold()

    local guildGold, guildName, guildLastUpdate = GetGuildGold()
    local guildText

    if not guildName then
        guildText = "None"
    elseif guildGold then
        guildText = FormatMoney(guildGold)

        local isStale = false
        if guildLastUpdate then
            if (time() - guildLastUpdate) > (4 * 24 * 60 * 60) then
                isStale = true
            end
        else
            isStale = true
        end

        if isStale then
            guildText = guildText .. " |TInterface\\TimeManager\\Clock-Red:0:0:0:0|t"
        end
    else
        guildText = "|cffff4444Visit|r"
    end

    sec.lines[1]:SetText(string.format("Char: %s   WB: %s   Guild: %s",
        FormatMoney(charGold), FormatMoney(warbandGold), guildText))

    local elapsed, net, gph = GetSessionStats()
    local hours   = math.floor(elapsed / 3600)
    local minutes = math.floor((elapsed % 3600) / 60)
    local timeStr
    if hours > 0 then
        timeStr = string.format("%dh %02dm", hours, minutes)
    else
        timeStr = string.format("%dm", minutes)
    end

    sec.lines[2]:SetText(string.format("Session: %s  Earnt: %s  (%s / h)",
        timeStr, FormatMoney(net), FormatMoney(gph)))

    local tokenPrice = self.token and self.token.lastPrice or 0
    if tokenPrice and tokenPrice > 0 then
        local trend = self:GetTokenTrend()
        local marker = " "
        if trend == "up" then
            marker = "▲"
        elseif trend == "down" then
            marker = "▼"
        end

        sec.lines[3]:SetText(string.format("Token: %s %s", FormatMoney(tokenPrice), marker))
    else
        sec.lines[3]:SetText("Token: n/a")
    end
end

-----------------------------------------------------------------------
-- Bag value and tracked counts
-----------------------------------------------------------------------

local function GetBagSlots()
    if not C_Container then
        return 0, 0
    end

    local totalSlots = 0
    local usedSlots  = 0

    for bag = 0, NUM_BAG_SLOTS do
        local n = C_Container.GetContainerNumSlots(bag) or 0
        totalSlots = totalSlots + n

        for slot = 1, n do
            local itemID = C_Container.GetContainerItemID(bag, slot)
            if itemID then
                usedSlots = usedSlots + 1
            end
        end
    end

    if Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag then
        local bag = Enum.BagIndex.ReagentBag
        local n = C_Container.GetContainerNumSlots(bag) or 0
        totalSlots = totalSlots + n

        for slot = 1, n do
            local itemID = C_Container.GetContainerItemID(bag, slot)
            if itemID then
                usedSlots = usedSlots + 1
            end
        end
    end

    local freeSlots = math.max(totalSlots - usedSlots, 0)
    return freeSlots, totalSlots
end

local function SafeResolveTSMLabel()
    local db = addon.db and addon.db.profile
    if not db then
        return "dbmarket"
    end

    local src = db.tsmSource or "dbmarket"

    if src == "custom" then
        local custom = (db.tsmCustomSource or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if custom ~= "" then
            return custom
        end
        return "dbmarket"
    end

    return src
end

local function GetItemPrice(itemLink)
    if not itemLink then
        return 0
    end

    local price = 0

    if TSM_API and TSM_API.GetCustomPriceValue then
        local sourceLabel = SafeResolveTSMLabel()
        local itemString = itemLink

        if TSM_API.ToItemString then
            local ok, s = pcall(TSM_API.ToItemString, itemLink)
            if ok and s then
                itemString = s
            end
        end

        local ok, value = pcall(TSM_API.GetCustomPriceValue, sourceLabel, itemString)
        if ok and value and value > 0 then
            price = value
        end
    end

    if price <= 0 then
        local vendor = select(11, GetItemInfo(itemLink)) or 0
        price = vendor
    end

    return price
end

local bagValuePending = false

local function ScanBag(bag, countByID, totalValue)
    local numSlots = C_Container.GetContainerNumSlots(bag)
    if not numSlots or numSlots <= 0 then
        return totalValue
    end

    for slot = 1, numSlots do
        local itemID = C_Container.GetContainerItemID(bag, slot)
        if itemID then
            local itemLink = C_Container.GetContainerItemLink(bag, slot)
            local info     = C_Container.GetContainerItemInfo(bag, slot)
            local count    = (info and info.stackCount) or 1

            countByID[itemID] = (countByID[itemID] or 0) + count

            if itemLink then
                local price = GetItemPrice(itemLink)
                totalValue = totalValue + price * count
            end
        end
    end

    return totalValue
end

local function RecalculateBagValue()
    bagValuePending = false

    if not C_Container then
        addon.state.bagValue = 0
        addon.trackedCounts  = {}
        addon:UpdateInventorySection()
        addon:UpdateTrackedBar()
        return
    end

    local total     = 0
    local countByID = {}

    for bag = 0, NUM_BAG_SLOTS do
        total = ScanBag(bag, countByID, total)
    end

    if Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag then
        total = ScanBag(Enum.BagIndex.ReagentBag, countByID, total)
    end

    addon.state.bagValue = total
    addon.trackedCounts  = countByID

    addon:UpdateInventorySection()
    addon:UpdateTrackedBar()
end

local function QueueBagValueRecalc()
    if bagValuePending then
        return
    end
    bagValuePending = true
    C_Timer.After(0.5, RecalculateBagValue)
end

function addon:UpdateInventorySection()
    if not self.db or not self.db.profile or not self.db.profile.modules then
        return
    end
    if not self.db.profile.modules.Inventory then
        return
    end

    local sec = HUD and HUD.sections and HUD.sections.Inventory
    if not sec or not sec.lines then
        return
    end

    local free, total = GetBagSlots()
    if sec.lines[1] then
        sec.lines[1]:SetText(string.format("Free bag slots: %d / %d", free, total))
        sec.lines[1]:Show()
    end

    if sec.lines[2] then
        local label = "vendor"
        if TSM_API and TSM_API.GetCustomPriceValue then
            label = SafeResolveTSMLabel()
        end
        sec.lines[2]:SetText(string.format("Bag value (%s): %s", label, FormatMoney(self.state.bagValue or 0)))
        sec.lines[2]:Show()
    end

    if sec.lines[3] then
        local isEnabled = nil
        if C_PlayerInfo and C_PlayerInfo.IsAccountBankEnabled then
            isEnabled = C_PlayerInfo.IsAccountBankEnabled()
        end

        local hasLock = nil
        if C_PlayerInfo and C_PlayerInfo.HasAccountInventoryLock then
            hasLock = C_PlayerInfo.HasAccountInventoryLock()
        end

        local text

        if hasLock == true then
            text = "Warbank: |cff44ff44●|r"
        elseif hasLock == false then
            text = "Warbank: |cffff4444●|r"
        elseif isEnabled == false then
            text = "Warbank: |cffff4444Needs Quest|r"
        else
            text = "Warbank:"
        end

        sec.lines[3]:SetText(text)
        sec.lines[3]:Show()
    end
end

function addon:UpdateProfessionsSection()
    if not self.db.profile.modules.Professions then
        return
    end
    local sec = HUD.sections.Professions
    if not sec then
        return
    end
    sec.lines[1]:SetText("Concentration: n/a")
end

function addon:UpdateAllSections()
    self:UpdateCharacterSection()
    self:UpdateGoldSection()
    self:UpdateInventorySection()
    self:UpdateProfessionsSection()
    self:UpdateTrackedBar()
    self:LayoutHUD()
end

-----------------------------------------------------------------------
-- Tracking list helpers
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

-----------------------------------------------------------------------
-- Bank helper: prefer Warband Bank tab on open (Blizzard UI only)
-----------------------------------------------------------------------

addon._bankAutoSwitchDone = false
addon._bankAutoSwitchTries = 0

function addon:ResetBankAutoSwitchState()
    self._bankAutoSwitchDone = false
    self._bankAutoSwitchTries = 0
end

local function FindWarbandBankTabButton()
    if not BankFrame or not BankFrame.IsShown or not BankFrame:IsShown() then
        return nil
    end

    local tabSystem = BankFrame.TabSystem
    if not tabSystem or not tabSystem.GetChildren then
        return nil
    end

    local children = { tabSystem:GetChildren() }
    for _, child in ipairs(children) do
        if child and child.GetObjectType and child:GetObjectType() == "Button" then
            local text = nil

            if child.GetText then
                text = child:GetText()
            end

            if (not text or text == "") and child.Text and child.Text.GetText then
                text = child.Text:GetText()
            end

            if type(text) == "string" and text:lower():find("warband") then
                return child
            end
        end
    end

    return nil
end

function addon:TryAutoSwitchToWarbandBank()
    if not self.db or not self.db.profile then
        return
    end
    if not self.db.profile.preferWarbandBankOnOpen then
        return
    end
    if self._bankAutoSwitchDone then
        return
    end

    self._bankAutoSwitchTries = (self._bankAutoSwitchTries or 0) + 1
    if self._bankAutoSwitchTries > 30 then
        self._bankAutoSwitchDone = true
        return
    end

    local btn = FindWarbandBankTabButton()
    if not btn then
        C_Timer.After(0.05, function()
            addon:TryAutoSwitchToWarbandBank()
        end)
        return
    end

    self._bankAutoSwitchDone = true
    pcall(function()
        btn:Click()
    end)
end

-----------------------------------------------------------------------
-- Visibility
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
        -- Utility bar is secure; hide safely.
        SetSecureFrameVisible(self.utilityBar, false)
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
        SetSecureFrameVisible(self.utilityBar, false)
        return
    end

    HUD.frame:Show()

    if self.trackerFrame and db.showTracker then
        self.trackerFrame:Show()
    elseif self.trackerFrame then
        self.trackerFrame:Hide()
    end

    if db.modules and db.modules.Utility then
        -- Utility bar visibility is controlled inside UpdateUtilityBar as well,
        -- but ensure it is in a consistent state here.
        self:UpdateUtilityBar()
    else
        SetSecureFrameVisible(self.utilityBar, false)
    end
end

-----------------------------------------------------------------------
-- Config window for /gtb menu
-----------------------------------------------------------------------

local configFrame
local OPT_TITLE_FONT, OPT_BODY_FONT

local tsmSourceList = {
    { value = "dbmarket",          text = "dbmarket" },
    { value = "dbregionmarketavg", text = "dbregionmarketavg" },
    { value = "dbregionsaleavg",   text = "dbregionsaleavg" },
    { value = "dbrecent",          text = "dbrecent" },
    { value = "custom",            text = "Custom (below)" },
}

local function EnsureOptionFonts()
    if OPT_TITLE_FONT and OPT_BODY_FONT then
        return
    end

    OPT_TITLE_FONT = CreateFont("GoblinToolboxOptTitle")
    OPT_TITLE_FONT:SetFont("Fonts\\ARIALN.TTF", 16, "OUTLINE")
    OPT_TITLE_FONT:SetTextColor(0.97, 0.86, 0.29)

    OPT_BODY_FONT = CreateFont("GoblinToolboxOptBody")
    OPT_BODY_FONT:SetFont("Fonts\\ARIALN.TTF", 13, "")
    OPT_BODY_FONT:SetTextColor(0.9, 0.9, 0.9)
end

local function CreateConfigFrame()
    if configFrame then
        return
    end

    EnsureOptionFonts()

    local f = CreateFrame("Frame", "GoblinToolboxConfig", UIParent, "BackdropTemplate")
    configFrame = f

    f:SetSize(440, 540)
    f:SetPoint("CENTER")
    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile     = true, tileSize = 16, edgeSize = 1,
        insets   = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    f:SetBackdropColor(0, 0, 0, 0.9)
    f:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)
    f:Hide()

    local title = f:CreateFontString(nil, "OVERLAY")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetFontObject(OPT_TITLE_FONT)
    title:SetText("Goblin Toolbox")

    local sub = f:CreateFontString(nil, "OVERLAY")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    sub:SetFontObject(OPT_BODY_FONT)
    sub:SetText("A Lightweight goldmaking HUD")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, -2)

    local function CreateCheck(label, x, y)
        local cb = CreateFrame("CheckButton", nil, f, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", x, y)
        cb.Text:SetFontObject(OPT_BODY_FONT)
        cb.Text:SetText(label)
        return cb
    end

    local y = -70

    f.enableCB     = CreateCheck("Enable HUD", 16, y);          y = y - 24
    f.hideCombatCB = CreateCheck("Hide in combat", 16, y);      y = y - 24
    f.hideInstCB   = CreateCheck("Hide in instances", 16, y);   y = y - 24
    f.headerCB     = CreateCheck("Show group headers", 16, y);  y = y - 24
    f.titlebarCB   = CreateCheck("Show title bar", 16, y);      y = y - 24
    f.bgCB         = CreateCheck("Show background", 16, y);     y = y - 28
    f.wbBankDefaultCB = CreateCheck("Prefer Warband Bank when visiting bankers (Will not work with bag addons)", 16, y); y = y - 28

    local tsmLabel = f:CreateFontString(nil, "OVERLAY")
    tsmLabel:SetPoint("TOPLEFT", 16, y)
    tsmLabel:SetFontObject(OPT_BODY_FONT)
    tsmLabel:SetText("Bag value source (TSM)")
    y = y - 20

    f.tsmDropdown = CreateFrame("Frame", "GoblinToolboxTSMDropdown", f, "UIDropDownMenuTemplate")
    f.tsmDropdown:SetPoint("TOPLEFT", 8, y)
    UIDropDownMenu_SetWidth(f.tsmDropdown, 220)

    UIDropDownMenu_Initialize(f.tsmDropdown, function(self, level)
        local info
        local current = addon.db.profile.tsmSource or "dbmarket"
        for _, entry in ipairs(tsmSourceList) do
            info = UIDropDownMenu_CreateInfo()
            info.text = entry.text
            info.arg1 = entry.value

            info.func = function(_, value)
                addon.db.profile.tsmSource = value
                UIDropDownMenu_SetText(f.tsmDropdown, entry.text)
                addon:UpdateInventorySection()
                addon:LayoutHUD()
                QueueBagValueRecalc()
            end

            info.checked = (current == entry.value)
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    y = y - 40

    f.customLabel = f:CreateFontString(nil, "OVERLAY")
    f.customLabel:SetPoint("TOPLEFT", 16, y)
    f.customLabel:SetFontObject(OPT_BODY_FONT)
    f.customLabel:SetText("Custom TSM source")

    f.customEdit = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    f.customEdit:SetPoint("TOPLEFT", f.customLabel, "BOTTOMLEFT", 0, -4)
    f.customEdit:SetSize(240, 20)
    f.customEdit:SetAutoFocus(false)
    f.customEdit:SetFontObject(OPT_BODY_FONT)

    y = y - 40

    local modLabel = f:CreateFontString(nil, "OVERLAY")
    modLabel:SetPoint("TOPLEFT", 16, y)
    modLabel:SetFontObject(OPT_BODY_FONT)
    modLabel:SetText("Modules")
    y = y - 24

    f.charCB    = CreateCheck("Character line", 32, y);            y = y - 24
    f.goldCB    = CreateCheck("Gold & Economy", 32, y);            y = y - 24
    f.invCB     = CreateCheck("Inventory & Currency", 32, y);      y = y - 24
    f.profCB    = CreateCheck("Professions", 32, y);               y = y - 24
    f.utilCB    = CreateCheck("Utility Bar", 32, y);               y = y - 24
    f.trackerCB = CreateCheck("Item Tracker Bar", 32, y)

    local function Refresh()
        local db = addon.db.profile
        f.enableCB:SetChecked(db.enabled)
        f.hideCombatCB:SetChecked(db.hideInCombat)
        f.hideInstCB:SetChecked(db.hideInInstances)
        f.headerCB:SetChecked(db.showHeaders)
        f.titlebarCB:SetChecked(db.showTitleBar)
        f.bgCB:SetChecked(db.showBackground)
        f.wbBankDefaultCB:SetChecked(db.preferWarbandBankOnOpen)

        f.charCB:SetChecked(db.modules.Character ~= false)
        f.goldCB:SetChecked(db.modules.Gold ~= false)
        f.invCB:SetChecked(db.modules.Inventory ~= false)
        f.profCB:SetChecked(db.modules.Professions ~= false)
        f.utilCB:SetChecked(db.modules.Utility ~= false)
        f.trackerCB:SetChecked(db.showTracker)

        local current = db.tsmSource or "dbmarket"
        local text = "dbmarket"
        for _, e in ipairs(tsmSourceList) do
            if e.value == current then
                text = e.text
                break
            end
        end
        UIDropDownMenu_SetText(f.tsmDropdown, text)

        f.customEdit:SetText(db.tsmCustomSource or "")
    end

    local function Apply()
        local db = addon.db.profile

        db.enabled         = f.enableCB:GetChecked()
        db.hideInCombat    = f.hideCombatCB:GetChecked()
        db.hideInInstances = f.hideInstCB:GetChecked()
        db.showHeaders     = f.headerCB:GetChecked()
        db.showTitleBar    = f.titlebarCB:GetChecked()
        db.showBackground  = f.bgCB:GetChecked()
        db.preferWarbandBankOnOpen = f.wbBankDefaultCB:GetChecked()

        db.tsmCustomSource = f.customEdit:GetText() or db.tsmCustomSource

        db.modules.Character   = f.charCB:GetChecked()
        db.modules.Gold        = f.goldCB:GetChecked()
        db.modules.Inventory   = f.invCB:GetChecked()
        db.modules.Professions = f.profCB:GetChecked()
        db.modules.Utility     = f.utilCB:GetChecked()
        db.showTracker         = f.trackerCB:GetChecked()

        addon:UpdateBackground()
        addon:UpdateTitleBar()
        if HUD.UpdateLockTexture then
            HUD.UpdateLockTexture()
        end
        QueueBagValueRecalc()
        addon:UpdateAllSections()
        addon:UpdateUtilityBar()
        addon:UpdateVisibility()
    end

    f:SetScript("OnShow", Refresh)

    local function Hook(cb)
        cb:SetScript("OnClick", Apply)
    end

    Hook(f.enableCB)
    Hook(f.hideCombatCB)
    Hook(f.hideInstCB)
    Hook(f.headerCB)
    Hook(f.titlebarCB)
    Hook(f.bgCB)
    Hook(f.wbBankDefaultCB)
    Hook(f.charCB)
    Hook(f.goldCB)
    Hook(f.invCB)
    Hook(f.profCB)
    Hook(f.utilCB)
    Hook(f.trackerCB)

    f.customEdit:SetScript("OnEnterPressed", function()
        f.customEdit:ClearFocus()
        Apply()
    end)
end

function addon:OpenConfig()
    CreateConfigFrame()
    if configFrame:IsShown() then
        configFrame:Hide()
    else
        configFrame:Show()
    end
end

-----------------------------------------------------------------------
-- Events
-----------------------------------------------------------------------

local EventFrame = CreateFrame("Frame")

EventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        addon.db = addon:GetDB()
        CreateHUD()
        addon:CreateTrackerFrame()
        addon:CreateUtilityBar()
        addon:UpdateBackground()
        addon:UpdateTitleBar()

        if addon.HUD and addon.HUD.UpdateLockTexture then
            addon.HUD.UpdateLockTexture()
        end

        addon:ResetSession()
        addon:StartSessionTicker()
        addon:StartTokenTicker()

        UpdateCharacterGoldCache()

        addon.state.bagValue = addon.state.bagValue or 0
        addon.trackedCounts  = addon.trackedCounts or {}
        addon:UpdateInventorySection()
        QueueBagValueRecalc()

        addon:UpdateAllSections()
        addon:UpdateUtilityBar()
        addon:UpdateUtilityCooldowns()
        addon:UpdateVisibility()

        print("Goblin Toolbox loaded. Type /gtb for options.")

    elseif event == "PLAYER_MONEY" then
        UpdateCharacterGoldCache()
        addon:UpdateGoldSection()
        addon:LayoutHUD()

    elseif event == "PLAYER_LOGOUT" then
        if addon._utilityMovedThisSession then
            SaveUtilityBarPosition()
        end
    elseif event == "ACCOUNT_MONEY" then
        addon:UpdateGoldSection()
        addon:LayoutHUD()

    elseif event == "BAG_UPDATE_DELAYED" then
        QueueBagValueRecalc()

    elseif event == "GUILDBANK_UPDATE_MONEY" then
        UpdateGuildGoldFromBank()
        addon:UpdateGoldSection()
        addon:LayoutHUD()

    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        local interactionType = ...

        if Enum and Enum.PlayerInteractionType
           and interactionType == Enum.PlayerInteractionType.Banker then
            addon:ResetBankAutoSwitchState()
            C_Timer.After(0.05, function()
                addon:TryAutoSwitchToWarbandBank()
            end)
        end

        if Enum and Enum.PlayerInteractionType
           and interactionType == Enum.PlayerInteractionType.GuildBanker then
            C_Timer.After(0.1, function()
                UpdateGuildGoldFromBank()
                addon:UpdateGoldSection()
                addon:LayoutHUD()
            end)
        end

    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
        local interactionType = ...
        if Enum and Enum.PlayerInteractionType
           and interactionType == Enum.PlayerInteractionType.Banker then
            addon:ResetBankAutoSwitchState()
        end

    elseif event == "PLAYER_REGEN_DISABLED" then
        addon:UpdateVisibility()
        addon._needsUtilityRefresh = true

    elseif event == "PLAYER_REGEN_ENABLED" then
        addon:UpdateVisibility()
        if addon._needsUtilityRefresh then
            addon._needsUtilityRefresh = false
            addon:UpdateUtilityBar()
            addon:UpdateUtilityCooldowns()
        end

    elseif event == "PLAYER_ENTERING_WORLD"
        or event == "ZONE_CHANGED_NEW_AREA" then
        addon:UpdateVisibility()

    elseif event == "SPELL_UPDATE_COOLDOWN"
        or event == "BAG_UPDATE_COOLDOWN"
        or event == "SPELL_UPDATE_CHARGES"
        or event == "TOYS_UPDATED"
        or event == "SPELLS_CHANGED"
        or event == "PLAYER_EQUIPMENT_CHANGED" then

        if InCombatLockdown() then
            addon._needsUtilityRefresh = true
            addon:UpdateUtilityCooldowns()
        else
            addon:UpdateUtilityBar()
            addon:UpdateUtilityCooldowns()
        end

    elseif event == "TOKEN_MARKET_PRICE_UPDATED" then
        if addon:UpdateTokenCache() then
            addon:UpdateGoldSection()
            addon:LayoutHUD()
        end
    end
end)

EventFrame:RegisterEvent("PLAYER_LOGIN")
EventFrame:RegisterEvent("PLAYER_MONEY")
EventFrame:RegisterEvent("ACCOUNT_MONEY")
EventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
EventFrame:RegisterEvent("GUILDBANK_UPDATE_MONEY")
EventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
EventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
EventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
EventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
EventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
EventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
EventFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
EventFrame:RegisterEvent("SPELL_UPDATE_CHARGES")
EventFrame:RegisterEvent("SPELLS_CHANGED")
EventFrame:RegisterEvent("TOYS_UPDATED")
EventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
EventFrame:RegisterEvent("TOKEN_MARKET_PRICE_UPDATED")
EventFrame:RegisterEvent("PLAYER_LOGOUT")

-----------------------------------------------------------------------
-- Slash command: /gtb
-----------------------------------------------------------------------

SLASH_GOBLINTOOLBOX1 = "/gtb"

SlashCmdList["GOBLINTOOLBOX"] = function(msg)
    msg = msg or ""
    msg = msg:gsub("^%s+", "")

    local cmd, rest = msg:match("^(%S+)%s*(.*)$")
    cmd  = (cmd or ""):lower()
    rest = rest or ""

    if cmd == "" or cmd == "menu" or cmd == "config" or cmd == "options" then
        addon:OpenConfig()
    elseif cmd == "add" then
        addon:AddTrackedItem(rest)
    elseif cmd == "reset" then
        addon:ResetSession()
        addon:UpdateGoldSection()
        addon:LayoutHUD()
        print("Goblin Toolbox: session reset.")
    elseif cmd == "pause" or cmd == "resume" then
        addon:TogglePauseSession()
        addon:UpdateGoldSection()
        addon:LayoutHUD()
    elseif cmd == "lock" then
        addon.db.profile.lockFrame = true
        if addon.HUD.UpdateLockTexture then
            addon.HUD.UpdateLockTexture()
        end
        print("Goblin Toolbox: frame locked.")
    elseif cmd == "unlock" then
        addon.db.profile.lockFrame = false
        if addon.HUD.UpdateLockTexture then
            addon.HUD.UpdateLockTexture()
        end
        print("Goblin Toolbox: frame unlocked.")
    elseif cmd == "show" then
        addon.db.profile.enabled = true
        addon:UpdateVisibility()
    elseif cmd == "hide" then
        addon.db.profile.enabled = false
        addon:UpdateVisibility()
    elseif cmd == "headers" then
        addon.db.profile.showHeaders = not addon.db.profile.showHeaders
        addon:UpdateAllSections()
        print("Goblin Toolbox: headers", addon.db.profile.showHeaders and "enabled" or "disabled")
    else
        print("Goblin Toolbox commands:")
        print("  /gtb              - open settings window")
        print("  /gtb add [link]   - add tracked item")
        print("  /gtb reset        - reset gold session")
        print("  /gtb pause        - pause or resume session timer")
        print("  /gtb lock         - lock HUD position")
        print("  /gtb unlock       - unlock HUD position")
        print("  /gtb show         - show HUD")
        print("  /gtb hide         - hide HUD")
        print("  /gtb headers      - toggle group headers")
    end
end
