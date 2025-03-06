local addonName, addon = ...

local currencyFrame = nil
local optionsFrame = nil
local CURRENCY = addon.CURRENCY       -- Reference to main addon's CURRENCY table
local CREST_ORDER = addon.CREST_ORDER -- Reference to crest order
local CRESTS_TO_UPGRADE = addon.CRESTS_TO_UPGRADE
local CRESTS_CONVERSION_UP = addon.CRESTS_CONVERSION_UP
local TEXT_POSITIONS = addon.TEXT_POSITIONS



-- Import helper functions
local IsCharacterTabSelected = function()
    return PaperDollFrame:IsVisible()
end

-- Create the base frame for currency display
local function CreateCurrencyFrame(parent)
    -- The parent frame is now just a container, no need for backdrop
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent) -- Fill the parent frame
    return frame
end

-- Create display elements for a single crest type
local function CreateCrestDisplay(parent, crestType, crestData)
    
    local display = {
        hoverFrame = CreateFrame("Frame", nil, parent),
        icon = parent:CreateTexture(nil, "ARTWORK"),
        text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal"),
        shortname = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    }

    -- Set up hover frame for tooltip
    display.hoverFrame:SetSize(80, 20)

    -- Set up icon
    display.icon:SetSize(20, 20)

    -- Set up text elements
    display.text:SetJustifyH("RIGHT")
    display.text:SetFont(display.text:GetFont(), 12, "OUTLINE")
    
    display.shortname:SetJustifyH("RIGHT")
    display.shortname:SetFont(display.shortname:GetFont(), 12, "OUTLINE")

    -- Color the shortname based on the crest's color from CREST_BASE
    local baseData = addon.CREST_BASE[crestType]
    if baseData and baseData.color then
        -- Convert hex color to RGB values
        local r = tonumber(baseData.color:sub(1,2), 16) / 255
        local g = tonumber(baseData.color:sub(3,4), 16) / 255
        local b = tonumber(baseData.color:sub(5,6), 16) / 255
        display.shortname:SetTextColor(r, g, b)
    end

    -- Set initial text
    display.shortname:SetText(crestData.reallyshortname or crestData.shortname)
    display.text:SetText(crestData.current or "0")

    -- Set initial positions (will be updated later)
    display.text:SetPoint("CENTER")
    display.icon:SetPoint("RIGHT", display.text, "LEFT", -2, 0)
    display.shortname:SetPoint("RIGHT", display.icon, "LEFT", -4, 0)
    display.hoverFrame:SetPoint("TOPLEFT", display.shortname, "TOPLEFT", -2, 2)
    display.hoverFrame:SetPoint("BOTTOMRIGHT", display.text, "BOTTOMRIGHT", 2, -2)

    -- Show all elements
    display.hoverFrame:Show()
    display.icon:Show()
    display.text:Show()
    display.shortname:Show()


    return display
end

-- Update the tooltip for a crest display
local function UpdateCrestTooltip(display, crestData)
    display.hoverFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        
        -- Get the crest type and base data
        local crestType = crestData.shortname:upper()
        local baseData = addon.CREST_BASE[crestType]
        
        -- Add name with color from CREST_BASE
        GameTooltip:AddLine(string.format("|cFF%s%s|r", baseData.color, baseData.baseName .. " Undermine Crest"))

        -- Show raid source information if available
        if baseData.source then
            GameTooltip:AddLine(baseData.source, 1, 0.5, 0) -- Orange color
        end

        -- Show mythic level requirement if applicable
        if baseData.mythicLevel > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(string.format("Requires Mythic %d+ dungeons", baseData.mythicLevel), 1, 1, 1)
        end

        -- Show rewards for each mythic level for this crest type
        if addon.CREST_REWARDS[crestType] then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Dungeon Rewards:", 1, 1, 0)

            -- Get all levels and sort them
            local levels = {}
            for level, _ in pairs(addon.CREST_REWARDS[crestType]) do
                table.insert(levels, level)
            end
            table.sort(levels)

            -- Display rewards in sorted order
            for _, level in ipairs(levels) do
                local rewards = addon.CREST_REWARDS[crestType][level]
                local baseReward = rewards.timed
                local expiredReward = math.max(0, baseReward - addon.EXPIRED_KEYSTONE_DEDUCTION)
                GameTooltip:AddLine(string.format("|cFF%sM%d:|r |cFF00FF00%d|r |cFFFFFFFF(Expired:|r |cFFFF0000%d|r|cFFFFFFFF)|r", 
                    baseData.color, level, baseReward, expiredReward), 1, 1, 1, true)
            end
        end

        -- Show upgrade conversion if available
        if baseData.upgradesTo then
            local upgradesTo = addon.CREST_BASE[baseData.upgradesTo]
            if upgradesTo then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(
                    string.format("Convert %d to %d |cFF%s%s|r", 
                        CRESTS_CONVERSION_UP, 
                        CRESTS_TO_UPGRADE, 
                        upgradesTo.color,
                        upgradesTo.baseName .. " Undermine Crest"
                    ), 1, 1, 0)
            end
        end

        GameTooltip:Show()
    end)
    display.hoverFrame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

-- Position a single crest display
local function PositionCrestDisplay(display, parent, xOffset)
    display.text:SetPoint("RIGHT", parent, "RIGHT", -xOffset, 0)
    display.icon:SetPoint("RIGHT", display.text, "LEFT", -2, 0)
    display.shortname:SetPoint("RIGHT", display.icon, "LEFT", -4, 0)
    display.hoverFrame:SetPoint("TOPLEFT", display.shortname, "TOPLEFT", -2, 2)
    display.hoverFrame:SetPoint("BOTTOMRIGHT", display.text, "BOTTOMRIGHT", 2, -2)
