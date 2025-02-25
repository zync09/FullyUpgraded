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

local upgradeTextPool = {}
local tooltipFrame = CreateFrame("GameTooltip", "GearUpgradeTooltip", UIParent, "GameTooltipTemplate")
local totalCrestFrame = CreateFrame("Frame", "GearUpgradeTotalFrame", CharacterFrame, "BackdropTemplate")
local totalCrestText = totalCrestFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")

totalCrestFrame:SetSize(250, 65)
totalCrestFrame:SetPoint("TOPRIGHT", CharacterFrame, "BOTTOMRIGHT", 0, 0)
totalCrestFrame:SetBackdrop({
    bgFile = "Interface/Buttons/WHITE8x8",
    edgeFile = "Interface/Buttons/WHITE8x8",
    tile = true,
    tileSize = 8,
    edgeSize = 2,
})
totalCrestFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
totalCrestFrame:SetBackdropBorderColor(0, 0, 0, 1)

totalCrestText:SetPoint("BOTTOMRIGHT", totalCrestFrame, "BOTTOMRIGHT", -2, 5)
totalCrestText:SetTextColor(1, 0.8, 0)
totalCrestText:SetFont(totalCrestText:GetFont(), 12, "OUTLINE")
totalCrestText:SetJustifyH("RIGHT")

-- Add after other local variables
local currentTextPos = "TR" -- Default position

-- Function to check if character tab is selected
local function IsCharacterTabSelected()
    return PaperDollFrame:IsVisible()
end

local function UpdateFrameSizeToText()
    totalCrestFrame:SetSize(totalCrestFrame:GetWidth(), totalCrestText:GetStringHeight() + 10)
end

UpdateFrameSizeToText()

-- Function to update frame visibility
local function UpdateFrameVisibility()
    if IsCharacterTabSelected() then
        totalCrestFrame:Show()
    else
        totalCrestFrame:Hide()
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
                CURRENCY.CRESTS[crestType].current = info.quantity
                CURRENCY.CRESTS[crestType].name = info.name
            end
        end
    end
end

-- **Creates Upgrade Text for a Slot**
local function CreateUpgradeText(slot)
    local slotFrame = _G["Character" .. slot]
    if not slotFrame then return end

    local text = slotFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    local posData = TEXT_POSITIONS[currentTextPos]
    text:SetPoint(posData.point, slotFrame, posData.point, posData.x, posData.y)
    text:SetJustifyH("RIGHT")
    text:SetDrawLayer("OVERLAY", 7)
    text:SetFont(text:GetFont(), 12, "OUTLINE, THICKOUTLINE")

    -- Create fully upgraded icon for this slot
    local fullyUpgradedIcon = slotFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    fullyUpgradedIcon:SetSize(16, 16)
    fullyUpgradedIcon:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-Ready")
    -- Position the fully upgraded icon using the same positioning data as the text
    -- posData.point: The anchor point (e.g. "TR", "TL", etc)
    -- posData.x/y: The x/y offset from the anchor point
    fullyUpgradedIcon:SetPoint(posData.point, slotFrame, posData.point, 0, 0)
    fullyUpgradedIcon:Hide()

    -- Create button for tooltip interaction
    local fullyUpgradedButton = CreateFrame("Button", nil, slotFrame)
    fullyUpgradedButton:SetSize(16, 16)
    fullyUpgradedButton:SetPoint(posData.point, slotFrame, posData.point, 0, 0)
    fullyUpgradedButton:Hide()

    -- Store references to the icon and button
    text.fullyUpgradedIcon = fullyUpgradedIcon
    text.fullyUpgradedButton = fullyUpgradedButton

    return text
end

-- **Initialize All Equipment Slot Overlays**
local function InitializeUpgradeTexts()
    for _, slot in ipairs(EQUIPMENT_SLOTS) do
        upgradeTextPool[slot] = CreateUpgradeText(slot)
    end
end

