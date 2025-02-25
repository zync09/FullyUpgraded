local addonName, addon = ...

-- Upgrade constants
addon.CRESTS_TO_UPGRADE = 15
addon.CRESTS_CONVERSION_UP = 45

-- Season item level ranges
addon.SEASONS = {
    [1] = {
        MIN_ILVL = 584,
        MAX_ILVL = 639
    },
    [2] = {
        MIN_ILVL = 623,
        MAX_ILVL = 678
    }
}

-- Equipment slots to track
addon.EQUIPMENT_SLOTS = {
    "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot",
    "WristSlot", "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot",
    "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot",
    "MainHandSlot", "SecondaryHandSlot"
}

-- Crest rewards by mythic level
addon.CREST_REWARDS = {
    CARVED = {
        [2] = {
            timed = 12,
            untimed = 8
        },
        [3] = {
            timed = 14,
            untimed = 10
        }
    },
    RUNED = {
        [4] = {
            timed = 12,
            untimed = 8
        },
        [5] = {
            timed = 14,
            untimed = 10
        },
        [6] = {
            timed = 16,
            untimed = 12
        },
        [7] = {
            timed = 18,
            untimed = 14
        },
    },
    GILDED = {
        [8] = {
            timed = 12,
            untimed = 8
        },
        [9] = {
            timed = 14,
            untimed = 10
        },
        [10] = {
            timed = 16,
            untimed = 12
        },
        [11] = {
            timed = 18,
            untimed = 14
        },
        [12] = {
            timed = 20,
            untimed = 16
        },
    }
}

-- Currency definitions
addon.CURRENCY = {
    CRESTS = {
        WEATHERED = {
            name = "Weathered Harbinger Crest",
            shortname = "Weathered",
            reallyshortname = "W",
            current = 0,
            needed = 0,
            upgraded = 0,
            mythicLevel = 0,
            upgradesTo = "CARVED",
            currencyID = 2914,
            source = "Dropped by raid bosses on LFR difficulty"
        },
        CARVED = {
            name = "Carved Harbinger Crest",
            shortname = "Carved",
            reallyshortname = "C",
            current = 0,
            needed = 0,
            upgraded = 0,
            mythicLevel = 2,
            upgradesTo = "RUNED",
            currencyID = 2915,
            source = "Dropped by raid bosses on Normal difficulty"
        },
        RUNED = {
            name = "Runed Harbinger Crest",
            shortname = "Runed",
            reallyshortname = "R",
            current = 0,
            needed = 0,
            upgraded = 0,
            mythicLevel = 4,
            upgradesTo = "GILDED",
            currencyID = 2916,
            source = "Dropped by raid bosses on Heroic difficulty"
        },
        GILDED = {
            name = "Gilded Harbinger Crest",
            shortname = "Gilded",
            reallyshortname = "G",
            current = 0,
            needed = 0,
            upgraded = 0,
            mythicLevel = 8,
            upgradesTo = nil,
            currencyID = 2917,
            source = "Dropped by raid bosses on Mythic difficulty"
        }
    }
}

-- Text position definitions
addon.TEXT_POSITIONS = {
    TR = { point = "TOPRIGHT", x = 6, y = 2 },
    TL = { point = "TOPLEFT", x = -6, y = 2 },
    BR = { point = "BOTTOMRIGHT", x = 6, y = -2 },
    BL = { point = "BOTTOMLEFT", x = -6, y = -2 },
    C = { point = "CENTER", x = 0, y = 0 },
}

-- Ordered list of crest types from lowest to highest tier
addon.CREST_ORDER = { "WEATHERED", "CARVED", "RUNED", "GILDED" }

-- Upgrade track definitions
addon.UPGRADE_TRACKS = {
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
    },
    VETERAN  = {
        color = "FF1eff00",
        crest = "Weathered Harbinger Crest",
        shortname = "Weathered",
        finalCrest = "Carved Harbinger Crest",
        upgradeLevels = 8,
        splitUpgrade = {
            firstTier = {
                crest = "Weathered Harbinger Crest",
                shortname = "Weathered",
                levels = 4
            },
            secondTier = {
                crest = "Carved Harbinger Crest",
                shortname = "Carved",
                levels = 4
            }
        }
    },
    CHAMPION = {
        color = "FF0070dd",
        crest = "Carved Harbinger Crest",
        shortname = "Carved",
        finalCrest = "Runed Harbinger Crest",
        upgradeLevels = 8,
        splitUpgrade = {
            firstTier = {
                crest = "Carved Harbinger Crest",
                shortname = "Carved",
                levels = 4
            },
            secondTier = {
                crest = "Runed Harbinger Crest",
                shortname = "Runed",
                levels = 4
            }
        }
    },
    HERO     = {
        color = "FFa335ee",
        crest = "Runed Harbinger Crest",
        shortname = "Runed",
        finalCrest = "Gilded Harbinger Crest",
        upgradeLevels = 6,
        splitUpgrade = {
            firstTier = {
                crest = "Runed Harbinger Crest",
                shortname = "Runed",
                levels = 4
            },
            secondTier = {
                crest = "Gilded Harbinger Crest",
                shortname = "Gilded",
                levels = 2
            }
        }
    },
    MYTH     = {
        color = "FFff8000",
        crest = "Gilded Harbinger Crest",
        shortname = "Gilded",
        finalCrest = "Gilded Harbinger Crest",
        upgradeLevels = 6,
        splitUpgrade = {
            firstTier = {
                crest = "Gilded Harbinger Crest",
                shortname = "Gilded",
                levels = 6
            },
            secondTier = {
                crest = "Gilded Harbinger Crest",
                shortname = "Gilded",
                levels = 0
            }
        }
    }
} 