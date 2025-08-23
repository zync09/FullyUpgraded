local addonName, addon = ...

-- Base upgrade constants
addon.CRESTS_TO_UPGRADE = 15
addon.CRESTS_CONVERSION_UP = 45

-- Cache settings (optimized for performance)
addon.CACHE_TIMEOUT = 3                -- Cache timeout in seconds (increased for better performance)
addon.MAX_CACHE_ENTRIES = 50           -- Maximum number of entries in caches
addon.TOOLTIP_CACHE_TTL = 5            -- Tooltip cache time-to-live in seconds (tooltips rarely change)
addon.ITEM_INFO_CACHE_TTL = 10         -- Item info cache TTL (item data is very stable)
addon.CURRENCY_CACHE_TTL = 2           -- Currency cache TTL (balance between freshness and performance)

-- UI settings
addon.FONT_SIZE = 12
addon.FONT_FLAGS = "OUTLINE, THICKOUTLINE"
addon.ICON_SIZE = 16
addon.BUTTON_SIZE = { width = 30, height = 20 }
addon.FRAME_PADDING = 8
addon.MASTER_FRAME_MIN_WIDTH = 230
addon.CURRENCY_FRAME_HEIGHT = 20
addon.CURRENCY_FRAME_WIDTH = 140

-- Timing settings (optimized for performance)
addon.UPDATE_THROTTLE_TIME = 0.2       -- Throttle time for updates (increased to reduce update frequency)
addon.DELAYED_SIZE_UPDATE_TIME = 0.15  -- Delay for size updates (slightly increased for batching)
addon.POSITION_RECALC_TIME = 0.1       -- Position recalculation delay (increased to reduce recalcs)
addon.CACHE_CLEANUP_INTERVAL = 30      -- Only clean caches every 30 seconds

-- Display settings
addon.CURRENCY_SPACING = 6             -- Spacing between currency groups
addon.ICON_TEXT_SPACING = 2            -- Spacing between icon and text
addon.SEPARATOR_WIDTH = 2              -- Width of separator between currencies

-- Debug mode (shared across all files)
addon.debugMode = false

-- Color constants for upgrade tracks
addon.TRACK_COLORS = {
    -- Standard WoW quality colors + custom track colors
    EXPLORER = "9d9d9d",      -- Grey (like poor quality items)
    ADVENTURER = "ffffff",    -- White (like common quality items)  
    VETERAN = "1eff00",       -- Green (like uncommon quality items)
    CHAMPION = "0070dd",      -- Blue (like rare quality items)
    HERO = "a335ee",          -- Purple (like epic quality items)
    MYTH = "ff8000",          -- Orange (like legendary quality items)
    
    -- Special cases
    SEASON1 = "ff6600",       -- Orange-red for old season items
    FULLY_UPGRADED = "ffd700", -- Gold for completed items
}

-- Text background settings
addon.TEXT_BACKGROUND = {
    enabled = false,          -- Whether to show background by default
    color = { 0, 0, 0, 0.8 }, -- Black with 80% transparency
    padding = 2,              -- Pixels of padding around text
}

-- Season item level ranges
addon.SEASONS = {
    [1] = {
        MIN_ILVL = 584,
        MAX_ILVL = 639
    },
    [2] = {
        MIN_ILVL = 597,
        MAX_ILVL = 678
    },
    [3] = {
        MIN_ILVL = 642,
        MAX_ILVL = 723
    }
}

-- Equipment slots organized by category
local SLOT_CATEGORIES = {
    armor = { "Head", "Shoulder", "Chest", "Wrist", "Hands", "Waist", "Legs", "Feet" },
    accessories = { "Neck", "Back", "Finger0", "Finger1", "Trinket0", "Trinket1" },
    weapons = { "MainHand", "SecondaryHand" }
}

-- Generate equipment slots array
addon.EQUIPMENT_SLOTS = (function()
    local slots = {}
    for _, category in pairs(SLOT_CATEGORIES) do
        for _, slot in ipairs(category) do
            table.insert(slots, slot .. "Slot")
        end
    end
    return slots
end)()

