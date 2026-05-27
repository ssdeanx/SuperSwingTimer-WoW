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
ns.isMoving            = false
ns.lastStoppedMovingAt = nil
ns.barTestActive       = false
ns.barTestTimer        = nil
ns.playerClass         = nil
ns.classConfig         = nil
ns.druidFormChangeTime = nil
ns.playerInCombat      = false
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
				version   = 2,
				showMH    = true,
				showOH    = true,
				positions = {
					mh     = ns.DB_DEFAULTS.positions.mh,
					oh     = ns.DB_DEFAULTS.positions.oh,
					ranged = {
						point         = legacyHunterDB.point or "CENTER",
						relativePoint = legacyHunterDB.relativePoint or "CENTER",
						x             = legacyHunterDB.x or 0,
						y             = legacyHunterDB.y or -100,
					},
				},
			}
			HunterTimerDB = nil -- clear legacy SavedVariable
		end
	end

	-- Fresh install
		if not SuperSwingTimerDB then
		SuperSwingTimerDB = {
			version                    = ns.DB_DEFAULTS.version or 43,
			showMH                     = ns.DB_DEFAULTS.showMH,
			showOH                     = ns.DB_DEFAULTS.showOH,
			showRanged                 = ns.DB_DEFAULTS.showRanged,
			showHunterRangeHelper      = ns.DB_DEFAULTS.showHunterRangeHelper,
			showEnemy                  = ns.DB_DEFAULTS.showEnemy,
			showRogueSinisterAssist    = ns.DB_DEFAULTS.showRogueSinisterAssist,
			showRogueEnergyTick        = ns.DB_DEFAULTS.showRogueEnergyTick,
			showRogueComboPoints       = ns.DB_DEFAULTS.showRogueComboPoints,
			showRogueSliceAndDice      = ns.DB_DEFAULTS.showRogueSliceAndDice,
			showWeaveAssist            = ns.DB_DEFAULTS.showWeaveAssist,
			showPaladinSealColor       = ns.DB_DEFAULTS.showPaladinSealColor,
			showPaladinSealLabel       = ns.DB_DEFAULTS.showPaladinSealLabel,
			showPaladinJudgementMarker = ns.DB_DEFAULTS.showPaladinJudgementMarker,
			showPaladinTwistFlash      = ns.DB_DEFAULTS.showPaladinTwistFlash,
			showWarriorRageBar         = ns.DB_DEFAULTS.showWarriorRageBar,
			showWarriorRageProtection  = ns.DB_DEFAULTS.showWarriorRageProtection,
			showDruidFormColors        = ns.DB_DEFAULTS.showDruidFormColors,
			showDruidPowerShiftBar     = ns.DB_DEFAULTS.showDruidPowerShiftBar,
			showDruidEnergyTickBar     = ns.DB_DEFAULTS.showDruidEnergyTickBar,
			useClassColors             = ns.DB_DEFAULTS.useClassColors,
			indicatorBlendMode         = ns.DB_DEFAULTS.indicatorBlendMode,
			weaveSpellFamilies         = {
				LB  = ns.DB_DEFAULTS.weaveSpellFamilies.LB,
				CL  = ns.DB_DEFAULTS.weaveSpellFamilies.CL,
				HW  = ns.DB_DEFAULTS.weaveSpellFamilies.HW,
				LHW = ns.DB_DEFAULTS.weaveSpellFamilies.LHW,
				CH  = ns.DB_DEFAULTS.weaveSpellFamilies.CH,
			},
			barWidth                   = ns.DB_DEFAULTS.barWidth,
			barHeight                  = ns.DB_DEFAULTS.barHeight,
			hunterCastBarHeight        = ns.DB_DEFAULTS.hunterCastBarHeight,
			rogueSliceAndDiceBarHeight = ns.DB_DEFAULTS.rogueSliceAndDiceBarHeight,
			rogueEnergyTickBarWidth    = ns.DB_DEFAULTS.rogueEnergyTickBarWidth,
			warriorShieldBlockBarHeight = ns.DB_DEFAULTS.warriorShieldBlockBarHeight,
			hunterRangeHelperWidth     = ns.DB_DEFAULTS.hunterRangeHelperWidth,
			hunterRapidFireBarHeight   = ns.DB_DEFAULTS.hunterRapidFireBarHeight,
			druidPowerShiftBarHeight   = ns.DB_DEFAULTS.druidPowerShiftBarHeight,
			druidEnergyTickBarWidth    = ns.DB_DEFAULTS.druidEnergyTickBarWidth,
			rogueAdrenalineRushBarHeight = ns.DB_DEFAULTS.rogueAdrenalineRushBarHeight,
			barTexture                 = ns.DB_DEFAULTS.barTexture,
			barTextureLayer            = ns.DB_DEFAULTS.barTextureLayer,
			rangedBarTexture           = ns.DB_DEFAULTS.rangedBarTexture,
			sparkTexture               = ns.DB_DEFAULTS.sparkTexture,
			sparkTextureLayer          = ns.DB_DEFAULTS.sparkTextureLayer,
			weaveSparkTexture          = ns.DB_DEFAULTS.weaveSparkTexture,
			weaveSparkTextureLayer     = ns.DB_DEFAULTS.weaveSparkTextureLayer,
			weaveSparkWidth            = ns.DB_DEFAULTS.weaveSparkWidth,
			weaveSparkHeight           = ns.DB_DEFAULTS.weaveSparkHeight,
			weaveSparkAlpha            = ns.DB_DEFAULTS.weaveSparkAlpha,
			weaveTriangleTopTexture    = ns.DB_DEFAULTS.weaveTriangleTopTexture,
			weaveTriangleBottomTexture = ns.DB_DEFAULTS.weaveTriangleBottomTexture,
			weaveTriangleTextureLayer  = ns.DB_DEFAULTS.weaveTriangleTextureLayer,
			weaveTriangleSize          = ns.DB_DEFAULTS.weaveTriangleSize,
			weaveTriangleGap           = ns.DB_DEFAULTS.weaveTriangleGap,
			weaveTriangleAlpha         = ns.DB_DEFAULTS.weaveTriangleAlpha,
			weaveMarkerLayer           = ns.DB_DEFAULTS.weaveMarkerLayer,
			sparkWidth                 = ns.DB_DEFAULTS.sparkWidth,
			sparkHeight                = ns.DB_DEFAULTS.sparkHeight,
			barBorderSize              = ns.DB_DEFAULTS.barBorderSize,
			barBackgroundAlpha         = ns.DB_DEFAULTS.barBackgroundAlpha,
			barBackgroundColor         = {
				r = ns.DB_DEFAULTS.barBackgroundColor.r,
				g = ns.DB_DEFAULTS.barBackgroundColor.g,
				b = ns.DB_DEFAULTS.barBackgroundColor.b,
				a = ns.DB_DEFAULTS.barBackgroundColor.a,
			},
			barBorderColor             = {
				r = ns.DB_DEFAULTS.barBorderColor.r,
				g = ns.DB_DEFAULTS.barBorderColor.g,
				b = ns.DB_DEFAULTS.barBorderColor.b,
				a = ns.DB_DEFAULTS.barBorderColor.a,
			},
			sparkAlpha                 = ns.DB_DEFAULTS.sparkAlpha,
			sparkColor                 = {
				r = ns.DB_DEFAULTS.sparkColor.r,
				g = ns.DB_DEFAULTS.sparkColor.g,
				b = ns.DB_DEFAULTS.sparkColor.b,
				a = ns.DB_DEFAULTS.sparkColor.a,
			},
			minimalMode                = ns.DB_DEFAULTS.minimalMode,
			lockBars                   = ns.DB_DEFAULTS.lockBars,
			colors                     = {},
			positions                  = {
				mh     = { point = ns.DB_DEFAULTS.positions.mh.point, relativePoint = ns.DB_DEFAULTS.positions.mh.relativePoint, x = ns.DB_DEFAULTS.positions.mh.x, y = ns.DB_DEFAULTS.positions.mh.y },
				oh     = { point = ns.DB_DEFAULTS.positions.oh.point, relativePoint = ns.DB_DEFAULTS.positions.oh.relativePoint, x = ns.DB_DEFAULTS.positions.oh.x, y = ns.DB_DEFAULTS.positions.oh.y },
				ranged = { point = ns.DB_DEFAULTS.positions.ranged.point, relativePoint = ns.DB_DEFAULTS.positions.ranged.relativePoint, x = ns.DB_DEFAULTS.positions.ranged.x, y = ns.DB_DEFAULTS.positions.ranged.y },
				enemy  = { point = ns.DB_DEFAULTS.positions.enemy.point, relativePoint = ns.DB_DEFAULTS.positions.enemy.relativePoint, x = ns.DB_DEFAULTS.positions.enemy.x, y = ns.DB_DEFAULTS.positions.enemy.y },
			},
		}
		for key, def in pairs(ns.DB_DEFAULTS.colors) do
			SuperSwingTimerDB.colors[key] = { r = def.r, g = def.g, b = def.b, a = def.a }
		end
	end

	-- Fill any missing fields for upgrades
	SuperSwingTimerDB.version = SuperSwingTimerDB.version or 10

	local function IsVisibleDefaultColor(color)
		return color and math.abs((color.r or 0) - 0.25) < 0.001 and math.abs((color.g or 0) - 0.72) < 0.001 and
		math.abs((color.b or 0) - 1.00) < 0.001
	end
	SuperSwingTimerDB.showMH             = (SuperSwingTimerDB.showMH ~= false)
	SuperSwingTimerDB.showOH             = (SuperSwingTimerDB.showOH ~= false)
	SuperSwingTimerDB.showRanged         = (SuperSwingTimerDB.showRanged ~= false)
	SuperSwingTimerDB.showHunterRangeHelper = (SuperSwingTimerDB.showHunterRangeHelper ~= false)
	SuperSwingTimerDB.showEnemy          = (SuperSwingTimerDB.showEnemy ~= false)
	SuperSwingTimerDB.showRogueSinisterAssist = (SuperSwingTimerDB.showRogueSinisterAssist ~= false)
	SuperSwingTimerDB.showRogueEnergyTick = (SuperSwingTimerDB.showRogueEnergyTick ~= false)
	SuperSwingTimerDB.showRogueComboPoints = (SuperSwingTimerDB.showRogueComboPoints ~= false)
	SuperSwingTimerDB.showRogueSliceAndDice = (SuperSwingTimerDB.showRogueSliceAndDice ~= false)
	SuperSwingTimerDB.showWeaveAssist    = (SuperSwingTimerDB.showWeaveAssist ~= false)
	SuperSwingTimerDB.showPaladinSealColor       = (SuperSwingTimerDB.showPaladinSealColor ~= false)
	SuperSwingTimerDB.showPaladinSealLabel       = (SuperSwingTimerDB.showPaladinSealLabel ~= false)
	SuperSwingTimerDB.showPaladinJudgementMarker = (SuperSwingTimerDB.showPaladinJudgementMarker ~= false)
	SuperSwingTimerDB.showPaladinTwistFlash      = (SuperSwingTimerDB.showPaladinTwistFlash ~= false)
	SuperSwingTimerDB.showWarriorRageBar         = (SuperSwingTimerDB.showWarriorRageBar ~= false)
	SuperSwingTimerDB.showDruidFormColors        = (SuperSwingTimerDB.showDruidFormColors ~= false)
	SuperSwingTimerDB.showWarriorShieldBlockBar  = (SuperSwingTimerDB.showWarriorShieldBlockBar ~= false)
	-- Phase 1 toggle defaults
	SuperSwingTimerDB.showSwingFlash            = (SuperSwingTimerDB.showSwingFlash ~= false)
	SuperSwingTimerDB.showGcdTicker             = (SuperSwingTimerDB.showGcdTicker ~= false)
	SuperSwingTimerDB.showDruidRageDim          = (SuperSwingTimerDB.showDruidRageDim ~= false)
	SuperSwingTimerDB.showDruidPowerShiftBar     = (SuperSwingTimerDB.showDruidPowerShiftBar ~= false)
	SuperSwingTimerDB.showDruidEnergyTickBar     = (SuperSwingTimerDB.showDruidEnergyTickBar ~= false)
	SuperSwingTimerDB.showRogueEnergyCountdown  = (SuperSwingTimerDB.showRogueEnergyCountdown ~= false)
	-- Phase 2 toggle defaults
	SuperSwingTimerDB.showHunterRapidFireBar     = (SuperSwingTimerDB.showHunterRapidFireBar ~= false)
	SuperSwingTimerDB.showWarriorFlurryCounter   = (SuperSwingTimerDB.showWarriorFlurryCounter ~= false)
	SuperSwingTimerDB.showRogueAdrenalineRushBar = (SuperSwingTimerDB.showRogueAdrenalineRushBar ~= false)
	SuperSwingTimerDB.showDruidOmenGlow          = (SuperSwingTimerDB.showDruidOmenGlow ~= false)
	SuperSwingTimerDB.showShamanWindfuryIcd      = (SuperSwingTimerDB.showShamanWindfuryIcd ~= false)
	SuperSwingTimerDB.showDruidRavageCue         = (SuperSwingTimerDB.showDruidRavageCue ~= false)
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
			SuperSwingTimerDB.positions[slot] = { point = def.point, relativePoint = def.relativePoint, x = def.x, y =
			def.y }
		end
	end
	SuperSwingTimerDB.colors = SuperSwingTimerDB.colors or {}
	for key, def in pairs(ns.DB_DEFAULTS.colors) do
		if not SuperSwingTimerDB.colors[key] then
			SuperSwingTimerDB.colors[key] = { r = def.r, g = def.g, b = def.b, a = def.a }
		end
	end
	SuperSwingTimerDB.sparkColor = SuperSwingTimerDB.sparkColor or {
		r = ns.DB_DEFAULTS.sparkColor.r,
		g = ns.DB_DEFAULTS.sparkColor.g,
		b = ns.DB_DEFAULTS.sparkColor.b,
		a = SuperSwingTimerDB.sparkAlpha ~= nil and SuperSwingTimerDB.sparkAlpha or ns.DB_DEFAULTS.sparkColor.a,
	}
	if SuperSwingTimerDB.sparkColor.a == nil then
		SuperSwingTimerDB.sparkColor.a = SuperSwingTimerDB.sparkAlpha or ns.DB_DEFAULTS.sparkColor.a
	end
	SuperSwingTimerDB.sparkAlpha = SuperSwingTimerDB.sparkColor.a or SuperSwingTimerDB.sparkAlpha or
	ns.DB_DEFAULTS.sparkAlpha

	-- v2 â†’ v3: bar dimensions + colors
	if (SuperSwingTimerDB.version or 0) < 3 then
		SuperSwingTimerDB.barWidth  = SuperSwingTimerDB.barWidth or ns.DB_DEFAULTS.barWidth
		SuperSwingTimerDB.barHeight = SuperSwingTimerDB.barHeight or ns.DB_DEFAULTS.barHeight
		SuperSwingTimerDB.colors    = SuperSwingTimerDB.colors or {}
		for key, def in pairs(ns.DB_DEFAULTS.colors) do
			if not SuperSwingTimerDB.colors[key] then
				SuperSwingTimerDB.colors[key] = { r = def.r, g = def.g, b = def.b, a = def.a }
			end
		end
		SuperSwingTimerDB.version = 3
	end

	-- v3 â†’ v5: bar texture selection
	if (SuperSwingTimerDB.version or 0) < 5 then
		SuperSwingTimerDB.barTexture = SuperSwingTimerDB.barTexture or ns.DB_DEFAULTS.barTexture
		SuperSwingTimerDB.version = 5
	end

	-- v5 â†’ v6: spark texture and sizing
	if (SuperSwingTimerDB.version or 0) < 6 then
		SuperSwingTimerDB.sparkTexture     = SuperSwingTimerDB.sparkTexture or ns.DB_DEFAULTS.sparkTexture
		SuperSwingTimerDB.weaveMarkerLayer = SuperSwingTimerDB.weaveMarkerLayer or ns.DB_DEFAULTS.weaveMarkerLayer
		SuperSwingTimerDB.sparkWidth       = SuperSwingTimerDB.sparkWidth or ns.DB_DEFAULTS.sparkWidth
		SuperSwingTimerDB.sparkHeight      = SuperSwingTimerDB.sparkHeight or ns.DB_DEFAULTS.sparkHeight
		SuperSwingTimerDB.version          = 6
	end

	-- v6 â†’ v7: texture layers, alpha controls, and UI quality-of-life settings
	if (SuperSwingTimerDB.version or 0) < 7 then
		SuperSwingTimerDB.barTextureLayer = SuperSwingTimerDB.barTextureLayer or ns.DB_DEFAULTS.barTextureLayer
		SuperSwingTimerDB.sparkTextureLayer = SuperSwingTimerDB.sparkTextureLayer or ns.DB_DEFAULTS.sparkTextureLayer
		SuperSwingTimerDB.barBackgroundAlpha = SuperSwingTimerDB.barBackgroundAlpha ~= nil and
		SuperSwingTimerDB.barBackgroundAlpha or ns.DB_DEFAULTS.barBackgroundAlpha
		SuperSwingTimerDB.sparkAlpha = SuperSwingTimerDB.sparkAlpha ~= nil and SuperSwingTimerDB.sparkAlpha or
		ns.DB_DEFAULTS.sparkAlpha
		SuperSwingTimerDB.minimalMode = SuperSwingTimerDB.minimalMode == true
		SuperSwingTimerDB.lockBars = SuperSwingTimerDB.lockBars == true
		SuperSwingTimerDB.version = 7
	end

	-- v7 â†’ v8: weave spark and dual triangle marker settings
	if (SuperSwingTimerDB.version or 0) < 8 then
		SuperSwingTimerDB.weaveSparkTexture = SuperSwingTimerDB.weaveSparkTexture or ns.DB_DEFAULTS.weaveSparkTexture
		SuperSwingTimerDB.weaveSparkTextureLayer = SuperSwingTimerDB.weaveSparkTextureLayer or
		ns.DB_DEFAULTS.weaveSparkTextureLayer
		SuperSwingTimerDB.weaveSparkWidth = SuperSwingTimerDB.weaveSparkWidth or ns.DB_DEFAULTS.weaveSparkWidth
		SuperSwingTimerDB.weaveSparkHeight = SuperSwingTimerDB.weaveSparkHeight or ns.DB_DEFAULTS.weaveSparkHeight
		SuperSwingTimerDB.weaveSparkAlpha = SuperSwingTimerDB.weaveSparkAlpha ~= nil and
		SuperSwingTimerDB.weaveSparkAlpha or ns.DB_DEFAULTS.weaveSparkAlpha
		SuperSwingTimerDB.weaveTriangleTopTexture = SuperSwingTimerDB.weaveTriangleTopTexture or
		ns.DB_DEFAULTS.weaveTriangleTopTexture
		SuperSwingTimerDB.weaveTriangleBottomTexture = SuperSwingTimerDB.weaveTriangleBottomTexture or
		ns.DB_DEFAULTS.weaveTriangleBottomTexture
		SuperSwingTimerDB.weaveTriangleTextureLayer = SuperSwingTimerDB.weaveTriangleTextureLayer or
		ns.DB_DEFAULTS.weaveTriangleTextureLayer
		SuperSwingTimerDB.weaveTriangleSize = SuperSwingTimerDB.weaveTriangleSize or ns.DB_DEFAULTS.weaveTriangleSize
		SuperSwingTimerDB.weaveTriangleGap = SuperSwingTimerDB.weaveTriangleGap or ns.DB_DEFAULTS.weaveTriangleGap
		SuperSwingTimerDB.weaveTriangleAlpha = SuperSwingTimerDB.weaveTriangleAlpha ~= nil and
		SuperSwingTimerDB.weaveTriangleAlpha or ns.DB_DEFAULTS.weaveTriangleAlpha
		SuperSwingTimerDB.version = 8
	end

	-- v8 â†’ v9: visible default bar colors for fresh installs / old black saves
	if (SuperSwingTimerDB.version or 0) < 9 then
		SuperSwingTimerDB.colors = SuperSwingTimerDB.colors or {}
		for key, def in pairs(ns.DB_DEFAULTS.colors) do
			local color = SuperSwingTimerDB.colors[key]
			if not color or (color.r == 0 and color.g == 0 and color.b == 0 and (color.a == nil or color.a == 1)) then
				SuperSwingTimerDB.colors[key] = { r = def.r, g = def.g, b = def.b, a = def.a }
			end
		end
		SuperSwingTimerDB.version = 9
	end

	-- v9 -> v10: restore the original dark gray bar palette unless the user already custom-tuned colors
	if (SuperSwingTimerDB.version or 0) < 10 then
		SuperSwingTimerDB.colors = SuperSwingTimerDB.colors or {}
		local colors = SuperSwingTimerDB.colors
		if IsVisibleDefaultColor(colors.mh) or not colors.mh then
			colors.mh = { r = 0, g = 0, b = 0, a = 1 }
		end
		if IsVisibleDefaultColor(colors.oh) or not colors.oh then
			colors.oh = { r = 0, g = 0, b = 0, a = 1 }
		end
		if IsVisibleDefaultColor(colors.ranged) or not colors.ranged then
			colors.ranged = { r = 0, g = 0, b = 0, a = 1 }
		end
		SuperSwingTimerDB.version = 10
	end

	-- v10 -> v11: smaller default weave markers and per-family weave toggles
	if (SuperSwingTimerDB.version or 0) < 11 then
		local function UpgradeWeaveDefault(currentValue, oldDefault, newDefault)
			if currentValue == nil or currentValue == oldDefault then
				return newDefault
			end
			return currentValue
		end

		SuperSwingTimerDB.weaveSparkWidth = UpgradeWeaveDefault(SuperSwingTimerDB.weaveSparkWidth, 14,
			ns.DB_DEFAULTS.weaveSparkWidth)
		SuperSwingTimerDB.weaveSparkHeight = UpgradeWeaveDefault(SuperSwingTimerDB.weaveSparkHeight, 30,
			ns.DB_DEFAULTS.weaveSparkHeight)
		SuperSwingTimerDB.weaveTriangleSize = UpgradeWeaveDefault(SuperSwingTimerDB.weaveTriangleSize, 14,
			ns.DB_DEFAULTS.weaveTriangleSize)
		SuperSwingTimerDB.weaveTriangleGap = UpgradeWeaveDefault(SuperSwingTimerDB.weaveTriangleGap, 2,
			ns.DB_DEFAULTS.weaveTriangleGap)

		SuperSwingTimerDB.weaveSpellFamilies = SuperSwingTimerDB.weaveSpellFamilies or {}
		for key, def in pairs(ns.DB_DEFAULTS.weaveSpellFamilies) do
			if SuperSwingTimerDB.weaveSpellFamilies[key] == nil then
				SuperSwingTimerDB.weaveSpellFamilies[key] = def
			end
		end

		SuperSwingTimerDB.version = 11
	end

	-- v11 -> v12: add indicator glow mode and class-color default toggle
	if (SuperSwingTimerDB.version or 0) < 12 then
		SuperSwingTimerDB.useClassColors = (SuperSwingTimerDB.useClassColors ~= false)
		SuperSwingTimerDB.indicatorBlendMode = SuperSwingTimerDB.indicatorBlendMode or ns.DB_DEFAULTS.indicatorBlendMode
		SuperSwingTimerDB.version = 12
	end

	-- v12 -> v13: separate ranged texture selection for hunters
	if (SuperSwingTimerDB.version or 0) < 13 then
		SuperSwingTimerDB.rangedBarTexture = SuperSwingTimerDB.rangedBarTexture or ns.DB_DEFAULTS.rangedBarTexture
		SuperSwingTimerDB.version = 13
	end

	-- v13 -> v14: seal twist becomes an opaque breakpoint line by default
	if (SuperSwingTimerDB.version or 0) < 14 then
		SuperSwingTimerDB.colors = SuperSwingTimerDB.colors or {}
		local sealTwist = SuperSwingTimerDB.colors.sealTwist
		local isLegacySealTwist = sealTwist and math.abs((sealTwist.r or 0) - 0) < 0.001
			and math.abs((sealTwist.g or 0) - 0.8) < 0.001
			and math.abs((sealTwist.b or 0) - 1) < 0.001
			and math.abs((sealTwist.a or 0) - 0.4) < 0.001

		if not sealTwist or isLegacySealTwist then
			SuperSwingTimerDB.colors.sealTwist = { r = 0, g = 0, b = 0, a = 1 }
		elseif sealTwist.a == nil then
			sealTwist.a = 1
		end

		SuperSwingTimerDB.version = 14
	end

	-- v14 -> v15: spark browser defaults and WeakAuras indicator textures
	if (SuperSwingTimerDB.version or 0) < 15 then
		if SuperSwingTimerDB.sparkTexture == nil or SuperSwingTimerDB.sparkTexture == "Interface\\CastingBar\\UI-CastingBar-Spark" then
			SuperSwingTimerDB.sparkTexture = ns.DB_DEFAULTS.sparkTexture
		end
		if SuperSwingTimerDB.weaveSparkTexture == nil or SuperSwingTimerDB.weaveSparkTexture == "Interface\\CastingBar\\UI-CastingBar-Spark" then
			SuperSwingTimerDB.weaveSparkTexture = ns.DB_DEFAULTS.weaveSparkTexture
		end
		if not SuperSwingTimerDB.sparkColor then
			SuperSwingTimerDB.sparkColor = {
				r = ns.DB_DEFAULTS.sparkColor.r,
				g = ns.DB_DEFAULTS.sparkColor.g,
				b = ns.DB_DEFAULTS.sparkColor.b,
				a = SuperSwingTimerDB.sparkAlpha or ns.DB_DEFAULTS.sparkColor.a,
			}
		elseif SuperSwingTimerDB.sparkColor.a == nil then
			SuperSwingTimerDB.sparkColor.a = SuperSwingTimerDB.sparkAlpha or ns.DB_DEFAULTS.sparkColor.a
		end
		SuperSwingTimerDB.sparkAlpha = SuperSwingTimerDB.sparkColor.a or SuperSwingTimerDB.sparkAlpha or
		ns.DB_DEFAULTS.sparkAlpha
		SuperSwingTimerDB.version = 15
	end

	-- v15 -> v16: compact spark sizes and thinner weave markers for the final release polish.
	if (SuperSwingTimerDB.version or 0) < 16 then
		local function UpgradeThinDefault(currentValue, oldDefault, newDefault)
			if currentValue == nil or currentValue == oldDefault then
				return newDefault
			end
			return currentValue
		end

		SuperSwingTimerDB.sparkWidth = UpgradeThinDefault(SuperSwingTimerDB.sparkWidth, 20, ns.DB_DEFAULTS.sparkWidth)
		SuperSwingTimerDB.sparkHeight = UpgradeThinDefault(SuperSwingTimerDB.sparkHeight, 44, ns.DB_DEFAULTS.sparkHeight)
		SuperSwingTimerDB.weaveSparkWidth = UpgradeThinDefault(SuperSwingTimerDB.weaveSparkWidth, 10,
			ns.DB_DEFAULTS.weaveSparkWidth)
		SuperSwingTimerDB.weaveSparkHeight = UpgradeThinDefault(SuperSwingTimerDB.weaveSparkHeight, 24,
			ns.DB_DEFAULTS.weaveSparkHeight)
		SuperSwingTimerDB.weaveTriangleSize = UpgradeThinDefault(SuperSwingTimerDB.weaveTriangleSize, 10,
			ns.DB_DEFAULTS.weaveTriangleSize)

		SuperSwingTimerDB.version = 16
	end

	-- v16 -> v17: bring the base spark width back up to 4px for the final polish pass.
	if (SuperSwingTimerDB.version or 0) < 17 then
		if SuperSwingTimerDB.sparkWidth == nil or SuperSwingTimerDB.sparkWidth == 3 then
			SuperSwingTimerDB.sparkWidth = ns.DB_DEFAULTS.sparkWidth
		end
		SuperSwingTimerDB.version = 17
	end

	-- v17 -> v18: keep the spark width at the 4px final-release default for installs
	-- that were already on the prior release before the width correction landed.
	if (SuperSwingTimerDB.version or 0) < 18 then
		if SuperSwingTimerDB.sparkWidth == nil or SuperSwingTimerDB.sparkWidth == 3 then
			SuperSwingTimerDB.sparkWidth = ns.DB_DEFAULTS.sparkWidth
		end
		SuperSwingTimerDB.version = 18
	end

	-- v18 -> v19: persist the configurable border size for the final UI polish pass.
	if (SuperSwingTimerDB.version or 0) < 19 then
		SuperSwingTimerDB.barBorderSize = SuperSwingTimerDB.barBorderSize or ns.DB_DEFAULTS.barBorderSize
		SuperSwingTimerDB.version = 19
	end

	-- v19 -> v20: add configurable bar background and border colors.
	if (SuperSwingTimerDB.version or 0) < 20 then
		SuperSwingTimerDB.barBackgroundColor = SuperSwingTimerDB.barBackgroundColor or {
			r = ns.DB_DEFAULTS.barBackgroundColor.r,
			g = ns.DB_DEFAULTS.barBackgroundColor.g,
			b = ns.DB_DEFAULTS.barBackgroundColor.b,
			a = SuperSwingTimerDB.barBackgroundAlpha ~= nil and SuperSwingTimerDB.barBackgroundAlpha or
			ns.DB_DEFAULTS.barBackgroundColor.a,
		}
		SuperSwingTimerDB.barBorderColor = SuperSwingTimerDB.barBorderColor or {
			r = ns.DB_DEFAULTS.barBorderColor.r,
			g = ns.DB_DEFAULTS.barBorderColor.g,
			b = ns.DB_DEFAULTS.barBorderColor.b,
			a = ns.DB_DEFAULTS.barBorderColor.a,
		}
		SuperSwingTimerDB.version = 20
	end

	-- v20 -> v21: change default colors to black (0,0,0)
	-- This resolves the "Yellow Bar" conflict where default bars looked like Heroic Strike indicators.
	if (SuperSwingTimerDB.version or 0) < 21 then
		SuperSwingTimerDB.version = 21
	end

	-- v21 -> v22: enforce white spark color and black bar defaults for final release.
	-- Also ensures useClassColors strictly defaults to false unless changed.
	if (SuperSwingTimerDB.version or 0) < 22 then
		SuperSwingTimerDB.colors = SuperSwingTimerDB.colors or {}
		local colors = SuperSwingTimerDB.colors
		colors.mh = { r = 0, g = 0, b = 0, a = 1 }
		colors.oh = { r = 0, g = 0, b = 0, a = 1 }
		colors.ranged = { r = 0, g = 0, b = 0, a = 1 }
		SuperSwingTimerDB.sparkColor = { r = 1, g = 1, b = 1, a = 1 }
		SuperSwingTimerDB.useClassColors = false
		SuperSwingTimerDB.version = 22
	end

	-- v22 -> v23: version bump for the final release line.
	if (SuperSwingTimerDB.version or 0) < 23 then
		SuperSwingTimerDB.version = 23
	end
	if (SuperSwingTimerDB.version or 0) < 24 then
		SuperSwingTimerDB.version = 24
	end

	-- v24 -> v25: add the enemy bar defaults and bring the stock spark width back to 3px.
	if (SuperSwingTimerDB.version or 0) < 25 then
		if SuperSwingTimerDB.sparkWidth == nil or math.abs((SuperSwingTimerDB.sparkWidth or 0) - 4) < 0.001 then
			SuperSwingTimerDB.sparkWidth = ns.DB_DEFAULTS.sparkWidth
		end
		SuperSwingTimerDB.version = 25
	end

	-- v25 -> v26: add configurable Auto Shot safe/unsafe colors.
	if (SuperSwingTimerDB.version or 0) < 26 then
		SuperSwingTimerDB.colors = SuperSwingTimerDB.colors or {}
		local colors = SuperSwingTimerDB.colors
		colors.autoShotSafe = colors.autoShotSafe or {
			r = ns.DB_DEFAULTS.colors.autoShotSafe.r,
			g = ns.DB_DEFAULTS.colors.autoShotSafe.g,
			b = ns.DB_DEFAULTS.colors.autoShotSafe.b,
			a = ns.DB_DEFAULTS.colors.autoShotSafe.a,
		}
		colors.autoShotUnsafe = colors.autoShotUnsafe or {
			r = ns.DB_DEFAULTS.colors.autoShotUnsafe.r,
			g = ns.DB_DEFAULTS.colors.autoShotUnsafe.g,
			b = ns.DB_DEFAULTS.colors.autoShotUnsafe.b,
			a = ns.DB_DEFAULTS.colors.autoShotUnsafe.a,
		}
		SuperSwingTimerDB.version = 26
	end

	-- v26 -> v27: add Rogue Sinister Strike helper defaults and color.
	if (SuperSwingTimerDB.version or 0) < 27 then
		SuperSwingTimerDB.showRogueSinisterAssist = (SuperSwingTimerDB.showRogueSinisterAssist ~= false)
		SuperSwingTimerDB.colors = SuperSwingTimerDB.colors or {}
		SuperSwingTimerDB.colors.rogueSinister = SuperSwingTimerDB.colors.rogueSinister or {
			r = ns.DB_DEFAULTS.colors.rogueSinister.r,
			g = ns.DB_DEFAULTS.colors.rogueSinister.g,
			b = ns.DB_DEFAULTS.colors.rogueSinister.b,
			a = ns.DB_DEFAULTS.colors.rogueSinister.a,
		}
		SuperSwingTimerDB.version = 27
	end

	-- v27 -> v28: slimmer default bar profile and Rogue energy tick helper.
	if (SuperSwingTimerDB.version or 0) < 28 then
		if SuperSwingTimerDB.barHeight == nil or math.abs((SuperSwingTimerDB.barHeight or 0) - 20) < 0.001 then
			SuperSwingTimerDB.barHeight = ns.DB_DEFAULTS.barHeight
		end
		if SuperSwingTimerDB.sparkHeight == nil or math.abs((SuperSwingTimerDB.sparkHeight or 0) - 20) < 0.001 then
			SuperSwingTimerDB.sparkHeight = ns.DB_DEFAULTS.sparkHeight
		end
		SuperSwingTimerDB.showRogueEnergyTick = (SuperSwingTimerDB.showRogueEnergyTick ~= false)
		SuperSwingTimerDB.colors = SuperSwingTimerDB.colors or {}
		SuperSwingTimerDB.colors.rogueEnergyTick = SuperSwingTimerDB.colors.rogueEnergyTick or {
			r = ns.DB_DEFAULTS.colors.rogueEnergyTick.r,
			g = ns.DB_DEFAULTS.colors.rogueEnergyTick.g,
			b = ns.DB_DEFAULTS.colors.rogueEnergyTick.b,
			a = ns.DB_DEFAULTS.colors.rogueEnergyTick.a,
		}
		SuperSwingTimerDB.version = 28
	end

	-- v28 -> v29: soften untouched Rogue SS cue alpha.
	if (SuperSwingTimerDB.version or 0) < 29 then
		SuperSwingTimerDB.colors = SuperSwingTimerDB.colors or {}
		local rogueCue = SuperSwingTimerDB.colors.rogueSinister
		if rogueCue
			and math.abs((rogueCue.r or 0) - 1) < 0.001
			and math.abs((rogueCue.g or 0) - 0) < 0.001
			and math.abs((rogueCue.b or 0) - 0) < 0.001
			and math.abs((rogueCue.a or 0) - 0.45) < 0.001 then
			rogueCue.a = ns.DB_DEFAULTS.colors.rogueSinister.a
		end
		SuperSwingTimerDB.version = 29
	end

	-- v29 -> v30: add Rogue Slice and Dice helper defaults and color.
	if (SuperSwingTimerDB.version or 0) < 30 then
		SuperSwingTimerDB.showRogueSliceAndDice = (SuperSwingTimerDB.showRogueSliceAndDice ~= false)
		SuperSwingTimerDB.colors = SuperSwingTimerDB.colors or {}
		SuperSwingTimerDB.colors.rogueSliceAndDice = SuperSwingTimerDB.colors.rogueSliceAndDice or {
			r = ns.DB_DEFAULTS.colors.rogueSliceAndDice.r,
			g = ns.DB_DEFAULTS.colors.rogueSliceAndDice.g,
			b = ns.DB_DEFAULTS.colors.rogueSliceAndDice.b,
			a = ns.DB_DEFAULTS.colors.rogueSliceAndDice.a,
		}
		SuperSwingTimerDB.version = 30
	end

	-- v30 -> v31: add Rogue total-energy battery color.
	if (SuperSwingTimerDB.version or 0) < 31 then
		SuperSwingTimerDB.colors = SuperSwingTimerDB.colors or {}
		SuperSwingTimerDB.colors.rogueEnergyTotal = SuperSwingTimerDB.colors.rogueEnergyTotal or {
			r = ns.DB_DEFAULTS.colors.rogueEnergyTotal.r,
			g = ns.DB_DEFAULTS.colors.rogueEnergyTotal.g,
			b = ns.DB_DEFAULTS.colors.rogueEnergyTotal.b,
			a = ns.DB_DEFAULTS.colors.rogueEnergyTotal.a,
		}
		SuperSwingTimerDB.version = 31
	end

	-- v31 -> v32: add Rogue combo-point helper defaults and color.
	if (SuperSwingTimerDB.version or 0) < 32 then
		SuperSwingTimerDB.showRogueComboPoints = (SuperSwingTimerDB.showRogueComboPoints ~= false)
		SuperSwingTimerDB.colors = SuperSwingTimerDB.colors or {}
		SuperSwingTimerDB.colors.rogueComboPoints = SuperSwingTimerDB.colors.rogueComboPoints or {
			r = ns.DB_DEFAULTS.colors.rogueComboPoints.r,
			g = ns.DB_DEFAULTS.colors.rogueComboPoints.g,
			b = ns.DB_DEFAULTS.colors.rogueComboPoints.b,
			a = ns.DB_DEFAULTS.colors.rogueComboPoints.a,
		}
		SuperSwingTimerDB.version = 32
	end

	-- v32 -> v33: add Hunter vertical range-helper defaults and colors.
	if (SuperSwingTimerDB.version or 0) < 33 then
		SuperSwingTimerDB.showHunterRangeHelper = (SuperSwingTimerDB.showHunterRangeHelper ~= false)
		SuperSwingTimerDB.colors = SuperSwingTimerDB.colors or {}
		for _, colorKey in ipairs({ "hunterRangeMelee", "hunterRangeSweetSpot", "hunterRangeRanged", "hunterRangeOutOfRange" }) do
			if not SuperSwingTimerDB.colors[colorKey] then
				local def = ns.DB_DEFAULTS.colors[colorKey]
				SuperSwingTimerDB.colors[colorKey] = { r = def.r, g = def.g, b = def.b, a = def.a }
			end
		end
		SuperSwingTimerDB.version = 33
	end

	-- v33 -> v34: Paladin seal twist color from opaque black to transparent red
	if (SuperSwingTimerDB.version or 0) < 34 then
		SuperSwingTimerDB.colors = SuperSwingTimerDB.colors or {}
		local sealTwist = SuperSwingTimerDB.colors.sealTwist
		local isLegacyBlack = sealTwist
			and math.abs((sealTwist.r or 0) - 0) < 0.001
			and math.abs((sealTwist.g or 0) - 0) < 0.001
			and math.abs((sealTwist.b or 0) - 0) < 0.001
			and math.abs((sealTwist.a or 1) - 1) < 0.001
		if not sealTwist or isLegacyBlack then
			SuperSwingTimerDB.colors.sealTwist = { r = 1, g = 0, b = 0, a = 0.35 }
		end
		SuperSwingTimerDB.version = 34
	end

	-- v34 -> v35: add per-seal color defaults for seal-based MH bar tinting
	if (SuperSwingTimerDB.version or 0) < 35 then
		SuperSwingTimerDB.colors = SuperSwingTimerDB.colors or {}
		for familyKey, defaultColor in pairs(ns.PALADIN_SEAL_COLORS or {}) do
			local colorKey = "sealColor" .. familyKey
			if not SuperSwingTimerDB.colors[colorKey] then
				SuperSwingTimerDB.colors[colorKey] = {
					r = defaultColor.r,
					g = defaultColor.g,
					b = defaultColor.b,
					a = defaultColor.a,
				}
			end
		end
	SuperSwingTimerDB.version = 35
	end

	if (SuperSwingTimerDB.version or 0) < 36 then
		SuperSwingTimerDB.showWarriorRageBar = ns.DB_DEFAULTS and ns.DB_DEFAULTS.showWarriorRageBar
		if SuperSwingTimerDB.showWarriorRageBar == nil then
			SuperSwingTimerDB.showWarriorRageBar = true
		end
		SuperSwingTimerDB.colors = SuperSwingTimerDB.colors or {}
		if not SuperSwingTimerDB.colors.warriorRageBarColor then
			local default = ns.DB_DEFAULTS and ns.DB_DEFAULTS.colors and ns.DB_DEFAULTS.colors.warriorRageBarColor
			SuperSwingTimerDB.colors.warriorRageBarColor = default or { r = 0.80, g = 0.20, b = 0.10, a = 0.85 }
		end
		SuperSwingTimerDB.version = 36
	end

	-- v36 -> v37: add druid form colors defaults + form color swatches.
	if (SuperSwingTimerDB.version or 0) < 37 then
		SuperSwingTimerDB.showDruidFormColors = true
		SuperSwingTimerDB.colors = SuperSwingTimerDB.colors or {}
		if not SuperSwingTimerDB.colors.druidFormBear then
			SuperSwingTimerDB.colors.druidFormBear = { r = 0.80, g = 0.15, b = 0.10, a = 1.0 }
		end
		if not SuperSwingTimerDB.colors.druidFormCat then
			SuperSwingTimerDB.colors.druidFormCat = { r = 0.90, g = 0.70, b = 0.10, a = 1.0 }
		end
		if not SuperSwingTimerDB.colors.druidFormMoonkin then
			SuperSwingTimerDB.colors.druidFormMoonkin = { r = 0.30, g = 0.55, b = 0.90, a = 1.0 }
		end
		SuperSwingTimerDB.version = 37
	end

	-- v37 -> v38: add warrior Protection spec-hide toggle.
	if (SuperSwingTimerDB.version or 0) < 38 then
		if SuperSwingTimerDB.showWarriorRageProtection == nil then
			SuperSwingTimerDB.showWarriorRageProtection = false
		end
		SuperSwingTimerDB.version = 38
	end

	-- v38 -> v39: Phase 1 quick win toggles + color defaults
	if (SuperSwingTimerDB.version or 0) < 39 then
		if SuperSwingTimerDB.showSwingFlash == nil then SuperSwingTimerDB.showSwingFlash = true end
		if SuperSwingTimerDB.showGcdTicker == nil then SuperSwingTimerDB.showGcdTicker = true end
		if SuperSwingTimerDB.showDruidRageDim == nil then SuperSwingTimerDB.showDruidRageDim = true end
		if SuperSwingTimerDB.showRogueEnergyCountdown == nil then SuperSwingTimerDB.showRogueEnergyCountdown = true end
		SuperSwingTimerDB.colors = SuperSwingTimerDB.colors or {}
		if not SuperSwingTimerDB.colors.gcdTickerColor then
			SuperSwingTimerDB.colors.gcdTickerColor = ns.DB_DEFAULTS and ns.DB_DEFAULTS.colors and ns.DB_DEFAULTS.colors.gcdTickerColor or { r = 0.30, g = 0.70, b = 1.00, a = 0.85 }
		end
		SuperSwingTimerDB.version = 39
	end

	-- v39 -> v40: Phase 2 class-specific defaults
	if (SuperSwingTimerDB.version or 0) < 40 then
		if SuperSwingTimerDB.showHunterRapidFireBar == nil then SuperSwingTimerDB.showHunterRapidFireBar = true end
		if SuperSwingTimerDB.showWarriorFlurryCounter == nil then SuperSwingTimerDB.showWarriorFlurryCounter = true end
		if SuperSwingTimerDB.showRogueAdrenalineRushBar == nil then SuperSwingTimerDB.showRogueAdrenalineRushBar = true end
		if SuperSwingTimerDB.showDruidOmenGlow == nil then SuperSwingTimerDB.showDruidOmenGlow = true end
		if SuperSwingTimerDB.showShamanWindfuryIcd == nil then SuperSwingTimerDB.showShamanWindfuryIcd = true end
		if SuperSwingTimerDB.showWarriorShieldBlockBar == nil then SuperSwingTimerDB.showWarriorShieldBlockBar = true end
		if SuperSwingTimerDB.showDruidRavageCue == nil then SuperSwingTimerDB.showDruidRavageCue = true end
		SuperSwingTimerDB.colors = SuperSwingTimerDB.colors or {}
		local colorDefaults = ns.DB_DEFAULTS and ns.DB_DEFAULTS.colors or {}
		for _, key in ipairs({ "rapidFireBar", "flurryCounter", "adrenalineRushBar", "omenGlow", "windfuryIcd" }) do
			if not SuperSwingTimerDB.colors[key] and colorDefaults[key] then
				SuperSwingTimerDB.colors[key] = { r = colorDefaults[key].r, g = colorDefaults[key].g, b = colorDefaults[key].b, a = colorDefaults[key].a }
			end
		end
		SuperSwingTimerDB.version = 40
	end

	-- v40 -> v41: Shield Block duration bar + Ravage opener cue defaults
	if (SuperSwingTimerDB.version or 0) < 41 then
		SuperSwingTimerDB.colors = SuperSwingTimerDB.colors or {}
		local colorDefaults = ns.DB_DEFAULTS and ns.DB_DEFAULTS.colors or {}
		for _, key in ipairs({ "shieldBlockBar", "ravageCue" }) do
			if not SuperSwingTimerDB.colors[key] and colorDefaults[key] then
				SuperSwingTimerDB.colors[key] = { r = colorDefaults[key].r, g = colorDefaults[key].g, b = colorDefaults[key].b, a = colorDefaults[key].a }
			end
		end
		SuperSwingTimerDB.version = 41
	end

	-- v41 -> v42: independent hunterCastBarHeight sizing
	if (SuperSwingTimerDB.version or 0) < 42 then
		if SuperSwingTimerDB.hunterCastBarHeight == nil then
			SuperSwingTimerDB.hunterCastBarHeight = ns.DB_DEFAULTS.hunterCastBarHeight or 10
		end
		SuperSwingTimerDB.version = 42
	end

	-- v42 -> v43: per-class bar heights
	if (SuperSwingTimerDB.version or 0) < 43 then
		if SuperSwingTimerDB.rogueSliceAndDiceBarHeight == nil then
			SuperSwingTimerDB.rogueSliceAndDiceBarHeight = ns.DB_DEFAULTS.rogueSliceAndDiceBarHeight or 4
		end
		if SuperSwingTimerDB.rogueEnergyTickBarWidth == nil then
			SuperSwingTimerDB.rogueEnergyTickBarWidth = ns.DB_DEFAULTS.rogueEnergyTickBarWidth or 4
		end
		if SuperSwingTimerDB.warriorShieldBlockBarHeight == nil then
			SuperSwingTimerDB.warriorShieldBlockBarHeight = ns.DB_DEFAULTS.warriorShieldBlockBarHeight or 4
		end
		if SuperSwingTimerDB.hunterRangeHelperWidth == nil then
			SuperSwingTimerDB.hunterRangeHelperWidth = ns.DB_DEFAULTS.hunterRangeHelperWidth or 7
		end
		if SuperSwingTimerDB.hunterRapidFireBarHeight == nil then
			SuperSwingTimerDB.hunterRapidFireBarHeight = ns.DB_DEFAULTS.hunterRapidFireBarHeight or 4
		end
		if SuperSwingTimerDB.druidPowerShiftBarHeight == nil then
			SuperSwingTimerDB.druidPowerShiftBarHeight = ns.DB_DEFAULTS.druidPowerShiftBarHeight or 4
		end
		if SuperSwingTimerDB.druidEnergyTickBarWidth == nil then
			SuperSwingTimerDB.druidEnergyTickBarWidth = ns.DB_DEFAULTS.druidEnergyTickBarWidth or 4
		end
		if SuperSwingTimerDB.rogueAdrenalineRushBarHeight == nil then
			SuperSwingTimerDB.rogueAdrenalineRushBarHeight = ns.DB_DEFAULTS.rogueAdrenalineRushBarHeight or 4
		end
		SuperSwingTimerDB.version = 43
	end

	-- v43 -> v44: druid energy tick color swatch, TF/FF badge toggles
	if (SuperSwingTimerDB.version or 0) < 44 then
		SuperSwingTimerDB.colors = SuperSwingTimerDB.colors or {}
		local colorDefaults = ns.DB_DEFAULTS and ns.DB_DEFAULTS.colors or {}
		if not SuperSwingTimerDB.colors.druidEnergyTick and colorDefaults.druidEnergyTick then
			SuperSwingTimerDB.colors.druidEnergyTick = {
				r = colorDefaults.druidEnergyTick.r,
				g = colorDefaults.druidEnergyTick.g,
				b = colorDefaults.druidEnergyTick.b,
				a = colorDefaults.druidEnergyTick.a,
			}
		end
		if SuperSwingTimerDB.showDruidTigerFuryBadge == nil then SuperSwingTimerDB.showDruidTigerFuryBadge = true end
		if SuperSwingTimerDB.showDruidFaerieFireBadge == nil then SuperSwingTimerDB.showDruidFaerieFireBadge = true end
		SuperSwingTimerDB.version = 44
	end

	-- v44 -> v45: Druid Mangle debuff timer + Rip duration bar
	if (SuperSwingTimerDB.version or 0) < 45 then
		SuperSwingTimerDB.colors = SuperSwingTimerDB.colors or {}
		local colorDefaults = ns.DB_DEFAULTS and ns.DB_DEFAULTS.colors or {}
		for _, key in ipairs({ "druidMangleTimer", "druidRipTracker" }) do
			if not SuperSwingTimerDB.colors[key] and colorDefaults[key] then
				SuperSwingTimerDB.colors[key] = {
					r = colorDefaults[key].r,
					g = colorDefaults[key].g,
					b = colorDefaults[key].b,
					a = colorDefaults[key].a,
				}
			end
		end
		if SuperSwingTimerDB.showDruidMangleTimer == nil then SuperSwingTimerDB.showDruidMangleTimer = true end
		if SuperSwingTimerDB.showDruidRipTracker == nil then SuperSwingTimerDB.showDruidRipTracker = true end
		SuperSwingTimerDB.version = 45
	end
