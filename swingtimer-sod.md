local MAJOR, MINOR = "LibClassicSwingTimerAPI", 4
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then
    return
end

-- ============================================
-- HIGH-PERFORMANCE CACHING & POOLING
-- ============================================
local frame = CreateFrame("Frame")
local C_Timer, tonumber = C_Timer, tonumber
local GetNetStats = GetNetStats
local GetClock = _G.GetTimePreciseSec or GetTime
local GetSpellCooldown = GetSpellCooldown
local GetSpellInfo = GetSpellInfo
local math_max, math_min = math.max, math.min

local cachedLatency = 0
local lastLatencyUpdate = 0

-- Prime the precise clock so the first live timestamp does not return 0.
GetClock()

local _, _, initialHomeLatency, initialWorldLatency = GetNetStats()
cachedLatency = math_max(((initialWorldLatency and initialWorldLatency > 0) and initialWorldLatency or initialHomeLatency or 0) / 1000, 0)

-- Latency is sampled on a 0.5s throttle from OnUpdate so we never call
-- GetNetStats() every frame (it allocates a tuple each call).
frame:SetScript("OnUpdate", function()
        local now = GetTime()
        if now - lastLatencyUpdate > 0.5 then
            lastLatencyUpdate = now
            local _, _, homeLatency, worldLatency = GetNetStats()
            local activeLatency = (worldLatency and worldLatency > 0) and worldLatency or homeLatency or 0
            cachedLatency = math_max(activeLatency / 1000, 0)
        end
end)

local function GetTimePrecise()
    return GetClock() + cachedLatency
end

local function GetAutoShotCooldown()
    local startTime, duration, enabled = GetSpellCooldown(75)
    if (not duration or duration <= 0) and GetSpellInfo then
        local autoShotName = GetSpellInfo(75)
        if autoShotName then
            startTime, duration, enabled = GetSpellCooldown(autoShotName)
        end
    end

    if enabled == 1 and startTime and duration and duration > 0 then
        return startTime + cachedLatency, duration
    end

    return nil, nil
end

local reset_swing_spells = {
    [16589] = true, -- Noggenfogger Elixir
    [2645] = true, -- Ghost Wolf
    [51533] = true, -- Feral Spirit
    [2764] = true, -- Throw
    [3018] = true, -- Shoots,
    [5384] = true, -- Feign Death
    [5019] = true, -- Shoot
    [75] = true, -- Auto Shot
    [20066] = true, -- Repentance
}

local prevent_swing_speed_update = {
    [768] = true, -- Cat Form
    [5487] = true, -- Bear Form
    [9634] = true, -- Dire Bear Form
}

local next_melee_spells = {
    [30324] = true, -- Heroic Strike (rank 11)
    [25286] = true, -- Heroic Strike (rank 9)
    [11567] = true, -- Heroic Strike (rank 8)
    [11566] = true, -- Heroic Strike (rank 7)
    [11565] = true, -- Heroic Strike (rank 6)
    [11564] = true, -- Heroic Strike (rank 5)
    [1608] = true, -- Heroic Strike (rank 4)
    [285] = true, -- Heroic Strike (rank 3)
    [284] = true, -- Heroic Strike (rank 2)
    [78] = true, -- Heroic Strike (rank 1)
    [25231] = true, -- Cleave (rank 6)
    [20569] = true, -- Cleave (rank 5)
    [11609] = true, -- Cleave (rank 4)
    [11608] = true, -- Cleave (rank 3)
    [7369] = true, -- Cleave (rank 2)
    [845] = true, -- Cleave (rank 1)
    [27022] = true, -- Volley (TBC)
    [34120] = true, -- Steady Shot (TBC)
    [30310] = true, -- Fel Iron Bomb (TBC)
    [30311] = true, -- Adamantite Grenade (TBC)
    [14266] = true, -- Raptor Strike (rank 8)
    [14265] = true, -- Raptor Strike (rank 7)
    [14264] = true, -- Raptor Strike (rank 6)
    [14263] = true, -- Raptor Strike (rank 5)
    [14262] = true, -- Raptor Strike (rank 4)
    [14261] = true, -- Raptor Strike (rank 3)
    [14260] = true, -- Raptor Strike (rank 2)
    [2973] = true, -- Raptor Strike (rank 1)
    [6807] = true, -- Maul (rank 1)
    [6808] = true, -- Maul (rank 2)
    [6809] = true, -- Maul (rank 3)
    [8972] = true, -- Maul (rank 4)
    [9745] = true, -- Maul (rank 5)
    [9880] = true, -- Maul (rank 6)
    [9881] = true, -- Maul (rank 7)
}

