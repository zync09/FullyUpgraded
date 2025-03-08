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
masterFrame:SetSize(230, 100) -- Adjusted size to be more compact

-- Function to update master frame size
local function UpdateMasterFrameSize()
    if not currencyFrame then return end

    local padding = 8 -- Reduced padding
    local titleHeight = titleText and titleText:GetHeight() or 0
    local currencyHeight = currencyFrame:GetHeight()
    local currencyWidth = currencyFrame:GetWidth()

    -- Set master frame size based on content plus padding
    masterFrame:SetSize(
        math.max(230, currencyWidth + padding * 2), -- Minimum width of 230
        titleHeight + currencyHeight + padding * 2
    )
end

-- Add a timer to update sizes after text rendering
local function DelayedSizeUpdate()
    C_Timer.After(0.1, function()
        UpdateMasterFrameSize()
        if addon.UpdateCrestCurrency then
            addon.UpdateCrestCurrency(currencyFrame)
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

-- Create title text
local titleText = masterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
titleText:SetPoint("TOP", masterFrame, "TOP", 0, -5)
titleText:SetText("Fully Upgraded:")
titleText:SetTextColor(1, 1, 0) -- Gold color

-- Create currency frame as a child of master frame (no backdrop needed)
local currencyFrame = CreateFrame("Frame", "GearUpgradeCurrencyFrame", masterFrame)
currencyFrame:SetPoint("TOP", titleText, "BOTTOM", 0, -2) -- Position relative to title
currencyFrame:SetSize(140, 20)                            -- Initial size, will be updated by CrestCurrencyFrame.lua

-- Set up frame update events
currencyFrame:SetScript("OnSizeChanged", UpdateMasterFrameSize)
C_Timer.After(0.1, UpdateMasterFrameSize) -- Initial size update after everything is created

-- Add after other local variables
local debugMode = false -- Set to true to enable debug messages

-- Function to check if character tab is selected
local function IsCharacterTabSelected()
    return PaperDollFrame:IsVisible()
end

-- Function to update frame visibility
local function UpdateFrameVisibility()
    if IsCharacterTabSelected() then
        masterFrame:Show()
    else
        masterFrame:Hide()
    end
end

-- Hook character frame tab changes
CharacterFrame:HookScript("OnShow", UpdateFrameVisibility)
CharacterFrame:HookScript("OnHide", function() masterFrame:Hide() end)

-- Hook tab changes
hooksecurefunc("ToggleCharacter", UpdateFrameVisibility)

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
            addon.UpdateAllUpgradeTexts()
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
        if IsCharacterTabSelected() then
            UpdateDisplay()
        end
        updateThrottled = false
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
        UpdateFrameVisibility()
    elseif event == "PLAYER_LOGIN" then
        if not addon.initialized then
            addon.InitializeUpgradeTexts()
            addon.initialized = true
            UpdateDisplay()
        end
        UpdateFrameVisibility()
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

    -- Update display immediately
    if addon.UpdateAllUpgradeTexts then
        addon.UpdateAllUpgradeTexts()
    end
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
if not itemUpgradeFrameHooked and IsAddonLoaded("Blizzard_ItemUpgradeUI") then
    -- The ItemUpgradeFrame hooks are now handled in CharacterFrame.lua
    itemUpgradeFrameHooked = true
end

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
addon.SetUpgradeTooltip = SetUpgradeTooltip
addon.ProcessUpgradeTrack = ProcessUpgradeTrack
addon.GetCachedTooltipData = GetCachedTooltipData
addon.GetCachedItemInfo = GetCachedItemInfo
addon.CalculateUpgradedCrests = CalculateUpgradedCrests
addon.CheckCurrencyForAllCrests = CheckCurrencyForAllCrests
addon.GetCurrentSeasonItemLevelRange = GetCurrentSeasonItemLevelRange
addon.ForceCurrencyUpdate = ForceCurrencyUpdate
