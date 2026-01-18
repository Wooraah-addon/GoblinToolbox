# Changelog

All notable changes to Goblin Toolbox will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
