# Changelog

All notable changes to Goblin Toolbox will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.4] - 2026-01-13

### Changed
- **Header button sizes**: Increased lock and minimize button sizes by 30% for better visibility
  - Lock button: 20px → 26px
  - Minimize button: 16px → 26px (now matches lock button size)
  - Addresses user feedback about buttons being too small and easy to miss
- **Guild bank clarity**: Changed "Visit" to "Visit GBank" to match the "GBank:" label added in v1.0.2

## [1.0.3] - 2026-01-13

### Fixed
- **HUD tooltip visibility**: Fixed tooltips displaying when HUD is minimized - all section tooltips now properly hidden when minimized

### Changed
- **Session pause indicators**: Improved clarity of pause state display
  - Manual pause: Now shows "Manually Paused" in red before hourglass icon
  - AFK auto-pause: Changed from "Paused AFK" to "Auto-Paused - AFK" in red
  - Chat messages now say "auto-paused" and "auto-resumed" for consistency
- **Profile change feedback**: Added visual flash indicator to profile dropdown when switching/copying profiles
  - Dropdown text pulses green 3 times to make profile changes more obvious
  - Helps prevent confusion when profiles auto-switch after copying

## [1.0.2] - 2026-01-13

### Changed
- **HUD label clarity**: Changed "Guild:" to "GBank:" to clarify it refers to guild bank gold
- **Utility Bar tooltips**: Added informative tooltips to Mailbox, AH Mount, Vendor Mount, and Hearthstone options explaining prioritization logic

## [1.0.1] - 2026-01-13

### Fixed
- **Tracker bar anchoring**: Fixed item/currency tracker bars shifting position when adding/removing items
  - Bars now anchor from their left edge (+ button) and only expand rightward
  - Re-anchor logic applied before every resize to maintain fixed position
  - Drag handlers now immediately convert position to TOPLEFT anchor for consistency
- **Tracker bar height**: Fixed vertical position shift when adding first item
  - Empty bars now use same height as populated bars (consistent padding)
  - Prevents frame from jumping vertically when transitioning between empty/populated states

## [1.0.0] - 2026-01-13

### Added
- **CurseForge distribution**: Addon now available on CurseForge with automatic packaging from GitHub tags

### Changed
- **HUD refresh optimization**: Implemented coalesced refresh scheduler to reduce UI churn during event storms
  - Event-driven updates (money changes, bag updates, AH activity) now debounce with 0.3s delay
  - User actions (button clicks, toggles, resizing) remain instant for responsive feedback
  - Significantly reduces layout passes during mass auction posting and rapid looting
- **Release workflow**: Streamlined release process with CurseForge GitHub integration

### Removed
- Removed unused `addon:Debug()` function (dead code cleanup)

### Notes
- First stable public release
- All core features complete and tested
- Ready for general use

## [0.7.2] - 2026-01-12

### Added
- **AFK auto-pause**: Session timer automatically pauses when you go AFK and resumes when you return
  - Enabled by default as account-wide setting
  - Displays "Paused AFK" indicator in red next to hourglass icon during AFK pause
  - Chat messages: "Session paused - AFK" and "Session resumed - No longer AFK"
  - Works with both manual `/afk` command and automatic AFK detection
  - Independent of manual pause - manual pause remains active after clearing AFK
- **Clear Note button**: Added "Clear Note" button next to "Save Note" in Character section for quick note removal

### Fixed
- **Utility Bar scale**: Fixed bug where Utility Bar would reset to scale 1.0 on `/reload` when custom UI scale was set
  - Utility Bar, Tracker Bar, and Currency Bar now correctly apply saved scale on startup
- **Hearthstone cooldown display**: Fixed spurious GCD cooldown animations appearing on hearthstone icons during combat
  - Filtered out short cooldowns (<3s) for hearthstone items during combat to eliminate GCD artifacts

