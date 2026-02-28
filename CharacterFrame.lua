local addonName, addon = ...

-- Import constants from addon namespace
local EQUIPMENT_SLOTS = addon.EQUIPMENT_SLOTS
local TEXT_POSITIONS = addon.TEXT_POSITIONS
local UPGRADE_TRACKS = addon.UPGRADE_TRACKS

-- Local references to shared functions and data
addon.upgradeTextPool = {}
local upgradeTextPool = addon.upgradeTextPool
local currentTextPos = "TOP" -- Default position

-- Font settings from constants
local fontFile = GameFontNormal:GetFont()
local fontSize = math.floor(addon.FONT_SIZE * 0.85)
local fontFlags = addon.FONT_FLAGS

local function debugPrint(message)
    if addon.debugMode then
        print(string.format("[FullyUpgraded] %s", message))
    end
end

-- Tooltip state management
local tooltipData = {}

-- Use unified tooltip system from addon namespace
local showTooltip = addon.showTooltip
local hideTooltip = addon.hideTooltip

-- Position a button relative to its slot frame based on current text position
local function positionButton(button, slotFrame)
    button:ClearAllPoints()
    local positionData = TEXT_POSITIONS[currentTextPos]
    if positionData then
        if positionData.point == "TOP" then
            button:SetPoint("TOP", slotFrame, "TOP", 0, -1)
        elseif positionData.point == "BOTTOM" then
            button:SetPoint("BOTTOM", slotFrame, "BOTTOM", 0, 1)
        elseif positionData.point == "CENTER" then
            button:SetPoint("CENTER", slotFrame, "CENTER", 0, 0)
        else
            button:SetPoint("TOP", slotFrame, "TOP", 0, -1)
        end
    else
        button:SetPoint("TOP", slotFrame, "TOP", 0, -1)
    end
end

-- Update background strip to match text size and position
local function updateBackgroundStrip(button)
    if not button or not button.text or not button.background then return end

    local textHeight = button.text:GetStringHeight()

    if textHeight > 0 then
        local gearWidth = button.slotFrame:GetWidth() - 2
        local padding = addon.TEXT_BACKGROUND.padding or 2
        local stripHeight = textHeight + (padding * 2)

        button.background:SetSize(gearWidth, stripHeight)
        button.background:ClearAllPoints()
        button.background:SetAllPoints(button)

        button:SetSize(gearWidth, stripHeight)
        positionButton(button, button.slotFrame)
    end
end

-- Creates Upgrade Text for a Slot
local function CreateUpgradeText(slot)
    local slotFrame = _G["Character" .. slot]
    if not slotFrame then return nil end

    local button = CreateFrame("Button", nil, slotFrame)

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetColorTexture(0, 0, 0, 0.28)
    background:Hide()

    local text = button:CreateFontString(nil, "OVERLAY")
    text:SetFont(fontFile, fontSize, fontFlags)
    text:SetJustifyH("RIGHT")
    text:SetDrawLayer("OVERLAY", 7)

    button:EnableMouse(true)
    button:SetFrameLevel(slotFrame:GetFrameLevel() + 1)

    button.text = text
    button.background = background
    button.slot = slot
    button.slotFrame = slotFrame

    text:ClearAllPoints()
    text:SetPoint("LEFT", button, "LEFT", 2, 0)
    text:SetPoint("RIGHT", button, "RIGHT", -2, 0)
    text:SetJustifyH("RIGHT")

    if FullyUpgradedDB and FullyUpgradedDB.textVisible ~= nil then
        if not FullyUpgradedDB.textVisible then
            button:Hide()
        end
    end

    button:SetScript("OnEnter", function(self)
        showTooltip(self, "ANCHOR_RIGHT", addon.tooltipProviders.upgrade, tooltipData[self.slot])
    end)

    button:SetScript("OnLeave", hideTooltip)

    return button
end

-- Initialize All Equipment Slot Overlays
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
                if button.background then
                    button.background:Hide()
                end
            end
        end
    end
end

-- Process an upgradeable item (SIMPLIFIED for Midnight - single crest type)
local function processUpgradeableItem(button, track, trackName, currentNum, maxNum, levelsToUpgrade)
    if not button or not track or not trackName then
        return
    end

    local trackUpper = trackName:upper()
    local trackLetter = trackUpper:sub(1, 1)

    -- Get color for this track type
    local color = addon.TRACK_COLORS[trackUpper] or "ffffff"

    button.text:SetText(string.format("|cFF%s+%d%s|r", color, levelsToUpgrade, trackLetter))

    updateBackgroundStrip(button)
    button.background:Show()
    button:Show()

    -- Simplified tooltip data - single crest type per track in Midnight
    tooltipData[button.slot] = {
        type = "upgradeable",
        track = track,
        trackName = trackName,
        currentNum = currentNum,
        maxNum = maxNum,
        levelsToUpgrade = levelsToUpgrade,
        requirements = {}
    }

    -- Midnight system: single crest type, flat cost
    if track.crestType then
        local crestType = track.crestType
        local crestCurrency = addon.CURRENCY.CRESTS[crestType]
        local goldCost = track.goldCost or 0

        tooltipData[button.slot].requirements.standard = {
            crestType = crestType,
            count = levelsToUpgrade * addon.CRESTS_TO_UPGRADE,
            mythicLevel = crestCurrency and crestCurrency.mythicLevel or 0,
            goldCost = levelsToUpgrade * goldCost
        }
    end

    addon.processUpgradeTrack(track, levelsToUpgrade, trackName)
end

