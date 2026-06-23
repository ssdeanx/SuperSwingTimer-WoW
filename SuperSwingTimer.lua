local addonName, ns = ...
local CreateFrame = rawget(_G, "CreateFrame")
local UIParent = rawget(_G, "UIParent")
local SlashCmdList = rawget(_G, "SlashCmdList")
local UnitClass = rawget(_G, "UnitClass")
local strtrim = rawget(_G, "strtrim")
local GetShapeshiftForm = rawget(_G, "GetShapeshiftForm")
local GetTimePreciseSec = rawget(_G, "GetTimePreciseSec")
local GetTime = rawget(_G, "GetTime")
local InCombatLockdown = rawget(_G, "InCombatLockdown")

local function GetCurrentTime()
    if ns.GetAlignedTime then
        return ns.GetAlignedTime()
    end
    if GetTimePreciseSec then
        return GetTimePreciseSec()
    end
    return GetTime()
end

local LATENCY_REFRESH_INTERVAL = 0.05
local nextLatencyRefreshAt = 0

-- ============================================================
-- Bootstrap: event frame, SavedVariables init, dispatch
-- ============================================================
-- This file wires everything together. Logic lives in:
--   SuperSwingTimer_Constants.lua  - spell IDs, class config, defaults
--   SuperSwingTimer_State.lua      - detection engine, timer state
--   SuperSwingTimer_Weaving.lua    - shaman breakpoint / cast helper
--   SuperSwingTimer_UI.lua         - bars, visuals, drag, show/hide
--   SuperSwingTimer_ClassMods.lua  - class-specific overlays

-- ============================================================
-- Runtime globals
-- ============================================================
ns.isMoving = false
ns.lastStoppedMovingAt = nil
ns.barTestActive = false
ns.barTestTimer = nil
ns.playerClass = nil
ns.classConfig = nil
ns.druidFormChangeTime = nil
ns.playerInCombat = false
ns.hunterAutoRepeatActive = false

