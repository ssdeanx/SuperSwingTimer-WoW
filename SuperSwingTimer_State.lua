local _, ns = ...

local GetTimePreciseSec = rawget(_G, "GetTimePreciseSec")
local GetTime = rawget(_G, "GetTime")
local UnitAttackSpeed = rawget(_G, "UnitAttackSpeed")
local UnitRangedDamage = rawget(_G, "UnitRangedDamage")
local GetSpellCooldown = rawget(_G, "GetSpellCooldown")
local GetSpellInfo = rawget(_G, "GetSpellInfo")
local UnitCastingInfo = rawget(_G, "UnitCastingInfo")
local CombatLogGetCurrentEventInfo = rawget(_G, "CombatLogGetCurrentEventInfo")
local C_Timer = rawget(_G, "C_Timer")
local UnitGUID = rawget(_G, "UnitGUID")
local GetNetStats = rawget(_G, "GetNetStats")
local GetMeleeHaste = rawget(_G, "GetMeleeHaste") or rawget(_G, "GetHaste")
local GetRangedHaste = rawget(_G, "GetRangedHaste") or rawget(_G, "GetHaste")
ns.cachedLatency = ns.cachedLatency or 0
local RANGED_START_DEDUPE_WINDOW = 0.25

-- ============================================================
-- Timer State
-- ============================================================
-- Three independent timers: mh (main hand), oh (off hand), ranged.
-- Each timer struct:
--   state              "idle" | "swinging"
--   lastSwing          GetCurrentTime() / combat-log timestamp at swing start
--   duration           weapon speed at swing start
--   speed              cached speed (for haste change detection)
--   nextSpeedCheckAt   GetCurrentTime() when next haste check should occur

ns.timers = {
	mh     = { state = "idle", lastSwing = 0, duration = 0, speed = 0, nextSpeedCheckAt = 0 },
	oh     = { state = "idle", lastSwing = 0, duration = 0, speed = 0, nextSpeedCheckAt = 0 },
	ranged = { state = "idle", lastSwing = 0, duration = 0, speed = 0, nextSpeedCheckAt = 0 },
}

ns.extraAttackPending = 0
ns.casting = false
ns.channeling = false
ns.channelingSpellId = nil
ns.currentCastSpellId = nil
ns.hunterCastActive = false
ns.hunterCastSpellId = nil
ns.hunterCastStartTime = nil
ns.hunterCastDuration = nil
ns.preventSwingReset = false
ns.pauseSwingTime = nil
ns.pendingMeleeQueueSpellId = nil

-- ============================================================
-- State helpers
-- ============================================================

local function GetCurrentTime()
	if GetTimePreciseSec then
		return GetTimePreciseSec() + (ns.cachedLatency or 0)
	end
	return GetTime() + (ns.cachedLatency or 0)
end

function ns.RefreshLatencyCache()
	local _, _, homeLatency, worldLatency = GetNetStats()
	local activeLatency = (worldLatency and worldLatency > 0) and worldLatency or homeLatency or 0
	ns.cachedLatency = math.max(activeLatency / 1000, 0)
	return ns.cachedLatency
end

function ns.GetAutoShotCooldown()
	ns.RefreshLatencyCache()
	if type(GetSpellCooldown) ~= "function" then
		return nil, nil
	end

	local startTime, duration, enabled = GetSpellCooldown(ns.AUTO_SHOT_ID)
	if (not duration or duration <= 0) and type(GetSpellInfo) == "function" then
		local autoShotName = GetSpellInfo(ns.AUTO_SHOT_ID)
		if autoShotName then
			startTime, duration, enabled = GetSpellCooldown(autoShotName)
		end
	end
	if enabled == 1 and startTime and duration and duration > 0 then
		return startTime + (ns.cachedLatency or 0), duration
	end

	return nil, nil
end

local function GetPlayerMeleeHastePercent()
	if type(GetMeleeHaste) == "function" then
		return math.max(GetMeleeHaste() or 0, 0)
	end

	return 0
end