-- Common crest values
local CREST_COMMON = {
    SUFFIX = "Undermine Crest",
    DIFFICULTIES = {
        LFR = "LFR difficulty",
        NORMAL = "Normal difficulty",
        HEROIC = "Heroic difficulty",
        MYTHIC = "Mythic difficulty"
    }
}

-- Base crest definitions
addon.CREST_BASE = {
    WEATHERED = {
        baseName = "Weathered",
        shortCode = "W",
        color = "ffffff",
        currencyID = 3284,
        mythicLevel = 0,
        usage = "Used to upgrade Adventurer and Veteran gear in War Within Season 3 up to item level 678",
        sources = {
            "Repeatable Outdoor Events",
            "Raid Finder Manaforge Omega (10 crests per boss, 15 from last two)",
            "Heroic Season Dungeons",
            "Delves (Tiers 1 to 5)"
        },
        upgradesTo = "CARVED"
    },
    CARVED = {
        baseName = "Carved",
        shortCode = "C",
        color = "006bee",
        currencyID = 3286,
        mythicLevel = 0,
        usage = "Used to upgrade Veteran and Champion gear in War Within Season 3 up to item level 691",
        sources = {
            "Weekly Random Events",
            "Normal Manaforge Omega (10 crests per boss, 15 from last two)",
            "Mythic 0 dungeons",
            "Delves (Tiers 6 and 7)",
            "Delver's Bounty (Tiers 4 and 5)"
        },
        upgradesTo = "RUNED"
    },
    RUNED = {
        baseName = "Runed",
        shortCode = "R",
        color = "a729ff",
        currencyID = 3288,
        mythicLevel = 2,
        usage = "Used to upgrade Champion and Hero gear in War Within Season 3 up to item level 704",
        sources = {
            "Heroic Manaforge Omega (10 crests per boss, 15 from last two)",
            "Mythic Keystone Dungeons from +2 to +6",
            "Delves (Tiers 8 to 11)",
            "Delver's Bounty (Tiers 6 and 7)"
        },
        upgradesTo = "GILDED"
    },
    GILDED = {
        baseName = "Gilded",
        shortCode = "G",
        color = "ff8000",
        currencyID = 3290,
        mythicLevel = 7,
        usage = "Used to upgrade Hero and Myth gear in War Within Season 3 up to item level 723",
        sources = {
            "Mythic Manaforge Omega (10 crests per boss, 15 from last two)",
            "Mythic Keystone Dungeons from +7 and up",
            "Delve's Gilded Stash (Tier 11)",
            "Delver's Bounty (Tier 8 and up)"
        },
        upgradesTo = nil
    }
}

-- Generate CREST_ORDER from CREST_BASE
addon.CREST_ORDER = (function()
    local order = {}
    local current = "WEATHERED"
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
                source = data.source
            }
        end
        return crests
    end)(),
    -- Add Valorstones currency
    VALORSTONES = {
        currencyID = 3008,
        name = "Valorstones",
        shortname = "Valor",
        reallyshortname = "V",
        color = "00ff00",  -- Green color for valorstones
        current = 0,
        needed = 0
    }
}

-- Crest rewards with base values and increments
local CREST_REWARD_BASE = {
    RUNED = {
        base = 10,
        increment = 2
    },
    GILDED = {
        base = 10,
        increment = 2
    }
}

-- Expired keystone deduction
addon.EXPIRED_KEYSTONE_DEDUCTION = 4

-- Generate CREST_REWARDS programmatically
addon.CREST_REWARDS = (function()
    local rewards = {}

    -- Helper function to generate rewards for a specific crest type
    local function generateRewards(crestType, startLevel, endLevel, baseRewards)
        local tier = {}
        for level = startLevel, endLevel do
            tier[level] = {
                timed = baseRewards[level],
                untimed = baseRewards[level] -- In Season 2, timed and untimed rewards are the same
            }
        end
        return tier
    end

    -- Generate Runed crest rewards (levels 2-6)
    rewards.RUNED = generateRewards("RUNED", 2, 6, {
        [2] = 10,
        [3] = 12,
        [4] = 14,
        [5] = 16,
        [6] = 18
    })

    -- Generate Gilded crest rewards (levels 7-12)
    rewards.GILDED = generateRewards("GILDED", 7, 12, {
        [7] = 10,
        [8] = 12,
        [9] = 14,
        [10] = 16,
        [11] = 18,
        [12] = 20
    })

    return rewards
end)()

