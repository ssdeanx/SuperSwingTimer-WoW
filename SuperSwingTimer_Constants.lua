local addonName, ns = ...
local LibStub = rawget(_G, "LibStub")

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

-- Spell-ID rules adapted from the reference swingtimer library.
-- RESET_SWING_SPELLS: casts that should reset melee/ranged swing flow.
ns.RESET_SWING_SPELLS = {}
local function registerResetSwingSpells(ids)
	for _, id in ipairs(ids) do
		ns.RESET_SWING_SPELLS[id] = true
	end
end

registerResetSwingSpells({ 16589, 2645, 51533, 2764, 3018, 5384, 5019, 20066 })

-- NO_RESET_SWING_SPELLS: casts that should not reset swing state.
ns.NO_RESET_SWING_SPELLS = {}
local function registerNoResetSwingSpells(ids)
	for _, id in ipairs(ids) do
		ns.NO_RESET_SWING_SPELLS[id] = true
	end
end

registerNoResetSwingSpells({
	30310, 30311, 23063, 4054, 4064, 4061, 8331, 4065, 4066, 4062, 4067, 4068,
	23000, 12421, 4069, 12562, 12543, 19769, 19784, 19821, 34120, 27022,
	19434, 20900, 20901, 20902, 20903, 20904, 27065,
})

-- PAUSE_SWING_SPELLS: casts that should pause and then resume swing timing.
-- Slam uses the pause/extend path rather than a hard MH reset.
ns.PAUSE_SWING_SPELLS = {}
for _, id in ipairs({ 1464, 8820, 11604, 11605 }) do
	ns.PAUSE_SWING_SPELLS[id] = true
end

