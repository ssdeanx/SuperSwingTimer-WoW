-- ============================================================
-- SuperSwingTimer_Forever.lua
-- WoW Forever (1.60.x) isolated feature module.
--
-- WHY THIS FILE EXISTS
--   WoW Forever exposes the modern secret-value system: while addon
--   restrictions are active (combat, encounter, challenge mode, PvP) every
--   AuraData field except auraInstanceID / isHelpful / isHarmful /
--   isFromPlayerOrPlayerPet / isNameplateOnly / isRaid can be a secret value.
--   Tainted addon code may not compare, index, or do arithmetic on a secret,
--   so the classic "scan UnitAura and match spellId" path cannot identify an
--   aura while restricted.
--
--   The client ships the sanctioned replacement: intrinsic AuraContainer /
--   AuraButton frames (CustomAuraContainerTemplate / CustomAuraButtonTemplate).
--   The addon declares the spell IDs it cares about and the *client* performs
--   the matching and writes icon, duration, stacks and duration-bar values
--   through secret-safe widget APIs. No secret value ever enters addon logic.
--
--   This file is loaded last and is a no-op on every non-Forever client:
--   ns.isForever is false, no frames are created, and the classic icon groups
--   in SuperSwingTimer_ClassMods.lua keep working exactly as before.
--
-- GATING
--   * ns.isForever            - client exposes C_SwingTimer + Enum.PlayerSwingType
--   * ns.hasAuraContainer     - client exposes C_AuraContainerUtil + sort enums
--   * every container call is pcall-protected; a failure falls back to the
--     classic icon groups (ns.foreverNativeAuraIcons stays false).
-- ============================================================

local _, ns = ...

-- ============================================================
-- 1. Client detection
-- ============================================================
local function IsForeverClient()
    return type(ns.HasNativeSwingTimer) == "function" and ns.HasNativeSwingTimer() == true
end

ns.isForever = IsForeverClient()

local function GetGlobal(name)
    return rawget(_G, name)
end

--- True when the client ships the 12.1 custom aura container intrinsics.
--  The sort enums are exported to _G by Blizzard_AuraContainerShared.lua and
--  C_AuraContainerUtil is the namespace that processes the display options.
--  @return (boolean) true when AuraContainer frames can be created
local function HasAuraContainerSupport()
    if type(GetGlobal("C_AuraContainerUtil")) ~= "table" then
        return false
    end
    if type(GetGlobal("AuraContainerSortMethod")) ~= "table" then
        return false
    end
    return type(GetGlobal("AuraContainerSortDirection")) == "table"
end

ns.hasAuraContainer = HasAuraContainerSupport()

-- ============================================================
-- 2. Aura secrecy helpers
-- ============================================================

--- True when aura queries currently produce secret values.
--  C_Secrets.ShouldAurasBeSecret() is the authoritative query. When it is
--  missing (Classic Era, TBC Anniversary, Titanforge) auras are never secret.
--  When it raises, fail closed: the caller must not touch aura fields.
--  @return (boolean) true when aura data must be treated as secret
function ns.IsAuraDataSecret()
    local cSecrets = GetGlobal("C_Secrets")
    if type(cSecrets) ~= "table" then
        return false
    end
    local shouldAurasBeSecret = cSecrets.ShouldAurasBeSecret
    if type(shouldAurasBeSecret) ~= "function" then
        return false
    end
    local ok, secret = pcall(shouldAurasBeSecret)
    if not ok then
        return true
    end
    return secret == true
end

--- Per-spell aura secrecy.
--  Enum.SecrecyLevel: 0 = NeverSecret, 1 = AlwaysSecret, 2 = ContextuallySecret.
--  A "NeverSecret" answer proves that spell's aura data is plain even while
--  restrictions are active, so the classic scan path is safe for that spell.
--  @param spellID (number) spell identifier
--  @return (number|nil) secrecy level, or nil when the client cannot answer
function ns.GetSpellAuraSecrecy(spellID)
    if type(spellID) ~= "number" then
        return nil
    end
    local cSecrets = GetGlobal("C_Secrets")
    if type(cSecrets) ~= "table" then
        return nil
    end
    local getSecrecy = cSecrets.GetSpellAuraSecrecy
    if type(getSecrecy) ~= "function" then
        return nil
    end
    local ok, secrecy = pcall(getSecrecy, spellID)
    if not ok or type(secrecy) ~= "number" then
        return nil
    end
    return secrecy
end

--- True when the given spell's aura can be read by tainted code right now.
--  NeverSecret always passes; ContextuallySecret passes only while no aura
--  restriction is active; AlwaysSecret never passes.
--  @param spellID (number) spell identifier
--  @return (boolean) true when a plain UnitAura scan is safe for this spell
function ns.IsSpellAuraReadable(spellID)
    local secrecy = ns.GetSpellAuraSecrecy(spellID)
    if secrecy == nil then
        -- No secrecy query on this client: the classic path is always plain.
        return not ns.IsAuraDataSecret()
    end
    -- Enum.SecrecyLevel.NeverSecret == 0
    if secrecy == 0 then
        return true
    end
    -- Enum.SecrecyLevel.AlwaysSecret == 1
    if secrecy == 1 then
        return false
    end
    -- ContextuallySecret: readable only while auras are not restricted.
    return not ns.IsAuraDataSecret()
end

