local _, ns = ...

local CreateFrame = rawget(_G, "CreateFrame")
local UIParent = rawget(_G, "UIParent")
local InCombatLockdown = rawget(_G, "InCombatLockdown")
local GetTimePreciseSec = rawget(_G, "GetTimePreciseSec")
local GetTime = rawget(_G, "GetTime")
local UnitCastingInfo = rawget(_G, "UnitCastingInfo")
local UnitAttackSpeed = rawget(_G, "UnitAttackSpeed")
local UnitChannelInfo = rawget(_G, "UnitChannelInfo")

local function GetCurrentTime()
	if ns.GetAlignedTime then
		return ns.GetAlignedTime()
	end
	if GetTimePreciseSec then
		return GetTimePreciseSec()
	end
	return GetTime()
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
		a = fallbackColor.a ~= nil and fallbackColor.a or 1,
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
	return math.max(6, baseHeight - 5)
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
	local sparkWidth = (bar.sparkTexture.GetWidth and bar.sparkTexture:GetWidth()) or (ns.GetSparkWidth and ns.GetSparkWidth()) or 0
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

local function IsHunterCastSpell(spellId)
	return spellId ~= nil and ns.IsHunterCastSpell and ns.IsHunterCastSpell(spellId)
end

local function GetHunterHiddenCastWindowFromRangedTimer(now)
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
			t.hiddenCastWindowStart = now
			return t.hiddenCastWindowStart, t.hiddenCastWindowDuration
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

local function ShouldShowHunterCastBar()
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

	if type(UnitCastingInfo) == "function" then
		local castSpellName, _, _, _, _, _, _, castSpellId = UnitCastingInfo("player")
		local liveSpell = castSpellId or castSpellName
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
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
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
	local backgroundColor = ns.GetBarBackgroundColor and ns.GetBarBackgroundColor() or (ns.DB_DEFAULTS and ns.DB_DEFAULTS.barBackgroundColor)
	backgroundColor = backgroundColor or { r = 0, g = 0, b = 0, a = 0.5 }
	backgroundTexture:SetColorTexture(backgroundColor.r or 0, backgroundColor.g or 0, backgroundColor.b or 0, 1)
	backgroundTexture:SetAlpha(backgroundColor.a ~= nil and backgroundColor.a or (ns.GetBarBackgroundAlpha() or 1))

	-- Border: 4 thin edges so the fill remains visible
	local borderColor = ns.GetBarBorderColor and ns.GetBarBorderColor() or (ns.DB_DEFAULTS and ns.DB_DEFAULTS.barBorderColor)
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

	f.borderTextures = {
		top = borderTop,
		bottom = borderBottom,
		left = borderLeft,
		right = borderRight,
	}

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

	local labelText = overlayFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	labelText:SetPoint("CENTER")
	labelText:Show()

	f.backgroundTexture = backgroundTexture
	f.statusBarTexture = statusBarTexture
	f.sparkTexture = sparkTexture
	f.labelText = labelText
	f.barWidth = f:GetWidth()
	return f
end

local function CreateEnemyBar()
	local f = CreateBar("SuperSwingTimerEnemyBar")
	local c = ns.GetBarColor and ns.GetBarColor("enemy") or (SuperSwingTimerDB and SuperSwingTimerDB.colors and SuperSwingTimerDB.colors.enemy)
	if c then
		f:SetStatusBarColor(c.r, c.g, c.b, c.a or 1)
	else
		f:SetStatusBarColor(1, 0, 0, 1)
	end
	f.labelText:SetText("Enemy")
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
		autoShotUnsafeColor.r or 1,
		autoShotUnsafeColor.g or 0,
		autoShotUnsafeColor.b or 0,
		autoShotUnsafeColor.a ~= nil and autoShotUnsafeColor.a or 0.4
	)
	castOverlay:SetPoint("TOPRIGHT")
	castOverlay:SetPoint("BOTTOMRIGHT")
	if ns.SetTextureLayerAboveBar then
		ns.SetTextureLayerAboveBar(castOverlay, ns.GetWeaveMarkerLayer and ns.GetWeaveMarkerLayer() or "OVERLAY", ns.GetBarTextureLayer and ns.GetBarTextureLayer() or "ARTWORK")
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

	f.labelText:SetText("Auto Shot")
	f:SetMinMaxValues(0, 1)
	ns.rangedBar = f
	return f
