local addonName, ns = ...
local CreateFrame = rawget(_G, "CreateFrame")
local UIParent = rawget(_G, "UIParent")
local InCombatLockdown = rawget(_G, "InCombatLockdown")
local ColorPickerFrame = rawget(_G, "ColorPickerFrame")
local wipe = rawget(_G, "wipe")
local strtrim = rawget(_G, "strtrim")

-- ============================================================
-- Config panel: /sst opens this frame.
-- Sliders for bar dimensions, color picker buttons for bar colors.
-- ============================================================

local panel
local layoutShift = 120

local function ShiftY(y)
	return y - layoutShift
end

local function GetLayerOptionLabel(layerValue)
	for _, option in ipairs(ns.TEXTURE_LAYER_OPTIONS) do
		if option.value == layerValue then
			return option.label
		end
	end
	return ns.TEXTURE_LAYER_OPTIONS[3].label
end

local function GetNextLayerValue(currentValue)
	for index, option in ipairs(ns.TEXTURE_LAYER_OPTIONS) do
		if option.value == currentValue then
			return ns.TEXTURE_LAYER_OPTIONS[(index % #ns.TEXTURE_LAYER_OPTIONS) + 1].value
		end
	end
	return ns.TEXTURE_LAYER_OPTIONS[3].value
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
	local c = SuperSwingTimerDB.colors[colorKey]
	local isSealTwist = (colorKey == "sealTwist")

	local function applyColor(r, g, b)
		local a = isSealTwist and 0.4 or 1
		SuperSwingTimerDB.colors[colorKey] = { r = r, g = g, b = b, a = a }
		swatch:SetColorTexture(r, g, b, a)
		ns.ApplyBarColors()
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
	slider:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -20, yOffset)
	slider:SetMinMaxValues(minVal, maxVal)
	slider:SetValueStep(step)
	slider:SetObeyStepOnDrag(true)
	slider:SetHeight(17)

	slider.Text:SetText(label)
	slider.Low:SetText(tostring(minVal))
	slider.High:SetText(tostring(maxVal))

	-- Value label below the slider
	local valText = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	valText:SetPoint("TOP", slider, "BOTTOM", 0, -2)
	slider.valueText = valText

	return slider
end

local function CreateColorButton(parent, label, colorKey, yOffset)
	local row = CreateFrame("Frame", nil, parent)
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
	row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -20, yOffset)
	row:SetHeight(22)

	local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	text:SetPoint("LEFT", row, "LEFT", 0, 0)
	text:SetText(label)

	local btn = CreateFrame("Button", nil, row)
	btn:SetSize(22, 22)
	btn:SetPoint("RIGHT", row, "RIGHT", 0, 0)

	local swatch = btn:CreateTexture(nil, "ARTWORK")
	swatch:SetAllPoints(true)
	local c = SuperSwingTimerDB.colors[colorKey]
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

	row.button = btn
	row.swatch = swatch
	return row
end

local textureDropdown

