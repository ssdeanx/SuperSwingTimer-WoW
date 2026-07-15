local _, ns = ...
---@diagnostic disable: undefined-field

local GetTimePreciseSec = rawget(_G, "GetTimePreciseSec")
local UnitAttackSpeed = rawget(_G, "UnitAttackSpeed")
local UnitRangedDamage = rawget(_G, "UnitRangedDamage")
local GetSpellCooldown = rawget(_G, "GetSpellCooldown")
local C_Spell = rawget(_G, "C_Spell")
local CombatLogGetCurrentEventInfo = rawget(_G, "CombatLogGetCurrentEventInfo")
local C_Timer = rawget(_G, "C_Timer")
local UnitGUID = rawget(_G, "UnitGUID")
local UnitExists = rawget(_G, "UnitExists")
local UnitCanAttack = rawget(_G, "UnitCanAttack")
local UnitName = rawget(_G, "UnitName")
local GetNetStats = rawget(_G, "GetNetStats")
local GetRangedHaste = rawget(_G, "GetRangedHaste") -- GetHaste() is melee haste, not a valid fallback
local IsMounted = rawget(_G, "IsMounted")
local pcall = pcall

if GetTimePreciseSec then
    GetTimePreciseSec()
end

ns.cachedLatency = ns.cachedLatency or 0
local RANGED_START_DEDUPE_WINDOW = 0.25
local WARRIOR_OVERPOWER_PROC_WINDOW = 5.0

-- ============================================================
-- Timer State
-- ============================================================
-- Four independent timers: mh (main hand), oh (off hand), ranged, enemy.
-- Each timer struct:
--   state              "idle" | "swinging"
--   lastSwing          ns.GetAlignedTime() / combat-log timestamp at swing start
--   duration           weapon speed at swing start
--   speed              cached speed (for haste change detection)
--   nextSpeedCheckAt   ns.GetAlignedTime() when next haste check should occur

