local addonName, ns = ...

local CreateFrame = rawget(_G, "CreateFrame")
local UIParent = rawget(_G, "UIParent")
local GetTimePreciseSec = rawget(_G, "GetTimePreciseSec")
local GetTime = rawget(_G, "GetTime")
local GetSpellInfo = rawget(_G, "GetSpellInfo")
local UnitAttackSpeed = rawget(_G, "UnitAttackSpeed")
local UnitRangedDamage = rawget(_G, "UnitRangedDamage")
local UnitChannelInfo = rawget(_G, "UnitChannelInfo")

local function GetCurrentTime()
	if GetTimePreciseSec then
		return GetTimePreciseSec() + (ns.cachedLatency or 0)
	end
	return GetTime() + (ns.cachedLatency or 0)
end

local function GetRangedCastWindow()
	local baseWindow = ns.CAST_WINDOW or 0
	local castWindow = baseWindow + (ns.cachedLatency or 0)
	if castWindow < 0 then
		return 0
	end
	return castWindow
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
	backgroundTexture:SetColorTexture(0, 0, 0, 1)
	backgroundTexture:SetAlpha(ns.GetBarBackgroundAlpha())

	-- Border: 4 thin edges so the fill remains visible
	local borderTop = f:CreateTexture(nil, "OVERLAY")
	borderTop:SetColorTexture(0, 0, 0, 1)
	borderTop:SetPoint("TOPLEFT", -1, 1)
	borderTop:SetPoint("TOPRIGHT", 1, 1)
	borderTop:SetHeight(1)

	local borderBottom = f:CreateTexture(nil, "OVERLAY")
	borderBottom:SetColorTexture(0, 0, 0, 1)
	borderBottom:SetPoint("BOTTOMLEFT", -1, -1)
	borderBottom:SetPoint("BOTTOMRIGHT", 1, -1)
	borderBottom:SetHeight(1)

	local borderLeft = f:CreateTexture(nil, "OVERLAY")
	borderLeft:SetColorTexture(0, 0, 0, 1)
	borderLeft:SetPoint("TOPLEFT", -1, 1)
	borderLeft:SetPoint("BOTTOMLEFT", -1, -1)
	borderLeft:SetWidth(1)

	local borderRight = f:CreateTexture(nil, "OVERLAY")
	borderRight:SetColorTexture(0, 0, 0, 1)
	borderRight:SetPoint("TOPRIGHT", 1, 1)
	borderRight:SetPoint("BOTTOMRIGHT", 1, -1)
	borderRight:SetWidth(1)

	local sparkTexture = overlayFrame:CreateTexture(nil, "OVERLAY")
	sparkTexture:SetTexture(ns.GetSparkTexture())
	if ns.SetTextureLayerAboveBar then
		ns.SetTextureLayerAboveBar(sparkTexture, ns.GetSparkTextureLayer(), ns.GetBarTextureLayer())
	else
		sparkTexture:SetDrawLayer(ns.GetSparkTextureLayer())
	end
	sparkTexture:SetBlendMode(ns.GetIndicatorBlendMode())
	sparkTexture:SetWidth(ns.GetSparkWidth())
	sparkTexture:SetHeight(ns.GetSparkHeight())
	sparkTexture:SetAlpha(ns.GetSparkAlpha())
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

-- ============================================================
-- Ranged bar (preserves v1.x behavior exactly)
-- ============================================================
local function CreateRangedBar()
	local f = CreateBar("SuperSwingTimerRangedBar")
	local overlayFrame = ns.GetOverlayFrame and ns.GetOverlayFrame(f) or f

	-- Red "cast window" overlay
	local castOverlay = overlayFrame:CreateTexture(nil, "ARTWORK")
	castOverlay:SetColorTexture(1, 0, 0, 0.4)
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
	castThresholdMarker:SetWidth(5)
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
	local f = CreateBar("SuperSwingTimerOHBar")
	local c = ns.GetBarColor and ns.GetBarColor("oh") or (SuperSwingTimerDB and SuperSwingTimerDB.colors and SuperSwingTimerDB.colors.oh)
	if c then
		f:SetStatusBarColor(c.r, c.g, c.b, c.a)
	else
		f:SetStatusBarColor(0, 0, 0, 1)
	end
	f.labelText:SetText("Off Hand")
	f:SetMinMaxValues(0, 1)
	-- Anchor OH below MH with 2px gap
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", mh, "BOTTOMLEFT", 0, -2)
	f:SetPoint("TOPRIGHT", mh, "BOTTOMRIGHT", 0, -2)
	ns.ohBar = f
	return f
