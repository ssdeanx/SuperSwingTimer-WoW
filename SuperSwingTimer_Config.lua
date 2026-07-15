local _, ns = ...
---@diagnostic disable: undefined-field
local CreateFrame = rawget(_G, "CreateFrame")
local UIParent = rawget(_G, "UIParent")
local ColorPickerFrame = rawget(_G, "ColorPickerFrame")
local GameTooltip = rawget(_G, "GameTooltip")
local C_Timer = rawget(_G, "C_Timer")
local UIDropDownMenu_AddButton = _G.UIDropDownMenu_AddButton or function() end
local UIDropDownMenu_CreateInfo = _G.UIDropDownMenu_CreateInfo or function() return {} end
local UIDropDownMenu_Initialize = _G.UIDropDownMenu_Initialize or function() end
local UIDropDownMenu_SetText = _G.UIDropDownMenu_SetText or function() end
local UIDropDownMenu_SetWidth = _G.UIDropDownMenu_SetWidth or function() end
local ToggleDropDownMenu = rawget(_G, "ToggleDropDownMenu") or function() end
local strtrim = rawget(_G, "strtrim")
local BackdropTemplateMixin = rawget(_G, "BackdropTemplateMixin")

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


local function GetOptionalBackdropTemplate(template)
    if not BackdropTemplateMixin then
        return template
    end

    if template and template ~= "" then
        return string.format("%s,BackdropTemplate", template)
    end

    return "BackdropTemplate"
end

local function CreateOptionalBackdropFrame(frameType, name, parent, template)
    return CreateFrame(frameType, name, parent, GetOptionalBackdropTemplate(template))
end

local function SetFrameBackdrop(frame, backdropInfo, backgroundColor, borderColor)
    if not frame or not frame.SetBackdrop then
        return
    end

    frame:SetBackdrop(backdropInfo)
    if backgroundColor and frame.SetBackdropColor then
        frame:SetBackdropColor(backgroundColor[1], backgroundColor[2], backgroundColor[3], backgroundColor[4])
    end
    if borderColor and frame.SetBackdropBorderColor then
        frame:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    end
end

local function EnableScrollFrameMouseWheel(scrollFrame, step)
    if not scrollFrame then
        return
    end

    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function (self, delta)
        local current = self:GetVerticalScroll() or 0
        local child = self:GetScrollChild()
        local maxRange = 0
        if child then
            maxRange = math.max((child:GetHeight() or 0) - (self:GetHeight() or 0), 0)
        end
        local nextScroll = math.max(0, math.min(current - (delta * (step or 32)), maxRange))
        self:SetVerticalScroll(nextScroll)
    end)
end

local INDICATOR_BLEND_OPTIONS = { { label = "Glow", value = "ADD" }, { label = "Opaque", value = "BLEND" } }

local TEXTURE_BROWSER_CATEGORY_CHOICES = {
    { label = "All", value = "All" }, { label = "Shapes", value = "WeakAuras" },
    { label = "SharedMedia", value = "SharedMedia" }, { label = "Blizzard", value = "Blizzard" },
    { label = "Platynator", value = "Platynator" }
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

    frame:HookScript("OnEnter", function (self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title or "", 1, 1, 1)
        if text and text ~= "" then
            GameTooltip:AddLine(text, 0.9, 0.9, 0.9, true)
        end
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function ()
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

    local showAdvanced = SuperSwingTimerDB and SuperSwingTimerDB.showAdvanced == true

    for _, row in ipairs(rows) do
        if row then
            if row.isAdvanced and not showAdvanced then
                if row.SetShown then
                    row:SetShown(false)
                elseif row.Hide then
                    row:Hide()
                end
            else
                if row.SetShown then
                    row:SetShown(shown)
                elseif shown and row.Show then
                    row:Show()
                elseif not shown and row.Hide then
                    row:Hide()
                end
            end
        end
    end
end

local function RememberRowLayoutInsets(row)
    if not row or row._layoutInsetsStored then
        return
    end

    local leftInset = nil
    local rightInset = nil
    local pointCount = row.GetNumPoints and row:GetNumPoints() or 0
    for index = 1, pointCount do
        local _, _, relativePoint, xOfs = row:GetPoint(index)
        if relativePoint == "TOPLEFT" then
            leftInset = xOfs
        elseif relativePoint == "TOPRIGHT" then
            rightInset = -(xOfs or 0)
        end
    end

    row._layoutLeftInset = leftInset or 20
    row._layoutRightInset = rightInset
    row._layoutInsetsStored = true
end

local function GetRowLayoutHeight(row)
    if not row then
        return 0
    end

    if row.layoutHeight and row.layoutHeight > 0 then
        return row.layoutHeight
    end

    local height = row.GetHeight and row:GetHeight() or 0
    if row.text and row.text.GetStringHeight then
        height = math.max(height, row.text:GetStringHeight() + 8)
    end

    return height
end

local function PositionRowAtY(parent, row, topY)
    if not parent or not row then
        return
    end

    RememberRowLayoutInsets(row)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", row._layoutLeftInset or 20, topY)
    if row._layoutRightInset ~= nil then
        row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -(row._layoutRightInset or 20), topY)
    end
end

local function PositionRowBetween(parent, row, leftX, rightX, topY)
    if not parent or not row then
        return
    end

    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", leftX, topY)
    row:SetPoint("TOPRIGHT", parent, "TOPLEFT", rightX, topY)
end

local function SetRowClassRequirement(row, classToken)
    if row then
        row.requiredClass = classToken
    end
    return row
end

local function AppendRow(rows, row)
    if row then
        rows[#rows + 1] = row
    end
    return row
end

local BAR_COLOR_KEYS = { "mh", "oh", "ranged" }

local function UsesClassColorToggle(colorKey)
    for _, key in ipairs(BAR_COLOR_KEYS) do
        if key == colorKey then
            return true
        end
    end

    return false
end

local function CopyColor(color, fallback)
    local source = color or fallback or { r = 1, g = 1, b = 1, a = 1 }
    return { r = source.r or 1, g = source.g or 1, b = source.b or 1, a = source.a ~= nil and source.a or 1 }
end

local function SavePreClassColorState()
    if not SuperSwingTimerDB then
        return
    end

    SuperSwingTimerDB.colors = SuperSwingTimerDB.colors or {}
    SuperSwingTimerDB.preClassColors = {}
    for _, key in ipairs(BAR_COLOR_KEYS) do
        local current = SuperSwingTimerDB.colors[key] or (ns.DB_DEFAULTS.colors and ns.DB_DEFAULTS.colors[key])
        SuperSwingTimerDB.preClassColors[key] = CopyColor(current, ns.DB_DEFAULTS.colors and ns.DB_DEFAULTS.colors[key])
    end

    local sparkColor = SuperSwingTimerDB.sparkColor or ns.GetSparkColor() or ns.DB_DEFAULTS.sparkColor
    SuperSwingTimerDB.preClassSparkColor = CopyColor(sparkColor, ns.DB_DEFAULTS.sparkColor)
end

local function RestoreColorsAfterClassToggleDisabled()
    if not SuperSwingTimerDB then
        return
    end

    SuperSwingTimerDB.colors = SuperSwingTimerDB.colors or {}

    local restoredFromBackup = false
    if SuperSwingTimerDB.preClassColors then
        for _, key in ipairs(BAR_COLOR_KEYS) do
            local saved = SuperSwingTimerDB.preClassColors[key]
            if saved then
                SuperSwingTimerDB.colors[key] = CopyColor(saved, ns.DB_DEFAULTS.colors and ns.DB_DEFAULTS.colors[key])
                restoredFromBackup = true
            end
        end
    end

    if SuperSwingTimerDB.preClassSparkColor then
        SuperSwingTimerDB.sparkColor = CopyColor(SuperSwingTimerDB.preClassSparkColor, ns.DB_DEFAULTS.sparkColor)
        restoredFromBackup = true
    end

    SuperSwingTimerDB.preClassColors = nil
    SuperSwingTimerDB.preClassSparkColor = nil

    if restoredFromBackup then
        return
    end
end

-- ============================================================
-- Bar preview: show bars while config panel is open
-- ============================================================
local function ShowBarPreview()
    if ns.UpdateOHBar then
        ns.UpdateOHBar()
    end
    ns.ApplyBarTexture(ns.GetBarTexture(), ns.GetBarTextureLayer())
    ns.ApplyRangedBarTexture(ns.GetRangedBarTexture(), ns.GetBarTextureLayer())
    ns.ApplySparkSettings(
        ns.GetSparkTexture(), ns.GetSparkWidth(), ns.GetSparkHeight(), ns.GetSparkTextureLayer(), ns.GetSparkAlpha()
    )
    ns.ApplyBarBackgroundColor(ns.GetBarBackgroundColor())
    ns.ApplyBarBorderColor(ns.GetBarBorderColor())
    ns.ApplyBarBorderSize(ns.GetBarBorderSize())
    ns.ApplyMinimalMode(ns.IsMinimalMode())
    ns.ApplyBarColors()
    ns.ApplyIndicatorBlendMode(ns.GetIndicatorBlendMode())
    ns.ApplyVisibility()
    local bars = { ns.enemyBar, ns.mhBar, ns.ohBar, ns.rangedBar, ns.hunterCastBar }
    for _, bar in ipairs(bars) do
        if bar then
            bar:SetAlpha(1)
            bar:SetMinMaxValues(0, 1)
            bar:SetValue(1)
            if ns.RefreshBarSparkPosition then
                ns.RefreshBarSparkPosition(bar, 1)
            end
        end
    end
    if ns.UpdateRogueEnergyTickVisual then
        ns.UpdateRogueEnergyTickVisual()
    end
    if ns.UpdateRogueComboPointVisual then
        ns.UpdateRogueComboPointVisual()
    end
    if ns.UpdateRogueSliceAndDiceVisual then
        ns.UpdateRogueSliceAndDiceVisual()
    end
end

local function HideBarPreview()
    if ns.barTestActive then
        return
    end
    if ns.ApplyVisibility then
        ns.ApplyVisibility()
        return
    end
    -- Fallback only if the shared visibility helper is unavailable.
    local bars = { ns.enemyBar, ns.mhBar, ns.ohBar, ns.rangedBar, ns.hunterCastBar }
    for _, bar in ipairs(bars) do
        if bar then bar:SetAlpha(0) end
    end
    if ns.UpdateRogueEnergyTickVisual then
        ns.UpdateRogueEnergyTickVisual()
    end
    if ns.UpdateRogueComboPointVisual then
        ns.UpdateRogueComboPointVisual()
    end
    if ns.UpdateRogueSliceAndDiceVisual then
        ns.UpdateRogueSliceAndDiceVisual()
    end
end

-- ------------------------------------------------------------
-- Animate test bars during barTestActive — drives each bar
-- through a separate swing cycle so they move like real timers.
-- ------------------------------------------------------------
local function AnimateTestBars()
    if not ns.barTestStartTime then return end
    local now = ns.GetAlignedTime()
    local t = now - ns.barTestStartTime

    local function animateOne(bar, period, offset)
        if not bar then return end
        local phase = ((t + offset) % period) / period
        local val = math.min(math.max(phase, 0), 1)
        bar:SetValue(val)
        if ns.RefreshBarSparkPosition then
            ns.RefreshBarSparkPosition(bar, val)
        end
    end

    animateOne(ns.mhBar, 3.6, 0)
    animateOne(ns.ohBar, 2.4, 0.8)
    animateOne(ns.rangedBar, 2.8, 1.5)
    animateOne(ns.enemyBar, 2.2, 0.3)
    animateOne(ns.hunterCastBar, 1.5, 2.0)
end

local function StartBarTestPreview(duration)
    duration = tonumber(duration) or 16
    ns.barTestActive = true
    ns.barTestStartTime = ns.GetAlignedTime()
    if ns.barTestTimer and ns.barTestTimer.Cancel then
        ns.barTestTimer:Cancel()
        ns.barTestTimer = nil
    end
    ShowBarPreview()
    if panel and panel.Hide then
        panel:Hide()
    end
    if C_Timer and C_Timer.NewTimer then
        ns.barTestTimer = C_Timer.NewTimer(duration, function ()
            ns.barTestActive = false
            ns.barTestStartTime = nil
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
        swatchFunc = function ()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = allowAlpha and (ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha() or c.a or 1)
                or 1
            Commit(r, g, b, a)
        end,
        cancelFunc = function (prev)
            if prev then
                Commit(prev.r, prev.g, prev.b, allowAlpha and (prev.a or 1) or 1)
            else
                Commit(c.r or 1, c.g or 1, c.b or 1, allowAlpha and (c.a or 1) or 1)
            end
        end
    }

    if allowAlpha then
        info.opacityFunc = function ()
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
local function CreateLabeledSliderRow(parent, label, minVal, maxVal, step, yOffset, options)
    options = options or {}
    local leftInset = options.leftInset or 20
    local rightInset = options.rightInset or 20
    local valueBoxWidth = options.valueBoxWidth or 58
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", leftInset, yOffset)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -rightInset, yOffset)
    row:SetHeight(options.rowHeight or 84)
    row.layoutHeight = row:GetHeight()
    row:EnableMouse(true)
    row.hover = AddRowHoverHighlight(row)

    local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    text:SetPoint("TOPRIGHT", row, "TOPRIGHT", -(valueBoxWidth + 12), 0)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetText(label)
    if text.SetTextColor then
        text:SetTextColor(1, 0.82, 0.05, 1)
    end
    row.text = text

    local slider = CreateFrame("Slider", nil, row, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -30)
    slider:SetPoint("TOPRIGHT", row, "TOPRIGHT", -(valueBoxWidth + 12), -30)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetHeight(16)
    if slider.SetFrameLevel and row.GetFrameLevel then
        slider:SetFrameLevel(row:GetFrameLevel() + 2)
    end
    if slider.Text then
        slider.Text:SetText("")
    end
    if slider.Low then
        slider.Low:SetText(FormatSliderValue(step, minVal))
        slider.Low:ClearAllPoints()
        slider.Low:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", -2, 0)
    end
    if slider.High then
        slider.High:SetText(FormatSliderValue(step, maxVal))
        slider.High:ClearAllPoints()
        slider.High:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 2, 0)
    end

    -- Slider track visuals (shared by every slider row).
    -- Render in a dedicated frame level so the track is always visible in Classic/TBC
    -- clients where OptionsSliderTemplate internals can mask BACKGROUND textures.
    local trackLayer = CreateFrame("Frame", nil, row)
    trackLayer:SetPoint("LEFT", slider, "LEFT", -1, 0)
    trackLayer:SetPoint("RIGHT", slider, "RIGHT", 1, 0)
    trackLayer:SetHeight(6)
    if trackLayer.SetFrameLevel and row.GetFrameLevel then
        trackLayer:SetFrameLevel(row:GetFrameLevel() + 1)
    end

    local trackShadow = trackLayer:CreateTexture(nil, "ARTWORK", nil, 0)
    trackShadow:SetAllPoints(trackLayer)
    trackShadow:SetColorTexture(0.02, 0.02, 0.02, 1)

    local trackBg = trackLayer:CreateTexture(nil, "ARTWORK", nil, 1)
    trackBg:SetPoint("TOPLEFT", trackLayer, "TOPLEFT", 1, -1)
    trackBg:SetPoint("BOTTOMRIGHT", trackLayer, "BOTTOMRIGHT", -1, 1)
    trackBg:SetColorTexture(0.32, 0.32, 0.32, 0.95)

    row.trackLayer = trackLayer
    row.trackShadow = trackShadow
    row.trackBg = trackBg

    local valueBox = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    valueBox:SetSize(valueBoxWidth, 20)
    valueBox:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, -24)
    valueBox:SetAutoFocus(false)
    valueBox:SetMaxLetters(options.maxLetters or 8)
    valueBox:SetJustifyH("CENTER")

    row.sliderWidget = slider
    row.valueBox = valueBox
    row.valueText = nil
    row.formatValue = function (value)
        return FormatSliderValue(step, value)
    end
    row.GetValue = function (self)
        return self.sliderWidget:GetValue()
    end
    row.SetValue = function (self, value)
        self.sliderWidget:SetValue(value)
    end
    row.SetScript = function (self, scriptType, handler)
        if scriptType == "OnValueChanged" then
            self.sliderWidget:SetScript(scriptType, function (_, value, ...)
                handler(self, value, ...)
            end)
        else
            self.sliderWidget:SetScript(scriptType, handler)
        end
    end

    valueBox:SetScript("OnEnterPressed", function (self)
        local parsed = NormalizeSliderValue(self:GetText(), minVal, maxVal, step)
        if parsed ~= nil then
            row:SetValue(parsed)
        end
        self:ClearFocus()
        SyncSliderDisplay(row, row:GetValue())
    end)
    valueBox:SetScript("OnEscapePressed", function (self)
        self:ClearFocus()
        SyncSliderDisplay(row, row:GetValue())
    end)
    valueBox:SetScript("OnEditFocusGained", function (self)
        self:HighlightText()
    end)
    valueBox:SetScript("OnEditFocusLost", function (self)
        SyncSliderDisplay(row, row:GetValue())
    end)

    local sliderTooltip = options.tooltipText or string.format("Drag or type a value to change %s.", label)
    AddControlTooltip(row, label, sliderTooltip)
    AddControlTooltip(valueBox, label, string.format("Type a value for %s.", label))
    SyncSliderDisplay(row, row:GetValue())

    if ns._panelSearchAdder then ns._panelSearchAdder(row, label) end
    return row
end

local function CreateSlider(parent, label, minVal, maxVal, step, yOffset, options)
    options = options or {}
    return CreateLabeledSliderRow(parent, label, minVal, maxVal, step, yOffset, {
        leftInset = 20,
        rightInset = 20,
        valueBoxWidth = 58,
        maxLetters = 8,
        rowHeight = 72,
        tooltipText = options.tooltipText
    })
end

-- ------------------------------------------------------------
-- Compact slider now reuses the same readable full-width row pattern.
-- ------------------------------------------------------------
local function CreateCompactSlider(parent, label, minVal, maxVal, step, yOffset, leftInset, rightInset, options)
    options = options or {}
    return CreateLabeledSliderRow(parent, label, minVal, maxVal, step, yOffset, {
        leftInset = 20,
        rightInset = 20,
        valueBoxWidth = 52,
        maxLetters = 6,
        rowHeight = 72,
        tooltipText = options.tooltipText
    })
end

local function CreateColorButton(parent, label, colorKey, yOffset, options)
    options = options or {}
    local leftInset = options.leftInset or 20
    local rightInset = options.rightInset or 20
    local compactLayout = options.compact == true
    local rowHeight = options.rowHeight or (compactLayout and 32 or 58)
    local buttonWidth = options.buttonWidth or 180
    local getColor = options.getColor
        or function ()
            return ns.GetBarColor(colorKey)
        end
    local allowAlpha = options.allowAlpha == true
    local tooltipText = options.tooltipText or string.format("Click the swatch button to change the %s color.", label)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", leftInset, yOffset)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -rightInset, yOffset)
    row:SetHeight(rowHeight)
    row.layoutHeight = rowHeight
    row:EnableMouse(true)
    row.hover = AddRowHoverHighlight(row)

    local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    text:SetText(label)
    if text.SetTextColor then
        text:SetTextColor(1, 0.82, 0.05, 1)
    end
    if not compactLayout then
        text:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
        text:SetJustifyH("LEFT")
        text:SetJustifyV("TOP")
    else
        text:SetJustifyH("LEFT")
        text:SetJustifyV("TOP")
    end

    local btn = CreateFrame("Button", nil, row)
    btn:SetSize(buttonWidth, 20)
    if compactLayout then
        btn:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
        text:SetPoint("RIGHT", btn, "LEFT", -12, 0)
    else
        btn:ClearAllPoints()
        btn:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
        btn:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
        btn:SetHeight(24)
    end

    local border = btn:CreateTexture(nil, "BACKGROUND")
    border:SetPoint("TOPLEFT", btn, "TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 1, -1)
    border:SetColorTexture(0.42, 0.42, 0.42, 1)
    btn.border = border

    local previewBase = btn:CreateTexture(nil, "BACKGROUND")
    previewBase:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    previewBase:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    previewBase:SetColorTexture(0.08, 0.08, 0.08, 0.96)
    btn.previewBase = previewBase

    local swatch = btn:CreateTexture(nil, "ARTWORK")
    swatch:SetAllPoints(previewBase)
    local c = getColor()
    if c then
        swatch:SetColorTexture(c.r, c.g, c.b, c.a)
    end
    btn.swatch = swatch
    btn.colorKey = colorKey

    local gloss = btn:CreateTexture(nil, "OVERLAY")
    gloss:SetPoint("TOPLEFT", swatch, "TOPLEFT", 0, 0)
    gloss:SetPoint("TOPRIGHT", swatch, "TOPRIGHT", 0, 0)
    gloss:SetHeight(8)
    gloss:SetColorTexture(1, 1, 1, 0.08)
    btn.gloss = gloss

    -- Color label on the swatch button itself, readable on any fill
    if compactLayout then
        local btnLabel = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        btnLabel:SetPoint("CENTER", btn, "CENTER", 0, 0)
        btnLabel:SetText(label)
        btnLabel:SetJustifyH("CENTER")
        btnLabel:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        btnLabel:SetTextColor(1, 1, 1, 0.9)
        btn.btnLabel = btnLabel

        local function UpdateBtnLabel()
            local color = getColor()
            if color then
                -- Dark backgrounds get white text, light backgrounds get dark text
                local luminance = (color.r or 0) * 0.3 + (color.g or 0) * 0.6 + (color.b or 0) * 0.1
                local textAlpha = compactLayout and 0.85 or 0
                if luminance > 0.5 then
                    btnLabel:SetTextColor(0, 0, 0, textAlpha)
                else
                    btnLabel:SetTextColor(1, 1, 1, textAlpha)
                end
            end
        end
        UpdateBtnLabel()
        btn.UpdateBtnLabel = UpdateBtnLabel
    end

    local function ApplySelectedColor(r, g, b, a)
        local alpha = allowAlpha and (a or 1) or 1
        if options.applyColor then
            options.applyColor(r, g, b, alpha, swatch)
        else
            local isSealTwist = (colorKey == "sealTwist")
            if not isSealTwist and UsesClassColorToggle(colorKey) then
                SuperSwingTimerDB.useClassColors = false
            end
            SuperSwingTimerDB.colors[colorKey] = { r = r, g = g, b = b, a = alpha }
            ns.ApplyBarColors()
            if panel and panel.useClassColorsRow and panel.useClassColorsRow.refresh then
                panel.useClassColorsRow.refresh()
            end
            if panel and panel.colorRows then
                for _, colorRow in ipairs(panel.colorRows) do
                    if colorRow and colorRow.button and colorRow.swatch then
                        local key = colorRow.button.colorKey
                        local effective = ns.GetBarColor(key)
                        if effective then
                            colorRow.swatch:SetColorTexture(effective.r, effective.g, effective.b, effective.a)
                            if colorRow.button.UpdateBtnLabel then colorRow.button.UpdateBtnLabel() end
                        end
                    end
                end
            end
        end
        swatch:SetColorTexture(r, g, b, alpha)
        if btn.UpdateBtnLabel then btn.UpdateBtnLabel() end
    end

    local function Refresh()
        local color = getColor() or { r = 1, g = 1, b = 1, a = 1 }
        swatch:SetColorTexture(color.r or 1, color.g or 1, color.b or 1, color.a or 1)
        if btn.UpdateBtnLabel then btn.UpdateBtnLabel() end
    end

    local function OpenPicker()
        OpenColorPicker({
            getColor = getColor,
            allowAlpha = allowAlpha,
            applyColor = ApplySelectedColor
        })
    end

    btn:SetScript("OnClick", OpenPicker)
    btn:SetScript("OnEnter", function (self)
        if self.border then
            self.border:SetColorTexture(0.82, 0.82, 0.82, 1)
        end
    end)
    btn:SetScript("OnLeave", function (self)
        if self.border then
            self.border:SetColorTexture(0.42, 0.42, 0.42, 1)
        end
    end)
    AddControlTooltip(row, label, tooltipText)

    row:SetScript("OnMouseUp", function (_, button)
        if button == "LeftButton" then
            if btn.IsMouseOver and btn:IsMouseOver() then
                return
            end
            OpenPicker()
        end
    end)

    if ns._panelSearchAdder then ns._panelSearchAdder(row, label) end
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
    table.sort(entries, function (a, b)
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

local function HideTextureBrowserGrid(frame)
    for _, button in ipairs(frame.buttons or {}) do
        button:Hide()
    end
    if frame.listScrollFrame then
        frame.listScrollFrame:Hide()
    end
end

local function CreateTextureBrowserListRow(parent)
    local button = CreateOptionalBackdropFrame("Button", nil, parent)
    button:SetHeight(26)
    SetFrameBackdrop(button, {
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 4,
        edgeSize = 8,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    }, { 0.08, 0.08, 0.08, 0.94 }, { 0.30, 0.30, 0.30, 1 }
    )

    local preview = button:CreateTexture(nil, "BACKGROUND")
    preview:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
    preview:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    preview:SetTexCoord(0.02, 0.98, 0.15, 0.85)
    button.preview = preview

    local shade = button:CreateTexture(nil, "BORDER")
    shade:SetAllPoints(preview)
    shade:SetColorTexture(0, 0, 0, 0.28)
    button.shade = shade

    local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", button, "LEFT", 8, 0)
    label:SetPoint("RIGHT", button, "RIGHT", -8, 0)
    label:SetJustifyH("LEFT")
    label:SetText("")
    if label.SetShadowOffset then
        label:SetShadowOffset(1, -1)
        label:SetShadowColor(0, 0, 0, 1)
    end
    button.label = label

    button:SetScript("OnEnter", function (self)
        if not self.entry then
            return
        end

        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(0.82, 0.82, 0.82, 1)
        end

        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.displayLabel or self.entry.label or self.entry.path or "", 1, 1, 1)
            if self.displayCategory and self.displayCategory ~= "" then
                GameTooltip:AddLine(self.displayCategory, 0.82, 0.82, 0.82)
            end
            if self.displayPath and self.displayPath ~= "" then
                GameTooltip:AddLine(self.displayPath, 0.72, 0.72, 0.72, true)
            end
            GameTooltip:Show()
        end
    end)

    button:SetScript("OnLeave", function (self)
        if GameTooltip then
            GameTooltip:Hide()
        end
        local owner = self.ownerFrame
        if owner and owner.Refresh then
            owner:Refresh()
        end
    end)

    button:SetScript("OnClick", function (self)
        if self.entry and self.ownerFrame then
            self.ownerFrame.pendingTexture = self.entry.path
            if self.ownerFrame.Refresh then
                self.ownerFrame:Refresh()
            end
        end
    end)

    return button
end

local function EnsureTextureBrowserList(frame)
    if frame.listScrollFrame then
        return
    end

    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -80)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -34, 46)
    scrollFrame:SetClipsChildren(true)
    EnableScrollFrameMouseWheel(scrollFrame, 32)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(1, 1)
    scrollFrame:SetScrollChild(content)

    frame.listScrollFrame = scrollFrame
    frame.listContent = content
    frame.listRows = {}
    frame.listRowSpacing = 2
    frame.listRowHeight = 26
    frame.listWidthOffset = 12
    frame.listScrollFrame:Hide()