-- **Tooltip Setup for Crest Costs**
local function SetUpgradeTooltip(self, track, remaining, current)
    tooltipFrame:SetOwner(self, "ANCHOR_RIGHT")
    tooltipFrame:AddLine("Upgrade Requirements:")

    -- Skip crest requirements for Explorer track
    if not track.crest then
        tooltipFrame:AddLine("No crests required")
        tooltipFrame:Show()
        return
    end

    -- Special handling for tracks with split requirements
    if track.splitUpgrade then
        local firstTier = track.splitUpgrade.firstTier
        local secondTier = track.splitUpgrade.secondTier
        local remainingFirstTier = math.min(remaining, math.max(0, firstTier.levels - current))
        local remainingSecondTier = math.max(0, remaining - remainingFirstTier)

        if remainingFirstTier > 0 and firstTier.crest then
            local crestType = firstTier.shortname:upper()
            local mythicText = CURRENCY.CRESTS[crestType] and CURRENCY.CRESTS[crestType].mythicLevel > 0 and
                string.format(" (M%d+)", CURRENCY.CRESTS[crestType].mythicLevel) or ""
            
            -- Get currency icon
            if CURRENCY.CRESTS[crestType] and CURRENCY.CRESTS[crestType].currencyID then
                local currencyID = CURRENCY.CRESTS[crestType].currencyID
                -- Get the icon file ID from the currency info
                local iconFileID = C_CurrencyInfo.GetCurrencyInfo(currencyID).iconFileID
                local iconText = CreateTextureMarkup(iconFileID, 64, 64, 16, 16, 0, 1, 0, 1)
                tooltipFrame:AddLine(string.format("%s %d x %s%s", iconText, remainingFirstTier * CRESTS_TO_UPGRADE, firstTier.crest, mythicText))
            else
                tooltipFrame:AddLine(string.format("%d x %s%s", remainingFirstTier * CRESTS_TO_UPGRADE, firstTier.crest, mythicText))
            end
        end

        if remainingSecondTier > 0 and secondTier.crest then
            local crestType = secondTier.shortname:upper()
            local mythicText = CURRENCY.CRESTS[crestType] and CURRENCY.CRESTS[crestType].mythicLevel > 0 and
                string.format(" (M%d+)", CURRENCY.CRESTS[crestType].mythicLevel) or ""
            
            -- Get currency icon
            if CURRENCY.CRESTS[crestType] and CURRENCY.CRESTS[crestType].currencyID then
                local currencyID = CURRENCY.CRESTS[crestType].currencyID
                -- Get the icon file ID from the currency info
                local iconFileID = C_CurrencyInfo.GetCurrencyInfo(currencyID).iconFileID
                local iconText = CreateTextureMarkup(iconFileID, 64, 64, 16, 16, 0, 1, 0, 1)
                tooltipFrame:AddLine(string.format("%s %d x %s%s", iconText, remainingSecondTier * CRESTS_TO_UPGRADE, secondTier.crest, mythicText))
            else
                tooltipFrame:AddLine(string.format("%d x %s%s", remainingSecondTier * CRESTS_TO_UPGRADE, secondTier.crest, mythicText))
            end
        end
    end

    tooltipFrame:Show()
end

-- Get the current season's item level range
local function GetCurrentSeasonItemLevelRange()
    -- For now, we'll use Season 1 as it's the current season
    -- TODO: Add proper season detection when needed
    return SEASONS[1].MIN_ILVL, SEASONS[1].MAX_ILVL
end

-- Remove the old ShowCrestCurrency function and replace with:
local function ShowCrestCurrency()
    addon.UpdateCrestCurrency(totalCrestFrame)
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