--- Read one helpful player aura by spell ID on Forever.
--  The AuraData table and every field used here are probed before use; a
--  secret or forbidden value returns nil instead of entering addon logic.
--  This is the Forever path — it does not call the SoD module.
--  @param spellID (number) aura spell ID
--  @return (table|nil) { spellID, stacks, duration, expirationTime }
function ns.GetForeverPlayerAura(spellID)
    if not ns.isForever or type(spellID) ~= "number" then
        return nil
    end
    local cUnitAuras = GetGlobal("C_UnitAuras")
    if type(cUnitAuras) ~= "table"
        or type(cUnitAuras.GetPlayerAuraBySpellID) ~= "function" then
        return nil
    end
    -- GetPlayerAuraBySpellID is RequiresNonSecretAura: an AlwaysSecret aura
    -- returns nothing, so skip the call when the client already says so.
    if not ns.IsSpellAuraReadable(spellID) then
        return nil
    end
    local ok, auraData = pcall(cUnitAuras.GetPlayerAuraBySpellID, spellID)
    if not ok or type(auraData) ~= "table" or ns.IsSecretValue(auraData) then
        return nil
    end
    if ns.IsSecretValue(auraData.spellId) or ns.IsSecretValue(auraData.applications)
        or ns.IsSecretValue(auraData.duration) or ns.IsSecretValue(auraData.expirationTime) then
        return nil
    end
    return {
        spellID = ns.SafeNumber(auraData.spellId) or spellID,
        stacks = ns.SafeNumber(auraData.applications) or 1,
        duration = ns.SafeNumber(auraData.duration) or 0,
        expirationTime = ns.SafeNumber(auraData.expirationTime) or 0,
    }
end

--- Maelstrom Weapon on Forever: 408505 is the aura, 408498 the talent record.
--  @return (table|nil) normalized aura data with stacks clamped to 1..5
function ns.GetForeverMaelstromData()
    if not ns.isForever then
        return nil
    end
    local data = ns.GetForeverPlayerAura(408505) or ns.GetForeverPlayerAura(408498)
    if not data then
        return nil
    end
    local stacks = data.stacks or 1
    if stacks < 1 then stacks = 1 end
    if stacks > 5 then stacks = 5 end
    data.stacks = stacks
    return data
end

-- ============================================================
-- 3. Forever tracked spell data
-- ============================================================
-- Only melee-relevant buffs/debuffs are listed. The native container performs
-- the matching, so names/labels are diagnostic only. Spell IDs are the same
-- IDs already tracked by the classic modules plus the Forever additions in
-- section 4.
-- ============================================================

-- Buffs on the player (HELPFUL auras).
-- Forever values (build 1.60.1.70790, ForeverDB 1.60.1.70862) are called out
-- next to the spell; the client supplies the live duration, so only the ID
-- matters here. See bench/forever-melee-changes.md for sources.
ns.FOREVER_BUFF_SPELLS = {
    WARRIOR = {
        -- Battle Shout r1-r7 (Forever: 180 s)
        6673, 5242, 6192, 11549, 11550, 11551, 25289,
        -- Overpower r1-r4
        7384, 7887, 11584, 11585,
        2565,  -- Shield Block (Forever: 7 s)
        12319, 12320, -- Flurry talent + rank-1 buff aura
        12292, -- Death Wish (Forever: 30 s)
        1719,  -- Recklessness (Forever: 15 s)
        12328, -- Sweeping Strikes
        20230, -- Retaliation
        871,   -- Shield Wall (Forever: 12 s)
        12975, -- Last Stand
        23920, -- Spell Reflection
        18499, -- Berserker Rage
        30033, -- Rampage
        2687,  -- Bloodrage
        12317, -- Enrage
        -- Bloodthirst r1-r4 (Forever: new 10 s self buff)
        23881, 23892, 23893, 23894,
        1329555, -- Reckless Swings (Forever: new, 8 s)
    },
    PALADIN = {
        31884, -- Avenging Wrath
        642, 1020, -- Divine Shield r1-r2
        10278, 1022, 5599, -- Blessing of Protection r1-r3
        20925, 20927, 20928, 1239570, -- Holy Shield r1-r4 (r4 new in Forever)
        498, 5573, -- Divine Protection r1-r2
        -- Seal of the Crusader r1-r6
        21082, 20162, 20305, 20306, 20307, 20308,
        -- Seal of Command r1-r5
        20375, 20915, 20918, 20919, 20920,
        -- Seal of Fury: ability + triggered buff ranks
        1311649, 1311656, 1311647, 20163, 20419, 20421, 20422, 20423,
        20049, 20050, -- Vengeance talent + rank-1 buff aura
        1310735, -- Unsealed Wrath (Forever: new, 15 s / 3 stacks)
    },
    SHAMAN = {
        -- Lightning Shield r1-r7
        324, 325, 905, 945, 8134, 10431, 10432,
        52127, -- Water Shield
        -- Rockbiter Weapon r1-r7
        8017, 8018, 8019, 10399, 16314, 16315, 16316,
        30823, -- Shamanistic Rage
        16280, -- Flurry (Classic rank)
        16256, -- Flurry (Forever talent; buff aura is server-side)
        -- Windfury Weapon r1-r4
        8232, 8235, 10486, 16362,
        29180, -- Elemental Devastation
        425336, -- Rage of the Farseer (Forever: new, +30% attack speed, 25 s)
        408505, -- Maelstrom Weapon aura (Instant, 30 s, -20% Lightning Bolt)
        408498, -- Maelstrom Weapon talent/buff record (passive; harmless if not an aura)
        -- Windfury Totem r1-r3 / Grace of Air Totem r1-r3
        8512, 10613, 10614, 8835, 10627, 25359,
    },
    DRUID = {
        16870, -- Clearcasting
        5217,  -- Tiger's Fury
        22842, -- Frenzied Regeneration
        22812, -- Barkskin
        1850, 9821, -- Dash r1-r2
        5229,  -- Enrage
        29166, -- Innervate
    },
    HUNTER = {
        -- Aspect of the Hawk r1-r7
        13165, 14318, 14319, 14320, 14321, 14322, 25296,
        19506, -- Trueshot Aura
        19574, -- Bestial Wrath
        3045,  -- Rapid Fire
        34692, -- The Beast Within
        6150,  -- Quick Shots
        34949, -- Rapid Killing
        34477, -- Misdirection
        19552, -- Deadly Aspects (Forever: new, +30% melee haste, 12 s)
        -- Aspect of the Beast r1-r4
        13161, 1299445, 1299446, 1299447,
    },
    ROGUE = {
        5171, 6774, -- Slice and Dice r1-r2 (Forever: 9-21 s by CP)
        13750, -- Adrenaline Rush
        13877, -- Blade Flurry (Forever: +20% attack speed, 15 s)
        14177, -- Cold Blood
        5277,  -- Evasion
        2983, 8696, 11305, -- Sprint r1-r3
        1856, 1857, -- Vanish r1-r2
        14179, -- Premeditation (Forever: 20 s)
        36554, -- Shadowstep
        31209, -- Cloak of Shadows
        14278, -- Ghostly Strike (Forever: 7 s)
        1329328, 1310703, -- Venom ability + triggered buff aura
    },
}