local noreset_swing_spells = {
    [30310] = true, -- Fel Iron Bomb (TBC)
    [30311] = true, -- Adamantite Grenade (TBC)
    [23063] = true, -- Dense Dynamite
    [4054] = true, -- Rough Dynamite
    [4064] = true, -- Rough Copper Bomb
    [4061] = true, -- Coarse Dynamite
    [8331] = true, -- Ez-Thro Dynamite
    [4065] = true, -- Large Copper Bomb
    [4066] = true, -- Small Bronze Bomb
    [4062] = true, -- Heavy Dynamite
    [4067] = true, -- Big Bronze Bomb
    [4068] = true, -- Iron Grenade
    [23000] = true, -- Ez-Thro Dynamite II
    [12421] = true, -- Mithril Frag Bomb
    [4069] = true, -- Big Iron Bomb
    [12562] = true, -- The Big One
    [12543] = true, -- Hi-Explosive Bomb
    [19769] = true, -- Thorium Grenade
    [19784] = true, -- Dark Iron Bomb
    [19821] = true, -- Arcane Bomb
    [34120] = true, -- Steady Shot (TBC)
    [27022] = true, -- Volley (TBC)
    [2643] = true, -- Multi-Shot rank 1 (TBC)
    [14288] = true, -- Multi-Shot rank 2 (TBC)
    [14289] = true, -- Multi-Shot rank 3 (TBC)
    [14290] = true, -- Multi-Shot rank 4 (TBC)
    [25294] = true, -- Multi-Shot rank 5 (TBC)
    [27021] = true, -- Multi-Shot rank 6 (TBC)
    [19434] = true, -- Aimed Shot (rank 1)
    [20900] = true, -- Aimed Shot (rank 2)
    [20901] = true, -- Aimed Shot (rank 3)
    [20902] = true, -- Aimed Shot (rank 4)
    [20903] = true, -- Aimed Shot (rank 5)
    [20904] = true, -- Aimed Shot (rank 6)
    [27065] = true, -- Aimed Shot (TBC)

    -- ========================================================
    -- SEASON OF DISCOVERY RUNES (1.15.x)
    -- These are instant attacks / off-hand strikes that must NOT
    -- reset the swing timer. IDs mirror SuperSwingTimer_SoD.lua.
    -- ========================================================
    -- Warrior
    [429765] = true, -- Quick Strike (2H instant filler)
    [402911] = true, -- Raging Blow (Enrage-gated instant)
    [407133] = true, -- Devastate (Shield + Sunder attack)
    [407135] = true, -- Devastate rank variant
    [413380] = true, -- Blood Surge Slam (Instant Slam proc)
    [413399] = true, -- Blood Surge proc
    [426956] = true, -- Precise Timing (Instant Slam 6s CD)
    [426940] = true, -- Rampage Rune active spell ID
    [34428]  = true, -- Victory Rush (instant attack on kill)
    -- Rogue
    [402780] = true, -- Saber Slash (CP attack + bleed)
    [409509] = true, -- Main Gauche (Parry counterattack)
    [32645]  = true, -- Envenom (finisher)
    [426640] = true, -- Secret Technique (Finisher)
    [409510] = true, -- Mutilate (DW dual strike)
    [409513] = true, -- Mutilate rank variant
    [400029] = true, -- Shadow Strike (Stealth strike)
    [409898] = true, -- Quick Draw (Ranged strike)
    [412096] = true, -- Crimson Tempest (AoE finisher)
    -- Shaman
    [408507] = true, -- Lava Lash (Off-hand attack)
    [408247] = true, -- Molten Blast (AoE fire strike)
    [408331] = true, -- Fire Nova (Instant AoE)
    -- Paladin
    [409553] = true, -- Crusader Strike (Melee attack)
    [409456] = true, -- Hammer of the Righteous (Melee AoE)
    [407778] = true, -- Divine Storm (AoE Holy strike)
    -- Hunter
    [415320] = true, -- Flanking Strike (Melee pet strike)
    [425711] = true, -- Carve (Frontal AoE)
    [415318] = true, -- Melee Specialist (Instant Raptor Strike rune)
    [425515] = true, -- Dual Wield Specialization (Melee DW rune)
    [53209]  = true, -- Chimera Shot (Ranged strike)
    [409433] = true, -- Chimera Shot variant
    [53301]  = true, -- Explosive Shot (Ranged explosive)
    [409552] = true, -- Explosive Shot variant
    -- Druid
    [3355]   = true, -- Mangle (Cat)
    [409805] = true, -- Mangle (Cat rune variant)
    [33878]  = true, -- Mangle (Bear)
    [409804] = true, -- Mangle (Bear rune variant)
    [414644] = true, -- Lacerate (Bear bleed strike)
    [417141] = true, -- Berserk (Cat/Bear form)
    [407988] = true, -- Savage Roar (Finisher)
    [414689] = true, -- Sunfire (Cat)
    [414684] = true, -- Sunfire (Bear)
}

