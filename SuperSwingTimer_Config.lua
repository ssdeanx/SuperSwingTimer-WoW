local _, ns = ...
local CreateFrame = rawget(_G, "CreateFrame")
local UIParent = rawget(_G, "UIParent")
local InCombatLockdown = rawget(_G, "InCombatLockdown")
local ColorPickerFrame = rawget(_G, "ColorPickerFrame")
local GameTooltip = rawget(_G, "GameTooltip")
local UIDropDownMenu_AddButton = rawget(_G, "UIDropDownMenu_AddButton")
local UIDropDownMenu_CreateInfo = rawget(_G, "UIDropDownMenu_CreateInfo")
local UIDropDownMenu_Initialize = rawget(_G, "UIDropDownMenu_Initialize")
local UIDropDownMenu_SetText = rawget(_G, "UIDropDownMenu_SetText")
local UIDropDownMenu_SetWidth = rawget(_G, "UIDropDownMenu_SetWidth")
local ToggleDropDownMenu = rawget(_G, "ToggleDropDownMenu")

-- ============================================================
-- Config panel: /sst opens this frame.
-- Dropdowns for layer / mode selectors, checkboxes for toggles,
-- sliders with numeric entry boxes, and color picker buttons for bar colors.
-- ============================================================

local panel
local layoutShift = 120
local layoutScale = 1.6

local function ShiftY(y)
	return math.floor((y * layoutScale) + 0.5) - layoutShift
end

local INDICATOR_BLEND_OPTIONS = {
	{ label = "Glow", value = "ADD" },
	{ label = "Opaque", value = "BLEND" },
}

local function GetOptionLabel(options, value)
	for _, option in ipairs(options) do
		if option.value == value then
			return option.label
		end
	end
	return options[1].label
end

local function FormatSliderValue(step, value)
	if step and step < 1 then
		return string.format("%.2f", value)
	end

	return tostring(math.floor(value + 0.5))
end

local function NormalizeSliderValue(text, minVal, maxVal, step)
	local value = tonumber(text)
	if not value then
		return nil
	end

	value = math.max(minVal, math.min(maxVal, value))
	if step and step > 0 then
		value = minVal + math.floor(((value - minVal) / step) + 0.5) * step
		value = math.max(minVal, math.min(maxVal, value))
	end

	return value
end

local function SyncSliderDisplay(slider, value)
	if not slider then
		return
	end

	local displayValue = slider.formatValue and slider.formatValue(value) or tostring(value)
	if slider.valueText then
		slider.valueText:SetText(displayValue)
	end
	if slider.valueBox and not slider.valueBox:HasFocus() then
		slider.valueBox:SetText(displayValue)
	end
end

local function AddRowHoverHighlight(row, alpha)
	if not row then
		return nil
	end

	local highlight = row:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetColorTexture(1, 1, 1, alpha or 0.06)
	highlight:SetAllPoints(true)
	return highlight
end

local function AddControlTooltip(frame, title, text)
	if not frame or not GameTooltip or not frame.HookScript then
		return
	end

	frame:HookScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(title or "", 1, 1, 1)
		if text and text ~= "" then
			GameTooltip:AddLine(text, 0.9, 0.9, 0.9, true)
		end
		GameTooltip:Show()
	end)
	frame:HookScript("OnLeave", function()
		GameTooltip:Hide()
	end)
end

local function GetTextureSummaryText(texturePath)
	if ns.GetTextureSummaryText then
		return ns.GetTextureSummaryText(texturePath)
	end

	return string.format("%s | Bar: %s", ns.GetTextureDisplayText(texturePath), ns.GetTextureDisplayText(ns.GetBarTexture and ns.GetBarTexture() or nil))
end

-- ============================================================
-- Bar preview: show bars while config panel is open
-- ============================================================
local function ShowBarPreview()
	local bars = { ns.mhBar, ns.ohBar, ns.rangedBar }
	for _, bar in ipairs(bars) do
		if bar then
			bar:SetAlpha(1)
			bar:SetMinMaxValues(0, 1)
			bar:SetValue(1)
		end
	end
	ns.ApplyBarTexture(ns.GetBarTexture(), ns.GetBarTextureLayer())
	ns.ApplyRangedBarTexture(ns.GetRangedBarTexture(), ns.GetBarTextureLayer())
	ns.ApplySparkSettings(
		ns.GetSparkTexture(),
		ns.GetSparkWidth(),
		ns.GetSparkHeight(),
		ns.GetSparkTextureLayer(),
		ns.GetSparkAlpha()
	)
	ns.ApplyBarBackgroundAlpha(ns.GetBarBackgroundAlpha())
	ns.ApplyMinimalMode(ns.IsMinimalMode())
	ns.ApplyBarColors()
	ns.ApplyIndicatorBlendMode(ns.GetIndicatorBlendMode())
	ns.ApplyVisibility()
end

local function HideBarPreview()
	-- Only hide if not in combat (combat show/hide handles itself)
	if not InCombatLockdown or not InCombatLockdown() then
		local bars = { ns.mhBar, ns.ohBar, ns.rangedBar }
		for _, bar in ipairs(bars) do
			if bar then bar:SetAlpha(0) end
		end
	end
end

-- ============================================================
-- Color picker helper
-- ============================================================
local function OpenColorPicker(colorKey, swatch)
	local c = ns.GetBarColor(colorKey)
	local isSealTwist = (colorKey == "sealTwist")

	local function applyColor(r, g, b)
		local a = 1
		if not isSealTwist then
			SuperSwingTimerDB.useClassColors = false
		end
		SuperSwingTimerDB.colors[colorKey] = { r = r, g = g, b = b, a = a }
		swatch:SetColorTexture(r, g, b, a)
		ns.ApplyBarColors()
		if panel and panel.useClassColorsRow and panel.useClassColorsRow.refresh then
			panel.useClassColorsRow.refresh()
		end
		if panel and panel.colorRows then
			for _, colorRow in ipairs(panel.colorRows) do
				local key = colorRow.button.colorKey
				local effective = ns.GetBarColor(key)
				if effective then
					colorRow.swatch:SetColorTexture(effective.r, effective.g, effective.b, effective.a)
				end
			end
		end
	end

	local info = {
		r = c.r,
		g = c.g,
		b = c.b,
		swatchFunc = function()
			local r, g, b = ColorPickerFrame:GetColorRGB()
			applyColor(r, g, b)
		end,
		cancelFunc = function(prev)
			applyColor(prev.r, prev.g, prev.b)
		end,
	}
	ColorPickerFrame:SetupColorPickerAndShow(info)
end

-- ============================================================
-- Widget builders
-- ============================================================
local function CreateSlider(parent, label, minVal, maxVal, step, yOffset)
	local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
	slider:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
	slider:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -90, yOffset)
	slider:SetMinMaxValues(minVal, maxVal)
	slider:SetValueStep(step)
	slider:SetObeyStepOnDrag(true)
	slider:SetHeight(17)

	slider.Text:SetText(label)
	slider.Low:SetText(tostring(minVal))
	slider.High:SetText(tostring(maxVal))
	slider.formatValue = function(value)
		return FormatSliderValue(step, value)
	end

	-- Value label below the slider
	local valText = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	valText:SetPoint("TOP", slider, "BOTTOM", 0, -2)
	slider.valueText = valText

	local valueBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	valueBox:SetSize(54, 20)
	valueBox:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -20, yOffset - 1)
	valueBox:SetAutoFocus(false)
	valueBox:SetMaxLetters(8)
	valueBox:SetJustifyH("CENTER")
	valueBox:SetScript("OnEnterPressed", function(self)
		local parsed = NormalizeSliderValue(self:GetText(), minVal, maxVal, step)
		if parsed ~= nil then
			slider:SetValue(parsed)
		end
		self:ClearFocus()
		SyncSliderDisplay(slider, slider:GetValue())
	end)
	valueBox:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
		SyncSliderDisplay(slider, slider:GetValue())
	end)
	valueBox:SetScript("OnEditFocusGained", function(self)
		self:HighlightText()
	end)
	valueBox:SetScript("OnEditFocusLost", function(self)
		SyncSliderDisplay(slider, slider:GetValue())
	end)
	slider.valueBox = valueBox
	AddControlTooltip(slider, label, string.format("Drag or type a value to change %s.", label))
	AddControlTooltip(valueBox, label, string.format("Type a value for %s.", label))

	SyncSliderDisplay(slider, slider:GetValue())

	return slider