local function GetPlayerRangedHastePercent()
	if type(GetRangedHaste) == "function" then
		return math.max(GetRangedHaste() or 0, 0)
	end

	return 0
end

local function EstimateSpeedFromHaste(lastSpeed, lastHastePercent, currentHastePercent)
	if not lastSpeed or lastSpeed <= 0 then
		return nil
	end

	if type(lastHastePercent) ~= "number" or type(currentHastePercent) ~= "number" then
		return nil
	end

	local lastMultiplier = 1 + (lastHastePercent / 100)
	local currentMultiplier = 1 + (currentHastePercent / 100)
	if lastMultiplier <= 0 or currentMultiplier <= 0 then
		return nil
	end

	return lastSpeed * (lastMultiplier / currentMultiplier)
end

function ns.HasActiveTimers()
	for _, timer in pairs(ns.timers) do
		if timer.state == "swinging" then
			return true
		end
	end
	if ns.channeling then
		return true
	end
	if ns.playerClass == "HUNTER" and ns.hunterCastActive and ns.hunterCastSpellId and ns.IsHunterCastSpell and ns.IsHunterCastSpell(ns.hunterCastSpellId) then
		return true
	end
	return false
end

local function ClearHunterCastState()
	ns.hunterCastActive = false
	ns.hunterCastSpellId = nil
	ns.hunterCastStartTime = nil
	ns.hunterCastDuration = nil
	if ns.hunterCastBar then
		ns.hunterCastBar:SetAlpha(0)
		ns.hunterCastBar:SetMinMaxValues(0, 1)
		ns.hunterCastBar:SetValue(0)
	end
end

ns.ClearHunterCastState = ClearHunterCastState

function ns.RefreshUpdateLoop()
	if ns.SetUpdateEnabled then
		ns.SetUpdateEnabled(ns.HasActiveTimers())
	end
end

function ns.SyncAllTimerSpeeds(force)
	local now = GetCurrentTime()
	if ns.timers.mh and ns.timers.mh.state == "swinging" then
		ns.SyncMeleeTimerSpeed("mh", now, force)
	end
	if ns.timers.oh and ns.timers.oh.state == "swinging" then
		ns.SyncMeleeTimerSpeed("oh", now, force)
	end
	if ns.timers.ranged and ns.timers.ranged.state == "swinging" then
		ns.SyncRangedTimerSpeed(now, force)
	end
end

function ns.SanityCheckTimers(force)
	ns.SyncAllTimerSpeeds(force == true)
end

function ns.StartSanityTicker()
	if ns.sanityTicker then return end
	if not C_Timer or not C_Timer.NewTicker then return end
	ns.sanityTicker = C_Timer.NewTicker(1.0, function()
		ns.RefreshLatencyCache()
		if ns.HasActiveTimers() then
			ns.SanityCheckTimers(true)
		end
	end)
end

function ns.StopSanityTicker()
	if ns.sanityTicker then
		ns.sanityTicker:Cancel()
		ns.sanityTicker = nil
	end
end

function ns.OnPlayerEnteringWorld()
	ns.isMoving = false
	ns.lastStoppedMovingAt = nil
	ns.druidFormChangeTime = nil
	ns.RefreshLatencyCache()
	ClearHunterCastState()
	if ns.ClearWeavePreview then
		ns.ClearWeavePreview()
	end
	ns.extraAttackPending = 0
	ns.StopSanityTicker()
	ns.ResetTimer("mh")
	ns.ResetTimer("oh")
	ns.ResetTimer("ranged")
	ns.HideBars()
	if ns.UpdateOHBar then
		ns.UpdateOHBar()
	end
	if ns.ApplyBarTexture then
		ns.ApplyBarTexture(ns.GetBarTexture())
	end
	if ns.ApplyRangedBarTexture then
		ns.ApplyRangedBarTexture(ns.GetRangedBarTexture(), ns.GetBarTextureLayer())
	end
	if ns.ApplySparkSettings then
		ns.ApplySparkSettings(ns.GetSparkTexture(), ns.GetSparkWidth(), ns.GetSparkHeight())
	end
	if ns.ApplyBarBackgroundAlpha then
		ns.ApplyBarBackgroundAlpha(ns.GetBarBackgroundAlpha())
	end
	if ns.ApplyMinimalMode then
		ns.ApplyMinimalMode(ns.IsMinimalMode())
	end
	if ns.ApplyBarColors then
		ns.ApplyBarColors()
	end
	ns.RefreshUpdateLoop()
