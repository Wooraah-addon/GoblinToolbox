-- GoblinToolbox.lua
-- Main entry point: initialization, events, slash commands
-- Core for Goblin Toolbox (12.0)

local addonName, addon = ...

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
-- Safe layout helper (prevents combat taint)
-- Optional immediate parameter for user actions that need instant feedback
-----------------------------------------------------------------------

function addon:SafeLayoutHUD(immediate)
    if InCombatLockdown() then
        self._needsLayoutRefresh = true
        return
    end

    -- Immediate mode: cancel any pending timer and layout now
    if immediate then
        if self._layoutRefreshTimer then
            self._layoutRefreshTimer:Cancel()
            self._layoutRefreshTimer = nil
        end
        self._layoutRefreshPending = false
        self:LayoutHUD()
        return
    end

    -- Debounced mode (default): coalesce rapid updates
    if self._layoutRefreshPending then
        return  -- Already scheduled, no need to reschedule
    end

    self._layoutRefreshPending = true

    if self._layoutRefreshTimer then
        self._layoutRefreshTimer:Cancel()
    end

    self._layoutRefreshTimer = C_Timer.NewTimer(0.3, function()
        self._layoutRefreshTimer = nil
        self._layoutRefreshPending = false

        if not InCombatLockdown() then
            self:LayoutHUD()
        else
            self._needsLayoutRefresh = true
        end
    end)
end

-----------------------------------------------------------------------
-- ReloadUI hook for session persistence
-----------------------------------------------------------------------

-- Hook ReloadUI to detect reloads vs full logouts
-- When ReloadUI() is called, we set a flag that persists through the reload
-- On next PLAYER_LOGIN, we check this flag to know if it was a reload
hooksecurefunc("ReloadUI", function()
    if addon.db and addon.db.global then
        addon.db.global.isReloading = true
    end
end)

-----------------------------------------------------------------------
-- Event handlers
-----------------------------------------------------------------------

