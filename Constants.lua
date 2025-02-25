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
        MIN_ILVL = 619,
        MAX_ILVL = 678
    }
}

-- Equipment slots organized by category
local SLOT_CATEGORIES = {
    armor = {"Head", "Shoulder", "Chest", "Wrist", "Hands", "Waist", "Legs", "Feet"},
    accessories = {"Neck", "Back", "Finger0", "Finger1", "Trinket0", "Trinket1"},
    weapons = {"MainHand", "SecondaryHand"}
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

-- Base crest definitions
addon.CREST_BASE = {
    WEATHERED = {
        baseName = "Weathered",
        suffix = "Harbinger Crest",
        shortCode = "W",
        color = "FF1eff00",
        currencyID = 2914,
        mythicLevel = 0,
        source = "Dropped by raid bosses on LFR difficulty",
        upgradesTo = "CARVED"
    },
    CARVED = {
        baseName = "Carved",
        suffix = "Harbinger Crest",
        shortCode = "C",
        color = "FF0070dd",
        currencyID = 2915,
        mythicLevel = 2,
        source = "Dropped by raid bosses on Normal difficulty",
        upgradesTo = "RUNED"
    },
    RUNED = {
        baseName = "Runed",
        suffix = "Harbinger Crest",
        shortCode = "R",
        color = "FFa335ee",
        currencyID = 2916,
        mythicLevel = 4,
        source = "Dropped by raid bosses on Heroic difficulty",
        upgradesTo = "GILDED"
    },
    GILDED = {
        baseName = "Gilded",
        suffix = "Harbinger Crest",
        shortCode = "G",
        color = "FFff8000",
        currencyID = 2917,
        mythicLevel = 8,
        source = "Dropped by raid bosses on Mythic difficulty",
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
            crests[crestType] = {
                name = data.baseName .. " " .. data.suffix,
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
    base = {
        timed = 12,
        untimed = 8
    },
    increment = {
        timed = 2,
        untimed = 2
    }
}

-- Generate CREST_REWARDS programmatically
addon.CREST_REWARDS = (function()
    local rewards = {}
    local function generateTierRewards(startLevel, count)
        local tier = {}
        for i = 0, count - 1 do
            local level = startLevel + i
            tier[level] = {
                timed = CREST_REWARD_BASE.base.timed + 
                    (i * CREST_REWARD_BASE.increment.timed),
                untimed = CREST_REWARD_BASE.base.untimed + 
                    (i * CREST_REWARD_BASE.increment.untimed)
            }
        end
        return tier
    end
    
    rewards.CARVED = generateTierRewards(2, 2)   -- Levels 2-3
    rewards.RUNED = generateTierRewards(4, 4)    -- Levels 4-7
    rewards.GILDED = generateTierRewards(8, 5)   -- Levels 8-12
    
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
            color = "FFffffff",
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
            crest = startCrestData.baseName .. " " .. startCrestData.suffix,
            shortname = startCrestData.baseName,
            finalCrest = nextCrestData and (nextCrestData.baseName .. " " .. nextCrestData.suffix) or startCrestData.baseName .. " " .. startCrestData.suffix,
            upgradeLevels = config.levels,
            splitUpgrade = {
                firstTier = {
                    crest = startCrestData.baseName .. " " .. startCrestData.suffix,
                    shortname = startCrestData.baseName,
                    levels = config.splitAt
                },
                secondTier = {
                    crest = nextCrestData and (nextCrestData.baseName .. " " .. nextCrestData.suffix) or nil,
                    shortname = nextCrestData and nextCrestData.baseName or startCrestData.baseName,
                    levels = config.levels - config.splitAt
                }
            }
        }
    end
    
    return tracks
end)() 