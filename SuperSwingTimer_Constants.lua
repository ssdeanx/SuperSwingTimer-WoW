local addonName, ns = ...
local GetSpellInfo = rawget(_G, "GetSpellInfo")
local GetAddOnInfo = rawget(_G, "GetAddOnInfo")

-- ============================================================
-- UI constants
-- ============================================================
ns.BAR_WIDTH   = 200
ns.BAR_HEIGHT  = 20
ns.HUNTER_CAST_BAR_HEIGHT = 10
ns.HUNTER_CAST_BAR_GAP = 2
ns.CAST_WINDOW = 0.5    -- hidden ranged cast time in TBC

-- ============================================================
-- Spell IDs
-- ============================================================
ns.AUTO_SHOT_ID = 75
ns.AUTO_SHOT_NAME = (type(GetSpellInfo) == "function" and GetSpellInfo(ns.AUTO_SHOT_ID)) or "Auto Shot"
ns.HUNTER_CAST_SPELLS = {
	[75] = true,     -- Auto Shot
	[2643] = true,   -- Multi-Shot rank 1
	[14288] = true,  -- Multi-Shot rank 2
	[14289] = true,  -- Multi-Shot rank 3
	[14290] = true,  -- Multi-Shot rank 4
	[25294] = true,  -- Multi-Shot rank 5
	[27021] = true,  -- Multi-Shot rank 6
}

ns.HUNTER_CAST_SPELL_NAMES = {}
if type(GetSpellInfo) == "function" then
	for spellId in pairs(ns.HUNTER_CAST_SPELLS) do
		local spellName = GetSpellInfo(spellId)
		if spellName then
			ns.HUNTER_CAST_SPELL_NAMES[spellName] = true
		end
	end
end

function ns.IsAutoShotSpell(spellValue)
	if spellValue == nil then
		return false
	end

	local spellId = tonumber(spellValue)
	return spellValue == ns.AUTO_SHOT_ID or spellValue == ns.AUTO_SHOT_NAME or (spellId and spellId == ns.AUTO_SHOT_ID)
end

function ns.IsHunterCastSpell(spellValue)
	if spellValue == nil then
		return false
	end

	local spellId = tonumber(spellValue)
	return (
		ns.HUNTER_CAST_SPELLS[spellValue] == true or
		(spellId and ns.HUNTER_CAST_SPELLS[spellId] == true) or
		ns.HUNTER_CAST_SPELL_NAMES[spellValue] == true
	)
end

-- Paladin seal spell IDs used for UnitAura-aware breakpoint logic.
-- The lookup prefers verified TBC/Classic spell IDs and also keeps literal
-- seal names so aura detection stays resilient across rank gaps and client
-- spell-ID availability.
ns.PALADIN_SEAL_FAMILIES = {
	COMMAND = {
		label = "Seal of Command",
		ids = { 20375, 20915, 20918, 20919, 20920, 27170 },
		names = { "Seal of Command" },
	},
	CORRUPTION = {
		label = "Seal of Corruption",
		ids = { 348704 },
		names = { "Seal of Corruption" },
	},
	BLOOD = {
		label = "Seal of Blood",
		ids = { 31892 },
		names = { "Seal of Blood" },
	},
	MARTYR = {
		label = "Seal of the Martyr",
		ids = { 348700 },
		names = { "Seal of the Martyr" },
	},
	VENGEANCE = {
		label = "Seal of Vengeance",
		ids = { 31801 },
		names = { "Seal of Vengeance" },
	},
	JUSTICE = {
		label = "Seal of Justice",
		ids = { 20165, 31895 },
		names = { "Seal of Justice" },
	},
	WISDOM = {
		label = "Seal of Wisdom",
		ids = { 20166, 20356, 20357, 27166 },
		names = { "Seal of Wisdom" },
	},
	RIGHTEOUSNESS = {
		label = "Seal of Righteousness",
		ids = { 20154, 20287, 20288, 20289, 20290, 20291, 20292, 20293, 27155 },
		names = { "Seal of Righteousness" },
	},
	LIGHT = {
		label = "Seal of Light",
		ids = { 20166, 20347, 20348, 20349, 27160 },
		names = { "Seal of Light" },
	},
	CRUSADER = {
		label = "Seal of the Crusader",
		ids = { 21082, 20162, 20305, 20306, 20307, 20308, 27158 },
		names = { "Seal of the Crusader" },
	},
}