-- Process a single equipment slot
local function ProcessEquipmentSlot(slot, text)
    -- Always hide the text first
    text:SetText("")
    text:Hide()
    text:SetScript("OnEnter", nil)
    text:SetScript("OnLeave", nil)
    text.fullyUpgradedIcon:Hide()
    text.fullyUpgradedButton:Hide()

    local slotID = GetInventorySlotInfo(slot)
    local itemLink = GetInventoryItemLink("player", slotID)

    if not itemLink then return end

    local effectiveILvl = select(4, C_Item.GetItemInfo(itemLink))
    local tooltipData = C_TooltipInfo.GetInventoryItem("player", slotID)

    -- Only process items within the season's item level range
    if effectiveILvl and tooltipData then
        local minIlvl, maxIlvl = GetCurrentSeasonItemLevelRange()
        if effectiveILvl >= minIlvl and effectiveILvl <= maxIlvl then
            for _, line in ipairs(tooltipData.lines) do
                local trackName, current, max = line.leftText:match("Upgrade Level: (%w+) (%d+)/(%d+)")
                if trackName then
                    local trackUpper = trackName:upper()
                    local currentNum = tonumber(current)
                    local maxNum = tonumber(max)
                    local levelsToUpgrade = maxNum - currentNum
                    local track = UPGRADE_TRACKS[trackUpper]

                    if track then
                        if levelsToUpgrade > 0 then
                            -- Show remaining upgrades
                            local trackLetter = trackUpper:sub(1, 1)
                            text:SetText("|cFFffffff+" .. levelsToUpgrade .. trackLetter .. "|r")
                            text:Show()

                            text:SetScript("OnEnter", function(self)
                                SetUpgradeTooltip(self, track, levelsToUpgrade, currentNum)
                            end)
                            text:SetScript("OnLeave", function() tooltipFrame:Hide() end)

                            ProcessUpgradeTrack(track, levelsToUpgrade, current)
                        elseif currentNum == maxNum then
                            -- Show fully upgraded icon with track letter
                            text.fullyUpgradedIcon:Show()
                            text.fullyUpgradedButton:Show()
                            -- Add track letter text
                            text:SetText("|cFFffffff" .. '*' .. trackUpper:sub(1,1) .. "|r")
                            text:Show()
                            
                            text.fullyUpgradedButton:SetScript("OnEnter", function(self)
                                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                                GameTooltip:AddLine("Fully Upgraded")
                                GameTooltip:AddLine(string.format("%s Track %d/%d", trackName, currentNum, maxNum), 1, 1, 1)
                                GameTooltip:Show()
                            end)
                            text.fullyUpgradedButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
                        end
                    end
                    break
                end
            end
        end
    end
end

-- Format the total text for crests
local function FormatTotalCrestText(sortedCrests)
    local totalText = ""
    for _, crestData in ipairs(sortedCrests) do
        local crestType = crestData.crestType
        local data = crestData.data
        if data.needed > 0 then
            local remaining = data.needed - data.current
            local potentialExtra = data.upgraded * CRESTS_TO_UPGRADE
            local upgradedText = data.upgraded and data.upgraded > 0
                and string.format(" [+%d]", potentialExtra)
                or ""

            if data.mythicLevel and data.mythicLevel > 0 then
                local currentRuns = math.max(0, math.ceil(remaining / CRESTS_TO_UPGRADE))
                local runsText = string.format("M%d+ Runs: ~%d", data.mythicLevel, currentRuns)

                totalText = totalText .. string.format("\n%s: %d/%d%s (%s)",
                    crestType:sub(1, 1) .. crestType:sub(2):lower(),
                    data.current,
                    data.needed,
                    upgradedText,
                    runsText)
            else
                totalText = totalText .. string.format("\n%s: %d/%d%s",
                    crestType:sub(1, 1) .. crestType:sub(2):lower(),
                    data.current,
                    data.needed,
                    upgradedText)
            end
        end
    end
    return totalText
end

-- Sort crests by mythic level
local function GetSortedCrests()
    local sortedCrests = {}
    for crestType, data in pairs(CURRENCY.CRESTS) do
        if data and data.needed and data.needed > 0 then
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
    end

    -- Sort with additional safety checks
    table.sort(sortedCrests, function(a, b)
        if not a or not b or not a.data or not b.data then
            return false
        end

        local aLevel = tonumber(a.data.mythicLevel) or 0
        local bLevel = tonumber(b.data.mythicLevel) or 0

        if aLevel == bLevel then
            return tostring(a.crestType) < tostring(b.crestType)
        end
        return aLevel < bLevel
    end)

    return sortedCrests
