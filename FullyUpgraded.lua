local addonName, addon = ...
local f = CreateFrame("Frame") -- Main event frame

-- Import constants from addon namespace
local CRESTS_TO_UPGRADE = addon.CRESTS_TO_UPGRADE
local CRESTS_CONVERSION_UP = addon.CRESTS_CONVERSION_UP
local SEASONS = addon.SEASONS
local CURRENCY = addon.CURRENCY
local CREST_ORDER = addon.CREST_ORDER

addon.seasonGearCount = 0

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

-- Forward declarations (needed so handlers can reference functions defined later)
local currencyFrame
local titleText
local shareUpgradeNeeds

-- Create master frame that will contain the display
local masterFrame = CreateFrame("Frame", "GearUpgradeMasterFrame", CharacterFrame, "BackdropTemplate")
masterFrame:SetPoint("TOPRIGHT", CharacterFrame, "BOTTOMRIGHT", 0, 0)
masterFrame:SetSize(addon.MASTER_FRAME_MIN_WIDTH, 100)
masterFrame:EnableMouse(true)

-- Function to update master frame size
local function updateMasterFrameSize()
    if not currencyFrame then return end

    local padding = addon.FRAME_PADDING
    local titleHeight = titleText and titleText:GetHeight() or 0
    local progressBarHeight = 5 -- 3px bar + 2px gap
    local currencyHeight = currencyFrame:GetHeight()
    local currencyWidth = currencyFrame:GetWidth()

    -- Set master frame size based on content plus padding
    masterFrame:SetSize(
        math.max(addon.MASTER_FRAME_MIN_WIDTH, currencyWidth + padding * 2),
        titleHeight + progressBarHeight + currencyHeight + padding
    )
end

-- Export the function so it can be called from currency frame
masterFrame.updateFrameSize = updateMasterFrameSize

masterFrame:SetBackdrop({
    bgFile = "Interface/Buttons/WHITE8x8",
    edgeFile = "Interface/Buttons/WHITE8x8",
    tile = true,
    tileSize = 8,
    edgeSize = 2,
})
masterFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
masterFrame:SetBackdropBorderColor(0, 0, 0, 1)

-- Add click handler for sharing and options
masterFrame:SetScript("OnMouseUp", function(self, button)
    if button == "LeftButton" then
        shareUpgradeNeeds()
    elseif button == "RightButton" then
        if not masterFrame.optionsFrame and addon.CreateOptionsFrame then
            masterFrame.optionsFrame = addon.CreateOptionsFrame(masterFrame)
        end
        if masterFrame.optionsFrame then
            if masterFrame.optionsFrame:IsShown() then
                masterFrame.optionsFrame:Hide()
            else
                masterFrame.optionsFrame:Show()
            end
        end
    end
end)

-- Master frame tooltip set up after tooltipProviders is defined (see below)

-- Create title text
titleText = masterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
titleText:SetPoint("TOPLEFT", masterFrame, "TOPLEFT", 8, -5)
titleText:SetText("Fully Upgraded:")
titleText:SetTextColor(1, 1, 0) -- Gold color

-- Export titleText to addon namespace for updates
addon.titleText = titleText

-- Create progress bar under title
local progressBar = CreateFrame("Frame", nil, masterFrame)
progressBar:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -2)
progressBar:SetPoint("RIGHT", masterFrame, "RIGHT", -8, 0)
progressBar:SetHeight(3)

local progressBg = progressBar:CreateTexture(nil, "BACKGROUND")
progressBg:SetAllPoints()
progressBg:SetColorTexture(0.2, 0.2, 0.2, 0.8)

local progressFill = progressBar:CreateTexture(nil, "ARTWORK")
progressFill:SetPoint("TOPLEFT")
progressFill:SetPoint("BOTTOMLEFT")
progressFill:SetHeight(3)
progressFill:SetColorTexture(1, 0.82, 0, 1) -- Gold

addon.progressBar = progressBar
addon.progressFill = progressFill
progressBar:Hide()

-- Export shared function to check if character tab is selected
local function isCharacterTabSelected()
    return PaperDollFrame and PaperDollFrame:IsVisible()
end
addon.isCharacterTabSelected = isCharacterTabSelected

