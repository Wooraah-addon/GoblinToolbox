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
    s.pauseGoldSnapshot = nil
    -- Earned/Spent tracking
    s.sessionEarned = 0
    s.sessionSpent = 0
    s.lastMoney = GetMoney()
end

function Gold:TogglePauseSession()
    local s = addon.state
    if not s.sessionStartTime then
        self:ResetSession()
        return
    end

    if s.sessionPaused then
        -- Resuming: adjust baseline to exclude gold changes during pause
        s.sessionPaused = false
        if s.pauseStartTime then
            s.pausedDuration = s.pausedDuration + (time() - s.pauseStartTime)
        end
        s.pauseStartTime = nil

        -- Adjust sessionStartGold to exclude gold gained/lost during pause
        if s.pauseGoldSnapshot then
            local goldDuringPause = GetMoney() - s.pauseGoldSnapshot
            s.sessionStartGold = s.sessionStartGold + goldDuringPause
            s.pauseGoldSnapshot = nil
        end

        -- Reset lastMoney to current gold so delta tracking starts clean
        s.lastMoney = GetMoney()

        print("Goblin Toolbox: session resumed.")
    else
        -- Pausing: snapshot current gold
        s.sessionPaused = true
        s.pauseStartTime = time()
        s.pauseGoldSnapshot = GetMoney()
        print("Goblin Toolbox: session paused.")
    end
end

function Gold:SaveSessionState()
    if not addon.db or not addon.db.profile then
        return
    end

    local db = addon.db.profile
    local s = addon.state

    -- Only save if persistence is enabled
    if not db.sessionPersistOnLogout then
        -- Clear any existing saved state if persistence is disabled
        db.sessionState = {}
        return
    end

    -- Save session state to SavedVariables (character-specific)
    db.sessionState = {
        characterKey = addon:GetCharacterKey(),
        sessionStartGold = s.sessionStartGold,
        sessionStartTime = s.sessionStartTime,
        sessionPaused = s.sessionPaused,
        pauseStartTime = s.pauseStartTime,
        pausedDuration = s.pausedDuration or 0,
        pauseGoldSnapshot = s.pauseGoldSnapshot,
        sessionEarned = s.sessionEarned or 0,
        sessionSpent = s.sessionSpent or 0,
        lastMoney = s.lastMoney,
        lastLogoutTime = time(),
    }
end

function Gold:LoadSessionState()
    if not addon.db or not addon.db.profile then
        return false
    end

    local db = addon.db.profile
    local saved = db.sessionState

    -- Only restore if persistence is enabled and saved state exists
    if not db.sessionPersistOnLogout or not saved or not saved.sessionStartTime then
        return false
    end

    -- Only restore if saved state is for THIS character
    local currentCharKey = addon:GetCharacterKey()
    if saved.characterKey and saved.characterKey ~= currentCharKey then
        return false
    end

    local now = time()
    local s = addon.state

    -- Restore session state
    s.sessionStartGold = saved.sessionStartGold
    s.sessionStartTime = saved.sessionStartTime
    s.sessionPaused = saved.sessionPaused
    s.pauseStartTime = saved.pauseStartTime
    s.pausedDuration = saved.pausedDuration or 0
    s.pauseGoldSnapshot = saved.pauseGoldSnapshot
    s.sessionEarned = saved.sessionEarned or 0
    s.sessionSpent = saved.sessionSpent or 0
    s.lastMoney = GetMoney()  -- Reset to current gold for clean delta tracking

    -- Add offline time to paused duration (treat offline as paused)
    if saved.lastLogoutTime and saved.lastLogoutTime > 0 then
        local offlineTime = math.max(0, now - saved.lastLogoutTime)
        s.pausedDuration = s.pausedDuration + offlineTime
    end

    -- If session was paused, update pause start time and gold snapshot
    if s.sessionPaused then
        s.pauseStartTime = now
        s.pauseGoldSnapshot = GetMoney()
    end

    return true
end

function Gold:GetSessionStats()
    local s = addon.state
    if not s.sessionStartTime or not s.sessionStartGold then
        return 0, 0, 0
    end

    local now = time()
    local elapsed = now - s.sessionStartTime

    if s.sessionPaused and s.pauseStartTime then
        elapsed = s.pauseStartTime - s.sessionStartTime - (s.pausedDuration or 0)
    else
        elapsed = elapsed - (s.pausedDuration or 0)
    end

    if elapsed < 1 then
        elapsed = 1
    end

    -- Use frozen gold snapshot while paused, current gold otherwise
    local currentGold = (s.sessionPaused and s.pauseGoldSnapshot) or GetMoney()
    local net = currentGold - s.sessionStartGold
    local gph = net * 3600 / elapsed

    return elapsed, net, gph
end

-----------------------------------------------------------------------
-- Session ticker
-----------------------------------------------------------------------

Gold._sessionTicker = nil
Gold._lastSessionSave = 0

-- Track earned/spent deltas based on gold changes
local function UpdateEarnedSpent()
    local s = addon.state

    -- Skip if session not started or paused
    if not s.sessionStartTime or s.sessionPaused then
        return
    end

    local currentMoney = GetMoney()

    -- Guard against GetMoney() returning 0 during login/loading
    if not currentMoney or currentMoney == 0 then
        return
    end

    -- Initialize lastMoney if not set or was 0
    if not s.lastMoney or s.lastMoney == 0 then
        s.lastMoney = currentMoney
        return
    end

    local delta = currentMoney - s.lastMoney

    -- Guard against unreasonably large deltas (likely from login race condition)
    -- Skip deltas larger than 100,000 gold in a single tick
    local maxDelta = 100000 * 10000  -- 100k gold in copper
    if math.abs(delta) > maxDelta then
        s.lastMoney = currentMoney
        return
    end

    if delta > 0 then
        s.sessionEarned = (s.sessionEarned or 0) + delta
    elseif delta < 0 then
        s.sessionSpent = (s.sessionSpent or 0) + math.abs(delta)
    end

    s.lastMoney = currentMoney
