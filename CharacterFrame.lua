local addonName, addon = ...

-- Import constants from addon namespace
local EQUIPMENT_SLOTS = addon.EQUIPMENT_SLOTS
local TEXT_POSITIONS = addon.TEXT_POSITIONS
local UPGRADE_TRACKS = addon.UPGRADE_TRACKS

-- Local references to shared functions and data
addon.upgradeTextPool = {} -- Make upgradeTextPool accessible to the main file
local upgradeTextPool = addon.upgradeTextPool
local currentTextPos = "TR" -- Default position

-- Font settings
local fontFile = GameFontNormal:GetFont()
local fontSize = 12
local fontFlags = "OUTLINE, THICKOUTLINE"

-- Forward declarations
local ProcessEquipmentSlot
local CreateUpgradeText
local InitializeUpgradeTexts
local UpdateAllUpgradeTexts

-- Debug function (reference to the main addon's debug function)
local Debug = function(...) 
    if addon.Debug then
        addon.Debug(...)
    end
end

-- Function to check if character tab is selected
local function IsCharacterTabSelected()
    return PaperDollFrame:IsVisible()
end

-- **Creates Upgrade Text for a Slot**
local function CreateUpgradeText(slot)
    Debug("Creating upgrade text for slot:", slot)
    local slotFrame = _G["Character" .. slot]
    if not slotFrame then 
        Debug("ERROR: Slot frame not found for:", slot)
        return 
    end

    -- Create the text element with proper settings
    local text = slotFrame:CreateFontString(nil, "OVERLAY")
    text:SetFontObject("GameFontNormalLarge")
    text:SetFont(fontFile, fontSize, fontFlags)
    
    -- Set text position relative to the slot frame
    local posData = TEXT_POSITIONS[currentTextPos]
    text:ClearAllPoints()
    text:SetPoint(posData.point, slotFrame, posData.point, posData.x, posData.y)
    text:SetJustifyH("RIGHT")
    text:SetDrawLayer("OVERLAY", 7)
    
    -- Create fully upgraded icon for this slot
    local fullyUpgradedIcon = slotFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    fullyUpgradedIcon:SetSize(16, 16)
    fullyUpgradedIcon:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-Ready")
    fullyUpgradedIcon:ClearAllPoints()
    fullyUpgradedIcon:SetPoint("CENTER", text, "CENTER", 0, 0)
    fullyUpgradedIcon:Hide()
    
    -- Create button for tooltip interaction
    local fullyUpgradedButton = CreateFrame("Button", nil, slotFrame)
    fullyUpgradedButton:SetSize(20, 20)
    fullyUpgradedButton:ClearAllPoints()
    fullyUpgradedButton:SetPoint("CENTER", text, "CENTER", 0, 0)
    fullyUpgradedButton:EnableMouse(true)
    fullyUpgradedButton:Hide()
    
    -- Store references
    text.fullyUpgradedIcon = fullyUpgradedIcon
    text.fullyUpgradedButton = fullyUpgradedButton
    text.slot = slot -- Store the slot reference
    text.slotFrame = slotFrame -- Store the slot frame reference
    
    Debug("Text position:", posData.point, posData.x, posData.y)
    
    return text
end

-- **Initialize All Equipment Slot Overlays**
local function InitializeUpgradeTexts()
    Debug("Initializing upgrade texts for all slots")
    -- Clear existing text pool
    for slot, text in pairs(upgradeTextPool) do
        if text then
            Debug("Clearing existing text for slot:", slot)
            text:Hide()
            if text.fullyUpgradedIcon then text.fullyUpgradedIcon:Hide() end
            if text.fullyUpgradedButton then text.fullyUpgradedButton:Hide() end
        end
    end
    wipe(upgradeTextPool)
    
    -- Create new text elements
    local failedSlots = {}
    for _, slot in ipairs(EQUIPMENT_SLOTS) do
        Debug("Creating text for slot:", slot)
        local text = CreateUpgradeText(slot)
        
        if text then
            upgradeTextPool[slot] = text
            Debug("Successfully created upgrade text for slot:", slot)
            -- Verify text creation
            if not text:GetFont() then
                Debug("WARNING: Font not set for slot:", slot)
                text:SetFont(fontFile, fontSize, fontFlags)
            end
            -- Force initial position
            local posData = TEXT_POSITIONS[currentTextPos]
            text:ClearAllPoints()
            text:SetPoint(posData.point, text.slotFrame, posData.point, posData.x, posData.y)
        else
            table.insert(failedSlots, slot)
            Debug("Failed to create upgrade text for slot:", slot)
        end
    end
    
    if #failedSlots > 0 then
        Debug("Failed to initialize texts for the following slots:", table.concat(failedSlots, ", "))
    end
    
    Debug("Finished initializing all upgrade texts. Total texts created:", #EQUIPMENT_SLOTS - #failedSlots)
end

-- Process a Season 1 item
local function ProcessSeason1Item(text, fontFile, fontSize, fontFlags)
    text:SetFont(fontFile, fontSize, fontFlags)
    text:SetText(string.format("|cFF%02x%02x%02xS1|r", 240, 100, 50)) 
    text:Show()
    
    -- Make the text itself interactive
    text:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Season 1 Item")
        GameTooltip:AddLine("This item can no longer be upgraded", 1, 0.2, 0.2)
        GameTooltip:Show()
    end)
    text:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    -- Also make the button interactive with the same tooltip
    text.fullyUpgradedButton:Show()
    text.fullyUpgradedButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Season 1 Item")
        GameTooltip:AddLine("This item can no longer be upgraded", 1, 0.2, 0.2)
        GameTooltip:Show()
    end)
    text.fullyUpgradedButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Process an upgradeable item