local EventHandlers = {
    PLAYER_LOGIN = function()
        addon.db = addon:GetDB()

        -- Cache character key at login (realm not available during logout)
        addon.state.characterKey = addon:GetCharacterKey()

        -- Run SavedVariables migrations
        addon:MigrateSavedVariables()

        -- Set up profile system and assign active profile
        addon:EnsureProfileSystem()

        addon:InitializeHUD()
        addon:CreateTrackerFrame()
        addon:CreateCurrencyFrame()
        addon:CreateUtilityBar()
        addon:CreateMinimapButton()
        addon:ApplyScale()  -- Apply saved scale to all frames
        addon:UpdateBackground()
        addon:UpdateTitleBar()

        if addon.HUD and addon.HUD.UpdateLockTexture then
            addon.HUD.UpdateLockTexture()
        end

        -- Restore session state if persistence is enabled, otherwise reset
        if not addon:LoadSessionState() then
            addon:ResetSession()
        end

        -- Initialize posted auction data (not session-based)
        if addon.Gold and addon.Gold.InitializePostedAuctions then
            addon.Gold:InitializePostedAuctions()
        end

        addon:StartSessionTicker()
        addon:StartTokenTicker()

        -- Setup bank transfer hooks for session tracking
        if addon.Gold and addon.Gold.SetupTransferHooks then
            addon.Gold:SetupTransferHooks()
        end

        -- Start character speed ticker (if module loaded)
        if addon.Character and addon.Character.StartSpeedTicker then
            addon.Character:StartSpeedTicker()
        end
        
        -- Start character combat log monitoring for shard detection
        -- Skip on Midnight (12.0.0+) due to combat log restrictions
        local interfaceVersion = select(4, GetBuildInfo())
        if addon.Character and addon.Character.StartCombatLogMonitoring and interfaceVersion < 120000 then
            addon.Character:StartCombatLogMonitoring()
        end

        addon.Gold:UpdateCharacterCache()

        addon.state.bagValue = addon.state.bagValue or 0
        addon.trackedCounts = addon.trackedCounts or {}
        addon:UpdateInventorySection()
        addon:QueueBagValueRecalc()

        addon:UpdateAllSections()
        addon:UpdateUtilityBar()
        addon:UpdateUtilityCooldowns()
        addon:UpdateVisibility()

        -- Initialize TooltipIDs module
        if addon.TooltipIDs and addon.TooltipIDs.Enable then
            addon.TooltipIDs:Enable()
        end
        
        -- Delayed update for Character section (some APIs need time to initialize)
        C_Timer.After(0.5, function()
            addon:UpdateCharacterSection()
            addon:SafeLayoutHUD()
        end)
        addon:UpdateVisibility()

        -- Set default positions only on true first run (HUD has never been positioned)
        local db = addon.db.profile
        if not db.point then
            addon:ResetAllPositions()
        end

        -- Hook auction posting functions for session tracking
        if C_AuctionHouse and addon.Gold then
            if C_AuctionHouse.PostCommodity then
                hooksecurefunc(C_AuctionHouse, "PostCommodity", function(...)
                    addon.Gold:HandleAuctionPost(true, ...)
                end)
            end
            if C_AuctionHouse.PostItem then
                hooksecurefunc(C_AuctionHouse, "PostItem", function(...)
                    addon.Gold:HandleAuctionPost(false, ...)
                end)
            end
        end

        -- Show load message if enabled (account-wide preference)
        if addon.db.global.showLoadMessage ~= false then
            print("Goblin Toolbox loaded. Type /gtb for options.")
        end

        -- TODO v1.1.1: Remove this entire block (one-time notice for v1.1.0 only)
        -- Show v1.1.0 UI update notice (one-time, account-wide)
        if not addon.db.global.shownV1_1_0Notice then
            C_Timer.After(1.5, function()
                StaticPopup_Show("GOBLINTOOLBOX_V1_1_0_NOTICE")
            end)
        end
    end,

    PLAYER_LOGOUT = function()
        -- Save utility bar position (nil-safe for future refactors)
        if addon.SaveUtilityBarPositionOnLogout then
            addon:SaveUtilityBarPositionOnLogout()
        end
        addon:SaveSessionState()
    end,

    PLAYER_LEAVING_WORLD = function()
        -- Save session state on any logout/reload/zone change
        addon:SaveSessionState()
    end,

    PLAYER_MONEY = function()
        addon.Gold:UpdateCharacterCache()

        -- Process earned/spent deltas immediately (including bank transfer matching)
        -- This prevents the "flash" of incorrect values before the session ticker runs
        if addon.Gold and addon.Gold.UpdateEarnedSpentImmediate then
            addon.Gold:UpdateEarnedSpentImmediate()
        end

        addon:UpdateGoldSection()
        addon:SafeLayoutHUD()
    end,

    ACCOUNT_MONEY = function()
        addon:GetWarbandBankGold()  -- This will update cache if we have access
        addon:UpdateGoldSection()
        addon:SafeLayoutHUD()
    end,

    BAG_UPDATE_DELAYED = function()
        addon:QueueBagValueRecalc()

        -- If bank is open, refresh bank scans
        if addon._bankIsOpen and addon.Inventory then
            -- Player bank scan (always accessible at banker)
            if addon.Inventory.QueuePlayerBankScan then
                addon.Inventory:QueuePlayerBankScan()
            end

            -- Warband bank scan (if accessible)
            if C_Bank and C_Bank.CanUseBank and Enum.BankType then
                if C_Bank.CanUseBank(Enum.BankType.Account) then
                    if addon.Inventory.QueueWarbandScan then
                        addon.Inventory:QueueWarbandScan()
                    end
                end
            end
        end
    end,

    GUILDBANK_UPDATE_MONEY = function()
        addon.Gold:UpdateGuildGoldFromBank()
        addon:UpdateGoldSection()
        addon:SafeLayoutHUD()
    end,

    PLAYER_INTERACTION_MANAGER_FRAME_SHOW = function(interactionType)
        if Enum and Enum.PlayerInteractionType
           and interactionType == Enum.PlayerInteractionType.Banker then
            addon:ResetBankAutoSwitchState()
            addon._bankIsOpen = true  -- Track bank open state

            C_Timer.After(0.05, function()
                addon:TryAutoSwitchToWarbandBank()
            end)

            -- Update warband bank gold cache when opening banker
            C_Timer.After(0.2, function()
                addon:GetWarbandBankGold()  -- This will update cache if we have access
                addon:UpdateGoldSection()
                addon:SafeLayoutHUD()
            end)

            -- Trigger bank item scans (player bank + warband bank)
            if addon.Inventory then
                -- Player bank scan (always accessible at banker)
                if addon.Inventory.QueuePlayerBankScan then
                    C_Timer.After(0.5, function()
                        addon.Inventory:QueuePlayerBankScan()
                    end)
                end

                -- Warband bank scan (if accessible)
                if addon.Inventory.QueueWarbandScan then
                    C_Timer.After(0.6, function()
                        addon.Inventory:QueueWarbandScan()
                    end)
                end
            end
        end

        if Enum and Enum.PlayerInteractionType
           and interactionType == Enum.PlayerInteractionType.GuildBanker then
            C_Timer.After(0.1, function()
                addon.Gold:UpdateGuildGoldFromBank()
                addon:UpdateGoldSection()
                addon:SafeLayoutHUD()
            end)
        end

        -- Note: Auctioneer handled by AUCTION_HOUSE_SHOW event instead
    end,

    PLAYER_INTERACTION_MANAGER_FRAME_HIDE = function(interactionType)
        if Enum and Enum.PlayerInteractionType
           and interactionType == Enum.PlayerInteractionType.Banker then
            addon:ResetBankAutoSwitchState()
            addon._bankIsOpen = false  -- Track bank closed state
        end
    end,

    PLAYER_REGEN_DISABLED = function()
        addon:UpdateVisibility()
        addon._needsUtilityRefresh = true
    end,

    PLAYER_REGEN_ENABLED = function()
        addon:UpdateVisibility()
        if addon._needsUtilityRefresh then
            addon._needsUtilityRefresh = false
            addon:UpdateUtilityBar()
            addon:UpdateUtilityCooldowns()
        end
        if addon._needsLayoutRefresh then
            addon._needsLayoutRefresh = false
            addon:LayoutHUD()
        end
    end,

    PLAYER_ENTERING_WORLD = function()
        addon:UpdateVisibility()
    end,

    ZONE_CHANGED = function()
        addon:UpdateVisibility()
    end,

    ZONE_CHANGED_NEW_AREA = function()
        addon:UpdateVisibility()
    end,

    CURRENCY_DISPLAY_UPDATE = function()
        addon:UpdateCurrencyBar()
    end,

    TOKEN_MARKET_PRICE_UPDATED = function()
        if addon:UpdateTokenCache() then
            addon:UpdateGoldSection()
            addon:SafeLayoutHUD()
        end
    end,

    CHAT_MSG_LOOT = function(message)
        if addon.Gold and addon.Gold.HandleLootMessage then
            addon.Gold:HandleLootMessage(message)
        end
    end,

    AUCTION_HOUSE_SHOW = function()
        -- Set AH state and request initial owned auctions refresh
        if addon.Gold then
            addon.Gold._atAuctionHouse = true
            addon.Gold:RequestOwnedAuctionsRefresh("show")
        end
    end,

    AUCTION_HOUSE_CLOSED = function()
        -- Clear AH state and cancel any pending timers
        if addon.Gold then
            addon.Gold._atAuctionHouse = false
            addon.Gold._ownedAuctionsRefreshPending = false
            if addon.Gold._ownedAuctionsRefreshTimer then
                addon.Gold._ownedAuctionsRefreshTimer:Cancel()
                addon.Gold._ownedAuctionsRefreshTimer = nil
            end
            -- Also cancel posted UI refresh timer
            addon.Gold._postedUIRefreshPending = false
            if addon.Gold._postedUIRefreshTimer then
                addon.Gold._postedUIRefreshTimer:Cancel()
                addon.Gold._postedUIRefreshTimer = nil
            end
        end
    end,

    OWNED_AUCTIONS_UPDATED = function()
        -- Recompute totals from authoritative owned auctions data
        if addon.Gold and addon.Gold.RecomputePostedTotalsFromOwned then
            addon.Gold:RecomputePostedTotalsFromOwned()
        end
    end,

    PLAYER_FLAGS_CHANGED = function(unit)
        -- Only care about player's AFK status
        if unit ~= "player" then
            return
        end

        -- Check if AFK auto-pause is enabled
        if not addon.db or not addon.db.global or not addon.db.global.afkAutoPause then
            return
        end

        local isAFK = UnitIsAFK("player")

        if isAFK then
            -- Player went AFK - auto-pause session
            if addon.Gold and addon.Gold.PauseSessionForAFK then
                addon.Gold:PauseSessionForAFK()
                addon:UpdateGoldSection()
                addon:SafeLayoutHUD()
            end
        else
            -- Player returned from AFK - auto-resume session
            if addon.Gold and addon.Gold.ResumeSessionFromAFK then
                addon.Gold:ResumeSessionFromAFK()
                addon:UpdateGoldSection()
                addon:SafeLayoutHUD()
            end
        end
    end,
}

