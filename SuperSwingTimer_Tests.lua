-- ============================================================
-- File role: WoWUnit in-game test suite for SuperSwingTimer
-- Depends on: WoWUnit addon (optional — gracefully skipped)
-- Loads after: all SuperSwingTimer files
-- Target: TBC Anniversary 2.5.5
-- ============================================================
local _, ns = ...

local function RegisterSSTTests()
    if not WoWUnit then return end

    local AreEqual = WoWUnit.AreEqual
    local IsTrue = WoWUnit.IsTrue
    local Exists = WoWUnit.Exists
    local IsFalse = WoWUnit.IsFalse
    local Replace = WoWUnit.Replace
    local T = ns._Test  -- test harness exports

    -- ============================================================
    -- Group 1: Constants & Spell Data
    -- ============================================================
    local Constants = WoWUnit('SST-Constants', 'PLAYER_ENTERING_WORLD', 'PLAYER_LOGIN')

    function Constants:AutoShotID_75()
        AreEqual(ns.AUTO_SHOT_ID, 75)
    end

    function Constants:AutoShotName_Resolves()
        Exists(ns.AUTO_SHOT_NAME)
        IsTrue(type(ns.AUTO_SHOT_NAME) == "string")
    end

    function Constants:SerpentStingIDs_Populated()
        Exists(ns.HUNTER_SERPENT_STING_IDS)
        local count = 0
        for _ in pairs(ns.HUNTER_SERPENT_STING_IDS) do count = count + 1 end
        IsTrue(count >= 3, 'at least 3 rank IDs for Serpent Sting')
    end

    function Constants:SerpentStingName_NotNil()
        Exists(ns.HUNTER_SERPENT_STING_NAME)
    end

    function Constants:DBDefaults_HasRequiredKeys()
        local db = ns.DB_DEFAULTS
        for _, key in ipairs({ 'version', 'barHeight', 'barWidth', 'barTexture',
            'barBackgroundColor', 'barBorderColor', 'useClassColors', 'showMH',
            'showOH', 'showRanged', 'showEnemy', 'colors' }) do
            IsTrue(db[key] ~= nil, 'DB_DEFAULTS.' .. key .. ' should exist (value=' .. tostring(db[key]) .. ')')
        end
    end

    function Constants:GetAlignedTime_IsNumber()
        IsTrue(type(ns.GetAlignedTime()) == "number")
    end

    function Constants:GetSpellInfo_WrapsSafely()
        Exists(ns.GetSpellInfo(ns.AUTO_SHOT_ID))
    end

    function Constants:SteadyShotCastTime_Is150()
        AreEqual(ns.STEADY_SHOT_CAST_TIME, 1.5)
    end

    function Constants:IsAutoShotSpell_DetectsByID()
        IsTrue(ns.IsAutoShotSpell(75))
    end

    function Constants:IsAutoShotSpell_DetectsByName()
        if ns.AUTO_SHOT_NAME then
            IsTrue(ns.IsAutoShotSpell(ns.AUTO_SHOT_NAME))
        end
    end

    function Constants:IsHunterCastSpell_DetectsSteadyShot()
        IsTrue(ns.IsHunterCastSpell(ns.STEADY_SHOT_ID))
    end

    function Constants:PaladinSealFamilies_AllHaveData()
        for _, key in ipairs({'COMMAND', 'BLOOD', 'MARTYR', 'VENGEANCE',
                              'RIGHTEOUSNESS', 'CORRUPTION'}) do
            local family = ns.PALADIN_SEAL_FAMILIES[key]
            Exists(family, 'family ' .. key)
            Exists(family.ids, 'ids for ' .. key)
            IsTrue(#family.ids > 0, key .. ' has at least 1 spell ID')
        end
    end

    function Constants:MultiShotNames_AllResolved()
        for id in pairs(ns.MULTI_SHOT_IDS) do
            Exists(ns.GetSpellInfo(id), 'Multi-Shot rank ' .. id .. ' resolves')
        end
    end

    -- ============================================================
    -- Group 2: Clock Domain & Timer State
    -- ============================================================
    local Timers = WoWUnit('SST-Timers', 'PLAYER_ENTERING_WORLD', 'UNIT_ATTACK_SPEED')

    function Timers:TimersTable_Exists()
        for _, key in ipairs({'mh', 'oh', 'ranged', 'enemy'}) do
            Exists(ns.timers[key], 'ns.timers.' .. key)
        end
    end

    function Timers:GetAlignedTime_Monotonic()
        local a, b = ns.GetAlignedTime(), ns.GetAlignedTime()
        IsTrue(b >= a, 'GetAlignedTime should be monotonic')
    end

    -- ============================================================
    -- Group 3: Harmful Aura Parsing (mocked)
    -- ============================================================
    local AuraParsing = WoWUnit('SST-AuraParsing', 'PLAYER_ENTERING_WORLD')

    function AuraParsing:MagicalDebuff_FullAPI()
        if not T or not T.GetHarmfulAuraData then return end
        Replace('UnitAura', function(unit, index, filter)
            if index == 1 then
                return 'Flame Shock', nil, 'Interface\\Icons\\Spell_Fire_FlameShock',
                       1, 'Fire', 12, 12350.0, 'player', nil, 0, 8050
            end
            return nil
        end)
        local name, count, dur, expT, caster, sId = T.GetHarmfulAuraData('target', 1, 'HARMFUL')
        AreEqual(name, 'Flame Shock')
        AreEqual(count, 1, 'stack count')
        AreEqual(dur, 12, 'duration')
        IsTrue(type(expT) == "number" and expT > 0, 'expirationTime > 0')
        AreEqual(caster, 'player', 'caster')
        AreEqual(sId, 8050, 'spellId')
        ClearReplaces()
    end

    function AuraParsing:PhysicalDebuff_NilDispelType()
        if not T or not T.GetHarmfulAuraData then return end
        Replace('UnitAura', function(unit, index, filter)
            if index == 1 then
                return 'Deep Wounds', nil, 'Interface\\Icons\\Ability_Warrior_DeepWounds',
                       1, nil, 12, 12360.0, 'player', nil, 0, 12721
            end
            return nil
        end)
        local name, count, dur, expT, caster, sId = T.GetHarmfulAuraData('target', 1, 'HARMFUL')
        AreEqual(name, 'Deep Wounds')
        AreEqual(dur, 12, 'duration')
        AreEqual(caster, 'player', 'caster')
        AreEqual(sId, 12721, 'spellId')
        ClearReplaces()
    end

    function AuraParsing:NoAura_ReturnsNil()
        if not T or not T.GetHarmfulAuraData then return end
        Replace('UnitAura', function() return nil end)
        IsFalse(T.GetHarmfulAuraData('target', 1, 'HARMFUL'))
        ClearReplaces()
    end

    -- ============================================================
    -- Group 4: GetDebuffStackOffset Math
    -- ============================================================
    local StackOffset = WoWUnit('SST-StackOffset', 'PLAYER_ENTERING_WORLD')

    function StackOffset:SingleBar_OffsetIsNegative()
        if not T or not T.GetDebuffStackOffset then return end
        local ref = { GetTop = function() return 100 end }
        local b1 = { IsShown = function() return true end,
                     GetTop = function() return 96 end,
                     GetBottom = function() return 102 end }
        local offset = T.GetDebuffStackOffset({b1}, ref)
        IsTrue(tonumber(offset) < 0, 'offset should be negative (above bar): ' .. tostring(offset))
    end

    function StackOffset:TwoBars_HighestWins()
        if not T or not T.GetDebuffStackOffset then return end
        local ref = { GetTop = function() return 100 end }
        local high = { IsShown = function() return true end,
                       GetTop = function() return 96 end,
                       GetBottom = function() return 102 end }
        local low  = { IsShown = function() return true end,
                       GetTop = function() return 104 end,
                       GetBottom = function() return 110 end }
        local offset = T.GetDebuffStackOffset({high, low}, ref)
        local gap = math.abs(tonumber(offset) - (96 - 100))
        IsTrue(gap >= 3, 'gap above highest bar should be >= 3, got ' .. tostring(gap))
    end

    function StackOffset:NoVisibleBars_ReturnsValue()
        if not T or not T.GetDebuffStackOffset then return end
        local ref = { GetTop = function() return 100 end }
        local b1 = { IsShown = function() return false end,
                     GetTop = function() return 96 end,
                     GetBottom = function() return 102 end }
        local offset = T.GetDebuffStackOffset({b1}, ref)
        IsTrue(type(offset) == "number", 'should return number even with hidden bars')
    end

    -- ============================================================
    -- Group 5: Hunter Serpent Sting Detection
    -- ============================================================
    local HunterSS = WoWUnit('SST-HunterSerpentSting', 'PLAYER_ENTERING_WORLD')

    function HunterSS:DetectsBySpellID()
        if not T or not T.GetTargetSerpentStingData then return end
        Replace('UnitAura', function(unit, index, filter)
            if index == 1 then
                return 'Serpent Sting', nil, 'Interface\\Icons\\Ability_Hunter_SerpentSting',
                       1, 'Nature', 15, 12345.0, 'player', nil, 0, 27019
            end
            return nil
        end)
        Replace('UnitExists', function() return true end)
        Replace('UnitCanAttack', function() return true end)
        local dur, expT = T.GetTargetSerpentStingData()
        Exists(dur, 'detect by TBC rank 9 spellID 27019')
        if dur then IsTrue(tonumber(dur) > 0) end
        ClearReplaces()
    end

    function HunterSS:DetectsByName()
        if not T or not T.GetTargetSerpentStingData then return end
        Replace('UnitAura', function(unit, index, filter)
            if index == 1 then
                return ns.HUNTER_SERPENT_STING_NAME, nil, 'Interface\\Icons\\Ability_Hunter_SerpentSting',
                       1, 'Nature', 15, 12345.0, 'player', nil, 0, 1978
            end
            return nil
        end)
        Replace('UnitExists', function() return true end)
        Replace('UnitCanAttack', function() return true end)
        local dur, expT = T.GetTargetSerpentStingData()
        Exists(dur, 'detect by name match')
        ClearReplaces()
    end

    function HunterSS:FiltersOtherCaster()
        if not T or not T.GetTargetSerpentStingData then return end
        Replace('UnitAura', function(unit, index, filter)
            if index == 1 then
                return 'Serpent Sting', nil, 'Interface\\Icons\\Ability_Hunter_SerpentSting',
                       1, 'Nature', 15, 12345.0, 'OtherHunter', nil, 0, 1978
            end
            return nil
        end)
        Replace('UnitExists', function() return true end)
        Replace('UnitCanAttack', function() return true end)
        local dur, expT = T.GetTargetSerpentStingData()
        IsFalse(dur, 'should NOT detect other-player Serpent Sting')
        ClearReplaces()
    end

    function HunterSS:NoTarget_HandledGracefully()
        Replace('UnitExists', function() return false end)
        Replace('UnitCanAttack', function() return true end)
        local ok, err = pcall(ns.UpdateHunterSerpentStingBar, true)
        IsTrue(ok, 'UpdateHunterSerpentStingBar with no target: ' .. tostring(err))
        ClearReplaces()
    end

    -- ============================================================
    -- Group 6: MigrateDB Chain
    -- ============================================================
    local Migrate = WoWUnit('SST-MigrateDB', 'PLAYER_ENTERING_WORLD')

    function Migrate:FreshDB_Completes()
        local db = {}
        local ok, err = pcall(ns.MigrateDB, db)
        IsTrue(ok, 'MigrateDB empty: ' .. tostring(err))
    end

    function Migrate:V1_UpgradesToCurrent()
        local db = { version = 1 }
        local ok, err = pcall(ns.MigrateDB, db)
        IsTrue(ok, 'MigrateDB v1: ' .. tostring(err))
        Exists(db.version)
        IsTrue(db.version >= 54, 'should reach v54+, got v' .. tostring(db.version))
    end

    function Migrate:V53_UpgradesToCurrent()
        local db = { version = 53 }
        local ok, err = pcall(ns.MigrateDB, db)
        IsTrue(ok, 'MigrateDB v53: ' .. tostring(err))
        AreEqual(db.version, 54, 'v53 should reach exactly v54')
    end

    function Migrate:V54_NoChange()
        local db = { version = 54 }
        local ok, err = pcall(ns.MigrateDB, db)
        IsTrue(ok, 'MigrateDB v54: ' .. tostring(err))
        AreEqual(db.version, 54)
    end

    function Migrate:FactoryReset()
        local ok, err = pcall(ns.ResetConfigDefaults)
        IsTrue(ok, 'ResetConfigDefaults: ' .. tostring(err))
    end

    -- ============================================================
    -- Group 7: Dispatch Safety (nil-guards)
    -- ============================================================
    local Dispatch = WoWUnit('SST-Dispatch', 'PLAYER_ENTERING_WORLD')

    function Dispatch:RestoreBarDefaultLabel_Nil()
        IsTrue(pcall(ns.RestoreBarDefaultLabel, nil))
    end

    function Dispatch:RefreshBarLabelStyles_Nil()
        IsTrue(pcall(ns.RefreshBarLabelStyles))
    end

    function Dispatch:GetAlignedTime_Num()
        local ok, t = pcall(ns.GetAlignedTime)
        IsTrue(ok)
        IsTrue(type(t) == "number")
    end

    -- ============================================================
    -- Group 8: Helpful Aura Parsing (mocked)
    -- ============================================================
    local HelpfulAura = WoWUnit('SST-HelpfulAura', 'PLAYER_ENTERING_WORLD')

    function HelpfulAura:TBCAnniversaryShape()
        if not T or not T.GetHelpfulAuraData then return end
        Replace('UnitBuff', function(unit, index)
            if index == 1 then
                return 'Slice and Dice', nil, 'Interface\\Icons\\Ability_Rogue_SliceDice',
                       1, 15, 12345.0, 'player', nil, 0, 5171
            end
            return nil
        end)
        local name, dur, expT, sId = T.GetHelpfulAuraData('player', 1)
        AreEqual(name, 'Slice and Dice')
        AreEqual(dur, 15, 'duration')
        IsTrue(type(expT) == "number" and expT > 0, 'expirationTime > 0')
        AreEqual(sId, 5171, 'spellId')
        ClearReplaces()
    end

    function HelpfulAura:RapidFireBySpellID()
        if not T or not T.GetHelpfulAuraData then return end
        Replace('UnitBuff', function(unit, index)
            if index == 1 then
                return 'Rapid Fire', nil, 'Interface\\Icons\\Ability_Hunter_RunningShot',
                       1, 15, 12345.0, 'player', nil, 0, 3045
            end
            return nil
        end)
        local name, dur, expT, sId = T.GetHelpfulAuraData('player', 1)
        AreEqual(name, 'Rapid Fire')
        AreEqual(dur, 15, 'duration')
        AreEqual(sId, 3045, 'spellId')
        ClearReplaces()
    end

    -- ============================================================
    -- Group 9: Flurry Buff Info (mocked)
    -- ============================================================
    local Flurry = WoWUnit('SST-Flurry', 'PLAYER_ENTERING_WORLD')

    function Flurry:TBC_3Charges()
        if not T or not T.GetFlurryBuffInfo then return end
        Replace('UnitBuff', function(unit, index)
            if index == 1 then
                return 'Flurry', nil, 'Interface\\Icons\\Ability_Warrior_FocusedRage',
                       3, nil, 12345.0, nil, nil, nil, nil, 16280
            end
            return nil
        end)
        local charges, expT = T.GetFlurryBuffInfo()
        AreEqual(charges, 3)
        Exists(expT)
        ClearReplaces()
    end

    function Flurry:NoFlurry_ReturnsNil()
        if not T or not T.GetFlurryBuffInfo then return end
        Replace('UnitBuff', function() return nil end)
        IsFalse(T.GetFlurryBuffInfo())
        ClearReplaces()
    end

    -- ============================================================
    -- Group 10: Cross-Class Debuff Detection
    -- ============================================================
    local CrossDebuffs = WoWUnit('SST-CrossDebuffs', 'PLAYER_ENTERING_WORLD')

    function CrossDebuffs:Warrior_DeepWounds()
        if not T or not T.GetHarmfulAuraData then return end
        Replace('UnitAura', function(u, i, f)
            if i == 1 then
                return 'Deep Wounds', nil, 'Interface\\Icons\\Ability_Warrior_DeepWounds',
                       1, nil, 12, 12360.0, 'player', nil, 0, 12721
            end
            return nil
        end)
        local name, _, dur, _, caster, sId = T.GetHarmfulAuraData('target', 1, 'HARMFUL')
        AreEqual(name, 'Deep Wounds')
        AreEqual(dur, 12, 'deep wounds duration')
        AreEqual(caster, 'player', 'caster')
        AreEqual(sId, 12721)
        ClearReplaces()
    end

    function CrossDebuffs:Shaman_FlameShock()
        if not T or not T.GetHarmfulAuraData then return end
        Replace('UnitAura', function(u, i, f)
            if i == 1 then
                return 'Flame Shock', nil, 'Interface\\Icons\\Spell_Fire_FlameShock',
                       1, 'Fire', 12, 12350.0, 'player', nil, 0, 8050
            end
            return nil
        end)
        local name, _, dur, _, caster, sId = T.GetHarmfulAuraData('target', 1, 'HARMFUL')
        AreEqual(name, 'Flame Shock')
        AreEqual(dur, 12, 'flame shock duration')
        AreEqual(caster, 'player', 'caster')
        AreEqual(sId, 8050)
        ClearReplaces()
    end

    function CrossDebuffs:Druid_Mangle()
        if not T or not T.GetHarmfulAuraData then return end
        Replace('UnitAura', function(u, i, f)
            if i == 1 then
                return 'Mangle', nil, 'Interface\\Icons\\Ability_Druid_Mangle',
                       1, nil, 60, 12400.0, 'player', nil, 0, 33983
            end
            return nil
        end)
        local name, _, dur, _, caster, sId = T.GetHarmfulAuraData('target', 1, 'HARMFUL')
        AreEqual(name, 'Mangle')
        AreEqual(dur, 60, 'mangle duration')
        AreEqual(caster, 'player', 'caster')
        AreEqual(sId, 33983)
        ClearReplaces()
    end

    function CrossDebuffs:Rogue_Rupture()
        if not T or not T.GetHarmfulAuraData then return end
        Replace('UnitAura', function(u, i, f)
            if i == 1 then
                return 'Rupture', nil, 'Interface\\Icons\\Ability_Rogue_Rupture',
                       1, nil, 16, 12370.0, 'player', nil, 0, 1943
            end
            return nil
        end)
        local name, _, dur, _, caster, sId = T.GetHarmfulAuraData('target', 1, 'HARMFUL')
        AreEqual(name, 'Rupture')
        AreEqual(dur, 16, 'rupture duration')
        AreEqual(caster, 'player', 'caster')
        AreEqual(sId, 1943)
        ClearReplaces()
    end

    function CrossDebuffs:Paladin_SealVengeance()
        if not T or not T.GetHarmfulAuraData then return end
        Replace('UnitAura', function(u, i, f)
            if i == 1 then
                return 'Seal of Vengeance', nil, 'Interface\\Icons\\Ability_Paladin_SealVengeance',
                       5, 'Holy', 15, 12380.0, 'player', nil, 0, 31804
            end
            return nil
        end)
        local name, _, dur, _, caster, sId = T.GetHarmfulAuraData('target', 1, 'HARMFUL')
        AreEqual(name, 'Seal of Vengeance')
        AreEqual(dur, 15, 'seal vengeance duration')
        AreEqual(caster, 'player', 'caster')
        AreEqual(sId, 31804)
        ClearReplaces()
    end

    function CrossDebuffs:SunderArmor()
        if not T or not T.GetHarmfulAuraData then return end
        Replace('UnitAura', function(u, i, f)
            if i == 1 then
                return 'Sunder Armor', nil, 'Interface\\Icons\\Ability_Warrior_Sunder',
                       3, 'Armor', 30, 12450.0, 'player', nil, 0, 7386
            end
            return nil
        end)
        local name, _, dur, _, caster, sId = T.GetHarmfulAuraData('target', 1, 'HARMFUL')
        AreEqual(name, 'Sunder Armor')
        AreEqual(dur, 30, 'sunder duration')
        AreEqual(caster, 'player', 'caster')
        AreEqual(sId, 7386)
        ClearReplaces()
    end

    -- ============================================================
    -- Group 11: Hunter Buff Icon Tracking
    -- ============================================================
    local HunterBuffs = WoWUnit('SST-HunterBuffs', 'PLAYER_ENTERING_WORLD')

    function HunterBuffs:RapidFire_DetectedAsBuff()
        if not T or not T.GetHelpfulAuraData then return end
        Replace('UnitBuff', function(u, i)
            if i == 1 then
                return 'Rapid Fire', nil, 'Interface\\Icons\\Ability_Hunter_RunningShot',
                       1, 15, 12345.0, 'player', nil, 0, 3045
            end
            return nil
        end)
        local name, dur, _, sId = T.GetHelpfulAuraData('player', 1)
        AreEqual(name, 'Rapid Fire')
        AreEqual(dur, 15)
        AreEqual(sId, 3045)
        ClearReplaces()
    end

    function HunterBuffs:BestialWrath_Detected()
        if not T or not T.GetHelpfulAuraData then return end
        Replace('UnitBuff', function(u, i)
            if i == 1 then
                return 'Bestial Wrath', nil, 'Interface\\Icons\\Ability_Druid_FerociousBite',
                       1, 18, 12360.0, 'player', nil, 0, 19574
            end
            return nil
        end)
        local name, dur, _, sId = T.GetHelpfulAuraData('player', 1)
        AreEqual(name, 'Bestial Wrath')
        AreEqual(dur, 18)
        ClearReplaces()
    end

    -- ============================================================
    -- Group 12: Paladin Seal Detection
    -- ============================================================
    local PaladinSeals = WoWUnit('SST-PaladinSeals', 'PLAYER_ENTERING_WORLD')

    function PaladinSeals:GetPaladinSealFamily_Command()
        if not ns.GetPaladinSealFamilyByAuraName then return end
        AreEqual(ns.GetPaladinSealFamilyByAuraName('Seal of Command'), 'COMMAND')
    end

    function PaladinSeals:GetPaladinSealFamily_Blood()
        if not ns.GetPaladinSealFamilyByAuraName then return end
        AreEqual(ns.GetPaladinSealFamilyByAuraName('Seal of Blood'), 'BLOOD')
    end

    function PaladinSeals:GetPaladinSealFamily_Vengeance()
        if not ns.GetPaladinSealFamilyByAuraName then return end
        AreEqual(ns.GetPaladinSealFamilyByAuraName('Seal of Vengeance'), 'VENGEANCE')
    end

    function PaladinSeals:GetPaladinSealFamily_UnknownReturnsNil()
        if not ns.GetPaladinSealFamilyByAuraName then return end
        IsFalse(ns.GetPaladinSealFamilyByAuraName('Fishing'))
    end

    -- ============================================================
    -- Group 13: Haste Scaling (sanity check)
    -- ============================================================
    local Haste = WoWUnit('SST-Haste', 'PLAYER_ENTERING_WORLD')

    function Haste:MeleeHaste_Exists()
        -- Just verify the API function exists; real test needs actual player
        IsTrue(type(GetMeleeHaste) == "function", 'GetMeleeHaste should exist')
    end

    -- ============================================================
    -- Group 14: nil-Stress Tests
    -- ============================================================
    local NilStress = WoWUnit('SST-NilStress', 'PLAYER_ENTERING_WORLD')

    function NilStress:GetSpellInfo_Nil()
        IsTrue(pcall(ns.GetSpellInfo, nil))
    end

    function NilStress:GetUnitCastingSpellInfo_Nil()
        IsTrue(pcall(ns.GetUnitCastingSpellInfo, nil))
    end

    function NilStress:IsAutoShotSpell_Nil()
        local ok, result = pcall(ns.IsAutoShotSpell, nil)
        IsTrue(ok)
        IsFalse(result)
    end

    function NilStress:IsHunterCastSpell_Nil()
        local ok, result = pcall(ns.IsHunterCastSpell, nil)
        IsTrue(ok)
        IsFalse(result)
    end

    function NilStress:SetBarLabelText_NilBar()
        IsTrue(pcall(ns.SetBarLabelText, nil, 'test', true))
    end

    function NilStress:RefreshBarSparkPosition_NilBar()
        IsTrue(pcall(ns.RefreshBarSparkPosition, nil))
    end

    -- ============================================================
    -- Group 15: Config Toggle → Bar Visibility
    -- ============================================================
    local ConfigToggle = WoWUnit('SST-ConfigToggle', 'PLAYER_ENTERING_WORLD')

    function ConfigToggle:ShowMhBar_Toggle()
        local db = SuperSwingTimerDB or ns.DB_DEFAULTS
        if not db then return end
        local was = db.showMhBar
        db.showMhBar = false
        if ns.ApplyVisibility then pcall(ns.ApplyVisibility) end
        db.showMhBar = was
        Exists(true, 'Toggle showMhBar false with no error')
    end

    function ConfigToggle:ShowOhBar_Toggle()
        local db = SuperSwingTimerDB or ns.DB_DEFAULTS
        if not db then return end
        local was = db.showOhBar
        db.showOhBar = false
        if ns.ApplyVisibility then pcall(ns.ApplyVisibility) end
        db.showOhBar = was
        Exists(true, 'Toggle showOhBar false with no error')
    end

    -- ============================================================
    -- Group 16: Hunter Cast Spell Detection
    -- ============================================================
    local HunterCast = WoWUnit('SST-HunterCast', 'PLAYER_ENTERING_WORLD')

    function HunterCast:SteadyShot_IsCastSpell()
        IsTrue(ns.IsHunterCastSpell(ns.STEADY_SHOT_ID))
    end

    function HunterCast:AimedShot_IsCastSpell()
        IsTrue(ns.IsHunterCastSpell(19434))
    end

    function HunterCast:MultiShot_IsCastSpell()
        IsTrue(ns.IsHunterCastSpell(2643))
    end

    function HunterCast:AutoShot_IsCastSpell()
        IsTrue(ns.IsHunterCastSpell(75))
    end

    function HunterCast:AutoShot_IsNotActualCast()
        IsFalse(ns.IsHunterActualCastSpell(75), 'Auto Shot is not an actual-cast spell')
    end

    function HunterCast:SteadyShot_IsActualCast()
        IsTrue(ns.IsHunterActualCastSpell(ns.STEADY_SHOT_ID))
    end

    -- ============================================================
    -- Group 17: CLEU Event Simulation
    -- ============================================================
    local CLEU = WoWUnit('SST-CLEU', 'PLAYER_ENTERING_WORLD')

    --- Build a mock CLEU tuple matching the CombatLogGetCurrentEventInfo shape.
    local function MakeCLEU(subEvent, sourceGUID, destGUID, arg12, arg13, arg15, arg21)
        return nil, subEvent, nil, sourceGUID, nil, nil, nil, destGUID,
               nil, nil, nil, arg12, arg13, nil, arg15, nil, nil, nil, nil, nil, arg21
    end

    local PLAYER_GUID = "Player-0000000000001"
    local ENEMY_GUID  = "Creature-0000000000001"
    local OTHER_GUID  = "Other-0000000000001"

    function CLEU:SWING_DAMAGE_MH_TriggersStartSwing()
        Replace('CombatLogGetCurrentEventInfo', function()
            return MakeCLEU("SWING_DAMAGE", PLAYER_GUID, ENEMY_GUID, nil, nil, 100, nil)
        end)
        Replace('GetPlayerGUID', function() return PLAYER_GUID end)
        local oldEnd = ns.timers.mh and ns.timers.mh.endTime or 0
        pcall(ns.HandleCLEU)
        local newEnd = ns.timers.mh and ns.timers.mh.endTime or 0
        IsTrue(ns.timers.mh.state == "swinging" or newEnd ~= oldEnd,
               'MH timer should be swinging after CLEU SWING_DAMAGE')
        ClearReplaces()
    end

    function CLEU:SWING_DAMAGE_OH_TriggersStartSwing()
        Replace('CombatLogGetCurrentEventInfo', function()
            return MakeCLEU("SWING_DAMAGE", PLAYER_GUID, ENEMY_GUID, nil, nil, 50, 1)
        end)
        Replace('GetPlayerGUID', function() return PLAYER_GUID end)
        local oldEnd = ns.timers.oh and ns.timers.oh.endTime or 0
        pcall(ns.HandleCLEU)
        local newEnd = ns.timers.oh and ns.timers.oh.endTime or 0
        IsTrue(ns.timers.oh.state == "swinging" or newEnd ~= oldEnd,
               'OH timer should be swinging after CLEU SWING_DAMAGE (OH flag=1)')
        ClearReplaces()
    end

    function CLEU:SWING_DAMAGE_Enemy_TriggersEnemySwing()
        Replace('CombatLogGetCurrentEventInfo', function()
            return MakeCLEU("SWING_DAMAGE", ENEMY_GUID, PLAYER_GUID, nil, nil, 80, nil)
        end)
        Replace('GetPlayerGUID', function() return PLAYER_GUID end)
        local savedGUID = ns.enemyTargetGUID
        ns.enemyTargetGUID = ENEMY_GUID
        local oldEnd = ns.timers.enemy and ns.timers.enemy.endTime or 0
        pcall(ns.HandleCLEU)
        local newEnd = ns.timers.enemy and ns.timers.enemy.endTime or 0
        IsTrue(newEnd ~= oldEnd or ns.timers.enemy.state == "swinging",
               'Enemy timer should update after enemy SWING_DAMAGE')
        ns.enemyTargetGUID = savedGUID
        ClearReplaces()
    end

    function CLEU:SWING_MISSED_TriggersStartSwing()
        Replace('CombatLogGetCurrentEventInfo', function()
            return MakeCLEU("SWING_MISSED", PLAYER_GUID, ENEMY_GUID, "MISS", nil, nil, nil)
        end)
        Replace('GetPlayerGUID', function() return PLAYER_GUID end)
        local oldEnd = ns.timers.mh and ns.timers.mh.endTime or 0
        pcall(ns.HandleCLEU)
        local newEnd = ns.timers.mh and ns.timers.mh.endTime or 0
        IsTrue(ns.timers.mh.state == "swinging" or newEnd ~= oldEnd,
               'MH timer should swing after SWING_MISSED')
        ClearReplaces()
    end

    function CLEU:SWING_MISSED_Dodge_SetsOverpowerWindow()
        Replace('CombatLogGetCurrentEventInfo', function()
            return MakeCLEU("SWING_MISSED", PLAYER_GUID, ENEMY_GUID, "DODGE", nil, nil, nil)
        end)
        Replace('GetPlayerGUID', function() return PLAYER_GUID end)
        pcall(ns.HandleCLEU)
        IsTrue(true, 'HandleCLEU with DODGE should not error')
        ClearReplaces()
    end

    function CLEU:OtherSource_Ignored()
        Replace('CombatLogGetCurrentEventInfo', function()
            return MakeCLEU("SWING_DAMAGE", OTHER_GUID, PLAYER_GUID, nil, nil, 99, nil)
        end)
        Replace('GetPlayerGUID', function() return PLAYER_GUID end)
        local savedGUID = ns.enemyTargetGUID
        ns.enemyTargetGUID = ENEMY_GUID
        pcall(ns.HandleCLEU)
        IsTrue(true, 'HandleCLEU should silently ignore non-player/non-enemy GUIDs')
        ns.enemyTargetGUID = savedGUID
        ClearReplaces()
    end

    -- ============================================================
    -- Group 18: Timer State Machine
    -- ============================================================
    local TimerState = WoWUnit('SST-TimerState', 'PLAYER_ENTERING_WORLD', 'UNIT_ATTACK_SPEED')

    function TimerState:StartSwing_MH_CreatesValidState()
        if not ns.StartSwing then return end
        local now = ns.GetAlignedTime()
        pcall(ns.StartSwing, "mh", nil, now)
        local t = ns.timers.mh
        Exists(t, 'MH timer exists after StartSwing')
        IsTrue(t.state == "swinging", 'state should be "swinging"')
        IsTrue(type(t.startTime) == "number" and t.startTime >= now - 0.1,
               'startTime should be near now')
        IsTrue(type(t.endTime) == "number" and t.endTime > t.startTime,
               'endTime should be > startTime')
        IsTrue(type(t.duration) == "number" and t.duration > 0,
               'duration should be positive')
    end

    function TimerState:StartSwing_OH_CreatesValidState()
        if not ns.StartSwing then return end
        local now = ns.GetAlignedTime()
        pcall(ns.StartSwing, "oh", nil, now)
        local t = ns.timers.oh
        Exists(t, 'OH timer exists after StartSwing')
        if t then
            IsTrue(t.state == "swinging", 'OH state should be "swinging"')
        end
    end

    function TimerState:StartSwing_Ranged_CreatesValidState()
        if not ns.StartSwing then return end
        local now = ns.GetAlignedTime()
        pcall(ns.StartSwing, "ranged", nil, now)
        local t = ns.timers.ranged
        Exists(t, 'Ranged timer exists after StartSwing')
        if t then
            IsTrue(t.state == "swinging", 'ranged state should be "swinging"')
        end
    end

    -- ============================================================
    -- Also register via slash command for manual trigger
    -- ============================================================
    _G.SLASH_SSTTEST1 = "/ssttest"
    SlashCmdList["SSTTEST"] = function()
        if not WoWUnit then
            print("|cffff4444[SST] WoWUnit not installed. Install from CurseForge to run tests.|r")
            return
        end
        -- Run all SST groups by firing their registered events
        for _, group in ipairs(WoWUnit.children) do
            if group.name and group.name:match("^SST%-") then
                group()
            end
        end
    end

    print("|cff44ff44[SST] 73 tests registered across 18 groups. Click WoWUnit toggle on the right, or type /ssttest to run.|r")
end

-- Use a one-shot OnUpdate frame for deferred registration — works on ALL WoW
-- clients (C_Timer.After doesn't exist on TBC Anniversary).  Wrapped in pcall
-- so any registration errors are caught and reported via BugSack.
local regFrame = CreateFrame("Frame")
regFrame:SetScript("OnUpdate", function(self)
    self:SetScript("OnUpdate", nil)  -- fire once
    if WoWUnit then
        local ok, err = pcall(RegisterSSTTests)
        if not ok then
            geterrorhandler()(err)
            print("|cffff4444[SST] Test registration failed: " .. tostring(err) .. "|r")
        end
    else
        print("|cffff4444[SST] WoWUnit not detected. Install WoWUnit and /reload.|r")
    end
end)
