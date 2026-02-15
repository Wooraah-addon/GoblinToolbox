# Changelog

All notable changes to Goblin Toolbox will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.10] - 2026-02-15

### Added
- **Hearthstone bind location**: Hearthstone tooltip on the utility bar now shows "Returns you to [location]", matching Blizzard's native tooltip style
- **Copy Name-Realm to clipboard**: Alt+Click the character name line on the HUD to copy your `Name-Realm` (invite-ready format) to clipboard via a quick popup — press Ctrl+C and it auto-closes

## [1.1.9] - 2026-02-07

### Fixed
- **Custom profession spells**: Profession buttons added to utility bar now work reliably for all professions
  - Leatherworking and Inscription previously failed when clicked (WoW's `/cast` doesn't work for these professions)
  - Now uses `C_TradeSkillUI.OpenTradeSkill()` API for all profession buttons
  - Tested across 7+ professions including Inscription, Blacksmithing, Archaeology, Fishing, Jewelcrafting, Enchanting, Leatherworking
- **Custom utility button errors**: Fixed lua error when custom spells (toys/mounts/pets) triggered cooldown updates
  - Error: "attempt to index local 'def' (a nil value)" in `UpdateUtilityButtonCooldown`
  - Custom slots now correctly skip hearthstone GCD filtering logic
- **Toggle spell double-fire**: Custom profession/racial spells no longer open and immediately close when clicked
  - Cleared stale `typerelease` attribute that caused action on both mouse press and release
  - Affects toggle-style spells that open windows (professions) or have press-and-hold behavior

### Technical
- Rewrote `IsProfessionSpell()` to use spell name matching against `parentProfessionName` from profession API
- Added cleanup of kind-specific button properties (`isProfession`, `professionName`, `mountJournalID`, `petSpeciesID`) when buttons are reused
- Added nil guard for `btn.utilDef` in cooldown update logic for custom slots

## [1.1.8] - 2026-01-29

### Added
- **Hide in groups option**: New visibility toggle to automatically hide HUD when in a party or raid
  - Added checkbox in General settings alongside existing combat/instance hide options
  - Applies to all frames (HUD, tracker bars, currency bar, utility bar)
  - Useful for players who prefer minimal UI during group content

### Changed
- **Session timer precision**: Timer now displays seconds when session duration is under 10 minutes
  - Format: "9m 45s" when under 10 minutes, "42m" when 10+ minutes, "2h 15m" when 1+ hours
  - Helps track short farming sessions more precisely (e.g., timing corpse despawns)
- **Config menu layout**: Reorganized General section for better readability
  - Row 1: Enable HUD (alone)
  - Row 2: Hide in combat, Hide in instances/raids, Hide in groups
  - Row 3: Lock frames, Show load message, Minimap button

### Fixed
- **Gold tracking accuracy**: Removed 100k gold transaction cap that was causing tracking discrepancies
  - Previously, any single transaction over 100k gold was silently excluded from Earned/Spent tracking
  - This caused Net to diverge from Earned-Spent for high-value AH sales (common for gold-makers)
  - All transaction sizes now tracked correctly, regardless of amount
- **Bank transfer matching**: Made transfer intent matching symmetric
  - Now allows delta to be slightly less OR more than intent amount (within 5% tolerance)
  - Fixes edge cases where API timing caused actual gold change to differ slightly from deposit/withdrawal

### Technical
- Registered `GROUP_ROSTER_UPDATE` event to handle visibility updates when joining/leaving groups
- Improved transfer offset tolerance calculation for large warband/guild bank transactions

## [1.1.7] - 2026-01-22

### Fixed
- **Item tracker rank display**: Reagent quality stars now display correctly on tracked items
  - `C_Texture.GetCraftingReagentQualityChatIcon()` does not exist in-game despite wiki documentation
  - Switched to atlas markup format: `|A:Professions-ChatIcon-Quality-Tier{rank}:16:16|a`
  - Rank 1/2/3 quality icons now visible on tiered crafting reagents at all scale settings

## [1.1.6] - 2026-01-22

### Fixed
- **Button removal**: Standard utility buttons now correctly remove themselves instead of custom buttons
  - When buttons were reused from the pool, custom button properties were not cleared
  - Shift+right-clicking standard buttons (e.g., Hearthstone) could incorrectly remove custom buttons
  - Added cleanup of `isCustomSlot`, `customIndex`, `customKind`, `customID` properties when configuring standard buttons

## [1.1.5] - 2026-01-22

### Fixed
- **Custom pet buttons**: Pet availability check now filter-independent
  - Previously, custom pet buttons would grey out if the pet journal had an active search filter
  - Changed from `GetNumPets()`/`GetPetInfoByIndex()` (filter-affected) to `GetOwnedBattlePetString()` (filter-independent)
  - Pet buttons now correctly show as available regardless of pet journal search state
  - Fix persists across `/reload` (previously required logout/login to clear)

