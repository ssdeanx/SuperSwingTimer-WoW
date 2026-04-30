local _, ns = ...
local CreateFrame = rawget(_G, "CreateFrame")
local UIParent = rawget(_G, "UIParent")
local InCombatLockdown = rawget(_G, "InCombatLockdown")
local ColorPickerFrame = rawget(_G, "ColorPickerFrame")
local GameTooltip = rawget(_G, "GameTooltip")
local C_Timer = rawget(_G, "C_Timer")
local UIDropDownMenu_AddButton = rawget(_G, "UIDropDownMenu_AddButton")
local UIDropDownMenu_CreateInfo = rawget(_G, "UIDropDownMenu_CreateInfo")
local UIDropDownMenu_Initialize = rawget(_G, "UIDropDownMenu_Initialize")
local UIDropDownMenu_SetText = rawget(_G, "UIDropDownMenu_SetText")
local UIDropDownMenu_SetWidth = rawget(_G, "UIDropDownMenu_SetWidth")
local ToggleDropDownMenu = rawget(_G, "ToggleDropDownMenu")
local strtrim = rawget(_G, "strtrim")

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

local TEXTURE_BROWSER_CATEGORY_CHOICES = {
	{ label = "All", value = "All" },
	{ label = "Shapes", value = "WeakAuras" },
	{ label = "SharedMedia", value = "SharedMedia" },
	{ label = "Blizzard", value = "Blizzard" },
	{ label = "Platynator", value = "Platynator" },
}

local function GetTextureBrowserCategoryLabel(categoryValue)
	for _, choice in ipairs(TEXTURE_BROWSER_CATEGORY_CHOICES) do
		if choice.value == categoryValue then
			return choice.label
		end
	end

	return TEXTURE_BROWSER_CATEGORY_CHOICES[1].label
end

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

	local sparkLabel = ns.GetTextureDisplayText(texturePath)
	local barTexture = ns.GetBarTexture and ns.GetBarTexture() or nil
	local barLabel = ns.GetTextureDisplayText(barTexture)
	return string.format("%s | Bar: %s", sparkLabel, barLabel)
end

local function SetRowsShown(rows, shown)
	if not rows then
		return
	end

	for _, row in ipairs(rows) do
		if row then
			row:SetShown(shown)
		end
	end
end

-- ============================================================
-- Bar preview: show bars while config panel is open
-- ============================================================
local function ShowBarPreview()
	local bars = { ns.mhBar, ns.ohBar, ns.rangedBar, ns.hunterCastBar }
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
	ns.ApplyBarBackgroundColor(ns.GetBarBackgroundColor())
	ns.ApplyBarBorderColor(ns.GetBarBorderColor())
	ns.ApplyBarBorderSize(ns.GetBarBorderSize())
	ns.ApplyMinimalMode(ns.IsMinimalMode())
	ns.ApplyBarColors()
	ns.ApplyIndicatorBlendMode(ns.GetIndicatorBlendMode())
	ns.ApplyVisibility()
	if ns.hunterCastBar then
		ns.hunterCastBar:SetAlpha(1)
		ns.hunterCastBar:SetMinMaxValues(0, 1)
		ns.hunterCastBar:SetValue(1)
	end
end

local function HideBarPreview()
	if ns.barTestActive then
		return
	end
	-- Only hide if not in combat (combat show/hide handles itself)
	if not InCombatLockdown or not InCombatLockdown() then
		local bars = { ns.mhBar, ns.ohBar, ns.rangedBar, ns.hunterCastBar }
		for _, bar in ipairs(bars) do
			if bar then bar:SetAlpha(0) end
		end
	end
end

local function StartBarTestPreview(duration)
	duration = tonumber(duration) or 8
	ns.barTestActive = true
	if ns.barTestTimer and ns.barTestTimer.Cancel then
		ns.barTestTimer:Cancel()
		ns.barTestTimer = nil
	end
	ShowBarPreview()
	if panel and panel.Hide then
		panel:Hide()
	end
	if C_Timer and C_Timer.NewTimer then
		ns.barTestTimer = C_Timer.NewTimer(duration, function()
			ns.barTestActive = false
			ns.barTestTimer = nil
			HideBarPreview()
		end)
	end
end

-- ============================================================
-- Color picker helper
-- ============================================================
local function OpenColorPicker(options)
	if not options or not options.getColor or not options.applyColor then
		return
	end

	local c = options.getColor() or { r = 1, g = 1, b = 1, a = 1 }
	local allowAlpha = options.allowAlpha == true

	local function Commit(r, g, b, a)
		a = tonumber(a)
		if not allowAlpha then
			a = 1
		elseif a == nil then
			a = c.a or 1
		elseif a < 0 then
			a = 0
		elseif a > 1 then
			a = 1
		end
		options.applyColor(r or 1, g or 1, b or 1, a)
	end

	local info = {
		r = c.r or 1,
		g = c.g or 1,
		b = c.b or 1,
		hasOpacity = allowAlpha,
		opacity = allowAlpha and (c.a or 1) or nil,
		swatchFunc = function()
			local r, g, b = ColorPickerFrame:GetColorRGB()
			local a = allowAlpha and (ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha() or c.a or 1) or 1
			Commit(r, g, b, a)
		end,
		cancelFunc = function(prev)
			if prev then
				Commit(prev.r, prev.g, prev.b, allowAlpha and (prev.a or 1) or 1)
			else
				Commit(c.r or 1, c.g or 1, c.b or 1, allowAlpha and (c.a or 1) or 1)
			end
		end,
	}

	if allowAlpha then
		info.opacityFunc = function()
			local r, g, b = ColorPickerFrame:GetColorRGB()
			local a = ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha() or c.a or 1
			Commit(r, g, b, a)
		end
	end

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

local function CreateColorButton(parent, label, colorKey, yOffset, options)
	options = options or {}
	local getColor = options.getColor or function()
		return ns.GetBarColor(colorKey)
	end
	local allowAlpha = options.allowAlpha == true
	local tooltipText = options.tooltipText or string.format("Click the swatch button to change the %s color.", label)
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
	local c = getColor()
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

	local function ApplySelectedColor(r, g, b, a)
		local alpha = allowAlpha and (a or 1) or 1
		if options.applyColor then
			options.applyColor(r, g, b, alpha, swatch)
		else
			local isSealTwist = (colorKey == "sealTwist")
			if not isSealTwist then
				SuperSwingTimerDB.useClassColors = false
			end
			SuperSwingTimerDB.colors[colorKey] = { r = r, g = g, b = b, a = alpha }
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
		swatch:SetColorTexture(r, g, b, alpha)
	end

	local function Refresh()
		local color = getColor() or { r = 1, g = 1, b = 1, a = 1 }
		swatch:SetColorTexture(color.r or 1, color.g or 1, color.b or 1, color.a or 1)
	end

	local function OpenPicker()
		OpenColorPicker({
			getColor = getColor,
			allowAlpha = allowAlpha,
			applyColor = ApplySelectedColor,
		})
	end

	btn:SetScript("OnClick", OpenPicker)
	AddControlTooltip(row, label, tooltipText)

	row:SetScript("OnMouseUp", function(_, button)
		if button == "LeftButton" then
			OpenPicker()
		end
	end)

	row.button = btn
	row.swatch = swatch
	row.refresh = Refresh
	Refresh()
	return row
