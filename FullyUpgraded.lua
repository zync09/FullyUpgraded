local addonName, addon = ...

-- Make the frame part of our addon table
addon.f = CreateFrame("Frame")
local f = addon.f  -- Local reference for convenience

CRESTS_TO_UPGRADE = 15

-- Maps numerical indices to WoW's internal slot names
local EQUIPMENT_SLOTS = {
    [1] = "HeadSlot",
    [2] = "NeckSlot",
    [3] = "ShoulderSlot",
    [4] = "BackSlot",
    [5] = "ChestSlot",
    [6] = "WristSlot",
    [7] = "HandsSlot",
    [8] = "WaistSlot",
    [9] = "LegsSlot",
    [10] = "FeetSlot",
    [11] = "Finger0Slot",
    [12] = "Finger1Slot",
    [13] = "Trinket0Slot",
    [14] = "Trinket1Slot",
    [15] = "MainHandSlot",
    [16] = "SecondaryHandSlot"
}

-- DEFAULT_CHAT_FRAME:AddMessage("Debug 3: Equipment slots defined", 1, 1, 0)

-- Pool to store font string objects for each equipment slot
local upgradeTextPool = {}

-- Upgrade track definitions with colors and crest requirements
local UPGRADE_TRACKS = {
    EXPLORER = {
        color = "FF1eff00", -- Green
        crest = "Weathered Harbinger Crest",
        finalCrest = "Carved Harbinger Crest",
        currencyCount = 1,
    },
    VETERAN = {
        color = "FF1eff00", -- Green (Uncommon)
        crest = "Weathered Harbinger Crest",
        finalCrest = "Carved Harbinger Crest", -- Last 2 upgrades
        currencyCount = 0,
    },
    CHAMPION = {
        color = "FF0070dd", -- Blue (Rare)
        crest = "Carved Harbinger Crest",
        finalCrest = "Runed Harbinger Crest",
        currencyCount = 0,
    },
    HERO = {
        color = "FFa335ee", -- Purple (Epic)
        crest = "Runed Harbinger Crest",
        finalCrest = "Gilded Harbinger Crest",
        currencyCount = 0,
    },
    MYTHIC = {
        color = "FFff8000", -- Orange (Legendary)
        crest = "Gilded Harbinger Crest",
        finalCrest = "Gilded Harbinger Crest", -- Same for mythic
        currencyCount = 0,
    }
}

--create a function to check currency for all crests
local function CheckCurrencyForAllCrests()
    for _, track in pairs(UPGRADE_TRACKS) do
        local currencyCount = track.currencyCount
        local currencyName = track.currencyName
        local currencyAmount = GetCurrencyInfo(currencyName)
        DEFAULT_CHAT_FRAME:AddMessage(string.format("Currency: %s, Amount: %d", currencyName, currencyAmount))

        UPGRADE_TRACKS[track].currencyCount = currencyAmount
    end
end



-- Creates a new font string overlay for displaying upgrade counts
-- @param slot: The equipment slot name to update
-- Creates a font string overlay to display upgrade counts for a given equipment slot
local function CreateUpgradeText(slot)
    local slotFrame = _G["Character"..slot]
    if not slotFrame then 
        DEFAULT_CHAT_FRAME:AddMessage("Failed to find frame for slot: " .. slot)
        return 
    end

    -- Create a new font string attached to the slot frame
    local text = slotFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    -- Position the text in the top right corner with a small offset
    text:SetPoint("TOPRIGHT", slotFrame, "TOPRIGHT", 2, 2)
    -- Set the text color to gold (RGB: 1, 0.8, 0)
    text:SetTextColor(1, 0.8, 0)  -- Gold color
    -- Align the text to the right
    text:SetJustifyH("RIGHT")
    -- Set the drawing layer to ensure visibility
    text:SetDrawLayer("OVERLAY", 7)
    -- Configure the font with size 12 and both outline styles
    text:SetFont(text:GetFont(), 12, "OUTLINE, THICKOUTLINE")
    -- Return the configured font string
    return text
end

-- DEFAULT_CHAT_FRAME:AddMessage("Debug 4: CreateUpgradeText function defined", 1, 1, 0)

-- Initializes upgrade text displays for all equipment slots
local function InitializeUpgradeTexts()
    -- DEFAULT_CHAT_FRAME:AddMessage("Starting to initialize upgrade texts...")
    for _, slot in pairs(EQUIPMENT_SLOTS) do
        upgradeTextPool[slot] = CreateUpgradeText(slot)
    end
    -- DEFAULT_CHAT_FRAME:AddMessage("Finished initializing upgrade texts")
end

-- Create the tooltip frame
local tooltipFrame = CreateFrame("GameTooltip", "GearUpgradeTooltip", UIParent, "GameTooltipTemplate")

