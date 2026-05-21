local _, ns = ...
---@diagnostic disable: undefined-field

local GetTimePreciseSec = rawget(_G, "GetTimePreciseSec")
local GetTime = rawget(_G, "GetTime")
local UnitAttackSpeed = rawget(_G, "UnitAttackSpeed")
local UnitRangedDamage = rawget(_G, "UnitRangedDamage")
local GetSpellCooldown = rawget(_G, "GetSpellCooldown")
local CombatLogGetCurrentEventInfo = rawget(_G, "CombatLogGetCurrentEventInfo")
local C_Timer = rawget(_G, "C_Timer")
local UnitGUID = rawget(_G, "UnitGUID")
local UnitExists = rawget(_G, "UnitExists")
local UnitCanAttack = rawget(_G, "UnitCanAttack")
local UnitName = rawget(_G, "UnitName")
local GetNetStats = rawget(_G, "GetNetStats")
local GetRangedHaste = rawget(_G, "GetRangedHaste") or rawget(_G, "GetHaste")
local C_Spell = rawget(_G, "C_Spell")
local IsMounted = rawget(_G, "IsMounted")
local pcall = pcall

if GetTimePreciseSec then
	GetTimePreciseSec()
end

ns.cachedLatency = ns.cachedLatency or 0
local RANGED_START_DEDUPE_WINDOW = 0.25

-- ============================================================
-- Timer State
-- ============================================================
-- Four independent timers: mh (main hand), oh (off hand), ranged, enemy.
-- Each timer struct:
--   state              "idle" | "swinging"
--   lastSwing          GetCurrentTime() / combat-log timestamp at swing start
--   duration           weapon speed at swing start
--   speed              cached speed (for haste change detection)
--   nextSpeedCheckAt   GetCurrentTime() when next haste check should occur

-- Swing landing flash state per timer slot
ns.swingFlash = {
	mh = { active = false, remaining = 0, duration = 0.08 },
	oh = { active = false, remaining = 0, duration = 0.08 },
	ranged = { active = false, remaining = 0, duration = 0.08 },
	enemy = { active = false, remaining = 0, duration = 0.08 },
}

ns.timers = {
	mh     = { state = "idle", lastSwing = 0, duration = 0, speed = 0, nextSpeedCheckAt = 0 },
	oh     = { state = "idle", lastSwing = 0, duration = 0, speed = 0, nextSpeedCheckAt = 0 },
	ranged = { state = "idle", lastSwing = 0, duration = 0, speed = 0, nextSpeedCheckAt = 0, lastRangedStartTime = 0 },
	enemy  = { state = "idle", lastSwing = 0, duration = 0, speed = 0, nextSpeedCheckAt = 0 },
}

ns.extraAttackPending = 0
ns.casting = false
ns.channeling = false
ns.channelingSpellId = nil
ns.currentCastSpellId = nil
ns.currentCastStartTime = nil
ns.hunterCastActive = false
ns.hunterCastSpellId = nil
ns.hunterCastStartTime = nil
ns.hunterCastDuration = nil
ns.lastResolvedHunterCastToken = nil
ns.lastResolvedHunterCastAt = nil
ns.preventSwingReset = false
ns.pauseSwingTime = nil
ns.warriorQueuedMeleeSpell = nil
ns.druidQueuedMeleeSpell = nil
ns.hunterQueuedMeleeSpell = nil
ns.warriorOverpowerProcUntil = nil
ns.paladinLibramSwapStartTime = nil
ns.paladinLibramLastItemId = nil
ns.druidPowerShiftStartTime = nil
ns.druidLastEnergy = nil
ns.druidEnergyTickStartTime = nil
ns.enemyTargetGUID = nil
ns.enemyTargetName = nil

-- ============================================================
-- State helpers
-- ============================================================

-- Keep the base timer clock in the GetTime() domain so cooldown, cast, and
-- channel timestamps stay directly comparable, but prefer GetTimePreciseSec()
-- by aligning it once to that same domain.
-- Latency is applied only to predictive windows and guards so a refreshed
-- latency cache cannot shift every in-flight timer forward or backward.

local function GetCurrentTime()
	if ns.GetAlignedTime then
		return ns.GetAlignedTime()
	end
	if GetTimePreciseSec then
		return GetTimePreciseSec()
	end
	return GetTime()
end

function ns.RefreshLatencyCache()
	local _, _, homeLatency, worldLatency = GetNetStats()
	local activeLatency = (worldLatency and worldLatency > 0) and worldLatency or homeLatency or 0
	ns.cachedLatency = math.max(activeLatency / 1000, 0)
	return ns.cachedLatency
end

function ns.GetAutoShotCooldown()
	if type(GetSpellCooldown) ~= "function" then
		return nil, nil
	end

	local startTime, duration, enabled = GetSpellCooldown(ns.AUTO_SHOT_ID)
	if (not duration or duration <= 0) and ns.GetSpellInfo then
		local autoShotName = ns.GetSpellInfo(ns.AUTO_SHOT_ID)
		if autoShotName then
			startTime, duration, enabled = GetSpellCooldown(autoShotName)
		end
	end
	if enabled == 1 and startTime and duration and duration > 0 then
		return startTime, duration
	end

	return nil, nil
