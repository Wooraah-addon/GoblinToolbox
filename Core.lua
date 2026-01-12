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
        lockFrame        = false,
        hideInCombat     = false,
        hideInInstances  = false,
        showHeaders      = true,
        showTitleBar     = true,
        showBackground   = true,
        preferWarbandBankOnOpen = false,
        goldViewMode     = "simple",  -- "simple" or "detailed"
        debugTransfers   = false,  -- Debug logging for bank transfers and session persistence

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
    },

    global = {
        accountLabel = "",  -- Account-wide label shown in Character section (e.g., "WOW1")
        sessionPersistOnLogout = false,  -- User preference for session data persistence (separate from profiles)
        -- Appearance settings (account-wide visual preferences)
        scale = 1.0,
        fontSize = 13,
        backgroundOpacity = 0.30,
        -- Gold valuation settings (account-wide technical preferences)
        tsmSource = "dbregionmarketavg",
        tsmCustomSource = "",
        schemaVersion = 1,  -- Used for tracking SavedVariables migrations
    },

    profiles = {},      -- Will be populated with Default profile after migration
    profileKeys = {},   -- Maps characterKey to profile name

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
-- Character-specific cache access
-----------------------------------------------------------------------

function addon:GetCharacterCache()
    if not self.db or not self.db.characters then
        return nil
    end

    local charKey = self.state.characterKey or self:GetCharacterKey()
    if not charKey then
        return nil
    end

    -- Initialize character cache if it doesn't exist
    if not self.db.characters[charKey] then
        self.db.characters[charKey] = {
            playerBankItemCounts = {},
            playerBankLastUpdate = 0,
            sessionState = {},
        }
    end

    return self.db.characters[charKey]
end

-----------------------------------------------------------------------
-- SavedVariables migrations
-----------------------------------------------------------------------