-- Debuffs on the current target (HARMFUL auras). Values are merged from the
-- authoritative ID tables in SuperSwingTimer_Constants.lua so rank variants
-- stay in sync with the classic debuff bars.
--
-- AURA-ID NOTE: for a direct "Apply Aura" debuff the client exposes the same
-- spell ID as the cast. Verified against the Wowhead Forever buff tooltip
-- records: Serpent Sting 25295, Flame Shock 29228, Rend 11574, Thunder Clap
-- 6343, Demoralizing Shout 1160, Sunder Armor 7386. Talents that *trigger* a
-- separate aura do differ, so both IDs are listed: Flurry 12320, Vengeance
-- 20050, Seal of Fury 1311647, Venom 1310703, Deep Wounds 12721.
ns.FOREVER_DEBUFF_SPELLS = {
    WARRIOR = {
        772, 6546, 6547, 6548, 11572, 11573, 11574, -- Rend (Forever: unchanged)
        12721, 12834,                               -- Deep Wounds aura + talent candidate
        7386, 7405, 8380, 11596, 11597, 25225,      -- Sunder Armor (unchanged, 5 stacks)
        6343, 8198, 8204, 8205, 11580, 11581,       -- Thunder Clap (10 s, 20% slow)
        1160, 6190, 11554, 11555, 11556,            -- Demoralizing Shout (Forever: 45 s)
    },
    ROGUE = {
        1943, 8637, 8639, 8640, 11273, 11274, 11275, 26867, -- Rupture (Forever r6 = 11275)
        8647, 8649, 8650, 11197, 11198, 26996,       -- Expose Armor (Forever: 30 s)
        16511,                                       -- Hemorrhage (Forever: 15 s)
    },
    DRUID = {
        1079, 9492, 9493, 9752, 9894, 9896, 27008,    -- Rip (Forever: 12 s)
        1822, 1823, 1824, 9904, 27006,                -- Rake (r4 = 9904; 9907 is Faerie Fire)
        1328617, 1328616, 414644, 1235826, 1235827,   -- Lacerate (Forever r1-r5, 15 s / 5)
        770, 778, 9749, 9907,                         -- Faerie Fire (Forever: usable in forms, 40 s)
        99, 1735, 9490, 9747, 9898,                   -- Demoralizing Roar (Forever: 30 s)
        -- Mangle 33876/33878 and Faerie Fire (Feral) 16857 were removed from
        -- Forever; do not add them back.
    },
    SHAMAN = {
        8050, 8052, 8053, 10447, 10448, 29228,        -- Flame Shock (Forever: 12 s)
        17364,                                        -- Stormstrike (Forever: 12 s)
        8056, 8058, 10472, 10473,                     -- Frost Shock (Forever: 8 s slow)
        -- Earth Shock's 2 s lockout is a school lock, not a trackable aura.
    },
    PALADIN = {
        -- Judgement of the Crusader r2-r6 (Forever: 40 s)
        20188, 20300, 20301, 20302, 20303,
        -- Judgement of Light r1-r4 (Forever: 40 s)
        20185, 20344, 20345, 20346,
        -- Judgement of Wisdom r1-r3 (Forever: 40 s)
        20186, 20354, 20355,
        -- Judgement of Fury r3-r7 (Forever: new 3 s taunt)
        20183, 20411, 20412, 20413, 20414,
        -- Seal of Vengeance / Seal of Corruption do not exist in Forever.
    },
    HUNTER = {
        -- Serpent Sting: Forever rank 9 is 25295 (level 60); 27019 is the TBC
        -- rank and is kept only for TBC Anniversary.
        1978, 13549, 13550, 13551, 13552, 13553, 13554, 13555, 25295, 27019,
        -- Wing Clip: Forever ranks 2/3 are 14267/14268.
        2974, 14267, 14268,
        5116, 13585, 13586, 13587, 13588, 13589, 13590, 27068,         -- Concussion Shot
        13795, 14302,                                                  -- Immolation Trap
        13813, 14303, 14304, 14305,                                    -- Explosive Trap
        1499, 14310, 14311, 3355, 14308, 14309,                        -- Freezing Trap
        13809, 13810,                                                  -- Frost Trap
        -- Hunter's Mark: Forever ranks 1-4 are 1130/14323/14324/14325 (120 s).
        1130, 14323, 14324, 14325,
        1310533,                                                       -- Lacerating Strikes (Forever: 21 s bleed)
    },
}