-- Create currency frame for crests (positioned below the title bar)
currencyFrame = CreateFrame("Frame", "GearUpgradeCurrencyFrame", masterFrame)
currencyFrame:SetPoint("TOP", masterFrame, "TOP", 0, -30)
currencyFrame:SetSize(addon.CURRENCY_FRAME_WIDTH, addon.CURRENCY_FRAME_HEIGHT)

-- Set up frame update events
currencyFrame:SetScript("OnSizeChanged", updateMasterFrameSize)
C_Timer.After(addon.DELAYED_SIZE_UPDATE_TIME, updateMasterFrameSize)

-- Initialize saved variables
local function InitializeSavedVariables()
    if not FullyUpgradedDB then
        FullyUpgradedDB = {
            textPosition = "TOP",
            textVisible = true
        }
    end
    if FullyUpgradedDB.textVisible == nil then
        FullyUpgradedDB.textVisible = true
    end
end

-- UpdateTextPositions delegates to CharacterFrame's version which handles
-- repositioning, background strips, and re-rendering equipment slots.
-- Set as a late-binding wrapper since CharacterFrame.lua loads after this file.
addon.UpdateTextPositions = function(newPosition)
    if addon.updateTextPositions then
        addon.updateTextPositions(newPosition)
    end
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

    -- Only clean caches every 30 seconds
    if currentTime - lastCleanupTime < addon.CACHE_CLEANUP_INTERVAL then
        return
    end
    lastCleanupTime = currentTime

    -- Clean tooltip cache if it gets too large
    local count = 0
    for k, v in pairs(tooltipCache) do
        count = count + 1
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

-- Calculate crest conversions
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
        if upgradeCalculationsCache.totalUpgrades then
            addon.totalUpgrades = upgradeCalculationsCache.totalUpgrades
        end
        return false
    end

    -- Reset upgraded counts and total upgrades
    for _, crestType in ipairs(CREST_ORDER) do
        if CURRENCY.CRESTS[crestType] then
            CURRENCY.CRESTS[crestType].upgraded = 0
        end
    end
    addon.totalUpgrades = 0

    local tempData = {}

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

    -- Store total upgrades in cache
    upgradeCalculationsCache.totalUpgrades = addon.totalUpgrades or 0
    upgradeCalculationsCache.lastUpdate = currentTime
    return true
end

-- Main update display function
local function updateDisplay(forceUpdate)
    -- Skip intensive calculations if player is in combat
    if UnitAffectingCombat("player") then
        return
    end

    if isCharacterTabSelected() then
        -- Clean caches periodically
        cleanOldCacheEntries()

        -- Only initialize texts if they don't exist
        if not next(addon.upgradeTextPool) then
            addon.initializeUpgradeTexts()
        end

        local currencyChanged = checkCurrencyForAllCrests()
        local calculationsChanged = calculateUpgradedCrests()

        -- Update displays if needed
        if forceUpdate or currencyChanged or calculationsChanged then
            -- Update upgrade texts on equipment
            if addon.updateAllUpgradeTexts then
                addon.updateAllUpgradeTexts()
            end

            -- Update currency display panel
            if addon.updateCrestCurrency and currencyFrame then
                addon.updateCrestCurrency(currencyFrame)
            end
        end

        -- Make sure the currency frame is visible
        if masterFrame then
            masterFrame:Show()
        end
    end
end

-- **UNIFIED TOOLTIP SYSTEM**
local function setTooltipBackdropColor(r, g, b, a)
    if GameTooltip.NineSlice then
        for _, region in pairs({GameTooltip.NineSlice:GetRegions()}) do
            if region:IsObjectType("Texture") then
                region:SetVertexColor(r, g, b, a)
            end
        end
    end
    if GameTooltip.SetBackdropColor then
        GameTooltip:SetBackdropColor(r, g, b, a)
    end
end

local function showTooltip(owner, anchorPoint, contentProvider, data)
    if not owner or not owner:IsVisible() then return end
    if not addon.isCharacterTabSelected() then return end

    GameTooltip:SetOwner(owner, anchorPoint or "ANCHOR_RIGHT")
    GameTooltip:ClearLines()

    if contentProvider and type(contentProvider) == "function" then
        contentProvider(data)
    end

    GameTooltip:Show()
    setTooltipBackdropColor(0.05, 0.05, 0.05, 0.95)
