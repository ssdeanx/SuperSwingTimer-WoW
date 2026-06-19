local _, ns = ...

local CreateFrame = rawget(_G, "CreateFrame")
local UIParent = rawget(_G, "UIParent")
local MouselookStart = rawget(_G, "MouselookStart")
local MouselookStop = rawget(_G, "MouselookStop")
local TurnOrActionStart = rawget(_G, "TurnOrActionStart")
local TurnOrActionStop = rawget(_G, "TurnOrActionStop")
local InCombatLockdown = rawget(_G, "InCombatLockdown")
local GetTimePreciseSec = rawget(_G, "GetTimePreciseSec")
local GetTime = rawget(_G, "GetTime")
local UnitAttackSpeed = rawget(_G, "UnitAttackSpeed")
local UnitChannelInfo = rawget(_G, "UnitChannelInfo")
local strtrim = rawget(_G, "strtrim")

local function GetCurrentTime()
    if ns.GetAlignedTime then
        return ns.GetAlignedTime()
    end
    if GetTimePreciseSec then
        return GetTimePreciseSec()
    end
    return GetTime()
end

local function SafeStartRightCamera()
    if TurnOrActionStart then
        local ok = pcall(TurnOrActionStart)
        if ok then
            return true
        end
    end
    if MouselookStart then
        local ok = pcall(MouselookStart)
        if ok then
            return true
        end
    end
    return false
end

local function SafeStopRightCamera()
    if TurnOrActionStop then
        local ok = pcall(TurnOrActionStop)
        if ok then
            return true
        end
    end
    if MouselookStop then
        local ok = pcall(MouselookStop)
        if ok then
            return true
        end
    end
    return false
end

local function GetSparkBlendMode()
    -- Keep the main swing spark color-preserving so a white/manual spark does
    -- not visually warm itself from the colored bar fill underneath.
    return "BLEND"
end

local function GetRangedCastWindow()
    local baseWindow = ns.CAST_WINDOW or 0
    local castWindow = baseWindow + (ns.cachedLatency or 0)
    if castWindow < 0 then
        return 0
    end
    return castWindow
end

local ShouldShowHunterCastBar
local UpdateHunterMeleeBarAnchor = function (_, force)
    if ns.playerClass ~= "HUNTER" or not ns.mhBar or not ns.rangedBar then
        return
    end

    if ns.mhBar.hunterAnchorTarget == ns.rangedBar then
        return
    end

    ns.mhBar:ClearAllPoints()
    ns.mhBar:SetPoint("BOTTOMLEFT", ns.rangedBar, "TOPLEFT", 0, -2)
    ns.mhBar:SetPoint("BOTTOMRIGHT", ns.rangedBar, "TOPRIGHT", 0, -2)
    ns.mhBar.hunterAnchorTarget = ns.rangedBar
end

local function IsHunterMeleeActive()
    if ns.IsHunterMeleeActive then
        return ns.IsHunterMeleeActive()
    end
    return false
end

local function IsHunterMeleeBarVisible()
    if ns.IsHunterMeleeBarVisible then
        return ns.IsHunterMeleeBarVisible()
    end
    return IsHunterMeleeActive()
end

local function ShouldKeepHunterRangedTimerActive(now)
    if ns.playerClass ~= "HUNTER" then
        return false
    end

    if IsHunterMeleeActive() then
        return false
    end

    if ns.IsHunterAutoRepeatActive and ns.IsHunterAutoRepeatActive() then
        return true
    end

    if ns.GetAutoShotCooldown then
        local cooldownStart, cooldownDuration = ns.GetAutoShotCooldown()
        if cooldownStart and cooldownDuration and cooldownDuration > 0 then
            local graceWindow = math.max(ns.cachedLatency or 0, 0.05)
            if (now or GetCurrentTime()) <= (cooldownStart + cooldownDuration + graceWindow) then
                return true
            end
        end
    end

    -- ShouldShowHunterCastBar is assigned later in this file (forward declaration pattern)
    if type(ShouldShowHunterCastBar) == "function" and ShouldShowHunterCastBar() then
        return true
    end

    return false
end

local function GetAutoShotWindowColor(colorKey, fallback)
    local color = ns.GetBarColor and ns.GetBarColor(colorKey) or nil
    if color then
        return color
    end

    local fallbackColor = fallback or { r = 1, g = 1, b = 1, a = 1 }
    return {
        r = fallbackColor.r or 1,
        g = fallbackColor.g or 1,
        b = fallbackColor.b or 1,
        a = fallbackColor.a ~= nil and fallbackColor.a or 1
    }
end

local function ClampSparkHeightForBar(bar, requestedHeight)
    local targetHeight = tonumber(requestedHeight) or 1
    local barHeight = bar and bar:GetHeight() or targetHeight
    if not barHeight or barHeight <= 0 then
        barHeight = targetHeight
    end
    return math.max(1, math.min(targetHeight, barHeight))
end

local function GetOffHandBarHeight(mainHeight)
    if ns.GetOffHandBarHeight then
        return ns.GetOffHandBarHeight(mainHeight)
    end

    local baseHeight = tonumber(mainHeight) or ns.BAR_HEIGHT or 15
    return math.max(6, baseHeight - 7)
end

local function GetRogueSliceAndDiceBarHeight(mainHeight)
    if ns.GetRogueSliceAndDiceBarHeight then
        return ns.GetRogueSliceAndDiceBarHeight(mainHeight)
    end

    local baseHeight = tonumber(mainHeight) or ns.BAR_HEIGHT or 15
    return math.max(3, math.min(4, math.floor((baseHeight * 0.3) + 0.5)))
end

local function GetBarProgressFraction(bar)
    if not bar or not bar.GetMinMaxValues or not bar.GetValue then
        return 0
    end

    local minValue, maxValue = bar:GetMinMaxValues()
    if type(minValue) ~= "number" or type(maxValue) ~= "number" or maxValue <= minValue then
        return 0
    end

    local value = bar:GetValue() or minValue
    local fraction = (value - minValue) / (maxValue - minValue)
    if fraction < 0 then
        return 0
    elseif fraction > 1 then
        return 1
    end

    return fraction
end

local function UpdateSparkPosition(bar, explicitFraction)
    if not bar or not bar.sparkTexture then
        return
    end

    local sparkAnchor = ns.GetOverlayFrame and ns.GetOverlayFrame(bar) or bar
    local barWidth = bar:GetWidth() or bar.barWidth or ns.BAR_WIDTH or 0
    local sparkWidth = (bar.sparkTexture.GetWidth and bar.sparkTexture:GetWidth()) or (ns.GetSparkWidth
        and ns.GetSparkWidth())
        or 0
    local sparkPos
    local fill = bar.statusBarTexture or (bar.GetStatusBarTexture and bar:GetStatusBarTexture()) or nil
    if fill and sparkAnchor.GetLeft and fill.GetRight and barWidth > 0 then
        local anchorLeft = sparkAnchor:GetLeft()
        local fillRight = fill:GetRight()
        if anchorLeft and fillRight then
            sparkPos = fillRight - anchorLeft
        end
    end

    if type(sparkPos) ~= "number" then
        local fraction = explicitFraction
        if fraction == nil then
            fraction = GetBarProgressFraction(bar)
        end
        sparkPos = (fraction or 0) * barWidth
    end

    if sparkWidth > 1 then
        sparkPos = sparkPos + math.min((sparkWidth - 1) * 0.25, 1)
    end
    sparkPos = math.floor((sparkPos or 0) + 0.5)

    if sparkPos < 0 then
        sparkPos = 0
    elseif sparkPos > barWidth then
        sparkPos = barWidth
    end

    bar.sparkTexture:ClearAllPoints()
    bar.sparkTexture:SetPoint("CENTER", sparkAnchor, "LEFT", sparkPos, 0)
end

ns.RefreshBarSparkPosition = UpdateSparkPosition

-- Green means the player stopped before the breakpoint.
-- Red means the player is still moving through the cast window, or stopped too late.
local function IsRangedCastWindowSafe(t, castWindow)
    if not t or t.state ~= "swinging" or not t.duration or t.duration <= 0 then
        return false
    end
    if not castWindow or castWindow <= 0 then
        return false
    end

    local cooldownEnd = t.lastSwing + t.duration - castWindow
    if ns.isMoving then
        return false
    end

    local stoppedAt = ns.lastStoppedMovingAt
    if stoppedAt and stoppedAt > cooldownEnd then
        return false
    end

    return true
end

local function CreateOverlayFrame(parent)
    local overlayFrame = CreateFrame("Frame", nil, parent)
    overlayFrame:SetAllPoints(parent)
    overlayFrame:SetFrameStrata(parent:GetFrameStrata())
    overlayFrame:SetFrameLevel((parent:GetFrameLevel() or 0) + 1)
    overlayFrame:EnableMouse(false)
    return overlayFrame
end

function ns.GetOverlayFrame(frame)
    if frame and frame.overlayFrame then
        return frame.overlayFrame
    end
    return frame
end

local function UsesInvertedClassLabelStyle(bar)
    local db = SuperSwingTimerDB or ns.DB_DEFAULTS
    if not db or db.useClassColors ~= true then
        return false
    end

    return bar == ns.mhBar or bar == ns.ohBar or bar == ns.rangedBar or bar == ns.hunterCastBar
end

local function SyncBarLabelText(bar, text)
    if not bar or not bar.labelText then
        return
    end

    text = text or ""
    bar.labelText:SetText(text)
    if bar.labelOutlineText then
        bar.labelOutlineText:SetText(text)
    end
end

local function ApplyBarLabelStyle(bar)
    if not bar or not bar.labelText then
        return
    end

    local useInverted = UsesInvertedClassLabelStyle(bar)
    if useInverted then
        bar.labelText:SetTextColor(0, 0, 0, 1)
        bar.labelText:SetShadowColor(0, 0, 0, 0)
        bar.labelText:SetShadowOffset(0, 0)
        if bar.labelOutlineText then
            local fontPath, fontSize = bar.labelText:GetFont()
            if fontPath and fontSize then
                bar.labelOutlineText:SetFont(fontPath, fontSize, "OUTLINE")
            end
            bar.labelOutlineText:SetTextColor(1, 1, 1, 1)
        end
    else
        bar.labelText:SetTextColor(1, 1, 1, 1)
        bar.labelText:SetShadowColor(0, 0, 0, 1)
        bar.labelText:SetShadowOffset(1, -1)
        if bar.labelOutlineText then
            bar.labelOutlineText:Hide()
        end
    end
end

local function SetBarLabelShown(bar, shown)
    if not bar or not bar.labelText then
        return
    end

    shown = shown == true
    if shown then
        bar.labelText:Show()
    else
        bar.labelText:Hide()
    end

    if bar.labelOutlineText then
        bar.labelOutlineText:SetShown(shown and UsesInvertedClassLabelStyle(bar))
    end

    ApplyBarLabelStyle(bar)
end

local function SetBarLabelText(bar, text, shown)
    if not bar or not bar.labelText then
        return
    end

    SyncBarLabelText(bar, text)
    if shown == nil then
        shown = (text or "") ~= ""
    end
    SetBarLabelShown(bar, shown)
end

local function RestoreBarDefaultLabel(bar)
    if not bar then
        return
    end

    local text = bar.defaultLabelText or ""
    SetBarLabelText(bar, text, text ~= "")
end

function ns.SetBarLabelText(bar, text, shown)
    SetBarLabelText(bar, text, shown)
end

function ns.RestoreBarDefaultLabel(bar)
    RestoreBarDefaultLabel(bar)
end

function ns.RefreshBarLabelStyles()
    for _, bar in ipairs({
        ns.enemyBar,
        ns.mhBar,
        ns.ohBar,
        ns.rangedBar,
        ns.hunterCastBar,
        ns.rogueSliceAndDiceBar,
        ns.rogueEnergyTickBar,
        ns.rogueEnergyTotalBar,
        ns.warriorRageBar
    }) do
        if bar and bar.labelText then
            ApplyBarLabelStyle(bar)
            SetBarLabelShown(bar, bar.labelText:IsShown())
        end
    end
    if ns.enemyBar and ns.enemyBar.labelText then
        SyncBarLabelText(ns.enemyBar, ns.enemyBar.labelText:GetText())
    end
    if ns.hunterCastBar and ns.hunterCastBar.labelText then
        SyncBarLabelText(ns.hunterCastBar, ns.hunterCastBar.labelText:GetText())
    end
    if ns.rangedBar and ns.rangedBar.labelText then
        SyncBarLabelText(ns.rangedBar, ns.rangedBar.labelText:GetText())
    end
    if ns.mhBar and ns.mhBar.labelText then
        SyncBarLabelText(ns.mhBar, ns.mhBar.labelText:GetText())
    end
    if ns.ohBar and ns.ohBar.labelText then
        SyncBarLabelText(ns.ohBar, ns.ohBar.labelText:GetText())
    end
end

local function IsHunterCastSpell(spellId)
    return spellId ~= nil and ns.IsHunterCastSpell and ns.IsHunterCastSpell(spellId)
end

local function GetLiveHunterCastInfo()
    if type(ns.GetUnitCastingSpellInfo) ~= "function" then
        return nil, nil, nil, nil
    end

    return ns.GetUnitCastingSpellInfo("player")
end

