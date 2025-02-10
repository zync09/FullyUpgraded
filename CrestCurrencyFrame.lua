local addonName, addon = ...

local currencyFrame = nil
local CURRENCY = addon.CURRENCY -- Reference to main addon's CURRENCY table
local CREST_ORDER = addon.CREST_ORDER -- Reference to crest order
local CRESTS_TO_UPGRADE = addon.CRESTS_TO_UPGRADE
local CRESTS_CONVERSION_UP = addon.CRESTS_CONVERSION_UP

-- Import helper functions
local IsCharacterTabSelected = function()
    return PaperDollFrame:IsVisible()
end

-- Create the base frame for currency display
local function CreateCurrencyFrame(parent)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetPoint("TOPRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    frame:SetSize(250, 20)
    frame:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8x8",
        edgeFile = "Interface/Buttons/WHITE8x8",
        tile = true,
        tileSize = 8,
        edgeSize = 2,
    })
    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    frame:SetBackdropBorderColor(0, 0, 0, 1)
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
    
    -- Set up icon and text
    display.icon:SetSize(20, 20)
    display.text:SetJustifyH("RIGHT")
    display.shortname:SetJustifyH("RIGHT")
    
    -- Color the shortname based on mythic level
    if crestData.mythicLevel >= 8 then
        display.shortname:SetTextColor(1, 0.5, 0) -- Orange for M8+
    elseif crestData.mythicLevel >= 4 then
        display.shortname:SetTextColor(0.64, 0.21, 0.93) -- Purple for M4+
    elseif crestData.mythicLevel >= 2 then
        display.shortname:SetTextColor(0, 0.44, 0.87) -- Blue for M2+
    else
        display.shortname:SetTextColor(0.12, 1, 0) -- Green for M0
    end
    
    return display
end

-- Update the tooltip for a crest display
local function UpdateCrestTooltip(display, crestData)
    display.hoverFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(crestData.name)
        
        -- Show mythic level requirement
        if crestData.mythicLevel > 0 then
            GameTooltip:AddLine(string.format("Requires Mythic %d+ dungeons", crestData.mythicLevel), 1, 1, 1)
            GameTooltip:AddLine(" ")
            
            -- Get the crest type from the name
            local crestType = crestData.shortname:upper()
            
            -- Show rewards for each mythic level for this crest type
            if addon.CREST_REWARDS[crestType] then
                GameTooltip:AddLine("Dungeon Rewards:", 1, 0.82, 0)
                
                -- Get all levels and sort them
                local levels = {}
                for level, _ in pairs(addon.CREST_REWARDS[crestType]) do
                    table.insert(levels, level)
                end
                table.sort(levels)
                
                -- Display rewards in sorted order
                for _, level in ipairs(levels) do
                    local rewards = addon.CREST_REWARDS[crestType][level]
                    GameTooltip:AddLine(string.format("M%d:  |cFF00FF00%d|r (Timed)  |cFFFFFF00%d|r (Untimed)", 
                        level, rewards.timed, rewards.untimed))
                end
            end
        end
        
        -- Show upgrade conversion if available
        if crestData.upgradesTo then
            local upgradesTo = CURRENCY.CRESTS[crestData.upgradesTo]
            if upgradesTo then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(string.format("Convert %d to %d %s", CRESTS_CONVERSION_UP, CRESTS_TO_UPGRADE, upgradesTo.name), 1, 0.82, 0)
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
            table.insert(sortedCrests, {type = crestType, data = crestData})
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
    if not currencyFrame then
        currencyFrame = CreateCurrencyFrame(parent)
    end

    -- Clear existing displays
    if currencyFrame.displays then
        for _, display in pairs(currencyFrame.displays) do
            if display.hoverFrame then
                display.hoverFrame:Hide()
            end
            if display.icon then
                display.icon:Hide()
            end
            if display.text then
                display.text:Hide()
            end
            if display.shortname then
                display.shortname:Hide()
            end
        end
    end

    currencyFrame.displays = currencyFrame.displays or {}
    
    local xOffset = 5
    local sortedCrests = GetSortedCrests()

    for _, crestInfo in ipairs(sortedCrests) do
        local crestType = crestInfo.type
        local crestData = crestInfo.data
        
        if crestData.currencyID then -- Only create display if we have a valid currencyID
            -- Create or get existing display
            if not currencyFrame.displays[crestType] then
                currencyFrame.displays[crestType] = CreateCrestDisplay(currencyFrame, crestType, crestData)
            end
            
            local display = currencyFrame.displays[crestType]
            
            -- Position and update the display
            PositionCrestDisplay(display, currencyFrame, xOffset)
            UpdateCrestDisplay(display, crestData)
            UpdateCrestTooltip(display, crestData)
            
            xOffset = xOffset + 60
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