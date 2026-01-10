  # Goblin Toolbox

  A lightweight, modular gold-making HUD addon for World of Warcraft (Retail).

  ![WoW Version](https://img.shields.io/badge/WoW-12.0%2B-blue)
  ![Version](https://img.shields.io/badge/Version-0.6.0-green)
  ![License](https://img.shields.io/badge/License-GPL--3.0-blue)

  ## Overview

  Goblin Toolbox provides gold-focused players ("goblins") with at-a-glance information about their gold, inventory, and common utility actions. It aims to be lightweight, modular, and visually integrated with Blizzard's default UI.

  With WeakAuras support being removed in the Midnight expansion, Goblin Toolbox consolidates many small quality-of-life gold tracking functions into a single, clean HUD.

  ## Recent Updates (v0.6.0)

  - **Account Labels**: Add custom account-wide identifiers (e.g., [WOW1]) next to character names
  - **HUD Tooltips**: Hover tooltips added for Shard ID, Session tracking, Warbank access, and all tracked values
  - **Enhanced Usability**: Clear explanations of features directly in the HUD

  ## Features

  ### Character & Server Module
  - Character name with race and class icons
  - Realm name display
  - **Account Label**: Custom account-wide identifier (e.g., [WOW1]) shown next to your name
  - **Shard ID tracking** with tooltip guidance (for farming coordination and phasing troubleshooting)      
  - **Movement speed display** to 3 decimal places (for testing speed sets)

  ### Gold & Economy Module
  - **Current character gold**
  - **Warband bank gold** total (cached when unavailable)
  - **Guild bank gold** with staleness indicator (shows age of data)
  - **Posted Auctions**: Total value and count of active auctions (updates on AH open/post)
  - **Session tracking** with pause/resume functionality:
    - Time elapsed with pause support
    - Session persistence option (keep data across logouts)
    - Two display modes:
      - **Simple**: Net gold and GPH
      - **Detailed**: Start/current gold, earned/spent breakdown, net gold and GPH
  - **Looted item value tracking**: Tracks estimated value of items looted during session with gold-per-hour calculation
  - **WoW Token price** with trend indicator (compares recent averages)

  ### Inventory Module
  - **Free bag slots** (normal and reagent bags separately)
  - **Bag value calculation**: Total estimated value of all items in bags
    - Uses TSM price sources when available
    - Falls back to vendor sell prices automatically
  - **Warband bank access indicator**: Shows which client has warband bank access when multi-boxing

  ### Tracker Bars
  - **Item Tracker**:
    - Drag items onto the bar to track quantities across bags, player bank, and warband bank
    - Shows item rank for tiered items
    - Optional gold value overlay (uses TSM or vendor prices)
    - Configurable source toggles (inventory/player bank/warband bank)
  - **Currency Tracker**: Track important currencies with `/gtb add`

  ### Utility Bar
  - Quick-access buttons for common actions:
    - Mobile Banking (guild perk)
    - Portable Mailbox (Katy Stampwhistle, MOLL-E, Ohuna Perch)
    - Warband Bank access (Trader's Brutosaur, Vendor mounts)
    - Hearthstone (auto-detects toys like Dalaran HS, Garrison HS)
    - Housing teleport (when available)
    - Optional Logout/Reload buttons

  ### Additional Features
  - **Interactive tooltips**: Hover over HUD elements for detailed explanations
  - **Tooltip ID display**: Optional display of IDs for items, spells, NPCs, currencies, mounts, and icons  
  - **Customizable visibility**: Hide in combat / hide in instances options
  - **Flexible layout**: Fully movable and resizable HUD with background opacity control
  - **Auto-switch to Warband Bank tab** (optional, Blizzard UI only)
  - **Minimal configuration** with sensible defaults

  ## Installation

  1. Download the latest release from [GitHub Releases](https://github.com/Wooraah-addon/GoblinToolbox/releases)
  2. Extract to your `World of Warcraft\_retail_\Interface\AddOns\` folder
  3. Ensure the folder is named `GoblinToolbox`
  4. Restart WoW or `/reload`

  ## Usage

  - Type `/gtb` to open the configuration panel
  - Drag the HUD to position it anywhere on screen
  - Use the lock icon (top-right of HUD) to lock/unlock frame positions
  - Shift+Right-click items on tracker bars to remove them
  - Hover over any HUD element to see a tooltip explanation

  ### Slash Commands

  | Command | Description |
  |---------|-------------|
  | `/gtb` | Open settings panel |
  | `/gtb add [item/currency]` | Add item or currency to tracker |
  | `/gtb reset` | Reset gold session (clears earned/spent/looted totals) |
  | `/gtb pause` | Pause/resume session timer |
  | `/gtb lock` | Lock frame positions |
  | `/gtb unlock` | Unlock frame positions |
  | `/gtb show` | Show HUD |
  | `/gtb hide` | Hide HUD |
  | `/gtb headers` | Toggle section headers on/off |

  ## Optional Integrations

  Goblin Toolbox works standalone but can integrate with:

  - **TradeSkillMaster (TSM)**: Uses TSM price sources for bag value, looted value, and item tracker calculations
    - Supports: dbmarket, dbminbuyout, dbhistorical, dbregionmarketavg, dbregionhistorical, dbregionsaleavg, and custom price sources
    - Automatically falls back to vendor prices when TSM data unavailable
  - **Auctionator / Oribos Exchange**: Future price source support planned

  ## Requirements

  - World of Warcraft: The War Within (12.0) or later
  - No required dependencies
  - Optional: TradeSkillMaster for advanced price data

  ## Roadmap

  See [Current_Development_status.txt](Current_Development_status.txt) for detailed feature status and active development tasks.

  **Recently Completed:**
  - ✅ Posted auctions tracking (v0.5.2)
  - ✅ Looted item value tracking with GPH (v0.5.2)
  - ✅ Session persistence on logout (v0.5.2)
  - ✅ Account label display (v0.6.0)
  - ✅ HUD tooltips for all major elements (v0.6.0)
  - ✅ Rank-aware item tracker with value overlay (v0.5.1)
  - ✅ Token price trend detection (v0.5.2)

  **Planned Features:**
  - Profession concentration tracking (paused)
  - Sales tracker
  - Auctionator/Oribos Exchange price source support
  - Additional utility bar customization

  ## Known Issues

  - Shard ID may show "Unknown" until you interact with an NPC (by design - detection requires NPC GUID)    
  - Guild bank gold requires visiting the guild bank to update (cached afterward)
  - Posted auctions only update when AH window is opened (Blizzard API limitation)

  ## Contributing

  Contributions are welcome! Please feel free to submit issues or pull requests.

  **Development:**
  - See [CLAUDE.md](CLAUDE.md) for development context and patterns
  - Follow existing code style and conventions
  - Test thoroughly before submitting PRs

  ## License

  This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

  This means you are free to:
  - Use, copy, modify, and distribute this addon
  - Fork and create derivative works

  **Requirements:**
  - Distribute under the same GPL-3.0 license
  - Make source code available
  - State any changes you made
  - Include copyright and license notices

  ## Author

  **Wooraah** - [goblintoolbox@gmail.com](mailto:goblintoolbox@gmail.com)

  ## Acknowledgments

  Thanks to my team of beta testers for their invaluable feedback and bug reports.
