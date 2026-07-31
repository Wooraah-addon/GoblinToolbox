-- Modules/Gold.lua
-- Gold & Economy module: character gold, warband gold, guild gold, session tracking, token price

local addonName, addon = ...

local Gold = {}
addon:RegisterModule("Gold", Gold)

-----------------------------------------------------------------------
-- Bank transfer intent tracking
-----------------------------------------------------------------------

-- Queue of pending money intents for transfer matching
-- Each entry: { ts = GetTime(), amount = copper (signed), source = "guild"/"warband" }
local pendingMoneyIntents = {}

-- Debug logging toggle (stored in saved variables)
local function IsDebugEnabled()
    return addon.db and addon.db.profile and addon.db.profile.debugTransfers
end

local function LogTransfer(msg)
    if IsDebugEnabled() then
        print("|cff00ff00[GTB Transfer]|r " .. msg)
    end
end

-- Add a transfer intent to the queue
local function EnqueueTransferIntent(amount, source)
    local intent = {
        ts = GetTime(),
        amount = amount,  -- Signed: negative for deposits, positive for withdrawals
        source = source,  -- "guild" or "warband"
    }
    table.insert(pendingMoneyIntents, intent)
    LogTransfer(string.format("Queued %s intent: %s copper", source, tostring(amount)))
end

-- Expire old intents (older than 2 seconds)
local function ExpireOldIntents()
    local now = GetTime()
    local i = 1
    while i <= #pendingMoneyIntents do
        if (now - pendingMoneyIntents[i].ts) > 2.0 then
            LogTransfer(string.format("Expired %s intent: %s copper (unmatched)",
                pendingMoneyIntents[i].source, tostring(pendingMoneyIntents[i].amount)))
            table.remove(pendingMoneyIntents, i)
        else
            i = i + 1
        end
    end
end

-- Attempt to match and consume a transfer intent from player delta
-- Returns: adjustedDelta, matchedAmount (or nil if no match)
local function TryConsumeTransferIntent(playerDelta)
    if #pendingMoneyIntents == 0 then
        return playerDelta, nil
    end

    ExpireOldIntents()

    -- Look for a matching intent
    for i = 1, #pendingMoneyIntents do
        local intent = pendingMoneyIntents[i]

        -- Check sign matches
        local signsMatch = (playerDelta > 0 and intent.amount > 0) or
                          (playerDelta < 0 and intent.amount < 0) or
                          (playerDelta == 0 and intent.amount == 0)

        if signsMatch then
            -- Check magnitude with symmetric tolerance (delta can be slightly less OR more)
            local intentMag = math.abs(intent.amount)
            local deltaMag = math.abs(playerDelta)
            local tolerance = math.max(10000, intentMag * 0.05)  -- 1g or 5%, whichever is larger

            if deltaMag >= (intentMag - tolerance) and deltaMag <= (intentMag + tolerance) then
                -- Match found!
                local matchedAmount = intent.amount
                LogTransfer(string.format("Matched %s transfer: intent=%s, delta=%s",
                    intent.source, tostring(intent.amount), tostring(playerDelta)))

                -- Remove this intent from queue
                table.remove(pendingMoneyIntents, i)

                -- Return adjusted delta (subtract matched portion)
                return playerDelta - matchedAmount, matchedAmount
            end
        end
    end

    -- No match found
    return playerDelta, nil
end

-----------------------------------------------------------------------
-- Character gold cache
-----------------------------------------------------------------------

function Gold:UpdateCharacterCache()
    local key = addon:GetCharacterKey()
    local db = addon.db
    db.characters[key] = db.characters[key] or {}
    db.characters[key].gold = GetMoney()

    -- Also cache posted auction data per character
    local s = addon.state
    db.characters[key].postedAuctionValueCopper = s.postedAuctionValueCopper or 0
    db.characters[key].postedAuctionCount = s.postedAuctionCount or 0
end

-----------------------------------------------------------------------
-- Guild bank tracking
-----------------------------------------------------------------------

function Gold:UpdateGuildGoldFromBank()
    local guildName, _, _, guildRealm = GetGuildInfo("player")
    if not guildName then
        return
    end
    if not guildRealm or guildRealm == "" then
        guildRealm = GetNormalizedRealmName()
    end
    if not guildRealm or guildRealm == "" then
        return
    end

    local money = GetGuildBankMoney()
    if money == nil then
        return
    end

    local db = addon.db
    local guildKey = guildName .. "-" .. guildRealm
    db.guilds[guildKey] = db.guilds[guildKey] or {}
    db.guilds[guildKey].gold = money
    db.guilds[guildKey].lastUpdate = time()