end

local function NormalizeTexturePath(texturePath, defaultTexture)
	texturePath = strtrim(texturePath or "")
	if texturePath == "" then
		return defaultTexture or ns.DB_DEFAULTS.sparkTexture
	end
	return texturePath
end

local function GetTextureBrowserEntries(allowedCategories, allowedUsages)
	local library = ns.TEXTURE_LIBRARY or ns.BuildTextureLibrary() or {}
	local entries = {}
	for _, entry in ipairs(library) do
		local categoryAllowed = not allowedCategories or allowedCategories[entry.category]
		local usage = entry.usage or "both"
		local usageAllowed = not allowedUsages or allowedUsages[usage]
		if categoryAllowed and usageAllowed then
			entries[#entries + 1] = entry
		end
	end
	table.sort(entries, function(a, b)
		local aCategory = a.category or ""
		local bCategory = b.category or ""
		if aCategory ~= bCategory then
			return aCategory < bCategory
		end
		local aLabel = a.label or a.path or ""
		local bLabel = b.label or b.path or ""
		if aLabel ~= bLabel then
			return aLabel < bLabel
		end
		return (a.path or "") < (b.path or "")
	end)
	return entries
end

local textureBrowserFrame

local function RefreshTextureBrowser(frame)
	if not frame then
		return
	end

	local searchText = strtrim(frame.searchBox and frame.searchBox:GetText() or "")
	searchText = string.lower(searchText or "")
	local category = frame.currentCategory or "All"
	local filtered = {}
	for _, entry in ipairs(frame.textureChoices or {}) do
		local categoryMatches = (category == "All") or (entry.category == category)
		if categoryMatches then
			local matchesSearch = true
			if searchText ~= "" then
				local displayLabel = entry.label or entry.path or ""
				if ns.GetTextureDisplayText then
					displayLabel = ns.GetTextureDisplayText(entry.path) or displayLabel
				end

				local categoryLabel = entry.category or ""
				if ns.GetTextureBrowserDisplayCategory then
					categoryLabel = ns.GetTextureBrowserDisplayCategory(entry) or categoryLabel
				end

				local haystack = string.lower(string.format(
					"%s %s %s %s",
					categoryLabel,
					displayLabel,
					entry.label or "",
					entry.path or ""
				))
				matchesSearch = string.find(haystack, searchText, 1, true) ~= nil
			end
			if matchesSearch then
				filtered[#filtered + 1] = entry
			end
		end
	end

	frame.filteredChoices = filtered
	for index, button in ipairs(frame.buttons or {}) do
		local entry = filtered[index]
		if entry then
			button:Show()
			button.entry = entry
			if button.texture then
				button.texture:SetTexture(entry.path)
			end
				button.displayLabel = entry.label or entry.path
				if ns.GetTextureDisplayText then
					button.displayLabel = ns.GetTextureDisplayText(entry.path) or button.displayLabel
				end

				button.displayCategory = entry.category or ""
				if ns.GetTextureBrowserDisplayCategory then
					button.displayCategory = ns.GetTextureBrowserDisplayCategory(entry) or button.displayCategory
				end
			button.displayPath = entry.path
			local selected = frame.pendingTexture and entry.path == frame.pendingTexture
			if button.SetBackdropBorderColor then
				if selected then
					button:SetBackdropBorderColor(0.95, 0.78, 0.20, 1)
					button:SetBackdropColor(0.14, 0.11, 0.05, 0.95)
				else
					button:SetBackdropBorderColor(0.30, 0.30, 0.30, 1)
					button:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
				end
			end
		else
			button:Hide()
			button.entry = nil
		end
	end

	if frame.noResultsText then
		frame.noResultsText:SetShown(#filtered == 0)
	end
end

local function CreateTextureBrowserFrame()
	local frame = CreateFrame("Frame", "SuperSwingTimerTextureBrowserFrame", UIParent, "BackdropTemplate")
	frame:SetSize(660, 580)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	frame:SetBackdropColor(0.06, 0.06, 0.06, 0.98)
	frame:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
	frame:Hide()

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOP", frame, "TOP", 0, -12)
	title:SetText("Spark Texture Picker")
	frame.titleText = title

	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -3, -3)
	frame.closeButton = close

	local categoryLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	categoryLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -34)
	categoryLabel:SetText("Category")

	local categoryDropdown = CreateFrame("Frame", nil, frame, "UIDropDownMenuTemplate")
	categoryDropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -46)
	if UIDropDownMenu_SetWidth then
		UIDropDownMenu_SetWidth(categoryDropdown, 150)
	end
	frame.categoryDropdown = categoryDropdown
	frame.categoryChoices = TEXTURE_BROWSER_CATEGORY_CHOICES

	local searchLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	searchLabel:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -214, -34)
	searchLabel:SetText("Search")

	local searchBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
	searchBox:SetSize(180, 20)
	searchBox:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -18, -44)
	searchBox:SetAutoFocus(false)
	searchBox:SetMaxLetters(128)
	searchBox:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
		RefreshTextureBrowser(frame)
	end)
	searchBox:SetScript("OnEscapePressed", function(self)
		self:SetText("")
		self:ClearFocus()
		RefreshTextureBrowser(frame)
	end)
	searchBox:SetScript("OnTextChanged", function(self, userInput)
		if userInput then
			RefreshTextureBrowser(frame)
		end
	end)
	frame.searchBox = searchBox

	if UIDropDownMenu_Initialize and UIDropDownMenu_CreateInfo and UIDropDownMenu_AddButton and UIDropDownMenu_SetText then
		UIDropDownMenu_Initialize(categoryDropdown, function(_, level)
			for _, category in ipairs(frame.categoryChoices) do
				local info = UIDropDownMenu_CreateInfo()
				info.text = category.label
				info.checked = frame.currentCategory == category.value
				info.func = function()
					frame.currentCategory = category.value
					UIDropDownMenu_SetText(categoryDropdown, category.label)
					RefreshTextureBrowser(frame)
				end
				UIDropDownMenu_AddButton(info, level)
			end
		end)
		UIDropDownMenu_SetText(categoryDropdown, GetTextureBrowserCategoryLabel(frame.currentCategory))
	end

	local buttonWidth = 100
	local buttonHeight = 100
	local buttonPaddingX = 8
	local buttonPaddingY = 8
	local columns = 5
	local startX = 16
	local startY = -78
	frame.buttons = {}
	for index = 1, 20 do
		local button = CreateFrame("Button", nil, frame, "BackdropTemplate")
		button:SetSize(buttonWidth, buttonHeight)
		button:SetBackdrop({
			bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true,
			tileSize = 4,
			edgeSize = 8,
			insets = { left = 1, right = 1, top = 1, bottom = 1 },
		})
		button:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
		button:SetBackdropBorderColor(0.30, 0.30, 0.30, 1)
		local columnOffset = ((index - 1) % columns) * (buttonWidth + buttonPaddingX)
		local rowOffset = math.floor((index - 1) / columns) * (buttonHeight + buttonPaddingY)
		button:SetPoint("TOPLEFT", frame, "TOPLEFT", startX + columnOffset, startY - rowOffset)
		button:SetScript("OnEnter", function(self)
			if self.entry then
				self:SetBackdropBorderColor(0.75, 0.75, 0.75, 1)
				if GameTooltip then
					GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
					GameTooltip:SetText(self.displayLabel or self.entry.label or self.entry.path or "", 1, 1, 1)
					if self.displayPath and self.displayPath ~= "" then
						GameTooltip:AddLine(self.displayPath, 0.85, 0.85, 0.85, true)
					end
					if self.displayCategory and self.displayCategory ~= "" then
						GameTooltip:AddLine(self.displayCategory, 0.70, 0.70, 0.70)
					end
					GameTooltip:Show()
				end
			end
		end)
		button:SetScript("OnLeave", function(self)
			if GameTooltip then
				GameTooltip:Hide()
			end
			RefreshTextureBrowser(frame)
		end)
		button:SetScript("OnClick", function(self)
			if self.entry then
				frame.pendingTexture = self.entry.path
				RefreshTextureBrowser(frame)
			end
		end)

		local texture = button:CreateTexture(nil, "ARTWORK")
		texture:SetPoint("TOPLEFT", 4, -4)
		texture:SetPoint("BOTTOMRIGHT", -4, 4)
		texture:SetTexCoord(0.05, 0.95, 0.05, 0.95)
		button.texture = texture

		frame.buttons[#frame.buttons + 1] = button
	end

	local noResultsText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	noResultsText:SetPoint("CENTER", frame, "CENTER", 0, -12)
	noResultsText:SetText("No matching textures.")
	noResultsText:Hide()
	frame.noResultsText = noResultsText

	local okButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	okButton:SetSize(90, 22)
	okButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -106, 12)
	okButton:SetText("Okay")
	okButton:SetScript("OnClick", function()
		if frame.applyTexture then
			frame.applyTexture(NormalizeTexturePath(frame.pendingTexture, ns.DB_DEFAULTS.sparkTexture))
		end
		frame:Hide()
	end)
	frame.okButton = okButton

	local cancelButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	cancelButton:SetSize(90, 22)
	cancelButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
	cancelButton:SetText("Cancel")
	cancelButton:SetScript("OnClick", function()
		frame:Hide()
	end)
	frame.cancelButton = cancelButton

	frame:SetScript("OnHide", function(self)
		self.applyTexture = nil
		self.pendingTexture = nil
	end)

	frame.Refresh = RefreshTextureBrowser
	return frame