-- Process a fully upgraded item
local function processFullyUpgradedItem(button, trackName, currentNum, maxNum)
    local trackUpper = trackName:upper()
    local trackLetter = trackUpper:sub(1, 1)

    local color = addon.TRACK_COLORS.FULLY_UPGRADED
    button.text:SetText(string.format("|cFF%s%s|r", color, trackLetter))

    updateBackgroundStrip(button)
    button.background:Show()
    button:Show()

    tooltipData[button.slot] = {
        type = "fullyUpgraded",
        trackName = trackName,
        currentNum = currentNum,
        maxNum = maxNum
    }
end

-- Process equipment slot
local function processEquipmentSlot(slot, button)
    button.text:ClearAllPoints()
    button.text:SetPoint("LEFT", button, "LEFT", 2, 0)
    button.text:SetPoint("RIGHT", button, "RIGHT", -2, 0)
    button.text:SetJustifyH("RIGHT")

    button.text:SetText("")
    if button.background then
        button.background:Hide()
    end

    local slotID = GetInventorySlotInfo(slot)
    local itemLink = GetInventoryItemLink("player", slotID)

    if not itemLink then
        button:Hide()
        return
    end

    local _, _, _, effectiveILvl = addon.getCachedItemInfo(itemLink)
    local itemTooltip = addon.getCachedTooltipData(slotID, itemLink)
    local shouldShow = false

    if effectiveILvl and itemTooltip then
        local minIlvl, maxIlvl = addon.getCurrentSeasonItemLevelRange()

        if effectiveILvl >= minIlvl and effectiveILvl <= maxIlvl then
            -- Process upgrade levels (Midnight uses X/6 format)
            for _, line in ipairs(itemTooltip.lines) do
                if line and line.leftText then
                    local trackName, current, max = line.leftText:match("Upgrade Level: (%w+) (%d+)/(%d+)")
                    if trackName then
                        local trackUpper = trackName:upper()
                        local currentNum = tonumber(current)
                        local maxNum = tonumber(max)

                        if currentNum and maxNum then
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

    if not shouldShow or (FullyUpgradedDB and not FullyUpgradedDB.textVisible) then
        button:Hide()
        if button.background then
            button.background:Hide()
        end
    end
end

-- Main update function for all upgrade texts
local function updateAllUpgradeTexts()
    if not next(upgradeTextPool) then
        initializeUpgradeTexts()
    end

    if FullyUpgradedDB and FullyUpgradedDB.textPosition and TEXT_POSITIONS[FullyUpgradedDB.textPosition] then
        currentTextPos = FullyUpgradedDB.textPosition
    else
        currentTextPos = "TOP"
        FullyUpgradedDB.textPosition = "TOP"
    end

    -- Reset needed counts
    for crestType, _ in pairs(addon.CURRENCY.CRESTS) do
        addon.CURRENCY.CRESTS[crestType].needed = 0
    end

    -- Reset total upgrades counter
    addon.totalUpgrades = 0

    -- Process each equipment slot
    for _, slot in ipairs(EQUIPMENT_SLOTS) do
        local button = upgradeTextPool[slot]
        if button then
            processEquipmentSlot(slot, button)
        end
    end

    -- Update title with total upgrades
    if addon.titleText and addon.totalUpgrades then
        if addon.totalUpgrades > 0 then
            addon.titleText:SetText(string.format("Fully Upgraded in %d", addon.totalUpgrades))
        else
            addon.titleText:SetText("Fully Upgraded")
        end
    end
end

-- Update text positions
local function updateTextPositions(position)
    if not TEXT_POSITIONS[position] then return end

    currentTextPos = position

    if FullyUpgradedDB then
        FullyUpgradedDB.textPosition = position
    end

    for slot, button in pairs(upgradeTextPool) do
        if button and button.slotFrame then
            button.text:ClearAllPoints()
            button.text:SetPoint("LEFT", button, "LEFT", 2, 0)
            button.text:SetPoint("RIGHT", button, "RIGHT", -2, 0)
            button.text:SetJustifyH("RIGHT")

            if button.text:GetText() and button.text:GetText() ~= "" then
                updateBackgroundStrip(button)
            else
                positionButton(button, button.slotFrame)
            end

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
                if button.background then
                    button.background:Hide()
                end
            end
        end
    end
end

-- Setup character frame hooks
local function setupCharacterFrameHooks()
    local function doUpdate()
        if addon.updateDisplay then
            addon.updateDisplay()
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

    -- Debounced equipment update hook
    local updatePending = false
    local UPDATE_DEBOUNCE = 0.3

    if PaperDollItemSlotButton_Update then
        hooksecurefunc("PaperDollItemSlotButton_Update", function(button)
            if not button or not addon.isCharacterTabSelected() then return end
            if not upgradeTextPool[button:GetName():gsub("Character", "")] then return end

            if not updatePending then
                updatePending = true
                C_Timer.After(UPDATE_DEBOUNCE, function()
                    if addon.isCharacterTabSelected() then
                        doUpdate()
                    end
                    updatePending = false
                end)
            end
        end)
    end
end

-- Initialize the module
local function initialize()
    debugPrint("Initializing character frame module...")
    setupCharacterFrameHooks()
    initializeUpgradeTexts()
    debugPrint("Character frame module initialized successfully")
end

-- Export functions to addon namespace
addon.initializeUpgradeTexts = initializeUpgradeTexts
addon.updateAllUpgradeTexts = updateAllUpgradeTexts
addon.updateTextPositions = updateTextPositions
addon.setTextVisibility = setTextVisibility
addon.upgradeTextPool = upgradeTextPool

print("[FullyUpgraded] CharacterFrame.lua loaded (Midnight Edition)")
addon.initializeCharacterFrame = initialize