## [1.1.4] - 2026-01-22

### Added
- **Custom Utility Slots**: Add your own spells, toys, mounts, and battle pets to the Utility Bar
  - Use `/gtb add [link]` after shift-clicking items from spellbook/toy box/mount journal/pet journal
  - Supports class spells, profession panels, toys, mounts, and battle pets
  - Automatically displays cooldowns for toys and spells
  - Greys out unavailable items with helpful tooltips (e.g., "Mount not collected", "Spell not learned")
  - Remove custom buttons with shift+right-click
  - No limit on number of custom slots (limited only by bar layout space)
  - Config option to hide all custom buttons with a single toggle

### Changed
- **Memory optimization**: Reduced memory usage during combat
  - Throttled cooldown event updates to 3x per second (from ~10x per second)
  - Cached element table references in LayoutHUD to reduce garbage collection
  - Optimized speed ticker to skip unnecessary table creation
  - Combined: ~15-20% reduction in combat memory footprint

### Fixed
- **Secret value handling**: Improved Midnight (12.0+) compatibility
  - Added pcall wrappers to Gold.lua loot message handler
  - Added pcall wrapper to UtilityBar.lua cooldown info access
  - Prevents "attempt to perform operation on secret value" errors in dungeons/instances

### Removed
- **v1.1.0 update notice**: Removed one-time popup notification for v1.1.0 bar layout changes
  - Cleanup of temporary user communication code
  - Prevents StaticPopup frame pollution that could affect other addon dialogs

## [1.1.3] - 2026-01-21

### Fixed
- **Comprehensive secret value handling**: Replaced `InCombatLockdown()` guards with `pcall()` wrappers
  - Secret values can appear outside of combat lockdown, making the lockdown check insufficient
  - All tooltip data processor callbacks now wrapped in pcall
  - Shard ID extraction from UnitGUID now wrapped in pcall
  - Tooltip duplicate ID checks now wrapped in pcall
  - Features gracefully degrade (skip updates) when secret values are encountered

## [1.1.2] - 2026-01-21

### Fixed
- **Tooltip ID duplicate check**: Added `InCombatLockdown()` guard to tooltip text reading
  - `type()` function returns the expected type even for secret values, so type checks don't help
  - Duplicate ID detection now skipped during combat (worst case: duplicate lines, which is harmless)

## [1.1.1] - 2026-01-21

### Fixed
- **Midnight (12.0) compatibility**: Fixed combat errors caused by "secret values" in spell cooldown API
  - `C_Spell.GetSpellCooldown()` returns protected values during combat that cannot be used in boolean tests or comparisons
  - Utility bar cooldown updates now skip reading spell cooldowns during combat to prevent errors
  - Affects: UtilityBar.lua, Core.lua

### Technical
- Added `InCombatLockdown()` guards to `GetSpellCooldown()` API wrappers
  - Returns safe defaults `(0, 0, 1)` during combat instead of reading secret values
  - Cooldown displays update normally when out of combat

## [1.1.0] - 2026-01-20

### Added
- **Minimap button**: Quick access to GTB configuration via minimap icon
  - Uses LibDBIcon-1.0 for maximum compatibility with minimap managers
  - Left-click to open/close menu
  - Right-drag to reposition around minimap rim
  - Toggle visibility via Options panel → General → "Minimap button" checkbox (account-wide setting)
  - Position persists across sessions
- **Per-bar scaling**: Each bar (Item Tracker, Currency Tracker, Utility Bar) now has independent scale control (0.5x to 2.0x)
  - Configurable in Options panel under each bar's section
  - Scale adjustments no longer cause position drift (see Technical section)
- **Buttons per row configuration**: All three bars now support wrapping to multiple rows
  - Item Tracker: 1-20 buttons per row
  - Currency Tracker: 1-20 buttons per row
  - Utility Bar: 1-12 buttons per row
- **Growth direction controls**: Choose how bars expand when adding items
  - Horizontal growth: LEFT or RIGHT
  - Vertical growth: UP or DOWN
  - Four corner anchoring options (e.g., grow right+down from top-left corner)
- **One-time update notice**: Account-wide popup on first login explaining v1.1.0 bar layout changes
  - Includes "Reset Bar Positions" button for easy recovery if bars shifted
  - "Don't show this again" checkbox to permanently dismiss
  - Will be removed in v1.1.1 (temporary notification only)

### Changed
- **Reset All Settings** now properly resets all UI/display settings to defaults
  - Preserves user behavioral preferences: session persistence, AFK auto-pause, TSM source, load message setting, account label
  - Uses deep copy from DEFAULTS table to ensure complete reset