end

local function CreateColorButton(parent, label, colorKey, yOffset)
	local row = CreateFrame("Frame", nil, parent)
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
	row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -20, yOffset)
	row:SetHeight(44)
	row:EnableMouse(true)
	row.hover = AddRowHoverHighlight(row)

	local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	text:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
	text:SetText(label)

	local btn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	btn:SetSize(180, 20)
	btn:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
	text:SetPoint("RIGHT", btn, "LEFT", -12, 0)

	local swatch = btn:CreateTexture(nil, "ARTWORK")
	swatch:SetAllPoints(true)
	local c = ns.GetBarColor(colorKey)
	if c then
		swatch:SetColorTexture(c.r, c.g, c.b, c.a)
	end
	btn.swatch = swatch
	btn.colorKey = colorKey

	local border = btn:CreateTexture(nil, "OVERLAY")
	border:SetColorTexture(0.4, 0.4, 0.4, 1)
	border:SetPoint("TOPLEFT", -1, 1)
	border:SetPoint("BOTTOMRIGHT", 1, -1)
	border:SetDrawLayer("OVERLAY", -1)

	btn:SetScript("OnClick", function()
		OpenColorPicker(colorKey, swatch)
	end)
	AddControlTooltip(row, label, string.format("Click the swatch button to change the %s color.", label))

	row:SetScript("OnMouseUp", function(_, button)
		if button == "LeftButton" then
			OpenColorPicker(colorKey, swatch)
		end
	end)

	row.button = btn
	row.swatch = swatch
	return row
end

local function CreateTexturePathRow(parent, label, yOffset, getTexture, applyTexture)
	local row = CreateFrame("Frame", nil, parent)
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
	row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -20, yOffset)
	row:SetHeight(52)
	row:EnableMouse(true)
	row.hover = AddRowHoverHighlight(row)

	local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	text:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
	text:SetText(label)

	local function Refresh()
		local path = getTexture()
		row.currentTexture = path
		if row.preview then
			row.preview:SetTexture(path)
		end
		if row.dropdown and UIDropDownMenu_SetText then
			UIDropDownMenu_SetText(row.dropdown, GetTextureSummaryText(path))
		end
	end

	local preview = row:CreateTexture(nil, "ARTWORK")
	preview:SetSize(18, 18)
	preview:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -282, 0)
	preview:SetTexture(getTexture())
	row.preview = preview
	text:SetPoint("RIGHT", preview, "LEFT", -8, 0)

	local dropdown = CreateFrame("Frame", nil, row, "UIDropDownMenuTemplate")
	dropdown:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, -1)
	if UIDropDownMenu_SetWidth then
		UIDropDownMenu_SetWidth(dropdown, 260)
	end
	row.dropdown = dropdown
	row:SetScript("OnMouseUp", function(_, mouseButton)
		if mouseButton == "LeftButton" and ToggleDropDownMenu then
			ToggleDropDownMenu(1, nil, dropdown, dropdown, 0, 0)
		end
	end)
	AddControlTooltip(row, label, string.format("Choose the texture used for %s from the dropdown preview list.", label))

	if UIDropDownMenu_Initialize and UIDropDownMenu_AddButton and UIDropDownMenu_CreateInfo then
		UIDropDownMenu_Initialize(dropdown, function(_, level)
			local library = ns.TEXTURE_LIBRARY or ns.BuildTextureLibrary() or {}
			for _, entry in ipairs(library) do
				local info = UIDropDownMenu_CreateInfo()
				info.text = string.format("[%s / %s] %s", entry.category or "Unknown", entry.style or "style", entry.label or entry.path)
				info.value = entry.path
				info.checked = entry.path == row.currentTexture
				info.func = function()
					applyTexture(entry.path)
					Refresh()
					if ns.RefreshTextureRows then
						ns.RefreshTextureRows()
					end
				end
				UIDropDownMenu_AddButton(info, level)
			end
		end)
	end

	row.refresh = Refresh
	Refresh()
	return row
end

local function CreateCycleRow(parent, label, yOffset, options, getValue, applyValue)
	local row = CreateFrame("Frame", nil, parent)
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
	row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -20, yOffset)
	row:SetHeight(52)
	row:EnableMouse(true)
	row.hover = AddRowHoverHighlight(row)

	local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	text:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
	text:SetText(label)

	local dropdown = CreateFrame("Frame", nil, row, "UIDropDownMenuTemplate")
	dropdown:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, -1)
	if UIDropDownMenu_SetWidth then
		UIDropDownMenu_SetWidth(dropdown, 180)
	end
	text:SetPoint("RIGHT", dropdown, "LEFT", -8, 0)

	local function Refresh()
		if UIDropDownMenu_SetText then
			UIDropDownMenu_SetText(dropdown, GetOptionLabel(options, getValue()))
		end
	end

	if UIDropDownMenu_Initialize and UIDropDownMenu_AddButton and UIDropDownMenu_CreateInfo then
		UIDropDownMenu_Initialize(dropdown, function(_, level)
			local currentValue = getValue()
			for _, option in ipairs(options) do
				local info = UIDropDownMenu_CreateInfo()
				info.text = option.label
				info.value = option.value
				info.checked = option.value == currentValue
				info.func = function()
					applyValue(option.value)
					Refresh()
				end
				UIDropDownMenu_AddButton(info, level)
			end
		end)
	end

	row.dropdown = dropdown
	row:SetScript("OnMouseUp", function(_, mouseButton)
		if mouseButton == "LeftButton" and ToggleDropDownMenu then
			ToggleDropDownMenu(1, nil, dropdown, dropdown, 0, 0)
		end
	end)
	AddControlTooltip(row, label, string.format("Choose the %s option from the dropdown. The full list shows the real WoW draw layers and modes.", label))
	row.refresh = Refresh
	Refresh()
	return row
end

local function CreateToggleRow(parent, label, yOffset, getValue, applyValue)
	local row = CreateFrame("Frame", nil, parent)
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
	row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -20, yOffset)
	row:SetHeight(40)
	row:EnableMouse(true)
	row.hover = AddRowHoverHighlight(row)

	local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	text:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
	text:SetText(label)

	local toggle = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
	toggle:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
	toggle:SetChecked(getValue())
	toggle:SetScript("OnClick", function(self)
		applyValue(self:GetChecked() == true)
	end)
	text:SetPoint("RIGHT", toggle, "LEFT", -8, 0)

	row:SetScript("OnMouseUp", function(_, mouseButton)
		if mouseButton == "LeftButton" then
			toggle:Click()
		end
	end)
	AddControlTooltip(row, label, string.format("Toggle %s on or off.", label))

	row.toggle = toggle
	row.refresh = function()
		toggle:SetChecked(getValue())
	end
	return row
end

local function CreateSectionHeader(parent, label, yOffset)
	local row = CreateFrame("Frame", nil, parent)
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
	row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -20, yOffset)
	row:SetHeight(18)

	local bg = row:CreateTexture(nil, "BACKGROUND")
	bg:SetColorTexture(0.08, 0.08, 0.08, 0.55)
	bg:SetPoint("TOPLEFT", row, "TOPLEFT", -4, 2)
	bg:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 4, -2)

	local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	text:SetPoint("LEFT", row, "LEFT", 0, 0)
	text:SetText(label)

	local line = row:CreateTexture(nil, "ARTWORK")
	line:SetColorTexture(0.35, 0.35, 0.35, 0.7)
	line:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, -2)
	line:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, -2)
	line:SetHeight(1)

	return row
end

local function CreateDescriptionText(parent, text, yOffset)
	local row = CreateFrame("Frame", nil, parent)
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
	row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -20, yOffset)
	row:SetHeight(42)

	local font = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	font:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
	font:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
	font:SetJustifyH("LEFT")
	font:SetJustifyV("TOP")
	font:SetWordWrap(true)
	font:SetText(text)

	row.text = font
	return row