-- Text position definitions (simplified to TOP/BOTTOM)
addon.TEXT_POSITIONS = {
    -- Primary positions with the background band
    TOP = { point = "TOP", x = 0, y = -3 },         -- Top of icon with band
    BOTTOM = { point = "BOTTOM", x = 0, y = 3 },    -- Bottom of icon with band
    
    -- Legacy positions (mapped to new positions for compatibility)
    TR = { point = "TOP", x = 0, y = -3 },          -- Maps to TOP
    TL = { point = "TOP", x = 0, y = -3 },          -- Maps to TOP
    BR = { point = "BOTTOM", x = 0, y = 3 },        -- Maps to BOTTOM
    BL = { point = "BOTTOM", x = 0, y = 3 },        -- Maps to BOTTOM
    C = { point = "CENTER", x = 0, y = 0 },         -- Center (kept for compatibility)
    
    -- External positions (removed - no longer supported)
}

-- Upgrade track definitions based on crest data
addon.UPGRADE_TRACKS = (function()
    local tracks = {
        EXPLORER = {
            color = "|cFFffffff",
            crest = nil,
            shortname = "Explorer",
            finalCrest = nil,
            upgradeLevels = 8,
            splitUpgrade = {
                firstTier = {
                    crest = nil,
                    shortname = "Explorer",
                    levels = 8
                },
                secondTier = {
                    crest = nil,
                    shortname = "Explorer",
                    levels = 0
                }
            }
        }
    }

    -- Define track configurations
    local trackConfigs = {
        VETERAN = {
            startCrest = "WEATHERED",
            levels = 8,
            splitAt = 4
        },
        CHAMPION = {
            startCrest = "CARVED",
            levels = 8,
            splitAt = 4
        },
        HERO = {
            startCrest = "RUNED",
            levels = 6,
            splitAt = 4
        },
        MYTH = {
            startCrest = "GILDED",
            levels = 6,
            splitAt = 6
        }
    }

    -- Generate tracks from configurations
    for trackName, config in pairs(trackConfigs) do
        local startCrestData = addon.CREST_BASE[config.startCrest]
        local nextCrestType = startCrestData.upgradesTo
        local nextCrestData = nextCrestType and addon.CREST_BASE[nextCrestType]

        tracks[trackName] = {
            color = startCrestData.color,
            crest = startCrestData.baseName .. " " .. startCrestData.shortCode,
            shortname = startCrestData.baseName,
            finalCrest = nextCrestData and (nextCrestData.baseName .. " " .. nextCrestData.shortCode) or
                startCrestData.baseName .. " " .. startCrestData.shortCode,
            upgradeLevels = config.levels,
            splitUpgrade = {
                firstTier = {
                    crest = startCrestData.baseName .. " " .. startCrestData.shortCode,
                    shortname = startCrestData.baseName,
                    levels = config.splitAt
                },
                secondTier = {
                    crest = nextCrestData and (nextCrestData.baseName .. " " .. nextCrestData.shortCode) or nil,
                    shortname = nextCrestData and nextCrestData.baseName or startCrestData.baseName,
                    levels = config.levels - config.splitAt
                }
            }
        }
    end

    return tracks
end)()

-- Raid boss rewards information
addon.RAID_REWARDS = {
    MANAFORGE_OMEGA = {
        name = "Manaforge Omega",
        difficulties = {
            LFR = "WEATHERED",
            NORMAL = "CARVED",
            HEROIC = "RUNED",
            MYTHIC = "GILDED"
        },
        bosses = {
            { name = "First Six Bosses", reward = 10 },
            { name = "Last Two Bosses",  reward = 15 }
        }
    }
}
