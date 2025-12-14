-- Modules/Character.lua
-- Character module: name, realm display (and future: class icon, movement speed)

local addonName, addon = ...

local Character = {}
addon:RegisterModule("Character", Character)

-----------------------------------------------------------------------
-- Section update (called by HUD)
-----------------------------------------------------------------------

function Character:Update()
    if not addon.db.profile.modules.Character then
        return
    end
    
    local sec = addon.HUD and addon.HUD.sections and addon.HUD.sections.Character
    if not sec then
        return
    end
    
    local name, realm = UnitFullName("player")
    sec.lines[1]:SetText(string.format("%s - %s", name or "Unknown", realm or "Unknown"))
end

-----------------------------------------------------------------------
-- Expose module to addon for backward compatibility
-----------------------------------------------------------------------

function addon:UpdateCharacterSection()
    Character:Update()
end

-- Expose for direct access if needed
addon.Character = Character
