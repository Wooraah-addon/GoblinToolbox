# Goblin Toolbox - Claude Code Context

## Project Overview

Goblin Toolbox is a lightweight, modular gold-making HUD addon for World of Warcraft (Retail). It targets Midnight (12.0+) and is currently at **v1.1.10**.

The addon is intentionally "at-a-glance": it consolidates small, high-signal gold-making utilities (gold/session/value/tracking/utility buttons) without trying to replace full systems like TSM/Auctionator.

## Author

Wooraah (golbintoolbox@gmail.com)

## Session Management

Use the custom Claude Code skills to start and end development sessions:

- **`/start`** — Reads project context, recent changes, and open decisions, then outputs a briefing and asks what to work on. Skill: `.claude/skills/start/SKILL.md`
- **`/end`** — Logs changes and decisions, prepares a git commit (with user approval), and outputs a handoff summary. Skill: `.claude/skills/end/SKILL.md`

Session artifacts (managed automatically by the skills):
- `.claude/session-changelog.md` — Timestamped log of code changes per session
- `.claude/decision-log.md` — Significant architectural and design decisions

## Project Planning & User Priorities

**CRITICAL: Always review `Current Development status.txt` when planning features or evaluating priorities.**

This document is manually maintained by the user and provides:
- Current feature completion status (COMPLETE/INCOMPLETE)
- User-assigned priority levels (LOW/MEDIUM/HIGH)
- Known bugs and their severity
- Features marked as "OUT OF SCOPE" or "IGNORE"
- User requests and community feedback

When proposing work or evaluating implementation approaches, cross-reference this document to:
- Avoid working on IGNORE/OUT OF SCOPE items unless explicitly requested
- Prioritize HIGH/MEDIUM items over LOW priority work
- Understand user perspective on feature value and complexity
- Check if a similar request has already been addressed or deferred

## Design Philosophy (Non-negotiables)

- **Lightweight + modular**: Features must be optional and avoid heavy background work.
- **Readable, conservative Lua**: Prefer clear code over clever abstractions.
- **Minimal dependencies**: Standalone by default; optional integrations must be nil-safe and wrapped with `pcall`.
- **Event-driven over polling**: Avoid frequent queries; debounce UI refreshes; use tickers sparingly.
- **Combat safety**: Never change protected/secure UI state in combat. Use existing safe helpers.
- **UI Design**: Clear, easily readable fonts, colors and spacing.

## WoW API Standards (CRITICAL - NON-NEGOTIABLE)

**ALWAYS validate WoW API functions against https://warcraft.wiki.gg/wiki/ before use.**

Before using ANY WoW API function, event, or frame method:

1. **Search the function on warcraft.wiki.gg** - Check for deprecation warnings, replacement APIs, and version notes
2. **Verify it's current for Retail/Midnight (12.0+)** - Classic-only or deprecated APIs must not be used
3. **Check for modern alternatives** - Blizzard frequently replaces old APIs with C_NamespacedAPI equivalents
4. **Review event documentation** - Ensure event payloads and registration requirements are current
5. **When refactoring existing code** - Audit all WoW API calls for deprecated functions even if currently working

**Common deprecation patterns to watch for:**
- Legacy global functions replaced by C_* namespaced APIs (e.g., `GetItemInfo` → `C_Item.GetItemInfo`)
- Old event names superseded by new events (e.g., `UNIT_INVENTORY_CHANGED` → specific slot events)
- Frame methods with secure alternatives (e.g., `Show()/Hide()` → `SetShown()` for secure frames)
- Removed APIs with no direct replacement (require alternative implementation approach)

**When receiving feedback about deprecated APIs:**
1. Immediately check warcraft.wiki.gg for the recommended replacement
2. Plan migration across all instances in codebase (use Grep to find all usages)
3. Test thoroughly - replacement APIs may have different signatures or behavior
4. Update relevant sections of this document if architectural patterns change

**Reference:** https://warcraft.wiki.gg/wiki/World_of_Warcraft_API

Failure to validate API currency can result in:
- Addon breaking in future patches when deprecated APIs are removed
- Poor performance from using outdated, slower API patterns
- Taint issues from using insecure methods when secure alternatives exist
- User-facing errors and negative community feedback

## Development Tools (Recommended)

### WoW API Extension for VS Code / Cursor