end

local function CreateWeaveFamilyRow(parent, abbrev, label, yOffset)
	local row = CreateFrame("Frame", nil, parent)
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
	row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -20, yOffset)
	row:SetHeight(40)
	row:EnableMouse(true)
	row.hover = AddRowHoverHighlight(row)

	local color = ns.GetWeaveFamilyColor and ns.GetWeaveFamilyColor(abbrev) or nil
	local swatch = row:CreateTexture(nil, "ARTWORK")
	swatch:SetSize(12, 12)
	swatch:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
	if color then
		swatch:SetColorTexture(color.r, color.g, color.b, color.a or 1)
	else
		swatch:SetColorTexture(0.8, 0.8, 0.8, 1)
	end

	local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	text:SetPoint("TOPLEFT", swatch, "RIGHT", 8, 0)
	text:SetPoint("RIGHT", row, "RIGHT", -96, 0)
	text:SetJustifyH("LEFT")
	text:SetText(string.format("%s — %s", abbrev, label))

	local toggle = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
	toggle:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
	toggle:SetChecked(ns.GetWeaveFamilyEnabled and ns.GetWeaveFamilyEnabled(abbrev))
	toggle:SetScript("OnClick", function(self)
		ns.SetWeaveFamilyEnabled(abbrev, self:GetChecked() == true)
		if ns.RebuildWeaveSpellCatalog then
			ns.RebuildWeaveSpellCatalog()
		end
		if ns.ClearWeavePreview then
			ns.ClearWeavePreview()
		end
	end)

	row:SetScript("OnMouseUp", function(_, mouseButton)
		if mouseButton == "LeftButton" then
			toggle:Click()
		end
	end)
	AddControlTooltip(row, string.format("%s family", abbrev), string.format("Keep the %s family in the weave breakpoint helper.", label))

	row.toggle = toggle
	row.refresh = function()
		toggle:SetChecked(ns.GetWeaveFamilyEnabled and ns.GetWeaveFamilyEnabled(abbrev))
	end
	return row
end

