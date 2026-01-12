# Goblin Toolbox - Claude Code Context

## Project Overview

Goblin Toolbox is a lightweight, modular gold-making HUD addon for World of Warcraft (Retail). It targets The War Within (12.0+) and is currently at **v0.6.3**.

The addon is intentionally "at-a-glance": it consolidates small, high-signal gold-making utilities (gold/session/value/tracking/utility buttons) without trying to replace full systems like TSM/Auctionator.

## Author

Wooraah (golbintoolbox@gmail.com)

## Design Philosophy (Non-negotiables)

- **Lightweight + modular**: Features must be optional and avoid heavy background work.
- **Readable, conservative Lua**: Prefer clear code over clever abstractions.
- **Minimal dependencies**: Standalone by default; optional integrations must be nil-safe and wrapped with `pcall`.
- **Event-driven over polling**: Avoid frequent queries; debounce UI refreshes; use tickers sparingly.
- **Combat safety**: Never change protected/secure UI state in combat. Use existing safe helpers.
- **UI Design**: Clear, easily readable fonts, colors and spacing.

## Tech Stack

- Lua 5.1 (WoW embedded interpreter)
- WoW API (The War Within / 12.0+)
- SavedVariables (`GoblinToolboxDB`) for persistence
- Optional: TSM API for price sources

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
    ├── Gold.lua       # Gold tracking, session, token price, auctions
    ├── Inventory.lua  # Bag slots, bag value, bank scanning
    ├── Professions.lua # (Paused) Profession display, concentration
    └── TooltipIDs.lua # Tooltip ID injection
```

**Note**: TOC references `Modules/` paths - ensure files are in that subfolder.

## Runtime Architecture

### Startup (PLAYER_LOGIN)
Boot sequence in `GoblinToolbox.lua`:
1. `addon.db = addon:GetDB()` (CopyDefaults into `GoblinToolboxDB`)
2. Cache `addon.state.characterKey` at login
3. Create UI frames: HUD, tracker bar, currency bar, utility bar
4. Restore or reset session (`LoadSessionState()` if enabled; else `ResetSession()`)
5. Initialize posted auction data from per-character cache
6. Start tickers (session 1s, token per constants)
7. Register hooks (bank transfer intent, auction posting)
8. Update all sections + visibility

### Central Event Router
`GoblinToolbox.lua` uses a single EventFrame + `EventHandlers[event]` map. Extend this pattern instead of adding new frames.

### Safe Layout Rule
Use `addon:SafeLayoutHUD()` when updates are triggered by events. This defers `LayoutHUD()` during combat to avoid taint.

## SavedVariables Model

`GoblinToolboxDB` structure:
- `profiles`: Named profile definitions (content, settings, positions per-profile)
- `profileKeys`: Maps `realm-name` character keys to active profile name
- `global`: Account-wide settings (appearance, TSM source, session persistence)
- `characters`: Per-character caches keyed by `realm-name`
- `guilds`: Per-guild caches keyed by guild name
- `warband`: Account-wide warband caches (gold + items)

**Profile vs Global Scope**:
- **Profile**: Content-specific (modules, elements, tracked items, positions, view modes)
- **Global**: Visual/technical preferences (scale, font, opacity, TSM source, account label, session persistence)

**Key Notes**:
- `CopyDefaults(DEFAULTS, GoblinToolboxDB)` merges missing keys without overwriting existing values.
- Session state stored per-character in `characters[characterKey].sessionState`
- Posted auction totals cached per-character in `characters[characterKey]`
- Frame positions (HUD, Utility, Tracker, Currency) stored per-profile
- Schema migrations tracked via `global.schemaVersion` (currently 5)

## Key Patterns

### Module Registration
```lua
local M = {}
addon:RegisterModule("MyModule", M)

function M:Update()
    -- Rebuild HUD lines based on db toggles + cached state
end

function addon:UpdateMyModuleSection()
    M:Update()
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

### UI Refresh Discipline
- Avoid spamming HUD refreshes inside high-frequency loops.
- Use debounced timers (`C_Timer.NewTimer`) with a guard flag.
- Example: Posted auctions HUD updates are debounced; bag value recalc is queued.

## High-Signal Implementation Details