end

local SPEED_CHECK_INTERVAL = 0.10

function ns.SyncMeleeTimerSpeed(slot, now, force)
	local t = ns.timers[slot]
	if not t or t.state ~= "swinging" then return end

	now = now or GetCurrentTime()
	if not force and now < (t.nextSpeedCheckAt or 0) then return end
	t.nextSpeedCheckAt = now + SPEED_CHECK_INTERVAL

	local mhSpeed, ohSpeed = UnitAttackSpeed("player")
	local currentSpeed = (slot == "oh") and ohSpeed or mhSpeed
	if currentSpeed and currentSpeed > 0 then
		ns.RescaleTimer(slot, currentSpeed)
	end
end

function ns.SyncRangedTimerSpeed(now, force)
	local t = ns.timers.ranged
	if not t or t.state ~= "swinging" then return end

	now = now or GetCurrentTime()
	if not force and now < (t.nextSpeedCheckAt or 0) then return end
	t.nextSpeedCheckAt = now + SPEED_CHECK_INTERVAL

	local currentRangedHaste = GetPlayerRangedHastePercent()
	local _, autoShotDuration = ns.GetAutoShotCooldown()
	if autoShotDuration and autoShotDuration > 0 then
		ns.RescaleTimer("ranged", autoShotDuration)
		t.hastePercent = currentRangedHaste
		return
	end

	local rangedSpeedValue = UnitRangedDamage("player")
	if rangedSpeedValue and rangedSpeedValue > 0 then
		ns.RescaleTimer("ranged", rangedSpeedValue)
		t.hastePercent = currentRangedHaste
		return
	end

	local estimatedSpeed = EstimateSpeedFromHaste(t.speed, t.hastePercent, currentRangedHaste)
	if estimatedSpeed and estimatedSpeed > 0 then
		ns.RescaleTimer("ranged", estimatedSpeed)
		t.hastePercent = currentRangedHaste
	end
end

-- Start a melee or ranged swing for the given slot ("mh", "oh", "ranged").
-- startTime: optional timestamp from the combat log
function ns.StartSwing(slot, _, startTime)
	local t = ns.timers[slot]
	if not t then return end

	local now = startTime or GetCurrentTime()
	local speed

	if slot == "ranged" then
		local rangedHastePercent = GetPlayerRangedHastePercent()
		local autoShotStart, autoShotDuration = ns.GetAutoShotCooldown()
		if autoShotDuration and autoShotDuration > 0 then
			speed = autoShotDuration
			t.lastSwing = (autoShotStart and autoShotStart > 0) and autoShotStart or now
			t.hastePercent = rangedHastePercent
		else
			local s = UnitRangedDamage("player")
			speed = (s and s > 0) and s or 2.0
			t.lastSwing = now
			t.hastePercent = rangedHastePercent
		end
	else
		local mhSpeed, ohSpeed = UnitAttackSpeed("player")
		if slot == "mh" then
			speed = (mhSpeed and mhSpeed > 0) and mhSpeed or 2.0
		else
			speed = (ohSpeed and ohSpeed > 0) and ohSpeed or 2.0
		end
		t.lastSwing = now
	end

	t.duration = speed
	t.speed    = speed
	t.state    = "swinging"
	t.nextSpeedCheckAt = now

	if slot == "ranged" then
		ns.SyncRangedTimerSpeed(now, true)
	else
		ns.SyncMeleeTimerSpeed(slot, now, true)
	end

	ns.RefreshUpdateLoop()
end