local function EnsureTextureDropdown()
	if textureDropdown then
		return textureDropdown
	end

	local f = CreateFrame("Frame", "SuperSwingTimerTextureDropdown", UIParent, "BackdropTemplate")
	f:SetSize(320, 320)
	f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 120, -120)
	f:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 32,
		insets = { left = 8, right = 8, top = 8, bottom = 8 },
	})
	f:SetFrameStrata("DIALOG")
	f:Hide()

	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOP", f, "TOP", 0, -12)
	title:SetText("Select Texture")

	local scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -34)
	scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30, 10)

	local content = CreateFrame("Frame", nil, scrollFrame)
	content:SetSize(260, 1000)
	scrollFrame:SetScrollChild(content)

	f.rows = {}
	f.content = content
	f.applyTexture = nil

	function f:Build(entries)
		for _, row in ipairs(self.rows) do
			row:Hide()
		end
		wipe(self.rows)

		local rowHeight = 28
		self.content:SetSize(260, math.max(1, #entries * rowHeight))

		for index, entry in ipairs(entries) do
			local row = CreateFrame("Button", nil, self.content, "UIPanelButtonTemplate")
			row:SetSize(240, 24)
			row:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -((index - 1) * rowHeight))

			local label = string.format("[%s / %s] %s", entry.category or "Unknown", entry.style or "style", entry.label or entry.path)
			row:SetText(label)
			row:SetScript("OnClick", function()
				if self.applyTexture then
					self.applyTexture(entry.path)
				end
				self:Hide()
			end)

			self.rows[#self.rows + 1] = row
		end
	end

	-- parent is already UIParent via CreateFrame; do not attempt to treat UIParent as a Lua table
	textureDropdown = f
	return f
end

local function OpenTextureDropdown(currentTexture, applyTexture)
	local dropdown = EnsureTextureDropdown()
	dropdown.applyTexture = applyTexture

	local library = ns.TEXTURE_LIBRARY or ns.BuildTextureLibrary() or {}
	dropdown:Build(library)
	dropdown:Show()
end

local function CreateTexturePathRow(parent, label, yOffset, getTexture, applyTexture)
	local row = CreateFrame("Frame", nil, parent)
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
	row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -20, yOffset)
	row:SetHeight(24)

	local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	text:SetPoint("LEFT", row, "LEFT", 0, 0)
	text:SetText(label)

	local function Refresh()
		local path = getTexture()
		if row.preview then
			row.preview:SetTexture(path)
		end
		if row.browseBtn then
			row.browseBtn:SetText(ns.GetTextureDisplayText(path))
		end
	end

	local preview = row:CreateTexture(nil, "ARTWORK")
	preview:SetSize(18, 18)
	preview:SetPoint("RIGHT", row, "RIGHT", -98, 0)
	preview:SetTexture(getTexture())
	row.preview = preview

	local browseBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	browseBtn:SetSize(150, 20)
	browseBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
	browseBtn:SetText(ns.GetTextureDisplayText(getTexture()))
	browseBtn:SetScript("OnClick", function()
		OpenTextureDropdown(getTexture(), function(texturePath)
			applyTexture(texturePath)
			if row.preview then
				row.preview:SetTexture(texturePath)
			end
			if browseBtn then
				browseBtn:SetText(ns.GetTextureDisplayText(texturePath))
			end
		end)
	end)

	row.refresh = Refresh
	row.browseBtn = browseBtn
	Refresh()
	return row
end

local function CreateCycleRow(parent, label, yOffset, getValue, applyValue)
	local row = CreateFrame("Frame", nil, parent)
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
	row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -20, yOffset)
	row:SetHeight(22)

	local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	text:SetPoint("LEFT", row, "LEFT", 0, 0)
	text:SetText(label)

	local button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	button:SetSize(120, 22)
	button:SetPoint("RIGHT", row, "RIGHT", 0, 0)

	local function Refresh()
		button:SetText(GetLayerOptionLabel(getValue()))
	end

	button:SetScript("OnClick", function()
		local nextValue = GetNextLayerValue(getValue())
		applyValue(nextValue)
		Refresh()
	end)

	row.button = button
	row.refresh = Refresh
	Refresh()
	return row
end

local function CreateToggleRow(parent, label, yOffset, getValue, applyValue)
	local row = CreateFrame("Frame", nil, parent)
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
	row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -20, yOffset)
	row:SetHeight(22)

	local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	text:SetPoint("LEFT", row, "LEFT", 0, 0)
	text:SetText(label)

	local toggle = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
	toggle:SetPoint("RIGHT", row, "RIGHT", 0, 0)
	toggle:SetChecked(getValue())
	toggle:SetScript("OnClick", function(self)
		applyValue(self:GetChecked() == true)
	end)

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