ns.timers = {
    mh = { state = "idle", lastSwing = 0.0, duration = 0.0, speed = 0.0, nextSpeedCheckAt = 0.0 },
    oh = { state = "idle", lastSwing = 0.0, duration = 0.0, speed = 0.0, nextSpeedCheckAt = 0.0 },
    ranged = {
        state = "idle",
        lastSwing = 0.0,
        duration = 0.0,
        speed = 0.0,
        nextSpeedCheckAt = 0.0,
        lastRangedStartTime = 0.0
    },
    enemy = { state = "idle", lastSwing = 0.0, duration = 0.0, speed = 0.0, nextSpeedCheckAt = 0.0 }
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
ns.lastGcdTime = nil
ns.gcdDuration = 1.5
ns.gcdActive = false
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

--- Refresh the cached network latency from GetNetStats().
--  Called every 0.05s from UpdateFrameOnUpdate. Stores the worst of
--  homeLatency / worldLatency in ns.cachedLatency for use by weave
--  safe-window and clip calculations.
--  @return (nil) Side-effect: updates ns.cachedLatency
function ns.RefreshLatencyCache()
    local _, _, homeLatency, worldLatency = GetNetStats()
    local activeLatency = (worldLatency and worldLatency > 0) and worldLatency or homeLatency or 0
    ns.cachedLatency = math.max(activeLatency / 1000, 0)
    return ns.cachedLatency
end

--- Get the cooldown start and duration for Auto Shot (spell 75).
--  Prefers C_Spell.GetSpellCooldown() with legacy GetSpellCooldown()
--  fallback. Also tries name-based lookup if ID fails.
--  @return (number|nil) cooldownStart, cooldownDuration, or nil/nil if not cooling
function ns.GetAutoShotCooldown()
    local startTime
    local duration
    local enabled

    if C_Spell and type(C_Spell.GetSpellCooldown) == "function" then
        local ok, cooldownInfo = pcall(C_Spell.GetSpellCooldown, ns.AUTO_SHOT_ID)
        if ok and type(cooldownInfo) == "table" then
            startTime = tonumber(cooldownInfo.startTime or cooldownInfo.start_time)
            duration = tonumber(cooldownInfo.duration)
            enabled = cooldownInfo.isEnabled
            if enabled == nil then
                enabled = cooldownInfo.enabled
            end
        end
    end

    if (not duration or duration <= 0) and type(GetSpellCooldown) == "function" then
        startTime, duration, enabled = GetSpellCooldown(ns.AUTO_SHOT_ID)
        if (not duration or duration <= 0) and ns.GetSpellInfo then
            local autoShotName = ns.GetSpellInfo(ns.AUTO_SHOT_ID)
            if autoShotName then
                startTime, duration, enabled = GetSpellCooldown(autoShotName)
            end
        end
    end

    local isEnabled = enabled == nil or enabled == 1 or enabled == true
    if isEnabled and startTime and duration and duration > 0 then
        return startTime, duration
    end

    return nil, nil
end

--- Check whether the Hunter's auto-repeat (Auto Shot) is currently active.
--  Uses C_Spell.IsAutoRepeatSpell() with legacy fallback. Mounted
--  hunters always return false. The fallbackState parameter allows
--  callers to provide a cached value when the API is unavailable.
--  @param fallbackState (boolean|nil) Optional cached auto-repeat state
--  @return (boolean) true if auto-repeat is active
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

    now = now or ns.GetAlignedTime()
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

--- Returns true if any swing timer, cast, or channel is currently active.
--  Used to decide whether the OnUpdate loop should keep running.
--  Also keeps the update loop alive for Warrior combat visuals (rage bar,
--  shield block) and Druid Cat energy tick even when no timer is swinging.
--  @return (boolean) true if any timer, cast, or channel is active
function ns.HasActiveTimers()
    for _, timer in pairs(ns.timers) do
        if timer.state == "swinging" then
            return true
        end
    end

    -- Normal spellcasting must also keep the update loop alive so cast-driven
    -- visuals (especially Shaman weave assist) continue to animate even when no
    -- melee/ranged swing timer is currently active.
    if ns.casting then
        return true
    end

    -- Warrior combat visuals (rage bar + Shield Block bar) need the update loop
    -- even when no swing timer is active yet; otherwise the bars can fail to
    -- refresh during combat until another timer starts.
    if ns.playerClass == "WARRIOR" and ns.playerInCombat == true then
        local db = SuperSwingTimerDB or ns.DB_DEFAULTS
        if db and (db.showWarriorRageBar ~= false or db.showWarriorShieldBlockBar ~= false) then
            return true
        end
    end

    if ns.playerClass == "DRUID" and ns.playerInCombat == true and ns.IsDruidCatFormActive and ns.IsDruidCatFormActive() then
        local db = SuperSwingTimerDB or ns.DB_DEFAULTS
        if db and db.showDruidEnergyTickBar ~= false then
            return true
        end
    end

    if ns.channeling then
        return true
    end

    -- Active GCD: keep the update loop running so the GCD ticker animates
    -- even outside combat (it has no swing/cast timer to keep the loop alive).
    if ns.gcdActive then
        return true
    end

    -- Buff/CD icons: keep the update loop alive when any class has buff icons
    -- enabled, so tracked auras render and count down outside combat.
    local db = SuperSwingTimerDB or ns.DB_DEFAULTS
    if db and ns.playerClass then
        if (ns.playerClass == "WARRIOR" and db.showWarriorBuffIcons ~= false)
        or (ns.playerClass == "PALADIN" and db.showPaladinBuffIcons ~= false)
        or (ns.playerClass == "SHAMAN" and db.showShamanBuffIcons ~= false)
        or (ns.playerClass == "DRUID" and db.showDruidBuffIcons ~= false)
        or (ns.playerClass == "HUNTER" and db.showHunterBuffIcons ~= false)
        or (ns.playerClass == "ROGUE" and db.showRogueBuffIcons ~= false) then
            return true
        end
    end

    if ns.playerClass == "HUNTER" and ns.hunterCastActive and ns.hunterCastSpellId and ns.IsHunterCastSpell
        and ns.IsHunterCastSpell(ns.hunterCastSpellId) then
        local startTime = ns.hunterCastStartTime
        local duration = ns.hunterCastDuration
        if startTime and duration and duration > 0 and ns.GetAlignedTime() < (startTime + duration) then
            return true
        end
        if ClearHunterCastState then
            ClearHunterCastState()
        end
    end
    return false
end

ClearHunterCastState = function (clearResolvedSpell)
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

--- Register a callback to fire when a spellcast succeeds.
--  This is used by class modules (Warrior, Druid, Hunter) to apply
--  next-melee queue tints after a queued spell lands.
--  @param callback (function) The function(unit, castGUIDOrSpellName, spellId) to call
--  @return (nil)
--  @usage ns.RegisterSpellcastSucceededHook(function(u, token, id) ... end)
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
    end

    -- Always hard-clear queue state so stale values cannot survive callback drift.
    ns.warriorQueuedMeleeSpell = nil
    ns.druidQueuedMeleeSpell = nil
    ns.hunterQueuedMeleeSpell = nil
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

    now = tonumber(now) or ns.GetAlignedTime()

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
    local now = ns.GetAlignedTime()
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
    ns.sanityTicker = C_Timer.NewTicker(1.0, function ()
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

function ns.OnPlayerEnteringWorld(isInitialLogin, isReloadingUi)
    ns.isMoving = false
    ns.lastStoppedMovingAt = nil
    ns.druidFormChangeTime = nil
    ns.casting = false
    ns.channeling = false
    ns.channelingSpellId = nil
    ns.currentCastSpellId = nil
    ns.currentCastStartTime = nil
    ns.lastGcdTime = nil
    ns.gcdDuration = 1.5
    ns.gcdActive = false
    ns.preventSwingReset = false
    ns.pauseSwingTime = nil
    ns.warriorOverpowerProcUntil = nil
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

--- Throttled sync of melee swing speed to the player's current
--  weapon speed. Used to detect and apply haste changes mid-swing.
--  @param slot (string) "mh", "oh", or "enemy"
--  @param now (number|nil) Current timestamp; defaults to GetAlignedTime()
--  @param force (boolean|nil) If true, skip the throttle check
--  @return (nil)
function ns.SyncMeleeTimerSpeed(slot, now, force)
    local t = ns.timers[slot]
    if not t or t.state ~= "swinging" then return end

    now = now or ns.GetAlignedTime()
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

    now = now or ns.GetAlignedTime()
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
            -- Always invalidate hidden cast window cache on speed change;
            -- stale window bounds from old duration cause the hunter bar to miss its window
            t.hiddenCastWindowStart = nil
            t.hiddenCastWindowDuration = nil
            if drift > 0.01 then
                t.lastSwing = autoShotStart
            end
        else
            ns.RescaleTimer("ranged", autoShotDuration)
        end
        t.hastePercent = currentRangedHaste
        return
    end

    -- On TBC Classic 2.5.5 (Legion-based client) UnitRangedDamage may return
    -- min damage (not weapon speed). Prefer the cached t.speed which was last
    -- set from GetSpellCooldown(75), and fall back to UnitRangedDamage only
    -- when no cached speed exists.
    local rangedSpeedValue = (t.speed and t.speed > 0) and t.speed or UnitRangedDamage("player")
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

--- Start or restart a swing timer for the given weapon slot.
--  Called from CLEU SWING_DAMAGE / SWING_MISSED handlers and from
--  spellcast-succeeded hooks for queue-at-end abilities. Resets the
--  timer duration from the current weapon speed and begins counting
--  down. If startTime is provided (combat-log timestamp), uses it as
--  the swing base; otherwise falls back to GetAlignedTime().
--  @param slot (string) "mh", "oh", or "ranged"
--  @param _ (nil) Unused legacy parameter
--  @param startTime (number|nil) Combat-log timestamp for the swing start
--  @return (nil) Side-effect: updates ns.timers[slot]
--  @see ns.ResetTimer
--- Start or restart a melee/ranged/enemy swing timer for the given slot.
--  Resolves weapon speed from UnitAttackSpeed() (melee) or
--  GetAutoShotCooldown() / UnitRangedDamage() (ranged), sets the
--  swing duration, and transitions the timer to "swinging" state.
--  @param slot (string) One of "mh", "oh", "ranged", "enemy"
--  @param _ (nil) Unused parameter (legacy)
--  @param startTime (number|nil) Optional timestamp override; defaults to GetAlignedTime()
--  @return (nil)
--  @see ns.ResetTimer, ns.RescaleTimer
function ns.StartSwing(slot, _, startTime)
    local t = ns.timers[slot]
    if not t then return end

    local now = startTime or ns.GetAlignedTime()
    local speed

    if slot == "ranged" then
        local rangedHastePercent = GetPlayerRangedHastePercent()
        local autoShotStart, autoShotDuration = ns.GetAutoShotCooldown()
        if autoShotDuration and autoShotDuration > 0 then
            speed = autoShotDuration
            t.lastSwing = (autoShotStart and autoShotStart > 0) and autoShotStart or now
            t.hastePercent = rangedHastePercent
        else
            -- Prefer cached speed; UnitRangedDamage may return min damage on TBC Classic 2.5.5
            local s = (t.speed and t.speed > 0) and t.speed or UnitRangedDamage("player")
            speed = (s and s > 0) and s or 2.0
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
    t.speed = speed
    t.state = "swinging"
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

    ns.StartSwing("enemy", nil, startTime or ns.GetAlignedTime())
    return ns.timers.enemy and ns.timers.enemy.state == "swinging"
end

function ns.StartRangedSwing(startTime)
    local t = ns.timers.ranged
    if not t then
        return false
    end

    local now = startTime or ns.GetAlignedTime()
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

    if ns.timers.mh.state == "swinging" then
        ns.timers.mh.lastSwing = ns.timers.mh.lastSwing + offset
    end
    if ns.timers.oh.state == "swinging" then
        ns.timers.oh.lastSwing = ns.timers.oh.lastSwing + offset
    end
end

local function ResolveSpellcastEventSpell(primaryArg, spellId)
    if spellId ~= nil then
        return spellId
    end

    if type(primaryArg) == "number" then
        return primaryArg
    end

    if type(primaryArg) ~= "string" or primaryArg == "" then
        return nil
    end

    -- Modern/Anniversary UNIT_SPELLCAST_* payloads can provide castGUID as the
    -- primary argument when spellId is absent. Never treat castGUID as a spell token.
    if primaryArg:match("^Cast%-%") then
        return nil
    end

    return primaryArg
end

local HUNTER_FEIGN_DEATH_ID = 5384
local HUNTER_FEIGN_DEATH_NAME = ns.GetSpellInfo and (ns.GetSpellInfo(HUNTER_FEIGN_DEATH_ID) or "Feign Death")
    or "Feign Death"
local GCD_QUERY_SPELL_ID = 61304

local function QuerySpellCooldown(spellToken)
    if C_Spell and type(C_Spell.GetSpellCooldown) == "function" then
        local ok, cooldownInfo = pcall(C_Spell.GetSpellCooldown, spellToken)
        if ok and type(cooldownInfo) == "table" then
            local startTime = tonumber(cooldownInfo.startTime or cooldownInfo.start_time)
            local duration = tonumber(cooldownInfo.duration)
            local enabled = cooldownInfo.isEnabled
            if enabled == nil then
                enabled = cooldownInfo.enabled
            end
            if (enabled == nil or enabled == true or enabled == 1) and type(startTime) == "number"
                and type(duration) == "number" and duration > 0 then
                return startTime, duration
            end
        end
    end

    if type(GetSpellCooldown) == "function" then
        local startTime, duration, enabled = GetSpellCooldown(spellToken)
        if (enabled == nil or enabled == true or enabled == 1) and type(startTime) == "number"
            and type(duration) == "number" and duration > 0 then
            return startTime, duration
        end
    end

    return nil, nil
end

local function RefreshGcdWindow(now, allowFallback)
    local queryNow = now or ns.GetAlignedTime()
    local startTime, duration = QuerySpellCooldown(GCD_QUERY_SPELL_ID)
    if type(startTime) == "number" and type(duration) == "number" and duration > 0 then
        ns.lastGcdTime = (startTime > 0 and startTime) or queryNow
        ns.gcdDuration = duration
        ns.gcdActive = true
        return
    end

    if allowFallback then
        ns.lastGcdTime = queryNow
        ns.gcdDuration = 1.5
        ns.gcdActive = true
    else
        ns.gcdActive = false
    end
end

local function IsHunterFeignDeathSpell(spellValue)
    if spellValue == nil then
        return false
    end

    local spellId = tonumber(spellValue)
    return spellValue == HUNTER_FEIGN_DEATH_ID or spellValue == HUNTER_FEIGN_DEATH_NAME
        or (spellId and spellId == HUNTER_FEIGN_DEATH_ID)
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
    local startTime = tonumber(fallbackStartTime) or ns.GetAlignedTime()
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
    local now = ns.GetAlignedTime()

    -- Track the live GCD window with Anniversary-safe cooldown queries and a
    -- fixed-duration fallback only when the API has not populated yet.
    RefreshGcdWindow(now, true)
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
    ns.preventSwingReset = ns.preventSwingReset
        or (ns.NO_RESET_SWING_SPELLS
            and (ns.NO_RESET_SWING_SPELLS[spellToken] or (spellIdNumber and ns.NO_RESET_SWING_SPELLS[spellIdNumber])))
    if ns.PAUSE_SWING_SPELLS and (ns.PAUSE_SWING_SPELLS[spellToken]
            or (spellIdNumber and ns.PAUSE_SWING_SPELLS[spellIdNumber])) and not ns.pauseSwingTime then
        ns.pauseSwingTime = ns.GetAlignedTime()
    end
    ns.RefreshUpdateLoop()
end

-- Track GCD for the GCD ticker bar.
-- Prefer the live cooldown query for spell 61304, with a 1.5s fallback when
-- the client has not populated the cooldown yet.
local GCD_DURATION = 1.5
function ns.GetGcdDuration()
    return GCD_DURATION
end

function ns.HandleSpellcastChannelStart(unit, castGUIDOrSpellName, spellId)
    if unit ~= "player" then return end
    ns.RefreshLatencyCache()
    RefreshGcdWindow(ns.GetAlignedTime(), true)
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
    ns.preventSwingReset = ns.NO_RESET_SWING_SPELLS
        and (ns.NO_RESET_SWING_SPELLS[spellToken] or (spellIdNumber and ns.NO_RESET_SWING_SPELLS[spellIdNumber]))
    ns.RefreshUpdateLoop()
end

function ns.HandleSpellcastStop(unit)
    if unit ~= "player" then return end
    ns.casting = false
    ns.channeling = false
    ns.channelingSpellId = nil
    ns.currentCastSpellId = nil
    ns.currentCastStartTime = nil
    if not (ns.playerClass == "HUNTER" and ns.hunterCastActive and ns.hunterCastSpellId and ns.IsHunterCastSpell
        and ns.IsHunterCastSpell(ns.hunterCastSpellId) and ns.hunterCastDuration and ns.hunterCastDuration > 0) then
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
    ns.currentCastStartTime = nil
    if not (ns.playerClass == "HUNTER" and ns.hunterCastActive and ns.hunterCastSpellId and ns.IsHunterCastSpell
        and ns.IsHunterCastSpell(ns.hunterCastSpellId) and ns.hunterCastDuration and ns.hunterCastDuration > 0) then
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
    ns.lastResolvedHunterCastAt = ns.GetAlignedTime()
    SeedHunterStoredCastState(spellToken, ns.GetAlignedTime(), ns.hunterCastDuration)
    ns.RefreshUpdateLoop()
end

function ns.HandleSpellcastInterruptedOrFailed(unit, castGUIDOrSpellName, spellId)
    if unit ~= "player" then return end
    ns.RefreshLatencyCache()
    local now = ns.GetAlignedTime()
    local spellToken = ResolveSpellcastEventSpell(castGUIDOrSpellName, spellId)
    local spellIdNumber = tonumber(spellToken)
    if ns.PAUSE_SWING_SPELLS and (ns.PAUSE_SWING_SPELLS[spellToken]
            or (spellIdNumber and ns.PAUSE_SWING_SPELLS[spellIdNumber])) and ns.pauseSwingTime then
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
    RefreshGcdWindow(now, false)
    ns.RefreshUpdateLoop()
end

-- Apply parry haste to a melee timer when the player parries an incoming attack.
-- Classic rule: reduce remaining time by 40% of the current swing duration,
-- but never below 20% remaining.
--- Apply parry haste to a melee timer when the player parries
--  an incoming attack. Classic rule: reduce remaining time by 40%
--  of the current swing duration, but never below 20% remaining.
--  @param slot (string) The timer slot ("mh" or "oh")
--  @param eventTime (number|nil) Timestamp of the parry event
--  @return (nil)
function ns.ApplyParryHaste(slot, eventTime)
    local t = ns.timers[slot]
    if not t or t.state ~= "swinging" then return end

    local now = eventTime or ns.GetAlignedTime()
    local remaining = (t.lastSwing + t.duration) - now
    local floor = 0.2 * t.duration

    if remaining <= floor then
        return -- already nearly ready; no change
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
    t.lastSwing = 0.0
    t.duration = 0.0
    t.speed = 0.0
    t.hastePercent = nil
    t.nextSpeedCheckAt = 0.0
    t.hiddenCastWindowStart = nil
    t.hiddenCastWindowDuration = nil
    t.lastRangedStartTime = 0.0

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

    local now = ns.GetAlignedTime()
    local remaining = (t.lastSwing + t.duration) - now
    if remaining < 0 then remaining = 0 end
    local ratio = newSpeed / t.duration
    local newRemaining = remaining * ratio

    t.duration = newSpeed
    t.speed = newSpeed
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

--- Main CLEU dispatch handler — called from the bootstrap OnEvent frame.
--  Parses CombatLogGetCurrentEventInfo() and dispatches to individual
--  sub-handlers for SWING_DAMAGE, SWING_MISSED, SPELL_CAST_SUCCESS,
--  SPELL_EXTRA_ATTACKS, SPELL_DAMAGE, SPELL_MISSED, and
--  SPELL_AURA_APPLIED. Handles both numeric spell IDs (Classic Era)
--  and localized string payloads (TBC Anniversary).
--  @return (nil) Side-effect: starts/resets timers, updates state
--  @see ns.StartSwing
--  @see ns.HandleSpellcastSucceeded
--- Main combat-log event handler. Dispatches SWING_DAMAGE, SWING_MISSED,
--  SPELL_CAST_SUCCESS, SPELL_EXTRA_ATTACKS, SPELL_DAMAGE, SPELL_MISSED,
--  and SPELL_AURA_APPLIED events. Routes swings to the correct timer slot
--  (mh, oh, enemy), handles off-hand detection, extra-attack suppression,
--  parry haste, and Overpower proc detection.
--  Called from the bootstrap OnEvent handler every CLEU payload.
--  @return (nil) Operates entirely through side effects on ns.timers
--  @usage Called automatically by the addon event frame; no manual calls needed
--  @see ns.StartSwing, ns.ApplyParryHaste
function ns.HandleCLEU()
    if type(CombatLogGetCurrentEventInfo) ~= "function" then
        return
    end

    -- Latency is refreshed periodically in the OnUpdate loop via
    -- LATENCY_REFRESH_INTERVAL (0.05s).  Calling GetNetStats() on every
    -- CLEU event (hundreds/sec in raids) would be wasteful.

    local _, subEvent, _, sourceGUID, _, _, _, targetGUID, _, _, _, cleuArg12, cleuArg13, _, cleuArg15, _, _, _, _, _, cleuArg21 = CombatLogGetCurrentEventInfo()
    if not subEvent then
        return
    end

    local eventTime = ns.GetAlignedTime()
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

    if sourceGUID == currentPlayerGUID then
        if subEvent == "SWING_DAMAGE" then
            local isOffHandAttack = cleuArg21
            local slot = isOffHandAttack and "oh" or "mh"
            if (ns.extraAttackPending or 0) > 0 then
                ns.extraAttackPending = ns.extraAttackPending - 1
            else
                ns.StartSwing(slot, nil, eventTime)
                if ns.OnMeleeSwing then ns.OnMeleeSwing(slot) end
                if ns.TriggerSwingLandingFlash then ns.TriggerSwingLandingFlash(slot) end
            end
        elseif subEvent == "SWING_MISSED" then
            local missType = cleuArg12
            local isOffHandAttack = cleuArg13
            local slot = isOffHandAttack and "oh" or "mh"
            if ns.playerClass == "WARRIOR" and missType == "DODGE" then
                ns.warriorOverpowerProcUntil = eventTime + WARRIOR_OVERPOWER_PROC_WINDOW
            end
            if (ns.extraAttackPending or 0) > 0 then
                ns.extraAttackPending = ns.extraAttackPending - 1
            else
                ns.StartSwing(slot, nil, eventTime)
                if ns.OnMeleeSwing then ns.OnMeleeSwing(slot) end
                if ns.TriggerSwingLandingFlash then ns.TriggerSwingLandingFlash(slot) end
            end
        elseif subEvent == "SPELL_CAST_SUCCESS" then
            local spellId = cleuArg12
            if ns.IsAutoShotSpell and ns.IsAutoShotSpell(spellId) then
                if ns.StartRangedSwing(eventTime) and ns.OnRangedSwing then
                    ns.OnRangedSwing()
                    if ns.TriggerSwingLandingFlash then ns.TriggerSwingLandingFlash("ranged") end
                end
            end
        elseif subEvent == "SPELL_EXTRA_ATTACKS" then
            local extraAttackAmount = cleuArg15
            ns.extraAttackPending = (ns.extraAttackPending or 0) + (extraAttackAmount or 1)
        elseif (subEvent == "SPELL_DAMAGE" or subEvent == "SPELL_MISSED") then
            local spellId = cleuArg12
            local missType = cleuArg15
            if IsQueuedMeleeHitForPlayerClass(spellId) then
                ns.StartSwing("mh", nil, eventTime)
                if ns.OnMeleeSwing then ns.OnMeleeSwing("mh") end
                if ns.TriggerSwingLandingFlash then ns.TriggerSwingLandingFlash("mh") end
                if ns.playerClass == "WARRIOR" and subEvent == "SPELL_MISSED" and missType == "DODGE" then
                    ns.warriorOverpowerProcUntil = eventTime + WARRIOR_OVERPOWER_PROC_WINDOW
                end
            elseif ns.RESET_RANGED_SWING_SPELLS and ns.RESET_RANGED_SWING_SPELLS[spellId] then
                if ns.StartRangedSwing(eventTime) and ns.OnRangedSwing then
                    ns.OnRangedSwing()
                    if ns.TriggerSwingLandingFlash then ns.TriggerSwingLandingFlash("ranged") end
                end
            end
        elseif subEvent == "SPELL_AURA_APPLIED" then
            local spellId = cleuArg12
            if ns.DRUID_FORM_IDS and ns.DRUID_FORM_IDS[spellId] then
                ns.ResetTimer("mh")
                ns.druidFormChangeTime = eventTime
                if ns.OnDruidFormChange then ns.OnDruidFormChange(spellId) end
            end
        end
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
    local now = ns.GetAlignedTime()
    RefreshGcdWindow(now, true)
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
        if not (liveSpell and ns.IsHunterCastSpell and ns.IsHunterCastSpell(liveSpell))
            and type(ns.GetUnitCastingSpellInfo) == "function" then
            liveSpell = ns.GetUnitCastingSpellInfo("player")
        end
        if liveSpell and ns.IsHunterCastSpell and ns.IsHunterCastSpell(liveSpell) then
            spellToken = liveSpell
        end
    end
    local spellIdNumber = tonumber(spellToken)

    if ns.PAUSE_SWING_SPELLS and (ns.PAUSE_SWING_SPELLS[spellToken]
            or (spellIdNumber and ns.PAUSE_SWING_SPELLS[spellIdNumber])) and ns.pauseSwingTime then
        ns.AdjustSwingTimesAfterPause(now)
    elseif ns.playerClass == "WARRIOR" and ns.WARRIOR_OVERPOWER_ID
        and (spellToken == ns.WARRIOR_OVERPOWER_ID or spellIdNumber == ns.WARRIOR_OVERPOWER_ID
            or spellToken == ns.WARRIOR_OVERPOWER_NAME) then
        ns.warriorOverpowerProcUntil = nil
    elseif ns.playerClass == "HUNTER" and ns.IsHunterCastSpell and ns.IsHunterCastSpell(spellToken) then
        local isAutoShotSpell = ns.IsAutoShotSpell and ns.IsAutoShotSpell(spellToken)
        if not isAutoShotSpell then
            SeedHunterStoredCastState(spellToken, ns.hunterCastStartTime or now, ns.hunterCastDuration)
        end
    elseif ns.RESET_SWING_SPELLS
        and (ns.RESET_SWING_SPELLS[spellToken] or (spellIdNumber and ns.RESET_SWING_SPELLS[spellIdNumber])) then
        ns.StartSwing("mh", nil, now)
        ns.StartSwing("oh", nil, now)
        if ns.StartRangedSwing(now) and ns.OnRangedSwing then
            ns.OnRangedSwing()
        end
        if ns.OnMeleeSwing then ns.OnMeleeSwing("mh") end
    elseif ns.playerClass == "HUNTER" and ns.HUNTER_READINESS_ID
        and (spellToken == ns.HUNTER_READINESS_ID or spellIdNumber == ns.HUNTER_READINESS_ID
            or spellToken == ns.HUNTER_READINESS_NAME) then
        if ns.ForceHunterRapidFireRefresh then
            ns.ForceHunterRapidFireRefresh()
        end
    elseif ns.playerClass == "ROGUE" and ns.ROGUE_ADRENALINE_RUSH_ID
        and (spellToken == ns.ROGUE_ADRENALINE_RUSH_ID or spellIdNumber == ns.ROGUE_ADRENALINE_RUSH_ID
            or spellToken == ns.ROGUE_ADRENALINE_RUSH_NAME) then
        if ns.ForceRogueAdrenalineRushRefresh then
            ns.ForceRogueAdrenalineRushRefresh()
        end
    elseif ns.playerClass == "HUNTER" and IsHunterFeignDeathSpell(spellToken) then
        ns.hunterAutoRepeatActive = false
        ns.ResetTimer("ranged")
    elseif ns.casting and not ns.preventSwingReset then
        -- Auto Shot must not reset the MH swing when the Hunter is at range;
        -- only reset MH/OH when the target is actually in melee range.
        local isHunterAutoShot = ns.playerClass == "HUNTER" and ns.IsAutoShotSpell and ns.IsAutoShotSpell(spellToken)
        local skipMeleeReset = false
        if isHunterAutoShot and ns.IsHunterTargetInMeleeRange then
            skipMeleeReset = ns.IsHunterTargetInMeleeRange() ~= true
        end
        if not skipMeleeReset then
            ns.StartSwing("mh", nil, now)
            ns.StartSwing("oh", nil, now)
        end
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