end

function Gold:GetGuildGold()
    local guildName, _, _, guildRealm = GetGuildInfo("player")
    if not guildName then
        return nil, nil, nil
    end
    if not guildRealm or guildRealm == "" then
        guildRealm = GetNormalizedRealmName()
    end
    local guildKey = (guildRealm and guildRealm ~= "") and (guildName .. "-" .. guildRealm) or nil

    -- Prefer realm-qualified key, fall back to legacy name-only key
    local data = guildKey and addon.db.guilds[guildKey]
    if data and type(data.gold) == "number" then
        return data.gold, guildName, data.lastUpdate
    end

    -- Legacy fallback: name-only key from before realm was added
    local legacy = addon.db.guilds[guildName]
    if legacy and type(legacy.gold) == "number" then
        return legacy.gold, guildName, legacy.lastUpdate
    end

    return nil, guildName, nil
end

-----------------------------------------------------------------------
-- Session tracking
-----------------------------------------------------------------------

function Gold:ResetSession()
    local s = addon.state
    s.sessionStartGold = GetMoney()
    s.sessionStartTime = time()
    s.sessionPaused = false
    s.pausedByAFK = false
    s.pauseStartTime = nil
    s.pausedDuration = 0
    s.pauseGoldSnapshot = nil
    -- Earned/Spent tracking
    s.sessionEarned = 0
    s.sessionSpent = 0
    s.lastMoney = GetMoney()
    -- Looted value tracking
    s.sessionLootedValueCopper = 0
    -- Transfer offset tracking (bank deposits/withdrawals)
    s.sessionTransferOffset = 0
    -- Posted auction tracking is NOT reset (not session-based)
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

function Gold:PauseSessionForAFK()
    local s = addon.state

    -- Don't pause if already paused (manually or by AFK)
    if s.sessionPaused then
        return
    end

    -- Don't pause if no session active
    if not s.sessionStartTime then
        return
    end

    -- Pause and mark as AFK-triggered
    s.sessionPaused = true
    s.pausedByAFK = true
    s.pauseStartTime = time()
    s.pauseGoldSnapshot = GetMoney()

    print("|cff00ff00Goblin Toolbox:|r Session auto-paused - AFK")
end

function Gold:ResumeSessionFromAFK()
    local s = addon.state

    -- Only resume if paused BY AFK (not manually paused)
    if not s.sessionPaused or not s.pausedByAFK then
        return
    end

    -- Resume session
    s.sessionPaused = false
    s.pausedByAFK = false

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

    print("|cff00ff00Goblin Toolbox:|r Session auto-resumed - No longer AFK")
end

function Gold:SaveSessionState()
    if not addon.db or not addon.db.profile then
        if IsDebugEnabled() then
            print("|cffff4444[GTB Session]|r Save failed: no db")
        end
        return
    end

    local db = addon.db.profile
    local s = addon.state

    if IsDebugEnabled() then
        local persistenceStatus = addon.db.global.sessionPersistOnLogout and "enabled" or "disabled"
        print("|cff00ff00[GTB Session]|r Saving session state (persistence: " .. persistenceStatus .. ")")
    end

    -- Always save session state (even when persistence is OFF)
    -- This allows reload to continue the session, while full logout resets it
    -- The load logic handles whether to restore based on persistence + time gap
    local charCache = addon:GetCharacterCache()
    if charCache then
        charCache.sessionState = {
            characterKey = s.characterKey or addon:GetCharacterKey(),
            sessionStartGold = s.sessionStartGold,
            sessionStartTime = s.sessionStartTime,
            sessionPaused = s.sessionPaused,
            pausedByAFK = s.pausedByAFK or false,  -- Save AFK pause flag to distinguish from manual pause
            pauseStartTime = s.pauseStartTime,
            pausedDuration = s.pausedDuration or 0,
            pauseGoldSnapshot = s.pauseGoldSnapshot,
            sessionEarned = s.sessionEarned or 0,
            sessionSpent = s.sessionSpent or 0,
            lastMoney = s.lastMoney,
            sessionLootedValueCopper = s.sessionLootedValueCopper or 0,
            sessionTransferOffset = s.sessionTransferOffset or 0,
            lastLogoutTime = time(),
        }
    end

    -- Posted auction data is saved per-character via UpdateCharacterCache()
    -- (called separately, not part of session state)
