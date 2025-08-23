local addonName, addon = ...

local TEXT_POSITIONS = addon.TEXT_POSITIONS

local function CreateOptionsFrame(parent)
    local frame = CreateFrame("Frame", "FullyUpgradedOptions", parent, "BackdropTemplate")
    frame:SetSize(280, 35)
    frame:SetPoint("TOP", parent, "BOTTOM", 0, 0)

    frame:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8x8",
        edgeFile = "Interface/Buttons/WHITE8x8",
        tile = true,
        tileSize = 8,
        edgeSize = 2,
    })
    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    frame:SetBackdropBorderColor(0, 0, 0, 1)
    frame:Hide()

    -- Create custom checkbox
    local checkbox = CreateFrame("Button", nil, frame, "BackdropTemplate")
    checkbox:SetSize(12, 12)
    checkbox:SetPoint("LEFT", frame, "LEFT", 10, 0)

    checkbox:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8x8",
        edgeFile = "Interface/Buttons/WHITE8x8",
        tile = true,
        tileSize = 8,
        edgeSize = 1,
    })
    checkbox:SetBackdropColor(0.2, 0.2, 0.2, 1)
    checkbox:SetBackdropBorderColor(0, 0, 0, 1)

    -- Create fill texture
    checkbox.fill = checkbox:CreateTexture(nil, "ARTWORK")
    checkbox.fill:SetTexture("Interface/Buttons/WHITE8x8")
    checkbox.fill:SetVertexColor(1, 0.82, 0, 1) -- Gold color
    checkbox.fill:SetAllPoints()
    checkbox.fill:SetPoint("TOPLEFT", 2, -2)
    checkbox.fill:SetPoint("BOTTOMRIGHT", -2, 2)

    -- Set initial state
    checkbox.checked = true
    checkbox.fill:Show()

    local checkboxLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    checkboxLabel:SetPoint("LEFT", checkbox, "RIGHT", 4, 0)
    checkboxLabel:SetText("Show Text")
    checkboxLabel:SetTextColor(1, 0.82, 0) -- Gold color

    checkbox:SetScript("OnClick", function(self)
        self.checked = not self.checked
        if self.checked then
            self.fill:Show()
        else
            self.fill:Hide()
        end
        -- Update both text and icon visibility
        addon.SetTextVisibility(self.checked)
    end)

    -- Create position label
    local positionLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    positionLabel:SetPoint("LEFT", checkboxLabel, "RIGHT", 15, 0)
    positionLabel:SetText("Position:")
    positionLabel:SetTextColor(1, 0.82, 0) -- Gold color

    -- Create dropdown menu
    local dropdown = CreateFrame("Frame", "FullyUpgradedPositionDropdown", frame, "UIDropDownMenuTemplate")
    dropdown:SetPoint("LEFT", positionLabel, "RIGHT", -12, 1)
    dropdown:SetPoint("RIGHT", frame, "RIGHT", 0, 1)

    local function OnClick(self, arg1, arg2, checked)
        UIDropDownMenu_SetSelectedValue(dropdown, self.value)
        UIDropDownMenu_SetText(dropdown, self.value)
        addon.UpdateTextPositions(self.value)
    end

    local function Initialize(self, level)
        local info = UIDropDownMenu_CreateInfo()
        -- Simplified position options
        local positions = {
            { value = "TOP", text = "Top" },
            { value = "BOTTOM", text = "Bottom" },
            { value = "C", text = "Center" }
        }

        for _, pos in ipairs(positions) do
            info.text = pos.text
            info.value = pos.value
            info.func = OnClick
            info.notCheckable = true
            UIDropDownMenu_AddButton(info, level)
        end
    end

    -- Initialize the dropdown
    UIDropDownMenu_Initialize(dropdown, Initialize)
    UIDropDownMenu_SetWidth(dropdown, 65)
    UIDropDownMenu_SetSelectedValue(dropdown, "TOP")
    UIDropDownMenu_SetText(dropdown, "Top")

    -- Style the dropdown
    local dropdownButton = _G[dropdown:GetName() .. "Button"]
    if dropdownButton then
        dropdownButton:SetNormalTexture("Interface/Buttons/WHITE8x8")
        dropdownButton:GetNormalTexture():SetVertexColor(0.2, 0.2, 0.2, 0.8)
    end

    -- Style the dropdown text
    local dropdownText = _G[dropdown:GetName() .. "Text"]
    if dropdownText then
        dropdownText:SetTextColor(1, 0.82, 0)
    end

    -- Show and style the dropdown arrow
    local dropdownArrow = _G[dropdown:GetName() .. "Button" .. "Normal"]
    if dropdownArrow then
        dropdownArrow:SetTexture("Interface/Buttons/UI-ScrollBar-ScrollDownButton-Up")
        dropdownArrow:SetSize(16, 16)
        dropdownArrow:SetVertexColor(1, 0.82, 0) -- Gold color to match the text
    end

    return frame
end

-- Export the create function to the addon namespace
addon.CreateOptionsFrame = CreateOptionsFrame
