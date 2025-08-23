local addonName, addon = ...

-- Import constants from addon namespace
local EQUIPMENT_SLOTS = addon.EQUIPMENT_SLOTS
local TEXT_POSITIONS = addon.TEXT_POSITIONS
local UPGRADE_TRACKS = addon.UPGRADE_TRACKS

-- Local references to shared functions and data
addon.upgradeTextPool = {}  -- Make upgradeTextPool accessible to the main file
local upgradeTextPool = addon.upgradeTextPool
local currentTextPos = "TR" -- Default position

-- Font settings from constants
local fontFile = GameFontNormal:GetFont()
local fontSize = addon.FONT_SIZE
local fontFlags = addon.FONT_FLAGS

local function debugPrint(message)
    if addon.debugMode then
        print(string.format("[FullyUpgraded] %s", message))
    end
end

-- Tooltip state management
local tooltipData = {}

-- Simple tooltip handling
local function showTooltip(button, tooltipFunc)
    if not button:IsVisible() or not addon.isCharacterTabSelected() then return end

    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()

    if tooltipFunc then
        tooltipFunc(button)
    end

    GameTooltip:Show()
end

local function hideTooltip()
    GameTooltip:Hide()
end

-- **Creates Upgrade Text for a Slot**
local function CreateUpgradeText(slot)
    local slotFrame = _G["Character" .. slot]
    if not slotFrame then return nil end

    local button = CreateFrame("Button", nil, slotFrame)
    button:SetSize(30, 20)

    local text = button:CreateFontString(nil, "OVERLAY")
    text:SetFont(fontFile, fontSize, fontFlags)
    text:SetJustifyH("RIGHT")
    text:SetDrawLayer("OVERLAY", 7)

    button:EnableMouse(true)
    button:SetFrameLevel(slotFrame:GetFrameLevel() + 1)

    button.text = text
    button.slot = slot
    button.slotFrame = slotFrame

    local posData = TEXT_POSITIONS[currentTextPos]
    button:ClearAllPoints()
    button:SetPoint(posData.point, slotFrame, posData.point, posData.x, posData.y)
    text:ClearAllPoints()
    text:SetPoint("CENTER", button, "CENTER", 0, 0)

    -- Set initial visibility based on saved setting
    if FullyUpgradedDB and FullyUpgradedDB.textVisible ~= nil then
        if not FullyUpgradedDB.textVisible then
            button:Hide()
        end
    end

    -- Set up tooltip handling
    button:SetScript("OnEnter", function(self)
        showTooltip(self, function(button)
            addon.setUpgradeTooltip(button, tooltipData[button.slot])
        end)
    end)

    button:SetScript("OnLeave", hideTooltip)

    return button
end

-- **Initialize All Equipment Slot Overlays**
local function initializeUpgradeTexts()
    if next(upgradeTextPool) then return end

    for _, slot in ipairs(EQUIPMENT_SLOTS) do
        local button = CreateUpgradeText(slot)
        if button then
            upgradeTextPool[slot] = button
        end
    end
end

-- Clean up text elements
local function cleanupUpgradeTexts()
    hideTooltip()

    for slot, button in pairs(upgradeTextPool) do
        if button then
            if button:IsVisible() then
                button:Hide()
            end
        end
    end
end

-- Process a Season 1 item
local function processSeason1Item(button)
    button.text:SetText(string.format("|cFF%02x%02x%02xS1|r", 240, 100, 50))
    button:Show()

    -- Store tooltip data
    tooltipData[button.slot] = {
        type = "season1"
    }
end

