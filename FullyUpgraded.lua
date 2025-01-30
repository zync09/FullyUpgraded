local addonName, addon = ...
addon.f = CreateFrame("Frame") -- Main frame
local f = addon.f

local CRESTS_TO_UPGRADE = 15

local EQUIPMENT_SLOTS = {
    "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot",
    "WristSlot", "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot",
    "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot",
    "MainHandSlot", "SecondaryHandSlot"
}

local CURRENCY = {
    CRESTS = {
        WEATHERED = {
            current = 0,
            needed = 0,
            mythicLevel = nil,
        },
        CARVED = {
            current = 0,
            needed = 0,
            mythicLevel = 2,
        },
        RUNED = {
            current = 0,
            needed = 0,
            mythicLevel = 4,
        },
        GILDED = {
            current = 0,
            needed = 0,
            mythicLevel = 8,
        },
    }
}

local UPGRADE_TRACKS = {
    EXPLORER = {
        color = "FFffffff",
        crest = "Weathered Harbinger Crest",
        shortname = "Weathered",
        finalCrest = "Carved Harbinger Crest",
        upgradeLevels = 8
    },
    VETERAN  = {
        color = "FF1eff00",
        crest = "Weathered Harbinger Crest",
        shortname = "Weathered",
        finalCrest = "Carved Harbinger Crest",
        upgradeLevels = 8
    },
    CHAMPION = {
        color = "FF0070dd",
        crest = "Carved Harbinger Crest",
        shortname = "Carved",
        finalCrest = "Runed Harbinger Crest",
        upgradeLevels = 8
    },
    HERO     = {
        color = "FFa335ee",
        crest = "Runed Harbinger Crest",
        shortname = "Runed",
        finalCrest = "Gilded Harbinger Crest",
        upgradeLevels = 6
    },
    MYTH     = {
        color = "FFff8000",
        crest = "Gilded Harbinger Crest",
        shortname = "Gilded",
        finalCrest = "Gilded Harbinger Crest",
        upgradeLevels = 6
    }
}

local upgradeTextPool = {}
local tooltipFrame = CreateFrame("GameTooltip", "GearUpgradeTooltip", UIParent, "GameTooltipTemplate")
local totalCrestFrame = CreateFrame("Frame", "GearUpgradeTotalFrame", CharacterFrame)
local totalCrestText = totalCrestFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")

totalCrestFrame:SetSize(200, 40)
totalCrestFrame:SetPoint("BOTTOMRIGHT", CharacterFrame, "BOTTOMRIGHT", -10, 10)

totalCrestText:SetPoint("RIGHT", totalCrestFrame, "RIGHT", 0, 0)
totalCrestText:SetTextColor(1, 0.8, 0)
totalCrestText:SetFont(totalCrestText:GetFont(), 11, "OUTLINE")
totalCrestText:SetJustifyH("RIGHT")

-- **Fetch Crest Currency Amounts**
local function CheckCurrencyForAllCrests()
    -- Reset currency counts
    for crestType, _ in pairs(CURRENCY.CRESTS) do
        CURRENCY.CRESTS[crestType].current = 0
        CURRENCY.CRESTS[crestType].needed = 0
    end

    local numCurrencies = C_CurrencyInfo.GetCurrencyListSize()
    for i = 1, numCurrencies do
        local currencyInfo = C_CurrencyInfo.GetCurrencyListInfo(i)
        if currencyInfo and not currencyInfo.isHeader and string.find(currencyInfo.name, "Harbinger Crest") then
            for trackName, track in pairs(UPGRADE_TRACKS) do
                if track.crest == currencyInfo.name then
                    local crestType = track.shortname:upper()
                    CURRENCY.CRESTS[crestType].current = currencyInfo.quantity
                end
            end
        end
    end
end

-- **Creates Upgrade Text for a Slot**
local function CreateUpgradeText(slot)
    local slotFrame = _G["Character" .. slot]
    if not slotFrame then return end

    local text = slotFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetPoint("TOPRIGHT", slotFrame, "TOPRIGHT", 6, 2)
    text:SetJustifyH("RIGHT")
    text:SetDrawLayer("OVERLAY", 7)
    text:SetFont(text:GetFont(), 14, "OUTLINE, THICKOUTLINE")
    return text
end

-- **Initialize All Equipment Slot Overlays**
local function InitializeUpgradeTexts()
    for _, slot in ipairs(EQUIPMENT_SLOTS) do
        upgradeTextPool[slot] = CreateUpgradeText(slot)
    end
end

