local addonName, addon = ...

-- Base upgrade constants (Midnight expansion)
addon.CRESTS_TO_UPGRADE = 20  -- Flat 20 crests per upgrade level
-- Season 2: 3 lower-tier Mistcrests convert to 1 higher-tier (was 45:1 in Season 1).
-- Conversion unlocks per tier after reaching that tier's max ilvl in every slot (feat of strength).
addon.CRESTS_CONVERSION_UP = 3

-- Cache settings (optimized for performance)
addon.CACHE_TIMEOUT = 3                -- Cache timeout in seconds
addon.MAX_CACHE_ENTRIES = 50           -- Maximum number of entries in caches
addon.TOOLTIP_CACHE_TTL = 5            -- Tooltip cache time-to-live in seconds

-- UI settings
addon.FONT_SIZE = 12
addon.FONT_FLAGS = "THICKOUTLINE"
addon.FRAME_PADDING = 12
addon.MASTER_FRAME_MIN_WIDTH = 230
addon.CURRENCY_FRAME_HEIGHT = 20
addon.CURRENCY_FRAME_WIDTH = 140

-- Timing settings
addon.UPDATE_THROTTLE_TIME = 0.2       -- Throttle time for updates
addon.DELAYED_SIZE_UPDATE_TIME = 0.15  -- Delay for size updates
addon.POSITION_RECALC_TIME = 0.1       -- Position recalculation delay
addon.CACHE_CLEANUP_INTERVAL = 30      -- Clean caches every 30 seconds

-- Debug mode (shared across all files)
addon.debugMode = false

-- Text background settings
addon.TEXT_BACKGROUND = {
    padding = 2,              -- Pixels of padding around text
}

-- Midnight expansion item level ranges
addon.CURRENT_SEASON = 2
addon.SEASONS = {
    [1] = {  -- Midnight Season 1
        MIN_ILVL = 220,
        MAX_ILVL = 289
    },
    [2] = {  -- Midnight Season 2 (12.1) — Adventurer 1/6 = 266, Myth 6/6 = 334,
             -- Very Rare / final-boss Mythic drops up to 344.
             -- NOTE: 266-289 overlaps Season 1 gear; verify how S1 leftovers display at launch.
        MIN_ILVL = 266,
        MAX_ILVL = 344
    }
}

-- Equipment slots
addon.EQUIPMENT_SLOTS = {
    "HeadSlot", "ShoulderSlot", "ChestSlot", "WristSlot",
    "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot",
    "NeckSlot", "BackSlot", "Finger0Slot", "Finger1Slot",
    "Trinket0Slot", "Trinket1Slot",
    "MainHandSlot", "SecondaryHandSlot"
}

-- Common crest values
local CREST_COMMON = {
    SUFFIX = "Mistcrest",  -- Season 2 currency (replaced Dawncrests; no conversion from S1)
    WEEKLY_CAP = 100       -- Per crest type; season maximum grows by 100/week (catch-up)
}
addon.CREST_SUFFIX = CREST_COMMON.SUFFIX

