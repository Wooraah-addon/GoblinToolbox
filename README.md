# Goblin Toolbox

A lightweight, modular gold-making HUD addon for World of Warcraft (Retail).

![WoW Version](https://img.shields.io/badge/WoW-12.0%2B-blue)
![License](https://img.shields.io/badge/License-GPL--3.0-blue)

## Overview

Goblin Toolbox provides gold-focused players ("goblins") with at-a-glance information about their gold, inventory, and common utility actions. It aims to be lightweight, modular, and visually integrated with Blizzard's default UI.

With WeakAuras support being removed in the Midnight expansion, Goblin Toolbox consolidates many small quality-of-life gold tracking functions into a single, clean HUD.

## Features

### Character & Server Module
- Character name with race and class icons
- Realm name display
- Shard ID tracking (for farming coordination)
- Movement speed display (for speed sets)

### Gold & Economy Module
- Current character gold
- Warband bank gold total
- Guild bank gold (with staleness indicator)
- Session tracking: time elapsed, gold earned, gold per hour
- WoW Token price with trend indicator

### Inventory Module
- Free bag slots (normal and reagent bags)
- Bag value calculation (TSM integration or vendor prices)
- Warband bank access indicator

### Tracker Bars
- **Item Tracker**: Drag items onto the bar to track quantities
- **Currency Tracker**: Track important currencies with `/gtb add`

### Utility Bar
- Quick-access buttons for common actions:
  - Mobile Banking (guild perk)
  - Portable Mailbox (Katy Stampwhistle, MOLL-E, etc.)
  - Warband Bank access
  - Hearthstone (auto-detects toys)
  - Dalaran Hearthstone
  - Garrison Hearthstone

### Additional Features
- Tooltip ID display (items, spells, NPCs, currencies, etc.)
- Hide in combat / hide in instances options
- Fully movable and resizable HUD
- Minimal configuration surface

## Installation

1. Download the latest release
2. Extract to your `World of Warcraft\_retail_\Interface\AddOns\` folder
3. Ensure the folder is named `GoblinToolbox`
4. Restart WoW or `/reload`

## Usage

- Type `/gtb` to open the configuration panel
- Drag the HUD to position it
- Use the lock icon to lock/unlock frame positions
- Shift+Right-click items on tracker bars to remove them

### Slash Commands

| Command | Description |
|---------|-------------|
| `/gtb` | Open settings panel |
| `/gtb add [item/currency]` | Add item or currency to tracker |
| `/gtb reset` | Reset gold session |
| `/gtb pause` | Pause/resume session timer |
| `/gtb lock` | Lock frame positions |
| `/gtb unlock` | Unlock frame positions |
| `/gtb show` | Show HUD |
| `/gtb hide` | Hide HUD |

## Optional Integrations

Goblin Toolbox works standalone but can integrate with:

- **TradeSkillMaster (TSM)**: Uses TSM price sources for bag value calculations
- **Auctionator / Oribos Exchange**: Future price source support planned

## Requirements

- World of Warcraft: The War Within (12.0) or later
- No required dependencies

## Roadmap

See [Current_Development_status.txt](Current_Development_status.txt) for detailed feature status.

**Planned Features:**
- Profession concentration tracking
- Sales tracker
- Additional utility bar buttons
- Auctionator price source support

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

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

**Wooraah**

## Acknowledgments

Thanks to my team of beta testers for their invaluable feedback and bug reports.