-- ============================================================
-- SavedVariables migration
-- ============================================================
local function MigrateDB()
    local legacyAddonDB = rawget(_G, "SwangThangDB")
    local legacyHunterDB = rawget(_G, "HunterTimerDB")

    -- v2: SuperSwingTimerDB with nested positions
    -- Migrate from v1: HunterTimerDB = {point, relativePoint, x, y}
    if not SuperSwingTimerDB then
        if legacyAddonDB then
            SuperSwingTimerDB = legacyAddonDB
            SwangThangDB = nil
        elseif legacyHunterDB then
            SuperSwingTimerDB = {
                version = 2,
                showMH = true,
                showOH = true,
                positions = {
                    mh = ns.DB_DEFAULTS.positions.mh,
                    oh = ns.DB_DEFAULTS.positions.oh,
                    ranged = {
                        point = legacyHunterDB.point or "CENTER",
                        relativePoint = legacyHunterDB.relativePoint or "CENTER",
                        x = legacyHunterDB.x or 0,
                        y = legacyHunterDB.y or -100
                    }
                }
            }
            HunterTimerDB = nil -- clear legacy SavedVariable
        end
    end

    -- Fresh install
    if not SuperSwingTimerDB then
        SuperSwingTimerDB = {
            version = ns.DB_DEFAULTS.version or 54,
            showMH = ns.DB_DEFAULTS.showMH,
            showOH = ns.DB_DEFAULTS.showOH,
            showRanged = ns.DB_DEFAULTS.showRanged,
            showHunterRangeHelper = ns.DB_DEFAULTS.showHunterRangeHelper,
            showEnemy = ns.DB_DEFAULTS.showEnemy,
            showRogueSinisterAssist = ns.DB_DEFAULTS.showRogueSinisterAssist,
            showRogueEnergyTick = ns.DB_DEFAULTS.showRogueEnergyTick,
            showRogueComboPoints = ns.DB_DEFAULTS.showRogueComboPoints,
            showRogueSliceAndDice = ns.DB_DEFAULTS.showRogueSliceAndDice,
            showWeaveAssist = ns.DB_DEFAULTS.showWeaveAssist,
            showPaladinSealColor = ns.DB_DEFAULTS.showPaladinSealColor,
            showPaladinSealLabel = ns.DB_DEFAULTS.showPaladinSealLabel,
            showPaladinJudgementMarker = ns.DB_DEFAULTS.showPaladinJudgementMarker,
            showPaladinTwistFlash = ns.DB_DEFAULTS.showPaladinTwistFlash,
            showWarriorRageBar = ns.DB_DEFAULTS.showWarriorRageBar,
            showWarriorRageProtection = ns.DB_DEFAULTS.showWarriorRageProtection,
            showDruidEnergyTickBar = ns.DB_DEFAULTS.showDruidEnergyTickBar,
            useClassColors = ns.DB_DEFAULTS.useClassColors,
            indicatorBlendMode = ns.DB_DEFAULTS.indicatorBlendMode,
            weaveSpellFamilies = {
                LB = ns.DB_DEFAULTS.weaveSpellFamilies.LB,
                CL = ns.DB_DEFAULTS.weaveSpellFamilies.CL,
                HW = ns.DB_DEFAULTS.weaveSpellFamilies.HW,
                LHW = ns.DB_DEFAULTS.weaveSpellFamilies.LHW,
                CH = ns.DB_DEFAULTS.weaveSpellFamilies.CH
            },
            barWidth = ns.DB_DEFAULTS.barWidth,
            barHeight = ns.DB_DEFAULTS.barHeight,
            hunterCastBarHeight = ns.DB_DEFAULTS.hunterCastBarHeight,
            rogueSliceAndDiceBarHeight = ns.DB_DEFAULTS.rogueSliceAndDiceBarHeight,
            rogueEnergyTickBarWidth = ns.DB_DEFAULTS.rogueEnergyTickBarWidth,
            warriorShieldBlockBarHeight = ns.DB_DEFAULTS.warriorShieldBlockBarHeight,
            hunterRangeHelperWidth = ns.DB_DEFAULTS.hunterRangeHelperWidth,
            hunterRapidFireBarHeight = ns.DB_DEFAULTS.hunterRapidFireBarHeight,
            druidEnergyTickBarWidth = ns.DB_DEFAULTS.druidEnergyTickBarWidth,
            rogueAdrenalineRushBarHeight = ns.DB_DEFAULTS.rogueAdrenalineRushBarHeight,
            shamanLightningTrackerGap = ns.DB_DEFAULTS.shamanLightningTrackerGap,
            barTexture = ns.DB_DEFAULTS.barTexture,
            barTextureLayer = ns.DB_DEFAULTS.barTextureLayer,
            rangedBarTexture = ns.DB_DEFAULTS.rangedBarTexture,
            sparkTexture = ns.DB_DEFAULTS.sparkTexture,
            sparkTextureLayer = ns.DB_DEFAULTS.sparkTextureLayer,
            weaveSparkTexture = ns.DB_DEFAULTS.weaveSparkTexture,
            weaveSparkTextureLayer = ns.DB_DEFAULTS.weaveSparkTextureLayer,
            weaveSparkWidth = ns.DB_DEFAULTS.weaveSparkWidth,
            weaveSparkHeight = ns.DB_DEFAULTS.weaveSparkHeight,
            weaveSparkAlpha = ns.DB_DEFAULTS.weaveSparkAlpha,
            weaveTriangleTopTexture = ns.DB_DEFAULTS.weaveTriangleTopTexture,
            weaveTriangleBottomTexture = ns.DB_DEFAULTS.weaveTriangleBottomTexture,
            weaveTriangleTextureLayer = ns.DB_DEFAULTS.weaveTriangleTextureLayer,
            weaveTriangleSize = ns.DB_DEFAULTS.weaveTriangleSize,
            weaveTriangleGap = ns.DB_DEFAULTS.weaveTriangleGap,
            weaveTriangleAlpha = ns.DB_DEFAULTS.weaveTriangleAlpha,
            weaveMarkerLayer = ns.DB_DEFAULTS.weaveMarkerLayer,
            sparkWidth = ns.DB_DEFAULTS.sparkWidth,
            sparkHeight = ns.DB_DEFAULTS.sparkHeight,
            barBorderSize = ns.DB_DEFAULTS.barBorderSize,
            barBackgroundAlpha = ns.DB_DEFAULTS.barBackgroundAlpha,
            barBackgroundColor = {
                r = ns.DB_DEFAULTS.barBackgroundColor.r,
                g = ns.DB_DEFAULTS.barBackgroundColor.g,
                b = ns.DB_DEFAULTS.barBackgroundColor.b,
                a = ns.DB_DEFAULTS.barBackgroundColor.a
            },
            barBorderColor = {
                r = ns.DB_DEFAULTS.barBorderColor.r,
                g = ns.DB_DEFAULTS.barBorderColor.g,
                b = ns.DB_DEFAULTS.barBorderColor.b,
                a = ns.DB_DEFAULTS.barBorderColor.a
            },
            sparkAlpha = ns.DB_DEFAULTS.sparkAlpha,
            sparkColor = {
                r = ns.DB_DEFAULTS.sparkColor.r,
                g = ns.DB_DEFAULTS.sparkColor.g,
                b = ns.DB_DEFAULTS.sparkColor.b,
                a = ns.DB_DEFAULTS.sparkColor.a
            },
            minimalMode = ns.DB_DEFAULTS.minimalMode,
            lockBars = ns.DB_DEFAULTS.lockBars,
            colors = {},
            positions = {
                mh = {
                    point = ns.DB_DEFAULTS.positions.mh.point,
                    relativePoint = ns.DB_DEFAULTS.positions.mh.relativePoint,
                    x = ns
                        .DB_DEFAULTS
                        .positions
                        .mh
                        .x,
                    y = ns
                        .DB_DEFAULTS
                        .positions
                        .mh
                        .y
                },
                oh = {
                    point = ns.DB_DEFAULTS.positions.oh.point,
                    relativePoint = ns.DB_DEFAULTS.positions.oh.relativePoint,
                    x = ns
                        .DB_DEFAULTS
                        .positions
                        .oh
                        .x,
                    y = ns
                        .DB_DEFAULTS
                        .positions
                        .oh
                        .y
                },
                ranged = {
                    point = ns.DB_DEFAULTS.positions.ranged.point,
                    relativePoint = ns
                        .DB_DEFAULTS
                        .positions
                        .ranged
                        .relativePoint,
                    x = ns
                        .DB_DEFAULTS
                        .positions
                        .ranged
                        .x,
                    y = ns
                        .DB_DEFAULTS
                        .positions
                        .ranged
                        .y
                },
                enemy = {
                    point = ns.DB_DEFAULTS.positions.enemy.point,
                    relativePoint = ns
                        .DB_DEFAULTS
                        .positions
                        .enemy
                        .relativePoint,
                    x = ns
                        .DB_DEFAULTS
                        .positions
                        .enemy
                        .x,
                    y = ns
                        .DB_DEFAULTS
                        .positions
                        .enemy
                        .y
                }
            }
        }
        for key, def in pairs(ns.DB_DEFAULTS.colors) do
            SuperSwingTimerDB.colors[key] = { r = def.r, g = def.g, b = def.b, a = def.a }
        end
    end

    -- Fill any missing fields for upgrades
    SuperSwingTimerDB.version = SuperSwingTimerDB.version or 10

    local function IsVisibleDefaultColor(color)
        return color and math.abs((color.r or 0) - 0.25) < 0.001
            and math.abs((color.g or 0) - 0.72) < 0.001 and math.abs((color.b or 0) - 1.00) < 0.001
    end
    SuperSwingTimerDB.showMH = (SuperSwingTimerDB.showMH ~= false)
    SuperSwingTimerDB.showOH = (SuperSwingTimerDB.showOH ~= false)
    SuperSwingTimerDB.showRanged = (SuperSwingTimerDB.showRanged ~= false)
    SuperSwingTimerDB.showHunterRangeHelper = (SuperSwingTimerDB.showHunterRangeHelper ~= false)
    SuperSwingTimerDB.showEnemy = (SuperSwingTimerDB.showEnemy ~= false)
    SuperSwingTimerDB.showRogueSinisterAssist = (SuperSwingTimerDB.showRogueSinisterAssist ~= false)
    SuperSwingTimerDB.showRogueEnergyTick = (SuperSwingTimerDB.showRogueEnergyTick ~= false)
    SuperSwingTimerDB.showRogueComboPoints = (SuperSwingTimerDB.showRogueComboPoints ~= false)
    SuperSwingTimerDB.showRogueSliceAndDice = (SuperSwingTimerDB.showRogueSliceAndDice ~= false)
    SuperSwingTimerDB.showWeaveAssist = (SuperSwingTimerDB.showWeaveAssist ~= false)
    SuperSwingTimerDB.showPaladinSealColor = (SuperSwingTimerDB.showPaladinSealColor ~= false)
    SuperSwingTimerDB.showPaladinSealLabel = (SuperSwingTimerDB.showPaladinSealLabel ~= false)
    SuperSwingTimerDB.showPaladinJudgementMarker = (SuperSwingTimerDB.showPaladinJudgementMarker ~= false)
    SuperSwingTimerDB.showPaladinTwistFlash = (SuperSwingTimerDB.showPaladinTwistFlash ~= false)
    SuperSwingTimerDB.showWarriorRageBar = (SuperSwingTimerDB.showWarriorRageBar ~= false)
    SuperSwingTimerDB.showWarriorShieldBlockBar = (SuperSwingTimerDB.showWarriorShieldBlockBar ~= false)
    -- Phase 1 toggle defaults
    SuperSwingTimerDB.showSwingFlash = (SuperSwingTimerDB.showSwingFlash ~= false)
    SuperSwingTimerDB.showGcdTicker = (SuperSwingTimerDB.showGcdTicker ~= false)
    SuperSwingTimerDB.showDruidEnergyTickBar = (SuperSwingTimerDB.showDruidEnergyTickBar ~= false)
    SuperSwingTimerDB.showRogueEnergyCountdown = (SuperSwingTimerDB.showRogueEnergyCountdown ~= false)
    -- Phase 2 toggle defaults
    SuperSwingTimerDB.showHunterRapidFireBar = (SuperSwingTimerDB.showHunterRapidFireBar ~= false)
    SuperSwingTimerDB.showWarriorFlurryCounter = (SuperSwingTimerDB.showWarriorFlurryCounter ~= false)
    SuperSwingTimerDB.showRogueAdrenalineRushBar = (SuperSwingTimerDB.showRogueAdrenalineRushBar ~= false)
    SuperSwingTimerDB.showShamanWindfuryIcd = (SuperSwingTimerDB.showShamanWindfuryIcd ~= false)
    SuperSwingTimerDB.showShamanLightningTracker = (SuperSwingTimerDB.showShamanLightningTracker ~= false)
    SuperSwingTimerDB.showShamanFlameShockBar = (SuperSwingTimerDB.showShamanFlameShockBar ~= false)
    SuperSwingTimerDB.showShamanBuffIcons = (SuperSwingTimerDB.showShamanBuffIcons ~= false)
    if SuperSwingTimerDB.shamanBuffIconSize == nil then
        SuperSwingTimerDB.shamanBuffIconSize = ns.DB_DEFAULTS.shamanBuffIconSize or 25
    end
    SuperSwingTimerDB.showWarriorBuffIcons = (SuperSwingTimerDB.showWarriorBuffIcons ~= false)
    if SuperSwingTimerDB.warriorBuffIconSize == nil then
        SuperSwingTimerDB.warriorBuffIconSize = ns.DB_DEFAULTS.warriorBuffIconSize or 25
    end
    SuperSwingTimerDB.showRogueBuffIcons = (SuperSwingTimerDB.showRogueBuffIcons ~= false)
    if SuperSwingTimerDB.rogueBuffIconSize == nil then
        SuperSwingTimerDB.rogueBuffIconSize = ns.DB_DEFAULTS.rogueBuffIconSize or 25
    end
    SuperSwingTimerDB.showPaladinBuffIcons = (SuperSwingTimerDB.showPaladinBuffIcons ~= false)
    if SuperSwingTimerDB.paladinBuffIconSize == nil then
        SuperSwingTimerDB.paladinBuffIconSize = ns.DB_DEFAULTS.paladinBuffIconSize or 25
    end
    if SuperSwingTimerDB.shamanLightningTrackerGap == nil then
        SuperSwingTimerDB.shamanLightningTrackerGap = ns.DB_DEFAULTS.shamanLightningTrackerGap or 6
    end
    -- useClassColors strictly defaults to false unless explicitly true in the DB
    if SuperSwingTimerDB.useClassColors == nil then
        SuperSwingTimerDB.useClassColors = false
    end
    SuperSwingTimerDB.indicatorBlendMode = SuperSwingTimerDB.indicatorBlendMode or ns.DB_DEFAULTS.indicatorBlendMode
    SuperSwingTimerDB.weaveSpellFamilies = SuperSwingTimerDB.weaveSpellFamilies or {}
    for key, def in pairs(ns.DB_DEFAULTS.weaveSpellFamilies) do
        if SuperSwingTimerDB.weaveSpellFamilies[key] == nil then
            SuperSwingTimerDB.weaveSpellFamilies[key] = def
        end
    end
    SuperSwingTimerDB.weaveMarkerLayer = SuperSwingTimerDB.weaveMarkerLayer or ns.DB_DEFAULTS.weaveMarkerLayer
    SuperSwingTimerDB.positions = SuperSwingTimerDB.positions or {}
    for slot, def in pairs(ns.DB_DEFAULTS.positions) do
        if not SuperSwingTimerDB.positions[slot] then
            SuperSwingTimerDB.positions[slot] = {
                point = def.point,
                relativePoint = def.relativePoint,
                x = def.x,
                y = def.y
            }
        end
    end
    SuperSwingTimerDB.colors = SuperSwingTimerDB.colors or {}
    for key, def in pairs(ns.DB_DEFAULTS.colors) do
        if not SuperSwingTimerDB.colors[key] then
            SuperSwingTimerDB.colors[key] = { r = def.r, g = def.g, b = def.b, a = def.a }
        end
    end
    SuperSwingTimerDB.sparkColor = SuperSwingTimerDB.sparkColor
        or {
            r = ns.DB_DEFAULTS.sparkColor.r,
            g = ns.DB_DEFAULTS.sparkColor.g,
            b = ns.DB_DEFAULTS.sparkColor.b,
            a = SuperSwingTimerDB.sparkAlpha ~= nil and SuperSwingTimerDB.sparkAlpha or ns.DB_DEFAULTS.sparkColor.a
        }
    if SuperSwingTimerDB.sparkColor.a == nil then
        SuperSwingTimerDB.sparkColor.a = SuperSwingTimerDB.sparkAlpha or ns.DB_DEFAULTS.sparkColor.a
    end
    SuperSwingTimerDB.sparkAlpha = SuperSwingTimerDB.sparkColor.a or SuperSwingTimerDB.sparkAlpha
        or ns.DB_DEFAULTS.sparkAlpha

    local migrations = {
        {
            version = 3,
            apply = function (db)
                db.barWidth = db.barWidth or ns.DB_DEFAULTS.barWidth
                db.barHeight = db.barHeight or ns.DB_DEFAULTS.barHeight
                db.colors = db.colors or {}
                for key, def in pairs(ns.DB_DEFAULTS.colors) do
                    if not db.colors[key] then
                        db.colors[key] = { r = def.r, g = def.g, b = def.b, a = def.a }
                    end
                end
            end
        },
        {
            version = 5,
            apply = function (db)
                db.barTexture = db.barTexture or ns.DB_DEFAULTS.barTexture
            end
        },
        {
            version = 6,
            apply = function (db)
                db.sparkTexture = db.sparkTexture or ns.DB_DEFAULTS.sparkTexture
                db.weaveMarkerLayer = db.weaveMarkerLayer or ns.DB_DEFAULTS.weaveMarkerLayer
                db.sparkWidth = db.sparkWidth or ns.DB_DEFAULTS.sparkWidth
                db.sparkHeight = db.sparkHeight or ns.DB_DEFAULTS.sparkHeight
            end
        },
        {
            version = 7,
            apply = function (db)
                db.barTextureLayer = db.barTextureLayer or ns.DB_DEFAULTS.barTextureLayer
                db.sparkTextureLayer = db.sparkTextureLayer or ns.DB_DEFAULTS.sparkTextureLayer
                db.barBackgroundAlpha = db.barBackgroundAlpha ~= nil and db.barBackgroundAlpha
                    or ns.DB_DEFAULTS.barBackgroundAlpha
                db.sparkAlpha = db.sparkAlpha ~= nil and db.sparkAlpha or ns.DB_DEFAULTS.sparkAlpha
                db.minimalMode = db.minimalMode == true
                db.lockBars = db.lockBars == true
            end
        },
        {
            version = 8,
            apply = function (db)
                db.weaveSparkTexture = db.weaveSparkTexture or ns.DB_DEFAULTS.weaveSparkTexture
                db.weaveSparkTextureLayer = db.weaveSparkTextureLayer or ns.DB_DEFAULTS.weaveSparkTextureLayer
                db.weaveSparkWidth = db.weaveSparkWidth or ns.DB_DEFAULTS.weaveSparkWidth
                db.weaveSparkHeight = db.weaveSparkHeight or ns.DB_DEFAULTS.weaveSparkHeight
                db.weaveSparkAlpha = db.weaveSparkAlpha ~= nil and db.weaveSparkAlpha or ns.DB_DEFAULTS.weaveSparkAlpha
                db.weaveTriangleTopTexture = db.weaveTriangleTopTexture or ns.DB_DEFAULTS.weaveTriangleTopTexture
                db.weaveTriangleBottomTexture = db.weaveTriangleBottomTexture
                    or ns.DB_DEFAULTS.weaveTriangleBottomTexture
                db.weaveTriangleTextureLayer = db.weaveTriangleTextureLayer or ns.DB_DEFAULTS.weaveTriangleTextureLayer
                db.weaveTriangleSize = db.weaveTriangleSize or ns.DB_DEFAULTS.weaveTriangleSize
                db.weaveTriangleGap = db.weaveTriangleGap or ns.DB_DEFAULTS.weaveTriangleGap
                db.weaveTriangleAlpha = db.weaveTriangleAlpha ~= nil and db.weaveTriangleAlpha
                    or ns.DB_DEFAULTS.weaveTriangleAlpha
            end
        },
        {
            version = 9,
            apply = function (db)
                db.colors = db.colors or {}
                for key, def in pairs(ns.DB_DEFAULTS.colors) do
                    local color = db.colors[key]
                    if not color
                        or (color.r == 0 and color.g == 0 and color.b == 0 and (color.a == nil or color.a == 1)) then
                        db.colors[key] = { r = def.r, g = def.g, b = def.b, a = def.a }
                    end
                end
            end
        },
        {
            version = 10,
            apply = function (db)
                db.colors = db.colors or {}
                local colors = db.colors
                if IsVisibleDefaultColor(colors.mh) or not colors.mh then
                    colors.mh = { r = 0, g = 0, b = 0, a = 1 }
                end
                if IsVisibleDefaultColor(colors.oh) or not colors.oh then
                    colors.oh = { r = 0, g = 0, b = 0, a = 1 }
                end
                if IsVisibleDefaultColor(colors.ranged) or not colors.ranged then
                    colors.ranged = { r = 0, g = 0, b = 0, a = 1 }
                end
            end
        },
        {
            version = 11,
            apply = function (db)
                local function UpgradeWeaveDefault(currentValue, oldDefault, newDefault)
                    if currentValue == nil or currentValue == oldDefault then return newDefault end
                    return currentValue
                end
                db.weaveSparkWidth = UpgradeWeaveDefault(db.weaveSparkWidth, 14, ns.DB_DEFAULTS.weaveSparkWidth)
                db.weaveSparkHeight = UpgradeWeaveDefault(db.weaveSparkHeight, 30, ns.DB_DEFAULTS.weaveSparkHeight)
                db.weaveTriangleSize = UpgradeWeaveDefault(db.weaveTriangleSize, 14, ns.DB_DEFAULTS.weaveTriangleSize)
                db.weaveTriangleGap = UpgradeWeaveDefault(db.weaveTriangleGap, 2, ns.DB_DEFAULTS.weaveTriangleGap)
                db.weaveSpellFamilies = db.weaveSpellFamilies or {}
                for key, def in pairs(ns.DB_DEFAULTS.weaveSpellFamilies) do
                    if db.weaveSpellFamilies[key] == nil then db.weaveSpellFamilies[key] = def end
                end
            end
        },
        {
            version = 12,
            apply = function (db)
                db.useClassColors = (db.useClassColors ~= false)
                db.indicatorBlendMode = db.indicatorBlendMode or ns.DB_DEFAULTS.indicatorBlendMode
            end
        },
        {
            version = 13,
            apply = function (db)
                db.rangedBarTexture = db.rangedBarTexture or ns.DB_DEFAULTS.rangedBarTexture
            end
        },
        {
            version = 14,
            apply = function (db)
                db.colors = db.colors or {}
                local sealTwist = db.colors.sealTwist
                local isLegacySealTwist = sealTwist and math.abs((sealTwist.r or 0) - 0) < 0.001
                    and math.abs((sealTwist.g or 0) - 0.8) < 0.001 and math.abs((sealTwist.b or 0) - 1) < 0.001
                    and math.abs((sealTwist.a or 0) - 0.4) < 0.001
                if not sealTwist or isLegacySealTwist then
                    db.colors.sealTwist = { r = 0, g = 0, b = 0, a = 1 }
                elseif sealTwist.a == nil then
                    sealTwist.a = 1
                end
            end
        },
        {
            version = 15,
            apply = function (db)
                if db.sparkTexture == nil or db.sparkTexture == "Interface\\CastingBar\\UI-CastingBar-Spark" then
                    db.sparkTexture = ns.DB_DEFAULTS.sparkTexture
                end
                if db.weaveSparkTexture == nil or db.weaveSparkTexture == "Interface\\CastingBar\\UI-CastingBar-Spark" then
                    db.weaveSparkTexture = ns.DB_DEFAULTS.weaveSparkTexture
                end
                if not db.sparkColor then
                    db.sparkColor = {
                        r = ns.DB_DEFAULTS.sparkColor.r,
                        g = ns.DB_DEFAULTS.sparkColor.g,
                        b = ns.DB_DEFAULTS.sparkColor.b,
                        a = db.sparkAlpha or ns.DB_DEFAULTS.sparkColor.a
                    }
                elseif db.sparkColor.a == nil then
                    db.sparkColor.a = db.sparkAlpha or ns.DB_DEFAULTS.sparkColor.a
                end
                db.sparkAlpha = db.sparkColor.a or db.sparkAlpha or ns.DB_DEFAULTS.sparkAlpha
            end
        },
        {
            version = 16,
            apply = function (db)
                local function UpgradeThinDefault(currentValue, oldDefault, newDefault)
                    if currentValue == nil or currentValue == oldDefault then return newDefault end
                    return currentValue
                end
                db.sparkWidth = UpgradeThinDefault(db.sparkWidth, 20, ns.DB_DEFAULTS.sparkWidth)
                db.sparkHeight = UpgradeThinDefault(db.sparkHeight, 44, ns.DB_DEFAULTS.sparkHeight)
                db.weaveSparkWidth = UpgradeThinDefault(db.weaveSparkWidth, 10, ns.DB_DEFAULTS.weaveSparkWidth)
                db.weaveSparkHeight = UpgradeThinDefault(db.weaveSparkHeight, 24, ns.DB_DEFAULTS.weaveSparkHeight)
                db.weaveTriangleSize = UpgradeThinDefault(db.weaveTriangleSize, 10, ns.DB_DEFAULTS.weaveTriangleSize)
            end
        },
        {
            version = 17,
            apply = function (db)
                if db.sparkWidth == nil or db.sparkWidth == 3 then db.sparkWidth = ns.DB_DEFAULTS.sparkWidth end
            end
        },
        {
            version = 18,
            apply = function (db)
                if db.sparkWidth == nil or db.sparkWidth == 3 then db.sparkWidth = ns.DB_DEFAULTS.sparkWidth end
            end
        },
        {
            version = 19,
            apply = function (db)
                db.barBorderSize = db.barBorderSize or ns.DB_DEFAULTS.barBorderSize
            end
        },
        {
            version = 20,
            apply = function (db)
                db.barBackgroundColor = db.barBackgroundColor
                    or {
                        r = ns.DB_DEFAULTS.barBackgroundColor.r,
                        g = ns.DB_DEFAULTS.barBackgroundColor.g,
                        b = ns.DB_DEFAULTS.barBackgroundColor.b,
                        a = db.barBackgroundAlpha ~= nil and db.barBackgroundAlpha
                            or ns.DB_DEFAULTS.barBackgroundColor.a
                    }
                db.barBorderColor = db.barBorderColor
                    or {
                        r = ns.DB_DEFAULTS.barBorderColor.r,
                        g = ns.DB_DEFAULTS.barBorderColor.g,
                        b = ns.DB_DEFAULTS.barBorderColor.b,
                        a = ns.DB_DEFAULTS.barBorderColor.a
                    }
            end
        },
        { version = 21, apply = function (_db) end },
        {
            version = 22,
            apply = function (db)
                db.colors = db.colors or {}
                local colors = db.colors
                colors.mh = { r = 0, g = 0, b = 0, a = 1 }
                colors.oh = { r = 0, g = 0, b = 0, a = 1 }
                colors.ranged = { r = 0, g = 0, b = 0, a = 1 }
                db.sparkColor = { r = 1, g = 1, b = 1, a = 1 }
                db.useClassColors = false
            end
        },
        { version = 23, apply = function (_db) end },
        { version = 24, apply = function (_db) end },
        {
            version = 25,
            apply = function (db)
                if db.sparkWidth == nil or math.abs((db.sparkWidth or 0) - 4) < 0.001 then
                    db.sparkWidth = ns.DB_DEFAULTS.sparkWidth
                end
            end
        },
        {
            version = 26,
            apply = function (db)
                db.colors = db.colors or {}
                local colors = db.colors
                colors.autoShotSafe = colors.autoShotSafe
                    or {
                        r = ns.DB_DEFAULTS.colors.autoShotSafe.r,
                        g = ns
                            .DB_DEFAULTS
                            .colors
                            .autoShotSafe
                            .g,
                        b = ns
                            .DB_DEFAULTS
                            .colors
                            .autoShotSafe
                            .b,
                        a = ns
                            .DB_DEFAULTS
                            .colors
                            .autoShotSafe
                            .a
                    }
                colors.autoShotUnsafe = colors.autoShotUnsafe
                    or {
                        r = ns.DB_DEFAULTS.colors.autoShotUnsafe.r,
                        g = ns
                            .DB_DEFAULTS
                            .colors
                            .autoShotUnsafe
                            .g,
                        b = ns
                            .DB_DEFAULTS
                            .colors
                            .autoShotUnsafe
                            .b,
                        a = ns
                            .DB_DEFAULTS
                            .colors
                            .autoShotUnsafe
                            .a
                    }
            end
        },
        {
            version = 27,
            apply = function (db)
                db.showRogueSinisterAssist = (db.showRogueSinisterAssist ~= false)
                db.colors = db.colors or {}
                db.colors.rogueSinister = db.colors.rogueSinister
                    or {
                        r = ns.DB_DEFAULTS.colors.rogueSinister.r,
                        g = ns
                            .DB_DEFAULTS
                            .colors
                            .rogueSinister
                            .g,
                        b = ns
                            .DB_DEFAULTS
                            .colors
                            .rogueSinister
                            .b,
                        a = ns
                            .DB_DEFAULTS
                            .colors
                            .rogueSinister
                            .a
                    }
            end
        },
        {
            version = 28,
            apply = function (db)
                if db.barHeight == nil or math.abs((db.barHeight or 0) - 20) < 0.001 then
                    db.barHeight = ns.DB_DEFAULTS.barHeight
                end
                if db.sparkHeight == nil or math.abs((db.sparkHeight or 0) - 20) < 0.001 then
                    db.sparkHeight = ns.DB_DEFAULTS.sparkHeight
                end
                db.showRogueEnergyTick = (db.showRogueEnergyTick ~= false)
                db.colors = db.colors or {}
                db.colors.rogueEnergyTick = db.colors.rogueEnergyTick
                    or {
                        r = ns.DB_DEFAULTS.colors.rogueEnergyTick.r,
                        g = ns
                            .DB_DEFAULTS
                            .colors
                            .rogueEnergyTick
                            .g,
                        b = ns
                            .DB_DEFAULTS
                            .colors
                            .rogueEnergyTick
                            .b,
                        a = ns
                            .DB_DEFAULTS
                            .colors
                            .rogueEnergyTick
                            .a
                    }
            end
        },
        {
            version = 29,
            apply = function (db)
                db.colors = db.colors or {}
                local rogueCue = db.colors.rogueSinister
                if rogueCue and math.abs((rogueCue.r or 0) - 1) < 0.001 and math.abs((rogueCue.g or 0) - 0) < 0.001
                    and math.abs((rogueCue.b or 0) - 0) < 0.001 and math.abs((rogueCue.a or 0) - 0.45) < 0.001 then
                    rogueCue.a = ns
                        .DB_DEFAULTS
                        .colors
                        .rogueSinister
                        .a
                end
            end
        },
        {
            version = 30,
            apply = function (db)
                db.showRogueSliceAndDice = (db.showRogueSliceAndDice ~= false)
                db.colors = db.colors or {}
                db.colors.rogueSliceAndDice = db.colors.rogueSliceAndDice
                    or {
                        r = ns.DB_DEFAULTS.colors.rogueSliceAndDice.r,
                        g = ns
                            .DB_DEFAULTS
                            .colors
                            .rogueSliceAndDice
                            .g,
                        b = ns
                            .DB_DEFAULTS
                            .colors
                            .rogueSliceAndDice
                            .b,
                        a = ns
                            .DB_DEFAULTS
                            .colors
                            .rogueSliceAndDice
                            .a
                    }
            end
        },
        {
            version = 31,
            apply = function (db)
                db.colors = db.colors or {}
                db.colors.rogueEnergyTotal = db.colors.rogueEnergyTotal
                    or {
                        r = ns.DB_DEFAULTS.colors.rogueEnergyTotal.r,
                        g = ns
                            .DB_DEFAULTS
                            .colors
                            .rogueEnergyTotal
                            .g,
                        b = ns
                            .DB_DEFAULTS
                            .colors
                            .rogueEnergyTotal
                            .b,
                        a = ns
                            .DB_DEFAULTS
                            .colors
                            .rogueEnergyTotal
                            .a
                    }
            end
        },
        {
            version = 32,
            apply = function (db)
                db.showRogueComboPoints = (db.showRogueComboPoints ~= false)
                db.colors = db.colors or {}
                db.colors.rogueComboPoints = db.colors.rogueComboPoints
                    or {
                        r = ns.DB_DEFAULTS.colors.rogueComboPoints.r,
                        g = ns
                            .DB_DEFAULTS
                            .colors
                            .rogueComboPoints
                            .g,
                        b = ns
                            .DB_DEFAULTS
                            .colors
                            .rogueComboPoints
                            .b,
                        a = ns
                            .DB_DEFAULTS
                            .colors
                            .rogueComboPoints
                            .a
                    }
            end
        },
        {
            version = 33,
            apply = function (db)
                db.showHunterRangeHelper = (db.showHunterRangeHelper ~= false)
                db.colors = db.colors or {}
                for _, colorKey in ipairs(
                    { "hunterRangeMelee", "hunterRangeSweetSpot", "hunterRangeRanged", "hunterRangeOutOfRange" }
                ) do
                    if not db.colors[colorKey] then
                        local def = ns.DB_DEFAULTS.colors[colorKey]
                        db.colors[colorKey] = { r = def.r, g = def.g, b = def.b, a = def.a }
                    end
                end
            end
        },
        {
            version = 34,
            apply = function (db)
                db.colors = db.colors or {}
                local sealTwist = db.colors.sealTwist
                local isLegacyBlack = sealTwist and math.abs((sealTwist.r or 0) - 0) < 0.001
                    and math.abs((sealTwist.g or 0) - 0) < 0.001 and math.abs((sealTwist.b or 0) - 0) < 0.001
                    and math.abs((sealTwist.a or 1) - 1) < 0.001
                if not sealTwist or isLegacyBlack then
                    db.colors.sealTwist = { r = 1, g = 0, b = 0, a = 0.35 }
                end
            end
        },
        {
            version = 35,
            apply = function (db)
                db.colors = db.colors or {}
                for familyKey, defaultColor in pairs(ns.PALADIN_SEAL_COLORS or {}) do
                    local colorKey = "sealColor" .. familyKey
                    if not db.colors[colorKey] then
                        db.colors[colorKey] = {
                            r = defaultColor.r,
                            g = defaultColor.g,
                            b = defaultColor.b,
                            a = defaultColor.a
                        }
                    end
                end
            end
        },
        {
            version = 36,
            apply = function (db)
                db.showWarriorRageBar = ns.DB_DEFAULTS and ns.DB_DEFAULTS.showWarriorRageBar
                if db.showWarriorRageBar == nil then db.showWarriorRageBar = true end
                db.colors = db.colors or {}
                if not db.colors.warriorRageBarColor then
                    local default = ns.DB_DEFAULTS and ns.DB_DEFAULTS.colors
                        and ns.DB_DEFAULTS.colors.warriorRageBarColor
                    db.colors.warriorRageBarColor = default or { r = 0.80, g = 0.20, b = 0.10, a = 0.85 }
                end
            end
        },
        {
            version = 37,
            apply = function (db)
                db.showDruidFormColors = true
                db.colors = db.colors or {}
                if not db.colors.druidFormBear then
                    db.colors.druidFormBear = { r = 0.80, g = 0.15, b = 0.10, a = 1.0 }
                end
                if not db.colors.druidFormCat then
                    db.colors.druidFormCat = { r = 0.90, g = 0.70, b = 0.10, a = 1.0 }
                end
                if not db.colors.druidFormMoonkin then
                    db.colors.druidFormMoonkin = { r = 0.30, g = 0.55, b = 0.90, a = 1.0 }
                end
            end
        },
        {
            version = 38,
            apply = function (db)
                if db.showWarriorRageProtection == nil then db.showWarriorRageProtection = false end
            end
        },
        {
            version = 39,
            apply = function (db)
                if db.showSwingFlash == nil then db.showSwingFlash = true end
                if db.showGcdTicker == nil then db.showGcdTicker = true end
                if db.showDruidRageDim == nil then db.showDruidRageDim = true end
                if db.showRogueEnergyCountdown == nil then db.showRogueEnergyCountdown = true end
                db.colors = db.colors or {}
                if not db.colors.gcdTickerColor then
                    db.colors.gcdTickerColor = (ns.DB_DEFAULTS and ns.DB_DEFAULTS.colors
                        and ns.DB_DEFAULTS.colors.gcdTickerColor)
                        or { r = 0.30, g = 0.70, b = 1.00, a = 0.85 }
                end
            end
        },
        {
            version = 40,
            apply = function (db)
                if db.showHunterRapidFireBar == nil then db.showHunterRapidFireBar = true end
                if db.showWarriorFlurryCounter == nil then db.showWarriorFlurryCounter = true end
                if db.showRogueAdrenalineRushBar == nil then db.showRogueAdrenalineRushBar = true end
                if db.showDruidOmenGlow == nil then db.showDruidOmenGlow = true end
                if db.showShamanWindfuryIcd == nil then db.showShamanWindfuryIcd = true end
                if db.showWarriorShieldBlockBar == nil then db.showWarriorShieldBlockBar = true end
                if db.showDruidRavageCue == nil then db.showDruidRavageCue = true end
                db.colors = db.colors or {}
                local colorDefaults = ns.DB_DEFAULTS and ns.DB_DEFAULTS.colors or {}
                for _, key in ipairs(
                    { "rapidFireBar", "flurryCounter", "adrenalineRushBar", "omenGlow", "windfuryIcd" }
                ) do
                    if not db.colors[key] and colorDefaults[key] then
                        db.colors[key] = {
                            r = colorDefaults[key].r,
                            g = colorDefaults[key].g,
                            b = colorDefaults[key].b,
                            a = colorDefaults[key].a
                        }
                    end
                end
            end
        },
        {
            version = 41,
            apply = function (db)
                db.colors = db.colors or {}
                local colorDefaults = ns.DB_DEFAULTS and ns.DB_DEFAULTS.colors or {}
                for _, key in ipairs({ "shieldBlockBar", "ravageCue" }) do
                    if not db.colors[key] and colorDefaults[key] then
                        db.colors[key] = {
                            r = colorDefaults[key].r,
                            g = colorDefaults[key].g,
                            b = colorDefaults[key].b,
                            a = colorDefaults[key].a
                        }
                    end
                end
            end
        },
        {
            version = 42,
            apply = function (db)
                if db.hunterCastBarHeight == nil then db.hunterCastBarHeight = ns.DB_DEFAULTS.hunterCastBarHeight or 10 end
            end
        },
        {
            version = 43,
            apply = function (db)
                if db.rogueSliceAndDiceBarHeight == nil then
                    db.rogueSliceAndDiceBarHeight = ns.DB_DEFAULTS.rogueSliceAndDiceBarHeight or 4
                end
                if db.rogueEnergyTickBarWidth == nil then
                    db.rogueEnergyTickBarWidth = ns.DB_DEFAULTS.rogueEnergyTickBarWidth or 4
                end
                if db.warriorShieldBlockBarHeight == nil then
                    db.warriorShieldBlockBarHeight = ns.DB_DEFAULTS.warriorShieldBlockBarHeight or 4
                end
                if db.hunterRangeHelperWidth == nil then
                    db.hunterRangeHelperWidth = ns.DB_DEFAULTS.hunterRangeHelperWidth or 7
                end
                if db.hunterRapidFireBarHeight == nil then
                    db.hunterRapidFireBarHeight = ns.DB_DEFAULTS.hunterRapidFireBarHeight or 4
                end
                if db.druidPowerShiftBarHeight == nil then
                    db.druidPowerShiftBarHeight = ns.DB_DEFAULTS.druidPowerShiftBarHeight or 4
                end
                if db.druidEnergyTickBarWidth == nil then
                    db.druidEnergyTickBarWidth = ns.DB_DEFAULTS.druidEnergyTickBarWidth or 4
                end
                if db.rogueAdrenalineRushBarHeight == nil then
                    db.rogueAdrenalineRushBarHeight = ns.DB_DEFAULTS.rogueAdrenalineRushBarHeight or 4
                end
            end
        },
        {
            version = 44,
            apply = function (db)
                db.showDruidTigerFuryBadge = (db.showDruidTigerFuryBadge ~= false)
                db.showDruidFaerieFireBadge = (db.showDruidFaerieFireBadge ~= false)
                db.colors = db.colors or {}
                local colorDefaults = ns.DB_DEFAULTS and ns.DB_DEFAULTS.colors or {}
                if not db.colors.druidEnergyTick and colorDefaults.druidEnergyTick then
                    db.colors.druidEnergyTick = {
                        r = colorDefaults.druidEnergyTick.r,
                        g = colorDefaults.druidEnergyTick.g,
                        b = colorDefaults.druidEnergyTick.b,
                        a = colorDefaults.druidEnergyTick.a
                    }
                end
            end
        },
        {
            version = 45,
            apply = function (db)
                db.showDruidMangleTimer = (db.showDruidMangleTimer ~= false)
                db.showDruidRipTracker = (db.showDruidRipTracker ~= false)
                db.colors = db.colors or {}
                local colorDefaults = ns.DB_DEFAULTS and ns.DB_DEFAULTS.colors or {}
                for _, key in ipairs({ "druidMangleTimer", "druidRipTracker" }) do
                    if not db.colors[key] and colorDefaults[key] then
                        db.colors[key] = {
                            r = colorDefaults[key].r,
                            g = colorDefaults[key].g,
                            b = colorDefaults[key].b,
                            a = colorDefaults[key].a
                        }
                    end
                end
            end
        },
        {
            version = 46,
            apply = function (db)
                if db.showShamanLightningTracker == nil then db.showShamanLightningTracker = true end
                db.colors = db.colors or {}
                local colorDefaults = ns.DB_DEFAULTS and ns.DB_DEFAULTS.colors or {}
                if not db.colors.shamanLightningShield and colorDefaults.shamanLightningShield then
                    db.colors.shamanLightningShield = {
                        r = colorDefaults.shamanLightningShield.r,
                        g = colorDefaults.shamanLightningShield.g,
                        b = colorDefaults.shamanLightningShield.b,
                        a = colorDefaults.shamanLightningShield.a
                    }
                end
            end
        },
        {
            version = 47,
            apply = function (db)
                if db.showShamanFlameShockBar == nil then db.showShamanFlameShockBar = true end
                if db.showDruidEnergyTickBar == nil then db.showDruidEnergyTickBar = true end
                if db.druidEnergyTickBarWidth == nil then
                    db.druidEnergyTickBarWidth = ns.DB_DEFAULTS.druidEnergyTickBarWidth or 4
                end
                db.colors = db.colors or {}
                local colorDefaults = ns.DB_DEFAULTS and ns.DB_DEFAULTS.colors or {}
                if not db.colors.druidEnergyTick and colorDefaults.druidEnergyTick then
                    db.colors.druidEnergyTick = {
                        r = colorDefaults.druidEnergyTick.r,
                        g = colorDefaults.druidEnergyTick.g,
                        b = colorDefaults.druidEnergyTick.b,
                        a = colorDefaults.druidEnergyTick.a
                    }
                end
                db.showDruidTigerFuryBadge = nil
                db.showDruidFaerieFireBadge = nil
                db.showDruidMangleTimer = nil
                db.showDruidRipTracker = nil
                db.showDruidFormColors = nil
                db.showDruidRageDim = nil
                db.showDruidPowerShiftBar = nil
                db.showDruidOmenGlow = nil
                db.showDruidRavageCue = nil
                db.druidPowerShiftBarHeight = nil
                db.colors.druidFormBear = nil
                db.colors.druidFormCat = nil
                db.colors.druidFormMoonkin = nil
                db.colors.omenGlow = nil
                db.colors.ravageCue = nil
                db.colors.druidMangleTimer = nil
                db.colors.druidRipTracker = nil
            end
        },
        {
            version = 48,
            apply = function (db)
                if db.shamanLightningTrackerGap == nil then
                    db.shamanLightningTrackerGap = (ns.DB_DEFAULTS and ns.DB_DEFAULTS.shamanLightningTrackerGap) or 6
                end
            end
        },
        {
            version = 49,
            apply = function (db)
                db.colors = db.colors or {}
                if not db.colors.hunterCastBar then
                    db.colors.hunterCastBar = {
                        r = ns.DB_DEFAULTS.colors.hunterCastBar.r,
                        g = ns.DB_DEFAULTS.colors.hunterCastBar.g,
                        b = ns.DB_DEFAULTS.colors.hunterCastBar.b,
                        a = ns.DB_DEFAULTS.colors.hunterCastBar.a
                    }
                end
            end
        },
        {
            version = 50,
            apply = function (db)
                if db.showWarriorDeepWoundsBar == nil then db.showWarriorDeepWoundsBar = true end
                if db.showDruidMangleBar == nil then db.showDruidMangleBar = true end
                if db.showDruidRipBar == nil then db.showDruidRipBar = true end
                if db.showRogueRuptureBar == nil then db.showRogueRuptureBar = true end
                if db.showHunterSerpentStingBar == nil then db.showHunterSerpentStingBar = true end
                if db.showPaladinJudgementBar == nil then db.showPaladinJudgementBar = true end
            end
        },
        {
            version = 51,
            apply = function (db)
                if db.showPaladinSealVengeanceBar == nil then db.showPaladinSealVengeanceBar = true end
                if db.showDruidRakeBar == nil then db.showDruidRakeBar = true end
                if db.showDruidBuffIcons == nil then db.showDruidBuffIcons = true end
                if db.druidBuffIconSize == nil then db.druidBuffIconSize = 25 end
            end
        },
        {
            version = 52,
            apply = function (db)
                if db.showHunterWingClipBar == nil then db.showHunterWingClipBar = true end
                if db.showHunterConcussionShotBar == nil then db.showHunterConcussionShotBar = true end
                if db.showWarriorSunderArmorBar == nil then db.showWarriorSunderArmorBar = true end
                if db.showRogueExposeArmorBar == nil then db.showRogueExposeArmorBar = true end
            end
        },
        {
            version = 53,
            apply = function (db)
                if db.showHunterImmolationTrapBar == nil then db.showHunterImmolationTrapBar = true end
                if db.showHunterExplosiveTrapBar == nil then db.showHunterExplosiveTrapBar = true end
            end
        },
        {
            version = 54,
            apply = function (db)
                if db.showHunterFreezingTrapBar == nil then db.showHunterFreezingTrapBar = true end
                if db.showHunterFrostTrapBar == nil then db.showHunterFrostTrapBar = true end
            end
        }
    }

    local currentVersion = tonumber(SuperSwingTimerDB.version) or 0
    for _, migration in ipairs(migrations) do
        if currentVersion < migration.version then
            migration.apply(SuperSwingTimerDB)
            currentVersion = migration.version
            SuperSwingTimerDB.version = migration.version
        end
    end
