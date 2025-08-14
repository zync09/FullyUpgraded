local addonName, addon = ...
addon.Data = {}
local Data = addon.Data

-- Constants
local CRESTS_PER_UPGRADE = 15
local SEASON2_MIN_ILVL = 597
local SEASON2_MAX_ILVL = 639

-- Upgrade tracks with crest requirements
local UPGRADE_TRACKS = {
    -- Explorer (597-613)
    ["Explorer"] = {
        minLevel = 1,
        maxLevel = 8,
        baseCrest = "WEATHERED"
    },
    -- Adventurer (613-629)
    ["Adventurer"] = {
        minLevel = 1,
        maxLevel = 8,
        baseCrest = "CARVED"
    },
    -- Champion (626-639)
    ["Champion"] = {
        minLevel = 1,
        maxLevel = 8,
        baseCrest = "RUNED",
        splitUpgrade = {
            firstTier = { levels = 6, crest = "RUNED" },
            secondTier = { levels = 2, crest = "GILDED" }
        }
    },
    -- Veteran (626-639)
    ["Veteran"] = {
        minLevel = 1,
        maxLevel = 8,
        baseCrest = "CARVED",
        splitUpgrade = {
            firstTier = { levels = 6, crest = "CARVED" },
            secondTier = { levels = 2, crest = "RUNED" }
        }
    },
    -- Hero (639-652)
    ["Hero"] = {
        minLevel = 1,
        maxLevel = 6,
        baseCrest = "GILDED"
    },
    -- Myth (652-658)
    ["Myth"] = {
        minLevel = 1,
        maxLevel = 4,
        baseCrest = "GILDED"
    }
}

-- Crest types
local CREST_TYPES = {
    WEATHERED = { name = "Weathered", order = 1, currencyID = 3191 },
    CARVED = { name = "Carved", order = 2, currencyID = 3192 },
    RUNED = { name = "Runed", order = 3, currencyID = 3193 },
    GILDED = { name = "Gilded", order = 4, currencyID = 3194 }
}

-- Equipment slots
local EQUIPMENT_SLOTS = {
    "HeadSlot", "ShoulderSlot", "ChestSlot", "WristSlot",
    "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot",
    "NeckSlot", "BackSlot", "Finger0Slot", "Finger1Slot",
    "Trinket0Slot", "Trinket1Slot", "MainHandSlot", "SecondaryHandSlot"
}

-- Cache for item upgrade data
local itemCache = {}
local lastScanTime = 0
local SCAN_THROTTLE = 0.5 -- Minimum time between full scans

-- Get upgrade info for an item
local function GetItemUpgradeInfo(itemLink)
    if not itemLink then return nil end
    
    -- Check cache first
    if itemCache[itemLink] then
        return itemCache[itemLink]
    end
    
    -- Get item info
    local itemInfo = C_TooltipInfo.GetHyperlink(itemLink)
    if not itemInfo then 
        return nil 
    end
    
    local upgradeInfo = {
        isUpgradeable = false,
        currentLevel = 0,
        maxLevel = 0,
        track = nil,
        remainingUpgrades = 0
    }
    
    -- Parse tooltip lines for upgrade info
    for _, line in ipairs(itemInfo.lines) do
        if line.leftText then
            local text = line.leftText
            
            -- Check for upgrade track and level (e.g., "Upgrade Level: Hero 6/8")
            local track, current, max = text:match("^Upgrade Level:%s*(%w+)%s+(%d+)/(%d+)$")
            if track and UPGRADE_TRACKS[track] then
                upgradeInfo.isUpgradeable = true
                upgradeInfo.track = track
                upgradeInfo.currentLevel = tonumber(current)
                upgradeInfo.maxLevel = tonumber(max)
                upgradeInfo.remainingUpgrades = upgradeInfo.maxLevel - upgradeInfo.currentLevel
                break
            end
        end
    end
    
    -- Cache the result
    itemCache[itemLink] = upgradeInfo
    return upgradeInfo
