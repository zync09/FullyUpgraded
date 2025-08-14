local addonName, addon = ...
addon.Currency = {}
local Currency = addon.Currency

-- M+ rewards per key level
local CREST_REWARDS = {
    [2] = { crest = "CARVED", count = 5 },
    [3] = { crest = "CARVED", count = 5 },
    [4] = { crest = "CARVED", count = 5 },
    [5] = { crest = "CARVED", count = 5 },
    [6] = { crest = "CARVED", count = 5 },
    [7] = { crest = "RUNED", count = 10 },
    [8] = { crest = "RUNED", count = 10 },
    [9] = { crest = "RUNED", count = 10 },
    [10] = { crest = "GILDED", count = 10 },
    [11] = { crest = "GILDED", count = 15 },
    [12] = { crest = "GILDED", count = 15 }
}

-- Crest conversion rates
local CREST_CONVERSION_RATE = 45 -- Lower tier crests to upgrade

-- Currency data
local currencyData = {}
local crestNeeds = {}
local lastUpdateTime = 0
local UPDATE_THROTTLE = 1 -- Minimum seconds between currency updates

-- Font strings for display
local displayStrings = {}

-- Initialize currency module
function Currency:Initialize()
    -- Get initial currency values
    self:UpdateCurrencyValues()
end

-- Update currency values from game
function Currency:UpdateCurrencyValues()
    local currentTime = GetTime()
    if currentTime - lastUpdateTime < UPDATE_THROTTLE then
        return false -- Too soon
    end
    
    lastUpdateTime = currentTime
    local hasChanges = false
    
    for crestType, crestInfo in pairs(addon.CREST_TYPES) do
        local info = C_CurrencyInfo.GetCurrencyInfo(crestInfo.currencyID)
        if info then
            local oldValue = currencyData[crestType] and currencyData[crestType].quantity or 0
            
            currencyData[crestType] = {
                name = info.name,
                quantity = info.quantity,
                iconFileID = info.iconFileID
            }
            
            if oldValue ~= info.quantity then
                hasChanges = true
            end
        end
    end
    
    return hasChanges
end

-- Set crest needs from Data module
function Currency:SetCrestNeeds(needs)
    crestNeeds = needs or {}
    self:UpdateDisplay()
end

-- Calculate M+ runs needed
local function CalculateMythicPlusRuns()
    local runsNeeded = {}
    
    -- Calculate net needs after conversions
    local netNeeds = {}
    local excessLower = {}
    
    -- Start from lowest tier
    for crestType, crestInfo in pairs(addon.CREST_TYPES) do
        local current = currencyData[crestType] and currencyData[crestType].quantity or 0
        local needed = crestNeeds[crestType] or 0
        netNeeds[crestType] = math.max(0, needed - current)
        excessLower[crestType] = math.max(0, current - needed)
    end
    
    -- Apply conversions (lower to higher)
    local orderedCrests = {"WEATHERED", "CARVED", "RUNED", "GILDED"}
    for i = 1, #orderedCrests - 1 do
        local lowerType = orderedCrests[i]
        local higherType = orderedCrests[i + 1]
        
        if excessLower[lowerType] > 0 and netNeeds[higherType] > 0 then
            local convertible = math.floor(excessLower[lowerType] / CREST_CONVERSION_RATE)
            local actualConvert = math.min(convertible, netNeeds[higherType])
            
            if actualConvert > 0 then
                netNeeds[higherType] = netNeeds[higherType] - actualConvert
                excessLower[lowerType] = excessLower[lowerType] - (actualConvert * CREST_CONVERSION_RATE)
            end
        end
    end
    
    -- Calculate runs needed for each crest type
    for keyLevel, reward in pairs(CREST_REWARDS) do
        local crestType = reward.crest
        local needed = netNeeds[crestType]
        
        if needed > 0 then
            local runs = math.ceil(needed / reward.count)
            if not runsNeeded[keyLevel] then
                runsNeeded[keyLevel] = 0
            end
            runsNeeded[keyLevel] = runsNeeded[keyLevel] + runs
        end
    end
    
    return runsNeeded, netNeeds
end

-- Update currency display
function Currency:UpdateDisplay()
    local frame = addon.UI and addon.UI:GetCurrencyFrame()
    if not frame or not frame:IsVisible() then return end
    
    -- Clear existing strings
    for _, str in pairs(displayStrings) do
        str:SetText("")
        str:Hide()
    end
    
    local yOffset = -5
    local index = 0
    
    -- Display current currencies
    for _, crestType in ipairs({"WEATHERED", "CARVED", "RUNED", "GILDED"}) do
        local data = currencyData[crestType]
        local needed = crestNeeds[crestType] or 0
        
        if data and (data.quantity > 0 or needed > 0) then
            index = index + 1
            
            -- Get or create font string
            if not displayStrings[index] then
                displayStrings[index] = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            end
            
            local str = displayStrings[index]
            str:ClearAllPoints()
            str:SetPoint("TOP", frame, "TOP", 0, yOffset)
            
            -- Create icon texture
            local iconText = ""
            if data.iconFileID then
                iconText = CreateTextureMarkup(data.iconFileID, 64, 64, 14, 14, 0, 1, 0, 1) .. " "
            end
            
            -- Format text with color
            local color = data.quantity >= needed and "|cFF00FF00" or "|cFFFF0000"
            str:SetText(string.format("%s%s%d/%d|r %s", iconText, color, data.quantity, needed, data.name or crestType))
            str:Show()
            
            yOffset = yOffset - 15
        end
    end
    
    -- Calculate and display M+ runs needed
    local runsNeeded, netNeeds = CalculateMythicPlusRuns()
    local hasRuns = false
    
    for level, runs in pairs(runsNeeded) do
        if runs > 0 then
            hasRuns = true
            index = index + 1
            
            if not displayStrings[index] then
                displayStrings[index] = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            end
            
            local str = displayStrings[index]
            str:ClearAllPoints()
            str:SetPoint("TOP", frame, "TOP", 0, yOffset)
            str:SetText(string.format("|cFFFFFF00M+%d: %d runs|r", level, runs))
            str:Show()
            
            yOffset = yOffset - 15
        end
    end
    
    -- Update frame size
    local height = math.abs(yOffset) + 10
    frame:SetHeight(height)
    
    -- Update master frame size
    local masterFrame = addon.UI:GetMasterFrame()
    if masterFrame then
        masterFrame:SetHeight(height + 30) -- Account for title
    end
end

-- Handle currency update event
function Currency:OnCurrencyUpdate()
    if self:UpdateCurrencyValues() then
        self:UpdateDisplay()
    end
end

-- Full update
function Currency:Update()
    self:UpdateCurrencyValues()
    self:UpdateDisplay()
end