end

-- ============================================================
-- Cast-zone visual for ranged bar
-- ============================================================
local function UpdateCastZoneVisual(castWindow)
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

		if f.castThresholdMarker then
			local markerWidth = math.min(5, barWidth)
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
end

local function RestorePosition(slot, frame)
	if not frame then return end
	local pos = SuperSwingTimerDB and SuperSwingTimerDB.positions and SuperSwingTimerDB.positions[slot]
	if pos then
		frame:ClearAllPoints()
		frame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
	end
end

-- ============================================================
-- Drag handling (anchor bar only â€” OH follows MH automatically)
-- ============================================================
local function AttachDrag(frame, slot)
	frame:SetScript("OnMouseDown", function(self, button)
		if button == "LeftButton" and not self.isMoving and not ns.AreBarsLocked() then
			self:StartMoving()
			self.isMoving = true
		end
	end)
	frame:SetScript("OnMouseUp", function(self, button)
		if button == "LeftButton" and self.isMoving then
			self:StopMovingOrSizing()
			self.isMoving = false
			SavePosition(slot, self)
		end
	end)
end

-- ============================================================
-- Combat show/hide
-- ============================================================
local function ShowBars()
	local cfg = ns.classConfig
	local db = SuperSwingTimerDB or ns.DB_DEFAULTS
	if cfg and cfg.ranged and db.showRanged ~= false and ns.rangedBar then
		ns.rangedBar:SetAlpha(1)
	end
	if cfg and cfg.melee and db.showMH ~= false and ns.mhBar then
		ns.mhBar:SetAlpha(1)
	end
	if cfg and cfg.dualWield and db.showOH ~= false and ns.ohBar then
		ns.ohBar:SetAlpha(1)
	end
end

local function HideBars()
	if ns.rangedBar then ns.rangedBar:SetAlpha(0) end
	if ns.mhBar     then ns.mhBar:SetAlpha(0) end
	if ns.ohBar     then ns.ohBar:SetAlpha(0) end
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
		if not channelName and ns.channelingSpellId and GetSpellInfo then
			channelName = GetSpellInfo(ns.channelingSpellId)
		end
		channelName = channelName or "Channel"
		if channelName and startTimeMs and endTimeMs and endTimeMs > startTimeMs then
			local channelNow = GetTimePreciseSec and GetTimePreciseSec() or GetTime()
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

			local barWidth = f:GetWidth() or f.barWidth or ns.BAR_WIDTH or 0
			local sparkPos = (elapsedChannel / channelDuration) * barWidth
			if sparkPos > barWidth then sparkPos = barWidth end
			local sparkAnchor = ns.GetOverlayFrame and ns.GetOverlayFrame(f) or f
			f.sparkTexture:ClearAllPoints()
			f.sparkTexture:SetPoint("CENTER", sparkAnchor, "LEFT", sparkPos, 0)
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
	UpdateCastZoneVisual(rangedWindowLead)

	-- Movement clipping in cast window
	local cooldownEnd = t.lastSwing + t.duration - rangedWindowLead
	if now >= cooldownEnd then
		f:SetStatusBarColor(1, 0, 0, 1)  -- red: cast window
		if ns.isMoving then
			-- Pin timer at cast-window boundary
			t.lastSwing = now - (t.duration - rangedWindowLead)
		end
	else
		local c = ns.rangedBarBaseColor
		if c then
			f:SetStatusBarColor(c.r, c.g, c.b, c.a)
		else
			f:SetStatusBarColor(0, 0, 0, 1)
		end
	end

	local elapsed_time = now - t.lastSwing
	if elapsed_time < 0 then elapsed_time = 0 end
	if elapsed_time > t.duration then elapsed_time = t.duration end
	local remaining = t.duration - elapsed_time
	if remaining < 0 then remaining = 0 end

	f:SetMinMaxValues(0, t.duration)
	f:SetValue(elapsed_time)
	f.labelText:SetText(string.format("%.1f", remaining))

	local barWidth = f:GetWidth() or f.barWidth or ns.BAR_WIDTH or 0
	local sparkPos = (elapsed_time / t.duration) * barWidth
	if sparkPos > barWidth then sparkPos = barWidth end
	local sparkAnchor = ns.GetOverlayFrame and ns.GetOverlayFrame(f) or f
	f.sparkTexture:ClearAllPoints()
	f.sparkTexture:SetPoint("CENTER", sparkAnchor, "LEFT", sparkPos, 0)
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

	local barWidth = frame:GetWidth() or frame.barWidth or ns.BAR_WIDTH or 0
	local sparkPos = (elapsed_time / t.duration) * barWidth
	if sparkPos > barWidth then sparkPos = barWidth end
	local sparkAnchor = ns.GetOverlayFrame and ns.GetOverlayFrame(frame) or frame
	frame.sparkTexture:ClearAllPoints()
	frame.sparkTexture:SetPoint("CENTER", sparkAnchor, "LEFT", sparkPos, 0)
