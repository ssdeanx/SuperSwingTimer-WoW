local _, ns = ...
---@diagnostic disable: undefined-field
local GetAddOnInfo = rawget(_G, "GetAddOnInfo")
local GetTimePreciseSec = rawget(_G, "GetTimePreciseSec")
local GetTime = rawget(_G, "GetTime")
local UnitCastingInfo = rawget(_G, "UnitCastingInfo")
local UnitChannelInfo = rawget(_G, "UnitChannelInfo")

local function EnsurePreciseClockOffset()
    if ns.preciseClockOffset == nil and GetTimePreciseSec and GetTime then
        local preciseNow = GetTimePreciseSec()
        ns.preciseClockOffset = (GetTime() or 0) - preciseNow
    end

    return ns.preciseClockOffset or 0
end

if GetTimePreciseSec and GetTime then
    EnsurePreciseClockOffset()
end

--- Return the addon's canonical clock time.
--  Uses GetTimePreciseSec() aligned to the GetTime() domain so that
--  cooldown, cast, and channel timestamps are directly comparable.
--  Falls back to GetTime() if GetTimePreciseSec is unavailable.
--  @return (number) Current time in seconds, aligned to the GetTime() domain
--  @usage local now = ns.GetAlignedTime()
--  @see ns.RefreshLatencyCache
function ns.GetAlignedTime()
    if GetTimePreciseSec and GetTime then
        return GetTimePreciseSec() + EnsurePreciseClockOffset()
    end

    return GetTime and GetTime() or 0
end

--- Authoritative GetSpellInfo wrapper for Classic/TBC Anniversary (1.15+).
--  Tries the legacy GetSpellInfo() first, then falls back to
--  C_Spell.GetSpellInfo() for modern clients. Both Classic Era and
--  TBC Anniversary are supported.
--  @param spellIdentifier (number|string) Spell ID or localized spell name
--  @return (string|nil) Localized spell name, or nil if not found
--  @usage local name = ns.GetSpellInfo(75)  -- "Auto Shot"
function ns.GetSpellInfo(spellIdentifier)
    if not spellIdentifier then return nil end
    local g = _G.GetSpellInfo
    if g then
        return g(spellIdentifier)
    end
    local C_Spell = _G.C_Spell
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellIdentifier)
        if info then
            return info.name, nil, info.iconID, info.castTime, info.minRange, info.maxRange, info.spellID
        end
    end
    return nil
end

--- Classic/TBC-safe UnitCastingInfo wrapper.
--  Classic clients reliably expose the localized spell name while
--  modern-only spellID returns are optional, so callers should prefer
--  the returned token and only trust spellID when numeric.
--  Falls back to UnitChannelInfo() when no cast is in progress.
--  @param unit (string) Unit token, e.g. "player"
--  @return (string|nil) spellIdOrName, name, startTimeMs, endTimeMs, castId, spellId
--  @usage local token, name = ns.GetUnitCastingSpellInfo("player")
--  @see ns.GetSpellInfo
function ns.GetUnitCastingSpellInfo(unit)
    if type(UnitCastingInfo) ~= "function" or not unit then
        return nil, nil, nil, nil, nil, nil
    end

    local spellName, _, _, startTimeMs, endTimeMs, _, castId, _, spellId = UnitCastingInfo(unit)
    if not spellName and type(UnitChannelInfo) == "function" then
        local channelSpellId
        spellName, _, _, startTimeMs, endTimeMs, _, _, channelSpellId = UnitChannelInfo(unit)
        castId = nil
        spellId = channelSpellId
    end
    if not spellName then
        return nil, nil, nil, nil, nil, nil
    end

    if type(spellId) ~= "number" then
        spellId = nil
    end

    return spellId or spellName, spellName, startTimeMs, endTimeMs, castId, spellId
end