ns.PALADIN_SEAL_LOOKUP = {}
ns.PALADIN_SEAL_NAME_LOOKUP = {}
ns.PALADIN_SEAL_TWIST_FAMILIES = {
	BLOOD = true,
	MARTYR = true,
}

ns.PALADIN_SEAL_FAMILY_ORDER = {
	"COMMAND",
	"CORRUPTION",
	"BLOOD",
	"MARTYR",
	"VENGEANCE",
	"JUSTICE",
	"WISDOM",
	"RIGHTEOUSNESS",
	"LIGHT",
	"CRUSADER",
}

for _, familyKey in ipairs(ns.PALADIN_SEAL_FAMILY_ORDER) do
	local family = ns.PALADIN_SEAL_FAMILIES[familyKey]
	if family then
		for _, spellName in ipairs(family.names or {}) do
			if not ns.PALADIN_SEAL_NAME_LOOKUP[spellName] then
				ns.PALADIN_SEAL_NAME_LOOKUP[spellName] = familyKey
			end
			local localizedName = GetSpellInfo and GetSpellInfo(spellName)
			if localizedName and not ns.PALADIN_SEAL_NAME_LOOKUP[localizedName] then
				ns.PALADIN_SEAL_NAME_LOOKUP[localizedName] = familyKey
			end
		end

		for _, spellId in ipairs(family.ids) do
			if not ns.PALADIN_SEAL_LOOKUP[spellId] then
				ns.PALADIN_SEAL_LOOKUP[spellId] = familyKey
			end

			local spellName = GetSpellInfo and GetSpellInfo(spellId)
			if spellName and not ns.PALADIN_SEAL_NAME_LOOKUP[spellName] then
				ns.PALADIN_SEAL_NAME_LOOKUP[spellName] = familyKey
			end
		end
	end
end

function ns.GetPaladinSealFamilyBySpellId(spellId)
	if not spellId then
		return nil
	end
	return ns.PALADIN_SEAL_LOOKUP and ns.PALADIN_SEAL_LOOKUP[spellId] or nil
end

function ns.GetPaladinSealFamilyByAuraName(auraName)
	if not auraName then
		return nil
	end
	return ns.PALADIN_SEAL_NAME_LOOKUP and ns.PALADIN_SEAL_NAME_LOOKUP[auraName] or nil
end

-- Next-Melee-Attack (NMA) abilities: queue on the MH swing, fire
-- as SPELL_DAMAGE (not SWING_DAMAGE), reset MH timer on land.
-- OH is unaffected by NMAs.
ns.NMA_LOOKUP = {}
local function registerNMAs(ids)
	for _, id in ipairs(ids) do
		ns.NMA_LOOKUP[id] = true
	end
end

local function addSpellNamesToLookup(lookup)
	if type(GetSpellInfo) ~= "function" then
		return
	end

	local names = {}
	for spellId in pairs(lookup) do
		if type(spellId) == "number" then
			local spellName = GetSpellInfo(spellId)
			if spellName then
				names[#names + 1] = spellName
			end
		end
	end

	for _, spellName in ipairs(names) do
		lookup[spellName] = true
	end
end

-- Heroic Strike (Warrior)
ns.WARRIOR_HEROIC_STRIKE_SPELLS = {}
for _, id in ipairs({ 78, 284, 285, 1608, 11564, 11565, 11566, 11567, 25286, 29707, 30324 }) do
	ns.WARRIOR_HEROIC_STRIKE_SPELLS[id] = true
	registerNMAs({ id })
end

-- Cleave (Warrior)
ns.WARRIOR_CLEAVE_SPELLS = {}
for _, id in ipairs({ 845, 7369, 11608, 11609, 20569, 25231 }) do
	ns.WARRIOR_CLEAVE_SPELLS[id] = true
	registerNMAs({ id })
end

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
	2643, 14288, 14289, 14290, 25294, 27021,
	19434, 20900, 20901, 20902, 20903, 20904, 27065,
})

