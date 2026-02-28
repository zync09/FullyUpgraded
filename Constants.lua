local addonName, addon = ...

-- Base upgrade constants (Midnight expansion)
addon.CRESTS_TO_UPGRADE = 20  -- Flat 20 crests per upgrade level
addon.CRESTS_CONVERSION_UP = 45  -- 45 lower-tier crests convert to 1 higher-tier crest

-- Cache settings (optimized for performance)
addon.CACHE_TIMEOUT = 3                -- Cache timeout in seconds
addon.MAX_CACHE_ENTRIES = 50           -- Maximum number of entries in caches
addon.TOOLTIP_CACHE_TTL = 5            -- Tooltip cache time-to-live in seconds
addon.ITEM_INFO_CACHE_TTL = 10         -- Item info cache TTL
addon.CURRENCY_CACHE_TTL = 2           -- Currency cache TTL

-- UI settings
addon.FONT_SIZE = 12
addon.FONT_FLAGS = "OUTLINE, THICKOUTLINE"
addon.ICON_SIZE = 16
addon.BUTTON_SIZE = { width = 30, height = 20 }
addon.FRAME_PADDING = 8
addon.MASTER_FRAME_MIN_WIDTH = 230
addon.CURRENCY_FRAME_HEIGHT = 20
addon.CURRENCY_FRAME_WIDTH = 140

-- Timing settings
addon.UPDATE_THROTTLE_TIME = 0.2       -- Throttle time for updates
addon.DELAYED_SIZE_UPDATE_TIME = 0.15  -- Delay for size updates
addon.POSITION_RECALC_TIME = 0.1       -- Position recalculation delay
addon.CACHE_CLEANUP_INTERVAL = 30      -- Clean caches every 30 seconds

-- Display settings
addon.CURRENCY_SPACING = 6             -- Spacing between currency groups
addon.ICON_TEXT_SPACING = 2            -- Spacing between icon and text
addon.SEPARATOR_WIDTH = 2              -- Width of separator between currencies

-- Debug mode (shared across all files)
addon.debugMode = false

-- Color constants for upgrade tracks (Midnight)
addon.TRACK_COLORS = {
    -- Midnight upgrade tracks
    ADVENTURER = "ffffff",    -- White
    VETERAN = "1eff00",       -- Green
    CHAMPION = "0070dd",      -- Blue
    HERO = "a335ee",          -- Purple
    MYTH = "ff8000",          -- Orange

    -- Special cases
    FULLY_UPGRADED = "ffd700", -- Gold for completed items
}

-- Text background settings
addon.TEXT_BACKGROUND = {
    enabled = false,          -- Whether to show background by default
    color = { 0, 0, 0, 0.8 }, -- Black with 80% transparency
    padding = 2,              -- Pixels of padding around text
}

-- Midnight expansion item level range
addon.SEASONS = {
    [1] = {  -- Midnight Season 1
        MIN_ILVL = 224,
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
        ilvlMin = 224,
        ilvlMax = 237,
        mythicLevel = 0,  -- No mythic+ requirement
        usage = "Used to upgrade Adventurer gear in Midnight Season 1",
        sources = {
            "World Quests",
            "Normal Dungeons",
            "Delves (Lower Tiers)"
        },
        upgradesTo = "VETERAN"
    },
    VETERAN = {
        baseName = "Veteran",
        shortCode = "V",
        color = "1eff00",  -- Green
        colorRGB = { 0.118, 1, 0 },
        currencyID = 3341,
        ilvlMin = 237,
        ilvlMax = 250,
        mythicLevel = 0,  -- No mythic+ requirement
        usage = "Used to upgrade Veteran gear in Midnight Season 1",
        sources = {
            "Heroic Dungeons",
            "World Events",
            "Delves (Mid Tiers)"
        },
        upgradesTo = "CHAMPION"
    },
    CHAMPION = {
        baseName = "Champion",
        shortCode = "C",
        color = "0070dd",  -- Blue
        colorRGB = { 0, 0.439, 0.867 },
        currencyID = 3343,
        ilvlMin = 250,
        ilvlMax = 263,
        mythicLevel = 2,  -- Mythic+ 2-3
        usage = "Used to upgrade Champion gear in Midnight Season 1",
        sources = {
            "Normal Raid",
            "Mythic+ 2-3",
            "Delves (High Tiers)"
        },
        upgradesTo = "HERO"
    },
    HERO = {
        baseName = "Hero",
        shortCode = "H",
        color = "a335ee",  -- Purple
        colorRGB = { 0.639, 0.208, 0.933 },
        currencyID = 3345,
        ilvlMin = 263,
        ilvlMax = 276,
        mythicLevel = 4,  -- Mythic+ 4-8
        usage = "Used to upgrade Hero gear in Midnight Season 1",
        sources = {
            "Heroic Raid",
            "Mythic+ 4-8"
        },
        upgradesTo = "MYTH"
    },
    MYTH = {
        baseName = "Myth",
        shortCode = "M",
        color = "ff8000",  -- Orange
        colorRGB = { 1, 0.502, 0 },
        currencyID = 3347,
        ilvlMin = 276,
        ilvlMax = 289,
        mythicLevel = 9,  -- Mythic+ 9+
        usage = "Used to upgrade Myth gear in Midnight Season 1",
        sources = {
            "Mythic Raid",
            "Mythic+ 9+"
        },
        upgradesTo = nil
    }
}

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