-- Base crest definitions (Midnight Season 2 Mistcrests, currency IDs 3442-3446)
addon.CREST_BASE = {
    ADVENTURER = {
        baseName = "Adventurer",
        shortCode = "A",
        color = "ffffff",  -- White
        colorRGB = { 1, 1, 1 },
        currencyID = 3442,
        mythicLevel = 0,  -- No mythic+ requirement
        sources = {
            "Repeatable Outdoor Events",
            "Delves (Tier 4)"
        },
        upgradesTo = "VETERAN"
    },
    VETERAN = {
        baseName = "Veteran",
        shortCode = "V",
        color = "1eff00",  -- Green
        colorRGB = { 0.118, 1, 0 },
        currencyID = 3443,
        mythicLevel = 0,  -- No mythic+ requirement
        sources = {
            "Repeatable Outdoor Events",
            "Raid Finder (The Venomous Abyss)",
            "Heroic Season Dungeons",
            "Delves (Tiers 5-6)",
            "Trovehunter's Bounty (Tiers 4-5)"
        },
        upgradesTo = "CHAMPION"
    },
    CHAMPION = {
        baseName = "Champion",
        shortCode = "C",
        color = "0070dd",  -- Blue
        colorRGB = { 0, 0.439, 0.867 },
        currencyID = 3444,
        mythicLevel = 2,  -- Mythic+ 2-3
        sources = {
            "Weekly Outdoor Events",
            "Mythic 0 Dungeons",
            "Mythic+ 2-3",
            "Normal Raid",
            "Delves (Tiers 7-10)",
            "Trovehunter's Bounty (Tiers 6-7)"
        },
        upgradesTo = "HERO"
    },
    HERO = {
        baseName = "Hero",
        shortCode = "H",
        color = "a335ee",  -- Purple
        colorRGB = { 0.639, 0.208, 0.933 },
        currencyID = 3445,
        mythicLevel = 4,  -- Mythic+ 4-8
        sources = {
            "Heroic Raid",
            "Mythic+ 4-8",
            "Delves (Tier 11)",
            "Trovehunter's Bounty (Tiers 8+)"
        },
        upgradesTo = "MYTH"
    },
    MYTH = {
        baseName = "Myth",
        shortCode = "M",
        color = "ff8000",  -- Orange
        colorRGB = { 1, 0.502, 0 },
        currencyID = 3446,
        mythicLevel = 9,  -- Mythic+ 9+
        sources = {
            "Mythic Raid",
            "Mythic+ 9+"
        },
        upgradesTo = nil
    }
}

-- Reverse lookup: shortCode → crestType key (e.g. "A" → "ADVENTURER")
addon.CREST_BY_SHORTCODE = (function()
    local lookup = {}
    for crestType, data in pairs(addon.CREST_BASE) do
        lookup[data.shortCode] = crestType
    end
    return lookup
end)()

-- Generate TRACK_COLORS from CREST_BASE (+ fully upgraded special case)
addon.TRACK_COLORS = (function()
    local colors = {}
    for crestType, data in pairs(addon.CREST_BASE) do
        colors[crestType] = data.color
    end
    colors.FULLY_UPGRADED = "ffd700"  -- Gold for completed items
    return colors
end)()

-- Generate CREST_ORDER from CREST_BASE
addon.CREST_ORDER = (function()
    local order = {}
    local current = "ADVENTURER"
    while current do
        table.insert(order, current)
        current = addon.CREST_BASE[current].upgradesTo
    end
    return order
end)()

-- Index lookup for CREST_ORDER (e.g. "VETERAN" → 2)
addon.CREST_ORDER_INDEX = (function()
    local lookup = {}
    for i, crestType in ipairs(addon.CREST_ORDER) do
        lookup[crestType] = i
    end
    return lookup
end)()

-- Generate CURRENCY.CRESTS from CREST_BASE
addon.CURRENCY = {
    CRESTS = (function()
        local crests = {}
        for crestType, data in pairs(addon.CREST_BASE) do
            local fullName = data.baseName .. " " .. CREST_COMMON.SUFFIX
            crests[crestType] = {
                name = fullName,
                shortname = data.baseName,
                reallyshortname = data.shortCode,
                current = 0,
                needed = 0,
                upgraded = 0,
                mythicLevel = data.mythicLevel,
                upgradesTo = data.upgradesTo,
                currencyID = data.currencyID,
                weeklyCap = CREST_COMMON.WEEKLY_CAP
            }
        end
        return crests
    end)()
}

-- Gold costs per upgrade (Midnight system - replaces Valorstones)
-- Season 2: no reported change; verify in-game at launch
addon.GOLD_COSTS = {
    ADVENTURER = 10,
    VETERAN = 20,
    CHAMPION = 30,
    HERO = 40,
    MYTH = 50
}