local function GetHunterHiddenCastWindowFromRangedTimer(now)
    -- NOTE: The hidden cast window depends only on the ranged timer, not melee state.
    -- Hunters can have both MH and ranged swings active simultaneously, and the
    -- Auto Shot cast window should always be available for the cast bar to render.
    local t = ns.timers and ns.timers.ranged
    if not t or t.state ~= "swinging" or not t.duration or t.duration <= 0 then
        return nil, nil
    end

    if t.hiddenCastWindowStart and t.hiddenCastWindowDuration and t.hiddenCastWindowDuration > 0 then
        local storedWindowStart = t.hiddenCastWindowStart
        local storedWindowEnd = storedWindowStart + t.hiddenCastWindowDuration
        if now < storedWindowStart then
            t.hiddenCastWindowStart = nil
            t.hiddenCastWindowDuration = nil
        elseif now <= storedWindowEnd then
            return storedWindowStart, t.hiddenCastWindowDuration
        elseif ns.isMoving == true and now >= storedWindowStart then
            -- Moving past cached window: recompute from live timer instead of
            -- shifting the start forward, which can push the window past the real swing end
            t.hiddenCastWindowStart = nil
            t.hiddenCastWindowDuration = nil
        else
            t.hiddenCastWindowStart = nil
            t.hiddenCastWindowDuration = nil
        end
    end

    local castWindow = math.max(GetRangedCastWindow() or 0.5, 0.01)
    local windowEnd = t.lastSwing + t.duration
    local windowStart = windowEnd - castWindow
    if now < windowStart or now > windowEnd then
        return nil, nil
    end

    t.hiddenCastWindowStart = windowStart
    t.hiddenCastWindowDuration = castWindow

    return windowStart, castWindow
end

local function IsStoredHunterCastDisplayStateActive(now)
    if ns.hunterCastActive ~= true or not IsHunterCastSpell(ns.hunterCastSpellId) then
        return false
    end

    if ns.IsAutoShotSpell and ns.IsAutoShotSpell(ns.hunterCastSpellId) then
        return false
    end

    local startTime = ns.hunterCastStartTime
    local duration = ns.hunterCastDuration
    if not startTime or not duration or duration <= 0 then
        return false
    end

    if now and now >= (startTime + duration) then
        if ns.ClearHunterCastState then
            ns.ClearHunterCastState()
        end
        if ns.RefreshUpdateLoop then
            ns.RefreshUpdateLoop()
        end
        return false
    end

    return true
end

ShouldShowHunterCastBar = function ()
    local cfg = ns.classConfig or {}
    local db = SuperSwingTimerDB or ns.DB_DEFAULTS
    if ns.playerClass ~= "HUNTER" or not ns.hunterCastBar or not cfg.ranged or db.showRanged == false then
        return false
    end

    local now = GetCurrentTime()
    local rangedWindowStart = GetHunterHiddenCastWindowFromRangedTimer(now)

    if IsStoredHunterCastDisplayStateActive(now) then
        return true
    end

    if type(ns.GetUnitCastingSpellInfo) == "function" then
        local liveSpell = GetLiveHunterCastInfo()
        if IsHunterCastSpell(liveSpell) then
            if ns.IsAutoShotSpell and ns.IsAutoShotSpell(liveSpell) then
                if rangedWindowStart then
                    return true
                end
            else
                return true
            end
        end
    end

    if rangedWindowStart then
        return true
    end

    return false
end

-- ============================================================
-- Bar factory
-- ============================================================
local function CreateBar(frameName, width, height)
    local f = CreateFrame("StatusBar", frameName, UIParent)
    f:SetSize(width or ns.BAR_WIDTH, height or ns.BAR_HEIGHT)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, -100)
    f:SetMovable(true)
    f:EnableMouse(false) -- mouse enabled later by ns.ApplyLockBars() when unlocked
    f.sstHasPropagateMouseClicks = (type(f.SetPropagateMouseClicks) == "function")
    if f.sstHasPropagateMouseClicks then
        f:SetPropagateMouseClicks(true)
    end
    f:SetClampedToScreen(true)
    f:SetHitRectInsets(-50, -50, -50, -50)
    f:SetStatusBarTexture(ns.GetBarTexture())
    f:SetStatusBarColor(0, 0, 0, 1)
    f:SetAlpha(0)

    local overlayFrame = CreateOverlayFrame(f)
    f.overlayFrame = overlayFrame

    local statusBarTexture = f:GetStatusBarTexture()
    if statusBarTexture then
        statusBarTexture:SetDrawLayer(ns.GetBarTextureLayer())
    end

    local backgroundTexture = f:CreateTexture(nil, "BACKGROUND")
    backgroundTexture:SetAllPoints(true)
    local backgroundColor = ns.GetBarBackgroundColor and ns.GetBarBackgroundColor()
        or (ns.DB_DEFAULTS and ns.DB_DEFAULTS.barBackgroundColor)
    backgroundColor = backgroundColor or { r = 0, g = 0, b = 0, a = 0.5 }
    backgroundTexture:SetColorTexture(backgroundColor.r or 0, backgroundColor.g or 0, backgroundColor.b or 0, 1)
    backgroundTexture:SetAlpha(backgroundColor.a ~= nil and backgroundColor.a or (ns.GetBarBackgroundAlpha() or 1))

    -- Border: 4 thin edges so the fill remains visible
    local borderColor = ns.GetBarBorderColor and ns.GetBarBorderColor()
        or (ns.DB_DEFAULTS and ns.DB_DEFAULTS.barBorderColor)
    borderColor = borderColor or { r = 0, g = 0, b = 0, a = 1 }
    local borderTop = f:CreateTexture(nil, "OVERLAY")
    borderTop:SetColorTexture(borderColor.r or 0, borderColor.g or 0, borderColor.b or 0, borderColor.a or 1)
    borderTop:SetPoint("TOPLEFT", -1, 1)
    borderTop:SetPoint("TOPRIGHT", 1, 1)
    borderTop:SetHeight(1)

    local borderBottom = f:CreateTexture(nil, "OVERLAY")
    borderBottom:SetColorTexture(borderColor.r or 0, borderColor.g or 0, borderColor.b or 0, borderColor.a or 1)
    borderBottom:SetPoint("BOTTOMLEFT", -1, -1)
    borderBottom:SetPoint("BOTTOMRIGHT", 1, -1)
    borderBottom:SetHeight(1)

    local borderLeft = f:CreateTexture(nil, "OVERLAY")
    borderLeft:SetColorTexture(borderColor.r or 0, borderColor.g or 0, borderColor.b or 0, borderColor.a or 1)
    borderLeft:SetPoint("TOPLEFT", -1, 1)
    borderLeft:SetPoint("BOTTOMLEFT", -1, -1)
    borderLeft:SetWidth(1)

    local borderRight = f:CreateTexture(nil, "OVERLAY")
    borderRight:SetColorTexture(borderColor.r or 0, borderColor.g or 0, borderColor.b or 0, borderColor.a or 1)
    borderRight:SetPoint("TOPRIGHT", 1, 1)
    borderRight:SetPoint("BOTTOMRIGHT", 1, -1)
    borderRight:SetWidth(1)

    f.borderTextures = { top = borderTop, bottom = borderBottom, left = borderLeft, right = borderRight }

    local sparkTexture = overlayFrame:CreateTexture(nil, "OVERLAY")
    sparkTexture:SetTexture(ns.GetSparkTexture())
    if ns.SetTextureLayerAboveBar then
        ns.SetTextureLayerAboveBar(sparkTexture, ns.GetSparkTextureLayer(), ns.GetBarTextureLayer())
    else
        sparkTexture:SetDrawLayer(ns.GetSparkTextureLayer())
    end
    sparkTexture:SetBlendMode(GetSparkBlendMode())
    sparkTexture:SetWidth(ns.GetSparkWidth())
    local sparkHeight = ClampSparkHeightForBar(f, ns.GetSparkHeight())
    sparkTexture:SetHeight(sparkHeight)
    local sparkColor = ns.GetSparkColor() or ns.DB_DEFAULTS.sparkColor
    if sparkColor then
        sparkTexture:SetVertexColor(sparkColor.r or 1, sparkColor.g or 1, sparkColor.b or 1, sparkColor.a or 1)
    else
        sparkTexture:SetVertexColor(1, 1, 1, 1)
    end
    sparkTexture:SetAlpha(1)
    sparkTexture:SetPoint("CENTER", overlayFrame, "LEFT", 0, 0)

    local labelOutlineText = overlayFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    labelOutlineText:SetPoint("CENTER")
    local outlineFontPath, outlineFontSize = labelOutlineText:GetFont()
    if outlineFontPath and outlineFontSize then
        labelOutlineText:SetFont(outlineFontPath, outlineFontSize, "OUTLINE")
    end
    labelOutlineText:SetTextColor(1, 1, 1, 1)
    labelOutlineText:Hide()

    local labelText = overlayFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    labelText:SetPoint("CENTER")
    labelText:SetShadowColor(0, 0, 0, 1)
    labelText:SetShadowOffset(1, -1)
    labelText:Show()

    f.backgroundTexture = backgroundTexture
    f.statusBarTexture = statusBarTexture
    f.sparkTexture = sparkTexture
    f.labelOutlineText = labelOutlineText
    f.labelText = labelText
    f.barWidth = f:GetWidth()
    return f
end

local function CreateEnemyBar()
    local f = CreateBar("SuperSwingTimerEnemyBar")
    local c = ns.GetBarColor and ns.GetBarColor("enemy")
        or (SuperSwingTimerDB and SuperSwingTimerDB.colors and SuperSwingTimerDB.colors.enemy)
    if c then
        f:SetStatusBarColor(c.r, c.g, c.b, c.a or 1)
    else
        f:SetStatusBarColor(1, 0, 0, 1)
    end
    f.defaultLabelText = "Enemy"
    RestoreBarDefaultLabel(f)
    f:SetMinMaxValues(0, 1)
    ns.enemyBar = f
    return f
end

-- ============================================================
-- Ranged bar (preserves v1.x behavior exactly)
-- ============================================================
local function CreateRangedBar()
    local f = CreateBar("SuperSwingTimerRangedBar")
    local overlayFrame = ns.GetOverlayFrame and ns.GetOverlayFrame(f) or f

    -- Cast-window overlay (red while moving, green when stopped before the breakpoint)
    local castOverlay = overlayFrame:CreateTexture(nil, "ARTWORK")
    local autoShotUnsafeColor = GetAutoShotWindowColor("autoShotUnsafe", { r = 1, g = 0, b = 0, a = 0.4 })
    castOverlay:SetColorTexture(
        autoShotUnsafeColor.r or 1, autoShotUnsafeColor.g or 0, autoShotUnsafeColor.b or 0,
        autoShotUnsafeColor.a ~= nil and autoShotUnsafeColor.a or 0.4
    )
    castOverlay:SetPoint("TOPRIGHT")
    castOverlay:SetPoint("BOTTOMRIGHT")
    if ns.SetTextureLayerAboveBar then
        ns.SetTextureLayerAboveBar(
            castOverlay, ns.GetWeaveMarkerLayer and ns.GetWeaveMarkerLayer() or "OVERLAY",
            ns.GetBarTextureLayer and ns.GetBarTextureLayer() or "ARTWORK"
        )
    end
    castOverlay:SetWidth(0)
    f.castOverlay = castOverlay

    -- Opaque marker showing where the bar will switch into the cast window.
    local castThresholdMarker = overlayFrame:CreateTexture(nil, "OVERLAY")
    castThresholdMarker:SetColorTexture(0, 0, 0, 1)
    castThresholdMarker:SetWidth(3)
    castThresholdMarker:SetPoint("TOPLEFT")
    castThresholdMarker:SetPoint("BOTTOMLEFT")
    if ns.SetTextureLayerAboveBar then
        ns.SetTextureLayerAboveBar(castThresholdMarker, ns.GetWeaveTriangleLayer(), ns.GetBarTextureLayer())
    end
    castThresholdMarker:Hide()
    f.castThresholdMarker = castThresholdMarker

    f.defaultLabelText = ""
    RestoreBarDefaultLabel(f)
    f:SetMinMaxValues(0, 1)
    ns.rangedBar = f
    return f
end

local function GetHunterRangedBarLabel()
    local db = SuperSwingTimerDB or ns.DB_DEFAULTS
    local label = db and db.hunterRangedBarLabel or (ns.DB_DEFAULTS and ns.DB_DEFAULTS.hunterRangedBarLabel) or ""
    return strtrim(label or "")
end

function ns.ApplyHunterRangedBarLabel(labelText)
    local normalized = strtrim(labelText or "")
    SuperSwingTimerDB.hunterRangedBarLabel = normalized
    if ns.rangedBar then
        ns.rangedBar.defaultLabelText = normalized
        RestoreBarDefaultLabel(ns.rangedBar)
    end
end