function addon:MigrateSavedVariables()
    if not self.db then
        return
    end

    local currentSchema = self.db.global.schemaVersion or 0

    -- Migration 1: Move character-specific caches from profile to characters[charKey]
    if currentSchema < 1 then
        local charCache = self:GetCharacterCache()
        if charCache and self.db.profile then
            -- Migrate player bank cache
            if self.db.profile.playerBankItemCountsByKey then
                charCache.playerBankItemCounts = self.db.profile.playerBankItemCountsByKey
                self.db.profile.playerBankItemCountsByKey = nil
            end
            if self.db.profile.playerBankItemsLastUpdate then
                charCache.playerBankLastUpdate = self.db.profile.playerBankItemsLastUpdate
                self.db.profile.playerBankItemsLastUpdate = nil
            end

            -- Migrate session state
            if self.db.profile.sessionState then
                charCache.sessionState = self.db.profile.sessionState
                self.db.profile.sessionState = nil
            end
        end

        self.db.global.schemaVersion = 1
    end

    -- Migration 2: Convert single profile to multi-profile system
    if currentSchema < 2 then
        -- If we have a legacy profile but no profiles table, migrate it
        if self.db.profile and not next(self.db.profiles or {}) then
            self.db.profiles = self.db.profiles or {}
            self.db.profiles["Default"] = self.db.profile

            -- Create profileKeys and assign current character to Default
            self.db.profileKeys = self.db.profileKeys or {}
            local charKey = self.state.characterKey or self:GetCharacterKey()
            if charKey then
                self.db.profileKeys[charKey] = "Default"
            end

            -- Keep legacy profile for backward compatibility (in case of rollback)
            -- but active profile will now be loaded from profiles["Default"]
        end

        self.db.global.schemaVersion = 2
    end

    -- Migration 3: Move sessionPersistOnLogout from profile to global scope
    -- This setting should be a user's separate decision (not affected by profile switching)
    if currentSchema < 3 then
        -- Check if any profile has this setting enabled and migrate the value to global
        local foundEnabled = false
        if self.db.profiles then
            for _, profile in pairs(self.db.profiles) do
                if profile.sessionPersistOnLogout == true then
                    foundEnabled = true
                    break
                end
            end
        end

        -- If found in any profile, set it in global (otherwise use default of false)
        self.db.global.sessionPersistOnLogout = foundEnabled

        -- Remove from all profiles
        if self.db.profiles then
            for _, profile in pairs(self.db.profiles) do
                profile.sessionPersistOnLogout = nil
            end
        end

        self.db.global.schemaVersion = 3
    end

    -- Migration 4: Move appearance settings from profile to global scope
    -- Appearance (scale, fontSize, backgroundOpacity) should be account-wide visual preferences
    if currentSchema < 4 then
        -- Try to get appearance settings from current active profile
        local sourceProfile = nil
        if self.db.profiles then
            -- First try the active profile
            local charKey = self.state.characterKey or self:GetCharacterKey()
            if charKey and self.db.profileKeys and self.db.profileKeys[charKey] then
                local activeProfileName = self.db.profileKeys[charKey]
                sourceProfile = self.db.profiles[activeProfileName]
            end
            -- Fallback to Default profile
            if not sourceProfile then
                sourceProfile = self.db.profiles["Default"]
            end
            -- Last resort: use any profile
            if not sourceProfile then
                for _, profile in pairs(self.db.profiles) do
                    sourceProfile = profile
                    break
                end
            end
        end

        -- Migrate appearance settings to global
        if sourceProfile then
            if sourceProfile.scale then
                self.db.global.scale = sourceProfile.scale
            end
            if sourceProfile.fontSize then
                self.db.global.fontSize = sourceProfile.fontSize
            end
            if sourceProfile.backgroundOpacity then
                self.db.global.backgroundOpacity = sourceProfile.backgroundOpacity
            end
        end

        -- Remove appearance settings from all profiles
        if self.db.profiles then
            for _, profile in pairs(self.db.profiles) do
                profile.scale = nil
                profile.fontSize = nil
                profile.backgroundOpacity = nil
            end
        end

        self.db.global.schemaVersion = 4
    end

    -- Migration 5: Move TSM price source settings from profile to global scope
    -- These are technical preferences, not profile-specific content settings
    if currentSchema < 5 then
        -- Try to get source from current active profile
        local sourceProfile = nil
        if self.db.profiles then
            -- First try the active profile
            local charKey = self.state.characterKey or self:GetCharacterKey()
            if charKey and self.db.profileKeys and self.db.profileKeys[charKey] then
                local activeProfileName = self.db.profileKeys[charKey]
                sourceProfile = self.db.profiles[activeProfileName]
            end
            -- Fallback to Default profile
            if not sourceProfile then
                sourceProfile = self.db.profiles["Default"]
            end
            -- Last resort: use any profile
            if not sourceProfile then
                for _, profile in pairs(self.db.profiles) do
                    sourceProfile = profile
                    break
                end
            end
        end

        -- Migrate TSM source settings to global
        if sourceProfile then
            if sourceProfile.tsmSource then
                self.db.global.tsmSource = sourceProfile.tsmSource
            end
            if sourceProfile.tsmCustomSource then
                self.db.global.tsmCustomSource = sourceProfile.tsmCustomSource
            end
        end

        -- Remove from all profiles
        if self.db.profiles then
            for _, profile in pairs(self.db.profiles) do
                profile.tsmSource = nil
                profile.tsmCustomSource = nil
            end
        end

        self.db.global.schemaVersion = 5
    end
end

-----------------------------------------------------------------------
-- Profile system setup
-----------------------------------------------------------------------