end

function Gold:LoadSessionState()
    if not addon.db or not addon.db.profile then
        if IsDebugEnabled() then
            print("|cffff4444[GTB Session]|r Load failed: no db")
        end
        return false
    end

    -- Read and clear the reload flag up front. This must happen before any of
    -- the early returns below: if the flag is left set (e.g. no saved session on
    -- this character), the next full logout looks like a reload and the session
    -- is wrongly restored even with persistence turned off.
    local isReload = addon.db.global.isReloading == true
    addon.db.global.isReloading = false

    local db = addon.db.profile

    -- Load from character-specific cache
    local charCache = addon:GetCharacterCache()
    if not charCache or not charCache.sessionState then
        if IsDebugEnabled() then
            print("|cffff4444[GTB Session]|r Load failed: no character cache or session state")
        end
        return false
    end

    local saved = charCache.sessionState

    if not saved.sessionStartTime then
        if IsDebugEnabled() then
            print("|cffff4444[GTB Session]|r Load failed: no start time")
        end
        return false
    end

    -- Only restore if saved state is for THIS character
    local currentCharKey = addon:GetCharacterKey()
    if saved.characterKey and saved.characterKey ~= currentCharKey then
        if IsDebugEnabled() then
            print("|cffff4444[GTB Session]|r Load failed: wrong character (saved: " .. tostring(saved.characterKey) .. ", current: " .. tostring(currentCharKey) .. ")")
        end
        return false
    end

    -- Persistence logic:
    -- - If persistence ON: always restore
    -- - If persistence OFF: restore only on reload, not on full logout
    if not addon.db.global.sessionPersistOnLogout and not isReload then
        if IsDebugEnabled() then
            print("|cffff4444[GTB Session]|r Load skipped: persistence disabled and not a reload")
        end
        return false
    end

    if IsDebugEnabled() then
        print("|cff00ff00[GTB Session]|r Loading session state")
    end

    local now = time()
    local s = addon.state

    -- Restore session state
    s.sessionStartGold = saved.sessionStartGold
    s.sessionStartTime = saved.sessionStartTime
    s.sessionPaused = saved.sessionPaused
    s.pausedByAFK = saved.pausedByAFK or false  -- Load the AFK pause flag
    s.pauseStartTime = saved.pauseStartTime
    s.pausedDuration = saved.pausedDuration or 0
    s.pauseGoldSnapshot = saved.pauseGoldSnapshot
    s.sessionEarned = saved.sessionEarned or 0
    s.sessionSpent = saved.sessionSpent or 0
    s.lastMoney = GetMoney()  -- Reset to current gold for clean delta tracking
    s.sessionLootedValueCopper = saved.sessionLootedValueCopper or 0
    s.sessionTransferOffset = saved.sessionTransferOffset or 0

    -- Posted auction data is loaded separately via InitializePostedAuctions()

    -- Add offline time to paused duration (treat offline as paused)
    if saved.lastLogoutTime and saved.lastLogoutTime > 0 then
        local offlineTime = math.max(0, now - saved.lastLogoutTime)
        s.pausedDuration = s.pausedDuration + offlineTime
    end

    -- Handle paused state restoration based on pause type
    if s.sessionPaused then
        if s.pausedByAFK then
            -- Was AFK-paused when logged out: auto-resume on login
            s.sessionPaused = false
            s.pausedByAFK = false
            s.pauseStartTime = nil
            s.pauseGoldSnapshot = nil
            print("|cff00ff00Goblin Toolbox:|r Session auto-resumed (was AFK-paused)")
        else
            -- Was manually paused: keep it paused on login
            s.pauseStartTime = now
            s.pauseGoldSnapshot = GetMoney()
        end
    end

    if IsDebugEnabled() then
        print("|cff00ff00[GTB Session]|r Session state loaded successfully")
    end

    return true
end

