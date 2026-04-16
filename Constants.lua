local addonName, addon = ...

-- Base upgrade constants (Midnight expansion)
addon.CRESTS_TO_UPGRADE = 20  -- Flat 20 crests per upgrade level
addon.CRESTS_CONVERSION_UP = 45  -- 45 lower-tier crests convert to 1 higher-tier crest

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

-- Midnight expansion item level range
addon.SEASONS = {
    [1] = {  -- Midnight Season 1
        MIN_ILVL = 220,
        MAX_ILVL = 289
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
    SUFFIX = "Dawncrest",
    WEEKLY_CAP = 100  -- Increased from 90 in War Within
}

-- Base crest definitions (Midnight Dawncrests)
addon.CREST_BASE = {
    ADVENTURER = {
        baseName = "Adventurer",
        shortCode = "A",
        color = "ffffff",  -- White
        colorRGB = { 1, 1, 1 },
        currencyID = 3383,
        mythicLevel = 0,  -- No mythic+ requirement
        sources = {
            "Repeatable Outdoor Events",
            "Delves (Tier 4)",
            "Prey Hunts (Normal)"
        },
        upgradesTo = "VETERAN"
    },
    VETERAN = {
        baseName = "Veteran",
        shortCode = "V",
        color = "1eff00",  -- Green
        colorRGB = { 0.118, 1, 0 },
        currencyID = 3341,
        mythicLevel = 0,  -- No mythic+ requirement
        sources = {
            "Repeatable Outdoor Events",
            "Raid Finder",
            "Heroic Season Dungeons",
            "Delves (Tiers 5-6)",
            "Prey Hunts (Hard)"
        },
        upgradesTo = "CHAMPION"
    },
    CHAMPION = {
        baseName = "Champion",
        shortCode = "C",
        color = "0070dd",  -- Blue
        colorRGB = { 0, 0.439, 0.867 },
        currencyID = 3343,
        mythicLevel = 2,  -- Mythic+ 2-3
        sources = {
            "Mythic 0 Dungeons",
            "Mythic+ 2-3",
            "Normal Raid",
            "Delves (Tiers 7-10)"
        },
        upgradesTo = "HERO"
    },
    HERO = {
        baseName = "Hero",
        shortCode = "H",
        color = "a335ee",  -- Purple
        colorRGB = { 0.639, 0.208, 0.933 },
        currencyID = 3345,
        mythicLevel = 4,  -- Mythic+ 4-8
        sources = {
            "Heroic Raid",
            "Mythic+ 4-8",
            "Delves (Tier 11)"
        },
        upgradesTo = "MYTH"
    },
    MYTH = {
        baseName = "Myth",
        shortCode = "M",
        color = "ff8000",  -- Orange
        colorRGB = { 1, 0.502, 0 },
        currencyID = 3347,
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
addon.GOLD_COSTS = {
    ADVENTURER = 10,
    VETERAN = 20,
    CHAMPION = 30,
    HERO = 40,
    MYTH = 50
}

-- Crest rewards from Mythic+ (Midnight Season 1)
-- Champion from M+2-3, Hero from M+4-8, Myth from M+9-12
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

-- Raid boss rewards information (Midnight Season 1)
-- Per-boss crest amounts are estimated until live data is available
addon.RAID_REWARDS = {
    THE_VOIDSPIRE = {
        name = "The Voidspire",
        difficulties = {
            LFR = "VETERAN",
            NORMAL = "CHAMPION",
            HEROIC = "HERO",
            MYTHIC = "MYTH"
        },
        bosses = {
            { name = "Imperator Averzian", reward = 10 },
            { name = "Vorasius", reward = 10 },
            { name = "Fallen-King Salhadaar", reward = 10 },
            { name = "Vaelgor & Ezzorak", reward = 10 },
            { name = "Lightblinded Vanguard", reward = 10 },
            { name = "Crown of the Cosmos", reward = 15 }
        }
    },
    THE_DREAMRIFT = {
        name = "The Dreamrift",
        difficulties = {
            LFR = "VETERAN",
            NORMAL = "CHAMPION",
            HEROIC = "HERO",
            MYTHIC = "MYTH"
        },
        bosses = {
            { name = "Chimaerus the Undreamt God", reward = 15 }
        }
    },
    MARCH_ON_QUELDANAS = {
        name = "March on Quel'Danas",
        difficulties = {
            LFR = "VETERAN",
            NORMAL = "CHAMPION",
            HEROIC = "HERO",
            MYTHIC = "MYTH"
        },
        bosses = {
            { name = "Belo'ren, Child of Al'ar", reward = 10 },
            { name = "Midnight Falls", reward = 15 }
        }
    }
}
