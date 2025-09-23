local addonName, addon = ...
addon.f = CreateFrame("Frame") -- Main frame
local f = addon.f

-- Import constants from addon namespace
local CRESTS_TO_UPGRADE = addon.CRESTS_TO_UPGRADE
local CRESTS_CONVERSION_UP = addon.CRESTS_CONVERSION_UP
local SEASONS = addon.SEASONS
local EQUIPMENT_SLOTS = addon.EQUIPMENT_SLOTS
local CREST_REWARDS = addon.CREST_REWARDS
local CURRENCY = addon.CURRENCY
local TEXT_POSITIONS = addon.TEXT_POSITIONS
local CREST_ORDER = addon.CREST_ORDER
local UPGRADE_TRACKS = addon.UPGRADE_TRACKS

-- Cache frequently used functions
local pairs = pairs
local ipairs = ipairs
local tonumber = tonumber
local format = string.format
local floor = math.floor
local ceil = math.ceil
local min = math.min
local max = math.max


-- Optimization: Create a single tooltip frame and reuse it
local tooltipFrame = CreateFrame("GameTooltip", "GearUpgradeTooltip", UIParent, "GameTooltipTemplate")

-- Cache variables with timestamps
local currencyCache = {}
local upgradeCalculationsCache = {
    lastUpdate = 0,
    data = {}
}
local tooltipCache = setmetatable({}, { __mode = "v" })      -- Weak values for tooltip cache
local itemCache = setmetatable({}, { __mode = "v" })         -- Weak values for item cache
local tooltipDataCache = setmetatable({}, { __mode = "kv" }) -- Weak references for tooltip data

-- Reusable table for temporary calculations
local tempTable = {}

-- Optimization: Create object pools for frames and textures
local framePool = CreateFramePool("Frame")
local texturePool = CreateTexturePool()
local fontStringPool = CreateFontStringPool()

-- Object pool for reusable tables
local tablePool = {
    pool = setmetatable({}, { __mode = "k" }),
    acquire = function(self)
        local tbl = next(self.pool) or {}
        self.pool[tbl] = nil
        return tbl
    end,
    release = function(self, tbl)
        if type(tbl) ~= "table" then return end
        wipe(tbl)
        self.pool[tbl] = true
    end
}

-- Create master frame that will contain both displays
local masterFrame = CreateFrame("Button", "GearUpgradeMasterFrame", CharacterFrame, "BackdropTemplate")
masterFrame:SetPoint("TOPRIGHT", CharacterFrame, "BOTTOMRIGHT", 0, 0)
masterFrame:SetSize(addon.MASTER_FRAME_MIN_WIDTH, 100) -- Adjusted size to be more compact
masterFrame:RegisterForClicks("LeftButtonUp", "RightButtonUp")

-- Function to update master frame size
local function updateMasterFrameSize()
    if not currencyFrame then return end

    local padding = addon.FRAME_PADDING
    local titleHeight = titleText and titleText:GetHeight() or 0
    local currencyHeight = currencyFrame:GetHeight()
    local currencyWidth = currencyFrame:GetWidth()

    -- Set master frame size based on content plus padding
    masterFrame:SetSize(
        math.max(addon.MASTER_FRAME_MIN_WIDTH, currencyWidth + padding * 2),
        titleHeight + currencyHeight + padding * 2
    )
end

-- Export the function so it can be called from currency frame
masterFrame.updateFrameSize = updateMasterFrameSize

-- Add a timer to update sizes after text rendering
local function DelayedSizeUpdate()
    C_Timer.After(0.1, function()
        updateMasterFrameSize()
        if addon.updateCrestCurrency then
            addon.updateCrestCurrency(currencyFrame)
        end
    end)
end

masterFrame:SetBackdrop({
    bgFile = "Interface/Buttons/WHITE8x8",
    edgeFile = "Interface/Buttons/WHITE8x8",
    tile = true,
    tileSize = 8,
    edgeSize = 2,
})
masterFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
masterFrame:SetBackdropBorderColor(0, 0, 0, 1)

-- Add click handler for sharing
masterFrame:SetScript("OnClick", function(self, button)
    if button == "LeftButton" then
        shareUpgradeNeeds()
    elseif button == "RightButton" then
        -- Show context menu or additional options
        print("|cFFFFFF00FullyUpgraded:|r Right-click options coming soon!")
    end
end)

