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

-- Font settings
local fontFile = GameFontNormal:GetFont()
local fontSize = 12
local fontFlags = "OUTLINE, THICKOUTLINE"

-- Optimization: Create a single tooltip frame and reuse it
local tooltipFrame = CreateFrame("GameTooltip", "GearUpgradeTooltip", UIParent, "GameTooltipTemplate")

-- Cache for tooltip data to reduce memory allocations
local tooltipCache = {}
local itemCache = {}

-- Optimization: Create object pools for frames and textures
local framePool = CreateFramePool("Frame")
local texturePool = CreateTexturePool()
local fontStringPool = CreateFontStringPool()

-- Create master frame that will contain both displays
local masterFrame = CreateFrame("Frame", "GearUpgradeMasterFrame", CharacterFrame, "BackdropTemplate")
masterFrame:SetPoint("TOPRIGHT", CharacterFrame, "BOTTOMRIGHT", 0, 0)
masterFrame:SetSize(280, 30) -- Initial size for just currency frame
masterFrame:SetBackdrop({
    bgFile = "Interface/Buttons/WHITE8x8",
    edgeFile = "Interface/Buttons/WHITE8x8",
    tile = true,
    tileSize = 8,
    edgeSize = 2,
})
masterFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
masterFrame:SetBackdropBorderColor(0, 0, 0, 1)

-- Create currency frame as a child of master frame (no backdrop needed)
local currencyFrame = CreateFrame("Frame", "GearUpgradeCurrencyFrame", masterFrame)
currencyFrame:SetPoint("TOPRIGHT", masterFrame, "TOPRIGHT", 0, 0)
currencyFrame:SetSize(250, 30)
currencyFrame:Show()

-- Create total crest frame as a child of master frame (no backdrop needed)
local totalCrestFrame = CreateFrame("Frame", "GearUpgradeTotalFrame", masterFrame)
totalCrestFrame:SetPoint("TOPRIGHT", currencyFrame, "BOTTOMRIGHT", 0, 0)
totalCrestFrame:SetSize(250, 0) -- Start with 0 height

local totalCrestText = totalCrestFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
totalCrestText:SetPoint("BOTTOMRIGHT", totalCrestFrame, "BOTTOMRIGHT", -2, 5)
totalCrestText:SetTextColor(1, 0.8, 0)
totalCrestText:SetFont(totalCrestText:GetFont(), 12, "OUTLINE")
totalCrestText:SetJustifyH("RIGHT")

-- Add after other local variables
local debugMode = false -- Set to true to enable debug messages

-- Function to check if character tab is selected
local function IsCharacterTabSelected()
    return PaperDollFrame:IsVisible()
end

local function UpdateFrameSizeToText()
    local currencyHeight = 30 -- Fixed height for currency frame
    local textHeight = 0

    if totalCrestText:IsShown() and totalCrestText:GetText() and totalCrestText:GetText() ~= "" then
        textHeight = totalCrestText:GetStringHeight() + 10 -- Add padding
    end

    totalCrestFrame:SetHeight(textHeight)              -- Only update height, keep width
    masterFrame:SetHeight(currencyHeight + textHeight) -- Update master frame height
end

UpdateFrameSizeToText()

-- Function to update frame visibility
local function UpdateFrameVisibility()
    if IsCharacterTabSelected() then
        masterFrame:Show()
    else
        masterFrame:Hide()
    end
end

local function CalculateUpgradedCrests()
    -- Reset upgraded counts
    for _, crestType in ipairs(CREST_ORDER) do
        if CURRENCY.CRESTS[crestType] then
            CURRENCY.CRESTS[crestType].upgraded = 0
        end
    end

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
        end
    end
end

-- Check currency for all crests
local function CheckCurrencyForAllCrests()
    for crestType, crestData in pairs(CURRENCY.CRESTS) do
        if crestData.currencyID then
            local info = C_CurrencyInfo.GetCurrencyInfo(crestData.currencyID)
            if info then
                local oldValue = CURRENCY.CRESTS[crestType].current
                CURRENCY.CRESTS[crestType].current = info.quantity
                CURRENCY.CRESTS[crestType].name = info.name
            end
        end
    end