-- Process an upgradeable item
local function processUpgradeableItem(button, track, trackName, currentNum, maxNum, levelsToUpgrade)
    if not button or not track or not trackName then
        return
    end

    local trackUpper = trackName:upper()
    local trackLetter = trackUpper:sub(1, 1)

    button.text:SetText("|cFFffffff+" .. levelsToUpgrade .. trackLetter .. "|r")
    button:Show()

    -- Calculate and store tooltip data
    tooltipData[button.slot] = {
        type = "upgradeable",
        track = track,
        trackName = trackName,
        currentNum = currentNum,
        maxNum = maxNum,
        levelsToUpgrade = levelsToUpgrade,
        requirements = {}
    }

    -- Calculate requirements
    if track.splitUpgrade then
        local firstTier = track.splitUpgrade.firstTier
        local secondTier = track.splitUpgrade.secondTier

        -- Validate tier data before processing
        if firstTier and firstTier.levels and firstTier.shortname then
            local remainingFirstTier = math.min(levelsToUpgrade, math.max(0, firstTier.levels - currentNum))
            local remainingSecondTier = secondTier and math.max(0, levelsToUpgrade - remainingFirstTier) or 0

            if remainingFirstTier > 0 and firstTier.crest then
                local firstTierShortname = firstTier.shortname:upper()
                local firstTierCurrency = addon.CURRENCY.CRESTS[firstTierShortname]

                tooltipData[button.slot].requirements.firstTier = {
                    crestType = firstTierShortname,
                    count = remainingFirstTier * addon.CRESTS_TO_UPGRADE,
                    mythicLevel = firstTierCurrency and firstTierCurrency.mythicLevel or 0
                }
            end

            -- Only process second tier if it exists and has valid data
            if remainingSecondTier > 0 and secondTier and secondTier.crest and secondTier.shortname then
                local secondTierShortname = secondTier.shortname:upper()
                local secondTierCurrency = addon.CURRENCY.CRESTS[secondTierShortname]

                tooltipData[button.slot].requirements.secondTier = {
                    crestType = secondTierShortname,
                    count = remainingSecondTier * addon.CRESTS_TO_UPGRADE,
                    mythicLevel = secondTierCurrency and secondTierCurrency.mythicLevel or 0
                }
            end
        end
    end

    addon.processUpgradeTrack(track, levelsToUpgrade, currentNum)
end

-- Process a fully upgraded item
local function processFullyUpgradedItem(button, trackName, currentNum, maxNum)
    local trackLetter = trackName:upper():sub(1, 1)
    button.text:SetText("|cFFffffff" .. trackLetter .. "|r")
    button:Show()

    -- Store tooltip data
    tooltipData[button.slot] = {
        type = "fullyUpgraded",
        trackName = trackName,
        currentNum = currentNum,
        maxNum = maxNum
    }
end

-- Process equipment slot
local function processEquipmentSlot(slot, button)
    button:ClearAllPoints()
    local posData = TEXT_POSITIONS[currentTextPos]
    button:SetPoint(posData.point, button.slotFrame, posData.point, posData.x, posData.y)
    button.text:SetText("")

    -- Ensure tooltip handlers are set
    button:SetScript("OnEnter", function(self)
        showTooltip(self, function(button)
            addon.setUpgradeTooltip(button, tooltipData[button.slot])
        end)
    end)
    button:SetScript("OnLeave", hideTooltip)

    local slotID = GetInventorySlotInfo(slot)
    local itemLink = GetInventoryItemLink("player", slotID)

    if not itemLink then
        button:Hide()
        return
    end

    local _, _, _, effectiveILvl = addon.getCachedItemInfo(itemLink)
    local tooltipData = addon.getCachedTooltipData(slotID, itemLink)
    local shouldShow = false

    if effectiveILvl and tooltipData then
        local minIlvl, maxIlvl = addon.getCurrentSeasonItemLevelRange()

        if effectiveILvl >= minIlvl and effectiveILvl <= maxIlvl then
            -- Check for Season 1 item
            for _, line in ipairs(tooltipData.lines) do
                if line.leftText and line.leftText:find("The War Within Season 1") then
                    processSeason1Item(button)
                    shouldShow = true
                    break
                end
            end

            -- Process upgrade levels for non-Season 1 items
            if not shouldShow then
                for _, line in ipairs(tooltipData.lines) do
                    if line and line.leftText then
                        local trackName, current, max = line.leftText:match("Upgrade Level: (%w+) (%d+)/(%d+)")
                        if trackName then
                            local trackUpper = trackName:upper()
                            local currentNum = tonumber(current)
                            local maxNum = tonumber(max)

                            -- Check if we have valid numbers
                            if currentNum and maxNum then
                                -- Find the matching track
                                local track = UPGRADE_TRACKS[trackUpper]
                                if track then
                                    shouldShow = true
                                    if currentNum < maxNum then
                                        processUpgradeableItem(button, track, trackName, currentNum, maxNum,
                                            maxNum - currentNum)
                                    else
                                        processFullyUpgradedItem(button, trackName, currentNum, maxNum)
                                    end
                                end
                            end
                            break
                        end
                    end
                end
            end
        end
    end

    if not shouldShow or (FullyUpgradedDB and not FullyUpgradedDB.textVisible) then
        button:Hide()
    end