- **Reset Bar Positions**: New dedicated function to reset only bar positions (not HUD)
  - Accessed via Options panel or v1.1.0 update notice popup
  - HUD position remains unchanged when resetting bars

### Fixed
- **Session pause state restoration**: Fixed "Manually Paused" flag appearing incorrectly after logout/reload
  - AFK-paused sessions now auto-resume on login (no longer incorrectly show "Manually Paused")
  - Manually-paused sessions correctly remain paused across logout/reload
  - Root cause: `pausedByAFK` flag now properly saved/restored in session state
- **Bar position persistence**: Scaling a bar no longer causes position drift on reload/logout
  - Bars now remember exact positions regardless of scale changes
  - Growth direction changes no longer shift bar position
- **Empty bar appearance**: Add button (+) on empty bars now properly square (not rectangular)
- **Empty bar dragging**: Fixed drag functionality on empty bars after visual fix

### Technical
- **Midnight (12.0.0) compatibility**: Full support for WoW Midnight launch
  - Migrated to modern C_Item and C_SpellBook namespaced APIs (19 deprecated API call sites replaced)
  - Replaced COMBAT_LOG_EVENT_UNFILTERED shard detection with PLAYER_TARGET_CHANGED and UPDATE_MOUSEOVER_UNIT events (combat log restrictions workaround)
  - Fixed SaveUtilityBarPositionOnLogout nil method error (session persistence now reliable on logout/reload)
  - Graceful degradation for combat log restrictions with pcall wrapper and version gating
  - All deprecated API usage eliminated (addresses community feedback from Larsj_02)
- **Modern API wrappers**: Added centralized addon.API compatibility layer for future-proofing
  - GetItemInfo, GetItemInfoInstant, GetItemCount, GetItemSpell → C_Item namespace
  - IsSpellKnown → C_SpellBook.IsSpellKnown (corrected from non-existent C_Spell.IsSpellKnown)
  - Added GetVendorSellPrice helper to replace select(11, GetItemInfo) patterns
  - No legacy fallbacks (12.0+ only), cleaner codebase
- **Config global leak fix**: Fixed trackersSection undefined variable in Config.lua sections table
- **Library dependencies**: GTB now vendors LibStub, CallbackHandler-1.0, LibDataBroker-1.1, and LibDBIcon-1.0 for minimap button functionality
  - First external dependencies for GTB (chosen for minimap manager compatibility)
  - Packaged via .pkgmeta externals (automatically pulled during CurseForge builds)
  - SavedVariables schema updated: `db.global.minimap = { hide = false, minimapPos = 220 }`
- **Anchor-container architecture**: Implemented separation of position (unscaled anchor frame) from visual rendering (scaled content frame)
  - Anchor frame handles position/movement, never scales
  - Visual content frame handles layout/scaling, always positioned relative to anchor
  - Eliminates coordinate conversion errors that caused position drift
- **Schema version**: Fresh installs now default to schemaVersion 5 (no unnecessary migrations)
- **SavedVariables cleanup**: Improved handling of bar position data with anchor-based storage

## [1.0.7] - 2026-01-18

### Added
- **Menu Lock/Unlock option**: New "Lock frames" checkbox in General settings (mirrors HUD title bar lock icon for better discoverability)
- **Load message toggle**: "Show load message" checkbox to suppress/enable addon loaded chat print (account-wide setting)
- **Utility action confirmations**: Single "Add confirmation step for sensitive actions" toggle for Logout, Reload, and Mailbox buttons
  - Shows StaticPopup-style confirmation dialogs (respects out-of-combat restrictions)
  - Works only when respective buttons are enabled
  - Default OFF to preserve current behavior
- **Currency count centering**: Currency tracker count overlay now centered for consistency with item tracker styling
- **Gold per hour toggle**: New "Show gold per hour values" option to hide /h values without changing other displays
- **Draggable tracker/currency bars**: Click and drag the green + icon on item tracker and currency tracker bars to reposition them
  - Preserves existing click-to-chat and item-drop functionality

### Fixed
- **Warband bank integer overflow**: Removed unsafe %d formatting for copper values in bank transfer debug logs (prevents overflow with large values)
- **Session persistence icon visibility**: Icon now correctly hides when Gold & Economy module is disabled, collapsed, or minimized
- **Child option parent enabling**: Enabling a child option now auto-enables the parent module before applying (fixes "I enabled something but nothing shows" confusion)

### Technical
- Debug logging for bank transfers now uses safe string formatting for all copper values
- Confirmation popups use Blizzard SecureActionButtonTemplate for Logout/Reload (respects combat lockdown)
- Mailbox confirmation uses custom handler for compatibility with secure action buttons