-- Cooldown-related events share one handler
local function OnCooldownEvent()
    if InCombatLockdown() then
        addon._needsUtilityRefresh = true
        addon:UpdateUtilityCooldowns()
    else
        addon:UpdateUtilityBar()
        addon:UpdateUtilityCooldowns()
    end
end

-----------------------------------------------------------------------
-- Event frame
-----------------------------------------------------------------------

local EventFrame = CreateFrame("Frame")

EventFrame:SetScript("OnEvent", function(self, event, ...)
    local handler = EventHandlers[event]
    if handler then
        handler(...)
    end
end)

-- Register all events
EventFrame:RegisterEvent("PLAYER_LOGIN")
EventFrame:RegisterEvent("PLAYER_LOGOUT")
EventFrame:RegisterEvent("PLAYER_LEAVING_WORLD")
EventFrame:RegisterEvent("PLAYER_MONEY")
EventFrame:RegisterEvent("ACCOUNT_MONEY")
EventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
EventFrame:RegisterEvent("GUILDBANK_UPDATE_MONEY")
EventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
EventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
EventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
EventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
EventFrame:RegisterEvent("ZONE_CHANGED")
EventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
EventFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
EventFrame:RegisterEvent("TOKEN_MARKET_PRICE_UPDATED")
EventFrame:RegisterEvent("CHAT_MSG_LOOT")
EventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
EventFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")
EventFrame:RegisterEvent("OWNED_AUCTIONS_UPDATED")
EventFrame:RegisterEvent("PLAYER_FLAGS_CHANGED")