end

-- ============================================================
-- Initialization
-- ============================================================
local RegisterSlashCommands

local function OnAddonLoaded()
	MigrateDB()

	-- Apply DB dimensions to runtime constants
	ns.BAR_WIDTH   = SuperSwingTimerDB.barWidth or ns.DB_DEFAULTS.barWidth
	ns.BAR_HEIGHT  = SuperSwingTimerDB.barHeight or ns.DB_DEFAULTS.barHeight
	ns.HUNTER_CAST_BAR_HEIGHT = SuperSwingTimerDB.hunterCastBarHeight or ns.HUNTER_CAST_BAR_HEIGHT or ns.DB_DEFAULTS.hunterCastBarHeight or 10
	ns.ROGUE_SLICE_AND_DICE_BAR_HEIGHT = SuperSwingTimerDB.rogueSliceAndDiceBarHeight or ns.ROGUE_SLICE_AND_DICE_BAR_HEIGHT or ns.DB_DEFAULTS.rogueSliceAndDiceBarHeight or 4
	ns.ROGUE_ENERGY_TICK_BAR_WIDTH = SuperSwingTimerDB.rogueEnergyTickBarWidth or ns.ROGUE_ENERGY_TICK_BAR_WIDTH or ns.DB_DEFAULTS.rogueEnergyTickBarWidth or 4
	ns.WARRIOR_SHIELD_BLOCK_BAR_HEIGHT = SuperSwingTimerDB.warriorShieldBlockBarHeight or ns.WARRIOR_SHIELD_BLOCK_BAR_HEIGHT or ns.DB_DEFAULTS.warriorShieldBlockBarHeight or 4
	ns.HUNTER_RANGE_HELPER_WIDTH = SuperSwingTimerDB.hunterRangeHelperWidth or ns.HUNTER_RANGE_HELPER_WIDTH or ns.DB_DEFAULTS.hunterRangeHelperWidth or 7
	ns.HUNTER_RAPID_FIRE_BAR_HEIGHT = SuperSwingTimerDB.hunterRapidFireBarHeight or ns.HUNTER_RAPID_FIRE_BAR_HEIGHT or ns.DB_DEFAULTS.hunterRapidFireBarHeight or 4
	ns.DRUID_POWER_SHIFT_BAR_HEIGHT = SuperSwingTimerDB.druidPowerShiftBarHeight or ns.DRUID_POWER_SHIFT_BAR_HEIGHT or ns.DB_DEFAULTS.druidPowerShiftBarHeight or 4
	ns.DRUID_ENERGY_TICK_BAR_WIDTH = SuperSwingTimerDB.druidEnergyTickBarWidth or ns.DRUID_ENERGY_TICK_BAR_WIDTH or ns.DB_DEFAULTS.druidEnergyTickBarWidth or 4
	ns.ROGUE_ADRENALINE_RUSH_BAR_HEIGHT = SuperSwingTimerDB.rogueAdrenalineRushBarHeight or ns.ROGUE_ADRENALINE_RUSH_BAR_HEIGHT or ns.DB_DEFAULTS.rogueAdrenalineRushBarHeight or 4

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