local function ProcessUpgradeableItem(text, track, trackName, currentNum, maxNum, levelsToUpgrade)
    local trackUpper = trackName:upper()
    local trackLetter = trackUpper:sub(1, 1)
    
    -- Show remaining upgrades
    text:SetText("|cFFffffff+" .. levelsToUpgrade .. trackLetter .. "|r")
    text:Show()
    
    -- Make the button visible and interactive
    text.fullyUpgradedButton:Show()

    -- Set up tooltip for both text and button
    local function setupTooltip(self)
        addon.SetUpgradeTooltip(self, track, levelsToUpgrade, currentNum)
    end
    
    text:SetScript("OnEnter", setupTooltip)
    text:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    text.fullyUpgradedButton:SetScript("OnEnter", setupTooltip)
    text.fullyUpgradedButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    addon.ProcessUpgradeTrack(track, levelsToUpgrade, currentNum)
end

-- Modified ProcessEquipmentSlot function with additional debugging
local function ProcessEquipmentSlot(slot, text)
    if not text then
        Debug("ERROR: No text element provided for slot:", slot)
        return
    end
    Debug("Processing slot:", slot)
    
    -- Always reset the text first
    text:ClearAllPoints()
    local posData = TEXT_POSITIONS[currentTextPos]
    text:SetPoint(posData.point, text.slotFrame, posData.point, posData.x, posData.y)
    text:SetText("")
    text:Hide()
    text:SetScript("OnEnter", nil)
    text:SetScript("OnLeave", nil)
    text:SetFont(fontFile, fontSize, fontFlags)
    
    -- Reset icon and button
    if text.fullyUpgradedIcon then
        text.fullyUpgradedIcon:ClearAllPoints()
        text.fullyUpgradedIcon:SetPoint("CENTER", text, "CENTER", 0, 0)
        text.fullyUpgradedIcon:Hide()
    end
    
    if text.fullyUpgradedButton then
        text.fullyUpgradedButton:ClearAllPoints()
        text.fullyUpgradedButton:SetPoint("CENTER", text, "CENTER", 0, 0)
        text.fullyUpgradedButton:Hide()
        text.fullyUpgradedButton:SetScript("OnEnter", nil)
        text.fullyUpgradedButton:SetScript("OnLeave", nil)
    end

    local slotID = GetInventorySlotInfo(slot)
    if not slotID then
        Debug("ERROR: Invalid slot ID for slot:", slot)
        return
    end
    
    local itemLink = GetInventoryItemLink("player", slotID)
    if not itemLink then 
        Debug("No item in slot:", slot)
        return 
    end

    -- Get cached item info
    local _, _, _, effectiveILvl = addon.GetCachedItemInfo(itemLink)
    Debug("Item level for slot", slot .. ":", effectiveILvl)
    
    -- Get cached tooltip data
    local tooltipData = addon.GetCachedTooltipData(slotID, itemLink)
    if not tooltipData then
        Debug("ERROR: No tooltip data for slot:", slot)
        return
    end

    -- Only process items within the season's item level range
    if effectiveILvl and tooltipData then
        local minIlvl, maxIlvl = addon.GetCurrentSeasonItemLevelRange()
        Debug("Season item level range for slot", slot .. ":", minIlvl, "-", maxIlvl)
        
        if effectiveILvl >= minIlvl and effectiveILvl <= maxIlvl then
            -- Check if this is a Season 1 item
            local isSeason1 = false
            for _, line in ipairs(tooltipData.lines) do
                if line.leftText and line.leftText:find("The War Within Season 1") then
                    isSeason1 = true
                    Debug("Season 1 item found in slot:", slot)
                    ProcessSeason1Item(text, fontFile, fontSize, fontFlags)
                    Debug("Text visibility after ProcessSeason1Item:", text:IsShown())
                    return
                end
            end

            -- Only process upgrade levels for non-Season 1 items
            if not isSeason1 then
                for _, line in ipairs(tooltipData.lines) do
                    local trackName, current, max = line.leftText:match("Upgrade Level: (%w+) (%d+)/(%d+)")
                    if trackName then
                        Debug("Found upgrade track:", trackName, current, "/", max)
                        local trackUpper = trackName:upper()
                        local currentNum = tonumber(current)
                        local maxNum = tonumber(max)
                        local levelsToUpgrade = maxNum - currentNum
                        local track = UPGRADE_TRACKS[trackUpper]

                        if track then
                            Debug("Track found:", trackUpper, "Levels to upgrade:", levelsToUpgrade)
                            if levelsToUpgrade > 0 then
                                Debug("Processing upgradeable item")
                                ProcessUpgradeableItem(text, track, trackName, currentNum, maxNum, levelsToUpgrade)
                                Debug("Text visibility after ProcessUpgradeableItem:", text:IsShown())
                            elseif currentNum == maxNum then
                                Debug("Processing fully upgraded item")
                                -- Show fully upgraded icon with track letter
                                local trackLetter = trackUpper:sub(1, 1)
                                text.fullyUpgradedIcon:Show()
                                text.fullyUpgradedButton:Show()
                                text:SetText("|cFFffffff" .. '*' .. trackLetter .. "|r")
                                text:Show()
                                Debug("Text visibility after fully upgraded:", text:IsShown())
                                
                                -- Set up tooltip for both the button and text
                                local function setupFullyUpgradedTooltip(self)
                                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                                    GameTooltip:AddLine("Fully Upgraded")
                                    GameTooltip:AddLine(string.format("%s Track %d/%d", trackName, currentNum, maxNum), 1, 1, 1)
                                    GameTooltip:Show()
                                end
                                
                                text.fullyUpgradedButton:SetScript("OnEnter", setupFullyUpgradedTooltip)
                                text.fullyUpgradedButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
                                text:SetScript("OnEnter", setupFullyUpgradedTooltip)
                                text:SetScript("OnLeave", function() GameTooltip:Hide() end)
                            end
                        else
                            Debug("Track not found in UPGRADE_TRACKS:", trackUpper)
                        end
                        break
                    end
                end
            end
        else
            Debug("Item level outside of season range for slot", slot .. ":", effectiveILvl)
        end
    else
        Debug("Missing item level or tooltip data for slot:", slot)
    end