end

local function RefreshTextureBrowserList(frame, filtered)
    EnsureTextureBrowserList(frame)
    frame.listScrollFrame:Show()

    local content = frame.listContent
    local rowHeight = frame.listRowHeight or 26
    local rowSpacing = frame.listRowSpacing or 2
    local rowStride = rowHeight + rowSpacing
    local contentHeight = math.max(#filtered * rowStride, 1)
    local width = math.max(
        (frame.listScrollFrame:GetWidth() or (frame:GetWidth() - 52)) - (frame.listWidthOffset or 12), 300
    )
    content:SetWidth(width)
    content:SetHeight(contentHeight)

    for index, entry in ipairs(filtered) do
        local row = frame.listRows[index]
        if not row then
            row = CreateTextureBrowserListRow(content)
            row.ownerFrame = frame
            frame.listRows[index] = row
        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -((index - 1) * rowStride))
        row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -((index - 1) * rowStride))
        row:SetHeight(rowHeight)
        row:Show()
        row.entry = entry
        row.displayLabel = (ns.GetTextureDisplayText and ns.GetTextureDisplayText(entry.path)) or entry.label
            or entry.path
        row.displayCategory = (ns.GetTextureBrowserDisplayCategory and ns.GetTextureBrowserDisplayCategory(entry)) or entry.category
            or ""
        row.displayPath = entry.path
        row.preview:SetTexture(entry.path)
        row.label:SetText(row.displayLabel or "")

        local selected = frame.pendingTexture and entry.path == frame.pendingTexture
        if row.SetBackdropBorderColor then
            if selected then
                row:SetBackdropBorderColor(0.95, 0.78, 0.20, 1)
                row:SetBackdropColor(0.14, 0.11, 0.05, 0.95)
            else
                row:SetBackdropBorderColor(0.30, 0.30, 0.30, 1)
                row:SetBackdropColor(0.08, 0.08, 0.08, 0.94)
            end
        end
        if row.shade then
            row.shade:SetColorTexture(0, 0, 0, selected and 0.14 or 0.28)
        end
    end

    for index = #filtered + 1, #(frame.listRows or {}) do
        local row = frame.listRows[index]
        if row then
            row:Hide()
            row.entry = nil
        end
    end
end

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

                local haystack = string.lower(
                    string.format("%s %s %s %s", categoryLabel, displayLabel, entry.label or "", entry.path or "")
                )
                matchesSearch = string.find(haystack, searchText, 1, true) ~= nil
            end
            if matchesSearch then
                filtered[#filtered + 1] = entry
            end
        end
    end

    frame.filteredChoices = filtered
    if frame.layoutMode == "barList" then
        HideTextureBrowserGrid(frame)
        RefreshTextureBrowserList(frame, filtered)
        if frame.noResultsText then
            frame.noResultsText:ClearAllPoints()
            frame.noResultsText:SetPoint("CENTER", frame.listScrollFrame or frame, "CENTER", 0, 0)
            frame.noResultsText:SetShown(#filtered == 0)
        end
        return
    end

    if frame.listScrollFrame then
        frame.listScrollFrame:Hide()
    end
    if frame.noResultsText then
        frame.noResultsText:ClearAllPoints()
        frame.noResultsText:SetPoint("CENTER", frame, "CENTER", 0, -12)
    end
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
    local frame = CreateOptionalBackdropFrame("Frame", "SuperSwingTimerTextureBrowserFrame", UIParent)
    frame:SetSize(660, 580)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetToplevel(true)
    if frame.SetFrameLevel and UIParent and UIParent.GetFrameLevel then
        frame:SetFrameLevel((UIParent:GetFrameLevel() or 0) + 120)
    end
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetScript("OnShow", function (self)
        self:SetFrameStrata("FULLSCREEN_DIALOG")
        self:SetToplevel(true)
        if self.SetFrameLevel and UIParent and UIParent.GetFrameLevel then
            self:SetFrameLevel((UIParent:GetFrameLevel() or 0) + 120)
        end
        self:Raise()
    end)
    SetFrameBackdrop(frame, {
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    }, { 0.06, 0.06, 0.06, 0.98 }, { 0.35, 0.35, 0.35, 1 }
    )
    frame:Hide()

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -12)
    title:SetText("Spark Texture Picker")
    frame.titleText = title

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -3, -3)
    frame.closeButton = close
    frame.layoutMode = "grid"

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
    searchBox:SetScript("OnEnterPressed", function (self)
        self:ClearFocus()
        RefreshTextureBrowser(frame)
    end)
    searchBox:SetScript("OnEscapePressed", function (self)
        self:SetText("")
        self:ClearFocus()
        RefreshTextureBrowser(frame)
    end)
    searchBox:SetScript("OnTextChanged", function (self, userInput)
        if userInput then
            RefreshTextureBrowser(frame)
        end
    end)
    frame.searchBox = searchBox

    if UIDropDownMenu_Initialize and UIDropDownMenu_CreateInfo and UIDropDownMenu_AddButton and UIDropDownMenu_SetText then
        UIDropDownMenu_Initialize(categoryDropdown, function (_, level)
            for _, category in ipairs(frame.categoryChoices) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = category.label
                info.checked = frame.currentCategory == category.value
                info.func = function ()
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
        local button = CreateOptionalBackdropFrame("Button", nil, frame)
        button:SetSize(buttonWidth, buttonHeight)
        SetFrameBackdrop(button, {
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 4,
            edgeSize = 8,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        }, { 0.08, 0.08, 0.08, 0.95 }, { 0.30, 0.30, 0.30, 1 }
        )
        local columnOffset = ((index - 1) % columns) * (buttonWidth + buttonPaddingX)
        local rowOffset = math.floor((index - 1) / columns) * (buttonHeight + buttonPaddingY)
        button:SetPoint("TOPLEFT", frame, "TOPLEFT", startX + columnOffset, startY - rowOffset)
        button:SetScript("OnEnter", function (self)
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
        button:SetScript("OnLeave", function (self)
            if GameTooltip then
                GameTooltip:Hide()
            end
            RefreshTextureBrowser(frame)
        end)
        button:SetScript("OnClick", function (self)
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
    okButton:SetScript("OnClick", function ()
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
    cancelButton:SetScript("OnClick", function ()
        frame:Hide()
    end)
    frame.cancelButton = cancelButton

    frame:SetScript("OnHide", function (self)
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
    frame.layoutMode = (options and options.layoutMode) or "grid"
    frame.applyTexture = applyTexture
    frame.allowedCategories = (options and options.allowedCategories)
        or { WeakAuras = true, SharedMedia = true, Blizzard = true, Platynator = true }
    frame.allowedUsages = options and options.allowedUsages or nil
    frame.textureChoices = GetTextureBrowserEntries(frame.allowedCategories, frame.allowedUsages)
    frame.currentCategory = (options and options.defaultCategory)
        or (frame.layoutMode == "barList" and "All" or "WeakAuras")
    local browserDefaultTexture = (options and options.defaultTexture) or ns.DB_DEFAULTS.sparkTexture
    frame.pendingTexture = NormalizeTexturePath(initialTexture, browserDefaultTexture)
    frame.searchBox:SetText("")
    if frame.layoutMode == "barList" then
        frame:SetSize(500, 560)
    else
        frame:SetSize(660, 580)
    end
    frame:ClearAllPoints()
    if options and options.anchorFrame then
        frame:SetPoint("TOPLEFT", options.anchorFrame, "BOTTOMLEFT", 0, -4)
    else
        frame:SetPoint("CENTER")
    end
    if frame.titleText then
        frame.titleText:SetText(
            (options and options.title) or (frame.layoutMode == "barList" and "Bar Texture Picker"
                    or "Spark Texture Picker")
        )
    end
    if UIDropDownMenu_SetText then
        UIDropDownMenu_SetText(frame.categoryDropdown, GetTextureBrowserCategoryLabel(frame.currentCategory))
    end
    RefreshTextureBrowser(frame)
    if frame.layoutMode == "barList" and frame.listScrollFrame then
        frame.listScrollFrame:SetVerticalScroll(0)
    end
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
    row:SetHeight(68)
    row.layoutHeight = 68
    row:EnableMouse(true)
    row.hover = AddRowHoverHighlight(row)

    local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    text:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetText(label)
    if text.SetTextColor then
        text:SetTextColor(1, 0.82, 0.05, 1)
    end

    local function Refresh()
        local path = getTexture()
        row.currentTexture = path
        local displayText = ns.GetTextureDisplayText and ns.GetTextureDisplayText(path) or path or ""
        if row.preview then
            row.preview:SetTexture(path)
        end
        if row.previewLabel then
            row.previewLabel:SetText(displayText)
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

        -- Inline preview chip (24x16 thumbnail of the current texture)
        local previewChip = row:CreateTexture(nil, "ARTWORK")
        previewChip:SetSize(24, 16)
        previewChip:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -28, 4)
        previewChip:SetTexCoord(0.02, 0.98, 0.15, 0.85)
        -- Subtle border via backdrop frame
        local chipBorder = CreateFrame("Frame", nil, row)
        chipBorder:SetPoint("TOPLEFT", previewChip, "TOPLEFT", -1, 1)
        chipBorder:SetPoint("BOTTOMRIGHT", previewChip, "BOTTOMRIGHT", 1, -1)
        chipBorder:SetFrameLevel(row:GetFrameLevel() + 1)
        SetFrameBackdrop(chipBorder, {
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 4,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        }, nil, { 0.4, 0.4, 0.4, 1 })
        row.previewChip = previewChip
        row.previewChipBorder = chipBorder

        local pathBox = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
        pathBox:SetHeight(20)
        pathBox:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
        pathBox:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -60, 0)
        pathBox:SetAutoFocus(false)
        pathBox:SetMaxLetters(260)
        pathBox:SetScript("OnEnterPressed", function (self)
            local path = NormalizeTexturePath(self:GetText(), defaultTexture)
            applyTexture(path)
            self:ClearFocus()
            Refresh()
            if ns.RefreshTextureRows then
                ns.RefreshTextureRows()
            end
        end)
        pathBox:SetScript("OnEscapePressed", function (self)
            self:ClearFocus()
            Refresh()
        end)
        pathBox:SetScript("OnEditFocusLost", function (self)
            local path = NormalizeTexturePath(self:GetText(), defaultTexture)
            applyTexture(path)
            Refresh()
            if ns.RefreshTextureRows then
                ns.RefreshTextureRows()
            end
        end)
        row.pathBox = pathBox

        local browseButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        browseButton:SetSize(24, 24)
        browseButton:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
        browseButton:SetText("")
        browseButton:SetNormalTexture("Interface\\AddOns\\WeakAuras\\Media\\Textures\\browse.tga")
        browseButton:SetScript("OnClick", function ()
            OpenTextureBrowser(
                getTexture(),
                function (texturePath)
                    applyTexture(NormalizeTexturePath(texturePath, defaultTexture))
                    Refresh()
                    if ns.RefreshTextureRows then
                        ns.RefreshTextureRows()
                    end
                end,
                {
                    defaultTexture = defaultTexture,
                    defaultCategory = options.browserDefaultCategory or "WeakAuras",
                    allowedCategories = options.browserCategories
                        or { WeakAuras = true, SharedMedia = true, Blizzard = true, Platynator = true },
                    title = options.browserTitle or "Spark Texture Picker"
                }
            )
        end)
        row.browseButton = browseButton

        -- Update the preview chip in Refresh
        local origRefresh = Refresh
        Refresh = function ()
            origRefresh()
            local path = getTexture() or ""
            if previewChip and path ~= "" then
                previewChip:SetTexture(path)
            end
        end

        local browserTooltip = options.tooltipText
            or string.format(
                "Type a texture path or click the browse icon to open the spark texture picker for %s.", label
            )
        AddControlTooltip(row, label, browserTooltip)
        row.refresh = Refresh
        Refresh()
        return row
    end

    if options.mode == "barList" then
        local defaultTexture = options.defaultTexture or getTexture() or ns.DB_DEFAULTS.barTexture

        local pickerButton = CreateOptionalBackdropFrame("Button", nil, row)
        pickerButton:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
        pickerButton:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
        pickerButton:SetHeight(24)
        SetFrameBackdrop(pickerButton, {
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 4,
            edgeSize = 8,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        }, { 0.08, 0.08, 0.08, 0.94 }, { 0.30, 0.30, 0.30, 1 }
        )
        row.pickerButton = pickerButton

        local preview = pickerButton:CreateTexture(nil, "BACKGROUND")
        preview:SetPoint("TOPLEFT", pickerButton, "TOPLEFT", 2, -2)
        preview:SetPoint("BOTTOMRIGHT", pickerButton, "BOTTOMRIGHT", -2, 2)
        preview:SetTexCoord(0.02, 0.98, 0.15, 0.85)
        row.preview = preview

        local previewShade = pickerButton:CreateTexture(nil, "BORDER")
        previewShade:SetAllPoints(preview)
        previewShade:SetColorTexture(0, 0, 0, 0.30)
        row.previewShade = previewShade

        local previewLabel = pickerButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        previewLabel:SetPoint("LEFT", pickerButton, "LEFT", 8, 0)
        previewLabel:SetPoint("RIGHT", pickerButton, "RIGHT", -24, 0)
        previewLabel:SetJustifyH("LEFT")
        if previewLabel.SetShadowOffset then
            previewLabel:SetShadowOffset(1, -1)
            previewLabel:SetShadowColor(0, 0, 0, 1)
        end
        row.previewLabel = previewLabel

        local arrow = pickerButton:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        arrow:SetPoint("RIGHT", pickerButton, "RIGHT", -8, 0)
        arrow:SetText("v")
        row.previewArrow = arrow

        pickerButton:SetScript("OnEnter", function (self)
            if self.SetBackdropBorderColor then
                self:SetBackdropBorderColor(0.80, 0.80, 0.80, 1)
            end
        end)
        pickerButton:SetScript("OnLeave", function (self)
            if self.SetBackdropBorderColor then
                self:SetBackdropBorderColor(0.30, 0.30, 0.30, 1)
            end
        end)
        pickerButton:SetScript("OnClick", function (self)
            OpenTextureBrowser(
                getTexture(),
                function (texturePath)
                    applyTexture(NormalizeTexturePath(texturePath, defaultTexture))
                    Refresh()
                    if ns.RefreshTextureRows then
                        ns.RefreshTextureRows()
                    end
                end,
                {
                    defaultTexture = defaultTexture,
                    defaultCategory = options.browserDefaultCategory or "All",
                    allowedCategories = options.browserCategories
                        or { WeakAuras = true, SharedMedia = true, Blizzard = true, Platynator = true },
                    allowedUsages = options.dropdownUsages or { both = true },
                    layoutMode = "barList",
                    title = options.browserTitle or label,
                    anchorFrame = self
                }
            )
        end)

        AddControlTooltip(
            row, label,
            options.tooltipText or string.format(
                    "Click the preview bar to open a full scrolling texture list for %s.", label
                )
        )
        row.refresh = Refresh
        Refresh()
        return row
    end

    local preview = row:CreateTexture(nil, "ARTWORK")
    preview:SetSize(18, 18)
    preview:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 1)
    preview:SetTexture(getTexture())
    row.preview = preview

    local dropdown = CreateFrame("Frame", nil, row, "UIDropDownMenuTemplate")
    dropdown:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, -1)
    if UIDropDownMenu_SetWidth then
        UIDropDownMenu_SetWidth(dropdown, 320)
    end
    row.dropdown = dropdown
    row:SetScript("OnMouseUp", function (_, mouseButton)
        if mouseButton == "LeftButton" and ToggleDropDownMenu then
            if dropdown.IsMouseOver and dropdown:IsMouseOver() then
                return
            end
            ToggleDropDownMenu(1, nil, dropdown, dropdown, 0, 0)
        end
    end)
    AddControlTooltip(
        row, label, string.format("Choose the texture used for %s from the dropdown preview list.", label)
    )
    if ns._panelSearchAdder then ns._panelSearchAdder(row, label) end

    if UIDropDownMenu_Initialize and UIDropDownMenu_AddButton and UIDropDownMenu_CreateInfo then
        UIDropDownMenu_Initialize(dropdown, function (_, level)
            local allowedUsages = options.dropdownUsages or { both = true }
            local library = GetTextureBrowserEntries(options.dropdownCategories, allowedUsages)
            level = level or 1

            local function AddTextureButton(entry)
                local info = UIDropDownMenu_CreateInfo()
                info.text = string.format("[%s] %s", entry.style or "style", entry.label or entry.path)
                info.value = entry.path
                info.icon = entry.path
                info.fontObject = "GameFontNormal"
                info.checked = entry.path == row.currentTexture
                info.func = function ()
                    applyTexture(entry.path)
                    Refresh()
                    if ns.RefreshTextureRows then
                        ns.RefreshTextureRows()
                    end
                end
                UIDropDownMenu_AddButton(info, level)
            end

            if level == 1 then
                local categories = {}
                local catOrder = {}
                for _, entry in ipairs(library) do
                    local cat = entry.category or "Unknown"
                    if not categories[cat] then
                        categories[cat] = {}
                        table.insert(catOrder, cat)
                    end
                    table.insert(categories[cat], entry)
                end
                for _, cat in ipairs(catOrder) do
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = cat .. " (" .. #categories[cat] .. ")"
                    info.hasArrow = true
                    info.notCheckable = true
                    info.value = "CAT:" .. cat
                    UIDropDownMenu_AddButton(info, level)
                end
            elseif level == 2 then
                local val = _G.UIDROPDOWNMENU_MENU_VALUE or ""
                if type(val) == "string" and string.sub(val, 1, 4) == "CAT:" then
                    local targetCat = string.sub(val, 5)
                    local items = {}
                    for _, entry in ipairs(library) do
                        if (entry.category or "Unknown") == targetCat then
                            table.insert(items, entry)
                        end
                    end
                    local pageSize = 20
                    if #items > pageSize then
                        local pages = math.ceil(#items / pageSize)
                        for p = 1, pages do
                            local info = UIDropDownMenu_CreateInfo()
                            info.text = "Page " .. p
                            info.hasArrow = true
                            info.notCheckable = true
                            info.value = "PAGE:" .. targetCat .. ":" .. p
                            UIDropDownMenu_AddButton(info, level)
                        end
                    else
                        for _, entry in ipairs(items) do
                            AddTextureButton(entry)
                        end
                    end
                end
            elseif level == 3 then
                local val = _G.UIDROPDOWNMENU_MENU_VALUE or ""
                if type(val) == "string" and string.sub(val, 1, 5) == "PAGE:" then
                    local targetCat, pageStr = string.match(val, "^PAGE:(.-):(%d+)$")
                    local targetPage = tonumber(pageStr) or 1
                    local items = {}
                    for _, entry in ipairs(library) do
                        if (entry.category or "Unknown") == targetCat then
                            table.insert(items, entry)
                        end
                    end
                    local pageSize = 20
                    local startIdx = (targetPage - 1) * pageSize + 1
                    local endIdx = math.min(targetPage * pageSize, #items)
                    for i = startIdx, endIdx do
                        AddTextureButton(items[i])
                    end
                end
            end
        end)
    end

    row.refresh = Refresh
    Refresh()
    return row
end

local function CreateCycleRow(parent, label, yOffset, options, getValue, applyValue, tooltipText)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -20, yOffset)
    row:SetHeight(62)
    row.layoutHeight = 62
    row:EnableMouse(true)
    row.hover = AddRowHoverHighlight(row)

    local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    text:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetText(label)
    if text.SetTextColor then
        text:SetTextColor(1, 0.82, 0.05, 1)
    end

    local dropdown = CreateFrame("Frame", nil, row, "UIDropDownMenuTemplate")
    dropdown:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, -1)
    if UIDropDownMenu_SetWidth then
        UIDropDownMenu_SetWidth(dropdown, 220)
    end

    local function Refresh()
        if UIDropDownMenu_SetText then
            UIDropDownMenu_SetText(dropdown, GetOptionLabel(options, getValue()))
        end
    end

    if UIDropDownMenu_Initialize and UIDropDownMenu_AddButton and UIDropDownMenu_CreateInfo then
        UIDropDownMenu_Initialize(dropdown, function (_, level)
            local currentValue = getValue()
            for _, option in ipairs(options) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = option.label
                info.value = option.value
                info.checked = option.value == currentValue
                info.func = function ()
                    applyValue(option.value)
                    Refresh()
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end)
    end

    row.dropdown = dropdown
    row:SetScript("OnMouseUp", function (_, mouseButton)
        if mouseButton == "LeftButton" and ToggleDropDownMenu then
            if dropdown.IsMouseOver and dropdown:IsMouseOver() then
                return
            end
            ToggleDropDownMenu(1, nil, dropdown, dropdown, 0, 0)
        end
    end)
    if ns._panelSearchAdder then ns._panelSearchAdder(row, label) end
    local dropdownTooltip = tooltipText or string.format(
        "Choose the %s option from the dropdown. The full list shows the real WoW draw layers and modes.", label
    )
    AddControlTooltip(row, label, dropdownTooltip)
    row.refresh = Refresh
    Refresh()
    return row
end

local function CreateToggleRow(parent, label, yOffset, getValue, applyValue, options)
    options = options or {}
    local leftInset = options.leftInset or 20
    local rightInset = options.rightInset or 20
    local compactLayout = options.compact == true
    local rowHeight = options.rowHeight or (compactLayout and 40 or 56)
    local tooltipText = options.tooltipText or string.format("Toggle %s on or off.", label)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", leftInset, yOffset)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -rightInset, yOffset)
    row:SetHeight(rowHeight)
    row.layoutHeight = rowHeight
    row:EnableMouse(true)
    row.hover = AddRowHoverHighlight(row)

    local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    text:SetText(label)
    if not compactLayout then
        text:SetPoint("TOPRIGHT", row, "TOPRIGHT", -34, 0)
        text:SetJustifyH("LEFT")
        text:SetJustifyV("TOP")
        if text.SetTextColor then
            text:SetTextColor(1, 0.82, 0.05, 1)
        end
    end

    local toggle = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    toggle:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    toggle:SetChecked(getValue())
    toggle:SetScript("OnClick", function (self)
        applyValue(self:GetChecked() == true)
    end)
    if compactLayout then
        text:SetPoint("RIGHT", toggle, "LEFT", -8, 0)
    end

    row:SetScript("OnMouseUp", function (_, mouseButton)
        if mouseButton == "LeftButton" then
            if toggle.IsMouseOver and toggle:IsMouseOver() then
                return
            end
            toggle:Click()
        end
    end)
    if ns._panelSearchAdder then ns._panelSearchAdder(row, label) end
    AddControlTooltip(row, label, tooltipText)

    row.toggle = toggle
    row.refresh = function ()
        toggle:SetChecked(getValue())
    end
    return row
end

local function CreateActionRow(parent, label, buttonText, yOffset, onClick, tooltipText)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -20, yOffset)
    row:SetHeight(56)
    row.layoutHeight = 56
    row:EnableMouse(true)
    row.hover = AddRowHoverHighlight(row)

    local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    text:SetPoint("TOPRIGHT", row, "TOPRIGHT", -130, 0)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetText(label)
    if text.SetTextColor then
        text:SetTextColor(1, 0.82, 0.05, 1)
    end

    local btn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    btn:SetSize(120, 22)
    btn:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    btn:SetText(buttonText or label)
    btn:SetScript("OnClick", function ()
        if onClick then
            onClick()
        end
    end)
    text:SetPoint("RIGHT", btn, "LEFT", -8, 0)

    row:SetScript("OnMouseUp", function (_, mouseButton)
        if mouseButton == "LeftButton" then
            if btn.IsMouseOver and btn:IsMouseOver() then
                return
            end
            btn:Click()
        end
    end)
    if ns._panelSearchAdder then ns._panelSearchAdder(row, label) end
    AddControlTooltip(row, label, tooltipText or string.format("Click to %s.", string.lower(buttonText or label)))

    row.button = btn
    row.refresh = function () end
    return row
