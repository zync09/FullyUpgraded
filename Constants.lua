local addonName, addon = ...

-- Base upgrade constants
addon.CRESTS_TO_UPGRADE = 15
addon.CRESTS_CONVERSION_UP = 45

-- Season item level ranges
addon.SEASONS = {
    [1] = {
        MIN_ILVL = 584,
        MAX_ILVL = 639
    },
    [2] = {
        MIN_ILVL = 597,
        MAX_ILVL = 678
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
        currencyID = 3107,
        mythicLevel = 0,
        usage = "Used to upgrade Adventurer and Veteran gear in War Within Season 2 up to item level 623-632",
        sources = {
            "Repeatable Outdoor Events",
            "Raid Finder Liberation of Undermine (10 crests per boss, 15 from last two)",
            "Heroic Season Dungeons",
            "Delves (Tiers 1 to 5)"
        },
        upgradesTo = "CARVED"
    },
    CARVED = {
        baseName = "Carved",
        shortCode = "C",
        color = "006bee",
        currencyID = 3108,
        mythicLevel = 0,
        usage = "Used to upgrade Veteran and Champion gear in War Within Season 2 up to item level 636-645",
        sources = {
            "Weekly Random Events",
            "Normal Liberation of Undermine (10 crests per boss, 15 from last two)",
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
        currencyID = 3109,
        mythicLevel = 2,
        usage = "Used to upgrade Champion and Hero gear in War Within Season 2 up to item level 649-658",
        sources = {
            "Heroic Liberation of Undermine (10 crests per boss, 15 from last two)",
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
        currencyID = 3110,
        mythicLevel = 7,
        usage = "Used to upgrade Hero and Myth gear in War Within Season 2 up to item levels 662 and above",
        sources = {
            "Mythic Liberation of Undermine (10 crests per boss, 15 from last two)",
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
    end)()
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

-- Text position definitions
addon.TEXT_POSITIONS = {
    TR = { point = "TOPRIGHT", x = 6, y = 2 },
    TL = { point = "TOPLEFT", x = -6, y = 2 },
    BR = { point = "BOTTOMRIGHT", x = 6, y = -2 },
    BL = { point = "BOTTOMLEFT", x = -6, y = -2 },
    C = { point = "CENTER", x = 0, y = 0 },
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
    LIBERATION_OF_UNDERMINE = {
        name = "Liberation of Undermine",
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