end

-- Get the current season's item level range
local function GetCurrentSeasonItemLevelRange()
    return SEASONS[2].MIN_ILVL, SEASONS[2].MAX_ILVL
end

-- Optimization: Clear caches periodically
local function ClearCaches()
    local currentTime = GetTime()

    -- Clear old tooltip cache entries
    for key, data in pairs(tooltipCache) do
        if (currentTime - data.time) > 5 then
            tooltipCache[key] = nil
        end
    end

    -- Clear item cache if it gets too large
    if next(itemCache) and #itemCache > 100 then
        wipe(itemCache)
    end
end

-- Simplified update function
local function UpdateDisplay()
    if IsCharacterTabSelected() then
        -- Only initialize texts if they don't exist
        if not next(addon.upgradeTextPool) then
            addon.InitializeUpgradeTexts()
        end

        -- Explicitly recalculate and update currency information
        CheckCurrencyForAllCrests()
        CalculateUpgradedCrests()

        -- Update the display
        if addon.UpdateAllUpgradeTexts then
            C_Timer.After(0, function()
                addon.UpdateAllUpgradeTexts()
            end)
        end

        -- Make sure the currency frame is visible
        if masterFrame then
            masterFrame:Show()
        end
    end
end

-- **Tooltip Setup for Crest Costs**
local function SetUpgradeTooltip(self, tooltipInfo)
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
                    local iconFileID = C_CurrencyInfo.GetCurrencyInfo(currencyID).iconFileID
                    local iconText = CreateTextureMarkup(iconFileID, 64, 64, 16, 16, 0, 1, 0, 1)
                    GameTooltip:AddLine(string.format("%s %d x |cFF%s%s Undermine Crest%s|r",
                        iconText,
                        req.count,
                        baseData.color,
                        baseData.baseName,
                        mythicText))
                end
            end

            if tooltipInfo.requirements.secondTier then
                local req = tooltipInfo.requirements.secondTier
                local baseData = addon.CREST_BASE[req.crestType]
                local mythicText = req.mythicLevel > 0 and string.format(" (M%d+)", req.mythicLevel) or ""

                if CURRENCY.CRESTS[req.crestType] and CURRENCY.CRESTS[req.crestType].currencyID then
                    local currencyID = CURRENCY.CRESTS[req.crestType].currencyID
                    local iconFileID = C_CurrencyInfo.GetCurrencyInfo(currencyID).iconFileID
                    local iconText = CreateTextureMarkup(iconFileID, 64, 64, 16, 16, 0, 1, 0, 1)
                    GameTooltip:AddLine(string.format("%s %d x |cFF%s%s Undermine Crest%s|r",
                        iconText,
                        req.count,
                        baseData.color,
                        baseData.baseName,
                        mythicText))
                end
            end
        elseif tooltipInfo.requirements.standard then
            local req = tooltipInfo.requirements.standard
            local baseData = addon.CREST_BASE[req.crestType]
            local mythicText = req.mythicLevel > 0 and string.format(" (M%d+)", req.mythicLevel) or ""

            if CURRENCY.CRESTS[req.crestType] and CURRENCY.CRESTS[req.crestType].currencyID then
                local currencyID = CURRENCY.CRESTS[req.crestType].currencyID
                local iconFileID = C_CurrencyInfo.GetCurrencyInfo(currencyID).iconFileID
                local iconText = CreateTextureMarkup(iconFileID, 64, 64, 16, 16, 0, 1, 0, 1)
                GameTooltip:AddLine(string.format("%s %d x |cFF%s%s Undermine Crest%s|r",
                    iconText,
                    req.count,
                    baseData.color,
                    baseData.baseName,
                    mythicText))
            end
        end
    end
end

-- Process a single upgrade track and update crest requirements
local function ProcessUpgradeTrack(track, levelsToUpgrade, current)
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
local function GetCachedTooltipData(slotID, itemLink)
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

-- Optimization: Cache item info
local function GetCachedItemInfo(itemLink)
    if not itemCache[itemLink] then
        itemCache[itemLink] = { C_Item.GetItemInfo(itemLink) }
    end
    return unpack(itemCache[itemLink])
