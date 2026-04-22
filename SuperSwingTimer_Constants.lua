local addonName, ns = ...

-- ============================================================
-- UI constants
-- ============================================================
ns.BAR_WIDTH   = 200
ns.BAR_HEIGHT  = 20
ns.CAST_WINDOW = 0.5    -- hidden ranged cast time in TBC

-- ============================================================
-- Spell IDs
-- ============================================================
ns.AUTO_SHOT_ID = 75

-- Next-Melee-Attack (NMA) abilities: queue on the MH swing, fire
-- as SPELL_DAMAGE (not SWING_DAMAGE), reset MH timer on land.
-- OH is unaffected by NMAs.
ns.NMA_LOOKUP = {}
local function registerNMAs(ids)
	for _, id in ipairs(ids) do
		ns.NMA_LOOKUP[id] = true
	end
end

-- Heroic Strike (Warrior)
registerNMAs({ 78, 284, 285, 1608, 11564, 11565, 11566, 11567, 25286, 29707, 30324 })

-- Cleave (Warrior)
registerNMAs({ 845, 7369, 11608, 11609, 20569, 25231 })

-- Maul (Druid â€” Bear)
registerNMAs({ 6807, 6808, 6809, 8972, 9745, 9880, 9881, 26996 })

-- Raptor Strike (Hunter)
registerNMAs({ 2973, 14260, 14261, 14262, 14263, 14264, 14265, 14266, 27014 })

-- Slam (Warrior) â€” resets MH timer on UNIT_SPELLCAST_SUCCEEDED.
-- In original TBC, Arms Warriors timed Slam immediately after a white hit.
-- Default: reset behavior. Verify via in-game test on Anniversary Edition.
ns.SLAM_IDS = {}
local SLAM_LIST = { 1464, 8820, 11604, 11605, 25241, 25242 }
for _, id in ipairs(SLAM_LIST) do
	ns.SLAM_IDS[id] = true
end

-- Druid form aura IDs (trigger MH timer reset on apply)
ns.DRUID_FORM_IDS = {
	[768]  = "Cat",       -- Cat Form
	[5487] = "Bear",      -- Bear Form
	[9634] = "DireBear",  -- Dire Bear Form
}

-- Shaman weaving spell groups.
-- Ordered from highest rank to lowest rank so the first available entry
-- becomes the active breakpoint target.
ns.WEAVE_SPELL_GROUPS = {
	{ abbrev = "LB",  label = "Lightning Bolt",       ids = { 403, 529, 548, 915, 943, 6041, 10391, 10392, 15207, 15208, 25448, 25449 } },
	{ abbrev = "CL",  label = "Chain Lightning",     ids = { 421, 930, 2860, 10605, 25439, 25442 } },
	{ abbrev = "HW",  label = "Healing Wave",        ids = { 331, 332, 547, 913, 939, 959, 8005, 10395, 10396, 25357, 25391, 25396 } },
	{ abbrev = "LHW", label = "Lesser Healing Wave", ids = { 8004, 8008, 8010, 10466, 10467, 10468, 25420 } },
	{ abbrev = "CH",  label = "Chain Heal",         ids = { 1064, 10622, 10623, 25422, 25423 } },
}

-- ============================================================
-- Class configuration
-- ============================================================
-- Determines which bars to create and which events to register.
ns.CLASS_CONFIG = {
	HUNTER  = { ranged = true,  melee = true,  dualWield = false },
	WARRIOR = { ranged = false, melee = true,  dualWield = true  },
	ROGUE   = { ranged = false, melee = true,  dualWield = true  },
	PALADIN = { ranged = false, melee = true,  dualWield = false },
	SHAMAN  = { ranged = false, melee = true,  dualWield = true  },
	DRUID   = { ranged = false, melee = true,  dualWield = false },
	MAGE    = { ranged = false, melee = false, dualWield = false },
	PRIEST  = { ranged = false, melee = false, dualWield = false },
	WARLOCK = { ranged = false, melee = false, dualWield = false },
}

-- ============================================================
-- SavedVariables defaults
-- ============================================================
ns.DB_DEFAULTS = {
	version   = 8,
	showMH    = true,
	showOH    = true,
	showRanged = true,
	showWeaveAssist = true,
	barWidth  = 200,
	barHeight = 20,
	barTexture = "Interface\\TargetingFrame\\UI-StatusBar",
	barTextureLayer = "ARTWORK",
	sparkTexture = "Interface\\CastingBar\\UI-CastingBar-Spark",
	sparkTextureLayer = "OVERLAY",
	weaveSparkTexture = "Interface\\CastingBar\\UI-CastingBar-Spark",
	weaveSparkTextureLayer = "OVERLAY",
	weaveSparkWidth = 14,
	weaveSparkHeight = 30,
	weaveSparkAlpha = 0.95,
	weaveTriangleTopTexture = "Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Arrow",
	weaveTriangleBottomTexture = "Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Arrow",
	weaveTriangleTextureLayer = "OVERLAY",
	weaveTriangleSize = 14,
	weaveTriangleGap = 2,
	weaveTriangleAlpha = 1,
	weaveMarkerLayer = "OVERLAY",
	sparkWidth = 20,
	sparkHeight = 44,
	barBackgroundAlpha = 0.5,
	sparkAlpha = 1,
	minimalMode = false,
	lockBars = false,
	colors = {
		mh        = { r = 0, g = 0, b = 0, a = 1   },  -- black (matches production look)
		oh        = { r = 0, g = 0, b = 0, a = 1   },  -- black
		ranged    = { r = 0, g = 0, b = 0, a = 1   },  -- black
		sealTwist = { r = 0, g = 0.8, b = 1, a = 0.4 },  -- cyan
	},
	positions = {
		mh     = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -120 },
		oh     = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -145 },
		ranged = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -100 },
	},
}