end

-- Main update function
local function UpdateAllUpgradeTexts()
    Debug("Starting UpdateAllUpgradeTexts")
    Debug("Current equipment slots:", table.concat(EQUIPMENT_SLOTS, ", "))
    
    -- Make sure currency is up to date before processing equipment slots
    Debug("Updating currency information")
    addon.CalculateUpgradedCrests()
    addon.CheckCurrencyForAllCrests()
    addon.ShowCrestCurrency()

    -- Reset needed counts
    for crestType, _ in pairs(addon.CURRENCY.CRESTS) do
        addon.CURRENCY.CRESTS[crestType].needed = 0
    end

    -- Process each equipment slot
    Debug("Processing equipment slots")
    local processedCount = 0
    local skippedCount = 0
    
    for _, slot in ipairs(EQUIPMENT_SLOTS) do
        local text = upgradeTextPool[slot]
        if text then 
            Debug("Found text element for slot:", slot)
            processedCount = processedCount + 1
            ProcessEquipmentSlot(slot, text)
        else
            Debug("ERROR: No text element found for slot:", slot)
            skippedCount = skippedCount + 1
            -- Try to reinitialize the missing text element
            local newText = CreateUpgradeText(slot)
            if newText then
                Debug("Successfully created missing text element for slot:", slot)
                upgradeTextPool[slot] = newText
                ProcessEquipmentSlot(slot, newText)
                processedCount = processedCount + 1
                skippedCount = skippedCount - 1
            end
        end
    end

    Debug("Slots processed:", processedCount, "Slots skipped:", skippedCount)

    -- Update total text display
    Debug("Updating total text display")
    local sortedCrests = addon.GetSortedCrests()
    local totalText = addon.FormatTotalCrestText(sortedCrests)

    if totalText ~= "" then
        addon.totalCrestText:SetText("Fully Upgraded:" .. totalText)
        addon.totalCrestText:Show()
    else
        addon.totalCrestText:SetText("")
        addon.totalCrestText:Hide()
    end

    addon.UpdateFrameSizeToText()
    Debug("Finished UpdateAllUpgradeTexts")
