local _, ns = ...

local math_max = math.max
local math_min = math.min
local GetTimePreciseSec = rawget(_G, "GetTimePreciseSec")
local GetTime = rawget(_G, "GetTime")
local GetNetStats = rawget(_G, "GetNetStats")
local UnitSpellHaste = rawget(_G, "UnitSpellHaste")
local GetSpellHaste = rawget(_G, "GetSpellHaste")
local UnitCastingInfo = rawget(_G, "UnitCastingInfo")
local UnitChannelInfo = rawget(_G, "UnitChannelInfo")
local IsSpellKnownOrOverridesKnown = rawget(_G, "IsSpellKnownOrOverridesKnown")
local IsSpellKnown = rawget(_G, "IsSpellKnown")
local IsPlayerSpell = rawget(_G, "IsPlayerSpell")

local function GetClock()
	if ns.GetAlignedTime then
		return ns.GetAlignedTime()
	end
	if GetTimePreciseSec then
		return GetTimePreciseSec()
	end
	return GetTime()
end

GetClock()

local function GetLatencySeconds()
	local _, _, homeLatency, worldLatency = GetNetStats()
	local latencyMs = (worldLatency and worldLatency > 0) and worldLatency or homeLatency or 0
	return math_max(latencyMs / 1000, 0)
end

local function GetSpellHastePercent()
	if type(UnitSpellHaste) == "function" then
		return math_max(UnitSpellHaste("player") or 0, 0)
	end

	if type(GetSpellHaste) == "function" then
		return math_max(GetSpellHaste() or 0, 0)
	end

	return 0
end

local function ResolveSpellInfo(group)
	local hasKnownCheck =
		type(IsSpellKnownOrOverridesKnown) == "function"
		or type(IsSpellKnown) == "function"
		or type(IsPlayerSpell) == "function"

	local function IsKnownSpellRank(spellId)
		if type(IsSpellKnownOrOverridesKnown) == "function" then
			local known = IsSpellKnownOrOverridesKnown(spellId)
			if known ~= nil then
				return known == true
			end
		end

		if type(IsSpellKnown) == "function" then
			local known = IsSpellKnown(spellId)
			if known ~= nil then
				return known == true
			end
		end

		if type(IsPlayerSpell) == "function" then
			local known = IsPlayerSpell(spellId)
			if known ~= nil then
				return known == true
			end
		end

		return false
	end

	-- Rank lists in constants are low -> high. Iterate backward so weave tracking
	-- locks to the highest known rank for leveling profiles.
	for idx = #group.ids, 1, -1 do
		local spellId = group.ids[idx]
		if (not hasKnownCheck) or IsKnownSpellRank(spellId) then
			local spellName, spellIcon, castTime
			if ns.GetSpellInfo then
				local spellInfo = { ns.GetSpellInfo(spellId) }
				spellName = spellInfo[1]
				spellIcon = spellInfo[3]
				castTime = spellInfo[4]
			end
			if spellName and castTime and castTime > 0 then
				return {
					spellId = spellId,
					spellName = spellName,
					iconTexture = spellIcon,
					castTime = castTime / 1000,
					abbrev = group.abbrev,
					label = group.label,
				}
			end
		end
	end
end

local function GetNextSwingExpiration()
	local timer = ns.timers and ns.timers.mh
	if timer and timer.state == "swinging" and timer.duration > 0 then
		return timer.lastSwing + timer.duration
	end

	return nil
end

local function GetSpellFamilyColor(spellInfo, safe)
	local baseColor
	if spellInfo and spellInfo.abbrev and ns.WEAVE_SPELL_FAMILY_COLORS then
		baseColor = ns.WEAVE_SPELL_FAMILY_COLORS[spellInfo.abbrev]
	end
	baseColor = baseColor or { r = 0.8, g = 0.8, b = 0.8, a = 1 }

	local color = {
		r = baseColor.r or 0.8,
		g = baseColor.g or 0.8,
		b = baseColor.b or 0.8,
		a = baseColor.a or 1,
	}

	if safe == false then
		color.a = 0.65
	end

	return color
end

ns.weaveState = ns.weaveState or {
	spellCatalogDirty = true,
	trackedSpellCatalog = {},
	trackedSpellLookup = {},
	defaultSpellId = nil,
	currentSpellId = nil,
	lastSpellId = nil,
	isCasting = false,
	spellCastTime = 0,
	baseSpellCastTime = 0,
	spellExpirationTime = nil,
	castStartTime = nil,
	castStartSwingFraction = nil,
	spellHaste = 0,
	cachedLatency = 0,
}