-- Updates the upgrade count display for a single equipment slot
local function UpdateUpgradeText(slot)
    local text = upgradeTextPool[slot]
    if not text then return end
    
    local slotID = GetInventorySlotInfo(slot)
    local itemLink = GetInventoryItemLink("player", slotID)
    
    if itemLink then
        local effectiveILvl = select(4, C_Item.GetItemInfo(itemLink))
        local itemString = string.match(itemLink, "item[%-?%d:]+")
        
        if itemString and effectiveILvl then
            -- Get the upgrade track info from the tooltip
            local tooltipData = C_TooltipInfo.GetInventoryItem("player", slotID)
            
            -- Debug output
            -- DEFAULT_CHAT_FRAME:AddMessage(string.format(
            --     "Examining item in %s: iLvl: %d, Raw: %s", 
            --     slot,
            --     effectiveILvl or 0,
            --     itemString or "nil"
            -- ))
            
            -- Look for upgrade track info in tooltip
            local track, currentLevel, maxLevel
            if tooltipData then
                for _, line in ipairs(tooltipData.lines) do
                    -- Look for "Upgrade Level: X/Y" in tooltip
                    local trackName, current, max = line.leftText:match("Upgrade Level: (%w+) (%d+)/(%d+)")
                    if trackName then
                        track = trackName:upper()
                        currentLevel = tonumber(current)
                        maxLevel = tonumber(max)
                        break
                    end
                end
            end
            
            if track and currentLevel and maxLevel then
                if currentLevel < maxLevel then
                    local remaining = maxLevel - currentLevel
                    local trackInfo = UPGRADE_TRACKS[track]
                    
                    -- Color the text based on track
                    text:SetText("|c" .. trackInfo.color .. "+" .. remaining .. "|r")
                    text:Show()
                    
                    -- Add tooltip functionality
                    text:SetScript("OnEnter", function(self)
                        tooltipFrame:SetOwner(self, "ANCHOR_RIGHT")
                        tooltipFrame:AddLine("Upgrade Requirements:")
                        
                        -- Calculate crest requirements (multiply by 15)
                        local regularCrestCount = remaining * CRESTS_TO_UPGRADE
                        local finalCrestCount = 0
                        
                        -- Last two upgrades need higher tier crest
                        if remaining > 2 then
                            regularCrestCount = (remaining - 2) * CRESTS_TO_UPGRADE
                            finalCrestCount = 2 * CRESTS_TO_UPGRADE
                        else
                            finalCrestCount = remaining * CRESTS_TO_UPGRADE
                            regularCrestCount = 0
                        end
                        
                        -- Show regular crest requirements if any
                        if regularCrestCount > 0 then
                            tooltipFrame:AddLine(string.format("%d x %s", 
                                regularCrestCount, 
                                trackInfo.crest))
                        end
                        
                        -- Show final crest requirements if any
                        if finalCrestCount > 0 then
                            tooltipFrame:AddLine(string.format("%d x %s", 
                                finalCrestCount, 
                                trackInfo.finalCrest))
                        end
                        
                        tooltipFrame:Show()
                    end)
                    
                    text:SetScript("OnLeave", function(self)
                        tooltipFrame:Hide()
                    end)
                    
                    -- DEFAULT_CHAT_FRAME:AddMessage(string.format(
                    --     "Found %s item in %s (Level %d/%d)", 
                    --     track,
                    --     slot,
                    --     currentLevel,
                    --     maxLevel
                    -- ))
                else
                    text:SetText("")
                end
            else
                text:SetText("")
            end
        else
            text:SetText("")
        end
    else
        text:SetText("")
    end
end

-- Create frame for total crest count
local totalCrestFrame = CreateFrame("Frame", "GearUpgradeTotalFrame", CharacterFrame)
totalCrestFrame:SetSize(200, 40)
totalCrestFrame:SetPoint("BOTTOMRIGHT", CharacterFrame, "BOTTOMRIGHT", -10, 10)

local totalCrestText = totalCrestFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
totalCrestText:SetPoint("RIGHT", totalCrestFrame, "RIGHT", 0, 0)
totalCrestText:SetTextColor(1, 0.8, 0)  -- Gold color
totalCrestText:SetFont(totalCrestText:GetFont(), 11, "OUTLINE")
totalCrestText:SetJustifyH("RIGHT")