end

-- Format the total text for crests
local function FormatTotalCrestText(sortedCrests)
    local totalText = ""
    for _, crestData in ipairs(sortedCrests) do
        local crestType = crestData.crestType
        local data = crestData.data
        if data.current > 0 or data.needed > 0 then -- Show if we have any or need any
            local remaining = math.max(0, data.needed - data.current)
            local potentialExtra = data.upgraded * CRESTS_TO_UPGRADE

            -- Get color from CREST_BASE
            local baseData = addon.CREST_BASE[crestType]
            local colorCode = baseData and baseData.color and string.format("|cFF%s", baseData.color) or "|cFFFFFFFF"

            if data.mythicLevel and data.mythicLevel > 0 then
                -- Calculate actual remaining after upgrades
                local actualRemaining = math.max(0, remaining - potentialExtra)
                local minLevel = data.mythicLevel
                local maxLevel = data.mythicLevel
                local minRuns = math.huge
                local maxRuns = 0

                -- Get all available M+ levels for this crest type
                if addon.CREST_REWARDS[crestType] then
                    -- Calculate runs needed at each level
                    for level, rewards in pairs(addon.CREST_REWARDS[crestType]) do
                        if level >= data.mythicLevel then
                            local runsNeeded = math.ceil(actualRemaining / rewards.timed)
                            if runsNeeded > 0 then
                                maxLevel = math.max(maxLevel, level)
                                if runsNeeded < minRuns then
                                    minRuns = runsNeeded
                                end
                                if level == data.mythicLevel then
                                    maxRuns = runsNeeded
                                end
                            end
                        end
                    end
                end

                local runsText = ""
                if actualRemaining <= 0 then
                    runsText = "No runs needed"
                else
                    runsText = string.format("M%d-%d: %d-%d runs", minLevel, maxLevel, maxRuns, minRuns)
                end

                totalText = totalText .. string.format("\n%s%s|r: %d/%d (%s)",
                    colorCode,
                    crestType:sub(1, 1) .. crestType:sub(2):lower(),
                    data.current,
                    data.needed,
                    runsText)
            else
                totalText = totalText .. string.format("\n%s%s|r: %d/%d",
                    colorCode,
                    crestType:sub(1, 1) .. crestType:sub(2):lower(),
                    data.current,
                    data.needed)
            end
        end
    end
    return totalText
end

-- Sort crests by the predefined order in CREST_ORDER (Weathered to Gilded)
local function GetSortedCrests()
    local sortedCrests = {}
    for crestType, data in pairs(CURRENCY.CRESTS) do
        -- Include all crests, not just those with needed > 0
        sortedCrests[#sortedCrests + 1] = {
            crestType = crestType,
            data = {
                mythicLevel = data.mythicLevel or 0,
                current = data.current or 0,
                needed = data.needed or 0,
                upgraded = data.upgraded or 0
            }
        }
    end

    -- Sort by the order defined in CREST_ORDER
    table.sort(sortedCrests, function(a, b)
        local aIndex = 0
        local bIndex = 0

        for i, crestType in ipairs(CREST_ORDER) do
            if a.crestType == crestType then aIndex = i end
            if b.crestType == crestType then bIndex = i end
        end

        return aIndex < bIndex
    end)

    return sortedCrests
end

-- **Event Handling**
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
f:RegisterEvent("BAG_UPDATE")

-- Throttle update calls
local updateThrottled = false
local function ThrottledUpdate()
    if not updateThrottled then
        updateThrottled = true
        C_Timer.After(0.1, function()
            if IsCharacterTabSelected() then
                UpdateDisplay()
            end
            updateThrottled = false
        end)
    end
end

-- Modified event handler with better initialization
f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        -- Initialize once
        if not addon.initialized then
            addon.InitializeUpgradeTexts()
            addon.initialized = true
            UpdateDisplay()
        end
    elseif event == "PLAYER_LOGIN" then
        if not addon.initialized then
            addon.InitializeUpgradeTexts()
            addon.initialized = true
            UpdateDisplay()
        end
    elseif event == "CURRENCY_DISPLAY_UPDATE" or
        event == "BAG_UPDATE" or
        event == "PLAYER_EQUIPMENT_CHANGED" then
        ThrottledUpdate()
    end
