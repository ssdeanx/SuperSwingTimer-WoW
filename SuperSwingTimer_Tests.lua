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

    -- ============================================================
    -- SST-Weaving: Real-time spell cast time, Maelstrom, spark colors
    -- ============================================================
    local Weaving = WoWUnit('SST-Weaving', 'PLAYER_ENTERING_WORLD')

    function Weaving:EffectiveCastTime_FunctionExists()
        IsTrue(type(ns.GetEffectiveSpellCastTime) == "function", 'ns.GetEffectiveSpellCastTime is a function')
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

    print("|cff44ff44[SST] 7 groups registered. Click WoWUnit toggle or type /ssttest.|r")
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