function addon:EnsureProfileSystem()
    if not self.db then
        return
    end

    -- Ensure profiles and profileKeys exist
    self.db.profiles = self.db.profiles or {}
    self.db.profileKeys = self.db.profileKeys or {}

    -- Get current character key
    local charKey = self.state.characterKey or self:GetCharacterKey()
    if not charKey then
        -- Fallback: use Default profile if character key unavailable
        if not self.db.profiles["Default"] then
            self.db.profiles["Default"] = CopyDefaults(DEFAULTS.profile, {})
        end
        self.db.profile = self.db.profiles["Default"]
        return
    end

    -- Get assigned profile for this character (or Default if not assigned)
    local profileName = self.db.profileKeys[charKey] or "Default"

    -- Ensure the assigned profile exists, create from defaults if needed
    if not self.db.profiles[profileName] then
        self.db.profiles[profileName] = CopyDefaults(DEFAULTS.profile, {})
        self.db.profileKeys[charKey] = profileName
    end

    -- Point addon.db.profile to the active profile table
    self.db.profile = self.db.profiles[profileName]

    -- Store the active profile name for easy reference
    self.state.activeProfileName = profileName
end

-----------------------------------------------------------------------
-- Profile management API
-----------------------------------------------------------------------

function addon:GetActiveProfileName()
    return self.state.activeProfileName or "Default"
end

function addon:GetProfileNames()
    local names = {}
    if self.db and self.db.profiles then
        for name in pairs(self.db.profiles) do
            table.insert(names, name)
        end
        table.sort(names)
    end
    return names
end

function addon:GetProfile(name)
    if not self.db or not self.db.profiles then
        return nil
    end
    return self.db.profiles[name]
end

function addon:ValidateProfileName(name)
    if not name then
        return false, "Profile name cannot be empty"
    end

    -- Trim whitespace
    name = name:match("^%s*(.-)%s*$")

    if name == "" then
        return false, "Profile name cannot be empty"
    end

    if #name > 30 then
        return false, "Profile name too long (max 30 characters)"
    end

    -- Check if name already exists
    if self.db and self.db.profiles and self.db.profiles[name] then
        return false, "Profile '" .. name .. "' already exists"
    end

    -- Check for control characters
    if name:match("[%c]") then
        return false, "Profile name contains invalid characters"
    end

    return true, name  -- Return true and the trimmed name
end

function addon:SetActiveProfile(profileName)
    if not self.db or not self.db.profiles then
        return false
    end

    -- Ensure profile exists
    if not self.db.profiles[profileName] then
        return false
    end

    -- Get current character key
    local charKey = self.state.characterKey or self:GetCharacterKey()
    if not charKey then
        return false
    end

    -- Update profileKeys mapping
    self.db.profileKeys = self.db.profileKeys or {}
    self.db.profileKeys[charKey] = profileName

    -- Update the active profile pointer
    self.db.profile = self.db.profiles[profileName]
    self.state.activeProfileName = profileName

    return true
end

function addon:CreateProfile(newName, copyFromName)
    local valid, trimmedName = self:ValidateProfileName(newName)
    if not valid then
        return false, trimmedName  -- trimmedName contains error message
    end

    -- Default to copying from current active profile
    copyFromName = copyFromName or self:GetActiveProfileName()

    -- Get source profile to copy from
    local sourceProfile = self:GetProfile(copyFromName)
    if not sourceProfile then
        return false, "Source profile '" .. copyFromName .. "' not found"
    end

    -- Deep copy the source profile
    local function deepCopy(src)
        if type(src) ~= "table" then
            return src
        end
        local copy = {}
        for k, v in pairs(src) do
            copy[k] = deepCopy(v)
        end
        return copy
    end

    -- Create new profile
    self.db.profiles[trimmedName] = deepCopy(sourceProfile)

    -- Switch to the new profile
    self:SetActiveProfile(trimmedName)

    return true, trimmedName
end

function addon:RenameProfile(oldName, newName)
    if oldName == "Default" then
        return false, "Cannot rename the Default profile"
    end

    if not self:GetProfile(oldName) then
        return false, "Profile '" .. oldName .. "' does not exist"
    end

    local valid, trimmedName = self:ValidateProfileName(newName)
    if not valid then
        return false, trimmedName
    end

    -- Copy profile data to new name
    self.db.profiles[trimmedName] = self.db.profiles[oldName]
    self.db.profiles[oldName] = nil

    -- Update all profileKeys that referenced the old name
    if self.db.profileKeys then
        for charKey, profileName in pairs(self.db.profileKeys) do
            if profileName == oldName then
                self.db.profileKeys[charKey] = trimmedName
            end
        end
    end

    -- If this was the active profile, update pointer
    if self.state.activeProfileName == oldName then
        self.db.profile = self.db.profiles[trimmedName]
        self.state.activeProfileName = trimmedName
    end

    return true, trimmedName