### Technical
- Added `ApplyScale()` call during PLAYER_LOGIN initialization to ensure all frames receive saved scale
- Added `afkAutoPause` to global settings (default: true)
- Implemented `PLAYER_FLAGS_CHANGED` event handler for AFK detection
- Added `pausedByAFK` state flag (runtime only, not persisted)
- AFK pause state automatically cleared on session restore

## [0.7.1] - 2026-01-12

### Added
- **Character Notes**: Per-character note field with multi-line input
  - 500 character limit with real-time counter (gray/yellow/red color coding)
  - Notes display in pale blue at bottom of Character section
  - "Save Note" button with confirmation message
  - Proper text padding and scrolling for clean rendering
  - Hover tooltip explaining note functionality
- **Section header tooltips**: Added informative tooltips to Item Tracker Bar, Currency Tracker Bar, and Tooltip IDs sections

### Changed
- **Session persistence behavior**: Improved reload detection using ReloadUI() hook
  - With persistence OFF: Session now continues on `/reload` but resets on full logout
  - With persistence ON: Session continues on both `/reload` and logout (unchanged)
  - Updated tooltip to explain new behavior
- **Config menu UI**: Removed +/- collapse icons from section headers
  - All sections now always visible (cleaner, simpler interface)
  - Section headers remain with hover effects
- **Character section**: Expanded to 3 lines to accommodate character note display

### Fixed
- Multi-line text input rendering with proper padding and scroll support
- Character note text box now displays cleanly without text bleeding

### Technical
- Added `COLORS.NOTE_TEXT` constant for consistent note styling
- Implemented deterministic reload detection via `ReloadUI()` hook and `isReloading` flag
- Session state always saved for reliable reload detection
- Updated documentation in CLAUDE.md

## [0.7.0] - 2026-01-12

### Added
- **Multi-profile system**: Complete profile management framework with creation, switching, copying, renaming, and deletion
  - Profile creation dialog with name input and position copy checkbox (checked by default)
  - Profile switching via dropdown menu with instant apply
  - Copy frame positions between existing profiles
  - Rename and delete profile functionality with safety confirmations
  - Profile presets: Default, Minimal, Market, and Gather configurations
  - Per-profile storage for content settings (modules, elements, tracked items/currencies)
  - Per-profile frame positions (HUD, Utility Bar, Tracker Bar, Currency Bar)
- **Admin command**: Added `/gtb wipe` command for complete data wipe (hidden, for testing/troubleshooting)

### Changed
- **Architecture**: Migrated from single-profile to multi-profile SavedVariables structure (Migration 5)
- **TSM price source**: Moved to global scope - no longer affected by profile switching
- **Default visibility**: "Hide in combat" and "Hide in instances/raids" now OFF by default for new installations
- **UI layout optimization**:
  - General section: Condensed 3 checkboxes onto single horizontal line
  - Appearance Settings: Condensed 3 checkboxes onto single horizontal line, renamed from "Appearance"
  - Added account-wide tooltip to Appearance Settings section header
  - Changed label "Hide in instances / raids" to "Hide in instances/raids"
  - Changed label "Show group headers" to "Show headers"
- **Frame positioning behavior**: Removed auto-snapping from all bars - each bar now uses fixed, independent default positions
- **Default positions**: Adjusted to prevent overlapping (Utility: -420, Tracker: -475, Currency: -530)

### Fixed
- **Session tracking**: Now properly persists and continues across profile switches and new profile creation
- **Position inheritance**: Presets no longer interfere with frame positioning - positions copy independently
- **Bar overlap issue**: Fixed utility/tracker bars moving when HUD height changes

## [0.6.3] - 2026-01-11

### Added
- **Bank transfer exclusion system**: Guild and warband bank deposits/withdrawals no longer affect session gold tracking
  - Uses intent hooks on C_Bank API for accurate transfer detection
  - Transfer offset tracked separately and excluded from Net/Earned/Spent calculations
