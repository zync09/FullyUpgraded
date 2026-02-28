local addonName, addon = ...

-- Import constants and references
local CURRENCY = addon.CURRENCY
local CREST_ORDER = addon.CREST_ORDER

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

    -- Store tooltip data reference on the display for OnEnter access
    display.tooltipInfo = nil
    display.tooltipCrestData = nil

    -- Set tooltip scripts once (data updated per-refresh via display fields)
    display.frame:SetScript("OnEnter", function(self)
        if display.tooltipInfo and display.tooltipCrestData then
            addon.showTooltip(self, "ANCHOR_TOP", addon.tooltipProviders.crest,
                {info = display.tooltipInfo, crestData = display.tooltipCrestData})
        end
    end)
    display.frame:SetScript("OnLeave", addon.hideTooltip)

    return display
end

-- Position a single crest display
local function PositionCrestDisplay(display, parent, index)
    if not display then return end

    local spacing = 2          -- Spacing between currency displays
    local baseHeight = 16      -- Height of each currency display
    local containerWidth = 230 -- Match container width from CreateCrestDisplay

    -- Position the container vertically with consistent spacing
    display.container:ClearAllPoints()
    if index == 1 then
        display.container:SetPoint("TOP", parent, "TOP", 0, -spacing)
    else
        display.container:SetPoint("TOP", parent, "TOP", 0, -((index - 1) * (baseHeight + spacing)) - spacing)
    end

    -- Set container width
    display.container:SetWidth(containerWidth)

    -- Show all elements
    display.container:Show()
    display.frame:Show()
    display.shortName:Show()
    display.icon:Show()
    display.count:Show()
    display.runsNeeded:Show()
end

-- Update the frame size based on total displays
local function UpdateFrameSize(frame, displayCount)
    local spacing = 2
    local baseHeight = 16
    local padding = 4  -- Padding at top and bottom
    
    -- Calculate total height needed
    local totalHeight = (displayCount * baseHeight) + ((displayCount - 1) * spacing) + (padding * 2)
    
    -- Update the frame size
    frame:SetHeight(totalHeight)
    frame:SetWidth(230)
    
    -- Trigger master frame size update if available
    if frame:GetParent() and frame:GetParent().updateFrameSize then
        frame:GetParent():updateFrameSize()
    end
end

-- Update a single crest display
local function UpdateCrestDisplay(display, info, crestData, crestType)
    if not display or not info then return end

    -- Update shortName (first letter of crest type)
    local shortName = crestData.reallyshortname or ""
    display.shortName:SetText(shortName)

    -- Set color from CREST_BASE using pre-computed RGB values
    local crestBaseData = addon.CREST_BASE[crestType]
    if crestBaseData then
        local rgb = crestBaseData.colorRGB
        display.shortName:SetTextColor(rgb[1], rgb[2], rgb[3])
        display.count:SetTextColor(rgb[1], rgb[2], rgb[3])
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
            local rewards = addon.CREST_REWARDS[crestType]

            -- Debug output
            if addon.debugMode then
                print("Crest Type:", crestType)
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
                end
            end
        end
    end

    -- Update tooltip data for OnEnter (scripts set once in CreateCrestDisplay)
    display.tooltipInfo = info
    display.tooltipCrestData = crestData
end

-- Main update function for currency display
local function updateCrestCurrency(parent)
    -- Skip work if character tab isn't visible
    if not addon.isCharacterTabSelected() then
        parent:Hide()
        return
    end

    -- Use the existing frame from parent
    local frame = parent
    frame.displays = frame.displays or {}

    -- Hide all existing displays and return them to pool
    for _, display in pairs(frame.displays) do
        if display.container then display.container:Hide() end
        if display.frame then display.frame:Hide() end
        if display.shortName then display.shortName:Hide() end
        if display.icon then display.icon:Hide() end
        if display.count then display.count:Hide() end
        if display.runsNeeded then display.runsNeeded:Hide() end
    end

    -- Update each crest display
    local index = 1

    -- Display crests in order from CREST_ORDER (Adventurer → Myth)
    for _, crestType in ipairs(CREST_ORDER) do
        local crestData = CURRENCY.CRESTS[crestType]
        if crestData and crestData.currencyID then
            local success, info = pcall(C_CurrencyInfo.GetCurrencyInfo, crestData.currencyID)
            if success and info then
                -- Create or get existing display
                if not frame.displays[crestType] then
                    frame.displays[crestType] = CreateCrestDisplay(frame)
                end

                local display = frame.displays[crestType]
                if display then
                    UpdateCrestDisplay(display, info, crestData, crestType)
                    PositionCrestDisplay(display, frame, index)
                    index = index + 1
                end
            end
        end
    end

    -- Update frame size based on actual content
    local displayCount = index - 1
    UpdateFrameSize(frame, displayCount)
    frame:Show()

    -- Single deferred size update after all displays are rendered
    C_Timer.After(addon.POSITION_RECALC_TIME, function()
        if frame:GetParent() and frame:GetParent().updateFrameSize then
            frame:GetParent():updateFrameSize()
        end
    end)
end

-- Export the update function
addon.updateCrestCurrency = updateCrestCurrency

print("[FullyUpgraded] CrestCurrencyFrame.lua loaded (Midnight Edition)")
