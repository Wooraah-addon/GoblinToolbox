-- Core.lua
-- Foundation: addon table, constants, defaults, and shared helpers

local addonName, addon = ...

-----------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------

addon.CONST = {
    COPPER_PER_GOLD = 10000,
    
    -- UI Layout
    HUD_WIDTH = 360,
    HUD_DEFAULT_HEIGHT = 120,
    BUTTON_SIZE = 32,
    BUTTON_SIZE_SMALL = 36,  -- Increased from 28 for better readability on tracker bars
    BUTTON_SPACING = 6,
    SPACING_SMALL = 4,
    PADDING = 4,
    TITLEBAR_HEIGHT = 22,
    
    -- Token tracking
    TOKEN_TREND_THRESHOLD = 2500 * 10000,  -- 2,500g in copper (lowered for more responsive trend)
    TOKEN_HISTORY_SIZE = 20,
    TOKEN_POLL_INTERVAL = 300,  -- seconds
    
    -- Timers
    SESSION_TICK_INTERVAL = 1.0,
    BAG_SCAN_DELAY = 0.5,
    
    -- Guild bank staleness (4 days in seconds)
    GUILD_STALE_THRESHOLD = 4 * 24 * 60 * 60,
    
    -- Spell IDs
    SPELLS = {
        MOBILE_BANKING = 83958,
        WARBAND_BANK_INHIBITOR = 460905,
        HEARTHSTONE = 8690,
    },
    
    -- Item IDs
    ITEMS = {
        DALARAN_HS = 140192,
        GARRISON_HS = 110560,
        KATY_STAMPWHISTLE = 156833,
        OHUNA_PERCH = 194885,
        MOLL_E = 40768,
    },
    
    -- Profession skill line IDs (for future use)
    PROFESSIONS = {
        ALCHEMY = 171,
        BLACKSMITHING = 164,
        ENCHANTING = 333,
        ENGINEERING = 202,
        HERBALISM = 182,
        INSCRIPTION = 773,
        JEWELCRAFTING = 755,
        LEATHERWORKING = 165,
        MINING = 186,
        SKINNING = 393,
        TAILORING = 197,
        COOKING = 185,
        FISHING = 356,
    },
}

-----------------------------------------------------------------------
-- Saved variables and defaults
-----------------------------------------------------------------------

local DEFAULTS = {
    profile = {
        enabled          = true,
        scale            = 1.0,
        fontSize         = 13,
        lockFrame        = false,
        hideInCombat     = true,
        hideInInstances  = true,
        showHeaders      = true,
        showTitleBar     = true,
        showBackground   = true,
        backgroundOpacity = 0.30,
        preferWarbandBankOnOpen = false,
        sessionPersistOnLogout = false,
        goldViewMode     = "simple",  -- "simple" or "detailed"

        modules = {
            Character   = true,
            Gold        = true,
            Inventory   = true,
            Utility     = true,
        },

        -- Individual element toggles within modules
        elements = {
            -- Character elements
            charIcon      = true,
            charClassIcon = true,
            charName      = true,
            charRealm     = true,
            charAccountLabel = false,  -- Off by default (account label under name)
            charShardID   = false,  -- Off by default (can be noisy)
            charMovespeed = false,  -- Off by default (updates frequently)
            -- Gold & Economy elements
            goldCharacter = true,
            goldWarband   = true,
            goldGuild     = true,
            goldSession   = true,
            goldToken     = true,
            goldLootedValue = true,      -- Looted item value per session (enabled by default)
            goldPostedAuctions = false,  -- Posted auction tracking (disabled by default)
            -- Inventory elements
            invBagSlots   = true,
            invBagValue   = true,
            invWarbank    = true,
        },

        collapsed       = {},
        tsmSource       = "dbmarket",
        tsmCustomSource = "",
        trackedItems    = {},

        showTracker     = true,
        showCurrencyTracker = true,
        showTrackedItemValue = true,  -- Display gold value overlay on tracked items

        -- Item tracker source toggles
        trackerIncludeInventory    = true,   -- Include bag items in tracker (default on)
        trackerIncludePlayerBank   = false,  -- Include player bank in tracker (default off)
        trackerIncludeWarbandBank  = false,  -- Include warband bank in tracker (default off)

        -- Tooltip IDs settings (all off by default)
        tooltipIDs = {
            enabled     = false,
            item        = false,
            spell       = false,
            currency    = false,
            unit        = false,
            mount       = false,
            icon        = false,
        },

        -- Utility bar button states
        utilityButtons = {
            logout            = false,
            reload            = false,
            mobileBank        = true,
            mailbox           = true,
            tradersBrutosaur  = true,
            vendorMount       = true,
            warbandBank       = true,
            hearthstone       = true,
            dalaranHS         = true,
            garrisonHS        = true,
            housingTeleport   = false,
        },

        -- Position persistence
        point           = nil,
        relPoint        = nil,
        xOfs            = nil,
        yOfs            = nil,
        hudWidth        = nil,

        utilityPoint     = nil,
        utilityRelPoint  = nil,
        utilityXOfs      = nil,
        utilityYOfs      = nil,
        utilityCXFrac    = nil,
        utilityCYFrac    = nil,

        trackerPoint     = nil,
        trackerRelPoint  = nil,
        trackerXOfs      = nil,
        trackerYOfs      = nil,
        currencyPoint    = nil,
        currencyRelPoint = nil,
        currencyXOfs     = nil,
        currencyYOfs     = nil,

        trackedCurrencies = {},

        -- Player bank cache (character-specific)
        playerBankItemCountsByKey = {},  -- Cache of player bank item counts (itemID:rank -> count)
        playerBankItemsLastUpdate = 0,   -- Timestamp of last player bank scan

        -- Session persistence (used when sessionPersistOnLogout is enabled)
        sessionState = {},
    },

    global = {
        accountLabel = "",  -- Account-wide label shown in Character section (e.g., "WOW1")
    },

    characters = {},
    guilds     = {},
    warband    = {
        gold        = 0,
        lastUpdate  = 0,
        itemCountsByKey = {},  -- Cache of warband bank item counts (itemID:rank -> count)
        itemsLastUpdate = 0,   -- Timestamp of last warband bank scan
    },
}

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

