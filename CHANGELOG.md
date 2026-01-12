# Changelog

All notable changes to Goblin Toolbox will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.7.0] - 2025-01-12

### Added
- **Position copy functionality**: New profile dialog now includes "Copy frame positions from current profile" checkbox (checked by default)
- **Profile management**: Added "Copy frame positions from:" section to copy positions between existing profiles
- **Admin command**: Added `/gtb wipe` command for complete data wipe (hidden, for testing/troubleshooting)

### Changed
- **Per-profile frame positions**: All frame positions (HUD, Utility, Tracker, Currency) now save per-profile instead of globally
- **TSM price source**: Moved to global scope - no longer affected by profile switching (Migration 5)
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

## [0.3.2] - 2025-01-XX

### Added
- Character & Server module with race/class icons, realm name
- Shard ID detection via combat log monitoring
- Movement speed display with real-time updates
- Gold & Economy module with character, warband, and guild gold tracking
- Session tracking: elapsed time, gold earned, gold per hour
- WoW Token price display with trend indicator (up/down arrows)
- Inventory module with normal and reagent bag slot counts
- Bag value calculation with TSM integration
- Warband bank access indicator
- Item Tracker bar with drag-and-drop support
- Currency Tracker bar
- Utility Bar with secure action buttons
- Mobile Banking, Mailbox, Warband Bank quick access
- Hearthstone button with automatic toy detection
- Dalaran and Garrison Hearthstone buttons
- Tooltip ID display feature (items, spells, NPCs, currencies, etc.)
- Comprehensive options panel via `/gtb` command
- Hide in combat / hide in instances options
- Movable, resizable, lockable HUD frames
- Hardware LED-style drag handles for auxiliary bars

### Notes
- Professions module currently paused pending Midnight API stabilization
- Some features marked incomplete in development status

## [Unreleased]

### Planned
- Profession concentration display
- Profession cooldown reminders
- Sales tracker (AH/Trade/Crafting Orders)
- Cooking fire utility button
- Portable anvil utility button
- Housing teleport button
- Auctionator price source support
- Gold spent tracking (session)
- Extended time period tracking (day/week/month)