end

function addon:DeleteProfile(name)
    if name == "Default" then
        return false, "Cannot delete the Default profile"
    end

    if not self:GetProfile(name) then
        return false, "Profile '" .. name .. "' does not exist"
    end

    -- Count total profiles to prevent deleting the last one
    local profileCount = 0
    for _ in pairs(self.db.profiles) do
        profileCount = profileCount + 1
    end

    if profileCount <= 1 then
        return false, "Cannot delete the last profile"
    end

    -- Reassign any characters using this profile to Default
    if self.db.profileKeys then
        for charKey, profileName in pairs(self.db.profileKeys) do
            if profileName == name then
                self.db.profileKeys[charKey] = "Default"
            end
        end
    end

    -- If deleting the active profile, switch to Default first
    if self.state.activeProfileName == name then
        self:SetActiveProfile("Default")
    end

    -- Delete the profile
    self.db.profiles[name] = nil

    return true
end

function addon:ResetProfile(name)
    name = name or self:GetActiveProfileName()

    if not self:GetProfile(name) then
        return false, "Profile '" .. name .. "' does not exist"
    end

    -- Reset the profile to defaults (deep copy)
    local function deepCopy(src)
        if type(src) ~= "table" then
            return src
        end
        local copy = {}
        for k, v in pairs(src) do
            copy[k] = deepCopy(v)
        end
        return copy
    end

    self.db.profiles[name] = deepCopy(DEFAULTS.profile)

    -- If this is the active profile, update the pointer
    if self.state.activeProfileName == name then
        self.db.profile = self.db.profiles[name]
    end

    return true
end

-----------------------------------------------------------------------
-- Preset system
-----------------------------------------------------------------------