end

local function CreateHunterCastBar()
	local f = CreateBar("SuperSwingTimerHunterCastBar", nil, ns.HUNTER_CAST_BAR_HEIGHT or 10)
	local rangedBar = ns.rangedBar
	if not rangedBar then
		return f
	end

	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", rangedBar, "BOTTOMLEFT", 0, -(ns.HUNTER_CAST_BAR_GAP or 2))
	f:SetPoint("TOPRIGHT", rangedBar, "BOTTOMRIGHT", 0, -(ns.HUNTER_CAST_BAR_GAP or 2))
	f:SetMovable(false)
	f:EnableMouse(false)
	f.labelText:Hide()
	f.labelText:SetText("")
	if ns.GetRangedBarTexture then
		f:SetStatusBarTexture(ns.GetRangedBarTexture())
	end
	if ns.GetBarColor then
		local c = ns.GetBarColor("ranged")
		if c then
			f:SetStatusBarColor(c.r, c.g, c.b, c.a or 1)
		end
	end
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
	local c = ns.GetBarColor and ns.GetBarColor("mh") or (SuperSwingTimerDB and SuperSwingTimerDB.colors and SuperSwingTimerDB.colors.mh)
	if c then
		f:SetStatusBarColor(c.r, c.g, c.b, c.a)
	else
		f:SetStatusBarColor(0, 0, 0, 1)
	end
	f.labelText:SetText("Main Hand")
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
	local c = ns.GetBarColor and ns.GetBarColor("oh") or (SuperSwingTimerDB and SuperSwingTimerDB.colors and SuperSwingTimerDB.colors.oh)
	if c then
		f:SetStatusBarColor(c.r, c.g, c.b, c.a)
	else
		f:SetStatusBarColor(0, 0, 0, 1)
	end
	f.labelText:SetText("Off Hand")
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
				safeColor.r or 0.2,
				safeColor.g or 0.78,
				safeColor.b or 0.25,
				safeColor.a ~= nil and safeColor.a or 0.4
			)
		else
			local unsafeColor = GetAutoShotWindowColor("autoShotUnsafe", { r = 1, g = 0, b = 0, a = 0.4 })
			f.castOverlay:SetColorTexture(
				unsafeColor.r or 1,
				unsafeColor.g or 0,
				unsafeColor.b or 0,
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

local function UpdateHunterCastBar()
	local f = ns.hunterCastBar
	if not f then
		return
	end

	if not ShouldShowHunterCastBar() then
		f:SetAlpha(0)
		f:SetMinMaxValues(0, 1)
		f:SetValue(0)
		return
	end

	local now = GetCurrentTime()
	local castWindow = math.max(GetRangedCastWindow() or ns.CAST_WINDOW or 0.5, 0.01)
	local elapsedTime
	local duration
	local rangedWindowStart, rangedWindowDuration = GetHunterHiddenCastWindowFromRangedTimer(now)
	local usingStoredHunterCast = false
	local usingLiveHunterCast = false

	local spellId = ns.hunterCastSpellId or ns.currentCastSpellId
	local startTime = nil
	if type(UnitCastingInfo) == "function" then
		local castSpellName, _, _, startTimeMs, endTimeMs, _, _, castSpellId = UnitCastingInfo("player")
		local liveSpell = castSpellId or castSpellName
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
				if startTimeMs and startTimeMs > 0 then
					startTime = (startTimeMs / 1000)
				end
				if startTimeMs and endTimeMs and endTimeMs > startTimeMs then
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
		f:SetAlpha(0)
		f:SetMinMaxValues(0, 1)
		f:SetValue(0)
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

	f:SetAlpha(1)
	f:SetMinMaxValues(0, duration)
	f:SetValue(elapsedTime)
	UpdateSparkPosition(f, duration > 0 and (elapsedTime / duration) or 0)
end

-- ============================================================
-- Bar position save/restore
-- ============================================================
local function SavePosition(slot, frame)
	if not frame then return end
	local point, _, relativePoint, x, y = frame:GetPoint()
	if SuperSwingTimerDB and SuperSwingTimerDB.positions then
		SuperSwingTimerDB.positions[slot] = {
			point = point, relativePoint = relativePoint, x = x, y = y
		}
	end
	if ns.UpdateRogueEnergyTickVisual then
		ns.UpdateRogueEnergyTickVisual()
	end
end

local function RestorePosition(slot, frame)
	if not frame then return end
	local pos = SuperSwingTimerDB and SuperSwingTimerDB.positions and SuperSwingTimerDB.positions[slot]
	if pos then
		frame:ClearAllPoints()
		frame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
	end
end

function ns.RestoreAllBarPositions()
	RestorePosition("enemy", ns.enemyBar)
	RestorePosition("ranged", ns.rangedBar)
	RestorePosition("mh", ns.mhBar)

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
end

-- ============================================================
-- Drag handling (anchor bar only â€” OH follows MH automatically)
-- ============================================================
local function AttachDrag(frame, slot)
	local function StartDrag(self)
		if not self.isMoving and not ns.AreBarsLocked() then
			self:StartMoving()
			self.isMoving = true
		end
	end

	local function StopDrag(self)
		if self.isMoving then
			self:StopMovingOrSizing()
			self.isMoving = false
			SavePosition(slot, self)
		end
	end

	frame:SetScript("OnDragStart", function(self)
		StartDrag(self)
	end)
	frame:SetScript("OnDragStop", function(self)
		StopDrag(self)
	end)
	frame:SetScript("OnMouseDown", function(self, button)
		if button == "LeftButton" then
			StartDrag(self)
		end
	end)
	frame:SetScript("OnMouseUp", function(self, button)
		if button == "LeftButton" then
			StopDrag(self)
		end
	end)
	frame:SetScript("OnHide", function(self)
		if self.isMoving then
			self:StopMovingOrSizing()
			self.isMoving = false
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
	local showEnemy = db.showEnemy ~= false and ns.enemyBar and (ns.enemyTargetGUID ~= nil or (ns.timers.enemy and ns.timers.enemy.state == "swinging"))
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

local function HideBars()
	if ns.enemyBar  then ns.enemyBar:SetAlpha(0) end
	if ns.rangedBar then ns.rangedBar:SetAlpha(0) end
	if ns.hunterCastBar then ns.hunterCastBar:SetAlpha(0) end
	if ns.mhBar     then ns.mhBar:SetAlpha(0) end
	if ns.ohBar     then ns.ohBar:SetAlpha(0) end
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
	local t = ns.timers.ranged
	local f = ns.rangedBar
	if not f then return end

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
			f.labelText:SetText(string.format("%s %.1f", channelName, remainingChannel))
			UpdateSparkPosition(f, channelDuration > 0 and (elapsedChannel / channelDuration) or 0)
			return
		end
	end

	if t.state ~= "swinging" then
		f.castOverlay:SetWidth(0)
		if f.castThresholdMarker then
			f.castThresholdMarker:Hide()
		end
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
	if now >= cooldownEnd then
		local barAlpha = (ns.rangedBarBaseColor and ns.rangedBarBaseColor.a) or 1
		if safeStop then
			local safeColor = GetAutoShotWindowColor("autoShotSafe", { r = 0.2, g = 0.78, b = 0.25, a = 0.4 })
			f:SetStatusBarColor(safeColor.r or 0.2, safeColor.g or 0.78, safeColor.b or 0.25, barAlpha)
		else
			local unsafeColor = GetAutoShotWindowColor("autoShotUnsafe", { r = 1, g = 0, b = 0, a = 0.4 })
			f:SetStatusBarColor(unsafeColor.r or 1, unsafeColor.g or 0, unsafeColor.b or 0, barAlpha)
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

	f:SetMinMaxValues(0, t.duration)
	f:SetValue(elapsed_time)
	f.labelText:SetText(string.format("%.1f", remaining))
	UpdateSparkPosition(f, t.duration > 0 and (elapsed_time / t.duration) or 0)
end

-- ============================================================
-- OnUpdate tick for melee bars
-- ============================================================
local function UpdateMeleeBar(slot, frame)
	local t = ns.timers[slot]
	if not frame or t.state ~= "swinging" then return end

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

	frame:SetMinMaxValues(0, t.duration)
	frame:SetValue(elapsed_time)
	frame.labelText:SetText(string.format("%.1f", remaining))
	UpdateSparkPosition(frame, t.duration > 0 and (elapsed_time / t.duration) or 0)
end

-- ============================================================
-- Runtime apply functions (called from config panel)
-- ============================================================
function ns.ApplyBarSize(width, height)
	ns.BAR_WIDTH  = width
	ns.BAR_HEIGHT = height
	SuperSwingTimerDB.barWidth  = width
	SuperSwingTimerDB.barHeight = height

	local bars = { ns.enemyBar, ns.mhBar, ns.ohBar, ns.rangedBar, ns.hunterCastBar }
	for _, bar in ipairs(bars) do
		if bar then
			local barHeight = height
			if bar == ns.hunterCastBar then
				barHeight = ns.HUNTER_CAST_BAR_HEIGHT or 10
			elseif bar == ns.ohBar then
				barHeight = GetOffHandBarHeight(height)
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
	if ns.UpdateCastZoneVisual then
		ns.UpdateCastZoneVisual()
	end
	if ns.UpdateRogueSinisterAssistVisual then
		ns.UpdateRogueSinisterAssistVisual()
	end
	if ns.UpdateRogueEnergyTickVisual then
		ns.UpdateRogueEnergyTickVisual()
	end
end

function ns.ApplyBarBorderSize(borderSize)
	borderSize = math.floor(tonumber(borderSize) or ns.DB_DEFAULTS.barBorderSize or 1)
	if borderSize < 0 then
		borderSize = 0
	end

	SuperSwingTimerDB.barBorderSize = borderSize

	for _, bar in ipairs({ ns.enemyBar, ns.mhBar, ns.ohBar, ns.rangedBar, ns.hunterCastBar, ns.rogueEnergyTickBar }) do
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
	for _, bar in ipairs({ ns.enemyBar, ns.mhBar, ns.ohBar, ns.rogueEnergyTickBar }) do
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
end

function ns.ApplyRangedBarTexture(texturePath, layer)
	if not texturePath or texturePath == "" then
		texturePath = ns.DB_DEFAULTS.rangedBarTexture or ns.DB_DEFAULTS.barTexture
	end
	if not layer or layer == "" then
		layer = ns.GetBarTextureLayer()
	end

	SuperSwingTimerDB.rangedBarTexture = texturePath
	for _, bar in ipairs({ ns.rangedBar, ns.hunterCastBar }) do
		if bar then
			bar:SetStatusBarTexture(texturePath)
			bar.statusBarTexture = bar.statusBarTexture or bar:GetStatusBarTexture()
			if bar.statusBarTexture then
				-- Keep the ranged fill on its requested layer; overlays are
				-- positioned separately and must not be promoted with the fill.
				bar.statusBarTexture:SetDrawLayer(layer)
			end
		end
	end
	if ns.UpdateCastZoneVisual then
		ns.UpdateCastZoneVisual()
	end
end

function ns.ApplyBarTextureLayer(layer)
	if not layer or layer == "" then
		layer = ns.DB_DEFAULTS.barTextureLayer
	end
	SuperSwingTimerDB.barTextureLayer = layer
	for _, bar in ipairs({ ns.enemyBar, ns.mhBar, ns.ohBar, ns.rangedBar, ns.hunterCastBar, ns.rogueEnergyTickBar }) do
		if bar and bar.statusBarTexture then
			bar.statusBarTexture:SetDrawLayer(layer)
		end
	end
	if ns.ApplySparkTextureLayer then
		ns.ApplySparkTextureLayer(SuperSwingTimerDB.sparkTextureLayer or ns.DB_DEFAULTS.sparkTextureLayer)
	end
	if ns.ApplyWeaveSparkTextureLayer then
		ns.ApplyWeaveSparkTextureLayer(SuperSwingTimerDB.weaveSparkTextureLayer or ns.DB_DEFAULTS.weaveSparkTextureLayer)
	end
	if ns.ApplyWeaveMarkerLayer then
		ns.ApplyWeaveMarkerLayer(SuperSwingTimerDB.weaveTriangleTextureLayer or ns.DB_DEFAULTS.weaveTriangleTextureLayer)
	end
	if ns.rangedBar and ns.rangedBar.castOverlay and ns.SetTextureLayerAboveBar then
		ns.SetTextureLayerAboveBar(ns.rangedBar.castOverlay, SuperSwingTimerDB.weaveMarkerLayer or ns.DB_DEFAULTS.weaveMarkerLayer, layer)
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
	for _, bar in ipairs({ ns.enemyBar, ns.mhBar, ns.ohBar, ns.rangedBar, ns.hunterCastBar, ns.rogueEnergyTickBar }) do
		if bar and bar.backgroundTexture then
			bar.backgroundTexture:SetColorTexture(r, g, b, 1)
			bar.backgroundTexture:SetAlpha(alpha)
		end
	end
end

function ns.ApplyBarBackgroundAlpha(alpha)
	alpha = tonumber(alpha) or ns.DB_DEFAULTS.barBackgroundAlpha
	if alpha < 0 then alpha = 0 elseif alpha > 1 then alpha = 1 end
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
	for _, bar in ipairs({ ns.enemyBar, ns.mhBar, ns.ohBar, ns.rangedBar, ns.hunterCastBar, ns.rogueEnergyTickBar }) do
		local borderTextures = bar and bar.borderTextures or nil
		if borderTextures then
			for _, texture in pairs(borderTextures) do
				if texture then
					texture:SetColorTexture(r, g, b, alpha)
				end
			end
		end
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
			bar.sparkTexture:SetAlpha(1)
			UpdateSparkPosition(bar)
		end
	end
	if ns.ApplyRogueCueLayer then
		ns.ApplyRogueCueLayer()
	end
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
	for _, texture in ipairs({ ns.weaveTriangleTop, ns.weaveTriangleBottom, ns.sealTwistBreakpoint, ns.sealTwistResealBreakpoint }) do
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
			if ns.SetTextureLayerAboveBar then
				ns.SetTextureLayerAboveBar(texture, layer, ns.GetBarTextureLayer())
			else
				texture:SetDrawLayer(layer)
			end
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
		if ns.SetTextureLayerAboveBar then
			ns.SetTextureLayerAboveBar(ns.weaveSpark, layer, ns.GetBarTextureLayer())
		else
			ns.weaveSpark:SetDrawLayer(layer)
		end
	end
end

function ns.ApplyWeaveSparkAlpha(alpha)
	alpha = tonumber(alpha) or ns.DB_DEFAULTS.weaveSparkAlpha
	if alpha < 0 then alpha = 0 elseif alpha > 1 then alpha = 1 end
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
	if alpha < 0 then alpha = 0 elseif alpha > 1 then alpha = 1 end
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
end

function ns.ApplyVisibility()
	local cfg = ns.classConfig or {}
	local db = SuperSwingTimerDB or ns.DB_DEFAULTS
	local _, ohSpeed = UnitAttackSpeed("player")
	local hasOffHand = ohSpeed and ohSpeed > 0
	local inCombat = InCombatLockdown and InCombatLockdown() or false
	local previewActive = ns.barTestActive == true
	local rangedActive = ns.timers and ns.timers.ranged and ns.timers.ranged.state == "swinging"
	local hunterCastVisible = ShouldShowHunterCastBar()
	local showEnemy = db.showEnemy ~= false and (
		previewActive or
		(inCombat and (ns.enemyTargetGUID ~= nil or (ns.timers.enemy and ns.timers.enemy.state == "swinging")))
	)
	local showMH = cfg.melee and db.showMH ~= false and (previewActive or inCombat)
	local showOH = cfg.dualWield and db.showOH ~= false and hasOffHand and (previewActive or inCombat)
	local showRanged = cfg.ranged and db.showRanged ~= false and (previewActive or inCombat or rangedActive or hunterCastVisible)

	if ns.enemyBar then
		ns.enemyBar:SetAlpha(showEnemy and 1 or 0)
	end

	if ns.mhBar then
		ns.mhBar:SetAlpha(showMH and 1 or 0)
	end
	if ns.ohBar then
		ns.ohBar:SetAlpha(showOH and 1 or 0)
	end
	if ns.rangedBar then
		ns.rangedBar:SetAlpha(showRanged and 1 or 0)
	end
	if ns.hunterCastBar then
		ns.hunterCastBar:SetAlpha((showRanged and hunterCastVisible) and 1 or 0)
	end
	if ns.weaveSpark or ns.weaveTriangleTop or ns.weaveTriangleBottom or ns.weaveMarker then
		local showWeave = db.showWeaveAssist ~= false and ns.playerClass == "SHAMAN" and not ns.IsMinimalMode()
		for _, texture in ipairs({ ns.weaveSpark, ns.weaveTriangleTop, ns.weaveTriangleBottom }) do
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
	end
	local rangedColor = ns.GetBarColor and ns.GetBarColor("ranged") or colors.ranged
	if rangedColor then
		local c = rangedColor
		ns.rangedBarBaseColor = { r = c.r, g = c.g, b = c.b, a = c.a or 1 }
		if ns.rangedBar then
			ns.rangedBar:SetStatusBarColor(c.r, c.g, c.b, c.a or 1)
		end
		if ns.hunterCastBar then
			ns.hunterCastBar:SetStatusBarColor(c.r, c.g, c.b, c.a or 1)
		end
	end
	if ns.UpdateCastZoneVisual then
		ns.UpdateCastZoneVisual()
	end
	if (ns.sealTwistBreakpoint or ns.sealTwistZone) and colors.sealTwist then
		local c = colors.sealTwist
		local sealLine = ns.sealTwistBreakpoint or ns.sealTwistZone
		sealLine:SetColorTexture(c.r, c.g, c.b, c.a or 1)
	end
	if ns.sealTwistResealBreakpoint and colors.sealTwist then
		local c = colors.sealTwist
		ns.sealTwistResealBreakpoint:SetColorTexture(c.r, c.g, c.b, c.a or 1)
	end

	if ns.UpdateWarriorQueueTint then
		ns.UpdateWarriorQueueTint()
	end
	if ns.UpdateDruidQueueTint then
		ns.UpdateDruidQueueTint()
	end
	if ns.UpdateHunterQueueTint then
		ns.UpdateHunterQueueTint()
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
	if ns.ApplySparkColor then
		ns.ApplySparkColor()
	end
end

-- ============================================================
-- OnUpdate dispatcher (called from bootstrap frame)
-- ============================================================
function ns.OnUpdate(elapsed)
	UpdateRangedBar(elapsed)
	UpdateHunterCastBar()
	if ns.enemyBar then UpdateMeleeBar("enemy", ns.enemyBar) end
	if ns.mhBar then UpdateMeleeBar("mh", ns.mhBar) end
	if ns.ohBar then UpdateMeleeBar("oh", ns.ohBar) end
	if ns.UpdateWarriorQueueTint then ns.UpdateWarriorQueueTint() end
	if ns.UpdateDruidQueueTint then ns.UpdateDruidQueueTint() end
	if ns.UpdateHunterQueueTint then ns.UpdateHunterQueueTint() end
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
		RestorePosition("mh", ns.mhBar)
		AttachDrag(ns.mhBar, "mh")
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
ns.OnMeleeSwing  = nil
ns.OnRangedSwing = nil
ns.OnBarsCreated = nil
ns.OnDruidFormChange = nil