end

-- Main update function for all upgrade texts
local function updateAllUpgradeTexts()
    -- Make sure we have text elements initialized
    if not next(upgradeTextPool) then
        initializeUpgradeTexts()
    end
    
    -- Ensure saved variables are loaded
    if not FullyUpgradedDB then
        FullyUpgradedDB = {
            textPosition = "TR",
            textVisible = true
        }
    end
    if FullyUpgradedDB.textVisible == nil then
        FullyUpgradedDB.textVisible = true
    end

    -- Reset needed counts
    for crestType, _ in pairs(addon.CURRENCY.CRESTS) do
        addon.CURRENCY.CRESTS[crestType].needed = 0
    end

    -- Process each equipment slot
    for _, slot in ipairs(EQUIPMENT_SLOTS) do
        local button = upgradeTextPool[slot]
        if button then
            processEquipmentSlot(slot, button)
        end
    end
end

-- Update text positions
local function updateTextPositions(position)
    if not TEXT_POSITIONS[position] then return end

    currentTextPos = position
    local posData = TEXT_POSITIONS[position]

    for slot, button in pairs(upgradeTextPool) do
        if button and button.slotFrame then
            button:ClearAllPoints()
            button:SetPoint(posData.point, button.slotFrame, posData.point, posData.x, posData.y)
            processEquipmentSlot(slot, button)
        end
    end
end

-- Set text visibility
local function setTextVisibility(show)
    for slot, button in pairs(upgradeTextPool) do
        if button then
            if show then
                processEquipmentSlot(slot, button)
            else
                button:Hide()
                button.text:SetText("")
            end
        end
    end
end

-- Setup character frame hooks
local function setupCharacterFrameHooks()
    local function doUpdate()
        if addon.isCharacterTabSelected() then
            -- Debug: Check if functions exist before calling
            if not addon.checkCurrencyForAllCrests then
                print("[FullyUpgraded] ERROR: checkCurrencyForAllCrests not found in addon namespace")
                return
            end
            if not addon.calculateUpgradedCrests then
                print("[FullyUpgraded] ERROR: calculateUpgradedCrests not found in addon namespace")
                return
            end
            if not addon.updateAllUpgradeTexts then
                print("[FullyUpgraded] ERROR: updateAllUpgradeTexts not found in addon namespace")
                return
            end
            
            addon.checkCurrencyForAllCrests()
            addon.calculateUpgradedCrests()
            addon.updateAllUpgradeTexts()
        end
    end

    if PaperDollFrame then
        PaperDollFrame:HookScript("OnShow", doUpdate)
        PaperDollFrame:HookScript("OnHide", hideTooltip)
    end

    if CharacterFrame then
        CharacterFrame:HookScript("OnShow", doUpdate)
        CharacterFrame:HookScript("OnHide", cleanupUpgradeTexts)
    end

    -- Hook equipment updates with throttling
    local updateThrottled = false
    if PaperDollItemSlotButton_Update then
        hooksecurefunc("PaperDollItemSlotButton_Update", function(button)
            if button and addon.isCharacterTabSelected() and upgradeTextPool[button:GetName():gsub("Character", "")] then
                if not updateThrottled then
                    updateThrottled = true
                    C_Timer.After(addon.UPDATE_THROTTLE_TIME, function()
                        if addon.isCharacterTabSelected() then
                            doUpdate()
                        end
                        updateThrottled = false
                    end)
                end
            end
        end)
    end