-- Add tooltip for master frame
masterFrame:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Fully Upgraded")
    GameTooltip:AddLine("Left-click to share upgrade needs in chat", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Use /fu for more options", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end)

masterFrame:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- Create title text (moved to left)
local titleText = masterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
titleText:SetPoint("TOPLEFT", masterFrame, "TOPLEFT", 8, -5)
titleText:SetText("Fully Upgraded:")
titleText:SetTextColor(1, 1, 0) -- Gold color

-- Create Valorstones display in top right
local valorFrame = CreateFrame("Frame", nil, masterFrame)
valorFrame:SetSize(60, 20)
valorFrame:SetPoint("TOPRIGHT", masterFrame, "TOPRIGHT", -8, -3)

local valorIcon = valorFrame:CreateTexture(nil, "ARTWORK")
valorIcon:SetSize(16, 16)
valorIcon:SetPoint("RIGHT", valorFrame, "RIGHT", 0, 0)

local valorText = valorFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
valorText:SetPoint("RIGHT", valorIcon, "LEFT", -3, 0)
valorText:SetTextColor(0, 1, 0) -- Green for Valorstones
valorText:SetFont(valorText:GetFont(), 11)

-- Make Valorstones frame interactive for tooltip using unified system
valorFrame:EnableMouse(true)
valorFrame:SetScript("OnEnter", function(self)
    local valorData = addon.CURRENCY.VALORSTONES
    if valorData and valorData.currencyID then
        local info = C_CurrencyInfo.GetCurrencyInfo(valorData.currencyID)
        if info then
            addon.showTooltip(self, "ANCHOR_LEFT", addon.tooltipProviders.valorstones, info)
        end
    end
end)

valorFrame:SetScript("OnLeave", addon.hideTooltip)

-- Function to update Valorstones display
local function updateValorstones()
    local valorData = addon.CURRENCY.VALORSTONES
    if valorData and valorData.currencyID then
        local info = C_CurrencyInfo.GetCurrencyInfo(valorData.currencyID)
        if info then
            valorIcon:SetTexture(info.iconFileID)
            valorData.current = info.quantity or 0
            
            -- Display format: current or current/needed if needed > 0
            local displayText = tostring(valorData.current)
            if valorData.needed and valorData.needed > 0 then
                displayText = displayText .. "/" .. valorData.needed
            end
            valorText:SetText(displayText)
            valorFrame:Show()
        else
            valorFrame:Hide()
        end
    else
        valorFrame:Hide()
    end
end

-- Export the update function
addon.updateValorstones = updateValorstones

-- Export shared function to check if character tab is selected (defined early to avoid loading issues)
local function isCharacterTabSelected()
    return PaperDollFrame and PaperDollFrame:IsVisible()
end
addon.isCharacterTabSelected = isCharacterTabSelected

-- Create currency frame for crests only (positioned below the title bar)
local currencyFrame = CreateFrame("Frame", "GearUpgradeCurrencyFrame", masterFrame)
currencyFrame:SetPoint("TOP", masterFrame, "TOP", 0, -25) -- Position below title/valor row
currencyFrame:SetSize(addon.CURRENCY_FRAME_WIDTH, addon.CURRENCY_FRAME_HEIGHT) -- Initial size, will be updated by CrestCurrencyFrame.lua

-- Set up frame update events
currencyFrame:SetScript("OnSizeChanged", updateMasterFrameSize)
C_Timer.After(addon.DELAYED_SIZE_UPDATE_TIME, updateMasterFrameSize) -- Initial size update after everything is created

-- Use shared debug mode from addon namespace

-- Initialize saved variables
local function InitializeSavedVariables()
    if not FullyUpgradedDB then
        FullyUpgradedDB = {
            textPosition = "TR", -- Default position - top right with background
            textVisible = true   -- Default visibility
        }
    end
    -- Ensure the visibility setting exists
    if FullyUpgradedDB.textVisible == nil then
        FullyUpgradedDB.textVisible = true
    end
    currentTextPos = FullyUpgradedDB.textPosition or "TR"
end

-- Function to update text positions with saving
local function updateTextPositions(newPosition)
    if TEXT_POSITIONS[newPosition] then
        currentTextPos = newPosition
        FullyUpgradedDB.textPosition = newPosition

        -- Update all existing texts
        for slot, button in pairs(addon.upgradeTextPool) do
            if button then
                local posData = TEXT_POSITIONS[currentTextPos]
                button:ClearAllPoints()
                button:SetPoint(posData.point, button.slotFrame, posData.point, posData.x, posData.y)
            end
        end
    end
end

-- Export UpdateTextPositions to addon namespace
addon.UpdateTextPositions = updateTextPositions

-- Function to check if currency has changed
local function HasCurrencyChanged()
    local hasChanged = false
    for crestType, crestData in pairs(CURRENCY.CRESTS) do
        if crestData.currencyID then
            local success, info = pcall(C_CurrencyInfo.GetCurrencyInfo, crestData.currencyID)
            if success and info then
                local cachedValue = currencyCache[crestType] and currencyCache[crestType].quantity
                if not cachedValue or cachedValue ~= info.quantity then
                    hasChanged = true
                    break
                end
            end
        end
    end
    return hasChanged
end

-- Check currency for all crests with caching
local function checkCurrencyForAllCrests()
    local hasChanges = false

    for crestType, crestData in pairs(CURRENCY.CRESTS) do
        if crestData.currencyID then
            local success, info = pcall(C_CurrencyInfo.GetCurrencyInfo, crestData.currencyID)
            if success and info then
                -- Check if we need to update the cache
                if not currencyCache[crestType] or
                    currencyCache[crestType].quantity ~= info.quantity or
                    currencyCache[crestType].name ~= info.name then
                    -- Update the cache
                    currencyCache[crestType] = {
                        quantity = info.quantity,
                        name = info.name
                    }

                    -- Update the actual data
                    local oldValue = CURRENCY.CRESTS[crestType].current
                    CURRENCY.CRESTS[crestType].current = info.quantity
                    CURRENCY.CRESTS[crestType].name = info.name

                    if oldValue ~= info.quantity then
                        hasChanges = true
                    end
                end
            end
        end
    end

    return hasChanges
end

-- Function to update frame visibility
local function updateFrameVisibility()
    if isCharacterTabSelected() then
        masterFrame:Show()
    else
        masterFrame:Hide()
    end
end

-- Hook character frame tab changes
CharacterFrame:HookScript("OnShow", updateFrameVisibility)
CharacterFrame:HookScript("OnHide", function() masterFrame:Hide() end)

-- Hook tab changes
hooksecurefunc("ToggleCharacter", updateFrameVisibility)

-- Optimized cache cleanup with reduced frequency
local lastCleanupTime = 0
local function cleanOldCacheEntries()
    local currentTime = GetTime()
    
    -- Only clean caches every 30 seconds (configurable)
    if currentTime - lastCleanupTime < (addon.CACHE_CLEANUP_INTERVAL or 30) then
        return
    end
    lastCleanupTime = currentTime

    -- Clean tooltip cache if it gets too large
    local count = 0
    for k, v in pairs(tooltipCache) do
        count = count + 1
        -- Remove old entries or if cache is too large
        if count > addon.MAX_CACHE_ENTRIES or (currentTime - v.time) > addon.TOOLTIP_CACHE_TTL then
            tooltipCache[k] = nil
        end
    end

    -- Clean item cache if it gets too large
    count = 0
    for k in pairs(itemCache) do
        count = count + 1
        if count > addon.MAX_CACHE_ENTRIES then
            itemCache[k] = nil
        end
    end

    -- Clean currency cache if it gets too large
    count = 0
    for k in pairs(currencyCache) do
        count = count + 1
        if count > addon.MAX_CACHE_ENTRIES then
            currencyCache[k] = nil
        end
    end
end

-- Modify CalculateUpgradedCrests to use table pool
local function calculateUpgradedCrests()
    local currentTime = GetTime()

    -- Check if cache is still valid
    if upgradeCalculationsCache.lastUpdate + addon.CACHE_TIMEOUT > currentTime then
        -- Apply cached values
        for crestType, data in pairs(upgradeCalculationsCache.data) do
            if CURRENCY.CRESTS[crestType] then
                CURRENCY.CRESTS[crestType].upgraded = data.upgraded
            end
        end
        return false -- No changes made
    end

    -- Reset upgraded counts
    for _, crestType in ipairs(CREST_ORDER) do
        if CURRENCY.CRESTS[crestType] then
            CURRENCY.CRESTS[crestType].upgraded = 0
        end
    end

    -- Get a temporary table from the pool
    local tempData = tablePool:acquire()

    -- Calculate upgrades starting from second crest type
    for i = 2, #CREST_ORDER do
        local currentType = CREST_ORDER[i]
        local previousType = CREST_ORDER[i - 1]

        if CURRENCY.CRESTS[currentType] and CURRENCY.CRESTS[previousType] then
            local currentCrest = CURRENCY.CRESTS[currentType]
            local previousCrest = CURRENCY.CRESTS[previousType]

            -- Calculate how many crests can be upgraded from the previous tier
            local upgradedCount = math.floor(previousCrest.current / CRESTS_CONVERSION_UP)
            currentCrest.upgraded = upgradedCount

            -- Store in temp table
            tempData[currentType] = upgradedCount
        end
    end

    -- Update cache all at once
    wipe(upgradeCalculationsCache.data)
    for crestType, upgradedCount in pairs(tempData) do
        upgradeCalculationsCache.data[crestType] = {
            upgraded = upgradedCount
        }
    end

    -- Release the temporary table back to the pool
    tablePool:release(tempData)

    upgradeCalculationsCache.lastUpdate = currentTime
    return true -- Changes made
end

-- Modify UpdateDisplay to include cache cleanup
local function updateDisplay(forceUpdate)
    -- Skip intensive calculations if player is in combat
    if UnitAffectingCombat("player") then
        return
    end
    
    -- Update Valorstones display
    if addon.updateValorstones then
        addon.updateValorstones()
    end

    if isCharacterTabSelected() then
        -- Clean caches periodically
        cleanOldCacheEntries()

        -- Only initialize texts if they don't exist
        if not next(addon.upgradeTextPool) then
            addon.initializeUpgradeTexts()
        end

        local currencyChanged = checkCurrencyForAllCrests()
        local calculationsChanged = false

        -- Only recalculate if currency changed
        if currencyChanged then
            calculationsChanged = calculateUpgradedCrests()
        end

        -- Update displays in coordinated fashion
        -- Force update if requested (e.g., after equipment change) or if currency/calculations changed
        if forceUpdate or currencyChanged or calculationsChanged then
            -- Update upgrade texts on equipment
            if addon.updateAllUpgradeTexts then
                addon.updateAllUpgradeTexts()
            end
            
            -- Update currency display panel
            if addon.updateCrestCurrency and _G["GearUpgradeCurrencyFrame"] then
                addon.updateCrestCurrency(_G["GearUpgradeCurrencyFrame"])
            end
        end

        -- Make sure the currency frame is visible
        if masterFrame then
            masterFrame:Show()
        end
    end
end

-- **Tooltip Setup for Crest Costs**
-- **UNIFIED TOOLTIP SYSTEM**
-- Centralized tooltip management for all addon components

local function showTooltip(owner, anchorPoint, contentProvider, data)
    -- Validate inputs
    if not owner or not owner:IsVisible() then return end
    if not addon.isCharacterTabSelected() then return end
    
    -- Set up tooltip
    GameTooltip:SetOwner(owner, anchorPoint or "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    
    -- Call content provider to populate tooltip
    if contentProvider and type(contentProvider) == "function" then
        contentProvider(data)
    end
    
    GameTooltip:Show()
end

local function hideTooltip()
    GameTooltip:Hide()
end

-- Content providers for different tooltip types
local tooltipProviders = {
    upgrade = function(tooltipInfo)
        if not tooltipInfo then return end

        if tooltipInfo.type == "season1" then
            GameTooltip:AddLine("Season 1 Item")
            GameTooltip:AddLine("This item can no longer be upgraded", 1, 0.2, 0.2)
            return
        end

        if tooltipInfo.type == "fullyUpgraded" then
            GameTooltip:AddLine("Fully Upgraded")
            GameTooltip:AddLine(string.format("%s Track %d/%d",
                    tooltipInfo.trackName,
                    tooltipInfo.currentNum,
                    tooltipInfo.maxNum),
                1, 1, 1)
            return
        end

        if tooltipInfo.type == "upgradeable" then
            GameTooltip:AddLine("Upgrade Requirements:")

            -- Handle split upgrade requirements
            if tooltipInfo.requirements.firstTier or tooltipInfo.requirements.secondTier then
                if tooltipInfo.requirements.firstTier then
                    local req = tooltipInfo.requirements.firstTier
                    local baseData = addon.CREST_BASE[req.crestType]
                    local mythicText = req.mythicLevel > 0 and string.format(" (M%d+)", req.mythicLevel) or ""

                    if CURRENCY.CRESTS[req.crestType] and CURRENCY.CRESTS[req.crestType].currencyID then
                        local currencyID = CURRENCY.CRESTS[req.crestType].currencyID
                        local success, currencyInfo = pcall(C_CurrencyInfo.GetCurrencyInfo, currencyID)
                        if success and currencyInfo then
                            local iconText = CreateTextureMarkup(currencyInfo.iconFileID, 64, 64, 16, 16, 0, 1, 0, 1)
                            local currencyName = currencyInfo.name or (baseData.baseName .. " Crest")
                            GameTooltip:AddLine(string.format("%s %d x |cFF%s%s%s|r",
                                iconText, req.count, baseData.color, currencyName, mythicText))
                        end
                    end
                end

                if tooltipInfo.requirements.secondTier then
                    local req = tooltipInfo.requirements.secondTier
                    local baseData = addon.CREST_BASE[req.crestType]
                    local mythicText = req.mythicLevel > 0 and string.format(" (M%d+)", req.mythicLevel) or ""

                    if CURRENCY.CRESTS[req.crestType] and CURRENCY.CRESTS[req.crestType].currencyID then
                        local currencyID = CURRENCY.CRESTS[req.crestType].currencyID
                        local success, currencyInfo = pcall(C_CurrencyInfo.GetCurrencyInfo, currencyID)
                        if success and currencyInfo then
                            local iconText = CreateTextureMarkup(currencyInfo.iconFileID, 64, 64, 16, 16, 0, 1, 0, 1)
                            local currencyName = currencyInfo.name or (baseData.baseName .. " Crest")
                            GameTooltip:AddLine(string.format("%s %d x |cFF%s%s%s|r",
                                iconText, req.count, baseData.color, currencyName, mythicText))
                        end
                    end
                end
            elseif tooltipInfo.requirements.standard then
                local req = tooltipInfo.requirements.standard
                local baseData = addon.CREST_BASE[req.crestType]
                local mythicText = req.mythicLevel > 0 and string.format(" (M%d+)", req.mythicLevel) or ""

                if CURRENCY.CRESTS[req.crestType] and CURRENCY.CRESTS[req.crestType].currencyID then
                    local currencyID = CURRENCY.CRESTS[req.crestType].currencyID
                    local success, currencyInfo = pcall(C_CurrencyInfo.GetCurrencyInfo, currencyID)
                    if success and currencyInfo then
                        local iconText = CreateTextureMarkup(currencyInfo.iconFileID, 64, 64, 16, 16, 0, 1, 0, 1)
                        local currencyName = currencyInfo.name or (baseData.baseName .. " Crest")
                        GameTooltip:AddLine(string.format("%s %d x |cFF%s%s%s|r",
                            iconText, req.count, baseData.color, currencyName, mythicText))
                    end
                end
            end
        end
    end,
    
    valorstones = function(info)
        if not info then return end
        local valorData = addon.CURRENCY.VALORSTONES
        GameTooltip:AddLine(info.name)
        GameTooltip:AddLine("Current: " .. (info.quantity or 0), 1, 1, 1)
        if valorData.needed and valorData.needed > 0 then
            GameTooltip:AddLine("Needed: " .. valorData.needed, 1, 0.82, 0)
        end
        GameTooltip:AddLine("Maximum: " .. (valorData.cap or 2000), 1, 1, 1)
        
        -- Use sources from Constants.lua
        if valorData.sources then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Sources:", 0.9, 0.7, 0)
            for _, source in ipairs(valorData.sources) do
                GameTooltip:AddLine("• " .. source, 0.8, 0.8, 0.8)
            end
        end
        
        if valorData.usage then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(valorData.usage, 0.8, 0.8, 0.8)
        end
        
        -- Add discount information
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Discount System:", 0.9, 0.7, 0)
        GameTooltip:AddLine("• 50% discount on upgrades if you've obtained", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("  higher ilvl gear in same slot (account-wide)", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("• Crest discounts are character-specific", 0.8, 0.8, 0.8)
    end,
    
    crest = function(data)
        local info, crestData = data.info, data.crestData
        if not info or not crestData then return end
        
        GameTooltip:AddLine(info.name)
        GameTooltip:AddLine("Current: " .. (info.quantity or 0), 1, 1, 1)
        if crestData.needed and crestData.needed > 0 then
            GameTooltip:AddLine("Needed: " .. crestData.needed, 1, 0.82, 0)
        end
        
        -- Add full crest tooltip content (migrated from CrestCurrencyFrame.lua)
        for crestType, baseData in pairs(addon.CREST_BASE) do
            if baseData.shortCode == crestData.reallyshortname then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Sources:", 0.9, 0.7, 0)
                for _, source in ipairs(baseData.sources) do
                    GameTooltip:AddLine("• " .. source, 0.8, 0.8, 0.8)
                end

                -- Add raid rewards section
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Raid Rewards:", 0.9, 0.7, 0)
                for raidName, raidData in pairs(addon.RAID_REWARDS) do
                    for difficulty, rewardType in pairs(raidData.difficulties) do
                        if rewardType == crestType then
                            GameTooltip:AddLine(string.format("%s (%s):", raidData.name, difficulty), 0.9, 0.9, 0.9)
                            local totalCrests = 0
                            for _, boss in ipairs(raidData.bosses) do
                                GameTooltip:AddLine(string.format("• %s: |cFF00FF00%d|r crests", boss.name, boss.reward), 0.8, 0.8, 0.8)
                                if boss.name == "First Six Bosses" then
                                    totalCrests = totalCrests + (boss.reward * 6)
                                else
                                    totalCrests = totalCrests + (boss.reward * 2)
                                end
                            end
                            GameTooltip:AddLine(string.format("Total potential crests: |cFF00FF00%d|r", totalCrests), 0.8, 0.8, 0.8)
                        end
                    end
                end

                -- Add dungeon rewards if this crest type has mythic requirements
                if baseData.mythicLevel and baseData.mythicLevel > 0 then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("Dungeon Rewards:", 0.9, 0.7, 0)
                    
                    local rewards = addon.CREST_REWARDS[crestType]
                    if rewards then
                        local remaining = crestData.needed and math.max(0, crestData.needed - crestData.current - (crestData.upgraded or 0)) or 0

                        for level = baseData.mythicLevel, 20 do
                            if rewards[level] then
                                local rewardAmount = rewards[level].timed
                                local expiredAmount = math.max(0, rewardAmount - addon.EXPIRED_KEYSTONE_DEDUCTION)
                                local runsNeeded = remaining > 0 and math.ceil(remaining / rewardAmount) or 0
                                local expiredRunsNeeded = remaining > 0 and math.ceil(remaining / expiredAmount) or 0

                                local levelText = string.format("|cFF%sM%d|r", baseData.color, level)
                                local rewardText = string.format("|cFF00FF00%d|r", rewardAmount)
                                local runsText = string.format("(%d runs)", runsNeeded)
                                local expiredText = string.format("| Expired: |cFFFF0000%d|r (%d runs)", expiredAmount, expiredRunsNeeded)

                                GameTooltip:AddLine(string.format("%s: %s %s %s", levelText, rewardText, runsText, expiredText), 1, 1, 1, true)
                            end
                        end
                    end
                end
                break
            end
        end
    end
}

-- Process a single upgrade track and update crest and valorstone requirements
local function processUpgradeTrack(track, levelsToUpgrade, current, trackName)
    -- Calculate Valorstone costs
    if addon.VALORSTONE_COSTS and trackName then
        local trackUpper = trackName:upper()
        local trackCosts = addon.VALORSTONE_COSTS[trackUpper]
        if trackCosts then
            local valorstoneCost = 0
            local currentLevel = tonumber(current) or 0
            
            -- Calculate the valorstone cost for the upgrades
            if type(trackCosts.perLevel) == "table" then
                -- Detailed per-level costs available
                -- For an item at 3/6 upgrading to 4/6:
                -- currentLevel = 3, levelsToUpgrade = 1
                -- We need perLevel[3] which is the cost FROM 3 TO 4
                local maxLevel = trackCosts.maxUpgrades or trackCosts.upgradeLevels
                
                for upgradeStep = 0, levelsToUpgrade - 1 do
                    local levelIndex = currentLevel + upgradeStep
                    -- Ensure we don't go past the maximum upgrade level
                    -- For X/6 items: perLevel[1] through perLevel[5] exist
                    -- An item at 5/6 (currentLevel=5) can upgrade to 6/6 using perLevel[5]
                    if levelIndex <= maxLevel and trackCosts.perLevel[levelIndex] then
                        valorstoneCost = valorstoneCost + trackCosts.perLevel[levelIndex]
                        
                        -- Debug output (can be removed later)
                        if addon.debugMode then
                            print(string.format("[FullyUpgraded] %s: Level %d->%d costs %d valorstones", 
                                trackName, levelIndex, levelIndex + 1, trackCosts.perLevel[levelIndex]))
                        end
                    end
                end
            elseif type(trackCosts.perLevel) == "number" then
                -- Average cost per level
                valorstoneCost = trackCosts.perLevel * levelsToUpgrade
            end
            
            -- Apply discount if applicable (placeholder for future implementation)
            -- Note: Detecting account-wide highest item level per slot would require
            -- storing this data or querying WoW's internal systems
            local discountedCost = valorstoneCost
            
            -- TODO: Implement discount detection logic
            -- if hasAccountWideDiscount(slotName, currentItemLevel) then
            --     discountedCost = math.floor(valorstoneCost * addon.VALORSTONE_DISCOUNT.valorstonesDiscount)
            -- end
            
            -- Update Valorstone needed count
            if CURRENCY.VALORSTONES then
                CURRENCY.VALORSTONES.needed = (CURRENCY.VALORSTONES.needed or 0) + discountedCost
                
                if addon.debugMode then
                    if discountedCost ~= valorstoneCost then
                        print(string.format("[FullyUpgraded] %s: Base cost %d, discounted to %d valorstones", 
                            trackName, valorstoneCost, discountedCost))
                    end
                    print(string.format("[FullyUpgraded] Total valorstones needed: %d", CURRENCY.VALORSTONES.needed))
                end
            end
        end
    end
    
    -- Original crest calculation logic
    if not track.crest then
        return CRESTS_TO_UPGRADE * levelsToUpgrade -- Just return the upgrade count for display
    elseif track.splitUpgrade then
        local firstTier = track.splitUpgrade.firstTier
        local secondTier = track.splitUpgrade.secondTier
        local currentLevel = tonumber(current)
        local remainingFirstTier = math.min(levelsToUpgrade, math.max(0, firstTier.levels - currentLevel))
        local remainingSecondTier = math.max(0, levelsToUpgrade - remainingFirstTier)

        if remainingFirstTier > 0 then
            local crestType = firstTier.shortname:upper()
            CURRENCY.CRESTS[crestType].needed = CURRENCY.CRESTS[crestType].needed +
                (remainingFirstTier * CRESTS_TO_UPGRADE)
        end

        if remainingSecondTier > 0 then
            local crestType = secondTier.shortname:upper()
            CURRENCY.CRESTS[crestType].needed = CURRENCY.CRESTS[crestType].needed +
                (remainingSecondTier * CRESTS_TO_UPGRADE)
        end
    else
        -- Original logic for other tracks
        local stdLevelCrestCount = levelsToUpgrade > 2 and
            (levelsToUpgrade - 2) * CRESTS_TO_UPGRADE or 0
        local nextLevelCrestCount = levelsToUpgrade > 2 and (2 * CRESTS_TO_UPGRADE) or
            (levelsToUpgrade * CRESTS_TO_UPGRADE)

        -- Update standard crest counts
        if stdLevelCrestCount > 0 then
            local crestType = track.shortname:upper()
            CURRENCY.CRESTS[crestType].needed = CURRENCY.CRESTS[crestType].needed +
                stdLevelCrestCount
        end

        -- Update final crest counts
        if nextLevelCrestCount > 0 then
            local finalCrestType = ""
            for _, upgradeTrack in pairs(UPGRADE_TRACKS) do
                if upgradeTrack.crest == track.finalCrest then
                    finalCrestType = upgradeTrack.shortname:upper()
                    break
                end
            end
            if finalCrestType ~= "" then
                CURRENCY.CRESTS[finalCrestType].needed = CURRENCY.CRESTS[finalCrestType].needed +
                    nextLevelCrestCount
            end
        end
    end
end

-- Optimization: Cache tooltip data
local function getCachedTooltipData(slotID, itemLink)
    local currentTime = GetTime()
    local cacheKey = itemLink or slotID

    if tooltipCache[cacheKey] and (currentTime - tooltipCache[cacheKey].time) < 1 then
        return tooltipCache[cacheKey].data
    end

    -- Force a tooltip refresh to get the most current data
    tooltipFrame:SetOwner(UIParent, "ANCHOR_NONE")
    tooltipFrame:SetInventoryItem("player", slotID)
    tooltipFrame:Hide()

    -- Get fresh tooltip data
    local data = C_TooltipInfo.GetInventoryItem("player", slotID)

    -- Cache the data
    tooltipCache[cacheKey] = {
        time = currentTime,
        data = data
    }

    return data
end

-- Optimization: Cache item info with error handling
local function getCachedItemInfo(itemLink)
    if not itemCache[itemLink] then
        local success, result = pcall(function()
            return { C_Item.GetItemInfo(itemLink) }
        end)
        if success then
            itemCache[itemLink] = result
        else
            return nil
        end
    end
    return unpack(itemCache[itemLink] or {})
end

-- Function to show crest currency
local function showCrestCurrency()
    if addon.updateCrestCurrency then
        addon.updateCrestCurrency(currencyFrame)
    end
end

-- Export ShowCrestCurrency function
addon.showCrestCurrency = showCrestCurrency

-- Call it initially
C_Timer.After(0.1, showCrestCurrency)

-- Function to share upgrade needs in chat
local function shareUpgradeNeeds()
    -- Check if we have any upgrade needs
    local hasNeeds = false
    local messageParts = {}
    
    -- Build the message with crest needs
    table.insert(messageParts, "My upgrade needs: ")
    
    for _, crestType in ipairs(CREST_ORDER) do
        local crestData = CURRENCY.CRESTS[crestType]
        if crestData and crestData.needed and crestData.needed > 0 then
            local current = crestData.current or 0
            local needed = crestData.needed
            local crestName = addon.CREST_BASE[crestType] and addon.CREST_BASE[crestType].baseName or crestType
            
            if current < needed then
                hasNeeds = true
                table.insert(messageParts, string.format("%s: %d/%d", crestName, current, needed))
            end
        end
    end
    
    if hasNeeds then
        local channel = IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or
                       IsInRaid() and "RAID" or
                       IsInGroup() and "PARTY" or
                       "SAY"
        
        local message = table.concat(messageParts, " | ")
        SendChatMessage(message, channel)
        print("|cFFFFFF00FullyUpgraded:|r Shared upgrade needs in " .. channel)
    else
        print("|cFFFFFF00FullyUpgraded:|r No upgrade needs to share!")
    end
end

-- Export the share function
addon.shareUpgradeNeeds = shareUpgradeNeeds

-- **Event Handling**
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
-- BAG_UPDATE removed - not needed and causes excessive updates
f:RegisterEvent("PLAYER_REGEN_DISABLED")  -- Entering combat
f:RegisterEvent("PLAYER_REGEN_ENABLED")   -- Leaving combat

-- Enhanced throttling with proper debouncing
local lastUpdateTime = 0
local updatePending = false
local UPDATE_THROTTLE = 0.2  -- Minimum time between updates

local function throttledUpdate(forceUpdate)
    local currentTime = GetTime()
    
    -- Don't update if we just updated recently (unless forced)
    if not forceUpdate and currentTime - lastUpdateTime < UPDATE_THROTTLE then
        if not updatePending then
            updatePending = true
            C_Timer.After(UPDATE_THROTTLE, function()
                updatePending = false
                if isCharacterTabSelected() then
                    updateDisplay(true)  -- Force update when delayed
                    lastUpdateTime = GetTime()
                end
            end)
        end
        return
    end
    
    -- Update immediately if enough time has passed or forced
    if isCharacterTabSelected() then
        updateDisplay(forceUpdate)
        lastUpdateTime = currentTime
    end
end

-- Combat state tracking
local inCombat = false

-- Optimized event handler with combat state management
f:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        -- Initialize saved variables first
        InitializeSavedVariables()

        -- Initialize once
        if not addon.initialized then
            -- Ensure CharacterFrame.lua has loaded and exported its functions
            if addon.initializeCharacterFrame then
                addon.initializeCharacterFrame()
            else
                print("[FullyUpgraded] ERROR: initializeCharacterFrame not available yet")
            end
            addon.initialized = true
            updateDisplay()
        end
        updateFrameVisibility()
    elseif event == "PLAYER_LOGIN" then
        if not addon.initialized then
            if addon.initializeCharacterFrame then
                addon.initializeCharacterFrame()
            else
                print("[FullyUpgraded] ERROR: initializeCharacterFrame not available at login")
            end
            addon.initialized = true
            updateDisplay()
        end
        updateFrameVisibility()
    elseif event == "CURRENCY_DISPLAY_UPDATE" then
        -- Only update if not in combat
        if not inCombat then
            throttledUpdate()
        end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        local slotID = ...
        -- Clear tooltip cache for the changed slot
        if slotID then
            tooltipCache[slotID] = nil
            -- Also clear any item link cache for this slot
            local itemLink = GetInventoryItemLink("player", slotID)
            if itemLink then
                tooltipCache[itemLink] = nil
                itemCache[itemLink] = nil
            end
        end
        calculateUpgradedCrests()
        -- Force immediate update for equipment changes
        throttledUpdate(true)
    elseif event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
        -- Hide frames during combat for performance
        if masterFrame then
            masterFrame:Hide()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
        -- Show and update after combat
        if isCharacterTabSelected() then
            if masterFrame then
                masterFrame:Show()
            end
            throttledUpdate()
        end
    end
end)

-- Optimize event registration based on character frame visibility
CharacterFrame:HookScript("OnShow", function()
    -- Re-register events when frame is shown
    f:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
    f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
end)

CharacterFrame:HookScript("OnHide", function()
    -- Unregister expensive events when frame is hidden
    f:UnregisterEvent("CURRENCY_DISPLAY_UPDATE")
    -- Keep PLAYER_EQUIPMENT_CHANGED to track changes while hidden
end)

-- Function to force a currency update
local function forceCurrencyUpdate()
    -- Clear caches to force update
    wipe(currencyCache)
    wipe(upgradeCalculationsCache.data)
    upgradeCalculationsCache.lastUpdate = 0

    checkCurrencyForAllCrests()
    calculateUpgradedCrests()
    if addon.showCrestCurrency then
        addon.showCrestCurrency()
    end

    -- Update display immediately
    if addon.updateAllUpgradeTexts then
        addon.updateAllUpgradeTexts()
    end
end

-- Function to set text visibility
local function setTextVisibility(visible)
    FullyUpgradedDB.textVisible = visible

    -- Update all existing texts
    if addon.SetTextVisibility then
        addon.SetTextVisibility(visible)
    end
    
    -- Force a refresh to show/hide items properly
    if visible and addon.updateAllUpgradeTexts then
        addon.updateAllUpgradeTexts()
    end
end

-- Export SetTextVisibility to addon namespace
addon.SetTextVisibility = setTextVisibility

-- Add slash command handler
SLASH_FULLYUPGRADED1 = "/fullyupgraded"
SLASH_FULLYUPGRADED2 = "/fu"
SlashCmdList["FULLYUPGRADED"] = function(msg)
    local cmd, arg = msg:match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()
    arg = arg:upper()

    if cmd == "textpos" then
        -- Convert argument to uppercase for consistency
        local position = arg and arg:upper() or ""
        
        -- Accept both old and new position names
        if position == "TOP" or position == "T" or position == "TR" or position == "TL" then
            addon.updateTextPositions("TOP")
            print("|cFFFFFF00FullyUpgraded:|r Text position set to TOP")
        elseif position == "BOTTOM" or position == "B" or position == "BR" or position == "BL" then
            addon.updateTextPositions("BOTTOM")
            print("|cFFFFFF00FullyUpgraded:|r Text position set to BOTTOM")
        elseif position == "CENTER" or position == "C" then
            addon.updateTextPositions("C")
            print("|cFFFFFF00FullyUpgraded:|r Text position set to CENTER")
        else
            print("|cFFFFFF00FullyUpgraded:|r Valid positions:")
            print("  TOP (or T) - Display at top of icon with background band")
            print("  BOTTOM (or B) - Display at bottom of icon with background band")
            print("  CENTER (or C) - Display in center of icon")
        end
    elseif cmd == "text" or cmd == "show" or cmd == "hide" then
        if cmd == "hide" then
            setTextVisibility(false)
            print("|cFFFFFF00FullyUpgraded:|r Text hidden")
        elseif cmd == "show" then
            setTextVisibility(true)
            print("|cFFFFFF00FullyUpgraded:|r Text shown")
        else
            -- Toggle current state
            setTextVisibility(not FullyUpgradedDB.textVisible)
            print("|cFFFFFF00FullyUpgraded:|r Text " .. (FullyUpgradedDB.textVisible and "shown" or "hidden"))
        end
    elseif cmd == "refresh" or cmd == "r" then
        print("|cFFFFFF00FullyUpgraded:|r Refreshing upgrade information...")
        updateDisplay()
    elseif cmd == "currency" or cmd == "c" then
        print("|cFFFFFF00FullyUpgraded:|r Refreshing currency information...")
        forceCurrencyUpdate()
    elseif cmd == "share" then
        shareUpgradeNeeds()
    elseif cmd == "colors" then
        print("|cFFFFFF00FullyUpgraded Track Colors:|r")
        for trackName, colorCode in pairs(addon.TRACK_COLORS) do
            print(string.format("  %s: |cFF%s%s|r", trackName, colorCode, trackName))
        end
    elseif cmd == "bg" or cmd == "background" then
        print("|cFFFFFF00FullyUpgraded:|r Dark backgrounds are now shown behind upgrade text for better visibility")
        print("  Background covers the entire gear slot when upgrade text is displayed")
    elseif cmd == "debug" then
        addon.debugMode = not addon.debugMode
        print("|cFFFFFF00FullyUpgraded:|r Debug mode " .. (addon.debugMode and "enabled" or "disabled"))
        if addon.debugMode then
            updateDisplay()
        end
    else
        print("|cFFFFFF00FullyUpgraded commands:|r")
        print("  /fu textpos <position> - Set text position (TOP/BOTTOM/CENTER)")
        print("  /fu show - Show upgrade text")
        print("  /fu hide - Hide upgrade text")
        print("  /fu text - Toggle upgrade text visibility")
        print("  /fu share - Share upgrade needs in chat")
        print("  /fu colors - Display color preview for all track types")
        print("  /fu bg - Information about text backgrounds")
        print("  /fu refresh - Manually refresh upgrade information")
        print("  /fu currency - Manually refresh currency information")
        print("  /fu debug - Toggle debug mode")
    end
end

-- Function to check if an addon is loaded (compatible with all WoW versions)
local function IsAddonLoaded(name)
    -- Try the newer API first
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded(name)
        -- Fall back to the older global function if available
    elseif _G.IsAddOnLoaded then
        return _G.IsAddOnLoaded(name)
    end
    return false
end

-- Register for ADDON_LOADED to hook into the ItemUpgradeFrame when it's available
f:RegisterEvent("ADDON_LOADED")
local itemUpgradeFrameHooked = false

-- Add ADDON_LOADED handling to the existing OnEvent script
local originalOnEvent = f:GetScript("OnEvent")
f:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and not itemUpgradeFrameHooked then
        local loadedAddon = ...
        if loadedAddon == "Blizzard_ItemUpgradeUI" then
            -- The ItemUpgradeFrame hooks are now handled in CharacterFrame.lua
            itemUpgradeFrameHooked = true
        end
    end

    -- Call the original OnEvent handler
    if originalOnEvent then
        originalOnEvent(self, event, ...)
    end
end)

-- Try to hook immediately in case the frame is already loaded
if not itemUpgradeFrameHooked and IsAddonLoaded("Blizzard_ItemUpgradeUI") then
    -- The ItemUpgradeFrame hooks are now handled in CharacterFrame.lua
    itemUpgradeFrameHooked = true
end

-- Modify CleanupAddon to be more thorough
local function CleanupAddon()
    wipe(tooltipCache)
    wipe(itemCache)
    wipe(currencyCache)
    wipe(upgradeCalculationsCache.data)
    wipe(tooltipDataCache)
    framePool:ReleaseAll()
    texturePool:ReleaseAll()
    fontStringPool:ReleaseAll()

    -- Force a garbage collection after cleanup
    collectgarbage("collect")
end

-- Register cleanup function
f:SetScript("OnDisable", CleanupAddon)

-- Get the current season's item level range
local function getCurrentSeasonItemLevelRange()
    return SEASONS[3].MIN_ILVL, SEASONS[3].MAX_ILVL
end

-- Define Debug function
local function Debug(message)
    if addon.debugMode then
        print(string.format("[FullyUpgraded] %s", message))
    end
end

-- Export functions to addon namespace
addon.Debug = Debug
addon.updateDisplay = updateDisplay
-- Export unified tooltip system
addon.showTooltip = showTooltip
addon.hideTooltip = hideTooltip
addon.tooltipProviders = tooltipProviders
-- Legacy compatibility (deprecated)
addon.setUpgradeTooltip = function(self, tooltipInfo) tooltipProviders.upgrade(tooltipInfo) end
addon.processUpgradeTrack = processUpgradeTrack
addon.getCachedTooltipData = getCachedTooltipData
addon.getCachedItemInfo = getCachedItemInfo
addon.calculateUpgradedCrests = calculateUpgradedCrests
addon.checkCurrencyForAllCrests = checkCurrencyForAllCrests
addon.getCurrentSeasonItemLevelRange = getCurrentSeasonItemLevelRange
addon.forceCurrencyUpdate = forceCurrencyUpdate

-- Character frame initialization will happen via events, not here
print("[FullyUpgraded] FullyUpgraded.lua loaded, waiting for game events to initialize")
