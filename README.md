  # Goblin Toolbox

  A lightweight, modular gold-making HUD addon for World of Warcraft (Retail).

  ![WoW Version](https://img.shields.io/badge/WoW-12.0%2B-blue)
  ![Version](https://img.shields.io/badge/Version-1.0.0-green)
  ![License](https://img.shields.io/badge/License-GPL--3.0-blue)

  ## Overview

  Goblin Toolbox provides gold-maers in retail WoW with at-a-glance information about their gold, inventory, and common utility actions. It aims to be lightweight, modular, and visually integrated with Blizzard's default UI.

  With WeakAuras support being removed in the Midnight expansion, Goblin Toolbox consolidates many small quality-of-life gold tracking functions into a single, clean HUD.

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

  **CurseForge (Recommended):**
  - Install via [CurseForge](https://www.curseforge.com/wow/addons/goblintoolbox) app or download directly

  **Manual Installation:**
  1. Download the latest release from [GitHub Releases](https://github.com/Wooraah-addon/GoblinToolbox/releases) or [CurseForge](https://www.curseforge.com/wow/addons/goblintoolbox)
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

  - World of Warcraft: Midnight (12.0) or later
  - No required dependencies
  - Optional: TradeSkillMaster for advanced price data

  ## Roadmap

  **Recent Updates:**
  - ✅ Posted auctions tracking (v0.5.2)
  - ✅ Looted item value tracking with GPH (v0.5.2)
  - ✅ Session persistence on logout (v0.5.2)
  - ✅ Account label display (v0.6.0)
  - ✅ HUD tooltips for all major elements (v0.6.0)
  - ✅ Rank-aware item tracker with value overlay (v0.5.1)
  - ✅ Token price trend detection (v0.5.2)

  **Future Planned Features:**
  - Auctionator/Oribos Exchange price source support
  - Additional utility bar customizations
  - The option to Auto-pause session on AFK
  - Configuration defaults for different use cases e.g. "Essentials", "Farmer", "Flipper"
  - Saving of GoblinToolbox profiles (inlcuding import/export and character specific profiles rather than current account wide config)
  - XP Tracking functionality

  ## Currently Out of Scope

  The following features have been **deferred or explicitly excluded** from active development:

  ### Profession Features (Paused)

  Various Profession Related Features have been proposed, but are currently deferred, as:
  1) Professions and crafting are neither my area of expertise or my passion
  2) Support for professions across multiple expanions is complex
  3) Professions status is very much in flux for Midnight at the time of writing
  4) Dedicated addons that are better placed (and probably better coded) should emerge to serve these needs.
  5) Limiting the functionality of Goblin Toolbox should allow it to remain relatively lightweight, foccused on gold tracking, and "at-a-glance", complementing rather than replacing dedicated addons for things like crafting, concentration, profession treasures and cooldowns etc.
     
Therefore the following proposed features are currently on hold/deffered or out of scope

  - **Profession concentration tracking**:  
    - Concentration values are character-specific and would require significant UI space
    - Most concentration tracking is better handled by dedicated profession addons
    - May be reconsidered if a compact, elegant implementation is found

  - **Profession skill level display**: Not currently planned
    - Already well-covered by Blizzard's default profession UI
    - Limited value for gold-making compared to other metrics
   
  ### Faster Looting
    -  Fast Looting: Not included to avoid conflicts with the many excellent addons that already handle this (SpeedyAutoLoot, FasterLoot, Leatrix Plus, etc.). GTB seeks to complement these addons rather than duplicating them.
  
   
  ### Non English Language Support
   - No plans currently in place for non English client support

  ### Support for other versions of WoW
   - No plans to support other wow versions (Classic, Remix etc)

  ### Detaled Sales Ledgers
  - **Detailed sales history**: While a "Sales tracker" is in the roadmap, comprehensive sales analytics are intentionally limited
    - Full sales tracking with history, trends, and analytics overlaps with that of better placed addons such as TSM and Journalator     
    - Goblin Toolbox focuses on *session-based* and *real-time* information rather than long-term analytics 

  ### Features Explicitly Out of Scope
  - **Auction House management**: TSM, Auctionator, and other dedicated AH addons handle this comprehensively
  - **Crafting queues and materials tracking**: Better served by profession-focused addons
  - **Mail management beyond quick access**: Use dedicated mail addons for bulk operations
  - **Inventory management**: GTB tracks value and counts, not organization/sorting

  ## Known Issues

  - Shard ID may show "Unknown" until you interact with an NPC (by design - detection requires NPC GUID)    
  - Guild bank gold requires visiting the guild bank to update (cached afterward)
  - Posted auctions only update when AH window is opened (Blizzard API limitation)
  - Although the menu option exists for support of custom TSM prices, the functionality is not yet working

  ## Feedback & suggestions

  Contributions are welcome! If you have feature requests or bug reports, please leave a comment on the CurseForge project page.

  **Development:**
  - Development of this addon was was assisted greatly by both ChatGPT and Claude Code for development context and patterns, I'm not a professional coder, so apologies if performance is not optimal, I'm learning as I go.

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

  Thanks to my team of beta testers for their feature suggestions, feedback and bug reports. These include Manthieus, SlickRock, Liqorice, negue, Yohanan, chosen2choose, Amazul Askira, Cirvis, Týýr, Aylin, Goldzen_tv, Quixxan, Bomanski, Kristian, ElonCS, bakoto, Warshal, special thanks also to Indopan for your guidance regarding efficient AI workflows and migration of the project from ChatGPT to Claude Code. 
  
Thanks also to the wider gold making and Addon/Weak Aura development community for your great addons and weakauras both past and present that have helped inspire many of the features included in GoblinToolbox.