end

-- Initialize the module
local function initialize()
    debugPrint("Initializing character frame module...")
    setupCharacterFrameHooks()
    -- Ensure upgrade texts are initialized when character frame is set up
    initializeUpgradeTexts()
    debugPrint("Character frame module initialized successfully")
end

-- Update crest currency display
local function updateCrestCurrency(frame)
    if not frame then return end

    -- Clear existing children
    local children = { frame:GetChildren() }
    for _, child in ipairs(children) do
        child:Hide()
        child:SetParent(nil)
    end

    -- First pass: calculate total width
    local totalWidth = 0
    local iconSize = 16
    local spacing = 6 -- Spacing between currency groups
    local elements = {}

    -- Calculate widths and create elements
    for _, crestType in ipairs(addon.CREST_ORDER) do
        local crestData = addon.CURRENCY.CRESTS[crestType]
        if crestData and crestData.currencyID then
            local info = C_CurrencyInfo.GetCurrencyInfo(crestData.currencyID)
            if info then
                -- Create temporary font string to measure text width
                local tempText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                tempText:SetText(info.quantity)
                local textWidth = tempText:GetStringWidth()
                tempText:Hide()

                -- Add to total width
                totalWidth = totalWidth + iconSize + textWidth + 2 -- 2 for spacing between icon and text

                -- Store element info
                table.insert(elements, {
                    crestType = crestType,
                    info = info,
                    textWidth = textWidth
                })

                -- Add separator width if not last
                if _ < #addon.CREST_ORDER then
                    totalWidth = totalWidth + spacing + 2 -- 2 for separator width
                end
            end
        end
    end

    -- Calculate starting X position to center everything
    local xOffset = (frame:GetWidth() - totalWidth) / 2
    xOffset = frame:GetWidth() - xOffset -- Convert to right-side offset

    -- Second pass: create and position elements
    for i, element in ipairs(elements) do
        -- Create icon
        local icon = CreateFrame("Frame", nil, frame)
        icon:SetSize(iconSize, iconSize)
        icon:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -xOffset, 0)

        local texture = icon:CreateTexture(nil, "ARTWORK")
        texture:SetAllPoints()
        texture:SetTexture(element.info.iconFileID)

        -- Create count text
        local count = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        count:SetPoint("RIGHT", icon, "LEFT", -2, 0)
        count:SetText(element.info.quantity)

        -- Color based on CREST_BASE
        local baseData = addon.CREST_BASE[element.crestType]
        if baseData and baseData.color then
            count:SetTextColor(
                tonumber(baseData.color:sub(1, 2), 16) / 255,
                tonumber(baseData.color:sub(3, 4), 16) / 255,
                tonumber(baseData.color:sub(5, 6), 16) / 255
            )
        end

        -- Update xOffset
        xOffset = xOffset + iconSize + element.textWidth + 2

        -- Add separator if not last
        if i < #elements then
            local separator = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            separator:SetPoint("RIGHT", count, "LEFT", -2, 0)
            separator:SetText("|")
            separator:SetTextColor(0.5, 0.5, 0.5)
            xOffset = xOffset + spacing + 2
        end
    end
end

-- Export functions to addon namespace
addon.initializeUpgradeTexts = initializeUpgradeTexts
addon.updateAllUpgradeTexts = updateAllUpgradeTexts
addon.updateTextPositions = updateTextPositions
addon.setTextVisibility = setTextVisibility
addon.upgradeTextPool = upgradeTextPool
addon.updateCrestCurrency = updateCrestCurrency

-- Debug command is handled in main FullyUpgraded.lua file

-- Export initialize function, will be called from main FullyUpgraded.lua
print("[FullyUpgraded] CharacterFrame.lua loaded, exporting initializeCharacterFrame")
addon.initializeCharacterFrame = initialize