local prevent_reset_swing_auras = {
    [408505] = true, -- Maelstrom Weapon
}

local pause_swing_spells = {
    [1464] = true, -- Slam (rank 1)
    [8820] = true, -- Slam (rank 2)
    [11604] = true, -- Slam (rank 3)
    [11605] = true, -- Slam (rank 4)
    [25241] = true, -- Slam (rank 5)
    [25242] = true, -- Slam (rank 6)
    [400320] = true, -- Spellfrost Bolt (Mage)
    [412510] = true, -- Chronostatic Preservation (Mage)
}

local ranged_swing = {
    [75] = true, -- Auto Shot
    [3018] = true, -- Shoot
    [2764] = true, -- Throw
    [5019] = true, -- Shoot
}

local reset_ranged_swing = {
    [14295] = true, -- Volley
    [11925] = true, -- Night Dragon's Breathe
    [11951] = true, -- Whipper Root Tuber
}

-- SoD rune proc buff IDs forwarded to WeakAuras as SOD_PROC events.
local sod_proc_auras = {
    [408505] = "Maelstrom Weapon",   -- Shaman (stacked buff, handled separately)
    [412507] = "Blood Frenzy",       -- Warrior
    [440114] = "Sudden Death",       -- Warrior
    [403349] = "Endless Rage",       -- Warrior
    [400012] = "Blade Dance",        -- Rogue
    [409509] = "Main Gauche",        -- Rogue
    [409844] = "Rolling with the Punches", -- Rogue
    [409503] = "Unfair Advantage",   -- Rogue
    [408696] = "Spirit of the Alpha",-- Shaman
    [408531] = "Way of Earth",       -- Shaman
    [408527] = "Shield Mastery",      -- Shaman
    [415100] = "Power Surge",         -- Shaman
    [408498] = "Dual Wield Specialization", -- Shaman
    [415318] = "Melee Specialist",    -- Hunter
    [425515] = "Dual Wield Specialization", -- Hunter
    [415423] = "Aspect of the Viper", -- Hunter
    [415317] = "Lone Wolf",           -- Hunter
    [407627] = "Sacred Shield",       -- Paladin
    [407630] = "Aegis",               -- Paladin
    [409859] = "Hand of Reckoning",   -- Paladin
    [408435] = "Guarded by the Light",-- Paladin
    [408434] = "Fanaticism",          -- Paladin
    [408432] = "Art of War",          -- Paladin
    [407988] = "Savage Roar",         -- Druid
    [407982] = "Wild Strikes",        -- Druid
    [408005] = "Survival Instincts",  -- Druid
}

-- Spells that consume Maelstrom Weapon stacks -> reset the stack counter.
local maelstrom_consume_spells = {
    [408498] = true, -- Dual Wield Specialization (instant LB)
    [408500] = true, -- Lava Burst
    [408490] = true, -- Lava Burst (variant)
}

function lib:Fire(event, ...)
    WeakAuras.ScanEvents(event, ...)
end

function lib:ADDON_LOADED(_, addOnName)
    if addOnName ~= MAJOR then
        return
    end
    self.unitGUID = UnitGUID("player")
    local mainSpeed, offSpeed = UnitAttackSpeed("player")
    local now = GetTimePrecise()
    self.mainSpeed = mainSpeed or 0
    self.offSpeed = offSpeed or 0
    self.mainDelta, self.offDelta = 0, 0
    self.lastMainSwing = now
    self.mainExpirationTime = now + self.mainSpeed
    self.firstMainSwing = false
    self.lastOffSwing = now
    self.offExpirationTime = now + self.offSpeed
    self.firstOffSwing = false
    self.lastRangedSwing = now
    self.rangedSpeed = UnitRangedDamage("player") or 0
    self.rangedExpirationTime = now + self.rangedSpeed
    self.mainTimer, self.offTimer, self.rangedTimer = nil, nil, nil
    self.casting, self.channeling, self.isAttacking = false, false, false
    self.preventSwingReset, self.skipNextAttack, self.skipNextAttackSpeedUpdate = false, nil, nil
    self.skipNextAttackCount, self.skipNextAttackSpeedUpdateCount = 0, 0
    self.maelstromStacks = 0
end

lib:ADDON_LOADED("", MAJOR)

function lib:CalculateDelta()
    local now = GetTimePrecise()
    if not now then return end
    if self.mainSpeed > 0 and self.offSpeed > 0 and self.mainExpirationTime > 0 and self.offExpirationTime > 0 then
        self:Fire("SWING_TIMER_DELTA", self.mainExpirationTime - self.offExpirationTime, now)
    end