-- RESET_RANGED_SWING_SPELLS: landed spell effects that should restart ranged.
ns.RESET_RANGED_SWING_SPELLS = {}
for _, id in ipairs({ 14295, 11925, 11951 }) do
	ns.RESET_RANGED_SWING_SPELLS[id] = true
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
ns.WEAVE_SPELL_FAMILY_COLORS = {
	LB  = { r = 0.45, g = 0.75, b = 1.00, a = 1 }, -- light blue
	CL  = { r = 0.15, g = 0.45, b = 0.95, a = 1 }, -- dark blue
	HW  = { r = 0.25, g = 0.90, b = 0.35, a = 1 }, -- green
	LHW = { r = 0.55, g = 1.00, b = 0.55, a = 1 }, -- light green
	CH  = { r = 1.00, g = 0.90, b = 0.20, a = 1 }, -- yellow
}

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
	version   = 12,
	showMH    = true,
	showOH    = true,
	showRanged = true,
	showWeaveAssist = true,
	useClassColors = true,
	weaveSpellFamilies = {
		LB  = true,
		CL  = true,
		HW  = true,
		LHW = true,
		CH  = true,
	},
	indicatorBlendMode = "ADD",
	barWidth  = 200,
	barHeight = 20,
	barTexture = "Interface\\TargetingFrame\\UI-StatusBar",
	rangedBarTexture = "Interface\\TargetingFrame\\UI-StatusBar",
	barTextureLayer = "ARTWORK",
	sparkTexture = "Interface\\CastingBar\\UI-CastingBar-Spark",
	sparkTextureLayer = "OVERLAY",
	weaveSparkTexture = "Interface\\CastingBar\\UI-CastingBar-Spark",
	weaveSparkTextureLayer = "OVERLAY",
	weaveSparkWidth = 10,
	weaveSparkHeight = 24,
	weaveSparkAlpha = 0.95,
	weaveTriangleTopTexture = "Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Arrow",
	weaveTriangleBottomTexture = "Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Arrow",
	weaveTriangleTextureLayer = "OVERLAY",
	weaveTriangleSize = 10,
	weaveTriangleGap = 1,
	weaveTriangleAlpha = 1,
	weaveMarkerLayer = "OVERLAY",
	sparkWidth = 20,
	sparkHeight = 44,
	barBackgroundAlpha = 0.5,
	sparkAlpha = 1,
	minimalMode = false,
	lockBars = false,
	colors = {
		mh        = { r = 0, g = 0, b = 0, a = 1   },
		oh        = { r = 0, g = 0, b = 0, a = 1   },
		ranged    = { r = 0, g = 0, b = 0, a = 1   },
		sealTwist = { r = 0, g = 0.8, b = 1, a = 0.4 },
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

ns.TEXTURE_LIBRARY = nil

function ns.BuildTextureLibrary()
	local entries = {}
	local seen = {}

	local function addEntry(category, label, path, style)
		if not path or path == "" or seen[path] then
			return
		end
		seen[path] = true
		entries[#entries + 1] = { category = category, style = style or category, label = label, path = path }
	end

	local libStub = rawget(_G, "LibStub")
	local lsm = libStub and libStub("LibSharedMedia-3.0", true)
	if lsm and lsm.List and lsm.Fetch then
		for _, mediaType in ipairs({ "statusbar", "background", "border" }) do
			for _, name in ipairs(lsm:List(mediaType) or {}) do
				addEntry("SharedMedia", name, lsm:Fetch(mediaType, name), mediaType)
			end
		end
	end

	addEntry("Blizzard", "Status Bar", "Interface\\TargetingFrame\\UI-StatusBar", "fallback")
	addEntry("Blizzard", "Casting Spark", "Interface\\CastingBar\\UI-CastingBar-Spark", "fallback")
	addEntry("Blizzard", "Casting Fill", "Interface\\CastingBar\\UI-CastingBar-Fill", "fallback")
	addEntry("Blizzard", "Casting Shield", "Interface\\CastingBar\\UI-CastingBar-Shield", "fallback")
	addEntry("Blizzard", "Tooltip Background", "Interface\\Tooltips\\UI-Tooltip-Background", "fallback")
	addEntry("Blizzard", "Tooltip Border", "Interface\\Tooltips\\UI-Tooltip-Border", "fallback")
	addEntry("Blizzard", "Dialog Background", "Interface\\DialogFrame\\UI-DialogBox-Background", "fallback")
	addEntry("Blizzard", "Dialog Dark Background", "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", "fallback")
	addEntry("Blizzard", "Dialog Border", "Interface\\DialogFrame\\UI-DialogBox-Border", "fallback")
	addEntry("Blizzard", "Scroll Arrow Down", "Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Arrow", "fallback")
	addEntry("Blizzard", "Scroll Arrow Up", "Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Arrow", "fallback")
	addEntry("Blizzard", "White 8x8", "Interface\\Buttons\\WHITE8X8", "fallback")

	table.sort(entries, function(a, b)
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

	local library = ns.TEXTURE_LIBRARY or ns.BuildTextureLibrary()
	for _, entry in ipairs(library) do
		if entry.path == texturePath then
			return string.format("[%s / %s] %s", entry.category or "Unknown", entry.style or "style", entry.label or texturePath)
		end
	end

	return texturePath
end

function ns.GetPlayerClassColor()
	local class = ns.playerClass
	local classColors = rawget(_G, "RAID_CLASS_COLORS")
	local color = class and classColors and classColors[class] or nil
	if color then
		return {
			r = color.r or 1,
			g = color.g or 1,
			b = color.b or 1,
			a = 1,
		}
	end

	return { r = 0.25, g = 0.72, b = 1.0, a = 1 }
end

function ns.GetBarColor(colorKey)
	local db = rawget(_G, "SuperSwingTimerDB")
	local useClassColors = not db or db.useClassColors ~= false
	if useClassColors and (colorKey == "mh" or colorKey == "oh" or colorKey == "ranged") then
		return ns.GetPlayerClassColor()
	end

	local colors = db and db.colors
	if colors and colors[colorKey] then
		return colors[colorKey]
	end

	return ns.DB_DEFAULTS.colors and ns.DB_DEFAULTS.colors[colorKey] or nil
end

function ns.SeedLegacyBarColorsFromClass()
	local db = rawget(_G, "SuperSwingTimerDB")
	if not db then
		return
	end

	db.colors = db.colors or {}
	local classColor = ns.GetPlayerClassColor()

	local function IsLegacyBlackColor(color)
		return not color or (
			math.abs((color.r or 0) - 0) < 0.001 and
			math.abs((color.g or 0) - 0) < 0.001 and
			math.abs((color.b or 0) - 0) < 0.001 and
			((color.a == nil) or math.abs((color.a or 1) - 1) < 0.001)
		)
	end

	for _, key in ipairs({ "mh", "oh", "ranged" }) do
		if IsLegacyBlackColor(db.colors[key]) then
			db.colors[key] = { r = classColor.r, g = classColor.g, b = classColor.b, a = 1 }
		end
	end
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
	if db and db.barBackgroundAlpha ~= nil then
		return db.barBackgroundAlpha
	end
	return ns.DB_DEFAULTS.barBackgroundAlpha
end

function ns.GetSparkAlpha()
	local db = rawget(_G, "SuperSwingTimerDB")
	if db and db.sparkAlpha ~= nil then
		return db.sparkAlpha
	end
	return ns.DB_DEFAULTS.sparkAlpha
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
	if db and db.barTexture then
		return db.barTexture
	end
	return ns.DB_DEFAULTS.barTexture
end

function ns.GetRangedBarTexture()
	local db = rawget(_G, "SuperSwingTimerDB")
	if db and db.rangedBarTexture then
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