## [1.0.6] - 2026-01-16

### Added
- **Reset Instances button**: New utility bar button for resetting dungeon instances (disabled by default)
  - Requires party leader when grouped
  - Grey overlay when unavailable with tooltip explanation
  - Configurable via Options > Utility Bar

### Fixed
- **Character Note editbox**: Improved text visibility by fixing frame level ordering to ensure editbox renders above background

### Documentation
- Comprehensive release workflow instructions added to CLAUDE.md and AGENTS.md
- README.md features section updated to reflect all v1.0+ capabilities
- CHANGELOG.md backfilled with missing v1.0.0-1.0.3 release history

## [1.0.5] - 2026-01-15

### Added
- **Session Persistence Indicator**: Added a new visual status icon to the HUD's Gold & Economy section
  - Uses a "Swirl" icon (ability_evoker_innatemagic4) to represent session continuity
  - **Bright Green**: Persistence enabled (session survives logout)
  - **Faded Grey**: Persistence disabled (session resets on logout)
  - Features a dedicated tooltip explaining the current persistence state and how to change it

### Fixed
- **HUD Tooltip Rendering**: Replaced unsupported Unicode arrow characters (`→`) with standard signs (`>`) to fix "box" artifact rendering in some locales
- **Session Timer Tooltip**: Expanded the pause button's interactive area to cover the timer text, ensuring the session controls tooltip appears reliably when hovering over the duration
- **Shard ID Tooltip**: Implemented "Smart Tooltip" logic that hides the Shard ID help text when the element is disabled in settings, preventing it from appearing over the movement speed text
- **Tooltip Consistency**: Standardized colors and formatting across all HUD and Bar tooltips using GTB's gold/grey/silver palette

### Technical
- Updated `.pkgmeta` and `.gitignore` to strictly exclude internal AI configuration (`.cursor/`, `AGENTS.md`) and technical design documentation (`DesignDoc.txt`) from CurseForge distribution and public repository history

## [1.0.4] - 2026-01-13

### Changed
- **Header button sizes**: Increased lock and minimize button sizes by 30% for better visibility
  - Lock button: 20px → 26px
  - Minimize button: 16px → 26px (now matches lock button size)
  - Addresses user feedback about buttons being too small and easy to miss
- **Guild bank clarity**: Changed "Visit" to "Visit GBank" to match the "GBank:" label added in v1.0.2

## [1.0.3] - 2026-01-12

### Added
- **Shift+Right-click removal**: Utility bar buttons can now be removed by Shift+Right-clicking them
- **Housing Teleport button**: New utility bar button for quick housing teleport (disabled by default)
- **Logout/Reload buttons**: Optional utility bar buttons for quick logout and UI reload (disabled by default)

### Fixed
- **Item tracker bar visibility**: Fixed issue where tracker bar wouldn't hide when HUD was disabled
- **Combat UI updates**: Improved combat safety checks to prevent taint issues
- **Hearthstone detection**: Fixed hearthstone button not working when physical hearthstone is in bags

## [1.0.2] - 2026-01-11

### Changed
- **Guild bank label**: Updated guild bank display from "Guild:" to "GBank:" for consistency
- **Unavailable button overlay**: Added grey desaturation overlay to utility buttons when not usable
- **Tooltip improvements**: Added explanatory tooltips to unavailable utility buttons

## [1.0.1] - 2026-01-10

### Fixed
- **Session tracking**: Fixed session reset on logout when persistence was enabled
- **Posted auctions**: Corrected commodity item value calculation (now properly multiplies by quantity)
- **Minor UI adjustments**: Improved spacing and alignment in HUD sections

## [1.0.0] - 2026-01-09

### Added
- **Initial public release**
- **Profile system**: Create, copy, and switch between named profiles per character
- **Character notes**: Per-character note field for labeling alts (up to 500 characters)
- **Session persistence**: Optional session data persistence across logouts with visual indicator
- **AFK auto-pause**: Automatic session pause when player goes AFK
- **Bank transfer neutralization**: Deposits/withdrawals to guild/warband banks don't affect session net
- **Multi-source item tracking**: Track items across inventory, player bank, and warband bank
- **Rank-aware tracking**: Separate tracking for tiered reagent ranks
- **Grey overlay system**: Visual feedback for unavailable utility buttons
- **Interactive tooltips**: Comprehensive tooltip system across all HUD elements
- **Account label**: Custom account-wide identifier display
- **Token trend detection**: Visual indicator for WoW Token price trends

### Technical
- Schema version 5 with migration system for saved variables
- Event-driven architecture with debounced UI updates
- Combat-safe frame management with taint prevention
- Modular codebase with clear separation of concerns