--- Classic/TBC-safe UnitAura wrapper. Normalizes all known client return
--  shapes into a canonical 11-value tuple:
--    name, rank, icon, count, debuffType, duration, expirationTime,
--    unitCaster, isStealable, shouldConsolidate, spellID
--  Handles Classic 1.13.x (9 ret, no icon), Classic 1.15.x (10 ret, icon),
--  TBC Anniversary 2.5.5 (AuraUtil.UnpackAuraData, 15+ ret), and Retail.
--  Missing fields are nil. Intended as the ONLY call site for raw UnitAura
--  in the addon — all callers use this wrapper or ns.UnitBuff/ns.UnitDebuff.
--  @param unit (string) Unit token, e.g. "target"
--  @param index (number) Aura slot index, 1-based
--  @param filter (string|nil) "HELPFUL", "HARMFUL", or nil (all)
--  @return (string|nil) name, (nil) rank, (string|number|nil) icon,
--          (number) count, (string|nil) debuffType, (number|nil) duration,
--          (number|nil) expirationTime, (string|nil) unitCaster,
--          (boolean|nil) isStealable, (number|nil) shouldConsolidate,
--          (number|nil) spellID
--  @usage local name, _, _, _, _, dur, expT, caster, _, _, sId = ns.UnitAura("target", 1, "HARMFUL")
function ns.UnitAura(unit, index, filter)
    if not unit or not index or not UnitAura then return nil end
    local r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11 = UnitAura(unit, index, filter)
    if not r1 then return nil end

    -- Determine shape by examining return values positionally.
    -- Three shapes:
    --   A. Classic 1.13.x:  r3=count(num), r4=debuffType, r9=spellID, r10=nil
    --   B. Classic 1.15.x:  r3=icon(str),  r4=count,       r10=spellID
    --   C. TBC Anniv:       r3=apps(num),  r4=dispelName,  r10=spellID(num), r11=canApplyAura(bool)
    --   D. Retail:          r3=icon(str),  r4=count,       r11=spellID
    -- Final normalized: name, rank/nil, icon, count, debuffType,
    --                   duration, expirationTime, unitCaster,
    --                   isStealable, shouldConsolidate, spellID
    if type(r3) == "string" then
        -- Shape B or D (string icon at r3): r4=count, r5=debuffType,
        -- r6=duration, r7=expTime, r8=caster, r9=stealable
        -- r10=spellID(B) or shouldConsolidate(D), r11=nil(B) or spellID(D)
        return r1, r2, r3, tonumber(r4) or 0, r5, r6, r7, r8, r9, r10,
               type(r11) == "number" and r11 or type(r10) == "number" and r10 or nil
    elseif type(r3) == "number" and type(r10) == "number" then
        -- Shape C (TBC Anniv via UnpackAuraData):
        -- r2=icon(FileID#), r3=applications, r4=dispelName,
        -- r5=duration, r6=expTime, r7=sourceUnit, r8=stealable,
        -- r9=nameplateShowPersonal(bool), r10=spellID, r11=canApplyAura(bool)
        return r1, nil, r2, tonumber(r3) or 0, r4, r5, r6, r7, r8, nil,
               type(r10) == "number" and r10 or nil
    else
        -- Shape A (Classic 1.13.x, no icon):
        -- r3=count, r4=debuffType, r5=duration, r6=expTime,
        -- r7=caster, r8=stealable, r9=spellID
        return r1, nil, nil, tonumber(r3) or 0, r4, r5, r6, r7, r8, nil,
               type(r9) == "number" and r9 or nil
    end
end
--- Convenience: ns.UnitBuff(unit, index) = ns.UnitAura(unit, index, "HELPFUL")
function ns.UnitBuff(unit, index)
    return ns.UnitAura(unit, index, "HELPFUL")
end
--- Convenience: ns.UnitDebuff(unit, index) = ns.UnitAura(unit, index, "HARMFUL")
function ns.UnitDebuff(unit, index)
    return ns.UnitAura(unit, index, "HARMFUL")
end

-- ============================================================
-- UI constants
-- ============================================================
ns.BAR_WIDTH = 240
ns.BAR_HEIGHT = 15
ns.HUNTER_CAST_BAR_HEIGHT = 13
ns.HUNTER_CAST_BAR_GAP = 2
ns.HUNTER_RANGE_HELPER_WIDTH = 7
ns.ROGUE_SLICE_AND_DICE_BAR_HEIGHT = 4
ns.ROGUE_ENERGY_TICK_BAR_WIDTH = 4
ns.WARRIOR_SHIELD_BLOCK_BAR_HEIGHT = 4
ns.HUNTER_RAPID_FIRE_BAR_HEIGHT = 4
ns.CAST_WINDOW = 0.5 -- shared hidden hunter / ranged cast window in TBC

-- ============================================================
-- Spell IDs
-- ============================================================
ns.AUTO_SHOT_ID = 75
ns.AUTO_SHOT_NAME = ns.GetSpellInfo(ns.AUTO_SHOT_ID) or "Auto Shot" or "Shoot"
ns.WING_CLIP_ID = 2974
ns.WING_CLIP_NAME = ns.GetSpellInfo(ns.WING_CLIP_ID) or "Wing Clip"
ns.STEADY_SHOT_ID = 34120
ns.STEADY_SHOT_NAME = ns.GetSpellInfo(ns.STEADY_SHOT_ID) or "Steady Shot"
ns.STEADY_SHOT_CAST_TIME = 1.5                                            -- TBC Steady Shot cast time (unaffected by haste)
ns.STEADY_SHOT_GRACE = 0.5                                                -- Auto Shot fires during the last 0.5s of SS without clipping
ns.HUNTER_READINESS_ID = 23989
ns.HUNTER_READINESS_NAME = ns.GetSpellInfo(ns.HUNTER_READINESS_ID) or "Readiness"
ns.ROGUE_ADRENALINE_RUSH_ID = 13750
ns.ROGUE_ADRENALINE_RUSH_NAME = ns.GetSpellInfo(ns.ROGUE_ADRENALINE_RUSH_ID) or "Adrenaline Rush"
ns.WARRIOR_BLOODTHIRST_ID = 23881
ns.WARRIOR_BLOODTHIRST_NAME = ns.GetSpellInfo(ns.WARRIOR_BLOODTHIRST_ID) or "Bloodthirst"
ns.WARRIOR_WHIRLWIND_ID = 1680
ns.WARRIOR_WHIRLWIND_NAME = ns.GetSpellInfo(ns.WARRIOR_WHIRLWIND_ID) or "Whirlwind"
ns.WARRIOR_OVERPOWER_ID = 7384
ns.WARRIOR_OVERPOWER_NAME = ns.GetSpellInfo(ns.WARRIOR_OVERPOWER_ID) or "Overpower"
ns.DRUID_TIGER_FURY_ID = 5217
ns.DRUID_TIGER_FURY_NAME = ns.GetSpellInfo(ns.DRUID_TIGER_FURY_ID) or "Tiger's Fury"
ns.SHAMAN_STORMSTRIKE_ID = 17364
ns.SHAMAN_STORMSTRIKE_NAME = ns.GetSpellInfo(ns.SHAMAN_STORMSTRIKE_ID) or "Stormstrike"
ns.SHAMANISTIC_RAGE_ID = 30823
ns.SHAMANISTIC_RAGE_NAME = ns.GetSpellInfo(ns.SHAMANISTIC_RAGE_ID) or "Shamanistic Rage"
ns.SHAMAN_FLAME_SHOCK_IDS = {
    [8050] = true,  -- Rank 1
    [8052] = true,  -- Rank 2
    [8053] = true,  -- Rank 3
    [10447] = true, -- Rank 4
    [10448] = true, -- Rank 5
    [29228] = true, -- Rank 6
    [25457] = true  -- Rank 7 (TBC)
}
ns.SHAMAN_FLAME_SHOCK_NAME = ns.GetSpellInfo(8050) or "Flame Shock"

-- Lightning Shield spell IDs (Classic/TBC)
ns.SHAMAN_LIGHTNING_SHIELD_IDS = {
    [324] = true,   -- Rank 1
    [325] = true,   -- Rank 2
    [905] = true,   -- Rank 3
    [945] = true,   -- Rank 4
    [8134] = true,  -- Rank 5
    [10431] = true, -- Rank 6
    [10432] = true, -- Rank 7
    [25469] = true, -- Rank 8 (TBC)
    [25472] = true  -- Rank 6 (TBC)
}
ns.SHAMAN_LIGHTNING_SHIELD_NAME = ns.GetSpellInfo(324) or "Lightning Shield"

-- Water Shield spell IDs (TBC)
ns.SHAMAN_WATER_SHIELD_IDS = {
    [52127] = true, -- Rank 1
    [52129] = true, -- Rank 2
    [52131] = true, -- Rank 3
    [24398] = true, -- alternate aura mapping observed on some clients
    [33736] = true, -- alternate aura mapping observed on some clients
    [33737] = true, -- alternate aura mapping observed on some clients
    [34827] = true, -- alternate aura mapping observed on some clients
    [57960] = true  -- legacy-safe fallback mapping
}
ns.SHAMAN_WATER_SHIELD_NAME = ns.GetSpellInfo(52127) or ns.GetSpellInfo(57960) or "Water Shield"

do
    local lightningNames = {}
    for spellId in pairs(ns.SHAMAN_LIGHTNING_SHIELD_IDS) do
        local spellName = ns.GetSpellInfo(spellId)
        if spellName then
            lightningNames[spellName] = true
        end
    end
    if ns.SHAMAN_LIGHTNING_SHIELD_NAME then
        lightningNames[ns.SHAMAN_LIGHTNING_SHIELD_NAME] = true
    end
    ns.SHAMAN_LIGHTNING_SHIELD_NAMES = lightningNames

    local waterNames = { ["Water Shield"] = true, ["Mana Shield"] = true }
    for spellId in pairs(ns.SHAMAN_WATER_SHIELD_IDS) do
        local spellName = ns.GetSpellInfo(spellId)
        if spellName then
            waterNames[spellName] = true
        end
    end
    if ns.SHAMAN_WATER_SHIELD_NAME then
        waterNames[ns.SHAMAN_WATER_SHIELD_NAME] = true
    end
    ns.SHAMAN_WATER_SHIELD_NAMES = waterNames
end
ns.ROGUE_SLICE_AND_DICE_ID = 5171
ns.SHIELD_BLOCK_ID = 2565
ns.SHIELD_BLOCK_NAME = ns.GetSpellInfo(ns.SHIELD_BLOCK_ID) or "Shield Block"
-- Shield Wall (Warrior - 50% damage reduction, 10s duration)
ns.SHIELD_WALL_ID = 871
ns.SHIELD_WALL_NAME = ns.GetSpellInfo(ns.SHIELD_WALL_ID) or "Shield Wall"
-- Last Stand (Warrior - 30% HP increase, 20s duration)
ns.LAST_STAND_ID = 12975
ns.LAST_STAND_NAME = ns.GetSpellInfo(ns.LAST_STAND_ID) or "Last Stand"
-- Spell Reflection (Warrior TBC - reflects spells, 5s duration)
ns.SPELL_REFLECTION_ID = 23920
ns.SPELL_REFLECTION_NAME = ns.GetSpellInfo(ns.SPELL_REFLECTION_ID) or "Spell Reflection"
ns.RAVAGE_ID = 6785
ns.RAVAGE_NAME = ns.GetSpellInfo(ns.RAVAGE_ID) or "Ravage"
-- Deep Wounds (Warrior bleed debuff from Mortal Strike talent crit proc)
ns.DEEP_WOUND_IDS = { [12721] = true }
ns.DEEP_WOUND_NAME = ns.GetSpellInfo(12721) or "Deep Wound"
-- Judgement of the Crusader (Paladin Ret debuff on target - Holy damage taken + crit chance)
ns.PALADIN_JUDGEMENT_CRUSADER_IDS = { [21183] = true }
ns.PALADIN_JUDGEMENT_CRUSADER_NAME = ns.GetSpellInfo(21183) or "Judgement of the Crusader"
-- Seal of Vengeance / Seal of Corruption (Ret Paladin stacking Holy DoT debuff on target)
-- Each stack level has a separate spell ID; all share the same display name.
ns.PALADIN_SEAL_VENGEANCE_IDS = {
    [31803] = true,  -- Seal of Vengeance 1 stack
    [31804] = true,  -- Seal of Vengeance 2 stacks
    [53736] = true,  -- Seal of Vengeance 3 stacks
    [53737] = true,  -- Seal of Vengeance 4 stacks
    [53738] = true,  -- Seal of Vengeance 5 stacks
    [53739] = true,  -- Seal of Corruption 1 stack
    [53740] = true,  -- Seal of Corruption 2 stacks
    [53741] = true,  -- Seal of Corruption 3 stacks
    [53742] = true,  -- Seal of Corruption 4 stacks
    [53743] = true,  -- Seal of Corruption 5 stacks
}
ns.PALADIN_SEAL_VENGEANCE_NAME = ns.GetSpellInfo(31803) or ns.GetSpellInfo(53739) or "Seal of Vengeance"
-- Mangle (Druid Feral debuff - Cat/Bear TBC talent)
ns.DRUID_MANGLE_IDS = { [33983] = true, [33987] = true }
ns.DRUID_MANGLE_NAME = ns.GetSpellInfo(33983) or ns.GetSpellInfo(33987) or "Mangle"
-- Rip (Druid Feral cat finisher bleed)
ns.DRUID_RIP_IDS = { [1079] = true, [9492] = true, [9493] = true, [9752] = true, [9894] = true, [9896] = true, [27008] = true }
ns.DRUID_RIP_NAME = ns.GetSpellInfo(27008) or ns.GetSpellInfo(1079) or "Rip"
-- Rake (Druid Feral Cat bleed, 9s duration)
ns.DRUID_RAKE_IDS = { [1822] = true, [1823] = true, [1824] = true, [9907] = true, [27006] = true }
ns.DRUID_RAKE_NAME = ns.GetSpellInfo(1822) or "Rake"
-- Rupture (Rogue finisher bleed)
ns.ROGUE_RUPTURE_IDS = { [1943] = true, [8637] = true, [8639] = true, [8640] = true, [11273] = true, [11274] = true, [26867] = true }
ns.ROGUE_RUPTURE_NAME = ns.GetSpellInfo(26867) or ns.GetSpellInfo(1943) or "Rupture"
-- Serpent Sting (Hunter nature DoT)
ns.HUNTER_SERPENT_STING_IDS = {
    [1978] = true, [13549] = true, [13550] = true, [13551] = true, [13552] = true,
    [13553] = true, [13554] = true, [13555] = true, [27019] = true
}
ns.HUNTER_SERPENT_STING_NAME = ns.GetSpellInfo(27019) or "Serpent Sting"
-- Concussion Shot (Hunter ranged snare debuff)
ns.HUNTER_CONCUSSION_SHOT_IDS = { [5116] = true, [13585] = true, [13586] = true, [13587] = true, [13588] = true, [13589] = true, [13590] = true, [27068] = true }
ns.HUNTER_CONCUSSION_SHOT_NAME = ns.GetSpellInfo(5116) or "Concussion Shot"
-- Misdirection (Hunter threat-transfer buff)
ns.HUNTER_MISDIRECTION_ID = 34477
ns.HUNTER_MISDIRECTION_NAME = ns.GetSpellInfo(34477) or "Misdirection"
-- Wing Clip (Hunter melee snare) — spell ID 2974 already defined for cast tracking
ns.HUNTER_WING_CLIP_NAME = ns.GetSpellInfo(2974) or "Wing Clip"
-- Immolation Trap (Hunter fire trap debuff on target)
ns.HUNTER_IMMOLATION_TRAP_IDS = { [13795] = true, [14302] = true }
ns.HUNTER_IMMOLATION_TRAP_NAME = ns.GetSpellInfo(13795) or "Immolation Trap"
-- Explosive Trap (Hunter fire trap debuff on target)
ns.HUNTER_EXPLOSIVE_TRAP_IDS = { [13813] = true, [14303] = true, [14304] = true, [14305] = true }
ns.HUNTER_EXPLOSIVE_TRAP_NAME = ns.GetSpellInfo(13813) or "Explosive Trap"
-- Freezing Trap (Hunter CC trap debuff on target - Freezing Trap Effect)
ns.HUNTER_FREEZING_TRAP_IDS = { [1499] = true, [14310] = true, [14311] = true, [3355] = true, [14308] = true, [14309] = true }
ns.HUNTER_FREEZING_TRAP_NAME = ns.GetSpellInfo(1499) or "Freezing Trap"
-- Frost Trap (Hunter slow trap debuff on target)
ns.HUNTER_FROST_TRAP_IDS = { [13809] = true, [13810] = true }
ns.HUNTER_FROST_TRAP_NAME = ns.GetSpellInfo(13809) or "Frost Trap"
-- Sunder Armor (Warrior armor reduction debuff, stacks 1-5)
ns.WARRIOR_SUNDER_ARMOR_IDS = { [7386] = true, [7405] = true, [8380] = true, [11596] = true, [11597] = true, [25225] = true }
ns.WARRIOR_SUNDER_ARMOR_NAME = ns.GetSpellInfo(7386) or "Sunder Armor"
-- Thunder Clap (Warrior attack speed reduction debuff)
ns.WARRIOR_THUNDER_CLAP_IDS = {}
for _, id in ipairs({ 6343, 8198, 8204, 8205, 11580, 11581 }) do
    ns.WARRIOR_THUNDER_CLAP_IDS[id] = true
end
ns.WARRIOR_THUNDER_CLAP_NAME = ns.GetSpellInfo(6343) or "Thunder Clap"
-- Demoralizing Shout (Warrior attack power reduction debuff)
ns.WARRIOR_DEMO_SHOUT_IDS = {}
for _, id in ipairs({ 1160, 6190, 11554, 11555, 11556 }) do
    ns.WARRIOR_DEMO_SHOUT_IDS[id] = true
end
ns.WARRIOR_DEMO_SHOUT_NAME = ns.GetSpellInfo(1160) or "Demoralizing Shout"
-- Expose Armor (Rogue armor reduction finisher)
ns.ROGUE_EXPOSE_ARMOR_IDS = { [8647] = true, [8649] = true, [8650] = true, [11197] = true, [11198] = true, [26996] = true }
ns.ROGUE_EXPOSE_ARMOR_NAME = ns.GetSpellInfo(8647) or "Expose Armor"
ns.HUNTER_CAST_SPELLS = {
    [75] = true,    -- Auto Shot
    [2643] = true,  -- Multi-Shot rank 1
    [14288] = true, -- Multi-Shot rank 2
    [14289] = true, -- Multi-Shot rank 3
    [14290] = true, -- Multi-Shot rank 4
    [25294] = true, -- Multi-Shot rank 5
    [27021] = true, -- Multi-Shot rank 6
    [34120] = true, -- Steady Shot (TBC)
    [19434] = true, -- Aimed Shot rank 1
    [20900] = true, -- Aimed Shot rank 2
    [20901] = true, -- Aimed Shot rank 3
    [20902] = true, -- Aimed Shot rank 4
    [20903] = true, -- Aimed Shot rank 5
    [20904] = true, -- Aimed Shot rank 6
    [27065] = true  -- Aimed Shot rank 7
}

ns.HUNTER_CAST_SPELL_NAMES = {}
if true then
    for spellId in pairs(ns.HUNTER_CAST_SPELLS) do
        local spellName = ns.GetSpellInfo(spellId)
        if spellName then
            ns.HUNTER_CAST_SPELL_NAMES[spellName] = true
        end
    end
end
ns.HUNTER_CAST_SPELL_NAMES["Volley"] = true

ns.HUNTER_ACTUAL_CAST_SPELLS = {
    [34120] = true, -- Steady Shot (TBC)
    [19434] = true, -- Aimed Shot rank 1
    [20900] = true, -- Aimed Shot rank 2
    [20901] = true, -- Aimed Shot rank 3
    [20902] = true, -- Aimed Shot rank 4
    [20903] = true, -- Aimed Shot rank 5
    [20904] = true, -- Aimed Shot rank 6
    [27065] = true  -- Aimed Shot rank 7
}

ns.HUNTER_ACTUAL_CAST_SPELL_NAMES = {}
if true then
    for spellId in pairs(ns.HUNTER_ACTUAL_CAST_SPELLS) do
        local spellName = ns.GetSpellInfo(spellId)
        if spellName then
            ns.HUNTER_ACTUAL_CAST_SPELL_NAMES[spellName] = true
        end
    end
end
ns.HUNTER_ACTUAL_CAST_SPELL_NAMES["Volley"] = true

--- Check if a spell value corresponds to the Auto Shot spell.
--  Accepts both numeric IDs and localized spell names.
--  @param spellValue (number|string|nil) Spell ID or name to check
--  @return (boolean) true if the value matches Auto Shot
function ns.IsAutoShotSpell(spellValue)
    if spellValue == nil then
        return false
    end

    local spellId = tonumber(spellValue)
    return spellValue == ns.AUTO_SHOT_ID or spellValue == ns.AUTO_SHOT_NAME or (spellId and spellId == ns.AUTO_SHOT_ID)
end

--- Check if a spell value is a hunter casting spell (Auto Shot, Multi-Shot,
--  Steady Shot, Aimed Shot, or Volley). Accepts IDs and names.
--  @param spellValue (number|string|nil) Spell ID or name
--  @return (boolean) true if the value is a hunter cast spell
--  @see ns.IsAutoShotSpell
function ns.IsHunterCastSpell(spellValue)
    if spellValue == nil then
        return false
    end

    local spellId = tonumber(spellValue)
    return (ns.HUNTER_CAST_SPELLS[spellValue] == true or (spellId and ns.HUNTER_CAST_SPELLS[spellId] == true)
        or ns.HUNTER_CAST_SPELL_NAMES[spellValue] == true)
end

--- Check if a spell value is a hunter actual cast spell (Steady Shot,
--  Aimed Shot, or Volley — excludes Auto Shot and Multi-Shot).
--  @param spellValue (number|string|nil) Spell ID or name
--  @return (boolean) true if the value is an actual cast spell
function ns.IsHunterActualCastSpell(spellValue)
    if spellValue == nil then
        return false
    end

    local spellId = tonumber(spellValue)
    return (ns.HUNTER_ACTUAL_CAST_SPELLS[spellValue] == true or (spellId
            and ns.HUNTER_ACTUAL_CAST_SPELLS[spellId] == true) or ns.HUNTER_ACTUAL_CAST_SPELL_NAMES[spellValue] == true)
end

-- ============================================================
-- Multi-Shot detection (TBC instant-shot hidden window)
-- ============================================================
-- Multi-Shot is instant in TBC (0 cast time) but has a ~0.5s hidden
-- shot-firing window identical to Auto Shot's, during which the next
-- Auto Shot is delayed. Treat it as a first-class spell with dedicated
-- detection, label, and clip-safety tinting.

ns.MULTI_SHOT_IDS = {
    [2643] = true,  -- Multi-Shot rank 1
    [14288] = true, -- Multi-Shot rank 2
    [14289] = true, -- Multi-Shot rank 3
    [14290] = true, -- Multi-Shot rank 4
    [25294] = true, -- Multi-Shot rank 5 (TBC)
    [27021] = true  -- Multi-Shot rank 6 (TBC)
}

ns.MULTI_SHOT_NAMES = {}
if true then
    for spellId in pairs(ns.MULTI_SHOT_IDS) do
        local spellName = ns.GetSpellInfo(spellId)
        if spellName then
            ns.MULTI_SHOT_NAMES[spellName] = true
        end
    end
end

--- Check if a spell value is Multi-Shot (all TBC ranks).
--  Accepts numeric IDs and localized names.
--  @param spellValue (number|string|nil) Spell ID or name
--  @return (boolean) true if the value is Multi-Shot
function ns.IsMultiShotSpell(spellValue)
    if spellValue == nil then
        return false
    end

    local spellId = tonumber(spellValue)
    return (ns.MULTI_SHOT_IDS[spellValue] == true or (spellId and ns.MULTI_SHOT_IDS[spellId] == true)
        or ns.MULTI_SHOT_NAMES[spellValue] == true)
end

-- Paladin seal spell IDs used for UnitAura-aware breakpoint logic.
-- The lookup prefers verified TBC/Classic spell IDs and also keeps literal
-- seal names so aura detection stays resilient across rank gaps and client
-- spell-ID availability.
ns.PALADIN_SEAL_FAMILIES = {
    COMMAND = {
        label = "Seal of Command",
        ids = { 20375, 20915, 20918, 20919, 20920, 27170 },
        names = { "Seal of Command" }
    },
    CORRUPTION = {
        label = "Seal of Corruption",
        ids = { 348704 },
        names = { "Seal of Corruption" }
    },
    BLOOD = {
        label = "Seal of Blood",
        ids = { 31892 },
        names = { "Seal of Blood" }
    },
    MARTYR = {
        label = "Seal of the Martyr",
        ids = { 348700 },
        names = { "Seal of the Martyr" }
    },
    VENGEANCE = {
        label = "Seal of Vengeance",
        ids = { 31801 },
        names = { "Seal of Vengeance" }
    },
    JUSTICE = {
        label = "Seal of Justice",
        ids = { 20165, 31895 },
        names = { "Seal of Justice" }
    },
    WISDOM = {
        label = "Seal of Wisdom",
        ids = { 20166, 20356, 20357, 27166 },
        names = { "Seal of Wisdom" }
    },
    RIGHTEOUSNESS = {
        label = "Seal of Righteousness",
        ids = { 20154, 20287, 20288, 20289, 20290, 20291, 20292, 20293, 27155 },
        names = { "Seal of Righteousness" }
    },
    LIGHT = {
        label = "Seal of Light",
        ids = { 20166, 20347, 20348, 20349, 27160 },
        names = { "Seal of Light" }
    },
    CRUSADER = {
        label = "Seal of the Crusader",
        ids = { 21082, 20162, 20305, 20306, 20307, 20308, 27158 },
        names = { "Seal of the Crusader" }
    }
}

ns.PALADIN_SEAL_LOOKUP = {}
ns.PALADIN_SEAL_NAME_LOOKUP = {}
-- Twist families identify which active seal should trigger the end-of-swing
-- twist zone and reseal marker. You can twist FROM Command or Righteousness,
-- and when Blood/Martyr is active you're mid-cycle and still need the zone
-- to time the next Command → Blood resequence.
ns.PALADIN_SEAL_TWIST_FAMILIES = {
    COMMAND = true,       -- twist to Blood/Martyr in 0.4s window
    RIGHTEOUSNESS = true, -- twist to Command in 0.4s window
    BLOOD = true,         -- mid-cycle: reseal Command at GCD, Blood at window
    MARTYR = true         -- mid-cycle: reseal at GCD, twist at window
}

-- PALADIN_JUDGEMENT_SPELLS: spell IDs for the Judgement ability.
-- These are the spells cast when a paladin presses Judgement.
-- The actual effect depends on the currently active seal.
ns.PALADIN_JUDGEMENT_SPELLS = {}
for _, id in ipairs({ 20271, 20272, 34413, 54158 }) do
    ns.PALADIN_JUDGEMENT_SPELLS[id] = true
end
ns.PALADIN_JUDGEMENT_COOLDOWN = 10 -- base CD in seconds; talents reduce it

ns.PALADIN_SEAL_FAMILY_ORDER = {
    "COMMAND", "CORRUPTION", "BLOOD", "MARTYR", "VENGEANCE", "JUSTICE", "WISDOM", "RIGHTEOUSNESS", "LIGHT", "CRUSADER"
}

for _, familyKey in ipairs(ns.PALADIN_SEAL_FAMILY_ORDER) do
    local family = ns.PALADIN_SEAL_FAMILIES[familyKey]
    if family then
        for _, spellName in ipairs(family.names or {}) do
            if not ns.PALADIN_SEAL_NAME_LOOKUP[spellName] then
                ns.PALADIN_SEAL_NAME_LOOKUP[spellName] = familyKey
            end
            local localizedName = ns.GetSpellInfo and ns.GetSpellInfo(spellName)
            if localizedName and not ns.PALADIN_SEAL_NAME_LOOKUP[localizedName] then
                ns.PALADIN_SEAL_NAME_LOOKUP[localizedName] = familyKey
            end
        end

        for _, spellId in ipairs(family.ids) do
            if not ns.PALADIN_SEAL_LOOKUP[spellId] then
                ns.PALADIN_SEAL_LOOKUP[spellId] = familyKey
            end

            local spellName = ns.GetSpellInfo and ns.GetSpellInfo(spellId)
            if spellName and not ns.PALADIN_SEAL_NAME_LOOKUP[spellName] then
                ns.PALADIN_SEAL_NAME_LOOKUP[spellName] = familyKey
            end
        end
    end
end

function ns.GetPaladinSealFamilyBySpellId(spellId)
    if not spellId then
        return nil
    end
    return ns.PALADIN_SEAL_LOOKUP and ns.PALADIN_SEAL_LOOKUP[spellId] or nil
end

function ns.GetPaladinSealFamilyByAuraName(auraName)
    if not auraName then
        return nil
    end
    return ns.PALADIN_SEAL_NAME_LOOKUP and ns.PALADIN_SEAL_NAME_LOOKUP[auraName] or nil
end

-- Per-seal static color map (used for seal-based MH bar tinting)
-- These are defaults; user can override per-seal in SavedVariables.
ns.PALADIN_SEAL_COLORS = {
    COMMAND = { r = 1.00, g = 0.85, b = 0.00, a = 1 },
    BLOOD = { r = 0.80, g = 0.10, b = 0.10, a = 1 },
    MARTYR = { r = 0.50, g = 0.30, b = 0.90, a = 1 },
    VENGEANCE = { r = 1.00, g = 0.60, b = 0.10, a = 1 },
    CORRUPTION = { r = 0.85, g = 0.20, b = 0.60, a = 1 },
    JUSTICE = { r = 0.60, g = 0.60, b = 0.60, a = 1 },
    WISDOM = { r = 0.30, g = 0.50, b = 1.00, a = 1 },
    RIGHTEOUSNESS = { r = 1.00, g = 0.95, b = 0.70, a = 1 },
    LIGHT = { r = 0.20, g = 0.80, b = 0.30, a = 1 },
    CRUSADER = { r = 0.60, g = 0.80, b = 1.00, a = 1 }
}

-- PALADIN_SEAL_COLOR_KEYS: list of color keys under DB_DEFAULTS.colors for per-seal customization.
ns.PALADIN_SEAL_COLOR_KEYS = {}
for familyKey in pairs(ns.PALADIN_SEAL_COLORS) do
    ns.PALADIN_SEAL_COLOR_KEYS[#ns.PALADIN_SEAL_COLOR_KEYS + 1] = "sealColor" .. familyKey
end
table.sort(ns.PALADIN_SEAL_COLOR_KEYS)

-- Next-Melee-Attack abilities stay separated by class. Landed-hit reset
-- detection is handled in the state module against the active class table.

local function addSpellNamesToLookup(lookup)
    if type(ns.GetSpellInfo) ~= "function" then
        return
    end

    local names = {}
    for spellId in pairs(lookup) do
        if type(spellId) == "number" then
            local spellName = ns.GetSpellInfo(spellId)
            if spellName then
                names[#names + 1] = spellName
            end
        end
    end

    for _, spellName in ipairs(names) do
        lookup[spellName] = true
    end
end

-- Heroic Strike (Warrior)
ns.WARRIOR_HEROIC_STRIKE_SPELLS = {}
for _, id in ipairs({ 78, 284, 285, 1608, 11564, 11565, 11566, 11567, 25286, 29707, 30324 }) do
    ns.WARRIOR_HEROIC_STRIKE_SPELLS[id] = true
end

-- Cleave (Warrior)
ns.WARRIOR_CLEAVE_SPELLS = {}
for _, id in ipairs({ 845, 7369, 11608, 11609, 20569, 25231 }) do
    ns.WARRIOR_CLEAVE_SPELLS[id] = true
end

-- Maul (Druid — Bear)
ns.DRUID_MAUL_SPELLS = {}
for _, id in ipairs({ 6807, 6808, 6809, 8972, 9745, 9880, 9881, 26996, 48479, 48480 }) do
    ns.DRUID_MAUL_SPELLS[id] = true
end

-- Raptor Strike (Hunter)
ns.HUNTER_RAPTOR_STRIKE_SPELLS = {}
for _, id in ipairs({ 2973, 14260, 14261, 14262, 14263, 14264, 14265, 14266, 27014 }) do
    ns.HUNTER_RAPTOR_STRIKE_SPELLS[id] = true
end

-- Spell-ID rules adapted from the reference swingtimer library.
-- RESET_SWING_SPELLS: casts that should reset melee/ranged swing flow.
-- Registered with BOTH numeric IDs and localized names so lookups work on
-- Classic Era (ID-based CLEU) and TBC Anniversary (name-based CLEU).
ns.RESET_SWING_SPELLS = {}
local function registerResetSwingSpells(ids)
    for _, id in ipairs(ids) do
        ns.RESET_SWING_SPELLS[id] = true
        local name = ns.GetSpellInfo(id)
        if name then
            ns.RESET_SWING_SPELLS[name] = true
        end
    end
end

registerResetSwingSpells({
    16589,
    2645,
    51533,
    2764,
    3018,
    5384,
    5019,
    20066, -- Repentance
    853,
    5588,
    5589,
    10308, -- Hammer of Justice (TBC ranks 1-4)
    2812,
    10318,
    27139  -- Holy Wrath (TBC ranks 1-3)
})

-- NO_RESET_SWING_SPELLS: casts that should not reset swing state.
ns.NO_RESET_SWING_SPELLS = {}
local function registerNoResetSwingSpells(ids)
    for _, id in ipairs(ids) do
        ns.NO_RESET_SWING_SPELLS[id] = true
        local name = ns.GetSpellInfo(id)
        if name then
            ns.NO_RESET_SWING_SPELLS[name] = true
        end
    end
end

registerNoResetSwingSpells({
    30310,
    30311,
    23063,
    4054,
    4064,
    4061,
    8331,
    4065,
    4066,
    4062,
    4067,
    4068,
    23000,
    12421,
    4069,
    12562,
    12543,
    19769,
    19784,
    19821,
    34120,
    27022,
    2643,
    14288,
    14289,
    14290,
    25294,
    27021,
    19434,
    20900,
    20901,
    20902,
    20903,
    20904,
    27065
})

-- PAUSE_SWING_SPELLS: casts that should pause and then resume swing timing.
-- Slam uses the pause/extend path rather than a hard MH reset.
ns.PAUSE_SWING_SPELLS = {}
for _, id in ipairs({ 1464, 8820, 11604, 11605, 25241, 25242 }) do
    ns.PAUSE_SWING_SPELLS[id] = true
    local name = ns.GetSpellInfo(id)
    if name then
        ns.PAUSE_SWING_SPELLS[name] = true
    end
end

-- RESET_RANGED_SWING_SPELLS: landed spell effects that should restart ranged.
ns.RESET_RANGED_SWING_SPELLS = {}
for _, id in ipairs({ 14295, 11925, 11951 }) do
    ns.RESET_RANGED_SWING_SPELLS[id] = true
    local name = ns.GetSpellInfo(id)
    if name then
        ns.RESET_RANGED_SWING_SPELLS[name] = true
    end
end

addSpellNamesToLookup(ns.PALADIN_JUDGEMENT_SPELLS)
addSpellNamesToLookup(ns.WARRIOR_HEROIC_STRIKE_SPELLS)
addSpellNamesToLookup(ns.WARRIOR_CLEAVE_SPELLS)
addSpellNamesToLookup(ns.DRUID_MAUL_SPELLS)
addSpellNamesToLookup(ns.HUNTER_RAPTOR_STRIKE_SPELLS)
addSpellNamesToLookup(ns.RESET_SWING_SPELLS)
addSpellNamesToLookup(ns.NO_RESET_SWING_SPELLS)
addSpellNamesToLookup(ns.PAUSE_SWING_SPELLS)
addSpellNamesToLookup(ns.RESET_RANGED_SWING_SPELLS)
addSpellNamesToLookup(ns.WARRIOR_THUNDER_CLAP_IDS)
addSpellNamesToLookup(ns.WARRIOR_DEMO_SHOUT_IDS)

-- Druid form aura IDs (trigger MH timer reset on apply)
ns.DRUID_FORM_IDS = {
    [768] = "Cat",       -- Cat Form
    [5487] = "Bear",     -- Bear Form
    [9634] = "DireBear", -- Dire Bear Form
    [24858] = "Moonkin"  -- Moonkin Form (TBC)
}

-- Druid form bar colors (form ID -> color). Uses GetShapeshiftForm() return values.
ns.DRUID_FORM_COLORS = {
    [0] = nil,                              -- No form / Caster -> keep default
    [1] = { r = 0.80, g = 0.15, b = 0.10 }, -- Bear / Dire Bear -> red
    [2] = { r = 0.90, g = 0.70, b = 0.10 }, -- Cat -> gold/orange
    [4] = { r = 0.30, g = 0.55, b = 0.90 }  -- Moonkin -> blue
}

-- Shaman weaving spell groups.
-- IDs are listed from low rank to high rank; runtime selection resolves the
-- highest known rank for the active character.
ns.WEAVE_SPELL_FAMILY_COLORS = {
    LB = { r = 0.45, g = 0.75, b = 1.00, a = 1 },  -- light blue
    CL = { r = 0.15, g = 0.45, b = 0.95, a = 1 },  -- dark blue
    HW = { r = 0.25, g = 0.90, b = 0.35, a = 1 },  -- green
    LHW = { r = 0.55, g = 1.00, b = 0.55, a = 1 }, -- light green
    CH = { r = 1.00, g = 0.90, b = 0.20, a = 1 }   -- yellow
}

ns.WEAVE_SPELL_GROUPS = {
    {
        abbrev = "LB",
        label = "Lightning Bolt",
        ids = { 403, 529, 548, 915, 943, 6041, 10391, 10392, 15207, 15208, 25448, 25449 }
    },
    { abbrev = "CL", label = "Chain Lightning", ids = { 421, 930, 2860, 10605, 25439, 25442 } },
    {
        abbrev = "HW",
        label = "Healing Wave",
        ids = { 331, 332, 547, 913, 939, 959, 8005, 10395, 10396, 25357, 25391, 25396 }
    },
    { abbrev = "LHW", label = "Lesser Healing Wave", ids = { 8004, 8008, 8010, 10466, 10467, 10468, 25420 } },
    { abbrev = "CH", label = "Chain Heal", ids = { 1064, 10622, 10623, 25422, 25423 } }
}

-- ============================================================
-- Class configuration
-- ============================================================
-- Determines which bars to create and which events to register.
ns.CLASS_CONFIG = {
    HUNTER = { ranged = true, melee = true, dualWield = false, hunterCastBar = true },
    WARRIOR = { ranged = false, melee = true, dualWield = true },
    ROGUE = { ranged = false, melee = true, dualWield = true },
    PALADIN = { ranged = false, melee = true, dualWield = false },
    SHAMAN = { ranged = false, melee = true, dualWield = true },
    DRUID = { ranged = false, melee = true, dualWield = false },
    MAGE = { ranged = false, melee = false, dualWield = false },
    PRIEST = { ranged = false, melee = false, dualWield = false },
    WARLOCK = { ranged = false, melee = false, dualWield = false }
}

-- ============================================================
-- SavedVariables defaults
-- ============================================================
ns.DB_DEFAULTS = {
    version = 56,
    showMH = true,
    showOH = true,
    showRanged = true,
    showHunterRangeHelper = true,
    showEnemy = true,
    showRogueSinisterAssist = true,
    showRogueEnergyTick = true,
    showRogueComboPoints = true,
    showRogueSliceAndDice = true,
    showWeaveAssist = true,
    showPaladinSealColor = true,
    showPaladinSealLabel = true,
    showPaladinJudgementMarker = true,
    showPaladinTwistFlash = true,
    showWarriorRageBar = true,
    showDruidEnergyTickBar = true,
    showWarriorRageProtection = true,
    showWarriorShieldBlockBar = true,
    showSwingFlash = true,
    showGcdTicker = true,
    showRogueEnergyCountdown = true,
    -- Phase 2 defaults (v39→v40)
    showHunterRapidFireBar = true,
    showHunterBuffIcons = true,
    showWarriorFlurryCounter = true,
    showWarriorDeepWoundsBar = true,
    showDruidMangleBar = true,
    showDruidRipBar = true,
    showDruidRakeBar = true,
    showDruidBuffIcons = true,
    druidBuffIconSize = 25,
    showRogueRuptureBar = true,
    showHunterSerpentStingBar = true,
    showPaladinJudgementBar = true,
    showPaladinSealVengeanceBar = true,
    showRogueAdrenalineRushBar = true,
    showShamanWindfuryIcd = true,
    showShamanLightningTracker = true,
    showShamanFlameShockBar = true,
    showShamanBuffIcons = true,
    showWarriorBuffIcons = true,
    showPaladinBuffIcons = true,
    showRogueBuffIcons = true,
    showHunterWingClipBar = true,
    showHunterConcussionShotBar = true,
    showHunterImmolationTrapBar = true,
    showHunterExplosiveTrapBar = true,
    showHunterFreezingTrapBar = true,
    showHunterFrostTrapBar = true,
    showWarriorSunderArmorBar = true,
    showRogueExposeArmorBar = true,
    useClassColors = true,
    weaveSpellFamilies = {

        LB = true,
        CL = true,
        HW = true,
        LHW = true,
        CH = true
    },
    indicatorBlendMode = "ADD",
    barWidth = 240,
    barHeight = 15,
    hunterCastBarHeight = 13,
    rogueSliceAndDiceBarHeight = 4,
    rogueEnergyTickBarWidth = 4,
    druidEnergyTickBarWidth = 4,
    warriorShieldBlockBarHeight = 4,
    hunterRapidFireBarHeight = 4,
    hunterRangeHelperWidth = 7,
    hunterBuffIconSize = 25,
    shamanBuffIconSize = 25,
    warriorBuffIconSize = 25,
    rogueBuffIconSize = 25,
    paladinBuffIconSize = 25,
    rogueAdrenalineRushBarHeight = 4,
    shamanLightningTrackerGap = 6,
    -- Global scale multiplier (0.5x–3.0x): proportionally scales all bars, icons, and fonts
    globalScale = 1.0,
    barTexture = "Interface\\AddOns\\SuperSwingTimer\\Media\\statusbar\\MerfinMain.tga",
    rangedBarTexture = "Interface\\AddOns\\SuperSwingTimer\\Media\\statusbar\\MerfinMain.tga",
    barTextureLayer = "ARTWORK",
    sparkTexture = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Square_FullWhite",
    sparkTextureLayer = "OVERLAY",
    weaveSparkTexture = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Square_FullWhite",
    weaveSparkTextureLayer = "OVERLAY",
    weaveSparkWidth = 3,
    weaveSparkHeight = 15,
    weaveSparkAlpha = 0.95,
    sparkColor = { r = 1, g = 1, b = 1, a = 1 },
    weaveTriangleTopTexture = "Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Arrow",
    weaveTriangleBottomTexture = "Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Arrow",
    weaveTriangleTextureLayer = "OVERLAY",
    weaveTriangleSize = 6,
    weaveTriangleGap = 1,
    weaveTriangleAlpha = 1,
    weaveMarkerLayer = "OVERLAY",
    sparkWidth = 3,
    sparkHeight = 15,
    barBorderSize = 1,
    barBackgroundAlpha = 0.4,
    barBackgroundColor = { r = 0, g = 0, b = 0, a = 0.4 },
    barBorderColor = { r = 0, g = 0, b = 0, a = 1 },
    sparkAlpha = 1,
    showAdvanced = false,
    minimalMode = false,
    lockBars = false,
    colors = {
        mh = { r = 0.25, g = 0.72, b = 1.00, a = 1 },
        oh = { r = 0.25, g = 0.72, b = 1.00, a = 1 },
        ranged = { r = 0.25, g = 0.72, b = 1.00, a = 1 },
        hunterCastBar = { r = 0.35, g = 0.65, b = 0.95, a = 1 },
        hunterRangeMelee = { r = 0.20, g = 0.85, b = 0.25, a = 1 },
        hunterRangeSweetSpot = { r = 0.98, g = 0.82, b = 0.18, a = 1 },
        hunterRangeRanged = { r = 0.20, g = 0.55, b = 1.00, a = 1 },
        hunterRangeOutOfRange = { r = 0.50, g = 0.50, b = 0.50, a = 1 },
        autoShotSafe = { r = 0.2, g = 0.78, b = 0.25, a = 0.4 },
        autoShotUnsafe = { r = 1, g = 0, b = 0, a = 0.4 },
        enemy = { r = 1, g = 0, b = 0, a = 1 },
        rogueSinister = { r = 1, g = 0, b = 0, a = 0.35 },
        rogueEnergyTick = { r = 1.0, g = 0.82, b = 0.18, a = 1 },
        druidEnergyTick = { r = 1.0, g = 0.82, b = 0.18, a = 1 },
        rogueEnergyTotal = { r = 0.98, g = 0.90, b = 0.24, a = 0.9 },
        rogueComboPoints = { r = 1.0, g = 0.18, b = 0.12, a = 0.95 },
        rogueSliceAndDice = { r = 0.95, g = 0.82, b = 0.22, a = 0.95 },
        sealTwist = { r = 1, g = 0, b = 0, a = 0.35 },
        -- Per-seal colors for seal-based MH bar tinting.
		-- Keyed by seal family name (COMMAND, BLOOD, MARTYR, etc.)
        sealColorCOMMAND = { r = 1.00, g = 0.85, b = 0.00, a = 1 },
        sealColorBLOOD = { r = 0.80, g = 0.10, b = 0.10, a = 1 },
        sealColorMARTYR = { r = 0.50, g = 0.30, b = 0.90, a = 1 },
        sealColorVENGEANCE = { r = 1.00, g = 0.60, b = 0.10, a = 1 },
        sealColorCORRUPTION = { r = 0.85, g = 0.20, b = 0.60, a = 1 },
        sealColorJUSTICE = { r = 0.60, g = 0.60, b = 0.60, a = 1 },
        sealColorWISDOM = { r = 0.30, g = 0.50, b = 1.00, a = 1 },
        sealColorRIGHTEOUSNESS = { r = 1.00, g = 0.95, b = 0.70, a = 1 },
        sealColorLIGHT = { r = 0.20, g = 0.80, b = 0.30, a = 1 },
        sealColorCRUSADER = { r = 0.60, g = 0.80, b = 1.00, a = 1 },
        gcdTickerColor = { r = 0.30, g = 0.70, b = 1.00, a = 0.85 },
        warriorRageBarColor = { r = 0.80, g = 0.20, b = 0.10, a = 0.85 },
        shieldBlockBar = { r = 0.20, g = 0.55, b = 1.00, a = 0.90 },
        ravageCue = { r = 1.00, g = 0.72, b = 0.16, a = 0.28 },
        gcdTicker = { r = 0.90, g = 0.90, b = 0.95, a = 0.70 },
        rogueEnergyText = { r = 1.0, g = 0.82, b = 0.18, a = 0.85 },
        rapidFireBar = { r = 0.15, g = 0.85, b = 0.45, a = 0.85 },
        flurryCounter = { r = 1.0, g = 0.75, b = 0.10, a = 1.0 },
        adrenalineRushBar = { r = 1.0, g = 0.40, b = 0.10, a = 0.85 },
        omenGlow = { r = 0.20, g = 1.0, b = 0.30, a = 0.80 },
        windfuryIcd = { r = 0.85, g = 0.45, b = 0.0, a = 0.80 },
        shamanLightningShield = { r = 0.25, g = 0.72, b = 1.0, a = 0.90 }
    },
    positions = {
        mh = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -120 },
        oh = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -145 },
        ranged = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -100 },
        enemy = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -50 }
    }
}