end

function lib:SwingStart(hand, startTime, isReset)
    if hand == "mainhand" then
        self:HandleMainHandSwing(startTime, isReset)
    elseif hand == "offhand" then
        self:HandleOffHandSwing(startTime, isReset)
    elseif hand == "ranged" then
        self:HandleRangedSwing(startTime, isReset)
    end
end

function lib:HandleMainHandSwing(startTime, isReset)
    local previousExpiration = self.mainExpirationTime
    self.lastMainSwing = startTime
    self.mainSpeed = UnitAttackSpeed("player") or 0
    if self.mainSpeed <= 0 then
        return
    end
    if self._suppressDelta then
        self.mainDelta = 0
    elseif previousExpiration and previousExpiration > 0 then
        self.mainDelta = startTime - previousExpiration
    else
        self.mainDelta = 0
    end
    self.mainExpirationTime = startTime + self.mainSpeed
    self:Fire("SWING_TIMER_START", self.mainSpeed, self.mainExpirationTime, "mainhand")
    if self.mainTimer then self.mainTimer:Cancel() end
    -- Self-correcting delta: Apply previous swing error to this timer
    local delta = self.mainDelta or 0
    local duration = math_max(0, self.mainExpirationTime - GetTimePrecise() + delta)
    -- Use NewTimer for precise control
    self.mainTimer = C_Timer.NewTimer(duration, function()
        self:SwingEnd("mainhand")
    end)

    if not self._suppressDelta then
        self:CalculateDelta()
    end
end

function lib:HandleOffHandSwing(startTime, isReset)
    local previousExpiration = self.offExpirationTime
    self.lastOffSwing = startTime
    local _, offSpeed = UnitAttackSpeed("player")
    self.offSpeed = offSpeed or 0
    if self.offSpeed > 0 then
        if self._suppressDelta then
            self.offDelta = 0
        elseif previousExpiration and previousExpiration > 0 then
            self.offDelta = startTime - previousExpiration
        else
            self.offDelta = 0
        end
        self.offExpirationTime = startTime + self.offSpeed
        self:Fire("SWING_TIMER_START", self.offSpeed, self.offExpirationTime, "offhand")
        if self.offTimer then self.offTimer:Cancel() end
        -- Self-correcting delta: Apply previous swing error to this timer
        local delta = self.offDelta or 0
        local duration = math_max(0, self.offExpirationTime - GetTimePrecise() + delta)
        self.offTimer = C_Timer.NewTimer(duration, function()
            self:SwingEnd("offhand")
        end)

        if not self._suppressDelta then
            self:CalculateDelta()
        end
    end
end

function lib:HandleRangedSwing(startTime, isReset)
    if self.rangedTimer and isReset then self.rangedTimer:Cancel() end
    -- Prefer the active Auto Shot cooldown when it exists, then fall back to
    -- the ranged weapon speed so the timer stays aligned with the live client.
    local autoShotStart, autoShotDuration = GetAutoShotCooldown()
    if autoShotDuration and autoShotDuration > 0 then
        self.rangedSpeed = autoShotDuration
        self.lastRangedSwing = (autoShotStart and autoShotStart > 0) and autoShotStart or startTime
    else
        self.rangedSpeed = UnitRangedDamage("player") or 0
        self.lastRangedSwing = startTime
    end
    self.rangedExpirationTime = self.lastRangedSwing + self.rangedSpeed
    self:Fire("SWING_TIMER_START", self.rangedSpeed, self.rangedExpirationTime, "ranged")
    -- Ensure the duration is non-negative
    local duration = math_max(0, self.rangedExpirationTime - GetTimePrecise())
    if duration > 0 then
        self.rangedTimer = C_Timer.NewTimer(duration, function() self:SwingEnd("ranged") end)
    else
        self:SwingEnd("ranged")
    end
end


function lib:UpdateRangedSpeed(now)
    if not self.rangedTimer or self.rangedSpeed <= 0 then
        return
    end

    now = now or GetTimePrecise()
    local autoShotStart, autoShotDuration = GetAutoShotCooldown()
    local newSpeed = autoShotDuration
    if not newSpeed or newSpeed <= 0 then
        newSpeed = UnitRangedDamage("player") or 0
    end

    if newSpeed <= 0 or math.abs(newSpeed - self.rangedSpeed) < 0.01 then
        return
    end

    local remaining = math_max(0, self.rangedExpirationTime - now)
    local ratio = newSpeed / self.rangedSpeed
    local newRemaining = remaining * ratio

    if self.rangedTimer then
        self.rangedTimer:Cancel()
    end

    self.rangedSpeed = newSpeed
    self.lastRangedSwing = (autoShotStart and autoShotStart > 0) and autoShotStart or self.lastRangedSwing
    self.rangedExpirationTime = now + newRemaining
    self:Fire("SWING_TIMER_UPDATE", self.rangedSpeed, self.rangedExpirationTime, "ranged")

    local duration = math_max(0, self.rangedExpirationTime - GetTimePrecise())
    if duration > 0 then
        self.rangedTimer = C_Timer.NewTimer(duration, function() self:SwingEnd("ranged") end)
    else
        self:SwingEnd("ranged")
    end
