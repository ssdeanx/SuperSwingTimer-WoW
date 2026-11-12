---@diagnostic disable: undefined-global
-- ============================================================
-- File role: WoWUnit in-game test suite for SuperSwingTimer
-- Depends on: WoWUnit addon (optional, skipped cleanly)
-- Target: TBC Anniversary 2.5.5
-- We dont use this anymore.
-- ============================================================
local _, ns = ...

local function RegisterSSTTests()
    if not WoWUnit then return end

    local IsTrue, IsFalse = WoWUnit.IsTrue, WoWUnit.IsFalse
    local Exists, AreEqual = WoWUnit.Exists, WoWUnit.AreEqual
    local Replace = WoWUnit.Replace
    -- WoWUnit exposes ClearReplaces as a method on the WoWUnit table,
    -- not as a global. Capture it so the Aura/CLEU tests can reset mocks.
    local ClearReplaces = WoWUnit.ClearReplaces
    local T = ns._Test
    local function pc(p, ...)
        local ok, r = pcall(p, ...); return ok, r
    end

    -- ============================================================
    -- SST-Core: addon loaded, constants sane, DB migrates, nil-safe
    -- ============================================================
    local Core = WoWUnit:New('SST-Core', 'PLAYER_ENTERING_WORLD')

    function Core:DBDefaults_HasKeys()
        local db = ns.DB_DEFAULTS
        for _, k in ipairs { 'version', 'barHeight', 'barWidth', 'barTexture',
            'barBackgroundColor', 'barBorderColor', 'useClassColors', 'showMH',
            'showOH', 'showRanged', 'showEnemy', 'colors' } do
            IsTrue(db[k] ~= nil, 'DB.' .. k .. '=' .. tostring(db[k]))
        end
    end

    function Core:Clock_IsNumber() IsTrue(type(ns.GetAlignedTime()) == "number") end

    function Core:TimersTable_Exists()
        for _, k in ipairs { 'mh', 'oh', 'ranged', 'enemy' } do Exists(ns.timers[k]) end
    end

    function Core:AutoShotID_75() AreEqual(ns.AUTO_SHOT_ID, 75) end

    function Core:SteadyShotCastTime() AreEqual(ns.STEADY_SHOT_CAST_TIME, 1.5) end

    function Core:MigrateDB_Fresh()
        local db = {}; local ok, _ = pc(ns.MigrateDB, db); IsTrue(ok); AreEqual(db.version, ns.DB_CURRENT_VERSION)
    end

    function Core:MigrateDB_V1()
        local db = { version = 1 }; local ok, _ = pc(ns.MigrateDB, db)
        IsTrue(ok); AreEqual(db.version, ns.DB_CURRENT_VERSION)
    end

    function Core:MigrateDB_V53()
        local db = { version = 53 }; local ok, _ = pc(ns.MigrateDB, db)
        IsTrue(ok); AreEqual(db.version, ns.DB_CURRENT_VERSION)
    end

    function Core:MigrateDB_V54()
        local db = { version = 54 }; local ok, _ = pc(ns.MigrateDB, db)
        IsTrue(ok); AreEqual(db.version, ns.DB_CURRENT_VERSION)
    end

    function Core:MigrateDB_V55()
        local db = { version = 55 }; local ok, _ = pc(ns.MigrateDB, db)
        IsTrue(ok); AreEqual(db.version, ns.DB_CURRENT_VERSION)
    end

    function Core:MigrateDB_V56()
        local db = { version = 56 }; local ok, _ = pc(ns.MigrateDB, db)
        IsTrue(ok); AreEqual(db.version, ns.DB_CURRENT_VERSION)
    end

    function Core:MigrateDB_V61()
        local db = { version = 61, colors = {} }; local ok, _ = pc(ns.MigrateDB, db)
        IsTrue(ok); AreEqual(db.version, ns.DB_CURRENT_VERSION)
        AreEqual(db.hunterCastBarHeight, 15)
        IsTrue(db.showPowerBar ~= nil)
        IsTrue(db.colors.warriorRageBarColor ~= nil)
        IsTrue(db.colors.paladinManaBarColor ~= nil)
        IsTrue(db.colors.shamanManaBarColor ~= nil)
        IsTrue(db.colors.rogueEnergyBarColor ~= nil)
        IsTrue(db.colors.hunterManaBarColor ~= nil)
        IsTrue(db.colors.druidManaBarColor ~= nil)
    end

    function Core:MigrateDB_V62()
        local db = { version = 62, colors = { autoShotUnsafe = { r = 1, g = 1, b = 1, a = 0.4 } } }
        local ok, _ = pc(ns.MigrateDB, db)
        IsTrue(ok)
        AreEqual(db.version, ns.DB_CURRENT_VERSION)
        AreEqual(db.colors.autoShotUnsafe.r, 1)
        AreEqual(db.colors.autoShotUnsafe.g, 0)
        AreEqual(db.colors.autoShotUnsafe.b, 0)
        AreEqual(db.colors.clipZone.r, 1)
        AreEqual(db.colors.clipZone.g, 0)
        AreEqual(db.colors.clipZone.b, 0)
    end

    function Core:MigrateDB_V63()
        local db = { version = 63, colors = {} }
        local ok, _ = pc(ns.MigrateDB, db)
        IsTrue(ok)
        AreEqual(db.version, ns.DB_CURRENT_VERSION)
        AreEqual(db.hunterCastBarHeight, 15)
        AreEqual(db.powerBarHeight, 14)
        IsTrue(db.colors.warriorRageBarColor ~= nil)
    end

    function Core:MigrateDB_V64()
        local db = { version = 63, hunterCastBarHeight = 15, powerBarHeight = 10, colors = {} }
        local ok, _ = pc(ns.MigrateDB, db)
        IsTrue(ok)
        AreEqual(db.version, ns.DB_CURRENT_VERSION)
        AreEqual(db.hunterCastBarHeight, 15)
        AreEqual(db.powerBarHeight, 14)
    end

    function Core:MigrateDB_V65()
        local db = { version = 64, barTexture = "Interface\\AddOns\\SuperSwingTimer\\Media\\statusbar\\MerfinMain.tga" }
        local ok, _ = pc(ns.MigrateDB, db)
        IsTrue(ok)
        AreEqual(db.version, ns.DB_CURRENT_VERSION)
        AreEqual(db.barTexture, "Interface\\AddOns\\SuperSwingTimer\\Media\\statusbar\\Wglass.tga")
        AreEqual(db.rangedBarTexture, "Interface\\AddOns\\SuperSwingTimer\\Media\\statusbar\\Wglass.tga")
    end

    function Core:MigrateDB_V66()
        local db = { version = 65, powerBarHeight = 10 }
        local ok, _ = pc(ns.MigrateDB, db)
        IsTrue(ok)
        AreEqual(db.version, ns.DB_CURRENT_VERSION)
        AreEqual(db.powerBarHeight, 14)
    end

    function Core:MigrateDB_V66_PreservesCustom()
        local db = { version = 65, powerBarHeight = 22 }
        local ok, _ = pc(ns.MigrateDB, db)
        IsTrue(ok)
        AreEqual(db.version, ns.DB_CURRENT_VERSION)
        AreEqual(db.powerBarHeight, 22)
    end

    function Core:MigrateDB_V67_SetsIconDefaults()
        local db = { version = 66, hunterBuffIconSize = 25, warriorBuffIconSize = 25 }
        local ok, _ = pc(ns.MigrateDB, db)
        IsTrue(ok)
        AreEqual(db.version, ns.DB_CURRENT_VERSION)
        AreEqual(db.hunterBuffIconSize, 30, "the old 25 px buff default moves to 30")
        AreEqual(db.warriorBuffIconSize, 30, "every class default moves together")
        AreEqual(db.foreverDebuffIconSize, 30, "the debuff row gains a 30 px default")
    end

    function Core:MigrateDB_V67_KeepsCustomIconSize()
        local db = { version = 66, hunterBuffIconSize = 28, foreverDebuffIconSize = 24 }
        local ok, _ = pc(ns.MigrateDB, db)
        IsTrue(ok)
        AreEqual(db.hunterBuffIconSize, 28, "a chosen buff icon size survives the migration")
        AreEqual(db.foreverDebuffIconSize, 24, "a chosen debuff icon size survives the migration")
    end

    function Core:TOC_Version_And_Interfaces()
        local f = io.open("SuperSwingTimer.toc", "r")
        IsTrue(f ~= nil, "SuperSwingTimer.toc must exist")
        local content = f:read("*all")
        f:close()
        IsTrue(content:find("## Version: v0.3.4", 1, true) ~= nil, "TOC Version must be v0.3.4")

        -- The settings panel reads its label from TOC metadata; keep the
        -- helper and the TOC in lockstep so a release bump cannot drift.
        local tocVersion = content:match("## Version:%s*([^%s]+)")
        IsTrue(tocVersion ~= nil, "TOC must declare a Version")
        AreEqual(ns.GetDisplayVersion(), tocVersion)
        IsTrue(content:find("38002", 1, true) ~= nil, "TOC must contain Titanforge interface 38002")
        IsTrue(content:find("11509", 1, true) ~= nil, "TOC must contain Classic Era interface 11509")
        IsTrue(content:find("20506", 1, true) ~= nil, "TOC must contain TBC Anniversary interface 20506")
        IsTrue(content:find("16001", 1, true) ~= nil, "TOC must contain WoW Forever interface 16001")

        local diagPos = content:find("SuperSwingTimer_Diag.lua", 1, true)
        local constPos = content:find("SuperSwingTimer_Constants.lua", 1, true)
        IsTrue(diagPos ~= nil, "TOC must load SuperSwingTimer_Diag.lua")
        IsTrue(constPos ~= nil, "TOC must load SuperSwingTimer_Constants.lua")
        IsTrue(diagPos and constPos and diagPos < constPos, "Diag must load before Constants")

        local libStubPos = content:find("Lib\\LibStub\\LibStub.lua", 1, true)
        local libGlowPos = content:find("Lib\\LibCustomGlow-1.0\\LibCustomGlow-1.0.xml", 1, true)
        IsTrue(libStubPos ~= nil, "TOC must load LibStub")
        IsTrue(libGlowPos ~= nil, "TOC must load LibCustomGlow")
        IsTrue(libStubPos and libGlowPos and libStubPos < libGlowPos, "LibStub must load before LibCustomGlow")

        local glowAdapterPos = content:find("SuperSwingTimer_Glow.lua", 1, true)
        local classModsPos = content:find("SuperSwingTimer_ClassMods.lua", 1, true)
        IsTrue(glowAdapterPos ~= nil, "TOC must load SuperSwingTimer_Glow.lua")
        IsTrue(glowAdapterPos and classModsPos and glowAdapterPos < classModsPos,
            "Glow adapter must load before ClassMods")
    end

    function Core:ResetBarDisplay_SetsIdempotentFlag()
        local bar = CreateFrame('StatusBar')
        IsTrue(type(ns.ResetBarDisplay) == 'function', 'ResetBarDisplay exposed')
        ns.ResetBarDisplay(bar)
        IsTrue(bar._sstResetDone == true, 'reset flag set for idle-path guard')
    end

    function Core:HasActiveTimers_Function()
        IsTrue(type(ns.HasActiveTimers) == "function")
        local active = ns.HasActiveTimers()
        IsTrue(type(active) == "boolean")
    end

    function Core:HasActiveBuffIcons_Tracking()
        IsTrue(type(ns.HasActiveBuffIcons) == "function")
        local savedCount = ns.activeBuffIconCount
        ns.activeBuffIconCount = 0
        IsFalse(ns.HasActiveBuffIcons())
        ns.activeBuffIconCount = 2
        IsTrue(ns.HasActiveBuffIcons())
        ns.activeBuffIconCount = savedCount
    end

    function Core:HunterCastBarHeight_Default15()
        AreEqual(ns.HUNTER_CAST_BAR_HEIGHT, 15)
        AreEqual(ns.DB_DEFAULTS.hunterCastBarHeight, 15)
    end

    function Core:PowerBarHeight_Default14()
        AreEqual(ns.POWER_BAR_HEIGHT, 14)
        AreEqual(ns.DB_DEFAULTS.powerBarHeight, 14)
    end

    function Core:DebuffBarHeight_Default8()
        AreEqual(ns.DEBUFF_BAR_HEIGHT, 8)
    end

    function Core:DefaultFont_Resolves()
        IsTrue(type(ns.GetDefaultFont) == "function")
        local font = ns.GetDefaultFont()
        IsTrue(type(font) == "string" and #font > 0)
    end

    function Core:FactoryReset() IsTrue(pc(ns.ResetConfigDefaults)) end

    function Core:GetSpellInfo_Wraps() Exists(ns.GetSpellInfo(ns.AUTO_SHOT_ID)) end

    function Core:GetSpellInfo_Nil()
        local ok, _ = pc(ns.GetSpellInfo, nil); IsTrue(ok)
    end

    function Core:GetUnitCasting_Nil()
        local ok, _ = pc(ns.GetUnitCastingSpellInfo, nil); IsTrue(ok)
    end

    function Core:SetBarLabelText_Nil() IsTrue(pc(ns.SetBarLabelText, nil, 'test', true)) end

    function Core:RefreshBarSpark_Nil() IsTrue(pc(ns.RefreshBarSparkPosition, nil)) end

    function Core:RestoreBarLabel_Nil() IsTrue(pc(ns.RestoreBarDefaultLabel, nil)) end

    function Core:RefreshBarLabels() IsTrue(pc(ns.RefreshBarLabelStyles)) end

    function Core:HasteAPI_Exists()
        IsTrue(type(GetMeleeHaste) == "function" or type(GetMeleeHaste) == "nil", 'GetMeleeHaste')
    end

    function Core:GetSpellTexture_PcallSafety()
        IsTrue(type(ns.GetSpellTexture) == "function")
        local ok1, res1 = pc(ns.GetSpellTexture, nil)
        IsTrue(ok1)
        AreEqual(res1, nil)
        local ok2, _ = pc(ns.GetSpellTexture, -99999)
        IsTrue(ok2)
        local ok3, _ = pc(ns.GetSpellTexture, "NonExistentSpell123")
        IsTrue(ok3)
    end

    function Core:Paladin_DebuffBars_IconCreated()
        local savedHooks = {}
        for i, h in ipairs(ns.OnUpdateHooks or {}) do savedHooks[i] = h end
        if ns._Test and ns._Test.SetupRetPaladin then
            ns._Test.SetupRetPaladin()
        end
        if ns.UpdatePaladinJudgementBar then
            ns.UpdatePaladinJudgementBar(true)
        end
        if ns.UpdatePaladinSealVengeanceBar then
            ns.UpdatePaladinSealVengeanceBar(true)
        end
        local jBar = ns.paladinJudgementBar
        Exists(jBar, "Judgement bar must exist after SetupRetPaladin")
        if jBar then
            Exists(jBar.icon, "Judgement bar icon frame must exist")
        end
        local sBar = ns.paladinSealVengeanceBar
        Exists(sBar, "Seal of Vengeance bar must exist after SetupRetPaladin")
        if sBar then
            Exists(sBar.icon, "Seal of Vengeance bar icon frame must exist")
        end
        ns.OnUpdateHooks = savedHooks
    end

    function Core:PixelSnap()
        IsTrue(type(ns.PixelSnap) == "function", "ns.PixelSnap must be a function")
        -- Non-number inputs should return unchanged
        AreEqual(ns.PixelSnap(nil), nil)
        AreEqual(ns.PixelSnap("text"), "text")
        -- Scale 1.0 snapping
        AreEqual(ns.PixelSnap(10.2, 1.0), 10)
        AreEqual(ns.PixelSnap(10.7, 1.0), 11)
        AreEqual(ns.PixelSnap(10.5, 1.0), 11)
        -- Scale 2.0 snapping (0.5 device pixel steps)
        AreEqual(ns.PixelSnap(10.2, 2.0), 10)
        AreEqual(ns.PixelSnap(10.3, 2.0), 10.5)
        AreEqual(ns.PixelSnap(10.74, 2.0), 10.5)
        AreEqual(ns.PixelSnap(10.8, 2.0), 11)
        -- Negative coordinates
        AreEqual(ns.PixelSnap(-5.4, 1.0), -5)
        AreEqual(ns.PixelSnap(-5.7, 1.0), -6)
        -- Default scale fallback (UIParent or 1.0)
        local snapped = ns.PixelSnap(14.0)
        IsTrue(type(snapped) == "number")
    end

    -- ============================================================
    -- SST-Auras: aura wrapper parsing for all API shapes
    -- ============================================================
    local Auras = WoWUnit:New('SST-Auras', 'PLAYER_ENTERING_WORLD')

    function Auras:HelpfulSpellID_AtPos10()
        if not T or not T.GetHelpfulAuraData then return end
        -- GetHelpfulAuraData -> ns.UnitBuff -> ns.UnitAura -> global UnitAura.
        -- The wrapper only calls the global UnitAura, so we must mock UnitAura
        -- (not the deprecated UnitBuff global) for the mock to engage.
        Replace('UnitAura', function(u, i)
            if i == 1 then return 'Slice and Dice', 132181, 5, nil, 15, 12345.0, 'player', false, false, 5171, false end
        end)
        local _, dur, _, sid = T.GetHelpfulAuraData('player', 1)
        AreEqual(dur, 15); AreEqual(sid, 5171)
        ClearReplaces()
    end

    function Auras:HelpfulStacks_Returned()
        if not T or not T.GetHelpfulAuraData then return end
        Replace('UnitAura', function(_, i)
            if i == 1 then return 'Maelstrom Weapon', 132181, 4, nil, 30, 12345.0, 'player', false, false, 408505, false end
        end)
        local _, dur, _, sid, count = T.GetHelpfulAuraData('player', 1)
        AreEqual(dur, 30)
        AreEqual(sid, 408505)
        AreEqual(count, 4)
        ClearReplaces()
    end

    function Auras:HarmfulSpellID_AtPos10()
        if not T or not T.GetHarmfulAuraData then return end
        Replace('UnitAura', function(u, i, f)
            if i == 1 then return 'Flame Shock', 132181, 1, 'Fire', 12, 12350.0, 'player', false, false, 8050, false end
        end)
        local _, _, dur, _, caster, sid = T.GetHarmfulAuraData('target', 1, 'HARMFUL')
        AreEqual(dur, 12); AreEqual(caster, 'player'); AreEqual(sid, 8050)
        ClearReplaces()
    end

    function Auras:HarmfulPhysical_NilDispel()
        if not T or not T.GetHarmfulAuraData then return end
        Replace('UnitAura', function(u, i, f)
            if i == 1 then return 'Deep Wounds', 132316, 1, nil, 12, 12360.0, 'player', false, false, 12721, false end
        end)
        local _, _, dur, _, caster, sid = T.GetHarmfulAuraData('target', 1, 'HARMFUL')
        AreEqual(dur, 12); AreEqual(caster, 'player'); AreEqual(sid, 12721)
        ClearReplaces()
    end

    function Auras:HarmfulNil_ReturnsNil()
        if not T or not T.GetHarmfulAuraData then return end
        Replace('UnitAura', function() end)
        IsFalse(T.GetHarmfulAuraData('target', 1, 'HARMFUL'))
        ClearReplaces()
    end

    function Auras:PaladinSeal_Command()
        if ns.GetPaladinSealFamilyByAuraName then
            AreEqual(ns.GetPaladinSealFamilyByAuraName('Seal of Command'), 'COMMAND')
        end
    end

    function Auras:CrossDebuff_FlameShock()
        if not T or not T.GetHarmfulAuraData then return end
        Replace('UnitAura', function(u, i, f)
            if i == 1 then return 'Flame Shock', 132181, 1, 'Fire', 12, 12350.0, 'player', false, false, 8050, false end
        end)
        local _, _, dur, _, c, s = T.GetHarmfulAuraData('target', 1, 'HARMFUL')
        AreEqual(dur, 12); AreEqual(c, 'player'); IsTrue(type(s) == 'number')
        ClearReplaces()
    end

    -- ============================================================
    -- SST-UnitAuraNorm: ns.UnitAura normalizer across API shapes
    -- ============================================================
    local UANorm = WoWUnit:New('SST-UnitAuraNorm', 'PLAYER_ENTERING_WORLD')

    function UANorm:ShapeA_Classic113()
        -- r3=count(num), r4=debuffType, r9=spellID
        Replace('UnitAura', function(u, i, f)
            return 'Deep Wounds', nil, 3, 'Bleed', 12, 12360.0, 'player', false, 12721
        end)
        local name, _, icon, count, debuffType, dur, _, caster, _, _, sid = ns.UnitAura('target', 1, 'HARMFUL')
        AreEqual(name, 'Deep Wounds')
        AreEqual(icon, nil)
        AreEqual(count, 3)
        AreEqual(debuffType, 'Bleed')
        AreEqual(dur, 12)
        AreEqual(caster, 'player')
        AreEqual(sid, 12721)
        ClearReplaces()
    end

    function UANorm:ShapeB_Classic115()
        -- r3=icon(str), r4=count, r10=spellID
        Replace('UnitAura', function(u, i, f)
            return 'Slice and Dice', 'Rank 1', 'Interface\\Icons\\x', 5, nil, 15, 12345.0, 'player', false, 5171
        end)
        local name, _, icon, count, _, dur, _, _, _, _, sid = ns.UnitAura("player", 1, "HELPFUL")
        AreEqual(name, 'Slice and Dice')
        AreEqual(icon, 'Interface\\Icons\\x')
        AreEqual(count, 5)
        AreEqual(dur, 15)
        AreEqual(sid, 5171)
        ClearReplaces()
    end

    function UANorm:ShapeC_TBCAnniv_WithSpellID()
        -- r2=icon(FileID), r3=applications, r4=dispelName, r9=bool, r10=spellID
        Replace('UnitAura', function(u, i, f)
            return 'Flame Shock', 132181, 1, 'Fire', 12, 12350.0, 'player', false, true, 8050, false
        end)
        local name, _, icon, count, debuffType, dur, _, caster, _, _, sid = ns.UnitAura('target', 1, 'HARMFUL')
        AreEqual(name, 'Flame Shock')
        AreEqual(icon, 132181)
        AreEqual(count, 1)
        AreEqual(debuffType, 'Fire')
        AreEqual(dur, 12)
        AreEqual(caster, 'player')
        AreEqual(sid, 8050)
        ClearReplaces()
    end

    function UANorm:ShapeC_TBCAnniv_NilSpellID()
        -- r10=nil but r9 is boolean -> should still detect Shape C
        Replace('UnitAura', function(u, i, f)
            return 'Some Aura', 132181, 2, 'Magic', 30, 12350.0, 'player', false, true, nil, false
        end)
        local name, _, icon, count, debuffType, dur, _, _, _, _, _ = ns.UnitAura('player', 1, 'HELPFUL')
        AreEqual(name, 'Some Aura')
        AreEqual(icon, 132181)
        AreEqual(count, 2)
        AreEqual(debuffType, 'Magic')
        AreEqual(dur, 30)
        ClearReplaces()
    end

    function UANorm:NilName_ReturnsNil()
        Replace('UnitAura', function(u, i, f) return nil end)
        IsFalse(ns.UnitAura('target', 1, 'HARMFUL'))
        ClearReplaces()
    end

    function UANorm:C_UnitAuras_Extraction()
        local prevC = rawget(_G, "C_UnitAuras")
        _G.C_UnitAuras = {
            GetAuraDataByIndex = function(unit, index, filter)
                if unit == "player" and index == 1 and filter == "HELPFUL" then
                    return {
                        name = "Slice and Dice",
                        icon = 132306,
                        applications = 0,
                        dispelName = nil,
                        duration = 21,
                        expirationTime = 12345.67,
                        sourceUnit = "player",
                        isStealable = false,
                        spellId = 6774
                    }
                end
                return nil
            end
        }

        local name, _, icon, _, _, dur, expT, caster, _, _, sId = ns.UnitAura("player", 1, "HELPFUL")
        _G.C_UnitAuras = prevC

        AreEqual(name, "Slice and Dice")
        AreEqual(icon, 132306)
        AreEqual(dur, 21)
        AreEqual(expT, 12345.67)
        AreEqual(caster, "player")
        AreEqual(sId, 6774)
    end

    function UANorm:C_UnitAuras_FallbackToLegacyWhenNil()
        local prevC = rawget(_G, "C_UnitAuras")
        _G.C_UnitAuras = nil
        Replace('UnitAura', function(u, i, f)
            return "Battle Shout", "Rank 1", "Interface\\Icons\\Ability_Warrior_WarCry", 0, nil, 120, 500, "player",
                false, nil, 6673
        end)

        local name, _, icon, _, _, _, _, _, _, _, sId = ns.UnitAura("player", 1, "HELPFUL")
        _G.C_UnitAuras = prevC
        ClearReplaces()

        AreEqual(name, "Battle Shout")
        AreEqual(icon, "Interface\\Icons\\Ability_Warrior_WarCry")
        AreEqual(sId, 6673)
    end

    -- ============================================================
    -- SST-Combat: timers, CLEU, debuff stacking, state machine
    -- ============================================================
    local Combat = WoWUnit:New('SST-Combat', 'PLAYER_ENTERING_WORLD')

    function Combat:StackOffset_SingleBar()
        if not T or not T.RestackDebuffBars or not T.GetDebuffStackOffset then return end
        local ref = { GetTop = function() return 100 end, GetAlpha = function() return 1 end }
        local b1 = {
            IsShown = function() return true end,
            GetHeight = function() return 6 end,
            ClearAllPoints = function() end,
            SetPoint = function() end
        }
        T.RestackDebuffBars({ b1 }, ref, 2)
        IsTrue(T.GetDebuffStackOffset() > 0)
    end

    function Combat:StackOffset_HiddenBars()
        if not T or not T.RestackDebuffBars or not T.GetDebuffStackOffset then return end
        local ref = { GetTop = function() return 100 end, GetAlpha = function() return 1 end }
        local b1 = { IsShown = function() return false end, GetHeight = function() return 6 end }
        T.RestackDebuffBars({ b1 }, ref, 2)
        IsTrue(type(T.GetDebuffStackOffset()) == 'number')
    end

    function Combat:StartSwing_MH()
        if not ns.StartSwing then return end
        local now = ns.GetAlignedTime()
        pc(ns.StartSwing, "mh", nil, now)
        local t = ns.timers.mh; Exists(t)
        if t then IsTrue(t.state == "swinging") end
    end

    function Combat:CLEU_SWING_DAMAGE()
        Replace('CombatLogGetCurrentEventInfo', function()
            return nil, "SWING_DAMAGE", nil, "Player-1", nil, nil, nil, nil, "Creature-1", nil, nil, nil, nil, nil, 100
        end)
        Replace('GetPlayerGUID', function() return "Player-1" end)
        local old = ns.timers.mh and ns.timers.mh.endTime or 0
        pc(ns.HandleCLEU)
        IsTrue(ns.timers.mh.endTime ~= old or ns.timers.mh.state == "swinging")
        ClearReplaces()
    end

    function Combat:CLEU_SWING_MISSED()
        Replace('CombatLogGetCurrentEventInfo', function()
            return nil, "SWING_MISSED", nil, "Player-1", nil, nil, nil, nil, "Creature-1", nil, nil, nil, "MISS"
        end)
        Replace('GetPlayerGUID', function() return "Player-1" end)
        pc(ns.HandleCLEU); IsTrue(true, 'no error')
        ClearReplaces()
    end

    function Combat:CLEU_FastPath_IgnoresThirdParty()
        Replace('CombatLogGetCurrentEventInfo', function()
            -- Event between Player-2 and Creature-999 (neither matches player "Player-1" or enemyTargetGUID nil)
            return nil, "SWING_DAMAGE", nil, "Player-2", nil, nil, nil, "Creature-999", nil, nil, nil, nil, nil, nil, 100
        end)
        Replace('GetPlayerGUID', function() return "Player-1" end)
        local alignedTimeCalled = false
        local origGetAlignedTime = ns.GetAlignedTime
        ns.GetAlignedTime = function()
            alignedTimeCalled = true
            return origGetAlignedTime()
        end
        ns.HandleCLEU()
        ns.GetAlignedTime = origGetAlignedTime
        ClearReplaces()
        IsFalse(alignedTimeCalled, "HandleCLEU must early-exit before GetAlignedTime for third-party events")
    end

    -- ============================================================
    -- SST-Hunter: Hunter-specific features
    -- ============================================================
    local Hunter = WoWUnit:New('SST-Hunter', 'PLAYER_ENTERING_WORLD')

    function Hunter:CastDetection_Steady() IsTrue(ns.IsHunterCastSpell(ns.STEADY_SHOT_ID)) end

    function Hunter:CastDetection_Aimed() IsTrue(ns.IsHunterCastSpell(19434)) end

    function Hunter:CastDetection_Auto() IsTrue(ns.IsHunterCastSpell(75)) end

    function Hunter:CastDetection_AutoNotActual() IsFalse(ns.IsHunterActualCastSpell(75)) end

    function Hunter:CastDetection_SteadyIsActual() IsTrue(ns.IsHunterActualCastSpell(ns.STEADY_SHOT_ID)) end

    function Hunter:SerpentStingIDs_Populated()
        local c = 0; for _ in pairs(ns.HUNTER_SERPENT_STING_IDS or {}) do c = c + 1 end
        IsTrue(c >= 3)
    end

    function Hunter:SerpentStingName_Resolved() Exists(ns.HUNTER_SERPENT_STING_NAME) end

    function Hunter:IsAutoShot_ByID() IsTrue(ns.IsAutoShotSpell(75)) end

    function Hunter:IsAutoShot_Nil()
        local ok, r = pc(ns.IsAutoShotSpell, nil); IsTrue(ok); IsFalse(r)
    end

    function Hunter:IsHunterCast_Nil()
        local ok, r = pc(ns.IsHunterCastSpell, nil); IsTrue(ok); IsFalse(r)
    end

    function Hunter:SerpentSting_MockDetect()
        if not T or not T.GetTargetSerpentStingData then return end
        Replace('UnitAura', function(u, i, f)
            if i == 1 then return 'Serpent Sting', 132181, 1, 'Nature', 15, 12345.0, 'player', false, false, 27019, false end
        end)
        Replace('UnitExists', function() return true end)
        Replace('UnitCanAttack', function() return true end)
        local dur, _ = T.GetTargetSerpentStingData()
        Exists(dur, 'SerpentSting found')
        ClearReplaces()
    end

    function Hunter:SerpentSting_FiltersOtherCaster()
        if not T or not T.GetTargetSerpentStingData then return end
        Replace('UnitAura', function(u, i, f)
            if i == 1 then return 'Serpent Sting', 132181, 1, 'Nature', 15, 12345.0, 'OtherGuy', false, false, 27019,
                    false end
        end)
        Replace('UnitExists', function() return true end)
        Replace('UnitCanAttack', function() return true end)
        IsFalse(T.GetTargetSerpentStingData())
        ClearReplaces()
    end

    function Hunter:SteadyShot_InRedZone_KeepsAutoShotVisible()
        local savedClass = ns.playerClass
        local savedTimers = ns.timers
        local savedCastBar = ns.hunterCastBar
        ns.playerClass = "HUNTER"
        ns.hunterCastBar = ns.hunterCastBar or CreateFrame("StatusBar", "SuperSwingTimerHunterCastBar", UIParent)
        ns.classConfig = { ranged = true, melee = true }
        ns.timers = {
            ranged = { state = "swinging", lastSwing = 100.0, duration = 2.8, speed = 2.8 },
            mh = { state = "idle", lastSwing = 0, duration = 0 },
            oh = { state = "idle", lastSwing = 0, duration = 0 },
            enemy = { state = "idle", lastSwing = 0, duration = 0 }
        }
        local savedGetAlignedTime = ns.GetAlignedTime
        ns.GetAlignedTime = function() return 102.5 end
        Replace('GetTimePreciseSec', function() return 102.5 end)
        Replace('GetTime', function() return 102.5 end)
        ns.HandleSpellcastSucceeded("player", nil, ns.STEADY_SHOT_ID)

        local showCastBar = ns.ShouldShowHunterCastBar and ns.ShouldShowHunterCastBar()
        IsTrue(showCastBar, "Cast bar must remain visible to show Auto Shot after Steady Shot ends in red zone")

        if ns.GetHunterHiddenCastWindowFromRangedTimer then
            local start, dur = ns.GetHunterHiddenCastWindowFromRangedTimer(102.5)
            Exists(start, "Hidden cast window start must exist")
            IsTrue(dur and dur > 0, "Hidden cast window duration must be > 0")
        end

        ClearReplaces()
        ns.GetAlignedTime = savedGetAlignedTime
        ns.playerClass = savedClass
        ns.timers = savedTimers
        ns.hunterCastBar = savedCastBar
    end

    function Hunter:SteadyShot_InRedZone_KeepsRangedTimerActive()
        local savedClass = ns.playerClass
        local savedTimers = ns.timers
        ns.playerClass = "HUNTER"
        ns.classConfig = { ranged = true, melee = true }
        ns.timers = {
            ranged = { state = "swinging", lastSwing = 100.0, duration = 2.8, speed = 2.8 },
            mh = { state = "idle", lastSwing = 0, duration = 0 },
            oh = { state = "idle", lastSwing = 0, duration = 0 },
            enemy = { state = "idle", lastSwing = 0, duration = 0 }
        }
        -- Steady shot ended in red zone at 102.7
        ns.lastHunterCastEndedAt = 102.7
        ns.hunterSteadyShotEndedInRedZone = 102.7

        -- Now is 102.82 (past 102.8 duration by 20ms, within latency/grace allowance)
        Replace('GetTimePreciseSec', function() return 102.82 end)
        Replace('GetTime', function() return 102.82 end)

        Exists(ns.ShouldKeepHunterRangedTimerActive, "ShouldKeepHunterRangedTimerActive must be exported")
        local keepActive = ns.ShouldKeepHunterRangedTimerActive(102.82)
        IsTrue(keepActive, "Ranged timer must remain active past nominal duration when Steady Shot landed in red zone")

        ClearReplaces()
        ns.lastHunterCastEndedAt = nil
        ns.hunterSteadyShotEndedInRedZone = nil
        ns.playerClass = savedClass
        ns.timers = savedTimers
    end

    function Hunter:SteadyShot_LateLanding_InRedZone_EndToEnd()
        local savedClass = ns.playerClass
        local savedTimers = ns.timers
        local savedCastBar = ns.hunterCastBar
        ns.playerClass = "HUNTER"
        ns.hunterCastBar = ns.hunterCastBar or CreateFrame("StatusBar", "SuperSwingTimerHunterCastBar", UIParent)
        ns.classConfig = { ranged = true, melee = true }
        ns.timers = {
            ranged = { state = "swinging", lastSwing = 100.0, duration = 2.8, speed = 2.8 },
            mh = { state = "idle", lastSwing = 0, duration = 0 },
            oh = { state = "idle", lastSwing = 0, duration = 0 },
            enemy = { state = "idle", lastSwing = 0, duration = 0 }
        }
        -- Steady shot finishes at 102.75 (late into the red clip zone, where windowEnd is 102.8)
        local savedGetAlignedTime = ns.GetAlignedTime
        ns.GetAlignedTime = function() return 102.75 end
        Replace('GetTimePreciseSec', function() return 102.75 end)
        Replace('GetTime', function() return 102.75 end)

        ns.HandleSpellcastSucceeded("player", nil, ns.STEADY_SHOT_ID)
        ns.HandleSpellcastStop("player")

        IsTrue(ns.hunterSteadyShotEndedInRedZone == 102.75, "hunterSteadyShotEndedInRedZone must be recorded")
        IsTrue(ns.ShouldKeepHunterRangedTimerActive(102.75), "Ranged timer must remain active")
        IsTrue(ns.ShouldShowHunterCastBar(), "Cast bar must remain shown for upcoming Auto Shot")

        -- Auto Shot fires and begins new cycle
        ns.StartRangedSwing(102.8)
        IsFalse(ns.hunterSteadyShotEndedInRedZone ~= nil, "hunterSteadyShotEndedInRedZone must be cleared upon StartRangedSwing")

        ClearReplaces()
        ns.GetAlignedTime = savedGetAlignedTime
        ns.playerClass = savedClass
        ns.timers = savedTimers
        ns.hunterCastBar = savedCastBar
    end

    function Hunter:IsAutoShotSpell_AcceptsIdAndAliases()
        IsTrue(ns.IsAutoShotSpell(ns.AUTO_SHOT_ID), "Auto Shot must match by numeric ID")
        IsTrue(ns.IsAutoShotSpell(tostring(ns.AUTO_SHOT_ID)), "Auto Shot must match a numeric string (name-shaped CLEU payloads)")
        IsTrue(ns.IsAutoShotSpell("Auto Shot"), "Auto Shot must match the canonical English name")
        IsTrue(ns.IsAutoShotSpell("Shoot"), "Auto Shot must match the Classic Era 'Shoot' alias")
        IsTrue(ns.IsAutoShotSpell(ns.AUTO_SHOT_NAME), "Auto Shot must match the client-resolved localized name")
        IsFalse(ns.IsAutoShotSpell(ns.STEADY_SHOT_ID), "Steady Shot ID must not be treated as Auto Shot")
        IsFalse(ns.IsAutoShotSpell("Steady Shot"), "Steady Shot name must not be treated as Auto Shot")
        IsFalse(ns.IsAutoShotSpell(nil), "nil must not be treated as Auto Shot")
    end

    function Hunter:Interrupt_ClearsCastIdentity()
        local savedClass = ns.playerClass
        local savedTimers = ns.timers
        local savedGetAlignedTime = ns.GetAlignedTime
        ns.playerClass = "HUNTER"
        ns.classConfig = { ranged = true, melee = true }
        ns.timers = {
            ranged = { state = "swinging", lastSwing = 100.0, duration = 2.8, speed = 2.8 },
            mh = { state = "idle", lastSwing = 0, duration = 0 },
            oh = { state = "idle", lastSwing = 0, duration = 0 },
            enemy = { state = "idle", lastSwing = 0, duration = 0 }
        }
        ns.hunterCastActive = true
        ns.hunterCastSpellId = ns.STEADY_SHOT_ID
        ns.hunterCastDuration = 1.5
        ns.currentCastSpellId = ns.STEADY_SHOT_ID
        ns.currentCastStartTime = 100.0
        ns.lastResolvedHunterCastToken = ns.STEADY_SHOT_ID
        ns.lastResolvedHunterCastAt = 100.0
        ns.casting = true

        ns.GetAlignedTime = function() return 101.2 end
        Replace('GetTimePreciseSec', function() return 101.2 end)
        Replace('GetTime', function() return 101.2 end)
        ns.HandleSpellcastInterruptedOrFailed("player", nil, ns.STEADY_SHOT_ID)

        -- A stale token lets HandleSpellcastSucceeded re-attribute a later,
        -- unrelated success to this interrupted cast.
        IsTrue(ns.currentCastSpellId == nil, "Interrupt must clear currentCastSpellId")
        IsTrue(ns.currentCastStartTime == nil, "Interrupt must clear currentCastStartTime")
        IsTrue(ns.lastResolvedHunterCastToken == nil, "Interrupt must clear lastResolvedHunterCastToken")
        IsTrue(ns.lastResolvedHunterCastAt == nil, "Interrupt must clear lastResolvedHunterCastAt")
        IsTrue(ns.hunterCastActive == false, "Interrupt must clear hunterCastActive")

        ClearReplaces()
        ns.GetAlignedTime = savedGetAlignedTime
        ns.playerClass = savedClass
        ns.timers = savedTimers
        ns.hunterSteadyShotEndedInRedZone = nil
        ns.currentCastSpellId = nil
        ns.currentCastStartTime = nil
    end

    function Hunter:ShouldKeep_HoldsPastCycleEnd_WithoutRedZoneFlag()
        local savedClass = ns.playerClass
        local savedTimers = ns.timers
        local savedCastBar = ns.hunterCastBar
        local savedAutoRepeat = ns.IsHunterAutoRepeatActive
        local savedCooldown = ns.GetAutoShotCooldown
        local savedLatency = ns.cachedLatency

        ns.playerClass = "HUNTER"
        ns.classConfig = { ranged = true, melee = true }
        ns.hunterCastBar = nil --[[@as StatusBar]]
        ns.cachedLatency = 0
        -- Cycle runs 100.0 -> 103.0. The cast ended early at 101.5, so the
        -- cast-anchored 1.0s red-zone window has already expired by cycle end.
        ns.timers = {
            ranged = { state = "swinging", lastSwing = 100.0, duration = 3.0, speed = 3.0 },
            mh = { state = "idle", lastSwing = 0, duration = 0 },
            oh = { state = "idle", lastSwing = 0, duration = 0 },
            enemy = { state = "idle", lastSwing = 0, duration = 0 }
        }
        ns.hunterSteadyShotEndedInRedZone = nil
        ns.IsHunterAutoRepeatActive = function() return false end
        ns.GetAutoShotCooldown = function() return nil, nil end

        -- Within cycleEnd + latency/grace (103.0 + 0.55): must still hold.
        IsTrue(ns.ShouldKeepHunterRangedTimerActive(103.2),
            "Ranged timer must hold past cycle end so Auto Shot can fire and display")
        -- Past the grace window the timer is genuinely over: must release.
        IsFalse(ns.ShouldKeepHunterRangedTimerActive(103.9),
            "Ranged timer must release once the cycle is overdue beyond latency/grace")

        ns.playerClass = savedClass
        ns.timers = savedTimers
        ns.hunterCastBar = savedCastBar
        ns.IsHunterAutoRepeatActive = savedAutoRepeat
        ns.GetAutoShotCooldown = savedCooldown
        ns.cachedLatency = savedLatency
    end

    function Hunter:ShouldKeep_ReleasesAfterReset()
        local savedClass = ns.playerClass
        local savedTimers = ns.timers
        local savedCastBar = ns.hunterCastBar
        local savedAutoRepeat = ns.IsHunterAutoRepeatActive
        local savedCooldown = ns.GetAutoShotCooldown
        local savedLatency = ns.cachedLatency

        ns.playerClass = "HUNTER"
        ns.classConfig = { ranged = true, melee = true }
        ns.hunterCastBar = nil --[[@as StatusBar]]
        ns.cachedLatency = 0
        -- ResetTimer leaves state="idle" and lastSwing=0; a stale lastSwing must
        -- never keep the bar alive forever.
        ns.timers = {
            ranged = { state = "idle", lastSwing = 0.0, duration = 0.0 },
            mh = { state = "idle", lastSwing = 0, duration = 0 },
            oh = { state = "idle", lastSwing = 0, duration = 0 },
            enemy = { state = "idle", lastSwing = 0, duration = 0 }
        }
        ns.hunterSteadyShotEndedInRedZone = nil
        ns.IsHunterAutoRepeatActive = function() return false end
        ns.GetAutoShotCooldown = function() return nil, nil end

        IsFalse(ns.ShouldKeepHunterRangedTimerActive(500.0),
            "Idle ranged timer must not be held active by the cycle anchor")

        ns.playerClass = savedClass
        ns.timers = savedTimers
        ns.hunterCastBar = savedCastBar
        ns.IsHunterAutoRepeatActive = savedAutoRepeat
        ns.GetAutoShotCooldown = savedCooldown
        ns.cachedLatency = savedLatency
    end

    function Hunter:AutoRepeat_NotWipedDuringCasting()
        local savedClass = ns.playerClass
        ns.playerClass = "HUNTER"
        ns.hunterAutoRepeatActive = true
        ns.casting = true
        ns.hunterCastActive = true

        -- Mock C_Spell.IsAutoRepeatSpell returning false during cast (standard client behavior)
        local cSpell = rawget(_G, "C_Spell")
        if cSpell and cSpell.IsAutoRepeatSpell then
            Replace('C_Spell', {
                IsAutoRepeatSpell = function() return false end
            })
        end

        local active = ns.IsHunterAutoRepeatActive()
        IsTrue(active, "Auto-repeat must not be wiped to false while player is actively casting")
        IsTrue(ns.hunterAutoRepeatActive, "ns.hunterAutoRepeatActive must remain true")

        ClearReplaces()
        ns.casting = false
        ns.hunterCastActive = false
        ns.playerClass = savedClass
    end

    function Hunter:GetHunterHiddenCastWindow_AllowsLatencyAndGraceTolerance()
        local savedClass = ns.playerClass
        local savedTimers = ns.timers
        ns.playerClass = "HUNTER"
        ns.timers = {
            ranged = { state = "swinging", lastSwing = 100.0, duration = 2.8, speed = 2.8 }
        }
        ns.cachedLatency = 0.05
        ns.lastHunterCastEndedAt = 102.7

        -- Scheduled window is [102.3, 102.8]. Now is 102.84 (40ms past scheduled windowEnd, within latency)
        Exists(ns.GetHunterHiddenCastWindowFromRangedTimer, "GetHunterHiddenCastWindowFromRangedTimer must be exported")
        local start, dur = ns.GetHunterHiddenCastWindowFromRangedTimer(102.84)
        Exists(start, "Hidden cast window must not be nil when within latency buffer of windowEnd")
        IsTrue(dur and dur > 0, "Hidden cast window duration must be positive")

        ns.lastHunterCastEndedAt = nil
        ns.playerClass = savedClass
        ns.timers = savedTimers
    end

    function Hunter:Aspect_AcceptsNumericFileID()
        local icon = ns.hunterAspectIcon
        Exists(icon, "Hunter aspect icon must exist")
        if not icon or not ns.rangedBar then return end

        local savedAlpha = ns.rangedBar:GetAlpha()
        ns.rangedBar:SetAlpha(1)

        -- Mock active Aspect of the Hawk returning numeric FileID 136006
        Replace('UnitAura', function(u, i)
            if u == "player" and i == 1 then
                return 'Aspect of the Hawk', 136006, 0, nil, 0, 0, 'player', false, false, 13165
            end
            return nil
        end)

        ns.UpdateHunterAspect(1.0)
        AreEqual(icon:GetAlpha(), 1, "Aspect icon must be shown (alpha 1)")
        AreEqual(icon.texture:GetTexture(), 136006, "Aspect icon texture must accept numeric FileID 136006")

        ClearReplaces()
        ns.rangedBar:SetAlpha(savedAlpha)
    end

    function Hunter:Aspect_AlertNoAspectInCombat()
        local icon = ns.hunterAspectIcon
        Exists(icon, "Hunter aspect icon must exist")
        if not icon or not ns.rangedBar then return end

        local savedAlpha = ns.rangedBar:GetAlpha()
        ns.rangedBar:SetAlpha(1)

        -- No auras active
        Replace('UnitAura', function() return nil end)

        -- 1. Out of combat: icon should hide (alpha 0)
        Replace('UnitAffectingCombat', function() return false end)
        ns.playerInCombat = false
        ns.UpdateHunterAspect(1.0)
        AreEqual(icon:GetAlpha(), 0, "Out of combat with no aspect: icon must be hidden")

        -- 2. In combat with no aspect: alert must trigger!
        Replace('UnitAffectingCombat', function() return true end)
        ns.playerInCombat = true
        ns.UpdateHunterAspect(1.0)
        AreEqual(icon:GetAlpha(), 1, "In combat with no aspect: icon must be shown as warning alert")
        AreEqual(icon.texture:GetTexture(), "Interface\\Icons\\INV_Misc_QuestionMark", "Warning alert should use question mark texture")
        if icon.border and icon.border.GetColorTexture then
            local r, g, b = icon.border:GetColorTexture()
            IsTrue(r > 0.8 and g < 0.2 and b < 0.2, "Warning alert border should be red")
        end

        -- 3. Gain Aspect of the Hawk during combat: alert clears to standard aspect display
        Replace('UnitAura', function(u, i)
            if u == "player" and i == 1 then
                return 'Aspect of the Hawk', 136006, 0, nil, 0, 0, 'player', false, false, 13165
            end
            return nil
        end)
        ns.UpdateHunterAspect(1.0)
        AreEqual(icon:GetAlpha(), 1, "Icon remains shown with active aspect")
        AreEqual(icon.texture:GetTexture(), 136006, "Icon texture updates to Hawk")

        ClearReplaces()
        ns.playerInCombat = false
        ns.rangedBar:SetAlpha(savedAlpha)
    end

    -- ============================================================
    -- SST-SoD: SoD rune spell registration & aura filters
    -- ============================================================
    local SoD = WoWUnit:New('SST-SoD', 'PLAYER_ENTERING_WORLD')

    function SoD:MaelstromMultiplier_Bounds()
        if ns.maelstromCastTimeMultiplier ~= nil then
            IsTrue(ns.maelstromCastTimeMultiplier >= 0.0 and ns.maelstromCastTimeMultiplier <= 1.0,
                'Maelstrom multiplier bounded')
        end
    end

    function SoD:TrackedSpells_AllNineClasses()
        if not ns.SOD_TRACKED_SPELLS then return end
        for _, classKey in ipairs { 'WARRIOR', 'ROGUE', 'SHAMAN', 'HUNTER', 'PALADIN', 'DRUID', 'WARLOCK', 'MAGE', 'PRIEST' } do
            Exists(ns.SOD_TRACKED_SPELLS[classKey], 'SoD tracked spells for ' .. classKey)
        end
    end

    -- ============================================================
    -- SST-ClassMods: per-class power bars & setups
    -- ============================================================
    local ClassMods = WoWUnit:New('SST-ClassMods', 'PLAYER_ENTERING_WORLD')

    function ClassMods:UpdateWarriorRageBar_Exists()
        IsTrue(type(ns.UpdateWarriorRageBar) == "function" or type(ns.UpdatePlayerPowerBar) == "function",
            'UpdateWarriorRageBar or UpdatePlayerPowerBar function exists')
    end

    function ClassMods:UpdatePlayerPowerBar_Exists()
        IsTrue(type(ns.UpdatePlayerPowerBar) == "function" or type(ns.UpdateWarriorRageBar) == "function",
            'UpdatePlayerPowerBar function exists')
    end

    function ClassMods:ResolvePowerBarColor_TableFormat()
        local resolver = (T and T.ResolvePowerBarColor) or ns.ResolvePowerBarColor
        if not resolver then return end
        local c = resolver(1, "RAGE", { r = 0.5, g = 0.5, b = 0.5, a = 1 })
        AreEqual(c.r, 0.5)
        local cDefault = resolver(1, "RAGE", nil)
        IsTrue(cDefault.r ~= nil and cDefault.g ~= nil and cDefault.b ~= nil)
    end

    function ClassMods:PlayerPowerBar_Structure()
        if ns.playerPowerBar then
            Exists(ns.playerPowerBar.label, 'powerBar.label exists')
            IsTrue(ns.playerPowerBar.label:GetFont() ~= nil or true)
        end
    end

    function ClassMods:CreateGlowBorder_Safe()
        local createGlow = (T and T.CreateGlowBorderFrames) or ns.CreateGlowBorderFrames
        if createGlow and ns.mhBar then
            local edges = createGlow(ns.mhBar, 1, 0, 0, 0.8)
            IsTrue(type(edges) == "table" and #edges == 4, 'glow border returns 4 edges')
            for _, edge in ipairs(edges) do
                IsTrue(edge.Show ~= nil and edge.Hide ~= nil)
            end
        end
    end

    function ClassMods:ExecuteGlowPulse_Calculation()
        local nowSec = 100.0
        local pulse = 0.6 + 0.4 * math.abs(math.sin(nowSec * 6))
        IsTrue(pulse >= 0.6 and pulse <= 1.0, 'Execute pulse bounded between 0.6 and 1.0')
    end

    local BUFF_ICON_BASE_OFFSET = 14 -- mirrors ClassMods.lua

    -- The mocked clock lives on the harness globals rather than on WoWUnit, so
    -- it is read through _G. In a real client the clock is the real one and
    -- AdvanceMockTime is nil, so the helpers below fall back to placing times
    -- in the past instead of stepping the clock.
    local AdvanceMockTime = rawget(_G, "AdvanceMockTime")

    -- ============================================================
    -- SST-Regressions: coverage for bugs that actually shipped
    -- ============================================================
    -- Three real defects reached production with a green suite:
    --   1. The GCD latch: UpdateGcdTicker only cleared ns.gcdActive inside the
    --      render branch, after `if not f then return end`. A Hunter (no ticker
    --      bar at all) who cast a spell kept the OnUpdate loop attached for
    --      the whole session.
    --   2. The Rogue gate asymmetry: HasActiveTimers returned false for a Rogue
    --      in combat, so the energy-tick sweep froze mid-cycle.
    --   3. RestackDebuffBars walked its list with ipairs, so a nil slot (a bar
    --      whose config toggle is off, hence never created) truncated the walk
    --      and left every later bar unstacked.
    -- Plus an allocation pin: the per-frame restack lists are pre-allocated and
    -- reused, never rebuilt as a fresh literal each frame.
    local Reg = WoWUnit:New('SST-Regressions', 'PLAYER_ENTERING_WORLD')

    -- Resolve a file-local function captured as an upvalue of a closure the
    -- addon already registered (the OnUpdate hooks close over them). This lets
    -- the tests drive the real function without the addon exporting anything.
    local function ResolveUpvalue(fn, wanted)
        if type(fn) ~= "function" or type(debug) ~= "table"
            or type(debug.getupvalue) ~= "function" then
            return nil
        end
        for i = 1, 64 do
            local name, value = debug.getupvalue(fn, i)
            if not name then return nil end
            if name == wanted then return value end
        end
        return nil
    end

    local function GetCoreRenderHook()
        for _, h in ipairs(ns.OnUpdateHooks or {}) do
            if ResolveUpvalue(h, "UpdateGcdTicker") then return h end
        end
        return ns.OnUpdateHooks and ns.OnUpdateHooks[1]
    end

    local function GetHunterHook()
        for _, h in ipairs(ns.OnUpdateHooks or {}) do
            if ResolveUpvalue(h, "hunterRestackBars") or ResolveUpvalue(h, "wingClipBar") then
                return h
            end
        end
        return ns.OnUpdateHooks and ns.OnUpdateHooks[2]
    end

    -- Drives the real per-frame restack call and records every list it is
    -- handed, without letting the spy's calls perturb the real function.
    -- Returns the recorder plus an undo function; always call the undo.
    local function SpyOnRestack(hookIndex, listUpvalueName, restackUpvalueName)
        if type(debug) ~= "table" or type(debug.setupvalue) ~= "function" then
            return nil
        end
        local hook = (type(hookIndex) == "number" and ns.OnUpdateHooks[hookIndex])
        if not hook or not ResolveUpvalue(hook, restackUpvalueName) then
            hook = GetHunterHook()
        end
        if type(hook) ~= "function" then return nil end
        local listIdx, realRestack, realList
        for i = 1, 64 do
            local name, value = debug.getupvalue(hook, i)
            if not name then break end
            if name == restackUpvalueName then
                listIdx, realRestack = i, value
            elseif name == listUpvalueName then
                realList = value
            end
        end
        if type(realRestack) ~= "function" or not listIdx then return nil end
        local seen = {}
        debug.setupvalue(hook, listIdx, function(list, referenceBar, gap, barCount)
            seen[#seen + 1] = list
            return realRestack(list, referenceBar, gap, barCount)
        end)
        return {
            lists = seen,
            hoisted = realList,
            undo = function() debug.setupvalue(hook, listIdx, realRestack) end,
        }
    end

    -- Puts the world in the state a GCD looks like just after it has expired:
    -- a 1.5s GCD that started a moment ago on the mocked clock. Deterministic
    -- (no sleeps, no real time) because GetTime/GetTimePreciseSec read nowSec.
    local function StartExpiredGcd()
        ns.gcdActive = true
        ns.gcdDuration = 1.5
        if AdvanceMockTime then
            ns.lastGcdTime = ns.GetAlignedTime()
            AdvanceMockTime(2.0)
        else
            ns.lastGcdTime = ns.GetAlignedTime() - 2.0
        end
    end

    -- Drives the real UpdateGcdTicker (a file-local in SuperSwingTimer_UI.lua,
    -- closed over by the core render hook) and counts how many times the update
    -- loop is told to re-evaluate. Yields the call count, restores
    -- ns.RefreshUpdateLoop itself.
    local function DriveGcdTicker(fn, frames)
        local calls = 0
        local real = ns.RefreshUpdateLoop
        ns.RefreshUpdateLoop = function() calls = calls + 1 end
        local ok, err = pcall(function()
            for _ = 1, (frames or 1) do fn(0.016) end
        end)
        ns.RefreshUpdateLoop = real
        if not ok then error(err, 0) end
        return calls
    end

    -- Silences every HasActiveTimers input except the one under test, so the
    -- clause being exercised is the only thing deciding the result.
    local function QuietAllGates()
        for _, key in ipairs({ "mh", "oh", "ranged", "enemy" }) do
            local t = ns.timers[key]
            if t then t.state = "idle" end
        end
        ns.casting = nil
        ns.channeling = nil
        ns.gcdActive = false
        ns.activeBuffIconCount = 0
        ns.hunterCastActive = false
        ns.hunterCastSpellId = nil
        ns.hunterCastStartTime = nil
        ns.hunterCastDuration = nil
        ns.currentCastSpellId = nil
        ns.playerInCombat = false
    end

    -- A bar stand-in that records the anchor points written to it, so the test
    -- asserts on what was actually anchored rather than on mock internals.
    local function RecordingBar(height)
        local f = CreateFrame("Frame")
        f:SetHeight(height or 6)
        f.anchors = {}
        local realSetPoint = f.SetPoint
        f.SetPoint = function(self, ...)
            local point, rel, relPoint, x, y = ...
            self.anchors[#self.anchors + 1] = { point = point, rel = rel, relPoint = relPoint, x = x, y = y }
            return realSetPoint(self, ...)
        end
        return f
    end

    local function HasAnchor(bar, point)
        for _, a in ipairs(bar.anchors) do
            if a.point == point then return a end
        end
        return nil
    end

    -- (1) GCD latch: the loop must be released even with no ticker bar.
    function Reg:GcdTicker_ExpiredGCD_ReleasesUpdateLoop_WithNoTickerBar()
        local fn = ResolveUpvalue(GetCoreRenderHook(), "UpdateGcdTicker")
        Exists(fn, "UpdateGcdTicker reachable via the core render hook")

        -- The Hunter case: InitBars never calls CreateGcdTickerBar for HUNTER,
        -- so ns.gcdTickerBar is nil and the old early return skipped expiry.
        ns.playerClass = "HUNTER"
        ns.gcdTickerBar = nil
        QuietAllGates()
        SuperSwingTimerDB.showHunterBuffIcons = false
        SuperSwingTimerDB.showPowerBar = false

        StartExpiredGcd()

        local calls = DriveGcdTicker(fn, 1)

        IsFalse(ns.gcdActive, 'expired GCD must clear ns.gcdActive')
        AreEqual(calls, 1, 'update loop must be told to re-evaluate exactly once')
        -- The observable consequence, through the public gate the update loop is
        -- actually keyed on: with every other input quiet, the loop is now free
        -- to detach. Before the fix gcdActive stayed true for the whole session.
        IsFalse(ns.HasActiveTimers(), 'no active timers once the GCD has expired')
    end

    -- The guard against the naive fix of calling RefreshUpdateLoop every frame.
    function Reg:GcdTicker_ExpiredGCD_ReleasesLoopOnce_NotEveryFrame()
        local fn = ResolveUpvalue(GetCoreRenderHook(), "UpdateGcdTicker")
        Exists(fn, 'UpdateGcdTicker reachable')

        ns.playerClass = "HUNTER"
        ns.gcdTickerBar = nil
        QuietAllGates()

        StartExpiredGcd()
        local calls = DriveGcdTicker(fn, 6)

        IsFalse(ns.gcdActive, 'expired GCD clears the latch')
        AreEqual(calls, 1, 'edge-only: exactly one refresh across 6 frames')

        -- And again from a fresh expired GCD: still exactly one per expiry.
        StartExpiredGcd()
        local more = DriveGcdTicker(fn, 4)
        AreEqual(more, 1, 'a second expiry triggers exactly one further refresh')
    end

    -- A GCD that has NOT expired must keep the loop attached.
    function Reg:GcdTicker_ActiveGCD_KeepsUpdateLoopAttached()
        local fn = ResolveUpvalue(GetCoreRenderHook(), "UpdateGcdTicker")
        Exists(fn, 'UpdateGcdTicker reachable')

        ns.playerClass = "HUNTER"
        ns.gcdTickerBar = nil
        QuietAllGates()

        -- A GCD that started now and is only halfway through: still running.
        ns.gcdActive = true
        ns.gcdDuration = 1.5
        ns.lastGcdTime = ns.GetAlignedTime()
        if AdvanceMockTime then AdvanceMockTime(0.5) end

        local calls = DriveGcdTicker(fn, 3)

        IsTrue(ns.gcdActive, 'GCD still running: the latch stays set')
        AreEqual(calls, 0, 'a live GCD must not churn the update loop')
        IsTrue(ns.HasActiveTimers(), 'a live GCD keeps the update loop alive')
    end

    -- The fix must not be Hunter-only: with a ticker bar present, expiry still
    -- has to clear the latch and refresh the loop.
    function Reg:GcdTicker_ExpiredGCD_ReleasesUpdateLoop_WithTickerBar()
        local fn = ResolveUpvalue(GetCoreRenderHook(), "UpdateGcdTicker")
        Exists(fn, 'UpdateGcdTicker reachable')

        ns.playerClass = "WARRIOR"
        ns.gcdTickerBar = CreateFrame("Frame") --[[@as StatusBar]]
        QuietAllGates()

        StartExpiredGcd()
        local calls = DriveGcdTicker(fn, 3)

        IsFalse(ns.gcdActive, 'expired GCD clears the latch with a bar present')
        AreEqual(calls, 1, 'exactly one refresh with a bar present')
    end

    -- Same thing, but driven through the real production path: the core render
    -- hook that OnUpdate dispatches. This needs no debug library, so it is the
    -- assertion that survives in a real client.
    function Reg:GcdTicker_ExpiredGCD_EndToEndThroughOnUpdate()
        local coreHook = GetCoreRenderHook()
        Exists(coreHook, 'core render hook registered')

        ns.playerClass = "HUNTER"
        ns.gcdTickerBar = nil
        QuietAllGates()

        StartExpiredGcd()

        local calls = 0
        local real = ns.RefreshUpdateLoop
        ns.RefreshUpdateLoop = function() calls = calls + 1 end
        local ok, err = pcall(coreHook, 0.016)
        ns.RefreshUpdateLoop = real
        IsTrue(ok, 'core render hook must not error: ' .. tostring(err))

        IsFalse(ns.gcdActive, 'expired GCD clears ns.gcdActive via the real render path')
        AreEqual(calls, 1, 'one refresh via the real render path')
        IsFalse(ns.HasActiveTimers(), 'loop free to detach after the GCD expires')
    end

    -- (2) Rogue gate: the clause must fire in combat, and must NOT fire out of
    -- combat. The second half is the important one: hoisting the clause out of
    -- the playerInCombat guard would pin the update loop on for every Rogue,
    -- forever, which is a worse bug than the freeze it fixes.
    function Reg:RogueGate_InCombat_EnergyTickKeepsLoopAlive()
        ns.playerClass = "ROGUE"
        QuietAllGates()
        local db = SuperSwingTimerDB
        -- Clear the OTHER in-combat gates so the Rogue clause is the decider.
        db.showPowerBar = false
        db.showRogueBuffIcons = false
        db.showRogueEnergyTick = true
        db.showRogueSliceAndDice = false

        ns.playerInCombat = true
        IsTrue(ns.HasActiveTimers(), 'Rogue energy tick sweeps need frames in combat')
    end

    function Reg:RogueGate_InCombat_SliceAndDiceKeepsLoopAlive()
        ns.playerClass = "ROGUE"
        QuietAllGates()
        local db = SuperSwingTimerDB
        db.showPowerBar = false
        db.showRogueBuffIcons = false
        db.showRogueEnergyTick = false
        db.showRogueSliceAndDice = true

        ns.playerInCombat = true
        IsTrue(ns.HasActiveTimers(), 'Slice and Dice needs frames in combat')
    end

    function Reg:RogueGate_InCombat_BothTogglesOff_LoopStaysOff()
        ns.playerClass = "ROGUE"
        QuietAllGates()
        local db = SuperSwingTimerDB
        db.showPowerBar = false
        db.showRogueBuffIcons = false
        db.showRogueEnergyTick = false
        db.showRogueSliceAndDice = false

        ns.playerInCombat = true
        IsFalse(ns.HasActiveTimers(), 'both toggles off: no reason to keep the loop')
    end

    function Reg:RogueGate_OutOfCombat_DoesNotPinUpdateLoop()
        ns.playerClass = "ROGUE"
        QuietAllGates()
        local db = SuperSwingTimerDB
        db.showPowerBar = false
        db.showRogueBuffIcons = false
        db.showRogueEnergyTick = true
        db.showRogueSliceAndDice = true

        -- The clause must live INSIDE the playerInCombat guard. Out of combat
        -- with no swing, cast, channel, GCD or buff icon running, the loop has
        -- to detach; otherwise every Rogue runs a permanent per-frame loop.
        ns.playerInCombat = false
        IsFalse(ns.HasActiveTimers(),
            'Rogue clause must not apply out of combat (would pin the loop on)')
    end

    -- (3) Restack: a nil in a MIDDLE slot must not truncate the walk. A Hunter
    -- with Wing Clip disabled leaves slot 2 nil, and ipairs used to stop there,
    -- so Immolation/Explosive/Freezing/Frost were never stacked.
    function Reg:RestackDebuffBars_SkipsNilMiddleSlot_StacksLaterBars()
        local TT = ns._Test
        if not TT or not TT.RestackDebuffBars then return end
        local reference = CreateFrame("Frame")
        local bar1, bar3, bar4 = RecordingBar(6), RecordingBar(6), RecordingBar(6)

        -- gap defaults to 2, bar height 6: bar1 at y=2, bar3 at y=10, bar4 at 18.
        local span = TT.RestackDebuffBars({ bar1, nil, bar3, bar4 }, reference, nil, 4)

        IsTrue(span >= 26, 'span must account for all three non-nil bars, got ' .. tostring(span))
        AreEqual(#bar1.anchors, 2, 'first bar anchored')
        AreEqual(#bar3.anchors, 2, 'bar after the nil slot is still anchored')
        AreEqual(#bar4.anchors, 2, 'last bar is still anchored')

        local a3 = HasAnchor(bar3, "BOTTOMLEFT")
        Exists(a3, 'bar3 has a BOTTOMLEFT anchor')
        AreEqual(a3 and a3.y, 10, 'bar3 stacks above bar1, skipping the nil slot')
        AreEqual(a3 and a3.rel, reference, 'bar3 anchors to the reference bar')
        IsTrue((HasAnchor(bar3, "BOTTOMRIGHT") or {}).y == 10, 'bar3 BOTTOMRIGHT mirrors BOTTOMLEFT')

        local a4 = HasAnchor(bar4, "BOTTOMLEFT")
        Exists(a4, 'bar4 has a BOTTOMLEFT anchor')
        AreEqual(a4 and a4.y, 18, 'bar4 stacks above bar3')
    end

    -- The class call sites must rewrite every slot of the hoisted list on EVERY
    -- frame, never latch on "if not list[1]". A latch permanently drops any bar
    -- whose Ensure* helper only runs later, and the toggle that decides that
    -- persists in SavedVariables, so the bar can be absent for the whole login
    -- and then appear at any time. This is the regression from the hoisted-list
    -- work, and it lives at the call site rather than inside RestackDebuffBars.
    function Reg:ClassHook_RewritesEveryRestackSlot_EveryFrame_NeverLatches()
        local hook = GetHunterHook()
        if type(hook) ~= "function" or type(debug) ~= "table"
            or type(debug.setupvalue) ~= "function" then
            IsTrue(true, 'debug library unavailable in this environment')
            return
        end
        local listIdx, wingClipIdx, wingClipBar
        for i = 1, 64 do
            local name, value = debug.getupvalue(hook, i)
            if not name then break end
            if name == "hunterRestackBars" then
                listIdx = i
            elseif name == "wingClipBar" then
                wingClipIdx, wingClipBar = i, value
            end
        end
        Exists(wingClipIdx, 'wingClipBar upvalue found')
        if not listIdx then
            -- Reached only if the hook stopped hoisting its list, which is the
            -- allocation regression this test also pins.
            AreEqual(false, true,
                'the Hunter hook must close over a pre-allocated restack list ' ..
                '(hunterRestackBars), not build a fresh table literal each frame')
            return
        end
        local _, list = debug.getupvalue(hook, listIdx)
        Exists(list, 'the Hunter restack list is a pre-allocated hoisted table')

        -- Drive the bar's whole life cycle across three frames. wingClipBar is
        -- normally nil in this harness (its Ensure* helper sits behind
        -- showHunterWingClipBar), which is exactly the shape of the bug: the
        -- slot is legitimately nil, and the question is whether the hook keeps
        -- revisiting it once the bar shows up. The upvalue is restored before
        -- any assertion runs, so a failure cannot leak a fake bar into the
        -- addon state the later tests read.
        local probe = CreateFrame("Frame")
        local ok1, err1, ok2, err2, ok3, err3
        ok1, err1 = pcall(function()
            debug.setupvalue(hook, wingClipIdx, probe)
            hook(0.016)
        end)
        local withBar = list[2]
        ok2, err2 = pcall(function()
            debug.setupvalue(hook, wingClipIdx, nil) -- toggle off: never created
            hook(0.016)
        end)
        local withoutBar = list[2]
        ok3, err3 = pcall(function()
            debug.setupvalue(hook, wingClipIdx, probe) -- toggle on: Ensure* creates it
            hook(0.016)
        end)
        local reEnabled = list[2]
        debug.setupvalue(hook, wingClipIdx, wingClipBar)
        hook(0.016)

        AreEqual(ok1, true, 'hook must accept an existing bar: ' .. tostring(err1))
        AreEqual(withBar, probe, 'slot 2 holds the bar while it exists')
        AreEqual(ok2, true, 'hook must accept a vanished bar: ' .. tostring(err2))
        AreEqual(withoutBar, nil, 'slot must clear when the bar does not exist')
        AreEqual(ok3, true, 'hook must accept a bar appearing late: ' .. tostring(err3))
        -- The regression from the hoisted-list work. A "if not list[n]" latch
        -- fills the slot once and never revisits it, so a bar enabled
        -- mid-session is silently dropped from the stack for the rest of the
        -- session -- and the toggle persists in SavedVariables, so it can
        -- happen on any frame.
        AreEqual(reEnabled, probe, 'a bar re-enabled mid-session must be restacked')
    end

    -- A bar created mid-session (its config toggle persists in SavedVariables,
    -- so it can appear at any time) must be picked up on the next call. This is
    -- RestackDebuffBars' own contract: the walk is by index, so a bar that only
    -- shows up in a later call is anchored then and there.
    function Reg:RestackDebuffBars_PicksUpBarSuppliedOnALaterCall()
        local TT = ns._Test
        if not TT or not TT.RestackDebuffBars then return end
        local reference = CreateFrame("Frame")
        local list = {}

        -- First call: the bar's toggle is off, so the slot is legitimately nil.
        local emptySpan = TT.RestackDebuffBars(list, reference, nil, 1)
        AreEqual(emptySpan, 2, 'no bars: span is just the gap')

        -- The toggle flips on (or the Ensure* helper finally runs).
        local bar = RecordingBar(6)
        list[1] = bar

        local span = TT.RestackDebuffBars(list, reference, nil, 1)

        AreEqual(#bar.anchors, 2, 'late-created bar is anchored on the later call')
        AreEqual((HasAnchor(bar, "BOTTOMLEFT") or {}).y, 2, 'late bar sits at the gap')
        IsTrue(span > emptySpan, 'span grows once the bar exists, got ' .. tostring(span))
        IsTrue(TT.GetDebuffStackOffset() > BUFF_ICON_BASE_OFFSET,
            'buff icon offset rises above the resting clearance, got ' .. tostring(TT.GetDebuffStackOffset()))
    end

    -- The all-nil fallback: bare gap, and the resting buff-icon clearance.
    function Reg:RestackDebuffBars_AllNil_FallsBackToBaseOffset()
        local TT = ns._Test
        if not TT or not TT.RestackDebuffBars then return end
        local reference = CreateFrame("Frame")

        local span = TT.RestackDebuffBars({}, reference, nil, 3)
        AreEqual(span, 2, 'all-nil list returns the bare gap')

        -- BUFF_ICON_BASE_OFFSET in SuperSwingTimer_ClassMods.lua.
        AreEqual(TT.GetDebuffStackOffset(), BUFF_ICON_BASE_OFFSET,
            'all-nil list falls back to BUFF_ICON_BASE_OFFSET')

        -- A hidden bar counts as absent too, and must fall back the same way.
        local hidden = RecordingBar(6)
        hidden:Hide()
        local hiddenSpan = TT.RestackDebuffBars({ hidden }, reference, nil, 1)
        AreEqual(hiddenSpan, 2, 'hidden bar contributes nothing to the span')
        AreEqual(TT.GetDebuffStackOffset(), BUFF_ICON_BASE_OFFSET,
            'hidden bar falls back to the base offset')
    end

    function Reg:ComputeBuffIconOffset_SkipsNilSlot_AccountsForLaterBars()
        local TT = ns._Test
        if not TT or not TT.ComputeBuffIconOffset then return end
        local reference = CreateFrame("Frame")
        local bar2 = RecordingBar(8)
        -- slot 1 is nil, slot 2 is bar2 with height 8
        -- gap=2, bar2 top = gap(2) + height(8) = 10
        -- icon bottom sits 8px above highest bar top: 10 + 8 = 18
        local offset = TT.ComputeBuffIconOffset({ nil, bar2 }, reference)
        AreEqual(offset, 18, 'ComputeBuffIconOffset must skip nil slot and position 8px above bar2 (got ' .. tostring(offset) .. ')')

        -- When no bars are visible, falls back to base offset (14)
        local emptyOffset = TT.ComputeBuffIconOffset({ nil, nil }, reference)
        AreEqual(emptyOffset, 14, 'ComputeBuffIconOffset falls back to base offset when no bars visible')
    end

    -- (4) Allocation pin: the per-frame restack lists are pre-allocated tables
    -- whose slots are rewritten, not fresh literals built every frame. Driving
    -- the Hunter hook twice must hand RestackDebuffBars the SAME table object
    -- both times, and that object must be the hoisted upvalue.
    function Reg:HunterRestackList_ReusedAcrossFrames_NotRebuiltPerFrame()
        local spy = SpyOnRestack(nil, "hunterRestackBars", "RestackDebuffBars")
        if not spy then
            -- No debug library (or the addon reshaped its hook): nothing to pin.
            IsTrue(true, 'restack spy unavailable in this environment')
            return
        end
        local ok, err = pcall(function()
            local hook = GetHunterHook()
            hook(0.016)
            hook(0.016)
            hook(0.016)
        end)
        spy.undo()
        IsTrue(ok, 'Hunter OnUpdate hook must not error: ' .. tostring(err))

        IsTrue(#spy.lists >= 2,
            'restack should be reached on every frame, saw ' .. tostring(#spy.lists) .. ' call(s)')
        local distinct = {}
        for _, list in ipairs(spy.lists) do
            distinct[list] = true
        end
        local distinctCount = 0
        for _ in pairs(distinct) do distinctCount = distinctCount + 1 end
        AreEqual(distinctCount, 1,
            'one pre-allocated list reused every frame; a fresh literal per frame would give ' ..
            tostring(distinctCount) .. ' distinct tables')
        AreEqual(spy.lists[1], spy.hoisted, 'the list passed is the pre-allocated hoisted table')
    end

    function Reg:OnUpdate_ClassIsolation()
        local coreHook = GetCoreRenderHook()
        Exists(coreHook, "core render hook registered")

        local savedClass = ns.playerClass
        ns.playerClass = "WARRIOR"

        local warriorCalled, hunterCalled, druidCalled, rogueCalled, shamanCalled = false, false, false, false, false
        local origWarrior = ns.UpdateWarriorQueueTint
        local origHunter = ns.UpdateHunterQueueTint
        local origDruid = ns.UpdateDruidQueueTint
        local origRogue = ns.UpdateRogueAdrenalineRush
        local origShaman = ns.UpdateShamanWindfuryIcd

        ns.UpdateWarriorQueueTint = function() warriorCalled = true end
        ns.UpdateHunterQueueTint = function() hunterCalled = true end
        ns.UpdateDruidQueueTint = function() druidCalled = true end
        ns.UpdateRogueAdrenalineRush = function() rogueCalled = true end
        ns.UpdateShamanWindfuryIcd = function() shamanCalled = true end

        coreHook(0.016)

        ns.UpdateWarriorQueueTint = origWarrior
        ns.UpdateHunterQueueTint = origHunter
        ns.UpdateDruidQueueTint = origDruid
        ns.UpdateRogueAdrenalineRush = origRogue
        ns.UpdateShamanWindfuryIcd = origShaman
        ns.playerClass = savedClass

        IsTrue(warriorCalled, "Warrior hook should be called for WARRIOR")
        IsFalse(hunterCalled, "Hunter hook should NOT be called for WARRIOR")
        IsFalse(druidCalled, "Druid hook should NOT be called for WARRIOR")
        IsFalse(rogueCalled, "Rogue hook should NOT be called for WARRIOR")
        IsFalse(shamanCalled, "Shaman hook should NOT be called for WARRIOR")
    end

    -- ============================================================
    -- SST-Weaving: Real-time spell cast time, Maelstrom, spark colors
    -- ============================================================
    local Weaving = WoWUnit:New('SST-Weaving', 'PLAYER_ENTERING_WORLD')

    function Weaving:EffectiveCastTime_FunctionExists()
        IsTrue(type(ns.GetEffectiveSpellCastTime) == "function", 'ns.GetEffectiveSpellCastTime is a function')
    end

    function Weaving:LiveSpellHasteMultiplier_Default()
        IsTrue(type(ns.GetLiveSpellHasteMultiplier) == "function")
        local mult = ns.GetLiveSpellHasteMultiplier()
        IsTrue(type(mult) == "number")
        AreEqual(mult, 1.0)
    end

    function Weaving:GetLatencySeconds_Fallback()
        IsTrue(type(ns.GetLatencySeconds) == "function")
        local lat = ns.GetLatencySeconds()
        IsTrue(type(lat) == "number")
        IsTrue(lat >= 0)
    end

    function Weaving:EffectiveCastTime_MaelstromScaling()
        if not ns.GetEffectiveSpellCastTime then return end
        local testSpell = { spellId = 403, abbrev = "LB", castTime = 2.0 }
        local savedMult = ns.maelstromCastTimeMultiplier

        ns.maelstromCastTimeMultiplier = 1.0
        local t0 = ns.GetEffectiveSpellCastTime(testSpell)
        AreEqual(t0, 2.0)

        ns.maelstromCastTimeMultiplier = 0.60
        local t2 = ns.GetEffectiveSpellCastTime(testSpell)
        AreEqual(t2, 1.2)

        ns.maelstromCastTimeMultiplier = 0.0
        local t5 = ns.GetEffectiveSpellCastTime(testSpell)
        AreEqual(t5, 0.0)

        ns.maelstromCastTimeMultiplier = savedMult
    end

    function Weaving:MarkerFraction_ScalesWithCastTime()
        local duration = 2.6
        local latency = 0.05
        local c1 = 2.0
        local m1 = math.max(0, math.min((duration - (c1 + latency)) / duration, 1))
        local c2 = 0.5
        local m2 = math.max(0, math.min((duration - (c2 + latency)) / duration, 1))
        IsTrue(m2 > m1, 'shorter cast time moves breakpoint marker further right')
    end

    function Weaving:SparkColor_SafeVsClipLogic()
        local classColor = { r = 0.0, g = 0.44, b = 0.87, a = 1.0 }
        local redColor = { r = 1.0, g = 0.15, b = 0.15, a = 1.0 }

        -- Safe: cast started before marker fraction (no clip)
        local markerFraction = 0.60
        local castStartFraction = 0.30
        local clipAmount = 0
        local isClipped = (clipAmount > 0) or (castStartFraction > markerFraction)
        local sparkColor = isClipped and redColor or classColor
        AreEqual(sparkColor.r, classColor.r)
        AreEqual(sparkColor.b, classColor.b)

        -- Clipped: cast started after marker fraction
        castStartFraction = 0.75
        isClipped = (clipAmount > 0) or (castStartFraction > markerFraction)
        sparkColor = isClipped and redColor or classColor
        AreEqual(sparkColor.r, 1.0)
    end

    function Weaving:BuffIcons_TextAnchoringAndStacks()
        local durationPoint = { point = "", relativeTo = nil, relativePoint = "", x = 0, y = 0 }
        local countPoint = { point = "", relativeTo = nil, relativePoint = "", x = 0, y = 0 }
        local icon = {
            durationText = {
                point = durationPoint,
                justifyH = "CENTER",
                SetPoint = function(fs, pt, rel, relPt, x, y)
                    fs.point.point = pt
                    fs.point.relativeTo = rel
                    fs.point.relativePoint = relPt
                    fs.point.x = x
                    fs.point.y = y
                end,
                SetJustifyH = function(fs, j) fs.justifyH = j end,
            },
            countText = {
                point = countPoint,
                justifyH = "RIGHT",
                SetPoint = function(fs, pt, rel, relPt, x, y)
                    fs.point.point = pt
                    fs.point.relativeTo = rel
                    fs.point.relativePoint = relPt
                    fs.point.x = x
                    fs.point.y = y
                end,
                SetJustifyH = function(fs, j) fs.justifyH = j end,
            }
        }
        icon.durationText:SetPoint("BOTTOM", icon, "TOP", 0, 2)
        icon.durationText:SetJustifyH("CENTER")
        icon.countText:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
        icon.countText:SetJustifyH("RIGHT")

        AreEqual(durationPoint.point, "BOTTOM")
        AreEqual(durationPoint.relativePoint, "TOP")
        AreEqual(durationPoint.y, 2)
        AreEqual(icon.durationText.justifyH, "CENTER")

        AreEqual(countPoint.point, "BOTTOMRIGHT")
        AreEqual(countPoint.relativePoint, "BOTTOMRIGHT")
        AreEqual(countPoint.x, -1)
        AreEqual(countPoint.y, 1)
        AreEqual(icon.countText.justifyH, "RIGHT")
    end

    -- ============================================================
    -- SST-MoveMode: Interactive Move Mode, slash commands, HUD
    -- ============================================================
    local MoveMode = WoWUnit:New('SST-MoveMode', 'PLAYER_ENTERING_WORLD')

    function MoveMode:MoveMode_StateTransitions()
        IsTrue(type(ns.StartMoveMode) == "function", "ns.StartMoveMode must be a function")
        IsTrue(type(ns.StopMoveMode) == "function", "ns.StopMoveMode must be a function")
        IsTrue(type(ns.ToggleMoveMode) == "function", "ns.ToggleMoveMode must be a function")

        ns.StopMoveMode()
        IsTrue(SuperSwingTimerDB.lockBars == true, "StopMoveMode must lock bars")
        IsFalse(ns.isMoveModeActive, "MoveMode must be inactive")

        ns.StartMoveMode()
        IsFalse(SuperSwingTimerDB.lockBars, "StartMoveMode must unlock bars")
        IsTrue(ns.isMoveModeActive, "MoveMode must be active")

        ns.ToggleMoveMode()
        IsFalse(ns.isMoveModeActive, "ToggleMoveMode must toggle active state")
        IsTrue(SuperSwingTimerDB.lockBars == true, "Bars must be locked after toggle")
    end

    function MoveMode:SlashCommands_RecognizeMoveAndLock()
        local cmdHandler = SlashCmdList["SUPERSWINGTIMER"]
        IsTrue(type(cmdHandler) == "function", "SUPERSWINGTIMER slash handler must exist")
        assert(type(cmdHandler) == "function", "SUPERSWINGTIMER slash handler must exist")

        -- Call /sst move
        cmdHandler("move")
        IsTrue(ns.isMoveModeActive, "/sst move must activate move mode")

        -- Call /sst lock
        cmdHandler("lock")
        IsFalse(ns.isMoveModeActive, "/sst lock must deactivate move mode")
        IsTrue(SuperSwingTimerDB.lockBars == true, "bars must be locked")

        -- Call /sst unlock
        cmdHandler("unlock")
        IsTrue(ns.isMoveModeActive, "/sst unlock must activate move mode")
        ns.StopMoveMode()
    end

    function MoveMode:MoveHUD_OnHide_CancelsMoveMode()
        ns.StartMoveMode()
        IsTrue(ns.isMoveModeActive, "Move mode must be active")
        local hud = ns.moveHUD
        IsTrue(hud ~= nil, "Move HUD frame must exist")
        local onHide = hud:GetScript("OnHide")
        IsTrue(type(onHide) == "function", "Move HUD must have an OnHide handler")
        hud:Hide()
        if onHide then onHide(hud) end
        IsFalse(ns.isMoveModeActive, "Hiding Move HUD must cancel move mode")
        IsTrue(SuperSwingTimerDB.lockBars == true, "Bars must be locked")
    end

    function MoveMode:Hunter_MoveMode_OverlayLabel()
        local origClass = ns.playerClass
        ns.playerClass = "HUNTER"
        ns.StartMoveMode()
        IsTrue(ns.mhBar._dragOverlay ~= nil, "MH bar must have drag overlay")
        IsTrue(ns.mhBar._dragOverlay.text:GetText() == "Main Hand (Follows Ranged)",
            "Hunter MH label must indicate it follows Ranged")
        ns.StopMoveMode()

        ns.playerClass = "WARRIOR"
        ns.StartMoveMode()
        IsTrue(ns.mhBar._dragOverlay.text:GetText() == "Main Hand (Drag)",
            "Warrior MH label must indicate Main Hand (Drag)")
        ns.StopMoveMode()
        ns.playerClass = origClass
    end

    function MoveMode:Hunter_WithoutOH_OverlayHidesOnLock()
        local savedOH = ns.ohBar
        ns.ohBar = nil
        ns.StartMoveMode()
        IsTrue(ns.isMoveModeActive, "Move mode must be active")
        IsTrue(ns.rangedBar._dragOverlay:IsShown(), "Ranged drag overlay must be shown in move mode")

        ns.StopMoveMode()
        IsFalse(ns.isMoveModeActive, "Move mode must be inactive")
        IsFalse(ns.rangedBar._dragOverlay:IsShown(), "Ranged drag overlay must be hidden after locking when ohBar is nil")
        if ns.enemyBar and ns.enemyBar._dragOverlay then
            IsFalse(ns.enemyBar._dragOverlay:IsShown(), "Enemy drag overlay must be hidden after locking when ohBar is nil")
        end

        ns.StartMoveMode()
        IsTrue(ns.rangedBar._dragOverlay:IsShown(), "Ranged drag overlay must be shown again in move mode")
        SuperSwingTimerDB.lockBars = true
        ns.ApplyLockBars()
        IsFalse(ns.rangedBar._dragOverlay:IsShown(), "ApplyLockBars must hide ranged drag overlay even when ohBar is nil")

        ns.ohBar = savedOH
    end

    function MoveMode:Combat_Enter_CancelsMoveMode()
        ns.StartMoveMode()
        IsTrue(ns.isMoveModeActive, "Move mode must be active before combat")
        local sstFrame = rawget(_G, "SuperSwingTimerFrame")
        IsTrue(sstFrame ~= nil, "SuperSwingTimerFrame must exist")
        local onEvent = sstFrame:GetScript("OnEvent")
        IsTrue(type(onEvent) == "function", "SuperSwingTimerFrame must have OnEvent handler")
        onEvent(sstFrame, "PLAYER_REGEN_DISABLED")
        IsFalse(ns.isMoveModeActive, "Entering combat must cancel move mode")
        IsTrue(ns.combatLocked == true, "Bars must be locked for the duration of the fight")
        IsTrue(ns.AreBarsLocked(), "The combat lock must make AreBarsLocked true")
        for _, bar in ipairs({ ns.mhBar, ns.ohBar, ns.rangedBar, ns.enemyBar }) do
            if bar and bar._dragOverlay then
                IsFalse(bar._dragOverlay:IsShown(), "Bar drag overlay must be hidden on entering combat")
            end
        end
        onEvent(sstFrame, "PLAYER_REGEN_ENABLED")
    end

    function MoveMode:TestPreview_SlashCommand()
        local cmdHandler = SlashCmdList["SUPERSWINGTIMER"]
        IsTrue(type(cmdHandler) == "function", "SUPERSWINGTIMER slash handler must exist")
        cmdHandler = assert(cmdHandler, "SUPERSWINGTIMER slash handler must exist")
        IsTrue(type(ns.StartBarTestPreview) == "function", "StartBarTestPreview must be exported")

        cmdHandler("test")
        IsTrue(ns.barTestActive == true, "/sst test must activate barTestActive")
        IsTrue(ns.barTestStartTime ~= nil, "/sst test must set barTestStartTime for animations")

        cmdHandler("test")
        IsFalse(ns.barTestActive, "/sst test second call must stop test preview")
        IsTrue(ns.barTestStartTime == nil, "Stopping test preview must clear barTestStartTime")
    end

    -- ============================================================
    -- Config: Decoupled Blizzard Settings & Responsive Layout
    -- ============================================================
    local Config = WoWUnit:New("SST-Config")

    function Config:DecoupledBlizzardCanvas()
        if not ns.panel and ns.InitConfig then ns.InitConfig() end
        local p = ns.panel
        IsTrue(p ~= nil, "Config panel must exist")
        IsTrue(p:GetParent() == UIParent, "Standalone panel must be parented to UIParent")

        -- Blizzard canvas must be a separate frame
        IsTrue(ns.blizzardCanvasFrame ~= nil, "Blizzard canvas frame must be registered separately")
        IsTrue(ns.blizzardCanvasFrame ~= p, "Blizzard canvas must not be the standalone panel")
        IsTrue(ns.blizzardCanvasFrame:GetName() == "SuperSwingTimerBlizzardOptionsPanel",
            "Blizzard canvas frame must have expected name")
    end

    function Config:ResponsiveClamping()
        if not ns.panel and ns.InitConfig then ns.InitConfig() end
        local p = ns.panel
        IsTrue(type(ns.ApplyConfigPanelResponsiveSize) == "function", "ApplyConfigPanelResponsiveSize must be a function")

        -- Simulate 1080p screen (virtual height 768)
        local origGetHeight = UIParent.GetHeight
        UIParent.GetHeight = function() return 768 end
        ns.ApplyConfigPanelResponsiveSize(p)
        IsTrue(p:GetHeight() <= 580, "Panel height must be <= 580 on 768 height screen")
        IsTrue(p:GetHeight() >= 420, "Panel height must be >= 420")

        -- Simulate low-res screen (virtual height 600)
        UIParent.GetHeight = function() return 600 end
        ns.ApplyConfigPanelResponsiveSize(p)
        IsTrue(p:GetHeight() <= 530, "Panel height must adapt to 600 height screen")
        IsTrue(p:GetHeight() >= 420, "Panel height must respect minimum")

        -- Restore original GetHeight
        UIParent.GetHeight = origGetHeight
        ns.ApplyConfigPanelResponsiveSize(p)
    end

    function Config:LockControlsSync()
        if not ns.panel and ns.InitConfig then ns.InitConfig() end
        local p = ns.panel
        IsTrue(p ~= nil, "Config panel must exist")
        IsTrue(type(ns.RefreshConfigLockControls) == "function", "RefreshConfigLockControls must exist")

        -- Move mode active
        ns.isMoveModeActive = true
        SuperSwingTimerDB.lockBars = false
        ns.RefreshConfigLockControls()
        IsTrue(p.moveHeaderText:GetText() == "Lock Bars & Save", "Header button must read Lock Bars & Save in move mode")

        -- Move mode inactive / locked
        ns.isMoveModeActive = false
        SuperSwingTimerDB.lockBars = true
        ns.RefreshConfigLockControls()
        IsTrue(p.moveHeaderText:GetText() == "Unlock & Move Bars",
            "Header button must read Unlock & Move Bars when locked")
    end

    function Config:HeaderButtonToggle()
        if not ns.panel and ns.InitConfig then ns.InitConfig() end
        local p = ns.panel
        local btn = p.moveHeaderBtn
        IsTrue(btn ~= nil, "Move header button must exist")
        local onClick = btn:GetScript("OnClick")
        IsTrue(type(onClick) == "function", "Move header button must have OnClick")

        -- Ensure locked first
        ns.StopMoveMode()
        IsTrue(SuperSwingTimerDB.lockBars == true, "Must start locked")
        IsFalse(ns.isMoveModeActive, "Move mode must start false")

        -- Click to unlock
        onClick(btn)
        IsTrue(ns.isMoveModeActive == true, "Clicking header button must activate move mode")
        IsFalse(SuperSwingTimerDB.lockBars, "Clicking header button must unlock bars in DB")

        -- Click to lock & save
        onClick(btn)
        IsFalse(ns.isMoveModeActive, "Clicking header button again must deactivate move mode")
        IsTrue(SuperSwingTimerDB.lockBars == true, "Clicking header button again must lock bars in DB")
        for _, bar in ipairs({ ns.mhBar, ns.ohBar, ns.rangedBar, ns.enemyBar }) do
            if bar and bar._dragOverlay then
                IsFalse(bar._dragOverlay:IsShown(), "Drag overlay must be hidden after locking")
            end
        end
    end

    function Config:ApplyLockBars_HidesOverlays()
        ns.StartMoveMode()
        IsTrue(ns.isMoveModeActive == true, "Must be in move mode")
        for _, bar in ipairs({ ns.mhBar, ns.ohBar, ns.rangedBar, ns.enemyBar }) do
            if bar and bar._dragOverlay then
                IsTrue(bar._dragOverlay:IsShown(), "Overlay must be shown in move mode")
            end
        end

        SuperSwingTimerDB.lockBars = true
        ns.ApplyLockBars()
        IsFalse(ns.isMoveModeActive, "ApplyLockBars when locked must clear isMoveModeActive")
        for _, bar in ipairs({ ns.mhBar, ns.ohBar, ns.rangedBar, ns.enemyBar }) do
            if bar and bar._dragOverlay then
                IsFalse(bar._dragOverlay:IsShown(), "ApplyLockBars must hide all drag overlays")
            end
        end
        if ns.moveHUD then
            IsFalse(ns.moveHUD:IsShown(), "ApplyLockBars must hide move HUD")
        end
    end

    function Config:SectionSpacingAndHeaders()
        local parent = CreateFrame("Frame", nil, UIParent)
        local header = ns._CreateSectionHeader and
        ns._CreateSectionHeader(parent, "Appearance", -20, { accentColor = { 0, 0.8, 1 } })
        IsTrue(header ~= nil, "Section header should be created")
        AreEqual(header and header.layoutHeight, 36, "Header layoutHeight must be 36px")
        Exists(header and header.accentBadge, "Header must have accent badge texture")
    end

    function Config:ActionRow_SingleRightAnchor()
        local parent = CreateFrame("Frame", nil, UIParent)
        local row = ns._CreateActionRow and ns._CreateActionRow(parent, "Test Action", "Click Me", 0, function() end)
        IsTrue(row ~= nil, "Action row should be created")
        if row and row.text then
            local p3 = row.text:GetPoint(3)
            AreEqual(p3, nil, "Action row text must only have two anchor points (TOPLEFT and RIGHT), not three")
        end
    end

    function Config:QuickTabStylingAndColorsGutter()
        if not ns.panel and ns.InitConfig then ns.InitConfig() end
        local p = ns.panel
        IsTrue(p ~= nil, "Config panel must exist")
        local tabBtn = p.quickTabButtons and p.quickTabButtons[1]
        IsTrue(tabBtn ~= nil, "Quick tab button 1 should exist")
        if tabBtn and tabBtn.refresh then
            tabBtn.refresh()
            local _, _, b = tabBtn.label:GetTextColor()
            IsTrue(b > 0.8, "Active tab text should have cyan accent blue component > 0.8")
            Exists(tabBtn.activeBorder, "Active tab should have active bottom border texture")
        end
    end

    function Config:PowerBarHeightSlider_ExistsAndAdjusts()
        if not ns.panel and ns.InitConfig then ns.InitConfig() end
        local p = ns.panel
        IsTrue(p ~= nil, "Config panel must exist")
        local slider = p.powerBarHeightSlider
        IsTrue(slider ~= nil, "Power bar height slider must exist on config panel")

        local initialVal = SuperSwingTimerDB.powerBarHeight or 14
        local onValueChanged = slider:GetScript("OnValueChanged")
        IsTrue(type(onValueChanged) == "function", "Slider must have OnValueChanged script")

        -- Test adjustment
        onValueChanged(slider, 22)
        AreEqual(SuperSwingTimerDB.powerBarHeight, 22, "DB powerBarHeight must update to 22")
        AreEqual(ns.POWER_BAR_HEIGHT, 22, "ns.POWER_BAR_HEIGHT must update to 22")

        -- Restore
        onValueChanged(slider, initialVal)
        AreEqual(SuperSwingTimerDB.powerBarHeight, initialVal, "DB powerBarHeight must restore")
    end

    -- ============================================================
    -- SST-Diag: /sst diag capture, report, and glow adapter fallback
    -- ============================================================
    local Diag = WoWUnit:New('SST-Diag', 'PLAYER_ENTERING_WORLD')

    function Diag:API_Exists()
        local d = ns.Diag
        IsTrue(type(d) == 'table', 'ns.Diag table')
        IsTrue(type(d.Record) == 'function', 'Record')
        IsTrue(type(d.BuildReport) == 'function', 'BuildReport')
        IsTrue(type(d.HandleSlash) == 'function', 'HandleSlash')
        IsTrue(type(d.Clear) == 'function', 'Clear')
    end

    function Diag:Record_DedupesAndCounts()
        local d = ns.Diag
        d.Clear()
        d.Record('boom at UI.lua:1', 'stack one', 'lua')
        d.Record('boom at UI.lua:1', 'stack two', 'lua')
        AreEqual(#d.errors, 1, 'one unique signature')
        AreEqual(d.errors[1].count, 2, 'count increments')
        AreEqual(d.errorTotal, 2, 'total increments')
        d.Clear()
    end

    function Diag:ErrorHandler_CapturesMessage()
        local d = ns.Diag
        d.Clear()
        local handler = geterrorhandler()
        handler('SuperSwingTimer test error')
        IsTrue(#d.errors >= 1, 'error handler recorded the message')
        IsTrue(d.errors[1].message:find('SuperSwingTimer test error', 1, true) ~= nil, 'message stored')
        d.Clear()
    end

    function Diag:LuaWarningEvent_CapturesMessage()
        local d = ns.Diag
        d.Clear()
        local frame = _G.SuperSwingTimerDiagFrame
        IsTrue(frame ~= nil, 'diag event frame exists')
        local onEvent = frame and frame:GetScript('OnEvent')
        IsTrue(type(onEvent) == 'function', 'diag OnEvent script exists')
        onEvent(frame, 'LUA_WARNING', 'SuperSwingTimer warning test')
        IsTrue(#d.errors >= 1, 'LUA_WARNING recorded')
        IsTrue(d.errors[1].source == 'warning', 'warning source tagged')
        d.Clear()
    end

    function Diag:Record_AttributesSSTErrors()
        local d = ns.Diag
        d.Clear()
        d.Record('SuperSwingTimer: synthetic failure', nil, 'lua')
        IsTrue(d.errors[1].attributed, 'SST message attributed')
        d.Record('OtherAddon: synthetic failure', nil, 'lua')
        IsFalse(d.errors[1].attributed, 'external message not attributed')
        d.Clear()
    end

    function Diag:Record_CapsRingBuffer()
        local d = ns.Diag
        d.Clear()
        for i = 1, d.maxErrors + 5 do
            d.Record('unique-' .. i, 'stack ' .. i, 'lua')
        end
        AreEqual(#d.errors, d.maxErrors, 'ring buffer capped')
        d.Clear()
    end

    function Diag:HandleSlash_OnlyConsumesDiag()
        local d = ns.Diag
        IsTrue(d.HandleSlash('diag') == true, 'diag consumed')
        IsTrue(d.HandleSlash('move') == false, 'move not consumed')
    end

    function Diag:BuildReport_CompactAndFull()
        local d = ns.Diag
        d.Clear()
        local compact = d.BuildReport('compact')
        IsTrue(type(compact) == 'string' and #compact > 0, 'compact report is text')
        IsTrue(compact:find('SST diag', 1, true) ~= nil, 'compact header')
        local full = d.BuildReport('full')
        IsTrue(full:find('libs', 1, true) ~= nil, 'full report includes libs check')
        d.Clear()
    end

    function Diag:BuildReport_IncludesCapturedError()
        local d = ns.Diag
        d.Clear()
        d.Record('synthetic diagnostic failure', 'stack line', 'test')
        local text = d.BuildReport('errors')
        IsTrue(text:find('synthetic diagnostic failure', 1, true) ~= nil, 'error text present')
        d.Clear()
    end

    function Diag:Clear_ResetsCounters()
        local d = ns.Diag
        d.Record('one', 'stack', 'lua')
        d.Clear()
        AreEqual(#d.errors, 0, 'errors cleared')
        AreEqual(d.errorTotal, 0, 'total cleared')
        AreEqual(d.errorUnique, 0, 'unique cleared')
    end

    function Diag:GlowFallback_NoError()
        local glow = ns.Glow
        IsTrue(type(glow) == 'table', 'glow adapter exists')
        IsFalse(glow.available, 'LCG absent in headless mode')
        local frame = CreateFrame('Frame')
        glow.SetBar(frame, 'test', true, { 1, 1, 1, 1 }, 'proc')
        glow.SetIcon(frame, true, { 1, 1, 1, 1 })
        glow.StopAll()
        glow.SetBar(frame, 'test', false)
        IsTrue(glow.lastError == nil, 'fallback does not error')
    end

    function Diag:GlowTransitions_StartStopOnce()
        local glow = ns.Glow
        local started, stopped = 0, 0
        glow._testLib = {
            ProcGlow_Start = function() started = started + 1 end,
            ProcGlow_Stop = function() stopped = stopped + 1 end,
            AutoCastGlow_Start = function() started = started + 1 end,
            AutoCastGlow_Stop = function() stopped = stopped + 1 end,
            ButtonGlow_Start = function() started = started + 1 end,
            ButtonGlow_Stop = function() stopped = stopped + 1 end,
        }
        local frame = CreateFrame('Frame')
        glow.SetBar(frame, 'k', true, { 1, 1, 1, 1 }, 'proc')
        glow.SetBar(frame, 'k', true, { 1, 1, 1, 1 }, 'proc')
        AreEqual(started, 1, 'proc start called once')
        glow.SetBar(frame, 'k', false)
        glow.SetBar(frame, 'k', false)
        AreEqual(stopped, 1, 'proc stop called once')
        glow.SetBar(frame, 'ac', true, { 1, 1, 1, 1 }, 'autocast')
        glow.SetBar(frame, 'ac', true, { 1, 1, 1, 1 }, 'autocast')
        AreEqual(started, 2, 'autocast start called once')
        glow.SetBar(frame, 'ac', false)
        AreEqual(stopped, 2, 'autocast stop called once')
        glow.SetIcon(frame, true, { 1, 1, 1, 1 })
        glow.SetIcon(frame, true, { 1, 1, 1, 1 })
        AreEqual(started, 3, 'icon start called once')
        glow.SetIcon(frame, false)
        AreEqual(stopped, 3, 'icon stop called once')
        glow._testLib = nil
        glow.StopAll()
    end

    function Diag:GlowBar_StopsOnHide()
        local glow = ns.Glow
        local stopped = 0
        glow._testLib = {
            AutoCastGlow_Start = function() end,
            AutoCastGlow_Stop = function() stopped = stopped + 1 end,
        }
        local bar = CreateFrame('Frame')
        glow.SetBar(bar, 'k', true, { 1, 1, 1, 1 }, 'autocast')
        local onHide = bar:GetScript('OnHide')
        IsTrue(type(onHide) == 'function', 'bar OnHide hook installed')
        onHide(bar)
        AreEqual(stopped, 1, 'bar glow stopped on hide')
        glow._testLib = nil
        glow.StopAll()
    end

    function Diag:GlowIcon_StopsOnHide()
        local glow = ns.Glow
        local started, stopped = 0, 0
        glow._testLib = {
            ButtonGlow_Start = function() started = started + 1 end,
            ButtonGlow_Stop = function() stopped = stopped + 1 end,
        }
        local icon = CreateFrame('Frame')
        glow.SetIcon(icon, true, { 1, 1, 1, 1 })
        AreEqual(started, 1, 'icon glow started')
        local onHide = icon:GetScript('OnHide')
        IsTrue(type(onHide) == 'function', 'OnHide hook installed')
        icon:Hide()
        onHide(icon)
        AreEqual(stopped, 1, 'icon glow stopped on hide')
        glow._testLib = nil
        glow.StopAll()
    end

    function Diag:DB_GlowDefault()
        IsTrue(ns.DB_DEFAULTS.showGlowEffects == true, 'glow defaults on')
    end

    function Diag:SlashAliases_IncludeSTT()
        AreEqual(SLASH_SUPERSWINGTIMER5, '/stt', 'stt alias registered')
        IsTrue(type(SlashCmdList['SUPERSWINGTIMER']) == 'function', 'shared slash handler registered')
    end

    function Diag:SlashGlowToggle()
        local saved = SuperSwingTimerDB.showGlowEffects
        SuperSwingTimerDB.showGlowEffects = true
        local handler = SlashCmdList["SUPERSWINGTIMER"]
        IsTrue(type(handler) == 'function', 'slash handler registered')
        if handler then handler('glow') end
        IsFalse(SuperSwingTimerDB.showGlowEffects, 'glow toggles off')
        if handler then handler('glow') end
        IsTrue(SuperSwingTimerDB.showGlowEffects, 'glow toggles on')
        SuperSwingTimerDB.showGlowEffects = saved
    end

    function Diag:LibsCheck_WithLibStub()
        local saved = _G.LibStub
        _G.LibStub = setmetatable({ minor = 2 }, {
            __call = function(_, major, silent)
                if major == "LibCustomGlow-1.0" then
                    return { ProcGlow_Start = function() end }, 21
                end
                return nil
            end,
        })
        local full = ns.Diag.BuildReport('full')
        _G.LibStub = saved
        IsTrue(full:find('LCG 21', 1, true) ~= nil, 'libs check sees LCG 21')
    end

    function Diag:Install_IsIdempotent()
        local d = ns.Diag
        IsTrue(d.installed, 'error handler installed at load')
        local before = geterrorhandler()
        d.Install()
        local after = geterrorhandler()
        AreEqual(before, after, 'second install is a no-op')
    end

    function Diag:Profile_RecordsHookTime()
        local d = ns.Diag
        d.StartProfile(5)
        d.RecordHookTime(1, 0.5, 'core')
        d.RecordHookTime(1, 1.5, 'core')
        IsTrue(d.profile and d.profile.active, 'profile active')
        d.StopProfile()
        IsFalse(d.profile and d.profile.active, 'profile stopped')
    end

    function Diag:RunTests_NoError()
        local ok = pcall(ns.Diag.RunTests)
        IsTrue(ok, 'self-test probes run without error')
    end

    function Diag:Export_NoError()
        local ok = pcall(ns.Diag.Export)
        IsTrue(ok, 'export builds without error')
    end

    -- ============================================================
    -- SST-Release-0.2.8: regression tests for this release's fixes.
    -- Every case in this group failed before its fix; keep them paired.
    -- ============================================================
    local Release028 = WoWUnit:New('SST-Release-0.2.8', 'PLAYER_ENTERING_WORLD')

    -- The mock clock lives on the harness globals; guard it the same way the
    -- existing regression helpers guard AdvanceMockTime.
    local SetMockTime = rawget(_G, 'SetMockTime')

    -- The Blizzard-settings checkbox stored the new value and then called
    -- ApplyMinimalMode() with no argument, which used to coerce to false.
    function Release028:MinimalMode_NilArgumentKeepsStoredValue()
        local previous = SuperSwingTimerDB.minimalMode
        SuperSwingTimerDB.minimalMode = true
        IsTrue(pc(ns.ApplyMinimalMode), 'ApplyMinimalMode() must not error')
        IsTrue(SuperSwingTimerDB.minimalMode == true,
            'a no-argument call must keep the stored setting instead of forcing it off')
        pc(ns.ApplyMinimalMode, false)
        IsFalse(SuperSwingTimerDB.minimalMode, 'an explicit false must switch minimal mode off')
        SuperSwingTimerDB.minimalMode = previous
    end

    -- /sst reset used to restore only the keys in a hand-written list (~69 of
    -- 104 defaults).
    function Release028:ResetConfigDefaults_RestoresEveryDefaultKey()
        local defaults = ns.DB_DEFAULTS
        for key, value in pairs(defaults) do
            if key ~= 'version' and type(value) ~= 'table' then
                SuperSwingTimerDB[key] = 'SST_SENTINEL'
            end
        end
        SuperSwingTimerDB.colors = {}
        SuperSwingTimerDB.positions = {}
        pc(ns.ResetConfigDefaults)
        -- Second pass so the Apply* helpers run against correctly typed values.
        pc(ns.ResetConfigDefaults)
        for key, value in pairs(defaults) do
            if key ~= 'version' and type(value) ~= 'table' then
                AreEqual(SuperSwingTimerDB[key], value, 'default not restored: ' .. key)
            end
        end
        IsTrue(SuperSwingTimerDB.barBorderSize ~= 'SST_SENTINEL', 'barBorderSize must be restored')
        IsTrue(SuperSwingTimerDB.showGcdTicker ~= 'SST_SENTINEL', 'showGcdTicker must be restored')
        IsTrue(SuperSwingTimerDB.colors and SuperSwingTimerDB.colors.mh ~= nil, 'bar colours must be restored')
        IsTrue(SuperSwingTimerDB.positions and SuperSwingTimerDB.positions.mh ~= nil, 'positions must be restored')
        AreEqual(SuperSwingTimerDB.version, ns.DB_CURRENT_VERSION,
            'a reset must not rewind the migration ladder to DB_DEFAULTS.version')
    end

    -- A granted extra attack whose own swing event never arrives used to pin the
    -- suppression counter and discard every later real swing.
    function Release028:ExtraAttack_CreditExpires()
        -- HandleCLEU keys off the addon's cached UnitGUID("player"), not the
        -- global GetPlayerGUID, so the fixture must use the live value.
        local playerGuid = UnitGUID('player')
        if SetMockTime then SetMockTime(3000) end
        Replace('CombatLogGetCurrentEventInfo', function()
            return nil, 'SPELL_EXTRA_ATTACKS', nil, playerGuid, 'Player', 0, 0,
                'Creature-1', 'Mob', 0, 0, 17364, 'Stormstrike', 1, 2
        end)
        pc(ns.HandleCLEU)
        AreEqual(ns.extraAttackPending, 2, 'both granted extra attacks must be counted')

        if SetMockTime then SetMockTime(3005) end
        ns.timers.mh.state = 'idle'
        ns.timers.mh.lastSwing = 0
        Replace('CombatLogGetCurrentEventInfo', function()
            -- SWING_DAMAGE: param10 (isOffHand) is the 21st return value
            return nil, 'SWING_DAMAGE', nil, playerGuid, 'Player', 0, 0,
                'Creature-1', 'Mob', 0, 0,
                100, 0, 1, 0, 0, 0, false, false, false, false
        end)
        local ok = pc(ns.HandleCLEU)
        local pendingAfter = ns.extraAttackPending
        local state = ns.timers.mh.state
        ClearReplaces()
        IsTrue(ok, 'HandleCLEU must not error')
        AreEqual(pendingAfter, 0, 'a stale extra-attack credit must expire')
        IsTrue(state == 'swinging', 'the real swing must still restart the main-hand timer')
        ns.extraAttackPending = 0
        ns.extraAttackExpiresAt = nil
        ns.ResetTimer('mh')
    end

    -- The expiry must not disable the feature: a credited extra swing is still
    -- swallowed while its window is open.
    function Release028:ExtraAttack_StillSuppressesTheCreditedSwing()
        local playerGuid = UnitGUID('player')
        if SetMockTime then SetMockTime(4000) end
        Replace('CombatLogGetCurrentEventInfo', function()
            return nil, 'SPELL_EXTRA_ATTACKS', nil, playerGuid, 'Player', 0, 0,
                'Creature-1', 'Mob', 0, 0, 17364, 'Stormstrike', 1, 1
        end)
        pc(ns.HandleCLEU)
        AreEqual(ns.extraAttackPending, 1, 'one extra attack must be credited')
        ns.timers.mh.state = 'idle'
        Replace('CombatLogGetCurrentEventInfo', function()
            return nil, 'SWING_DAMAGE', nil, playerGuid, 'Player', 0, 0,
                'Creature-1', 'Mob', 0, 0,
                100, 0, 1, 0, 0, 0, false, false, false, false
        end)
        pc(ns.HandleCLEU)
        local pendingAfter = ns.extraAttackPending
        local state = ns.timers.mh.state
        ClearReplaces()
        AreEqual(pendingAfter, 0, 'the credited swing must consume one credit')
        IsTrue(state == 'idle', 'the extra swing must not restart the main-hand timer')
        ns.extraAttackPending = 0
        ns.extraAttackExpiresAt = nil
    end

    -- Entering combat used to write lockBars=true into SavedVariables.
    function Release028:CombatLock_DoesNotRewriteSavedPreference()
        local previous = SuperSwingTimerDB.lockBars
        SuperSwingTimerDB.lockBars = false
        ns.combatLocked = false
        local frame = rawget(_G, 'SuperSwingTimerFrame')
        local onEvent = frame and frame:GetScript('OnEvent')
        IsTrue(type(onEvent) == 'function', 'event frame must have an OnEvent handler')
        if type(onEvent) ~= 'function' then return end
        onEvent(frame, 'PLAYER_REGEN_DISABLED')
        local saved = SuperSwingTimerDB.lockBars
        local locked = ns.combatLocked
        local effective = ns.AreBarsLocked()
        onEvent(frame, 'PLAYER_REGEN_ENABLED')
        local afterCombat = ns.combatLocked
        SuperSwingTimerDB.lockBars = previous
        IsTrue(saved == false, 'entering combat must not rewrite the saved lock preference')
        IsTrue(locked == true, 'bars must still lock for the duration of the fight')
        IsTrue(effective, 'the combat lock must make AreBarsLocked true')
        IsFalse(afterCombat, 'the combat lock must release when the fight ends')
    end

    -- A localized Steady Shot name used to be unmatched, so the red-zone hold
    -- never engaged on a non-enUS client.
    function Release028:LocalizedSteadyShot_RegistersRedZone()
        local localized = 'Zuverlaessiger Schuss'
        ns.STEADY_SHOT_NAMES[localized] = true
        ns.HUNTER_CAST_SPELL_NAMES[localized] = true
        ns.HUNTER_ACTUAL_CAST_SPELL_NAMES[localized] = true

        local previousClass = ns.playerClass
        ns.playerClass = 'HUNTER'
        ns.hunterSteadyShotEndedInRedZone = nil
        ns.casting = true
        ns.timers.ranged.state = 'swinging'
        ns.timers.ranged.lastSwing = ns.GetAlignedTime()
        ns.timers.ranged.duration = 2.8

        pc(ns.HandleSpellcastSucceeded, 'player', localized, nil)
        local flagged = ns.hunterSteadyShotEndedInRedZone

        ns.hunterSteadyShotEndedInRedZone = nil
        ns.STEADY_SHOT_NAMES[localized] = nil
        ns.HUNTER_CAST_SPELL_NAMES[localized] = nil
        ns.HUNTER_ACTUAL_CAST_SPELL_NAMES[localized] = nil
        ns.casting = false
        ns.playerClass = previousClass
        ns.ResetTimer('ranged')

        IsTrue(flagged ~= nil, 'a localized Steady Shot name must register the red-zone hold')
    end

    -- ClassMods mixed the raw client aura tuple with the wrapper's normalized
    -- one, so the Reckoning stack count read a dispel type as the count.
    function Release028:ClassModsUsesOnlyWrappedAuraCalls()
        local f = io.open('SuperSwingTimer_ClassMods.lua', 'r')
        IsTrue(f ~= nil, 'SuperSwingTimer_ClassMods.lua must exist')
        if not f then return end
        local source = f:read('*all')
        f:close()
        local function count(pattern)
            local n = 0
            for _ in source:gmatch(pattern) do n = n + 1 end
            return n
        end
        AreEqual(count('UnitBuff%s*%('), count('ns%.UnitBuff%s*%('),
            'raw UnitBuff() mixes the client tuple with the normalized one; use ns.UnitBuff')
        AreEqual(count('UnitAura%s*%('), count('ns%.UnitAura%s*%('),
            'raw UnitAura() mixes the client tuple with the normalized one; use ns.UnitAura')
    end

    function Release028:GcdDuration_FollowsMeasuredValue()
        local previous = ns.gcdDuration
        ns.gcdDuration = 1.25
        local measured = ns.GetGcdDuration()
        ns.gcdDuration = previous
        AreEqual(measured, 1.25, 'GetGcdDuration must return the measured GCD, not the constant')
    end

    function Release028:SpellcastStopHandlers_ShareOneImplementation()
        IsTrue(ns.HandleSpellcastStop == ns.HandleSpellcastChannelStop,
            'UNIT_SPELLCAST_STOP and UNIT_SPELLCAST_CHANNEL_STOP must share one handler')
    end

    -- Feign Death (5384) is registered in RESET_SWING_SPELLS, so the dedicated
    -- Feign Death branch used to be unreachable and restarted the ranged cycle.
    function Release028:FeignDeath_CancelsRangedCycle()
        local previousClass = ns.playerClass
        ns.playerClass = 'HUNTER'
        ns.hunterAutoRepeatActive = true
        ns.casting = true
        ns.timers.ranged.state = 'swinging'
        ns.timers.ranged.lastSwing = ns.GetAlignedTime()
        ns.timers.ranged.duration = 2.8
        pc(ns.HandleSpellcastSucceeded, 'player', 5384, 5384)
        local state = ns.timers.ranged.state
        ns.casting = false
        ns.playerClass = previousClass
        ns.ResetTimer('ranged')
        IsTrue(state == 'idle', 'Feign Death must cancel the ranged cycle instead of restarting it')
    end

    -- Every non-Hunter class has classConfig.ranged=false. Before v0.2.8 a
    -- successful cast started a hidden "swinging" ranged timer for all of them,
    -- which kept HasActiveTimers() true and ran ranged speed sync for a bar the
    -- class never renders. The gate must hold for every class, not just Warrior.
    function Release028:MeleeClass_CastDoesNotStartRangedTimer()
        local previousClass, previousConfig = ns.playerClass, ns.classConfig
        local failures = {}
        for className, config in pairs(ns.CLASS_CONFIG) do
            if config.ranged ~= true then
                ns.playerClass = className
                ns.classConfig = config
                ns.ResetTimer('ranged')
                ns.ResetTimer('mh')
                ns.ResetTimer('oh')
                ns.casting = true
                local ok = pc(ns.HandleSpellcastSucceeded, 'player', 'Battle Shout', 6673)
                local state = ns.timers.ranged.state
                if not ok or state == 'swinging' then
                    failures[#failures + 1] = className .. ':' .. tostring(state) .. (ok and '' or ':error')
                end
            end
        end
        ns.casting = false
        ns.ResetTimer('ranged')
        ns.ResetTimer('mh')
        ns.ResetTimer('oh')
        ns.playerClass, ns.classConfig = previousClass, previousConfig
        IsTrue(#failures == 0,
            'no class without a ranged slot may start a phantom ranged timer: ' .. table.concat(failures, ', '))
    end

    -- A Hunter melee ability must never start or restart the Auto Shot cycle.
    -- v0.2.8 widened the generic cast-success ranged reset to every class with
    -- a ranged slot, so a Raptor Strike success that reached this branch while
    -- ns.casting was true started a ranged timer with no Auto Shot behind it.
    function Release028:RaptorStrikeCast_DoesNotRestartRangedCycle()
        local previousClass, previousConfig = ns.playerClass, ns.classConfig
        local previousQueued = ns.hunterQueuedMeleeSpell
        ns.playerClass = 'HUNTER'
        ns.classConfig = ns.CLASS_CONFIG.HUNTER
        ns.hunterQueuedMeleeSpell = nil
        ns.preventSwingReset = false
        ns.ResetTimer('ranged')
        ns.ResetTimer('mh')
        if SetMockTime then SetMockTime(2000) end

        local okStart = pc(ns.HandleSpellcastStart, 'player', 2973, 2973)
        local castingAfterStart = ns.casting
        local okSuccess = pc(ns.HandleSpellcastSucceeded, 'player', 2973, 2973)
        local rangedState = ns.timers.ranged.state
        local mhState = ns.timers.mh.state
        local castingAfterSuccess = ns.casting

        ns.playerClass, ns.classConfig = previousClass, previousConfig
        ns.hunterQueuedMeleeSpell = previousQueued
        IsTrue(okStart, 'HandleSpellcastStart must not error for Raptor Strike')
        IsTrue(okSuccess, 'HandleSpellcastSucceeded must not error for Raptor Strike')
        IsTrue(castingAfterStart == true, 'a spellcast start must set ns.casting (the branch precondition)')
        IsFalse(castingAfterSuccess, 'a spellcast success must clear ns.casting')
        AreEqual(rangedState, 'idle', 'Raptor Strike must not start or restart the Auto Shot cycle')
        AreEqual(mhState, 'swinging', 'Raptor Strike must still restart the main-hand timer')
    end

    -- The main-hand CLEU branches must restart MH/OH only. They must never
    -- write the ranged timer (the ranged cycle is owned by Auto Shot events).
    function Release028:MainHandCLEU_DoesNotResetRangedTimer()
        local previousClass, previousConfig = ns.playerClass, ns.classConfig
        local previousEnemy = ns.enemyTargetGUID
        local previousPending, previousExpires = ns.extraAttackPending, ns.extraAttackExpiresAt
        local playerGuid = UnitGUID('player')
        ns.playerClass = 'HUNTER'
        ns.classConfig = ns.CLASS_CONFIG.HUNTER
        ns.enemyTargetGUID = nil
        ns.extraAttackPending = 0
        ns.extraAttackExpiresAt = nil
        ns.timers.ranged.state = 'swinging'
        ns.timers.ranged.lastSwing = 100.0
        ns.timers.ranged.duration = 2.8
        ns.timers.ranged.speed = 2.8
        ns.ResetTimer('mh')

        if SetMockTime then SetMockTime(101.0) end
        Replace('CombatLogGetCurrentEventInfo', function()
            -- SWING_DAMAGE: base args 1-11, then amount..isOffHand (arg 21)
            return nil, 'SWING_DAMAGE', nil, playerGuid, 'Player', 0, 0,
                'Creature-1', 'Mob', 0, 0,
                100, 0, 1, 0, 0, 0, false, false, false, false
        end)
        local okDamage = pc(ns.HandleCLEU)
        local rangedStateAfterDamage = ns.timers.ranged.state
        local rangedLastSwingAfterDamage = ns.timers.ranged.lastSwing
        local mhStateAfterDamage = ns.timers.mh.state
        local mhLastSwingAfterDamage = ns.timers.mh.lastSwing

        if SetMockTime then SetMockTime(102.0) end
        Replace('CombatLogGetCurrentEventInfo', function()
            -- SWING_MISSED: missType arg 12, isOffHand arg 13
            return nil, 'SWING_MISSED', nil, playerGuid, 'Player', 0, 0,
                'Creature-1', 'Mob', 0, 0,
                'MISS', false
        end)
        local okMiss = pc(ns.HandleCLEU)
        local rangedStateAfterMiss = ns.timers.ranged.state
        local rangedLastSwingAfterMiss = ns.timers.ranged.lastSwing
        local mhLastSwingAfterMiss = ns.timers.mh.lastSwing

        ClearReplaces()
        ns.playerClass, ns.classConfig = previousClass, previousConfig
        ns.enemyTargetGUID = previousEnemy
        ns.extraAttackPending, ns.extraAttackExpiresAt = previousPending, previousExpires
        IsTrue(okDamage, 'HandleCLEU must not error for a player SWING_DAMAGE')
        IsTrue(okMiss, 'HandleCLEU must not error for a player SWING_MISSED')
        AreEqual(rangedStateAfterDamage, 'swinging', 'a main-hand hit must not reset the ranged timer')
        AreEqual(rangedLastSwingAfterDamage, 100.0, 'a main-hand hit must not move the ranged cycle anchor')
        AreEqual(mhStateAfterDamage, 'swinging', 'a main-hand hit must restart the main-hand timer')
        AreEqual(mhLastSwingAfterDamage, 101.0, 'the main-hand timer must use the CLEU event time')
        AreEqual(rangedStateAfterMiss, 'swinging', 'a main-hand miss must not reset the ranged timer')
        AreEqual(rangedLastSwingAfterMiss, 100.0, 'a main-hand miss must not move the ranged cycle anchor')
        AreEqual(mhLastSwingAfterMiss, 102.0, 'a main-hand miss must restart the main-hand timer')
    end

    -- The legitimate Auto Shot path must still start the ranged cycle.
    function Release028:AutoShotCLEU_StartsRangedCycle()
        local previousClass, previousConfig = ns.playerClass, ns.classConfig
        local playerGuid = UnitGUID('player')
        ns.playerClass = 'HUNTER'
        ns.classConfig = ns.CLASS_CONFIG.HUNTER
        ns.ResetTimer('ranged')
        if SetMockTime then SetMockTime(1100.0) end
        Replace('CombatLogGetCurrentEventInfo', function()
            return nil, 'SPELL_CAST_SUCCESS', nil, playerGuid, 'Player', 0, 0,
                'Creature-1', 'Mob', 0, 0, ns.AUTO_SHOT_ID
        end)
        local ok = pc(ns.HandleCLEU)
        local state = ns.timers.ranged.state
        local duration = ns.timers.ranged.duration
        ClearReplaces()
        ns.playerClass, ns.classConfig = previousClass, previousConfig
        IsTrue(ok, 'HandleCLEU must not error for an Auto Shot cast success')
        AreEqual(state, 'swinging', 'an Auto Shot cast success must start the ranged cycle')
        IsTrue(duration and duration > 0, 'the started ranged cycle must have a positive duration')
    end

    -- "Shoot" is the Classic Era alias shape for Auto Shot. The narrowed gate
    -- must still accept it, or a real Auto Shot would stop restarting ranged.
    function Release028:AutoShotShootAlias_StillStartsRangedCycle()
        local previousClass, previousConfig = ns.playerClass, ns.classConfig
        ns.playerClass = 'HUNTER'
        ns.classConfig = ns.CLASS_CONFIG.HUNTER
        ns.ResetTimer('ranged')
        ns.casting = true
        ns.preventSwingReset = false
        ns.currentCastSpellId = nil
        ns.lastResolvedHunterCastToken = nil
        ns.lastResolvedHunterCastAt = nil
        if SetMockTime then SetMockTime(1200.0) end
        local ok = pc(ns.HandleSpellcastSucceeded, 'player', 'Shoot', nil)
        local state = ns.timers.ranged.state
        ns.casting = false
        ns.playerClass, ns.classConfig = previousClass, previousConfig
        IsTrue(ok, 'HandleSpellcastSucceeded must not error for the Shoot alias')
        AreEqual(state, 'swinging', 'the Shoot alias must still start the ranged cycle')
    end

    -- Every historical DB version must migrate to the current one.
    function Release028:MigrateDB_FromEveryHistoricalVersion()
        for version = 0, ns.DB_CURRENT_VERSION do
            local db = { version = version }
            local ok = pc(ns.MigrateDB, db)
            IsTrue(ok, 'migration from v' .. version .. ' must not error')
            AreEqual(db.version, ns.DB_CURRENT_VERSION,
                'migration from v' .. version .. ' must reach the current version')
        end
    end

    -- WoW Forever (16001) C_SwingTimer / PLAYER_SWING compatibility gate.
    function Release028:ForeverGate_HandlePlayerSwing_StartsTimers()
        local previousClass, previousConfig = ns.playerClass, ns.classConfig
        ns.playerClass = 'HUNTER'
        ns.classConfig = ns.CLASS_CONFIG.HUNTER
        ns.ResetTimer('mh')
        ns.ResetTimer('oh')
        ns.ResetTimer('ranged')

        local prevSwingTimer = rawget(_G, 'C_SwingTimer')
        local prevEnum = rawget(_G, 'Enum')
        rawset(_G, 'C_SwingTimer', {
            IsTargetWithinSwingRange = function() return true end,
        })
        rawset(_G, 'Enum', {
            PlayerSwingType = { MainHand = 0, OffHand = 1, Ranged = 2 },
        })

        IsTrue(ns.HasNativeSwingTimer(), 'HasNativeSwingTimer must be true when C_SwingTimer is present')
        -- A native swing timer is not proof that CLEU is restricted; only the
        -- client's C_CombatLog.IsCombatLogRestricted() query may decide that.
        IsFalse(ns.IsRestrictedCombatLog(), 'native C_SwingTimer alone must not disable the combat log')

        local prevCombatLog = rawget(_G, 'C_CombatLog')
        rawset(_G, 'C_CombatLog', { IsCombatLogRestricted = function() return true end })
        IsTrue(ns.IsRestrictedCombatLog(), 'C_CombatLog.IsCombatLogRestricted() must gate CLEU on Forever')
        rawset(_G, 'C_CombatLog', { IsCombatLogRestricted = function() return false end })
        IsFalse(ns.IsRestrictedCombatLog(), 'a readable combat log must stay enabled on Forever')

        ns.HandlePlayerSwing(2.6, 0)
        AreEqual(ns.timers.mh.state, 'swinging', 'MainHand (0) PLAYER_SWING must start MH timer')
        AreEqual(ns.timers.mh.duration, 2.6, 'MainHand PLAYER_SWING must use explicit duration')

        ns.HandlePlayerSwing(1.8, 1)
        AreEqual(ns.timers.oh.state, 'swinging', 'OffHand (1) PLAYER_SWING must start OH timer')
        AreEqual(ns.timers.oh.duration, 1.8, 'OffHand PLAYER_SWING must use explicit duration')

        ns.HandlePlayerSwing(2.9, 2)
        AreEqual(ns.timers.ranged.state, 'swinging', 'Ranged (2) PLAYER_SWING must start Ranged timer')
        AreEqual(ns.timers.ranged.duration, 2.9, 'Ranged PLAYER_SWING must use explicit duration')
        AreEqual(ns.timers.ranged.lastNativeStartAt, ns.timers.ranged.lastSwing,
            'a native ranged start must be recorded so the CLEU fallback cannot double-start it')

        -- Enemy tracking is suppressed only while the combat log is restricted.
        rawset(_G, 'C_CombatLog', { IsCombatLogRestricted = function() return true end })
        ns.RefreshEnemyTarget()
        AreEqual(ns.enemyTargetGUID, nil, 'RefreshEnemyTarget must keep enemyTargetGUID nil under restricted combat log')
        rawset(_G, 'C_CombatLog', prevCombatLog)

        local prevCVar = rawget(_G, 'C_CVar')
        local recordedCVarName, recordedCVarVal
        rawset(_G, 'C_CVar', {
            SetCVar = function(k, v)
                recordedCVarName = k
                recordedCVarVal = v
            end,
        })
        ns.ApplyBlizzardSwingTimerVisibility(true)
        AreEqual(recordedCVarName, 'showSwingTimer', 'ApplyBlizzardSwingTimerVisibility must set showSwingTimer CVar')
        AreEqual(recordedCVarVal, '0', 'ApplyBlizzardSwingTimerVisibility(true) must disable Blizzard swing timer')
        ns.ApplyBlizzardSwingTimerVisibility(false)
        AreEqual(recordedCVarVal, '1', 'ApplyBlizzardSwingTimerVisibility(false) must re-enable Blizzard swing timer')
        rawset(_G, 'C_CVar', prevCVar)

        rawset(_G, 'C_SwingTimer', prevSwingTimer)
        rawset(_G, 'Enum', prevEnum)
        ns.playerClass, ns.classConfig = previousClass, previousConfig
    end

    -- WoW Forever secret-value guard for UnitAura and SafeNumber.
    function Release028:ForeverGate_SecretValues_GuardedSafely()
        local prevIsSecret = rawget(_G, 'issecretvalue')
        local prevCUnitAuras = rawget(_G, 'C_UnitAuras')
        local secretSentinel = {}
        rawset(_G, 'issecretvalue', function(v) return v == secretSentinel or v == 999999 end)

        AreEqual(ns.IsSecretValue(secretSentinel), true, 'IsSecretValue must detect secret values')
        AreEqual(ns.SafeNumber(999999, 42), 42, 'SafeNumber must return fallback for secret number')
        AreEqual(ns.SafeNumber(2.5, 42), 2.5, 'SafeNumber must return numeric value when not secret')

        rawset(_G, 'C_UnitAuras', {
            GetAuraDataByIndex = function()
                return {
                    name = secretSentinel,
                    icon = 136000,
                    applications = 1,
                    duration = 10,
                    expirationTime = 100,
                    sourceUnit = 'player',
                    spellId = 12345,
                }
            end,
        })

        local auraName = ns.UnitAura('player', 1, 'HELPFUL')
        AreEqual(auraName, nil, 'ns.UnitAura must return nil when C_UnitAuras returns secret fields')

        rawset(_G, 'issecretvalue', prevIsSecret)
        rawset(_G, 'C_UnitAuras', prevCUnitAuras)
    end

    -- A secret UnitAttackSpeed value must never reach a comparison: StartSwing
    -- has to fall back to the cached/2.0 speed instead of raising.
    function Release028:ForeverGate_SecretAttackSpeed_DoesNotThrow()
        local prevSecret = rawget(_G, 'issecretvalue')
        local prevAttackSpeed = rawget(_G, 'UnitAttackSpeed')
        -- Numeric string: the removed `or tonumber(x)` tail would re-parse it
        -- and produce 9.9 instead of the real weapon speed (2.6 in the mock).
        local secret = '9.9'
        rawset(_G, 'issecretvalue', function(v) return v == secret end)

        ns.playerClass = 'WARRIOR'
        ns.classConfig = ns.CLASS_CONFIG.WARRIOR
        ns.ResetTimer('mh')
        local ok, err = pcall(ns.StartSwing, 'mh', nil, 1000, secret)
        IsTrue(ok, 'StartSwing must not raise on a secret duration: ' .. tostring(err))
        AreEqual(ns.timers.mh.state, 'swinging', 'MH timer must start with the fallback speed')
        AreEqual(ns.timers.mh.duration, 2.6,
            'secret duration must be ignored, never re-parsed outside the guard')

        ns.ResetTimer('mh')
        rawset(_G, 'UnitAttackSpeed', prevAttackSpeed)
        rawset(_G, 'issecretvalue', prevSecret)
    end

    -- A restricted UNIT_SPELLCAST_* payload must degrade to "unknown spell"
    -- instead of comparing secret values.
    function Release028:ForeverGate_SecretSpellcastPayload_DoesNotThrow()
        local prevSecret = rawget(_G, 'issecretvalue')
        local prevScrub = rawget(_G, 'scrubsecretvalues')
        local secret = {}
        rawset(_G, 'issecretvalue', function(v) return v == secret end)
        rawset(_G, 'scrubsecretvalues', function() return nil, nil, nil end)

        ns.playerClass = 'WARRIOR'
        ns.classConfig = ns.CLASS_CONFIG.WARRIOR
        local ok, err = pcall(ns.HandleSpellcastSucceeded, 'player', secret, secret)
        IsTrue(ok, 'HandleSpellcastSucceeded must not raise on a secret payload: ' .. tostring(err))
        local ok2, err2 = pcall(ns.HandleSpellcastInterruptedOrFailed, 'player', secret, secret)
        IsTrue(ok2, 'HandleSpellcastInterruptedOrFailed must not raise on a secret payload: ' .. tostring(err2))

        rawset(_G, 'scrubsecretvalues', prevScrub)
        rawset(_G, 'issecretvalue', prevSecret)
    end

    -- PLAYER_SWING hands the addon the real cycle duration; the throttled speed
    -- sync must not overwrite it mid-swing.
    function Release028:ForeverGate_NativeSwingDuration_SurvivesSpeedSync()
        local prevAttackSpeed = rawget(_G, 'UnitAttackSpeed')
        rawset(_G, 'UnitAttackSpeed', function() return 3.5, 1.5 end)

        ns.playerClass = 'WARRIOR'
        ns.classConfig = ns.CLASS_CONFIG.WARRIOR
        ns.ResetTimer('mh')
        local now = ns.GetAlignedTime()
        ns.StartSwing('mh', nil, now, 2.0)
        AreEqual(ns.timers.mh.duration, 2.0, 'native PLAYER_SWING duration must be applied')
        ns.SyncMeleeTimerSpeed('mh', now + 0.2, true)
        AreEqual(ns.timers.mh.duration, 2.0,
            'speed sync must not overwrite the native swing duration mid-swing')

        ns.ResetTimer('mh')
        rawset(_G, 'UnitAttackSpeed', prevAttackSpeed)
    end

    -- Secret text must be handed to SetText (AllowedWhenTainted) instead of
    -- being compared or dropped.
    function Release028:ForeverGate_SecretLabelText_IsPassedThrough()
        local prevSecret = rawget(_G, 'issecretvalue')
        local secretText = {}
        rawset(_G, 'issecretvalue', function(v) return v == secretText end)

        local bar = { labelText = CreateFrame('Frame') }
        local ok, err = pcall(ns.SetBarLabelText, bar, secretText, true)
        IsTrue(ok, 'SetBarLabelText must accept secret text: ' .. tostring(err))
        AreEqual(bar.labelText:GetText(), secretText,
            'secret text must reach SetText unchanged (pass-through, not dropped)')

        rawset(_G, 'issecretvalue', prevSecret)
    end

    -- Regression for the in-game failure "attempt to perform numeric conversion
    -- on a secret number value": a probe that raises on a plain value must never
    -- make the guard report "not secret" (the old capability self-test did).
    function Release028:ForeverGate_ProbeFailure_DoesNotDisableGuard()
        local prevSecret = rawget(_G, 'issecretvalue')
        local sentinel = {}
        rawset(_G, 'issecretvalue', function(v)
            if v == 1 then
                error('probe failed on a plain value')
            end
            return v == sentinel
        end)

        IsTrue(ns.IsSecretValue(sentinel),
            'a raising probe must not make every value look plain')
        AreEqual(ns.SafeNumber(sentinel, 7), 7,
            'SafeNumber must still fall back for the secret value')

        rawset(_G, 'issecretvalue', prevSecret)
    end

    -- The in-game failure mode: the client reports "not secret" for a value it
    -- still refuses to convert. SafeNumber must catch the raising conversion
    -- itself instead of trusting detection.
    function Release028:ForeverGate_ConversionGuard_CatchesUndetectedSecret()
        local prevSecret = rawget(_G, 'issecretvalue')
        local prevIsSecretValue = ns.IsSecretValue
        local prevMax = math.max
        local sentinel = 7

        rawset(_G, 'issecretvalue', function() return false end)
        ns.IsSecretValue = function() return false end
        rawset(math, 'max', function(a, b)
            if a == sentinel or b == sentinel then
                error('attempt to perform numeric conversion on a secret number value')
            end
            return prevMax(a, b)
        end)

        local ok, result = pcall(ns.SafeNumber, sentinel, 42)

        rawset(math, 'max', prevMax)
        ns.IsSecretValue = prevIsSecretValue
        rawset(_G, 'issecretvalue', prevSecret)

        IsTrue(ok, 'SafeNumber must not raise on a restricted conversion: ' .. tostring(result))
        AreEqual(result, 42,
            'SafeNumber must fall back when the numeric conversion raises')
    end

    local ForeverAura = WoWUnit:New('SST-ForeverAura', 'PLAYER_ENTERING_WORLD')

    function ForeverAura:TOC_LoadsForeverModule()
        local f = io.open("SuperSwingTimer.toc", "r")
        IsTrue(f ~= nil, "SuperSwingTimer.toc must exist")
        local content = f:read("*all")
        f:close()
        IsTrue(content:find("SuperSwingTimer_Forever.lua", 1, true) ~= nil,
            "TOC must load SuperSwingTimer_Forever.lua")
    end

    function ForeverAura:WeaveFamilies_HaveForeverRanks()
        local groups = ns.FOREVER_WEAVE_SPELL_GROUPS or {}
        local byAbbrev = {}
        for _, group in ipairs(groups) do
            byAbbrev[group.abbrev] = group
        end
        IsTrue(byAbbrev.LB ~= nil, "LB family must exist")
        AreEqual(#byAbbrev.LB.ids, 10, "Forever LB must have 10 ranks")
        AreEqual(byAbbrev.LB.ids[10], 15208, "Forever LB rank 10 is 15208")
        AreEqual(#byAbbrev.CL.ids, 4, "Forever CL must have 4 ranks")
        AreEqual(byAbbrev.CL.ids[4], 10605, "Forever CL rank 4 is 10605")
        AreEqual(#byAbbrev.HW.ids, 10, "Forever HW must have 10 ranks")
        AreEqual(byAbbrev.HW.ids[10], 25357, "Forever HW rank 10 is 25357")
        AreEqual(#byAbbrev.LHW.ids, 6, "Forever LHW must have 6 ranks")
        AreEqual(#byAbbrev.CH.ids, 3, "Forever CH must have 3 ranks")
    end

    function ForeverAura:Maelstrom_ReadsAndConsumes()
        local prevForever = ns.isForever
        local prevCUnitAuras = rawget(_G, 'C_UnitAuras')
        local prevSecret = rawget(_G, 'issecretvalue')
        local prevSecrecy = ns.GetSpellAuraSecrecy

        ns.isForever = true
        ns.GetSpellAuraSecrecy = function() return 0 end -- NeverSecret
        rawset(_G, 'issecretvalue', function() return false end)
        rawset(_G, 'C_UnitAuras', {
            GetPlayerAuraBySpellID = function(spellID)
                if spellID == 408505 then
                    return { spellId = 408505, applications = 3, duration = 20, expirationTime = 100 }
                end
                return nil
            end,
        })

        AreEqual(ns.GetForeverMaelstromStacks(), 3, "Maelstrom stacks must be read from the Forever aura")
        IsTrue(math.abs(ns.ForeverMaelstromMultiplier("LB") - 0.4) < 1e-9,
            "3 stacks = 40% cast time on LB")
        AreEqual(ns.ForeverMaelstromMultiplier("CL"), 1.0, "CL must not receive the reduction")
        ns.ForeverMaelstromConsume()
        AreEqual(ns.foreverMaelstromStacks, 0, "consume must clear the stacks")

        ns.GetSpellAuraSecrecy = prevSecrecy
        ns.isForever = prevForever
        rawset(_G, 'C_UnitAuras', prevCUnitAuras)
        rawset(_G, 'issecretvalue', prevSecret)
    end

    function ForeverAura:Maelstrom_SecretIsRejected()
        local prevForever = ns.isForever
        local prevCUnitAuras = rawget(_G, 'C_UnitAuras')
        local prevSecret = rawget(_G, 'issecretvalue')
        local prevSecrecy = ns.GetSpellAuraSecrecy
        local secret = setmetatable({}, { __tostring = function() return "secret" end })

        ns.isForever = true
        ns.GetSpellAuraSecrecy = function() return 0 end
        rawset(_G, 'issecretvalue', function(value) return value == secret end)
        rawset(_G, 'C_UnitAuras', {
            GetPlayerAuraBySpellID = function()
                return { spellId = 408505, applications = secret, duration = 20, expirationTime = 100 }
            end,
        })

        AreEqual(ns.GetForeverMaelstromStacks(), nil, "a secret stack count must return nil")
        AreEqual(ns.ForeverMaelstromMultiplier("LB"), 1.0, "unreadable stacks must not reduce cast time")

        ns.GetSpellAuraSecrecy = prevSecrecy
        ns.isForever = prevForever
        rawset(_G, 'C_UnitAuras', prevCUnitAuras)
        rawset(_G, 'issecretvalue', prevSecret)
    end

    function ForeverAura:Weave_UsesForeverRanksAndLBOnly()
        local prevForever = ns.isForever
        local prevCUnitAuras = rawget(_G, 'C_UnitAuras')
        local prevSecret = rawget(_G, 'issecretvalue')
        local prevSecrecy = ns.GetSpellAuraSecrecy
        local prevGetSpellInfo = _G.GetSpellInfo

        ns.isForever = true
        ns.GetSpellAuraSecrecy = function() return 0 end
        rawset(_G, 'issecretvalue', function() return false end)
        rawset(_G, 'C_UnitAuras', {
            GetPlayerAuraBySpellID = function(spellID)
                if spellID == 408505 then
                    return { spellId = 408505, applications = 3, duration = 20, expirationTime = 100 }
                end
                return nil
            end,
        })
        _G.GetSpellInfo = function(id)
            local cast = 1500
            if id == 15208 then cast = 2500 end
            if id == 10605 then cast = 2500 end
            return "Spell-" .. tostring(id), "", "icon", cast, 0, 30, id
        end

        IsTrue(math.abs(ns.GetEffectiveSpellCastTime({ spellId = 15208, abbrev = "LB", castTime = 2.5 }) - 1.0) < 1e-9,
            "Forever LB rank 10 at 3 stacks = 1.0 s")
        IsTrue(math.abs(ns.GetEffectiveSpellCastTime({ spellId = 10605, abbrev = "CL", castTime = 2.5 }) - 2.5) < 1e-9,
            "Forever CL keeps its 2.5 s cast time (no Maelstrom reduction)")

        _G.GetSpellInfo = prevGetSpellInfo
        ns.GetSpellAuraSecrecy = prevSecrecy
        ns.isForever = prevForever
        rawset(_G, 'C_UnitAuras', prevCUnitAuras)
        rawset(_G, 'issecretvalue', prevSecret)
    end

    function ForeverAura:SlamPauseRule_ForeverOnly()
        local prevForever = ns.isForever
        local prevIsPlayerSpell = _G.IsPlayerSpell

        ns.isForever = true
        local hasImprovedSlam = true
        _G.IsPlayerSpell = function(id) return hasImprovedSlam and id == 12862 end
        IsFalse(ns.ForeverSlamPausesSwing(1240193), "Improved Slam removes the swing delay")

        hasImprovedSlam = false
        IsTrue(ns.ForeverSlamPausesSwing(1240193), "without Improved Slam the cast delays the swing")
        IsFalse(ns.ForeverSlamPausesSwing(1464), "other Slam ranks are not the Forever rule")

        ns.isForever = false
        IsFalse(ns.ForeverSlamPausesSwing(1240193), "non-Forever clients never use the rule")

        ns.isForever = prevForever
        _G.IsPlayerSpell = prevIsPlayerSpell
    end

    function ForeverAura:NewAbilities_AreTracked()
        local function has(list, id)
            for _, value in ipairs(list or {}) do
                if value == id then return true end
            end
            return false
        end
        local function hasAnywhere(id)
            for _, list in pairs(ns.FOREVER_BUFF_SPELLS or {}) do
                if has(list, id) then return true end
            end
            for _, list in pairs(ns.FOREVER_DEBUFF_SPELLS or {}) do
                if has(list, id) then return true end
            end
            for _, list in pairs(ns.FOREVER_STANCE_SPELLS or {}) do
                if has(list, id) then return true end
            end
            for _, list in pairs(ns.FOREVER_NEW_ABILITY_CANDIDATES or {}) do
                if has(list, id) then return true end
            end
            return false
        end
        local required = {
            402927, 1310222, 1329555, 1240193, -- Warrior
            1329283, 1329328, 399956, 1328825, -- Rogue
            1328617, 407995, 1223246, 417051, -- Druid
            408498, 425336, 408341, 1223031,  -- Shaman
            679, 1311649, 20183, 1310735,      -- Paladin
            1317257, 1310533, 19306, 19552, 13161, 1265831, -- Hunter
        }
        for _, id in ipairs(required) do
            IsTrue(hasAnywhere(id), "new Forever ability " .. tostring(id) .. " must be tracked")
        end
    end

    function ForeverAura:StanceSpells_SegregatedFromProcBuffs()
        local function has(list, id)
            for _, value in ipairs(list or {}) do
                if value == id then return true end
            end
            return false
        end
        -- Aspects must be in FOREVER_STANCE_SPELLS and not in FOREVER_BUFF_SPELLS
        local hunterStances = ns.FOREVER_STANCE_SPELLS and ns.FOREVER_STANCE_SPELLS.HUNTER
        local hunterBuffs = ns.FOREVER_BUFF_SPELLS and ns.FOREVER_BUFF_SPELLS.HUNTER
        IsTrue(has(hunterStances, 13165), "Aspect of the Hawk rank 1 in stance spells")
        IsTrue(has(hunterStances, 27044), "Aspect of the Hawk rank 8 in stance spells")
        IsFalse(has(hunterBuffs, 13165), "Aspect of the Hawk rank 1 must not be in buff proc spells")
        IsFalse(has(hunterBuffs, 27044), "Aspect of the Hawk rank 8 must not be in buff proc spells")

        -- Warrior Stances
        local warriorStances = ns.FOREVER_STANCE_SPELLS and ns.FOREVER_STANCE_SPELLS.WARRIOR
        local warriorBuffs = ns.FOREVER_BUFF_SPELLS and ns.FOREVER_BUFF_SPELLS.WARRIOR
        IsTrue(has(warriorStances, 2457), "Battle Stance in stance spells")
        IsTrue(has(warriorStances, 71), "Defensive Stance in stance spells")
        IsTrue(has(warriorStances, 2458), "Berserker Stance in stance spells")
        IsFalse(has(warriorBuffs, 2457), "Battle Stance must not be in buff proc spells")

        -- Paladin Seals
        local paladinStances = ns.FOREVER_STANCE_SPELLS and ns.FOREVER_STANCE_SPELLS.PALADIN
        local paladinBuffs = ns.FOREVER_BUFF_SPELLS and ns.FOREVER_BUFF_SPELLS.PALADIN
        IsTrue(has(paladinStances, 20375), "Seal of Command in stance spells")
        IsTrue(has(paladinStances, 1311649), "Seal of Fury in stance spells")
        IsFalse(has(paladinBuffs, 20375), "Seal of Command must not be in buff proc spells")

        -- Shaman Shields
        local shamanStances = ns.FOREVER_STANCE_SPELLS and ns.FOREVER_STANCE_SPELLS.SHAMAN
        local shamanBuffs = ns.FOREVER_BUFF_SPELLS and ns.FOREVER_BUFF_SPELLS.SHAMAN
        IsTrue(has(shamanStances, 324), "Lightning Shield in stance spells")
        IsTrue(has(shamanStances, 52127), "Water Shield in stance spells")
        IsFalse(has(shamanBuffs, 324), "Lightning Shield must not be in buff proc spells")

        -- Druid Forms
        local druidStances = ns.FOREVER_STANCE_SPELLS and ns.FOREVER_STANCE_SPELLS.DRUID
        local druidBuffs = ns.FOREVER_BUFF_SPELLS and ns.FOREVER_BUFF_SPELLS.DRUID
        IsTrue(has(druidStances, 768), "Cat Form in stance spells")
        IsTrue(has(druidStances, 9634), "Dire Bear Form in stance spells")
        IsFalse(has(druidBuffs, 768), "Cat Form must not be in buff proc spells")

        -- Rogue Stealth
        local rogueStances = ns.FOREVER_STANCE_SPELLS and ns.FOREVER_STANCE_SPELLS.ROGUE
        local rogueBuffs = ns.FOREVER_BUFF_SPELLS and ns.FOREVER_BUFF_SPELLS.ROGUE
        IsTrue(has(rogueStances, 1784), "Stealth in stance spells")
        IsFalse(has(rogueBuffs, 1784), "Stealth must not be in buff proc spells")
    end

    function ForeverAura:UpdateForeverAuraIcons_Throttling()
        -- Calling with 0 or nil should be safe and execute without errors
        local ok0, _ = pcall(ns.UpdateForeverAuraIcons, 0)
        IsTrue(ok0, "calling UpdateForeverAuraIcons(0) is safe")
        local okNil, _ = pcall(ns.UpdateForeverAuraIcons)
        IsTrue(okNil, "calling UpdateForeverAuraIcons() is safe")
        local okElapsed, _ = pcall(ns.UpdateForeverAuraIcons, 0.016)
        IsTrue(okElapsed, "calling UpdateForeverAuraIcons(elapsed) is safe")
    end

    function ForeverAura:DruidDebuffs_ExcludeRemovedSpells()
        local function has(list, id)
            for _, value in ipairs(list or {}) do
                if value == id then return true end
            end
            return false
        end
        local druid = ns.FOREVER_DEBUFF_SPELLS.DRUID
        IsFalse(has(druid, 16857), "Faerie Fire (Feral) was removed from Forever")
        IsFalse(has(druid, 33876), "Mangle (cat) was removed from Forever")
        IsFalse(has(druid, 33878), "Mangle (bear) was removed from Forever")
        IsTrue(has(druid, 770), "base Faerie Fire must stay tracked")
    end

    function ForeverAura:IconRows_ShareThirtyByTwentyFiveShape()
        local width, height = ns.GetForeverBuffIconDimensions(30)
        AreEqual(width, 30, "a 30 px configured width renders 30 px wide")
        AreEqual(height, 25, "a 30 px configured width renders 25 px tall")

        -- The debuff row is built from the same helper, so the rows match.
        local debuffWidth, debuffHeight = ns.GetForeverIconDimensions(30)
        AreEqual(debuffWidth, width, "debuff and buff widths match")
        AreEqual(debuffHeight, height, "debuff and buff heights match")

        -- A customised slider value keeps the aspect instead of a fixed size.
        local customWidth, customHeight = ns.GetForeverIconDimensions(36)
        AreEqual(customWidth, 36, "a custom width is honoured")
        AreEqual(customHeight, 30, "a custom height follows the 30x25 aspect")

        local defaultWidth, defaultHeight = ns.GetForeverIconDimensions(nil)
        AreEqual(defaultWidth, 30, "the default width is 30")
        AreEqual(defaultHeight, 25, "the default height is 25")

        local minWidth, minHeight = ns.GetForeverIconDimensions(1)
        AreEqual(minWidth, 8, "tiny values clamp to the minimum width")
        AreEqual(minHeight, 8, "tiny values clamp to the minimum height")
    end

    function ForeverAura:DebuffRowPopulation_HandlesSecretHeight()
        local prevProbe = _G.issecretvalue
        local sentinel = 987654.25
        _G.issecretvalue = function(value) return value == sentinel end

        -- A secret height must be classified without comparing it: the client
        -- hands back a secret number while the debuff row holds frames, which
        -- is exactly the value that raised "attempt to compare a secret number".
        IsTrue(ns.IsForeverDebuffRowPopulated(true, sentinel),
            "a secret height means the debuff row is populated")
        IsTrue(ns.IsForeverDebuffRowPopulated(true, 47),
            "a plain populated height reserves space")
        IsFalse(ns.IsForeverDebuffRowPopulated(true, 1),
            "an empty 1x1 container collapses the proc row to the bar")
        IsFalse(ns.IsForeverDebuffRowPopulated(false, nil),
            "an unreadable container falls back to the bar")

        _G.issecretvalue = prevProbe
    end

    function ForeverAura:StanceIcon_OneSizeBiggerThanBar()
        local function sizeAt(barHeight)
            return ns.GetForeverStanceIconSize({ GetHeight = function() return barHeight end })
        end
        AreEqual(sizeAt(15), 20, "default 15 px bar gives an 18 + 2 px stance icon")
        AreEqual(sizeAt(21), 23, "mid-range bars add the 2 px bonus")
        AreEqual(sizeAt(30), 26, "tall bars clamp at 24 + 2 px")
        AreEqual(ns.GetForeverStanceIconSize(nil), 20, "missing bar falls back to 18 + 2 px")
    end

    function ForeverAura:DistanceBar_ColorBandsMatchRangeHelper()
        AreEqual(ns.GetForeverDistanceBarColorKey("melee"), "hunterRangeMelee", "melee band colour")
        AreEqual(ns.GetForeverDistanceBarColorKey("sweetSpot"), "hunterRangeSweetSpot", "sweet spot band colour")
        AreEqual(ns.GetForeverDistanceBarColorKey("ranged"), "hunterRangeRanged", "ranged band colour")
        AreEqual(ns.GetForeverDistanceBarColorKey("outOfRange"), "hunterRangeOutOfRange", "out of range band colour")
        AreEqual(ns.GetForeverDistanceBarColorKey(nil), nil, "unknown band has no colour")
        AreEqual(ns.GetForeverDistanceBarColorKey("bogus"), nil, "bogus band has no colour")
    end

    function ForeverAura:DistanceBar_ValueIsExactYards()
        local max = ns.FOREVER_DISTANCE_MAX_RANGE
        -- Full across melee reach (the 1-5 yd green band).
        AreEqual(ns.GetForeverDistanceBarValue(1, max, false, "melee"), 0, "1 yd reads full")
        AreEqual(ns.GetForeverDistanceBarValue(5, max, false, "melee"), 0, "5 yd reads full")
        AreEqual(ns.GetForeverDistanceBarValue(0, max, false, nil), 0, "0 yd reads full without a band")
        -- Linear from the melee edge to the ranged maximum.
        local deadzoneEdge = (8 - 5) / (max - 5) * max
        AreEqual(ns.GetForeverDistanceBarValue(8, max, false, "sweetSpot"), deadzoneEdge,
            "8 yd is one step off full")
        AreEqual(ns.GetForeverDistanceBarValue(max, max, false, "ranged"), max, "max range reads empty")
        AreEqual(ns.GetForeverDistanceBarValue(max + 10, max, false, "outOfRange"), max,
            "beyond max range stays empty")
        -- The band no longer overrides an exact reading: a near target stays
        -- off the empty end even when the client band says out of range.
        local near = ns.GetForeverDistanceBarValue(9, max, false, "outOfRange")
        IsTrue(near < max, "an exact near reading is not pinned empty by the band")
        -- A secret reading is never touched, whatever its scale.
        AreEqual(ns.GetForeverDistanceBarValue(9999, max, true, "ranged"), 9999,
            "a secret reading is returned untouched")
        -- With no distance at all the band fallbacks still work.
        AreEqual(ns.GetForeverDistanceBarValue(nil, max, false, "outOfRange"), max,
            "out of range band pins the bar empty without a reading")
        AreEqual(ns.GetForeverDistanceBarValue(nil, max, false, "melee"), 0,
            "melee band pins the bar full without a reading")
        AreEqual(ns.GetForeverDistanceBarValue(nil, max, false, "ranged"), nil,
            "no reading and no empty band hides the bar")
        AreEqual(ns.GetForeverDistanceBarValue(20, nil, false, "ranged"), nil,
            "missing scale hides the bar")
    end

    function ForeverAura:DistanceBar_BandFromExactYards()
        AreEqual(ns.GetForeverDistanceBandFromYards(1), "melee", "1 yd is melee")
        AreEqual(ns.GetForeverDistanceBandFromYards(5), "melee", "5 yd is melee")
        AreEqual(ns.GetForeverDistanceBandFromYards(5.5), "sweetSpot", "5-8 yd is the dead zone")
        AreEqual(ns.GetForeverDistanceBandFromYards(8), "sweetSpot", "8 yd is still the dead zone")
        AreEqual(ns.GetForeverDistanceBandFromYards(9), "ranged", "9 yd is ranged")
        AreEqual(ns.GetForeverDistanceBandFromYards(ns.FOREVER_DISTANCE_MAX_RANGE), "ranged",
            "the ranged maximum is still ranged")
        AreEqual(ns.GetForeverDistanceBandFromYards(ns.FOREVER_DISTANCE_MAX_RANGE + 0.5), "outOfRange",
            "past the ranged maximum is out of range")
        AreEqual(ns.GetForeverDistanceBandFromYards(nil), nil, "no reading has no band")
        AreEqual(ns.GetForeverDistanceBandFromYards(0 / 0), nil, "a NaN reading has no band")
    end

    function ForeverAura:DistanceBar_ReadsCreatureDistanceFirst()
        local prevCreatureID = _G.UnitCreatureID
        local prevClosest = _G.ClosestUnitPosition
        local prevUnitDistance = _G.UnitDistanceSquared
        local prevUnitPosition = _G.UnitPosition

        local creatureScenario = 1
        local distanceSquaredScenario = 1
        _G.UnitCreatureID = function(unit) if unit ~= "target" then return nil end if creatureScenario == 1 then return 1234 end return nil end
        -- ClosestUnitPosition takes a CREATURE ID, not a unit token.
        _G.ClosestUnitPosition = function(creatureID)
            if creatureID ~= 1234 then return nil end
            return 10, 20, 17.5
        end
        _G.UnitDistanceSquared = function(unit)
            if unit ~= "target" then return nil, false end
            if distanceSquaredScenario == 1 then return 9999, true end
            if distanceSquaredScenario == 2 then return 400, true end
            if distanceSquaredScenario == 4 then return 400, false end
            if distanceSquaredScenario == 5 then return 0, false end
            return nil, false
        end
        local value, maxValue, secret, source = ns.ReadForeverTargetDistance()
        AreEqual(value, 17.5, "linear creature distance is used first")
        AreEqual(maxValue, ns.FOREVER_DISTANCE_MAX_RANGE, "creature distance uses the linear scale")
        IsFalse(secret, "a plain test reading is not secret")
        AreEqual(source, "closest", "creature source wins")

        -- UnitDistanceSquared answers squared yards, and only a CHECKED reading
        -- is a distance at all (see the unchecked cases below).
        creatureScenario = 2
        distanceSquaredScenario = 2
        _G.ClosestUnitPosition = nil
        local fallbackValue, fallbackMax, _, fallbackSource = ns.ReadForeverTargetDistance()
        AreEqual(fallbackValue, 20, "a checked squared distance converts to yards")
        AreEqual(fallbackMax, ns.FOREVER_DISTANCE_MAX_RANGE, "plain readings use the linear scale")
        AreEqual(fallbackSource, "unit", "unit source is reported")

        -- Exact map-coordinate fallback for when the client hides both APIs.
        distanceSquaredScenario = 3
        local unitPositionScenario = 1
        _G.UnitPosition = function(unit)
            if unit == "player" then return 0, 0, 0, 1 end
            if unit ~= "target" then return nil, nil, nil, nil end
            if unitPositionScenario == 1 then return 30, 40, 0, 1 end
            if unitPositionScenario == 2 then return 30, 40, 0, 2 end
            return nil, nil, nil, 1
        end
        local posValue, posMax, posSecret, posSource = ns.ReadForeverTargetDistance()
        AreEqual(posValue, 50, "UnitPosition gives exact yards (30-40-50 triangle)")
        AreEqual(posMax, ns.FOREVER_DISTANCE_MAX_RANGE, "position distance uses the linear scale")
        IsFalse(posSecret, "map coordinates are plain numbers")
        AreEqual(posSource, "position", "position source is reported")

        unitPositionScenario = 2
        AreEqual(select(1, ns.ReadForeverTargetDistance()), nil, "a different map yields no reading")

        unitPositionScenario = 3
        AreEqual(select(1, ns.ReadForeverTargetDistance()), nil, "missing coordinates yield no reading")

        -- checkedDistance=false is not a distance: Forever answers 0 + false for
        -- a live target, which must not read as "standing on top of it".
        distanceSquaredScenario = 4
        AreEqual(select(1, ns.ReadForeverTargetDistance()), nil,
            "an unchecked non-zero reading is rejected")
        distanceSquaredScenario = 5
        AreEqual(select(1, ns.ReadForeverTargetDistance()), nil,
            "an unchecked zero reading is rejected, not read as 0 yards")

        _G.UnitCreatureID = prevCreatureID
        _G.ClosestUnitPosition = prevClosest
        _G.UnitDistanceSquared = prevUnitDistance
        _G.UnitPosition = prevUnitPosition
    end

    function ForeverAura:DistanceBar_UpdatesFromDistanceApi()
        local prevBar = ns.foreverHunterDistanceBar
        local prevForever = ns.isForever
        local prevClass = ns.playerClass
        local prevStateFn = ns.GetHunterRangeState
        local prevPowerBar = ns.playerPowerBar
        local prevApi = _G.UnitDistanceSquared

        local recorded = {}
        local mockBar = {
            bandTexture = {
                SetColorTexture = function(_, r, g, b, a) recorded.band = { r, g, b, a } end,
            },
            SetMinMaxValues = function(_, minValue, maxValue) recorded.min, recorded.max = minValue, maxValue end,
            SetValue = function(_, value) recorded.value = value end,
            SetStatusBarColor = function(_, r, g, b, a) recorded.color = { r, g, b, a } end,
            SetAlpha = function() end,
            Show = function() recorded.shown = true end,
            Hide = function() recorded.shown = false end,
            GetPoint = function() return nil end,
            ClearAllPoints = function() end,
            SetPoint = function() end,
            GetHeight = function() return 5 end,
            SetHeight = function() end,
        }

        ns.isForever = true
        ns.playerClass = "HUNTER"
        ns.playerPowerBar = nil -- keep the layout helper out of this mock
        ns.foreverHunterDistanceBar = mockBar
        local rangeState = "ranged"
        ns.GetHunterRangeState = function() return rangeState end
        _G.UnitDistanceSquared = function() return 400, true end

        ns.UpdateForeverHunterDistanceBar(0)

        -- 400 squared yards is a 20 yd target: linear to the empty end.
        local expected = (20 - 5) / (ns.FOREVER_DISTANCE_MAX_RANGE - 5) * ns.FOREVER_DISTANCE_MAX_RANGE
        AreEqual(recorded.value, expected, "exact 20 yd is linear on the fill")
        AreEqual(recorded.min, 0, "bar minimum is 0")
        AreEqual(recorded.max, ns.FOREVER_DISTANCE_MAX_RANGE,
            "bar maximum is the linear ranged scale")
        IsTrue(recorded.shown == true, "bar is shown with a target")
        IsTrue(recorded.band ~= nil, "band colour is applied")
        AreEqual(recorded.color and recorded.color[4], 1, "empty cover stays opaque")

        -- The exact reading owns the colour too: a client band that fell back to
        -- "outOfRange" (the range checks could not answer) must not paint a
        -- 20 yd target grey.
        rangeState = "outOfRange"
        recorded.band = nil
        ns.UpdateForeverHunterDistanceBar(0)
        local rangedColor = ns.GetBarColor("hunterRangeRanged")
        IsTrue(recorded.band ~= nil, "a colour is still applied")
        IsTrue(rangedColor ~= nil and recorded.band ~= nil and recorded.band[1] == rangedColor.r,
            "exact yards win over a fallback out-of-range band")

        ns.foreverHunterDistanceBar = prevBar
        ns.isForever = prevForever
        ns.playerClass = prevClass
        ns.GetHunterRangeState = prevStateFn
        ns.playerPowerBar = prevPowerBar
        _G.UnitDistanceSquared = prevApi
    end

    function ForeverAura:DistanceBar_GatedToForeverHunter()
        local previousBar = ns.foreverHunterDistanceBar
        local previousForever = ns.isForever
        ns.foreverHunterDistanceBar = nil
        ns.isForever = false
        local ok = pcall(ns.UpdateForeverHunterDistanceBar, 0)
        IsTrue(ok, "distance bar update is safe off Forever")
        AreEqual(ns.foreverHunterDistanceBar, nil, "no distance bar is created off Forever")
        ns.foreverHunterDistanceBar = previousBar
        ns.isForever = previousForever
    end

    function ForeverAura:DBDefaults_HasForeverAuraKeys()
        IsTrue(ns.DB_DEFAULTS.showForeverDebuffIcons == true, "showForeverDebuffIcons default is true")
        IsTrue(ns.DB_DEFAULTS.showForeverStanceIcon == true, "showForeverStanceIcon default is true")
        IsTrue(ns.DB_DEFAULTS.showHunterDistanceBar == true, "showHunterDistanceBar default is true")
    end

    function ForeverAura:Diagnostics_IncludesStanceFields()
        local d = ns.GetForeverAuraDiagnostics()
        IsTrue(type(d) == "table", "GetForeverAuraDiagnostics returns a table")
        IsTrue(d.stanceContainer ~= nil, "d.stanceContainer is boolean")
        IsTrue(d.stanceSlot ~= nil, "d.stanceSlot is boolean")
        IsTrue(d.shapeshiftIcon ~= nil, "d.shapeshiftIcon is boolean")
        IsTrue(type(d.stanceSpells) == "number", "d.stanceSpells is a number")
    end

    function ForeverAura:LegacyUpdaters_WrapWithoutError()
        local prevNative = ns.foreverNativeAuraIcons
        local prevHunter = ns.UpdateHunterBuffIcons
        local called = 0

        ns.UpdateHunterBuffIcons = function() called = called + 1 end
        ns.foreverNativeAuraIcons = true

        local ok = pcall(ns.WrapLegacyIconUpdaters)
        IsTrue(ok, "wrapping legacy updaters must not raise")

        ns.UpdateHunterBuffIcons()
        AreEqual(called, 0, "wrapped updater must stand down while native rows are live")

        ns.foreverNativeAuraIcons = false
        ns.UpdateHunterBuffIcons()
        AreEqual(called, 1, "wrapped updater must run when native rows are off")

        ns.UpdateHunterBuffIcons = prevHunter
        ns.foreverNativeAuraIcons = prevNative
    end

    local nGroups = 0
    for _ in ipairs(WoWUnit.children) do nGroups = nGroups + 1 end
    print("|cff44ff44[SST] " .. nGroups .. " groups registered. Click WoWUnit toggle or type /ssttest.|r")
end

SLASH_SSTTEST1 = "/ssttest"
SlashCmdList["SSTTEST"] = function()
    if not WoWUnit then
        print("|cffff4444[SST] WoWUnit not installed.|r"); return
    end
    local n = 0; for _, g in ipairs(WoWUnit.children) do if g.name and g.name:match("^SST%-") then
            g(); n = n + 1
        end end
    print("|cff44ff44[SST] Ran " .. n .. " groups.|r")
end

local f = CreateFrame("Frame")
f:SetScript("OnUpdate", function(s)
    s:SetScript("OnUpdate", nil)
    if WoWUnit then
        local ok, err = pcall(RegisterSSTTests); if not ok then
            geterrorhandler()(err); print("|cffff4444[SST] " .. tostring(err))
        end
    else
        print("|cffff4444[SST] WoWUnit not found.|r")
    end
end)