end

-- ============================================================
-- Initialization
-- ============================================================
local RegisterSlashCommands

local function OnAddonLoaded()
    MigrateDB()

    -- Apply DB dimensions to runtime constants
    ns.BAR_WIDTH = SuperSwingTimerDB.barWidth or ns.DB_DEFAULTS.barWidth
    ns.BAR_HEIGHT = SuperSwingTimerDB.barHeight or ns.DB_DEFAULTS.barHeight
    ns.HUNTER_CAST_BAR_HEIGHT = SuperSwingTimerDB.hunterCastBarHeight or ns.HUNTER_CAST_BAR_HEIGHT
        or ns.DB_DEFAULTS.hunterCastBarHeight or 10
    ns.ROGUE_SLICE_AND_DICE_BAR_HEIGHT = SuperSwingTimerDB.rogueSliceAndDiceBarHeight or ns.ROGUE_SLICE_AND_DICE_BAR_HEIGHT
        or ns.DB_DEFAULTS.rogueSliceAndDiceBarHeight or 4
    ns.ROGUE_ENERGY_TICK_BAR_WIDTH = SuperSwingTimerDB.rogueEnergyTickBarWidth or ns.ROGUE_ENERGY_TICK_BAR_WIDTH
        or ns.DB_DEFAULTS.rogueEnergyTickBarWidth or 4
    ns.WARRIOR_SHIELD_BLOCK_BAR_HEIGHT = SuperSwingTimerDB.warriorShieldBlockBarHeight or ns.WARRIOR_SHIELD_BLOCK_BAR_HEIGHT
        or ns.DB_DEFAULTS.warriorShieldBlockBarHeight or 4
    ns.HUNTER_RANGE_HELPER_WIDTH = SuperSwingTimerDB.hunterRangeHelperWidth or ns.HUNTER_RANGE_HELPER_WIDTH
        or ns.DB_DEFAULTS.hunterRangeHelperWidth or 7
    ns.HUNTER_RAPID_FIRE_BAR_HEIGHT = SuperSwingTimerDB.hunterRapidFireBarHeight or ns.HUNTER_RAPID_FIRE_BAR_HEIGHT
        or ns.DB_DEFAULTS.hunterRapidFireBarHeight or 4
    ns.DRUID_ENERGY_TICK_BAR_WIDTH = SuperSwingTimerDB.druidEnergyTickBarWidth or ns.DRUID_ENERGY_TICK_BAR_WIDTH
        or ns.DB_DEFAULTS.druidEnergyTickBarWidth or 4
    ns.ROGUE_ADRENALINE_RUSH_BAR_HEIGHT = SuperSwingTimerDB.rogueAdrenalineRushBarHeight or ns.ROGUE_ADRENALINE_RUSH_BAR_HEIGHT
        or ns.DB_DEFAULTS.rogueAdrenalineRushBarHeight or 4

    -- Detect class once
    local _, class = UnitClass("player")
    ns.playerClass = class
    ns.classConfig = ns.CLASS_CONFIG[class] or { ranged = false, melee = false, dualWield = false }
    if ns.InitWeaving then
        ns.InitWeaving()
    end
    -- Class-specific mods first (registers callbacks before bars are created)
    ns.InitClassMods()

    -- Create bars for this class
    ns.InitBars()

    -- Apply DB colors after bars + class mods are set up
    ns.ApplyBarColors()
    ns.ApplyBarBackgroundColor(SuperSwingTimerDB.barBackgroundColor or ns.DB_DEFAULTS.barBackgroundColor)
    ns.ApplyBarBorderColor(SuperSwingTimerDB.barBorderColor or ns.DB_DEFAULTS.barBorderColor)
    ns.ApplyBarBorderSize(SuperSwingTimerDB.barBorderSize or ns.DB_DEFAULTS.barBorderSize)

    -- Create config panel (hidden)
    ns.InitConfig()

    RegisterSlashCommands()
