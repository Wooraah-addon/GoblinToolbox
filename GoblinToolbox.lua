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
-- Event handlers
-----------------------------------------------------------------------

local EventHandlers = {
    PLAYER_LOGIN = function()
        addon.db = addon:GetDB()
        
        addon:InitializeHUD()
        addon:CreateTrackerFrame()
        addon:CreateCurrencyFrame()
        addon:CreateUtilityBar()
        addon:UpdateBackground()
        addon:UpdateTitleBar()

        if addon.HUD and addon.HUD.UpdateLockTexture then
            addon.HUD.UpdateLockTexture()
        end

        addon:ResetSession()
        addon:StartSessionTicker()
        addon:StartTokenTicker()
        
        -- Start character speed ticker (if module loaded)
        if addon.Character and addon.Character.StartSpeedTicker then
            addon.Character:StartSpeedTicker()
        end
        
        -- Start character combat log monitoring for shard detection
        if addon.Character and addon.Character.StartCombatLogMonitoring then
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
            addon:LayoutHUD()
        end)
        addon:UpdateVisibility()
        
        -- Fix initial positioning only if user hasn't moved frames yet
        local db = addon.db.profile
        if not db.trackerPoint and not db.currencyPoint and not db.utilityBarPos then
            addon:ResetAllPositions()
        end
        
        print("Goblin Toolbox loaded. Type /gtb for options.")
    end,

    PLAYER_LOGOUT = function()
        addon:SaveUtilityBarPositionOnLogout()
    end,

    PLAYER_MONEY = function()
        addon.Gold:UpdateCharacterCache()
        addon:UpdateGoldSection()
        addon:LayoutHUD()
    end,

    ACCOUNT_MONEY = function()
        addon:GetWarbandBankGold()  -- This will update cache if we have access
        addon:UpdateGoldSection()
        addon:LayoutHUD()
    end,

    BAG_UPDATE_DELAYED = function()
        addon:QueueBagValueRecalc()
    end,

    GUILDBANK_UPDATE_MONEY = function()
        addon.Gold:UpdateGuildGoldFromBank()
        addon:UpdateGoldSection()
        addon:LayoutHUD()
    end,

    PLAYER_INTERACTION_MANAGER_FRAME_SHOW = function(interactionType)
        if Enum and Enum.PlayerInteractionType
           and interactionType == Enum.PlayerInteractionType.Banker then
            addon:ResetBankAutoSwitchState()
            C_Timer.After(0.05, function()
                addon:TryAutoSwitchToWarbandBank()
            end)
            
            -- Update warband bank gold cache when opening banker
            C_Timer.After(0.2, function()
                addon:GetWarbandBankGold()  -- This will update cache if we have access
                addon:UpdateGoldSection()
                addon:LayoutHUD()
            end)
        end

        if Enum and Enum.PlayerInteractionType
           and interactionType == Enum.PlayerInteractionType.GuildBanker then
            C_Timer.After(0.1, function()
                addon.Gold:UpdateGuildGoldFromBank()
                addon:UpdateGoldSection()
                addon:LayoutHUD()
            end)
        end
    end,

    PLAYER_INTERACTION_MANAGER_FRAME_HIDE = function(interactionType)
        if Enum and Enum.PlayerInteractionType
           and interactionType == Enum.PlayerInteractionType.Banker then
            addon:ResetBankAutoSwitchState()
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
    end,

    PLAYER_ENTERING_WORLD = function()
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
            addon:LayoutHUD()
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
EventFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
EventFrame:RegisterEvent("TOKEN_MARKET_PRICE_UPDATED")

-- Cooldown events
local cooldownEvents = {
    "SPELL_UPDATE_COOLDOWN",
    "BAG_UPDATE_COOLDOWN",
    "SPELL_UPDATE_CHARGES",
    "SPELLS_CHANGED",
    "TOYS_UPDATED",
    "PLAYER_EQUIPMENT_CHANGED",
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
        addon:UpdateGoldSection()
        addon:LayoutHUD()
        print("Goblin Toolbox: session reset.")

    elseif cmd == "pause" or cmd == "resume" then
        addon:TogglePauseSession()
        addon:UpdateGoldSection()
        addon:LayoutHUD()

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
    end
end