RegisterSlashCommands = function()
	SLASH_SUPERSWINGTIMER1 = "/sst"
	SLASH_SUPERSWINGTIMER2 = "/super"
	SLASH_SUPERSWINGTIMER3 = "/superswingtimer"
	SLASH_SUPERSWINGTIMER4 = "/swang"
	SlashCmdList["SUPERSWINGTIMER"] = function(msg)
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

	if cfg.melee and ns.playerClass == "ROGUE" then
		frame:RegisterEvent("UNIT_POWER_UPDATE")
		frame:RegisterEvent("UNIT_POWER_FREQUENT")
	end

	if cfg.ranged then
		frame:RegisterEvent("UNIT_RANGEDDAMAGE")
		frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
		frame:RegisterEvent("START_AUTOREPEAT_SPELL")
		frame:RegisterEvent("STOP_AUTOREPEAT_SPELL")
		frame:RegisterEvent("PLAYER_STARTED_MOVING")
		frame:RegisterEvent("PLAYER_STOPPED_MOVING")
	end

	if cfg.melee and ns.playerClass == "DRUID" then
		frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
	end

	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
end

local function UpdateFrameOnUpdate(self, elapsed)
	if ns.RefreshLatencyCache then
		local rawNow = GetTimePreciseSec and GetTimePreciseSec() or GetTime()
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