local function CreateHunterCastBar()
    local f = CreateBar("SuperSwingTimerHunterCastBar", nil, ns.HUNTER_CAST_BAR_HEIGHT or 10)
    local rangedBar = ns.rangedBar
    if not rangedBar then
        -- No ranged bar yet — hide until bars are fully initialized
        f:SetAlpha(0)
        ns.hunterCastBar = f
        return f
    end
    local overlayFrame = ns.GetOverlayFrame and ns.GetOverlayFrame(f) or f

    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", rangedBar, "BOTTOMLEFT", 0, -(ns.HUNTER_CAST_BAR_GAP or 2))
    f:SetPoint("TOPRIGHT", rangedBar, "BOTTOMRIGHT", 0, -(ns.HUNTER_CAST_BAR_GAP or 2))
    f:SetMovable(false)
    f:EnableMouse(false)
    f.defaultLabelText = ""
    RestoreBarDefaultLabel(f)
    if f.labelText then
        f.labelText:ClearAllPoints()
        f.labelText:SetPoint("LEFT", f, "LEFT", 4, 0)
        f.labelText:SetPoint("RIGHT", f, "RIGHT", -60, 0)
        f.labelText:SetJustifyH("LEFT")
    end
    if f.labelOutlineText then
        f.labelOutlineText:ClearAllPoints()
        f.labelOutlineText:SetPoint("LEFT", f, "LEFT", 4, 0)
        f.labelOutlineText:SetPoint("RIGHT", f, "RIGHT", -60, 0)
        f.labelOutlineText:SetJustifyH("LEFT")
    end
    local countdownText = overlayFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    countdownText:SetPoint("RIGHT", f, "RIGHT", -4, 0)
    countdownText:SetJustifyH("RIGHT")
    countdownText:SetTextColor(1, 1, 1, 1)
    f.countdownText = countdownText
    if ns.GetRangedBarTexture then
        f:SetStatusBarTexture(ns.GetRangedBarTexture())
    end
    if ns.GetBarColor then
        local c = ns.GetBarColor("hunterCastBar")
        if c then
            f:SetStatusBarColor(c.r, c.g, c.b, c.a or 1)
        end
    end
    f:SetAlpha(0)

    local latencyOverlay = overlayFrame:CreateTexture(nil, "ARTWORK")
    latencyOverlay:SetPoint("TOPRIGHT")
    latencyOverlay:SetPoint("BOTTOMRIGHT")
    latencyOverlay:SetWidth(0)
    if ns.SetTextureLayerAboveBar then
        ns.SetTextureLayerAboveBar(
            latencyOverlay, ns.GetWeaveMarkerLayer and ns.GetWeaveMarkerLayer() or "OVERLAY",
            ns.GetBarTextureLayer and ns.GetBarTextureLayer() or "ARTWORK"
        )
    end
    f.latencyOverlay = latencyOverlay

    local latencyMarker = overlayFrame:CreateTexture(nil, "OVERLAY")
    latencyMarker:SetColorTexture(1, 1, 1, 1)
    latencyMarker:SetPoint("TOPLEFT")
    latencyMarker:SetPoint("BOTTOMLEFT")
    latencyMarker:SetWidth(2)
    if ns.SetTextureLayerAboveBar then
        ns.SetTextureLayerAboveBar(
            latencyMarker, ns.GetWeaveTriangleLayer and ns.GetWeaveTriangleLayer() or "OVERLAY",
            ns.GetBarTextureLayer and ns.GetBarTextureLayer() or "ARTWORK"
        )
    end
    latencyMarker:Hide()
    f.latencyMarker = latencyMarker

    f:SetMinMaxValues(0, 1)
    f:SetValue(0)
    f:SetAlpha(0)
    ns.hunterCastBar = f
    return f
end

-- ============================================================
-- Melee bars (MH and optional OH)
-- ============================================================
local function CreateMHBar()
    local f = CreateBar("SuperSwingTimerMHBar")
    local c = ns.GetBarColor and ns.GetBarColor("mh")
        or (SuperSwingTimerDB and SuperSwingTimerDB.colors and SuperSwingTimerDB.colors.mh)
    if c then
        f:SetStatusBarColor(c.r, c.g, c.b, c.a)
    else
        f:SetStatusBarColor(0, 0, 0, 1)
    end
    f.defaultLabelText = "Main Hand"
    RestoreBarDefaultLabel(f)
    f:SetMinMaxValues(0, 1)
    ns.mhBar = f
    return f
end

local function CreateOHBar()
    local mh = ns.mhBar
    local f = ns.ohBar or rawget(_G, "SuperSwingTimerOHBar")
    local offHandHeight = GetOffHandBarHeight((mh and mh:GetHeight()) or ns.BAR_HEIGHT)
    local offHandWidth = (mh and mh:GetWidth()) or ns.BAR_WIDTH
    if not f then
        f = CreateBar("SuperSwingTimerOHBar", offHandWidth, offHandHeight)
    end
    local c = ns.GetBarColor and ns.GetBarColor("oh")
        or (SuperSwingTimerDB and SuperSwingTimerDB.colors and SuperSwingTimerDB.colors.oh)
    if c then
        f:SetStatusBarColor(c.r, c.g, c.b, c.a)
    else
        f:SetStatusBarColor(0, 0, 0, 1)
    end
    f.defaultLabelText = "Off Hand"
    RestoreBarDefaultLabel(f)
    f:SetMinMaxValues(0, 1)
    f:SetSize(offHandWidth, offHandHeight)
    if f.sparkTexture then
        f.sparkTexture:SetHeight(ClampSparkHeightForBar(f, ns.GetSparkHeight()))
    end
    -- Anchor OH below MH with 2px gap
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", mh, "BOTTOMLEFT", 0, -2)
    f:SetPoint("TOPRIGHT", mh, "BOTTOMRIGHT", 0, -2)
    f:Show()
    ns.ohBar = f
    return f
end

-- ============================================================
-- Cast-zone visual for ranged bar
-- ============================================================
local function UpdateCastZoneVisual(castWindow, isSafeStop)
    local f = ns.rangedBar
    if not f then return end
    local t = ns.timers.ranged
    local duration = t and t.duration or 0
    local barWidth = f:GetWidth() or f.barWidth or ns.BAR_WIDTH or 0
    castWindow = castWindow or GetRangedCastWindow()
    if t and t.state == "swinging" and duration > 0 and castWindow > 0 then
        local width = math.min((castWindow / duration) * barWidth, barWidth)
        if width < 0 then width = 0 end
        f.castOverlay:SetWidth(width)

        if isSafeStop == nil then
            isSafeStop = IsRangedCastWindowSafe(t, castWindow)
        end
        if isSafeStop then
            local safeColor = GetAutoShotWindowColor("autoShotSafe", { r = 0.2, g = 0.78, b = 0.25, a = 0.4 })
            f.castOverlay:SetColorTexture(
                safeColor.r or 0.2, safeColor.g or 0.78, safeColor.b or 0.25, safeColor.a ~= nil and safeColor.a or 0.4
            )
        else
            local unsafeColor = GetAutoShotWindowColor("autoShotUnsafe", { r = 1, g = 0, b = 0, a = 0.4 })
            f.castOverlay:SetColorTexture(
                unsafeColor.r or 1, unsafeColor.g or 0, unsafeColor.b or 0,
                unsafeColor.a ~= nil and unsafeColor.a or 0.4
            )
        end

        if f.castThresholdMarker then
            local markerWidth = math.min(3, barWidth)
            local markerLeft = math.max(barWidth - width - (markerWidth * 0.5), 0)
            local markerAnchor = ns.GetOverlayFrame and ns.GetOverlayFrame(f) or f
            f.castThresholdMarker:ClearAllPoints()
            f.castThresholdMarker:SetPoint("TOPLEFT", markerAnchor, "LEFT", markerLeft, 0)
            f.castThresholdMarker:SetPoint("BOTTOMLEFT", markerAnchor, "LEFT", markerLeft, 0)
            f.castThresholdMarker:SetWidth(markerWidth)
            f.castThresholdMarker:Show()
        end
    else
        f.castOverlay:SetWidth(0)
        if f.castThresholdMarker then
            f.castThresholdMarker:Hide()
        end
    end
end
ns.UpdateCastZoneVisual = UpdateCastZoneVisual

local function ApplyHunterCastBarColor(spellId, remainingCastTime, now)
    local f = ns.hunterCastBar
    if not f then
        return nil
    end

    -- Use the dedicated hunter cast bar color, not the ranged bar fill color
    -- This allows users to set the cast bar color independently from the ranged bar
    local baseColor = (ns.GetBarColor and ns.GetBarColor("hunterCastBar")) or { r = 0, g = 0, b = 0, a = 1 }
    local alpha = baseColor.a ~= nil and baseColor.a or 1
    local clipSafe = nil
    if spellId and remainingCastTime and remainingCastTime > 0 then
        local isSpellEligible = (ns.IsHunterActualCastSpell and ns.IsHunterActualCastSpell(spellId))
            or (ns.IsMultiShotSpell and ns.IsMultiShotSpell(spellId))
        if isSpellEligible then
            local timeUntilNextShot = ns.GetTimeUntilNextHunterRangedShot and ns.GetTimeUntilNextHunterRangedShot(now)
                or nil
            if timeUntilNextShot ~= nil then
                local safetyBuffer = math.max(ns.cachedLatency or 0, 0.03)
                local isMultiShot = ns.IsMultiShotSpell and ns.IsMultiShotSpell(spellId)
                -- Multi-Shot has 0 grace: its hidden window delays Auto Shot on overlap.
                -- Steady Shot has a 0.5s grace period: Auto Shot fires during the last 0.5s
                -- of the cast without clipping. This makes the green/red tint match real
                -- TBC hunter clip behavior for both spell types.
                local gracePeriod = isMultiShot and 0 or (ns.STEADY_SHOT_GRACE or 0.5)
                clipSafe = remainingCastTime <= math.max(timeUntilNextShot + gracePeriod - safetyBuffer, 0)
                if clipSafe then
                    local safeColor = GetAutoShotWindowColor("autoShotSafe", { r = 0.2, g = 0.78, b = 0.25, a = 0.4 })
                    f:SetStatusBarColor(safeColor.r or 0.2, safeColor.g or 0.78, safeColor.b or 0.25, alpha)
                else
                    local unsafeColor = GetAutoShotWindowColor("autoShotUnsafe", { r = 1, g = 0, b = 0, a = 0.4 })
                    f:SetStatusBarColor(unsafeColor.r or 1, unsafeColor.g or 0, unsafeColor.b or 0, alpha)
                end
                return clipSafe
            end
        end
    end

    f:SetStatusBarColor(baseColor.r or 0, baseColor.g or 0, baseColor.b or 0, alpha)
    return clipSafe
end

local function UpdateHunterCastLatencyVisual(duration, showVisual)
    local f = ns.hunterCastBar
    if not f or not f.latencyOverlay then
        return
    end

    if not showVisual or not duration or duration <= 0 then
        f.latencyOverlay:SetWidth(0)
        if f.latencyMarker then
            f.latencyMarker:Hide()
        end
        return
    end

    local latencyWindow = math.max(ns.cachedLatency or 0, 0)
    local barWidth = f:GetWidth() or f.barWidth or ns.BAR_WIDTH or 0
    if latencyWindow <= 0 or barWidth <= 0 then
        f.latencyOverlay:SetWidth(0)
        if f.latencyMarker then
            f.latencyMarker:Hide()
        end
        return
    end

    local overlayColor = GetAutoShotWindowColor("autoShotUnsafe", { r = 1, g = 0, b = 0, a = 0.4 })
    local overlayAlpha = overlayColor.a ~= nil and overlayColor.a or 0.4
    f.latencyOverlay:SetColorTexture(
        overlayColor.r or 1, overlayColor.g or 0, overlayColor.b or 0,
        math.max(math.min(overlayAlpha * 0.6, 0.35), 0.12)
    )

    local width = math.min((latencyWindow / duration) * barWidth, barWidth)
    if width <= 0 then
        f.latencyOverlay:SetWidth(0)
        if f.latencyMarker then
            f.latencyMarker:Hide()
        end
        return
    end

    f.latencyOverlay:SetWidth(width)
    if f.latencyMarker then
        local markerAnchor = ns.GetOverlayFrame and ns.GetOverlayFrame(f) or f
        local markerWidth = math.min(2, barWidth)
        local markerLeft = math.max(barWidth - width - (markerWidth * 0.5), 0)
        f.latencyMarker:ClearAllPoints()
        f.latencyMarker:SetPoint("TOPLEFT", markerAnchor, "LEFT", markerLeft, 0)
        f.latencyMarker:SetPoint("BOTTOMLEFT", markerAnchor, "LEFT", markerLeft, 0)
        f.latencyMarker:SetWidth(markerWidth)
        f.latencyMarker:Show()
    end
end