end)

-- Function to force a currency update
local function ForceCurrencyUpdate()
    CheckCurrencyForAllCrests()
    CalculateUpgradedCrests()
    if addon.ShowCrestCurrency then
        addon.ShowCrestCurrency()
    end

    -- Force a display update after currency update
    C_Timer.After(0, function()
        if addon.UpdateAllUpgradeTexts then
            addon.UpdateAllUpgradeTexts()
        end
    end)
end

-- Add slash command handler
SLASH_FULLYUPGRADED1 = "/fullyupgraded"
SLASH_FULLYUPGRADED2 = "/fu"
SlashCmdList["FULLYUPGRADED"] = function(msg)
    local cmd, arg = msg:match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()
    arg = arg:upper()

    if cmd == "textpos" then
        if TEXT_POSITIONS[arg] then
            addon.UpdateTextPositions(arg)
            print("|cFFFFFF00FullyUpgraded:|r Text position set to " .. arg)
        else
            print(
                "|cFFFFFF00FullyUpgraded:|r Valid positions: TR (Top Right), TL (Top Left), BR (Bottom Right), BL (Bottom Left), C (Center)")
        end
    elseif cmd == "refresh" or cmd == "r" then
        print("|cFFFFFF00FullyUpgraded:|r Refreshing upgrade information...")
        UpdateDisplay()
    elseif cmd == "currency" or cmd == "c" then
        print("|cFFFFFF00FullyUpgraded:|r Refreshing currency information...")
        ForceCurrencyUpdate()
    elseif cmd == "debug" then
        debugMode = not debugMode
        print("|cFFFFFF00FullyUpgraded:|r Debug mode " .. (debugMode and "enabled" or "disabled"))
        if debugMode then
            UpdateDisplay()
        end
    else
        print("|cFFFFFF00FullyUpgraded commands:|r")
        print("  /fu textpos <position> - Set text position (TR/TL/BR/BL/C)")
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
C_Timer.After(1, function()
    if not itemUpgradeFrameHooked and IsAddonLoaded("Blizzard_ItemUpgradeUI") then
        -- The ItemUpgradeFrame hooks are now handled in CharacterFrame.lua
        itemUpgradeFrameHooked = true
    end
end)

-- Optimization: Clean up resources when addon is disabled
local function CleanupAddon()
    wipe(tooltipCache)
    wipe(itemCache)
    framePool:ReleaseAll()
    texturePool:ReleaseAll()
    fontStringPool:ReleaseAll()
end

-- Register cleanup function
f:SetScript("OnDisable", CleanupAddon)

-- Periodically clean caches
C_Timer.NewTicker(5, ClearCaches)

-- Export functions to addon namespace
addon.Debug = Debug
addon.UpdateDisplay = UpdateDisplay
addon.UpdateFrameSizeToText = UpdateFrameSizeToText
addon.SetUpgradeTooltip = SetUpgradeTooltip
addon.ProcessUpgradeTrack = ProcessUpgradeTrack
addon.GetCachedTooltipData = GetCachedTooltipData
addon.GetCachedItemInfo = GetCachedItemInfo
addon.FormatTotalCrestText = FormatTotalCrestText
addon.GetSortedCrests = GetSortedCrests
addon.CalculateUpgradedCrests = CalculateUpgradedCrests
addon.CheckCurrencyForAllCrests = CheckCurrencyForAllCrests
addon.GetCurrentSeasonItemLevelRange = GetCurrentSeasonItemLevelRange
addon.totalCrestText = totalCrestText
addon.ForceCurrencyUpdate = ForceCurrencyUpdate

-- Function to show crest currency
local function ShowCrestCurrency()
    if addon.UpdateCrestCurrency then
        addon.UpdateCrestCurrency(currencyFrame)
    end
end

-- Export ShowCrestCurrency function
addon.ShowCrestCurrency = ShowCrestCurrency

-- Call it initially
C_Timer.After(0.1, ShowCrestCurrency)