function ns.StartRangedSwing(startTime)
	local t = ns.timers.ranged
	if not t then
		return false
	end

	local now = startTime or GetCurrentTime()
	local dedupeWindow = math.max(RANGED_START_DEDUPE_WINDOW, (ns.cachedLatency or 0) + 0.05)
	if t.state == "swinging" and t.lastSwing and t.lastSwing > 0 then
		local elapsed = now - t.lastSwing
		if elapsed >= 0 and elapsed < dedupeWindow then
			return false
		end
	end

	ns.StartSwing("ranged", nil, now)
	if ns.UpdateCastZoneVisual then
		ns.UpdateCastZoneVisual()
	end
	return true
end

function ns.AdjustSwingTimesAfterPause(now)
	if not ns.pauseSwingTime then
		return
	end

	local offset = now - ns.pauseSwingTime
	ns.pauseSwingTime = nil

	if ns.timers.mh and ns.timers.mh.state == "swinging" then
		ns.timers.mh.lastSwing = ns.timers.mh.lastSwing + offset
	end
	if ns.timers.oh and ns.timers.oh.state == "swinging" then
		ns.timers.oh.lastSwing = ns.timers.oh.lastSwing + offset
	end
end

function ns.HandleSpellcastStart(unit, _, spellId)
	if unit ~= "player" then return end
	ns.RefreshLatencyCache()
	local now = GetCurrentTime()
	local castWindow = math.max(ns.CAST_WINDOW or 0.5, 0.01)
	local spellIdNumber = tonumber(spellId)
	local isHunterCastSpell = ns.playerClass == "HUNTER" and ns.IsHunterCastSpell and ns.IsHunterCastSpell(spellId)
	local isAutoShotSpell = isHunterCastSpell and ns.IsAutoShotSpell and ns.IsAutoShotSpell(spellId)
	ns.casting = true
	ns.currentCastSpellId = spellId
	if isHunterCastSpell and not isAutoShotSpell then
		ns.hunterCastActive = true
		ns.hunterCastSpellId = spellId
	end
	ns.hunterCastStartTime = nil
	ns.hunterCastDuration = nil
	if isHunterCastSpell and not isAutoShotSpell then
		ns.hunterCastDuration = castWindow
		if type(UnitCastingInfo) == "function" then
			local _, _, _, startTimeMs = UnitCastingInfo("player")
			if startTimeMs and startTimeMs > 0 then
				ns.hunterCastStartTime = (startTimeMs / 1000) + (ns.cachedLatency or 0)
			end
		end
		if not ns.hunterCastStartTime then
			ns.hunterCastStartTime = now
		end
	end
	ns.preventSwingReset = ns.preventSwingReset or (ns.NO_RESET_SWING_SPELLS and (ns.NO_RESET_SWING_SPELLS[spellId] or (spellIdNumber and ns.NO_RESET_SWING_SPELLS[spellIdNumber])))
	if ns.PAUSE_SWING_SPELLS and (ns.PAUSE_SWING_SPELLS[spellId] or (spellIdNumber and ns.PAUSE_SWING_SPELLS[spellIdNumber])) and not ns.pauseSwingTime then
		ns.pauseSwingTime = GetCurrentTime()
	end
	ns.RefreshUpdateLoop()
end

function ns.HandleSpellcastChannelStart(unit, _, spellId)
	if unit ~= "player" then return end
	ns.RefreshLatencyCache()
	local spellIdNumber = tonumber(spellId)
	ns.casting = true
	ns.channeling = true
	ns.channelingSpellId = spellId
	ns.currentCastSpellId = spellId
	if ns.playerClass == "HUNTER" and ns.IsHunterCastSpell and ns.IsHunterCastSpell(spellId) then
		ns.hunterCastActive = true
		ns.hunterCastSpellId = spellId
	end
	ns.preventSwingReset = ns.NO_RESET_SWING_SPELLS and (ns.NO_RESET_SWING_SPELLS[spellId] or (spellIdNumber and ns.NO_RESET_SWING_SPELLS[spellIdNumber]))
	ns.RefreshUpdateLoop()
end

