local addonName, ns = ...
local CreateFrame = rawget(_G, "CreateFrame")
local UIParent = rawget(_G, "UIParent")
local SlashCmdList = rawget(_G, "SlashCmdList")
local UnitClass = rawget(_G, "UnitClass")
local strtrim = rawget(_G, "strtrim")
local GetShapeshiftForm = rawget(_G, "GetShapeshiftForm")
local GetTimePreciseSec = rawget(_G, "GetTimePreciseSec")
local GetTime = rawget(_G, "GetTime")

local function GetCurrentTime()
	if GetTimePreciseSec then
		return GetTimePreciseSec() + (ns.cachedLatency or 0)
	end
	return GetTime() + (ns.cachedLatency or 0)
end

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
			version                    = 21,
			showMH                     = ns.DB_DEFAULTS.showMH,
			showOH                     = ns.DB_DEFAULTS.showOH,
			showRanged                 = ns.DB_DEFAULTS.showRanged,
			showWeaveAssist            = ns.DB_DEFAULTS.showWeaveAssist,
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
	SuperSwingTimerDB.showWeaveAssist    = (SuperSwingTimerDB.showWeaveAssist ~= false)
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
end

-- ============================================================
-- Initialization
-- ============================================================
local function OnAddonLoaded()
	MigrateDB()

	-- Apply DB dimensions to runtime constants
	ns.BAR_WIDTH   = SuperSwingTimerDB.barWidth or ns.DB_DEFAULTS.barWidth
	ns.BAR_HEIGHT  = SuperSwingTimerDB.barHeight or ns.DB_DEFAULTS.barHeight

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

	-- Slash commands
	SLASH_SUPERSWINGTIMER1 = "/sst"
	SLASH_SUPERSWINGTIMER2 = "/super"
	SLASH_SUPERSWINGTIMER3 = "/superswingtimer"
	SLASH_SUPERSWINGTIMER4 = "/swang"
	SlashCmdList["SUPERSWINGTIMER"] = function(msg)
		msg = strtrim(msg or ""):lower()
		if msg == "reset" then
			ns.ResetConfigDefaults()
			print("|cff00ccffSuper Swing Timer:|r Settings reset to defaults.")
		elseif msg == "help" then
			print("|cff00ccffSuper Swing Timer:|r /sst, /super, or /superswingtimer - open config panel")
			print("|cff00ccffSuper Swing Timer:|r /sst reset - restore default settings")
		else
			ns.ToggleConfig()
		end
	end
end

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

	if cfg.melee then
		frame:RegisterEvent("UNIT_ATTACK_SPEED")
		frame:RegisterEvent("UNIT_AURA")
		frame:RegisterEvent("PLAYER_REGEN_DISABLED")
		frame:RegisterEvent("PLAYER_REGEN_ENABLED")
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

	if cfg.ranged then
		frame:RegisterEvent("UNIT_RANGEDDAMAGE")
		frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
		frame:RegisterEvent("START_AUTOREPEAT_SPELL")
		frame:RegisterEvent("STOP_AUTOREPEAT_SPELL")
		frame:RegisterEvent("PLAYER_STARTED_MOVING")
		frame:RegisterEvent("PLAYER_STOPPED_MOVING")
		frame:RegisterEvent("PLAYER_REGEN_DISABLED")
		frame:RegisterEvent("PLAYER_REGEN_ENABLED")
	end

	if cfg.melee and ns.playerClass == "DRUID" then
		frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
	end

	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
end

local function UpdateFrameOnUpdate(self, elapsed)
	if ns.RefreshLatencyCache then
		ns.RefreshLatencyCache()
	end
	ns.OnUpdate(elapsed)
end

function ns.SetUpdateEnabled(enabled)
	if enabled then
		if ns.RefreshLatencyCache then
			ns.RefreshLatencyCache()
		end
		frame:SetScript("OnUpdate", UpdateFrameOnUpdate)
	else
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
	elseif event == "UNIT_ATTACK_SPEED" then
		local unit = ...
		if unit == "player" then
			ns.SyncMeleeTimerSpeed("mh", nil, true)
			ns.SyncMeleeTimerSpeed("oh", nil, true)
		end
	elseif event == "UNIT_AURA" then
		local unit = ...
		if unit == "player" then
			ns.SanityCheckTimers()
		end
	elseif event == "UNIT_RANGEDDAMAGE" then
		local unit = ...
		if unit == "player" then
			ns.SyncRangedTimerSpeed(nil, true)
		end
	elseif event == "SPELL_UPDATE_COOLDOWN" then
		if ns.playerClass == "HUNTER" and ns.GetAutoShotCooldown then
			local _, autoShotDuration = ns.GetAutoShotCooldown()
			if autoShotDuration and autoShotDuration > 0 then
				if ns.timers.ranged and ns.timers.ranged.state == "swinging" then
					ns.SyncRangedTimerSpeed(nil, true)
				else
					ns.StartRangedSwing()
				end
			end
		end
	elseif event == "UNIT_INVENTORY_CHANGED" then
		ns.UpdateOHBar()
		ns.SanityCheckTimers()
	elseif event == "PLAYER_EQUIPMENT_CHANGED" then
		ns.UpdateOHBar()
		ns.SanityCheckTimers(true)
	elseif event == "PLAYER_ENTERING_WORLD" then
		local isInitialLogin, isReloadingUi = ...
		ns.OnPlayerEnteringWorld(isInitialLogin, isReloadingUi)
		if ns.ClearWeavePreview then
			ns.ClearWeavePreview()
		end
	elseif event == "SPELLS_CHANGED" then
		if ns.playerClass == "SHAMAN" and ns.RebuildWeaveSpellCatalog then
			ns.RebuildWeaveSpellCatalog()
		end
	elseif event == "START_AUTOREPEAT_SPELL" then
		-- Hunter starts auto-shooting
		if ns.playerClass == "HUNTER" and ns.GetAutoShotCooldown then
			local _, autoShotDuration = ns.GetAutoShotCooldown()
			if autoShotDuration and autoShotDuration > 0 and ns.timers.ranged and ns.timers.ranged.state ~= "swinging" then
				ns.StartRangedSwing()
			end
		end
		if ns.rangedBar then ns.rangedBar:SetAlpha(1) end
	elseif event == "STOP_AUTOREPEAT_SPELL" then
		ns.ResetTimer("ranged")
		if ns.rangedBar then ns.rangedBar:SetAlpha(0) end
	elseif event == "PLAYER_REGEN_DISABLED" then
		ns.ShowBars()
		ns.StartSanityTicker()
	elseif event == "PLAYER_REGEN_ENABLED" then
		ns.StopSanityTicker()
		ns.HideBars()
		ns.ResetTimer("mh")
		ns.ResetTimer("oh")
		ns.ResetTimer("ranged")
		if ns.ClearHunterCastState then
			ns.ClearHunterCastState()
		end
		ns.lastStoppedMovingAt = nil
		ns.extraAttackPending = 0
		if ns.ClearWeavePreview then
			ns.ClearWeavePreview()
		end
	elseif event == "UPDATE_SHAPESHIFT_FORM" then
		-- Druid form label update handled via classmod callback
		if ns.OnDruidFormChange then
			-- Fire with current form; exact aura handled via CLEU
			local form = GetShapeshiftForm and GetShapeshiftForm() or 0
			if form == 0 then
				ns.OnDruidFormChange(0)
			end
		end
	end
end)

ns.SetUpdateEnabled(ns.HasActiveTimers())