end

-- Main update function
local function UpdateAllUpgradeTexts()
    CalculateUpgradedCrests()
    CheckCurrencyForAllCrests()
    ShowCrestCurrency()

    -- Reset needed counts
    for crestType, _ in pairs(CURRENCY.CRESTS) do
        CURRENCY.CRESTS[crestType].needed = 0
    end

    -- Process each equipment slot
    for _, slot in ipairs(EQUIPMENT_SLOTS) do
        local text = upgradeTextPool[slot]
        if not text then return end
        ProcessEquipmentSlot(slot, text)
    end

    -- Update total text display
    local sortedCrests = GetSortedCrests()
    local totalText = FormatTotalCrestText(sortedCrests)

    if totalText ~= "" then
        totalCrestText:SetText("Fully Upgraded:" .. totalText)
        totalCrestText:Show()
    else
        totalCrestText:Hide()
    end

    UpdateFrameSizeToText()
end

-- **Event Handling**
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
f:RegisterEvent("BAG_UPDATE")

f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        CalculateUpgradedCrests()
        InitializeUpgradeTexts()
    end
    if event == "CURRENCY_DISPLAY_UPDATE" or event == "BAG_UPDATE" then
        if IsCharacterTabSelected() then
            CalculateUpgradedCrests()
            UpdateAllUpgradeTexts()
        end
    end
    if IsCharacterTabSelected() then
        CalculateUpgradedCrests()
        UpdateAllUpgradeTexts()
    end
end)

-- Hook to character frame tab changes
PaperDollFrame:HookScript("OnShow", function()
    UpdateAllUpgradeTexts()
    UpdateFrameVisibility()
end)

PaperDollFrame:HookScript("OnHide", function()
    UpdateFrameVisibility()
end)

CharacterFrame:HookScript("OnShow", function()
    if IsCharacterTabSelected() then
        UpdateAllUpgradeTexts()
    end
end)

-- Function to update text position for all slots
local function UpdateTextPositions(position)
    if not TEXT_POSITIONS[position] then return end

    currentTextPos = position
    local posData = TEXT_POSITIONS[position]

    for _, text in pairs(upgradeTextPool) do
        if text then
            text:ClearAllPoints()
            text:SetPoint(posData.point, text:GetParent(), posData.point, posData.x, posData.y)
        end
    end
end

-- Function to set text visibility
local function SetTextVisibility(show)
    for slot, text in pairs(upgradeTextPool) do
        if text then
            if show then
                -- Re-process the slot to properly show either upgrade text or fully upgraded icon
                ProcessEquipmentSlot(slot, text)
            else
                text:Hide()
                text:SetText("")
                -- Also hide the icon and button
                if text.fullyUpgradedIcon then
                    text.fullyUpgradedIcon:Hide()
                    text.fullyUpgradedButton:Hide()
                end
            end
        end
    end
end

-- Export functions to addon namespace
addon.UpdateTextPositions = UpdateTextPositions
addon.SetTextVisibility = SetTextVisibility

-- Add slash command handler
SLASH_FULLYUPGRADED1 = "/fullyupgraded"
SLASH_FULLYUPGRADED2 = "/fu"
SlashCmdList["FULLYUPGRADED"] = function(msg)
    local cmd, arg = msg:match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()
    arg = arg:upper()

    if cmd == "textpos" then
        if TEXT_POSITIONS[arg] then
            UpdateTextPositions(arg)
            print("|cFFFFFF00FullyUpgraded:|r Text position set to " .. arg)
        else
            print(
                "|cFFFFFF00FullyUpgraded:|r Valid positions: TR (Top Right), TL (Top Left), BR (Bottom Right), BL (Bottom Left), C (Center)")
        end
    else
        print("|cFFFFFF00FullyUpgraded commands:|r")
        print("  /fu textpos <position> - Set text position (TR/TL/BR/BL/C)")
    end
end