-- PAUSE_SWING_SPELLS: casts that should pause and then resume swing timing.
-- Slam uses the pause/extend path rather than a hard MH reset.
ns.PAUSE_SWING_SPELLS = {}
for _, id in ipairs({ 1464, 8820, 11604, 11605, 25241, 25242 }) do
	ns.PAUSE_SWING_SPELLS[id] = true
end

-- RESET_RANGED_SWING_SPELLS: landed spell effects that should restart ranged.
ns.RESET_RANGED_SWING_SPELLS = {}
for _, id in ipairs({ 14295, 11925, 11951 }) do
	ns.RESET_RANGED_SWING_SPELLS[id] = true
end

addSpellNamesToLookup(ns.NMA_LOOKUP)
addSpellNamesToLookup(ns.WARRIOR_HEROIC_STRIKE_SPELLS)
addSpellNamesToLookup(ns.WARRIOR_CLEAVE_SPELLS)
addSpellNamesToLookup(ns.RESET_SWING_SPELLS)
addSpellNamesToLookup(ns.NO_RESET_SWING_SPELLS)
addSpellNamesToLookup(ns.PAUSE_SWING_SPELLS)
addSpellNamesToLookup(ns.RESET_RANGED_SWING_SPELLS)

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
	{
		abbrev = "LB",
		label = "Lightning Bolt",
		ids = { 403, 529, 548, 915, 943, 6041, 10391, 10392, 15207, 15208, 25448, 25449 },
	},
	{ abbrev = "CL",  label = "Chain Lightning",     ids = { 421, 930, 2860, 10605, 25439, 25442 } },
	{
		abbrev = "HW",
		label = "Healing Wave",
		ids = { 331, 332, 547, 913, 939, 959, 8005, 10395, 10396, 25357, 25391, 25396 },
	},
	{ abbrev = "LHW", label = "Lesser Healing Wave", ids = { 8004, 8008, 8010, 10466, 10467, 10468, 25420 } },
	{ abbrev = "CH",  label = "Chain Heal",         ids = { 1064, 10622, 10623, 25422, 25423 } },
}