-- New Forever abilities that may or may not apply an aura. The native groups
-- match by spell ID, and includeSpellIDs is a set, so a non-aura ID is a
-- harmless no-op. If the client exposes an aura under one of these IDs the
-- row picks it up without another data pass.
ns.FOREVER_NEW_ABILITY_CANDIDATES = {
    WARRIOR = {
        402927,  -- Victory Rush
        1310222, -- Spearing Strike
        1240193, -- Slam (Forever rebuild)
    },
    ROGUE = {
        1329283, -- Shank (off-hand strike, not a swing)
        399956,  -- Mutilate
    },
    DRUID = {
        407995,  -- Primal Bite (replaces Mangle)
    },
    SHAMAN = {
        408341,  -- Fire Nova
    },
    PALADIN = {
        679,     -- Holy Strike
    },
    HUNTER = {
        1317257, -- Strider Kick
        19306,   -- Counterattack
    },
}

-- Shared buffs are deliberately NOT merged into a class list: they can be
-- on any class and are combined with the class list only when the native
-- container is created. That keeps each class list pure.
ns.FOREVER_SHARED_BUFFS = {
    2825,  -- Bloodlust
    32182, -- Heroism
    35476, -- Drums of Battle
    35477, -- Drums of Speed
    28507, -- Haste Potion
}

-- Racial buffs are keyed by race token (UnitRace second return, then the
-- localized name as a fallback). A class list never carries another race's
-- racial.
ns.FOREVER_RACIAL_BUFFS = {
    Orc = { 20572 },        -- Blood Fury
    Troll = { 26297 },      -- Berserking
    Draenei = { 28880 },    -- Gift of the Naaru
    BloodElf = { 28730 },   -- Arcane Torrent
    Human = { 20600 },      -- Perception
    Dwarf = { 20594 },      -- Stoneform
    Gnome = { 20589 },      -- Escape Artist
    Undead = { 7744 },      -- Will of the Forsaken
    Scourge = { 7744 },     -- UnitRace file token for Undead
    NightElf = { 58984 },   -- Shadowmeld
}

