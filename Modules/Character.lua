-- Modules/Character.lua
-- Character module: class icon, name, realm, shard ID, movement speed

local addonName, addon = ...

local Character = {}
addon:RegisterModule("Character", Character)

-----------------------------------------------------------------------
-- Helper functions
-----------------------------------------------------------------------

-- Race icon markup as an ATLAS (Syndicator-style).
-- Atlas format (Retail): raceicon128-<race>-<male|female>
-- Rendered inline in FontStrings: \124A:<atlasName>:<w>:<h>\124a
local raceIconCache = {}
local genders = { "unknown", "male", "female" }

-- Race file strings that differ from atlas naming
local raceCorrections = {
    ["scourge"] = "undead",
    ["zandalaritroll"] = "zandalari",
    ["highmountaintauren"] = "highmountain",
    ["lightforgeddraenei"] = "lightforged",
    ["earthendwarf"] = "earthen",
}

local function GetRaceIconMarkup(size)
    size = tonumber(size) or 20

    local _, raceFile = UnitRace("player")
    local sex = UnitSex("player") -- 1 unknown, 2 male, 3 female
    if not raceFile then
        return "\124TInterface\\Icons\\INV_Misc_QuestionMark:" .. size .. ":" .. size .. ":0:0\124t"
    end

    local gender = genders[sex] or "male"
    local raceKey = string.lower(raceFile)
    raceKey = raceCorrections[raceKey] or raceKey

    local prefix = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) and "raceicon128" or "raceicon"
    local atlasName = prefix .. "-" .. raceKey .. "-" .. gender

    local cacheKey = atlasName .. ":" .. size
    if raceIconCache[cacheKey] then
        return raceIconCache[cacheKey]
    end

    if C_Texture and type(C_Texture.GetAtlasInfo) == "function" then
        if C_Texture.GetAtlasInfo(atlasName) then
            local markup = string.format("\124A:%s:%d:%d\124a", atlasName, size, size)
            raceIconCache[cacheKey] = markup
            return markup
        end
    end

    return "\124TInterface\\Icons\\INV_Misc_QuestionMark:" .. size .. ":" .. size .. ":0:0\124t"
end

-- Shard ID cache
local cachedShardID = nil
local lastShardUpdate = 0

local function GetShardID()
    -- Return cached value if recent (within 5 seconds)
    if cachedShardID and (GetTime() - lastShardUpdate) < 5 then
        return cachedShardID
    end

    -- Try target
    local guid = UnitGUID("target")
    if guid and not UnitPlayerControlled("target") then
        local _, _, _, _, zone_uid = strsplit("-", guid)
        if zone_uid then
            cachedShardID = tonumber(zone_uid)
            lastShardUpdate = GetTime()
            return cachedShardID
        end
    end

    -- Try mouseover
    guid = UnitGUID("mouseover")
    if guid and not UnitPlayerControlled("mouseover") then
        local _, _, _, _, zone_uid = strsplit("-", guid)
        if zone_uid then
            cachedShardID = tonumber(zone_uid)
            lastShardUpdate = GetTime()
            return cachedShardID
        end
    end

    -- Try pet
    guid = UnitGUID("pet")
    if guid and not UnitPlayerControlled("pet") then
        local _, _, _, _, zone_uid = strsplit("-", guid)
        if zone_uid then
            cachedShardID = tonumber(zone_uid)
            lastShardUpdate = GetTime()
            return cachedShardID
        end
    end

    return cachedShardID or 0
end

local function OnCombatLogEvent()
    local _, subevent, _, _, _, _, _, destGUID = CombatLogGetCurrentEventInfo()

    -- Only process NPC-related events
    if subevent and destGUID and not string.match(destGUID, "^Player%-") then
        local _, _, _, _, zone_uid = strsplit("-", destGUID)
        if zone_uid then
            local shardID = tonumber(zone_uid)
            if shardID and shardID > 0 then
                cachedShardID = shardID
                lastShardUpdate = GetTime()
            end
        end
    end
end

local function GetMovementSpeed()
    local _, runSpeed, flightSpeed = GetUnitSpeed("player")

    local currentSpeed = flightSpeed
    if currentSpeed == 0 or not IsFlying() then
        currentSpeed = runSpeed
    end

    -- Base run speed is 7 yards/sec
    local baseSpeed = 7
    local speedPercent = (currentSpeed / baseSpeed) * 100

    return speedPercent
end

-----------------------------------------------------------------------
-- Section update (called by HUD)
-----------------------------------------------------------------------

