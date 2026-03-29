"Time is money, friend! And Fully Upgraded saves ya both! This nifty addon shows ya exactly how many upgrades yer gear's got left AND how many Dawncrests you'll need to get it maxed out. Updated for Midnight's new upgrade system—simpler, faster, more profitable! No more guesswork, no more wastin' time! Just strap it on, check yer gear, and get ready to make those bosses cough up the goods. Remember, friend: efficiency means profits, and profits mean ka-ching!"

![image](https://github.com/user-attachments/assets/98b16e52-b3a9-4f1a-b869-b70a7cd1bd23)

![image](https://github.com/user-attachments/assets/b3ed48fd-e9c1-4c96-8347-078fe87efb6c)
![image](https://github.com/user-attachments/assets/83e47873-afde-47b5-bec4-cc2690a05ba5)

## Features (Midnight Edition)
- **Shows upgrade potential** for all equipped items (X/6 format)
- **Tracks Dawncrest requirements** across all 5 tiers (Adventurer -> Veteran -> Champion -> Hero -> Myth)
- **Dual-crest transitions** — shows when cheaper crests can be used at track boundaries
- **Progress bar** showing overall upgrade completion percentage
- **Per-slot breakdown tooltip** — hover the panel to see every slot's upgrade needs with crest icons
- **Season progress tracking** — shows earned vs season maximum per crest type
- **Weekly cap display** in currency panel rows (earned/100)
- **Excess crest indicator** — shows conversion potential (45:1 ratio) in crest tooltips
- **Color-coded currency counts** — green when you have enough crests
- **Mythic+ run calculations** based on Dawncrest needs (flat 20 crests per upgrade)
- **Raid rewards breakdown** for all 3 Midnight raids (The Voidspire, The Dreamrift, March on Quel'Danas)
- **Pre-season "Waiting for gear" state** when no season gear is equipped
- **Customizable text position** via `/fu textpos` command

## What's New in 2.3
- **Dual-crest support** — tracks overlap at boundaries (level 2 accepts lower-tier, level 6 accepts higher-tier crest)
- **Progress bar** under the title showing upgrade completion percentage
- **Per-slot breakdown tooltip** — hover the master panel to see all slots with crest icons and upgrade counts
- **Season progress** — shows total earned vs season maximum per crest type (increases weekly)
- **Weekly cap indicator** in currency panel rows
- **Excess crest indicator** — crest tooltip shows conversion potential to higher tiers
- **Color-coded counts** — currency panel turns green when you have enough crests
- **Corrected M+ crest ranges** — Champion M+2-3, Hero M+4-8, Myth M+9+ (verified from in-game)
- **Updated crest sources** — all 5 tiers updated to match in-game currency tooltips
- **Fixed minimum ilvl** — season gear now detected from ilvl 220 (was 224)

## What's New in 2.2
- Added Adventurer Dawncrest tracking in currency panel (now shows all 5 tiers: A/V/C/H/M)
- Fixed currency panel dynamic sizing (panel now properly resizes for all crest rows)

## What's New in 2.1
- Added "Waiting for gear" state for pre-season characters (no misleading 0/0 display)
- Updated M+ crest rewards from Wowhead: Hero Dawncrests from M+ 2-6, Myth Dawncrests from M+ 7+
- Added all 3 Midnight Season 1 raids with full boss lists and crest reward data
- Color-coded raid titles in tooltips matching crest tier
- Weekly cap now reads from WoW API when available
- Dark tooltip backdrop for better readability

## What's New in 2.0 (Midnight)
- Removed Valorstones (replaced with flat gold costs)
- Updated to 6-level upgrade system (was 8 levels)
- New Dawncrest currency system (5 tiers)
- Flat 20 crests per upgrade (simplified from complex scaling)
- Single crest type per track (no more split upgrades)
- Updated item level ranges for Midnight Season 1 (220-289)

## Usage
- Open your character panel to see upgrade information
- Hover over upgrade indicators to see detailed crest requirements
- Hover over Dawncrest display to see sources, raid rewards, and M+ runs needed
- Hover over the panel title for a full per-slot breakdown with season progress
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
All tracks have **6 upgrade levels** with dual-crest transitions at boundaries:

- **Adventurer**: Adventurer Dawncrests (Outdoor Events, Tier 4 Delves)
- **Veteran**: Veteran Dawncrests (LFR, Heroic Dungeons, Delves 5-6)
- **Champion**: Champion Dawncrests (M+2-3, Mythic 0, Normal Raid, Delves 7-10)
- **Hero**: Hero Dawncrests (M+4-8, Heroic Raid, Tier 11 Delves)
- **Myth**: Myth Dawncrests (M+9+, Mythic Raid)

## Raids (Midnight Season 1)
- **The Voidspire** — 6 bosses (LFR/Normal/Heroic/Mythic)
- **The Dreamrift** — 1 boss (LFR/Normal/Heroic/Mythic)
- **March on Quel'Danas** — 2 bosses (all difficulties)

## Crest Conversion
Convert **45 lower-tier crests** -> **1 higher-tier crest** (unlocked via seasonal achievements).

## Support
Report issues or suggestions on [GitHub](https://github.com/zync09/FullyUpgraded/issues)