-- ============================================================
-- Panel creation
-- ============================================================
local function CreatePanel()
	local f = CreateFrame("Frame", "SuperSwingTimerConfigPanel", UIParent, "BackdropTemplate")
	f:SetSize(780, 760)
	f:SetPoint("CENTER")
	f:SetBackdrop({
		bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 32,
		insets = { left = 8, right = 8, top = 8, bottom = 8 },
	})
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:SetScript("OnMouseDown", function(self, button)
		if button == "RightButton" then return end  -- suppress right-click menu
	end)
	f:SetClampedToScreen(true)
	f:SetFrameStrata("DIALOG")
	f:SetScript("OnHide", function() HideBarPreview() end)
	f:Hide()
	f.name = "Super Swing Timer"
	f.icon = "Interface\\Icons\\INV_Sword_27"

	local interfaceOptionsAddCategory = rawget(_G, "InterfaceOptions_AddCategory")
	if interfaceOptionsAddCategory then
		interfaceOptionsAddCategory(f)
	else
		local settings = rawget(_G, "Settings")
		if settings and settings.RegisterCanvasLayoutCategory and settings.RegisterAddOnCategory then
			local category = settings.RegisterCanvasLayoutCategory(f, f.name)
			settings.RegisterAddOnCategory(category)
			f.settingsCategory = category
		end
	end

	-- Title
	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOP", f, "TOP", 0, -16)
	title:SetText("Super Swing Timer")

	local subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	subtitle:SetPoint("TOP", title, "BOTTOM", 0, -2)
	subtitle:SetText("Hover rows for help, then use the right-side checkbox, dropdown, numeric field, or swatch button to change them.")

	-- Close button
	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)

	local scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -46)
	scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 54)

	local content = CreateFrame("Frame", nil, scrollFrame)
	content:SetSize(720, 3600)
	scrollFrame:SetScrollChild(content)
	f.scrollFrame = scrollFrame
	f.content = content

	-- Sliders / selectors
	CreateSectionHeader(content, "Bar Visibility", -10)

	local showMHRow = CreateToggleRow(
		content,
		"Show Main Hand",
		-50,
		function() return SuperSwingTimerDB.showMH ~= false end,
		function(enabled)
			SuperSwingTimerDB.showMH = enabled
			ns.ApplyVisibility()
		end
	)

	local showOHRow = CreateToggleRow(
		content,
		"Show Off Hand",
		-78,
		function() return SuperSwingTimerDB.showOH ~= false end,
		function(enabled)
			SuperSwingTimerDB.showOH = enabled
			ns.ApplyVisibility()
		end
	)

	local showRangedRow = CreateToggleRow(
		content,
		"Show Ranged",
		-106,
		function() return SuperSwingTimerDB.showRanged ~= false end,
		function(enabled)
			SuperSwingTimerDB.showRanged = enabled
			ns.ApplyVisibility()
		end
	)

	local showWeaveRow = CreateToggleRow(
		content,
		"Shaman Weave Assist",
		-134,
		function() return SuperSwingTimerDB.showWeaveAssist ~= false end,
		function(enabled)
			SuperSwingTimerDB.showWeaveAssist = enabled
			ns.ApplyVisibility()
		end
	)

	CreateSectionHeader(content, "MH/OH Bar Appearance", -174)

	if ns.playerClass ~= "SHAMAN" then
		showWeaveRow:Hide()
	end

	local widthSlider = CreateSlider(content, "Bar Width", 100, 400, 10, ShiftY(-50))
	widthSlider:SetValue(SuperSwingTimerDB.barWidth or ns.DB_DEFAULTS.barWidth)
	SyncSliderDisplay(widthSlider, widthSlider:GetValue())

	local heightSlider = CreateSlider(content, "Bar Height", 10, 40, 2, ShiftY(-100))
	heightSlider:SetValue(SuperSwingTimerDB.barHeight or ns.DB_DEFAULTS.barHeight)
	SyncSliderDisplay(heightSlider, heightSlider:GetValue())

	local barTextureRow = CreateTexturePathRow(
		content,
		"MH/OH Bar Texture",
		ShiftY(-145),
		function() return SuperSwingTimerDB.barTexture or ns.DB_DEFAULTS.barTexture end,
		function(texturePath) ns.ApplyBarTexture(texturePath, SuperSwingTimerDB.barTextureLayer or ns.DB_DEFAULTS.barTextureLayer) end
	)

	local barLayerRow = CreateCycleRow(
		content,
		"MH/OH Texture Layer",
		ShiftY(-180),
		ns.TEXTURE_LAYER_OPTIONS,
		function() return SuperSwingTimerDB.barTextureLayer or ns.DB_DEFAULTS.barTextureLayer end,
		function(layer) ns.ApplyBarTextureLayer(layer) end
	)

	local rangedTextureRow = CreateTexturePathRow(
		content,
		"Ranged Bar Texture",
		ShiftY(-200),
		function() return SuperSwingTimerDB.rangedBarTexture or ns.DB_DEFAULTS.rangedBarTexture end,
		function(texturePath) ns.ApplyRangedBarTexture(texturePath, SuperSwingTimerDB.barTextureLayer or ns.DB_DEFAULTS.barTextureLayer) end
	)

	local sparkTextureRow = CreateTexturePathRow(
		content,
		"MH/OH Spark Texture",
		ShiftY(-215),
		function() return SuperSwingTimerDB.sparkTexture or ns.DB_DEFAULTS.sparkTexture end,
		function(texturePath)
			ns.ApplySparkSettings(
				texturePath,
				SuperSwingTimerDB.sparkWidth or ns.DB_DEFAULTS.sparkWidth,
				SuperSwingTimerDB.sparkHeight or ns.DB_DEFAULTS.sparkHeight,
				SuperSwingTimerDB.sparkTextureLayer or ns.DB_DEFAULTS.sparkTextureLayer,
				SuperSwingTimerDB.sparkAlpha or ns.DB_DEFAULTS.sparkAlpha
			)
		end
	)

	local sparkLayerRow = CreateCycleRow(
		content,
		"MH/OH Spark Layer",
		ShiftY(-250),
		ns.TEXTURE_LAYER_OPTIONS,
		function() return SuperSwingTimerDB.sparkTextureLayer or ns.DB_DEFAULTS.sparkTextureLayer end,
		function(layer) ns.ApplySparkTextureLayer(layer) end
	)

	local sparkWidthSlider = CreateSlider(content, "Spark Width", 8, 60, 1, ShiftY(-315))
	sparkWidthSlider:SetValue(SuperSwingTimerDB.sparkWidth or ns.DB_DEFAULTS.sparkWidth)
	SyncSliderDisplay(sparkWidthSlider, sparkWidthSlider:GetValue())

	local sparkHeightSlider = CreateSlider(content, "Spark Height", 12, 90, 1, ShiftY(-365))
	sparkHeightSlider:SetValue(SuperSwingTimerDB.sparkHeight or ns.DB_DEFAULTS.sparkHeight)
	SyncSliderDisplay(sparkHeightSlider, sparkHeightSlider:GetValue())

	local backgroundAlphaSlider = CreateSlider(content, "Bar Background Alpha", 0, 1, 0.05, ShiftY(-415))
	backgroundAlphaSlider:SetValue(SuperSwingTimerDB.barBackgroundAlpha or ns.DB_DEFAULTS.barBackgroundAlpha)
	SyncSliderDisplay(backgroundAlphaSlider, backgroundAlphaSlider:GetValue())

	local sparkAlphaSlider = CreateSlider(content, "Spark Alpha", 0, 1, 0.05, ShiftY(-465))
	sparkAlphaSlider:SetValue(SuperSwingTimerDB.sparkAlpha or ns.DB_DEFAULTS.sparkAlpha)
	SyncSliderDisplay(sparkAlphaSlider, sparkAlphaSlider:GetValue())

	local indicatorBlendModeRow = CreateCycleRow(
		content,
		"Indicator Glow Mode",
		ShiftY(-495),
		INDICATOR_BLEND_OPTIONS,
		function() return SuperSwingTimerDB.indicatorBlendMode or ns.DB_DEFAULTS.indicatorBlendMode end,
		function(blendMode)
			ns.ApplyIndicatorBlendMode(blendMode)
		end
	)

	CreateSectionHeader(content, "Shaman Weave Assist", -534)

	local weaveSparkTextureRow = CreateTexturePathRow(
		content,
		"Cast Breakpoint Spark Texture",
		ShiftY(-545),
		function() return SuperSwingTimerDB.weaveSparkTexture or ns.DB_DEFAULTS.weaveSparkTexture end,
		function(texturePath)
			ns.ApplyWeaveSparkSettings(
				texturePath,
				SuperSwingTimerDB.weaveSparkWidth or ns.DB_DEFAULTS.weaveSparkWidth,
				SuperSwingTimerDB.weaveSparkHeight or ns.DB_DEFAULTS.weaveSparkHeight,
				SuperSwingTimerDB.weaveSparkTextureLayer or ns.DB_DEFAULTS.weaveSparkTextureLayer,
				SuperSwingTimerDB.weaveSparkAlpha or ns.DB_DEFAULTS.weaveSparkAlpha
			)
		end
	)

	local weaveSparkLayerRow = CreateCycleRow(
		content,
		"Cast Breakpoint Layer",
		ShiftY(-580),
		ns.TEXTURE_LAYER_OPTIONS,
		function() return SuperSwingTimerDB.weaveSparkTextureLayer or ns.DB_DEFAULTS.weaveSparkTextureLayer end,
		function(layer) ns.ApplyWeaveSparkTextureLayer(layer) end
	)

	local weaveSparkWidthSlider = CreateSlider(content, "Cast Spark Width", 6, 60, 1, ShiftY(-615))
	weaveSparkWidthSlider:SetValue(SuperSwingTimerDB.weaveSparkWidth or ns.DB_DEFAULTS.weaveSparkWidth)
	SyncSliderDisplay(weaveSparkWidthSlider, weaveSparkWidthSlider:GetValue())

	local weaveSparkHeightSlider = CreateSlider(content, "Cast Spark Height", 8, 100, 1, ShiftY(-665))
	weaveSparkHeightSlider:SetValue(SuperSwingTimerDB.weaveSparkHeight or ns.DB_DEFAULTS.weaveSparkHeight)
	SyncSliderDisplay(weaveSparkHeightSlider, weaveSparkHeightSlider:GetValue())

	local weaveSparkAlphaSlider = CreateSlider(content, "Cast Spark Alpha", 0, 1, 0.05, ShiftY(-715))
	weaveSparkAlphaSlider:SetValue(SuperSwingTimerDB.weaveSparkAlpha or ns.DB_DEFAULTS.weaveSparkAlpha)
	SyncSliderDisplay(weaveSparkAlphaSlider, weaveSparkAlphaSlider:GetValue())

	local weaveTriangleTopRow = CreateTexturePathRow(
		content,
		"Upper Marker Texture",
		ShiftY(-765),
		function() return SuperSwingTimerDB.weaveTriangleTopTexture or ns.DB_DEFAULTS.weaveTriangleTopTexture end,
		function(texturePath)
			ns.ApplyWeaveTriangleSettings(
				texturePath,
				SuperSwingTimerDB.weaveTriangleBottomTexture or ns.DB_DEFAULTS.weaveTriangleBottomTexture,
				SuperSwingTimerDB.weaveTriangleSize or ns.DB_DEFAULTS.weaveTriangleSize,
				SuperSwingTimerDB.weaveTriangleGap or ns.DB_DEFAULTS.weaveTriangleGap,
				SuperSwingTimerDB.weaveTriangleTextureLayer or ns.DB_DEFAULTS.weaveTriangleTextureLayer,
				SuperSwingTimerDB.weaveTriangleAlpha or ns.DB_DEFAULTS.weaveTriangleAlpha
			)
		end
	)

	local weaveTriangleBottomRow = CreateTexturePathRow(
		content,
		"Lower Marker Texture",
		ShiftY(-800),
		function() return SuperSwingTimerDB.weaveTriangleBottomTexture or ns.DB_DEFAULTS.weaveTriangleBottomTexture end,
		function(texturePath)
			ns.ApplyWeaveTriangleSettings(
				SuperSwingTimerDB.weaveTriangleTopTexture or ns.DB_DEFAULTS.weaveTriangleTopTexture,
				texturePath,
				SuperSwingTimerDB.weaveTriangleSize or ns.DB_DEFAULTS.weaveTriangleSize,
				SuperSwingTimerDB.weaveTriangleGap or ns.DB_DEFAULTS.weaveTriangleGap,
				SuperSwingTimerDB.weaveTriangleTextureLayer or ns.DB_DEFAULTS.weaveTriangleTextureLayer,
				SuperSwingTimerDB.weaveTriangleAlpha or ns.DB_DEFAULTS.weaveTriangleAlpha
			)
		end
	)

	local weaveTriangleLayerRow = CreateCycleRow(
		content,
		"Marker Layer",
		ShiftY(-835),
		ns.TEXTURE_LAYER_OPTIONS,
		function() return SuperSwingTimerDB.weaveTriangleTextureLayer or ns.DB_DEFAULTS.weaveTriangleTextureLayer end,
		function(layer)
			ns.ApplyWeaveTriangleSettings(
				SuperSwingTimerDB.weaveTriangleTopTexture or ns.DB_DEFAULTS.weaveTriangleTopTexture,
				SuperSwingTimerDB.weaveTriangleBottomTexture or ns.DB_DEFAULTS.weaveTriangleBottomTexture,
				SuperSwingTimerDB.weaveTriangleSize or ns.DB_DEFAULTS.weaveTriangleSize,
				SuperSwingTimerDB.weaveTriangleGap or ns.DB_DEFAULTS.weaveTriangleGap,
				layer,
				SuperSwingTimerDB.weaveTriangleAlpha or ns.DB_DEFAULTS.weaveTriangleAlpha
			)
		end
	)

	local weaveTriangleSizeSlider = CreateSlider(content, "Marker Size", 6, 24, 1, ShiftY(-870))
	weaveTriangleSizeSlider:SetValue(SuperSwingTimerDB.weaveTriangleSize or ns.DB_DEFAULTS.weaveTriangleSize)
	SyncSliderDisplay(weaveTriangleSizeSlider, weaveTriangleSizeSlider:GetValue())

	local weaveTriangleGapSlider = CreateSlider(content, "Marker Gap", 0, 6, 1, ShiftY(-920))
	weaveTriangleGapSlider:SetValue(SuperSwingTimerDB.weaveTriangleGap or ns.DB_DEFAULTS.weaveTriangleGap)
	SyncSliderDisplay(weaveTriangleGapSlider, weaveTriangleGapSlider:GetValue())

	local weaveTriangleAlphaSlider = CreateSlider(content, "Marker Alpha", 0, 1, 0.05, ShiftY(-970))
	weaveTriangleAlphaSlider:SetValue(SuperSwingTimerDB.weaveTriangleAlpha or ns.DB_DEFAULTS.weaveTriangleAlpha)
	SyncSliderDisplay(weaveTriangleAlphaSlider, weaveTriangleAlphaSlider:GetValue())

	CreateSectionHeader(content, "General Behavior", -1130)

	local minimalModeRow = CreateToggleRow(
		content,
		"Minimal Mode",
		ShiftY(-1145),
		function() return SuperSwingTimerDB.minimalMode == true end,
		function(enabled) ns.ApplyMinimalMode(enabled) end
	)

	local lockBarsRow = CreateToggleRow(
		content,
		"Lock Bars",
		ShiftY(-1175),
		function() return SuperSwingTimerDB.lockBars == true end,
		function(enabled) SuperSwingTimerDB.lockBars = enabled end
	)

	widthSlider:SetScript("OnValueChanged", function(self, value)
		value = math.floor(value + 0.5)
		SyncSliderDisplay(self, value)
		ns.ApplyBarSize(value, heightSlider:GetValue())
	end)

	heightSlider:SetScript("OnValueChanged", function(self, value)
		value = math.floor(value + 0.5)
		SyncSliderDisplay(self, value)
		ns.ApplyBarSize(widthSlider:GetValue(), value)
	end)

	sparkWidthSlider:SetScript("OnValueChanged", function(self, value)
		value = math.floor(value + 0.5)
		SyncSliderDisplay(self, value)
		ns.ApplySparkSettings(
			SuperSwingTimerDB.sparkTexture or ns.DB_DEFAULTS.sparkTexture,
			value,
			sparkHeightSlider:GetValue(),
			SuperSwingTimerDB.sparkTextureLayer or ns.DB_DEFAULTS.sparkTextureLayer,
			SuperSwingTimerDB.sparkAlpha or ns.DB_DEFAULTS.sparkAlpha
		)
	end)

	sparkHeightSlider:SetScript("OnValueChanged", function(self, value)
		value = math.floor(value + 0.5)
		SyncSliderDisplay(self, value)
		ns.ApplySparkSettings(
			SuperSwingTimerDB.sparkTexture or ns.DB_DEFAULTS.sparkTexture,
			sparkWidthSlider:GetValue(),
			value,
			SuperSwingTimerDB.sparkTextureLayer or ns.DB_DEFAULTS.sparkTextureLayer,
			SuperSwingTimerDB.sparkAlpha or ns.DB_DEFAULTS.sparkAlpha
		)
	end)

	backgroundAlphaSlider:SetScript("OnValueChanged", function(self, value)
		value = math.floor((value + 0.0001) * 100) / 100
		SyncSliderDisplay(self, value)
		ns.ApplyBarBackgroundAlpha(value)
	end)

	sparkAlphaSlider:SetScript("OnValueChanged", function(self, value)
		value = math.floor((value + 0.0001) * 100) / 100
		SyncSliderDisplay(self, value)
		ns.ApplySparkAlpha(value)
	end)

	weaveSparkWidthSlider:SetScript("OnValueChanged", function(self, value)
		value = math.floor(value + 0.5)
		SyncSliderDisplay(self, value)
		ns.ApplyWeaveSparkSettings(
			SuperSwingTimerDB.weaveSparkTexture or ns.DB_DEFAULTS.weaveSparkTexture,
			value,
			weaveSparkHeightSlider:GetValue(),
			SuperSwingTimerDB.weaveSparkTextureLayer or ns.DB_DEFAULTS.weaveSparkTextureLayer,
			SuperSwingTimerDB.weaveSparkAlpha or ns.DB_DEFAULTS.weaveSparkAlpha
		)
	end)

	weaveSparkHeightSlider:SetScript("OnValueChanged", function(self, value)
		value = math.floor(value + 0.5)
		SyncSliderDisplay(self, value)
		ns.ApplyWeaveSparkSettings(
			SuperSwingTimerDB.weaveSparkTexture or ns.DB_DEFAULTS.weaveSparkTexture,
			weaveSparkWidthSlider:GetValue(),
			value,
			SuperSwingTimerDB.weaveSparkTextureLayer or ns.DB_DEFAULTS.weaveSparkTextureLayer,
			SuperSwingTimerDB.weaveSparkAlpha or ns.DB_DEFAULTS.weaveSparkAlpha
		)
	end)

	weaveSparkAlphaSlider:SetScript("OnValueChanged", function(self, value)
		value = math.floor((value + 0.0001) * 100) / 100
		SyncSliderDisplay(self, value)
		ns.ApplyWeaveSparkAlpha(value)
	end)

	weaveTriangleSizeSlider:SetScript("OnValueChanged", function(self, value)
		value = math.floor(value + 0.5)
		SyncSliderDisplay(self, value)
		ns.ApplyWeaveTriangleSettings(
			SuperSwingTimerDB.weaveTriangleTopTexture or ns.DB_DEFAULTS.weaveTriangleTopTexture,
			SuperSwingTimerDB.weaveTriangleBottomTexture or ns.DB_DEFAULTS.weaveTriangleBottomTexture,
			value,
			weaveTriangleGapSlider:GetValue(),
			SuperSwingTimerDB.weaveTriangleTextureLayer or ns.DB_DEFAULTS.weaveTriangleTextureLayer,
			SuperSwingTimerDB.weaveTriangleAlpha or ns.DB_DEFAULTS.weaveTriangleAlpha
		)
	end)

	weaveTriangleGapSlider:SetScript("OnValueChanged", function(self, value)
		value = math.floor(value + 0.5)
		SyncSliderDisplay(self, value)
		ns.ApplyWeaveTriangleSettings(
			SuperSwingTimerDB.weaveTriangleTopTexture or ns.DB_DEFAULTS.weaveTriangleTopTexture,
			SuperSwingTimerDB.weaveTriangleBottomTexture or ns.DB_DEFAULTS.weaveTriangleBottomTexture,
			weaveTriangleSizeSlider:GetValue(),
			value,
			SuperSwingTimerDB.weaveTriangleTextureLayer or ns.DB_DEFAULTS.weaveTriangleTextureLayer,
			SuperSwingTimerDB.weaveTriangleAlpha or ns.DB_DEFAULTS.weaveTriangleAlpha
		)
	end)

	weaveTriangleAlphaSlider:SetScript("OnValueChanged", function(self, value)
		value = math.floor((value + 0.0001) * 100) / 100
		SyncSliderDisplay(self, value)
		ns.ApplyWeaveTriangleSettings(
			SuperSwingTimerDB.weaveTriangleTopTexture or ns.DB_DEFAULTS.weaveTriangleTopTexture,
			SuperSwingTimerDB.weaveTriangleBottomTexture or ns.DB_DEFAULTS.weaveTriangleBottomTexture,
			weaveTriangleSizeSlider:GetValue(),
			weaveTriangleGapSlider:GetValue(),
			SuperSwingTimerDB.weaveTriangleTextureLayer or ns.DB_DEFAULTS.weaveTriangleTextureLayer,
			value
		)
	end)

	-- Color buttons
	CreateSectionHeader(content, "Bar Colors", -1210)

	local useClassColorsRow = CreateToggleRow(
		content,
		"Use Class Colors",
		ShiftY(-1238),
		function() return SuperSwingTimerDB.useClassColors ~= false end,
		function(enabled)
			SuperSwingTimerDB.useClassColors = enabled
			if enabled then
				ns.SeedLegacyBarColorsFromClass()
			end
			ns.ApplyBarColors()
			if f.useClassColorsRow and f.useClassColorsRow.refresh then
				f.useClassColorsRow.refresh()
			end
			if f.colorRows then
				for _, colorRow in ipairs(f.colorRows) do
					local key = colorRow.button.colorKey
					local effective = ns.GetBarColor(key)
					if effective then
						colorRow.swatch:SetColorTexture(effective.r, effective.g, effective.b, effective.a)
					end
				end
			end
		end
	)

	local yStart = ShiftY(-1270)
	local spacing = -28

	local mhRow     = CreateColorButton(content, "Main Hand Color",  "mh",     yStart)
	local ohRow     = CreateColorButton(content, "Off Hand Color",   "oh",     yStart + spacing)
	local rangedRow = CreateColorButton(content, "Ranged Color",     "ranged", yStart + spacing * 2)
	local sealRow   = CreateColorButton(content, "Seal Breakpoint Line", "sealTwist", yStart + spacing * 3)

	-- Seal-twist row only visible for Paladins
	if ns.playerClass ~= "PALADIN" then
		sealRow:Hide()
	end

	local weaveFamiliesHeader = CreateSectionHeader(content, "Weave Families", -1520)
	local weaveFamiliesDescription = CreateDescriptionText(
		content,
		"Each family below is color-coded to match its spell breakpoint family. Toggle a family off to remove every rank in that family from the weave helper. The tiny upper and lower markers stay attached to the MH swing bar and move with spell haste.",
		-1548
	)

	local weaveFamilyRows = {
		CreateWeaveFamilyRow(content, "LB",  "Lightning Bolt",        -1590),
		CreateWeaveFamilyRow(content, "CL",  "Chain Lightning",       -1618),
		CreateWeaveFamilyRow(content, "HW",  "Healing Wave",          -1646),
		CreateWeaveFamilyRow(content, "LHW", "Lesser Healing Wave",   -1674),
		CreateWeaveFamilyRow(content, "CH",  "Chain Heal",            -1702),
	}

	if ns.playerClass ~= "SHAMAN" then
		weaveFamiliesHeader:Hide()
		weaveFamiliesDescription:Hide()
		for _, row in ipairs(weaveFamilyRows) do
			row:Hide()
		end
	end

	-- Reset button
	local resetBtn = CreateFrame("Button", nil, f)
	resetBtn:SetSize(120, 24)
	resetBtn:SetPoint("BOTTOM", f, "BOTTOM", 0, 16)

	local resetBg = resetBtn:CreateTexture(nil, "BACKGROUND")
	resetBg:SetAllPoints(true)
	resetBg:SetColorTexture(0.2, 0.2, 0.2, 0.8)

	local resetBorder = resetBtn:CreateTexture(nil, "OVERLAY")
	resetBorder:SetColorTexture(0.5, 0.5, 0.5, 1)
	resetBorder:SetPoint("TOPLEFT", -1, 1)
	resetBorder:SetPoint("BOTTOMRIGHT", 1, -1)
	resetBorder:SetDrawLayer("OVERLAY", -1)

	local resetText = resetBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	resetText:SetPoint("CENTER")
	resetText:SetText("Reset Defaults")

	resetBtn:SetScript("OnEnter", function(self)
		resetBg:SetColorTexture(0.3, 0.3, 0.3, 0.9)
	end)
	resetBtn:SetScript("OnLeave", function(self)
		resetBg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
	end)
	resetBtn:SetScript("OnClick", function()
		ns.ResetConfigDefaults()
		-- Update slider positions
		widthSlider:SetValue(ns.DB_DEFAULTS.barWidth)
		heightSlider:SetValue(ns.DB_DEFAULTS.barHeight)
		backgroundAlphaSlider:SetValue(ns.DB_DEFAULTS.barBackgroundAlpha)
		sparkAlphaSlider:SetValue(ns.DB_DEFAULTS.sparkAlpha)
		sparkWidthSlider:SetValue(ns.DB_DEFAULTS.sparkWidth)
		sparkHeightSlider:SetValue(ns.DB_DEFAULTS.sparkHeight)
		weaveSparkWidthSlider:SetValue(ns.DB_DEFAULTS.weaveSparkWidth)
		weaveSparkHeightSlider:SetValue(ns.DB_DEFAULTS.weaveSparkHeight)
		weaveSparkAlphaSlider:SetValue(ns.DB_DEFAULTS.weaveSparkAlpha)
		weaveTriangleSizeSlider:SetValue(ns.DB_DEFAULTS.weaveTriangleSize)
		weaveTriangleGapSlider:SetValue(ns.DB_DEFAULTS.weaveTriangleGap)
		weaveTriangleAlphaSlider:SetValue(ns.DB_DEFAULTS.weaveTriangleAlpha)
		if indicatorBlendModeRow and indicatorBlendModeRow.refresh then
			indicatorBlendModeRow.refresh()
		end
		if useClassColorsRow and useClassColorsRow.refresh then
			useClassColorsRow.refresh()
		end
		if barTextureRow and barTextureRow.refresh then
			barTextureRow.refresh()
		end
		if barLayerRow and barLayerRow.refresh then
			barLayerRow.refresh()
		end
		if sparkTextureRow and sparkTextureRow.refresh then
			sparkTextureRow.refresh()
		end
		if sparkLayerRow and sparkLayerRow.refresh then
			sparkLayerRow.refresh()
		end
		if weaveSparkTextureRow and weaveSparkTextureRow.refresh then
			weaveSparkTextureRow.refresh()
		end
		if weaveSparkLayerRow and weaveSparkLayerRow.refresh then
			weaveSparkLayerRow.refresh()
		end
		if weaveTriangleTopRow and weaveTriangleTopRow.refresh then
			weaveTriangleTopRow.refresh()
		end
		if weaveTriangleBottomRow and weaveTriangleBottomRow.refresh then
			weaveTriangleBottomRow.refresh()
		end
		if weaveTriangleLayerRow and weaveTriangleLayerRow.refresh then
			weaveTriangleLayerRow.refresh()
		end
		if minimalModeRow and minimalModeRow.refresh then
			minimalModeRow.refresh()
		end
		if lockBarsRow and lockBarsRow.refresh then
			lockBarsRow.refresh()
		end
		if showMHRow and showMHRow.refresh then
			showMHRow.refresh()
		end
		if showOHRow and showOHRow.refresh then
			showOHRow.refresh()
		end
		if showRangedRow and showRangedRow.refresh then
			showRangedRow.refresh()
		end
		if showWeaveRow and showWeaveRow.refresh then
			showWeaveRow.refresh()
		end
		-- Update color swatches
		for _, row in ipairs({ mhRow, ohRow, rangedRow, sealRow }) do
			local key = row.button.colorKey
			local c = ns.GetBarColor(key)
			if c then
				row.swatch:SetColorTexture(c.r, c.g, c.b, c.a)
			end
		end
	end)

	f.widthSlider = widthSlider
	f.heightSlider = heightSlider
	f.barTextureRow = barTextureRow
	f.barLayerRow = barLayerRow
	f.rangedTextureRow = rangedTextureRow
	f.sparkTextureRow = sparkTextureRow
	f.sparkLayerRow = sparkLayerRow
	f.weaveSparkTextureRow = weaveSparkTextureRow
	f.weaveSparkLayerRow = weaveSparkLayerRow
	f.weaveSparkWidthSlider = weaveSparkWidthSlider
	f.weaveSparkHeightSlider = weaveSparkHeightSlider
	f.weaveSparkAlphaSlider = weaveSparkAlphaSlider
	f.weaveTriangleTopRow = weaveTriangleTopRow
	f.weaveTriangleBottomRow = weaveTriangleBottomRow
	f.weaveTriangleLayerRow = weaveTriangleLayerRow
	f.weaveTriangleSizeSlider = weaveTriangleSizeSlider
	f.weaveTriangleGapSlider = weaveTriangleGapSlider
	f.weaveTriangleAlphaSlider = weaveTriangleAlphaSlider
	f.textureRows = {
		barTextureRow,
		rangedTextureRow,
		sparkTextureRow,
		weaveSparkTextureRow,
		weaveTriangleTopRow,
		weaveTriangleBottomRow,
	}
	f.sparkWidthSlider = sparkWidthSlider
	f.sparkHeightSlider = sparkHeightSlider
	f.backgroundAlphaSlider = backgroundAlphaSlider
	f.sparkAlphaSlider = sparkAlphaSlider
	f.indicatorBlendModeRow = indicatorBlendModeRow
	f.minimalModeRow = minimalModeRow
	f.lockBarsRow = lockBarsRow
	f.showMHRow = showMHRow
	f.showOHRow = showOHRow
	f.showRangedRow = showRangedRow
	f.showWeaveRow = showWeaveRow
	f.useClassColorsRow = useClassColorsRow
	f.weaveFamilyRows = weaveFamilyRows
	f.colorRows = { mhRow, ohRow, rangedRow, sealRow }
	return f
