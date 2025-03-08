local addonName, addon = ...

-- Import constants and references
local CURRENCY = addon.CURRENCY
local CREST_ORDER = addon.CREST_ORDER
local TEXT_POSITIONS = addon.TEXT_POSITIONS

-- Helper function
local function IsCharacterTabSelected()
    return PaperDollFrame:IsVisible()
end

-- Create display elements for a single crest type
local function CreateCrestDisplay(parent)
    local display = {
        frame = CreateFrame("Frame", nil, parent),
        container = CreateFrame("Frame", nil, parent),
        shortName = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal"),
        icon = parent:CreateTexture(nil, "ARTWORK"),
        count = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal"),
        runsNeeded = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    }

    -- Set up container frame for better layout control
    display.container:SetSize(230, 16) -- Reduced height and width

    -- Set up frame for tooltip and layout
    display.frame:SetSize(220, 16) -- Reduced height and width
    display.frame:SetParent(display.container)
    display.frame:SetPoint("LEFT", display.container, "LEFT", 5, 0)
    display.frame:EnableMouse(true)

    -- Set up shortName with consistent width and alignment
    display.shortName:SetFont(display.shortName:GetFont(), 12, "OUTLINE")
    display.shortName:SetPoint("LEFT", display.frame, "LEFT", 8, 0)
    display.shortName:SetJustifyH("LEFT")
    display.shortName:SetWidth(20) -- Fixed width for consistent icon alignment

    -- Set up icon with precise positioning
    display.icon:SetSize(16, 16)
    display.icon:SetPoint("LEFT", display.frame, "LEFT", 26, 0) -- Fixed position relative to frame

    -- Set up count text with consistent spacing
    display.count:SetFont(display.count:GetFont(), 12, "OUTLINE")
    display.count:SetPoint("LEFT", display.icon, "RIGHT", 6, 0)
    display.count:SetJustifyH("LEFT")
    display.count:SetTextColor(1, 1, 1)

    -- Set up runs needed text with right alignment
    display.runsNeeded:SetFont(display.count:GetFont(), 12, "OUTLINE")
    display.runsNeeded:SetPoint("RIGHT", display.frame, "RIGHT", -5, 0) -- Position from right edge
    display.runsNeeded:SetJustifyH("RIGHT")
    display.runsNeeded:SetTextColor(0.7, 0.7, 0.7)

    return display
end

-- Position a single crest display
local function PositionCrestDisplay(display, parent, index, totalDisplays)
    if not display then return end

    local spacing = 1          -- Spacing between currency displays
    local baseHeight = 16      -- Reduced height of each currency display
    local containerWidth = 230 -- Match container width from CreateCrestDisplay

    -- Position the container vertically with consistent spacing
    display.container:ClearAllPoints()
    if index == 1 then
        display.container:SetPoint("TOP", parent, "TOP", 0, -1)
    else
        display.container:SetPoint("TOP", parent, "TOP", 0, -((index - 1) * (baseHeight + spacing)) - 1)
    end

    -- Set container width
    display.container:SetWidth(containerWidth)

    -- Update parent frame height based on total displays
    local totalHeight = (totalDisplays * baseHeight) + ((totalDisplays - 1) * spacing) + 2
    parent:SetHeight(totalHeight)
    parent:SetWidth(containerWidth)

    -- Show all elements
    display.container:Show()
    display.frame:Show()
    display.shortName:Show()
    display.icon:Show()
    display.count:Show()
    display.runsNeeded:Show()
end