- **Session gold color coding**: Earned and gold/hr values now show green (positive) or red (negative)
- **Debug commands**: Added `/gtb debugtransfers` and `/gtb sessiondebug` for troubleshooting
- **TSM tooltip**: Added informative tooltip to custom TSM price string field

### Fixed
- **Utility Bar modifier click**: Fixed buttons triggering on Shift+Right-click when removing items
  - Added combat lockdown check for removal safety
- **Session persistence**: Character key now cached at login (realm unavailable during logout)
  - Session data now properly persists across logout/login

## [0.6.2] - 2026-01-10

### Fixed
- **Commodity auction values**: Posted auction total value now calculated correctly for commodity items
  - Blizzard API returns unit price for commodities, not total stack price
  - Now correctly multiplies price by quantity for commodities (e.g., 100 ore at 50g each = 5,000g)
  - Added IsCommodity() helper with itemID caching for performance
  - Equipment auctions continue to use price only (unchanged)

## [0.6.1] - 2026-01-10

### Fixed
- **Posted auction data**: Now properly cached per-character instead of shared across characters
  - Posted auction totals were being stored in db.profile (shared), causing Character 2's data to overwrite Character 1's
  - Now correctly stores in db.characters[key] for character-specific tracking
  - Each character maintains independent posted auction counts and values

## [0.6.0] - 2026-01-10

### Added
- **Account Label**: Optional account-wide label displayed next to character name
  - Configurable in Character options with 16 character limit
  - Stored globally, displayed when enabled per-character
  - Shows as [LABEL] next to name-realm on same line
- **HUD Tooltips**: Added informative tooltips for key elements
  - Shard ID: Explains sharding with NPC targeting hint
  - Session Header: Details pause/resume, tracking behavior, persistence options
  - Warbank Access: Explains multi-client access indicator
  - Posted Auctions: Auction tracking details and update frequency
  - Earned/Looted/Bag Value: Price source info with vendor fallback notes

### Changed
- **Character section restructure**: Account label on line 1, Shard/Speed on line 2
- **Config menu**: Added account label input box with trim/validation

### Fixed
- Fixed Config.lua error with account label positioning
- Fixed Character module line number references

## [0.5.2] - 2026-01-09

### Added
- **Session persistence**: Session data now reliably persists across logout/reload
  - Added PLAYER_LEAVING_WORLD event handler for reliable saves
  - Added periodic backup saves (every 60 seconds)
  - Session data is character-specific
- **Gold tracking view modes**: Simple/Detailed view toggle in options
  - Detailed view shows Start/Current gold and Earned/Spent breakdown
  - Clock icon replaces "Session" text (green=running, red=paused)
- **Token tooltip**: Added tooltip explaining WoW Token trend calculation

### Changed
- **Token trend sensitivity**: Reduced threshold from 10,000g to 2,500g for more responsive arrows
- **Grammar**: Changed "Earnt" to "Earned" for consistency

### Fixed
- Fixed combat taint error (EnableMouse on secure frames)
- Fixed pause time calculation not accounting for previous pauses
- Added guards against GetMoney() race conditions during login

## [0.5.1] - 2026-01-08

### Added
- **Rank-aware item tracking**: Track items by rank (e.g., Bismuth Rank 1, 2, 3 as separate entries)
  - Display rank diamond overlay (top-left) using Blizzard APIs
  - Show item count with abbreviation (1.2k, 12.3k, 1.23m)
  - Optional gold value display (bottom) with TSM integration
  - Drag & drop auto-detects item rank from link
  - Support for both ranked and unranked items

### Changed
- **Item count positioning**: Repositioned to center of icon to avoid rank overlap
- **Value display**: Added gold/silver icons with tight spacing
- **Frame strata**: Set tracker/currency/utility bars to MEDIUM strata
- **Drag handle z-order**: Raised frame level to appear above Blizzard action bars