local function AppendUnique(list, values)
    local seen = {}
    for _, value in ipairs(list) do
        seen[value] = true
    end
    for _, value in ipairs(values) do
        if type(value) == "number" and not seen[value] then
            seen[value] = true
            list[#list + 1] = value
        end
    end
end

for class, classList in pairs(ns.FOREVER_BUFF_SPELLS) do
    local candidates = ns.FOREVER_NEW_ABILITY_CANDIDATES[class]
    if candidates then
        AppendUnique(classList, candidates)
    end
end
for class, classList in pairs(ns.FOREVER_DEBUFF_SPELLS) do
    local candidates = ns.FOREVER_NEW_ABILITY_CANDIDATES[class]
    if candidates then
        AppendUnique(classList, candidates)
    end
end

-- ============================================================
-- 4. Forever class/spec additions
-- ============================================================
-- Populated from the Forever class-change research. Each entry is a plain
-- spell ID added to the matching list above. Kept separate so the base lists
-- stay auditable against the classic modules.
-- ============================================================

ns.FOREVER_EXTRA_BUFFS = {
    -- WARRIOR = { ... },
    -- ROGUE = { ... },
}

ns.FOREVER_EXTRA_DEBUFFS = {
    -- WARRIOR = { ... },
    -- ROGUE = { ... },
}

for class, ids in pairs(ns.FOREVER_EXTRA_BUFFS) do
    local list = ns.FOREVER_BUFF_SPELLS[class]
    if list then
        AppendUnique(list, ids)
    end
end

for class, ids in pairs(ns.FOREVER_EXTRA_DEBUFFS) do
    local list = ns.FOREVER_DEBUFF_SPELLS[class]
    if list then
        AppendUnique(list, ids)
    end
end

--- Build the includeSpellIDs map the native container expects.
--  @param list (table) array of numeric spell IDs
--  @return (table) map of spellID -> true
function ns.BuildAuraSpellIDMap(list)
    local map = {}
    for _, spellID in ipairs(list or {}) do
        if type(spellID) == "number" then
            map[spellID] = true
        end
    end
    return map
end

-- ============================================================
-- 5. Native aura icon groups
-- ============================================================
local BUFF_TOGGLE_BY_CLASS = {
    WARRIOR = "showWarriorBuffIcons",
    PALADIN = "showPaladinBuffIcons",
    SHAMAN = "showShamanBuffIcons",
    DRUID = "showDruidBuffIcons",
    HUNTER = "showHunterBuffIcons",
    ROGUE = "showRogueBuffIcons",
}

local BUFF_SIZE_BY_CLASS = {
    WARRIOR = "warriorBuffIconSize",
    PALADIN = "paladinBuffIconSize",
    SHAMAN = "shamanBuffIconSize",
    DRUID = "druidBuffIconSize",
    HUNTER = "hunterBuffIconSize",
    ROGUE = "rogueBuffIconSize",
}

local BUFF_ROW_GAP = 4
local DEBUFF_BAR_EXTRA = 10
local AURA_FRAME_STRATA = "DIALOG"

local function GetDB()
    return rawget(_G, "SuperSwingTimerDB") or ns.DB_DEFAULTS
end

local function GetFontPath()
    return (ns.GetDefaultFont and ns.GetDefaultFont())
        or rawget(_G, "STANDARD_TEXT_FONT")
        or "Fonts\\FRIZQT__.TTF"
end

local function GetBarTexture()
    return (ns.GetBarTexture and ns.GetBarTexture())
        or "Interface\\TargetingFrame\\UI-StatusBar"
end

--- Vertical offset (above the primary bar) for the native icon rows.
--  SuperSwingTimer_ClassMods.lua publishes the exact offset its classic icon
--  groups use (8 px above the tallest visible debuff bar). Reusing it keeps
--  the Forever rows in the same place without reading any aura data.
--  @return (number) offset in pixels
local function ComputeIconYOffset()
    local offset = ns.debuffStackIconOffset
    if type(offset) == "number" and offset > 0 then
        return offset
    end
    return 8
end

--- Build a colour curve that turns the duration text red below 4 seconds.
--  The classic icon groups pulse a glow in the last 4 seconds, which requires
--  reading the remaining duration. With secret auras that read is illegal, so
--  the client's DurationTextBinding evaluates the curve against the secret
--  duration internally and only the resulting colour reaches the font string.
--  @return (table|nil) { curve = ..., property = ... } or nil when unsupported
local function CreateLowTimeTextColor()
    local curveUtil = GetGlobal("C_CurveUtil")
    local enumTable = GetGlobal("Enum")
    local propertyEnum = enumTable and enumTable.DurationTextBindingProperty
    if type(curveUtil) ~= "table" or type(curveUtil.CreateColorCurve) ~= "function"
        or type(propertyEnum) ~= "table" or propertyEnum.RemainingDuration == nil then
        return nil
    end

    local ok, curve = pcall(curveUtil.CreateColorCurve)
    if not ok or not curve then
        return nil
    end

    -- RemainingDuration is expressed in seconds. Red at 0-4s, white above.
    local pointsOk = pcall(function()
        curve:AddPoint(0, { r = 1, g = 0.25, b = 0.25, a = 1 })
        curve:AddPoint(4, { r = 1, g = 0.25, b = 0.25, a = 1 })
        curve:AddPoint(4.01, { r = 1, g = 1, b = 1, a = 0.95 })
        curve:AddPoint(3600, { r = 1, g = 1, b = 1, a = 0.95 })
    end)
    if not pointsOk then
        return nil
    end
    return { curve = curve, property = propertyEnum.RemainingDuration }
end

local LOW_TIME_TEXT_COLOR = nil
local lowTimeColorInitialized = false

local function GetLowTimeTextColor()
    if not lowTimeColorInitialized then
        lowTimeColorInitialized = true
        LOW_TIME_TEXT_COLOR = CreateLowTimeTextColor()
    end
    return LOW_TIME_TEXT_COLOR
end

--- Create and register one styled aura button.
--  Runs inside securecallfunction from the frame provider, so every widget
--  call is pcall-protected: a failure leaves the frame without that element
--  instead of aborting the whole container.
--  @param frame (Frame) AuraButton created by the container
--  @param options (table) size / withBar / withCooldown flags
local function StyleAuraButton(frame, options)
    local size = options.size
    local ok = pcall(function()
        frame:SetSize(size, size)
    end)
    if not ok then
        return
    end

    -- Icon texture: the client writes the aura's icon into it (secret-safe).
    pcall(function()
        local icon = frame:CreateTexture(nil, "BACKGROUND")
        icon:SetAllPoints()
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        frame:SetIcon(icon)
    end)

    -- 4-edge outline border, matching the classic icon groups.
    pcall(function()
        local edges = {
            { "TOPLEFT", -1, 1, "TOPRIGHT", 1, 1, "HEIGHT" },
            { "BOTTOMLEFT", -1, -1, "BOTTOMRIGHT", 1, -1, "HEIGHT" },
            { "TOPLEFT", -1, 1, "BOTTOMLEFT", -1, -1, "WIDTH" },
            { "TOPRIGHT", 1, 1, "BOTTOMRIGHT", 1, -1, "WIDTH" },
        }
        for _, edge in ipairs(edges) do
            local texture = frame:CreateTexture(nil, "OVERLAY", nil, -1)
            texture:SetPoint(edge[1], edge[2], edge[3])
            texture:SetPoint(edge[4], edge[5], edge[6])
            if edge[7] == "HEIGHT" then
                texture:SetHeight(1)
            else
                texture:SetWidth(1)
            end
            texture:SetColorTexture(0, 0, 0, 0.65)
        end
    end)

    -- Remaining-duration text above the icon.
    pcall(function()
        local durationText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        durationText:SetPoint("BOTTOM", frame, "TOP", 0, 2)
        durationText:SetJustifyH("CENTER")
        durationText:SetFont(GetFontPath(), 12, "OUTLINE")
        durationText:SetTextColor(1, 1, 1, 0.95)
        frame:SetDurationText(durationText, { textColor = GetLowTimeTextColor() })
    end)

    -- Stack / application count in the bottom-right corner.
    pcall(function()
        local countText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        countText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
        countText:SetJustifyH("RIGHT")
        countText:SetFont(GetFontPath(), 11, "OUTLINE")
        countText:SetTextColor(1, 1, 1, 1)
        frame:SetApplicationCount(countText)
    end)

    -- Optional thin duration bar under the icon (debuff group).
    if options.withBar then
        pcall(function()
            local bar = CreateFrame("StatusBar", nil, frame)
            bar:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -2)
            bar:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -2)
            bar:SetHeight(3)
            bar:SetStatusBarTexture(GetBarTexture())
            bar:SetMinMaxValues(0, 1)
            bar:SetValue(0)
            bar:SetFrameLevel(frame:GetFrameLevel() + 1)
            local directionEnum = GetGlobal("Enum")
            local direction = directionEnum and directionEnum.StatusBarTimerDirection
            local opts
            if direction and direction.RemainingTime ~= nil then
                opts = { direction = direction.RemainingTime }
            end
            frame:SetDurationBar(bar, opts)
        end)
    end

    -- Optional cooldown sweep (buff group), matching the classic urgency cue.
    if options.withCooldown then
        pcall(function()
            local cooldown
            local templateOk, templated = pcall(CreateFrame, "Cooldown", nil, frame,
                "CooldownFrameTemplate")
            if templateOk and templated then
                cooldown = templated
                if cooldown.SetReverse then cooldown:SetReverse(true) end
                if cooldown.SetHideCountdownNumbers then
                    cooldown:SetHideCountdownNumbers(true)
                end
            else
                cooldown = CreateFrame("Cooldown", nil, frame)
            end
            cooldown:SetAllPoints()
            frame:SetDurationCooldown(cooldown)
        end)
    end