function ns.HandleSpellcastStop(unit)
	if unit ~= "player" then return end
	ns.casting = false
	ns.channeling = false
	ns.channelingSpellId = nil
	ns.currentCastSpellId = nil
	if not (ns.playerClass == "HUNTER" and ns.hunterCastActive and ns.hunterCastSpellId and ns.IsHunterCastSpell and ns.IsHunterCastSpell(ns.hunterCastSpellId) and ns.hunterCastDuration and ns.hunterCastDuration > 0) then
		ClearHunterCastState()
	end
	ns.preventSwingReset = false
	ns.RefreshUpdateLoop()
end

function ns.HandleSpellcastChannelStop(unit)
	if unit ~= "player" then return end
	ns.casting = false
	ns.channeling = false
	ns.channelingSpellId = nil
	ns.currentCastSpellId = nil
	if not (ns.playerClass == "HUNTER" and ns.hunterCastActive and ns.hunterCastSpellId and ns.IsHunterCastSpell and ns.IsHunterCastSpell(ns.hunterCastSpellId) and ns.hunterCastDuration and ns.hunterCastDuration > 0) then
		ClearHunterCastState()
	end
	ns.preventSwingReset = false
	ns.RefreshUpdateLoop()
end

function ns.HandleSpellcastInterruptedOrFailed(unit, _, spellId)
	if unit ~= "player" then return end
	ns.RefreshLatencyCache()
	local now = GetCurrentTime()
	local spellIdNumber = tonumber(spellId)
	local isQueuedMeleeSpecial = ns.NMA_LOOKUP and (ns.NMA_LOOKUP[spellId] or (spellIdNumber and ns.NMA_LOOKUP[spellIdNumber]))
	if ns.PAUSE_SWING_SPELLS and (ns.PAUSE_SWING_SPELLS[spellId] or (spellIdNumber and ns.PAUSE_SWING_SPELLS[spellIdNumber])) and ns.pauseSwingTime then
		ns.AdjustSwingTimesAfterPause(now)
	end
	if ns.pendingMeleeQueueSpellId and (isQueuedMeleeSpecial or not spellId) then
		if ns.ClearWarriorQueueTint then
			ns.ClearWarriorQueueTint()
		else
			ns.pendingMeleeQueueSpellId = nil
		end
	elseif ns.pendingMeleeQueueSpellId == spellId or (spellIdNumber and ns.pendingMeleeQueueSpellId == spellIdNumber) then
		ns.pendingMeleeQueueSpellId = nil
	end
	ns.casting = false
	ns.channeling = false
	ns.channelingSpellId = nil
	ns.currentCastSpellId = nil
	if ns.playerClass == "HUNTER" and ns.hunterCastActive then
		ClearHunterCastState()
	end
	ns.preventSwingReset = false
	ns.RefreshUpdateLoop()
end

-- Apply parry haste to a melee timer when the player parries an incoming attack.
-- Formula: reduce remaining time by 40% of weapon speed, floor at 20%.
function ns.ApplyParryHaste(slot)
	local t = ns.timers[slot]
	if not t or t.state ~= "swinging" then return end

	local now = GetCurrentTime()
	local remaining = (t.lastSwing + t.duration) - now
	local floor = 0.2 * t.duration

	if remaining <= floor then
		return  -- already nearly ready; no change
	end

	local meleeHaste = GetPlayerMeleeHastePercent() / 100
	local adjustedReduction = math.max(0.2, 0.4 - (meleeHaste * 0.1))
	local reduction = adjustedReduction * t.duration
	local newRemaining = math.max(remaining - reduction, floor)
	-- Shift lastSwing so the bar reflects the new remaining time
	t.lastSwing = now + newRemaining - t.duration
	t.nextSpeedCheckAt = now
end

-- Reset a timer slot to idle.
function ns.ResetTimer(slot)
	local t = ns.timers[slot]
	if not t then return end
	t.state = "idle"
	t.lastSwing = 0
	t.duration = 0
	t.speed = 0
	t.hastePercent = nil
	t.nextSpeedCheckAt = 0

	ns.RefreshUpdateLoop()
	if slot == "ranged" then
		if ns.ClearHunterCastState then
			ns.ClearHunterCastState()
		end
		if ns.UpdateCastZoneVisual then
			ns.UpdateCastZoneVisual()
		end
	end