end

-- Calculate crest requirements for an item
local function CalculateCrestRequirements(upgradeInfo)
    if not upgradeInfo or not upgradeInfo.isUpgradeable or upgradeInfo.remainingUpgrades <= 0 then
        return nil
    end
    
    local track = UPGRADE_TRACKS[upgradeInfo.track]
    if not track then return nil end
    
    local requirements = {}
    local remainingUpgrades = upgradeInfo.remainingUpgrades
    local currentLevel = upgradeInfo.currentLevel
    
    if track.splitUpgrade then
        -- Handle split upgrades (Champion/Veteran tracks)
        local split = track.splitUpgrade
        local firstTierRemaining = math.max(0, split.firstTier.levels - currentLevel)
        local secondTierNeeded = math.max(0, remainingUpgrades - firstTierRemaining)
        
        if firstTierRemaining > 0 then
            requirements[split.firstTier.crest] = math.min(firstTierRemaining, remainingUpgrades) * CRESTS_PER_UPGRADE
        end
        
        if secondTierNeeded > 0 then
            requirements[split.secondTier.crest] = secondTierNeeded * CRESTS_PER_UPGRADE
        end
    else
        -- Simple single crest type
        requirements[track.baseCrest] = remainingUpgrades * CRESTS_PER_UPGRADE
    end
    
    return requirements
end

-- Initialize the data module
function Data:Initialize()
    -- Clear cache on init
    wipe(itemCache)
end

-- Scan all equipment
function Data:ScanEquipment()
    local currentTime = GetTime()
    if currentTime - lastScanTime < SCAN_THROTTLE then
        return -- Too soon since last scan
    end
    
    lastScanTime = currentTime
    local equipmentData = {}
    local totalCrestNeeds = {}
    local upgradeableCount = 0
    
    -- Initialize crest needs
    for crestType in pairs(CREST_TYPES) do
        totalCrestNeeds[crestType] = 0
    end
    
    -- Scan each slot
    for _, slot in ipairs(EQUIPMENT_SLOTS) do
        local slotId = GetInventorySlotInfo(slot)
        local itemLink = GetInventoryItemLink("player", slotId)
        
        if itemLink then
            
            local upgradeInfo = GetItemUpgradeInfo(itemLink)
            
            if upgradeInfo and upgradeInfo.isUpgradeable then
                upgradeableCount = upgradeableCount + 1
                
                -- Calculate crest requirements
                local crestReqs = CalculateCrestRequirements(upgradeInfo)
                
                if crestReqs then
                    for crestType, amount in pairs(crestReqs) do
                        totalCrestNeeds[crestType] = totalCrestNeeds[crestType] + amount
                    end
                end
                
                equipmentData[slot] = {
                    itemLink = itemLink,
                    upgradeInfo = upgradeInfo,
                    crestRequirements = crestReqs
                }
            end
        end
    end
    
    
    -- Store results
    self.equipmentData = equipmentData
    self.totalCrestNeeds = totalCrestNeeds
    
    -- Notify currency module of updated needs
    if addon.Currency then
        addon.Currency:SetCrestNeeds(totalCrestNeeds)
    end
end

-- Get upgrade info for a specific slot
function Data:GetSlotInfo(slot)
    if not self.equipmentData then
        return nil
    end
    return self.equipmentData[slot]
end

-- Get total crest needs
function Data:GetTotalCrestNeeds()
    return self.totalCrestNeeds or {}
end

-- Clear cache (called on equipment change)
function Data:ClearCache()
    wipe(itemCache)
end

-- Export constants for other modules
addon.CREST_TYPES = CREST_TYPES
addon.EQUIPMENT_SLOTS = EQUIPMENT_SLOTS
addon.CRESTS_PER_UPGRADE = CRESTS_PER_UPGRADE