addon.PRESETS = {
    Default = {
        showHeaders = true,
        showTitleBar = true,
        goldViewMode = "simple",
        modules = { Character = true, Gold = true, Inventory = true, Utility = true },
        elements = {
            charIcon = true, charClassIcon = true, charName = true, charRealm = true,
            charAccountLabel = false, charShardID = false, charMovespeed = false,
            goldCharacter = true, goldWarband = true, goldGuild = true,
            goldSession = true, goldToken = true, goldLootedValue = true, goldPostedAuctions = false,
            invBagSlots = true, invBagValue = true, invWarbank = true,
        },
        showTracker = true,
        showCurrencyTracker = true,
        showTrackedItemValue = true,
        trackerIncludeInventory = true,
        trackerIncludePlayerBank = false,
        trackerIncludeWarbandBank = false,
    },

    Essentials = {
        showHeaders = false,
        showTitleBar = true,
        goldViewMode = "simple",
        modules = { Character = true, Gold = true, Inventory = false, Utility = false },
        elements = {
            charIcon = true, charClassIcon = true, charName = true, charRealm = true,
            charAccountLabel = false, charShardID = false, charMovespeed = false,
            goldCharacter = true, goldWarband = true, goldGuild = true,
            goldSession = true, goldToken = false, goldLootedValue = false, goldPostedAuctions = false,
        },
        showTracker = false,
        showCurrencyTracker = false,
    },

    Farmer = {
        showHeaders = true,
        goldViewMode = "detailed",
        modules = { Character = true, Gold = true, Inventory = true, Utility = true },
        elements = {
            charIcon = true, charClassIcon = true, charName = true, charRealm = false,
            charAccountLabel = false, charShardID = false,
            charMovespeed = true,  -- Speed set tracking
            goldCharacter = true, goldWarband = true, goldGuild = false,
            goldSession = true, goldToken = false, goldLootedValue = true, goldPostedAuctions = false,
            invBagSlots = true, invBagValue = true, invWarbank = false,
        },
        showTracker = true,
        showTrackedItemValue = true,
        trackerIncludeInventory = true,
        trackerIncludePlayerBank = false,
        trackerIncludeWarbandBank = false,
    },

    Flipper = {
        showHeaders = true,
        goldViewMode = "detailed",
        modules = { Character = true, Gold = true, Inventory = true, Utility = true },
        elements = {
            charIcon = true, charClassIcon = true, charName = true, charRealm = true,  -- Multi-realm flippers want realm
            charAccountLabel = false, charShardID = false, charMovespeed = false,
            goldCharacter = true, goldWarband = true, goldGuild = false,
            goldSession = true, goldToken = true, goldLootedValue = false, goldPostedAuctions = true,
            invBagSlots = true, invBagValue = true, invWarbank = false,
        },
        showTracker = true,
        showTrackedItemValue = true,
        trackerIncludeInventory = true,
        trackerIncludePlayerBank = true,  -- Flippers track inventory across locations
        trackerIncludeWarbandBank = true,
    },

    Everything = {
        showHeaders = true,
        goldViewMode = "detailed",
        modules = { Character = true, Gold = true, Inventory = true, Utility = true },
        elements = {
            charIcon = true, charClassIcon = true, charName = true, charRealm = true,
            charAccountLabel = true, charShardID = true, charMovespeed = true,
            goldCharacter = true, goldWarband = true, goldGuild = true,
            goldSession = true, goldToken = true, goldLootedValue = true, goldPostedAuctions = true,
            invBagSlots = true, invBagValue = true, invWarbank = true,
        },
        showTracker = true,
        showCurrencyTracker = true,
        showTrackedItemValue = true,
        trackerIncludeInventory = true,
        trackerIncludePlayerBank = true,
        trackerIncludeWarbandBank = true,
        -- Enable all utility buttons
        utilityButtons = {
            logout = true,
            reload = true,
            mobileBank = true,
            mailbox = true,
            tradersBrutosaur = true,
            vendorMount = true,
            warbandBank = true,
            hearthstone = true,
            dalaranHS = true,
            garrisonHS = true,
            housingTeleport = true,
        },
        -- Enable all tooltip IDs
        tooltipIDs = {
            enabled = true,
            item = true,
            spell = true,
            currency = true,
            unit = true,
            mount = true,
            icon = true,
        },
    },
}

function addon:GetPresetNames()
    local names = {}
    for name in pairs(self.PRESETS) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

function addon:ApplyPresetToProfile(presetName, profileName)
    profileName = profileName or self:GetActiveProfileName()

    local preset = self.PRESETS[presetName]
    if not preset then
        return false, "Preset '" .. presetName .. "' does not exist"
    end

    local profile = self:GetProfile(profileName)
    if not profile then
        return false, "Profile '" .. profileName .. "' does not exist"
    end

    -- Deep merge preset into profile (recursive overwrite)
    local function deepMerge(dest, src)
        for k, v in pairs(src) do
            if type(v) == "table" and type(dest[k]) == "table" then
                deepMerge(dest[k], v)
            else
                dest[k] = v
            end
        end
    end

    deepMerge(profile, preset)

    -- If this is the active profile, refresh is needed
    if profileName == self:GetActiveProfileName() then
        return true, "refresh_needed"
    end

    return true
end

