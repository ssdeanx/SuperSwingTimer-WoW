local MAJOR, MINOR = "LibClassicSwingTimerAPI", 3
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then
    return
end

local frame = CreateFrame("Frame")
local C_Timer, tonumber = C_Timer, tonumber
local GetSpellInfo, GetTime, CombatLogGetCurrentEventInfo = GetSpellInfo, GetTime, CombatLogGetCurrentEventInfo
local UnitAttackSpeed, UnitGUID, UnitRangedDamage = UnitAttackSpeed, UnitGUID, UnitRangedDamage
local GetNetStats, GetHaste = GetNetStats, GetHaste

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
    
    [25286] = true, -- Heroic Strike (rank 9)
    [11567] = true, -- Heroic Strike (rank 8)
    [11566] = true, -- Heroic Strike (rank 7)
    [11565] = true, -- Heroic Strike (rank 6)
    [11564] = true, -- Heroic Strike (rank 5)
    [1608] = true, -- Heroic Strike (rank 4)
    [285] = true, -- Heroic Strike (rank 3)
    [284] = true, -- Heroic Strike (rank 2)
    [78] = true, -- Heroic Strike (rank 1)
    [20569] = true, -- Cleave (rank 5)    
    [11609] = true, -- Cleave (rank 4)
    [11608] = true, -- Cleave (rank 3)
    [7369] = true, -- Cleave (rank 2)
    [845] = true, -- Cleave (rank 1)
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
    [56641] = true, -- Steady Shot (rank 1)
    [34120] = true, -- Steady Shot (rank 2)
    [19434] = true, -- Aimed Shot (rank 1)
    [1464] = true, -- Slam (rank 1)
    [8820] = true, -- Slam (rank 2)
    [11604] = true, -- Slam (rank 3)
    [11605] = true, -- Slam (rank 4)
    [17402] = true, -- Hurricane (rank 3)
    [17401] = true, -- Hurricane (rank 2)
    [16914] = true, -- Hurricane (rank 1)
    [12051] = true, -- Evocation
    [14295] = true, -- Volley (rank 3)
    [14294] = true, -- Volley (rank 2)
    [1510] = true, -- Volley (rank 1)
    
}

local prevent_reset_swing_auras = {
    [408505] = true, -- Maelstrom Weapon
}

local pause_swing_spells = {
    [1464] = true, -- Slam (rank 1)
    [8820] = true, -- Slam (rank 2)
    [11604] = true, -- Slam (rank 3)
    [11605] = true, -- Slam (rank 4)
    
}

local ranged_swing = {
    [75] = true, -- Auto Shot
    [3018] = true, -- Shoot
    [2764] = true, -- Throw
    [5019] = true, -- Shoot
}

local reset_ranged_swing = {
    [14295] = true, -- Volley
    
}

-- lib.callbacks = lib.callbacks or LibStub("CallbackHandler-1.0"):New(lib)

function lib:Fire(event, ...)
    WeakAuras.ScanEvents(event, ...)
end

local lastLatencyUpdate, cachedLatency = 0, 0

