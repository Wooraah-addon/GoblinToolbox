-- Modules/Gold.lua
-- Gold & Economy module: character gold, warband gold, guild gold, session tracking, token price

local addonName, addon = ...

local Gold = {}
addon:RegisterModule("Gold", Gold)

-----------------------------------------------------------------------
-- Character gold cache
-----------------------------------------------------------------------

function Gold:UpdateCharacterCache()
    local key = addon:GetCharacterKey()
    local db = addon.db
    db.characters[key] = db.characters[key] or {}
    db.characters[key].gold = GetMoney()
end

-----------------------------------------------------------------------
-- Guild bank tracking
-----------------------------------------------------------------------

function Gold:UpdateGuildGoldFromBank()
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
    db.guilds[guildName].gold = money
    db.guilds[guildName].lastUpdate = time()
end

function Gold:GetGuildGold()
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
-- Session tracking
-----------------------------------------------------------------------

function Gold:ResetSession()
    local s = addon.state
    s.sessionStartGold = GetMoney()
    s.sessionStartTime = time()
    s.sessionPaused = false
    s.pauseStartTime = nil
    s.pausedDuration = 0
end

function Gold:TogglePauseSession()
    local s = addon.state
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
        s.sessionPaused = true
        s.pauseStartTime = time()
        print("Goblin Toolbox: session paused.")
    end
end

function Gold:GetSessionStats()
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

-----------------------------------------------------------------------
-- Session ticker
-----------------------------------------------------------------------

Gold._sessionTicker = nil

function Gold:StartSessionTicker()
    if self._sessionTicker then
        return
    end

    self._sessionTicker = C_Timer.NewTicker(addon.CONST.SESSION_TICK_INTERVAL, function()
        if not addon.db or not addon.db.profile then
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
-- WoW Token tracking (price + simple trend)
-----------------------------------------------------------------------

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
    while #hist > addon.CONST.TOKEN_HISTORY_SIZE do
        table.remove(hist, 1)
    end
end

function Gold:GetTokenTrend()
    local hist = addon.token and addon.token.history
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
    local threshold = addon.CONST.TOKEN_TREND_THRESHOLD

    if delta > threshold then
        return "up"
    elseif delta < -threshold then
        return "down"
    end

    return "flat"
end

function Gold:RequestTokenPrice()
    if C_WowTokenPublic and C_WowTokenPublic.UpdateMarketPrice then
        C_WowTokenPublic.UpdateMarketPrice()
        return true
    end
    return false
end

function Gold:ReadTokenPrice()
    if C_WowTokenPublic and C_WowTokenPublic.GetCurrentMarketPrice then
        local price = C_WowTokenPublic.GetCurrentMarketPrice()
        if type(price) == "number" and price > 0 then
            return price
        end
    end
    return nil
end

function Gold:UpdateTokenCache()
    local price = self:ReadTokenPrice()
    if not price then
        return false
    end

    addon.token.lastPrice = price
    addon.token.lastUpdated = time()
    TokenHistoryPush(price)
    return true
end

Gold._tokenTicker = nil

function Gold:StartTokenTicker()
    if self._tokenTicker then
        return
    end

    self:RequestTokenPrice()

    self._tokenTicker = C_Timer.NewTicker(addon.CONST.TOKEN_POLL_INTERVAL, function()
        if not addon.db or not addon.db.profile then
            return
        end
        if not addon.db.profile.enabled then
            return
        end
        Gold:RequestTokenPrice()
    end)
end

-----------------------------------------------------------------------
-- Section update (called by HUD)
-----------------------------------------------------------------------

function Gold:Update()
    -- Treat nil as enabled, older saved variables may not have the key.
    if addon.db.profile.modules.Gold == false then
        return
    end

    
    local sec = addon.HUD and addon.HUD.sections and addon.HUD.sections.Gold
    if not sec then
        return
    end

    local db = addon.db.profile
    local elem = db.elements or {}

    self:UpdateCharacterCache()

    -- Line 1: Character gold, Warband gold, Guild gold
    local goldParts = {}
    
    if elem.goldCharacter ~= false then
        local charGold = GetMoney()
        table.insert(goldParts, "Char: " .. addon:FormatMoney(charGold))
    end
    
    if elem.goldWarband ~= false then
        local warbandGold = addon:GetWarbandBankGold()
        table.insert(goldParts, "WB: " .. addon:FormatMoney(warbandGold))
    end
    
    if elem.goldGuild ~= false then
        local guildGold, guildName, guildLastUpdate = self:GetGuildGold()
        local guildText

        if not guildName then
            guildText = "None"
        elseif guildGold then
            guildText = addon:FormatMoney(guildGold)

            local isStale = false
            if guildLastUpdate then
                if (time() - guildLastUpdate) > addon.CONST.GUILD_STALE_THRESHOLD then
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
        
        table.insert(goldParts, "Guild: " .. guildText)
    end

    if #goldParts > 0 then
        sec.lines[1]:SetText(table.concat(goldParts, "   "))
    else
        sec.lines[1]:SetText("")
    end

    -- Line 2: Session tracking
    if elem.goldSession ~= false then
        local elapsed, net, gph = self:GetSessionStats()
        local hours = math.floor(elapsed / 3600)
        local minutes = math.floor((elapsed % 3600) / 60)
        local timeStr
        if hours > 0 then
            timeStr = string.format("%dh %02dm", hours, minutes)
        else
            timeStr = string.format("%dm", minutes)
        end

        sec.lines[2]:SetText(string.format("Session: %s  Earnt: %s  (%s / h)",
            timeStr, addon:FormatMoney(net), addon:FormatMoney(gph)))
    else
        sec.lines[2]:SetText("")
    end

    -- Line 3: Token price
    if elem.goldToken ~= false then
        local tokenPrice = addon.token and addon.token.lastPrice or 0
        if tokenPrice and tokenPrice > 0 then
            local trend = self:GetTokenTrend()
            local marker = " "
            if trend == "up" then
                marker = "▲"
            elseif trend == "down" then
                marker = "▼"
            end

            sec.lines[3]:SetText(string.format("Token: %s %s", addon:FormatMoney(tokenPrice), marker))
        else
            sec.lines[3]:SetText("Token: n/a")
        end
    else
        sec.lines[3]:SetText("")
    end
end

-----------------------------------------------------------------------
-- Expose module to addon for backward compatibility during transition
-----------------------------------------------------------------------

-- These wrapper functions let existing code continue to work
function addon:ResetSession()
    Gold:ResetSession()
end

function addon:TogglePauseSession()
    Gold:TogglePauseSession()
end

function addon:UpdateGoldSection()
    Gold:Update()
end

function addon:StartSessionTicker()
    Gold:StartSessionTicker()
end

function addon:StartTokenTicker()
    Gold:StartTokenTicker()
end

function addon:UpdateTokenCache()
    return Gold:UpdateTokenCache()
end

function addon:RequestTokenPrice()
    return Gold:RequestTokenPrice()
end

-- Expose for event handlers
addon.Gold = Gold