end


function lib:SwingEnd(hand)
    -- Immediately clear the timer handle to prevent any "stuck" state
    if hand == "mainhand" then self.mainTimer = nil end
    if hand == "offhand" then self.offTimer = nil end
    if hand == "ranged" then self.rangedTimer = nil end
    self:Fire("SWING_TIMER_STOP", hand)
    -- Auto-restart melee swings if the player is still attacking and not casting.
    -- Ranged restarts from the next Auto Shot / reset event instead of a blind loop.
    if (self.casting or self.channeling) and self.isAttacking and hand ~= "ranged" then
        self:SwingStart(hand, GetTimePrecise(), true)
        self:Fire("SWING_TIMER_CLIPPED", hand)
    end
end

-- Dynamic adjustment function
function lib:UpdateTimer(hand)
    if hand == "mainhand" and self.mainTimer then
        self.mainTimer:Cancel()
        self:HandleMainHandSwing(self.lastMainSwing, false)
    elseif hand == "offhand" and self.offTimer then
        self.offTimer:Cancel()
        self:HandleOffHandSwing(self.lastOffSwing, false)
    end
end

function lib:ResetTimers(now)
    now = now or GetTimePrecise()

    if self.mainTimer then self.mainTimer:Cancel() end
    if self.offTimer then self.offTimer:Cancel() end
    if self.rangedTimer then self.rangedTimer:Cancel() end

    self.mainTimer, self.offTimer, self.rangedTimer = nil, nil, nil
    self.firstMainSwing, self.firstOffSwing = false, false
    self.mainDelta, self.offDelta = 0, 0

    self._suppressDelta = true
    self:SwingStart("mainhand", now, true)
    self:SwingStart("offhand", now, true)
    self:SwingStart("ranged", now, true)
    self._suppressDelta = nil

    self:CalculateDelta()
end

function lib:SwingTimerInfo(hand)
    if hand == "mainhand" then return self.mainSpeed, self.mainExpirationTime, self.lastMainSwing end
    if hand == "offhand" then return self.offSpeed, self.offExpirationTime, self.lastOffSwing end
    if hand == "ranged" then return self.rangedSpeed, self.rangedExpirationTime, self.lastRangedSwing end
end

-- ========================================================
-- SoD: Maelstrom Weapon stack tracking + rune proc forwarding
-- ========================================================
local C_UnitAuras = rawget(_G, "C_UnitAuras")

local function GetMaelstromStacks()
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(408505)
        if aura and aura.count then
            return math_min(aura.count, 5)
        end
    end
    -- Fallback: index scan
    for i = 1, 40 do
        local name, _, _, count, _, _, _, _, _, _, spellID = UnitAura("player", i, "HELPFUL")
        if not name then break end
        if spellID == 408505 or name == "Maelstrom Weapon" then
            return math_min(count or 0, 5)
        end
    end
    return 0
end

local function FireMaelstrom(stacks)
    lib.maelstromStacks = stacks
    local multiplier = math_max(1.0 - 0.20 * stacks, 0.0)
    lib:Fire("SWING_TIMER_SOD_MAELSTROM", stacks, multiplier)
    if stacks == 5 and type(PlaySound) == "function" then
        PlaySound(8960)
    end
end

function lib:UpdateSoDProcs()
    -- Maelstrom Weapon stacks
    local stacks = GetMaelstromStacks()
    if stacks ~= self.maelstromStacks then
        FireMaelstrom(stacks)
    end

    -- Generic SoD rune proc buffs (non-Maelstrom)
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        for spellID, label in pairs(sod_proc_auras) do
            if spellID == 408505 then
                -- handled above
            else
                local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
                local active = aura and true or false
                local key = "sod_proc_" .. spellID
                if self[key] ~= active then
                    self[key] = active
                    self:Fire("SWING_TIMER_SOD_PROC", spellID, label, active and 1 or 0)
                end
            end
        end
    end
end

