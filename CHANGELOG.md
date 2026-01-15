# Changelog

All notable changes to Goblin Toolbox will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

... (rest of file remains unchanged)