end

RegisterSlashCommands = function ()
    SLASH_SUPERSWINGTIMER1 = "/sst"
    SLASH_SUPERSWINGTIMER2 = "/super"
    SLASH_SUPERSWINGTIMER3 = "/superswingtimer"
    SLASH_SUPERSWINGTIMER4 = "/swang"
    SlashCmdList["SUPERSWINGTIMER"] = function (msg)
        msg = strtrim(msg or ""):lower()
        if msg == "reset" then
            local ok, err = pcall(ns.ResetConfigDefaults)
            if ok then
                print("|cff00ccffSuper Swing Timer:|r Settings reset to defaults.")
            else
                print("|cff00ccffSuper Swing Timer:|r Could not reset settings: " .. tostring(err))
            end
        elseif msg == "help" then
            print("|cff00ccffSuper Swing Timer:|r /sst, /super, or /superswingtimer - open config panel")
            print("|cff00ccffSuper Swing Timer:|r /sst reset - restore default settings")
        else
            local ok, err = pcall(ns.ToggleConfig)
            if not ok then
                print("|cff00ccffSuper Swing Timer:|r Could not open config: " .. tostring(err))
            end
        end
    end
end

RegisterSlashCommands()

-- ============================================================
-- Event frame
-- ============================================================
local frame = CreateFrame("Frame", "SuperSwingTimerFrame", UIParent)

