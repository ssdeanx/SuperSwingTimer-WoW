local addonName, ns = ...

local math_max = math.max
local GetTimePreciseSec = rawget(_G, "GetTimePreciseSec")
local GetTime = rawget(_G, "GetTime")
local GetNetStats = rawget(_G, "GetNetStats")
local GetSpellInfo = rawget(_G, "GetSpellInfo")
local UnitSpellHaste = rawget(_G, "UnitSpellHaste")
local UnitCastingInfo = rawget(_G, "UnitCastingInfo")
local GetClock = GetTimePreciseSec or GetTime

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

	return 0
end

local function ResolveSpellInfo(group)
	for _, spellId in ipairs(group.ids) do
		local spellName, _, _, castTime = GetSpellInfo(spellId)
		if spellName and castTime and castTime > 0 then
			return {
				spellId = spellId,
				spellName = spellName,
				castTime = castTime / 1000,
				abbrev = group.abbrev,
				label = group.label,
			}
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
	local color
	if not spellInfo then
		color = { r = 0.8, g = 0.8, b = 0.8, a = 1 }
	elseif spellInfo.abbrev == "LB" then
		color = { r = 0.45, g = 0.75, b = 1.00, a = 1 }
	elseif spellInfo.abbrev == "CL" then
		color = { r = 0.15, g = 0.45, b = 0.95, a = 1 }
	elseif spellInfo.abbrev == "HW" or spellInfo.abbrev == "LHW" or spellInfo.abbrev == "CH" then
		color = { r = 0.25, g = 0.95, b = 0.35, a = 1 }
	else
		color = { r = 0.70, g = 0.85, b = 1.00, a = 1 }
	end

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
	spellExpirationTime = nil,
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
	state.defaultSpellId = nil

	for _, group in ipairs(ns.WEAVE_SPELL_GROUPS or {}) do
		local info = ResolveSpellInfo(group)
		if info then
			state.trackedSpellCatalog[#state.trackedSpellCatalog + 1] = info
			state.trackedSpellLookup[info.spellId] = info
			if not state.defaultSpellId then
				state.defaultSpellId = info.spellId
			end
		end
	end

	state.spellCatalogDirty = false
end

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

local function GetTrackedSpellInfo(spellId)
	local state = ns.weaveState
	if not state or not spellId then
		return nil
	end

	return state.trackedSpellLookup[spellId]
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

local function BuildDisplayInfo(spellInfo)
	if not spellInfo then
		return nil
	end

	local state = ns.weaveState
	local nextSwingExpiration = GetNextSwingExpiration()
	if not nextSwingExpiration then
		return nil
	end

	local now = GetClock()
	local latency = state.cachedLatency or GetLatencySeconds()
	local spellHaste = state.spellHaste or GetSpellHastePercent()
	local hasteMultiplier = 1 + (math_max(spellHaste, 0) / 100)
	local effectiveCastTime = math_max(0, spellInfo.castTime / hasteMultiplier)
	local castRemaining = effectiveCastTime
	local isCasting = state.isCasting and state.currentSpellId == spellInfo.spellId

	if isCasting then
		local _, _, _, _, endTime = UnitCastingInfo("player")
		if endTime then
			castRemaining = math_max(0, (endTime / 1000) - now)
		end
	end

	local safeStartIn = nextSwingExpiration - now - latency - effectiveCastTime
	local clipAmount = math_max(0, (now + latency + castRemaining) - nextSwingExpiration)
	local safe = safeStartIn > 0 and clipAmount <= 0
	local text

	if isCasting then
		if clipAmount > 0 then
			text = string.format("%s clip %.1fs", spellInfo.abbrev, clipAmount)
		else
			text = string.format("%s safe", spellInfo.abbrev)
		end
	else
		if safe then
			text = string.format("%s start in %.1fs", spellInfo.abbrev, safeStartIn)
		else
			text = string.format("%s clip %.1fs", spellInfo.abbrev, -safeStartIn)
		end
	end

	local color = GetSpellFamilyColor(spellInfo, safe)

	return {
		spellId = spellInfo.spellId,
		spellName = spellInfo.spellName,
		spellAbbrev = spellInfo.abbrev,
		castTime = effectiveCastTime,
		castRemaining = castRemaining,
		latency = latency,
		nextSwingExpiration = nextSwingExpiration,
		safeStartIn = safeStartIn,
		clipAmount = clipAmount,
		safe = safe,
		isCasting = isCasting,
		text = text,
		color = color,
	}
end

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

function ns.HandleWeavingSpellcast(event, unit, _, spellId)
	if unit ~= "player" then
		return
	end

	local state = ns.weaveState
	if not state then
		return
	end

	local spellInfo = GetTrackedSpellInfo(spellId)
	if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_DELAYED" then
		if spellInfo then
			state.isCasting = true
			state.currentSpellId = spellId
			state.lastSpellId = spellId
		else
			state.isCasting = false
			state.currentSpellId = nil
		end
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		if spellInfo then
			state.isCasting = false
			state.currentSpellId = spellId
			state.lastSpellId = spellId
		end
	elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" then
		state.isCasting = false
		if spellInfo then
			state.lastSpellId = spellId
		end
		if state.currentSpellId == spellId then
			state.currentSpellId = nil
		end
	end

	if spellInfo then
		state.currentSpellName = spellInfo.spellName
		state.spellCastTime = spellInfo.castTime
		state.spellExpirationTime = nil
	end
end

function ns.ClearWeavePreview()
	if not ns.weaveState then
		return
	end

	ns.weaveState.isCasting = false
	ns.weaveState.currentSpellId = nil
	ns.weaveState.spellCastTime = 0
	ns.weaveState.spellExpirationTime = nil
	for _, texture in ipairs({ ns.weaveSpark, ns.weaveTriangleTop, ns.weaveTriangleBottom }) do
		if texture then
			texture:Hide()
		end
	end
end