end

-- Rescale remaining time proportionally when weapon speed changes mid-swing.
-- Called by event-driven sync helpers and their throttled fallback.
function ns.RescaleTimer(slot, newSpeed)
	local t = ns.timers[slot]
	if not t or t.state ~= "swinging" or t.duration <= 0 then return end
	if math.abs(t.duration - newSpeed) < 0.01 then return end

	local now = GetCurrentTime()
	local remaining = (t.lastSwing + t.duration) - now
	if remaining < 0 then remaining = 0 end
	local ratio = newSpeed / t.duration
	local newRemaining = remaining * ratio

	t.duration  = newSpeed
	t.speed     = newSpeed
	t.lastSwing = now + newRemaining - newSpeed
end

-- ============================================================
-- CLEU dispatch
-- ============================================================

-- Returns the current player GUID. Cached at first call since it never changes.
local playerGUID
local function GetPlayerGUID()
	if not playerGUID then
		playerGUID = UnitGUID("player")
	end
	return playerGUID
end

-- Main CLEU handler. Called from the bootstrap OnEvent.
function ns.HandleCLEU()
	local _, subEvent, _, sourceGUID, _, _, _, targetGUID, _, _, _, cleuArg12, cleuArg13, _, cleuArg15, _, _, _, _, _, cleuArg21 = CombatLogGetCurrentEventInfo()
	ns.RefreshLatencyCache()

	local currentPlayerGUID = GetPlayerGUID()

	-- ---- Player is the source ----
	if sourceGUID == currentPlayerGUID then

		if subEvent == "SWING_DAMAGE" then
			local isOffHandAttack = cleuArg21
			local slot = isOffHandAttack and "oh" or "mh"
			if (ns.extraAttackPending or 0) > 0 then
				ns.extraAttackPending = ns.extraAttackPending - 1
			else
				ns.StartSwing(slot, nil, GetCurrentTime())
				if ns.OnMeleeSwing then ns.OnMeleeSwing(slot) end
			end

		elseif subEvent == "SWING_MISSED" then
			local isOffHandAttack = cleuArg13
			local slot = isOffHandAttack and "oh" or "mh"
			if (ns.extraAttackPending or 0) > 0 then
				ns.extraAttackPending = ns.extraAttackPending - 1
			else
				ns.StartSwing(slot, nil, GetCurrentTime())
				if ns.OnMeleeSwing then ns.OnMeleeSwing(slot) end
			end

		elseif subEvent == "SPELL_CAST_SUCCESS" then
			local spellId = cleuArg12
			if ns.IsAutoShotSpell and ns.IsAutoShotSpell(spellId) then
				-- Ranged: use the same latency-aware clock as melee, but allow
				-- spellcast fallback to recover if CLEU arrives late or out of order.
				if ns.StartRangedSwing(GetCurrentTime()) and ns.OnRangedSwing then
					ns.OnRangedSwing()
				end
			end

		elseif subEvent == "SPELL_EXTRA_ATTACKS" then
			local extraAttackAmount = cleuArg15
			ns.extraAttackPending = (ns.extraAttackPending or 0) + (extraAttackAmount or 1)

		elseif (subEvent == "SPELL_DAMAGE" or subEvent == "SPELL_MISSED") and sourceGUID == currentPlayerGUID then
			local spellId = cleuArg12
			local spellIdNumber = tonumber(spellId)
			if ns.NMA_LOOKUP and (ns.NMA_LOOKUP[spellId] or (spellIdNumber and ns.NMA_LOOKUP[spellIdNumber])) then
				ns.StartSwing("mh", nil, GetCurrentTime())
				if ns.OnMeleeSwing then ns.OnMeleeSwing("mh") end
			elseif ns.RESET_RANGED_SWING_SPELLS and ns.RESET_RANGED_SWING_SPELLS[spellId] then
				if ns.StartRangedSwing(GetCurrentTime()) and ns.OnRangedSwing then
					ns.OnRangedSwing()
				end
			end

		elseif subEvent == "SPELL_AURA_APPLIED" then
			-- Druid form change → reset MH timer
			local spellId = cleuArg12
			if ns.DRUID_FORM_IDS and ns.DRUID_FORM_IDS[spellId] then
				ns.ResetTimer("mh")
				ns.druidFormChangeTime = GetCurrentTime()
				if ns.OnDruidFormChange then ns.OnDruidFormChange(spellId) end
			end
		end

	-- ---- Player is the destination (incoming parry) ----
	elseif targetGUID == currentPlayerGUID then
		if subEvent == "SWING_MISSED" then
			local missType = cleuArg12
			if missType == "PARRY" then
				ns.ApplyParryHaste("mh")
			end
		end
	end