end

-- ------------------------------------------------------------
-- [?] help button — small clickable font string that shows a
-- GameTooltip explaining a complex concept. Placed next to a
local function CreateSectionHeader(parent, label, yOffset, options)
    local row = CreateOptionalBackdropFrame("Button", nil, parent)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -20, yOffset)
    row:SetHeight(24)
    row.layoutHeight = 30
    row:EnableMouse(true)
    row:EnableKeyboard(true)
    row:RegisterForClicks("LeftButtonUp")
    row:Show()
    row.options = options or {}
    row.rows = row.options.rows

    -- Keyboard activation for section headers (Enter/Space to toggle collapse)
    row:SetScript("OnKeyDown", function (self, key)
        if key == "ENTER" or key == "SPACE" then
            self:Click()
        end
    end)

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

    -- Per-section Reset button (far right, created eagerly so it's always in the layout)
    do
        local resetBtn = CreateFrame("Button", nil, row)
        resetBtn:SetSize(50, 18)
        resetBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        resetBtn:SetFrameLevel(row:GetFrameLevel() + 5)
        resetBtn:EnableMouse(true)
        resetBtn:RegisterForClicks("LeftButtonUp")
        resetBtn:Show()

        local resetBg = resetBtn:CreateTexture(nil, "BACKGROUND")
        resetBg:SetAllPoints(true)
        resetBg:SetColorTexture(0.3, 0.15, 0.15, 0.6)

        local resetHover = resetBtn:CreateTexture(nil, "HIGHLIGHT")
        resetHover:SetAllPoints(true)
        resetHover:SetColorTexture(0.5, 0.2, 0.2, 0.4)

        local resetText = resetBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        resetText:SetPoint("CENTER")
        resetText:SetText("Reset")
        resetText:SetTextColor(0.85, 0.55, 0.55, 0.9)

        resetBtn:SetScript("OnEnter", function ()
            resetBg:SetColorTexture(0.4, 0.2, 0.2, 0.8)
            resetText:SetTextColor(1, 0.7, 0.7, 1)
        end)
        resetBtn:SetScript("OnLeave", function ()
            resetBg:SetColorTexture(0.3, 0.15, 0.15, 0.6)
            resetText:SetTextColor(0.85, 0.55, 0.55, 0.9)
        end)

        -- Stop click from also toggling section collapse
        resetBtn:SetScript("OnMouseDown", function ()
            -- Consume the click; do nothing
        end)

        row.resetBtn = resetBtn
        row.resetBtnText = resetText
        row.resetBtnBg = resetBg

        -- Deferred callback: call this after all controls are created
        row.setResetCallback = function (callback)
            options.onReset = callback
            local hasCallback = callback ~= nil
            resetBtn:SetShown(hasCallback)
            if hasCallback then
                resetBtn:SetScript("OnClick", function ()
                    callback()
                end)
            end
        end
    end

    local line = row:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(0.38, 0.38, 0.38, 0.78)
    line:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, -2)
    line:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, -2)
    line:SetHeight(2)

    row.refresh = function ()
        local collapsed = row.options and row.options.getCollapsed and row.options.getCollapsed() or false
        if row.arrow then
            row.arrow:SetText(collapsed and "+" or "-")
        end
        if row.rows then
            SetRowsShown(row.rows, not collapsed)
        end
    end

    if row.options and row.options.rows then
        row:SetScript("OnClick", function (self)
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
    if ns._panelSearchAdder then ns._panelSearchAdder(row, text) end
    local descriptionHeight = math.max(math.ceil((font:GetStringHeight() or 0) + 6), 42)
    row:SetHeight(descriptionHeight)
    row.layoutHeight = descriptionHeight

    row.text = font
    return row
end

local function CreateWeaveFamilyRow(parent, abbrev, label, yOffset)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -20, yOffset)
    row:SetHeight(40)
    row.layoutHeight = 40
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
    toggle:SetScript("OnClick", function (self)
        ns.SetWeaveFamilyEnabled(abbrev, self:GetChecked() == true)
        if ns.RebuildWeaveSpellCatalog then
            ns.RebuildWeaveSpellCatalog()
        end
        if ns.ClearWeavePreview then
            ns.ClearWeavePreview()
        end
    end)

    row:SetScript("OnMouseUp", function (_, mouseButton)
        if mouseButton == "LeftButton" then
            if toggle.IsMouseOver and toggle:IsMouseOver() then
                return
            end
            toggle:Click()
        end
    end)
    local familyLabel = string.format("%s family", abbrev)
    local familyTooltip = string.format("Keep the %s family in the weave breakpoint helper.", label)
    AddControlTooltip(row, familyLabel, familyTooltip)

    row.toggle = toggle
    row.refresh = function ()
        toggle:SetChecked(ns.GetWeaveFamilyEnabled and ns.GetWeaveFamilyEnabled(abbrev))
    end
    return row
end