function Character:Update()
    -- Treat nil as enabled, older saved variables may not have the key.
    if addon.db.profile.modules.Character == false then
        return
    end

    local sec = addon.HUD and addon.HUD.sections and addon.HUD.sections.Character
    if not sec or not sec.lines or not sec.lines[1] then
        return
    end

    local db = addon.db.profile
    local elem = db.elements or {}

    -------------------------------------------------------------------
    -- LINE 1: Character identity (icons + name + realm)
    -------------------------------------------------------------------
    local name, realm = UnitFullName("player")
    local line1 = ""

    if elem.charIcon ~= false then
        line1 = line1 .. GetRaceIconMarkup(20) .. " "
    end

    if elem.charClassIcon ~= false then
        local _, class = UnitClass("player")
        if class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class] then
            local coords = CLASS_ICON_TCOORDS[class]
            local left, right, top, bottom = coords[1], coords[2], coords[3], coords[4]
            line1 = line1 .. string.format(
                "\124TInterface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes:20:20:0:0:256:256:%d:%d:%d:%d\124t ",
                math.floor(left * 256), math.floor(right * 256), math.floor(top * 256), math.floor(bottom * 256)
            )
        end
    end

    if elem.charName ~= false then
        if line1 ~= "" then
            line1 = line1 .. (name or "Unknown")
        else
            line1 = (name or "Unknown")
        end
    end

    if elem.charRealm ~= false then
        local r = realm or GetRealmName() or "Unknown"
        if elem.charName ~= false and line1 ~= "" then
            line1 = line1 .. " - " .. r
        elseif line1 ~= "" then
            line1 = line1 .. r
        else
            line1 = r
        end
    end

    -- Add account label to the right of name/realm on same line
    if elem.charAccountLabel ~= false and addon.db.global and addon.db.global.accountLabel then
        local label = addon.db.global.accountLabel
        -- Only show if label is non-empty after trimming
        if label and label:trim() ~= "" then
            if line1 ~= "" then
                line1 = line1 .. " [" .. label .. "]"
            else
                line1 = "[" .. label .. "]"
            end
        end
    end

    sec.lines[1]:SetText(line1)

    -------------------------------------------------------------------
    -- LINE 2: ShardID / MoveSpeed (plain labels, no icons)
    -------------------------------------------------------------------
    if sec.lines[2] then
        local parts = {}

        if elem.charShardID ~= false then
            local shardID = GetShardID()
            local shardText = (shardID and shardID > 0) and tostring(shardID) or "Unknown"
            table.insert(parts, "ShardID: " .. shardText)
        end

        if elem.charMovespeed ~= false then
            local speed = GetMovementSpeed()
            table.insert(parts, string.format("MoveSpeed: %.3f%%", speed))
        end

        local line2 = table.concat(parts, "   ")
        sec.lines[2]:SetText(line2)
    end
end

-----------------------------------------------------------------------
-- Movement speed update ticker (for real-time updates)
-----------------------------------------------------------------------

Character._speedTicker = nil

function Character:StartSpeedTicker()
    if self._speedTicker then
        return
    end

    -- Update speed every 0.5 seconds when module is enabled
    self._speedTicker = C_Timer.NewTicker(0.5, function()
        if not addon.db or not addon.db.profile then
            return
        end

        local db = addon.db.profile
        if not db.enabled or db.modules.Character == false then
            return
        end

        if not addon.HUD or not addon.HUD.frame or not addon.HUD.frame:IsShown() then
            return
        end

        -- Only update if movement speed element is enabled
        local elem = db.elements or {}
        if elem.charMovespeed ~= false then
            Character:Update()
        end
    end)
end

-----------------------------------------------------------------------
-- Combat log event monitoring for shard detection
-----------------------------------------------------------------------

Character._combatLogFrame = nil

function Character:StartCombatLogMonitoring()
    if self._combatLogFrame then
        return
    end

    self._combatLogFrame = CreateFrame("Frame")
    self._combatLogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self._combatLogFrame:SetScript("OnEvent", function()
        OnCombatLogEvent()
    end)
end

-----------------------------------------------------------------------
-- Expose module to addon for backward compatibility
-----------------------------------------------------------------------

function addon:UpdateCharacterSection()
    Character:Update()
end

function addon:StartCharacterSpeedTicker()
    Character:StartSpeedTicker()
end

function addon:StartCharacterCombatLogMonitoring()
    Character:StartCombatLogMonitoring()
end

addon.Character = Character
