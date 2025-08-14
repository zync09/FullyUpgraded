local addonName, addon = ...
addon.UI = {}
local UI = addon.UI

-- Text positions
local TEXT_POSITIONS = {
    TR = { point = "TOPRIGHT", x = 0, y = 0 },
    TL = { point = "TOPLEFT", x = 0, y = 0 },
    BR = { point = "BOTTOMRIGHT", x = 0, y = 0 },
    BL = { point = "BOTTOMLEFT", x = 0, y = 0 },
    C = { point = "CENTER", x = 0, y = 0 }
}

-- Frame pools for efficiency
local textPool = {}
local activeTexts = {}

-- Master frame for currency display
local masterFrame = nil
local currencyFrame = nil

-- Create or get text overlay for a slot
local function GetOrCreateText(slot)
    if activeTexts[slot] then
        return activeTexts[slot]
    end
    
    -- Try to get from pool
    local text = table.remove(textPool)
    
    if not text then
        -- Create new text frame
        local slotFrame = _G["Character" .. slot]
        if not slotFrame then 
            return nil 
        end
        
        text = CreateFrame("Frame", nil, slotFrame)
        text:SetSize(25, 15)
        
        local fontString = text:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fontString:SetFont(GameFontNormal:GetFont(), 11, "OUTLINE")
        fontString:SetPoint("CENTER", text, "CENTER", 0, 0)
        
        text.fontString = fontString
        text.slot = slot
        
        -- Tooltip handling
        text:EnableMouse(true)
        text:SetScript("OnEnter", function(self)
            UI:ShowTooltip(self)
        end)
        text:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end
    
    -- Position the text
    local pos = TEXT_POSITIONS[FullyUpgradedDB.textPosition or "TR"]
    text:ClearAllPoints()
    text:SetPoint(pos.point, _G["Character" .. slot], pos.point, pos.x, pos.y)
    
    activeTexts[slot] = text
    return text
end

-- Return text to pool
local function ReleaseText(slot)
    local text = activeTexts[slot]
    if not text then return end
    
    text:Hide()
    text.fontString:SetText("")
    text.upgradeInfo = nil
    activeTexts[slot] = nil
    table.insert(textPool, text)
end

-- Initialize UI
function UI:Initialize()
    
    -- Create master frame for currency display
    masterFrame = CreateFrame("Frame", "FullyUpgradedMasterFrame", CharacterFrame, "BackdropTemplate")
    masterFrame:SetPoint("TOPRIGHT", CharacterFrame, "BOTTOMRIGHT", 0, 0)
    masterFrame:SetSize(230, 80)
    masterFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = true,
        tileSize = 8,
        edgeSize = 2,
    })
    masterFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    masterFrame:SetBackdropBorderColor(0, 0, 0, 1)
    
    -- Title
    local title = masterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", masterFrame, "TOP", 0, -5)
    title:SetText("Fully Upgraded")
    title:SetTextColor(1, 1, 0)
    
    -- Currency frame
    currencyFrame = CreateFrame("Frame", nil, masterFrame)
    currencyFrame:SetPoint("TOP", title, "BOTTOM", 0, -5)
    currencyFrame:SetSize(200, 60)
    
    masterFrame:Hide()
end

-- Update display
function UI:UpdateDisplay()
    
    if not addon:ShouldProcess() then 
        return 
    end
    
    local data = addon.Data
    if not data or not data.equipmentData then 
        return 
    end
    
    
    -- Update each slot
    for _, slot in ipairs(addon.EQUIPMENT_SLOTS) do
        local slotInfo = data:GetSlotInfo(slot)
        
        if slotInfo and slotInfo.upgradeInfo and slotInfo.upgradeInfo.remainingUpgrades > 0 then
            
            local text = GetOrCreateText(slot)
            if text then
                -- Format: current/max with track letter
                local upgradeInfo = slotInfo.upgradeInfo
                local trackLetter = upgradeInfo.track:sub(1, 1) -- First letter of track name
                local upgradesToFinish = upgradeInfo.maxLevel - upgradeInfo.currentLevel
                text.fontString:SetText(string.format("%s%d+", trackLetter, upgradesToFinish))
                
                -- Always white color
                text.fontString:SetTextColor(1, 1, 1)
                
                text.upgradeInfo = slotInfo
                
                if FullyUpgradedDB.textVisible then
                    text:Show()
                else
                end
            else
            end
        else
            -- No upgrades needed, release the text
            ReleaseText(slot)
        end
    end
    
    -- Show master frame
    masterFrame:Show()
end

-- Show tooltip
function UI:ShowTooltip(textFrame)
    if not textFrame.upgradeInfo then return end
    
    GameTooltip:SetOwner(textFrame, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    
    local info = textFrame.upgradeInfo.upgradeInfo
    local crestReqs = textFrame.upgradeInfo.crestRequirements
    
    GameTooltip:AddLine("Upgrade Information", 1, 1, 1)
    GameTooltip:AddLine(string.format("%s Track %d/%d", info.track, info.currentLevel, info.maxLevel), 1, 1, 1)
    
    if crestReqs then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Crests Needed:", 1, 0.8, 0)
        
        for crestType, amount in pairs(crestReqs) do
            local crestData = addon.CREST_TYPES[crestType]
            if crestData then
                -- Get crest icon
                local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(crestData.currencyID)
                if currencyInfo and currencyInfo.iconFileID then
                    local iconText = CreateTextureMarkup(currencyInfo.iconFileID, 64, 64, 16, 16, 0, 1, 0, 1)
                    GameTooltip:AddDoubleLine(iconText .. " " .. crestData.name .. " Crests:", amount, 1, 1, 1, 1, 1, 1)
                else
                    GameTooltip:AddDoubleLine(crestData.name .. " Crests:", amount, 1, 1, 1, 1, 1, 1)
                end
            end
        end
    end
    
    GameTooltip:Show()
end

-- Hide all UI elements
function UI:HideAll()
    -- Hide all active texts
    for slot in pairs(activeTexts) do
        ReleaseText(slot)
    end
    
    -- Hide master frame
    if masterFrame then
        masterFrame:Hide()
    end
end

-- Update visibility based on settings
function UI:UpdateVisibility()
    local visible = FullyUpgradedDB.textVisible
    
    for _, text in pairs(activeTexts) do
        if visible then
            text:Show()
        else
            text:Hide()
        end
    end
end

-- Set text position
function UI:SetTextPosition(position)
    if not TEXT_POSITIONS[position] then
        return false
    end
    
    FullyUpgradedDB.textPosition = position
    
    -- Update all active texts
    local pos = TEXT_POSITIONS[position]
    for slot, text in pairs(activeTexts) do
        text:ClearAllPoints()
        text:SetPoint(pos.point, _G["Character" .. slot], pos.point, pos.x, pos.y)
    end
    
    return true
end

-- Get currency frame for Currency module
function UI:GetCurrencyFrame()
    return currencyFrame
end

-- Get master frame
function UI:GetMasterFrame()
    return masterFrame
end