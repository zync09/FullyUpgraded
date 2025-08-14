local addonName, addon = ...
addon.version = "2.0.0"

-- Core state management
local state = {
    initialized = false,
    inCombat = false,
    pendingUpdate = false,
    characterPanelVisible = false
}

-- Main event frame
local eventFrame = CreateFrame("Frame")
addon.eventFrame = eventFrame

-- Combat state management
local function UpdateCombatState(inCombat)
    state.inCombat = inCombat
    
    if not inCombat and state.pendingUpdate then
        state.pendingUpdate = false
        addon:UpdateAll()
    end
end

-- Check if updates should be processed
function addon:ShouldProcess()
    return not state.inCombat and state.characterPanelVisible and state.initialized
end

-- Request an update (respects combat state)
function addon:RequestUpdate()
    if state.inCombat then
        state.pendingUpdate = true
        return
    end
    
    if self:ShouldProcess() then
        self:UpdateAll()
    end
end

-- Main update function
function addon:UpdateAll()
    
    if not self:ShouldProcess() then return end
    
    -- Update data
    if self.Data then
        self.Data:ScanEquipment()
    end
    
    -- Update UI
    if self.UI then
        self.UI:UpdateDisplay()
    end
    
    -- Update currency
    if self.Currency then
        self.Currency:Update()
    end
end

-- Character panel visibility tracking
local function UpdatePanelVisibility()
    state.characterPanelVisible = CharacterFrame and CharacterFrame:IsShown() and PaperDollFrame and PaperDollFrame:IsVisible()
    
    
    if state.characterPanelVisible then
        addon:RequestUpdate()
    else
        -- Hide UI elements when panel closes
        if addon.UI then
            addon.UI:HideAll()
        end
    end
end

-- Initialize addon
local function Initialize()
    if state.initialized then return end
    
    
    -- Load saved variables
    FullyUpgradedDB = FullyUpgradedDB or {
        textPosition = "TR",
        textVisible = true,
        version = addon.version
    }
    
    
    -- Initialize modules
    if addon.Data then addon.Data:Initialize() end
    if addon.UI then addon.UI:Initialize() end
    if addon.Currency then addon.Currency:Initialize() end
    
    state.initialized = true
    
    
    -- Set up character frame hooks AFTER initialization
    CharacterFrame:HookScript("OnShow", UpdatePanelVisibility)
    CharacterFrame:HookScript("OnHide", UpdatePanelVisibility)
    if PaperDollFrame then
        PaperDollFrame:HookScript("OnShow", UpdatePanelVisibility)
        PaperDollFrame:HookScript("OnHide", UpdatePanelVisibility)
    end
    hooksecurefunc("ToggleCharacter", UpdatePanelVisibility)
    
    -- Initial update if character panel is open
    UpdatePanelVisibility()
end

-- Event handling
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        Initialize()
    elseif event == "PLAYER_ENTERING_WORLD" then
        local isInitialLogin, isReloadingUi = ...
        if isInitialLogin or isReloadingUi then
            Initialize()
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        UpdateCombatState(true)
    elseif event == "PLAYER_REGEN_ENABLED" then
        UpdateCombatState(false)
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        addon:RequestUpdate()
    elseif event == "CURRENCY_DISPLAY_UPDATE" then
        if addon.Currency then
            addon.Currency:OnCurrencyUpdate()
        end
    end
end)

-- Slash commands
SLASH_FULLYUPGRADED1 = "/fullyupgraded"
SLASH_FULLYUPGRADED2 = "/fu"

SlashCmdList["FULLYUPGRADED"] = function(msg)
    local cmd, arg = msg:match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()
    
    if cmd == "textpos" then
        arg = arg:upper()
        if addon.UI and addon.UI:SetTextPosition(arg) then
            print("|cFFFFFF00FullyUpgraded:|r Text position set to " .. arg)
        else
            print("|cFFFFFF00FullyUpgraded:|r Valid positions: TR, TL, BR, BL, C")
        end
    elseif cmd == "hide" then
        FullyUpgradedDB.textVisible = false
        if addon.UI then addon.UI:UpdateVisibility() end
        print("|cFFFFFF00FullyUpgraded:|r Text hidden")
    elseif cmd == "show" then
        FullyUpgradedDB.textVisible = true
        if addon.UI then addon.UI:UpdateVisibility() end
        print("|cFFFFFF00FullyUpgraded:|r Text shown")
    elseif cmd == "refresh" then
        print("|cFFFFFF00FullyUpgraded:|r Refreshing...")
        addon:RequestUpdate()
    else
        print("|cFFFFFF00FullyUpgraded " .. addon.version .. " commands:|r")
        print("  /fu textpos <position> - Set text position (TR/TL/BR/BL/C)")
        print("  /fu show - Show upgrade text")
        print("  /fu hide - Hide upgrade text")
        print("  /fu refresh - Manually refresh")
    end
end