-- Cooldown events
local cooldownEvents = {
    "SPELL_UPDATE_COOLDOWN",
    "BAG_UPDATE_COOLDOWN",
    "SPELL_UPDATE_CHARGES",
    "SPELLS_CHANGED",
    "TOYS_UPDATED",
    "PLAYER_EQUIPMENT_CHANGED",
    "UPDATE_OVERRIDE_ACTIONBAR",
}

for _, event in ipairs(cooldownEvents) do
    EventFrame:RegisterEvent(event)
    EventHandlers[event] = OnCooldownEvent
end

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

    elseif cmd == "addcurrency" or cmd == "addc" then
        addon:AddTrackedCurrency(rest)

    elseif cmd == "currencies" or cmd == "listcurrencies" then
        addon:ListTrackedCurrencies()

    elseif cmd == "reset" then
        addon:ResetSession()
        -- Clear persisted session state
        if addon.db and addon.db.profile then
            addon.db.profile.sessionState = {}
        end
        addon:UpdateGoldSection()
        addon:SafeLayoutHUD(true)  -- Immediate layout for user command
        print("Goblin Toolbox: session reset.")

    elseif cmd == "pause" or cmd == "resume" then
        addon:TogglePauseSession()
        addon:UpdateGoldSection()
        addon:SafeLayoutHUD(true)  -- Immediate layout for user command

    elseif cmd == "lock" then
        addon.db.profile.lockFrame = true
        if addon.HUD and addon.HUD.UpdateLockTexture then
            addon.HUD.UpdateLockTexture()
        end
        print("Goblin Toolbox: frame locked.")

    elseif cmd == "unlock" then
        addon.db.profile.lockFrame = false
        if addon.HUD and addon.HUD.UpdateLockTexture then
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

    elseif cmd == "profiles" or cmd == "profile" then
        print("|cff00ff00=== Goblin Toolbox Profile System ===|r")
        print("Schema Version:", addon.db.global.schemaVersion or 0)
        print("Active Profile:", addon:GetActiveProfileName())

        print("\nAvailable Profiles:")
        local profiles = addon:GetProfileNames()
        if #profiles > 0 then
            for _, name in ipairs(profiles) do
                local marker = (name == addon:GetActiveProfileName()) and " |cff00ff00(active)|r" or ""
                print("  - " .. name .. marker)
            end
        else
            print("  (none)")
        end

        print("\nCharacter Assignments:")
        if addon.db.profileKeys then
            local count = 0
            for charKey, profileName in pairs(addon.db.profileKeys) do
                print("  " .. charKey .. " -> " .. profileName)
                count = count + 1
            end
            if count == 0 then
                print("  (none)")
            end
        else
            print("  (no profileKeys table)")
        end

        print("\nPresets Available:")
        for _, presetName in ipairs(addon:GetPresetNames()) do
            print("  - " .. presetName)
        end

    elseif cmd == "debugtransfers" then
        if addon.Gold and addon.Gold.ToggleTransferDebug then
            local enabled = addon.Gold:ToggleTransferDebug()
            print("Goblin Toolbox: transfer debug logging", enabled and "enabled" or "disabled")
        end

    elseif cmd == "sessiondebug" or cmd == "debugsession" then
        local db = addon.db and addon.db.profile
        if not db then
            print("Goblin Toolbox: No database found")
            return
        end

        print("=== Session State Debug ===")
        print("Persistence enabled:", addon.db.global.sessionPersistOnLogout and "YES" or "NO")

        local charCache = addon:GetCharacterCache()
        if charCache and charCache.sessionState and charCache.sessionState.sessionStartTime then
            print("Saved state found:")
            print("  Character:", charCache.sessionState.characterKey or "none")
            print("  Start time:", charCache.sessionState.sessionStartTime or "none")
            print("  Start gold:", charCache.sessionState.sessionStartGold or 0)
            print("  Earned:", charCache.sessionState.sessionEarned or 0)
            print("  Spent:", charCache.sessionState.sessionSpent or 0)
            print("  Transfer offset:", charCache.sessionState.sessionTransferOffset or 0)
        else
            print("No saved state found")
        end

        print("\nCurrent state:")
        local s = addon.state
        print("  Start time:", s.sessionStartTime or "none")
        print("  Start gold:", s.sessionStartGold or 0)
        print("  Earned:", s.sessionEarned or 0)
        print("  Spent:", s.sessionSpent or 0)
        print("  Transfer offset:", s.sessionTransferOffset or 0)

    elseif cmd == "wipe" then
        -- Admin/testing command: completely wipe all saved data
        StaticPopup_Show("GOBLINTOOLBOX_WIPE_ALL")

    else
        print("Goblin Toolbox commands:")
        print("  /gtb              - open settings window")
        print("  /gtb add [link/name] - add item or currency to tracker")
        print("  /gtb addcurrency [name/ID] - add currency to tracker")
        print("  /gtb currencies   - list tracked currencies")
        print("  /gtb reset        - reset gold session")
        print("  /gtb pause        - pause or resume session timer")
        print("  /gtb lock         - lock frame positions")
        print("  /gtb unlock       - unlock frame positions")
        print("  /gtb show         - show HUD")
        print("  /gtb hide         - hide HUD")
        print("  /gtb headers      - toggle group headers")
        print("  /gtb debugtransfers - toggle bank transfer debug logging")
        print("  /gtb sessiondebug - show session persistence debug info")
    end
end

-----------------------------------------------------------------------
-- StaticPopup for /gtb wipe command
-----------------------------------------------------------------------

StaticPopupDialogs["GOBLINTOOLBOX_WIPE_ALL"] = {
    text = "|cffff4444WARNING:|r This will completely wipe ALL Goblin Toolbox data!\n\nThis includes:\n- All profiles\n- All settings\n- Character gold history\n- Guild gold history\n- Warband gold data\n- All tracked items and currencies\n- Session data\n\n|cffff8800This CANNOT be undone!|r\n\nThe UI will reload after wiping.",
    button1 = "WIPE EVERYTHING",
    button2 = "Cancel",
    OnAccept = function()
        -- Nuclear option: completely wipe all saved variables
        GoblinToolboxDB = nil
        -- Force UI reload to reinitialize from scratch
        ReloadUI()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}