end

--- Create one native aura group container.
--  @param groupKey (string) unique group key inside the container
--  @param unitToken (string) "player" or "target"
--  @param filter (string) "HELPFUL" or "HARMFUL"
--  @param spellList (table) array of spell IDs to match
--  @param options (table) size / withBar / withCooldown
--  @return (Frame|nil) the container, or nil when creation failed
local function CreateAuraGroupContainer(groupKey, unitToken, filter, spellList, options)
    local ok, container = pcall(CreateFrame, "AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
    if not ok or not container then
        return nil
    end

    local spellMap = ns.BuildAuraSpellIDMap(spellList)
    local spellCount = 0
    for _ in pairs(spellMap) do
        spellCount = spellCount + 1
    end
    if spellCount == 0 then
        return nil
    end

    local setupOk = pcall(function()
        container:SetSize(1, 1)
        container:SetFrameStrata(AURA_FRAME_STRATA)
        container:SetUnit(unitToken)

        local maxFrames = spellCount
        if maxFrames > 16 then
            maxFrames = 16
        end

        local groupOptions = {
            candidateFilters = { includeSpellIDs = spellMap },
            maxFrameCount = maxFrames,
            layout = {
                elementWidth = options.size,
                elementHeight = options.size,
                elementSpacing = 3,
            },
            initializeFrame = function(frame)
                StyleAuraButton(frame, options)
            end,
        }

        local sortMethod = GetGlobal("AuraContainerSortMethod")
        local sortDirection = GetGlobal("AuraContainerSortDirection")
        if sortMethod and sortMethod.Expiration ~= nil then
            groupOptions.sortMethod = sortMethod.Expiration
        end
        if sortDirection and sortDirection.Normal ~= nil then
            groupOptions.sortDirection = sortDirection.Normal
        end

        container:AddAuraGroup(groupKey, filter, groupOptions)
        container:SetFlowLayoutAnchorPoint("BOTTOM")
        container:SetEnabled(true)
        container:Show()
    end)

    if not setupOk then
        return nil
    end
    return container
end

-- ============================================================
-- 6. Runtime state
-- ============================================================
ns.foreverAura = {
    buffContainer = nil,
    debuffContainer = nil,
    buffSize = 25,
    debuffSize = 22,
    lastYOffset = nil,
    lastBuffSize = nil,
    lastDebuffSize = nil,
    lastAnchorBar = nil,
    initAttempts = 0,
    initError = nil,
}

--- True once the native groups are live; the classic updaters then stand down.
ns.foreverNativeAuraIcons = false

-- Mirrors GetDebuffAnchorBar() in SuperSwingTimer_ClassMods.lua: Hunters
-- prefer the visible MH bar, everyone else uses the MH bar.
local function GetAnchorBar()
    if ns.playerClass == "HUNTER" then
        if ns.mhBar and ns.mhBar.IsShown and ns.mhBar:IsShown()
            and ns.mhBar.GetAlpha and (ns.mhBar:GetAlpha() or 0) > 0 then
            return ns.mhBar
        end
        if ns.rangedBar and ns.rangedBar.GetAlpha and (ns.rangedBar:GetAlpha() or 0) > 0 then
            return ns.rangedBar
        end
        return ns.rangedBar or ns.mhBar
    end
    return ns.mhBar or ns.rangedBar
end

local function GetBuffToggle()
    local db = GetDB()
    local key = BUFF_TOGGLE_BY_CLASS[ns.playerClass]
    if not key or not db then
        return true
    end
    return db[key] ~= false
end

local function GetDebuffToggle()
    local db = GetDB()
    if not db then
        return true
    end
    return db.showForeverDebuffIcons ~= false
end

--- Buffs for the player's own race only. UnitRace returns (localizedName,
-- raceFile); either token may be used, and an unknown race simply adds nothing.
--  @return (table|nil) array of racial buff spell IDs
local function GetPlayerRacialBuffList()
    local unitRace = rawget(_G, "UnitRace")
    if type(unitRace) ~= "function" then
        return nil
    end
    local ok, raceName, raceFile = pcall(unitRace, "player")
    if not ok then
        return nil
    end
    -- A secret race token cannot be used as a table key; SafeString turns it
    -- into nil and the racial list is simply skipped.
    local safeName = ns.SafeString and ns.SafeString(raceName) or raceName
    local safeFile = ns.SafeString and ns.SafeString(raceFile) or raceFile
    if type(safeFile) == "string" then
        local byFile = ns.FOREVER_RACIAL_BUFFS[safeFile]
        if byFile then
            return byFile
        end
    end
    if type(safeName) == "string" then
        return ns.FOREVER_RACIAL_BUFFS[safeName]
    end
    return nil
end

local function GetBuffSize()
    local db = GetDB()
    local key = BUFF_SIZE_BY_CLASS[ns.playerClass]
    local size = key and db and db[key] or nil
    if type(size) ~= "number" or size <= 0 then
        size = 25
    end
    return size
end

local function GetDebuffSize()
    local db = GetDB()
    local size = db and db.foreverDebuffIconSize or nil
    if type(size) ~= "number" or size <= 0 then
        size = 22
    end
    return size
end