end

local function hideTooltip()
    GameTooltip:Hide()
    setTooltipBackdropColor(0.09, 0.09, 0.09, 1)
end

-- Content providers for different tooltip types
local tooltipProviders = {
    upgrade = function(tooltipInfo)
        if not tooltipInfo then return end

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

            -- Show primary crest line (full cost using track's own crest type)
            if tooltipInfo.requirements.standard then
                local req = tooltipInfo.requirements.standard
                local baseData = addon.CREST_BASE[req.crestType]
                local mythicText = req.mythicLevel > 0 and string.format(" (M%d+)", req.mythicLevel) or ""

                if CURRENCY.CRESTS[req.crestType] and CURRENCY.CRESTS[req.crestType].currencyID then
                    local currencyID = CURRENCY.CRESTS[req.crestType].currencyID
                    local success, currencyInfo = pcall(C_CurrencyInfo.GetCurrencyInfo, currencyID)
                    if success and currencyInfo then
                        local iconText = CreateTextureMarkup(currencyInfo.iconFileID, 64, 64, 16, 16, 0, 1, 0, 1)
                        local currencyName = currencyInfo.name or (baseData.baseName .. " Dawncrest")
                        GameTooltip:AddLine(string.format("%s %d x |cFF%s%s%s|r",
                            iconText, req.count, baseData.color, currencyName, mythicText))
                    end
                end


            end
        end
    end,

    crest = function(data)
        local info, crestData = data.info, data.crestData
        if not info or not crestData then return end

        GameTooltip:AddLine(info.name)
        GameTooltip:AddLine("Current: " .. (info.quantity or 0), 1, 1, 1)
        local weeklyCap = (info.maxWeeklyQuantity and info.maxWeeklyQuantity > 0) and info.maxWeeklyQuantity or (crestData.weeklyCap or 100)
        GameTooltip:AddLine("Weekly Cap: " .. weeklyCap, 0.8, 0.8, 0.8)

        if crestData.needed and crestData.needed > 0 then
            GameTooltip:AddLine("Needed: " .. crestData.needed, 1, 0.82, 0)
        end

        -- Season maximum
        local totalEarned = info.totalEarned or info.quantity or 0
        local seasonMax = info.maxQuantity or 0
        if seasonMax > 0 then
            GameTooltip:AddLine(string.format("Season: %d / %d", totalEarned, seasonMax), 0.6, 0.8, 1)
        end

        -- Excess crest indicator with conversion potential
        local excess = math.max(0, (info.quantity or 0) - (crestData.needed or 0))
        if excess > 0 then
            local crestType = addon.CREST_BY_SHORTCODE[crestData.reallyshortname]
            local baseData = crestType and addon.CREST_BASE[crestType]
            if baseData and baseData.upgradesTo then
                local nextTier = addon.CREST_BASE[baseData.upgradesTo]
                local convertible = math.floor(excess / addon.CRESTS_CONVERSION_UP)
                if nextTier and convertible > 0 then
                    GameTooltip:AddLine(string.format("Excess: %d (converts to %d |cFF%s%s|r)",
                        excess, convertible, nextTier.color, nextTier.baseName), 0.5, 1, 0.5)
                elseif nextTier then
                    local remaining = addon.CRESTS_CONVERSION_UP - (excess % addon.CRESTS_CONVERSION_UP)
                    GameTooltip:AddLine(string.format("Excess: %d (%d more to convert to |cFF%s%s|r)",
                        excess, remaining, nextTier.color, nextTier.baseName), 0.7, 0.7, 0.7)
                end
            elseif excess > 0 then
                GameTooltip:AddLine(string.format("Excess: %d", excess), 0.5, 1, 0.5)
            end
        end

        -- Add crest information via direct lookup
        local crestType = addon.CREST_BY_SHORTCODE[crestData.reallyshortname]
        local baseData = crestType and addon.CREST_BASE[crestType]
        if baseData then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Sources:", 0.9, 0.7, 0)
            for _, source in ipairs(baseData.sources) do
                GameTooltip:AddLine("• " .. source, 0.8, 0.8, 0.8)
            end

            -- Add raid rewards section
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Raid Rewards:", 0.9, 0.7, 0)
            local firstRaid = true
            for raidName, raidData in pairs(addon.RAID_REWARDS) do
                for difficulty, rewardType in pairs(raidData.difficulties) do
                    if rewardType == crestType then
                        if not firstRaid then
                            GameTooltip:AddLine(" ")
                        end
                        firstRaid = false
                        local rgb = baseData.colorRGB
                        GameTooltip:AddLine(string.format("%s (%s):", raidData.name, difficulty), rgb[1], rgb[2], rgb[3])
                        local totalCrests = 0
                        for _, boss in ipairs(raidData.bosses) do
                            GameTooltip:AddLine(string.format("• %s: |cFF00FF00%d|r crests", boss.name, boss.reward), 0.8, 0.8, 0.8)
                            totalCrests = totalCrests + boss.reward
                        end
                        GameTooltip:AddLine(string.format("Total potential crests: |cFF00FF00%d|r", totalCrests), 0.8, 0.8, 0.8)
                    end
                end
            end

            -- Add dungeon rewards if this crest type has mythic requirements
            if baseData.mythicLevel and baseData.mythicLevel > 0 then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Mythic+ Rewards:", 0.9, 0.7, 0)

                local rewards = addon.CREST_REWARDS[crestType]
                if rewards then
                    local remaining = crestData.needed and math.max(0, crestData.needed - crestData.current - (crestData.upgraded or 0)) or 0

                    for level = baseData.mythicLevel, 12 do
                        if rewards[level] then
                            local rewardAmount = rewards[level].timed
                            local runsNeeded = remaining > 0 and math.ceil(remaining / rewardAmount) or 0

                            local levelText = string.format("|cFF%sM+%d|r", baseData.color, level)
                            local rewardText = string.format("|cFF00FF00%d|r crests", rewardAmount)
                            local runsText = remaining > 0 and string.format("(%d runs needed)", runsNeeded) or ""

                            GameTooltip:AddLine(string.format("%s: %s %s", levelText, rewardText, runsText), 1, 1, 1, true)
                        end
                    end
                end
            end
        end
    end
}

-- Cache crest icons for tooltip use (populated on first tooltip show)
local crestIconCache = {}
local function getCrestIcon(crestType)
    if crestIconCache[crestType] then return crestIconCache[crestType] end
    local crestData = CURRENCY.CRESTS[crestType]
    if crestData and crestData.currencyID then
        local success, info = pcall(C_CurrencyInfo.GetCurrencyInfo, crestData.currencyID)
        if success and info and info.iconFileID then
            crestIconCache[crestType] = CreateTextureMarkup(info.iconFileID, 64, 64, 14, 14, 0, 1, 0, 1)
            return crestIconCache[crestType]
        end
    end
    return ""
end

-- Master frame tooltip: per-slot breakdown with totals
tooltipProviders.masterFrame = function()
    GameTooltip:AddLine("Fully Upgraded", 1, 0.82, 0)

    -- Per-slot breakdown
    local hasSlots = false
    if addon.slotUpgradeData then
        for _, slot in ipairs(addon.EQUIPMENT_SLOTS) do
            local data = addon.slotUpgradeData[slot]
            if data then
                if not hasSlots then
                    GameTooltip:AddLine(" ")
                    hasSlots = true
                end
                local slotLabel = addon.SLOT_DISPLAY_NAMES[slot] or slot:gsub("Slot$", "")
                if data.fullyUpgraded then
                    local color = addon.TRACK_COLORS.FULLY_UPGRADED
                    local icon = getCrestIcon(data.trackName:upper())
                    GameTooltip:AddDoubleLine(
                        slotLabel,
                        string.format("%s |cFF%s%s %d/%d|r", icon, color, data.trackName, data.currentNum, data.maxNum),
                        0.7, 0.7, 0.7, 1, 1, 1)
                else
                    local trackUpper = data.trackName:upper()
                    local color = addon.TRACK_COLORS[trackUpper] or "ffffff"
                    local icon = getCrestIcon(data.crestType or trackUpper)
                    GameTooltip:AddDoubleLine(
                        slotLabel,
                        string.format("|cFF%s+%d|r %s %d",
                            color, data.levelsToUpgrade,
                            icon, data.crestCount),
                        0.7, 0.7, 0.7, 1, 1, 1)
                end
            end
        end
    end

    -- Season progress summary
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Season Progress:", 0.9, 0.7, 0)
    for _, crestType in ipairs(CREST_ORDER) do
        local crestData = CURRENCY.CRESTS[crestType]
        if crestData and crestData.currencyID then
            local success, info = pcall(C_CurrencyInfo.GetCurrencyInfo, crestData.currencyID)
            if success and info then
                local totalEarned = info.totalEarned or info.quantity or 0
                local seasonMax = info.maxQuantity or 0
                if seasonMax > 0 then
                    local baseData = addon.CREST_BASE[crestType]
                    local color = baseData and baseData.color or "ffffff"
                    local icon = getCrestIcon(crestType)
                    GameTooltip:AddDoubleLine(
                        string.format("%s |cFF%s%s|r", icon, color, baseData.baseName),
                        string.format("%d / %d", totalEarned, seasonMax),
                        1, 1, 1, 0.8, 0.8, 0.8)
                end
            end
        end
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Left-click to share | Right-click for options", 0.5, 0.5, 0.5)
end

-- Set up master frame tooltip scripts
masterFrame:SetScript("OnEnter", function(self)
    showTooltip(self, "ANCHOR_TOP", tooltipProviders.masterFrame)
end)
masterFrame:SetScript("OnLeave", hideTooltip)

-- Process a single upgrade track (Midnight - flat 20 crests per upgrade)
-- Dual-crest transitions: level 1→2 assigned to lower tier (cheaper),
-- level 5→6 kept as same tier (wouldn't waste higher-tier crests).
local function processUpgradeTrack(track, levelsToUpgrade, trackName, currentNum)
    -- Add to total upgrades counter
    if levelsToUpgrade > 0 then
        addon.totalUpgrades = (addon.totalUpgrades or 0) + levelsToUpgrade
    end

    if track.crestType then
        local crestType = track.crestType

        -- All upgrade levels use the track's own crest type as the primary cost
        -- Dual-crest alternatives (level 2 accepting lower tier) are optional,
        -- tracked separately in CharacterFrame tooltip data
        local standardCrests = levelsToUpgrade * CRESTS_TO_UPGRADE

        CURRENCY.CRESTS[crestType].needed = (CURRENCY.CRESTS[crestType].needed or 0) + standardCrests

        if addon.debugMode then
            print(string.format("[FullyUpgraded] %s: %d levels, %d %s crests",
                trackName, levelsToUpgrade, standardCrests, crestType))
        end
    end
end

-- Cache tooltip data
local function getCachedTooltipData(slotID, itemLink)
    local currentTime = GetTime()
    local cacheKey = itemLink or slotID

    if tooltipCache[cacheKey] and (currentTime - tooltipCache[cacheKey].time) < addon.TOOLTIP_CACHE_TTL then
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

-- Cache item info with error handling
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

-- Initial currency display
C_Timer.After(0.1, function()
    if addon.updateCrestCurrency then
        addon.updateCrestCurrency(currencyFrame)
    end
end)

-- Function to share upgrade needs in chat
shareUpgradeNeeds = function()
    local hasNeeds = false
    local messageParts = {}

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

-- **Event Handling**
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
f:RegisterEvent("PLAYER_REGEN_DISABLED")  -- Entering combat
f:RegisterEvent("PLAYER_REGEN_ENABLED")   -- Leaving combat

-- Enhanced throttling with proper debouncing
local lastUpdateTime = 0
local updatePending = false
local UPDATE_THROTTLE = addon.UPDATE_THROTTLE_TIME

local function throttledUpdate(forceUpdate)
    local currentTime = GetTime()

    if not forceUpdate and currentTime - lastUpdateTime < UPDATE_THROTTLE then
        if not updatePending then
            updatePending = true
            C_Timer.After(UPDATE_THROTTLE, function()
                updatePending = false
                if isCharacterTabSelected() then
                    updateDisplay(true)
                    lastUpdateTime = GetTime()
                end
            end)
        end
        return
    end

    if isCharacterTabSelected() then
        updateDisplay(forceUpdate)
        lastUpdateTime = currentTime
    end
end

-- Combat state tracking
local inCombat = false

-- Shared initialization for login/entering world events
local function handleInitEvent()
    InitializeSavedVariables()

    if not addon.initialized then
        if addon.initializeCharacterFrame then
            addon.initializeCharacterFrame()
        else
            print("[FullyUpgraded] ERROR: initializeCharacterFrame not available")
        end
        addon.initialized = true
        updateDisplay()
    end
    updateFrameVisibility()
end

-- Optimized event handler with combat state management
f:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_LOGIN" then
        handleInitEvent()
    elseif event == "CURRENCY_DISPLAY_UPDATE" then
        if not inCombat then
            throttledUpdate()
        end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        local slotID = ...
        if slotID then
            tooltipCache[slotID] = nil
            local itemLink = GetInventoryItemLink("player", slotID)
            if itemLink then
                tooltipCache[itemLink] = nil
                itemCache[itemLink] = nil
            end
        end
        calculateUpgradedCrests()
        throttledUpdate(true)
    elseif event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
        if masterFrame then
            masterFrame:Hide()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
        if isCharacterTabSelected() then
            if masterFrame then
                masterFrame:Show()
            end
            throttledUpdate()
        end
    end
end)

-- Function to force a currency update
local function forceCurrencyUpdate()
    wipe(currencyCache)
    wipe(upgradeCalculationsCache.data)
    upgradeCalculationsCache.lastUpdate = 0

    checkCurrencyForAllCrests()
    calculateUpgradedCrests()
    if addon.updateCrestCurrency then
        addon.updateCrestCurrency(currencyFrame)
    end

    if addon.updateAllUpgradeTexts then
        addon.updateAllUpgradeTexts()
    end
end

-- Function to set text visibility
local function setTextVisibility(visible)
    FullyUpgradedDB.textVisible = visible

    -- Delegate to CharacterFrame's version for UI updates
    if addon.setTextVisibility then
        addon.setTextVisibility(visible)
    end

    if visible and addon.updateAllUpgradeTexts then
        addon.updateAllUpgradeTexts()
    end
end

-- Export as SetTextVisibility (capital S) for OptionsFrame
addon.SetTextVisibility = setTextVisibility

-- Add slash command handler
SLASH_FULLYUPGRADED1 = "/fullyupgraded"
SLASH_FULLYUPGRADED2 = "/fu"
SlashCmdList["FULLYUPGRADED"] = function(msg)
    local cmd, arg = msg:match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()
    arg = arg:upper()

    if cmd == "textpos" then
        local position = arg or ""

        if position == "TOP" or position == "T" or position == "TR" or position == "TL" then
            addon.UpdateTextPositions("TOP")
            print("|cFFFFFF00FullyUpgraded:|r Text position set to TOP")
        elseif position == "BOTTOM" or position == "B" or position == "BR" or position == "BL" then
            addon.UpdateTextPositions("BOTTOM")
            print("|cFFFFFF00FullyUpgraded:|r Text position set to BOTTOM")
        elseif position == "CENTER" or position == "C" then
            addon.UpdateTextPositions("C")
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
        print("  /fu refresh - Manually refresh upgrade information")
        print("  /fu currency - Manually refresh currency information")
        print("  /fu debug - Toggle debug mode")
    end
end

-- Cleanup function
local function CleanupAddon()
    wipe(tooltipCache)
    wipe(itemCache)
    wipe(currencyCache)
    wipe(upgradeCalculationsCache.data)
    collectgarbage("collect")
end

f:SetScript("OnDisable", CleanupAddon)

-- Get the current season's item level range
local function getCurrentSeasonItemLevelRange()
    return SEASONS[1].MIN_ILVL, SEASONS[1].MAX_ILVL
end

-- Export functions to addon namespace
addon.updateDisplay = updateDisplay
addon.showTooltip = showTooltip
addon.hideTooltip = hideTooltip
addon.tooltipProviders = tooltipProviders
addon.processUpgradeTrack = processUpgradeTrack
addon.getCachedTooltipData = getCachedTooltipData
addon.getCachedItemInfo = getCachedItemInfo
addon.getCurrentSeasonItemLevelRange = getCurrentSeasonItemLevelRange

print("[FullyUpgraded] FullyUpgraded.lua loaded (Midnight Edition)")
