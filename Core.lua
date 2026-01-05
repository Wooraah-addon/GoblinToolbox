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
    TOKEN_TREND_THRESHOLD = 10000 * 10000,  -- 10,000g in copper
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
        preferWarbandBankOnOpen = false,
        sessionPersistOnLogout = false,

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
            charShardID   = false,  -- Off by default (can be noisy)
            charMovespeed = false,  -- Off by default (updates frequently)
            -- Gold & Economy elements
            goldCharacter = true,
            goldWarband   = true,
            goldGuild     = true,
            goldSession   = true,
            goldToken     = true,
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

        -- Tooltip IDs settings (all off by default)
        tooltipIDs = {
            enabled     = false,
            item        = false,
            spell       = false,
            currency    = false,
            unit        = false,
            achievement = false,
            quest       = false,
            talent      = false,
            mount       = false,
            icon        = false,
        },

        -- Utility bar button states
        utilityButtons = {
            logout            = false,
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
    },

    characters = {},
    guilds     = {},
    warband    = {
        gold        = 0,
        lastUpdate  = 0,
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
}

addon.token = {
    lastPrice   = 0,
    lastUpdated = 0,
    history     = {},
}

addon.trackedCounts  = {}
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

-- For secure frames (Utility Bar), never call Show/Hide in combat.
function addon:SetSecureFrameVisible(frame, wantVisible)
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