local function UpdateHunterCastBar()
    local f = ns.hunterCastBar
    if not f then
        return
    end

    if not ShouldShowHunterCastBar() then
        RestoreBarDefaultLabel(f)
        f:SetAlpha(0)
        f:SetMinMaxValues(0, 1)
        f:SetValue(0)
        UpdateHunterCastLatencyVisual(nil, false)
        UpdateHunterMeleeBarAnchor(false)
        return
    end

    local now = GetCurrentTime()
    local castWindow = math.max(GetRangedCastWindow() or 0.5, 0.01)
    -- ns.CAST_WINDOW is a constant defined in Constants.lua
    local elapsedTime
    local duration
    local rangedWindowStart, rangedWindowDuration = GetHunterHiddenCastWindowFromRangedTimer(now)
    local usingStoredHunterCast = false
    local usingLiveHunterCast = false
    local isAutoShotHiddenWindow = false

    local spellId = ns.hunterCastSpellId or ns.currentCastSpellId
    local startTime = nil
    if type(ns.GetUnitCastingSpellInfo) == "function" then
        local liveSpell, liveSpellName, startTimeMs, endTimeMs = GetLiveHunterCastInfo()
        if IsHunterCastSpell(liveSpell) then
            local isAutoShotSpell = ns.IsAutoShotSpell and ns.IsAutoShotSpell(liveSpell)
            spellId = liveSpell
            if isAutoShotSpell then
                if rangedWindowStart and rangedWindowDuration and rangedWindowDuration > 0 then
                    usingLiveHunterCast = true
                    startTime = rangedWindowStart
                    duration = rangedWindowDuration
                end
            else
                usingLiveHunterCast = true
                spellId = liveSpell or liveSpellName
                if type(startTimeMs) == "number" and startTimeMs > 0 then
                    startTime = (startTimeMs / 1000)
                end
                if type(startTimeMs) == "number" and type(endTimeMs) == "number" and endTimeMs > startTimeMs then
                    duration = math.max((endTimeMs - startTimeMs) / 1000, 0.01)
                end
            end
        end
    end
    if usingLiveHunterCast and not startTime then
        startTime = now
    end

    if usingLiveHunterCast and (not duration or duration <= 0) then
        duration = math.max(ns.hunterCastDuration or castWindow, 0.01)
    end

    if not startTime and IsStoredHunterCastDisplayStateActive(now) then
        usingStoredHunterCast = true
        spellId = ns.hunterCastSpellId
        startTime = ns.hunterCastStartTime
        duration = math.max(ns.hunterCastDuration or castWindow, 0.01)
    end

    if not startTime and rangedWindowStart and rangedWindowDuration and rangedWindowDuration > 0 then
        spellId = ns.AUTO_SHOT_ID
        startTime = rangedWindowStart
        duration = rangedWindowDuration
        isAutoShotHiddenWindow = true
    end

    local persistSpellState = spellId and not (ns.IsAutoShotSpell and ns.IsAutoShotSpell(spellId))
    if usingLiveHunterCast and persistSpellState and startTime and duration and duration > 0 then
        ns.hunterCastStartTime = startTime
        ns.hunterCastDuration = duration
        ns.hunterCastSpellId = spellId
        ns.hunterCastActive = true
    end

    if startTime and duration and duration > 0 then
        elapsedTime = now - startTime
    end

    if not startTime or not duration or duration <= 0 then
        RestoreBarDefaultLabel(f)
        f:SetAlpha(0)
        f:SetMinMaxValues(0, 1)
        f:SetValue(0)
        UpdateHunterCastLatencyVisual(nil, false)
        UpdateHunterMeleeBarAnchor(false)
        return
    end

    if elapsedTime == nil then
        elapsedTime = 0
    elseif elapsedTime < 0 then
        elapsedTime = 0
    elseif elapsedTime > duration then
        elapsedTime = duration
    end

    if elapsedTime >= duration and usingStoredHunterCast then
        if ns.ClearHunterCastState then
            ns.ClearHunterCastState()
        end
        if ns.RefreshUpdateLoop then
            ns.RefreshUpdateLoop()
        end
    end

    local showActualCastLabel = spellId and ns.IsHunterActualCastSpell
        and ns.IsHunterActualCastSpell(spellId) and not (ns.IsAutoShotSpell and ns.IsAutoShotSpell(spellId))
    local showMultiShotLabel = spellId and ns.IsMultiShotSpell and ns.IsMultiShotSpell(spellId)
        and not (ns.IsAutoShotSpell and ns.IsAutoShotSpell(spellId))
    local showAutoShotLabel = spellId and isAutoShotHiddenWindow
    local remainingTime = math.max(duration - elapsedTime, 0)
    if showActualCastLabel or showMultiShotLabel then
        local spellName = (type(spellId) == "string" and spellId) or (ns.GetSpellInfo and ns.GetSpellInfo(spellId))
            or "Cast"
        SetBarLabelText(f, string.format("%s %.1f", spellName or "Cast", remainingTime), true)
    elseif showAutoShotLabel then
        SetBarLabelText(f, string.format("Auto Shot %.1f", remainingTime), true)
    else
        RestoreBarDefaultLabel(f)
    end

    if showAutoShotLabel then
        -- Tint with safe/unsafe auto shot window coloring matching the ranged bar
        local rangedWindowLead = GetRangedCastWindow()
        local rangedTimer = ns.timers and ns.timers.ranged
        local safeStop = rangedTimer and IsRangedCastWindowSafe(rangedTimer, rangedWindowLead) or false
        if safeStop then
            local safeColor = GetAutoShotWindowColor("autoShotSafe", { r = 0.2, g = 0.78, b = 0.25, a = 0.4 })
            f:SetStatusBarColor(safeColor.r or 0.2, safeColor.g or 0.78, safeColor.b or 0.25, 1)
        else
            local unsafeColor = GetAutoShotWindowColor("autoShotUnsafe", { r = 1, g = 0, b = 0, a = 0.4 })
            f:SetStatusBarColor(unsafeColor.r or 1, unsafeColor.g or 0, unsafeColor.b or 0, 1)
        end
    else
        ApplyHunterCastBarColor(spellId, (showActualCastLabel or showMultiShotLabel) and remainingTime or nil, now)
    end
    UpdateHunterCastLatencyVisual(duration, showActualCastLabel or showMultiShotLabel or showAutoShotLabel)

    f:SetAlpha(1)
    f:SetMinMaxValues(0, duration)
    f:SetValue(elapsedTime)
    UpdateSparkPosition(f, duration > 0 and (elapsedTime / duration) or 0)
    UpdateHunterMeleeBarAnchor(true)
end

-- ============================================================
-- Bar position save/restore
-- ============================================================
local function SavePosition(slot, frame)
    if not frame then return end
    local point, _, relativePoint, x, y = frame:GetPoint()
    SuperSwingTimerDB.positions[slot] = { point = point, relativePoint = relativePoint, x = x, y = y }
    if ns.UpdateRogueEnergyTickVisual then
        ns.UpdateRogueEnergyTickVisual()
    end
    if ns.UpdateHunterRangeHelperVisual then
        ns.UpdateHunterRangeHelperVisual()
    end
    if ns.UpdateRogueComboPointVisual then
        ns.UpdateRogueComboPointVisual()
    end
    if ns.UpdateRogueSliceAndDiceVisual then
        ns.UpdateRogueSliceAndDiceVisual()
    end
end

local function RestorePosition(slot, frame)
    if not frame then return end
    local pos = SuperSwingTimerDB.positions[slot]
    if type(pos) == "table" and pos.point then
        frame:ClearAllPoints()
        frame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
    end
end

function ns.RestoreAllBarPositions()
    RestorePosition("enemy", ns.enemyBar)
    RestorePosition("ranged", ns.rangedBar)
    if ns.playerClass ~= "HUNTER" then
        RestorePosition("mh", ns.mhBar)
    end

    if ns.ohBar and ns.mhBar then
        ns.ohBar:ClearAllPoints()
        ns.ohBar:SetPoint("TOPLEFT", ns.mhBar, "BOTTOMLEFT", 0, -2)
        ns.ohBar:SetPoint("TOPRIGHT", ns.mhBar, "BOTTOMRIGHT", 0, -2)
    end

    if ns.hunterCastBar and ns.rangedBar then
        ns.hunterCastBar:ClearAllPoints()
        ns.hunterCastBar:SetPoint("TOPLEFT", ns.rangedBar, "BOTTOMLEFT", 0, -(ns.HUNTER_CAST_BAR_GAP or 2))
        ns.hunterCastBar:SetPoint("TOPRIGHT", ns.rangedBar, "BOTTOMRIGHT", 0, -(ns.HUNTER_CAST_BAR_GAP or 2))
    end
    if ns.playerClass == "HUNTER" then
        UpdateHunterMeleeBarAnchor(nil, true)
        if ns.UpdateHunterRangeHelperVisual then
            ns.UpdateHunterRangeHelperVisual()
        end
    end

    if ns.rogueSliceAndDiceBar and ns.mhBar then
        ns.rogueSliceAndDiceBar:ClearAllPoints()
        ns.rogueSliceAndDiceBar:SetPoint("BOTTOMLEFT", ns.mhBar, "TOPLEFT", 0, 2)
        ns.rogueSliceAndDiceBar:SetPoint("BOTTOMRIGHT", ns.mhBar, "TOPRIGHT", 0, 2)
    end

    if ns.warriorRageBar and ns.ohBar then
        ns.warriorRageBar:ClearAllPoints()
        ns.warriorRageBar:SetPoint("TOPLEFT", ns.ohBar, "BOTTOMLEFT", 0, -4)
        ns.warriorRageBar:SetPoint("TOPRIGHT", ns.ohBar, "BOTTOMRIGHT", 0, -4)
    elseif ns.warriorRageBar and ns.mhBar then
        ns.warriorRageBar:ClearAllPoints()
        ns.warriorRageBar:SetPoint("TOPLEFT", ns.mhBar, "BOTTOMLEFT", 0, -4)
        ns.warriorRageBar:SetPoint("TOPRIGHT", ns.mhBar, "BOTTOMRIGHT", 0, -4)
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
    if ns.UpdateHunterRangeHelperVisual then
        ns.UpdateHunterRangeHelperVisual()
    end
end

-- ============================================================
-- Lock/unlock bars â€" controls mouse capture to prevent blocked
-- right-click camera movement when bars are locked.
-- ============================================================
function ns.ApplyLockBars()
    local locked = ns.AreBarsLocked()
    for _, bar in ipairs({ ns.mhBar, ns.ohBar, ns.rangedBar, ns.enemyBar }) do
        if bar then
            local isHunterMH = (ns.playerClass == "HUNTER" and bar == ns.mhBar)
            -- Only enable mouse when unlocked AND the bar is actually visible.
            -- Right-click camera control is preserved via SetPropagateMouseClicks(true)
            -- set during CreateBar, so clicks pass through to the game world frame.
            -- During combat, left-click drag uses manual mouse tracking since
            -- StartMoving() is a protected function blocked by combat lockdown.
            local isVisible = ((bar:IsShown() and bar:GetAlpha() > 0) or ns.barTestActive)
            if locked or isHunterMH or not isVisible then
                bar:EnableMouse(false)
                bar:RegisterForDrag()
                if bar.sstRightCameraActive then
                    SafeStopRightCamera()
                    bar.sstRightCameraActive = nil
                end
            else
                bar:EnableMouse(true)
                bar:RegisterForDrag("LeftButton")
            end
        end
    end
end