function addon:CreateProfileFromPreset(presetName, newProfileName)
    local preset = self.PRESETS[presetName]
    if not preset then
        return false, "Preset '" .. presetName .. "' does not exist"
    end

    local valid, trimmedName = self:ValidateProfileName(newProfileName)
    if not valid then
        return false, trimmedName
    end

    -- Start with defaults
    local function deepCopy(src)
        if type(src) ~= "table" then
            return src
        end
        local copy = {}
        for k, v in pairs(src) do
            copy[k] = deepCopy(v)
        end
        return copy
    end

    local newProfile = deepCopy(DEFAULTS.profile)

    -- Apply preset to the new profile
    local function deepMerge(dest, src)
        for k, v in pairs(src) do
            if type(v) == "table" and type(dest[k]) == "table" then
                deepMerge(dest[k], v)
            else
                dest[k] = v
            end
        end
    end

    deepMerge(newProfile, preset)

    -- Create the profile
    self.db.profiles[trimmedName] = newProfile

    -- Switch to it
    self:SetActiveProfile(trimmedName)

    return true, trimmedName
end

function addon:GetCurrentProfilePositions()
    local db = self.db.profile
    if not db then return nil end

    -- Extract all position-related fields from current profile
    return {
        -- HUD positions
        point = db.point,
        relPoint = db.relPoint,
        xOfs = db.xOfs,
        yOfs = db.yOfs,
        hudWidth = db.hudWidth,

        -- Utility bar position (table format)
        utilityBarPos = db.utilityBarPos and {
            point = db.utilityBarPos.point,
            relPoint = db.utilityBarPos.relPoint,
            x = db.utilityBarPos.x,
            y = db.utilityBarPos.y,
        } or nil,

        -- Tracker bar positions
        trackerPoint = db.trackerPoint,
        trackerRelPoint = db.trackerRelPoint,
        trackerXOfs = db.trackerXOfs,
        trackerYOfs = db.trackerYOfs,

        -- Currency bar positions
        currencyPoint = db.currencyPoint,
        currencyRelPoint = db.currencyRelPoint,
        currencyXOfs = db.currencyXOfs,
        currencyYOfs = db.currencyYOfs,
    }
end

function addon:GetProfilePositions(profileName)
    if not profileName then return nil end

    local profile = self.db.profiles[profileName]
    if not profile then return nil end

    -- Extract all position-related fields from specified profile
    return {
        -- HUD positions
        point = profile.point,
        relPoint = profile.relPoint,
        xOfs = profile.xOfs,
        yOfs = profile.yOfs,
        hudWidth = profile.hudWidth,

        -- Utility bar position (table format)
        utilityBarPos = profile.utilityBarPos and {
            point = profile.utilityBarPos.point,
            relPoint = profile.utilityBarPos.relPoint,
            x = profile.utilityBarPos.x,
            y = profile.utilityBarPos.y,
        } or nil,

        -- Tracker bar positions
        trackerPoint = profile.trackerPoint,
        trackerRelPoint = profile.trackerRelPoint,
        trackerXOfs = profile.trackerXOfs,
        trackerYOfs = profile.trackerYOfs,

        -- Currency bar positions
        currencyPoint = profile.currencyPoint,
        currencyRelPoint = profile.currencyRelPoint,
        currencyXOfs = profile.currencyXOfs,
        currencyYOfs = profile.currencyYOfs,
    }
end

function addon:CopyPositionsToProfile(targetProfileName, positions)
    if not targetProfileName or not positions then return end

    local targetProfile = self.db.profiles[targetProfileName]
    if not targetProfile then return end

    -- Copy all position fields to target profile
    targetProfile.point = positions.point
    targetProfile.relPoint = positions.relPoint
    targetProfile.xOfs = positions.xOfs
    targetProfile.yOfs = positions.yOfs
    targetProfile.hudWidth = positions.hudWidth

    if positions.utilityBarPos then
        targetProfile.utilityBarPos = {
            point = positions.utilityBarPos.point,
            relPoint = positions.utilityBarPos.relPoint,
            x = positions.utilityBarPos.x,
            y = positions.utilityBarPos.y,
        }
    end

    targetProfile.trackerPoint = positions.trackerPoint
    targetProfile.trackerRelPoint = positions.trackerRelPoint
    targetProfile.trackerXOfs = positions.trackerXOfs
    targetProfile.trackerYOfs = positions.trackerYOfs

    targetProfile.currencyPoint = positions.currencyPoint
    targetProfile.currencyRelPoint = positions.currencyRelPoint
    targetProfile.currencyXOfs = positions.currencyXOfs
    targetProfile.currencyYOfs = positions.currencyYOfs