function addon:GetDB()
    GoblinToolboxDB = CopyDefaults(DEFAULTS, GoblinToolboxDB or {})
    return GoblinToolboxDB
end

-----------------------------------------------------------------------
-- Shared state
-----------------------------------------------------------------------

addon.state = {
    sessionStartGold = nil,
    sessionStartTime = nil,
    sessionPaused    = false,
    pauseStartTime   = nil,
    pausedDuration   = 0,
    bagValue         = 0,
    -- Earned/Spent tracking for Detailed view
    sessionEarned    = 0,
    sessionSpent     = 0,
    lastMoney        = nil,
}

addon.token = {
    lastPrice   = 0,
    lastUpdated = 0,
    history     = {},
}

addon.trackedCounts  = {}
addon.trackedCountsByKey = {}
addon.trackerButtons = {}
addon.utilityButtons = {}

-----------------------------------------------------------------------
-- Shared helper functions
-----------------------------------------------------------------------

function addon:GetCharacterKey()
    local name, realm = UnitFullName("player")
    return string.format("%s-%s", realm or "Unknown", name or "Unknown")
end

function addon:FormatMoney(amount)
    amount = amount or 0
    local gold = math.floor(amount / self.CONST.COPPER_PER_GOLD + 0.5)
    local text = BreakUpLargeNumbers(gold)
    local icon = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
    return text .. icon
end

function addon:GetWarbandBankGold()
    -- Try to fetch current warband bank gold
    if C_Bank and Enum and Enum.BankType and Enum.BankType.Account then
        local ok, value = pcall(C_Bank.FetchDepositedMoney, Enum.BankType.Account)
        if ok and type(value) == "number" and value > 0 then
            -- We have access - update cache
            self.db.warband = self.db.warband or {}
            self.db.warband.gold = value
            self.db.warband.lastUpdate = time()
            return value
        end
    end
    
    -- No access or API failed - return cached value
    if self.db and self.db.warband and self.db.warband.gold then
        return self.db.warband.gold
    end
    
    return 0
end

-- For secure frames (Utility Bar), never call Show/Hide or EnableMouse in combat.
function addon:SetSecureFrameVisible(frame, wantVisible)
    if not frame then
        return
    end

    if InCombatLockdown() then
        -- During combat, only change alpha (can't call EnableMouse/Show/Hide on secure frames)
        if wantVisible then
            frame:SetAlpha(1)
        else
            frame:SetAlpha(0)
        end
        return
    end

    -- Out of combat, we can safely modify secure frame state
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
-- API Compatibility Wrappers
-----------------------------------------------------------------------

addon.API = {}

function addon.API.GetItemIcon(itemID)
    if not itemID then return nil end
    
    if C_Item and C_Item.GetItemIconByID then
        return C_Item.GetItemIconByID(itemID)
    elseif GetItemIcon then
        return GetItemIcon(itemID)
    end
    return nil
end

function addon.API.GetSpellCooldown(spellID)
    if not spellID then return 0, 0, 0 end
    
    if C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(spellID)
        if info then
            return info.startTime or 0, info.duration or 0, info.isEnabled and 1 or 0
        end
    elseif GetSpellCooldown then
        local start, duration, enabled = GetSpellCooldown(spellID)
        return start or 0, duration or 0, enabled and 1 or 0
    end
    return 0, 0, 0
end

function addon.API.GetSpellTexture(spellID)
    if not spellID then return nil end
    
    if GetSpellTexture then
        return GetSpellTexture(spellID)
    elseif GetSpellInfo then
        local _, _, tex = GetSpellInfo(spellID)
        return tex
    end
    return nil
end

function addon.API.GetSpellName(spellID)
    if not spellID then return nil end
    
    if GetSpellInfo then
        return GetSpellInfo(spellID)
    end
    return nil
end

-----------------------------------------------------------------------
-- Font management
-----------------------------------------------------------------------

local bodyFont, headerFont

function addon:GetBodyFont()
    if not bodyFont then
        local size = self.db and self.db.profile.fontSize or 13
        bodyFont = CreateFont("GoblinToolboxFontBody")
        bodyFont:SetFont("Fonts\\ARIALN.TTF", size, "")
        bodyFont:SetTextColor(0.9, 0.9, 0.9)
    end
    return bodyFont
end

function addon:GetHeaderFont()
    if not headerFont then
        local size = (self.db and self.db.profile.fontSize or 13) + 1
        headerFont = CreateFont("GoblinToolboxFontHeader")
        headerFont:SetFont("Fonts\\ARIALN.TTF", size, "OUTLINE")
        headerFont:SetTextColor(0.97, 0.86, 0.29)
    end
    return headerFont
end

function addon:ResetFontCache()
    bodyFont = nil
    headerFont = nil
end

-----------------------------------------------------------------------
-- Module registry (for future extensibility)
-----------------------------------------------------------------------

addon.modules = {}

function addon:RegisterModule(key, moduleTable)
    self.modules[key] = moduleTable
end

function addon:GetModule(key)
    return self.modules[key]
end

-----------------------------------------------------------------------
-- Debug helper (optional, useful during development)
-----------------------------------------------------------------------

function addon:Debug(...)
    if self.db and self.db.profile and self.db.profile.debug then
        print("|cff00ff00[GTB Debug]|r", ...)
    end
end