-- Crest rewards from Mythic+ (Midnight values)
-- Note: These are approximate and may need adjustment based on live data
addon.CREST_REWARDS = {
    CHAMPION = {
        [2] = { timed = 20, untimed = 16 },
        [3] = { timed = 24, untimed = 20 }
    },
    HERO = {
        [4] = { timed = 20, untimed = 16 },
        [5] = { timed = 24, untimed = 20 },
        [6] = { timed = 28, untimed = 24 },
        [7] = { timed = 32, untimed = 28 },
        [8] = { timed = 36, untimed = 32 }
    },
    MYTH = {
        [9] = { timed = 20, untimed = 16 },
        [10] = { timed = 24, untimed = 20 },
        [11] = { timed = 28, untimed = 24 },
        [12] = { timed = 32, untimed = 28 },
        [13] = { timed = 36, untimed = 32 },
        [14] = { timed = 40, untimed = 36 },
        [15] = { timed = 44, untimed = 40 }
    }
}

-- Text position definitions
addon.TEXT_POSITIONS = {
    TOP = { point = "TOP", x = 0, y = -3 },
    BOTTOM = { point = "BOTTOM", x = 0, y = 3 },
    C = { point = "CENTER", x = 0, y = 0 },
}

-- Upgrade track definitions (Midnight - simplified)
-- All tracks now have 6 levels and use a single crest type
addon.UPGRADE_TRACKS = (function()
    local tracks = {}

    -- Define track configurations
    local trackConfigs = {
        ADVENTURER = {
            crestType = "ADVENTURER",
            levels = 6
        },
        VETERAN = {
            crestType = "VETERAN",
            levels = 6
        },
        CHAMPION = {
            crestType = "CHAMPION",
            levels = 6
        },
        HERO = {
            crestType = "HERO",
            levels = 6
        },
        MYTH = {
            crestType = "MYTH",
            levels = 6
        }
    }

    -- Generate tracks from configurations
    for trackName, config in pairs(trackConfigs) do
        local crestData = addon.CREST_BASE[config.crestType]

        tracks[trackName] = {
            color = crestData.color,
            crest = crestData.baseName,
            shortname = crestData.baseName,
            upgradeLevels = config.levels,
            crestType = config.crestType,
            goldCost = addon.GOLD_COSTS[config.crestType]
        }
    end

    return tracks
end)()

-- Raid boss rewards information (Midnight Season 1)
-- Note: These values may need adjustment based on live data
addon.RAID_REWARDS = {
    -- Placeholder for Midnight raid data
    -- Update with actual raid name and boss information when available
    MIDNIGHT_RAID = {
        name = "Midnight Season 1 Raid",
        difficulties = {
            NORMAL = "CHAMPION",
            HEROIC = "HERO",
            MYTHIC = "MYTH"
        },
        bosses = {
            { name = "Boss 1-6", reward = 15 },
            { name = "Boss 7-8", reward = 20 }
        }
    }
}