end

function ns.RefreshTextureRows()
	if not panel or not panel.textureRows then
		return
	end

	for _, textureRow in ipairs(panel.textureRows) do
		if textureRow and textureRow.refresh then
			textureRow.refresh()
		end
	end
end

-- ============================================================
-- Public API
-- ============================================================
function ns.InitConfig()
	panel = CreatePanel()
end

function ns.ToggleConfig()
	if not panel then return end
	if panel:IsShown() then
		panel:Hide()
	else
		-- Refresh slider values from DB before showing
		panel.widthSlider:SetValue(SuperSwingTimerDB.barWidth or ns.DB_DEFAULTS.barWidth)
		panel.heightSlider:SetValue(SuperSwingTimerDB.barHeight or ns.DB_DEFAULTS.barHeight)
		if panel.barTextureRow and panel.barTextureRow.refresh then
			panel.barTextureRow.refresh()
		end
		if panel.barLayerRow and panel.barLayerRow.refresh then
			panel.barLayerRow.refresh()
		end
		if panel.rangedTextureRow and panel.rangedTextureRow.refresh then
			panel.rangedTextureRow.refresh()
		end
		if panel.sparkTextureRow and panel.sparkTextureRow.refresh then
			panel.sparkTextureRow.refresh()
		end
		if panel.sparkLayerRow and panel.sparkLayerRow.refresh then
			panel.sparkLayerRow.refresh()
		end
		if panel.weaveSparkTextureRow and panel.weaveSparkTextureRow.refresh then
			panel.weaveSparkTextureRow.refresh()
		end
		if panel.weaveSparkLayerRow and panel.weaveSparkLayerRow.refresh then
			panel.weaveSparkLayerRow.refresh()
		end
		if panel.weaveTriangleTopRow and panel.weaveTriangleTopRow.refresh then
			panel.weaveTriangleTopRow.refresh()
		end
		if panel.weaveTriangleBottomRow and panel.weaveTriangleBottomRow.refresh then
			panel.weaveTriangleBottomRow.refresh()
		end
		if panel.weaveTriangleLayerRow and panel.weaveTriangleLayerRow.refresh then
			panel.weaveTriangleLayerRow.refresh()
		end
		if panel.indicatorBlendModeRow and panel.indicatorBlendModeRow.refresh then
			panel.indicatorBlendModeRow.refresh()
		end
		if panel.weaveFamilyRows then
			for _, row in ipairs(panel.weaveFamilyRows) do
				if row.refresh then
					row.refresh()
				end
			end
		end
		panel.sparkWidthSlider:SetValue(SuperSwingTimerDB.sparkWidth or ns.DB_DEFAULTS.sparkWidth)
		panel.sparkHeightSlider:SetValue(SuperSwingTimerDB.sparkHeight or ns.DB_DEFAULTS.sparkHeight)
		panel.backgroundAlphaSlider:SetValue(SuperSwingTimerDB.barBackgroundAlpha or ns.DB_DEFAULTS.barBackgroundAlpha)
		panel.sparkAlphaSlider:SetValue(SuperSwingTimerDB.sparkAlpha or ns.DB_DEFAULTS.sparkAlpha)
		panel.weaveSparkWidthSlider:SetValue(SuperSwingTimerDB.weaveSparkWidth or ns.DB_DEFAULTS.weaveSparkWidth)
		panel.weaveSparkHeightSlider:SetValue(SuperSwingTimerDB.weaveSparkHeight or ns.DB_DEFAULTS.weaveSparkHeight)
		panel.weaveSparkAlphaSlider:SetValue(SuperSwingTimerDB.weaveSparkAlpha or ns.DB_DEFAULTS.weaveSparkAlpha)
		panel.weaveTriangleSizeSlider:SetValue(SuperSwingTimerDB.weaveTriangleSize or ns.DB_DEFAULTS.weaveTriangleSize)
		panel.weaveTriangleGapSlider:SetValue(SuperSwingTimerDB.weaveTriangleGap or ns.DB_DEFAULTS.weaveTriangleGap)
		panel.weaveTriangleAlphaSlider:SetValue(SuperSwingTimerDB.weaveTriangleAlpha or ns.DB_DEFAULTS.weaveTriangleAlpha)
		if panel.minimalModeRow and panel.minimalModeRow.refresh then
			panel.minimalModeRow.refresh()
		end
		if panel.lockBarsRow and panel.lockBarsRow.refresh then
			panel.lockBarsRow.refresh()
		end
		if panel.useClassColorsRow and panel.useClassColorsRow.refresh then
			panel.useClassColorsRow.refresh()
		end
		if panel.showMHRow and panel.showMHRow.refresh then
			panel.showMHRow.refresh()
		end
		if panel.showOHRow and panel.showOHRow.refresh then
			panel.showOHRow.refresh()
		end
		if panel.showRangedRow and panel.showRangedRow.refresh then
			panel.showRangedRow.refresh()
		end
		if panel.showWeaveRow and panel.showWeaveRow.refresh then
			panel.showWeaveRow.refresh()
		end
		if panel.weaveFamilyRows then
			for _, row in ipairs(panel.weaveFamilyRows) do
				if row.refresh then
					row.refresh()
				end
			end
		end
		for _, row in ipairs(panel.colorRows) do
			local key = row.button.colorKey
			local c = ns.GetBarColor(key)
			if c then
				row.swatch:SetColorTexture(c.r, c.g, c.b, c.a)
			end
		end
		if panel.scrollFrame then
			panel.scrollFrame:SetVerticalScroll(0)
		end
		panel:Show()
		ShowBarPreview()
	end