-- ============================================================
-- Class configuration
-- ============================================================
-- Determines which bars to create and which events to register.
ns.CLASS_CONFIG = {
	HUNTER  = { ranged = true,  melee = true,  dualWield = false, hunterCastBar = true },
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
	version   = 20,
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
	sparkTexture = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Square_FullWhite",
	sparkTextureLayer = "OVERLAY",
	weaveSparkTexture = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\target_indicator.tga",
	weaveSparkTextureLayer = "OVERLAY",
	weaveSparkWidth = 3,
	weaveSparkHeight = 20,
	weaveSparkAlpha = 0.95,
	sparkColor = { r = 1, g = 1, b = 1, a = 1 },
	weaveTriangleTopTexture = "Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Arrow",
	weaveTriangleBottomTexture = "Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Arrow",
	weaveTriangleTextureLayer = "OVERLAY",
	weaveTriangleSize = 6,
	weaveTriangleGap = 1,
	weaveTriangleAlpha = 1,
	weaveMarkerLayer = "OVERLAY",
	sparkWidth = 4,
	sparkHeight = 20,
	barBorderSize = 1,
	barBackgroundAlpha = 0.5,
	barBackgroundColor = { r = 0, g = 0, b = 0, a = 0.5 },
	barBorderColor = { r = 0, g = 0, b = 0, a = 1 },
	sparkAlpha = 1,
	minimalMode = false,
	lockBars = false,
	colors = {
		mh        = { r = 0, g = 0, b = 0, a = 1   },
		oh        = { r = 0, g = 0, b = 0, a = 1   },
		ranged    = { r = 0, g = 0, b = 0, a = 1   },
		sealTwist = { r = 0, g = 0, b = 0, a = 1 },
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

local function IsAddOnInstalled(addonKey)
	if type(GetAddOnInfo) ~= "function" then
		return true
	end

	return GetAddOnInfo(addonKey) ~= nil
end

function ns.GetTextureBrowserDisplayCategory(entry)
	if not entry then
		return ""
	end

	local category = entry.category or ""
	local style = entry.style or ""

	if category == "WeakAuras" then
		if style == "bar" then
			return "WeakAuras / Bars"
		end
		return "WeakAuras / Shapes"
	elseif category == "SharedMedia" then
		return string.format("SharedMedia / %s", style ~= "" and style or "media")
	elseif category == "Platynator" then
		return string.format("Platynator / %s", style ~= "" and style or "preset")
	elseif category == "Blizzard" then
		return string.format("Blizzard / %s", style ~= "" and style or "fallback")
	end

	return category
end

ns.TEXTURE_LIBRARY = nil

function ns.BuildTextureLibrary()
	local entries = {}
	local seen = {}

	local function addEntry(category, label, path, style, usage)
		if not path or path == "" or seen[path] then
			return
		end
		seen[path] = true
		entries[#entries + 1] = {
			category = category,
			style = style or category,
			usage = usage or "both",
			label = label,
			path = path,
		}
	end

	local weakAurasInstalled = IsAddOnInstalled("WeakAuras")
	local platynatorInstalled = IsAddOnInstalled("Platynator")

	local libStub = rawget(_G, "LibStub")
	local lsm = libStub and libStub("LibSharedMedia-3.0", true)
	if lsm and lsm.List and lsm.Fetch then
		for _, mediaType in ipairs({ "statusbar", "background", "border" }) do
			for _, name in ipairs(lsm:List(mediaType) or {}) do
				local usage = (mediaType == "statusbar") and "both" or "spark"
				addEntry("SharedMedia", name, lsm:Fetch(mediaType, name), mediaType, usage)
			end
		end
	end

	if weakAurasInstalled then
		local weakAurasShapeTextures = {
			{ label = "Square Full White", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Square_FullWhite" },
			{ label = "Target Indicator", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\target_indicator.tga" },
			{
				label = "Target Indicator Glow",
				path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\target_indicator_glow.tga",
			},
			{ label = "Triangle", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\triangle.tga" },
			{ label = "Triangle Border", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\triangle-border.tga" },
			{ label = "Triangle 45", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Triangle45.tga" },
			{
				label = "Square Alpha Gradient",
				path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Square_AlphaGradient.tga",
			},
			{ label = "Square White", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Square_White.tga" },
			{ label = "Square White Border", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Square_White_Border.tga" },
			{ label = "Square Smooth", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Square_Smooth.tga" },
			{ label = "Square Smooth Border", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Square_Smooth_Border.tga" },
			{
				label = "Square Smooth Border 2",
				path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Square_Smooth_Border2.tga",
			},
			{ label = "Square Squirrel", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Square_Squirrel.tga" },
			{
				label = "Square Squirrel Border",
				path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Square_Squirrel_Border.tga",
			},
			{
				label = "Circle Alpha Gradient In",
				path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Circle_AlphaGradient_In.tga",
			},
			{
				label = "Circle Alpha Gradient Out",
				path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Circle_AlphaGradient_Out.tga",
			},
			{ label = "Circle Smooth", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Circle_Smooth.tga" },
			{ label = "Circle Smooth 2", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Circle_Smooth2.tga" },
			{ label = "Circle Smooth Border", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Circle_Smooth_Border.tga" },
			{ label = "Circle Squirrel", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Circle_Squirrel.tga" },
			{
				label = "Circle Squirrel Border",
				path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Circle_Squirrel_Border.tga",
			},
			{ label = "Circle White", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Circle_White.tga" },
			{ label = "Circle White Border", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Circle_White_Border.tga" },
			{ label = "Ring 10px", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Ring_10px.tga" },
			{ label = "Ring 20px", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Ring_20px.tga" },
			{ label = "Ring 30px", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Ring_30px.tga" },
			{ label = "Ring 40px", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Ring_40px.tga" },
			{ label = "Trapezoid", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Trapezoid.tga" },
			{ label = "Striped Texture", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\StripedTexture.tga" },
			{ label = "Arrows Target", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\arrows_target.tga" },
			{ label = "Targeting Mark", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\targeting-mark.tga" },
		}

		for _, texture in ipairs(weakAurasShapeTextures) do
			addEntry("WeakAuras", texture.label, texture.path, "shape", "spark")
		end

		local weakAurasBarTextures = {
			{ label = "Statusbar Clean", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Statusbar_Clean.blp" },
			{ label = "Statusbar Stripes", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Statusbar_Stripes.blp" },
			{
				label = "Statusbar Stripes Thick",
				path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Statusbar_Stripes_Thick.blp",
			},
			{
				label = "Statusbar Stripes Thin",
				path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Statusbar_Stripes_Thin.blp",
			},
			{ label = "Rainbow Bar", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\rainbowbar.tga" },
			{ label = "Striped Bar", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\stripe-bar.tga" },
			{ label = "Striped Rainbow Bar", path = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\stripe-rainbow-bar.tga" },
		}

		for _, texture in ipairs(weakAurasBarTextures) do
			addEntry("WeakAuras", texture.label, texture.path, "bar", "both")
		end
	end

	if platynatorInstalled then
		-- Texture packs from other installed addons can be good bar-skin sources.
		addEntry("Platynator", "GW2", "Interface\\AddOns\\Platynator\\Assets\\gw2.png", "preset", "both")
		addEntry("Platynator", "ToxiUI G2", "Interface\\AddOns\\Platynator\\Assets\\ToxiUI-g2.tga", "preset", "both")
	end

	addEntry("Blizzard", "Status Bar", "Interface\\TargetingFrame\\UI-StatusBar", "fallback", "both")
	addEntry("Blizzard", "Casting Fill", "Interface\\CastingBar\\UI-CastingBar-Fill", "fallback", "both")
	addEntry("Blizzard", "Casting Spark", "Interface\\CastingBar\\UI-CastingBar-Spark", "fallback", "spark")
	addEntry("Blizzard", "Casting Shield", "Interface\\CastingBar\\UI-CastingBar-Shield", "fallback", "spark")
	addEntry("Blizzard", "Tooltip Background", "Interface\\Tooltips\\UI-Tooltip-Background", "fallback", "spark")
	addEntry("Blizzard", "Tooltip Border", "Interface\\Tooltips\\UI-Tooltip-Border", "fallback", "spark")
	addEntry("Blizzard", "Dialog Background", "Interface\\DialogFrame\\UI-DialogBox-Background", "fallback", "spark")
	addEntry(
		"Blizzard",
		"Dialog Dark Background",
		"Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
		"fallback",
		"spark"
	)
	addEntry("Blizzard", "Dialog Border", "Interface\\DialogFrame\\UI-DialogBox-Border", "fallback", "spark")
	addEntry(
		"Blizzard",
		"Scroll Arrow Down",
		"Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Arrow",
		"fallback",
		"spark"
	)
	addEntry("Blizzard", "Scroll Arrow Up", "Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Arrow", "fallback", "spark")
	addEntry("Blizzard", "White 8x8", "Interface\\Buttons\\WHITE8X8", "fallback", "both")

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

	if texturePath == ns.DB_DEFAULTS.sparkTexture then
		return "Normal"
	end

	if texturePath == ns.DB_DEFAULTS.weaveSparkTexture then
		return "Target Indicator"
	end

	local library = ns.TEXTURE_LIBRARY or ns.BuildTextureLibrary()
	if library then
		for _, entry in ipairs(library) do
			if entry.path == texturePath then
				if entry.category and entry.label then
					return string.format("%s / %s", entry.category, entry.label)
				end
				return entry.label or texturePath
			end
		end
	end

	return texturePath
end

function ns.GetTextureSummaryText(texturePath)
	local textureLabel = ns.GetTextureDisplayText(texturePath)
	local barLabel = ns.GetTextureDisplayText(ns.GetBarTexture and ns.GetBarTexture() or nil)
	return string.format("%s | Bar: %s", textureLabel, barLabel)
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
		local classColor = ns.GetPlayerClassColor()
		local alpha = 1
		if db and db.colors and db.colors[colorKey] and db.colors[colorKey].a ~= nil then
			alpha = db.colors[colorKey].a
		end
		return {
			r = classColor.r or 1,
			g = classColor.g or 1,
			b = classColor.b or 1,
			a = alpha,
		}
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
			local existingAlpha = db.colors[key] and db.colors[key].a or 1
			db.colors[key] = { r = classColor.r, g = classColor.g, b = classColor.b, a = existingAlpha }
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

-- Overlay textures live on a dedicated non-mouse frame above the bar, so the
-- requested draw layer can be preserved directly while still using a positive
-- sublayer to keep same-frame ordering predictable.
function ns.ResolveTextureLayerAboveBar(requestedLayer, barLayer)
	local layer = requestedLayer or "OVERLAY"
	return layer, 1
end

function ns.SetTextureLayerAboveBar(texture, requestedLayer, barLayer)
	if texture and texture.SetDrawLayer then
		local layer, subLayer = ns.ResolveTextureLayerAboveBar(requestedLayer, barLayer)
		texture:SetDrawLayer(layer, subLayer)
	end
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
	if db and db.barBackgroundColor and db.barBackgroundColor.a ~= nil then
		return db.barBackgroundColor.a
	end
	if db and db.barBackgroundAlpha ~= nil then
		return db.barBackgroundAlpha
	end
	return ns.DB_DEFAULTS.barBackgroundAlpha
end

function ns.GetBarBackgroundColor()
	local db = rawget(_G, "SuperSwingTimerDB")
	if db and db.barBackgroundColor then
		return db.barBackgroundColor
	end
	return ns.DB_DEFAULTS.barBackgroundColor
end

function ns.GetBarBorderSize()
	local db = rawget(_G, "SuperSwingTimerDB")
	if db and db.barBorderSize ~= nil then
		return db.barBorderSize
	end
	return ns.DB_DEFAULTS.barBorderSize
end

function ns.GetBarBorderColor()
	local db = rawget(_G, "SuperSwingTimerDB")
	if db and db.barBorderColor then
		return db.barBorderColor
	end
	return ns.DB_DEFAULTS.barBorderColor
end

function ns.GetSparkAlpha()
	local db = rawget(_G, "SuperSwingTimerDB")
	if db and db.sparkColor and db.sparkColor.a ~= nil then
		return db.sparkColor.a
	end
	if db and db.sparkAlpha ~= nil then
		return db.sparkAlpha
	end
	return ns.DB_DEFAULTS.sparkAlpha
end

function ns.GetSparkColor()
	local db = rawget(_G, "SuperSwingTimerDB")
	if db and db.sparkColor then
		return db.sparkColor
	end
	return ns.DB_DEFAULTS.sparkColor
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