end

local function OpenTextureBrowser(initialTexture, applyTexture, options)
	if not textureBrowserFrame then
		textureBrowserFrame = CreateTextureBrowserFrame()
	end

	local frame = textureBrowserFrame
	frame.applyTexture = applyTexture
	frame.allowedCategories = (options and options.allowedCategories) or {
		WeakAuras = true,
		SharedMedia = true,
		Blizzard = true,
		Platynator = true,
	}
	frame.textureChoices = GetTextureBrowserEntries(frame.allowedCategories)
	frame.currentCategory = (options and options.defaultCategory) or "WeakAuras"
	local browserDefaultTexture = (options and options.defaultTexture) or ns.DB_DEFAULTS.sparkTexture
	frame.pendingTexture = NormalizeTexturePath(initialTexture, browserDefaultTexture)
	frame.searchBox:SetText("")
	if frame.titleText then
		frame.titleText:SetText((options and options.title) or "Spark Texture Picker")
	end
	if UIDropDownMenu_SetText then
		UIDropDownMenu_SetText(frame.categoryDropdown, GetTextureBrowserCategoryLabel(frame.currentCategory))
	end
	RefreshTextureBrowser(frame)
	frame:Show()
	frame:Raise()
end

local function CreateTexturePathRow(parent, label, yOffset, getTexture, applyTexture)
	local options = nil
	if type(getTexture) == "table" then
		options = getTexture
		getTexture = options.getTexture
		applyTexture = options.applyTexture
		yOffset = options.yOffset or yOffset
		label = options.label or label
	end
	options = options or {}
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
		if row.pathBox then
			row.pathBox:SetText(path or "")
		end
	end

	if options.mode == "browser" then
		local defaultTexture = options.defaultTexture or getTexture() or ns.DB_DEFAULTS.sparkTexture
		local pathBox = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
		pathBox:SetSize(236, 20)
		pathBox:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -30, 0)
		pathBox:SetAutoFocus(false)
		pathBox:SetMaxLetters(260)
		pathBox:SetScript("OnEnterPressed", function(self)
			local path = NormalizeTexturePath(self:GetText(), defaultTexture)
			applyTexture(path)
			self:ClearFocus()
			Refresh()
			if ns.RefreshTextureRows then
				ns.RefreshTextureRows()
			end
		end)
		pathBox:SetScript("OnEscapePressed", function(self)
			self:ClearFocus()
			Refresh()
		end)
		pathBox:SetScript("OnEditFocusLost", function(self)
			local path = NormalizeTexturePath(self:GetText(), defaultTexture)
			applyTexture(path)
			Refresh()
			if ns.RefreshTextureRows then
				ns.RefreshTextureRows()
			end
		end)
		row.pathBox = pathBox

		local browseButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
		browseButton:SetSize(22, 20)
		browseButton:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
		browseButton:SetText("")
		browseButton:SetNormalTexture("Interface\\AddOns\\WeakAuras\\Media\\Textures\\browse.tga")
		browseButton:SetScript("OnClick", function()
			OpenTextureBrowser(getTexture(), function(texturePath)
				applyTexture(NormalizeTexturePath(texturePath, defaultTexture))
				Refresh()
				if ns.RefreshTextureRows then
					ns.RefreshTextureRows()
				end
			end, {
				defaultTexture = defaultTexture,
				defaultCategory = options.browserDefaultCategory or "WeakAuras",
				allowedCategories = options.browserCategories or {
					WeakAuras = true,
					SharedMedia = true,
					Blizzard = true,
					Platynator = true,
				},
				title = options.browserTitle or "Spark Texture Picker",
			})
		end)
		row.browseButton = browseButton
		local browserTooltip = options.tooltipText or string.format(
			"Type a texture path or click the browse icon to open the spark texture picker for %s.",
			label
		)
		AddControlTooltip(row, label, browserTooltip)
		row.refresh = Refresh
		Refresh()
		return row
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
			local allowedUsages = options.dropdownUsages or { both = true }
			local library = GetTextureBrowserEntries(options.dropdownCategories, allowedUsages)
			for _, entry in ipairs(library) do
				local info = UIDropDownMenu_CreateInfo()
				local entryCategory = entry.category or "Unknown"
				local entryStyle = entry.style or "style"
				local entryLabel = entry.label or entry.path
				info.text = string.format("[%s / %s] %s", entryCategory, entryStyle, entryLabel)
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
	local dropdownTooltip = string.format(
		"Choose the %s option from the dropdown. The full list shows the real WoW draw layers and modes.",
		label
	)
	AddControlTooltip(row, label, dropdownTooltip)
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