end

-- ============================================================
-- Runtime apply functions (called from config panel)
-- ============================================================
function ns.ApplyBarSize(width, height)
	ns.BAR_WIDTH  = width
	ns.BAR_HEIGHT = height
	SuperSwingTimerDB.barWidth  = width
	SuperSwingTimerDB.barHeight = height

	local bars = { ns.mhBar, ns.ohBar, ns.rangedBar }
	for _, bar in ipairs(bars) do
		if bar then
			bar:SetSize(width, height)
			bar.barWidth = width
			if bar.sparkTexture then
				bar.sparkTexture:SetWidth(ns.GetSparkWidth())
				bar.sparkTexture:SetHeight(ns.GetSparkHeight())
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
	for _, bar in ipairs({ ns.mhBar, ns.ohBar }) do
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
	for _, bar in ipairs({ ns.rangedBar }) do
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
	for _, bar in ipairs({ ns.mhBar, ns.ohBar, ns.rangedBar }) do
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

function ns.ApplyBarBackgroundAlpha(alpha)
	alpha = tonumber(alpha) or ns.DB_DEFAULTS.barBackgroundAlpha
	if alpha < 0 then alpha = 0 elseif alpha > 1 then alpha = 1 end
	SuperSwingTimerDB.barBackgroundAlpha = alpha
	for _, bar in ipairs({ ns.mhBar, ns.ohBar, ns.rangedBar }) do
		if bar and bar.backgroundTexture then
			bar.backgroundTexture:SetAlpha(alpha)
		end
	end
end

function ns.ApplySparkSettings(texturePath, width, height, layer, alpha)
	if not texturePath or texturePath == "" then
		texturePath = ns.DB_DEFAULTS.sparkTexture
	end
	if not layer or layer == "" then
		layer = ns.GetSparkTextureLayer()
	end
	width = width or ns.DB_DEFAULTS.sparkWidth
	height = height or ns.DB_DEFAULTS.sparkHeight
	alpha = tonumber(alpha)
	if alpha == nil then
		alpha = ns.GetSparkAlpha()
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

	for _, bar in ipairs({ ns.mhBar, ns.ohBar, ns.rangedBar }) do
		if bar and bar.sparkTexture then
			bar.sparkTexture:SetTexture(texturePath)
			if ns.SetTextureLayerAboveBar then
				ns.SetTextureLayerAboveBar(bar.sparkTexture, layer, ns.GetBarTextureLayer())
			else
				bar.sparkTexture:SetDrawLayer(layer)
			end
			bar.sparkTexture:SetBlendMode(ns.GetIndicatorBlendMode())
			bar.sparkTexture:SetWidth(width)
			bar.sparkTexture:SetHeight(height)
			bar.sparkTexture:SetAlpha(alpha)
		end
	end
end

