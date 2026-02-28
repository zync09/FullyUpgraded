"Time is money, friend! And Fully Upgraded saves ya both! This nifty addon shows ya exactly how many upgrades yer gear's got left AND how many Dawncrests AND gold you'll need to get it maxed out. Updated for Midnight's new upgrade system—simpler, faster, more profitable! No more guesswork, no more wastin' time—or gold! Just strap it on, check yer gear, and get ready to make those bosses cough up the goods. Remember, friend: efficiency means profits, and profits mean ka-ching!"

![image](https://github.com/user-attachments/assets/98b16e52-b3a9-4f1a-b869-b70a7cd1bd23)

![image](https://github.com/user-attachments/assets/b3ed48fd-e9c1-4c96-8347-078fe87efb6c)
![image](https://github.com/user-attachments/assets/83e47873-afde-47b5-bec4-cc2690a05ba5)

## Features (Midnight Edition)
- **Shows upgrade potential** for all equipped items (X/6 format)
- **Tracks Dawncrest requirements** across 4 tracked tiers (Veteran → Champion → Hero → Myth)
- **Calculates gold costs** per item and total across all gear
- **Mythic+ run calculations** based on Dawncrest needs (flat 20 crests per upgrade)
- **Raid rewards breakdown** for all 3 Midnight raids (The Voidspire, The Dreamrift, March on Quel'Danas)
- **Real-time currency tracking** with weekly cap display (100 per crest type)
- **Pre-season "Waiting for gear" state** when no season gear is equipped
- **Simplified upgrade system** - one crest type per track, no split upgrades
- **Customizable text position** via `/fu textpos` command

## What's New in 2.1
- Added "Waiting for gear" state for pre-season characters (no misleading 0/0 display)
- Updated M+ crest rewards from Wowhead: Hero Dawncrests from M+ 2-6, Myth Dawncrests from M+ 7+
- Added all 3 Midnight Season 1 raids with full boss lists and crest reward data
- Color-coded raid titles in tooltips matching crest tier
- Weekly cap now reads from WoW API when available
- Dark tooltip backdrop for better readability
- Removed Adventurer tier from currency panel (not needed for upgrades)

## What's New in 2.0 (Midnight)
- Removed Valorstones (replaced with flat gold costs)
- Updated to 6-level upgrade system (was 8 levels)
- New Dawncrest currency system (5 tiers)
- Flat 20 crests per upgrade (simplified from complex scaling)
- Single crest type per track (no more split upgrades)
- Gold cost tracking (10g-50g per upgrade depending on track)
- Updated item level ranges for Midnight Season 1 (224-289)

## Usage
- Open your character panel to see upgrade information
- Hover over upgrade indicators to see detailed requirements (crests + gold)
- Hover over Dawncrest display to see sources, raid rewards, and M+ runs needed
- Left-click the panel to share your upgrade needs in chat
- Right-click the panel for options
- Use `/fu` or `/fullyupgraded` for commands

## Commands
- `/fu textpos <TOP|BOTTOM|CENTER>` - Change text position
- `/fu show` / `/fu hide` - Toggle upgrade text visibility
- `/fu share` - Share upgrade needs in chat
- `/fu colors` - Preview track colors
- `/fu refresh` - Force refresh display
- `/fu currency` - Refresh currency information
- `/fu debug` - Toggle debug mode

## Track System (Midnight Season 1)
All tracks have **6 upgrade levels** and use a **single Dawncrest type**:

- **Adventurer**: 10g per upgrade, no crests required
- **Veteran**: 20g per upgrade, Veteran Dawncrests
- **Champion**: 30g per upgrade, Champion Dawncrests (Mythic 0, Normal Raid)
- **Hero**: 40g per upgrade, Hero Dawncrests (M+ 2-6, Heroic Raid)
- **Myth**: 50g per upgrade, Myth Dawncrests (M+ 7+, Mythic Raid)

## Raids (Midnight Season 1)
- **The Voidspire** — 6 bosses (LFR/Normal/Heroic/Mythic)
- **The Dreamrift** — 1 boss (LFR/Normal/Heroic/Mythic)
- **March on Quel'Danas** — 2 bosses (all difficulties)

## Crest Conversion
Convert **45 lower-tier crests** → **1 higher-tier crest** (unlocked via seasonal achievements).

## Support
Report issues or suggestions on [GitHub](https://github.com/zync09/FullyUpgraded/issues)