-- Register events conditionally in ADDON_LOADED once class is known
local function RegisterEvents()
    local cfg = ns.classConfig or {}

    -- Core events for all classes
    frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    frame:RegisterEvent("ADDON_LOADED")
    frame:RegisterEvent("UNIT_ATTACK_SPEED")
    frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")

    if cfg.melee then
        frame:RegisterEvent("UNIT_AURA")
        frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
        frame:RegisterEvent("UNIT_INVENTORY_CHANGED")
        frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        frame:RegisterEvent("UNIT_SPELLCAST_START")
        frame:RegisterEvent("UNIT_SPELLCAST_STOP")
        frame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
        frame:RegisterEvent("UNIT_SPELLCAST_FAILED")
        frame:RegisterEvent("UNIT_SPELLCAST_DELAYED")
        frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
        frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    end

    if cfg.melee and ns.playerClass == "SHAMAN" then
        frame:RegisterEvent("SPELLS_CHANGED")
    end

    if cfg.melee and (ns.playerClass == "ROGUE" or ns.playerClass == "DRUID") then
        frame:RegisterEvent("UNIT_POWER_UPDATE")
        frame:RegisterEvent("UNIT_POWER_FREQUENT")
    end

    if cfg.melee and ns.playerClass == "DRUID" then
        frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    end

    if cfg.ranged then
        frame:RegisterEvent("UNIT_RANGEDDAMAGE")
        frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        frame:RegisterEvent("START_AUTOREPEAT_SPELL")
        frame:RegisterEvent("STOP_AUTOREPEAT_SPELL")
        frame:RegisterEvent("PLAYER_STARTED_MOVING")
        frame:RegisterEvent("PLAYER_STOPPED_MOVING")
    end

    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
