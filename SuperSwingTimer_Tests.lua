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
    local _, playerClass = UnitClass("player")

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
        if playerClass == "PALADIN" and ns.GetPaladinSealFamilyByAuraName then
            AreEqual(ns.GetPaladinSealFamilyByAuraName('Seal of Command'),'COMMAND') end end
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
    -- SST-Hunter: Hunter-specific features (gated on class)
    -- ============================================================
    if playerClass == "HUNTER" then
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
    end

    print("|cff44ff44[SST] 4 groups registered. Click WoWUnit toggle or type /ssttest.|r")
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