-- Crest rewards from Mythic+ (Midnight Season 2)
-- Brackets match the in-game currency tooltips: Champion M+2-3, Hero M+4-8, Myth M+9+
-- (Method's S2 guide instead lists Hero from +2-6 and Myth from +7+ — same conflict
-- Wowhead had in S1 before in-game data confirmed the bracket layout below.
-- VERIFY IN-GAME at season launch and adjust if the brackets shifted.)
-- Reward amounts are estimates - update when confirmed
addon.CREST_REWARDS = {
    CHAMPION = {
        [2] = { timed = 10 },
        [3] = { timed = 12 }
    },
    HERO = {
        [4] = { timed = 10 },
        [5] = { timed = 12 },
        [6] = { timed = 14 },
        [7] = { timed = 16 },
        [8] = { timed = 18 }
    },
    MYTH = {
        [9] = { timed = 10 },
        [10] = { timed = 12 },
        [11] = { timed = 14 },
        [12] = { timed = 16 }
    }
}

-- Slot display names for tooltips
addon.SLOT_DISPLAY_NAMES = {
    HeadSlot = "Head",
    ShoulderSlot = "Shoulder",
    ChestSlot = "Chest",
    WristSlot = "Wrist",
    HandsSlot = "Hands",
    WaistSlot = "Waist",
    LegsSlot = "Legs",
    FeetSlot = "Feet",
    NeckSlot = "Neck",
    BackSlot = "Back",
    Finger0Slot = "Ring 1",
    Finger1Slot = "Ring 2",
    Trinket0Slot = "Trinket 1",
    Trinket1Slot = "Trinket 2",
    MainHandSlot = "Main Hand",
    SecondaryHandSlot = "Off Hand"
}

-- Format gold amount with comma separators
function addon.formatGold(amount)
    if amount >= 1000 then
        return string.format("%d,%03dg", math.floor(amount / 1000), amount % 1000)
    end
    return amount .. "g"
end

-- Text position definitions
addon.TEXT_POSITIONS = {
    TOP = { point = "TOP", x = 0, y = -3 },
    BOTTOM = { point = "BOTTOM", x = 0, y = 3 },
    C = { point = "CENTER", x = 0, y = 0 },
}

-- Upgrade track definitions (Midnight - simplified)
-- All tracks have 6 levels, one crest type each, generated from CREST_BASE
addon.UPGRADE_TRACKS = (function()
    local tracks = {}
    for crestType, data in pairs(addon.CREST_BASE) do
        tracks[crestType] = {
            color = data.color,
            crest = data.baseName,
            shortname = data.baseName,
            upgradeLevels = 6,
            crestType = crestType,
            goldCost = addon.GOLD_COSTS[crestType]
        }
    end
    return tracks
end)()

-- Raid boss rewards information (Midnight Season 2 - The Venomous Abyss, 8 bosses)
-- Crests scale with how deep into the raid the boss is (10-20).
-- Per-boss amounts are estimates - update when live data is available.
-- Note: on Normal/Heroic the final boss (Ula'tek) also awards ~10 crests of the
-- next tier up (Hero on Normal, Myth on Heroic) - not modeled in this table.
addon.RAID_REWARDS = {
    THE_VENOMOUS_ABYSS = {
        name = "The Venomous Abyss",
        difficulties = {
            LFR = "VETERAN",
            NORMAL = "CHAMPION",
            HEROIC = "HERO",
            MYTHIC = "MYTH"
        },
        bosses = {
            { name = "Nek'zali the Soulcoiler", reward = 10 },
            { name = "Entombed Sentinels", reward = 10 },
            { name = "The Lost Explorers", reward = 10 },
            { name = "Vashnik the Malignant", reward = 15 },
            { name = "Sszorak", reward = 15 },
            { name = "The Twin Fangs", reward = 15 },
            { name = "The Coiled Altar", reward = 20 },
            { name = "Ula'tek", reward = 20 }
        }
    }
}