--- Reposition the two containers above the primary swing bar.
--  Called on init and whenever the bar or debuff-bar visibility changes.
local function ApplyContainerAnchors()
    local state = ns.foreverAura
    local bar = GetAnchorBar()
    if not bar then
        return
    end
    local yOffset = ComputeIconYOffset()
    local buffSize = state.buffSize
    local debuffSize = state.debuffSize

    if state.buffContainer then
        pcall(function()
            state.buffContainer:ClearAllPoints()
            state.buffContainer:SetPoint("BOTTOM", bar, "TOP", 0, yOffset)
        end)
    end
    if state.debuffContainer then
        pcall(function()
            state.debuffContainer:ClearAllPoints()
            state.debuffContainer:SetPoint("BOTTOM", bar, "TOP", 0,
                yOffset + buffSize + BUFF_ROW_GAP + DEBUFF_BAR_EXTRA)
        end)
    end
    state.lastYOffset = yOffset
    state.lastBuffSize = buffSize
    state.lastDebuffSize = debuffSize
    state.lastAnchorBar = bar
end

--- Create the native groups once the bars and class are known.
--  Safe to call repeatedly; only the first successful call creates frames.
function ns.InitForeverAuraIcons()
    local state = ns.foreverAura
    if ns.foreverNativeAuraIcons then
        return true
    end
    if not ns.isForever or not ns.hasAuraContainer then
        return false
    end
    if not ns.playerClass or not GetAnchorBar() then
        return false
    end

    state.initAttempts = state.initAttempts + 1
    local buffList = ns.FOREVER_BUFF_SPELLS[ns.playerClass]
    local debuffList = ns.FOREVER_DEBUFF_SPELLS[ns.playerClass]
    if not buffList and not debuffList then
        return false
    end

    state.buffSize = GetBuffSize()
    state.debuffSize = GetDebuffSize()

    -- Class list + shared buffs + the player's own racials. The class list
    -- itself stays pure; nothing from another class is merged into it.
    local containerBuffList = nil
    if buffList then
        containerBuffList = {}
        AppendUnique(containerBuffList, buffList)
        AppendUnique(containerBuffList, ns.FOREVER_SHARED_BUFFS)
        local racials = GetPlayerRacialBuffList()
        if racials then
            AppendUnique(containerBuffList, racials)
        end
    end

    if containerBuffList and #containerBuffList > 0 then
        local container = CreateAuraGroupContainer("forever_buffs", "player", "HELPFUL", containerBuffList, {
            size = state.buffSize,
            withBar = false,
            withCooldown = false,
        })
        if container then
            state.buffContainer = container
        else
            state.initError = "buff container creation failed"
        end
    end

    if debuffList and #debuffList > 0 then
        -- "PLAYER" is the client's own-caster filter (AuraUtil.lua:274:
        -- "Include only auras that were cast by the player, or by the player's
        -- pet or vehicle"). That is what keeps another hunter's Serpent Sting
        -- or another shaman's Flame Shock off this row when several are on the
        -- same mob.
        local container = CreateAuraGroupContainer("forever_debuffs", "target", "HARMFUL|PLAYER", debuffList, {
            size = state.debuffSize,
            withBar = true,
            withCooldown = false,
        })
        if container then
            state.debuffContainer = container
        else
            state.initError = (state.initError and (state.initError .. "; ") or "")
                .. "debuff container creation failed"
        end
    end

    if not state.buffContainer and not state.debuffContainer then
        return false
    end

    ns.foreverNativeAuraIcons = true
    -- The native containers drive their own updates. Zero the classic counter
    -- so ns.HasActiveTimers does not keep the swing loop alive for icons that
    -- are no longer rendered by the legacy path.
    ns.activeBuffIconCount = 0
    ApplyContainerAnchors()
    ns.UpdateForeverAuraIcons(0)
    return true
end

--- Resize every frame the container has allocated for a group.
--  Layout options control spacing, but the button frames keep their own size,
--  so a settings change must resize the allocated frames as well. Each call is
--  pcall-protected: frames are inaccessible to tainted code while aura data is
--  secret, and the next unrestricted tick picks the new size up.
--  @param container (Frame) aura container
--  @param groupKey (string) registered group key
--  @param size (number) new square icon size
local function ResizeGroupFrames(container, groupKey, size)
    if not container or not container.GetAuraGroupFrameCount
        or not container.GetAuraGroupFrame then
        return
    end
    local ok, count = pcall(container.GetAuraGroupFrameCount, container, groupKey)
    if not ok or type(count) ~= "number" then
        return
    end
    for index = 1, count do
        local frameOk, frame = pcall(container.GetAuraGroupFrame, container, groupKey, index)
        if frameOk and frame and frame.SetSize then
            pcall(frame.SetSize, frame, size, size)
        end
    end
end