-- Shared font path for all class-mod overlay text and icons.
ns.FONT_PATH = "Fonts\\FRIZQT__.TTF"

ns.TEXTURE_LAYER_OPTIONS = {
    { label = "Background", value = "BACKGROUND" }, { label = "Border", value = "BORDER" },
    { label = "Artwork", value = "ARTWORK" }, { label = "Overlay", value = "OVERLAY" },
    { label = "Highlight", value = "HIGHLIGHT" }
}

local function IsAddOnInstalled(addonKey)
    if type(GetAddOnInfo) ~= "function" then
        return true
    end

    return GetAddOnInfo(addonKey) ~= nil
end

function ns.GetTextureBrowserDisplayCategory(entry)
    if not entry then
        return ""
    end

    local category = entry.category or ""
    local style = entry.style or ""

    if category == "WeakAuras" then
        if style == "bar" then
            return "WeakAuras / Bars"
        end
        return "WeakAuras / Shapes"
    elseif category == "SharedMedia" then
        return string.format("SharedMedia / %s", style ~= "" and style or "media")
    elseif category == "Platynator" then
        return string.format("Platynator / %s", style ~= "" and style or "preset")
    elseif category == "Blizzard" then
        return string.format("Blizzard / %s", style ~= "" and style or "fallback")
    end

    return category