### Fixed
- Fixed position reset on character login (only reset on true first run)
- Fixed drag handle clickability when behind Blizzard action bars
- Fixed combat taint error with frame visibility toggling
- Fixed add button drag-and-drop for item tracking

## [0.4.1] - 2026-01-06

### Added
- **Reload button**: Added to utility bar (disabled by default)
- **Reload UI button**: Added to config menu bottom for convenience
- **Background opacity slider**: Control HUD background opacity (0-100%)
- **Tooltips**: Added to settings cogwheel and 9+ menu options

### Changed
- **Movement speed precision**: Now shows 3 decimal places for accuracy
- **Slider layout**: Reorganized to inline layout for compact menu
- **Instance hiding tooltip**: Updated to mention delves

### Fixed
- Fixed tracker bars not respecting "Enable HUD" setting
- Fixed tracker bars not hiding in combat/instances when hide options enabled

### Removed
- Removed non-functional Tooltip ID options (Achievement, Quest, Talent)

## [0.4.0] - 2026-01-05

### Added
- **Utility Bar expansion**: New mount and teleport buttons
  - AH/Vendor mount support (Brutosaur, Packmaster, Yak, Mammoth)
  - Housing Teleport button with cooldown display
  - Logout button (disabled by default)
  - Mount buttons now use Mount Journal API for locale-safe operation

### Fixed
- Fixed hearthstone icon not working when physical hearthstone in bags
- Fixed ADDON_ACTION_BLOCKED error during combat/instance entry
- Improved combat lockdown handling for secure frames

### Technical
- Housing teleport uses async event pattern for reliability

## [0.3.3] - 2025-12-21

### Fixed
- **Gold module**: Added nil guard for addon.db in Gold:Update() to prevent crash during initialization
- **Session pause**: Now correctly freezes gold tracking - uses gold snapshot when paused
- **Session resume**: Baseline adjusts on resume to exclude gold changes during pause
- **Combat taint**: Added SafeLayoutHUD wrapper to prevent ADDON_ACTION_BLOCKED taint errors
  - Deferred layout updates when in combat, applied after PLAYER_REGEN_ENABLED
- **Drag handle hitbox**: Reduced from 22x22 to 14x14 pixels to prevent tooltip obstruction
- **Mobile Banking availability**: Corrected guild reputation check using C_Reputation API instead of incorrect GetGuildInfo usage

## [0.3.2] - 2025-12-19

### Added
- **Character & Server module**: Race/class icons, realm name, shard ID detection via combat log monitoring, movement speed display with real-time updates
- **Gold & Economy module**: Character, warband, and guild gold tracking
  - Session tracking: elapsed time, gold earned, gold per hour
  - WoW Token price display with trend indicator (up/down arrows)
  - Posted auctions tracking with TSM integration
- **Inventory module**: Normal and reagent bag slot counts, bag value calculation with TSM integration, warband bank access indicator
- **Item Tracker bar**: Drag-and-drop support for tracking items across characters
- **Currency Tracker bar**: Track multiple currencies with icon display
- **Utility Bar**: Secure action buttons for quick access
  - Mobile Banking, Mailbox, Warband Bank
  - Hearthstone button with automatic toy detection
  - Dalaran and Garrison Hearthstone buttons
- **Tooltip ID display**: Show IDs for items, spells, NPCs, currencies, etc.
- **Options panel**: Comprehensive configuration via `/gtb` command
  - Hide in combat / hide in instances options
  - Module and element toggles
  - TSM price source configuration
- **Movable frames**: HUD and auxiliary bars with hardware LED-style drag handles
- **Frame controls**: Resizable, lockable HUD frames

### Notes
- Initial public release
- Professions module currently paused pending Midnight API stabilization

## [Unreleased]

### Planned
- Profession concentration display
- Profession cooldown reminders
- Sales tracker (AH/Trade/Crafting Orders)
- Cooking fire utility button
- Portable anvil utility button
- Auctionator price source support
- Extended time period tracking (day/week/month)