end

function ns.IsHunterAutoRepeatActive(fallbackState)
	if ns.playerClass ~= "HUNTER" then
		return false
	end

	if IsMounted and IsMounted() then
		ns.hunterAutoRepeatActive = false
		return false
	end

	local autoRepeatActive = nil
	if C_Spell and type(C_Spell.IsAutoRepeatSpell) == "function" then
		local ok, isRepeating = pcall(C_Spell.IsAutoRepeatSpell, ns.AUTO_SHOT_ID)
		if ok and isRepeating ~= nil then
			autoRepeatActive = isRepeating == true
		elseif type(ns.GetSpellInfo) == "function" then
			local autoShotName = ns.GetSpellInfo(ns.AUTO_SHOT_ID)
			if autoShotName then
				ok, isRepeating = pcall(C_Spell.IsAutoRepeatSpell, autoShotName)
				if ok and isRepeating ~= nil then
					autoRepeatActive = isRepeating == true
				end
			end
		end
	end

	if autoRepeatActive == nil then
		if fallbackState ~= nil then
			autoRepeatActive = fallbackState == true
		else
			autoRepeatActive = ns.hunterAutoRepeatActive == true
		end
	end

	ns.hunterAutoRepeatActive = autoRepeatActive == true
	return ns.hunterAutoRepeatActive
end

function ns.IsHunterRangedPinnedByMovement(now)
	if ns.playerClass ~= "HUNTER" or ns.isMoving ~= true then
		return false
	end

	local t = ns.timers and ns.timers.ranged
	if not t or t.state ~= "swinging" or not t.duration or t.duration <= 0 then
		return false
	end

	local castWindow = math.max((ns.CAST_WINDOW or 0) + (ns.cachedLatency or 0), 0)
	if castWindow <= 0 then
		return false
	end

	now = now or GetCurrentTime()
	return now >= ((t.lastSwing + t.duration) - castWindow)
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

local ClearHunterCastState

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
		local startTime = ns.hunterCastStartTime
		local duration = ns.hunterCastDuration
		if startTime and duration and duration > 0 and GetCurrentTime() < (startTime + duration) then
			return true
		end
		if ClearHunterCastState then
			ClearHunterCastState()
		end
	end
	return false
end

ClearHunterCastState = function(clearResolvedSpell)
	ns.hunterCastActive = false
	ns.hunterCastSpellId = nil
	ns.hunterCastStartTime = nil
	ns.hunterCastDuration = nil
	if clearResolvedSpell == true then
		ns.currentCastSpellId = nil
		ns.lastResolvedHunterCastToken = nil
		ns.lastResolvedHunterCastAt = nil
	end
	if ns.hunterCastBar then
		ns.hunterCastBar:SetAlpha(0)
		ns.hunterCastBar:SetMinMaxValues(0, 1)
		ns.hunterCastBar:SetValue(0)
		if ns.hunterCastBar.latencyOverlay then
			ns.hunterCastBar.latencyOverlay:SetWidth(0)
		end
		if ns.hunterCastBar.latencyMarker then
			ns.hunterCastBar.latencyMarker:Hide()
		end
	end
end
ns.spellcastSucceededHooks = ns.spellcastSucceededHooks or {}