--- Per-frame maintenance for the native groups.
--  Re-anchors when the primary bar moves, the debuff-bar stack changes, or
--  the configured icon size changes. No aura data is read here.
--  @param elapsed (number) seconds since the previous frame
function ns.UpdateForeverAuraIcons(elapsed)
    local state = ns.foreverAura
    if not ns.foreverNativeAuraIcons then
        return
    end

    local buffVisible = GetBuffToggle()
    local debuffVisible = GetDebuffToggle()
    -- While auras are readable the classic groups already render the buffs
    -- (including cooldown-only icons); the native buff row only takes over
    -- when reading an AuraData field would be illegal.
    local nativeBuffVisible = buffVisible and ns.IsAuraDataSecret()

    if state.buffContainer then
        pcall(function()
            if nativeBuffVisible then state.buffContainer:Show() else state.buffContainer:Hide() end
        end)
    end
    if state.debuffContainer then
        pcall(function()
            if debuffVisible then state.debuffContainer:Show() else state.debuffContainer:Hide() end
        end)
    end

    -- Size changes require a fresh layout definition.
    local buffSize = GetBuffSize()
    local debuffSize = GetDebuffSize()
    if buffSize ~= state.buffSize and state.buffContainer then
        local ok = pcall(function()
            state.buffContainer:SetAuraGroupLayout("forever_buffs", {
                elementWidth = buffSize,
                elementHeight = buffSize,
                elementSpacing = 3,
            })
            ResizeGroupFrames(state.buffContainer, "forever_buffs", buffSize)
        end)
        if ok then
            state.buffSize = buffSize
        end
    end
    if debuffSize ~= state.debuffSize and state.debuffContainer then
        local ok = pcall(function()
            state.debuffContainer:SetAuraGroupLayout("forever_debuffs", {
                elementWidth = debuffSize,
                elementHeight = debuffSize,
                elementSpacing = 3,
            })
            ResizeGroupFrames(state.debuffContainer, "forever_debuffs", debuffSize)
        end)
        if ok then
            state.debuffSize = debuffSize
        end
    end

    -- Re-anchor only when something that affects the offset changed.
    local yOffset = ComputeIconYOffset()
    local anchorBar = GetAnchorBar()
    if anchorBar and (anchorBar ~= state.lastAnchorBar
            or yOffset ~= state.lastYOffset
            or buffSize ~= state.lastBuffSize
            or debuffSize ~= state.lastDebuffSize) then
        ApplyContainerAnchors()
    end
end

-- ============================================================
-- 7. Hand-over between the classic and native icon rows
-- ============================================================
-- The classic per-class icon groups are NOT wrapped or disabled. They keep
-- running exactly as before and simply hide themselves while aura data is
-- secret, because ns.UnitAura correctly returns nil instead of reading a
-- restricted field. That preserves every classic feature while auras are
-- readable (cooldown-only icons such as Kill Command / Readiness / Lay on
-- Hands, the 4 s glow, the exact duration formatting).
--
-- The native buff row is shown only while ns.IsAuraDataSecret() is true, so
-- the two rows never display the same aura at the same time. The native
-- debuff row is additive: it is the requested "own icon group" for target
-- debuffs and is shown independently of the classic thin bars.

-- ============================================================
-- 8. Initialization events
-- ============================================================
-- The swing bars are created during the addon's ADDON_LOADED handler, so the
-- containers are created on PLAYER_LOGIN / PLAYER_ENTERING_WORLD once the
-- bars and the player class exist. A light OnUpdate retries a bounded number
-- of times (for load-order and target-frame timing) and then keeps the two
-- rows anchored above the primary bar.
if ns.isForever and ns.hasAuraContainer then
    local initFrame = CreateFrame("Frame")
    initFrame:RegisterEvent("PLAYER_LOGIN")
    initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    initFrame:SetScript("OnEvent", function()
        ns.InitForeverAuraIcons()
    end)

    local elapsedSinceRetry = 0
    local elapsedSinceMaintain = 0
    initFrame:SetScript("OnUpdate", function(_, elapsed)
        if ns.foreverNativeAuraIcons then
            elapsedSinceMaintain = elapsedSinceMaintain + (elapsed or 0)
            if elapsedSinceMaintain >= 0.25 then
                elapsedSinceMaintain = 0
                ns.UpdateForeverAuraIcons(elapsed)
            end
            return
        end
        elapsedSinceRetry = elapsedSinceRetry + (elapsed or 0)
        if elapsedSinceRetry < 0.5 then
            return
        end
        elapsedSinceRetry = 0
        if ns.foreverAura.initAttempts >= 20 then
            -- Native setup failed permanently: the classic groups were never
            -- suppressed, so nothing else needs to be restored.
            return
        end
        ns.InitForeverAuraIcons()
    end)
    ns.foreverAura.initFrame = initFrame
end

-- ============================================================
-- 9. Diagnostics
-- ============================================================
--- Snapshot of the Forever aura subsystem for /sst diag.
--  @return (table) plain diagnostic values
function ns.GetForeverAuraDiagnostics()
    local state = ns.foreverAura
    local buffCount = nil
    local debuffCount = nil
    if state.buffContainer and state.buffContainer.GetAuraGroupFrameCount then
        local ok, count = pcall(state.buffContainer.GetAuraGroupFrameCount, state.buffContainer,
            "forever_buffs")
        if ok then
            buffCount = ns.SafeNumber and ns.SafeNumber(count) or count
        end
    end
    if state.debuffContainer and state.debuffContainer.GetAuraGroupFrameCount then
        local ok, count = pcall(state.debuffContainer.GetAuraGroupFrameCount, state.debuffContainer,
            "forever_debuffs")
        if ok then
            debuffCount = ns.SafeNumber and ns.SafeNumber(count) or count
        end
    end
    local buffSpells = 0
    local debuffSpells = 0
    if ns.playerClass then
        local buffList = ns.FOREVER_BUFF_SPELLS[ns.playerClass]
        local debuffList = ns.FOREVER_DEBUFF_SPELLS[ns.playerClass]
        buffSpells = buffList and #buffList or 0
        debuffSpells = debuffList and #debuffList or 0
    end
    return {
        isForever = ns.isForever,
        hasAuraContainer = ns.hasAuraContainer,
        nativeActive = ns.foreverNativeAuraIcons,
        buffContainer = state.buffContainer ~= nil,
        debuffContainer = state.debuffContainer ~= nil,
        buffFrames = buffCount,
        debuffFrames = debuffCount,
        buffSpells = buffSpells,
        debuffSpells = debuffSpells,
        auraSecret = ns.IsAuraDataSecret(),
        initAttempts = state.initAttempts,
        initError = state.initError,
    }
end