-- ============================================================
-- Panel creation
-- ============================================================
local function CreatePanel()
	local f = CreateFrame("Frame", "SuperSwingTimerConfigPanel", UIParent, "BackdropTemplate")
	f:SetSize(420, 650)
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

	-- Title
	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOP", f, "TOP", 0, -16)
	title:SetText("Super Swing Timer")

	local subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	subtitle:SetPoint("TOP", title, "BOTTOM", 0, -2)
	subtitle:SetText("Configure bars, textures, visibility, and weave assist")

	-- Close button
	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)

	local scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -46)
	scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30, 50)

	local content = CreateFrame("Frame", nil, scrollFrame)
	content:SetSize(360, 1550)
	scrollFrame:SetScrollChild(content)
	f.scrollFrame = scrollFrame
	f.content = content

	-- Sliders / selectors
	CreateSectionHeader(content, "Visibility", -10)

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

	CreateSectionHeader(content, "Appearance", -174)

	if ns.playerClass ~= "SHAMAN" then
		showWeaveRow:Hide()
	end

	local widthSlider = CreateSlider(content, "Bar Width", 100, 400, 10, ShiftY(-50))
	widthSlider:SetValue(SuperSwingTimerDB.barWidth or ns.DB_DEFAULTS.barWidth)
	widthSlider.valueText:SetText(tostring(widthSlider:GetValue()))

	local heightSlider = CreateSlider(content, "Bar Height", 10, 40, 2, ShiftY(-100))
	heightSlider:SetValue(SuperSwingTimerDB.barHeight or ns.DB_DEFAULTS.barHeight)
	heightSlider.valueText:SetText(tostring(heightSlider:GetValue()))

	local barTextureRow = CreateTexturePathRow(
		content,
		"Bar Texture",
		ShiftY(-145),
		function() return SuperSwingTimerDB.barTexture or ns.DB_DEFAULTS.barTexture end,
		function(texturePath) ns.ApplyBarTexture(texturePath, SuperSwingTimerDB.barTextureLayer or ns.DB_DEFAULTS.barTextureLayer) end
	)

	local barLayerRow = CreateCycleRow(
		content,
		"Bar Texture Layer",
		ShiftY(-180),
		function() return SuperSwingTimerDB.barTextureLayer or ns.DB_DEFAULTS.barTextureLayer end,
		function(layer) ns.ApplyBarTextureLayer(layer) end
	)

	local sparkTextureRow = CreateTexturePathRow(
		content,
		"Spark Texture",
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
		"Spark Texture Layer",
		ShiftY(-250),
		function() return SuperSwingTimerDB.sparkTextureLayer or ns.DB_DEFAULTS.sparkTextureLayer end,
		function(layer) ns.ApplySparkTextureLayer(layer) end
	)

	local sparkWidthSlider = CreateSlider(content, "Spark Width", 8, 60, 1, ShiftY(-315))
	sparkWidthSlider:SetValue(SuperSwingTimerDB.sparkWidth or ns.DB_DEFAULTS.sparkWidth)
	sparkWidthSlider.valueText:SetText(tostring(sparkWidthSlider:GetValue()))

	local sparkHeightSlider = CreateSlider(content, "Spark Height", 12, 90, 1, ShiftY(-365))
	sparkHeightSlider:SetValue(SuperSwingTimerDB.sparkHeight or ns.DB_DEFAULTS.sparkHeight)
	sparkHeightSlider.valueText:SetText(tostring(sparkHeightSlider:GetValue()))

	local backgroundAlphaSlider = CreateSlider(content, "Bar Background Alpha", 0, 1, 0.05, ShiftY(-415))
	backgroundAlphaSlider:SetValue(SuperSwingTimerDB.barBackgroundAlpha or ns.DB_DEFAULTS.barBackgroundAlpha)
	backgroundAlphaSlider.valueText:SetText(string.format("%.2f", backgroundAlphaSlider:GetValue()))

	local sparkAlphaSlider = CreateSlider(content, "Spark Alpha", 0, 1, 0.05, ShiftY(-465))
	sparkAlphaSlider:SetValue(SuperSwingTimerDB.sparkAlpha or ns.DB_DEFAULTS.sparkAlpha)
	sparkAlphaSlider.valueText:SetText(string.format("%.2f", sparkAlphaSlider:GetValue()))

	CreateSectionHeader(content, "Shaman Weave Assist", -504)

	local weaveSparkTextureRow = CreateTexturePathRow(
		content,
		"Weave Spark Texture",
		ShiftY(-515),
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
		"Weave Spark Layer",
		ShiftY(-550),
		function() return SuperSwingTimerDB.weaveSparkTextureLayer or ns.DB_DEFAULTS.weaveSparkTextureLayer end,
		function(layer) ns.ApplyWeaveSparkTextureLayer(layer) end
	)

	local weaveSparkWidthSlider = CreateSlider(content, "Weave Spark Width", 6, 60, 1, ShiftY(-585))
	weaveSparkWidthSlider:SetValue(SuperSwingTimerDB.weaveSparkWidth or ns.DB_DEFAULTS.weaveSparkWidth)
	weaveSparkWidthSlider.valueText:SetText(tostring(weaveSparkWidthSlider:GetValue()))

	local weaveSparkHeightSlider = CreateSlider(content, "Weave Spark Height", 8, 100, 1, ShiftY(-635))
	weaveSparkHeightSlider:SetValue(SuperSwingTimerDB.weaveSparkHeight or ns.DB_DEFAULTS.weaveSparkHeight)
	weaveSparkHeightSlider.valueText:SetText(tostring(weaveSparkHeightSlider:GetValue()))

	local weaveSparkAlphaSlider = CreateSlider(content, "Weave Spark Alpha", 0, 1, 0.05, ShiftY(-685))
	weaveSparkAlphaSlider:SetValue(SuperSwingTimerDB.weaveSparkAlpha or ns.DB_DEFAULTS.weaveSparkAlpha)
	weaveSparkAlphaSlider.valueText:SetText(string.format("%.2f", weaveSparkAlphaSlider:GetValue()))

	local weaveTriangleTopRow = CreateTexturePathRow(
		content,
		"Triangle Top Texture",
		ShiftY(-735),
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
		"Triangle Bottom Texture",
		ShiftY(-770),
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
		"Triangle Layer",
		ShiftY(-805),
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

	local weaveTriangleSizeSlider = CreateSlider(content, "Triangle Size", 8, 28, 1, ShiftY(-840))
	weaveTriangleSizeSlider:SetValue(SuperSwingTimerDB.weaveTriangleSize or ns.DB_DEFAULTS.weaveTriangleSize)
	weaveTriangleSizeSlider.valueText:SetText(tostring(weaveTriangleSizeSlider:GetValue()))

	local weaveTriangleGapSlider = CreateSlider(content, "Triangle Gap", 0, 16, 1, ShiftY(-890))
	weaveTriangleGapSlider:SetValue(SuperSwingTimerDB.weaveTriangleGap or ns.DB_DEFAULTS.weaveTriangleGap)
	weaveTriangleGapSlider.valueText:SetText(tostring(weaveTriangleGapSlider:GetValue()))

	local weaveTriangleAlphaSlider = CreateSlider(content, "Triangle Alpha", 0, 1, 0.05, ShiftY(-940))
	weaveTriangleAlphaSlider:SetValue(SuperSwingTimerDB.weaveTriangleAlpha or ns.DB_DEFAULTS.weaveTriangleAlpha)
	weaveTriangleAlphaSlider.valueText:SetText(string.format("%.2f", weaveTriangleAlphaSlider:GetValue()))

	CreateSectionHeader(content, "Behavior", -1100)

	local minimalModeRow = CreateToggleRow(
		content,
		"Minimal Mode",
		ShiftY(-1115),
		function() return SuperSwingTimerDB.minimalMode == true end,
		function(enabled) ns.ApplyMinimalMode(enabled) end
	)

	local lockBarsRow = CreateToggleRow(
		content,
		"Lock Bars",
		ShiftY(-1145),
		function() return SuperSwingTimerDB.lockBars == true end,
		function(enabled) SuperSwingTimerDB.lockBars = enabled end
	)

	widthSlider:SetScript("OnValueChanged", function(self, value)
		value = math.floor(value + 0.5)
		self.valueText:SetText(tostring(value))
		ns.ApplyBarSize(value, heightSlider:GetValue())
	end)

	heightSlider:SetScript("OnValueChanged", function(self, value)
		value = math.floor(value + 0.5)
		self.valueText:SetText(tostring(value))
		ns.ApplyBarSize(widthSlider:GetValue(), value)
	end)

	sparkWidthSlider:SetScript("OnValueChanged", function(self, value)
		value = math.floor(value + 0.5)
		self.valueText:SetText(tostring(value))
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
		self.valueText:SetText(tostring(value))
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
		self.valueText:SetText(string.format("%.2f", value))
		ns.ApplyBarBackgroundAlpha(value)
	end)

	sparkAlphaSlider:SetScript("OnValueChanged", function(self, value)
		value = math.floor((value + 0.0001) * 100) / 100
		self.valueText:SetText(string.format("%.2f", value))
		ns.ApplySparkAlpha(value)
	end)

	weaveSparkWidthSlider:SetScript("OnValueChanged", function(self, value)
		value = math.floor(value + 0.5)
		self.valueText:SetText(tostring(value))
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
		self.valueText:SetText(tostring(value))
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
		self.valueText:SetText(string.format("%.2f", value))
		ns.ApplyWeaveSparkAlpha(value)
	end)

	weaveTriangleSizeSlider:SetScript("OnValueChanged", function(self, value)
		value = math.floor(value + 0.5)
		self.valueText:SetText(tostring(value))
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
		self.valueText:SetText(tostring(value))
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
		self.valueText:SetText(string.format("%.2f", value))
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
	local yStart = ShiftY(-1210)
	local spacing = -28
	CreateSectionHeader(content, "Colors", -1180)

	local mhRow     = CreateColorButton(content, "Main Hand Color",  "mh",     yStart)
	local ohRow     = CreateColorButton(content, "Off Hand Color",   "oh",     yStart + spacing)
	local rangedRow = CreateColorButton(content, "Ranged Color",     "ranged", yStart + spacing * 2)
	local sealRow   = CreateColorButton(content, "Seal-Twist Color", "sealTwist", yStart + spacing * 3)

	-- Seal-twist row only visible for Paladins
	if ns.playerClass ~= "PALADIN" then
		sealRow:Hide()
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
			local c = SuperSwingTimerDB.colors[key]
			if c then
				row.swatch:SetColorTexture(c.r, c.g, c.b, c.a)
			end
		end
	end)

	f.widthSlider = widthSlider
	f.heightSlider = heightSlider
	f.barTextureRow = barTextureRow
	f.barLayerRow = barLayerRow
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
	f.sparkWidthSlider = sparkWidthSlider
	f.sparkHeightSlider = sparkHeightSlider
	f.backgroundAlphaSlider = backgroundAlphaSlider
	f.sparkAlphaSlider = sparkAlphaSlider
	f.minimalModeRow = minimalModeRow
	f.lockBarsRow = lockBarsRow
	f.showMHRow = showMHRow
	f.showOHRow = showOHRow
	f.showRangedRow = showRangedRow
	f.showWeaveRow = showWeaveRow
	f.colorRows = { mhRow, ohRow, rangedRow, sealRow }
	textureDropdown = f
	return f
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
		for _, row in ipairs(panel.colorRows) do
			local key = row.button.colorKey
			local c = SuperSwingTimerDB.colors[key]
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
	for key, def in pairs(ns.DB_DEFAULTS.colors) do
		SuperSwingTimerDB.colors[key] = { r = def.r, g = def.g, b = def.b, a = def.a }
	end
	ns.ApplyBarSize(ns.DB_DEFAULTS.barWidth, ns.DB_DEFAULTS.barHeight)
	ns.ApplyBarTexture(ns.DB_DEFAULTS.barTexture, ns.DB_DEFAULTS.barTextureLayer)
	ns.ApplyBarTextureLayer(ns.DB_DEFAULTS.barTextureLayer)
	ns.ApplySparkSettings(ns.DB_DEFAULTS.sparkTexture, ns.DB_DEFAULTS.sparkWidth, ns.DB_DEFAULTS.sparkHeight, ns.DB_DEFAULTS.sparkTextureLayer, ns.DB_DEFAULTS.sparkAlpha)
	ns.ApplySparkTextureLayer(ns.DB_DEFAULTS.sparkTextureLayer)
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
	if panel and panel.minimalModeRow and panel.minimalModeRow.refresh then
		panel.minimalModeRow.refresh()
	end
	if panel and panel.lockBarsRow and panel.lockBarsRow.refresh then
		panel.lockBarsRow.refresh()
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