end

-- Update a single crest display
local function UpdateCrestDisplay(display, crestData)
    local info = C_CurrencyInfo.GetCurrencyInfo(crestData.currencyID)
    if info then
        display.icon:SetTexture(info.iconFileID)
        display.text:SetText(info.quantity)
        display.shortname:SetText(crestData.reallyshortname)

        -- Show all elements
        display.hoverFrame:Show()
        display.icon:Show()
        display.text:Show()
        display.shortname:Show()
    end
end

-- Sort crests by mythic level (highest to lowest)
local function GetSortedCrests()
    local sortedCrests = {}
    -- Use CREST_ORDER to maintain consistent order
    for _, crestType in ipairs(CREST_ORDER) do
        local crestData = CURRENCY.CRESTS[crestType]
        if crestData then
            table.insert(sortedCrests, { type = crestType, data = crestData })
        end
    end
    
    
    -- Reverse the order since we want highest to lowest
    for i = 1, math.floor(#sortedCrests / 2) do
        sortedCrests[i], sortedCrests[#sortedCrests - i + 1] = sortedCrests[#sortedCrests - i + 1], sortedCrests[i]
    end
    
    return sortedCrests
end

-- Main update function for the currency frame
local function UpdateCrestCurrency(parent)
    
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

    if not currencyFrame then
        currencyFrame = CreateFrame("Frame", "FullyUpgradedCurrencyFrame", parent, "BackdropTemplate")
        if currencyFrame then
            currencyFrame:SetSize(250, 30)
            currencyFrame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
            currencyFrame:Show()
            
            -- Add a background for debugging visibility using the modern Backdrop API
            currencyFrame:SetBackdrop({
                bgFile = "Interface/Buttons/WHITE8x8",
                edgeFile = "Interface/Buttons/WHITE8x8",
                tile = true,
                tileSize = 8,
                edgeSize = 1,
            })
            currencyFrame:SetBackdropColor(0, 0, 0, 0.5)
            currencyFrame:SetBackdropBorderColor(1, 1, 1, 0.5)
        else
            return
        end
    end

    -- Clear existing displays
    if currencyFrame.displays then
        for crestType, display in pairs(currencyFrame.displays) do
            if display.hoverFrame then display.hoverFrame:Hide() end
            if display.icon then display.icon:Hide() end
            if display.text then display.text:Hide() end
            if display.shortname then display.shortname:Hide() end
        end
    end

    currencyFrame.displays = currencyFrame.displays or {}

    local xOffset = 5
    local sortedCrests = GetSortedCrests()

    for _, crestInfo in ipairs(sortedCrests) do
        local crestType = crestInfo.type
        local crestData = crestInfo.data

        if crestData.currencyID then
            -- Create the display if it doesn't exist
            if not currencyFrame.displays[crestType] then
                currencyFrame.displays[crestType] = CreateCrestDisplay(currencyFrame, crestType, crestData)
            end

            local display = currencyFrame.displays[crestType]
            if display then  -- Add safety check
                -- Position and update the display
                PositionCrestDisplay(display, currencyFrame, xOffset)
                UpdateCrestDisplay(display, crestData)
                UpdateCrestTooltip(display, crestData)

                xOffset = xOffset + 60
            end
        end
    end

    -- Update frame visibility
    if IsCharacterTabSelected() then
        currencyFrame:Show()
    else
        currencyFrame:Hide()
    end
end

-- Export functions to addon namespace
addon.UpdateCrestCurrency = UpdateCrestCurrency

-- Add a hook to update the currency display when the character frame is shown
CharacterFrame:HookScript("OnShow", function()
    if IsCharacterTabSelected() and currencyFrame then
        UpdateCrestCurrency(currencyFrame:GetParent())
    end
end)

-- Add a hook to update the currency display when the currency changes
local currencyEventFrame = CreateFrame("Frame")
currencyEventFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
currencyEventFrame:SetScript("OnEvent", function(self, event)
    if IsCharacterTabSelected() and currencyFrame then
        UpdateCrestCurrency(currencyFrame:GetParent())
    end
end)

-- Update the position of a single currency display
local function UpdateDisplayPosition(display, parent, xOffset)
    if not display then return xOffset end  -- Guard against nil display
    
    display:ClearAllPoints()
    display:SetPoint("LEFT", parent, "LEFT", xOffset, 0)
    
    -- Update xOffset for next display
    return xOffset + display:GetWidth() + 5  -- 5 pixel spacing between displays
end

-- Update all currency display positions
local function UpdateCurrencyPositions(parent)
    if not parent or not parent.displays then return end  -- Guard against nil parent
    
    local xOffset = 5  -- Initial offset from left edge
    
    -- Update position for each display
    for _, display in pairs(parent.displays) do
        if display and display:IsShown() then
            xOffset = UpdateDisplayPosition(display, parent, xOffset)
        end
    end
    
    -- Update frame width to fit all displays
    if parent:GetWidth() ~= xOffset then
        parent:SetWidth(math.max(xOffset, 50))  -- Minimum width of 50
    end
end

-- Create or update a currency display
local function UpdateCrestDisplay(crestType, count, parent)
    if not parent or not parent.displays then 
        parent.displays = {}  -- Initialize displays table if it doesn't exist
    end
    
    -- Get or create display
    local display = parent.displays[crestType]
    if not display then
        display = CreateFrame("Frame", nil, parent)
        parent.displays[crestType] = display
        -- Initialize display frame here
        display:SetSize(32, 32)
        -- Add other necessary initialization
    end
    
    -- Update display
    if display then
        -- Update count and visibility
        display:Show()
        -- Update other display properties
    end
    
    return display
end