function Gold:InitializePostedAuctions()
    -- Load posted auction data from character-specific saved variables
    local db = addon.db
    if not db then
        return
    end

    local key = addon:GetCharacterKey()
    local charData = db.characters and db.characters[key]
    if not charData then
        return
    end

    local s = addon.state
    s.postedAuctionValueCopper = charData.postedAuctionValueCopper or 0
    s.postedAuctionCount = charData.postedAuctionCount or 0
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
    local rawNet = currentGold - s.sessionStartGold

    -- Adjust net by subtracting transfer offset (neutralizes bank deposits/withdrawals)
    local net = rawNet - (s.sessionTransferOffset or 0)
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

    -- Try to match and consume a bank transfer intent
    local adjustedDelta, matchedTransfer = TryConsumeTransferIntent(delta)

    if matchedTransfer then
        -- This delta (or part of it) was a bank transfer
        -- Update transfer offset to neutralize it from Net calculation
        s.sessionTransferOffset = (s.sessionTransferOffset or 0) + matchedTransfer
        LogTransfer(string.format("Transfer offset updated: %s (total: %s)",
            tostring(matchedTransfer), tostring(s.sessionTransferOffset)))
    end

    -- Apply the adjusted delta to Earned/Spent
    if adjustedDelta > 0 then
        s.sessionEarned = (s.sessionEarned or 0) + adjustedDelta
    elseif adjustedDelta < 0 then
        s.sessionSpent = (s.sessionSpent or 0) + math.abs(adjustedDelta)
    end

    s.lastMoney = currentMoney
end