end

local function UpdateFrameOnUpdate(self, elapsed)
    if ns.RefreshLatencyCache then
        local rawNow = GetCurrentTime()
        if rawNow >= nextLatencyRefreshAt then
            ns.RefreshLatencyCache()
            nextLatencyRefreshAt = rawNow + LATENCY_REFRESH_INTERVAL
        end
    end
    ns.OnUpdate(elapsed)
end

function ns.SetUpdateEnabled(enabled)
    if enabled then
        if ns.RefreshLatencyCache then
            ns.RefreshLatencyCache()
        end
        nextLatencyRefreshAt = 0
        frame:SetScript("OnUpdate", UpdateFrameOnUpdate)
    else
        nextLatencyRefreshAt = 0
        frame:SetScript("OnUpdate", nil)
    end
end

frame:RegisterEvent("ADDON_LOADED")

frame:SetScript("OnEvent", function (self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == addonName then
            local initOk, initErr = pcall(OnAddonLoaded)
            if not initOk then
                geterrorhandler()(string.format("SuperSwingTimer init: %s", tostring(initErr)))
            end
            RegisterEvents()
        end
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        ns.HandleCLEU()
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        ns.HandleSpellcastSucceeded(...)
        if ns.playerClass == "SHAMAN" and ns.HandleWeavingSpellcast then
            ns.HandleWeavingSpellcast(event, ...)
        end
    elseif event == "UNIT_SPELLCAST_START" then
        if ns.HandleSpellcastStart then
            ns.HandleSpellcastStart(...)
        end
        if ns.playerClass == "SHAMAN" and ns.HandleWeavingSpellcast then
            ns.HandleWeavingSpellcast(event, ...)
        end
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
        if ns.HandleSpellcastChannelStart then
            ns.HandleSpellcastChannelStart(...)
        end
        if ns.playerClass == "SHAMAN" and ns.HandleWeavingSpellcast then
            ns.HandleWeavingSpellcast(event, ...)
        end
    elseif event == "UNIT_SPELLCAST_STOP" then
        if ns.HandleSpellcastStop then
            ns.HandleSpellcastStop(...)
        end
        if ns.playerClass == "SHAMAN" and ns.HandleWeavingSpellcast then
            ns.HandleWeavingSpellcast(event, ...)
        end
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        if ns.HandleSpellcastChannelStop then
            ns.HandleSpellcastChannelStop(...)
        end
        if ns.playerClass == "SHAMAN" and ns.HandleWeavingSpellcast then
            ns.HandleWeavingSpellcast(event, ...)
        end
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" then
        if ns.HandleSpellcastInterruptedOrFailed then
            ns.HandleSpellcastInterruptedOrFailed(...)
        end
        if ns.playerClass == "SHAMAN" and ns.HandleWeavingSpellcast then
            ns.HandleWeavingSpellcast(event, ...)
        end
    elseif event == "UNIT_SPELLCAST_DELAYED" then
        if ns.HandleSpellcastDelayed then
            ns.HandleSpellcastDelayed(...)
        end
        if ns.playerClass == "SHAMAN" and ns.HandleWeavingSpellcast then
            ns.HandleWeavingSpellcast(event, ...)
        end
    elseif event == "PLAYER_STARTED_MOVING" then
        ns.isMoving = true
        if ns.UpdateCastZoneVisual then
            ns.UpdateCastZoneVisual()
        end
    elseif event == "PLAYER_STOPPED_MOVING" then
        ns.isMoving = false
        if ns.RefreshLatencyCache then
            ns.RefreshLatencyCache()
        end
        ns.lastStoppedMovingAt = GetCurrentTime()
        if ns.UpdateCastZoneVisual then
            ns.UpdateCastZoneVisual()
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        if ns.RefreshEnemyTarget then
            ns.RefreshEnemyTarget()
        end
        if ns.playerClass == "SHAMAN" and ns.UpdateShamanFlameShockBar then
            ns.UpdateShamanFlameShockBar(true)
        end
        if ns.playerClass == "WARRIOR" and ns.UpdateWarriorDeepWoundsBar then
            ns.UpdateWarriorDeepWoundsBar(true)
        end
        if ns.playerClass == "DRUID" and ns.UpdateDruidMangleBar then
            ns.UpdateDruidMangleBar(true)
        end
        if ns.playerClass == "DRUID" and ns.UpdateDruidRipBar then
            ns.UpdateDruidRipBar(true)
        end
        if ns.playerClass == "DRUID" and ns.UpdateDruidRakeBar then
            ns.UpdateDruidRakeBar(true)
        end
        if ns.playerClass == "ROGUE" and ns.UpdateRogueRuptureBar then
            ns.UpdateRogueRuptureBar(true)
        end
        if ns.playerClass == "HUNTER" and ns.UpdateHunterSerpentStingBar then
            ns.UpdateHunterSerpentStingBar(true)
        end
        if ns.playerClass == "PALADIN" and ns.UpdatePaladinJudgementBar then
            ns.UpdatePaladinJudgementBar(true)
        end
        if ns.playerClass == "PALADIN" and ns.UpdatePaladinSealVengeanceBar then
            ns.UpdatePaladinSealVengeanceBar(true)
        end
        if ns.playerClass == "WARRIOR" and ns.UpdateWarriorSunderArmorBar then
            ns.UpdateWarriorSunderArmorBar(true)
        end
        if ns.playerClass == "ROGUE" and ns.UpdateRogueExposeArmorBar then
            ns.UpdateRogueExposeArmorBar(true)
        end
        if ns.playerClass == "HUNTER" and ns.UpdateHunterWingClipBar then
            ns.UpdateHunterWingClipBar(true)
        end
        if ns.playerClass == "HUNTER" and ns.UpdateHunterConcussionShotBar then
            ns.UpdateHunterConcussionShotBar(true)
        end
        if ns.playerClass == "HUNTER" and ns.UpdateHunterImmolationTrapBar then
            ns.UpdateHunterImmolationTrapBar(true)
        end
        if ns.playerClass == "HUNTER" and ns.UpdateHunterExplosiveTrapBar then
            ns.UpdateHunterExplosiveTrapBar(true)
        end
        if ((ns.playerInCombat == true) or (InCombatLockdown and InCombatLockdown())) and ns.ApplyVisibility then
            ns.ApplyVisibility()
        end
    elseif event == "UNIT_ATTACK_SPEED" then
        local unit = ...
        if unit == "player" then
            ns.SyncMeleeTimerSpeed("mh", nil, true)
            ns.SyncMeleeTimerSpeed("oh", nil, true)
        elseif unit == "target" and ns.SyncMeleeTimerSpeed then
            ns.SyncMeleeTimerSpeed("enemy", nil, true)
        end
    elseif event == "UNIT_AURA" then
        local unit = ...
        if unit == "player" then
            ns.SanityCheckTimers()
            if ns.playerClass == "SHAMAN" and ns.UpdateLightningShieldVisual then
                ns.UpdateLightningShieldVisual()
            end
            if ns.playerClass == "WARRIOR" and ns.UpdateWarriorShieldBlockBar then
                ns.UpdateWarriorShieldBlockBar(0, true)
            end
            if ns.playerClass == "ROGUE" and ns.HandleRogueSliceAndDiceAura then
                ns.HandleRogueSliceAndDiceAura(unit)
            end
        elseif unit == "target" and ns.playerClass == "SHAMAN" and ns.UpdateShamanFlameShockBar then
            ns.UpdateShamanFlameShockBar(true)
        elseif unit == "target" and ns.playerClass == "WARRIOR" and ns.UpdateWarriorDeepWoundsBar then
            ns.UpdateWarriorDeepWoundsBar(true)
        elseif unit == "target" and ns.playerClass == "DRUID" and ns.UpdateDruidMangleBar then
            ns.UpdateDruidMangleBar(true)
        elseif unit == "target" and ns.playerClass == "DRUID" and ns.UpdateDruidRipBar then
            ns.UpdateDruidRipBar(true)
        elseif unit == "target" and ns.playerClass == "DRUID" and ns.UpdateDruidRakeBar then
            ns.UpdateDruidRakeBar(true)
        elseif unit == "target" and ns.playerClass == "ROGUE" and ns.UpdateRogueRuptureBar then
            ns.UpdateRogueRuptureBar(true)
        elseif unit == "target" and ns.playerClass == "HUNTER" and ns.UpdateHunterSerpentStingBar then
            ns.UpdateHunterSerpentStingBar(true)
        elseif unit == "target" and ns.playerClass == "PALADIN" and ns.UpdatePaladinJudgementBar then
            ns.UpdatePaladinJudgementBar(true)
        elseif unit == "target" and ns.playerClass == "PALADIN" and ns.UpdatePaladinSealVengeanceBar then
            ns.UpdatePaladinSealVengeanceBar(true)
        elseif unit == "target" and ns.playerClass == "WARRIOR" and ns.UpdateWarriorSunderArmorBar then
            ns.UpdateWarriorSunderArmorBar(true)
        elseif unit == "target" and ns.playerClass == "ROGUE" and ns.UpdateRogueExposeArmorBar then
            ns.UpdateRogueExposeArmorBar(true)
        elseif unit == "target" and ns.playerClass == "HUNTER" and ns.UpdateHunterWingClipBar then
            ns.UpdateHunterWingClipBar(true)
        elseif unit == "target" and ns.playerClass == "HUNTER" and ns.UpdateHunterConcussionShotBar then
            ns.UpdateHunterConcussionShotBar(true)
        elseif unit == "target" and ns.playerClass == "HUNTER" and ns.UpdateHunterImmolationTrapBar then
            ns.UpdateHunterImmolationTrapBar(true)
        elseif unit == "target" and ns.playerClass == "HUNTER" and ns.UpdateHunterExplosiveTrapBar then
            ns.UpdateHunterExplosiveTrapBar(true)
        end
    elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT" then
        local unit, powerType = ...
        if ns.playerClass == "ROGUE" and unit == "player"
            and ns.HandleRogueEnergyPowerUpdate and (powerType == nil or powerType == "ENERGY") then
            ns.HandleRogueEnergyPowerUpdate(unit, powerType)
        elseif ns.playerClass == "DRUID" and unit == "player"
            and ns.HandleDruidEnergyPowerUpdate and (powerType == nil or powerType == "ENERGY") then
            ns.HandleDruidEnergyPowerUpdate(unit, powerType)
        end
    elseif event == "UNIT_RANGEDDAMAGE" then
        local unit = ...
        if unit == "player" then
            ns.SyncRangedTimerSpeed(nil, true)
        end
    elseif event == "SPELL_UPDATE_COOLDOWN" then
        if ns.playerClass == "HUNTER" and ns.GetAutoShotCooldown then
            if ns.IsHunterRangedPinnedByMovement and ns.IsHunterRangedPinnedByMovement() then
                if ns.UpdateCastZoneVisual then
                    ns.UpdateCastZoneVisual()
                end
                return
            end
            local autoRepeatActive = ns.IsHunterAutoRepeatActive and ns.IsHunterAutoRepeatActive()
                or (ns.hunterAutoRepeatActive == true)
            ns.hunterAutoRepeatActive = autoRepeatActive
            local _, autoShotDuration = ns.GetAutoShotCooldown()
            local rangedTimerActive = ns.timers.ranged and ns.timers.ranged.state == "swinging"
            if autoShotDuration and autoShotDuration > 0 and (autoRepeatActive or rangedTimerActive) then
                if ns.timers.ranged and ns.timers.ranged.state == "swinging" then
                    ns.SyncRangedTimerSpeed(nil, true)
                elseif autoRepeatActive then
                    ns.StartRangedSwing()
                end
                if ns.ApplyVisibility then
                    ns.ApplyVisibility()
                end
            end
        end
    elseif event == "UNIT_INVENTORY_CHANGED" then
        ns.UpdateOHBar()
        ns.SanityCheckTimers()
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        local slot = ...
        ns.UpdateOHBar()
        ns.SanityCheckTimers(true)
        if ns.playerClass == "PALADIN" and slot == 18 and ns.HandlePaladinLibramEquipmentChanged then
            ns.HandlePaladinLibramEquipmentChanged(slot)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        local isInitialLogin, isReloadingUi = ...
        ns.playerInCombat = false
        ns.OnPlayerEnteringWorld(isInitialLogin, isReloadingUi)
        if ns.playerClass == "HUNTER" and ns.IsHunterAutoRepeatActive then
            ns.hunterAutoRepeatActive = ns.IsHunterAutoRepeatActive()
        end
        if ns.RefreshEnemyTarget then
            ns.RefreshEnemyTarget()
        end
        if ns.playerClass == "ROGUE" and ns.HandleRogueEnergyPowerUpdate then
            ns.HandleRogueEnergyPowerUpdate("player", "ENERGY")
        elseif ns.playerClass == "DRUID" and ns.HandleDruidEnergyPowerUpdate then
            ns.HandleDruidEnergyPowerUpdate("player", "ENERGY")
        end
        if ns.ClearWeavePreview then
            ns.ClearWeavePreview()
        end
    elseif event == "SPELLS_CHANGED" then
        if ns.playerClass == "SHAMAN" and ns.RebuildWeaveSpellCatalog then
            ns.RebuildWeaveSpellCatalog()
        end
    elseif event == "START_AUTOREPEAT_SPELL" then
        -- Hunter starts auto-shooting
        if ns.playerClass == "HUNTER" then
            ns.hunterAutoRepeatActive = true
            if ns.timers.ranged and ns.timers.ranged.state ~= "swinging" then
                ns.StartRangedSwing()
            end
            if ns.ApplyVisibility then
                ns.ApplyVisibility()
            elseif ns.rangedBar then
                ns.rangedBar:SetAlpha(1)
            end
        end
    elseif event == "STOP_AUTOREPEAT_SPELL" then
        if ns.playerClass == "HUNTER" then
            ns.hunterAutoRepeatActive = ns.IsHunterAutoRepeatActive and ns.IsHunterAutoRepeatActive(false) or false
            if ns.UpdateCastZoneVisual then
                ns.UpdateCastZoneVisual()
            end
        end
        if ns.ApplyVisibility then
            ns.ApplyVisibility()
        elseif ns.rangedBar then
            ns.rangedBar:SetAlpha(0)
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        ns.playerInCombat = true
        ns.ShowBars()
        if ns.playerClass == "WARRIOR" then
            if ns.UpdateWarriorRageBar then
                ns.UpdateWarriorRageBar()
            end
            if ns.UpdateWarriorShieldBlockBar then
                ns.UpdateWarriorShieldBlockBar(0, true)
            end
        end
        ns.StartSanityTicker()
    elseif event == "PLAYER_REGEN_ENABLED" then
        ns.playerInCombat = false
        if ns.playerClass == "WARRIOR" and ns.UpdateWarriorRageBar then
            ns.UpdateWarriorRageBar()
        end
        ns.warriorOverpowerProcUntil = nil
        ns.casting = false
        ns.channeling = false
        ns.channelingSpellId = nil
        ns.currentCastSpellId = nil
        ns.currentCastStartTime = nil
        ns.lastGcdTime = nil
        ns.gcdDuration = ns.GetGcdDuration and ns.GetGcdDuration() or 1.5
        ns.gcdActive = false
        ns.preventSwingReset = false
        ns.pauseSwingTime = nil
        if ns.ClearHunterCastState then
            ns.ClearHunterCastState(true)
        end
        ns.hunterAutoRepeatActive = false
        ns.StopSanityTicker()
        ns.HideBars()
        if ns.ClearPendingMeleeQueueState then
            ns.ClearPendingMeleeQueueState()
        end
        ns.ResetTimer("mh")
        ns.ResetTimer("oh")
        ns.ResetTimer("ranged")
        ns.ResetTimer("enemy")
        ns.lastStoppedMovingAt = nil
        ns.extraAttackPending = 0
        if ns.ClearWeavePreview then
            ns.ClearWeavePreview()
        end
    elseif event == "UPDATE_SHAPESHIFT_FORM" then
        -- Druid form label update: fire for ALL forms, not just Caster.
        -- CLEU also fires for form changes but UPDATE_SHAPESHIFT_FORM is more
        -- reliable for immediate feedback. Pass the form index directly;
        -- OnDruidFormChange handles both spell IDs (from CLEU) and form indices.
        if ns.OnDruidFormChange then
            local form = GetShapeshiftForm and GetShapeshiftForm() or 0
            ns.OnDruidFormChange(form)
        end
    end
end)

ns.SetUpdateEnabled(ns.HasActiveTimers())