-- Update a single crest display
local function UpdateCrestDisplay(display, info, crestData)
    if not display or not info then return end

    -- Update shortName (first letter of crest type)
    local shortName = crestData.reallyshortname or ""
    display.shortName:SetText(shortName)

    -- Set color from CREST_BASE using the exact crest type (WEATHERED, CARVED, etc)
    local crestBaseData
    for crestType, baseData in pairs(addon.CREST_BASE) do
        if baseData.shortCode == crestData.reallyshortname then
            local r = tonumber(baseData.color:sub(1, 2), 16) / 255
            local g = tonumber(baseData.color:sub(3, 4), 16) / 255
            local b = tonumber(baseData.color:sub(5, 6), 16) / 255
            -- Apply color to both shortName and count
            display.shortName:SetTextColor(r, g, b)
            display.count:SetTextColor(r, g, b)
            crestBaseData = baseData
            crestBaseData.crestType = crestType -- Store the actual crest type
            break
        end
    end

    -- Update icon
    display.icon:SetTexture(info.iconFileID)

    -- Update count text (without runs calculation)
    local needed = crestData.needed or 0
    local current = info.quantity or 0
    display.count:SetText(current .. "/" .. needed)

    -- Reset and update runs needed text
    display.runsNeeded:SetText("")

    -- Calculate runs needed if this crest type has mythic requirements
    if crestBaseData and crestBaseData.mythicLevel and crestBaseData.mythicLevel > 0 then
        -- Only show runs if we need more crests
        if current < needed then
            -- Get rewards for this crest type
            local rewards = addon.CREST_REWARDS[crestBaseData.crestType]

            -- Debug output
            if addon.debugMode then
                print("Crest Type:", crestBaseData.crestType)
                print("Has Rewards:", rewards ~= nil)
                print("Mythic Level:", crestBaseData.mythicLevel)
                print("Current/Needed:", current, "/", needed)
            end

            if rewards then
                local remaining = needed - current

                -- Find lowest M+ level reward (from minimum required level)
                local lowestReward = nil
                for level = crestBaseData.mythicLevel, 20 do
                    if rewards[level] and rewards[level].timed then
                        lowestReward = rewards[level].timed
                        break
                    end
                end

                -- Find highest M+ level reward
                local highestReward = nil
                for level = 20, crestBaseData.mythicLevel, -1 do
                    if rewards[level] and rewards[level].timed then
                        highestReward = rewards[level].timed
                        break
                    end
                end

                -- Debug output
                if addon.debugMode then
                    print("Lowest Reward:", lowestReward)
                    print("Highest Reward:", highestReward)
                end

                if lowestReward and highestReward then
                    -- Calculate min/max runs needed
                    local maxRuns = math.ceil(remaining / lowestReward)
                    local minRuns = math.ceil(remaining / highestReward)


                    -- Set runs needed text with "runs" prefix in smaller font
                    display.runsNeeded:SetFont(display.runsNeeded:GetFont(), 10, "OUTLINE")
                    display.runsNeeded:SetText(string.format("M+ runs (%d/%d)", minRuns, maxRuns))

                    -- Ensure runs text is properly positioned
                    display.runsNeeded:ClearAllPoints()
                    display.runsNeeded:SetPoint("RIGHT", display.frame, "RIGHT", -5, 0)

                    -- Add a timer to recalculate positions
                    C_Timer.After(0.05, function()
                        if display.container:GetParent().UpdateFrameSize then
                            display.container:GetParent():UpdateFrameSize()
                        end
                    end)
                end
            end
        end
    end

    -- Set up tooltip
    display.frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(info.name)
        GameTooltip:AddLine("Current: " .. info.quantity, 1, 1, 1)
        if crestData.needed and crestData.needed > 0 then
            GameTooltip:AddLine("Needed: " .. crestData.needed, 1, 0.82, 0)
        end


        -- Add sources from CREST_BASE
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

                -- Find which raid difficulty awards this crest type
                for raidName, raidData in pairs(addon.RAID_REWARDS) do
                    for difficulty, rewardType in pairs(raidData.difficulties) do
                        if rewardType == crestBaseData.crestType then
                            GameTooltip:AddLine(string.format("%s (%s):", raidData.name, difficulty), 0.9, 0.9, 0.9)
                            -- Calculate total potential crests
                            local totalCrests = 0
                            for _, boss in ipairs(raidData.bosses) do
                                GameTooltip:AddLine(string.format("• %s: |cFF00FF00%d|r crests", boss.name, boss.reward),
                                    0.8, 0.8, 0.8)
                                if boss.name == "First Six Bosses" then
                                    totalCrests = totalCrests + (boss.reward * 6)
                                else
                                    totalCrests = totalCrests + (boss.reward * 2)
                                end
                            end
                            GameTooltip:AddLine(string.format("Total potential crests: |cFF00FF00%d|r", totalCrests), 0.8,
                                0.8, 0.8)
                        end
                    end
                end

                -- Add dungeon rewards if this crest type has mythic requirements
                if baseData.mythicLevel and baseData.mythicLevel > 0 then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("Dungeon Rewards:", 0.9, 0.7, 0)

                    -- Get rewards for this crest type
                    local rewards = addon.CREST_REWARDS[crestType]
                    if rewards then
                        -- Calculate total needed runs
                        local remaining = crestData.needed and
                            math.max(0, crestData.needed - crestData.current - (crestData.upgraded or 0)) or 0

                        for level = baseData.mythicLevel, 20 do
                            if rewards[level] then
                                local rewardAmount = rewards[level].timed
                                local expiredAmount = math.max(0, rewardAmount - addon.EXPIRED_KEYSTONE_DEDUCTION)

                                -- Calculate runs needed for both normal and expired rewards
                                local runsNeeded = remaining > 0 and math.ceil(remaining / rewardAmount) or 0
                                local expiredRunsNeeded = remaining > 0 and math.ceil(remaining / expiredAmount) or 0

                                -- Format the line with colored M+ level, green reward, and runs info
                                local levelText = string.format("|cFF%sM%d|r", baseData.color, level)
                                local rewardText = string.format("|cFF00FF00%d|r", rewardAmount)
                                local runsText = string.format("(%d runs)", runsNeeded)
                                local expiredText = string.format("| Expired: |cFFFF0000%d|r (%d runs)", expiredAmount,
                                    expiredRunsNeeded)

                                -- Always show both normal and expired rewards
                                GameTooltip:AddLine(
                                    string.format("%s: %s %s %s", levelText, rewardText, runsText, expiredText),
                                    1, 1, 1, true)
                            end
                        end
                    end
                end
                break
            end
        end

        GameTooltip:Show()
    end)

    display.frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

