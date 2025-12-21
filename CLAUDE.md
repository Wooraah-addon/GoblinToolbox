# Goblin Toolbox - Claude Code Context

## Project Overview

Goblin Toolbox is a lightweight, modular gold-making HUD addon for World of Warcraft (Retail). It targets The War Within (12.0) and beyond.

## Author

Wooraah (golbintoolbox@gmail.com)

## Design Philosophy

- **Plumber-inspired**: Modular, lightweight, minimal configuration
- **Blizzard UI integration**: Fonts, colors, spacing match default WoW look
- **Conservative patterns**: Readable code over clever abstractions
- **No required dependencies**: Works standalone, optional TSM integration

## Tech Stack

- Lua 5.1 (WoW embedded interpreter)
- WoW API (The War Within / 12.0+)
- SavedVariables for persistence

## File Structure

```
GoblinToolbox/
├── Core.lua           # Constants, defaults, shared helpers, API wrappers
├── HUD.lua            # Main frame, sections, layout engine, visibility
├── Config.lua         # Options panel, /gtb command handler
├── GoblinToolbox.lua  # Event handlers, initialization, slash commands
├── TrackerBar.lua     # Item tracker bar frame
├── CurrencyBar.lua    # Currency tracker bar frame
├── UtilityBar.lua     # Secure action buttons bar
└── Modules/
    ├── Character.lua  # Character info, shard ID, movement speed
    ├── Gold.lua       # Gold tracking, session, token price
    ├── Inventory.lua  # Bag slots, bag value, warband access
    ├── Professions.lua # (Paused) Profession display, concentration
    └── TooltipIDs.lua # Tooltip ID injection
```

**Note**: TOC references `Modules/` paths - ensure files are in that subfolder.

## Key Patterns

### Module Registration
```lua
local MyModule = {}
addon:RegisterModule("MyModule", MyModule)

function MyModule:Update()
    -- Called by HUD to refresh display
end

-- Expose for backward compatibility
function addon:UpdateMyModuleSection()
    MyModule:Update()
end
```

### Section Creation (HUD.lua)
```lua
CreateSection(frame, "Key", "Header Text", numLines)
```

### Element Toggles
Individual elements controlled via `db.elements.elementKey`
Modules controlled via `db.modules.ModuleName`

### Secure Frames
UtilityBar uses SecureActionButtonTemplate - never Show/Hide in combat.
Use `addon:SetSecureFrameVisible(frame, visible)` instead.

## Current Development Status

See `Current_Development_status.txt` for detailed feature completion status.

### Complete
- HUD frame with movable/resizable/lockable functionality
- Character module (name, realm, icons, shard ID, movement speed)
- Gold module (character, warband, guild, session, token)
- Inventory module (bag slots, bag value, warband access)
- Item and Currency tracker bars
- Utility bar with hearthstones and portable services
- Options panel with collapsible sections
- Tooltip ID display

### Incomplete / In Progress
- Session persistence on logout (option exists but not working)
- Gold spent tracking
- Extended period tracking (day/week/month)
- Additional utility buttons (cooking fire, anvil, housing)
- Professions module (paused for Midnight)

## Code Style Preferences

1. **Always return complete files** - no snippets or diffs
2. **Preserve existing structure** - comments, formatting, organization
3. **Use local functions** where possible
4. **Follow existing patterns** for consistency
5. **Conservative error handling** - pcall for external APIs
6. **Clear variable names** over brevity

## Common Tasks

### Adding a new HUD element
1. Add toggle to `DEFAULTS.profile.elements` in Core.lua
2. Add checkbox to Config.lua in appropriate module section
3. Update module's `:Update()` function to check `elem.newElement ~= false`
4. Update section line text accordingly

### Adding a new Utility button
1. Add definition to `UTILITY_ACTIONS` in UtilityBar.lua
2. Add to `UTILITY_ORDER` array
3. Add default state to `DEFAULTS.profile.utilityButtons` in Core.lua
4. Add checkbox to Config.lua utility section
5. Add availability check function if needed

### Adding a new tracked bar
1. Create new bar file (e.g., NewBar.lua)
2. Add to TOC file
3. Create frame with backdrop, drag handle, buttons pattern
4. Add position persistence to saved variables
5. Call from GoblinToolbox.lua initialization

## Testing Checklist

- [ ] `/reload` doesn't error
- [ ] `/gtb` opens config
- [ ] All checkboxes save/load correctly
- [ ] Frames remember position after logout
- [ ] Hide in combat works
- [ ] Utility buttons work outside combat
- [ ] No taint errors in combat
