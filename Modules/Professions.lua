-- Modules/Professions.lua
-- Professions module: profession display, concentration tracking, cooldowns (future)

local addonName, addon = ...

local Professions = {}
addon:RegisterModule("Professions", Professions)

-----------------------------------------------------------------------
-- Profession detection (TODO: implement)
-----------------------------------------------------------------------

-- Future: Use GetProfessions() and GetProfessionInfo() to get:
--   prof1, prof2, archaeology, fishing, cooking, firstAid = GetProfessions()
--   name, icon, skillLevel, maxSkillLevel, numAbilities, spelloffset, skillLine, skillModifier, specializationIndex, specializationOffset = GetProfessionInfo(index)
--
-- For current expansion skill levels, may need C_TradeSkillUI APIs

function Professions:GetPlayerProfessions()
    -- Placeholder: returns nil until implemented
    -- Will return table like:
    -- {
    --     { name = "Engineering", skillLine = 202, icon = ..., level = 100, maxLevel = 100 },
    --     { name = "Alchemy", skillLine = 171, icon = ..., level = 80, maxLevel = 100 },
    -- }
    return nil
end

-----------------------------------------------------------------------
-- Concentration tracking (TODO: implement)
-----------------------------------------------------------------------

-- Future: Track concentration for crafting professions
-- Need to identify the correct API for this in 11.0+

function Professions:GetConcentration()
    -- Placeholder: returns nil until implemented
    -- Will return: current, max (or nil if not applicable)
    return nil, nil
end

-----------------------------------------------------------------------
-- Section update (called by HUD)
-----------------------------------------------------------------------

function Professions:Update()
    if not addon.db.profile.modules.Professions then
        return
    end
    
    local sec = addon.HUD and addon.HUD.sections and addon.HUD.sections.Professions
    if not sec then
        return
    end
    
    -- Placeholder display until profession detection is implemented
    local current, max = self:GetConcentration()
    
    if current and max then
        local percent = max > 0 and math.floor((current / max) * 100) or 0
        sec.lines[1]:SetText(string.format("Concentration: %d / %d (%d%%)", current, max, percent))
    else
        sec.lines[1]:SetText("Concentration: n/a")
    end
end

-----------------------------------------------------------------------
-- Click to open profession UI (TODO: implement)
-----------------------------------------------------------------------

-- Future: Allow clicking on profession name/icon to open that profession's UI
-- Use: C_TradeSkillUI.OpenTradeSkill(skillLineID)

function Professions:OpenProfessionUI(skillLineID)
    if skillLineID and C_TradeSkillUI and C_TradeSkillUI.OpenTradeSkill then
        C_TradeSkillUI.OpenTradeSkill(skillLineID)
    end
end

-----------------------------------------------------------------------
-- Expose module to addon for backward compatibility
-----------------------------------------------------------------------

function addon:UpdateProfessionsSection()
    Professions:Update()
end

-- Expose for direct access if needed
addon.Professions = Professions