end

-- Function to update text position for all slots
local function UpdateTextPositions(position)
    if not TEXT_POSITIONS[position] then return end

    currentTextPos = position
    local posData = TEXT_POSITIONS[position]

    for slot, text in pairs(upgradeTextPool) do
        if text and text.slotFrame then
            -- Reset all points first
            text:ClearAllPoints()
            
            -- Set the text position relative to its slot frame
            if posData.point == "TOPRIGHT" then
                text:SetPoint("BOTTOMRIGHT", text.slotFrame, "TOPRIGHT", -2, 2)
            elseif posData.point == "TOPLEFT" then
                text:SetPoint("BOTTOMLEFT", text.slotFrame, "TOPLEFT", 2, 2)
            elseif posData.point == "BOTTOMRIGHT" then
                text:SetPoint("TOPRIGHT", text.slotFrame, "BOTTOMRIGHT", -2, -2)
            elseif posData.point == "BOTTOMLEFT" then
                text:SetPoint("TOPLEFT", text.slotFrame, "BOTTOMLEFT", 2, -2)
            elseif posData.point == "CENTER" then
                text:SetPoint("CENTER", text.slotFrame, "CENTER", 0, 0)
            end
            
            -- Position the icon and button relative to the text
            if text.fullyUpgradedIcon then
                text.fullyUpgradedIcon:ClearAllPoints()
                text.fullyUpgradedIcon:SetPoint("CENTER", text, "CENTER", 0, 0)
            end
            
            if text.fullyUpgradedButton then
                text.fullyUpgradedButton:ClearAllPoints()
                text.fullyUpgradedButton:SetPoint("CENTER", text, "CENTER", 0, 0)
            end
            
            -- Force a refresh of the slot
            ProcessEquipmentSlot(slot, text)
        end
    end
end