ns.TEXTURE_LAYER_OPTIONS = {
	{ label = "Background", value = "BACKGROUND" },
	{ label = "Border",     value = "BORDER" },
	{ label = "Artwork",    value = "ARTWORK" },
	{ label = "Overlay",     value = "OVERLAY" },
	{ label = "Highlight",   value = "HIGHLIGHT" },
}

ns.TEXTURE_LIBRARY = {
	{ category = "Bars", label = "Status Bar", path = "Interface\\TargetingFrame\\UI-StatusBar" },
	{ category = "Bars", label = "White 8x8", path = "Interface\\Buttons\\WHITE8X8" },
	{ category = "Bars", label = "Chat Background", path = "Interface\\ChatFrame\\ChatFrameBackground" },
	{ category = "Bars", label = "Tooltip Background", path = "Interface\\Tooltips\\UI-Tooltip-Background" },
	{ category = "Bars", label = "Dialog Background", path = "Interface\\DialogFrame\\UI-DialogBox-Background" },
	{ category = "Bars", label = "Dialog Border", path = "Interface\\DialogFrame\\UI-DialogBox-Border" },
	{ category = "Bars", label = "Tooltip Border", path = "Interface\\Tooltips\\UI-Tooltip-Border" },
	{ category = "Bars", label = "Listbox Highlight", path = "Interface\\Buttons\\UI-Listbox-Highlight" },
	{ category = "Bars", label = "Button Highlight", path = "Interface\\Buttons\\UI-Button-Highlight" },
	{ category = "Bars", label = "Quest Title Highlight", path = "Interface\\QuestFrame\\UI-QuestTitleHighlight" },
	{ category = "Bars", label = "Friends Online", path = "Interface\\FriendsFrame\\UI-FriendsFrame-Online" },
	{ category = "Bars", label = "Friends Highlight Blue", path = "Interface\\FriendsFrame\\UI-FriendsFrame-HighlightBarBlue" },
	{ category = "Casting", label = "Casting Spark", path = "Interface\\CastingBar\\UI-CastingBar-Spark" },
	{ category = "Casting", label = "Casting Fill", path = "Interface\\CastingBar\\UI-CastingBar-Fill" },
	{ category = "Casting", label = "Casting Icon Shield", path = "Interface\\CastingBar\\UI-CastingBar-Shield" },
	{ category = "Casting", label = "Checkmark", path = "Interface\\Buttons\\UI-CheckBox-Check" },
	{ category = "Casting", label = "Scroll Up Arrow", path = "Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Arrow" },
	{ category = "Casting", label = "Scroll Down Arrow", path = "Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Arrow" },
	{ category = "Casting", label = "Radio Checked", path = "Interface\\Buttons\\UI-RadioButton-Check" },
	{ category = "Casting", label = "Radio Unchecked", path = "Interface\\Buttons\\UI-RadioButton" },
	{ category = "Casting", label = "Glow", path = "Interface\\Buttons\\UI-DialogBox-Button-Highlight" },
	{ category = "Casting", label = "Parchment", path = "Interface\\FrameGeneral\\UI-FrameBackground" },
}

function ns.GetBarTextureLayer()
	if SuperSwingTimerDB and SuperSwingTimerDB.barTextureLayer then
		return SuperSwingTimerDB.barTextureLayer
	end
	return ns.DB_DEFAULTS.barTextureLayer
end

function ns.GetSparkTextureLayer()
	if SuperSwingTimerDB and SuperSwingTimerDB.sparkTextureLayer then
		return SuperSwingTimerDB.sparkTextureLayer
	end
	return ns.DB_DEFAULTS.sparkTextureLayer
end

function ns.GetWeaveSparkTexture()
	if SuperSwingTimerDB and SuperSwingTimerDB.weaveSparkTexture then
		return SuperSwingTimerDB.weaveSparkTexture
	end
	return ns.DB_DEFAULTS.weaveSparkTexture
end