### Session Tracking
- Offline time treated as paused time when persistence enabled.
- Earned/Spent derived from `GetMoney()` deltas with login race guards.
- Bank deposits/withdrawals neutralized via intent queue + `sessionTransferOffset`.

### Looted Item Value
- Driven by `CHAT_MSG_LOOT`.
- Uses TSM/vendor pricing via Inventory pricing path.
- Handles uncached items via pending retry queue (no heavy loops).

### Posted Auctions
- Immediate increments on post hooks: commodity = unitPrice * quantity; non-commodity = buyout.
- Authoritative recompute on `OWNED_AUCTIONS_UPDATED` using owned auction API.
- **Do not** add frequent owned auction refresh queries during posting (known lag source).

### Rank-aware Item Tracking
Counts tracked both aggregated by `itemID` and rank-aware by `itemID:rank` key (rank 0 for unranked).

### Price Sources
- Primary: TSM custom price sources via `TSM_API.GetCustomPriceValue`
- Fallback: vendor sell price (`GetItemInfo` vendor field)
- All external calls must be `pcall`'d and nil-guarded.
- Planned: Auctionator / Oribos Exchange support

## Current Development Status

See `Current Development status.txt` for detailed tracking of feature completion and bugs.

**High priority items**:
- Auctionator price source support
- Profile management / presets / import-export (lightweight approach)
- Code cleanup pass prior to wider release

## Debug / Slash Commands

- `/gtb` - Opens config panel
- `/gtb debugtransfers` - Toggles bank transfer debug logging
- `/gtb sessiondebug` - Prints persisted + live session state
- `/gtb reset` - Reset session
- `/gtb pause` - Pause/resume session
- `/gtb lock` / `/gtb unlock` - Lock/unlock frame positions

## Code Style Preferences

- Edit in place with minimal diffs - change only what is necessary.
- Preserve existing structure - keep comments, formatting, naming conventions.
- Prefer local scope - use local functions/variables; avoid new globals.
- Follow existing patterns - mirror current module/section/toggle conventions.
- Conservative error handling - nil-guard timing-sensitive WoW API; pcall for external integrations.
- Readable over clever - clear names, straightforward flow, small functions.
- Performance-aware - avoid OnUpdate loops; throttle/batch high-frequency events; cache computations.
- WoW safety - avoid taint/combat-lockdown hazards; guard with `InCombatLockdown()`.

## Common Tasks

### Adding a new HUD element
1. Add toggle to `DEFAULTS.profile.elements` in Core.lua
2. Add checkbox to Config.lua in appropriate module section
3. Update module's `:Update()` to check `elem.newElement ~= false`
4. Ensure HUD line is blanked when disabled (avoid stale text)
5. Call `addon:SafeLayoutHUD()` after update if layout might change

### Adding a new config setting that affects computation
1. Add to `DEFAULTS.profile` (or `global` if account-wide)
2. Add Config UI control and save/load wiring
3. Queue recalcs instead of doing work inline
4. Verify persistence across `/reload`

### Adding a new Utility button
1. Add entry in UtilityBar action tables / order list
2. Add defaults in `DEFAULTS.profile.utilityButtons`
3. Add config checkbox
4. Confirm combat safety: attribute changes only out of combat

### Adding a new tracked bar
1. Create new bar file (e.g., NewBar.lua)
2. Add to TOC file
3. Create frame with backdrop, drag handle, buttons pattern
4. Add position persistence to saved variables
5. Call from GoblinToolbox.lua initialization

## Git Hygiene & Releases

- Commit when `/reload` is clean and testing checklist passes.
- Prefer small commits with clear intent (e.g., `fix: nil guard bag scan`, `feat: add warband gold line`).
- For releases: tag `vX.Y.Z`. Keep release notes short and user-facing.
- If CurseForge packaging present, keep metadata updated.

## Testing Checklist

- [ ] `/reload` produces no errors
- [ ] `/gtb` opens config
- [ ] Toggle changes persist across `/reload`
- [ ] HUD + tracker + currency + utility frames remember positions after relog
- [ ] Hide in combat / hide in instances behaves correctly
- [ ] Utility bar secure behavior: no blocked actions in combat
- [ ] Auction house: open AH updates posted totals; mass posting does not lag
- [ ] Bank: opening banker triggers bank scans; warband cache fallback works when inaccessible
- [ ] Session persistence restores correctly after relog