-- **Tooltip Setup for Crest Costs**
local function SetUpgradeTooltip(self, track, remaining)
    tooltipFrame:SetOwner(self, "ANCHOR_RIGHT")
    tooltipFrame:AddLine("Upgrade Requirements:")

    local regularCrestCount = math.max(0, (remaining - 2) * CRESTS_TO_UPGRADE)
    local finalCrestCount = remaining > 2 and (2 * CRESTS_TO_UPGRADE) or (remaining * CRESTS_TO_UPGRADE)

    if regularCrestCount > 0 then
        local crestType = track.shortname:upper()
        local mythicText = CURRENCY.CRESTS[crestType].mythicLevel and 
            string.format(" (M%d+)", CURRENCY.CRESTS[crestType].mythicLevel) or ""
        tooltipFrame:AddLine(string.format("%d x %s%s", regularCrestCount, track.crest, mythicText))
    end
    
    if finalCrestCount > 0 then
        local finalCrestType = ""
        for _, upgradeTrack in pairs(UPGRADE_TRACKS) do
            if upgradeTrack.crest == track.finalCrest then
                finalCrestType = upgradeTrack.shortname:upper()
                break
            end
        end
        local mythicText = finalCrestType ~= "" and CURRENCY.CRESTS[finalCrestType].mythicLevel and 
            string.format(" (M%d+)", CURRENCY.CRESTS[finalCrestType].mythicLevel) or ""
        tooltipFrame:AddLine(string.format("%d x %s%s", finalCrestCount, track.finalCrest, mythicText))
    end

    tooltipFrame:Show()
end

-- **Update All Equipment Slots & Crest Totals**
local function UpdateAllUpgradeTexts()
    CheckCurrencyForAllCrests()

    -- Reset needed counts
    for crestType, _ in pairs(CURRENCY.CRESTS) do
        CURRENCY.CRESTS[crestType].needed = 0
    end

    for _, slot in ipairs(EQUIPMENT_SLOTS) do
        local text = upgradeTextPool[slot]
        if not text then return end

        local slotID = GetInventorySlotInfo(slot)
        local itemLink = GetInventoryItemLink("player", slotID)

        if itemLink then
            local effectiveILvl = select(4, C_Item.GetItemInfo(itemLink))
            local tooltipData = C_TooltipInfo.GetInventoryItem("player", slotID)

            if effectiveILvl and tooltipData then
                for _, line in ipairs(tooltipData.lines) do
                    local trackName, current, max = line.leftText:match("Upgrade Level: (%w+) (%d+)/(%d+)")
                    if trackName then
                        local trackUpper = trackName:upper()
                        local levelsToUpgrade = tonumber(max) - tonumber(current)
                        local track = UPGRADE_TRACKS[trackUpper]

                        -- Update the UI text and tooltip
                        if track and levelsToUpgrade > 0 then
                            text:SetText("|cFFffffff+" .. levelsToUpgrade .. "|r")
                            text:Show()

                            text:SetScript("OnEnter", function(self)
                                SetUpgradeTooltip(self, track, levelsToUpgrade)
                            end)
                            text:SetScript("OnLeave", function() tooltipFrame:Hide() end)

                            -- Calculate crests needed
                            local stdLevelCrestCount = levelsToUpgrade > 2 and (levelsToUpgrade - 2) * CRESTS_TO_UPGRADE or 0
                            local nextLevelCrestCount = levelsToUpgrade > 2 and (2 * CRESTS_TO_UPGRADE) or (levelsToUpgrade * CRESTS_TO_UPGRADE)

                            -- Update standard crest counts
                            if stdLevelCrestCount > 0 then
                                local crestType = track.shortname:upper()
                                CURRENCY.CRESTS[crestType].needed = CURRENCY.CRESTS[crestType].needed + stdLevelCrestCount
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
                                    CURRENCY.CRESTS[finalCrestType].needed = CURRENCY.CRESTS[finalCrestType].needed + nextLevelCrestCount
                                end
                            end
                        else
                            text:SetText("")
                        end
                        break
                    end
                end
            end
        else
            text:SetText("")
        end
    end

    -- Display totals with correct M+ levels
    --sort in order of mythic level from lowest to highest
    local sortedCrests = {}
    for crestType, data in pairs(CURRENCY.CRESTS) do
        if data.needed > 0 then
            sortedCrests[#sortedCrests + 1] = {crestType = crestType, data = data}
        end
    end
    table.sort(sortedCrests, function(a, b) return a.data.mythicLevel < b.data.mythicLevel end)

    local totalText = ""
    for _, crestData in ipairs(sortedCrests) do
        local crestType = crestData.crestType
        local data = crestData.data
        if data.needed > 0 then
            if data.mythicLevel and data.mythicLevel > 0 then
                totalText = totalText .. string.format("\n%s: %d (M%d+ Runs: %d)", 
                    crestType:sub(1,1) .. crestType:sub(2):lower(),
                    data.needed,
                    data.mythicLevel,
                    math.ceil(data.needed / CRESTS_TO_UPGRADE))
            else
                totalText = totalText .. string.format("\n%s: %d",
                    crestType:sub(1,1) .. crestType:sub(2):lower(),
                    data.needed)
            end
        end
    end

    if totalText ~= "" then
        totalCrestText:SetText("Total Crests Required:" .. totalText)
        totalCrestText:Show()
    else
        totalCrestText:Hide()
    end
end

-- **Event Handling**
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")

f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        InitializeUpgradeTexts()
    end
    UpdateAllUpgradeTexts()
end)

CharacterFrame:HookScript("OnShow", UpdateAllUpgradeTexts)