end

-- ============================================================
-- UNIT_SPELLCAST_SUCCEEDED handler
-- ============================================================
-- Slam detection still uses the pause/extend path, while queued melee specials
-- keep their tint until the combat-log hit restarts the MH swing.
function ns.HandleSpellcastSucceeded(unit, _, spellId)
	if unit ~= "player" then return end
	ns.RefreshLatencyCache()
	local now = GetCurrentTime()
	local spellIdNumber = tonumber(spellId)

	if ns.PAUSE_SWING_SPELLS and (ns.PAUSE_SWING_SPELLS[spellId] or (spellIdNumber and ns.PAUSE_SWING_SPELLS[spellIdNumber])) and ns.pauseSwingTime then
		ns.AdjustSwingTimesAfterPause(now)
	elseif ns.playerClass == "HUNTER" and ns.IsHunterCastSpell and ns.IsHunterCastSpell(spellId) then
		local castWindow = math.max(ns.CAST_WINDOW or 0.5, 0.01)
		if ns.hunterCastActive and ns.hunterCastSpellId and ns.IsHunterCastSpell(ns.hunterCastSpellId) then
			ns.hunterCastDuration = castWindow
			ns.hunterCastStartTime = ns.hunterCastStartTime or now
		elseif type(UnitCastingInfo) == "function" then
			local castSpellName, _, _, startTimeMs, _, _, _, castSpellId = UnitCastingInfo("player")
			if ns.IsHunterCastSpell(castSpellId) or ns.IsHunterCastSpell(castSpellName) then
				ns.hunterCastActive = true
				ns.hunterCastSpellId = castSpellId or castSpellName or spellId
				ns.hunterCastDuration = castWindow
				if startTimeMs and startTimeMs > 0 then
					ns.hunterCastStartTime = (startTimeMs / 1000) + (ns.cachedLatency or 0)
				else
					ns.hunterCastStartTime = now
				end
			end
		end
	elseif ns.NMA_LOOKUP[spellId] or (spellIdNumber and ns.NMA_LOOKUP[spellIdNumber]) then
		ns.pendingMeleeQueueSpellId = spellIdNumber or spellId
	elseif ns.RESET_SWING_SPELLS and (ns.RESET_SWING_SPELLS[spellId] or (spellIdNumber and ns.RESET_SWING_SPELLS[spellIdNumber])) then
		ns.StartSwing("mh", nil, now)
		ns.StartSwing("oh", nil, now)
		if ns.StartRangedSwing(now) and ns.OnRangedSwing then
			ns.OnRangedSwing()
		end
		if ns.OnMeleeSwing then ns.OnMeleeSwing("mh") end
	elseif ns.casting and not ns.preventSwingReset then
		ns.StartSwing("mh", nil, now)
		ns.StartSwing("oh", nil, now)
		if ns.StartRangedSwing(now) and ns.OnRangedSwing then
			ns.OnRangedSwing()
		end
	end

	ns.casting = false
	ns.channeling = false
	ns.channelingSpellId = nil
	ns.currentCastSpellId = nil
	ns.preventSwingReset = false
	ns.RefreshUpdateLoop()
end
