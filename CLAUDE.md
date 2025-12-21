# Goblin Toolbox - Claude Code Context

## Project Overview

Goblin Toolbox is a lightweight, modular gold-making HUD addon for World of Warcraft (Retail). It targets The War Within (12.0) and beyond.

## Author

Wooraah (golbintoolbox@gmail.com)

## Design Philosophy

- **Overall design**: Modular, lightweight, flexible configuration for end users
- **UI Design**: Clear, easily readable fonts, colors and spacing
- **Conservative patterns**: Readable code over clever abstractions
- **Limited dependencies**: Should be able to work standalone, optional integrations with common pricing based addons such as TSM and Auctionator.

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

See `Current_Development_status.txt` for the most detailed and up to date tracking of feature completion and current bugs.


## Code Style Preferences

- Edit in place with minimal diffs — change only what is necessary; avoid unrelated refactors or formatting changes.
- Preserve existing structure — keep comments, formatting, file organization, and naming conventions unless the change requires otherwise.
- Prefer local scope — use local functions/variables where appropriate; avoid introducing new globals.
- Follow existing patterns — mirror current module/section/toggle conventions and UI construction patterns for consistency.
- Conservative error handling — nil-guard timing-sensitive WoW API usage; use pcall only for optional external integrations (e.g., TSM).
- Readable over clever — clear variable names, straightforward control flow, and small functions; no abstraction layers unless they clearly reduce duplication.
- Performance-aware — avoid OnUpdate loops unless necessary; throttle/batch high-frequency event work; cache repeat computations where sensible.
- WoW safety — avoid taint/combat-lockdown hazards; do not modify protected/secure UI state in combat; defer or guard with InCombatLockdown() when needed.

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


### Git Hygiene & Releases

- Commit whenever: /reload is clean and the testing checklist passes for the change.
- Prefer small commits with clear intent (e.g., fix: nil guard bag scan, feat: add warband gold line).
- For releases: tag vX.Y.Z. Release notes should be short and user-facing (what changed, what to watch).
- If a release pipeline is present (CurseForge packaging), keep packaging metadata updated and avoid manual zip edits.

## Testing Checklist

- [ ] `/reload` doesn't error
- [ ] `/gtb` opens config
- [ ] All checkboxes save/load correctly
- [ ] Frames remember position after logout
- [ ] Hide in combat works
- [ ] Utility buttons work outside combat
- [ ] No taint errors in combat