-- Public wrapper for immediate updates (called from PLAYER_MONEY event)
function Gold:UpdateEarnedSpentImmediate()
    UpdateEarnedSpent()
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

        -- Periodic backup save (once per minute)
        -- Always save for reload detection, regardless of persistence setting
        local now = time()
        if (now - Gold._lastSessionSave) >= 60 then
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

    -- Time gate: only push if at least 60 seconds since last sample
    -- This allows history to grow even when price is stable
    local now = time()
    local lastSampleTime = t.lastSampleTime or 0
    local timeSinceLastSample = now - lastSampleTime

    -- Skip if duplicate AND less than 60 seconds since last sample
    if hist[#hist] == priceCopper and timeSinceLastSample < 60 then
        return
    end

    table.insert(hist, priceCopper)
    t.lastSampleTime = now

    while #hist > addon.CONST.TOKEN_HISTORY_SIZE do
        table.remove(hist, 1)
    end
end

function Gold:GetTokenTrend()
    local hist = addon.token and addon.token.history
    if not hist or #hist < 2 then
        return "flat"
    end

    local n = #hist
    local threshold = addon.CONST.TOKEN_TREND_THRESHOLD

    -- Fallback for short histories (2-5 samples): simple delta comparison
    if n < 6 then
        local latest = hist[n]
        local compareIndex = math.max(1, n - 3)  -- Compare to 3 samples back (or earliest)
        local earlier = hist[compareIndex]

        if not latest or not earlier or latest <= 0 or earlier <= 0 then
            return "flat"
        end

        local delta = latest - earlier

        if delta > threshold then
            return "up"
        elseif delta < -threshold then
            return "down"
        end

        return "flat"
    end

    -- Full averaging logic for 6+ samples
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

    local prevAvg = Avg(n - 5, n - 3)
    local lastAvg = Avg(n - 2, n)

    if prevAvg <= 0 or lastAvg <= 0 then
        return "flat"
    end

    local delta = lastAvg - prevAvg

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
-- Looted item value tracking (per session)
-----------------------------------------------------------------------

-- Pending retry queue for uncached items
local lootedValuePendingQueue = {}
local lootedValueRetryPending = false

local function RetryPendingLootedItems()
    lootedValueRetryPending = false

    if #lootedValuePendingQueue == 0 then
        return
    end

    local stillPending = {}
    local s = addon.state

    for _, entry in ipairs(lootedValuePendingQueue) do
        local itemLink = entry.itemLink
        local quantity = entry.quantity

        -- Try to get item info again
        local name = addon.API.GetItemInfo(itemLink)
        if name then
            -- Item cached now, calculate price
            local price = 0
            if addon.Inventory then
                price = addon.Inventory:GetItemPrice(itemLink)
            end

            if price > 0 then
                s.sessionLootedValueCopper = (s.sessionLootedValueCopper or 0) + (price * quantity)
            end
        else
            -- Still not cached, keep in pending queue
            table.insert(stillPending, entry)
        end
    end

    lootedValuePendingQueue = stillPending

    -- If still items pending, schedule another retry
    if #lootedValuePendingQueue > 0 then
        lootedValueRetryPending = true
        C_Timer.After(0.5, RetryPendingLootedItems)
    end
end

function Gold:HandleLootMessage(message)
    -- Skip if session not started or paused
    local s = addon.state
    if not s.sessionStartTime or s.sessionPaused then
        return
    end

    -- Parse loot message using global patterns
    -- LOOT_ITEM_SELF = "You receive loot: %s."
    -- LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."

    local itemLink, quantity

    -- Try multiple pattern first
    if LOOT_ITEM_SELF_MULTIPLE then
        local pattern = LOOT_ITEM_SELF_MULTIPLE:gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
        itemLink, quantity = message:match(pattern)
        if itemLink and quantity then
            quantity = tonumber(quantity)
        end
    end

    -- Try single item pattern if multiple didn't match
    if not itemLink and LOOT_ITEM_SELF then
        local pattern = LOOT_ITEM_SELF:gsub("%%s", "(.+)")
        itemLink = message:match(pattern)
        if itemLink then
            quantity = 1
        end
    end

    if not itemLink or not quantity then
        return
    end

    -- Try to get item info (may not be cached yet)
    local name = addon.API.GetItemInfo(itemLink)
    if name then
        -- Item is cached, calculate price immediately
        local price = 0
        if addon.Inventory then
            price = addon.Inventory:GetItemPrice(itemLink)
        end

        if price > 0 then
            s.sessionLootedValueCopper = (s.sessionLootedValueCopper or 0) + (price * quantity)
        end
    else
        -- Item not cached, add to pending queue
        table.insert(lootedValuePendingQueue, {
            itemLink = itemLink,
            quantity = quantity
        })

        -- Start retry timer if not already running
        if not lootedValueRetryPending then
            lootedValueRetryPending = true
            C_Timer.After(0.2, RetryPendingLootedItems)
        end
    end
end

-----------------------------------------------------------------------
-- Posted auction tracking (not session-based, uses Blizzard owned auctions API)
-----------------------------------------------------------------------

-- State tracking
Gold._atAuctionHouse = false
Gold._ownedAuctionsRefreshPending = false
Gold._ownedAuctionsRefreshTimer = nil
Gold._postedUIRefreshPending = false
Gold._postedUIRefreshTimer = nil

function Gold:HandleAuctionPost(isCommodity, ...)
    -- Track all auction posts regardless of session state
    -- This provides immediate local increment (cheap), debounced UI update
    -- Source of truth reconciliation happens on AH open/close only
    local s = addon.state

    local value = 0

    if isCommodity then
        -- C_AuctionHouse.PostCommodity(item, duration, quantity, unitPrice)
        local item, duration, quantity, unitPrice = ...
        if quantity and unitPrice and quantity > 0 and unitPrice > 0 then
            value = unitPrice * quantity
        end
    else
        -- C_AuctionHouse.PostItem(item, duration, quantity, bid, buyout)
        local item, duration, quantity, bid, buyout = ...
        -- Prefer buyout, fallback to bid
        if buyout and buyout > 0 then
            value = buyout
        elseif bid and bid > 0 then
            value = bid
        end
    end

    if value > 0 then
        s.postedAuctionValueCopper = (s.postedAuctionValueCopper or 0) + value
        s.postedAuctionCount = (s.postedAuctionCount or 0) + 1

        -- Debounced UI update (prevents lag during mass posting)
        self:RequestPostedAuctionsUIRefresh()
    end

    -- NO owned-auctions refresh during posting (prevents lag)
    -- Source of truth reconciliation happens on AH open/close only
end

function Gold:RequestPostedAuctionsUIRefresh()
    -- Debounce HUD updates during mass posting
    if self._postedUIRefreshPending then
        return
    end

    self._postedUIRefreshPending = true

    -- Cancel any existing timer
    if self._postedUIRefreshTimer then
        self._postedUIRefreshTimer:Cancel()
    end

    -- Schedule debounced refresh (0.3s delay)
    self._postedUIRefreshTimer = C_Timer.NewTimer(0.3, function()
        self._postedUIRefreshTimer = nil
        self._postedUIRefreshPending = false

        addon:UpdateGoldSection()
        addon:SafeLayoutHUD()
    end)
end

function Gold:RequestOwnedAuctionsRefresh(reason)
    -- Only refresh while at auction house
    if not self._atAuctionHouse then
        return
    end

    -- Debounce: if already pending, don't schedule another
    if self._ownedAuctionsRefreshPending then
        return
    end

    self._ownedAuctionsRefreshPending = true

    -- Cancel any existing timer
    if self._ownedAuctionsRefreshTimer then
        self._ownedAuctionsRefreshTimer:Cancel()
    end

    -- Schedule the query after a short delay (debounce)
    -- Use NewTimer for proper cancellation support
    self._ownedAuctionsRefreshTimer = C_Timer.NewTimer(1.0, function()
        self._ownedAuctionsRefreshTimer = nil

        if not self._atAuctionHouse then
            self._ownedAuctionsRefreshPending = false
            return
        end

        -- Query owned auctions from server
        if C_AuctionHouse and C_AuctionHouse.QueryOwnedAuctions then
            C_AuctionHouse.QueryOwnedAuctions({})
        end

        -- Note: _ownedAuctionsRefreshPending is cleared in RecomputePostedTotalsFromOwned
        -- when OWNED_AUCTIONS_UPDATED fires
    end)
end

-- Commodity status cache for performance
Gold._commodityCache = Gold._commodityCache or {}

local function IsCommodity(itemKey)
    if not itemKey or not itemKey.itemID then
        return false
    end

    local itemID = itemKey.itemID

    -- Check cache first
    if Gold._commodityCache[itemID] ~= nil then
        return Gold._commodityCache[itemID]
    end

    -- Query and cache result
    local isCommodity = false
    if C_AuctionHouse and C_AuctionHouse.GetItemKeyInfo then
        local itemKeyInfo = C_AuctionHouse.GetItemKeyInfo(itemKey)
        if itemKeyInfo then
            isCommodity = itemKeyInfo.isCommodity or false
        end
    end

    Gold._commodityCache[itemID] = isCommodity
    return isCommodity
end

function Gold:RecomputePostedTotalsFromOwned()
    -- Recompute count and total value from currently owned auctions
    -- This is the source of truth, called when OWNED_AUCTIONS_UPDATED fires

    self._ownedAuctionsRefreshPending = false

    if not C_AuctionHouse then
        return
    end

    local totalCount = 0
    local totalValue = 0

    -- Try GetOwnedAuctions first (preferred)
    if C_AuctionHouse.GetOwnedAuctions then
        local auctions = C_AuctionHouse.GetOwnedAuctions()
        if auctions then
            for _, auctionInfo in ipairs(auctions) do
                -- Only count active auctions
                if auctionInfo.status == Enum.AuctionStatus.Active then
                    totalCount = totalCount + 1

                    -- Use buyoutAmount if present, otherwise bidAmount (unit price for commodities)
                    local price = auctionInfo.buyoutAmount or auctionInfo.bidAmount or 0
                    local qty = auctionInfo.quantity or 1

                    -- For commodities, price is per-unit, so multiply by quantity
                    local value = price
                    if IsCommodity(auctionInfo.itemKey) then
                        value = price * qty
                    end

                    totalValue = totalValue + value
                end
            end
        end
    -- Fallback to GetOwnedAuctionInfo loop
    elseif C_AuctionHouse.GetOwnedAuctionInfo then
        local i = 1
        while true do
            local auctionInfo = C_AuctionHouse.GetOwnedAuctionInfo(i)
            if not auctionInfo then
                break
            end

            -- Only count active auctions
            if auctionInfo.status == Enum.AuctionStatus.Active then
                totalCount = totalCount + 1

                -- Use buyoutAmount if present, otherwise bidAmount (unit price for commodities)
                local price = auctionInfo.buyoutAmount or auctionInfo.bidAmount or 0
                local qty = auctionInfo.quantity or 1

                -- For commodities, price is per-unit, so multiply by quantity
                local value = price
                if IsCommodity(auctionInfo.itemKey) then
                    value = price * qty
                end

                totalValue = totalValue + value
            end

            i = i + 1
        end
    end

    -- Update state
    local s = addon.state
    s.postedAuctionCount = totalCount
    s.postedAuctionValueCopper = totalValue

    -- Persist to character-specific saved variables
    local db = addon.db
    if db and db.characters then
        local key = addon:GetCharacterKey()
        db.characters[key] = db.characters[key] or {}
        db.characters[key].postedAuctionCount = totalCount
        db.characters[key].postedAuctionValueCopper = totalValue
    end

    -- Update display
    addon:UpdateGoldSection()
    addon:SafeLayoutHUD()
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

-- Format money with color coding and minus sign for negatives
-- Green if positive, red with "-" if negative, white if zero
local function FormatColoredMoney(amount)
    if amount > 0 then
        return "|cff00ff00" .. addon:FormatMoney(amount) .. "|r"
    elseif amount < 0 then
        return "|cffff4444-" .. addon:FormatMoney(math.abs(amount)) .. "|r"
    else
        return addon:FormatMoney(amount)  -- white/default for zero
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
    local showPH = (db.showGoldPerHour ~= false)  -- Show per-hour values (default true)
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
            guildText = "|cffff4444Visit GBank|r"
        end

        table.insert(goldParts, "GBank: " .. guildText)
    end

    if #goldParts > 0 then
        sec.lines[1]:SetText(table.concat(goldParts, "   "))
    else
        sec.lines[1]:SetText("")
    end

    -- Line 2: Posted auctions (count + value)
    if elem.goldPostedAuctions ~= false then
        local count = s.postedAuctionCount or 0
        local value = s.postedAuctionValueCopper or 0
        sec.lines[2]:SetText(string.format("Posted Auctions: (%d) %s", count, addon:FormatMoney(value)))
    else
        sec.lines[2]:SetText("")
    end

    -- Line 3: Token
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

    -- Lines 4-7 depend on session and view mode
    if elem.goldSession ~= false then
        local elapsed, net, gph = self:GetSessionStats()
        local hours = math.floor(elapsed / 3600)
        local minutes = math.floor((elapsed % 3600) / 60)
        local seconds = math.floor(elapsed % 60)
        local timeStr
        if hours > 0 then
            timeStr = string.format("%dh %02dm", hours, minutes)
        elseif minutes >= 10 then
            timeStr = string.format("%dm", minutes)
        else
            -- Under 10 minutes: show seconds too
            timeStr = string.format("%dm %02ds", minutes, seconds)
        end

        local isPaused = s.sessionPaused
        local isPausedByAFK = s.pausedByAFK

        -- Session time display: clock icon + time (red when paused, green when running)
        -- When paused by AFK, show "Auto-Paused - AFK" indicator to the left of the hourglass
        -- When paused manually, show "Manually Paused" indicator to the left of the hourglass
        local sessionTimeDisplay
        if isPaused then
            if isPausedByAFK then
                sessionTimeDisplay = string.format("|cffff4444Auto-Paused - AFK|r %s |cffff4444%s|r", CLOCK_ICON_RED, timeStr)
            else
                sessionTimeDisplay = string.format("|cffff4444Manually Paused|r %s |cffff4444%s|r", CLOCK_ICON_RED, timeStr)
            end
        else
            sessionTimeDisplay = string.format("%s |cff00ff00%s|r", CLOCK_ICON_GREEN, timeStr)
        end

        -- Line 4: Session header (timer is displayed separately)
        sec.lines[4]:SetText("Session")

        -- Set timer display (positioned to left of buttons in HUD layout)
        if sec.sessionTimerDisplay then
            sec.sessionTimerDisplay:SetText(sessionTimeDisplay)
        end

        if isDetailed then
            -- DETAILED MODE
            -- Line 5: Start + Current + GPH
            local startGold = s.sessionStartGold or 0
            local currentGold = (isPaused and s.pauseGoldSnapshot) or GetMoney()

            if showPH then
                sec.lines[5]:SetText(string.format("Start: %s   Current: %s   (%s/h)",
                    addon:FormatMoney(startGold), addon:FormatMoney(currentGold), FormatColoredMoney(gph)))
            else
                sec.lines[5]:SetText(string.format("Start: %s   Current: %s",
                    addon:FormatMoney(startGold), addon:FormatMoney(currentGold)))
            end

            -- Line 6: Earned / Spent / Net
            local earned = s.sessionEarned or 0
            local spent = s.sessionSpent or 0
            local netDisplay = FormatSignedMoney(net)

            sec.lines[6]:SetText(string.format("Earned: %s    Spent: %s       Net: %s",
                addon:FormatMoney(earned), addon:FormatMoney(spent), netDisplay))
        else
            -- SIMPLE MODE
            -- Line 5: Earned + GPH
            if showPH then
                sec.lines[5]:SetText(string.format("Earned: %s (%s/h)",
                    FormatColoredMoney(net), FormatColoredMoney(gph)))
            else
                sec.lines[5]:SetText(string.format("Earned: %s",
                    FormatColoredMoney(net)))
            end

            -- Line 6: Empty in simple mode
            sec.lines[6]:SetText("")
        end
    else
        -- Session disabled
        sec.lines[4]:SetText("")
        sec.lines[5]:SetText("")
        sec.lines[6]:SetText("")
        if sec.sessionTimerDisplay then
            sec.sessionTimerDisplay:SetText("")
        end
    end

    -- Line 7: Looted value with GPH
    if elem.goldLootedValue ~= false then
        local lootedValue = s.sessionLootedValueCopper or 0
        local priceSource = "vendor"
        if TSM_API and TSM_API.GetCustomPriceValue and addon.Inventory then
            priceSource = addon.Inventory:ResolveTSMLabel()
        end

        -- Calculate looted GPH
        local lootedGPH = 0
        if elem.goldSession ~= false then
            local elapsed = self:GetSessionStats()
            if elapsed and elapsed > 0 then
                lootedGPH = (lootedValue * 3600) / elapsed
            end
        end

        if showPH then
            sec.lines[7]:SetText(string.format("Looted (%s): %s (%s/h)",
                priceSource, addon:FormatMoney(lootedValue), addon:FormatMoney(lootedGPH)))
        else
            sec.lines[7]:SetText(string.format("Looted (%s): %s",
                priceSource, addon:FormatMoney(lootedValue)))
        end
    else
        sec.lines[7]:SetText("")
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

-----------------------------------------------------------------------
-- Debug command
-----------------------------------------------------------------------

function Gold:ToggleTransferDebug()
    if not addon.db or not addon.db.profile then
        return false
    end
    addon.db.profile.debugTransfers = not addon.db.profile.debugTransfers
    return addon.db.profile.debugTransfers
end

-----------------------------------------------------------------------
-- Bank transfer hooks setup
-----------------------------------------------------------------------

function Gold:SetupTransferHooks()
    -- Hook unified bank API (covers Warband and Guild if routed through it)
    if C_Bank and C_Bank.DepositMoney then
        hooksecurefunc(C_Bank, "DepositMoney", function(bankType, amount)
            if not amount or amount <= 0 then
                return
            end

            -- Check if this is a guild or warband bank deposit
            local source = nil
            if bankType == Enum.BankType.Account or bankType == 2 then
                source = "warband"
            elseif bankType == Enum.BankType.Guild or bankType == 1 then
                source = "guild"
            end

            if source then
                -- Deposit: player loses gold, so intent delta is negative
                EnqueueTransferIntent(-amount, source)
            end
        end)
    end

    if C_Bank and C_Bank.WithdrawMoney then
        hooksecurefunc(C_Bank, "WithdrawMoney", function(bankType, amount)
            if not amount or amount <= 0 then
                return
            end

            -- Check if this is a guild or warband bank withdrawal
            local source = nil
            if bankType == Enum.BankType.Account or bankType == 2 then
                source = "warband"
            elseif bankType == Enum.BankType.Guild or bankType == 1 then
                source = "guild"
            end

            if source then
                -- Withdrawal: player gains gold, so intent delta is positive
                EnqueueTransferIntent(amount, source)
            end
        end)
    end

    -- Hook legacy guild bank functions (belt-and-braces)
    if DepositGuildBankMoney then
        hooksecurefunc("DepositGuildBankMoney", function(amount)
            if amount and amount > 0 then
                -- Deposit: player loses gold, so intent delta is negative
                EnqueueTransferIntent(-amount, "guild")
            end
        end)
    end

    if WithdrawGuildBankMoney then
        hooksecurefunc("WithdrawGuildBankMoney", function(amount)
            if amount and amount > 0 then
                -- Withdrawal: player gains gold, so intent delta is positive
                EnqueueTransferIntent(amount, "guild")
            end
        end)
    end
end

-- Expose for event handlers
addon.Gold = Gold
