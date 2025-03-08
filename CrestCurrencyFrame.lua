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
        shortName = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal"),
        icon = parent:CreateTexture(nil, "ARTWORK"),
        count = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal"),
        separator = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    }

    -- Set up frame for tooltip and layout
    display.frame:SetSize(60, 20)
    display.frame:EnableMouse(true)

    -- Set up shortName
    display.shortName:SetFont(display.shortName:GetFont(), 12, "OUTLINE")
    display.shortName:SetPoint("LEFT", display.frame, "LEFT", 0, 0)
    display.shortName:SetJustifyH("LEFT")

    -- Set up icon
    display.icon:SetSize(16, 16)
    display.icon:SetPoint("LEFT", display.shortName, "RIGHT", 2, 0)

    -- Set up count text
    display.count:SetFont(display.count:GetFont(), 12, "OUTLINE")
    display.count:SetPoint("LEFT", display.icon, "RIGHT", 2, 0)
    display.count:SetJustifyH("LEFT")
    display.count:SetTextColor(1, 1, 1) -- White color

    -- Set up separator
    display.separator:SetFont(display.separator:GetFont(), 12, "OUTLINE")
    display.separator:SetText("|")
    display.separator:SetTextColor(0.5, 0.5, 0.5) -- Gray color
    display.separator:SetPoint("RIGHT", display.frame, "RIGHT", 0, 0)

    return display
end

-- Position a single crest display
local function PositionCrestDisplay(display, parent, index, totalDisplays)
    if not display then return end

    local parentWidth = parent:GetWidth()
    local displayWidth = parentWidth / totalDisplays
    local xOffset = (index - 1) * displayWidth

    -- Position the frame
    display.frame:ClearAllPoints()
    display.frame:SetPoint("LEFT", parent, "LEFT", xOffset, 0)
    display.frame:SetWidth(displayWidth)

    -- Show all elements
    display.frame:Show()
    display.shortName:Show()
    display.icon:Show()
    display.count:Show()

    -- Show separator unless it's the last item
    if index < totalDisplays then
        display.separator:Show()
    else
        display.separator:Hide()
    end
end

-- Update a single crest display
local function UpdateCrestDisplay(display, info, crestData)
    if not display or not info then return end

    -- Update shortName (first letter of crest type)
    local shortName = crestData.reallyshortname or ""
    display.shortName:SetText(shortName)

    -- Set color from CREST_BASE using the exact crest type (WEATHERED, CARVED, etc)
    for crestType, baseData in pairs(addon.CREST_BASE) do
        if baseData.shortCode == crestData.reallyshortname then
            local r = tonumber(baseData.color:sub(1, 2), 16) / 255
            local g = tonumber(baseData.color:sub(3, 4), 16) / 255
            local b = tonumber(baseData.color:sub(5, 6), 16) / 255
            -- Apply color to both shortName and count
            display.shortName:SetTextColor(r, g, b)
            display.count:SetTextColor(r, g, b)
            break
        end
    end

    -- Update icon
    display.icon:SetTexture(info.iconFileID)

    -- Update count text
    display.count:SetText(info.quantity)

    -- Set up tooltip
    display.frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(info.name)
        GameTooltip:AddLine("Current: " .. info.quantity, 1, 1, 1)
        if crestData.needed and crestData.needed > 0 then
            GameTooltip:AddLine("Needed: " .. crestData.needed, 1, 0.82, 0)
        end
        if crestData.upgraded and crestData.upgraded > 0 then
            GameTooltip:AddLine("From upgrades: " .. crestData.upgraded, 0, 1, 0)
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
            if display.separator then display.separator:Hide() end
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