-- ============================================================
-- Panel creation
-- ============================================================
local function CreatePanel()
    local f = CreateOptionalBackdropFrame("Frame", "SuperSwingTimerConfigPanel", UIParent)
    panel = f
    f:SetSize(780, 760)
    f:SetPoint("CENTER")
    SetFrameBackdrop(f, {
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetScript("OnMouseDown", function (self, button)
        if button == "RightButton" then return end -- suppress right-click menu
    end)
    f:SetClampedToScreen(true)
    f:SetFrameStrata("DIALOG")
    f:SetScript("OnHide", function ()
        HideBarPreview()
    end)
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
    subtitle:SetJustifyH("LEFT")
    subtitle:SetText(
        "SuperSwingTimer tracks melee, ranged, and enemy swing timers with per-class overlay support. " ..
        "Left column = visibility toggles. Right column = color swatches. " ..
        "Class-specific controls are in sections at the bottom (/sst help for slash commands)."
    )

    -- Close button
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)

    local scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -46)
    scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 54)
    EnableScrollFrameMouseWheel(scrollFrame, 36)

    -- ============================================================
    -- Search bar — fixed above scroll frame, filters rows in real-time
    -- ============================================================
    local searchBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    searchBox:SetPoint("TOPLEFT", scrollFrame, "BOTTOMLEFT", 6, -2)
    searchBox:SetPoint("TOPRIGHT", scrollFrame, "BOTTOMRIGHT", -6, -2)
    searchBox:SetHeight(22)
    searchBox:SetAutoFocus(false)
    searchBox:SetTextInsets(6, 6, 1, 1)
    searchBox:SetText("")
    searchBox:Show()

    do
        local placeholder = searchBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        placeholder:SetPoint("LEFT", searchBox, "LEFT", 10, 0)
        placeholder:SetText("Search settings...")
        placeholder:SetTextColor(0.45, 0.45, 0.45, 0.7)
        placeholder:SetJustifyH("LEFT")
        searchBox:HookScript("OnTextChanged", function (self)
            placeholder:SetShown((self:GetText() or "") == "")
        end)
    end

    -- Flat list of all searchable row frames
    local searchRows = {}
    f.searchRows = searchRows
    f.searchBox = searchBox

    -- Expose AddSearchRow globally so factory functions can register rows
    ns._panelSearchAdder = function (row, text)
        if row and text and text ~= "" then
            searchRows[#searchRows + 1] = { frame = row, text = string.lower(text) }
        end
    end

    local function FilterSearchRows()
        local searchText = string.lower(searchBox:GetText() or "")
        local hasSearch = searchText ~= ""

        for _, entry in ipairs(searchRows) do
            local frame = entry.frame
            if frame then
                local match = not hasSearch or entry.text:find(searchText, 1, true) ~= nil
                if match then
                    frame:SetAlpha(1)
                    frame:Show()
                else
                    frame:SetAlpha(0.25)
                end
            end
        end

        if f.ReflowConfigSections then f.ReflowConfigSections() end
    end

    searchBox:HookScript("OnTextChanged", FilterSearchRows)
    searchBox:HookScript("OnEscapePressed", function (self)
        self:SetText("")
        FilterSearchRows()
    end)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(720, 4000)
    scrollFrame:SetScrollChild(content)
    f.scrollFrame = scrollFrame
    f.content = content

    local sectionCollapsed = {
        general = false,
        colors = false,
        weaveFamilies = false,
        quickTab = "visibility"
    }
    local barVisibilityRows = {}
    local quickToggleRows = {}
    local quickColorRows = {}
    local mhOhRows = {}
    local shamanRows = {}
    local generalRows = {}
    local colorRowsSection = {}
    local weaveFamiliesRows = {}
    local cfg = ns.classConfig or {}
    local quickToggleOptions = { leftInset = 20, rightInset = 360, rowHeight = 32, compact = true }
    local quickColorOptions = { leftInset = 360, rightInset = 20, rowHeight = 32, buttonWidth = 160, compact = true }
    -- ============================================================
    -- Global Scale slider — first control, always visible at top
    -- ============================================================
    local SCALE_SECTION_HEIGHT = 184  -- 120 (slider + desc) + 30 (minimal) + 30 (advanced) + 4 (gap)
    local globalScaleRow = CreateLabeledSliderRow(content, "Global Scale", 0.5, 3.0, 0.1, 0, {
        leftInset = 20, rightInset = 20, rowHeight = 84
    })
    if globalScaleRow and globalScaleRow.text then
        globalScaleRow.text:SetTextColor(1, 0.90, 0.30, 1)
    end
    local globalScaleSlider = globalScaleRow and select(1, globalScaleRow:GetChildren()) or nil
    panel.globalScaleSlider = globalScaleSlider

    if globalScaleSlider then
        globalScaleSlider:SetValue(SuperSwingTimerDB.globalScale or ns.DB_DEFAULTS.globalScale or 1.0)
        globalScaleSlider:SetScript("OnValueChanged", function (self, value)
            local clamped = math.max(0.5, math.min(3.0, tonumber(value) or 1.0))
            SuperSwingTimerDB.globalScale = clamped
            SyncSliderDisplay(self, clamped)
            if ns.ApplyGlobalScale then
                ns.ApplyGlobalScale()
            end
        end)
        SyncSliderDisplay(globalScaleSlider, SuperSwingTimerDB.globalScale or ns.DB_DEFAULTS.globalScale or 1.0)
    end

    -- Description text below scale slider
    local scaleDesc = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    scaleDesc:SetPoint("TOPLEFT", content, "TOPLEFT", 20, -(84 + 2))
    scaleDesc:SetPoint("TOPRIGHT", content, "TOPRIGHT", -20, -(84 + 2))
    scaleDesc:SetJustifyH("LEFT")
    scaleDesc:SetJustifyV("TOP")
    scaleDesc:SetText(
        "Proportionally scales all bars, icons, sparks, borders, and fonts relative to their base (default) size. " ..
        "Each individual slider still fine-tunes that base size; this master slider multiplies everything."
    )
    scaleDesc:SetTextColor(0.75, 0.75, 0.75, 1)
    scaleDesc.layoutHeight = 28

    -- Minimal Mode toggle (right side of top area)
    local MINIMAL_ROW_HEIGHT = 30
    local topMinimalModeRow = CreateToggleRow(
        content,
        "Minimal Mode",
        -(84 + 2 + 28 + 4),  -- below scale description
        function () return SuperSwingTimerDB.minimalMode == true end,
        function (enabled)
            ns.ApplyMinimalMode(enabled)
        end
    )
    -- Anchor Minimal Mode to the right half
    topMinimalModeRow:ClearAllPoints()
    topMinimalModeRow:SetPoint("TOPLEFT", content, "TOPLEFT", 380, -(84 + 2 + 28 + 4))
    topMinimalModeRow:SetPoint("TOPRIGHT", content, "TOPRIGHT", -20, -(84 + 2 + 28 + 4))
    topMinimalModeRow.layoutHeight = MINIMAL_ROW_HEIGHT

    -- Label and description for Minimal Mode
    local minimalDesc = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    minimalDesc:SetPoint("TOPLEFT", content, "TOPLEFT", 20, -(84 + 2 + 28 + 4))
    minimalDesc:SetPoint("RIGHT", topMinimalModeRow, "LEFT", -8, 0)
    minimalDesc:SetJustifyH("LEFT")
    minimalDesc:SetJustifyV("TOP")
    minimalDesc:SetText("Hide non-essential overlays\nfor a cleaner combat view. Bars, sparks,\nand timers remain functional.")
    minimalDesc:SetTextColor(0.7, 0.7, 0.7, 0.9)
    minimalDesc.layoutHeight = MINIMAL_ROW_HEIGHT

    -- Show Advanced toggle (below Minimal Mode, right side)
    local SHOW_ADVANCED_ROW_HEIGHT = 30
    local showAdvancedRow = CreateToggleRow(
        content,
        "Show Advanced",
        -(84 + 2 + 28 + 4 + MINIMAL_ROW_HEIGHT + 4),
        function () return SuperSwingTimerDB.showAdvanced == true end,
        function (enabled)
            SuperSwingTimerDB.showAdvanced = enabled
            if f.ReflowConfigSections then
                f.ReflowConfigSections()
            end
        end
    )
    showAdvancedRow:ClearAllPoints()
    showAdvancedRow:SetPoint("TOPLEFT", content, "TOPLEFT", 380, -(84 + 2 + 28 + 4 + MINIMAL_ROW_HEIGHT + 4))
    showAdvancedRow:SetPoint("TOPRIGHT", content, "TOPRIGHT", -20, -(84 + 2 + 28 + 4 + MINIMAL_ROW_HEIGHT + 4))
    showAdvancedRow.layoutHeight = SHOW_ADVANCED_ROW_HEIGHT

    -- Description text for Show Advanced
    local showAdvancedDesc = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    showAdvancedDesc:SetPoint("TOPLEFT", content, "TOPLEFT", 20, -(84 + 2 + 28 + 4 + MINIMAL_ROW_HEIGHT + 4))
    showAdvancedDesc:SetPoint("RIGHT", showAdvancedRow, "LEFT", -8, 0)
    showAdvancedDesc:SetJustifyH("LEFT")
    showAdvancedDesc:SetJustifyV("TOP")
    showAdvancedDesc:SetText("Show fine-tuning controls like\ntexture layers, spark dimensions,\nand blending mode.")
    showAdvancedDesc:SetTextColor(0.7, 0.7, 0.7, 0.9)
    showAdvancedDesc.layoutHeight = SHOW_ADVANCED_ROW_HEIGHT

    -- Refresh Show Advanced toggle when section reflow runs
    f.showAdvancedRow = showAdvancedRow

    local quickToggleY = -66 - SCALE_SECTION_HEIGHT
    local quickColorY = -66 - SCALE_SECTION_HEIGHT
    local quickRowStep = -30

    -- Sliders / selectors
    local barVisibilityHeader = CreateSectionHeader(content, "Quick Controls", -10 - SCALE_SECTION_HEIGHT, {
        rows = barVisibilityRows,
        getCollapsed = function () return sectionCollapsed.barVisibility end,
        setCollapsed = function (collapsed)
            sectionCollapsed.barVisibility = collapsed
        end
    })

    local quickToggleLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    quickToggleLabel:SetPoint("TOPLEFT", content, "TOPLEFT", quickToggleOptions.leftInset, -32 - SCALE_SECTION_HEIGHT)
    quickToggleLabel:SetText("Visibility (show/hide bars)")
    quickToggleLabel.layoutHeight = math.max(math.ceil((quickToggleLabel:GetStringHeight() or 12)), 14)
    barVisibilityRows[#barVisibilityRows + 1] = quickToggleLabel
    quickToggleLabel:Hide()

    local quickColorLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    quickColorLabel:SetPoint("TOPLEFT", content, "TOPLEFT", quickColorOptions.leftInset, -32 - SCALE_SECTION_HEIGHT)
    quickColorLabel:SetText("Colors (bar / swatch tint)")
    quickColorLabel.layoutHeight = math.max(math.ceil((quickColorLabel:GetStringHeight() or 12)), 14)
    barVisibilityRows[#barVisibilityRows + 1] = quickColorLabel
    quickColorLabel:Hide()

    -- Tabbed Quick Controls: Visibility | Colors | Class
    local function CreateQuickTab(label, tabKey)
        local btn = CreateOptionalBackdropFrame("Button", nil, content)
        btn:SetHeight(22)
        btn:SetWidth(100)
        btn:SetFrameLevel(content:GetFrameLevel() + 5)
        btn:EnableMouse(true)
        btn:EnableKeyboard(true)
        btn:RegisterForClicks("LeftButtonUp")
        btn:Show()
        -- Keyboard activation for tabs (Enter/Space)
        btn:SetScript("OnKeyDown", function (self, key)
            if key == "ENTER" or key == "SPACE" then
                self:Click()
            end
        end)

        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.12, 0.12, 0.12, 0.85)
        btn.bg = bg

        local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        txt:SetPoint("CENTER")
        txt:SetText(label)
        btn.label = txt

        local activeBg = btn:CreateTexture(nil, "OVERLAY")
        activeBg:SetAllPoints()
        activeBg:SetColorTexture(0.22, 0.22, 0.22, 0.9)
        activeBg:Hide()
        btn.activeBg = activeBg

        btn:SetScript("OnClick", function ()
            if sectionCollapsed.quickTab ~= tabKey then
                sectionCollapsed.quickTab = tabKey
                if f.ReflowConfigSections then f.ReflowConfigSections() end
            end
        end)

        -- Store refresh function to update active state
        btn.refresh = function ()
            local isActive = sectionCollapsed.quickTab == tabKey
            activeBg:SetShown(isActive)
            if isActive then
                txt:SetTextColor(1, 0.90, 0.30, 1)
            else
                txt:SetTextColor(0.7, 0.7, 0.7, 1)
            end
        end

        return btn
    end

    -- Tab buttons stored for positioning in ReflowQuickControls
    local quickTabButtons = {}
    for _, tabDef in ipairs({
        { label = "Visibility", key = "visibility" },
        { label = "Colors", key = "colors" },
        { label = "Class", key = "class" }
    }) do
        local btn = CreateQuickTab(tabDef.label, tabDef.key)
        quickTabButtons[#quickTabButtons + 1] = btn
        barVisibilityRows[#barVisibilityRows + 1] = btn
    end
    -- Start on visibility tab
    sectionCollapsed.quickTab = "visibility"

    local function AddQuickToggle(label, getValue, applyValue, options, tab)
        local rowOptions = {}
        for key, value in pairs(quickToggleOptions) do
            rowOptions[key] = value
        end
        if options then
            for key, value in pairs(options) do
                rowOptions[key] = value
            end
        end
        local row = CreateToggleRow(content, label, quickToggleY, getValue, applyValue, rowOptions)
        quickToggleY = quickToggleY + quickRowStep
        row.quickTab = tab or "visibility"
        quickToggleRows[#quickToggleRows + 1] = row
        barVisibilityRows[#barVisibilityRows + 1] = row
        return row
    end

    local function AddQuickColor(label, colorKey, options, tab)
        options = options or {}
        options.leftInset = quickColorOptions.leftInset
        options.rightInset = quickColorOptions.rightInset
        options.rowHeight = quickColorOptions.rowHeight
        options.buttonWidth = quickColorOptions.buttonWidth
        local row = CreateColorButton(content, label, colorKey, quickColorY, options)
        quickColorY = quickColorY + quickRowStep
        row.quickTab = tab or "colors"
        quickColorRows[#quickColorRows + 1] = row
        barVisibilityRows[#barVisibilityRows + 1] = row
        colorRowsSection[#colorRowsSection + 1] = row
        return row
    end

    local useClassColorsRow = AddQuickToggle(
        "Use Class Colors",
        function ()
            return SuperSwingTimerDB.useClassColors == true
        end,
        function (enabled)
            local wasEnabled = SuperSwingTimerDB.useClassColors == true
            if enabled and not wasEnabled then
                SavePreClassColorState()
            elseif not enabled and wasEnabled then
                RestoreColorsAfterClassToggleDisabled()
            end
            SuperSwingTimerDB.useClassColors = enabled
            ns.ApplyBarColors()
            if f.useClassColorsRow and f.useClassColorsRow.refresh then
                f.useClassColorsRow.refresh()
            end
            if f.colorRows then
                for _, colorRow in ipairs(f.colorRows) do
                    if colorRow and colorRow.button and colorRow.swatch then
                        local key = colorRow.button.colorKey
                        local effective = ns.GetBarColor(key)
                        if effective then
                            colorRow.swatch:SetColorTexture(effective.r, effective.g, effective.b, effective.a)
                        end
                    end
                end
            end
        end,
        {
            tooltipText = "Tint bar fills with your class color (Warrior=tan, Paladin=pink, Hunter=green, Rogue=yellow, Shaman=blue, Druid=orange). Disable to use custom swatches."
        }
    )

    -- Lock Bars at top of Quick Controls for fast access
    local lockBarsQuickRow = AddQuickToggle(
        "Lock Bars", function () return SuperSwingTimerDB.lockBars == true end,
        function (enabled)
            SuperSwingTimerDB.lockBars = enabled
            if ns.ApplyLockBars then
                ns.ApplyLockBars()
            end
        end,
        {
            tooltipText = "Lock bars in place so right-click camera movement passes through them. Unlock to reposition."
        }
    )

    local showMHRow = nil
    if cfg.melee then
        showMHRow = AddQuickToggle(
            "Show Main Hand",
            function () return SuperSwingTimerDB.showMH ~= false end,
            function (enabled)
                SuperSwingTimerDB.showMH = enabled
                ns.ApplyVisibility()
            end,
            {
                tooltipText = "Show/hide the main-hand swing timer bar. Hidden bars still tick in the background."
            }
        )
    end

    local showOHRow = nil
    if cfg.dualWield then
        showOHRow = AddQuickToggle(
            "Show Off Hand",
            function () return SuperSwingTimerDB.showOH ~= false end,
            function (enabled)
                SuperSwingTimerDB.showOH = enabled
                ns.ApplyVisibility()
            end,
            {
                tooltipText = "Show/hide the off-hand swing timer bar (dual-wield only). Hidden bars still tick in the background."
            }
        )
    end

    local showRangedRow = nil
    if cfg.ranged then
        showRangedRow = AddQuickToggle(
            "Show Ranged",
            function () return SuperSwingTimerDB.showRanged ~= false end,
            function (enabled)
                SuperSwingTimerDB.showRanged = enabled
                ns.ApplyVisibility()
            end,
            {
                tooltipText = "Show/hide the ranged swing timer bar (auto-shot cycle). Hidden bars still tick in the background."
            }
        )
    end

    local showHunterRangeHelperRow = nil
    if ns.playerClass == "HUNTER" then
        showHunterRangeHelperRow = AddQuickToggle(
            "Hunter Range Helper", function () return SuperSwingTimerDB.showHunterRangeHelper ~= false end,
            function (enabled)
                SuperSwingTimerDB.showHunterRangeHelper = enabled
                if ns.UpdateHunterRangeHelperVisual then
                    ns.UpdateHunterRangeHelperVisual()
                else
                    ns.ApplyVisibility()
                end
            end,
            {
                tooltipText = "Show the slim four-state Hunter range strip next to the ranged stack: green melee, yellow sweet spot, blue ranged, red out of range."
            }
        )
        -- Phase 2: Hunter Rapid Fire CD bar toggle
        AddQuickToggle(
            "Rapid Fire Bar", function () return SuperSwingTimerDB.showHunterRapidFireBar ~= false end,
            function (enabled)
                SuperSwingTimerDB.showHunterRapidFireBar = enabled
            end,
            {
                tooltipText = "Show a thin 4px bar below the ranged stack tracking Rapid Fire cooldown."
            }
        )
        -- Phase 3: Hunter buff/cooldown icon toggle
        AddQuickToggle(
            "Buff Icons", function () return SuperSwingTimerDB.showHunterBuffIcons ~= false end,
            function (enabled)
                SuperSwingTimerDB.showHunterBuffIcons = enabled
            end,
            {
                tooltipText = "Show 25x25 buff/duration icons above the ranged bar for hunter abilities and racials. Icons glow gold in the last 4 seconds."
            }
        )
    end

    local showEnemyRow = AddQuickToggle(
        "Show Enemy Bar",
        function () return SuperSwingTimerDB.showEnemy ~= false end,
        function (enabled)
            SuperSwingTimerDB.showEnemy = enabled
            ns.ApplyVisibility()
        end,
        {
            tooltipText = "Show/hide the current target's swing timer bar (non-player). Updates when targeting a new enemy."
        }
    )

    local showWeaveRow = nil
    if ns.playerClass == "SHAMAN" then
        showWeaveRow = AddQuickToggle(
            "Shaman Weave Assist",
            function ()
                return SuperSwingTimerDB.showWeaveAssist ~= false
            end,
            function (enabled)
                SuperSwingTimerDB.showWeaveAssist = enabled
                ns.ApplyVisibility()
            end,
            {
                tooltipText = "Show spell weave cast-time overlays on the swing bar. Covers LB, CL, HW, LHW, and CH families with safe-zone and clip feedback."
            }
        )
        -- Phase 2: Shaman Windfury ICD toggle
        AddQuickToggle(
            "Windfury ICD", function () return SuperSwingTimerDB.showShamanWindfuryIcd ~= false end,
            function (enabled)
                SuperSwingTimerDB.showShamanWindfuryIcd = enabled
            end,
            {
                tooltipText = "Show a slim 3px vertical bar on the right side of the main-hand bar tracking the 3s Windfury internal cooldown: green=ready, orange=winding down, red=recharging."
            }
        )
    end

    local showRogueAssistRow = nil
    if ns.playerClass == "ROGUE" then
        showRogueAssistRow = AddQuickToggle(
            "Rogue SS Cue",
            function ()
                return SuperSwingTimerDB.showRogueSinisterAssist ~= false
            end,
            function (enabled)
                SuperSwingTimerDB.showRogueSinisterAssist = enabled
                if ns.UpdateRogueSinisterAssistVisual then
                    ns.UpdateRogueSinisterAssistVisual()
                end
            end,
            {
                tooltipText = "Show a colored end-window cue on the MH bar marking when to queue Sinister Strike before the swing lands."
            }
        )
    end

    local showRogueEnergyRow = nil
    if ns.playerClass == "ROGUE" then
        showRogueEnergyRow = AddQuickToggle(
            "Rogue Energy Tick", function () return SuperSwingTimerDB.showRogueEnergyTick ~= false end,
            function (enabled)
                SuperSwingTimerDB.showRogueEnergyTick = enabled
                if ns.UpdateRogueEnergyTickVisual then
                    ns.UpdateRogueEnergyTickVisual()
                end
            end,
            {
                tooltipText = "Show the slim Rogue energy-tick bar to the left of the main-hand bar."
            }
        )
    end

    local showDruidEnergyRow = nil
    if ns.playerClass == "DRUID" then
        showDruidEnergyRow = AddQuickToggle(
            "Druid Energy Tick", function () return SuperSwingTimerDB.showDruidEnergyTickBar ~= false end,
            function (enabled)
                SuperSwingTimerDB.showDruidEnergyTickBar = enabled
                if ns.UpdateDruidEnergyTickVisual then
                    ns.UpdateDruidEnergyTickVisual()
                end
            end,
            {
                tooltipText = "Show the slim Cat-form energy-tick bar to the left of the main-hand bar."
            }
        )
    end

    local showRogueSliceAndDiceRow = nil
    if ns.playerClass == "ROGUE" then
        showRogueSliceAndDiceRow = AddQuickToggle(
            "Rogue Slice and Dice", function () return SuperSwingTimerDB.showRogueSliceAndDice ~= false end,
            function (enabled)
                SuperSwingTimerDB.showRogueSliceAndDice = enabled
                if ns.UpdateRogueSliceAndDiceVisual then
                    ns.UpdateRogueSliceAndDiceVisual()
                end
            end,
            {
                tooltipText = "Show the slim Slice and Dice duration bar above the main-hand bar while the buff is active; it now hides whenever the MH bar is hidden and rechecks the buff state on a short throttle for smoother live updates."
            }
        )
    end
    if ns.playerClass == "ROGUE" then
        AddQuickToggle(
            "Rogue Combo Points", function () return SuperSwingTimerDB.showRogueComboPoints ~= false end,
            function (enabled)
                SuperSwingTimerDB.showRogueComboPoints = enabled
                if ns.UpdateRogueComboPointVisual then
                    ns.UpdateRogueComboPointVisual()
                end
            end,
            {
                tooltipText = "Show the compact five-box combo-point strip above the main-hand bar while you have a target selected."
            }
        )
    end

    -- Phase 2: Rogue Adrenaline Rush CD bar toggle
    if ns.playerClass == "ROGUE" then
        AddQuickToggle(
            "Rogue Adrenaline Rush", function () return SuperSwingTimerDB.showRogueAdrenalineRushBar ~= false end,
            function (enabled)
                SuperSwingTimerDB.showRogueAdrenalineRushBar = enabled
            end,
            {
                tooltipText = "Show a thin 3px bar below the main-hand bar tracking the 3m cooldown and 15s duration of Adrenaline Rush."
            }
        )
    end

    -- Phase 2: Warrior Flurry counter toggle
    if ns.playerClass == "WARRIOR" then
        AddQuickToggle(
            "Warrior Flurry", function () return SuperSwingTimerDB.showWarriorFlurryCounter ~= false end,
            function (enabled)
                SuperSwingTimerDB.showWarriorFlurryCounter = enabled
            end,
            {
                tooltipText = "Show remaining Flurry charges (⚡1-3) on the main-hand bar while the buff is active."
            }
        )

        AddQuickToggle(
            "Buff Icons", function () return SuperSwingTimerDB.showWarriorBuffIcons ~= false end,
            function (enabled)
                SuperSwingTimerDB.showWarriorBuffIcons = enabled
            end,
            {
                tooltipText = "Show icons above the MH bar for active Warrior buffs and CDs (Death Wish, Recklessness, Sweeping Strikes, Retaliation, Shield Wall, Last Stand, racials). Icons glow gold in the last 4 seconds."
            }
        )
    end

    -- Phase 1 Quick Toggles
    AddQuickToggle(
        "Swing Flash", function () return SuperSwingTimerDB.showSwingFlash ~= false end,
        function (enabled)
            SuperSwingTimerDB.showSwingFlash = enabled
        end,
        {
            tooltipText = "Flash the spark white for 80ms when a swing lands, for instant hit-feedback without checking the combat log."
        }
    )
    if ns.playerClass ~= "HUNTER" then
        AddQuickToggle(
            "GCD Ticker", function () return SuperSwingTimerDB.showGcdTicker ~= false end,
            function (enabled)
                SuperSwingTimerDB.showGcdTicker = enabled
            end,
            {
                tooltipText = "Show a thin 3px bar above the main-hand bar that counts down the fixed 1.5s global cooldown after each cast."
            }
        )
    end

    if ns.playerClass == "ROGUE" then
        AddQuickToggle(
            "Energy Countdown", function () return SuperSwingTimerDB.showRogueEnergyCountdown ~= false end,
            function (enabled)
                SuperSwingTimerDB.showRogueEnergyCountdown = enabled
            end,
            {
                tooltipText = "Show seconds-until-next-tick text on the energy-tick bar so you know exactly when your next 20 energy arrives."
            }
        )

        AddQuickToggle(
            "Buff Icons", function () return SuperSwingTimerDB.showRogueBuffIcons ~= false end,
            function (enabled)
                SuperSwingTimerDB.showRogueBuffIcons = enabled
            end,
            {
                tooltipText = "Show icons above the MH bar for active Rogue buffs and CDs (Adrenaline Rush, Blade Flurry, Cold Blood, Evasion, Sprint, Vanish, Premeditation, Shadowstep, racials). Icons glow gold in the last 4 seconds."
            }
        )
    end

    -- Phase 1: swing landing flash toggle (all melee classes)
    if cfg.melee then
        AddQuickToggle(
            "Swing Flash", function () return SuperSwingTimerDB.showSwingFlash ~= false end,
            function (enabled)
                SuperSwingTimerDB.showSwingFlash = enabled
            end,
            {
                tooltipText = "Flash the spark texture white when a melee or ranged swing lands, giving a crisp visual confirmation of the hit."
            }
        )
    end

    -- GCD ticker toggle (melee except Hunter)
    if cfg.melee and ns.playerClass ~= "HUNTER" then
        AddQuickToggle(
            "GCD Ticker", function () return SuperSwingTimerDB.showGcdTicker ~= false end,
            function (enabled)
                SuperSwingTimerDB.showGcdTicker = enabled
            end,
            {
                tooltipText = "Show a thin 3px bar above the main-hand bar tracking the fixed 1.5s global cooldown window."
            }
        )
    end

    -- Rogue energy countdown toggle
    if ns.playerClass == "ROGUE" then
        AddQuickToggle(
            "Energy Countdown", function () return SuperSwingTimerDB.showRogueEnergyCountdown ~= false end,
            function (enabled)
                SuperSwingTimerDB.showRogueEnergyCountdown = enabled
            end,
            {
                tooltipText = "Show a countdown label on the energy-tick bar showing seconds until the next energy pulse."
            }
        )
    end

    if cfg.melee then
        AddQuickColor("MH Color", "mh", { allowAlpha = true })
    end

    if cfg.dualWield then
        AddQuickColor("OH Color", "oh", { allowAlpha = true })
    end

    if cfg.ranged then
        AddQuickColor("Ranged Color", "ranged", { allowAlpha = true })
    end

    -- Phase 1: GCD ticker color swatch
    if ns.playerClass ~= "HUNTER" then
        AddQuickColor("GCD Ticker", "gcdTicker", {
            allowAlpha = true,
            tooltipText = "Pick the GCD ticker bar color."
        })
    end

    if ns.playerClass == "WARRIOR" then
        AddQuickColor("Rage Bar", "warriorRageBar", {
            allowAlpha = true,
            tooltipText = "Pick the warrior rage bar color for the slim rage bar under the main-hand/off-hand bars."
        })
    end

    if ns.playerClass == "HUNTER" then
        -- Hunter cast bar color is separate from the ranged bar fill color
        AddQuickColor("Cast Bar", "hunterCastBar", {
            allowAlpha = true,
            tooltipText = "Pick the Hunter cast bar fill color (Steady Shot, Multi-Shot, etc.) independent from the ranged bar fill."
        })
        AddQuickColor("Range Melee", "hunterRangeMelee", {
            allowAlpha = true,
            tooltipText = "Pick the Hunter melee-range helper color for targets close enough to use melee skills like Wing Clip."
        })
        AddQuickColor("Range Sweet Spot", "hunterRangeSweetSpot", {
            allowAlpha = true,
            tooltipText = "Pick the Hunter near-target sweet-spot color for the slim vertical helper beside the ranged stack."
        })
        AddQuickColor("Range Ranged", "hunterRangeRanged", {
            allowAlpha = true,
            tooltipText = "Pick the Hunter ranged-state color for targets safely in Auto Shot range outside the sweet-spot band."
        })
        AddQuickColor("Range Out", "hunterRangeOutOfRange", {
            allowAlpha = true,
            tooltipText = "Pick the Hunter out-of-range color for targets beyond usable Auto Shot range."
        })
        AddQuickColor("Auto Shot Safe", "autoShotSafe", {
            allowAlpha = true,
            tooltipText = "Pick the green stop-safe Auto Shot window color and overlay opacity."
        })
        AddQuickColor("Auto Shot Late", "autoShotUnsafe", {
            allowAlpha = true,
            tooltipText = "Pick the red late / still-moving Auto Shot window color and overlay opacity."
        })
        -- Phase 2: Hunter Rapid Fire bar color swatch
        AddQuickColor("Rapid Fire", "rapidFireBar", {
            allowAlpha = true,
            tooltipText = "Pick the color for the thin 4px Rapid Fire CD/duration bar below the ranged stack."
        })
    end

    AddQuickColor("Enemy Color", "enemy", { allowAlpha = true })

    -- Phase 1: GCD ticker color swatch (all non-Hunter melee)
    if cfg.melee and ns.playerClass ~= "HUNTER" then
        AddQuickColor("GCD Ticker", "gcdTicker", {
            allowAlpha = true,
            tooltipText = "Pick the GCD ticker bar color for the thin 3px bar above the main-hand bar."
        })
    end

    if ns.playerClass == "ROGUE" then
        AddQuickColor("Rogue SS Cue", "rogueSinister", {
            allowAlpha = true,
            tooltipText = "Pick the Rogue main-hand end-window color that marks when to queue Sinister Strike into the swing landing; the configured alpha updates live."
        })
        AddQuickColor("Rogue Energy Tick", "rogueEnergyTick", {
            allowAlpha = true,
            tooltipText = "Pick the Rogue energy-tick bar color for the slim vertical helper on the left side of the main-hand bar."
        })
        AddQuickColor("Rogue Combo", "rogueComboPoints", {
            allowAlpha = true,
            tooltipText = "Pick the Rogue combo-point fill color for the five-box strip above the main-hand bar."
        })
        AddQuickColor("Rogue SnD", "rogueSliceAndDice", {
            allowAlpha = true,
            tooltipText = "Pick the Rogue Slice and Dice helper bar color for the slim duration bar above the main-hand bar."
        })
        -- Phase 2: Rogue Adrenaline Rush bar color swatch
        AddQuickColor("Rogue Adrenaline Rush", "adrenalineRushBar", {
            allowAlpha = true,
            tooltipText = "Pick the color for the thin Adrenaline Rush CD/duration bar below the main-hand bar."
        })
    end

    if ns.playerClass == "DRUID" then
        AddQuickColor("Druid Energy Tick", "druidEnergyTick", {
            allowAlpha = true,
            tooltipText = "Pick the Cat-form energy-tick bar color for the slim vertical helper on the left side of the main-hand bar."
        })
    end

    if ns.playerClass == "WARRIOR" then
        AddQuickToggle(
            "Shield Block", function () return SuperSwingTimerDB.showWarriorShieldBlockBar ~= false end,
            function (enabled)
                SuperSwingTimerDB.showWarriorShieldBlockBar = enabled
            end,
            {
                tooltipText = "Show a slim Shield Block duration bar above the main-hand stack while the buff is active."
            }
        )
        AddQuickToggle(
            "Warrior Rage Bar", function () return SuperSwingTimerDB.showWarriorRageBar ~= false end,
            function (enabled)
                SuperSwingTimerDB.showWarriorRageBar = enabled
                ns.ApplyVisibility()
            end,
            {
                tooltipText = "Show a slim rage bar under the main-hand/off-hand bars that tracks your current warrior rage (0-100)."
            }
        )
        AddQuickToggle(
            "Protection Hide", function () return SuperSwingTimerDB.showWarriorRageProtection end,
            function (enabled)
                SuperSwingTimerDB.showWarriorRageProtection = enabled
            end,
            {
                tooltipText = "When enabled, show the rage bar even in Protection spec (hidden by default)."
            }
        )
        -- Phase 2: Warrior Flurry counter color swatch
        AddQuickColor("Flurry Counter", "flurryCounter", {
            allowAlpha = true,
            tooltipText = "Pick the color for the Flurry charges text (⚡1-3) on the main-hand bar."
        })
        AddQuickColor("Shield Block", "shieldBlockBar", {
            allowAlpha = true,
            tooltipText = "Pick the color for the Shield Block duration bar above the main-hand stack."
        })
    end

    if ns.playerClass == "PALADIN" then
        AddQuickToggle(
            "Paladin Seal Color", function () return SuperSwingTimerDB.showPaladinSealColor ~= false end,
            function (enabled)
                SuperSwingTimerDB.showPaladinSealColor = enabled
                ns.ApplyBarColors()
            end,
            {
                tooltipText = "Color the main-hand bar to match your currently active seal (Command=gold, Blood=red, Martyr=purple, etc.)."
            }
        )

        AddQuickToggle(
            "Paladin Seal Label", function () return SuperSwingTimerDB.showPaladinSealLabel ~= false end,
            function (enabled)
                SuperSwingTimerDB.showPaladinSealLabel = enabled
                ns.ApplyBarColors()
            end,
            {
                tooltipText = "Show the name of your active seal on the main-hand bar (e.g., Command, Blood, Righteousness)."
            }
        )

        AddQuickToggle(
            "Paladin Judgement CD", function () return SuperSwingTimerDB.showPaladinJudgementMarker ~= false end,
            function (enabled)
                SuperSwingTimerDB.showPaladinJudgementMarker = enabled
                ns.ApplyBarColors()
            end,
            {
                tooltipText = "Show a gold marker on the swing bar when Judgement cooldown is available."
            }
        )

        AddQuickToggle(
            "Paladin Twist Flash", function () return SuperSwingTimerDB.showPaladinTwistFlash ~= false end,
            function (enabled)
                SuperSwingTimerDB.showPaladinTwistFlash = enabled
                ns.ApplyBarColors()
            end,
            {
                tooltipText = "Flash the seal-twist zone red on the swing end when a twist-family seal (Command, Blood, Martyr) is active."
            }
        )

        AddQuickColor("Seal Line", "sealTwist", { allowAlpha = true })

        AddQuickToggle(
            "Buff Icons", function () return SuperSwingTimerDB.showPaladinBuffIcons ~= false end,
            function (enabled)
                SuperSwingTimerDB.showPaladinBuffIcons = enabled
            end,
            {
                tooltipText = "Show icons above the MH bar for active Paladin buffs and CDs (Avenging Wrath, Divine Shield, Hammer of Justice, Blessing of Protection, Holy Wrath, Lay on Hands, racials). Icons glow gold in the last 4 seconds."
            }
        )
    end

    -- Phase 2: Shaman Windfury ICD color swatch + Lightning Shield tracker
    if ns.playerClass == "SHAMAN" then
        AddQuickToggle(
            "Lightning Shield Tracker", function () return SuperSwingTimerDB.showShamanLightningTracker ~= false end,
            function (enabled)
                SuperSwingTimerDB.showShamanLightningTracker = enabled
                if ns.UpdateLightningShieldVisual then
                    ns.UpdateLightningShieldVisual()
                end
            end,
            {
                tooltipText = "Show 3 small dot indicators to the left of your melee bars tracking Lightning Shield charges. Fills with class color; dims as charges are consumed. Water Shield always renders in light blue."
            }
        )

        AddQuickToggle(
            "Flame Shock Bar", function () return SuperSwingTimerDB.showShamanFlameShockBar ~= false end,
            function (enabled)
                SuperSwingTimerDB.showShamanFlameShockBar = enabled
                if ns.UpdateShamanFlameShockBar then
                    ns.UpdateShamanFlameShockBar(true)
                end
            end,
            {
                tooltipText = "Show a thin duration bar above the MH bar for your own Flame Shock on the current target."
            }
        )

        AddQuickToggle(
            "Deep Wounds Bar", function () return SuperSwingTimerDB.showWarriorDeepWoundsBar ~= false end,
            function (enabled)
                SuperSwingTimerDB.showWarriorDeepWoundsBar = enabled
                if ns.UpdateWarriorDeepWoundsBar then
                    ns.UpdateWarriorDeepWoundsBar(true)
                end
            end,
            {
                tooltipText = "Show a thin duration bar above the MH bar for your own Deep Wounds bleed on the current target (Arms Warrior)."
            }
        )

        AddQuickToggle(
            "Sunder Armor Bar", function () return SuperSwingTimerDB.showWarriorSunderArmorBar ~= false end,
            function (enabled)
                SuperSwingTimerDB.showWarriorSunderArmorBar = enabled
                if ns.UpdateWarriorSunderArmorBar then
                    ns.UpdateWarriorSunderArmorBar(true)
                end
            end,
            {
                tooltipText = "Show a thin duration bar above the MH bar tracking Sunder Armor stacks (1-5) on the current target (Warrior)."
            }
        )

        AddQuickToggle(
            "Mangle Bar", function () return SuperSwingTimerDB.showDruidMangleBar ~= false end,
            function (enabled)
                SuperSwingTimerDB.showDruidMangleBar = enabled
                if ns.UpdateDruidMangleBar then
                    ns.UpdateDruidMangleBar(true)
                end
            end,
            {
                tooltipText = "Show a thin duration bar above the MH bar for your own Mangle debuff on the current target (Feral Druid)."
            }
        )

        AddQuickToggle(
            "Rip Bar", function () return SuperSwingTimerDB.showDruidRipBar ~= false end,
            function (enabled)
                SuperSwingTimerDB.showDruidRipBar = enabled
                if ns.UpdateDruidRipBar then
                    ns.UpdateDruidRipBar(true)
                end
            end,
            {
                tooltipText = "Show a thin duration bar above the MH bar for your own Rip bleed on the current target (Feral Cat)."
            }
        )

        AddQuickToggle(
            "Rake Bar", function () return SuperSwingTimerDB.showDruidRakeBar ~= false end,
            function (enabled)
                SuperSwingTimerDB.showDruidRakeBar = enabled
                if ns.UpdateDruidRakeBar then
                    ns.UpdateDruidRakeBar(true)
                end
            end,
            {
                tooltipText = "Show a thin duration bar above the Mangle/Rip bars for your own Rake bleed on the current target (Feral Cat)."
            }
        )

        AddQuickToggle(
            "Buff Icons", function () return SuperSwingTimerDB.showDruidBuffIcons ~= false end,
            function (enabled)
                SuperSwingTimerDB.showDruidBuffIcons = enabled
            end,
            {
                tooltipText = "Show icons above the MH bar for active Druid buffs and CDs (Tiger's Fury, Barkskin, Enrage, Dash, Frenzied Regeneration, Innervate, racials). Icons glow gold in the last 4 seconds."
            }
        )

        AddQuickToggle(
            "Rupture Bar", function () return SuperSwingTimerDB.showRogueRuptureBar ~= false end,
            function (enabled)
                SuperSwingTimerDB.showRogueRuptureBar = enabled
                if ns.UpdateRogueRuptureBar then
                    ns.UpdateRogueRuptureBar(true)
                end
            end,
            {
                tooltipText = "Show a thin duration bar above the MH bar for your own Rupture bleed on the current target (Rogue)."
            }
        )

        AddQuickToggle(
            "Expose Armor Bar", function () return SuperSwingTimerDB.showRogueExposeArmorBar ~= false end,
            function (enabled)
                SuperSwingTimerDB.showRogueExposeArmorBar = enabled
                if ns.UpdateRogueExposeArmorBar then
                    ns.UpdateRogueExposeArmorBar(true)
                end
            end,
            {
                tooltipText = "Show a thin duration bar above the MH bar for your own Expose Armor on the current target (Rogue)."
            }
        )

        AddQuickToggle(
            "Serpent Sting Bar", function () return SuperSwingTimerDB.showHunterSerpentStingBar ~= false end,
            function (enabled)
                SuperSwingTimerDB.showHunterSerpentStingBar = enabled
                if ns.UpdateHunterSerpentStingBar then
                    ns.UpdateHunterSerpentStingBar(true)
                end
            end,
            {
                tooltipText = "Show a thin duration bar above the MH bar for your own Serpent Sting on the current target (Hunter)."
            }
        )

        AddQuickToggle(
            "Wing Clip Bar", function () return SuperSwingTimerDB.showHunterWingClipBar ~= false end,
            function (enabled)
                SuperSwingTimerDB.showHunterWingClipBar = enabled
                if ns.UpdateHunterWingClipBar then
                    ns.UpdateHunterWingClipBar(true)
                end
            end,
            {
                tooltipText = "Show a thin duration bar above the MH bar for your own Wing Clip snare on the current target (Hunter)."
            }
        )

        AddQuickToggle(
            "Concussion Shot Bar", function () return SuperSwingTimerDB.showHunterConcussionShotBar ~= false end,
            function (enabled)
                SuperSwingTimerDB.showHunterConcussionShotBar = enabled
                if ns.UpdateHunterConcussionShotBar then
                    ns.UpdateHunterConcussionShotBar(true)
                end
            end,
            {
                tooltipText = "Show a thin duration bar above the MH bar for your own Concussion Shot snare on the current target (Hunter)."
            }
        )

        AddQuickToggle(
            "Immolation Trap Bar", function () return SuperSwingTimerDB.showHunterImmolationTrapBar ~= false end,
            function (enabled)
                SuperSwingTimerDB.showHunterImmolationTrapBar = enabled
                if ns.UpdateHunterImmolationTrapBar then
                    ns.UpdateHunterImmolationTrapBar(true)
                end
            end,
            {
                tooltipText = "Show a thin duration bar above the MH/ranged bar for your own Immolation Trap fire DoT on the current target (Hunter)."
            }
        )

        AddQuickToggle(
            "Explosive Trap Bar", function () return SuperSwingTimerDB.showHunterExplosiveTrapBar ~= false end,
            function (enabled)
                SuperSwingTimerDB.showHunterExplosiveTrapBar = enabled
                if ns.UpdateHunterExplosiveTrapBar then
                    ns.UpdateHunterExplosiveTrapBar(true)
                end
            end,
            {
                tooltipText = "Show a thin duration bar above the MH/ranged bar for your own Explosive Trap fire DoT on the current target (Hunter)."
            }
        )

        AddQuickToggle(
            "Freezing Trap Bar", function () return SuperSwingTimerDB.showHunterFreezingTrapBar ~= false end,
            function (enabled)
                SuperSwingTimerDB.showHunterFreezingTrapBar = enabled
                if ns.UpdateHunterFreezingTrapBar then
                    ns.UpdateHunterFreezingTrapBar(true)
                end
            end,
            {
                tooltipText = "Show a thin duration bar above the MH/ranged bar for your own Freezing Trap CC on the current target (Hunter)."
            }
        )

        AddQuickToggle(
            "Frost Trap Bar", function () return SuperSwingTimerDB.showHunterFrostTrapBar ~= false end,
            function (enabled)
                SuperSwingTimerDB.showHunterFrostTrapBar = enabled
                if ns.UpdateHunterFrostTrapBar then
                    ns.UpdateHunterFrostTrapBar(true)
                end
            end,
            {
                tooltipText = "Show a thin duration bar above the MH/ranged bar for your own Frost Trap snare on the current target (Hunter)."
            }
        )

        AddQuickToggle(
            "Judgement Bar", function () return SuperSwingTimerDB.showPaladinJudgementBar ~= false end,
            function (enabled)
                SuperSwingTimerDB.showPaladinJudgementBar = enabled
                if ns.UpdatePaladinJudgementBar then
                    ns.UpdatePaladinJudgementBar(true)
                end
            end,
            {
                tooltipText = "Show a thin duration bar above the MH bar for your own Judgement of the Crusader on the current target (Retribution Paladin)."
            }
        )

        AddQuickToggle(
            "Seal Vengeance Bar", function () return SuperSwingTimerDB.showPaladinSealVengeanceBar ~= false end,
            function (enabled)
                SuperSwingTimerDB.showPaladinSealVengeanceBar = enabled
                if ns.UpdatePaladinSealVengeanceBar then
                    ns.UpdatePaladinSealVengeanceBar(true)
                end
            end,
            {
                tooltipText = "Show a thin duration bar above the MH bar for your own Seal of Vengeance / Corruption stacking Holy DoT on the current target (Retribution Paladin)."
            }
        )

        AddQuickToggle(
            "Buff Icons", function () return SuperSwingTimerDB.showShamanBuffIcons ~= false end,
            function (enabled)
                SuperSwingTimerDB.showShamanBuffIcons = enabled
            end,
            {
                tooltipText = "Show icons above the MH bar for active Shaman buffs and CDs (Shamanistic Rage, Heroism, Flurry, Windfury Weapon, Stormstrike, racials). Icons glow gold in the last 4 seconds."
            }
        )

        AddQuickColor("Lightning Shield", "shamanLightningShield", {
            allowAlpha = true,
            tooltipText = "Pick the fill color for Lightning Shield charge dots on the left side of the main-hand bar (class color blue by default). Water Shield always uses light blue regardless of this setting."
        })

        AddQuickColor("Windfury ICD", "windfuryIcd", {
            allowAlpha = true,
            tooltipText = "Pick the color for the 3px Windfury ICD tracker bar on the right side of the main-hand bar."
        })
    end

    local ReflowConfigSections
    local quickSectionBottomY = math.min(quickToggleY, quickColorY)
    -- Keep the legacy offset helper alive for row creation, but the real panel
    -- layout now comes from the section reflow below instead of these raw Y values.
    local postQuickYOffset = (quickSectionBottomY - 60) - (-230)
    local function PostQuickY(y)
        return y + postQuickYOffset
    end

    local mhOhHeader = CreateSectionHeader(content, "Appearance", PostQuickY(-230), {
        rows = mhOhRows,
        getCollapsed = function () return sectionCollapsed.mhOh end,
        setCollapsed = function (collapsed)
            sectionCollapsed.mhOh = collapsed
        end
    })
    SetRowsShown(barVisibilityRows, not sectionCollapsed.barVisibility)
    if barVisibilityHeader.refresh then
        barVisibilityHeader.refresh()
    end

    -- Section help text
    local appearanceHelp = CreateDescriptionText(content,
        "Adjust bar sizing, textures, spark visuals, border, and background. " ..
        "Changes apply immediately to the preview bars. Close and reopen /sst to see them in combat.",
        PostQuickY(-255)
    )
    AppendRow(mhOhRows, appearanceHelp)

    -- Keep the first MH/OH control clearly below the section header so slider clicks
    -- cannot also hit the collapse toggle.
    local widthSlider = CreateCompactSlider(content, "Bar Width", 100, 400, 10, PostQuickY(ShiftY(-88)), 20, 600, {
        tooltipText = "Set the base width for all swing timer bars in pixels. All helper bars (SnD, Shield Block, etc.) scale from this width. The Global Scale multiplier above applies on top."
    })
    widthSlider:SetValue(SuperSwingTimerDB.barWidth or ns.DB_DEFAULTS.barWidth)
    SyncSliderDisplay(widthSlider, widthSlider:GetValue())

    local heightSlider = CreateCompactSlider(content, "Bar Height", 10, 40, 2, PostQuickY(ShiftY(-88)), 160, 460, {
        tooltipText = "Set the base height for the main-hand bar in pixels. Off-hand bar height derives automatically (MH - 7px). Helper bars have their own height controls below."
    })
    heightSlider:SetValue(SuperSwingTimerDB.barHeight or ns.DB_DEFAULTS.barHeight)
    SyncSliderDisplay(heightSlider, heightSlider:GetValue())

    local hunterCastBarHeightSlider = nil
    if ns.playerClass == "HUNTER" then
        hunterCastBarHeightSlider = CreateSlider(content, "Hunter Cast Bar Height", 4, 30, 2, PostQuickY(ShiftY(-100)), {
            tooltipText = "Height of the dedicated cast bar beneath the ranged bar showing Steady Shot, Aimed Shot, and the hidden Auto Shot window."
        })
        SetRowClassRequirement(hunterCastBarHeightSlider, "HUNTER")
        hunterCastBarHeightSlider:SetValue(
            SuperSwingTimerDB.hunterCastBarHeight or ns.DB_DEFAULTS.hunterCastBarHeight or 10
        )
        SyncSliderDisplay(hunterCastBarHeightSlider, hunterCastBarHeightSlider:GetValue())
    end

    local rogueSndBarHeightSlider = nil
    if ns.playerClass == "ROGUE" then
        rogueSndBarHeightSlider = CreateSlider(content, "Rogue SnD Height", 2, 20, 1, PostQuickY(ShiftY(-115)), {
            tooltipText = "Height of the Slice and Dice duration bar above the main-hand bar. Shows remaining SnD time."
        })
        SetRowClassRequirement(rogueSndBarHeightSlider, "ROGUE")
        rogueSndBarHeightSlider:SetValue(
            SuperSwingTimerDB.rogueSliceAndDiceBarHeight or ns.DB_DEFAULTS.rogueSliceAndDiceBarHeight or 4
        )
        SyncSliderDisplay(rogueSndBarHeightSlider, rogueSndBarHeightSlider:GetValue())
    end

    local rogueEnergyTickSlider = nil
    if ns.playerClass == "ROGUE" then
        rogueEnergyTickSlider = CreateSlider(content, "Rogue Tick Width", 2, 20, 1, PostQuickY(ShiftY(-140)), {
            tooltipText = "Width of the vertical energy-tick bar to the left of the main-hand bar. Ticks on the 2s energy pulse cadence."
        })
        SetRowClassRequirement(rogueEnergyTickSlider, "ROGUE")
        rogueEnergyTickSlider:SetValue(
            SuperSwingTimerDB.rogueEnergyTickBarWidth or ns.DB_DEFAULTS.rogueEnergyTickBarWidth or 4
        )
        SyncSliderDisplay(rogueEnergyTickSlider, rogueEnergyTickSlider:GetValue())
    end

    local druidEnergyTickSlider = nil
    if ns.playerClass == "DRUID" then
        druidEnergyTickSlider = CreateSlider(content, "Druid Tick Width", 2, 20, 1, PostQuickY(ShiftY(-140)), {
            tooltipText = "Width of the vertical Cat-form energy-tick bar to the left of the main-hand bar."
        })
        SetRowClassRequirement(druidEnergyTickSlider, "DRUID")
        druidEnergyTickSlider:SetValue(
            SuperSwingTimerDB.druidEnergyTickBarWidth or ns.DB_DEFAULTS.druidEnergyTickBarWidth or 4
        )
        SyncSliderDisplay(druidEnergyTickSlider, druidEnergyTickSlider:GetValue())
    end

    local hunterRangeHelperWidthSlider = nil
    if ns.playerClass == "HUNTER" then
        hunterRangeHelperWidthSlider = CreateSlider(content, "Range Helper Width", 2, 20, 1, PostQuickY(ShiftY(-160)), {
            tooltipText = "Width of the 4-state range strip showing melee/sweet spot/ranged/out-of-range zones for Hunters."
        })
        SetRowClassRequirement(hunterRangeHelperWidthSlider, "HUNTER")
        hunterRangeHelperWidthSlider:SetValue(
            SuperSwingTimerDB.hunterRangeHelperWidth or ns.DB_DEFAULTS.hunterRangeHelperWidth or 7
        )
        SyncSliderDisplay(hunterRangeHelperWidthSlider, hunterRangeHelperWidthSlider:GetValue())
    end

    local hunterRapidFireSlider = nil
    if ns.playerClass == "HUNTER" then
        hunterRapidFireSlider = CreateSlider(content, "Rapid Fire Height", 2, 20, 1, PostQuickY(ShiftY(-180)), {
            tooltipText = "Height of the Rapid Fire cooldown/duration bar below the ranged stack. Shows remaining time while active."
        })
        SetRowClassRequirement(hunterRapidFireSlider, "HUNTER")
        hunterRapidFireSlider:SetValue(
            SuperSwingTimerDB.hunterRapidFireBarHeight or ns.DB_DEFAULTS.hunterRapidFireBarHeight or 4
        )
        SyncSliderDisplay(hunterRapidFireSlider, hunterRapidFireSlider:GetValue())
    end

    local hunterBuffIconSlider = nil
    if ns.playerClass == "HUNTER" then
        hunterBuffIconSlider = CreateSlider(content, "Buff Icon Size", 12, 48, 2, PostQuickY(ShiftY(-180)), {
            tooltipText = "Size of the buff/CD icon group above the ranged bar. Icons show active buffs and cooldowns with countdown text and a gold glow in the last 4 seconds."
        })
        SetRowClassRequirement(hunterBuffIconSlider, "HUNTER")
        hunterBuffIconSlider:SetValue(SuperSwingTimerDB.hunterBuffIconSize or ns.DB_DEFAULTS.hunterBuffIconSize or 25)
        SyncSliderDisplay(hunterBuffIconSlider, hunterBuffIconSlider:GetValue())
    end

    local warriorShieldBlockSlider = nil
    if ns.playerClass == "WARRIOR" then
        warriorShieldBlockSlider = CreateSlider(content, "Shield Block Height", 2, 20, 1, PostQuickY(ShiftY(-200)), {
            tooltipText = "Height of the Shield Block duration bar above the main-hand stack for Protection Warriors."
        })
        SetRowClassRequirement(warriorShieldBlockSlider, "WARRIOR")
        warriorShieldBlockSlider:SetValue(
            SuperSwingTimerDB.warriorShieldBlockBarHeight or ns.DB_DEFAULTS.warriorShieldBlockBarHeight or 4
        )
        SyncSliderDisplay(warriorShieldBlockSlider, warriorShieldBlockSlider:GetValue())
    end

    local warriorBuffIconSlider = nil
    if ns.playerClass == "WARRIOR" then
        warriorBuffIconSlider = CreateSlider(content, "Buff Icon Size", 12, 48, 2, PostQuickY(ShiftY(-200)), {
            tooltipText = "Size of the buff/CD icon group above the MH bar for Warrior abilities and racials."
        })
        SetRowClassRequirement(warriorBuffIconSlider, "WARRIOR")
        warriorBuffIconSlider:SetValue(
            SuperSwingTimerDB.warriorBuffIconSize or ns.DB_DEFAULTS.warriorBuffIconSize or 25
        )
        SyncSliderDisplay(warriorBuffIconSlider, warriorBuffIconSlider:GetValue())
    end

    local paladinBuffIconSlider = nil
    if ns.playerClass == "PALADIN" then
        paladinBuffIconSlider = CreateSlider(content, "Buff Icon Size", 12, 48, 2, PostQuickY(ShiftY(-220)), {
            tooltipText = "Size of the buff/CD icon group above the MH bar for Paladin abilities and racials."
        })
        SetRowClassRequirement(paladinBuffIconSlider, "PALADIN")
        paladinBuffIconSlider:SetValue(
            SuperSwingTimerDB.paladinBuffIconSize or ns.DB_DEFAULTS.paladinBuffIconSize or 25
        )
        SyncSliderDisplay(paladinBuffIconSlider, paladinBuffIconSlider:GetValue())
    end

    local shamanLightningGapSlider = nil
    if ns.playerClass == "SHAMAN" then
        shamanLightningGapSlider = CreateSlider(content, "Lightning Tracker Gap", 0, 24, 1, PostQuickY(ShiftY(-220)), {
            tooltipText = "Horizontal gap in pixels between the main-hand bar and the Lightning Shield charge tracker dots to the left."
        })
        SetRowClassRequirement(shamanLightningGapSlider, "SHAMAN")
        shamanLightningGapSlider:SetValue(
            SuperSwingTimerDB.shamanLightningTrackerGap or ns.DB_DEFAULTS.shamanLightningTrackerGap or 6
        )
        SyncSliderDisplay(shamanLightningGapSlider, shamanLightningGapSlider:GetValue())
    end

    local shamanBuffIconSlider = nil
    if ns.playerClass == "SHAMAN" then
        shamanBuffIconSlider = CreateSlider(content, "Buff Icon Size", 12, 48, 2, PostQuickY(ShiftY(-240)), {
            tooltipText = "Size of the buff/CD icon group above the MH bar for Shaman abilities and racials."
        })
        SetRowClassRequirement(shamanBuffIconSlider, "SHAMAN")
        shamanBuffIconSlider:SetValue(
            SuperSwingTimerDB.shamanBuffIconSize or ns.DB_DEFAULTS.shamanBuffIconSize or 25
        )
        SyncSliderDisplay(shamanBuffIconSlider, shamanBuffIconSlider:GetValue())
    end

    local rogueAdrenalineRushSlider = nil
    if ns.playerClass == "ROGUE" then
        rogueAdrenalineRushSlider = CreateSlider(content, "Adrenaline Rush Height", 2, 20, 1, PostQuickY(ShiftY(-260)), {
            tooltipText = "Height of the Adrenaline Rush cooldown/duration bar below the main-hand stack."
        })
        SetRowClassRequirement(rogueAdrenalineRushSlider, "ROGUE")
        rogueAdrenalineRushSlider:SetValue(
            SuperSwingTimerDB.rogueAdrenalineRushBarHeight or ns.DB_DEFAULTS.rogueAdrenalineRushBarHeight or 4
        )
        SyncSliderDisplay(rogueAdrenalineRushSlider, rogueAdrenalineRushSlider:GetValue())
    end

    local rogueBuffIconSlider = nil
    if ns.playerClass == "ROGUE" then
        rogueBuffIconSlider = CreateSlider(content, "Buff Icon Size", 12, 48, 2, PostQuickY(ShiftY(-260)), {
            tooltipText = "Size of the buff/CD icon group above the MH bar for Rogue abilities and racials."
        })
        SetRowClassRequirement(rogueBuffIconSlider, "ROGUE")
        rogueBuffIconSlider:SetValue(
            SuperSwingTimerDB.rogueBuffIconSize or ns.DB_DEFAULTS.rogueBuffIconSize or 25
        )
        SyncSliderDisplay(rogueBuffIconSlider, rogueBuffIconSlider:GetValue())
    end

    local barTextureRow = CreateTexturePathRow(content, "MH/OH Bar Texture", PostQuickY(ShiftY(-280)), {
        mode = "barList",
        defaultTexture = ns.DB_DEFAULTS.barTexture,
        getTexture = function () return ns.GetBarTexture() end,
        applyTexture = function (texturePath)
            ns.ApplyBarTexture(texturePath, SuperSwingTimerDB.barTextureLayer or ns.DB_DEFAULTS.barTextureLayer)
        end,
        browserDefaultCategory = "All",
        browserTitle = "MH/OH Bar Texture",
        browserCategories = {
            WeakAuras = true,
            SharedMedia = true,
            Blizzard = true,
            Platynator = true
        },
        dropdownUsages = { both = true }
    })

    local barLayerRow = CreateCycleRow(
        content,
        "MH/OH Texture Layer",
        PostQuickY(ShiftY(-315)),
        ns.TEXTURE_LAYER_OPTIONS,
        function () return SuperSwingTimerDB.barTextureLayer or ns.DB_DEFAULTS.barTextureLayer end,
        function (layer)
            ns.ApplyBarTextureLayer(layer)
        end
    )
    barLayerRow.isAdvanced = true

    local rangedTextureRow = CreateTexturePathRow(content, "Ranged Bar Texture", PostQuickY(ShiftY(-335)), {
        mode = "barList",
        defaultTexture = ns.DB_DEFAULTS.rangedBarTexture,
        getTexture = function () return ns.GetRangedBarTexture() end,
        applyTexture = function (texturePath)
            ns.ApplyRangedBarTexture(
                texturePath,
                SuperSwingTimerDB.barTextureLayer
                    or ns.DB_DEFAULTS
                        .barTextureLayer
            )
        end,
        browserDefaultCategory = "All",
        browserTitle = "Ranged Bar Texture",
        browserCategories = {
            WeakAuras = true,
            SharedMedia = true,
            Blizzard = true,
            Platynator = true
        },
        dropdownUsages = { both = true }
    })

    local sparkTextureRow = CreateTexturePathRow(content, "Spark Texture", PostQuickY(ShiftY(-350)), {
        mode = "browser",
        label = "Spark Texture",
        yOffset = PostQuickY(ShiftY(-350)),
        defaultTexture = ns.DB_DEFAULTS.sparkTexture,
        getTexture = function () return SuperSwingTimerDB.sparkTexture or ns.DB_DEFAULTS.sparkTexture end,
        applyTexture = function (texturePath)
            ns.ApplySparkSettings(
                texturePath, SuperSwingTimerDB.sparkWidth or ns.DB_DEFAULTS.sparkWidth,
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
            Platynator = true
        },
        browserTitle = "Spark Texture Picker",
        tooltipText = "Type a texture path or click the browse icon to choose the Normal spark preset (Square_FullWhite) or another texture."
    })

    local sparkAlphaSlider = CreateSlider(content, "Spark Alpha", 0, 1, 0.05, PostQuickY(ShiftY(-560)), {
        tooltipText = "Set the spark opacity. 1.0 = fully opaque, 0.0 = invisible. Lower values create a subtle shimmer effect."
    })
    sparkAlphaSlider:SetValue(
        SuperSwingTimerDB.sparkAlpha ~= nil and SuperSwingTimerDB.sparkAlpha or ns.DB_DEFAULTS.sparkAlpha
    )
    SyncSliderDisplay(sparkAlphaSlider, sparkAlphaSlider:GetValue())
    sparkAlphaSlider.isAdvanced = true

    local sparkColorRow = CreateColorButton(content, "Spark Color", "spark", PostQuickY(ShiftY(-385)), {
        allowAlpha = true,
        getColor = function ()
            return SuperSwingTimerDB.sparkColor or ns.GetSparkColor() or ns.DB_DEFAULTS.sparkColor
        end,
        applyColor = function (r, g, b, a)
            local texturePath = SuperSwingTimerDB.sparkTexture or ns.DB_DEFAULTS.sparkTexture
            ns.ApplySparkSettings(
                texturePath, SuperSwingTimerDB.sparkWidth or ns.DB_DEFAULTS.sparkWidth,
                SuperSwingTimerDB.sparkHeight or ns.DB_DEFAULTS.sparkHeight,
                SuperSwingTimerDB.sparkTextureLayer or ns.DB_DEFAULTS.sparkTextureLayer, a,
                { r = r, g = g, b = b, a = a }
            )
        end,
        tooltipText = "Pick the spark tint and opacity with the color wheel."
    })

    local sparkLayerRow = CreateCycleRow(
        content,
        "Spark Layer",
        PostQuickY(ShiftY(-420)),
        ns.TEXTURE_LAYER_OPTIONS,
        function () return SuperSwingTimerDB.sparkTextureLayer or ns.DB_DEFAULTS.sparkTextureLayer end,
        function (layer)
            ns.ApplySparkTextureLayer(layer)
        end
    )
    sparkLayerRow.isAdvanced = true

    local sparkWidthSlider = CreateCompactSlider(content, "Spark Width", 2, 60, 1, PostQuickY(ShiftY(-485)), 20, 600, {
        tooltipText = "Width of the white tracking spark that moves along the bar fill. Wider sparks are easier to see at a glance."
    })
    sparkWidthSlider:SetValue(SuperSwingTimerDB.sparkWidth or ns.DB_DEFAULTS.sparkWidth)
    SyncSliderDisplay(sparkWidthSlider, sparkWidthSlider:GetValue())
    sparkWidthSlider.isAdvanced = true

    local sparkHeightSlider = CreateCompactSlider(content, "Spark Height", 2, 90, 1, PostQuickY(ShiftY(-485)), 160, 460, {
        tooltipText = "Height of the tracking spark. Clamped to the bar height if the value exceeds it."
    })
    sparkHeightSlider:SetValue(SuperSwingTimerDB.sparkHeight or ns.DB_DEFAULTS.sparkHeight)
    SyncSliderDisplay(sparkHeightSlider, sparkHeightSlider:GetValue())
    sparkHeightSlider.isAdvanced = true

    local backgroundColorRow = CreateColorButton(
        content,
        "Bar Background Color",
        "barBackground",
        PostQuickY(ShiftY(-585)),
        {
            allowAlpha = false,
            getColor = function ()
                return SuperSwingTimerDB.barBackgroundColor or ns.DB_DEFAULTS.barBackgroundColor
            end,
            applyColor = function (r, g, b)
                local alpha = SuperSwingTimerDB.barBackgroundAlpha ~= nil and SuperSwingTimerDB.barBackgroundAlpha
                    or ns.DB_DEFAULTS.barBackgroundAlpha
                ns.ApplyBarBackgroundColor({ r = r, g = g, b = b, a = alpha })
            end,
            tooltipText = "Pick the bar background tint. Use the alpha slider below to control opacity."
        }
    )
    backgroundColorRow.isAdvanced = true

    local backgroundAlphaSlider = CreateSlider(content, "Bar Background Alpha", 0, 1, 0.05, PostQuickY(ShiftY(-635)), {
        tooltipText = "Opacity of the dark bar background behind the fill texture. 1.0 = solid, 0.0 = transparent."
    })
    backgroundAlphaSlider:SetValue(
        SuperSwingTimerDB.barBackgroundAlpha ~= nil and SuperSwingTimerDB.barBackgroundAlpha
            or ns.DB_DEFAULTS.barBackgroundAlpha
    )
    SyncSliderDisplay(backgroundAlphaSlider, backgroundAlphaSlider:GetValue())
    backgroundAlphaSlider.isAdvanced = true

    local indicatorBlendModeRow = CreateCycleRow(
        content,
        "Indicator Glow Mode",
        PostQuickY(ShiftY(-685)),
        INDICATOR_BLEND_OPTIONS,
        function () return SuperSwingTimerDB.indicatorBlendMode or ns.DB_DEFAULTS.indicatorBlendMode end,
        function (blendMode)
            ns.ApplyIndicatorBlendMode(blendMode)
        end,
        "Controls how spark and weave indicator textures blend with the bar fill. " ..
        "Glow (ADD) = bright additive highlighting. Opaque (BLEND) = standard transparency."
    )
    indicatorBlendModeRow.isAdvanced = true

    local barBorderColorRow = CreateColorButton(content, "Bar Border Color", "barBorder", PostQuickY(ShiftY(-735)), {
        allowAlpha = true,
        getColor = function ()
            return SuperSwingTimerDB.barBorderColor or ns.DB_DEFAULTS.barBorderColor
        end,
        applyColor = function (r, g, b, a)
            ns.ApplyBarBorderColor({ r = r, g = g, b = b, a = a })
        end,
        tooltipText = "Pick the bar border tint and opacity with the color wheel."
    })
    barBorderColorRow.isAdvanced = true

    local barBorderSlider = CreateSlider(content, "Bar Border Size", 0, 6, 1, PostQuickY(ShiftY(-785)), {
        tooltipText = "Thickness of the black border around each bar frame. Set to 0 to hide borders entirely."
    })
    barBorderSlider:SetValue(
        SuperSwingTimerDB.barBorderSize ~= nil and SuperSwingTimerDB.barBorderSize or ns.DB_DEFAULTS.barBorderSize
    )
    SyncSliderDisplay(barBorderSlider, barBorderSlider:GetValue())
    barBorderSlider:SetScript("OnValueChanged", function (self, value)
        value = math.floor(value + 0.5)
        SyncSliderDisplay(self, value)
        ns.ApplyBarBorderSize(value)
    end)
    barBorderSlider.isAdvanced = true
    AppendRow(mhOhRows, widthSlider)
    AppendRow(mhOhRows, heightSlider)
    AppendRow(mhOhRows, hunterCastBarHeightSlider)
    AppendRow(mhOhRows, rogueSndBarHeightSlider)
    AppendRow(mhOhRows, rogueEnergyTickSlider)
    AppendRow(mhOhRows, druidEnergyTickSlider)
    AppendRow(mhOhRows, hunterRangeHelperWidthSlider)
    AppendRow(mhOhRows, hunterRapidFireSlider)
    AppendRow(mhOhRows, hunterBuffIconSlider)
    AppendRow(mhOhRows, warriorShieldBlockSlider)
    AppendRow(mhOhRows, warriorBuffIconSlider)
    AppendRow(mhOhRows, paladinBuffIconSlider)
    AppendRow(mhOhRows, shamanLightningGapSlider)
    AppendRow(mhOhRows, rogueAdrenalineRushSlider)
    AppendRow(mhOhRows, rogueBuffIconSlider)
    AppendRow(mhOhRows, barTextureRow)
    AppendRow(mhOhRows, barLayerRow)
    AppendRow(mhOhRows, rangedTextureRow)
    AppendRow(mhOhRows, sparkTextureRow)
    AppendRow(mhOhRows, sparkAlphaSlider)
    AppendRow(mhOhRows, sparkColorRow)
    AppendRow(mhOhRows, sparkLayerRow)
    AppendRow(mhOhRows, sparkWidthSlider)
    AppendRow(mhOhRows, sparkHeightSlider)
    AppendRow(mhOhRows, backgroundColorRow)
    AppendRow(mhOhRows, backgroundAlphaSlider)
    AppendRow(mhOhRows, indicatorBlendModeRow)
    AppendRow(mhOhRows, barBorderColorRow)
    AppendRow(mhOhRows, barBorderSlider)
    SetRowsShown(mhOhRows, not sectionCollapsed.mhOh)
    -- Class-specific visibility (overrides SetRowsShown for per-class sliders)
    local function ApplyMHOhClassVisibility()
        local collapsed = sectionCollapsed.mhOh or false
        local show = not collapsed
        for _, row in ipairs(mhOhRows) do
            if row and row.requiredClass then
                row:SetShown(show and ns.playerClass == row.requiredClass)
            end
        end
    end
    ApplyMHOhClassVisibility()
    -- Override header OnClick and refresh so collapse/expand re-applies class filtering
    mhOhHeader:SetScript("OnClick", function (self)
        local collapsed = sectionCollapsed.mhOh
        collapsed = not collapsed
        sectionCollapsed.mhOh = collapsed
        SetRowsShown(mhOhRows, not collapsed)
        ApplyMHOhClassVisibility()
        if mhOhHeader.arrow then
            mhOhHeader.arrow:SetText(collapsed and "+" or "-")
        end
        if ReflowConfigSections then
            ReflowConfigSections()
        end
    end)
    mhOhHeader.refresh = function ()
        local collapsed = sectionCollapsed.mhOh or false
        if mhOhHeader.arrow then
            mhOhHeader.arrow:SetText(collapsed and "+" or "-")
        end
        SetRowsShown(mhOhRows, not collapsed)
        ApplyMHOhClassVisibility()
        if ReflowConfigSections then
            ReflowConfigSections()
        end
    end

    local shamanHeader = CreateSectionHeader(content, "Shaman Weave Assist", PostQuickY(-750), {
        rows = shamanRows,
        getCollapsed = function () return sectionCollapsed.shaman end,
        setCollapsed = function (collapsed)
            sectionCollapsed.shaman = collapsed
        end
    })

    -- Section help text
    local shamanHelp = CreateDescriptionText(content,
        "Configure cast-breakpoint overlays for Enhancement Shaman weaving. " ..
        "Markers show the safe cast window and track live spell progress on the MH bar. " ..
        "Breakpoints account for latency and spell haste.",
        PostQuickY(-775)
    )
    AppendRow(shamanRows, shamanHelp)

    local weaveSparkTextureRow = CreateTexturePathRow(content, "Cast Breakpoint Spark Texture", PostQuickY(ShiftY(-725)), {
        mode = "browser",
        label = "Cast Breakpoint Spark Texture",
        yOffset = PostQuickY(ShiftY(-725)),
        defaultTexture = ns.DB_DEFAULTS.weaveSparkTexture,
        getTexture = function () return SuperSwingTimerDB.weaveSparkTexture or ns.DB_DEFAULTS.weaveSparkTexture end,
        applyTexture = function (texturePath)
            ns.ApplyWeaveSparkSettings(
                texturePath, SuperSwingTimerDB.weaveSparkWidth or ns.DB_DEFAULTS.weaveSparkWidth,
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
            Platynator = true
        },
        browserTitle = "Cast Breakpoint Spark Picker",
        tooltipText = "Type a texture path or click the browse icon to choose the cast-breakpoint spark preset (Target Indicator) or another texture."
    })

    local weaveSparkLayerRow = CreateCycleRow(
        content,
        "Cast Breakpoint Layer",
        PostQuickY(ShiftY(-760)),
        ns.TEXTURE_LAYER_OPTIONS,
        function () return SuperSwingTimerDB.weaveSparkTextureLayer or ns.DB_DEFAULTS.weaveSparkTextureLayer end,
        function (layer)
            ns.ApplyWeaveSparkTextureLayer(layer)
        end
    )
    weaveSparkLayerRow.isAdvanced = true

    local weaveSparkWidthSlider = CreateSlider(content, "Cast Spark Width", 2, 60, 1, PostQuickY(ShiftY(-795)), {
        tooltipText = "Width of the moving weave cast spark in pixels. This is the indicator that travels along the MH bar during an active cast."
    })
    weaveSparkWidthSlider:SetValue(SuperSwingTimerDB.weaveSparkWidth or ns.DB_DEFAULTS.weaveSparkWidth)
    SyncSliderDisplay(weaveSparkWidthSlider, weaveSparkWidthSlider:GetValue())
    weaveSparkWidthSlider.isAdvanced = true

    local weaveSparkHeightSlider = CreateSlider(content, "Cast Spark Height", 2, 100, 1, PostQuickY(ShiftY(-845)), {
        tooltipText = "Height of the moving weave cast spark in pixels. Clamped to the MH bar height if the value exceeds it."
    })
    weaveSparkHeightSlider:SetValue(SuperSwingTimerDB.weaveSparkHeight or ns.DB_DEFAULTS.weaveSparkHeight)
    SyncSliderDisplay(weaveSparkHeightSlider, weaveSparkHeightSlider:GetValue())
    weaveSparkHeightSlider.isAdvanced = true

    local weaveSparkAlphaSlider = CreateSlider(content, "Cast Spark Alpha", 0, 1, 0.05, PostQuickY(ShiftY(-895)))
    weaveSparkAlphaSlider:SetValue(
        SuperSwingTimerDB.weaveSparkAlpha ~= nil and SuperSwingTimerDB.weaveSparkAlpha or ns.DB_DEFAULTS.weaveSparkAlpha
    )
    SyncSliderDisplay(weaveSparkAlphaSlider, weaveSparkAlphaSlider:GetValue())
    weaveSparkAlphaSlider.isAdvanced = true

    local weaveMarkerNoteRow = CreateDescriptionText(
        content,
        "Breakpoint markers now use the tracked spell's icon automatically. "
            .. "Use the size, gap, alpha, and layer controls below to tune the small icon markers.",
        PostQuickY(ShiftY(-935))
    )
    weaveMarkerNoteRow.isAdvanced = true

    local weaveTriangleTopRow = nil
    local weaveTriangleBottomRow = nil

    local weaveTriangleLayerRow = CreateCycleRow(
        content,
        "Spell Icon Layer",
        PostQuickY(ShiftY(-1015)),
        ns.TEXTURE_LAYER_OPTIONS,
        function () return SuperSwingTimerDB.weaveTriangleTextureLayer or ns.DB_DEFAULTS.weaveTriangleTextureLayer end,
        function (layer)
            ns.ApplyWeaveTriangleSettings(
                SuperSwingTimerDB.weaveTriangleTopTexture or ns.DB_DEFAULTS.weaveTriangleTopTexture,
                SuperSwingTimerDB.weaveTriangleBottomTexture or ns.DB_DEFAULTS.weaveTriangleBottomTexture,
                SuperSwingTimerDB.weaveTriangleSize or ns.DB_DEFAULTS.weaveTriangleSize,
                SuperSwingTimerDB.weaveTriangleGap ~= nil and SuperSwingTimerDB.weaveTriangleGap or ns.DB_DEFAULTS.weaveTriangleGap,
                layer,
                SuperSwingTimerDB.weaveTriangleAlpha ~= nil and SuperSwingTimerDB.weaveTriangleAlpha
                    or ns.DB_DEFAULTS.weaveTriangleAlpha
            )
        end
    )
    weaveTriangleLayerRow.isAdvanced = true

    local weaveTriangleSizeSlider = CreateSlider(content, "Spell Icon Size", 6, 24, 1, PostQuickY(ShiftY(-1050)))
    weaveTriangleSizeSlider:SetValue(SuperSwingTimerDB.weaveTriangleSize or ns.DB_DEFAULTS.weaveTriangleSize)
    SyncSliderDisplay(weaveTriangleSizeSlider, weaveTriangleSizeSlider:GetValue())

    local weaveTriangleGapSlider = CreateSlider(content, "Spell Icon Gap", 0, 6, 1, PostQuickY(ShiftY(-1100)))
    weaveTriangleGapSlider:SetValue(
        SuperSwingTimerDB.weaveTriangleGap ~= nil and SuperSwingTimerDB.weaveTriangleGap or ns.DB_DEFAULTS.weaveTriangleGap
    )
    SyncSliderDisplay(weaveTriangleGapSlider, weaveTriangleGapSlider:GetValue())

    local weaveTriangleAlphaSlider = CreateSlider(content, "Spell Icon Alpha", 0, 1, 0.05, PostQuickY(ShiftY(-1150)))
    weaveTriangleAlphaSlider:SetValue(
        SuperSwingTimerDB.weaveTriangleAlpha ~= nil and SuperSwingTimerDB.weaveTriangleAlpha
            or ns.DB_DEFAULTS.weaveTriangleAlpha
    )
    SyncSliderDisplay(weaveTriangleAlphaSlider, weaveTriangleAlphaSlider:GetValue())
    shamanRows[1] = weaveSparkTextureRow
    shamanRows[2] = weaveSparkLayerRow
    shamanRows[3] = weaveSparkWidthSlider
    shamanRows[4] = weaveSparkHeightSlider
    shamanRows[5] = weaveSparkAlphaSlider
    shamanRows[6] = weaveMarkerNoteRow
    shamanRows[7] = weaveTriangleLayerRow
    shamanRows[8] = weaveTriangleSizeSlider
    shamanRows[9] = weaveTriangleGapSlider
    shamanRows[10] = weaveTriangleAlphaSlider
    if ns.playerClass == "SHAMAN" then
        SetRowsShown(shamanRows, not sectionCollapsed.shaman)
        if shamanHeader.refresh then
            shamanHeader.refresh()
        end
    else
        shamanHeader:Hide()
        SetRowsShown(shamanRows, false)
    end

    local generalHeader = CreateSectionHeader(content, "Combat & Timer Behavior", PostQuickY(-1340), {
        rows = generalRows,
        getCollapsed = function () return sectionCollapsed.general end,
        setCollapsed = function (collapsed)
            sectionCollapsed.general = collapsed
        end
    })

    -- Section help text
    local generalHelp = CreateDescriptionText(content,
        "Toggle timing helpers and visual feedback options. " ..
        "Swing Flash briefly brightens the spark on each landing. " ..
        "GCD Ticker shows a thin bar above the MH for the global cooldown.",
        PostQuickY(-1365)
    )
    AppendRow(generalRows, generalHelp)

    local lockBarsRow = CreateToggleRow(
        content,
        "Lock / Unlock Bars",
        PostQuickY(ShiftY(-1355)),
        function () return SuperSwingTimerDB.lockBars == true end,
        function (enabled)
            SuperSwingTimerDB.lockBars = enabled
            if ns.ApplyLockBars then
                ns.ApplyLockBars()
            end
        end
    )
    local testBarsRow = CreateActionRow(content, "Test Bars", "Preview 16s", PostQuickY(ShiftY(-1385)), function ()
        StartBarTestPreview(16)
    end,
        "Temporarily show the bars for sixteen seconds with animated swing cycles so you can reposition them when unlocked."
    )
    generalRows[1] = lockBarsRow
    generalRows[2] = testBarsRow
    SetRowsShown(generalRows, not sectionCollapsed.general)
    if generalHeader.refresh then
        generalHeader.refresh()
    end

    widthSlider:SetScript("OnValueChanged", function (self, value)
        value = math.floor(value + 0.5)
        SyncSliderDisplay(self, value)
        ns.ApplyBarSize(value, heightSlider:GetValue())
    end)

    heightSlider:SetScript("OnValueChanged", function (self, value)
        value = math.floor(value + 0.5)
        SyncSliderDisplay(self, value)
        ns.ApplyBarSize(widthSlider:GetValue(), value)
    end)

    if hunterCastBarHeightSlider then
        hunterCastBarHeightSlider:SetScript("OnValueChanged", function (self, value)
            value = math.floor(value + 0.5)
            SyncSliderDisplay(self, value)
            SuperSwingTimerDB.hunterCastBarHeight = value
            ns.HUNTER_CAST_BAR_HEIGHT = value
            ns.ApplyBarSize(widthSlider:GetValue(), heightSlider:GetValue())
        end)
    end

    if rogueSndBarHeightSlider then
        rogueSndBarHeightSlider:SetScript("OnValueChanged", function (self, value)
            value = math.floor(value + 0.5)
            SyncSliderDisplay(self, value)
            SuperSwingTimerDB.rogueSliceAndDiceBarHeight = value
            ns.ROGUE_SLICE_AND_DICE_BAR_HEIGHT = value
            ns.ApplyBarSize(widthSlider:GetValue(), heightSlider:GetValue())
        end)
    end

    if rogueEnergyTickSlider then
        rogueEnergyTickSlider:SetScript("OnValueChanged", function (self, value)
            value = math.floor(value + 0.5)
            SyncSliderDisplay(self, value)
            SuperSwingTimerDB.rogueEnergyTickBarWidth = value
            ns.ROGUE_ENERGY_TICK_BAR_WIDTH = value
        end)
    end

    if druidEnergyTickSlider then
        druidEnergyTickSlider:SetScript("OnValueChanged", function (self, value)
            value = math.floor(value + 0.5)
            SyncSliderDisplay(self, value)
            SuperSwingTimerDB.druidEnergyTickBarWidth = value
            ns.DRUID_ENERGY_TICK_BAR_WIDTH = value
            if ns.UpdateDruidEnergyTickVisual then
                ns.UpdateDruidEnergyTickVisual()
            end
        end)
    end

    if hunterRangeHelperWidthSlider then
        hunterRangeHelperWidthSlider:SetScript("OnValueChanged", function (self, value)
            value = math.floor(value + 0.5)
            SyncSliderDisplay(self, value)
            SuperSwingTimerDB.hunterRangeHelperWidth = value
            ns.HUNTER_RANGE_HELPER_WIDTH = value
            if ns.UpdateHunterRangeHelperVisual then
                ns.UpdateHunterRangeHelperVisual()
            end
        end)
    end

    if hunterRapidFireSlider then
        hunterRapidFireSlider:SetScript("OnValueChanged", function (self, value)
            value = math.floor(value + 0.5)
            SyncSliderDisplay(self, value)
            SuperSwingTimerDB.hunterRapidFireBarHeight = value
            ns.HUNTER_RAPID_FIRE_BAR_HEIGHT = value
        end)
    end

    if hunterBuffIconSlider then
        hunterBuffIconSlider:SetScript("OnValueChanged", function (self, value)
            value = math.floor(value + 0.5)
            SyncSliderDisplay(self, value)
            SuperSwingTimerDB.hunterBuffIconSize = value
        end)
    end

    if warriorShieldBlockSlider then
        warriorShieldBlockSlider:SetScript("OnValueChanged", function (self, value)
            value = math.floor(value + 0.5)
            SyncSliderDisplay(self, value)
            SuperSwingTimerDB.warriorShieldBlockBarHeight = value
            ns.WARRIOR_SHIELD_BLOCK_BAR_HEIGHT = value
        end)
    end

    if warriorBuffIconSlider then
        warriorBuffIconSlider:SetScript("OnValueChanged", function (self, value)
            value = math.floor(value + 0.5)
            SyncSliderDisplay(self, value)
            SuperSwingTimerDB.warriorBuffIconSize = value
        end)
    end

    if paladinBuffIconSlider then
        paladinBuffIconSlider:SetScript("OnValueChanged", function (self, value)
            value = math.floor(value + 0.5)
            SyncSliderDisplay(self, value)
            SuperSwingTimerDB.paladinBuffIconSize = value
        end)
    end

    if shamanLightningGapSlider then
        shamanLightningGapSlider:SetScript("OnValueChanged", function (self, value)
            value = math.floor(value + 0.5)
            SyncSliderDisplay(self, value)
            SuperSwingTimerDB.shamanLightningTrackerGap = value
            if ns.UpdateLightningShieldVisual then
                ns.UpdateLightningShieldVisual()
            end
        end)
    end

    if shamanBuffIconSlider then
        shamanBuffIconSlider:SetScript("OnValueChanged", function (self, value)
            value = math.floor(value + 0.5)
            SyncSliderDisplay(self, value)
            SuperSwingTimerDB.shamanBuffIconSize = value
        end)
    end

    if rogueAdrenalineRushSlider then
        rogueAdrenalineRushSlider:SetScript("OnValueChanged", function (self, value)
            value = math.floor(value + 0.5)
            SyncSliderDisplay(self, value)
            SuperSwingTimerDB.rogueAdrenalineRushBarHeight = value
            ns.ROGUE_ADRENALINE_RUSH_BAR_HEIGHT = value
        end)
    end

    if rogueBuffIconSlider then
        rogueBuffIconSlider:SetScript("OnValueChanged", function (self, value)
            value = math.floor(value + 0.5)
            SyncSliderDisplay(self, value)
            SuperSwingTimerDB.rogueBuffIconSize = value
        end)
    end

    sparkWidthSlider:SetScript("OnValueChanged", function (self, value)
        value = math.floor(value + 0.5)
        SyncSliderDisplay(self, value)
        ns.ApplySparkSettings(
            SuperSwingTimerDB.sparkTexture or ns.DB_DEFAULTS.sparkTexture, value, sparkHeightSlider:GetValue(),
            SuperSwingTimerDB.sparkTextureLayer or ns.DB_DEFAULTS.sparkTextureLayer,
            SuperSwingTimerDB.sparkAlpha ~= nil and SuperSwingTimerDB.sparkAlpha or ns.DB_DEFAULTS.sparkAlpha
        )
    end)

    sparkHeightSlider:SetScript("OnValueChanged", function (self, value)
        value = math.floor(value + 0.5)
        SyncSliderDisplay(self, value)
        ns.ApplySparkSettings(
            SuperSwingTimerDB.sparkTexture or ns.DB_DEFAULTS.sparkTexture, sparkWidthSlider:GetValue(), value,
            SuperSwingTimerDB.sparkTextureLayer or ns.DB_DEFAULTS.sparkTextureLayer,
            SuperSwingTimerDB.sparkAlpha ~= nil and SuperSwingTimerDB.sparkAlpha or ns.DB_DEFAULTS.sparkAlpha
        )
    end)

    backgroundAlphaSlider:SetScript("OnValueChanged", function (self, value)
        value = math.floor((value + 0.0001) * 100) / 100
        SyncSliderDisplay(self, value)
        ns.ApplyBarBackgroundAlpha(value)
    end)

    sparkAlphaSlider:SetScript("OnValueChanged", function (self, value)
        value = math.floor((value + 0.0001) * 100) / 100
        SyncSliderDisplay(self, value)
        ns.ApplySparkAlpha(value)
    end)

    weaveSparkWidthSlider:SetScript("OnValueChanged", function (self, value)
        value = math.floor(value + 0.5)
        SyncSliderDisplay(self, value)
        ns.ApplyWeaveSparkSettings(
            SuperSwingTimerDB.weaveSparkTexture or ns.DB_DEFAULTS.weaveSparkTexture, value,
            weaveSparkHeightSlider:GetValue(),
            SuperSwingTimerDB.weaveSparkTextureLayer or ns.DB_DEFAULTS.weaveSparkTextureLayer,
            SuperSwingTimerDB.weaveSparkAlpha ~= nil and SuperSwingTimerDB.weaveSparkAlpha or ns.DB_DEFAULTS.weaveSparkAlpha
        )
    end)

    weaveSparkHeightSlider:SetScript("OnValueChanged", function (self, value)
        value = math.floor(value + 0.5)
        SyncSliderDisplay(self, value)
        ns.ApplyWeaveSparkSettings(
            SuperSwingTimerDB.weaveSparkTexture or ns.DB_DEFAULTS.weaveSparkTexture, weaveSparkWidthSlider:GetValue(),
            value, SuperSwingTimerDB.weaveSparkTextureLayer or ns.DB_DEFAULTS.weaveSparkTextureLayer,
            SuperSwingTimerDB.weaveSparkAlpha ~= nil and SuperSwingTimerDB.weaveSparkAlpha or ns.DB_DEFAULTS.weaveSparkAlpha
        )
    end)

    weaveSparkAlphaSlider:SetScript("OnValueChanged", function (self, value)
        value = math.floor((value + 0.0001) * 100) / 100
        SyncSliderDisplay(self, value)
        ns.ApplyWeaveSparkAlpha(value)
    end)

    weaveTriangleSizeSlider:SetScript("OnValueChanged", function (self, value)
        value = math.floor(value + 0.5)
        SyncSliderDisplay(self, value)
        ns.ApplyWeaveTriangleSettings(
            SuperSwingTimerDB.weaveTriangleTopTexture or ns.DB_DEFAULTS.weaveTriangleTopTexture,
            SuperSwingTimerDB.weaveTriangleBottomTexture or ns.DB_DEFAULTS.weaveTriangleBottomTexture, value,
            weaveTriangleGapSlider:GetValue(),
            SuperSwingTimerDB.weaveTriangleTextureLayer or ns.DB_DEFAULTS.weaveTriangleTextureLayer,
            SuperSwingTimerDB.weaveTriangleAlpha ~= nil and SuperSwingTimerDB.weaveTriangleAlpha
                or ns.DB_DEFAULTS.weaveTriangleAlpha
        )
    end)

    weaveTriangleGapSlider:SetScript("OnValueChanged", function (self, value)
        value = math.floor(value + 0.5)
        SyncSliderDisplay(self, value)
        ns.ApplyWeaveTriangleSettings(
            SuperSwingTimerDB.weaveTriangleTopTexture or ns.DB_DEFAULTS.weaveTriangleTopTexture,
            SuperSwingTimerDB.weaveTriangleBottomTexture or ns.DB_DEFAULTS.weaveTriangleBottomTexture,
            weaveTriangleSizeSlider:GetValue(), value,
            SuperSwingTimerDB.weaveTriangleTextureLayer or ns.DB_DEFAULTS.weaveTriangleTextureLayer,
            SuperSwingTimerDB.weaveTriangleAlpha ~= nil and SuperSwingTimerDB.weaveTriangleAlpha
                or ns.DB_DEFAULTS.weaveTriangleAlpha
        )
    end)

    weaveTriangleAlphaSlider:SetScript("OnValueChanged", function (self, value)
        value = math.floor((value + 0.0001) * 100) / 100
        SyncSliderDisplay(self, value)
        ns.ApplyWeaveTriangleSettings(
            SuperSwingTimerDB.weaveTriangleTopTexture or ns.DB_DEFAULTS.weaveTriangleTopTexture,
            SuperSwingTimerDB.weaveTriangleBottomTexture or ns.DB_DEFAULTS.weaveTriangleBottomTexture,
            weaveTriangleSizeSlider:GetValue(), weaveTriangleGapSlider:GetValue(),
            SuperSwingTimerDB.weaveTriangleTextureLayer or ns.DB_DEFAULTS.weaveTriangleTextureLayer, value
        )
    end)

    local weaveFamiliesHeader = CreateSectionHeader(content, "Shaman Weave Spells", PostQuickY(-1708), {
        rows = weaveFamiliesRows,
        getCollapsed = function () return sectionCollapsed.weaveFamilies end,
        setCollapsed = function (collapsed)
            sectionCollapsed.weaveFamilies = collapsed
        end
    })
    local weaveFamiliesDescription = CreateDescriptionText(
        content,
        "Each family below is color-coded to match its spell breakpoint family. " .. "Toggle a family off to remove every rank in that family from the weave helper. "
            .. "The small breakpoint icons use the tracked spell's real icon, stay attached to the MH swing bar, and move with spell haste.",
        PostQuickY(-1736)
    )

    local weaveFamilyRows = {
        CreateWeaveFamilyRow(content, "LB", "Lightning Bolt", PostQuickY(-1750)),
        CreateWeaveFamilyRow(content, "CL", "Chain Lightning", PostQuickY(-1778)),
        CreateWeaveFamilyRow(content, "HW", "Healing Wave", PostQuickY(-1806)),
        CreateWeaveFamilyRow(content, "LHW", "Lesser Healing Wave", PostQuickY(-1834)),
        CreateWeaveFamilyRow(content, "CH", "Chain Heal", PostQuickY(-1862))
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

    local function LayoutSectionRows(header, rows, topY, options)
        if not header or not header:IsShown() then
            return topY
        end

        options = options or {}
        local gapAfterHeader = options.gapAfterHeader or 16
        local rowSpacing = options.rowSpacing or 10

        PositionRowAtY(content, header, topY)
        local nextY = topY - GetRowLayoutHeight(header) - gapAfterHeader
        for _, row in ipairs(rows or {}) do
            if row and row:IsShown() then
                PositionRowAtY(content, row, nextY)
                nextY = nextY - GetRowLayoutHeight(row) - rowSpacing
            end
        end

        return nextY
    end

    local function ReflowQuickControls()
        local headerTopY = -10
        PositionRowAtY(content, barVisibilityHeader, headerTopY)
        local headerBottomY = headerTopY - GetRowLayoutHeight(barVisibilityHeader)

        if sectionCollapsed.barVisibility then
            SetRowsShown(barVisibilityRows, false)
            quickSectionBottomY = headerBottomY
            return headerBottomY
        end

        SetRowsShown(barVisibilityRows, true)
        local contentWidth = content:GetWidth() or 720
        local outerInset = 20
        local usableWidth = contentWidth - (outerInset * 2)

        -- Position tab buttons in a row below the header
        local tabY = headerBottomY - 28
        local tabCount = #quickTabButtons
        local tabWidth = math.min(120, math.floor(usableWidth / tabCount) - 8)
        local totalTabsWidth = tabCount * tabWidth + (tabCount - 1) * 6
        local tabStartX = math.floor((contentWidth - totalTabsWidth) / 2)
        for i, btn in ipairs(quickTabButtons) do
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", content, "TOPLEFT", tabStartX + (i - 1) * (tabWidth + 6), tabY)
            btn:SetWidth(tabWidth)
            if btn.refresh then btn.refresh() end
        end

        local activeTab = sectionCollapsed.quickTab or "visibility"
        local tabBottomY = tabY - 24

        -- Helper: show/hide rows based on tab
        local function ShowRowsForTab(rows, tabMatch, insetLeft, insetRight, yRef)
            local nextY = yRef - 4
            local shown = false
            for _, row in ipairs(rows) do
                if row and row:IsShown() and (row.quickTab or "visibility") == tabMatch then
                    PositionRowBetween(content, row, insetLeft, insetRight, nextY)
                    nextY = nextY - GetRowLayoutHeight(row) - 4
                    shown = true
                elseif row and row.SetShown then
                    row:SetShown(false)
                end
            end
            return nextY, shown
        end

        -- Show only rows for the active tab
        if activeTab == "visibility" then
            local endY = ShowRowsForTab(quickToggleRows, "visibility", outerInset, contentWidth - outerInset, tabBottomY)
            ShowRowsForTab(quickColorRows, "visibility", outerInset, contentWidth - outerInset, tabBottomY)
            quickSectionBottomY = endY

        elseif activeTab == "colors" then
            -- 2-column grid for color swatches
            local gutter = 16
            local columnWidth = math.floor((usableWidth - gutter) / 2)
            local leftStart = outerInset
            local rightStart = outerInset + columnWidth + gutter
            local leftY = tabBottomY - 4
            local rightY = tabBottomY - 4
            local colIdx = 0
            for _, row in ipairs(quickColorRows) do
                if row and row:IsShown() and (row.quickTab or "colors") == "colors" then
                    colIdx = colIdx + 1
                    if colIdx % 2 == 1 then
                        PositionRowBetween(content, row, leftStart, leftStart + columnWidth, leftY)
                        leftY = leftY - GetRowLayoutHeight(row) - 4
                    else
                        PositionRowBetween(content, row, rightStart, rightStart + columnWidth, rightY)
                        rightY = rightY - GetRowLayoutHeight(row) - 4
                    end
                elseif row and row.SetShown then
                    row:SetShown(false)
                end
            end
            ShowRowsForTab(quickToggleRows, "colors", outerInset, contentWidth - outerInset, tabBottomY)
            quickSectionBottomY = math.min(leftY, rightY)

        elseif activeTab == "class" then
            -- Class tab: show all rows from both lists in a single column
            -- (class-specific rows auto-filter since they're only created for the active class)
            local classY = tabBottomY - 4
            for _, row in ipairs(barVisibilityRows) do
                if row and row:IsShown() and row ~= quickToggleLabel and row ~= quickColorLabel
                    and not row.quickTabBtn then
                    local isTabBtn = false
                    for _, btn in ipairs(quickTabButtons) do
                        if row == btn then isTabBtn = true; break end
                    end
                    if not isTabBtn then
                        PositionRowBetween(content, row, outerInset, contentWidth - outerInset, classY)
                        classY = classY - GetRowLayoutHeight(row) - 4
                    end
                end
            end
            quickSectionBottomY = classY
        end

        return quickSectionBottomY
    end

    ReflowConfigSections = function ()
        local sectionY = ReflowQuickControls() - 26
        sectionY = LayoutSectionRows(mhOhHeader, mhOhRows, sectionY, {
            gapAfterHeader = 22,
            rowSpacing = 14
        })

        if shamanHeader:IsShown() then
            sectionY = LayoutSectionRows(shamanHeader, shamanRows, sectionY - 8, {
                gapAfterHeader = 22,
                rowSpacing = 14
            })
        end

        sectionY = LayoutSectionRows(generalHeader, generalRows, sectionY - 8, {
            gapAfterHeader = 20,
            rowSpacing = 14
        })

        if weaveFamiliesHeader:IsShown() then
            sectionY = LayoutSectionRows(weaveFamiliesHeader, weaveFamiliesRows, sectionY - 8, {
                gapAfterHeader = 20,
                rowSpacing = 12
            })
        end

        local contentHeight = math.max(math.ceil(-sectionY) + 120, 2200)
        content:SetHeight(contentHeight)
    end

    local function AttachHeaderReflow(header)
        if not header then
            return
        end

        local originalOnClick = header:GetScript("OnClick")
        if originalOnClick then
            header:SetScript("OnClick", function (self, ...)
                originalOnClick(self, ...)
                if ReflowConfigSections then
                    ReflowConfigSections()
                end
            end)
        end

        local originalRefresh = header.refresh
        header.refresh = function (...)
            if originalRefresh then
                originalRefresh(...)
            end
            if ReflowConfigSections then
                ReflowConfigSections()
            end
        end
    end

    AttachHeaderReflow(barVisibilityHeader)
    AttachHeaderReflow(shamanHeader)
    AttachHeaderReflow(generalHeader)
    AttachHeaderReflow(weaveFamiliesHeader)

    -- ============================================================
    -- Per-section Reset callbacks (defined here after all controls exist)
    -- ============================================================

    -- Appearance section reset
    mhOhHeader.setResetCallback(function ()
        local d = ns.DB_DEFAULTS
        local set = function (dbKey, slider, defVal)
            SuperSwingTimerDB[dbKey] = defVal
            if slider and slider.SetValue then slider:SetValue(defVal) end
        end
        local function setColor(dbKey, def)
            SuperSwingTimerDB[dbKey] = { r = def.r, g = def.g, b = def.b, a = def.a }
        end

        set("barWidth", widthSlider, d.barWidth)
        set("barHeight", heightSlider, d.barHeight)
        set("hunterCastBarHeight", hunterCastBarHeightSlider, d.hunterCastBarHeight)
        set("rogueSliceAndDiceBarHeight", rogueSndBarHeightSlider, d.rogueSliceAndDiceBarHeight)
        set("rogueEnergyTickBarWidth", rogueEnergyTickSlider, d.rogueEnergyTickBarWidth)
        set("druidEnergyTickBarWidth", druidEnergyTickSlider, d.druidEnergyTickBarWidth)
        set("hunterRangeHelperWidth", hunterRangeHelperWidthSlider, d.hunterRangeHelperWidth)
        set("hunterRapidFireBarHeight", hunterRapidFireSlider, d.hunterRapidFireBarHeight)
        set("hunterBuffIconSize", hunterBuffIconSlider, d.hunterBuffIconSize)
        set("warriorShieldBlockBarHeight", warriorShieldBlockSlider, d.warriorShieldBlockBarHeight)
        set("warriorBuffIconSize", warriorBuffIconSlider, d.warriorBuffIconSize)
        set("paladinBuffIconSize", paladinBuffIconSlider, d.paladinBuffIconSize)
        set("shamanBuffIconSize", shamanBuffIconSlider, d.shamanBuffIconSize)
        set("shamanLightningTrackerGap", shamanLightningGapSlider, d.shamanLightningTrackerGap or 6)
        set("rogueAdrenalineRushBarHeight", rogueAdrenalineRushSlider, d.rogueAdrenalineRushBarHeight)
        set("rogueBuffIconSize", rogueBuffIconSlider, d.rogueBuffIconSize)

        SuperSwingTimerDB.barTexture = d.barTexture
        SuperSwingTimerDB.barTextureLayer = d.barTextureLayer
        SuperSwingTimerDB.rangedBarTexture = d.rangedBarTexture
        SuperSwingTimerDB.sparkTexture = d.sparkTexture
        SuperSwingTimerDB.sparkTextureLayer = d.sparkTextureLayer
        set("sparkWidth", sparkWidthSlider, d.sparkWidth)
        set("sparkHeight", sparkHeightSlider, d.sparkHeight)
        set("sparkAlpha", sparkAlphaSlider, d.sparkAlpha)
        setColor("sparkColor", d.sparkColor)
        set("barBackgroundAlpha", backgroundAlphaSlider, d.barBackgroundAlpha)
        setColor("barBackgroundColor", d.barBackgroundColor)
        SuperSwingTimerDB.indicatorBlendMode = d.indicatorBlendMode
        setColor("barBorderColor", d.barBorderColor)
        set("barBorderSize", barBorderSlider, d.barBorderSize)

        -- Refresh custom rows
        if barTextureRow and barTextureRow.refresh then barTextureRow.refresh() end
        if barLayerRow and barLayerRow.refresh then barLayerRow.refresh() end
        if rangedTextureRow and rangedTextureRow.refresh then rangedTextureRow.refresh() end
        if sparkTextureRow and sparkTextureRow.refresh then sparkTextureRow.refresh() end
        if sparkLayerRow and sparkLayerRow.refresh then sparkLayerRow.refresh() end
        if indicatorBlendModeRow and indicatorBlendModeRow.refresh then indicatorBlendModeRow.refresh() end

        -- Apply
        ns.ApplyBarSize(d.barWidth, d.barHeight)
        ns.ApplyBarTexture(d.barTexture, d.barTextureLayer)
        ns.ApplyRangedBarTexture(d.rangedBarTexture, d.barTextureLayer)
        ns.ApplySparkSettings(d.sparkTexture, d.sparkWidth, d.sparkHeight, d.sparkTextureLayer, d.sparkAlpha, d.sparkColor)
        ns.ApplyBarBackgroundColor(d.barBackgroundColor)
        ns.ApplyBarBorderColor(d.barBorderColor)
        ns.ApplyBarBorderSize(d.barBorderSize)
        ns.ApplyIndicatorBlendMode(d.indicatorBlendMode)

        -- Refresh color swatches for this section
        for _, row in ipairs(colorRowsSection) do
            if row and row.button then
                local key = row.button.colorKey
                local c = ns.GetBarColor(key)
                if c then row.swatch:SetColorTexture(c.r, c.g, c.b, c.a) end
            end
        end
    end)

    -- Shaman Weave Assist section reset
    shamanHeader.setResetCallback(function ()
        local d = ns.DB_DEFAULTS
        SuperSwingTimerDB.weaveSparkTexture = d.weaveSparkTexture
        SuperSwingTimerDB.weaveSparkTextureLayer = d.weaveSparkTextureLayer
        SuperSwingTimerDB.weaveSparkWidth = d.weaveSparkWidth
        SuperSwingTimerDB.weaveSparkHeight = d.weaveSparkHeight
        SuperSwingTimerDB.weaveSparkAlpha = d.weaveSparkAlpha
        SuperSwingTimerDB.weaveTriangleTopTexture = d.weaveTriangleTopTexture
        SuperSwingTimerDB.weaveTriangleBottomTexture = d.weaveTriangleBottomTexture
        SuperSwingTimerDB.weaveTriangleTextureLayer = d.weaveTriangleTextureLayer
        SuperSwingTimerDB.weaveTriangleSize = d.weaveTriangleSize
        SuperSwingTimerDB.weaveTriangleGap = d.weaveTriangleGap
        SuperSwingTimerDB.weaveTriangleAlpha = d.weaveTriangleAlpha

        -- Sync sliders
        weaveSparkWidthSlider:SetValue(d.weaveSparkWidth)
        weaveSparkHeightSlider:SetValue(d.weaveSparkHeight)
        weaveSparkAlphaSlider:SetValue(d.weaveSparkAlpha)
        weaveTriangleSizeSlider:SetValue(d.weaveTriangleSize)
        weaveTriangleGapSlider:SetValue(d.weaveTriangleGap)
        weaveTriangleAlphaSlider:SetValue(d.weaveTriangleAlpha)

        -- Refresh custom rows
        if weaveSparkTextureRow and weaveSparkTextureRow.refresh then weaveSparkTextureRow.refresh() end
        if weaveSparkLayerRow and weaveSparkLayerRow.refresh then weaveSparkLayerRow.refresh() end
        if weaveTriangleLayerRow and weaveTriangleLayerRow.refresh then weaveTriangleLayerRow.refresh() end

        -- Apply
        ns.ApplyWeaveSparkSettings(d.weaveSparkTexture, d.weaveSparkWidth, d.weaveSparkHeight, d.weaveSparkTextureLayer, d.weaveSparkAlpha)
        ns.ApplyWeaveTriangleSettings(d.weaveTriangleTopTexture, d.weaveTriangleBottomTexture, d.weaveTriangleSize, d.weaveTriangleGap, d.weaveTriangleTextureLayer, d.weaveTriangleAlpha)
    end)

    -- Combat & Timer Behavior section reset
    generalHeader.setResetCallback(function ()
        local d = ns.DB_DEFAULTS
        SuperSwingTimerDB.lockBars = d.lockBars
        if lockBarsRow and lockBarsRow.refresh then lockBarsRow.refresh() end
        if ns.ApplyLockBars then ns.ApplyLockBars() end
    end)

    -- Shaman Weave Spells section reset
    weaveFamiliesHeader.setResetCallback(function ()
        local d = ns.DB_DEFAULTS
        SuperSwingTimerDB.weaveSpellFamilies = {}
        for key, val in pairs(d.weaveSpellFamilies) do
            SuperSwingTimerDB.weaveSpellFamilies[key] = val
        end
        for _, row in ipairs(weaveFamilyRows) do
            if row and row.refresh then row.refresh() end
        end
    end)

    ReflowConfigSections()
    f.ReflowConfigSections = ReflowConfigSections

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

    resetBtn:SetScript("OnEnter", function (self)
        resetBg:SetColorTexture(0.3, 0.3, 0.3, 0.9)
    end)
    resetBtn:SetScript("OnLeave", function (self)
        resetBg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
    end)
    resetBtn:SetScript("OnClick", function ()
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
        if shamanLightningGapSlider then
            shamanLightningGapSlider:SetValue(ns.DB_DEFAULTS.shamanLightningTrackerGap or 6)
        end
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
        if topMinimalModeRow and topMinimalModeRow.refresh then
            topMinimalModeRow.refresh()
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
        if showHunterRangeHelperRow and showHunterRangeHelperRow.refresh then
            showHunterRangeHelperRow.refresh()
        end
        if showEnemyRow and showEnemyRow.refresh then
            showEnemyRow.refresh()
        end
        if showWeaveRow and showWeaveRow.refresh then
            showWeaveRow.refresh()
        end
        if showRogueAssistRow and showRogueAssistRow.refresh then
            showRogueAssistRow.refresh()
        end
        if showRogueEnergyRow and showRogueEnergyRow.refresh then
            showRogueEnergyRow.refresh()
        end
        if showDruidEnergyRow and showDruidEnergyRow.refresh then
            showDruidEnergyRow.refresh()
        end
        if showRogueSliceAndDiceRow and showRogueSliceAndDiceRow.refresh then
            showRogueSliceAndDiceRow.refresh()
        end
        -- Update color swatches
        for _, row in ipairs(colorRowsSection) do
            if row and row.button then
                local key = row.button.colorKey
                local c = ns.GetBarColor(key)
                if c then
                    row.swatch:SetColorTexture(c.r, c.g, c.b, c.a)
                end
            end
        end
    end)

    f.widthSlider = widthSlider
    f.heightSlider = heightSlider
    f.hunterCastBarHeightSlider = hunterCastBarHeightSlider
    f.rogueSndBarHeightSlider = rogueSndBarHeightSlider
    f.rogueEnergyTickSlider = rogueEnergyTickSlider
    f.druidEnergyTickSlider = druidEnergyTickSlider
    f.hunterRangeHelperWidthSlider = hunterRangeHelperWidthSlider
    f.hunterRapidFireSlider = hunterRapidFireSlider
    f.hunterBuffIconSlider = hunterBuffIconSlider
    f.warriorShieldBlockSlider = warriorShieldBlockSlider
    f.warriorBuffIconSlider = warriorBuffIconSlider
    f.paladinBuffIconSlider = paladinBuffIconSlider
    f.shamanLightningGapSlider = shamanLightningGapSlider

    f.rogueAdrenalineRushSlider = rogueAdrenalineRushSlider
    f.rogueBuffIconSlider = rogueBuffIconSlider
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
    f.textureRows = { barTextureRow, rangedTextureRow, sparkTextureRow, weaveSparkTextureRow }
    f.sparkWidthSlider = sparkWidthSlider
    f.sparkHeightSlider = sparkHeightSlider
    f.backgroundAlphaSlider = backgroundAlphaSlider
    f.barBorderColorRow = barBorderColorRow
    f.barBorderSlider = barBorderSlider
    f.indicatorBlendModeRow = indicatorBlendModeRow
    f.minimalModeRow = topMinimalModeRow
    f.lockBarsRow = lockBarsRow
    f.lockBarsQuickRow = lockBarsQuickRow
    f.showMHRow = showMHRow
    f.showOHRow = showOHRow
    f.showRangedRow = showRangedRow
    f.showHunterRangeHelperRow = showHunterRangeHelperRow
    f.showEnemyRow = showEnemyRow
    f.showWeaveRow = showWeaveRow
    f.showRogueAssistRow = showRogueAssistRow
    f.showRogueEnergyRow = showRogueEnergyRow
    f.showDruidEnergyRow = showDruidEnergyRow
    f.showRogueSliceAndDiceRow = showRogueSliceAndDiceRow
    f.useClassColorsRow = useClassColorsRow
    f.weaveFamilyRows = weaveFamilyRows
    f.colorRows = colorRowsSection

    -- Register Test Bars hook at front of OnUpdate chain.
    -- Runs BEFORE the core render path so AnimateTestBars() can override
    -- bar values before the normal frame update logic runs.
    if not ns._testBarsHookRegistered then
        ns.RegisterOnUpdateHook(function (elapsed)
            if ns.barTestActive then
                AnimateTestBars()
            end
        end, 1)  -- Position 1 = runs before core render
        ns._testBarsHookRegistered = true
    end

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
    if panel then
        return
    end
    panel = CreatePanel()
end

--- Open or close the /sst config panel. Initializes the panel
--  on first call. Refreshes slider values from DB before showing.
--  @return (nil)
--  @usage Bound to /sst, /super, /superswingtimer slash commands
function ns.ToggleConfig()
    if not panel and ns.InitConfig then
        ns.InitConfig()
    end
    if not panel then return end
    if panel:IsShown() then
        panel:Hide()
    else
        -- Refresh slider values from DB before showing
        if panel.globalScaleSlider then
            panel.globalScaleSlider:SetValue(SuperSwingTimerDB.globalScale or ns.DB_DEFAULTS.globalScale or 1.0)
            SyncSliderDisplay(panel.globalScaleSlider, SuperSwingTimerDB.globalScale or ns.DB_DEFAULTS.globalScale or 1.0)
        end
        panel.widthSlider:SetValue(SuperSwingTimerDB.barWidth or ns.DB_DEFAULTS.barWidth)
        panel.heightSlider:SetValue(SuperSwingTimerDB.barHeight or ns.DB_DEFAULTS.barHeight)
        if panel.hunterCastBarHeightSlider then
            panel.hunterCastBarHeightSlider:SetValue(
                SuperSwingTimerDB.hunterCastBarHeight or ns.DB_DEFAULTS.hunterCastBarHeight or 10
            )
        end
        if panel.rogueSndBarHeightSlider then
            panel.rogueSndBarHeightSlider:SetValue(
                SuperSwingTimerDB.rogueSliceAndDiceBarHeight or ns.DB_DEFAULTS.rogueSliceAndDiceBarHeight or 4
            )
        end
        if panel.rogueEnergyTickSlider then
            panel.rogueEnergyTickSlider:SetValue(
                SuperSwingTimerDB.rogueEnergyTickBarWidth or ns.DB_DEFAULTS.rogueEnergyTickBarWidth or 4
            )
        end
        if panel.hunterRangeHelperWidthSlider then
            panel.hunterRangeHelperWidthSlider:SetValue(
                SuperSwingTimerDB.hunterRangeHelperWidth or ns.DB_DEFAULTS.hunterRangeHelperWidth or 7
            )
        end
        if panel.hunterRapidFireSlider then
            panel.hunterRapidFireSlider:SetValue(
                SuperSwingTimerDB.hunterRapidFireBarHeight or ns.DB_DEFAULTS.hunterRapidFireBarHeight or 4
            )
        end
        if panel.warriorShieldBlockSlider then
            panel.warriorShieldBlockSlider:SetValue(
                SuperSwingTimerDB.warriorShieldBlockBarHeight or ns.DB_DEFAULTS.warriorShieldBlockBarHeight or 4
            )
        end
        if panel.shamanLightningGapSlider then
            panel.shamanLightningGapSlider:SetValue(
                SuperSwingTimerDB.shamanLightningTrackerGap or ns.DB_DEFAULTS.shamanLightningTrackerGap or 6
            )
        end
        if panel.druidPowerShiftSlider then
            panel.druidPowerShiftSlider:SetValue(
                SuperSwingTimerDB.druidPowerShiftBarHeight or ns.DB_DEFAULTS.druidPowerShiftBarHeight or 4
            )
        end
        if panel.druidEnergyTickSlider then
            panel.druidEnergyTickSlider:SetValue(
                SuperSwingTimerDB.druidEnergyTickBarWidth or ns.DB_DEFAULTS.druidEnergyTickBarWidth or 4
            )
        end
        if panel.rogueAdrenalineRushSlider then
            panel.rogueAdrenalineRushSlider:SetValue(
                SuperSwingTimerDB.rogueAdrenalineRushBarHeight or ns.DB_DEFAULTS.rogueAdrenalineRushBarHeight or 4
            )
        end
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
        if panel.ReflowConfigSections then
            panel.ReflowConfigSections()
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
        panel.backgroundAlphaSlider:SetValue(
            SuperSwingTimerDB.barBackgroundAlpha ~= nil and SuperSwingTimerDB.barBackgroundAlpha
                or ns.DB_DEFAULTS.barBackgroundAlpha
        )
        if panel.barBorderSlider then
            panel.barBorderSlider:SetValue(
                SuperSwingTimerDB.barBorderSize ~= nil and SuperSwingTimerDB.barBorderSize or ns.DB_DEFAULTS.barBorderSize
            )
        end
        panel.weaveSparkWidthSlider:SetValue(SuperSwingTimerDB.weaveSparkWidth or ns.DB_DEFAULTS.weaveSparkWidth)
        panel.weaveSparkHeightSlider:SetValue(SuperSwingTimerDB.weaveSparkHeight or ns.DB_DEFAULTS.weaveSparkHeight)
        panel.weaveSparkAlphaSlider:SetValue(
            SuperSwingTimerDB.weaveSparkAlpha ~= nil and SuperSwingTimerDB.weaveSparkAlpha or ns.DB_DEFAULTS.weaveSparkAlpha
        )
        panel.weaveTriangleSizeSlider:SetValue(SuperSwingTimerDB.weaveTriangleSize or ns.DB_DEFAULTS.weaveTriangleSize)
        panel.weaveTriangleGapSlider:SetValue(
            SuperSwingTimerDB.weaveTriangleGap ~= nil and SuperSwingTimerDB.weaveTriangleGap or ns.DB_DEFAULTS.weaveTriangleGap
        )
        panel.weaveTriangleAlphaSlider:SetValue(
            SuperSwingTimerDB.weaveTriangleAlpha ~= nil and SuperSwingTimerDB.weaveTriangleAlpha
                or ns.DB_DEFAULTS.weaveTriangleAlpha
        )
        if panel.minimalModeRow and panel.minimalModeRow.refresh then
            panel.minimalModeRow.refresh()
        end
        if panel.lockBarsRow and panel.lockBarsRow.refresh then
            panel.lockBarsRow.refresh()
        end
        if panel.lockBarsQuickRow and panel.lockBarsQuickRow.refresh then
            panel.lockBarsQuickRow.refresh()
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
        if panel.showHunterRangeHelperRow and panel.showHunterRangeHelperRow.refresh then
            panel.showHunterRangeHelperRow.refresh()
        end
        if panel.showEnemyRow and panel.showEnemyRow.refresh then
            panel.showEnemyRow.refresh()
        end
        if panel.showWeaveRow and panel.showWeaveRow.refresh then
            panel.showWeaveRow.refresh()
        end
        if panel.showRogueAssistRow and panel.showRogueAssistRow.refresh then
            panel.showRogueAssistRow.refresh()
        end
        if panel.showRogueEnergyRow and panel.showRogueEnergyRow.refresh then
            panel.showRogueEnergyRow.refresh()
        end
        if panel.showDruidEnergyRow and panel.showDruidEnergyRow.refresh then
            panel.showDruidEnergyRow.refresh()
        end
        if panel.showRogueSliceAndDiceRow and panel.showRogueSliceAndDiceRow.refresh then
            panel.showRogueSliceAndDiceRow.refresh()
        end
        if panel.weaveFamilyRows then
            for _, row in ipairs(panel.weaveFamilyRows) do
                if row.refresh then
                    row.refresh()
                end
            end
        end
        if panel.colorRows then
            for _, row in ipairs(panel.colorRows) do
                if row and row.button and row.swatch then
                    local key = row.button.colorKey
                    local c = ns.GetBarColor(key)
                    if c then
                        row.swatch:SetColorTexture(c.r, c.g, c.b, c.a)
                    end
                end
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

--- Reset all SavedVariables to their default values.
--  Preserves positions, then wipes everything to ns.DB_DEFAULTS
--  and reapplies all settings to active frames. Called by /sst reset.
--  @return (nil)
function ns.ResetConfigDefaults()
    SuperSwingTimerDB.colors = SuperSwingTimerDB.colors or {}
    SuperSwingTimerDB.positions = {
        mh = {
            point = ns.DB_DEFAULTS.positions.mh.point,
            relativePoint = ns.DB_DEFAULTS.positions.mh.relativePoint,
            x = ns.DB_DEFAULTS.positions.mh.x,
            y = ns.DB_DEFAULTS.positions.mh.y
        },
        oh = {
            point = ns.DB_DEFAULTS.positions.oh.point,
            relativePoint = ns.DB_DEFAULTS.positions.oh.relativePoint,
            x = ns.DB_DEFAULTS.positions.oh.x,
            y = ns.DB_DEFAULTS.positions.oh.y
        },
        ranged = {
            point = ns.DB_DEFAULTS.positions.ranged.point,
            relativePoint = ns.DB_DEFAULTS.positions.ranged.relativePoint,
            x = ns.DB_DEFAULTS.positions.ranged.x,
            y = ns.DB_DEFAULTS.positions.ranged.y
        },
        enemy = {
            point = ns.DB_DEFAULTS.positions.enemy.point,
            relativePoint = ns.DB_DEFAULTS.positions.enemy.relativePoint,
            x = ns.DB_DEFAULTS.positions.enemy.x,
            y = ns.DB_DEFAULTS.positions.enemy.y
        }
    }
    SuperSwingTimerDB.barWidth = ns.DB_DEFAULTS.barWidth
    SuperSwingTimerDB.barHeight = ns.DB_DEFAULTS.barHeight
    SuperSwingTimerDB.hunterCastBarHeight = ns.DB_DEFAULTS.hunterCastBarHeight
    SuperSwingTimerDB.rogueSliceAndDiceBarHeight = ns.DB_DEFAULTS.rogueSliceAndDiceBarHeight
    SuperSwingTimerDB.rogueEnergyTickBarWidth = ns.DB_DEFAULTS.rogueEnergyTickBarWidth
    SuperSwingTimerDB.warriorShieldBlockBarHeight = ns.DB_DEFAULTS.warriorShieldBlockBarHeight
    SuperSwingTimerDB.hunterRangeHelperWidth = ns.DB_DEFAULTS.hunterRangeHelperWidth
    SuperSwingTimerDB.hunterRapidFireBarHeight = ns.DB_DEFAULTS.hunterRapidFireBarHeight
    SuperSwingTimerDB.druidPowerShiftBarHeight = ns.DB_DEFAULTS.druidPowerShiftBarHeight
    SuperSwingTimerDB.druidEnergyTickBarWidth = ns.DB_DEFAULTS.druidEnergyTickBarWidth
    SuperSwingTimerDB.rogueAdrenalineRushBarHeight = ns.DB_DEFAULTS.rogueAdrenalineRushBarHeight
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
        a = ns.DB_DEFAULTS.barBackgroundColor.a
    }
    SuperSwingTimerDB.barBorderColor = {
        r = ns.DB_DEFAULTS.barBorderColor.r,
        g = ns.DB_DEFAULTS.barBorderColor.g,
        b = ns.DB_DEFAULTS.barBorderColor.b,
        a = ns.DB_DEFAULTS.barBorderColor.a
    }
    SuperSwingTimerDB.sparkAlpha = ns.DB_DEFAULTS.sparkAlpha
    SuperSwingTimerDB.sparkColor = {
        r = ns.DB_DEFAULTS.sparkColor.r,
        g = ns.DB_DEFAULTS.sparkColor.g,
        b = ns.DB_DEFAULTS.sparkColor.b,
        a = ns.DB_DEFAULTS.sparkColor.a
    }
    SuperSwingTimerDB.minimalMode = ns.DB_DEFAULTS.minimalMode
    SuperSwingTimerDB.lockBars = ns.DB_DEFAULTS.lockBars
    SuperSwingTimerDB.showMH = ns.DB_DEFAULTS.showMH
    SuperSwingTimerDB.showOH = ns.DB_DEFAULTS.showOH
    SuperSwingTimerDB.showRanged = ns.DB_DEFAULTS.showRanged
    SuperSwingTimerDB.showHunterRangeHelper = ns.DB_DEFAULTS.showHunterRangeHelper
    SuperSwingTimerDB.showEnemy = ns.DB_DEFAULTS.showEnemy
    SuperSwingTimerDB.showRogueSinisterAssist = ns.DB_DEFAULTS.showRogueSinisterAssist
    SuperSwingTimerDB.showRogueEnergyTick = ns.DB_DEFAULTS.showRogueEnergyTick
    SuperSwingTimerDB.showDruidEnergyTickBar = ns.DB_DEFAULTS.showDruidEnergyTickBar
    SuperSwingTimerDB.showRogueSliceAndDice = ns.DB_DEFAULTS.showRogueSliceAndDice
    SuperSwingTimerDB.showWeaveAssist = ns.DB_DEFAULTS.showWeaveAssist
    SuperSwingTimerDB.showShamanLightningTracker = ns.DB_DEFAULTS.showShamanLightningTracker
    SuperSwingTimerDB.showShamanFlameShockBar = ns.DB_DEFAULTS.showShamanFlameShockBar
    SuperSwingTimerDB.showShamanBuffIcons = ns.DB_DEFAULTS.showShamanBuffIcons
    SuperSwingTimerDB.shamanBuffIconSize = ns.DB_DEFAULTS.shamanBuffIconSize
    SuperSwingTimerDB.showWarriorBuffIcons = ns.DB_DEFAULTS.showWarriorBuffIcons
    SuperSwingTimerDB.warriorBuffIconSize = ns.DB_DEFAULTS.warriorBuffIconSize
    SuperSwingTimerDB.showRogueBuffIcons = ns.DB_DEFAULTS.showRogueBuffIcons
    SuperSwingTimerDB.rogueBuffIconSize = ns.DB_DEFAULTS.rogueBuffIconSize
    SuperSwingTimerDB.showPaladinBuffIcons = ns.DB_DEFAULTS.showPaladinBuffIcons
    SuperSwingTimerDB.paladinBuffIconSize = ns.DB_DEFAULTS.paladinBuffIconSize
    SuperSwingTimerDB.shamanLightningTrackerGap = ns.DB_DEFAULTS.shamanLightningTrackerGap
    SuperSwingTimerDB.useClassColors = ns.DB_DEFAULTS.useClassColors
    SuperSwingTimerDB.globalScale = ns.DB_DEFAULTS.globalScale
    SuperSwingTimerDB.indicatorBlendMode = ns.DB_DEFAULTS.indicatorBlendMode
    SuperSwingTimerDB.weaveSpellFamilies = {
        LB = ns.DB_DEFAULTS.weaveSpellFamilies.LB,
        CL = ns.DB_DEFAULTS.weaveSpellFamilies.CL,
        HW = ns.DB_DEFAULTS.weaveSpellFamilies.HW,
        LHW = ns.DB_DEFAULTS.weaveSpellFamilies.LHW,
        CH = ns.DB_DEFAULTS.weaveSpellFamilies.CH
    }
    for key, def in pairs(ns.DB_DEFAULTS.colors) do
        SuperSwingTimerDB.colors[key] = { r = def.r, g = def.g, b = def.b, a = def.a }
    end
    SuperSwingTimerDB.preClassColors = nil
    SuperSwingTimerDB.preClassSparkColor = nil
    ns.HUNTER_CAST_BAR_HEIGHT = ns.DB_DEFAULTS.hunterCastBarHeight
    ns.ROGUE_SLICE_AND_DICE_BAR_HEIGHT = ns.DB_DEFAULTS.rogueSliceAndDiceBarHeight
    ns.ROGUE_ENERGY_TICK_BAR_WIDTH = ns.DB_DEFAULTS.rogueEnergyTickBarWidth
    ns.WARRIOR_SHIELD_BLOCK_BAR_HEIGHT = ns.DB_DEFAULTS.warriorShieldBlockBarHeight
    ns.HUNTER_RANGE_HELPER_WIDTH = ns.DB_DEFAULTS.hunterRangeHelperWidth
    ns.HUNTER_RAPID_FIRE_BAR_HEIGHT = ns.DB_DEFAULTS.hunterRapidFireBarHeight
    ns.DRUID_POWER_SHIFT_BAR_HEIGHT = ns.DB_DEFAULTS.druidPowerShiftBarHeight
    ns.DRUID_ENERGY_TICK_BAR_WIDTH = ns.DB_DEFAULTS.druidEnergyTickBarWidth
    ns.ROGUE_ADRENALINE_RUSH_BAR_HEIGHT = ns.DB_DEFAULTS.rogueAdrenalineRushBarHeight
    if ns.UpdateDruidEnergyTickVisual then
        ns.UpdateDruidEnergyTickVisual()
    end
    ns.ApplyBarSize(ns.DB_DEFAULTS.barWidth, ns.DB_DEFAULTS.barHeight)
    ns.ApplyBarTexture(ns.DB_DEFAULTS.barTexture, ns.DB_DEFAULTS.barTextureLayer)
    ns.ApplyRangedBarTexture(ns.DB_DEFAULTS.rangedBarTexture, ns.DB_DEFAULTS.barTextureLayer)
    ns.ApplyBarTextureLayer(ns.DB_DEFAULTS.barTextureLayer)
    ns.ApplySparkSettings(
        ns.DB_DEFAULTS.sparkTexture, ns.DB_DEFAULTS.sparkWidth, ns.DB_DEFAULTS.sparkHeight,
        ns.DB_DEFAULTS.sparkTextureLayer, ns.DB_DEFAULTS.sparkColor.a, ns.DB_DEFAULTS.sparkColor
    )
    ns.ApplySparkTextureLayer(ns.DB_DEFAULTS.sparkTextureLayer)
    ns.ApplyIndicatorBlendMode(ns.DB_DEFAULTS.indicatorBlendMode)
    ns.ApplyWeaveSparkSettings(
        ns.DB_DEFAULTS.weaveSparkTexture, ns.DB_DEFAULTS.weaveSparkWidth, ns.DB_DEFAULTS.weaveSparkHeight,
        ns.DB_DEFAULTS.weaveSparkTextureLayer, ns.DB_DEFAULTS.weaveSparkAlpha
    )
    ns.ApplyWeaveSparkTextureLayer(ns.DB_DEFAULTS.weaveSparkTextureLayer)
    ns.ApplyWeaveTriangleSettings(
        ns.DB_DEFAULTS.weaveTriangleTopTexture, ns.DB_DEFAULTS.weaveTriangleBottomTexture,
        ns.DB_DEFAULTS.weaveTriangleSize, ns.DB_DEFAULTS.weaveTriangleGap, ns.DB_DEFAULTS.weaveTriangleTextureLayer,
        ns.DB_DEFAULTS.weaveTriangleAlpha
    )
    ns.ApplyWeaveMarkerLayer(ns.DB_DEFAULTS.weaveMarkerLayer)
    ns.ApplyBarBackgroundColor(ns.DB_DEFAULTS.barBackgroundColor)
    ns.ApplyBarBorderColor(ns.DB_DEFAULTS.barBorderColor)
    ns.ApplyBarBorderSize(ns.DB_DEFAULTS.barBorderSize)
    ns.ApplySparkColor(ns.DB_DEFAULTS.sparkColor)
    ns.ApplyMinimalMode(ns.DB_DEFAULTS.minimalMode)
    ns.ApplyBarColors()
    if ns.UpdateLightningShieldVisual then
        ns.UpdateLightningShieldVisual()
    end
    if ns.UpdateOHBar then
        ns.UpdateOHBar()
    end
    if ns.RestoreAllBarPositions then
        ns.RestoreAllBarPositions()
    end
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
    if panel and panel.lockBarsQuickRow and panel.lockBarsQuickRow.refresh then
        panel.lockBarsQuickRow.refresh()
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
    if panel and panel.showHunterRangeHelperRow and panel.showHunterRangeHelperRow.refresh then
        panel.showHunterRangeHelperRow.refresh()
    end
    if panel and panel.showEnemyRow and panel.showEnemyRow.refresh then
        panel.showEnemyRow.refresh()
    end
    if panel and panel.showWeaveRow and panel.showWeaveRow.refresh then
        panel.showWeaveRow.refresh()
    end
    if panel and panel.showRogueAssistRow and panel.showRogueAssistRow.refresh then
        panel.showRogueAssistRow.refresh()
    end
    if panel and panel.showRogueEnergyRow and panel.showRogueEnergyRow.refresh then
        panel.showRogueEnergyRow.refresh()
    end
    if panel and panel.showRogueSliceAndDiceRow and panel.showRogueSliceAndDiceRow.refresh then
        panel.showRogueSliceAndDiceRow.refresh()
    end
    if panel and panel.colorRows then
        for _, row in ipairs(panel.colorRows) do
            if row and row.refresh then
                row.refresh()
            end
        end
    end
    -- Apply global scale after all other settings are restored
    if ns.ApplyGlobalScale then
        ns.ApplyGlobalScale()
    end
end