function ns.GetWeaveSparkLayer()
	if SuperSwingTimerDB and SuperSwingTimerDB.weaveSparkTextureLayer then
		return SuperSwingTimerDB.weaveSparkTextureLayer
	end
	return ns.DB_DEFAULTS.weaveSparkTextureLayer
end

function ns.GetWeaveTriangleTopTexture()
	if SuperSwingTimerDB and SuperSwingTimerDB.weaveTriangleTopTexture then
		return SuperSwingTimerDB.weaveTriangleTopTexture
	end
	return ns.DB_DEFAULTS.weaveTriangleTopTexture
end

function ns.GetWeaveTriangleBottomTexture()
	if SuperSwingTimerDB and SuperSwingTimerDB.weaveTriangleBottomTexture then
		return SuperSwingTimerDB.weaveTriangleBottomTexture
	end
	return ns.DB_DEFAULTS.weaveTriangleBottomTexture
end

function ns.GetWeaveTriangleLayer()
	if SuperSwingTimerDB and SuperSwingTimerDB.weaveTriangleTextureLayer then
		return SuperSwingTimerDB.weaveTriangleTextureLayer
	end
	return ns.DB_DEFAULTS.weaveTriangleTextureLayer
end

function ns.GetWeaveMarkerLayer()
	if SuperSwingTimerDB and SuperSwingTimerDB.weaveMarkerLayer then
		return SuperSwingTimerDB.weaveMarkerLayer
	end
	return ns.DB_DEFAULTS.weaveMarkerLayer
end

function ns.GetBarBackgroundAlpha()
	if SuperSwingTimerDB and SuperSwingTimerDB.barBackgroundAlpha ~= nil then
		return SuperSwingTimerDB.barBackgroundAlpha
	end
	return ns.DB_DEFAULTS.barBackgroundAlpha
end

function ns.GetSparkAlpha()
	if SuperSwingTimerDB and SuperSwingTimerDB.sparkAlpha ~= nil then
		return SuperSwingTimerDB.sparkAlpha
	end
	return ns.DB_DEFAULTS.sparkAlpha
end

function ns.IsMinimalMode()
	return SuperSwingTimerDB and SuperSwingTimerDB.minimalMode == true
end

function ns.AreBarsLocked()
	return SuperSwingTimerDB and SuperSwingTimerDB.lockBars == true
end

function ns.GetBarTexture()
	if SuperSwingTimerDB and SuperSwingTimerDB.barTexture then
		return SuperSwingTimerDB.barTexture
	end
	return ns.DB_DEFAULTS.barTexture
end

function ns.GetSparkTexture()
	if SuperSwingTimerDB and SuperSwingTimerDB.sparkTexture then
		return SuperSwingTimerDB.sparkTexture
	end
	return ns.DB_DEFAULTS.sparkTexture
end

function ns.GetSparkWidth()
	if SuperSwingTimerDB and SuperSwingTimerDB.sparkWidth then
		return SuperSwingTimerDB.sparkWidth
	end
	return ns.DB_DEFAULTS.sparkWidth
end

function ns.GetSparkHeight()
	if SuperSwingTimerDB and SuperSwingTimerDB.sparkHeight then
		return SuperSwingTimerDB.sparkHeight
	end
	return ns.DB_DEFAULTS.sparkHeight
end

function ns.GetWeaveSparkWidth()
	if SuperSwingTimerDB and SuperSwingTimerDB.weaveSparkWidth then
		return SuperSwingTimerDB.weaveSparkWidth
	end
	return ns.DB_DEFAULTS.weaveSparkWidth
end

function ns.GetWeaveSparkHeight()
	if SuperSwingTimerDB and SuperSwingTimerDB.weaveSparkHeight then
		return SuperSwingTimerDB.weaveSparkHeight
	end
	return ns.DB_DEFAULTS.weaveSparkHeight
end

function ns.GetWeaveSparkAlpha()
	if SuperSwingTimerDB and SuperSwingTimerDB.weaveSparkAlpha ~= nil then
		return SuperSwingTimerDB.weaveSparkAlpha
	end
	return ns.DB_DEFAULTS.weaveSparkAlpha
end

function ns.GetWeaveTriangleSize()
	if SuperSwingTimerDB and SuperSwingTimerDB.weaveTriangleSize then
		return SuperSwingTimerDB.weaveTriangleSize
	end
	return ns.DB_DEFAULTS.weaveTriangleSize
end

function ns.GetWeaveTriangleGap()
	if SuperSwingTimerDB and SuperSwingTimerDB.weaveTriangleGap then
		return SuperSwingTimerDB.weaveTriangleGap
	end
	return ns.DB_DEFAULTS.weaveTriangleGap
end

function ns.GetWeaveTriangleAlpha()
	if SuperSwingTimerDB and SuperSwingTimerDB.weaveTriangleAlpha ~= nil then
		return SuperSwingTimerDB.weaveTriangleAlpha
	end
	return ns.DB_DEFAULTS.weaveTriangleAlpha
end