function ns.RebuildWeaveSpellCatalog()
	local state = ns.weaveState
	if not state then
		return
	end

	state.trackedSpellCatalog = {}
	state.trackedSpellLookup = {}
	state.trackedSpellNameLookup = {}  -- name → spellInfo for Classic TBC events
	state.defaultSpellId = nil

	for _, group in ipairs(ns.WEAVE_SPELL_GROUPS or {}) do
		local familyEnabled = true
		if ns.GetWeaveFamilyEnabled then
			familyEnabled = ns.GetWeaveFamilyEnabled(group.abbrev)
		end

		local info = nil
		if familyEnabled then
			info = ResolveSpellInfo(group)
		end
		if familyEnabled and info then
			state.trackedSpellCatalog[#state.trackedSpellCatalog + 1] = info
			state.trackedSpellLookup[info.spellId] = info
			-- Also index by localized spell name for Classic events that deliver names not IDs
			if info.spellName then
				state.trackedSpellNameLookup[info.spellName] = info
			end
			if not state.defaultSpellId then
				state.defaultSpellId = info.spellId
			end
		end
	end

	state.spellCatalogDirty = false
end

--- Initialize the weave state and rebuild the spell catalog.
--  Must be called once during addon load after ns.DB_DEFAULTS is ready.
--  @return (nil)
function ns.InitWeaving()
	if not ns.weaveState then
		return
	end

	ns.RebuildWeaveSpellCatalog()
	ns.weaveState.cachedLatency = GetLatencySeconds()
	ns.weaveState.spellHaste = GetSpellHastePercent()
end

function ns.RefreshWeavingState()
	local state = ns.weaveState
	if not state then
		return
	end

	state.cachedLatency = GetLatencySeconds()
	state.spellHaste = GetSpellHastePercent()

	if state.spellCatalogDirty then
		ns.RebuildWeaveSpellCatalog()
	end
end

local function GetTrackedSpellInfo(spellValue)
	local state = ns.weaveState
	if not state or not spellValue then
		return nil
	end
	-- Try numeric ID first (CLEU path), then localized name (Classic spellcast events)
	return state.trackedSpellLookup[spellValue]
		or (state.trackedSpellNameLookup and state.trackedSpellNameLookup[spellValue])
end

local function GetDefaultSpellInfo()
	local state = ns.weaveState
	if not state then
		return nil
	end

	if state.currentSpellId then
		local current = GetTrackedSpellInfo(state.currentSpellId)
		if current then
			return current
		end
	end

	if state.lastSpellId then
		local last = GetTrackedSpellInfo(state.lastSpellId)
		if last then
			return last
		end
	end

	if state.defaultSpellId then
		return GetTrackedSpellInfo(state.defaultSpellId)
	end

	return state.trackedSpellCatalog[1]
end

local function ClampFraction(value)
	if type(value) ~= "number" then
		return 0
	end

	return math_max(0, math_min(value, 1))
end

local function GetLivePlayerCastTiming()
	if type(UnitCastingInfo) == "function" then
		local _, _, _, startTimeMs, endTimeMs = UnitCastingInfo("player")
		if type(startTimeMs) == "number" and type(endTimeMs) == "number" and endTimeMs > startTimeMs then
			return startTimeMs / 1000, endTimeMs / 1000
		end
	end

	if type(UnitChannelInfo) == "function" then
		local _, _, _, startTimeMs, endTimeMs = UnitChannelInfo("player")
		if type(startTimeMs) == "number" and type(endTimeMs) == "number" and endTimeMs > startTimeMs then
			return startTimeMs / 1000, endTimeMs / 1000
		end
	end

	return nil, nil
end

local function CaptureWeaveCastTiming(state, spellInfo)
	if not state or not spellInfo then
		return
	end

	local now = GetClock()
	local startTime, endTime = GetLivePlayerCastTiming()

	local castStartTime = startTime or now
	state.castStartTime = castStartTime
	state.baseSpellCastTime = math_max(spellInfo.castTime or 0, 0)

	if type(endTime) == "number" and endTime > castStartTime then
		state.spellExpirationTime = endTime
	else
		local spellHaste = state.spellHaste or GetSpellHastePercent()
		local hasteMultiplier = 1 + (math_max(spellHaste, 0) / 100)
		local effectiveCastTime = math_max(0, spellInfo.castTime / hasteMultiplier)
		state.spellExpirationTime = castStartTime + effectiveCastTime
	end

	local timer = ns.timers and ns.timers.mh
	if timer and timer.state == "swinging" and timer.duration and timer.duration > 0 then
		state.castStartSwingFraction = ClampFraction((castStartTime - timer.lastSwing) / timer.duration)
	else
		state.castStartSwingFraction = nil
	end
end

local function BuildDisplayInfo(spellInfo)
	if not spellInfo then
		return nil
	end

	local state = ns.weaveState
	local timer = ns.timers and ns.timers.mh
	if not timer or timer.state ~= "swinging" or not timer.duration or timer.duration <= 0 then
		return nil
	end

	local nextSwingExpiration = GetNextSwingExpiration()
	if not nextSwingExpiration then
		return nil
	end

	local now = GetClock()
	local latency = state.cachedLatency or GetLatencySeconds()
	local spellHaste = state.spellHaste or GetSpellHastePercent()
	local hasteMultiplier = 1 + (math_max(spellHaste, 0) / 100)
	local effectiveCastTime = math_max(0, spellInfo.castTime / hasteMultiplier)
	local isCasting = state.isCasting and state.currentSpellId == spellInfo.spellId
	local castStartTime = type(state.castStartTime) == "number" and state.castStartTime or nil
	local castElapsed = castStartTime and math_max(now - castStartTime, 0) or 0
	local castRemaining = effectiveCastTime
	local liveCastStart, liveCastEnd = GetLivePlayerCastTiming()
	local liveCastDuration = nil

	if isCasting then
		if liveCastStart and liveCastEnd and liveCastEnd > liveCastStart then
			castStartTime = liveCastStart
			state.castStartTime = castStartTime
			castElapsed = math_max(now - castStartTime, 0)
			castRemaining = math_max(liveCastEnd - now, 0)
			liveCastDuration = math_max(liveCastEnd - liveCastStart, 0)
		elseif type(state.baseSpellCastTime) == "number" and state.baseSpellCastTime > 0 then
			local baseHastedCastTime = math_max(state.baseSpellCastTime / hasteMultiplier, 0.01)
			castRemaining = math_max(baseHastedCastTime - castElapsed, 0)
		elseif type(state.spellExpirationTime) == "number" then
			castRemaining = math_max(0, state.spellExpirationTime - now)
		end
	end

	local safeStartIn = nextSwingExpiration - now - latency - effectiveCastTime
	local clipAmount = math_max(0, (now + latency + castRemaining) - nextSwingExpiration)
	local safe = safeStartIn > 0 and clipAmount <= 0
	local castProgress = 0
	if isCasting then
		local progressDuration = liveCastDuration or effectiveCastTime
		if progressDuration and progressDuration > 0 then
			castProgress = ClampFraction(castElapsed / progressDuration)
		end
	end

	local markerFraction = ClampFraction((timer.duration - (effectiveCastTime + latency)) / timer.duration)
	local currentSwingFraction = ClampFraction((now - timer.lastSwing) / timer.duration)
	local projectedImpactFraction = ClampFraction(((now + castRemaining + latency) - timer.lastSwing) / timer.duration)
	local castStartSwingFraction = state.castStartSwingFraction
	if castStartSwingFraction == nil and type(state.castStartTime) == "number" then
		castStartSwingFraction = ClampFraction((state.castStartTime - timer.lastSwing) / timer.duration)
	end

	local sparkFraction = nil
	if isCasting then
		local liveStartFraction = castStartSwingFraction or currentSwingFraction
		sparkFraction = ClampFraction(liveStartFraction + ((projectedImpactFraction - liveStartFraction) * castProgress))
	end

	local spellLabel = spellInfo.spellName or spellInfo.abbrev or "Weave"
	local text

	if isCasting then
		if clipAmount > 0 then
			text = string.format("%s clip %.1fs", spellLabel, clipAmount)
		else
			text = string.format("%s safe", spellLabel)
		end
	else
		if safe then
			text = string.format("%s start in %.1fs", spellLabel, safeStartIn)
		else
			text = string.format("%s clip %.1fs", spellLabel, -safeStartIn)
		end
	end

	local color = GetSpellFamilyColor(spellInfo, safe)

	return {
		spellId = spellInfo.spellId,
		spellName = spellInfo.spellName,
		iconTexture = spellInfo.iconTexture,
		spellAbbrev = spellInfo.abbrev,
		castTime = effectiveCastTime,
		baseSpellCastTime = state.baseSpellCastTime,
		castRemaining = castRemaining,
		castProgress = castProgress,
		castElapsed = castElapsed,
		latency = latency,
		nextSwingExpiration = nextSwingExpiration,
		safeStartIn = safeStartIn,
		clipAmount = clipAmount,
		safe = safe,
		isCasting = isCasting,
		markerFraction = markerFraction,
		currentSwingFraction = currentSwingFraction,
		castStartSwingFraction = castStartSwingFraction,
		projectedImpactFraction = projectedImpactFraction,
		sparkFraction = sparkFraction,
		text = text,
		color = color,
	}
end

--- Get the current weave display info for Shaman class.
--  Returns nil for non-Shaman or when weave assist is disabled.
--  @return (table|nil) Display info with cast time, safe start, clip amount,
--          spark fraction, colors, and text, or nil if unavailable
--  @see BuildDisplayInfo
function ns.GetWeaveDisplayInfo()
	if ns.playerClass ~= "SHAMAN" then
		return nil
	end

	if SuperSwingTimerDB and SuperSwingTimerDB.showWeaveAssist == false then
		return nil
	end

	ns.RefreshWeavingState()
	local state = ns.weaveState
	local spellInfo = GetTrackedSpellInfo(state.currentSpellId) or GetTrackedSpellInfo(state.lastSpellId) or GetDefaultSpellInfo()
	return BuildDisplayInfo(spellInfo)
end

--- Handle spellcast events for the weave system (Shaman only).
--  Routes UNIT_SPELLCAST_START/SUCCEEDED/STOP/FAILED events to
--  update the tracked spell state and capture cast timing.
--  @param event (string) The spellcast event type
--  @param unit (string) The unit that triggered the event
--  @param castGUIDOrSpellName (string|nil) Cast GUID or spell name
--  @param spellId (number|nil) Numeric spell ID if available
--  @return (nil)
function ns.HandleWeavingSpellcast(event, unit, castGUIDOrSpellName, spellId)
	-- Classic/BCC spellcast events prefer castGUID + spellID, but keep support for
	-- older spellName payloads by falling back when no spellID is present.
	if unit ~= "player" then
		return
	end

	local state = ns.weaveState
	if not state then
		return
	end

	local spellToken = spellId ~= nil and spellId or castGUIDOrSpellName
	local spellInfo = GetTrackedSpellInfo(spellToken)
	if not spellInfo and type(ns.GetUnitCastingSpellInfo) == "function" and
		(event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_DELAYED" or event == "UNIT_SPELLCAST_CHANNEL_START") then
		local liveSpellToken = ns.GetUnitCastingSpellInfo("player")
		if liveSpellToken then
			spellInfo = GetTrackedSpellInfo(liveSpellToken)
		end
	end

	if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_DELAYED" or event == "UNIT_SPELLCAST_CHANNEL_START" then
		if spellInfo then
			state.isCasting = true
			state.currentSpellId = spellInfo.spellId
			state.lastSpellId = spellInfo.spellId
			CaptureWeaveCastTiming(state, spellInfo)
		elseif event == "UNIT_SPELLCAST_DELAYED" and state.isCasting and state.currentSpellId then
			local currentSpellInfo = GetTrackedSpellInfo(state.currentSpellId)
			if currentSpellInfo then
				CaptureWeaveCastTiming(state, currentSpellInfo)
			end
		else
			state.isCasting = false
			state.currentSpellId = nil
			state.currentSpellName = nil
			state.spellCastTime = 0
			state.castStartTime = nil
			state.castStartSwingFraction = nil
			state.spellExpirationTime = nil
			state.baseSpellCastTime = 0
		end
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		if spellInfo then
			state.isCasting = false
			state.lastSpellId = spellInfo.spellId
		end
		state.currentSpellId = nil
		state.currentSpellName = nil
		state.spellCastTime = 0
		state.castStartTime = nil
		state.castStartSwingFraction = nil
		state.spellExpirationTime = nil
		state.baseSpellCastTime = 0
	elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
		state.isCasting = false
		if spellInfo then
			state.lastSpellId = spellInfo.spellId
		end
		state.currentSpellId = nil
		state.currentSpellName = nil
		state.spellCastTime = 0
		state.castStartTime = nil
		state.castStartSwingFraction = nil
		state.spellExpirationTime = nil
		state.baseSpellCastTime = 0
	end

	if spellInfo then
		state.currentSpellName = spellInfo.spellName
		state.spellCastTime = spellInfo.castTime
	elseif not state.isCasting then
		state.spellCastTime = 0
	end
end

function ns.ClearWeavePreview()
	if not ns.weaveState then
		return
	end

	ns.weaveState.isCasting = false
	ns.weaveState.currentSpellId = nil
	ns.weaveState.currentSpellName = nil
	ns.weaveState.spellCastTime = 0
	ns.weaveState.baseSpellCastTime = 0
	ns.weaveState.spellExpirationTime = nil
	ns.weaveState.castStartTime = nil
	ns.weaveState.castStartSwingFraction = nil
	for _, texture in ipairs({ ns.weaveSpark, ns.weaveTriangleTop, ns.weaveTriangleBottom }) do
		if texture then
			texture:Hide()
		end
	end
end