-- Modify UpdateAllUpgradeTexts to calculate and show totals
local function UpdateAllUpgradeTexts()
    -- DEFAULT_CHAT_FRAME:AddMessage("Updating all upgrade texts")
    
    local totalWeathered = 0
    local totalCarved = 0
    local totalRuned = 0
    local totalGilded = 0
    
    for _, slot in pairs(EQUIPMENT_SLOTS) do
        UpdateUpgradeText(slot)
        
        -- Calculate totals
        local slotID = GetInventorySlotInfo(slot)
        local itemLink = GetInventoryItemLink("player", slotID)
        
        if itemLink then
            local tooltipData = C_TooltipInfo.GetInventoryItem("player", slotID)
            if tooltipData then
                for _, line in ipairs(tooltipData.lines) do
                    local trackName, current, max = line.leftText:match("Upgrade Level: (%w+) (%d+)/(%d+)")
                    if trackName then
                        local track = trackName:upper()
                        local remaining = tonumber(max) - tonumber(current)
                        if remaining > 0 then
                            local trackInfo = UPGRADE_TRACKS[track]
                            if trackInfo then
                                if remaining > 2 then
                                    -- Add regular crests
                                    if trackInfo.crest == "Weathered Harbinger Crest" then
                                        totalWeathered = totalWeathered + ((remaining - 2) * CRESTS_TO_UPGRADE)
                                    elseif trackInfo.crest == "Carved Harbinger Crest" then
                                        totalCarved = totalCarved + ((remaining - 2) * CRESTS_TO_UPGRADE)
                                    elseif trackInfo.crest == "Runed Harbinger Crest" then
                                        totalRuned = totalRuned + ((remaining - 2) * CRESTS_TO_UPGRADE)
                                    elseif trackInfo.crest == "Gilded Harbinger Crest" then
                                        totalGilded = totalGilded + ((remaining - 2) * CRESTS_TO_UPGRADE)
                                    end
                                    
                                    -- Add final crests
                                    if trackInfo.finalCrest == "Carved Harbinger Crest" then
                                        totalCarved = totalCarved + (2 * CRESTS_TO_UPGRADE)
                                    elseif trackInfo.finalCrest == "Runed Harbinger Crest" then
                                        totalRuned = totalRuned + (2 * CRESTS_TO_UPGRADE)
                                    elseif trackInfo.finalCrest == "Gilded Harbinger Crest" then
                                        totalGilded = totalGilded + (2 * CRESTS_TO_UPGRADE)
                                    end
                                else
                                    -- All upgrades use final crest
                                    if trackInfo.finalCrest == "Carved Harbinger Crest" then
                                        totalCarved = totalCarved + (remaining * CRESTS_TO_UPGRADE)
                                    elseif trackInfo.finalCrest == "Runed Harbinger Crest" then
                                        totalRuned = totalRuned + (remaining * CRESTS_TO_UPGRADE)
                                    elseif trackInfo.finalCrest == "Gilded Harbinger Crest" then
                                        totalGilded = totalGilded + (remaining * CRESTS_TO_UPGRADE)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Update total text
    --add the runs required as well assuming 15 per run
    local totalText = ""
    if totalWeathered > 0 then
        totalText = totalText .. "\nWeathered: " .. totalWeathered
    end
    if totalCarved > 0 then
        totalText = totalText .. "\nCarved: " .. totalCarved .. " (M2+) Runs: " .. math.ceil(totalCarved / CRESTS_TO_UPGRADE)
    end
    if totalRuned > 0 then
        totalText = totalText .. "\nRuned: " .. totalRuned .. " (M4+) Runs: " .. math.ceil(totalRuned / CRESTS_TO_UPGRADE)
    end
    if totalGilded > 0 then
        totalText = totalText .. "\nGilded: " .. totalGilded .. " (M8+) Runs: " .. math.ceil(totalGilded / CRESTS_TO_UPGRADE)
    end
    
    if totalText ~= "" then
        totalCrestText:SetText("Total Crests Required:" .. totalText)
        totalCrestText:Show()
    else
        totalCrestText:Hide()
    end
end

-- Register only valid events
local success, err = pcall(function()
    f:RegisterEvent("PLAYER_LOGIN")
    f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    -- DEFAULT_CHAT_FRAME:AddMessage("Debug 5: Events registered", 1, 1, 0)
end)

if not success then
    DEFAULT_CHAT_FRAME:AddMessage("FullUp: Error registering events: " .. tostring(err), 1, 0, 0)
end

-- Try to set up event handler
success, err = pcall(function()
    f:SetScript("OnEvent", function(self, event, ...)
        -- DEFAULT_CHAT_FRAME:AddMessage("Event fired: " .. event, 0, 1, 0)
        if event == "PLAYER_ENTERING_WORLD" then
            InitializeUpgradeTexts()
        end
        if event == "PLAYER_LOGIN" then
            CheckCurrencyForAllCrests()
        end
        UpdateAllUpgradeTexts()
    end)
    -- DEFAULT_CHAT_FRAME:AddMessage("Debug 6: Event handler set up", 1, 1, 0)
end)

if not success then
    -- DEFAULT_CHAT_FRAME:AddMessage("Error setting up event handler: " .. tostring(err), 1, 0, 0)
end

-- Hook character frame to update when opened
CharacterFrame:HookScript("OnShow", function()
    -- DEFAULT_CHAT_FRAME:AddMessage("Character frame shown", 1, 1, 0)
    UpdateAllUpgradeTexts()
end)
