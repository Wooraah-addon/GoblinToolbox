-- MinimapButton.lua
-- LibDBIcon-based minimap button for Goblin Toolbox

local addonName, addon = ...

local LDB = LibStub and LibStub:GetLibrary("LibDataBroker-1.1", true)
local LDBIcon = LibStub and LibStub:GetLibrary("LibDBIcon-1.0", true)

-- Verify libraries are available
if not LDB or not LDBIcon then
    print("|cFFFFD700Goblin Toolbox:|r LibDataBroker or LibDBIcon not found. Minimap button disabled.")
    return
end

-- Create LDB launcher data object
local launcher = LDB:NewDataObject("GoblinToolbox", {
    type = "launcher",
    icon = "Interface\\AddOns\\GoblinToolbox\\media\\Textures\\MinimapButton.png",
    OnClick = function(self, button)
        if button == "LeftButton" then
            addon:OpenConfig()
        end
    end,
    OnTooltipShow = function(tooltip)
        tooltip:SetText("Goblin Toolbox", 1, 0.82, 0)
        tooltip:AddLine("Left-click: Toggle options", 1, 1, 1)
        tooltip:AddLine("Drag: Move", 0.6, 0.6, 0.6)
    end,
})

function addon:CreateMinimapButton()
    -- Ensure db.global.minimap exists with defaults
    local db = addon.db.global
    if not db.minimap then
        db.minimap = { hide = false, minimapPos = 220 }
    end

    -- Register with LibDBIcon (uses db.global.minimap for persistence)
    LDBIcon:Register("GoblinToolbox", launcher, db.minimap)

    -- Apply initial visibility
    addon:UpdateMinimapButtonVisibility()
end

function addon:UpdateMinimapButtonVisibility()
    if not LDBIcon then return end

    local hide = addon.db.global.minimap.hide
    if hide then
        LDBIcon:Hide("GoblinToolbox")
    else
        LDBIcon:Show("GoblinToolbox")
    end
end