-- Function to set text visibility
local function SetTextVisibility(show)
    for slot, text in pairs(upgradeTextPool) do
        if text then
            if show then
                -- Re-process the slot to properly show either upgrade text or fully upgraded icon
                ProcessEquipmentSlot(slot, text)
            else
                text:Hide()
                text:SetText("")
                -- Also hide the icon and button
                if text.fullyUpgradedIcon then
                    text.fullyUpgradedIcon:Hide()
                    text.fullyUpgradedButton:Hide()
                end
            end
        end
    end
end

-- Setup hooks for character frame
local function SetupCharacterFrameHooks()
    -- Modified hook functions with immediate initialization
    PaperDollFrame:HookScript("OnShow", function()
        Debug("PaperDollFrame shown")
        if not next(upgradeTextPool) then
            Debug("Reinitializing texts due to empty pool")
            InitializeUpgradeTexts()
        end
        -- Force a currency update when the character frame is shown
        Debug("Forcing currency update from PaperDollFrame OnShow")
        addon.CheckCurrencyForAllCrests()
        addon.CalculateUpgradedCrests()
        addon.UpdateDisplay()
    end)

    CharacterFrame:HookScript("OnShow", function()
        Debug("CharacterFrame shown")
        if IsCharacterTabSelected() then
            if not next(upgradeTextPool) then
                Debug("Reinitializing texts due to empty pool")
                InitializeUpgradeTexts()
            end
            -- Force a currency update when the character frame is shown
            Debug("Forcing currency update from CharacterFrame OnShow")
            addon.CheckCurrencyForAllCrests()
            addon.CalculateUpgradedCrests()
            addon.UpdateDisplay()
        end
    end)

    -- Modified equipment update hook
    hooksecurefunc("PaperDollItemSlotButton_Update", function(button)
        if IsCharacterTabSelected() and upgradeTextPool[button:GetName():gsub("Character", "")] then
            -- Force a currency update when equipment changes
            Debug("Forcing currency update from PaperDollItemSlotButton_Update")
            addon.CheckCurrencyForAllCrests()
            addon.CalculateUpgradedCrests()
            addon.UpdateDisplay()
        end
    end)
end

-- Initialize the module
local function Initialize()
    SetupCharacterFrameHooks()
    
    -- Hook to the ItemUpgradeFrame to catch all upgrade events
    if ItemUpgradeFrame then
        ItemUpgradeFrame:HookScript("OnHide", addon.UpdateDisplay)
        
        if ItemUpgradeFrame.UpgradeButton then
            ItemUpgradeFrame.UpgradeButton:HookScript("OnClick", addon.UpdateDisplay)
        end
        
        if ItemUpgradeFrame.ItemButton then
            hooksecurefunc(ItemUpgradeFrame.ItemButton, "SetItemLocation", addon.UpdateDisplay)
        end
    else
        -- Register for ADDON_LOADED to hook into the ItemUpgradeFrame when it's available
        local frame = CreateFrame("Frame")
        frame:RegisterEvent("ADDON_LOADED")
        frame:SetScript("OnEvent", function(self, event, loadedAddon)
            if loadedAddon == "Blizzard_ItemUpgradeUI" then
                if ItemUpgradeFrame then
                    ItemUpgradeFrame:HookScript("OnHide", addon.UpdateDisplay)
                    
                    if ItemUpgradeFrame.UpgradeButton then
                        ItemUpgradeFrame.UpgradeButton:HookScript("OnClick", addon.UpdateDisplay)
                    end
                    
                    if ItemUpgradeFrame.ItemButton then
                        hooksecurefunc(ItemUpgradeFrame.ItemButton, "SetItemLocation", addon.UpdateDisplay)
                    end
                end
                self:UnregisterEvent("ADDON_LOADED")
            end
        end)
    end
end

-- Export functions to addon namespace
addon.InitializeUpgradeTexts = InitializeUpgradeTexts
addon.UpdateAllUpgradeTexts = UpdateAllUpgradeTexts
addon.UpdateTextPositions = UpdateTextPositions
addon.SetTextVisibility = SetTextVisibility
addon.upgradeTextPool = upgradeTextPool

-- Initialize when this file is loaded
Initialize() 