end

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

        -- Track earned/spent deltas
        UpdateEarnedSpent()

        addon:UpdateGoldSection()
        addon:SafeLayoutHUD()

        -- Periodic backup save (once per minute) in case of crashes
        local now = time()
        if db.sessionPersistOnLogout and (now - Gold._lastSessionSave) >= 60 then
            addon:SaveSessionState()
            Gold._lastSessionSave = now
        end
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

-- Helper to format signed money with color (green positive, red negative)
local function FormatSignedMoney(amount)
    if amount >= 0 then
        return "|cff00ff00+" .. addon:FormatMoney(amount) .. "|r"
    else
        return "|cffff4444-" .. addon:FormatMoney(math.abs(amount)) .. "|r"
    end
end

-- Clock/timer icons (textures with color tinting)
local CLOCK_ICON_GREEN = "|TInterface\\COMMON\\mini-hourglass:0:0:0:0:16:16:0:16:0:16:0:255:0|t"
local CLOCK_ICON_RED = "|TInterface\\COMMON\\mini-hourglass:0:0:0:0:16:16:0:16:0:16:255:0:0|t"

function Gold:Update()
    -- Nil guard for database
    if not addon.db or not addon.db.profile then
        return
    end

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
    local s = addon.state
    local isDetailed = (db.goldViewMode == "detailed")

    self:UpdateCharacterCache()

    -- Line 1: Character gold, Warband gold, Guild gold (same for both modes)
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

    -- Session tracking rendering depends on view mode
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

        local isPaused = s.sessionPaused

        -- Session time display: clock icon + time (red when paused, green when running)
        local sessionTimeDisplay
        if isPaused then
            sessionTimeDisplay = string.format("%s |cffff4444%s|r", CLOCK_ICON_RED, timeStr)
        else
            sessionTimeDisplay = string.format("%s |cff00ff00%s|r", CLOCK_ICON_GREEN, timeStr)
        end

        if isDetailed then
            -- DETAILED MODE
            -- Line 2: Clock + time + Start + Current + GPH
            local startGold = s.sessionStartGold or 0
            local currentGold = (isPaused and s.pauseGoldSnapshot) or GetMoney()

            sec.lines[2]:SetText(string.format("%s  Start: %s  Current: %s  (%s/h)",
                sessionTimeDisplay, addon:FormatMoney(startGold), addon:FormatMoney(currentGold), addon:FormatMoney(gph)))

            -- Line 3: Earned / Spent / Net
            local earned = s.sessionEarned or 0
            local spent = s.sessionSpent or 0
            local netDisplay = FormatSignedMoney(net)

            sec.lines[3]:SetText(string.format("Earned: %s  Spent: %s  Net: %s",
                addon:FormatMoney(earned), addon:FormatMoney(spent), netDisplay))

            -- Line 4: Token (in detailed mode)
            if elem.goldToken ~= false then
                local tokenPrice = addon.token and addon.token.lastPrice or 0
                if tokenPrice and tokenPrice > 0 then
                    local trend = self:GetTokenTrend()
                    local marker = ""
                    if trend == "up" then
                        marker = " |cff00ff00▲|r"
                    elseif trend == "down" then
                        marker = " |cffff4444▼|r"
                    end

                    sec.lines[4]:SetText(string.format("Token: %s%s", addon:FormatMoney(tokenPrice), marker))
                else
                    sec.lines[4]:SetText("Token: n/a")
                end
            else
                sec.lines[4]:SetText("")
            end
        else
            -- SIMPLE MODE
            -- Line 2: Clock + time + net + GPH
            sec.lines[2]:SetText(string.format("%s  Earned: %s  (%s/h)",
                sessionTimeDisplay, addon:FormatMoney(net), addon:FormatMoney(gph)))

            -- Line 3: Token (in simple mode)
            if elem.goldToken ~= false then
                local tokenPrice = addon.token and addon.token.lastPrice or 0
                if tokenPrice and tokenPrice > 0 then
                    local trend = self:GetTokenTrend()
                    local marker = ""
                    if trend == "up" then
                        marker = " |cff00ff00▲|r"
                    elseif trend == "down" then
                        marker = " |cffff4444▼|r"
                    end

                    sec.lines[3]:SetText(string.format("Token: %s%s", addon:FormatMoney(tokenPrice), marker))
                else
                    sec.lines[3]:SetText("Token: n/a")
                end
            else
                sec.lines[3]:SetText("")
            end

            -- Line 4: Empty in simple mode
            sec.lines[4]:SetText("")
        end
    else
        -- Session disabled
        sec.lines[2]:SetText("")
        sec.lines[3]:SetText("")
        sec.lines[4]:SetText("")

        -- Still show token if enabled but session disabled
        if elem.goldToken ~= false and not isDetailed then
            local tokenPrice = addon.token and addon.token.lastPrice or 0
            if tokenPrice and tokenPrice > 0 then
                local trend = self:GetTokenTrend()
                local marker = ""
                if trend == "up" then
                    marker = " |cff00ff00▲|r"
                elseif trend == "down" then
                    marker = " |cffff4444▼|r"
                end
                sec.lines[3]:SetText(string.format("Token: %s%s", addon:FormatMoney(tokenPrice), marker))
            else
                sec.lines[3]:SetText("Token: n/a")
            end
        end
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

function addon:SaveSessionState()
    return Gold:SaveSessionState()
end

function addon:LoadSessionState()
    return Gold:LoadSessionState()
end

-- Expose for event handlers
addon.Gold = Gold