end

function ns.ResetConfigDefaults()
	SuperSwingTimerDB.barWidth  = ns.DB_DEFAULTS.barWidth
	SuperSwingTimerDB.barHeight = ns.DB_DEFAULTS.barHeight
	SuperSwingTimerDB.barTexture = ns.DB_DEFAULTS.barTexture
	SuperSwingTimerDB.barTextureLayer = ns.DB_DEFAULTS.barTextureLayer
	SuperSwingTimerDB.rangedBarTexture = ns.DB_DEFAULTS.rangedBarTexture
	SuperSwingTimerDB.sparkTexture = ns.DB_DEFAULTS.sparkTexture
	SuperSwingTimerDB.sparkTextureLayer = ns.DB_DEFAULTS.sparkTextureLayer
	SuperSwingTimerDB.weaveSparkTexture = ns.DB_DEFAULTS.weaveSparkTexture
	SuperSwingTimerDB.weaveSparkTextureLayer = ns.DB_DEFAULTS.weaveSparkTextureLayer
	SuperSwingTimerDB.weaveSparkWidth = ns.DB_DEFAULTS.weaveSparkWidth
	SuperSwingTimerDB.weaveSparkHeight = ns.DB_DEFAULTS.weaveSparkHeight
	SuperSwingTimerDB.weaveSparkAlpha = ns.DB_DEFAULTS.weaveSparkAlpha
	SuperSwingTimerDB.weaveTriangleTopTexture = ns.DB_DEFAULTS.weaveTriangleTopTexture
	SuperSwingTimerDB.weaveTriangleBottomTexture = ns.DB_DEFAULTS.weaveTriangleBottomTexture
	SuperSwingTimerDB.weaveTriangleTextureLayer = ns.DB_DEFAULTS.weaveTriangleTextureLayer
	SuperSwingTimerDB.weaveTriangleSize = ns.DB_DEFAULTS.weaveTriangleSize
	SuperSwingTimerDB.weaveTriangleGap = ns.DB_DEFAULTS.weaveTriangleGap
	SuperSwingTimerDB.weaveTriangleAlpha = ns.DB_DEFAULTS.weaveTriangleAlpha
	SuperSwingTimerDB.weaveMarkerLayer = ns.DB_DEFAULTS.weaveMarkerLayer
	SuperSwingTimerDB.sparkWidth = ns.DB_DEFAULTS.sparkWidth
	SuperSwingTimerDB.sparkHeight = ns.DB_DEFAULTS.sparkHeight
	SuperSwingTimerDB.barBackgroundAlpha = ns.DB_DEFAULTS.barBackgroundAlpha
	SuperSwingTimerDB.sparkAlpha = ns.DB_DEFAULTS.sparkAlpha
	SuperSwingTimerDB.minimalMode = ns.DB_DEFAULTS.minimalMode
	SuperSwingTimerDB.lockBars = ns.DB_DEFAULTS.lockBars
	SuperSwingTimerDB.showMH = ns.DB_DEFAULTS.showMH
	SuperSwingTimerDB.showOH = ns.DB_DEFAULTS.showOH
	SuperSwingTimerDB.showRanged = ns.DB_DEFAULTS.showRanged
	SuperSwingTimerDB.showWeaveAssist = ns.DB_DEFAULTS.showWeaveAssist
	SuperSwingTimerDB.useClassColors = ns.DB_DEFAULTS.useClassColors
	SuperSwingTimerDB.indicatorBlendMode = ns.DB_DEFAULTS.indicatorBlendMode
	SuperSwingTimerDB.weaveSpellFamilies = {
		LB  = ns.DB_DEFAULTS.weaveSpellFamilies.LB,
		CL  = ns.DB_DEFAULTS.weaveSpellFamilies.CL,
		HW  = ns.DB_DEFAULTS.weaveSpellFamilies.HW,
		LHW = ns.DB_DEFAULTS.weaveSpellFamilies.LHW,
		CH  = ns.DB_DEFAULTS.weaveSpellFamilies.CH,
	}
	for key, def in pairs(ns.DB_DEFAULTS.colors) do
		SuperSwingTimerDB.colors[key] = { r = def.r, g = def.g, b = def.b, a = def.a }
	end
	ns.SeedLegacyBarColorsFromClass()
	ns.ApplyBarSize(ns.DB_DEFAULTS.barWidth, ns.DB_DEFAULTS.barHeight)
	ns.ApplyBarTexture(ns.DB_DEFAULTS.barTexture, ns.DB_DEFAULTS.barTextureLayer)
	ns.ApplyRangedBarTexture(ns.DB_DEFAULTS.rangedBarTexture, ns.DB_DEFAULTS.barTextureLayer)
	ns.ApplyBarTextureLayer(ns.DB_DEFAULTS.barTextureLayer)
	ns.ApplySparkSettings(ns.DB_DEFAULTS.sparkTexture, ns.DB_DEFAULTS.sparkWidth, ns.DB_DEFAULTS.sparkHeight, ns.DB_DEFAULTS.sparkTextureLayer, ns.DB_DEFAULTS.sparkAlpha)
	ns.ApplySparkTextureLayer(ns.DB_DEFAULTS.sparkTextureLayer)
	ns.ApplyIndicatorBlendMode(ns.DB_DEFAULTS.indicatorBlendMode)
	ns.ApplyWeaveSparkSettings(ns.DB_DEFAULTS.weaveSparkTexture, ns.DB_DEFAULTS.weaveSparkWidth, ns.DB_DEFAULTS.weaveSparkHeight, ns.DB_DEFAULTS.weaveSparkTextureLayer, ns.DB_DEFAULTS.weaveSparkAlpha)
	ns.ApplyWeaveSparkTextureLayer(ns.DB_DEFAULTS.weaveSparkTextureLayer)
	ns.ApplyWeaveTriangleSettings(ns.DB_DEFAULTS.weaveTriangleTopTexture, ns.DB_DEFAULTS.weaveTriangleBottomTexture, ns.DB_DEFAULTS.weaveTriangleSize, ns.DB_DEFAULTS.weaveTriangleGap, ns.DB_DEFAULTS.weaveTriangleTextureLayer, ns.DB_DEFAULTS.weaveTriangleAlpha)
	ns.ApplyWeaveMarkerLayer(ns.DB_DEFAULTS.weaveMarkerLayer)
	ns.ApplyBarBackgroundAlpha(ns.DB_DEFAULTS.barBackgroundAlpha)
	ns.ApplySparkAlpha(ns.DB_DEFAULTS.sparkAlpha)
	ns.ApplyMinimalMode(ns.DB_DEFAULTS.minimalMode)
	ns.ApplyBarColors()
	ns.ApplyVisibility()
	if panel and panel.barTextureRow and panel.barTextureRow.refresh then
		panel.barTextureRow.refresh()
	end
	if panel and panel.barLayerRow and panel.barLayerRow.refresh then
		panel.barLayerRow.refresh()
	end
	if panel and panel.rangedTextureRow and panel.rangedTextureRow.refresh then
		panel.rangedTextureRow.refresh()
	end
	if panel and panel.sparkTextureRow and panel.sparkTextureRow.refresh then
		panel.sparkTextureRow.refresh()
	end
	if panel and panel.sparkLayerRow and panel.sparkLayerRow.refresh then
		panel.sparkLayerRow.refresh()
	end
	if panel and panel.weaveSparkTextureRow and panel.weaveSparkTextureRow.refresh then
		panel.weaveSparkTextureRow.refresh()
	end
	if panel and panel.weaveSparkLayerRow and panel.weaveSparkLayerRow.refresh then
		panel.weaveSparkLayerRow.refresh()
	end
	if panel and panel.weaveTriangleTopRow and panel.weaveTriangleTopRow.refresh then
		panel.weaveTriangleTopRow.refresh()
	end
	if panel and panel.weaveTriangleBottomRow and panel.weaveTriangleBottomRow.refresh then
		panel.weaveTriangleBottomRow.refresh()
	end
	if panel and panel.weaveTriangleLayerRow and panel.weaveTriangleLayerRow.refresh then
		panel.weaveTriangleLayerRow.refresh()
	end
	if panel and panel.weaveFamilyRows then
		for _, row in ipairs(panel.weaveFamilyRows) do
			if row.refresh then
				row.refresh()
			end
		end
	end
	if panel and panel.minimalModeRow and panel.minimalModeRow.refresh then
		panel.minimalModeRow.refresh()
	end
	if panel and panel.lockBarsRow and panel.lockBarsRow.refresh then
		panel.lockBarsRow.refresh()
	end
	if panel and panel.indicatorBlendModeRow and panel.indicatorBlendModeRow.refresh then
		panel.indicatorBlendModeRow.refresh()
	end
	if panel and panel.useClassColorsRow and panel.useClassColorsRow.refresh then
		panel.useClassColorsRow.refresh()
	end
	if panel and panel.showMHRow and panel.showMHRow.refresh then
		panel.showMHRow.refresh()
	end
	if panel and panel.showOHRow and panel.showOHRow.refresh then
		panel.showOHRow.refresh()
	end
	if panel and panel.showRangedRow and panel.showRangedRow.refresh then
		panel.showRangedRow.refresh()
	end
	if panel and panel.showWeaveRow and panel.showWeaveRow.refresh then
		panel.showWeaveRow.refresh()
	end
end