-- Main update function for currency display
local function UpdateCrestCurrency(parent)
    -- Use the existing frame from parent
    local frame = parent
    frame.displays = frame.displays or {}

    -- Clear existing displays
    if frame.displays then
        for _, display in pairs(frame.displays) do
            if display.frame then display.frame:Hide() end
            if display.shortName then display.shortName:Hide() end
            if display.icon then display.icon:Hide() end
            if display.count then display.count:Hide() end
            if display.runsNeeded then display.runsNeeded:Hide() end
        end
    end

    -- Count how many displays we'll have
    local displayCount = 0
    for _, crestType in ipairs(CREST_ORDER) do
        local crestData = CURRENCY.CRESTS[crestType]
        if crestData and crestData.currencyID then
            displayCount = displayCount + 1
        end
    end

    -- Update each crest display
    local index = 1

    -- Display crests in order from CREST_ORDER (weathered to gilded)
    for _, crestType in ipairs(CREST_ORDER) do
        local crestData = CURRENCY.CRESTS[crestType]
        if crestData and crestData.currencyID then
            local info = C_CurrencyInfo.GetCurrencyInfo(crestData.currencyID)
            if info then
                -- Create or get existing display
                if not frame.displays[crestType] then
                    frame.displays[crestType] = CreateCrestDisplay(frame)
                end

                local display = frame.displays[crestType]
                if display then
                    UpdateCrestDisplay(display, info, crestData)
                    PositionCrestDisplay(display, frame, index, displayCount)
                    index = index + 1
                end
            end
        end
    end

    -- Update frame visibility
    if IsCharacterTabSelected() then
        frame:Show()
    else
        frame:Hide()
    end
end

-- Set up event handlers
local function SetupEventHandlers()
    -- Update when character frame is shown
    CharacterFrame:HookScript("OnShow", function()
        if IsCharacterTabSelected() then
            UpdateCrestCurrency(_G["GearUpgradeCurrencyFrame"]) -- Use the global frame
        end
    end)

    -- Update when currency changes
    local currencyEventFrame = CreateFrame("Frame")
    currencyEventFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
    currencyEventFrame:SetScript("OnEvent", function()
        if IsCharacterTabSelected() then
            UpdateCrestCurrency(_G["GearUpgradeCurrencyFrame"]) -- Use the global frame
        end
    end)

    -- Hide tooltips when character frame is hidden
    CharacterFrame:HookScript("OnHide", function()
        GameTooltip:Hide()
    end)

    -- Hide tooltips when switching tabs
    PaperDollFrame:HookScript("OnHide", function()
        GameTooltip:Hide()
    end)
end

-- Export the update function
addon.UpdateCrestCurrency = UpdateCrestCurrency

-- Initialize
SetupEventHandlers()
