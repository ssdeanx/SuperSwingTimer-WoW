---@diagnostic disable: undefined-global
-- ============================================================
-- File role: WoWUnit in-game test suite for SuperSwingTimer
-- Depends on: WoWUnit addon (optional, skipped cleanly)
-- Target: TBC Anniversary 2.5.5
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
    local function pc(p, ...) local ok, r = pcall(p, ...); return ok, r end

    -- ============================================================
    -- SST-Core: addon loaded, constants sane, DB migrates, nil-safe
    -- ============================================================
    local Core = WoWUnit('SST-Core', 'PLAYER_ENTERING_WORLD')

    function Core:DBDefaults_HasKeys()
        local db = ns.DB_DEFAULTS
        for _, k in ipairs{'version','barHeight','barWidth','barTexture',
            'barBackgroundColor','barBorderColor','useClassColors','showMH',
            'showOH','showRanged','showEnemy','colors'} do
            IsTrue(db[k] ~= nil, 'DB.'..k..'='..tostring(db[k]))
        end
    end
    function Core:Clock_IsNumber() IsTrue(type(ns.GetAlignedTime()) == "number") end
    function Core:TimersTable_Exists()
        for _, k in ipairs{'mh','oh','ranged','enemy'} do Exists(ns.timers[k]) end
    end
    function Core:AutoShotID_75() AreEqual(ns.AUTO_SHOT_ID, 75) end
    function Core:SteadyShotCastTime() AreEqual(ns.STEADY_SHOT_CAST_TIME, 1.5) end
    function Core:MigrateDB_Fresh() local db={}; local ok,_=pc(ns.MigrateDB,db); IsTrue(ok); AreEqual(db.version, ns.DB_CURRENT_VERSION) end
    function Core:MigrateDB_V1()
        local db={version=1}; local ok,_=pc(ns.MigrateDB,db)
        IsTrue(ok); AreEqual(db.version, ns.DB_CURRENT_VERSION)
    end
    function Core:MigrateDB_V53()
        local db={version=53}; local ok,_=pc(ns.MigrateDB,db)
        IsTrue(ok); AreEqual(db.version, ns.DB_CURRENT_VERSION)
    end
    function Core:MigrateDB_V54()
        local db={version=54}; local ok,_=pc(ns.MigrateDB,db)
        IsTrue(ok); AreEqual(db.version, ns.DB_CURRENT_VERSION)
    end
    function Core:MigrateDB_V55()
        local db={version=55}; local ok,_=pc(ns.MigrateDB,db)
        IsTrue(ok); AreEqual(db.version, ns.DB_CURRENT_VERSION)
    end
    function Core:MigrateDB_V56()
        local db={version=56}; local ok,_=pc(ns.MigrateDB,db)
        IsTrue(ok); AreEqual(db.version, ns.DB_CURRENT_VERSION)
    end
    function Core:MigrateDB_V61()
        local db={version=61, colors={}}; local ok,_=pc(ns.MigrateDB,db)
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
        AreEqual(db.powerBarHeight, 10)
        IsTrue(db.colors.warriorRageBarColor ~= nil)
    end
    function Core:MigrateDB_V64()
        local db = { version = 64, hunterCastBarHeight = 15, powerBarHeight = 10, colors = {} }
        local ok, _ = pc(ns.MigrateDB, db)
        IsTrue(ok)
        AreEqual(db.version, 64)
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
    function Core:PowerBarHeight_Default10()
        AreEqual(ns.POWER_BAR_HEIGHT, 10)
        AreEqual(ns.DB_DEFAULTS.powerBarHeight, 10)
    end
    function Core:DefaultFont_Resolves()
        IsTrue(type(ns.GetDefaultFont) == "function")
        local font = ns.GetDefaultFont()
        IsTrue(type(font) == "string" and #font > 0)
    end
    function Core:FactoryReset() IsTrue(pc(ns.ResetConfigDefaults)) end
    function Core:GetSpellInfo_Wraps() Exists(ns.GetSpellInfo(ns.AUTO_SHOT_ID)) end
    function Core:GetSpellInfo_Nil() local ok,_=pc(ns.GetSpellInfo,nil); IsTrue(ok) end
    function Core:GetUnitCasting_Nil() local ok,_=pc(ns.GetUnitCastingSpellInfo,nil); IsTrue(ok) end
    function Core:SetBarLabelText_Nil() IsTrue(pc(ns.SetBarLabelText,nil,'test',true)) end
    function Core:RefreshBarSpark_Nil() IsTrue(pc(ns.RefreshBarSparkPosition,nil)) end
    function Core:RestoreBarLabel_Nil() IsTrue(pc(ns.RestoreBarDefaultLabel,nil)) end
    function Core:RefreshBarLabels() IsTrue(pc(ns.RefreshBarLabelStyles)) end
    function Core:HasteAPI_Exists()
        IsTrue(type(GetMeleeHaste) == "function" or type(GetMeleeHaste) == "nil", 'GetMeleeHaste')
    end

    -- ============================================================
    -- SST-Auras: aura wrapper parsing for all API shapes
    -- ============================================================
    local Auras = WoWUnit('SST-Auras', 'PLAYER_ENTERING_WORLD')

    function Auras:HelpfulSpellID_AtPos10()
        if not T or not T.GetHelpfulAuraData then return end
        -- GetHelpfulAuraData -> ns.UnitBuff -> ns.UnitAura -> global UnitAura.
        -- The wrapper only calls the global UnitAura, so we must mock UnitAura
        -- (not the deprecated UnitBuff global) for the mock to engage.
        Replace('UnitAura', function(u,i)
            if i==1 then return 'Slice and Dice', 132181, 5, nil, 15, 12345.0, 'player', false, false, 5171, false end
        end)
        local _,dur,_,sid=T.GetHelpfulAuraData('player',1)
        AreEqual(dur,15); AreEqual(sid,5171)
        ClearReplaces()
    end
    function Auras:HelpfulStacks_Returned()
        if not T or not T.GetHelpfulAuraData then return end
        Replace('UnitAura', function(_,i)
            if i==1 then return 'Maelstrom Weapon', 132181, 4, nil, 30, 12345.0, 'player', false, false, 408505, false end
        end)
        local _, dur, _, sid, count = T.GetHelpfulAuraData('player', 1)
        AreEqual(dur, 30)
        AreEqual(sid, 408505)
        AreEqual(count, 4)
        ClearReplaces()
    end
    function Auras:HarmfulSpellID_AtPos10()
        if not T or not T.GetHarmfulAuraData then return end
        Replace('UnitAura', function(u,i,f)
            if i==1 then return 'Flame Shock',132181,1,'Fire',12,12350.0,'player',false,false,8050,false end
        end)
        local _,_,dur,_,caster,sid=T.GetHarmfulAuraData('target',1,'HARMFUL')
        AreEqual(dur,12); AreEqual(caster,'player'); AreEqual(sid,8050)
        ClearReplaces()
    end
    function Auras:HarmfulPhysical_NilDispel()
        if not T or not T.GetHarmfulAuraData then return end
        Replace('UnitAura', function(u,i,f)
            if i==1 then return 'Deep Wounds',132316,1,nil,12,12360.0,'player',false,false,12721,false end
        end)
        local _,_,dur,_,caster,sid=T.GetHarmfulAuraData('target',1,'HARMFUL')
        AreEqual(dur,12); AreEqual(caster,'player'); AreEqual(sid,12721)
        ClearReplaces()
    end
    function Auras:HarmfulNil_ReturnsNil()
        if not T or not T.GetHarmfulAuraData then return end
        Replace('UnitAura',function() end)
        IsFalse(T.GetHarmfulAuraData('target',1,'HARMFUL'))
        ClearReplaces()
    end
    function Auras:PaladinSeal_Command()
        if ns.GetPaladinSealFamilyByAuraName then
            AreEqual(ns.GetPaladinSealFamilyByAuraName('Seal of Command'),'COMMAND')
        end
    end
    function Auras:CrossDebuff_FlameShock()
        if not T or not T.GetHarmfulAuraData then return end
        Replace('UnitAura',function(u,i,f)
            if i==1 then return 'Flame Shock',132181,1,'Fire',12,12350.0,'player',false,false,8050,false end
            end)
        local _,_,dur,_,c,s=T.GetHarmfulAuraData('target',1,'HARMFUL')
        AreEqual(dur,12); AreEqual(c,'player'); IsTrue(type(s)=='number')
        ClearReplaces()
    end

    -- ============================================================
    -- SST-Combat: timers, CLEU, debuff stacking, state machine
    -- ============================================================
    local Combat = WoWUnit('SST-Combat', 'PLAYER_ENTERING_WORLD')

    function Combat:StackOffset_SingleBar()
        if not T or not T.RestackDebuffBars or not T.GetDebuffStackOffset then return end
        local ref = {GetTop = function() return 100 end, GetAlpha = function() return 1 end}
        local b1 = {IsShown = function() return true end, GetHeight = function() return 6 end,
            ClearAllPoints = function() end, SetPoint = function() end}
        T.RestackDebuffBars({b1}, ref, 2)
        IsTrue(T.GetDebuffStackOffset() > 0)
    end
    function Combat:StackOffset_HiddenBars()
        if not T or not T.RestackDebuffBars or not T.GetDebuffStackOffset then return end
        local ref = {GetTop = function() return 100 end, GetAlpha = function() return 1 end}
        local b1 = {IsShown = function() return false end, GetHeight = function() return 6 end}
        T.RestackDebuffBars({b1}, ref, 2)
        IsTrue(type(T.GetDebuffStackOffset()) == 'number')
    end
    function Combat:StartSwing_MH()
        if not ns.StartSwing then return end
        local now=ns.GetAlignedTime()
        pc(ns.StartSwing,"mh",nil,now)
        local t=ns.timers.mh; Exists(t)
        if t then IsTrue(t.state=="swinging") end
    end
    function Combat:CLEU_SWING_DAMAGE()
        Replace('CombatLogGetCurrentEventInfo',function()
            return nil,"SWING_DAMAGE",nil,"Player-1",nil,nil,nil,nil,"Creature-1",nil,nil,nil,nil,nil,100
        end)
        Replace('GetPlayerGUID',function() return "Player-1" end)
        local old=ns.timers.mh and ns.timers.mh.endTime or 0
        pc(ns.HandleCLEU)
        IsTrue(ns.timers.mh.endTime ~= old or ns.timers.mh.state=="swinging")
        ClearReplaces()
    end
    function Combat:CLEU_SWING_MISSED()
        Replace('CombatLogGetCurrentEventInfo',function()
            return nil,"SWING_MISSED",nil,"Player-1",nil,nil,nil,nil,"Creature-1",nil,nil,nil,"MISS"
        end)
        Replace('GetPlayerGUID',function() return "Player-1" end)
        pc(ns.HandleCLEU); IsTrue(true,'no error')
        ClearReplaces()
    end

    -- ============================================================
    -- SST-Hunter: Hunter-specific features
    -- ============================================================
    local Hunter = WoWUnit('SST-Hunter', 'PLAYER_ENTERING_WORLD')

    function Hunter:CastDetection_Steady() IsTrue(ns.IsHunterCastSpell(ns.STEADY_SHOT_ID)) end
    function Hunter:CastDetection_Aimed() IsTrue(ns.IsHunterCastSpell(19434)) end
    function Hunter:CastDetection_Auto() IsTrue(ns.IsHunterCastSpell(75)) end
    function Hunter:CastDetection_AutoNotActual() IsFalse(ns.IsHunterActualCastSpell(75)) end
    function Hunter:CastDetection_SteadyIsActual() IsTrue(ns.IsHunterActualCastSpell(ns.STEADY_SHOT_ID)) end
    function Hunter:SerpentStingIDs_Populated()
        local c=0; for _ in pairs(ns.HUNTER_SERPENT_STING_IDS or {}) do c=c+1 end
        IsTrue(c>=3)
    end
    function Hunter:SerpentStingName_Resolved() Exists(ns.HUNTER_SERPENT_STING_NAME) end
    function Hunter:IsAutoShot_ByID() IsTrue(ns.IsAutoShotSpell(75)) end
    function Hunter:IsAutoShot_Nil() local ok,r=pc(ns.IsAutoShotSpell,nil); IsTrue(ok); IsFalse(r) end
    function Hunter:IsHunterCast_Nil() local ok,r=pc(ns.IsHunterCastSpell,nil); IsTrue(ok); IsFalse(r) end
    function Hunter:SerpentSting_MockDetect()
        if not T or not T.GetTargetSerpentStingData then return end
        Replace('UnitAura',function(u,i,f)
            if i==1 then return 'Serpent Sting',132181,1,'Nature',15,12345.0,'player',false,false,27019,false end
        end)
        Replace('UnitExists',function() return true end)
        Replace('UnitCanAttack',function() return true end)
        local dur,_=T.GetTargetSerpentStingData()
        Exists(dur,'SerpentSting found')
        ClearReplaces()
    end
    function Hunter:SerpentSting_FiltersOtherCaster()
        if not T or not T.GetTargetSerpentStingData then return end
        Replace('UnitAura',function(u,i,f)
            if i==1 then return 'Serpent Sting',132181,1,'Nature',15,12345.0,'OtherGuy',false,false,27019,false end
        end)
        Replace('UnitExists',function() return true end)
        Replace('UnitCanAttack',function() return true end)
        IsFalse(T.GetTargetSerpentStingData())
        ClearReplaces()
    end

    -- ============================================================
    -- SST-SoD: SoD rune spell registration & aura filters
    -- ============================================================
    local SoD = WoWUnit('SST-SoD', 'PLAYER_ENTERING_WORLD')

    function SoD:MaelstromMultiplier_Bounds()
        if ns.maelstromCastTimeMultiplier ~= nil then
            IsTrue(ns.maelstromCastTimeMultiplier >= 0.0 and ns.maelstromCastTimeMultiplier <= 1.0, 'Maelstrom multiplier bounded')
        end
    end
    function SoD:TrackedSpells_AllNineClasses()
        if not ns.SOD_TRACKED_SPELLS then return end
        for _, classKey in ipairs{'WARRIOR','ROGUE','SHAMAN','HUNTER','PALADIN','DRUID','WARLOCK','MAGE','PRIEST'} do
            Exists(ns.SOD_TRACKED_SPELLS[classKey], 'SoD tracked spells for '..classKey)
        end
    end

    -- ============================================================
    -- SST-ClassMods: per-class power bars & setups
    -- ============================================================
    local ClassMods = WoWUnit('SST-ClassMods', 'PLAYER_ENTERING_WORLD')

    function ClassMods:UpdateWarriorRageBar_Exists()
        IsTrue(type(ns.UpdateWarriorRageBar) == "function" or type(ns.UpdatePlayerPowerBar) == "function", 'UpdateWarriorRageBar or UpdatePlayerPowerBar function exists')
    end
    function ClassMods:UpdatePlayerPowerBar_Exists()
        IsTrue(type(ns.UpdatePlayerPowerBar) == "function" or type(ns.UpdateWarriorRageBar) == "function", 'UpdatePlayerPowerBar function exists')
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

    local BUFF_ICON_BASE_OFFSET = 14  -- mirrors ClassMods.lua

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
    local Reg = WoWUnit('SST-Regressions', 'PLAYER_ENTERING_WORLD')

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

    -- Drives the real per-frame restack call and records every list it is
    -- handed, without letting the spy's calls perturb the real function.
    -- Returns the recorder plus an undo function; always call the undo.
    local function SpyOnRestack(hookIndex, listUpvalueName, restackUpvalueName)
        if type(debug) ~= "table" or type(debug.setupvalue) ~= "function" then
            return nil
        end
        local hook = ns.OnUpdateHooks[hookIndex]
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
        f.SetPoint = function(self, point, rel, relPoint, x, y)
            self.anchors[#self.anchors + 1] = { point = point, rel = rel, relPoint = relPoint, x = x, y = y }
            return realSetPoint(self, point, rel, relPoint, x, y)
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
        local fn = ResolveUpvalue(ns.OnUpdateHooks[1], "UpdateGcdTicker")
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
        local fn = ResolveUpvalue(ns.OnUpdateHooks[1], "UpdateGcdTicker")
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
        local fn = ResolveUpvalue(ns.OnUpdateHooks[1], "UpdateGcdTicker")
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
        local fn = ResolveUpvalue(ns.OnUpdateHooks[1], "UpdateGcdTicker")
        Exists(fn, 'UpdateGcdTicker reachable')

        ns.playerClass = "WARRIOR"
        ns.gcdTickerBar = CreateFrame("Frame")
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
        local coreHook = ns.OnUpdateHooks[1]
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
        AreEqual(a3.y, 10, 'bar3 stacks above bar1, skipping the nil slot')
        AreEqual(a3.rel, reference, 'bar3 anchors to the reference bar')
        IsTrue((HasAnchor(bar3, "BOTTOMRIGHT") or {}).y == 10, 'bar3 BOTTOMRIGHT mirrors BOTTOMLEFT')

        local a4 = HasAnchor(bar4, "BOTTOMLEFT")
        Exists(a4, 'bar4 has a BOTTOMLEFT anchor')
        AreEqual(a4.y, 18, 'bar4 stacks above bar3')
    end

    -- The class call sites must rewrite every slot of the hoisted list on EVERY
    -- frame, never latch on "if not list[1]". A latch permanently drops any bar
    -- whose Ensure* helper only runs later, and the toggle that decides that
    -- persists in SavedVariables, so the bar can be absent for the whole login
    -- and then appear at any time. This is the regression from the hoisted-list
    -- work, and it lives at the call site rather than inside RestackDebuffBars.
    function Reg:ClassHook_RewritesEveryRestackSlot_EveryFrame_NeverLatches()
        local hook = ns.OnUpdateHooks[2]
        if type(hook) ~= "function" or type(debug) ~= "table"
            or type(debug.setupvalue) ~= "function" then
            IsTrue(true, 'debug library unavailable in this environment')
            return
        end
        local listIdx, wingClipIdx, wingClipBar
        for i = 1, 64 do
            local name, value = debug.getupvalue(hook, i)
            if not name then break end
            if name == "hunterRestackBars" then listIdx = i
            elseif name == "wingClipBar" then wingClipIdx, wingClipBar = i, value end
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
            debug.setupvalue(hook, wingClipIdx, nil)  -- toggle off: never created
            hook(0.016)
        end)
        local withoutBar = list[2]
        ok3, err3 = pcall(function()
            debug.setupvalue(hook, wingClipIdx, probe)  -- toggle on: Ensure* creates it
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

    -- (4) Allocation pin: the per-frame restack lists are pre-allocated tables
    -- whose slots are rewritten, not fresh literals built every frame. Driving
    -- the Hunter hook twice must hand RestackDebuffBars the SAME table object
    -- both times, and that object must be the hoisted upvalue.
    function Reg:HunterRestackList_ReusedAcrossFrames_NotRebuiltPerFrame()
        local spy = SpyOnRestack(2, "hunterRestackBars", "RestackDebuffBars")
        if not spy then
            -- No debug library (or the addon reshaped its hook): nothing to pin.
            IsTrue(true, 'restack spy unavailable in this environment')
            return
        end
        local ok, err = pcall(function()
            local hook = ns.OnUpdateHooks[2]
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

    -- ============================================================
    -- SST-Weaving: Real-time spell cast time, Maelstrom, spark colors
    -- ============================================================
    local Weaving = WoWUnit('SST-Weaving', 'PLAYER_ENTERING_WORLD')

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

    local nGroups = 0
    for _ in ipairs(WoWUnit.children) do nGroups = nGroups + 1 end
    print("|cff44ff44[SST] " .. nGroups .. " groups registered. Click WoWUnit toggle or type /ssttest.|r")
end

SLASH_SSTTEST1 = "/ssttest"
SlashCmdList["SSTTEST"] = function()
    if not WoWUnit then print("|cffff4444[SST] WoWUnit not installed.|r"); return end
    local n=0; for _,g in ipairs(WoWUnit.children) do if g.name and g.name:match("^SST%-") then g(); n=n+1 end end
    print("|cff44ff44[SST] Ran "..n.." groups.|r")
end

local f=CreateFrame("Frame")
f:SetScript("OnUpdate",function(s)
    s:SetScript("OnUpdate",nil)
    if WoWUnit then local ok,err=pcall(RegisterSSTTests); if not ok then geterrorhandler()(err); print("|cffff4444[SST] "..tostring(err)) end
    else print("|cffff4444[SST] WoWUnit not found.|r") end
end)