-- ============================================================
-- Drag handling (anchor bar only â€" OH follows MH automatically)
-- ============================================================
local function AttachDrag(frame, slot)
    local function StartDrag(self)
        if ns.AreBarsLocked() or self.isMoving then return end
        local inCombat = (ns.playerInCombat == true) or (InCombatLockdown and InCombatLockdown())
        if inCombat then
            -- Manual drag via mouse-tracking deltas.
            -- StartMoving() is a protected function blocked during combat lockdown,
            -- so we track cursor position manually and update via SetPoint instead.
            local cursorX, cursorY = GetCursorPosition()
            if not cursorX then return end
            local scale = UIParent:GetEffectiveScale()
            self.isMoving = true
            self.dragData = { cursorX = cursorX / scale, cursorY = cursorY / scale }
        else
            self:StartMoving()
            self.isMoving = true
        end
    end

    local function StopDrag(self)
        if not self.isMoving then return end
        if not self.dragData then
            -- Standard drag (out of combat) -- stop the built-in moving.
            self:StopMovingOrSizing()
        end
        self.isMoving = false
        self.dragData = nil
        SavePosition(slot, self)
    end

    -- OnUpdate for manual combat drag: tracks cursor deltas and repositions frame.
    frame:HookScript("OnUpdate", function (self, elapsed)
        if self.isMoving and self.dragData then
            local cursorX, cursorY = GetCursorPosition()
            if not cursorX then return end
            local scale = UIParent:GetEffectiveScale()
            cursorX = cursorX / scale
            cursorY = cursorY / scale

            local dx = cursorX - self.dragData.cursorX
            local dy = cursorY - self.dragData.cursorY

            local point, _, relativePoint, x, y = self:GetPoint()
            self:ClearAllPoints()
            self:SetPoint(point or "CENTER", UIParent, relativePoint or "CENTER", (x or 0) + dx, (y or 0) - dy)

            -- Update anchor for next delta
            self.dragData.cursorX = cursorX
            self.dragData.cursorY = cursorY
        end
    end)

    frame:SetScript("OnDragStart", function (self)
        StartDrag(self)
    end)
    frame:SetScript("OnDragStop", function (self)
        StopDrag(self)
    end)
    frame:SetScript("OnMouseDown", function (self, button)
        if button == "LeftButton" and not ns.AreBarsLocked() then
            StartDrag(self)
        elseif button == "RightButton" and not ns.AreBarsLocked() then
            if not self.sstHasPropagateMouseClicks and SafeStartRightCamera() then
                self.sstRightCameraActive = true
            end
        end
    end)
    frame:SetScript("OnMouseUp", function (self, button)
        if button == "LeftButton" then
            if self.isMoving then
                StopDrag(self)
            end
        elseif button == "RightButton" and self.sstRightCameraActive then
            SafeStopRightCamera()
            self.sstRightCameraActive = nil
        end
    end)
    frame:SetScript("OnHide", function (self)
        if self.isMoving then
            if self.dragData then
                self.dragData = nil
            else
                self:StopMovingOrSizing()
            end
            self.isMoving = false
        end
        if self.sstRightCameraActive then
            SafeStopRightCamera()
            self.sstRightCameraActive = nil
        end
    end)
end

-- ============================================================
-- Combat show/hide
-- ============================================================
local function ShowBars()
    if ns.ApplyVisibility then
        ns.ApplyVisibility()
        return
    end

    local cfg = ns.classConfig
    local db = SuperSwingTimerDB or ns.DB_DEFAULTS
    local _, ohSpeed = UnitAttackSpeed("player")
    local hasOffHand = ohSpeed and ohSpeed > 0
    local showEnemy = db.showEnemy ~= false and ns.enemyBar
        and (ns.enemyTargetGUID ~= nil or (ns.timers.enemy and ns.timers.enemy.state == "swinging"))
    if showEnemy and ns.enemyBar then
        ns.enemyBar:SetAlpha(1)
    elseif ns.enemyBar then
        ns.enemyBar:SetAlpha(0)
    end
    if cfg and cfg.ranged and db.showRanged ~= false and ns.rangedBar then
        ns.rangedBar:SetAlpha(1)
    end
    if ns.hunterCastBar then
        ns.hunterCastBar:SetAlpha(ShouldShowHunterCastBar() and 1 or 0)
    end
    if cfg and cfg.melee and db.showMH ~= false and ns.mhBar then
        ns.mhBar:SetAlpha(1)
    end
    if cfg and cfg.dualWield and db.showOH ~= false and hasOffHand and ns.ohBar then
        ns.ohBar:SetAlpha(1)
    elseif ns.ohBar then
        ns.ohBar:SetAlpha(0)
    end
    if ns.UpdateRogueEnergyTickVisual then
        ns.UpdateRogueEnergyTickVisual()
    end
end

local function ResetBarDisplay(bar)
    if not bar then
        return
    end

    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    RestoreBarDefaultLabel(bar)
    if bar.castOverlay then
        bar.castOverlay:SetWidth(0)
    end
    if bar.castThresholdMarker then
        bar.castThresholdMarker:Hide()
    end
    UpdateSparkPosition(bar, 0)
end

local function HideBars()
    if ns.enemyBar then
        ns.enemyBar:SetAlpha(0)
        ResetBarDisplay(ns.enemyBar)
    end
    if ns.rangedBar then
        ns.rangedBar:SetAlpha(0)
        ResetBarDisplay(ns.rangedBar)
    end
    if ns.hunterCastBar then
        ns.hunterCastBar:SetAlpha(0)
        ResetBarDisplay(ns.hunterCastBar)
    end
    if ns.hunterRangeHelperBar then
        ns.hunterRangeHelperBar:SetAlpha(0)
        ns.hunterRangeHelperBar:SetValue(0)
    end
    if ns.mhBar then
        ns.mhBar:SetAlpha(0)
        ResetBarDisplay(ns.mhBar)
    end
    if ns.ohBar then
        ns.ohBar:SetAlpha(0)
        ResetBarDisplay(ns.ohBar)
    end
    if ns.UpdateRogueEnergyTickVisual then
        ns.UpdateRogueEnergyTickVisual()
    end
end

ns.ShowBars = ShowBars
ns.HideBars = HideBars

-- ============================================================
-- OnUpdate tick for ranged bar
-- ============================================================
local function UpdateRangedBar(elapsed)
    local t = ns.timers and ns.timers.ranged
    local f = ns.rangedBar
    if not f or not t then return end

    if ns.channeling and UnitChannelInfo then
        local channelName, _, _, startTimeMs, endTimeMs = UnitChannelInfo("player")
        if not channelName and ns.channelingSpellId and ns.GetSpellInfo then
            channelName = ns.GetSpellInfo(ns.channelingSpellId)
        end
        channelName = channelName or "Channel"
        if channelName and startTimeMs and endTimeMs and endTimeMs > startTimeMs then
            local channelNow = GetCurrentTime()
            local channelDuration = (endTimeMs - startTimeMs) / 1000
            local elapsedChannel = channelNow - (startTimeMs / 1000)
            if elapsedChannel < 0 then elapsedChannel = 0 end
            if elapsedChannel > channelDuration then elapsedChannel = channelDuration end
            local remainingChannel = channelDuration - elapsedChannel
            if remainingChannel < 0 then remainingChannel = 0 end

            f.castOverlay:SetWidth(0)
            if f.castThresholdMarker then
                f.castThresholdMarker:Hide()
            end
            f:SetMinMaxValues(0, channelDuration)
            f:SetValue(elapsedChannel)
            SetBarLabelText(f, string.format("%s %.1f", channelName, remainingChannel), true)
            UpdateSparkPosition(f, channelDuration > 0 and (elapsedChannel / channelDuration) or 0)
            return
        end
    end

    if not t or t.state ~= "swinging" then
        ResetBarDisplay(f)
        return
    end

    local now = GetCurrentTime()
    if not t.duration or t.duration <= 0 then return end

    -- Haste rescaling: throttled sync + event fallback
    ns.SyncRangedTimerSpeed(now)
    local rangedWindowLead = GetRangedCastWindow()
    local safeStop = IsRangedCastWindowSafe(t, rangedWindowLead)
    UpdateCastZoneVisual(rangedWindowLead, safeStop)

    -- Movement clipping in cast window
    local cooldownEnd = t.lastSwing + t.duration - rangedWindowLead
    local elapsed_time = now - t.lastSwing
    -- Small grace buffer (~2 frames) prevents the timer from resetting one frame
    -- before the hunter cast window has a chance to display, which would clear
    -- hiddenCastWindowStart/Duration before ShouldShowHunterCastBar can use them.
    local resetGraceBuffer = 0.03
    if elapsed_time >= t.duration + resetGraceBuffer and not ShouldKeepHunterRangedTimerActive(now) then
        ns.ResetTimer("ranged")
        ResetBarDisplay(f)
        return
    end
    if now >= cooldownEnd then
        -- Keep the ranged bar's own fill color; cast overlay handles safe/unsafe tint
        local c = ns.rangedBarBaseColor
        if c then
            f:SetStatusBarColor(c.r, c.g, c.b, c.a or 1)
        else
            f:SetStatusBarColor(0, 0, 0, 1)
        end
        if ns.isMoving then
            local castBoundaryElapsed = math.max(t.duration - rangedWindowLead, 0)
            if elapsed_time > castBoundaryElapsed then
                elapsed_time = castBoundaryElapsed
            end
        end
    else
        local c = ns.rangedBarBaseColor
        if c then
            f:SetStatusBarColor(c.r, c.g, c.b, c.a or 1)
        else
            f:SetStatusBarColor(0, 0, 0, 1)
        end
    end

    if elapsed_time < 0 then elapsed_time = 0 end
    if elapsed_time > t.duration then elapsed_time = t.duration end
    local remaining = t.duration - elapsed_time
    if remaining < 0 then remaining = 0 end
    local rangedLabel = GetHunterRangedBarLabel()
    local countdownLabel = rangedLabel ~= "" and string.format("%s %.1f", rangedLabel, remaining)
        or string.format("%.1f", remaining)

    f:SetMinMaxValues(0, t.duration)
    f:SetValue(elapsed_time)
    SetBarLabelText(f, countdownLabel, true)
    UpdateSparkPosition(f, t.duration > 0 and (elapsed_time / t.duration) or 0)
end

-- ============================================================
-- OnUpdate tick for melee bars
-- ============================================================
local TriggerSwingLandingFlash
local function UpdateMeleeBar(slot, frame)
    local t = ns.timers[slot]
    if not frame then return end
    if t.state ~= "swinging" then
        ResetBarDisplay(frame)
        return
    end

    local now = GetCurrentTime()
    if ns.pauseSwingTime and (slot == "mh" or slot == "oh") then
        now = ns.pauseSwingTime
    end
    if not t.duration or t.duration <= 0 then return end

    -- Haste rescaling: throttled sync + event fallback
    local skipUntil = ns.druidFormChangeTime and (ns.druidFormChangeTime + 0.05)
    if not skipUntil or now > skipUntil then
        ns.SyncMeleeTimerSpeed(slot, now)
    end

    local elapsed_time = now - t.lastSwing
    if elapsed_time < 0 then elapsed_time = 0 end
    if elapsed_time > t.duration then elapsed_time = t.duration end
    local remaining = t.duration - elapsed_time
    if remaining < 0 then remaining = 0 end
    -- Swing landing flash: detect progress crossing 1.0
    if t.duration > 0 then
        local progress = elapsed_time / t.duration
        local lastProgress = ns.swingFlash[slot] and ns.swingFlash[slot]._lastProgress or 0
        if progress >= 1 and lastProgress < 1 then
            if type(TriggerSwingLandingFlash) == "function" then
                TriggerSwingLandingFlash(slot)
            end
        end
        if ns.swingFlash[slot] then
            ns.swingFlash[slot]._lastProgress = progress
        end
    end

    frame:SetMinMaxValues(0, t.duration)
    frame:SetValue(elapsed_time)
    SetBarLabelText(frame, string.format("%.1f", remaining), true)
    UpdateSparkPosition(frame, t.duration > 0 and (elapsed_time / t.duration) or 0)
end

-- ============================================================
-- GCD ticker bar (thin bar above MH showing 1.5s GCD)
-- ============================================================
-- ============================================================
-- Swing landing flash and GCD ticker support
-- ============================================================
-- These helpers are defined here so the melee update loop can reference them
-- without needing a second pass through the file.
-- ============================================================
-- Runtime apply functions (called from config panel)
-- ============================================================
-- Runtime apply functions (called from config panel)
-- ============================================================
function ns.ApplyBarSize(width, height)
    ns.BAR_WIDTH = width
    ns.BAR_HEIGHT = height
    SuperSwingTimerDB.barWidth = width
    SuperSwingTimerDB.barHeight = height

    local bars = {
        ns.enemyBar, ns.mhBar, ns.ohBar, ns.rangedBar, ns.hunterCastBar, ns.rogueSliceAndDiceBar, ns.warriorRageBar
    }
    for _, bar in ipairs(bars) do
        if bar then
            local barHeight = height
            if bar == ns.hunterCastBar then
                barHeight = ns.HUNTER_CAST_BAR_HEIGHT or 10
            elseif bar == ns.ohBar then
                barHeight = GetOffHandBarHeight(height)
            elseif bar == ns.rogueSliceAndDiceBar then
                barHeight = GetRogueSliceAndDiceBarHeight(height)
            end
            bar:SetSize(width, barHeight)
            bar.barWidth = width
            if bar.sparkTexture then
                bar.sparkTexture:SetWidth(ns.GetSparkWidth())
                bar.sparkTexture:SetHeight(ClampSparkHeightForBar(bar, ns.GetSparkHeight()))
                UpdateSparkPosition(bar)
            end
        end
    end
    -- OH anchors to MH via two-point, so width follows automatically.
    -- Re-anchor to ensure the gap is correct after height change.
    if ns.ohBar and ns.mhBar then
        ns.ohBar:ClearAllPoints()
        ns.ohBar:SetPoint("TOPLEFT", ns.mhBar, "BOTTOMLEFT", 0, -2)
        ns.ohBar:SetPoint("TOPRIGHT", ns.mhBar, "BOTTOMRIGHT", 0, -2)
    end
    if ns.playerClass == "HUNTER" then
        UpdateHunterMeleeBarAnchor(nil, true)
    end
    if ns.rogueSliceAndDiceBar and ns.mhBar then
        ns.rogueSliceAndDiceBar:ClearAllPoints()
        ns.rogueSliceAndDiceBar:SetPoint("BOTTOMLEFT", ns.mhBar, "TOPLEFT", 0, 2)
        ns.rogueSliceAndDiceBar:SetPoint("BOTTOMRIGHT", ns.mhBar, "TOPRIGHT", 0, 2)
    end
    if ns.warriorRageBar and ns.ohBar then
        ns.warriorRageBar:ClearAllPoints()
        ns.warriorRageBar:SetPoint("TOPLEFT", ns.ohBar, "BOTTOMLEFT", 0, -4)
        ns.warriorRageBar:SetPoint("TOPRIGHT", ns.ohBar, "BOTTOMRIGHT", 0, -4)
    elseif ns.warriorRageBar and ns.mhBar then
        ns.warriorRageBar:ClearAllPoints()
        ns.warriorRageBar:SetPoint("TOPLEFT", ns.mhBar, "BOTTOMLEFT", 0, -4)
        ns.warriorRageBar:SetPoint("TOPRIGHT", ns.mhBar, "BOTTOMRIGHT", 0, -4)
    end
    ns.UpdateCastZoneVisual()
    if ns.UpdateRogueSinisterAssistVisual then
        ns.UpdateRogueSinisterAssistVisual()
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
    if ns.UpdatePaladinSealZone then
        ns.UpdatePaladinSealZone()
    end
    if ns.UpdateWarriorShieldBlockBar then
        ns.UpdateWarriorShieldBlockBar(0, true)
    end
    if ns.UpdateHunterRapidFire then
        ns.UpdateHunterRapidFire(0, true)
    end
end

function ns.ApplyBarBorderSize(borderSize)
    borderSize = math.floor(tonumber(borderSize) or ns.DB_DEFAULTS.barBorderSize or 1)
    if borderSize < 0 then
        borderSize = 0
    end

    SuperSwingTimerDB.barBorderSize = borderSize

    for _, bar in ipairs({
        ns.enemyBar,
        ns.mhBar,
        ns.ohBar,
        ns.rangedBar,
        ns.hunterCastBar,
        ns.hunterRangeHelperBar,
        ns.rogueEnergyTickBar,
        ns.rogueEnergyTotalBar,
        ns.rogueSliceAndDiceBar,
        ns.warriorRageBar
    }) do
        local borderTextures = bar and bar.borderTextures or nil
        if borderTextures then
            local showBorder = borderSize > 0
            for _, texture in pairs(borderTextures) do
                if texture then
                    if showBorder then
                        texture:Show()
                    else
                        texture:Hide()
                    end
                end
            end
            if showBorder then
                borderTextures.top:SetHeight(borderSize)
                borderTextures.bottom:SetHeight(borderSize)
                borderTextures.left:SetWidth(borderSize)
                borderTextures.right:SetWidth(borderSize)
            end
        end
    end
    if ns.UpdateRogueComboPointVisual then
        ns.UpdateRogueComboPointVisual()
    end
    if ns.UpdateHunterRangeHelperVisual then
        ns.UpdateHunterRangeHelperVisual()
    end
end

function ns.ApplyBarTexture(texturePath, layer)
    if not texturePath or texturePath == "" then
        texturePath = ns.DB_DEFAULTS.barTexture
    end
    if not layer or layer == "" then
        layer = ns.GetBarTextureLayer()
    end

    SuperSwingTimerDB.barTexture = texturePath
    SuperSwingTimerDB.barTextureLayer = layer
    for _, bar in ipairs({
        ns.enemyBar,
        ns.mhBar,
        ns.ohBar,
        ns.rogueEnergyTickBar,
        ns.rogueEnergyTotalBar,
        ns.rogueSliceAndDiceBar,
        ns.warriorRageBar
    }) do
        if bar then
            bar:SetStatusBarTexture(texturePath)
            bar.statusBarTexture = bar.statusBarTexture or bar:GetStatusBarTexture()
            if bar.statusBarTexture then
                -- Keep the fill on its requested layer; the above-bar helper is
                -- reserved for spark / breakpoint overlays so they stay visible.
                bar.statusBarTexture:SetDrawLayer(layer)
            end
        end
    end
    if ns.UpdateRogueComboPointVisual then
        ns.UpdateRogueComboPointVisual()
    end
    if ns.UpdateHunterRapidFire then
        ns.UpdateHunterRapidFire(0, true)
    end
    if ns.UpdateWarriorShieldBlockBar then
        ns.UpdateWarriorShieldBlockBar(0, true)
    end
end

function ns.ApplyRangedBarTexture(texturePath, layer)
    if not texturePath or texturePath == "" then
        texturePath = ns.DB_DEFAULTS.rangedBarTexture or ns.DB_DEFAULTS.barTexture
    end
    if not layer or layer == "" then
        layer = ns.GetBarTextureLayer()
    end

    SuperSwingTimerDB.rangedBarTexture = texturePath
    for _, bar in ipairs({ ns.rangedBar, ns.hunterCastBar, ns.hunterRangeHelperBar }) do
        if bar then
            bar:SetStatusBarTexture(texturePath)
            bar.statusBarTexture = bar.statusBarTexture or bar:GetStatusBarTexture()
            if bar.statusBarTexture then
                bar.statusBarTexture:SetDrawLayer(layer)
            end
        end
    end
    ns.UpdateCastZoneVisual()
    if ns.UpdateHunterRapidFire then
        ns.UpdateHunterRapidFire(0, true)
    end
end

function ns.ApplyBarTextureLayer(layer)
    if not layer or layer == "" then
        layer = ns.DB_DEFAULTS.barTextureLayer
    end
    SuperSwingTimerDB.barTextureLayer = layer
    for _, bar in ipairs({
        ns.enemyBar,
        ns.mhBar,
        ns.ohBar,
        ns.rangedBar,
        ns.hunterCastBar,
        ns.hunterRangeHelperBar,
        ns.rogueEnergyTickBar,
        ns.rogueEnergyTotalBar,
        ns.rogueSliceAndDiceBar,
        ns.warriorRageBar
    }) do
        if bar and bar.statusBarTexture then
            bar.statusBarTexture:SetDrawLayer(layer)
        end
    end
    if ns.ApplySparkTextureLayer then
        ns.ApplySparkTextureLayer(SuperSwingTimerDB.sparkTextureLayer or ns.DB_DEFAULTS.sparkTextureLayer)
    end
    if ns.ApplyWeaveSparkTextureLayer then
        ns.ApplyWeaveSparkTextureLayer(
            SuperSwingTimerDB.weaveSparkTextureLayer or ns.DB_DEFAULTS.weaveSparkTextureLayer
        )
    end
    if ns.ApplyWeaveMarkerLayer then
        ns.ApplyWeaveMarkerLayer(
            SuperSwingTimerDB.weaveTriangleTextureLayer or ns.DB_DEFAULTS.weaveTriangleTextureLayer
        )
    end
    if ns.rangedBar and ns.rangedBar.castOverlay and ns.SetTextureLayerAboveBar then
        ns.SetTextureLayerAboveBar(
            ns.rangedBar.castOverlay, SuperSwingTimerDB.weaveMarkerLayer or ns.DB_DEFAULTS.weaveMarkerLayer, layer
        )
    end
    if ns.UpdateRogueComboPointVisual then
        ns.UpdateRogueComboPointVisual()
    end
end

function ns.ApplyBarBackgroundColor(color)
    color = color or ns.GetBarBackgroundColor() or ns.DB_DEFAULTS.barBackgroundColor
    local r = tonumber(color and color.r)
    local g = tonumber(color and color.g)
    local b = tonumber(color and color.b)
    local alpha = tonumber(color and color.a)
    if r == nil then r = 0 end
    if g == nil then g = 0 end
    if b == nil then b = 0 end
    if alpha == nil then
        alpha = ns.GetBarBackgroundAlpha() or ns.DB_DEFAULTS.barBackgroundAlpha or 1
    elseif alpha < 0 then
        alpha = 0
    elseif alpha > 1 then
        alpha = 1
    end

    SuperSwingTimerDB.barBackgroundColor = { r = r, g = g, b = b, a = alpha }
    SuperSwingTimerDB.barBackgroundAlpha = alpha
    for _, bar in ipairs({
        ns.enemyBar,
        ns.mhBar,
        ns.ohBar,
        ns.rangedBar,
        ns.hunterCastBar,
        ns.hunterRangeHelperBar,
        ns.rogueEnergyTickBar,
        ns.rogueEnergyTotalBar,
        ns.rogueSliceAndDiceBar,
        ns.warriorRageBar
    }) do
        if bar and bar.backgroundTexture then
            bar.backgroundTexture:SetColorTexture(r, g, b, 1)
            bar.backgroundTexture:SetAlpha(alpha)
        end
    end
    if ns.UpdateRogueComboPointVisual then
        ns.UpdateRogueComboPointVisual()
    end
end

function ns.ApplyBarBackgroundAlpha(alpha)
    alpha = tonumber(alpha) or ns.DB_DEFAULTS.barBackgroundAlpha
    if alpha < 0 then
        alpha = 0
    elseif alpha > 1 then
        alpha = 1
    end
    local color = ns.GetBarBackgroundColor and ns.GetBarBackgroundColor() or ns.DB_DEFAULTS.barBackgroundColor
    color = color or { r = 0, g = 0, b = 0, a = 1 }
    color = { r = color.r or 0, g = color.g or 0, b = color.b or 0, a = alpha }
    ns.ApplyBarBackgroundColor(color)
end

function ns.ApplyBarBorderColor(color)
    color = color or ns.GetBarBorderColor() or ns.DB_DEFAULTS.barBorderColor
    local r = tonumber(color and color.r)
    local g = tonumber(color and color.g)
    local b = tonumber(color and color.b)
    local alpha = tonumber(color and color.a)
    if r == nil then r = 0 end
    if g == nil then g = 0 end
    if b == nil then b = 0 end
    if alpha == nil then
        alpha = 1
    elseif alpha < 0 then
        alpha = 0
    elseif alpha > 1 then
        alpha = 1
    end

    SuperSwingTimerDB.barBorderColor = { r = r, g = g, b = b, a = alpha }
    for _, bar in ipairs({
        ns.enemyBar,
        ns.mhBar,
        ns.ohBar,
        ns.rangedBar,
        ns.hunterCastBar,
        ns.hunterRangeHelperBar,
        ns.rogueEnergyTickBar,
        ns.rogueEnergyTotalBar,
        ns.rogueSliceAndDiceBar,
        ns.warriorRageBar
    }) do
        local borderTextures = bar and bar.borderTextures or nil
        if borderTextures then
            for _, texture in pairs(borderTextures) do
                if texture then
                    texture:SetColorTexture(r, g, b, alpha)
                end
            end
        end
    end
    if ns.UpdateRogueComboPointVisual then
        ns.UpdateRogueComboPointVisual()
    end
end

function ns.ApplySparkSettings(texturePath, width, height, layer, alpha, color)
    if not texturePath or texturePath == "" then
        texturePath = ns.DB_DEFAULTS.sparkTexture
    end
    if not layer or layer == "" then
        layer = ns.GetSparkTextureLayer()
    end
    width = width or ns.DB_DEFAULTS.sparkWidth
    height = height or ns.DB_DEFAULTS.sparkHeight
    local currentColor = ns.GetSparkColor() or ns.DB_DEFAULTS.sparkColor
    color = color or currentColor
    local r, g, b = tonumber(color and color.r) or (currentColor and currentColor.r) or 1,
        tonumber(color and color.g) or (currentColor and currentColor.g) or 1,
        tonumber(color and color.b) or (currentColor and currentColor.b) or 1

    alpha = tonumber(alpha)
    if alpha == nil then
        alpha = tonumber(color and color.a)
    end
    if alpha == nil then
        alpha = (currentColor and currentColor.a) or ns.DB_DEFAULTS.sparkColor.a or 1
    elseif alpha < 0 then
        alpha = 0
    elseif alpha > 1 then
        alpha = 1
    end

    SuperSwingTimerDB.sparkTexture = texturePath
    SuperSwingTimerDB.sparkTextureLayer = layer
    SuperSwingTimerDB.sparkWidth = width
    SuperSwingTimerDB.sparkHeight = height
    SuperSwingTimerDB.sparkAlpha = alpha
    -- Spark tint stays independent from MH/OH/ranged class colors and queued-attack fill tints.
    SuperSwingTimerDB.sparkColor = { r = r, g = g, b = b, a = alpha }

    for _, bar in ipairs({ ns.enemyBar, ns.mhBar, ns.ohBar, ns.rangedBar, ns.hunterCastBar }) do
        if bar and bar.sparkTexture then
            bar.sparkTexture:SetTexture(texturePath)
            if ns.SetTextureLayerAboveBar then
                ns.SetTextureLayerAboveBar(bar.sparkTexture, layer, ns.GetBarTextureLayer())
            else
                bar.sparkTexture:SetDrawLayer(layer)
            end
            bar.sparkTexture:SetBlendMode(GetSparkBlendMode())
            bar.sparkTexture:SetWidth(width)
            local targetHeight = ClampSparkHeightForBar(bar, height)
            bar.sparkTexture:SetHeight(targetHeight)
            bar.sparkTexture:SetVertexColor(r, g, b, alpha)
        end
    end
end

-- ============================================================
-- Swing landing flash: pool per bar slot, driven by progress crossing 1.0
-- ============================================================
ns.swingFlash = {}
local SWING_FLASH_BASE_DURATION = 0.08

local function EnsureSwingFlashSlot(slot)
    if not ns.swingFlash[slot] then
        ns.swingFlash[slot] = { remaining = 0.0, duration = SWING_FLASH_BASE_DURATION }
    end
    return ns.swingFlash[slot]
end

TriggerSwingLandingFlash = function (slot)
    local db = SuperSwingTimerDB or ns.DB_DEFAULTS
    if db and db.showSwingFlash == false then return end
    local state = EnsureSwingFlashSlot(slot)
    state.remaining = (state.duration or SWING_FLASH_BASE_DURATION) + 0.0
end

local function UpdateSwingFlash(elapsed)
    for slot, state in pairs(ns.swingFlash) do
        if state.remaining > 0 then
            state.remaining = state.remaining - (elapsed or 0)
            if state.remaining <= 0 then
                state.remaining = 0.0
                local bar = slot == "mh" and ns.mhBar or slot == "oh" and ns.ohBar
                    or slot == "ranged" and ns.rangedBar or slot == "enemy" and ns.enemyBar
                if bar and bar.sparkTexture then
                    if ns.ApplySparkColor then ns.ApplySparkColor() end
                end
            end
        end
    end
end

local function RenderSwingFlash()
    for slot, state in pairs(ns.swingFlash) do
        if state.remaining > 0 then
            local bar = slot == "mh" and ns.mhBar or slot == "oh" and ns.ohBar
                or slot == "ranged" and ns.rangedBar or slot == "enemy" and ns.enemyBar
            if bar and bar.sparkTexture then
                local flashAlpha = math.max(state.remaining / state.duration, 0)
                bar.sparkTexture:SetVertexColor(1, 1, 1, flashAlpha)
            end
        end
    end
end

-- GCD ticker bar: thin bar above MH showing 1.5s GCD remaining
local function CreateGcdTickerBar()
    if ns.gcdTickerBar then return ns.gcdTickerBar end
    local f = CreateFrame("StatusBar", "SuperSwingTimerGcdTicker", UIParent)
    f:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    local db = SuperSwingTimerDB or ns.DB_DEFAULTS
    local color = db and db.colors and db.colors.gcdTickerColor or { r = 0.30, g = 0.70, b = 1.00, a = 0.85 }
    f:SetStatusBarColor(color.r, color.g, color.b, color.a)
    f:SetSize(ns.BAR_WIDTH or 240, 3)
    f:SetMinMaxValues(0, 1)
    f:SetValue(0)
    f:SetAlpha(0)
    f:SetFrameStrata("BACKGROUND")
    f:SetFrameLevel(0)
    if ns.mhBar then
        f:ClearAllPoints()
        f:SetPoint("BOTTOMLEFT", ns.mhBar, "TOPLEFT", 0, 6)
        f:SetPoint("BOTTOMRIGHT", ns.mhBar, "TOPRIGHT", 0, 6)
    end
    f:Hide()
    ns.gcdTickerBar = f
    return f
end

local function UpdateGcdTicker(elapsed)
    local f = ns.gcdTickerBar
    if not f then return end
    local db = SuperSwingTimerDB or ns.DB_DEFAULTS
    if not db or db.showGcdTicker == false or ns.playerClass == "HUNTER" or (ns.IsMinimalMode and ns.IsMinimalMode()) then
        f:SetAlpha(0)
        f:Hide()
        return
    end
    local now = GetCurrentTime()
    local gcdStart = ns.lastGcdTime
    if not gcdStart or not ns.gcdActive or (now - gcdStart) >= (ns.gcdDuration or 1.5) then
        if gcdStart and (now - gcdStart) >= (ns.gcdDuration or 1.5) then
            ns.gcdActive = false
        end
        f:SetAlpha(0)
        f:Hide()
        return
    end
    local elapsedGcd = now - gcdStart
    local fraction = 1 - math.min(elapsedGcd / (ns.gcdDuration or 1.5), 1)
    f:SetValue(fraction)
    f:SetAlpha(1)
    f:Show()
end

function ns.ApplySparkColor(color)
    color = color or ns.GetSparkColor() or ns.DB_DEFAULTS.sparkColor
    local currentTexture = ns.GetSparkTexture()
    local currentWidth = ns.GetSparkWidth()
    local currentHeight = ns.GetSparkHeight()
    local currentLayer = ns.GetSparkTextureLayer()
    local alpha = tonumber(color and color.a) or (ns.GetSparkAlpha() or 1)
    ns.ApplySparkSettings(currentTexture, currentWidth, currentHeight, currentLayer, alpha, color)
end

function ns.ApplyIndicatorBlendMode(blendMode)
    blendMode = blendMode or ns.GetIndicatorBlendMode()
    if blendMode ~= "ADD" and blendMode ~= "BLEND" then
        blendMode = ns.DB_DEFAULTS.indicatorBlendMode
    end

    SuperSwingTimerDB.indicatorBlendMode = blendMode

    for _, bar in ipairs({ ns.enemyBar, ns.mhBar, ns.ohBar, ns.rangedBar, ns.hunterCastBar }) do
        if bar and bar.sparkTexture then
            bar.sparkTexture:SetBlendMode(GetSparkBlendMode())
        end
    end

    for _, texture in ipairs({ ns.weaveSpark, ns.weaveTriangleTop, ns.weaveTriangleBottom }) do
        if texture then
            texture:SetBlendMode(blendMode)
        end
    end
end

function ns.ApplySparkTextureLayer(layer)
    if not layer or layer == "" then
        layer = ns.DB_DEFAULTS.sparkTextureLayer
    end
    SuperSwingTimerDB.sparkTextureLayer = layer
    for _, bar in ipairs({ ns.enemyBar, ns.mhBar, ns.ohBar, ns.rangedBar, ns.hunterCastBar }) do
        if bar and bar.sparkTexture then
            if ns.SetTextureLayerAboveBar then
                ns.SetTextureLayerAboveBar(bar.sparkTexture, layer, ns.GetBarTextureLayer())
            else
                bar.sparkTexture:SetDrawLayer(layer)
            end
        end
    end
    if ns.ApplyRogueCueLayer then
        ns.ApplyRogueCueLayer()
    end
    -- Direct layer refresh for Paladin seal zone (independent of weave marker system)
    local function refreshPaladinSealLayer(texture)
        if texture and texture.SetDrawLayer then
            texture:SetDrawLayer("OVERLAY", 0)
        end
    end
    refreshPaladinSealLayer(ns.sealTwistBreakpoint)
    refreshPaladinSealLayer(ns.sealTwistResealBreakpoint)
    refreshPaladinSealLayer(ns.paladinJudgementMarker)
end

function ns.ApplyRogueCueLayer()
    if not ns.rogueSinisterAssistZone or not ns.rogueSinisterAssistZone.SetDrawLayer then
        return
    end

    local sparkLayer = ns.GetSparkTextureLayer and ns.GetSparkTextureLayer() or "OVERLAY"
    ns.rogueSinisterAssistZone:SetDrawLayer(sparkLayer, 0)
end

function ns.ApplyWeaveMarkerLayer(layer)
    if not layer or layer == "" then
        layer = ns.DB_DEFAULTS.weaveMarkerLayer
    end
    SuperSwingTimerDB.weaveMarkerLayer = layer
    for _, texture in ipairs({ ns.weaveTriangleTop, ns.weaveTriangleBottom }) do
        if texture and texture.SetDrawLayer then
            if ns.SetTextureLayerAboveBar then
                ns.SetTextureLayerAboveBar(texture, layer, ns.GetBarTextureLayer())
            else
                texture:SetDrawLayer(layer)
            end
        end
    end
    -- Also apply layer to the canonical weave marker if present
    if ns.weaveMarker and ns.weaveMarker.SetDrawLayer then
        if ns.SetTextureLayerAboveBar then
            ns.SetTextureLayerAboveBar(ns.weaveMarker, layer, ns.GetBarTextureLayer())
        else
            ns.weaveMarker:SetDrawLayer(layer)
        end
    end
    if ns.rangedBar and ns.rangedBar.castThresholdMarker and ns.rangedBar.castThresholdMarker.SetDrawLayer then
        if ns.SetTextureLayerAboveBar then
            ns.SetTextureLayerAboveBar(ns.rangedBar.castThresholdMarker, layer, ns.GetBarTextureLayer())
        else
            ns.rangedBar.castThresholdMarker:SetDrawLayer(layer)
        end
    end
    if ns.rangedBar and ns.rangedBar.castOverlay and ns.rangedBar.castOverlay.SetDrawLayer then
        if ns.SetTextureLayerAboveBar then
            ns.SetTextureLayerAboveBar(ns.rangedBar.castOverlay, layer, ns.GetBarTextureLayer())
        else
            ns.rangedBar.castOverlay:SetDrawLayer(layer)
        end
    end
end

function ns.ApplyWeaveSparkSettings(texturePath, width, height, layer, alpha)
    if not texturePath or texturePath == "" then
        texturePath = ns.DB_DEFAULTS.weaveSparkTexture
    end
    if not layer or layer == "" then
        layer = ns.GetWeaveSparkLayer()
    end
    width = tonumber(width) or ns.DB_DEFAULTS.weaveSparkWidth
    height = tonumber(height) or ns.DB_DEFAULTS.weaveSparkHeight
    alpha = tonumber(alpha)
    if alpha == nil then
        alpha = ns.GetWeaveSparkAlpha()
    elseif alpha < 0 then
        alpha = 0
    elseif alpha > 1 then
        alpha = 1
    end

    SuperSwingTimerDB.weaveSparkTexture = texturePath
    SuperSwingTimerDB.weaveSparkTextureLayer = layer
    SuperSwingTimerDB.weaveSparkWidth = width
    SuperSwingTimerDB.weaveSparkHeight = height
    SuperSwingTimerDB.weaveSparkAlpha = alpha

    for _, texture in ipairs({ ns.weaveSpark }) do
        if texture then
            texture:SetTexture(texturePath)
            texture:SetDrawLayer(layer, 5) -- high sublayer so spark renders above bar fill
            texture:SetBlendMode(ns.GetIndicatorBlendMode())
            texture:SetWidth(width)
            local targetHeight = math.max(1, math.min(height, (ns.mhBar and ns.mhBar:GetHeight()) or height))
            texture:SetHeight(targetHeight)
            texture:SetAlpha(alpha)
        end
    end
end

function ns.ApplyWeaveSparkTextureLayer(layer)
    if not layer or layer == "" then
        layer = ns.DB_DEFAULTS.weaveSparkTextureLayer
    end
    SuperSwingTimerDB.weaveSparkTextureLayer = layer
    if ns.weaveSpark then
        ns.weaveSpark:SetDrawLayer(layer, 5) -- high sublayer so spark renders above bar fill
    end
end

function ns.ApplyWeaveSparkAlpha(alpha)
    alpha = tonumber(alpha) or ns.DB_DEFAULTS.weaveSparkAlpha
    if alpha < 0 then
        alpha = 0
    elseif alpha > 1 then
        alpha = 1
    end
    SuperSwingTimerDB.weaveSparkAlpha = alpha
    if ns.weaveSpark then
        ns.weaveSpark:SetAlpha(alpha)
    end
end

function ns.ApplyWeaveTriangleSettings(topTexture, bottomTexture, size, gap, layer, alpha)
    if not topTexture or topTexture == "" then
        topTexture = ns.DB_DEFAULTS.weaveTriangleTopTexture
    end
    if not bottomTexture or bottomTexture == "" then
        bottomTexture = ns.DB_DEFAULTS.weaveTriangleBottomTexture
    end
    if not layer or layer == "" then
        layer = ns.GetWeaveTriangleLayer()
    end
    size = tonumber(size) or ns.DB_DEFAULTS.weaveTriangleSize
    gap = tonumber(gap) or ns.DB_DEFAULTS.weaveTriangleGap
    alpha = tonumber(alpha)
    if alpha == nil then
        alpha = ns.GetWeaveTriangleAlpha()
    elseif alpha < 0 then
        alpha = 0
    elseif alpha > 1 then
        alpha = 1
    end

    SuperSwingTimerDB.weaveTriangleTopTexture = topTexture
    SuperSwingTimerDB.weaveTriangleBottomTexture = bottomTexture
    SuperSwingTimerDB.weaveTriangleTextureLayer = layer
    SuperSwingTimerDB.weaveTriangleSize = size
    SuperSwingTimerDB.weaveTriangleGap = gap
    SuperSwingTimerDB.weaveTriangleAlpha = alpha

    for _, texture in ipairs({ ns.weaveTriangleTop, ns.weaveTriangleBottom }) do
        if texture then
            texture:SetDrawLayer(layer)
            texture:SetBlendMode(ns.GetIndicatorBlendMode())
            texture:SetWidth(size)
            texture:SetHeight(size)
            texture:SetAlpha(alpha)
        end
    end
    if ns.ApplyWeaveMarkerLayer then
        ns.ApplyWeaveMarkerLayer(layer)
    end
    if ns.weaveTriangleTop then
        ns.weaveTriangleTop:SetTexture(topTexture)
    end
    if ns.weaveTriangleBottom then
        ns.weaveTriangleBottom:SetTexture(bottomTexture)
    end
end

function ns.ApplySparkAlpha(alpha)
    alpha = tonumber(alpha) or ns.DB_DEFAULTS.sparkAlpha
    if alpha < 0 then
        alpha = 0
    elseif alpha > 1 then
        alpha = 1
    end
    local color = ns.GetSparkColor() or ns.DB_DEFAULTS.sparkColor
    ns.ApplySparkColor({ r = color.r or 1, g = color.g or 1, b = color.b or 1, a = alpha })
end

function ns.ApplyMinimalMode(enabled)
    enabled = enabled == true
    SuperSwingTimerDB.minimalMode = enabled
    for _, texture in ipairs({ ns.weaveSpark, ns.weaveTriangleTop, ns.weaveTriangleBottom }) do
        if texture then
            texture:SetShown(not enabled)
        end
    end
    if ns.UpdateRogueSinisterAssistVisual then
        ns.UpdateRogueSinisterAssistVisual()
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
    if ns.UpdateHunterRangeHelperVisual then
        ns.UpdateHunterRangeHelperVisual()
    end
    if ns.UpdatePaladinSealZone then
        ns.UpdatePaladinSealZone()
    end
end

function ns.ApplyVisibility()
    local cfg = ns.classConfig or {}
    local db = SuperSwingTimerDB or ns.DB_DEFAULTS
    local _, ohSpeed = UnitAttackSpeed("player")
    local hasOffHand = ohSpeed and ohSpeed > 0
    local inCombat = (ns.playerInCombat == true) or (InCombatLockdown and InCombatLockdown() or false)
    local previewActive = ns.barTestActive == true
    local meleeMHActive = ns.timers and ns.timers.mh and ns.timers.mh.state == "swinging"
    local meleeOHActive = ns.timers and ns.timers.oh and ns.timers.oh.state == "swinging"
    local rangedActive = ns.timers and ns.timers.ranged and ns.timers.ranged.state == "swinging"
    local hunterCastVisible = ShouldShowHunterCastBar()
    local hunterMeleeActive = IsHunterMeleeActive()
    local hunterMeleeVisible = IsHunterMeleeBarVisible()
    local hunterAutoRepeatActive = ns.playerClass == "HUNTER" and ns.IsHunterAutoRepeatActive
        and ns.IsHunterAutoRepeatActive() or false
    local hunterAutoRepeatVisual = hunterAutoRepeatActive and not hunterMeleeActive
    local showEnemy = db.showEnemy ~= false and (previewActive or (inCombat and ns.enemyTargetGUID ~= nil))
    local showMH = cfg.melee and db.showMH ~= false and (previewActive or inCombat)
    local showOH = cfg.dualWield and db.showOH ~= false and hasOffHand and (previewActive or inCombat)
    local showRanged = cfg.ranged and db.showRanged ~= false and (previewActive or inCombat)
    local effectiveRangedActive = rangedActive
    if ns.playerClass == "HUNTER" then
        -- CRITICAL: Prevent MH bar flicker during ranged-only transitions.
        -- When the ranged timer resets and immediately restarts (auto shot cycle),
        -- rangedActive briefly becomes false. Without a holdover, the condition
        -- (hunterMeleeVisible and not (rangedActive or hunterCastVisible)) would
        -- briefly become true and show the MH bar when it should stay hidden.
        -- Use a 0.1s holdover to smooth this transition.
        local now = GetCurrentTime()
        if ns.rangedTimerHoldEnd == nil or now > ns.rangedTimerHoldEnd then
            ns.rangedTimerHoldEnd = nil
        end
        if rangedActive then
            ns.rangedTimerHoldEnd = now + 0.1
        end
        effectiveRangedActive = rangedActive or (ns.rangedTimerHoldEnd ~= nil)
        showMH = cfg.melee and db.showMH ~= false
            and (previewActive or (hunterMeleeVisible and not (effectiveRangedActive or hunterCastVisible)))
        showRanged = cfg.ranged and db.showRanged ~= false and (previewActive or effectiveRangedActive
                or hunterCastVisible or hunterAutoRepeatVisual)
    end

    if ns.playerClass == "HUNTER" then
        UpdateHunterMeleeBarAnchor(hunterCastVisible)
    end

    if ns.enemyBar then
        ns.enemyBar:SetAlpha(showEnemy and 1 or 0)
        if not showEnemy then
            ResetBarDisplay(ns.enemyBar)
        end
    end

    if ns.mhBar then
        ns.mhBar:SetAlpha(showMH and 1 or 0)
        if not previewActive and not meleeMHActive then
            ResetBarDisplay(ns.mhBar)
        end
    end
    if ns.ohBar then
        ns.ohBar:SetAlpha(showOH and 1 or 0)
        if not previewActive and not meleeOHActive then
            ResetBarDisplay(ns.ohBar)
        end
    end
    if ns.rangedBar then
        ns.rangedBar:SetAlpha(showRanged and 1 or 0)
        -- For Hunters, use the holdover-aware effective ranged state so the bar
        -- display does not flicker during auto-shot cycle transitions.
        if not previewActive and not effectiveRangedActive and not ns.channeling and not hunterAutoRepeatVisual then
            ResetBarDisplay(ns.rangedBar)
        end
    end
    if ns.hunterCastBar then
        ns.hunterCastBar:SetAlpha((showRanged and hunterCastVisible) and 1 or 0)
        if not hunterCastVisible then
            ResetBarDisplay(ns.hunterCastBar)
        end
    end
    if ns.UpdateHunterRangeHelperVisual then
        ns.UpdateHunterRangeHelperVisual()
    end
    if ns.weaveSpark or ns.weaveSparkOH or ns.weaveTriangleTop or ns.weaveTriangleBottom or ns.weaveMarker then
        local showWeave = db.showWeaveAssist ~= false and ns.playerClass == "SHAMAN" and not ns.IsMinimalMode()
        for _, texture in ipairs({ ns.weaveSpark, ns.weaveSparkOH, ns.weaveTriangleTop, ns.weaveTriangleBottom }) do
            if texture then
                texture:SetBlendMode(ns.GetIndicatorBlendMode())
                texture:SetShown(showWeave)
            end
        end
    end
    if ns.UpdateRogueSinisterAssistVisual then
        ns.UpdateRogueSinisterAssistVisual()
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
    if ns.UpdatePaladinSealZone then
        ns.UpdatePaladinSealZone()
    end
    if ns.UpdateLightningShieldVisual then
        ns.UpdateLightningShieldVisual()
    end
    if ns.UpdateShamanFlameShockBar then
        ns.UpdateShamanFlameShockBar(true)
    end
    ns.ApplyLockBars()
end

function ns.ApplyBarColors()
    local colors = SuperSwingTimerDB and SuperSwingTimerDB.colors
    if not colors then return end

    local enemyColor = ns.GetBarColor and ns.GetBarColor("enemy") or colors.enemy
    if ns.enemyBar and enemyColor then
        local c = enemyColor
        ns.enemyBar:SetStatusBarColor(c.r, c.g, c.b, c.a or 1)
        ns.enemyBarBaseColor = { r = c.r, g = c.g, b = c.b, a = c.a or 1 }
    end
    local mhColor = ns.GetBarColor and ns.GetBarColor("mh") or colors.mh
    if ns.mhBar and mhColor then
        local c = mhColor
        ns.mhBar:SetStatusBarColor(c.r, c.g, c.b, c.a or 1)
        ns.mhBarBaseColor = { r = c.r, g = c.g, b = c.b, a = c.a or 1 }
    end
    local ohColor = ns.GetBarColor and ns.GetBarColor("oh") or colors.oh
    if ns.ohBar and ohColor then
        local c = ohColor
        ns.ohBar:SetStatusBarColor(c.r, c.g, c.b, c.a or 1)
        ns.ohBarBaseColor = { r = c.r, g = c.g, b = c.b, a = c.a or 1 }
    end
    local rangedColor = ns.GetBarColor and ns.GetBarColor("ranged") or colors.ranged
    if rangedColor then
        local c = rangedColor
        ns.rangedBarBaseColor = { r = c.r, g = c.g, b = c.b, a = c.a or 1 }
        if ns.rangedBar then
            ns.rangedBar:SetStatusBarColor(c.r, c.g, c.b, c.a or 1)
        end
    end
    local hunterCastBarColor = ns.GetBarColor and ns.GetBarColor("hunterCastBar") or colors.hunterCastBar
    if ns.hunterCastBar and hunterCastBarColor then
        local c = hunterCastBarColor
        if c.r and c.g and c.b then
            ns.hunterCastBar:SetStatusBarColor(c.r, c.g, c.b, c.a or 1)
        end
    end
    ns.UpdateCastZoneVisual()
    -- Paladin seal twist line: attached to MH bar when seal is active
    local sealLine = ns.sealTwistBreakpoint or ns.sealTwistZone
    if sealLine and type(sealLine.SetColorTexture) == "function" and colors.sealTwist then
        sealLine:SetColorTexture(
            colors.sealTwist.r or 1, colors.sealTwist.g or 0, colors.sealTwist.b or 0, colors.sealTwist.a or 1
        )
    end
    -- NOTE: The reseal marker keeps its opaque-black creation color from
    -- OnBarsCreated instead of inheriting the sealTwist (red) zone color,
    -- so it stays visually distinct as a thin sharp line.

    if ns.UpdateWarriorQueueTint then
        ns.UpdateWarriorQueueTint()
    end
    if ns.UpdateWarriorRageBar then
        ns.UpdateWarriorRageBar()
    end
    if ns.UpdateWarriorShieldBlockBar then
        ns.UpdateWarriorShieldBlockBar(0, true)
    end
    if ns.UpdateDruidQueueTint then
        ns.UpdateDruidQueueTint()
    end
    if ns.UpdateHunterQueueTint then
        ns.UpdateHunterQueueTint()
    end
    if ns.UpdateHunterRangeHelperColor then
        ns.UpdateHunterRangeHelperColor()
    end
    if ns.UpdateHunterRangeHelperVisual then
        ns.UpdateHunterRangeHelperVisual()
    end
    if ns.UpdateRogueSinisterAssistColor then
        ns.UpdateRogueSinisterAssistColor()
    end
    if ns.UpdateRogueSinisterAssistVisual then
        ns.UpdateRogueSinisterAssistVisual()
    end
    if ns.UpdateRogueEnergyTickColor then
        ns.UpdateRogueEnergyTickColor()
    end
    if ns.UpdateRogueEnergyTickVisual then
        ns.UpdateRogueEnergyTickVisual()
    end
    if ns.UpdateRogueComboPointColor then
        ns.UpdateRogueComboPointColor()
    end
    if ns.UpdateRogueComboPointVisual then
        ns.UpdateRogueComboPointVisual()
    end
    if ns.UpdateRogueSliceAndDiceColor then
        ns.UpdateRogueSliceAndDiceColor()
    end
    if ns.UpdateRogueSliceAndDiceVisual then
        ns.UpdateRogueSliceAndDiceVisual()
    end
    if ns.ApplySparkColor then
        ns.ApplySparkColor()
    end
    if ns.UpdatePaladinSealVisual then
        ns.UpdatePaladinSealVisual()
    end
    -- Also refresh the paladin seal twist zone position (matches Rogue pattern)
    if ns.UpdatePaladinSealZone then
        ns.UpdatePaladinSealZone()
    end
    if ns.UpdateDruidEnergyTickColor then
        ns.UpdateDruidEnergyTickColor()
    end
    if ns.UpdateHunterRapidFire then
        ns.UpdateHunterRapidFire(0, true)
    end
    if ns.UpdateLightningShieldVisual then
        ns.UpdateLightningShieldVisual()
    end
    if ns.RefreshBarLabelStyles then
        ns.RefreshBarLabelStyles()
    end
end

-- ============================================================
-- Phase 1: Druid rage dim live refresh (throttled every ~200ms)
-- NOTE: ApplyBarColors also applies rage dim on config change;
-- this per-frame path handles dynamic rage changes in combat.
-- ============================================================
-- ============================================================
-- OnUpdate dispatcher (called from bootstrap frame)
-- ============================================================
function ns.OnUpdate(elapsed)
    UpdateRangedBar(elapsed)
    UpdateHunterCastBar()
    if ns.enemyBar then UpdateMeleeBar("enemy", ns.enemyBar) end
    if ns.mhBar then UpdateMeleeBar("mh", ns.mhBar) end
    if ns.ohBar then UpdateMeleeBar("oh", ns.ohBar) end
    -- Phase 1: GCD ticker + swing flash + spark flash render
    UpdateGcdTicker(elapsed)
    UpdateSwingFlash(elapsed)
    RenderSwingFlash()
    if ns.UpdateWarriorQueueTint then ns.UpdateWarriorQueueTint() end
    if ns.UpdateDruidQueueTint then ns.UpdateDruidQueueTint() end
    if ns.UpdateHunterQueueTint then ns.UpdateHunterQueueTint() end
    if ns.UpdateHunterRangeHelperVisual then ns.UpdateHunterRangeHelperVisual() end
    -- Phase 2: Hunter Rapid Fire bar
    if ns.UpdateHunterRapidFire then ns.UpdateHunterRapidFire(elapsed) end
    -- Phase 2: Warrior Flurry counter (throttled internally)
    if ns.UpdateWarriorFlurryCounter then ns.UpdateWarriorFlurryCounter(elapsed) end
    -- Phase 2: Rogue Adrenaline Rush bar
    if ns.UpdateRogueAdrenalineRush then ns.UpdateRogueAdrenalineRush(elapsed) end
    -- Phase 2: Shaman Windfury ICD tracker
    if ns.UpdateShamanWindfuryIcd then ns.UpdateShamanWindfuryIcd() end
end

-- ============================================================
-- Bar initialization (called after SavedVariables are loaded)
-- ============================================================
function ns.InitBars()
    local cfg = ns.classConfig
    if not cfg then return end

    SuperSwingTimerDB.barTexture = SuperSwingTimerDB.barTexture or ns.DB_DEFAULTS.barTexture
    CreateEnemyBar()
    RestorePosition("enemy", ns.enemyBar)
    AttachDrag(ns.enemyBar, "enemy")

    if cfg.ranged then
        CreateRangedBar()
        if cfg.hunterCastBar and ns.playerClass == "HUNTER" then
            CreateHunterCastBar()
        end
        RestorePosition("ranged", ns.rangedBar)
        AttachDrag(ns.rangedBar, "ranged")
    end

    if cfg.melee then
        CreateMHBar()
        if ns.playerClass == "HUNTER" and cfg.ranged then
            UpdateHunterMeleeBarAnchor(false, true)
            ns.mhBar:SetMovable(false)
            ns.mhBar:EnableMouse(false)
        else
            RestorePosition("mh", ns.mhBar)
            AttachDrag(ns.mhBar, "mh")
        end
    end

    if cfg.melee and cfg.dualWield then
        -- Only create OH bar if player has an OH weapon equipped
        -- (checked via UnitAttackSpeed returning a non-nil ohSpeed)
        local _, ohSpeed = UnitAttackSpeed("player")
        if ohSpeed then
            CreateOHBar()
            -- OH doesn't need drag â€” it follows MH automatically
        end
    end

    -- Phase 1: GCD ticker bar (all melee classes except Hunter)
    if cfg.melee and ns.playerClass ~= "HUNTER" then
        CreateGcdTickerBar()
    end

    -- Notify ClassMods that bars exist
    if ns.OnBarsCreated then ns.OnBarsCreated() end

    -- Apply the persisted bar texture after the bars exist.
    ns.ApplyBarTexture(ns.GetBarTexture())
    ns.ApplyBarTextureLayer(ns.GetBarTextureLayer())
    ns.ApplySparkSettings(ns.GetSparkTexture(), ns.GetSparkWidth(), ns.GetSparkHeight())
    ns.ApplySparkTextureLayer(ns.GetSparkTextureLayer())
    ns.ApplyBarBackgroundAlpha(ns.GetBarBackgroundAlpha())
    ns.ApplyBarBorderSize(ns.GetBarBorderSize())
    ns.ApplySparkColor(ns.GetSparkColor())
    ns.ApplyMinimalMode(ns.IsMinimalMode())
    ns.ApplyVisibility()
    ns.ApplyLockBars()
end

-- ============================================================
-- OH bar creation on equipment change
-- ============================================================
function ns.UpdateOHBar()
    local cfg = ns.classConfig
    if not cfg or not cfg.dualWield then return end

    local _, ohSpeed = UnitAttackSpeed("player")
    if ohSpeed and ohSpeed > 0 then
        CreateOHBar()
        if ns.ApplyVisibility then
            ns.ApplyVisibility()
        end
    elseif ns.ohBar then
        ns.ohBar:Hide()
        ns.ResetTimer("oh")
    end
    if ns.UpdateRogueEnergyTickVisual then
        ns.UpdateRogueEnergyTickVisual()
    end
end

-- Callbacks set by ClassMods (optional)
ns.OnMeleeSwing = nil
ns.OnRangedSwing = nil
ns.OnBarsCreated = nil
ns.OnDruidFormChange = nil