local function GetTimePrecise()
    local currentTime = GetTime()
    if currentTime - lastLatencyUpdate > 0.5 then
        lastLatencyUpdate = currentTime
        local netStats = { GetNetStats() }
        assert(netStats and #netStats > 0, "GetNetStats returned nil or an empty table")
        cachedLatency = netStats[3] / 1000
    end
    return currentTime + cachedLatency
end

function lib:ADDON_LOADED(_, addOnName)
    if addOnName ~= MAJOR then
        return
    end
    
    self.unitGUID = UnitGUID("player")
    
    local mainSpeed, offSpeed = UnitAttackSpeed("player")
    local now = GetTimePrecise()
    
    self.mainSpeed = mainSpeed
    self.offSpeed = offSpeed or 0
    
    self.lastMainSwing = now
    self.mainExpirationTime = now + self.mainSpeed
    self.firstMainSwing = false
    
    self.lastOffSwing = now
    self.offExpirationTime = now + self.offSpeed
    self.firstOffSwing = false
    
    self.lastRangedSwing = now
    self.rangedSpeed = UnitRangedDamage("player") or 0
    self.rangedExpirationTime = now + self.rangedSpeed
    
    self.mainTimer, self.offTimer, self.rangedTimer, self.calculaDeltaTimer = nil, nil, nil, nil
    self.casting, self.channeling, self.isAttacking = false, false, false
    self.preventSwingReset, self.skipNextAttack, self.skipNextAttackSpeedUpdate = false, nil, nil
    self.skipNextAttackCount, self.skipNextAttackSpeedUpdateCount = 0, 0
end

lib:ADDON_LOADED("",MAJOR)

function lib:CalculateDelta()
    if not GetTimePrecise() then return end
    if self.offSpeed > 0 then
        self:Fire("SWING_TIMER_DELTA", self.mainExpirationTime - self.offExpirationTime, GetTimePrecise())
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
    if self.mainTimer and isReset then self.mainTimer:Cancel() end
    self.lastMainSwing = startTime
    self.mainSpeed = UnitAttackSpeed("player")
    self.mainExpirationTime = startTime + self.mainSpeed
    self:Fire("SWING_TIMER_START", self.mainSpeed, self.mainExpirationTime, "mainhand")
    
    -- Ensure the duration is non-negative
    local duration = self.mainExpirationTime - GetTime()
    if duration > 0 then
        self.mainTimer = C_Timer.After(duration, function() self:SwingEnd("mainhand") end)
    else
        -- Handle the case where the duration is negative or zero
        self:SwingEnd("mainhand")
    end
end

function lib:HandleOffHandSwing(startTime, isReset)
    if self.offTimer and isReset then self.offTimer:Cancel() end
    self.lastOffSwing = startTime
    local _, offSpeed = UnitAttackSpeed("player")
    self.offSpeed = offSpeed or 0
    
    if self.offSpeed > 0 then
        local adjustedDelay = offSpeed * (0.5 - GetHaste() / 100 * 0.1)
        self.offExpirationTime = startTime + self.offSpeed
        
        if self.calculaDeltaTimer then
            self.calculaDeltaTimer:Cancel()
        end
        
        if not self.firstOffSwing and self.isAttacking then
            self.offExpirationTime = startTime + (self.offSpeed / 2)
            self:CalculateDelta()
            self:Fire("SWING_TIMER_UPDATE", self.offSpeed, self.offExpirationTime, "offhand")
        else
            self:Fire("SWING_TIMER_START", self.offSpeed, self.offExpirationTime, "offhand")
            self.calculaDeltaTimer = C_Timer.After(self.offSpeed / 2, function() self:CalculateDelta() end)
        end
        
        -- Ensure the duration is non-negative
        local duration = self.offExpirationTime - GetTime()
        if duration > 0 then
            self.offTimer = C_Timer.After(duration, function() self:SwingEnd("offhand") end)
        else
            -- Handle the case where the duration is negative or zero
            self:SwingEnd("offhand")
        end
    end
end

function lib:HandleRangedSwing(startTime, isReset)
    if self.rangedTimer and isReset then self.rangedTimer:Cancel() end
    self.rangedSpeed = UnitRangedDamage("player") or 0
    self.lastRangedSwing = startTime
    self.rangedExpirationTime = startTime + self.rangedSpeed
    self:Fire("SWING_TIMER_START", self.rangedSpeed, self.rangedExpirationTime, "ranged")
    
    -- Ensure the duration is non-negative
    local duration = self.rangedExpirationTime - GetTimePrecise()
    if duration > 0 then
        self.rangedTimer = C_Timer.After(duration, function() self:SwingEnd("ranged") end)
    else
        -- Handle the case where the duration is negative or zero
        self:SwingEnd("ranged")
    end
end


function lib:SwingEnd(hand)
    self:Fire("SWING_TIMER_STOP", hand)
    if (self.casting or self.channeling) and self.isAttacking and hand ~= "ranged" then
        self:SwingStart(hand, GetTimePrecise(), true)
        self:Fire("SWING_TIMER_CLIPPED", hand)
    end
end

function lib:SwingTimerInfo(hand)
    if hand == "mainhand" then return self.mainSpeed, self.mainExpirationTime, self.lastMainSwing end
    if hand == "offhand" then return self.offSpeed, self.offExpirationTime, self.lastOffSwing end
    if hand == "ranged" then return self.rangedSpeed, self.rangedExpirationTime, self.lastRangedSwing end
end

function lib:COMBAT_LOG_EVENT_UNFILTERED(_, ts, subEvent, _, sourceGUID, _, _, _, destGUID, _, _, _, amount, overkill, _, resisted, _, _, _, _, _, isOffHand)
    local now = GetTime()
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
            self.mainTimer = C_Timer.After(self.mainExpirationTime - GetTimePrecise(), function()
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
    elseif (subEvent == "SPELL_DAMAGE" or subEvent == "SPELL_MISSED") and sourceGUID == self.unitGUID then
        local spell = amount
        if reset_ranged_swing[spell] then
            self:SwingStart("ranged", GetTimePrecise(), true)
        end
    end
end

function lib:UNIT_ATTACK_SPEED()
    local now = GetTimePrecise()
    if self.skipNextAttackSpeedUpdate and (now - self.skipNextAttackSpeedUpdate) < 0.04 and self.skipNextAttackSpeedUpdateCount then
        self.skipNextAttackSpeedUpdateCount = self.skipNextAttackSpeedUpdateCount - 1
        return
    end
    if self.mainTimer then self.mainTimer:Cancel() end
    if self.offTimer then self.offTimer:Cancel() end
    self:UpdateSwingSpeeds(now)
end

function lib:UpdateSwingSpeeds(now)
    local mainSpeedNew, offSpeedNew = UnitAttackSpeed("player")
    offSpeedNew = offSpeedNew or 0
    self:UpdateMainHandSpeed(mainSpeedNew, now)
    self:UpdateOffHandSpeed(offSpeedNew, now)
end

function lib:UpdateMainHandSpeed(mainSpeedNew, now)
    if mainSpeedNew > 0 and self.mainSpeed > 0 and mainSpeedNew ~= self.mainSpeed then
        local hasteFactor = GetHaste() / 100
        local adjustedMultiplier = mainSpeedNew / self.mainSpeed * (1 - hasteFactor * 0.1)
        local timeLeft = (self.lastMainSwing + self.mainSpeed - now) * adjustedMultiplier
        self.mainSpeed = mainSpeedNew
        self.mainExpirationTime = now + timeLeft
        self:Fire("SWING_TIMER_UPDATE", self.mainSpeed, self.mainExpirationTime, "mainhand")
        
        -- Ensure the duration is non-negative
        local duration = self.mainExpirationTime - GetTimePrecise()
        if duration > 0 then
            self.mainTimer = C_Timer.After(duration, function() self:SwingEnd("mainhand") end)
        else
            self:SwingEnd("mainhand")
        end
    end
end

function lib:UpdateOffHandSpeed(offSpeedNew, now)
    if offSpeedNew > 0 and self.offSpeed > 0 and offSpeedNew ~= self.offSpeed then
        local hasteFactor = GetHaste() / 100
        local adjustedMultiplier = offSpeedNew / self.offSpeed * (1 - hasteFactor * 0.1)
        local timeLeft = (self.lastOffSwing + self.offSpeed - now) * adjustedMultiplier
        self.offSpeed = offSpeedNew
        self.offExpirationTime = now + timeLeft
        
        if self.calculaDeltaTimer then self.calculaDeltaTimer:Cancel() end
        
        self:Fire("SWING_TIMER_UPDATE", self.offSpeed, self.offExpirationTime, "offhand")
        
        -- Ensure the duration is non-negative
        local duration = self.offExpirationTime - GetTimePrecise()
        if duration > 0 then
            self.offTimer = C_Timer.After(duration, function() self:SwingEnd("offhand") end)
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
                self.mainTimer = C_Timer.After(duration, function() self:SwingEnd("mainhand") end)
            else
                self:SwingEnd("mainhand")
            end
        end
        
        if self.offSpeed > 0 then
            if self.offExpirationTime < now and self.isAttacking then
                self.offExpirationTime = self.offExpirationTime + self.offSpeed
            end
            self:Fire("SWING_TIMER_UPDATE", self.offSpeed, self.offExpirationTime, "offhand")
            
            -- Ensure the duration is non-negative
            local duration = self.offExpirationTime - now
            if duration > 0 then
                self.offTimer = C_Timer.After(duration, function() self:SwingEnd("offhand") end)
            else
                self:SwingEnd("offhand")
            end
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
            self.mainTimer = C_Timer.After(duration, function() self:SwingEnd("mainhand") end)
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
            self.offTimer = C_Timer.After(duration, function() self:SwingEnd("offhand") end)
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
        self:ResetTimers(GetTimePrecise())
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

frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("PLAYER_ENTER_COMBAT")
frame:RegisterEvent("PLAYER_LEAVE_COMBAT")
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
        else
            lib[event](lib, event, ...)
        end
end)