function ns.ApplyIndicatorBlendMode(blendMode)
	blendMode = blendMode or ns.GetIndicatorBlendMode()
	if blendMode ~= "ADD" and blendMode ~= "BLEND" then
		blendMode = ns.DB_DEFAULTS.indicatorBlendMode
	end

	SuperSwingTimerDB.indicatorBlendMode = blendMode

	for _, bar in ipairs({ ns.mhBar, ns.ohBar, ns.rangedBar }) do
		if bar and bar.sparkTexture then
			bar.sparkTexture:SetBlendMode(blendMode)
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
	for _, bar in ipairs({ ns.mhBar, ns.ohBar, ns.rangedBar }) do
		if bar and bar.sparkTexture then
			if ns.SetTextureLayerAboveBar then
				ns.SetTextureLayerAboveBar(bar.sparkTexture, layer, ns.GetBarTextureLayer())
			else
				bar.sparkTexture:SetDrawLayer(layer)
			end
		end
	end
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
			texture:SetHeight(height)
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
	SuperSwingTimerDB.sparkAlpha = alpha
	for _, bar in ipairs({ ns.mhBar, ns.ohBar, ns.rangedBar }) do
		if bar and bar.sparkTexture then
			bar.sparkTexture:SetAlpha(alpha)
		end
	end
end

function ns.ApplyMinimalMode(enabled)
	enabled = enabled == true
	SuperSwingTimerDB.minimalMode = enabled
	for _, texture in ipairs({ ns.weaveSpark, ns.weaveTriangleTop, ns.weaveTriangleBottom }) do
		if texture then
			texture:SetShown(not enabled)
		end
	end
end

function ns.ApplyVisibility()
	local cfg = ns.classConfig or {}
	local db = SuperSwingTimerDB or ns.DB_DEFAULTS
	local showMH = cfg.melee and db.showMH ~= false
	local showOH = cfg.dualWield and db.showOH ~= false
	local showRanged = cfg.ranged and db.showRanged ~= false

	if ns.mhBar then
		ns.mhBar:SetAlpha(showMH and 1 or 0)
	end
	if ns.ohBar then
		ns.ohBar:SetAlpha(showOH and 1 or 0)
	end
	if ns.rangedBar then
		ns.rangedBar:SetAlpha(showRanged and 1 or 0)
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
end

function ns.ApplyBarColors()
	local colors = SuperSwingTimerDB and SuperSwingTimerDB.colors
	if not colors then return end

	-- Bars always use alpha=1; the seal breakpoint line is also kept opaque by default.
	local mhColor = ns.GetBarColor and ns.GetBarColor("mh") or colors.mh
	if ns.mhBar and mhColor then
		local c = mhColor
		ns.mhBar:SetStatusBarColor(c.r, c.g, c.b, 1)
		ns.mhBarBaseColor = { r = c.r, g = c.g, b = c.b, a = 1 }
	end
	local ohColor = ns.GetBarColor and ns.GetBarColor("oh") or colors.oh
	if ns.ohBar and ohColor then
		local c = ohColor
		ns.ohBar:SetStatusBarColor(c.r, c.g, c.b, 1)
	end
	local rangedColor = ns.GetBarColor and ns.GetBarColor("ranged") or colors.ranged
	if rangedColor then
		local c = rangedColor
		ns.rangedBarBaseColor = { r = c.r, g = c.g, b = c.b, a = 1 }
		if ns.rangedBar then
			ns.rangedBar:SetStatusBarColor(c.r, c.g, c.b, 1)
		end
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
end

-- ============================================================
-- OnUpdate dispatcher (called from bootstrap frame)
-- ============================================================
function ns.OnUpdate(elapsed)
	UpdateRangedBar(elapsed)
	if ns.mhBar then UpdateMeleeBar("mh", ns.mhBar) end
	if ns.ohBar then UpdateMeleeBar("oh", ns.ohBar) end
end

-- ============================================================
-- Bar initialization (called after SavedVariables are loaded)
-- ============================================================
function ns.InitBars()
	local cfg = ns.classConfig
	if not cfg then return end

	SuperSwingTimerDB.barTexture = SuperSwingTimerDB.barTexture or ns.DB_DEFAULTS.barTexture

	if cfg.ranged then
		CreateRangedBar()
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
	ns.ApplySparkAlpha(ns.GetSparkAlpha())
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
	if ohSpeed and not ns.ohBar then
		CreateOHBar()
	elseif not ohSpeed and ns.ohBar then
		ns.ohBar:Hide()
		ns.ohBar = nil
		ns.timers.oh.state = "idle"
		ns.RefreshUpdateLoop()
	end
end

-- Callbacks set by ClassMods (optional)
ns.OnMeleeSwing  = nil
ns.OnRangedSwing = nil
ns.OnBarsCreated = nil
ns.OnDruidFormChange = nil

