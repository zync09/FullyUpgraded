local addonName, addon = ...
addon.f = CreateFrame("Frame") -- Main frame
local f = addon.f

local CRESTS_TO_UPGRADE = 15
local CRESTS_CONVERSION_UP = 45

local EQUIPMENT_SLOTS = {
    "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot",
    "WristSlot", "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot",
    "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot",
    "MainHandSlot", "SecondaryHandSlot"
}

local CURRENCY = {
    CRESTS = {
        WEATHERED = {
            name = "Weathered Harbinger Crest",
            current = 0,
            needed = 0,
            upgraded = 0,
            mythicLevel = 0,
            upgradesTo = "CARVED"
        },
        CARVED = {
            name = "Carved Harbinger Crest",
            current = 0,
            needed = 0,
            upgraded = 0,
            mythicLevel = 2,
            upgradesTo = "RUNED"
        },
        RUNED = {
            name = "Runed Harbinger Crest",
            current = 0,
            needed = 0,
            upgraded = 0,
            mythicLevel = 4,
            upgradesTo = "GILDED"
        },
        GILDED = {
            name = "Gilded Harbinger Crest",
            current = 0,
            needed = 0,
            upgraded = 0,
            mythicLevel = 8,
            upgradesTo = nil
        }
    }
}

local UPGRADE_TRACKS = {
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

-- Function to check if character tab is selected
local function IsCharacterTabSelected()
    return PaperDollFrame:IsVisible()
end

-- Function to update frame visibility
local function UpdateFrameVisibility()
    if IsCharacterTabSelected() then
        totalCrestFrame:Show()
    else
        totalCrestFrame:Hide()
    end
end

-- Ordered list of crest types from lowest to highest tier
local CREST_ORDER = {"WEATHERED", "CARVED", "RUNED", "GILDED"}

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
        local previousType = CREST_ORDER[i-1]
        
        if CURRENCY.CRESTS[currentType] and CURRENCY.CRESTS[previousType] then
            local currentCrest = CURRENCY.CRESTS[currentType]
            local previousCrest = CURRENCY.CRESTS[previousType]
            
            -- Calculate how many crests can be upgraded from the previous tier
            local upgradedCount = math.floor(previousCrest.current / CRESTS_CONVERSION_UP)
            currentCrest.upgraded = upgradedCount
        end
    end
end

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
            tooltipFrame:AddLine(string.format("%d x %s%s", remainingFirstTier * CRESTS_TO_UPGRADE, firstTier.crest, mythicText))
        end

        if remainingSecondTier > 0 and secondTier.crest then
            local crestType = secondTier.shortname:upper()
            local mythicText = CURRENCY.CRESTS[crestType] and CURRENCY.CRESTS[crestType].mythicLevel > 0 and
                string.format(" (M%d+)", CURRENCY.CRESTS[crestType].mythicLevel) or ""
            tooltipFrame:AddLine(string.format("%d x %s%s", remainingSecondTier * CRESTS_TO_UPGRADE, secondTier.crest, mythicText))
        end
    end

    tooltipFrame:Show()
end

-- **Update All Equipment Slots & Crest Totals**
local function UpdateAllUpgradeTexts()
    CalculateUpgradedCrests()
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
                                SetUpgradeTooltip(self, track, levelsToUpgrade, tonumber(current))
                            end)
                            text:SetScript("OnLeave", function() tooltipFrame:Hide() end)

                            -- Skip crest calculations for Explorer track
                            if not track.crest then
                                -- No crest requirements to calculate
                                text:SetText("|cFFffffff+" .. levelsToUpgrade .. "|r")
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
            sortedCrests[#sortedCrests + 1] = { crestType = crestType, data = data }
        end
    end
    table.sort(sortedCrests, function(a, b) return a.data.mythicLevel < b.data.mythicLevel end)

    local totalText = ""
    for _, crestData in ipairs(sortedCrests) do
        local crestType = crestData.crestType
        local data = crestData.data
        if data.needed > 0 then
            --subtract current crests from needed crests and show it as (xx/xx)
            local remaining = data.needed - data.current
            local potentialExtra = data.upgraded * CRESTS_TO_UPGRADE
            local upgradedText = data.upgraded and data.upgraded > 0 
                and string.format(" [+%d P.Tier]", potentialExtra)
                or ""

            if data.mythicLevel and data.mythicLevel > 0 then
                local currentRuns = math.max(0, math.ceil(remaining / CRESTS_TO_UPGRADE))
                local potentialRuns = math.max(0, math.ceil((remaining - potentialExtra) / CRESTS_TO_UPGRADE))
                
                local runsText
                if potentialRuns > 0 and potentialRuns < currentRuns then
                    runsText = string.format("M%d+ Runs: [%d]/%d", data.mythicLevel, potentialRuns, currentRuns)
                else
                    runsText = string.format("M%d+ Runs: %d", data.mythicLevel, currentRuns)
                end
                
                totalText = totalText .. string.format("\n%s: %d/%d%s (%s)",
                    crestType:sub(1,1) .. crestType:sub(2):lower(),
                    data.current,
                    data.needed,
                    upgradedText,
                    runsText)
            else
                totalText = totalText .. string.format("\n%s: %d/%d%s",
                    crestType:sub(1,1) .. crestType:sub(2):lower(),
                    data.current,
                    data.needed,
                    upgradedText)
            end
        end
    end

    if totalText ~= "" then
        totalCrestText:SetText("Fully Upgraded:" .. totalText)
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
        CalculateUpgradedCrests()
        InitializeUpgradeTexts()
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