end

-----------------------------------------------------------------------
-- Central refresh pipeline (called after profile/preset changes)
-----------------------------------------------------------------------

function addon:ApplyProfileAndRefresh(reason)
    -- Reset font cache (font size may have changed)
    if self.ResetFontCache then
        self:ResetFontCache()
    end

    -- Update all UI components
    if self.ApplyScale then
        self:ApplyScale()
    end

    if self.UpdateBackground then
        self:UpdateBackground()
    end

    if self.UpdateTitleBar then
        self:UpdateTitleBar()
    end

    if self.UpdateAllSections then
        self:UpdateAllSections()
    end

    -- Restore frame positions from new profile
    if self.RestoreHUDPosition then
        self:RestoreHUDPosition()
    end

    if self.RestoreUtilityBarPosition then
        self:RestoreUtilityBarPosition()
    end

    if self.RestoreTrackerBarPosition then
        self:RestoreTrackerBarPosition()
    end

    if self.RestoreCurrencyBarPosition then
        self:RestoreCurrencyBarPosition()
    end

    -- Ensure session is initialized (important for profile switches/creation)
    -- Session state lives in addon.state and should persist across profile changes
    -- But we need to ensure it's initialized if this is the first time
    if not self.state.sessionStartTime or not self.state.sessionStartGold then
        -- Session not initialized, initialize it now
        -- Don't try to load from cache here since we want to preserve running sessions
        if self.ResetSession then
            self:ResetSession()
        end
    end

    -- Re-initialize posted auction data (profile-independent, per-character)
    if self.Gold and self.Gold.InitializePostedAuctions then
        self.Gold:InitializePostedAuctions()
    end

    -- Ensure session ticker is running (safe to call multiple times)
    if self.StartSessionTicker then
        self:StartSessionTicker()
    end

    if self.UpdateUtilityBar then
        self:UpdateUtilityBar()
    end

    if self.UpdateTrackerBar then
        self:UpdateTrackerBar()
    end

    if self.UpdateCurrencyBar then
        self:UpdateCurrencyBar()
    end

    if self.UpdateVisibility then
        self:UpdateVisibility()
    end

    if self.SafeLayoutHUD then
        self:SafeLayoutHUD()
    end

    -- If config frame is open, refresh it
    if self.Config and self.Config.Refresh then
        self.Config:Refresh()
    end

    -- Print confirmation message
    if reason then
        print("|cff00ff00Goblin Toolbox:|r " .. reason)
    end
end

-- Wrapper functions that include refresh

function addon:SwitchProfile(profileName)
    local success = self:SetActiveProfile(profileName)
    if success then
        self:ApplyProfileAndRefresh("Switched to profile '" .. profileName .. "'")
    end
    return success
end

function addon:ApplyPreset(presetName)
    local success, result = self:ApplyPresetToProfile(presetName)
    if success then
        self:ApplyProfileAndRefresh("Applied preset '" .. presetName .. "'")
    end
    return success, result
end

function addon:ResetCurrentProfile()
    local profileName = self:GetActiveProfileName()
    local success = self:ResetProfile(profileName)
    if success then
        self:ApplyProfileAndRefresh("Reset profile '" .. profileName .. "' to defaults")
    end
    return success
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
    characterKey     = nil,  -- Cached at login (realm not available during logout)
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
        local size = self.db and self.db.global.fontSize or 13
        bodyFont = CreateFont("GoblinToolboxFontBody")
        bodyFont:SetFont("Fonts\\ARIALN.TTF", size, "")
        bodyFont:SetTextColor(0.9, 0.9, 0.9)
    end
    return bodyFont
end

function addon:GetHeaderFont()
    if not headerFont then
        local size = (self.db and self.db.global.fontSize or 13) + 1
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