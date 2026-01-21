-- Modules/TooltipIDs.lua
-- Tooltip IDs module: displays item, spell, currency, NPC, and other IDs in tooltips

local addonName, addon = ...

local TooltipIDs = {}
addon:RegisterModule("TooltipIDs", TooltipIDs)

-----------------------------------------------------------------------
-- ID Type Definitions
-----------------------------------------------------------------------

local ID_TYPES = {
    item        = "Item ID",
    spell       = "Spell ID",
    currency    = "Currency ID",
    unit        = "NPC ID",
    mount       = "Mount ID",
    icon        = "Icon ID",
}

-- Order for config display
local ID_TYPE_ORDER = {
    "item", "spell", "currency", "unit", "mount", "icon"
}

-----------------------------------------------------------------------
-- Tooltip Data Processing (Modern API)
-----------------------------------------------------------------------

-- Mapping from TooltipDataProcessor type IDs to our ID types
local TOOLTIP_TYPE_MAP = {
    [0]  = "item",        -- Item
    [1]  = "spell",       -- Spell
    [2]  = "unit",        -- Unit
    [3]  = "unit",        -- Corpse
    [5]  = "currency",    -- Currency
    [7]  = "spell",       -- UnitAura
    [10] = "mount",       -- Mount
}

local function AddIDLine(tooltip, id, idType)
    if not id or id == "" or not tooltip then
        return
    end
    
    local db = addon.db and addon.db.profile
    if not db or not db.tooltipIDs or not db.tooltipIDs.enabled then
        return
    end
    
    if not db.tooltipIDs[idType] then
        return
    end
    
    -- Check if we already added this ID to avoid duplicates
    local name = tooltip:GetName()
    if name then
        for i = 1, tooltip:NumLines() do
            local line = _G[name .. "TextLeft" .. i]
            if line then
                local text = line:GetText()
                if type(text) == "string" and text:find(ID_TYPES[idType]) then
                    return
                end
            end
        end
    end
    
    local label = ID_TYPES[idType]
    tooltip:AddDoubleLine(label, tostring(id), 0.5, 0.8, 1, 1, 1, 1)
    tooltip:Show()
end

-----------------------------------------------------------------------
-- Hook Tooltip Processor
-----------------------------------------------------------------------

function TooltipIDs:Initialize()
    if not TooltipDataProcessor then
        return
    end
    
    TooltipDataProcessor.AddTooltipPostCall(TooltipDataProcessor.AllTypes, function(tooltip, data)
        if not data or not data.type then
            return
        end
        
        local idType = TOOLTIP_TYPE_MAP[tonumber(data.type)]
        if not idType then
            return
        end
        
        -- Special handling for units (extract NPC ID from GUID)
        if idType == "unit" and data.guid then
            local unitId = tonumber(data.guid:match("-(%d+)-%x+$"), 10)
            if unitId and data.guid:match("%a+") ~= "Player" then
                AddIDLine(tooltip, unitId, "unit")
            end
        else
            AddIDLine(tooltip, data.id, idType)
        end
    end)
end

-----------------------------------------------------------------------
-- Additional Hooks for Coverage
-----------------------------------------------------------------------

function TooltipIDs:HookAdditionalTooltips()
    -- Hook spell tooltips (OnTooltipSetSpell doesn't exist in TWW, handled by TooltipDataProcessor)
    
    -- Hook item tooltips
    if GameTooltip.HookScript and GameTooltip:HasScript("OnTooltipSetItem") then
        GameTooltip:HookScript("OnTooltipSetItem", function(tooltip)
            local _, link = tooltip:GetItem()
            if link then
                local itemId = link:match("item:(%d+)")
                if itemId then
                    AddIDLine(tooltip, itemId, "item")
                    
                    -- Add icon ID if enabled
                    if addon.API and addon.API.GetItemIcon then
                        local iconId = addon.API.GetItemIcon(tonumber(itemId))
                        if iconId then
                            AddIDLine(tooltip, iconId, "icon")
                        end
                    end
                end
            end
        end)
    end
    
    -- Hook currency tooltips
    if GameTooltip.SetCurrencyByID then
        hooksecurefunc(GameTooltip, "SetCurrencyByID", function(tooltip, id)
            AddIDLine(tooltip, id, "currency")
        end)
    end
    
    -- Hook unit tooltips (OnTooltipSetUnit doesn't exist in TWW, handled by TooltipDataProcessor)
end

-----------------------------------------------------------------------
-- Module Initialization
-----------------------------------------------------------------------

-- This will be called from the main addon after PLAYER_LOGIN
function TooltipIDs:Enable()
    local db = addon.db and addon.db.profile
    if not db or not db.tooltipIDs or not db.tooltipIDs.enabled then
        return
    end
    
    self:Initialize()
    self:HookAdditionalTooltips()
end

-----------------------------------------------------------------------
-- Expose module
-----------------------------------------------------------------------

addon.TooltipIDs = TooltipIDs

-- Export for config
addon.TOOLTIP_ID_TYPES = ID_TYPES
addon.TOOLTIP_ID_TYPE_ORDER = ID_TYPE_ORDER