function ns.RegisterSpellcastSucceededHook(callback)
	if type(callback) ~= "function" then
		return
	end

	ns.spellcastSucceededHooks[#ns.spellcastSucceededHooks + 1] = callback
end

local function RunSpellcastSucceededHooks(unit, castGUIDOrSpellName, spellId)
	local hooks = ns.spellcastSucceededHooks
	if not hooks then
		return
	end

	for i = 1, #hooks do
		local hook = hooks[i]
		if hook then
			hook(unit, castGUIDOrSpellName, spellId)
		end
	end
end

ns.ClearHunterCastState = ClearHunterCastState

local function ClearPendingMeleeQueueState()
	if ns.playerClass == "WARRIOR" and ns.ClearWarriorQueueTint then
		ns.ClearWarriorQueueTint()
	elseif ns.playerClass == "DRUID" and ns.ClearDruidQueueTint then
		ns.ClearDruidQueueTint()
	elseif ns.playerClass == "HUNTER" and ns.ClearHunterQueueTint then
		ns.ClearHunterQueueTint()
	else
		ns.warriorQueuedMeleeSpell = nil
		ns.druidQueuedMeleeSpell = nil
		ns.hunterQueuedMeleeSpell = nil
	end
end

local function LookupContains(lookup, spellValue)
	if not lookup or spellValue == nil then
		return false
	end

	if lookup[spellValue] then
		return true
	end

	local spellId = tonumber(spellValue)
	return spellId ~= nil and lookup[spellId] == true
end

local function IsWarriorQueuedMeleeSpell(spellName)
	return LookupContains(ns.WARRIOR_HEROIC_STRIKE_SPELLS, spellName)
		or LookupContains(ns.WARRIOR_CLEAVE_SPELLS, spellName)
end

local function IsDruidQueuedMeleeSpell(spellName)
	return LookupContains(ns.DRUID_MAUL_SPELLS, spellName)
end

local function IsHunterQueuedMeleeSpell(spellName)
	return LookupContains(ns.HUNTER_RAPTOR_STRIKE_SPELLS, spellName)
end

function ns.IsHunterMeleeActive()
	if ns.playerClass ~= "HUNTER" then
		return false
	end

	if ns.playerInCombat ~= true then
		return false
	end

	local hunterTimer = ns.timers and ns.timers.mh
	return hunterTimer and hunterTimer.state == "swinging" or false
end

function ns.IsHunterMeleeBarVisible()
	if ns.playerClass ~= "HUNTER" then
		return false
	end

	return ns.IsHunterMeleeActive() or ns.hunterQueuedMeleeSpell ~= nil
end

function ns.GetTimeUntilNextHunterRangedShot(now)
	if ns.playerClass ~= "HUNTER" then
		return nil
	end

	now = tonumber(now) or GetCurrentTime()

	local rangedTimer = ns.timers and ns.timers.ranged
	if rangedTimer and rangedTimer.state == "swinging" and rangedTimer.duration and rangedTimer.duration > 0 then
		return math.max((rangedTimer.lastSwing + rangedTimer.duration) - now, 0)
	end

	if ns.GetAutoShotCooldown then
		local cooldownStart, cooldownDuration = ns.GetAutoShotCooldown()
		if cooldownStart and cooldownDuration and cooldownDuration > 0 then
			return math.max((cooldownStart + cooldownDuration) - now, 0)
		end
	end

	return nil
end

local function IsQueuedMeleeHitForPlayerClass(spellValue)
	if ns.playerClass == "WARRIOR" then
		return IsWarriorQueuedMeleeSpell(spellValue)
	elseif ns.playerClass == "DRUID" then
		return IsDruidQueuedMeleeSpell(spellValue)
	elseif ns.playerClass == "HUNTER" then
		return IsHunterQueuedMeleeSpell(spellValue)
	end

	return false
end

ns.ClearPendingMeleeQueueState = ClearPendingMeleeQueueState

function ns.RefreshUpdateLoop()
	if ns.SetUpdateEnabled then
		ns.SetUpdateEnabled(ns.HasActiveTimers())
	end
end

local function HasAttackableTarget()
	if type(UnitExists) == "function" and not UnitExists("target") then
		return false
	end
	if type(UnitCanAttack) == "function" and not UnitCanAttack("player", "target") then
		return false
	end
	return type(UnitGUID) == "function" and UnitGUID("target") ~= nil
end

local function GetEnemySwingSpeed()
	if not ns.enemyTargetGUID or type(UnitGUID) ~= "function" then
		return nil
	end

	if UnitGUID("target") ~= ns.enemyTargetGUID then
		return nil
	end

	local enemySpeed = type(UnitAttackSpeed) == "function" and UnitAttackSpeed("target") or nil
	if enemySpeed and enemySpeed > 0 then
		return enemySpeed
	end

	return nil
end

function ns.RefreshEnemyTarget()
	local enemyTimer = ns.timers and ns.timers.enemy
	local hadTrackedTarget = ns.enemyTargetGUID ~= nil
	if not HasAttackableTarget() then
		ns.enemyTargetGUID = nil
		ns.enemyTargetName = nil
		if hadTrackedTarget then
			ns.ResetTimer("enemy")
		end
		if ns.enemyBar and ns.enemyBar.labelText then
			if ns.SetBarLabelText then
				ns.SetBarLabelText(ns.enemyBar, "Enemy", true)
			else
				ns.enemyBar.labelText:SetText("Enemy")
			end
		end
		return
	end

	local targetGUID = UnitGUID("target")
	local targetChanged = ns.enemyTargetGUID ~= targetGUID
	ns.enemyTargetGUID = targetGUID
	ns.enemyTargetName = type(UnitName) == "function" and UnitName("target") or "Enemy"

	if targetChanged then
		ns.ResetTimer("enemy")
	end

	local targetSpeed = GetEnemySwingSpeed()
	if enemyTimer and targetSpeed and targetSpeed > 0 then
		enemyTimer.speed = targetSpeed
		if enemyTimer.state ~= "swinging" then
			enemyTimer.duration = targetSpeed
		end
	end

	if ns.enemyBar and enemyTimer and enemyTimer.state ~= "swinging" and ns.enemyBar.labelText then
		if ns.SetBarLabelText then
			ns.SetBarLabelText(ns.enemyBar, ns.enemyTargetName or "Enemy", true)
		else
			ns.enemyBar.labelText:SetText(ns.enemyTargetName or "Enemy")
		end
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
	if ns.timers.enemy and ns.timers.enemy.state == "swinging" then
		ns.SyncMeleeTimerSpeed("enemy", now, force)
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
	ClearHunterCastState(true)
	if ns.ClearWeavePreview then
		ns.ClearWeavePreview()
	end
	ns.extraAttackPending = 0
	ClearPendingMeleeQueueState()
	ns.StopSanityTicker()
	ns.enemyTargetGUID = nil
	ns.enemyTargetName = nil
	ns.ResetTimer("mh")
	ns.ResetTimer("oh")
	ns.ResetTimer("ranged")
	ns.ResetTimer("enemy")
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

	local currentSpeed
	if slot == "enemy" then
		currentSpeed = GetEnemySwingSpeed()
	else
		local mhSpeed, ohSpeed = UnitAttackSpeed("player")
		currentSpeed = (slot == "oh") and ohSpeed or mhSpeed
	end
	if currentSpeed and currentSpeed > 0 then
		ns.RescaleTimer(slot, currentSpeed)
	end
end

function ns.SyncRangedTimerSpeed(now, force)
	local t = ns.timers.ranged
	if not t or t.state ~= "swinging" then return end

	now = now or GetCurrentTime()
	if ns.IsHunterRangedPinnedByMovement and ns.IsHunterRangedPinnedByMovement(now) then
		return
	end
	if not force and now < (t.nextSpeedCheckAt or 0) then return end
	t.nextSpeedCheckAt = now + SPEED_CHECK_INTERVAL

	local currentRangedHaste = GetPlayerRangedHastePercent()
	local autoShotStart, autoShotDuration = ns.GetAutoShotCooldown()
	if autoShotDuration and autoShotDuration > 0 then
		if autoShotStart and autoShotStart > 0 then
			local drift = math.abs((t.lastSwing or autoShotStart) - autoShotStart)
			t.duration = autoShotDuration
			t.speed = autoShotDuration
			if drift > 0.01 then
				t.lastSwing = autoShotStart
				t.hiddenCastWindowStart = nil
				t.hiddenCastWindowDuration = nil
			end
		else
			ns.RescaleTimer("ranged", autoShotDuration)
		end
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
			speed = (s and s > 0) and s or ((t.speed and t.speed > 0) and t.speed or 2.0)
			t.lastSwing = now
			t.hastePercent = rangedHastePercent
		end
		t.hiddenCastWindowStart = nil
		t.hiddenCastWindowDuration = nil
	elseif slot == "enemy" then
		local enemySpeed = GetEnemySwingSpeed()
		speed = (enemySpeed and enemySpeed > 0) and enemySpeed or ((t.speed and t.speed > 0) and t.speed or 2.0)
		t.lastSwing = now
	else
		local mhSpeed, ohSpeed = UnitAttackSpeed("player")
		if slot == "mh" then
			speed = (mhSpeed and mhSpeed > 0) and mhSpeed or ((t.speed and t.speed > 0) and t.speed or 2.0)
		else
			if not ohSpeed or ohSpeed <= 0 then
				ns.ResetTimer("oh")
				return
			end
			speed = ohSpeed
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
	if ns.ApplyVisibility then
		ns.ApplyVisibility()
	end
end

function ns.StartEnemySwing(startTime)
	if not ns.enemyTargetGUID then
		return false
	end

	ns.StartSwing("enemy", nil, startTime or GetCurrentTime())
	return ns.timers.enemy and ns.timers.enemy.state == "swinging"
end

function ns.StartRangedSwing(startTime)
	local t = ns.timers.ranged
	if not t then
		return false
	end

	local now = startTime or GetCurrentTime()
	local dedupeWindow = math.max(RANGED_START_DEDUPE_WINDOW, (ns.cachedLatency or 0) + 0.05)
	if t.state == "swinging" and t.lastRangedStartTime and t.lastRangedStartTime > 0 then
		local elapsed = now - t.lastRangedStartTime
		if elapsed >= 0 and elapsed < dedupeWindow then
			return false
		end
	end

	ns.StartSwing("ranged", nil, now)
	t.lastRangedStartTime = now
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

local function ResolveSpellcastEventSpell(primaryArg, spellId)
	if spellId ~= nil then
		return spellId
	end

	return primaryArg
end

local HUNTER_FEIGN_DEATH_ID = 5384
local HUNTER_FEIGN_DEATH_NAME = ns.GetSpellInfo and (ns.GetSpellInfo(HUNTER_FEIGN_DEATH_ID) or "Feign Death") or "Feign Death"

local function IsHunterFeignDeathSpell(spellValue)
	if spellValue == nil then
		return false
	end

	local spellId = tonumber(spellValue)
	return spellValue == HUNTER_FEIGN_DEATH_ID or spellValue == HUNTER_FEIGN_DEATH_NAME or (spellId and spellId == HUNTER_FEIGN_DEATH_ID)
end

local function GetHunterStoredCastDuration(spellToken, fallbackDuration)
	local resolvedDuration = tonumber(fallbackDuration)

	if type(ns.GetSpellInfo) == "function" then
		local _, _, _, castTimeMs = ns.GetSpellInfo(spellToken)
		if castTimeMs and castTimeMs > 0 then
			resolvedDuration = math.max((castTimeMs / 1000), 0.01)
		end
	end

	if not resolvedDuration or resolvedDuration <= 0 then
		resolvedDuration = math.max(ns.CAST_WINDOW or 0.5, 0.01)
	end

	return math.max(resolvedDuration, 0.01)
end

local function SeedHunterStoredCastState(spellToken, fallbackStartTime, fallbackDuration)
	if ns.playerClass ~= "HUNTER" or not ns.IsHunterCastSpell or not ns.IsHunterCastSpell(spellToken) then
		return false
	end

	if ns.IsAutoShotSpell and ns.IsAutoShotSpell(spellToken) then
		return false
	end

	local storedSpell = spellToken
	local startTime = tonumber(fallbackStartTime) or GetCurrentTime()
	local duration = GetHunterStoredCastDuration(spellToken, fallbackDuration)

	if type(ns.GetUnitCastingSpellInfo) == "function" then
		local liveSpell, _, startTimeMs, endTimeMs = ns.GetUnitCastingSpellInfo("player")
		if liveSpell and ns.IsHunterCastSpell(liveSpell) and not (ns.IsAutoShotSpell and ns.IsAutoShotSpell(liveSpell)) then
			storedSpell = liveSpell
			if startTimeMs and startTimeMs > 0 then
				startTime = (startTimeMs / 1000)
			end
			if endTimeMs and startTimeMs and endTimeMs > startTimeMs then
				duration = math.max((endTimeMs - startTimeMs) / 1000, 0.01)
			end
		end
	end

	ns.hunterCastActive = true
	ns.hunterCastSpellId = storedSpell
	ns.hunterCastStartTime = startTime
	ns.hunterCastDuration = duration
	return true
end

function ns.HandleSpellcastStart(unit, castGUIDOrSpellName, spellId)
	-- Classic/BCC payloads provide castGUID + spellID; older paths may still pass
	-- spellName/rank, so resolve whichever spell token is actually present.
	if unit ~= "player" then return end
	ns.RefreshLatencyCache()
	local now = GetCurrentTime()

	-- GCD tracking: record when any player cast starts (1.5s fixed GCD in Classic/TBC)
	ns.lastGcdTime = now
	ns.gcdDuration = 1.5
	ns.gcdActive = true
	local castWindow = math.max(ns.CAST_WINDOW or 0.5, 0.01)
	local spellToken = ResolveSpellcastEventSpell(castGUIDOrSpellName, spellId)
	local isHunterCastSpell = ns.playerClass == "HUNTER" and ns.IsHunterCastSpell and ns.IsHunterCastSpell(spellToken)
	if ns.playerClass == "HUNTER" and not isHunterCastSpell and type(ns.GetUnitCastingSpellInfo) == "function" then
		local liveSpell = ns.GetUnitCastingSpellInfo("player")
		if liveSpell and ns.IsHunterCastSpell and ns.IsHunterCastSpell(liveSpell) then
			spellToken = liveSpell
			isHunterCastSpell = true
		end
	end
	local spellIdNumber = tonumber(spellToken)
	local isAutoShotSpell = isHunterCastSpell and ns.IsAutoShotSpell and ns.IsAutoShotSpell(spellToken)
	ns.casting = true
	ns.currentCastSpellId = spellToken
	ns.currentCastStartTime = now
	ns.lastResolvedHunterCastToken = isHunterCastSpell and spellToken or nil
	ns.lastResolvedHunterCastAt = isHunterCastSpell and now or nil
	if isHunterCastSpell and not isAutoShotSpell then
		SeedHunterStoredCastState(spellToken, now, castWindow)
	else
		ns.hunterCastStartTime = nil
		ns.hunterCastDuration = nil
	end
	ns.preventSwingReset = ns.preventSwingReset or (ns.NO_RESET_SWING_SPELLS and (ns.NO_RESET_SWING_SPELLS[spellToken] or (spellIdNumber and ns.NO_RESET_SWING_SPELLS[spellIdNumber])))
	if ns.PAUSE_SWING_SPELLS and (ns.PAUSE_SWING_SPELLS[spellToken] or (spellIdNumber and ns.PAUSE_SWING_SPELLS[spellIdNumber])) and not ns.pauseSwingTime then
		ns.pauseSwingTime = GetCurrentTime()
	end
	ns.RefreshUpdateLoop()
end

-- Track GCD for the GCD ticker bar (Classic/TBC: 1.5s fixed).
-- Using 1.5s as the canonical GCD duration for all melee classes.
-- Reset by HandleSpellcastStop when the global cooldown window expires.
local GCD_DURATION = 1.5
function ns.GetGcdDuration()
	return GCD_DURATION
end

function ns.HandleSpellcastChannelStart(unit, castGUIDOrSpellName, spellId)
	if unit ~= "player" then return end
	ns.RefreshLatencyCache()
	local spellToken = ResolveSpellcastEventSpell(castGUIDOrSpellName, spellId)
	local spellIdNumber = tonumber(spellToken)
	ns.casting = true
	ns.channeling = true
	ns.channelingSpellId = spellToken
	ns.currentCastSpellId = spellToken
	if ns.playerClass == "HUNTER" and ns.IsHunterCastSpell and ns.IsHunterCastSpell(spellToken) then
		ns.hunterCastActive = true
		ns.hunterCastSpellId = spellToken
	end
	ns.preventSwingReset = ns.NO_RESET_SWING_SPELLS and (ns.NO_RESET_SWING_SPELLS[spellToken] or (spellIdNumber and ns.NO_RESET_SWING_SPELLS[spellIdNumber]))
	ns.RefreshUpdateLoop()
end

function ns.HandleSpellcastStop(unit)
	if unit ~= "player" then return end
	ns.casting = false
	ns.channeling = false
	ns.channelingSpellId = nil
	ns.currentCastSpellId = nil
	ns.currentCastStartTime = nil
	if not (ns.playerClass == "HUNTER" and ns.hunterCastActive and ns.hunterCastSpellId and ns.IsHunterCastSpell and ns.IsHunterCastSpell(ns.hunterCastSpellId) and ns.hunterCastDuration and ns.hunterCastDuration > 0) then
		ClearHunterCastState()
	end
	ns.preventSwingReset = false
	-- GCD ends when cast stops (OnUpdate handles visual tail decay)
	ns.gcdActive = false
	ns.RefreshUpdateLoop()
end

function ns.HandleSpellcastChannelStop(unit)
	if unit ~= "player" then return end
	ns.casting = false
	ns.channeling = false
	ns.channelingSpellId = nil
	ns.currentCastSpellId = nil
	ns.currentCastStartTime = nil
	if not (ns.playerClass == "HUNTER" and ns.hunterCastActive and ns.hunterCastSpellId and ns.IsHunterCastSpell and ns.IsHunterCastSpell(ns.hunterCastSpellId) and ns.hunterCastDuration and ns.hunterCastDuration > 0) then
		ClearHunterCastState()
	end
	ns.preventSwingReset = false
	ns.RefreshUpdateLoop()
end

function ns.HandleSpellcastDelayed(unit, castGUIDOrSpellName, spellId)
	ns.RefreshLatencyCache()
	if unit ~= "player" or ns.playerClass ~= "HUNTER" then
		return
	end

	local spellToken = ResolveSpellcastEventSpell(castGUIDOrSpellName, spellId)
	if not (ns.IsHunterActualCastSpell and ns.IsHunterActualCastSpell(spellToken)) then
		if type(ns.GetUnitCastingSpellInfo) == "function" then
			spellToken = ns.GetUnitCastingSpellInfo("player")
		end
	end

	if not (spellToken and ns.IsHunterActualCastSpell and ns.IsHunterActualCastSpell(spellToken)) then
		return
	end

	ns.currentCastSpellId = spellToken
	ns.lastResolvedHunterCastToken = spellToken
	ns.lastResolvedHunterCastAt = GetCurrentTime()
	SeedHunterStoredCastState(spellToken, GetCurrentTime(), ns.hunterCastDuration)
	ns.RefreshUpdateLoop()
end

function ns.HandleSpellcastInterruptedOrFailed(unit, castGUIDOrSpellName, spellId)
	if unit ~= "player" then return end
	ns.RefreshLatencyCache()
	local now = GetCurrentTime()
	local spellToken = ResolveSpellcastEventSpell(castGUIDOrSpellName, spellId)
	local spellIdNumber = tonumber(spellToken)
	if ns.PAUSE_SWING_SPELLS and (ns.PAUSE_SWING_SPELLS[spellToken] or (spellIdNumber and ns.PAUSE_SWING_SPELLS[spellIdNumber])) and ns.pauseSwingTime then
		ns.AdjustSwingTimesAfterPause(now)
	end
	if ns.playerClass == "WARRIOR" and ns.warriorQueuedMeleeSpell then
		if not spellToken or IsWarriorQueuedMeleeSpell(spellToken) then
			ClearPendingMeleeQueueState()
		end
	elseif ns.playerClass == "DRUID" and ns.druidQueuedMeleeSpell then
		if not spellToken or IsDruidQueuedMeleeSpell(spellToken) then
			ClearPendingMeleeQueueState()
		end
	elseif ns.playerClass == "HUNTER" and ns.hunterQueuedMeleeSpell then
		if not spellToken or IsHunterQueuedMeleeSpell(spellToken) then
			ClearPendingMeleeQueueState()
		end
	end
	ns.casting = false
	ns.channeling = false
	ns.channelingSpellId = nil
	ns.currentCastSpellId = nil
	ns.currentCastStartTime = nil
	ns.lastResolvedHunterCastToken = nil
	ns.lastResolvedHunterCastAt = nil
	if ns.playerClass == "HUNTER" and ns.hunterCastActive then
		ClearHunterCastState()
	end
	ns.preventSwingReset = false
	ns.RefreshUpdateLoop()
end

-- Apply parry haste to a melee timer when the player parries an incoming attack.
-- Classic rule: reduce remaining time by 40% of the current swing duration,
-- but never below 20% remaining.
function ns.ApplyParryHaste(slot, eventTime)
	local t = ns.timers[slot]
	if not t or t.state ~= "swinging" then return end

	local now = eventTime or GetCurrentTime()
	local remaining = (t.lastSwing + t.duration) - now
	local floor = 0.2 * t.duration

	if remaining <= floor then
		return  -- already nearly ready; no change
	end

	local reduction = 0.4 * t.duration
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
	t.hiddenCastWindowStart = nil
	t.hiddenCastWindowDuration = nil
	t.lastRangedStartTime = 0

	ns.RefreshUpdateLoop()
	if slot == "ranged" then
		if ns.ClearHunterCastState then
			ns.ClearHunterCastState(true)
		end
		if ns.UpdateCastZoneVisual then
			ns.UpdateCastZoneVisual()
		end
	end
	if ns.ApplyVisibility then
		ns.ApplyVisibility()
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
	local eventTime = GetCurrentTime()

	local currentPlayerGUID = GetPlayerGUID()
	local currentEnemyGUID = ns.enemyTargetGUID

	if currentEnemyGUID and sourceGUID == currentEnemyGUID then
		if subEvent == "SWING_DAMAGE" then
			local isOffHandAttack = cleuArg21
			if not isOffHandAttack then
				ns.StartEnemySwing(eventTime)
			end
		elseif subEvent == "SWING_MISSED" then
			local isOffHandAttack = cleuArg13
			if not isOffHandAttack then
				ns.StartEnemySwing(eventTime)
			end
		end
	end

	-- ---- Player is the source ----
	if sourceGUID == currentPlayerGUID then

		if subEvent == "SWING_DAMAGE" then
			local isOffHandAttack = cleuArg21
			local slot = isOffHandAttack and "oh" or "mh"
			if (ns.extraAttackPending or 0) > 0 then
				ns.extraAttackPending = ns.extraAttackPending - 1
			else
				ns.StartSwing(slot, nil, eventTime)
				if ns.OnMeleeSwing then ns.OnMeleeSwing(slot) end
			end

		elseif subEvent == "SWING_MISSED" then
			local isOffHandAttack = cleuArg13
			local slot = isOffHandAttack and "oh" or "mh"
			if (ns.extraAttackPending or 0) > 0 then
				ns.extraAttackPending = ns.extraAttackPending - 1
			else
				ns.StartSwing(slot, nil, eventTime)
				if ns.OnMeleeSwing then ns.OnMeleeSwing(slot) end
			end

		elseif subEvent == "SPELL_CAST_SUCCESS" then
			local spellId = cleuArg12
			if ns.IsAutoShotSpell and ns.IsAutoShotSpell(spellId) then
				-- Ranged: use the same latency-aware clock as melee, but allow
				-- spellcast fallback to recover if CLEU arrives late or out of order.
				if ns.StartRangedSwing(eventTime) and ns.OnRangedSwing then
					ns.OnRangedSwing()
				end
			end

		elseif subEvent == "SPELL_EXTRA_ATTACKS" then
			local extraAttackAmount = cleuArg15
			ns.extraAttackPending = (ns.extraAttackPending or 0) + (extraAttackAmount or 1)

		elseif (subEvent == "SPELL_DAMAGE" or subEvent == "SPELL_MISSED") and sourceGUID == currentPlayerGUID then
			local spellId = cleuArg12
			if IsQueuedMeleeHitForPlayerClass(spellId) then
				ns.StartSwing("mh", nil, eventTime)
				if ns.OnMeleeSwing then ns.OnMeleeSwing("mh") end
			elseif ns.RESET_RANGED_SWING_SPELLS and ns.RESET_RANGED_SWING_SPELLS[spellId] then
				if ns.StartRangedSwing(eventTime) and ns.OnRangedSwing then
					ns.OnRangedSwing()
				end
			end

		elseif subEvent == "SPELL_AURA_APPLIED" then
			-- Druid form change → reset MH timer
			local spellId = cleuArg12
			if ns.DRUID_FORM_IDS and ns.DRUID_FORM_IDS[spellId] then
				ns.ResetTimer("mh")
				ns.druidFormChangeTime = eventTime
				if ns.OnDruidFormChange then ns.OnDruidFormChange(spellId) end
			end
		end

	-- ---- Player is the destination (incoming parry) ----
	elseif targetGUID == currentPlayerGUID then
		if subEvent == "SWING_MISSED" then
			local missType = cleuArg12
			if missType == "PARRY" then
				ns.ApplyParryHaste("mh", eventTime)
			end
		end
	end

	if currentEnemyGUID and targetGUID == currentEnemyGUID then
		if subEvent == "UNIT_DIED" or subEvent == "UNIT_DESTROYED" then
			ns.enemyTargetGUID = nil
			ns.enemyTargetName = nil
			ns.ResetTimer("enemy")
		end
	end
end

-- ============================================================
-- UNIT_SPELLCAST_SUCCEEDED handler
-- ============================================================
-- Slam detection still uses the pause/extend path, while queued melee specials
-- keep their tint until the combat-log hit restarts the MH swing.
function ns.HandleSpellcastSucceeded(unit, castGUIDOrSpellName, spellId)
	if unit ~= "player" then return end
	ns.RefreshLatencyCache()
	local now = GetCurrentTime()
	local spellToken = ResolveSpellcastEventSpell(castGUIDOrSpellName, spellId)
	if ns.playerClass == "HUNTER" and not (ns.IsHunterCastSpell and ns.IsHunterCastSpell(spellToken)) then
		local liveSpell = ns.currentCastSpellId
		if not (liveSpell and ns.IsHunterCastSpell and ns.IsHunterCastSpell(liveSpell)) then
			local resolvedAt = ns.lastResolvedHunterCastAt
			local maxResolvedAge = math.max(ns.hunterCastDuration or 0, 2.5)
			if ns.lastResolvedHunterCastToken and resolvedAt and (now - resolvedAt) <= (maxResolvedAge + 0.25) then
				liveSpell = ns.lastResolvedHunterCastToken
			else
				ns.lastResolvedHunterCastToken = nil
				ns.lastResolvedHunterCastAt = nil
			end
		end
		if not (liveSpell and ns.IsHunterCastSpell and ns.IsHunterCastSpell(liveSpell)) and type(ns.GetUnitCastingSpellInfo) == "function" then
			liveSpell = ns.GetUnitCastingSpellInfo("player")
		end
		if liveSpell and ns.IsHunterCastSpell and ns.IsHunterCastSpell(liveSpell) then
			spellToken = liveSpell
		end
	end
	local spellIdNumber = tonumber(spellToken)

	if ns.PAUSE_SWING_SPELLS and (ns.PAUSE_SWING_SPELLS[spellToken] or (spellIdNumber and ns.PAUSE_SWING_SPELLS[spellIdNumber])) and ns.pauseSwingTime then
		ns.AdjustSwingTimesAfterPause(now)
	elseif ns.playerClass == "HUNTER" and ns.IsHunterCastSpell and ns.IsHunterCastSpell(spellToken) then
		local isAutoShotSpell = ns.IsAutoShotSpell and ns.IsAutoShotSpell(spellToken)
		if not isAutoShotSpell then
			SeedHunterStoredCastState(spellToken, ns.hunterCastStartTime or now, ns.hunterCastDuration)
		end
	elseif ns.RESET_SWING_SPELLS and (ns.RESET_SWING_SPELLS[spellToken] or (spellIdNumber and ns.RESET_SWING_SPELLS[spellIdNumber])) then
		ns.StartSwing("mh", nil, now)
		ns.StartSwing("oh", nil, now)
		if ns.StartRangedSwing(now) and ns.OnRangedSwing then
			ns.OnRangedSwing()
		end
		if ns.OnMeleeSwing then ns.OnMeleeSwing("mh") end
	elseif ns.playerClass == "HUNTER" and ns.HUNTER_READINESS_ID and (spellToken == ns.HUNTER_READINESS_ID or spellIdNumber == ns.HUNTER_READINESS_ID or spellToken == ns.HUNTER_READINESS_NAME) then
		if ns.ForceHunterRapidFireRefresh then
			ns.ForceHunterRapidFireRefresh()
		end
	elseif ns.playerClass == "ROGUE" and ns.ROGUE_ADRENALINE_RUSH_ID and (spellToken == ns.ROGUE_ADRENALINE_RUSH_ID or spellIdNumber == ns.ROGUE_ADRENALINE_RUSH_ID or spellToken == ns.ROGUE_ADRENALINE_RUSH_NAME) then
		if ns.ForceRogueAdrenalineRushRefresh then
			ns.ForceRogueAdrenalineRushRefresh()
		end
	elseif ns.playerClass == "HUNTER" and IsHunterFeignDeathSpell(spellToken) then
		ns.hunterAutoRepeatActive = false
		ns.ResetTimer("ranged")
	elseif ns.casting and not ns.preventSwingReset then
		ns.StartSwing("mh", nil, now)
		ns.StartSwing("oh", nil, now)
		local shouldResetRanged = ns.playerClass ~= "HUNTER"
		if not shouldResetRanged and ns.IsHunterCastSpell and ns.IsHunterCastSpell(spellToken) then
			shouldResetRanged = true
		end
		if shouldResetRanged and ns.StartRangedSwing(now) and ns.OnRangedSwing then
			ns.OnRangedSwing()
		end
	end

	ns.casting = false
	ns.channeling = false
	ns.channelingSpellId = nil
	ns.currentCastSpellId = nil
	ns.lastResolvedHunterCastToken = nil
	ns.lastResolvedHunterCastAt = nil
	ns.preventSwingReset = false
	RunSpellcastSucceededHooks(unit, castGUIDOrSpellName, spellId)
	ns.RefreshUpdateLoop()
end