frame:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		local name = ...
		if name == addonName then
			OnAddonLoaded()
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
		if ns.playerClass == "DRUID" and ns.UpdateDruidRavageCue then
			ns.UpdateDruidRavageCue(0, true)
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
			if ns.playerClass == "WARRIOR" and ns.UpdateWarriorShieldBlockBar then
				ns.UpdateWarriorShieldBlockBar(0, true)
			end
			if ns.playerClass == "DRUID" and ns.UpdateDruidRavageCue then
				ns.UpdateDruidRavageCue(0, true)
			end
			if ns.playerClass == "ROGUE" and ns.HandleRogueSliceAndDiceAura then
				ns.HandleRogueSliceAndDiceAura(unit)
			end
		end
	elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT" then
		local unit, powerType = ...
		if ns.playerClass == "ROGUE" and unit == "player" and ns.HandleRogueEnergyPowerUpdate and (powerType == nil or powerType == "ENERGY") then
			ns.HandleRogueEnergyPowerUpdate(unit, powerType)
		elseif ns.playerClass == "DRUID" and unit == "player" and ns.HandleDruidEnergyPowerUpdate and (powerType == nil or powerType == "ENERGY") then
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
			local autoRepeatActive = ns.IsHunterAutoRepeatActive and ns.IsHunterAutoRepeatActive() or (ns.hunterAutoRepeatActive == true)
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