function lib:COMBAT_LOG_EVENT_UNFILTERED(_, ts, subEvent, _, sourceGUID, _, _, _, destGUID, _, _, _, amount, overkill, _, resisted, _, _, _, _, _, isOffHand)
    local now = GetTimePrecise()
    if subEvent == "SPELL_EXTRA_ATTACKS" and sourceGUID == self.unitGUID then
        self.skipNextAttack = ts
        self.skipNextAttackCount = resisted
    elseif (subEvent == "SWING_DAMAGE" or subEvent == "SWING_MISSED") and sourceGUID == self.unitGUID then
        isOffHand = isOffHand
        if subEvent == "SWING_MISSED" then
            isOffHand = overkill
        end
        if
        self.skipNextAttack ~= nil
        and tonumber(self.skipNextAttack)
        and (ts - self.skipNextAttack) < 0.04
        and tonumber(self.skipNextAttackCount)
        and not isOffHand
        then
            if self.skipNextAttackCount > 0 then
                self.skipNextAttackCount = self.skipNextAttackCount - 1
                return false
            end
        end
        if isOffHand then
            self.firstOffSwing = true
            self:SwingStart("offhand", now, false)
            self:SwingStart("ranged", now, true)
        else
            self.firstMainSwing = true
            self:SwingStart("mainhand", now, false)
            self:SwingStart("ranged", now, true)
        end
    elseif subEvent == "SWING_MISSED" and amount ~= nil and amount == "PARRY" and destGUID == self.unitGUID then
        if self.mainTimer then
            self.mainTimer:Cancel()
        end
        local hasteFactor = GetHaste() / 100
        local adjustedReduction = 0.4 - hasteFactor * 0.1 -- Adjust reduction based on haste
        local swing_timer_reduced_40p = self.mainExpirationTime - (adjustedReduction * self.mainSpeed)
        local min_swing_time = 0.2 * self.mainSpeed
        if swing_timer_reduced_40p < min_swing_time then
            self.mainExpirationTime = min_swing_time
        else
            self.mainExpirationTime = swing_timer_reduced_40p
        end
        self:Fire("SWING_TIMER_UPDATE", self.mainSpeed, self.mainExpirationTime, "mainhand")
        if self.mainSpeed > 0 and self.mainExpirationTime - GetTimePrecise() > 0 then
            self.mainTimer = C_Timer.NewTimer(self.mainExpirationTime - GetTimePrecise(), function()
                self:SwingEnd("mainhand")
            end)
        end
    elseif (subEvent == "SPELL_AURA_APPLIED" or subEvent == "SPELL_AURA_REMOVED") and sourceGUID == self.unitGUID then
        local spell = amount
        if spell and prevent_swing_speed_update[spell] then
            self.skipNextAttackSpeedUpdate = now
            self.skipNextAttackSpeedUpdateCount = 2
        end
        if spell and prevent_reset_swing_auras[spell] then
            self.preventSwingReset = subEvent == "SPELL_AURA_APPLIED"
        end
        -- SoD proc forwarder: re-scan on every player aura change
        self:UpdateSoDProcs()
    elseif (subEvent == "SPELL_DAMAGE" or subEvent == "SPELL_MISSED") and sourceGUID == self.unitGUID then
        local spell = amount
        if reset_ranged_swing[spell] then
            self:SwingStart("ranged", GetTimePrecise(), true)
        end
    elseif subEvent == "SPELL_CAST_SUCCESS" and sourceGUID == self.unitGUID then
        local spell = amount
        -- Maelstrom Weapon consumption
        if spell and maelstrom_consume_spells[spell] then
            self.maelstromStacks = 0
            self:Fire("SWING_TIMER_SOD_MAELSTROM", 0, 1.0)
        end
        -- Sudden Death proc alert
        if spell == 440114 and type(PlaySound) == "function" then
            PlaySound(8960)
        end
    end
end

function lib:UNIT_ATTACK_SPEED()
    local now = GetTimePrecise()
    if self.skipNextAttackSpeedUpdate and (now - self.skipNextAttackSpeedUpdate) < 0.04 and self.skipNextAttackSpeedUpdateCount then
        self.skipNextAttackSpeedUpdateCount = self.skipNextAttackSpeedUpdateCount - 1
        return
    end
    self:UpdateSwingSpeeds(now)
end

function lib:UpdateSwingSpeeds(now)
    local mainSpeedNew, offSpeedNew = UnitAttackSpeed("player")
    mainSpeedNew = mainSpeedNew or 0
    offSpeedNew = offSpeedNew or 0

    if mainSpeedNew == self.mainSpeed and offSpeedNew == self.offSpeed then
        return
    end

    self:UpdateMainHandSpeed(mainSpeedNew, now)
    self:UpdateOffHandSpeed(offSpeedNew, now)

    self:CalculateDelta()
end