**Extension:** [WoW API - Ketho](https://marketplace.visualstudio.com/items?itemName=ketho.wow-api)

**What it provides:**
- LuaLS (Lua Language Server) type annotations for all WoW APIs
- Full function signatures with parameter/return types
- `@deprecated` warnings for outdated functions
- Direct links to warcraft.wiki.gg in hover tooltips
- IntelliSense autocomplete for WoW namespaces (C_Item, C_SpellBook, etc.)

**Installation:**
1. **VS Code**: Install from Extensions marketplace (search "WoW API")
2. **Cursor**: Same extension works in Cursor (built on VS Code) - install from Extensions marketplace

**How it helps GTB:**
- Flags deprecated API usage with strikethrough/warnings before testing
- Shows exact replacement functions (e.g., `GetItemInfo` → `C_Item.GetItemInfo`)
- Catches namespace typos (e.g., nonexistent `C_Spell.IsSpellKnown` vs correct `C_SpellBook.IsSpellKnown`)
- Validates function signatures at write-time instead of in-game

**Current workspace configuration** (`.vscode/settings.json`):
```json
{
    "Lua.runtime.version": "Lua 5.1",
    "Lua.workspace.library": [
        "~\\.vscode\\extensions\\ketho.wow-api-0.21.0\\Annotations\\Core"
    ]
}
```

**Note for Claude Code:**
I can read the extension's annotation files to verify specific APIs if needed:
- API definitions: `~/.vscode/extensions/ketho.wow-api-*/Annotations/Core/Blizzard_APIDocumentationGenerated/`
- Deprecated APIs: `~/.vscode/extensions/ketho.wow-api-*/Annotations/Core/FrameXML/Blizzard_Deprecated/`

**Complementary workflow:**
1. **Extension** catches deprecated usage at write-time (strikethrough, warnings)
2. **Manual wiki check** confirms replacement API behavior before implementation
3. **Claude Code** implements migration and runs grep to find all instances
4. **In-game testing** verifies behavior matches expectations

## Task Delegation & Model Selection

When working on GTB, use appropriate models/agents for different task types to optimize token efficiency and response quality.

### LIGHTWEIGHT Tasks → Haiku (via Task tool or model switch)
- **File/code searching**: "Where is X defined", "Find all references to Y", "List all event handlers"
- **Simple summaries**: "What does this function do", "Explain this code block"
- **Documentation writing**: README updates, CHANGELOG entries, simple inline comments
- **Mechanical refactors**: Rename variable across files, consistent formatting, batch similar edits
- **Git operations**: Commit message drafting (after code review), simple git commands
- **Pattern-following config**: Adding checkboxes that follow existing patterns exactly

### STANDARD Tasks → Sonnet (main agent, default)
- **Code implementation**: New modules, feature additions, bug fixes, logic modifications
- **WoW API integration**: Event handlers, protected frames, combat safety, timing-sensitive code
- **Config UI changes**: New sections, layout modifications, tooltip text (requires UX judgment)
- **SavedVariables work**: Schema changes, migration logic, backwards compatibility
- **Debugging**: Error analysis, execution flow tracing, nil-guarding, pcall wrapping
- **Testing verification**: Analyzing test results, identifying root causes
- **User-facing text**: Error messages, feature explanations, tooltip content
- **Third-party analysis**: Understanding other addons' approaches, API patterns

### HEAVY Tasks → Opus (via `/model opusplan` or plan mode)
- **Architecture planning**: Multi-file system redesigns, major refactoring decisions
- **Feature evaluation**: Analyzing feasibility, complexity, and impact of new features
- **Complex problem-solving**: Issues requiring deep reasoning across multiple systems
- **Design decisions**: Choosing between multiple implementation approaches
- **Scope analysis**: Breaking down large features, identifying dependencies

### When to Delegate vs Stay in Main Agent

**Delegate to Haiku when:**
- Task is purely mechanical and well-defined
- No judgment or architecture decisions required
- Batch operations (updating 5+ files identically)
- Simple, isolated information retrieval

**Stay in Sonnet when:**
- Task requires any architectural thinking
- Multiple file changes that interact with each other
- Unclear specifications that need judgment
- Work that builds on previous context in the conversation

**Use Opus when:**
- Planning new features (use plan mode)
- Evaluating complex tradeoffs
- Making decisions that affect core systems
- Situations where you'd normally "stop and think" for a while

### Gray Areas - Use Judgment

**Code exploration** ("How does session tracking work?"):
- Simple flow/summary → Haiku
- Complex multi-file analysis → Sonnet

**Config additions** (adding new checkboxes):
- Obvious pattern duplication → Haiku
- Requires UX/placement judgment → Sonnet

**TOC/manifest updates**:
- Usually faster to just do in main agent than context-switch

**Testing**:
- Pass/fail verification → Haiku
- Debugging failures → Sonnet

**Important**: For GTB's scale (small codebase, clear patterns), only delegate when it provides clear benefit. When in doubt, stay in Sonnet to maintain conversation context and avoid overhead.

## Tech Stack

- Lua 5.1 (WoW embedded interpreter)
- WoW API (Midnight / 12.0+)
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
4. Restore or reset session:
   - `LoadSessionState()` checks persistence setting and `isReloading` flag
   - If persistence ON: always restore
   - If persistence OFF: restore only on reload (flag set by `ReloadUI()` hook), reset on full logout
   - Falls back to `ResetSession()` if restore fails
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

### SavedVariables Architecture (Implementation Details)

**CRITICAL: GTB is live with users - treat SavedVariables as an external contract.**

**Core Pattern (Core.lua:214-231):**
```lua
-- CopyDefaults: Recursive merge that only fills nil keys
function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = CopyDefaults(v, dst[k])
        elseif dst[k] == nil then  -- ← Never overwrites existing values
            dst[k] = v
        end
    end
end

-- GetDB: One-line initialization
function addon:GetDB()
    GoblinToolboxDB = CopyDefaults(DEFAULTS, GoblinToolboxDB or {})
    return GoblinToolboxDB
end
```

**Migration Philosophy (Core.lua:264+):**
- Each migration checks `if currentSchema < N` (idempotent, ordered, never re-runs)
- Migrations run sequentially: v0→v1→v2→v3→v4→v5
- Update `global.schemaVersion` at end of each step
- Never delete old keys during migration (deprecate first, remove in later schema)
- Test requirement: v4 profile → v5 must load without errors (see Testing Checklist)

**Data Separation Principles:**
- **Profile-specific**: UI content, element toggles, tracked items, frame positions
- **Character-specific**: Session state, bank caches, auction data, notes (in `characters[charKey]`)
- **Account-wide**: Visual preferences, technical settings (in `global`)
- **Runtime-only**: Volatile state in `addon.state`, never saved

**Stable Internal Keys:**
- Use machine-readable keys in SavedVariables: `utilityButtons.resetInstances`
- UI labels can change freely: "Reset Instances" displayed to user
- Example: Config checkbox label "Reset Instances" maps to `db.utilityButtons.resetInstances`

**Known Gap: No Explicit Validation/Sanitization**
GTB currently has no validation pass after CopyDefaults + migrations. If adding:
- Clamp numeric ranges: `scale` (0.5-2.0), `fontSize` (8-24), `backgroundOpacity` (0.0-1.0)
- Coerce booleans: `if type(db.enabled) ~= "boolean" then db.enabled = true end`
- Repair invalid enums: `if db.goldViewMode ~= "simple" and db.goldViewMode ~= "detailed" then db.goldViewMode = "simple" end`
- Location: Add validation function called after `MigrateSavedVariables()` in `GoblinToolbox.lua:PLAYER_LOGIN`

**Nil-Guard Discipline:**
Throughout codebase, always guard against missing data:
```lua
local value = db.setting or defaultValue  -- Never assume db.setting exists
local count = cache[itemKey] or 0         -- Never assume cache entry exists
if not charCache then return end          -- Early return on missing tables
```

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
- Session state always saved on logout/reload.
- Reload detection via `ReloadUI()` hook: sets `db.global.isReloading = true` flag.
- On PLAYER_LOGIN, flag is checked then cleared.
- **Persistence ON**: Session restores on both `/reload` and full logout.
- **Persistence OFF**: Session restores on `/reload` only; resets on full logout.
- Offline time treated as paused time when session is restored.
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

## Future Enhancements

**Post v1.0.0 priorities**:
- Auctionator / Oribos Exchange price source support
- Profile import/export functionality

## Slash Commands

- `/gtb` - Opens config panel
- `/gtb add [link]` - Add spell/toy/mount/pet/profession to utility bar, or item/currency to tracker
- `/gtb reset` - Reset session
- `/gtb pause` - Pause/resume session
- `/gtb lock` / `/gtb unlock` - Lock/unlock frame positions
- `/gtb show` / `/gtb hide` - Show/hide HUD
- `/gtb headers` - Toggle group headers

**Hidden debug commands (not shown in help):**
- `/gtb debugtransfers` - Toggles bank transfer debug logging
- `/gtb sessiondebug` - Prints persisted + live session state

## Change Impact Considerations (CRITICAL - Addon is Live)

**The addon is now publicly released with active users. Every change must be evaluated for impact on existing installations.**

Before implementing ANY change, consider:

### Profile & Settings Impact
- **Will this change break existing profiles?** Ensure saved variable schema changes are backwards compatible
- **Will existing settings migrate correctly?** If changing setting structure, add migration logic
- **Will default value changes affect existing users?** Use `CopyDefaults()` pattern to preserve existing values
- **Does this require a schema version bump?** Update `global.schemaVersion` and add migration in `GetDB()`

### User Experience Impact
- **Will this disrupt existing workflows?** Consider if behavior changes will confuse users who are accustomed to current behavior
- **Will frame positions be preserved?** Changes to frame layout/sizing should preserve existing saved positions
- **Will tracked items/currencies persist?** Don't accidentally clear user's tracked item lists
- **Will session data survive?** Ensure session tracking state survives the change

### Data Preservation
- **Character-specific data**: Cached gold, auction data, bank scans (in `characters` table)
- **Profile-specific data**: Module toggles, tracked items, frame positions (in `profiles` table)
- **Account-wide data**: Warband caches, global settings (in `global` table)
- **Guild data**: Guild bank caches (in `guilds` table)

### Testing Requirements
After implementing changes affecting saved data:
1. Test with existing profile → ensure old data still works
2. Test with new profile → ensure defaults work
3. Test `/reload` → ensure settings persist
4. Test logout/login → ensure session persistence settings honored
5. If schema changes: test migration from previous version

**When in doubt, prefer additive changes over destructive ones. Add new fields instead of replacing existing ones.**

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

### Development Workflow (CRITICAL - READ FIRST)

**NEVER commit or push changes without user approval after testing.**

Standard workflow for ANY code changes:

1. **Make the code changes** - Edit files as requested
2. **Wait for user to test** - User will `/reload` and verify changes work correctly in-game
3. **User provides feedback** - User will report if changes work or need adjustment
4. **Only after user approval** - Proceed to commit and push

**DO NOT**:
- Automatically commit after making changes
- Push to git without explicit user instruction
- Create tags without user confirmation that testing passed
- Skip the testing step - user MUST test first

### Release Workflow (After Testing Approved)

When the user explicitly says "push and commit to git" or "commit this as vX.Y.Z" AFTER testing, you MUST:

1. **Update CHANGELOG.md**
   - Add or update the version section with Added/Changed/Fixed/Technical entries
   - Use Keep a Changelog format with proper subsections
   - Ensure no placeholder text like "... (rest of file remains unchanged)"
   - Verify all previous versions are documented (no gaps in version history)
   - If backfilling missing versions, reconstruct from git history and Current Development status.txt

2. **Update README.md**
   - **Version badge**: Update `![Version](https://img.shields.io/badge/Version-X.Y.Z-green)` to current version
   - **Feature descriptions**: Add/update sections for new features in the "Features" section
   - **Known Issues**: Remove fixed bugs, add new ones if applicable
   - **Roadmap/Recent Updates**: Move completed items from "Future Planned Features" to "Recent Updates"
   - **Verify accuracy**: All features in "Features" section match actual implementation
   - **Verify completeness**: Cross-check against Current Development status.txt for missing features

3. **Update version references in all files**
   - `GoblinToolbox.toc` (Line 5: `## Version: X.Y.Z`)
   - `CLAUDE.md` (Line 5: "currently at **vX.Y.Z**")
   - `README.md` version badge (as noted in step 2)

4. **Cross-check against Current Development status.txt**
   - Verify all COMPLETE features have corresponding documentation in README.md
   - Don't document IGNORE/OUT OF SCOPE items as if they're implemented
   - Update any references to feature priorities if they've changed since last release
   - Ensure "Known Issues" in README matches current MINOR/INCOMPLETE bugs

5. **If working in Cursor: Verify AGENTS.md synchronization**
   - Check if any constraint changes in CLAUDE.md need to be reflected in AGENTS.md
   - Keep tooltip standards in sync between both files
   - AGENTS.md should remain a lightweight reference that defers to CLAUDE.md for full workflow

6. **Commit changes** - Stage all modified files with descriptive message following conventional commit format

7. **Push and tag** - `git push origin main && git tag vX.Y.Z && git push origin vX.Y.Z`

CurseForge automatically packages and publishes tagged commits via GitHub integration. No manual upload required.

**Pre-Commit Documentation Checklist:**
- [ ] CHANGELOG.md has entry for this version with all changes documented
- [ ] CHANGELOG.md has no placeholder text or gaps in version history
- [ ] README.md version badge updated to current version
- [ ] README.md feature descriptions match implemented features
- [ ] README.md "Known Issues" section is current and accurate
- [ ] README.md "Roadmap" section updated (completed items moved out)
- [ ] All version references updated (TOC, CLAUDE.md, README.md)
- [ ] Current Development status.txt cross-checked for feature accuracy
- [ ] AGENTS.md synchronized if constraints or standards changed
- [ ] No references to unimplemented features or outdated version numbers

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
- [ ] **Legacy profile defaults regression test** (critical for addon updates):
  - [ ] Load addon with a profile created in previous version (or manually remove a newly-added key from SavedVariables)
  - [ ] Open `/gtb` and verify newly added toggles show their intended default state (OFF = unchecked, ON = checked)
  - [ ] Toggle an unrelated setting (e.g., "AFK auto-pause") and Apply
  - [ ] Verify the new toggle did NOT flip state or get persisted unexpectedly
  - [ ] This test prevents "nil defaults to ON" regressions where old profiles missing new keys show wrong UI state