local function CreateActionRow(parent, label, buttonText, yOffset, onClick, tooltipText)
	local row = CreateFrame("Frame", nil, parent)
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
	row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -20, yOffset)
	row:SetHeight(40)
	row:EnableMouse(true)
	row.hover = AddRowHoverHighlight(row)

	local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	text:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
	text:SetText(label)

	local btn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	btn:SetSize(120, 22)
	btn:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
	btn:SetText(buttonText or label)
	btn:SetScript("OnClick", function()
		if onClick then
			onClick()
		end
	end)
	text:SetPoint("RIGHT", btn, "LEFT", -8, 0)

	row:SetScript("OnMouseUp", function(_, mouseButton)
		if mouseButton == "LeftButton" then
			btn:Click()
		end
	end)
	AddControlTooltip(row, label, tooltipText or string.format("Click to %s.", string.lower(buttonText or label)))

	row.button = btn
	row.refresh = function() end
	return row
end

local function CreateSectionHeader(parent, label, yOffset, options)
	local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
	row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -20, yOffset)
	row:SetHeight(24)
	row:EnableMouse(true)
	row:RegisterForClicks("LeftButtonUp")
	row:Show()
	row.options = options or {}
	row.rows = row.options.rows

	local bg = row:CreateTexture(nil, "BACKGROUND")
	bg:SetColorTexture(0.07, 0.07, 0.07, 0.82)
	bg:SetPoint("TOPLEFT", row, "TOPLEFT", -6, 3)
	bg:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 6, -3)

	local hover = AddRowHoverHighlight(row, 0.05)
	row.hover = hover

	local arrow = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	arrow:SetPoint("LEFT", row, "LEFT", 2, 0)
	arrow:SetText("-")
	row.arrow = arrow

	local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	text:SetPoint("LEFT", arrow, "RIGHT", 6, 0)
	text:SetText(label)
	row.text = text

	local line = row:CreateTexture(nil, "ARTWORK")
	line:SetColorTexture(0.38, 0.38, 0.38, 0.78)
	line:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, -2)
	line:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, -2)
	line:SetHeight(2)

	row.refresh = function()
		local collapsed = row.options and row.options.getCollapsed and row.options.getCollapsed() or false
		if row.arrow then
			row.arrow:SetText(collapsed and "+" or "-")
		end
		if row.rows then
			SetRowsShown(row.rows, not collapsed)
		end
	end

	if row.options and row.options.rows then
		row:SetScript("OnClick", function(self)
			local collapsed = self.options and self.options.getCollapsed and self.options.getCollapsed() or false
			collapsed = not collapsed
			if self.options and self.options.setCollapsed then
				self.options.setCollapsed(collapsed)
			end
			SetRowsShown(self.rows, not collapsed)
			if self.arrow then
				self.arrow:SetText(collapsed and "+" or "-")
			end
		end)
	end

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
	local familyLabel = string.format("%s family", abbrev)
	local familyTooltip = string.format("Keep the %s family in the weave breakpoint helper.", label)
	AddControlTooltip(row, familyLabel, familyTooltip)

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

	local sectionCollapsed = {
		barVisibility = false,
		mhOh = false,
		shaman = false,
		general = false,
		colors = false,
		weaveFamilies = false,
	}
	local barVisibilityRows = {}
	local mhOhRows = {}
	local shamanRows = {}
	local generalRows = {}
	local colorRowsSection = {}
	local weaveFamiliesRows = {}

	-- Sliders / selectors
	local barVisibilityHeader = CreateSectionHeader(content, "Bar Visibility", -10, {
		rows = barVisibilityRows,
		getCollapsed = function() return sectionCollapsed.barVisibility end,
		setCollapsed = function(collapsed) sectionCollapsed.barVisibility = collapsed end,
	})

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

	local mhOhHeader = CreateSectionHeader(content, "MH/OH Bar Appearance", -174, {
		rows = mhOhRows,
		getCollapsed = function() return sectionCollapsed.mhOh end,
		setCollapsed = function(collapsed) sectionCollapsed.mhOh = collapsed end,
	})

	if ns.playerClass ~= "SHAMAN" then
		showWeaveRow:Hide()
	end
	barVisibilityRows[1] = showMHRow
	barVisibilityRows[2] = showOHRow
	barVisibilityRows[3] = showRangedRow
	if ns.playerClass == "SHAMAN" then
		barVisibilityRows[4] = showWeaveRow
	end
	SetRowsShown(barVisibilityRows, not sectionCollapsed.barVisibility)
	if barVisibilityHeader.refresh then
		barVisibilityHeader.refresh()
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
		{
			defaultTexture = ns.DB_DEFAULTS.barTexture,
			getTexture = function() return SuperSwingTimerDB.barTexture or ns.DB_DEFAULTS.barTexture end,
			applyTexture = function(texturePath)
				ns.ApplyBarTexture(texturePath, SuperSwingTimerDB.barTextureLayer or ns.DB_DEFAULTS.barTextureLayer)
			end,
			dropdownUsages = { both = true },
		}
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
		{
			defaultTexture = ns.DB_DEFAULTS.rangedBarTexture,
			getTexture = function() return SuperSwingTimerDB.rangedBarTexture or ns.DB_DEFAULTS.rangedBarTexture end,
			applyTexture = function(texturePath)
				ns.ApplyRangedBarTexture(texturePath, SuperSwingTimerDB.barTextureLayer or ns.DB_DEFAULTS.barTextureLayer)
			end,
			dropdownUsages = { both = true },
		}
	)

	local sparkTextureRow = CreateTexturePathRow(
		content,
		"Spark Texture",
		ShiftY(-215),
		{
			mode = "browser",
			label = "Spark Texture",
			yOffset = ShiftY(-215),
			defaultTexture = ns.DB_DEFAULTS.sparkTexture,
			getTexture = function() return SuperSwingTimerDB.sparkTexture or ns.DB_DEFAULTS.sparkTexture end,
			applyTexture = function(texturePath)
				ns.ApplySparkSettings(
					texturePath,
					SuperSwingTimerDB.sparkWidth or ns.DB_DEFAULTS.sparkWidth,
					SuperSwingTimerDB.sparkHeight or ns.DB_DEFAULTS.sparkHeight,
					SuperSwingTimerDB.sparkTextureLayer or ns.DB_DEFAULTS.sparkTextureLayer,
					SuperSwingTimerDB.sparkAlpha ~= nil and SuperSwingTimerDB.sparkAlpha or ns.DB_DEFAULTS.sparkAlpha,
					SuperSwingTimerDB.sparkColor or ns.GetSparkColor()
				)
			end,
			browserDefaultCategory = "WeakAuras",
			browserCategories = {
				WeakAuras = true,
				SharedMedia = true,
				Blizzard = true,
				Platynator = true,
			},
			browserTitle = "Spark Texture Picker",
			tooltipText = "Type a texture path or click the browse icon to choose the Normal spark preset (Square_FullWhite) or another texture.",
		}
	)

	local sparkAlphaSlider = CreateSlider(content, "Spark Alpha", 0, 1, 0.05, ShiftY(-425))
	sparkAlphaSlider:SetValue(SuperSwingTimerDB.sparkAlpha ~= nil and SuperSwingTimerDB.sparkAlpha or ns.DB_DEFAULTS.sparkAlpha)
	SyncSliderDisplay(sparkAlphaSlider, sparkAlphaSlider:GetValue())

	local sparkColorRow = CreateColorButton(
		content,
		"Spark Color",
		"spark",
		ShiftY(-250),
		{
			allowAlpha = true,
			getColor = function()
				return SuperSwingTimerDB.sparkColor or ns.GetSparkColor() or ns.DB_DEFAULTS.sparkColor
			end,
			applyColor = function(r, g, b, a)
				local texturePath = SuperSwingTimerDB.sparkTexture or ns.DB_DEFAULTS.sparkTexture
				ns.ApplySparkSettings(
					texturePath,
					SuperSwingTimerDB.sparkWidth or ns.DB_DEFAULTS.sparkWidth,
					SuperSwingTimerDB.sparkHeight or ns.DB_DEFAULTS.sparkHeight,
					SuperSwingTimerDB.sparkTextureLayer or ns.DB_DEFAULTS.sparkTextureLayer,
					a,
					{ r = r, g = g, b = b, a = a }
				)
			end,
			tooltipText = "Pick the spark tint and opacity with the color wheel.",
		}
	)

	local sparkLayerRow = CreateCycleRow(
		content,
		"Spark Layer",
		ShiftY(-285),
		ns.TEXTURE_LAYER_OPTIONS,
		function() return SuperSwingTimerDB.sparkTextureLayer or ns.DB_DEFAULTS.sparkTextureLayer end,
		function(layer) ns.ApplySparkTextureLayer(layer) end
	)

	local sparkWidthSlider = CreateSlider(content, "Spark Width", 2, 60, 1, ShiftY(-350))
	sparkWidthSlider:SetValue(SuperSwingTimerDB.sparkWidth or ns.DB_DEFAULTS.sparkWidth)
	SyncSliderDisplay(sparkWidthSlider, sparkWidthSlider:GetValue())

	local sparkHeightSlider = CreateSlider(content, "Spark Height", 2, 90, 1, ShiftY(-400))
	sparkHeightSlider:SetValue(SuperSwingTimerDB.sparkHeight or ns.DB_DEFAULTS.sparkHeight)
	SyncSliderDisplay(sparkHeightSlider, sparkHeightSlider:GetValue())

	local backgroundColorRow = CreateColorButton(
		content,
		"Bar Background Color",
		"barBackground",
		ShiftY(-450),
		{
			allowAlpha = false,
			getColor = function()
				return SuperSwingTimerDB.barBackgroundColor or ns.DB_DEFAULTS.barBackgroundColor
			end,
			applyColor = function(r, g, b)
				local alpha = SuperSwingTimerDB.barBackgroundAlpha ~= nil and SuperSwingTimerDB.barBackgroundAlpha or ns.DB_DEFAULTS.barBackgroundAlpha
				ns.ApplyBarBackgroundColor({ r = r, g = g, b = b, a = alpha })
			end,
			tooltipText = "Pick the bar background tint. Use the alpha slider below to control opacity.",
		}
	)

	local backgroundAlphaSlider = CreateSlider(content, "Bar Background Alpha", 0, 1, 0.05, ShiftY(-500))
	backgroundAlphaSlider:SetValue(SuperSwingTimerDB.barBackgroundAlpha ~= nil and SuperSwingTimerDB.barBackgroundAlpha or ns.DB_DEFAULTS.barBackgroundAlpha)
	SyncSliderDisplay(backgroundAlphaSlider, backgroundAlphaSlider:GetValue())

	local indicatorBlendModeRow = CreateCycleRow(
		content,
		"Indicator Glow Mode",
		ShiftY(-550),
		INDICATOR_BLEND_OPTIONS,
		function() return SuperSwingTimerDB.indicatorBlendMode or ns.DB_DEFAULTS.indicatorBlendMode end,
		function(blendMode)
			ns.ApplyIndicatorBlendMode(blendMode)
		end
	)

	local barBorderColorRow = CreateColorButton(
		content,
		"Bar Border Color",
		"barBorder",
		ShiftY(-600),
		{
			allowAlpha = true,
			getColor = function()
				return SuperSwingTimerDB.barBorderColor or ns.DB_DEFAULTS.barBorderColor
			end,
			applyColor = function(r, g, b, a)
				ns.ApplyBarBorderColor({ r = r, g = g, b = b, a = a })
			end,
			tooltipText = "Pick the bar border tint and opacity with the color wheel.",
		}
	)

	local barBorderSlider = CreateSlider(content, "Bar Border Size", 0, 6, 1, ShiftY(-650))
	barBorderSlider:SetValue(SuperSwingTimerDB.barBorderSize ~= nil and SuperSwingTimerDB.barBorderSize or ns.DB_DEFAULTS.barBorderSize)
	SyncSliderDisplay(barBorderSlider, barBorderSlider:GetValue())
	barBorderSlider:SetScript("OnValueChanged", function(self, value)
		value = math.floor(value + 0.5)
		SyncSliderDisplay(self, value)
		ns.ApplyBarBorderSize(value)
	end)
	mhOhRows[1] = widthSlider
	mhOhRows[2] = heightSlider
	mhOhRows[3] = barTextureRow
	mhOhRows[4] = barLayerRow
	mhOhRows[5] = rangedTextureRow
	mhOhRows[6] = sparkTextureRow
	mhOhRows[7] = sparkAlphaSlider
	mhOhRows[8] = sparkColorRow
	mhOhRows[9] = sparkLayerRow
	mhOhRows[10] = sparkWidthSlider
	mhOhRows[11] = sparkHeightSlider
	mhOhRows[12] = backgroundColorRow
	mhOhRows[13] = backgroundAlphaSlider
	mhOhRows[14] = indicatorBlendModeRow
	mhOhRows[15] = barBorderColorRow
	mhOhRows[16] = barBorderSlider
	SetRowsShown(mhOhRows, not sectionCollapsed.mhOh)
	if mhOhHeader.refresh then
		mhOhHeader.refresh()
	end

	local shamanHeader = CreateSectionHeader(content, "Shaman Weave Assist", -700, {
		rows = shamanRows,
		getCollapsed = function() return sectionCollapsed.shaman end,
		setCollapsed = function(collapsed) sectionCollapsed.shaman = collapsed end,
	})

	local weaveSparkTextureRow = CreateTexturePathRow(
		content,
		"Cast Breakpoint Spark Texture",
		ShiftY(-705),
		{
			mode = "browser",
			label = "Cast Breakpoint Spark Texture",
			yOffset = ShiftY(-705),
			defaultTexture = ns.DB_DEFAULTS.weaveSparkTexture,
			getTexture = function() return SuperSwingTimerDB.weaveSparkTexture or ns.DB_DEFAULTS.weaveSparkTexture end,
			applyTexture = function(texturePath)
				ns.ApplyWeaveSparkSettings(
					texturePath,
					SuperSwingTimerDB.weaveSparkWidth or ns.DB_DEFAULTS.weaveSparkWidth,
					SuperSwingTimerDB.weaveSparkHeight or ns.DB_DEFAULTS.weaveSparkHeight,
					SuperSwingTimerDB.weaveSparkTextureLayer or ns.DB_DEFAULTS.weaveSparkTextureLayer,
					SuperSwingTimerDB.weaveSparkAlpha ~= nil and SuperSwingTimerDB.weaveSparkAlpha or ns.DB_DEFAULTS.weaveSparkAlpha
				)
			end,
			browserDefaultCategory = "WeakAuras",
			browserCategories = {
				WeakAuras = true,
				SharedMedia = true,
				Blizzard = true,
				Platynator = true,
			},
			browserTitle = "Cast Breakpoint Spark Picker",
			tooltipText = "Type a texture path or click the browse icon to choose the cast-breakpoint spark preset (Target Indicator) or another texture.",
		}
	)

	local weaveSparkLayerRow = CreateCycleRow(
		content,
		"Cast Breakpoint Layer",
		ShiftY(-740),
		ns.TEXTURE_LAYER_OPTIONS,
		function() return SuperSwingTimerDB.weaveSparkTextureLayer or ns.DB_DEFAULTS.weaveSparkTextureLayer end,
		function(layer) ns.ApplyWeaveSparkTextureLayer(layer) end
	)

	local weaveSparkWidthSlider = CreateSlider(content, "Cast Spark Width", 2, 60, 1, ShiftY(-775))
	weaveSparkWidthSlider:SetValue(SuperSwingTimerDB.weaveSparkWidth or ns.DB_DEFAULTS.weaveSparkWidth)
	SyncSliderDisplay(weaveSparkWidthSlider, weaveSparkWidthSlider:GetValue())

	local weaveSparkHeightSlider = CreateSlider(content, "Cast Spark Height", 2, 100, 1, ShiftY(-825))
	weaveSparkHeightSlider:SetValue(SuperSwingTimerDB.weaveSparkHeight or ns.DB_DEFAULTS.weaveSparkHeight)
	SyncSliderDisplay(weaveSparkHeightSlider, weaveSparkHeightSlider:GetValue())

	local weaveSparkAlphaSlider = CreateSlider(content, "Cast Spark Alpha", 0, 1, 0.05, ShiftY(-875))
	weaveSparkAlphaSlider:SetValue(SuperSwingTimerDB.weaveSparkAlpha ~= nil and SuperSwingTimerDB.weaveSparkAlpha or ns.DB_DEFAULTS.weaveSparkAlpha)
	SyncSliderDisplay(weaveSparkAlphaSlider, weaveSparkAlphaSlider:GetValue())

	local weaveTriangleTopRow = CreateTexturePathRow(
		content,
		"Upper Marker Texture",
		ShiftY(-925),
		function() return SuperSwingTimerDB.weaveTriangleTopTexture or ns.DB_DEFAULTS.weaveTriangleTopTexture end,
		function(texturePath)
			ns.ApplyWeaveTriangleSettings(
				texturePath,
				SuperSwingTimerDB.weaveTriangleBottomTexture or ns.DB_DEFAULTS.weaveTriangleBottomTexture,
				SuperSwingTimerDB.weaveTriangleSize or ns.DB_DEFAULTS.weaveTriangleSize,
				SuperSwingTimerDB.weaveTriangleGap ~= nil and SuperSwingTimerDB.weaveTriangleGap or ns.DB_DEFAULTS.weaveTriangleGap,
				SuperSwingTimerDB.weaveTriangleTextureLayer or ns.DB_DEFAULTS.weaveTriangleTextureLayer,
				SuperSwingTimerDB.weaveTriangleAlpha ~= nil and SuperSwingTimerDB.weaveTriangleAlpha or ns.DB_DEFAULTS.weaveTriangleAlpha
			)
		end
	)

	local weaveTriangleBottomRow = CreateTexturePathRow(
		content,
		"Lower Marker Texture",
		ShiftY(-960),
		function() return SuperSwingTimerDB.weaveTriangleBottomTexture or ns.DB_DEFAULTS.weaveTriangleBottomTexture end,
		function(texturePath)
			ns.ApplyWeaveTriangleSettings(
				SuperSwingTimerDB.weaveTriangleTopTexture or ns.DB_DEFAULTS.weaveTriangleTopTexture,
				texturePath,
				SuperSwingTimerDB.weaveTriangleSize or ns.DB_DEFAULTS.weaveTriangleSize,
				SuperSwingTimerDB.weaveTriangleGap ~= nil and SuperSwingTimerDB.weaveTriangleGap or ns.DB_DEFAULTS.weaveTriangleGap,
				SuperSwingTimerDB.weaveTriangleTextureLayer or ns.DB_DEFAULTS.weaveTriangleTextureLayer,
				SuperSwingTimerDB.weaveTriangleAlpha ~= nil and SuperSwingTimerDB.weaveTriangleAlpha or ns.DB_DEFAULTS.weaveTriangleAlpha
			)
		end
	)

	local weaveTriangleLayerRow = CreateCycleRow(
		content,
		"Marker Layer",
		ShiftY(-995),
		ns.TEXTURE_LAYER_OPTIONS,
		function() return SuperSwingTimerDB.weaveTriangleTextureLayer or ns.DB_DEFAULTS.weaveTriangleTextureLayer end,
		function(layer)
			ns.ApplyWeaveTriangleSettings(
				SuperSwingTimerDB.weaveTriangleTopTexture or ns.DB_DEFAULTS.weaveTriangleTopTexture,
				SuperSwingTimerDB.weaveTriangleBottomTexture or ns.DB_DEFAULTS.weaveTriangleBottomTexture,
				SuperSwingTimerDB.weaveTriangleSize or ns.DB_DEFAULTS.weaveTriangleSize,
				SuperSwingTimerDB.weaveTriangleGap ~= nil and SuperSwingTimerDB.weaveTriangleGap or ns.DB_DEFAULTS.weaveTriangleGap,
				layer,
				SuperSwingTimerDB.weaveTriangleAlpha ~= nil and SuperSwingTimerDB.weaveTriangleAlpha or ns.DB_DEFAULTS.weaveTriangleAlpha
			)
		end
	)

	local weaveTriangleSizeSlider = CreateSlider(content, "Marker Size", 6, 24, 1, ShiftY(-1030))
	weaveTriangleSizeSlider:SetValue(SuperSwingTimerDB.weaveTriangleSize or ns.DB_DEFAULTS.weaveTriangleSize)
	SyncSliderDisplay(weaveTriangleSizeSlider, weaveTriangleSizeSlider:GetValue())

	local weaveTriangleGapSlider = CreateSlider(content, "Marker Gap", 0, 6, 1, ShiftY(-1080))
	weaveTriangleGapSlider:SetValue(SuperSwingTimerDB.weaveTriangleGap ~= nil and SuperSwingTimerDB.weaveTriangleGap or ns.DB_DEFAULTS.weaveTriangleGap)
	SyncSliderDisplay(weaveTriangleGapSlider, weaveTriangleGapSlider:GetValue())

	local weaveTriangleAlphaSlider = CreateSlider(content, "Marker Alpha", 0, 1, 0.05, ShiftY(-1130))
	weaveTriangleAlphaSlider:SetValue(SuperSwingTimerDB.weaveTriangleAlpha ~= nil and SuperSwingTimerDB.weaveTriangleAlpha or ns.DB_DEFAULTS.weaveTriangleAlpha)
	SyncSliderDisplay(weaveTriangleAlphaSlider, weaveTriangleAlphaSlider:GetValue())
	shamanRows[1] = weaveSparkTextureRow
	shamanRows[2] = weaveSparkLayerRow
	shamanRows[3] = weaveSparkWidthSlider
	shamanRows[4] = weaveSparkHeightSlider
	shamanRows[5] = weaveSparkAlphaSlider
	shamanRows[6] = weaveTriangleTopRow
	shamanRows[7] = weaveTriangleBottomRow
	shamanRows[8] = weaveTriangleLayerRow
	shamanRows[9] = weaveTriangleSizeSlider
	shamanRows[10] = weaveTriangleGapSlider
	shamanRows[11] = weaveTriangleAlphaSlider
	SetRowsShown(shamanRows, not sectionCollapsed.shaman)
	if shamanHeader.refresh then
		shamanHeader.refresh()
	end

	local generalHeader = CreateSectionHeader(content, "General Behavior", -1290, {
		rows = generalRows,
		getCollapsed = function() return sectionCollapsed.general end,
		setCollapsed = function(collapsed) sectionCollapsed.general = collapsed end,
	})

	local minimalModeRow = CreateToggleRow(
		content,
		"Minimal Mode",
		ShiftY(-1305),
		function() return SuperSwingTimerDB.minimalMode == true end,
		function(enabled) ns.ApplyMinimalMode(enabled) end
	)

	local lockBarsRow = CreateToggleRow(
		content,
		"Lock / Unlock Bars",
		ShiftY(-1335),
		function() return SuperSwingTimerDB.lockBars == true end,
		function(enabled) SuperSwingTimerDB.lockBars = enabled end
	)
	local testBarsRow = CreateActionRow(
		content,
		"Test Bars",
		"Preview 8s",
		ShiftY(-1365),
		function()
			StartBarTestPreview(8)
		end,
		"Temporarily show the bars for eight seconds so you can reposition them when unlocked."
	)
	generalRows[1] = minimalModeRow
	generalRows[2] = lockBarsRow
	generalRows[3] = testBarsRow
	SetRowsShown(generalRows, not sectionCollapsed.general)
	if generalHeader.refresh then
		generalHeader.refresh()
	end

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
			SuperSwingTimerDB.sparkAlpha ~= nil and SuperSwingTimerDB.sparkAlpha or ns.DB_DEFAULTS.sparkAlpha
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
			SuperSwingTimerDB.sparkAlpha ~= nil and SuperSwingTimerDB.sparkAlpha or ns.DB_DEFAULTS.sparkAlpha
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
			SuperSwingTimerDB.weaveSparkAlpha ~= nil and SuperSwingTimerDB.weaveSparkAlpha or ns.DB_DEFAULTS.weaveSparkAlpha
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
			SuperSwingTimerDB.weaveSparkAlpha ~= nil and SuperSwingTimerDB.weaveSparkAlpha or ns.DB_DEFAULTS.weaveSparkAlpha
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
			SuperSwingTimerDB.weaveTriangleAlpha ~= nil and SuperSwingTimerDB.weaveTriangleAlpha or ns.DB_DEFAULTS.weaveTriangleAlpha
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
			SuperSwingTimerDB.weaveTriangleAlpha ~= nil and SuperSwingTimerDB.weaveTriangleAlpha or ns.DB_DEFAULTS.weaveTriangleAlpha
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
	local colorHeader = CreateSectionHeader(content, "Bar Colors", -1370, {
		rows = colorRowsSection,
		getCollapsed = function() return sectionCollapsed.colors end,
		setCollapsed = function(collapsed) sectionCollapsed.colors = collapsed end,
	})

	local useClassColorsRow = CreateToggleRow(
		content,
		"Use Class Colors",
		ShiftY(-1398),
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

	local yStart = ShiftY(-1430)
	local spacing = -28

	local mhRow     = CreateColorButton(content, "Main Hand Color",  "mh",     yStart, { allowAlpha = true })
	local ohRow     = CreateColorButton(content, "Off Hand Color",   "oh",     yStart + spacing, { allowAlpha = true })
	local rangedRow = CreateColorButton(content, "Ranged Color",     "ranged", yStart + spacing * 2, { allowAlpha = true })
	local sealRow   = CreateColorButton(content, "Seal Breakpoint Line", "sealTwist", yStart + spacing * 3, { allowAlpha = true })

	-- Seal-twist row only visible for Paladins
	if ns.playerClass ~= "PALADIN" then
		sealRow:Hide()
	end
	colorRowsSection[1] = useClassColorsRow
	colorRowsSection[2] = mhRow
	colorRowsSection[3] = ohRow
	colorRowsSection[4] = rangedRow
	if ns.playerClass == "PALADIN" then
		colorRowsSection[5] = sealRow
	end
	SetRowsShown(colorRowsSection, not sectionCollapsed.colors)
	if colorHeader.refresh then
		colorHeader.refresh()
	end

	local weaveFamiliesHeader = CreateSectionHeader(content, "Weave Families", -1680, {
		rows = weaveFamiliesRows,
		getCollapsed = function() return sectionCollapsed.weaveFamilies end,
		setCollapsed = function(collapsed) sectionCollapsed.weaveFamilies = collapsed end,
	})
	local weaveFamiliesDescription = CreateDescriptionText(
		content,
		"Each family below is color-coded to match its spell breakpoint family. Toggle a family off to remove every rank in that family from the weave helper. The tiny upper and lower markers stay attached to the MH swing bar and move with spell haste.",
		-1708
	)

	local weaveFamilyRows = {
		CreateWeaveFamilyRow(content, "LB",  "Lightning Bolt",        -1750),
		CreateWeaveFamilyRow(content, "CL",  "Chain Lightning",       -1778),
		CreateWeaveFamilyRow(content, "HW",  "Healing Wave",          -1806),
		CreateWeaveFamilyRow(content, "LHW", "Lesser Healing Wave",   -1834),
		CreateWeaveFamilyRow(content, "CH",  "Chain Heal",            -1862),
	}

	if ns.playerClass ~= "SHAMAN" then
		weaveFamiliesHeader:Hide()
		weaveFamiliesDescription:Hide()
		for _, row in ipairs(weaveFamilyRows) do
			row:Hide()
		end
	else
		weaveFamiliesRows[1] = weaveFamiliesDescription
		for index, row in ipairs(weaveFamilyRows) do
			weaveFamiliesRows[index + 1] = row
		end
		SetRowsShown(weaveFamiliesRows, not sectionCollapsed.weaveFamilies)
		if weaveFamiliesHeader.refresh then
			weaveFamiliesHeader.refresh()
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
	f.sparkColorRow = sparkColorRow
	f.backgroundColorRow = backgroundColorRow
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
	f.barBorderColorRow = barBorderColorRow
	f.barBorderSlider = barBorderSlider
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
		if panel.sparkColorRow and panel.sparkColorRow.refresh then
			panel.sparkColorRow.refresh()
		end
		if panel.backgroundColorRow and panel.backgroundColorRow.refresh then
			panel.backgroundColorRow.refresh()
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
		panel.backgroundAlphaSlider:SetValue(SuperSwingTimerDB.barBackgroundAlpha ~= nil and SuperSwingTimerDB.barBackgroundAlpha or ns.DB_DEFAULTS.barBackgroundAlpha)
		if panel.barBorderSlider then
			panel.barBorderSlider:SetValue(SuperSwingTimerDB.barBorderSize ~= nil and SuperSwingTimerDB.barBorderSize or ns.DB_DEFAULTS.barBorderSize)
		end
		panel.weaveSparkWidthSlider:SetValue(SuperSwingTimerDB.weaveSparkWidth or ns.DB_DEFAULTS.weaveSparkWidth)
		panel.weaveSparkHeightSlider:SetValue(SuperSwingTimerDB.weaveSparkHeight or ns.DB_DEFAULTS.weaveSparkHeight)
		panel.weaveSparkAlphaSlider:SetValue(SuperSwingTimerDB.weaveSparkAlpha ~= nil and SuperSwingTimerDB.weaveSparkAlpha or ns.DB_DEFAULTS.weaveSparkAlpha)
		panel.weaveTriangleSizeSlider:SetValue(SuperSwingTimerDB.weaveTriangleSize or ns.DB_DEFAULTS.weaveTriangleSize)
		panel.weaveTriangleGapSlider:SetValue(SuperSwingTimerDB.weaveTriangleGap ~= nil and SuperSwingTimerDB.weaveTriangleGap or ns.DB_DEFAULTS.weaveTriangleGap)
		panel.weaveTriangleAlphaSlider:SetValue(SuperSwingTimerDB.weaveTriangleAlpha ~= nil and SuperSwingTimerDB.weaveTriangleAlpha or ns.DB_DEFAULTS.weaveTriangleAlpha)
		if panel.minimalModeRow and panel.minimalModeRow.refresh then
			panel.minimalModeRow.refresh()
		end
		if panel.lockBarsRow and panel.lockBarsRow.refresh then
			panel.lockBarsRow.refresh()
		end
		if panel.useClassColorsRow and panel.useClassColorsRow.refresh then
			panel.useClassColorsRow.refresh()
		end
		if panel.sparkColorRow and panel.sparkColorRow.refresh then
			panel.sparkColorRow.refresh()
		end
		if panel.backgroundColorRow and panel.backgroundColorRow.refresh then
			panel.backgroundColorRow.refresh()
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
		if panel.barBorderColorRow and panel.barBorderColorRow.refresh then
			panel.barBorderColorRow.refresh()
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
	SuperSwingTimerDB.barBackgroundColor = {
		r = ns.DB_DEFAULTS.barBackgroundColor.r,
		g = ns.DB_DEFAULTS.barBackgroundColor.g,
		b = ns.DB_DEFAULTS.barBackgroundColor.b,
		a = ns.DB_DEFAULTS.barBackgroundColor.a,
	}
	SuperSwingTimerDB.barBorderColor = {
		r = ns.DB_DEFAULTS.barBorderColor.r,
		g = ns.DB_DEFAULTS.barBorderColor.g,
		b = ns.DB_DEFAULTS.barBorderColor.b,
		a = ns.DB_DEFAULTS.barBorderColor.a,
	}
	SuperSwingTimerDB.sparkAlpha = ns.DB_DEFAULTS.sparkAlpha
	SuperSwingTimerDB.sparkColor = {
		r = ns.DB_DEFAULTS.sparkColor.r,
		g = ns.DB_DEFAULTS.sparkColor.g,
		b = ns.DB_DEFAULTS.sparkColor.b,
		a = ns.DB_DEFAULTS.sparkColor.a,
	}
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
	ns.ApplySparkSettings(ns.DB_DEFAULTS.sparkTexture, ns.DB_DEFAULTS.sparkWidth, ns.DB_DEFAULTS.sparkHeight, ns.DB_DEFAULTS.sparkTextureLayer, ns.DB_DEFAULTS.sparkColor.a, ns.DB_DEFAULTS.sparkColor)
	ns.ApplySparkTextureLayer(ns.DB_DEFAULTS.sparkTextureLayer)
	ns.ApplyIndicatorBlendMode(ns.DB_DEFAULTS.indicatorBlendMode)
	ns.ApplyWeaveSparkSettings(ns.DB_DEFAULTS.weaveSparkTexture, ns.DB_DEFAULTS.weaveSparkWidth, ns.DB_DEFAULTS.weaveSparkHeight, ns.DB_DEFAULTS.weaveSparkTextureLayer, ns.DB_DEFAULTS.weaveSparkAlpha)
	ns.ApplyWeaveSparkTextureLayer(ns.DB_DEFAULTS.weaveSparkTextureLayer)
	ns.ApplyWeaveTriangleSettings(
		ns.DB_DEFAULTS.weaveTriangleTopTexture,
		ns.DB_DEFAULTS.weaveTriangleBottomTexture,
		ns.DB_DEFAULTS.weaveTriangleSize,
		ns.DB_DEFAULTS.weaveTriangleGap,
		ns.DB_DEFAULTS.weaveTriangleTextureLayer,
		ns.DB_DEFAULTS.weaveTriangleAlpha
	)
	ns.ApplyWeaveMarkerLayer(ns.DB_DEFAULTS.weaveMarkerLayer)
	ns.ApplyBarBackgroundColor(ns.DB_DEFAULTS.barBackgroundColor)
	ns.ApplyBarBorderColor(ns.DB_DEFAULTS.barBorderColor)
	ns.ApplyBarBorderSize(ns.DB_DEFAULTS.barBorderSize)
	ns.ApplySparkColor(ns.DB_DEFAULTS.sparkColor)
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
	if panel and panel.sparkColorRow and panel.sparkColorRow.refresh then
		panel.sparkColorRow.refresh()
	end
	if panel and panel.backgroundColorRow and panel.backgroundColorRow.refresh then
		panel.backgroundColorRow.refresh()
	end
	if panel and panel.barBorderColorRow and panel.barBorderColorRow.refresh then
		panel.barBorderColorRow.refresh()
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
	if panel and panel.barBorderSlider then
		panel.barBorderSlider:SetValue(ns.DB_DEFAULTS.barBorderSize)
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