function lib:UpdateMainHandSpeed(mainSpeedNew, now)
    if mainSpeedNew > 0 and self.mainSpeed > 0 and mainSpeedNew ~= self.mainSpeed then
        local remaining = math_max(0, self.mainExpirationTime - now)
        local timeLeft = remaining * (mainSpeedNew / self.mainSpeed)
        if self.mainTimer then self.mainTimer:Cancel() end
        self.mainSpeed = mainSpeedNew
        self.mainExpirationTime = now + timeLeft
        self:Fire("SWING_TIMER_UPDATE", self.mainSpeed, self.mainExpirationTime, "mainhand")
        -- Ensure the duration is non-negative
        local duration = self.mainExpirationTime - GetTimePrecise()
        if duration > 0 then
            self.mainTimer = C_Timer.NewTimer(duration, function() self:SwingEnd("mainhand") end)
        else
            self:SwingEnd("mainhand")
        end

    end
end

function lib:UpdateOffHandSpeed(offSpeedNew, now)
    if offSpeedNew > 0 and self.offSpeed > 0 and offSpeedNew ~= self.offSpeed then
        local remaining = math_max(0, self.offExpirationTime - now)
        local timeLeft = remaining * (offSpeedNew / self.offSpeed)
        if self.offTimer then self.offTimer:Cancel() end
        self.offSpeed = offSpeedNew
        self.offExpirationTime = now + timeLeft
        self:Fire("SWING_TIMER_UPDATE", self.offSpeed, self.offExpirationTime, "offhand")
        -- Ensure the duration is non-negative
        local duration = self.offExpirationTime - GetTimePrecise()
        if duration > 0 then
            self.offTimer = C_Timer.NewTimer(duration, function() self:SwingEnd("offhand") end)
        else
            self:SwingEnd("offhand")
        end

    end
end

function lib:UNIT_SPELLCAST_INTERRUPTED_OR_FAILED(_, _, _, spell)
    self.casting = false
    if spell and pause_swing_spells[spell] and self.pauseSwingTime then
        self.pauseSwingTime = nil
        local now = GetTimePrecise()
        if self.mainSpeed > 0 then
            if self.mainExpirationTime < now and self.isAttacking then
                self.mainExpirationTime = self.mainExpirationTime + self.mainSpeed
            end
            self:Fire("SWING_TIMER_UPDATE", self.mainSpeed, self.mainExpirationTime, "mainhand")
            -- Ensure the duration is non-negative
            local duration = self.mainExpirationTime - now
            if duration > 0 then
                self.mainTimer = C_Timer.NewTimer(duration, function() self:SwingEnd("mainhand") end)
            else
                self:SwingEnd("mainhand")
            end

            self:CalculateDelta()
        end
        if self.offSpeed > 0 then
            if self.offExpirationTime < now and self.isAttacking then
                self.offExpirationTime = self.offExpirationTime + self.offSpeed
            end
            self:Fire("SWING_TIMER_UPDATE", self.offSpeed, self.offExpirationTime, "offhand")
            -- Ensure the duration is non-negative
            local duration = self.offExpirationTime - now
            if duration > 0 then
                self.offTimer = C_Timer.NewTimer(duration, function() self:SwingEnd("offhand") end)
            else
                self:SwingEnd("offhand")
            end

            self:CalculateDelta()
        end
    end
end


function lib:UNIT_SPELLCAST_INTERRUPTED(...)
    self:UNIT_SPELLCAST_INTERRUPTED_OR_FAILED(...)
end

function lib:UNIT_SPELLCAST_FAILED(...)
    self:UNIT_SPELLCAST_INTERRUPTED_OR_FAILED(...)
end

function lib:UNIT_SPELLCAST_SUCCEEDED(_, _, _, spell)
    local now = GetTimePrecise()
    if spell ~= nil and next_melee_spells[spell] then
        self:SwingStart("mainhand", now, false)
        self:SwingStart("ranged", now, true)
    end
    if (spell and reset_swing_spells[spell]) or (self.casting and not self.preventSwingReset) then
        self:SwingStart("mainhand", now, true)
        self:SwingStart("offhand", now, true)
        self:SwingStart("ranged", now, not ranged_swing[spell])
    end
    if spell and pause_swing_spells[spell] and self.pauseSwingTime then
        local offset = now - self.pauseSwingTime
        self.pauseSwingTime = nil
        if self.mainSpeed > 0 then
            self.mainExpirationTime = self.mainExpirationTime + offset
            self:Fire("SWING_TIMER_UPDATE", self.mainSpeed, self.mainExpirationTime, "mainhand")
            self.mainTimer = C_Timer.After(self.mainExpirationTime - now, function()
                self:SwingEnd("mainhand")
            end)
        end
        if self.offSpeed > 0 then
            self.offExpirationTime = self.offExpirationTime + offset
            self:Fire("SWING_TIMER_UPDATE", self.offSpeed, self.offExpirationTime, "offhand")
            self.offTimer = C_Timer.After(self.offExpirationTime - now, function()
                self:SwingEnd("offhand")
            end)
        end
    end
    if self.casting and spell ~= 6603 then
        self.casting = false
    end