end

ns.TEXTURE_LIBRARY = nil

function ns.BuildTextureLibrary()
    local entries = {}
    local seen = {}

    local function addEntry(category, label, path, style, usage)
        if not path or path == "" or seen[path] then
            return
        end
        seen[path] = true
        entries[#entries + 1] = {
            category = category,
            style = style or category,
            usage = usage or "both",
            label = label,
            path = path
        }
    end

    local weakAurasInstalled = IsAddOnInstalled("WeakAuras")
    local platynatorInstalled = IsAddOnInstalled("Platynator")

    local libStub = rawget(_G, "LibStub")
    local lsm = libStub and libStub("LibSharedMedia-3.0", true)
    if lsm and lsm.List and lsm.Fetch then
        for _, mediaType in ipairs({ "statusbar", "background", "border" }) do
            for _, name in ipairs(lsm:List(mediaType) or {}) do
                local usage = (mediaType == "statusbar") and "both" or "spark"
                addEntry("SharedMedia", name, lsm:Fetch(mediaType, name), mediaType, usage)
            end
        end
    end

    if weakAurasInstalled then
        local weakAurasShapeTextures = {
            { label = "Square Full White", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Square_FullWhite" },
            { label = "Target Indicator", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\target_indicator.tga" },
            {
                label = "Target Indicator Glow",
                path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\target_indicator_glow.tga"
            },
            { label = "Triangle", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\triangle.tga" },
            { label = "Triangle Border", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\triangle-border.tga" },
            { label = "Triangle 45", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Triangle45.tga" },
            {
                label = "Square Alpha Gradient",
                path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Square_AlphaGradient.tga"
            },
            { label = "Square White", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Square_White.tga" },
            {
                label = "Square White Border",
                path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Square_White_Border.tga"
            },
            { label = "Square Smooth", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Square_Smooth.tga" },
            {
                label = "Square Smooth Border",
                path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Square_Smooth_Border.tga"
            },
            {
                label = "Square Smooth Border 2",
                path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Square_Smooth_Border2.tga"
            },
            { label = "Square Squirrel", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Square_Squirrel.tga" },
            {
                label = "Square Squirrel Border",
                path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Square_Squirrel_Border.tga"
            },
            {
                label = "Circle Alpha Gradient In",
                path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Circle_AlphaGradient_In.tga"
            },
            {
                label = "Circle Alpha Gradient Out",
                path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Circle_AlphaGradient_Out.tga"
            },
            { label = "Circle Smooth", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Circle_Smooth.tga" },
            { label = "Circle Smooth 2", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Circle_Smooth2.tga" },
            {
                label = "Circle Smooth Border",
                path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Circle_Smooth_Border.tga"
            },
            { label = "Circle Squirrel", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Circle_Squirrel.tga" },
            {
                label = "Circle Squirrel Border",
                path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Circle_Squirrel_Border.tga"
            },
            { label = "Circle White", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Circle_White.tga" },
            {
                label = "Circle White Border",
                path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Circle_White_Border.tga"
            },
            { label = "Ring 10px", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Ring_10px.tga" },
            { label = "Ring 20px", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Ring_20px.tga" },
            { label = "Ring 30px", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Ring_30px.tga" },
            { label = "Ring 40px", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Ring_40px.tga" },
            { label = "Trapezoid", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Trapezoid.tga" },
            { label = "Striped Texture", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\StripedTexture.tga" },
            { label = "Arrows Target", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\arrows_target.tga" },
            { label = "Targeting Mark", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\targeting-mark.tga" }
        }

        for _, texture in ipairs(weakAurasShapeTextures) do
            addEntry("WeakAuras", texture.label, texture.path, "shape", "spark")
        end

        local weakAurasBarTextures = {
            { label = "Statusbar Clean", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Statusbar_Clean.blp" },
            {
                label = "Statusbar Stripes",
                path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Statusbar_Stripes.blp"
            },
            {
                label = "Statusbar Stripes Thick",
                path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Statusbar_Stripes_Thick.blp"
            },
            {
                label = "Statusbar Stripes Thin",
                path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Statusbar_Stripes_Thin.blp"
            },
            { label = "Rainbow Bar", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\rainbowbar.tga" },
            { label = "Striped Bar", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\stripe-bar.tga" },
            {
                label = "Striped Rainbow Bar",
                path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\stripe-rainbow-bar.tga"
            }
        }

        for _, texture in ipairs(weakAurasBarTextures) do
            addEntry("WeakAuras", texture.label, texture.path, "bar", "both")
        end
    end

    if platynatorInstalled then
        -- Texture packs from other installed addons can be good bar-skin sources.
        addEntry("Platynator", "GW2", "Interface\\AddOns\\Platynator\\Assets\\gw2.png", "preset", "both")
        addEntry("Platynator", "ToxiUI G2", "Interface\\AddOns\\Platynator\\Assets\\ToxiUI-g2.tga", "preset", "both")
    end

    addEntry("Blizzard", "Status Bar", "Interface\\TargetingFrame\\UI-StatusBar", "fallback", "both")
    addEntry("Blizzard", "Casting Spark", "Interface\\CastingBar\\UI-CastingBar-Spark", "fallback", "spark")
    addEntry("Blizzard", "Casting Shield", "Interface\\CastingBar\\UI-CastingBar-Shield", "fallback", "spark")
    addEntry("Blizzard", "Tooltip Background", "Interface\\Tooltips\\UI-Tooltip-Background", "fallback", "spark")
    addEntry("Blizzard", "Tooltip Border", "Interface\\Tooltips\\UI-Tooltip-Border", "fallback", "spark")
    addEntry("Blizzard", "Dialog Background", "Interface\\DialogFrame\\UI-DialogBox-Background", "fallback", "spark")
    addEntry(
        "Blizzard", "Dialog Dark Background", "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", "fallback",
        "spark"
    )
    addEntry("Blizzard", "Dialog Border", "Interface\\DialogFrame\\UI-DialogBox-Border", "fallback", "spark")
    addEntry(
        "Blizzard", "Scroll Arrow Down", "Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Arrow", "fallback", "spark"
    )
    addEntry(
        "Blizzard", "Scroll Arrow Up", "Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Arrow", "fallback", "spark"
    )
    addEntry("Blizzard", "White 8x8", "Interface\\Buttons\\WHITE8X8", "fallback", "both")

    table.sort(entries, function (a, b)
        if (a.category or "") ~= (b.category or "") then
            return (a.category or "") < (b.category or "")
        end
        if (a.label or "") ~= (b.label or "") then
            return (a.label or "") < (b.label or "")
        end
        return (a.path or "") < (b.path or "")
    end)

    ns.TEXTURE_LIBRARY = entries
    return entries
end

function ns.GetTextureDisplayText(texturePath)
    if not texturePath or texturePath == "" then
        return "Select texture"
    end

    if texturePath == ns.DB_DEFAULTS.sparkTexture then
        return "Normal"
    end

    if texturePath == ns.DB_DEFAULTS.weaveSparkTexture then
        return "Target Indicator"
    end

    local library = ns.TEXTURE_LIBRARY or ns.BuildTextureLibrary()
    if library then
        for _, entry in ipairs(library) do
            if entry.path == texturePath then
                if entry.category and entry.label then
                    return string.format("%s / %s", entry.category, entry.label)
                end
                return entry.label or texturePath
            end
        end
    end

    return texturePath
end

function ns.GetTextureSummaryText(texturePath)
    local textureLabel = ns.GetTextureDisplayText(texturePath)
    local barLabel = ns.GetTextureDisplayText(ns.GetBarTexture and ns.GetBarTexture() or nil)
    return string.format("%s | Bar: %s", textureLabel, barLabel)
end

function ns.GetPlayerClassColor()
    local class = ns.playerClass
    local classColors = rawget(_G, "RAID_CLASS_COLORS")
    local color = class and classColors and classColors[class] or nil
    if color then
        return { r = color.r or 1, g = color.g or 1, b = color.b or 1, a = 1 }
    end

    return { r = 0.25, g = 0.72, b = 1.0, a = 1 }
end

function ns.GetBarColor(colorKey)
    local db = rawget(_G, "SuperSwingTimerDB")
    local useClassColors = db and db.useClassColors == true
    if useClassColors and (colorKey == "mh" or colorKey == "oh" or colorKey == "ranged") then
        local classColor = ns.GetPlayerClassColor()
        local alpha = 1
        if db and db.colors and db.colors[colorKey] and db.colors[colorKey].a ~= nil then
            alpha = db.colors[colorKey].a
        end
        return { r = classColor.r or 1, g = classColor.g or 1, b = classColor.b or 1, a = alpha }
    end

    local colors = db and db.colors
    if colors and colors[colorKey] then
        return colors[colorKey]
    end

    return ns.DB_DEFAULTS.colors and ns.DB_DEFAULTS.colors[colorKey] or nil
end

function ns.GetBarWidth()
    local db = rawget(_G, "SuperSwingTimerDB")
    if db and db.barWidth then
        return db.barWidth
    end
    return ns.BAR_WIDTH or ns.DB_DEFAULTS.barWidth
end

function ns.GetBarHeight()
    local db = rawget(_G, "SuperSwingTimerDB")
    if db and db.barHeight then
        return db.barHeight
    end
    return ns.BAR_HEIGHT or ns.DB_DEFAULTS.barHeight
end

function ns.GetIndicatorBlendMode()
    local db = rawget(_G, "SuperSwingTimerDB")
    if db and db.indicatorBlendMode and db.indicatorBlendMode ~= "" then
        return db.indicatorBlendMode
    end
    return ns.DB_DEFAULTS.indicatorBlendMode
end

function ns.GetBarTextureLayer()
    local db = rawget(_G, "SuperSwingTimerDB")
    if db and db.barTextureLayer then
        return db.barTextureLayer
    end
    return ns.DB_DEFAULTS.barTextureLayer
end

function ns.GetSparkTextureLayer()
    local db = rawget(_G, "SuperSwingTimerDB")
    if db and db.sparkTextureLayer then
        return db.sparkTextureLayer
    end
    return ns.DB_DEFAULTS.sparkTextureLayer
end

-- ============================================================
-- Global Scale
-- ============================================================
-- Master scale multiplier (0.5x–3.0x) that proportionally adjusts
-- all bar dimensions, icon sizes, font sizes, sparks, borders,
-- and inter-element gaps relative to their saved/default base pixel values.
ns.GLOBAL_SCALE_MIN = 0.5
ns.GLOBAL_SCALE_MAX = 3.0
ns.GLOBAL_SCALE_STEP = 0.1

--- Read the current global scale multiplier from SavedVariables.
--  Clamped to [GLOBAL_SCALE_MIN, GLOBAL_SCALE_MAX]. Falls back to 1.0
--  (no scaling) if the DB key is missing, nil, or non-numeric.
--  @return (number) Scale factor between 0.5 and 3.0, always ≥ 0.5
--  @see ns.Scale
--  @usage local s = ns.GetGlobalScale()  -- e.g. 1.5 for 150% size
function ns.GetGlobalScale()
    local db = rawget(_G, "SuperSwingTimerDB")
    local scale = db and db.globalScale
    if type(scale) ~= "number" or scale <= 0 then
        return 1.0
    end
    return math.max(ns.GLOBAL_SCALE_MIN, math.min(scale, ns.GLOBAL_SCALE_MAX))
end

--- Multiply a base pixel value by the current global scale, rounded to nearest int.
--- @param value number  The base pixel size (at 1.0× scale).
--- @return number  The scaled pixel size, min 1.
function ns.Scale(value)
    if type(value) ~= "number" then
        return value --[[@as number]]
    end
    return math.max(1, math.floor(value * ns.GetGlobalScale() + 0.5))
end

function ns.GetWeaveSparkTexture()
    local db = rawget(_G, "SuperSwingTimerDB")
    if db and db.weaveSparkTexture then
        return db.weaveSparkTexture
    end
    return ns.DB_DEFAULTS.weaveSparkTexture
end

function ns.GetWeaveSparkLayer()
    local db = rawget(_G, "SuperSwingTimerDB")
    if db and db.weaveSparkTextureLayer then
        return db.weaveSparkTextureLayer
    end
    return ns.DB_DEFAULTS.weaveSparkTextureLayer
end

function ns.GetWeaveTriangleTopTexture()
    local db = rawget(_G, "SuperSwingTimerDB")
    if db and db.weaveTriangleTopTexture then
        return db.weaveTriangleTopTexture
    end
    return ns.DB_DEFAULTS.weaveTriangleTopTexture
end

function ns.GetWeaveTriangleBottomTexture()
    local db = rawget(_G, "SuperSwingTimerDB")
    if db and db.weaveTriangleBottomTexture then
        return db.weaveTriangleBottomTexture
    end
    return ns.DB_DEFAULTS.weaveTriangleBottomTexture
end

function ns.GetWeaveTriangleLayer()
    local db = rawget(_G, "SuperSwingTimerDB")
    if db and db.weaveTriangleTextureLayer then
        return db.weaveTriangleTextureLayer
    end
    return ns.DB_DEFAULTS.weaveTriangleTextureLayer
end

function ns.GetWeaveMarkerLayer()
    local db = rawget(_G, "SuperSwingTimerDB")
    if db and db.weaveMarkerLayer then
        return db.weaveMarkerLayer
    end
    return ns.DB_DEFAULTS.weaveMarkerLayer
end

-- Overlay textures live on a dedicated non-mouse frame above the bar, so the
-- requested draw layer can be preserved directly while still using a positive
-- sublayer to keep same-frame ordering predictable.
function ns.ResolveTextureLayerAboveBar(requestedLayer, barLayer)
    local layer = requestedLayer or "OVERLAY"
    return layer, 1
end

function ns.SetTextureLayerAboveBar(texture, requestedLayer, barLayer)
    if texture and texture.SetDrawLayer then
        local layer, subLayer = ns.ResolveTextureLayerAboveBar(requestedLayer, barLayer)
        texture:SetDrawLayer(layer, subLayer)
    end
end

function ns.GetWeaveFamilyColor(abbrev)
    return ns.WEAVE_SPELL_FAMILY_COLORS and ns.WEAVE_SPELL_FAMILY_COLORS[abbrev] or nil
end

function ns.GetWeaveFamilyEnabled(abbrev)
    local db = rawget(_G, "SuperSwingTimerDB")
    if db and db.weaveSpellFamilies and db.weaveSpellFamilies[abbrev] ~= nil then
        return db.weaveSpellFamilies[abbrev] == true
    end
    return ns.DB_DEFAULTS.weaveSpellFamilies and ns.DB_DEFAULTS.weaveSpellFamilies[abbrev] ~= false
end

function ns.SetWeaveFamilyEnabled(abbrev, enabled)
    local db = rawget(_G, "SuperSwingTimerDB")
    if not db then
        return
    end

    db.weaveSpellFamilies = db.weaveSpellFamilies or {}
    db.weaveSpellFamilies[abbrev] = enabled == true

    if ns.weaveState then
        ns.weaveState.spellCatalogDirty = true
    end
end

function ns.GetBarBackgroundAlpha()
    local db = rawget(_G, "SuperSwingTimerDB")
    if db and db.barBackgroundColor and db.barBackgroundColor.a ~= nil then
        return db.barBackgroundColor.a
    end
    if db and db.barBackgroundAlpha ~= nil then
        return db.barBackgroundAlpha
    end
    return ns.DB_DEFAULTS.barBackgroundAlpha
end

function ns.GetBarBackgroundColor()
    local db = rawget(_G, "SuperSwingTimerDB")
    if db and db.barBackgroundColor then
        return db.barBackgroundColor
    end
    return ns.DB_DEFAULTS.barBackgroundColor
end

function ns.GetBarBorderSize()
    local db = rawget(_G, "SuperSwingTimerDB")
    if db and db.barBorderSize ~= nil then
        return db.barBorderSize
    end
    return ns.DB_DEFAULTS.barBorderSize
end

function ns.GetBarBorderColor()
    local db = rawget(_G, "SuperSwingTimerDB")
    if db and db.barBorderColor then
        return db.barBorderColor
    end
    return ns.DB_DEFAULTS.barBorderColor
end

function ns.GetSparkAlpha()
    local db = rawget(_G, "SuperSwingTimerDB")
    if db and db.sparkColor and db.sparkColor.a ~= nil then
        return db.sparkColor.a
    end
    if db and db.sparkAlpha ~= nil then
        return db.sparkAlpha
    end
    return ns.DB_DEFAULTS.sparkAlpha
end

function ns.GetSparkColor()
    local db = rawget(_G, "SuperSwingTimerDB")
    if db and db.sparkColor then
        return db.sparkColor
    end
    return ns.DB_DEFAULTS.sparkColor
end

function ns.IsMinimalMode()
    local db = rawget(_G, "SuperSwingTimerDB")
    return db and db.minimalMode == true
end

function ns.AreBarsLocked()
    local db = rawget(_G, "SuperSwingTimerDB")
    return db and db.lockBars == true
end

function ns.GetBarTexture()
    local db = rawget(_G, "SuperSwingTimerDB")
    if db and db.barTexture and db.barTexture ~= "Interface\\CastingBar\\UI-CastingBar-Fill" then
        return db.barTexture
    end
    return ns.DB_DEFAULTS.barTexture
end

function ns.GetRangedBarTexture()
    local db = rawget(_G, "SuperSwingTimerDB")
    if db and db.rangedBarTexture and db.rangedBarTexture ~= "Interface\\CastingBar\\UI-CastingBar-Fill" then
        return db.rangedBarTexture
    end
    return ns.GetBarTexture()
end

function ns.GetSparkTexture()
    local db = rawget(_G, "SuperSwingTimerDB")
    if db and db.sparkTexture then
        return db.sparkTexture
    end
    return ns.DB_DEFAULTS.sparkTexture
end

function ns.GetSparkWidth()
    local db = rawget(_G, "SuperSwingTimerDB")
    if db and db.sparkWidth then
        return db.sparkWidth
    end
    return ns.DB_DEFAULTS.sparkWidth
end

function ns.GetSparkHeight()
    local db = rawget(_G, "SuperSwingTimerDB")
    if db and db.sparkHeight then
        return db.sparkHeight
    end
    return ns.DB_DEFAULTS.sparkHeight
end

function ns.GetHunterRangeHelperWidth()
    return ns.HUNTER_RANGE_HELPER_WIDTH or 7
end

function ns.GetOffHandBarHeight(mainHeight)
    local baseHeight = tonumber(mainHeight) or ns.BAR_HEIGHT or ns.DB_DEFAULTS.barHeight or 15
    return math.max(6, baseHeight - 7)
end

function ns.GetRogueSliceAndDiceBarHeight(mainHeight)
    local baseHeight = tonumber(mainHeight) or ns.BAR_HEIGHT or ns.DB_DEFAULTS.barHeight or 15
    return math.max(3, math.min(4, math.floor((baseHeight * 0.3) + 0.5)))
end

function ns.GetRogueComboPointBarHeight(mainHeight)
    local baseHeight = tonumber(mainHeight) or ns.BAR_HEIGHT or ns.DB_DEFAULTS.barHeight or 15
    return math.max(2, math.min(4, math.floor((baseHeight * 0.27) + 0.5)))
end

function ns.GetWeaveSparkWidth()
    local db = rawget(_G, "SuperSwingTimerDB")
    if db and db.weaveSparkWidth then
        return db.weaveSparkWidth
    end
    return ns.DB_DEFAULTS.weaveSparkWidth
end

function ns.GetWeaveSparkHeight()
    local db = rawget(_G, "SuperSwingTimerDB")
    if db and db.weaveSparkHeight then
        return db.weaveSparkHeight
    end
    return ns.DB_DEFAULTS.weaveSparkHeight
end

function ns.GetWeaveSparkAlpha()
    local db = rawget(_G, "SuperSwingTimerDB")
    if db and db.weaveSparkAlpha ~= nil then
        return db.weaveSparkAlpha
    end
    return ns.DB_DEFAULTS.weaveSparkAlpha
end

function ns.GetWeaveTriangleSize()
    local db = rawget(_G, "SuperSwingTimerDB")
    if db and db.weaveTriangleSize then
        return db.weaveTriangleSize
    end
    return ns.DB_DEFAULTS.weaveTriangleSize
end

function ns.GetWeaveTriangleGap()
    local db = rawget(_G, "SuperSwingTimerDB")
    if db and db.weaveTriangleGap then
        return db.weaveTriangleGap
    end
    return ns.DB_DEFAULTS.weaveTriangleGap
end

function ns.GetWeaveTriangleAlpha()
    local db = rawget(_G, "SuperSwingTimerDB")
    if db and db.weaveTriangleAlpha ~= nil then
        return db.weaveTriangleAlpha
    end
    return ns.DB_DEFAULTS.weaveTriangleAlpha
end