end

function lib:AdjustSwingTimesAfterPause(now)
    local offset = now - self.pauseSwingTime
    self.pauseSwingTime = nil
    if self.mainSpeed > 0 then
        self.mainExpirationTime = self.mainExpirationTime + offset
        self:Fire("SWING_TIMER_UPDATE", self.mainSpeed, self.mainExpirationTime, "mainhand")
        -- Ensure the duration is non-negative
        local duration = self.mainExpirationTime - now
        if duration > 0 then
            self.mainTimer = C_Timer.NewTimer(duration, function() self:SwingEnd("mainhand") end)
        else
            self:SwingEnd("mainhand")
        end
    end
    if self.offSpeed > 0 then
        self.offExpirationTime = self.offExpirationTime + offset
        self:Fire("SWING_TIMER_UPDATE", self.offSpeed, self.offExpirationTime, "offhand")
        -- Ensure the duration is non-negative
        local duration = self.offExpirationTime - now
        if duration > 0 then
            self.offTimer = C_Timer.NewTimer(duration, function() self:SwingEnd("offhand") end)
        else
            self:SwingEnd("offhand")
        end
    end
end

function lib:UNIT_SPELLCAST_START(_, unit, _, spell)
    if spell then
        local now = GetTimePrecise()
        -- Remove unused variable
        GetSpellInfo(spell)
        self.casting = true
        self.preventSwingReset = self.preventSwingReset or noreset_swing_spells[spell]
        if spell and pause_swing_spells[spell] then
            self.pauseSwingTime = now
            if self.mainSpeed > 0 then
                self:Fire("SWING_TIMER_PAUSED", "mainhand")
                if self.mainTimer then
                    self.mainTimer:Cancel()
                end
            end
            if self.offSpeed > 0 then
                self:Fire("SWING_TIMER_PAUSED", "offhand")
                if self.offTimer then
                    self.offTimer:Cancel()
                end
            end
        end
    end
end

function lib:UNIT_SPELLCAST_CHANNEL_START(_, _, _, spell)
    self.casting, self.channeling = true, true
    self.preventSwingReset = noreset_swing_spells[spell]
end

function lib:UNIT_SPELLCAST_CHANNEL_STOP()
    self.channeling = false
end

function lib:PLAYER_EQUIPMENT_CHANGED(_, equipmentSlot)
    if equipmentSlot == 16 or equipmentSlot == 17 or equipmentSlot == 18 then
        local mainSpeed = UnitAttackSpeed("player")
        if mainSpeed then
            self:ResetTimers(GetTimePrecise())
        end
    end
end

function lib:PLAYER_ENTER_COMBAT()
    self.isAttacking = true
    local now = GetTimePrecise()
    if now > (self.offExpirationTime - (self.offSpeed / 2)) and self.offTimer then
        self.offTimer:Cancel()
        self:SwingStart("offhand", now, true)
    end
end

function lib:PLAYER_LEAVE_COMBAT()
    self.isAttacking, self.firstMainSwing, self.firstOffSwing = false, false, false
end

function lib:PLAYER_TALENT_UPDATE()
    self:UpdateSwingSpeeds(GetTimePrecise())
end

function lib:UNIT_AURA()
    self:UpdateSoDProcs()
end

frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("PLAYER_ENTER_COMBAT")
frame:RegisterEvent("PLAYER_LEAVE_COMBAT")
frame:RegisterEvent("PLAYER_TALENT_UPDATE")
frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
frame:RegisterUnitEvent("UNIT_RANGEDDAMAGE", "player")
frame:RegisterUnitEvent("UNIT_AURA", "player")
frame:RegisterUnitEvent("UNIT_ATTACK_SPEED", "player")
frame:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
frame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
frame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
frame:RegisterEvent("ADDON_LOADED")

frame:SetScript("OnEvent", function(_, event, ...)
        if event == "COMBAT_LOG_EVENT_UNFILTERED" then
            lib[event](lib, event, CombatLogGetCurrentEventInfo())
        elseif event == "UNIT_ATTACK_SPEED" then
            lib[event](lib, event, ...)
        elseif event == "SPELL_UPDATE_COOLDOWN" or event == "UNIT_RANGEDDAMAGE" then
            lib:UpdateRangedSpeed(GetTimePrecise())
        elseif event == "UNIT_AURA" then
            lib:UpdateSoDProcs()
        else
            lib[event](lib, event, ...)
        end
end)
