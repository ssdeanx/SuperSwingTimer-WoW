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
--  This is the Forever path; it uses C_UnitAuras directly.
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
-- 2b. Forever Maelstrom Weapon (weaving input)
-- ============================================================
ns.FOREVER_MAELSTROM_AURA_ID = 408505
ns.FOREVER_MAELSTROM_TALENT_ID = 408498
ns.foreverMaelstromStacks = 0
ns.foreverMaelstromMultiplier = 1.0

--- Read the live Maelstrom Weapon stacks on Forever.
--  Returns nil when the aura is absent or unreadable. An unreadable read
--  clears the cached value so the weave math can never use stale stacks.
--  @return (number|nil) stacks in 1..5
function ns.GetForeverMaelstromStacks()
    local data = ns.GetForeverMaelstromData()
    if not data then
        ns.foreverMaelstromStacks = 0
        ns.foreverMaelstromMultiplier = 1.0
        ns.maelstromStacks = 0
        ns.maelstromCastTimeMultiplier = 1.0
        return nil
    end
    local multiplier = 1.0 - (0.20 * data.stacks)
    if multiplier < 0 then
        multiplier = 0
    end
    ns.foreverMaelstromStacks = data.stacks
    ns.foreverMaelstromMultiplier = multiplier
    ns.maelstromStacks = data.stacks
    ns.maelstromCastTimeMultiplier = multiplier
    return data.stacks
end

--- Cast-time multiplier from Maelstrom Weapon for one weave spell.
--  Only Lightning Bolt is reduced; Chain Lightning and the heals return 1.0.
--  @param abbrev (string|nil) weave spell abbreviation
--  @return (number) multiplier in [0, 1]
function ns.ForeverMaelstromMultiplier(abbrev)
    if not ns.isForever or abbrev ~= "LB" then
        return 1.0
    end
    if not ns.GetForeverMaelstromStacks() then
        return 1.0
    end
    return ns.foreverMaelstromMultiplier
end

--- A successful Lightning Bolt consumes every Maelstrom Weapon stack.
function ns.ForeverMaelstromConsume()
    ns.foreverMaelstromStacks = 0
    ns.foreverMaelstromMultiplier = 1.0
    ns.maelstromStacks = 0
    ns.maelstromCastTimeMultiplier = 1.0
end

-- ============================================================
-- 2b-2. Forever swing-delay rules
-- ============================================================
--- True when a Forever Slam cast should still delay the melee swing.
--  Improved Slam (12862) explicitly removes Slam's swing delay; without the
--  talent the cast still pushes the next swing. Non-Forever clients are never
--  affected because the helper returns false when ns.isForever is false.
--  @param spellId (number|nil) cast spell ID
--  @return (boolean) true when the swing should pause for this cast
function ns.ForeverSlamPausesSwing(spellId)
    if not ns.isForever or tonumber(spellId) ~= 1240193 then
        return false
    end
    local isPlayerSpell = rawget(_G, "IsPlayerSpell")
    if type(isPlayerSpell) == "function" then
        local ok, known = pcall(isPlayerSpell, 12862)
        if ok then
            return known ~= true
        end
    end
    -- Unknown talent state: keep the delay rather than dropping it.
    return true
end

-- ============================================================
-- 2c. Forever weave spell families
-- ============================================================
-- Ranks verified on ForeverDB (build 1.60.1.70862). The live GetSpellInfo
-- supplies each rank's cast time, so the weave marker uses the real Forever
-- value: LB r1 1.5 s, r2 2.0 s, r3-r10 2.5 s (Classic r4+ is 3.0 s);
-- CL 2.5 s for every rank (Forever changed it from 2.0 s); HW 2.5 s;
-- LHW 1.5 s; CH 2.5 s. TBC-only rank IDs do not exist on Forever and are
-- intentionally absent.
ns.FOREVER_WEAVE_SPELL_GROUPS = {
    {
        abbrev = "LB",
        label = "Lightning Bolt",
        castTime = 2.5,
        ids = { 403, 529, 548, 915, 943, 6041, 10391, 10392, 15207, 15208 },
    },
    {
        abbrev = "CL",
        label = "Chain Lightning",
        castTime = 2.5,
        ids = { 421, 930, 2860, 10605 },
    },
    {
        abbrev = "HW",
        label = "Healing Wave",
        castTime = 2.5,
        ids = { 331, 332, 547, 913, 939, 959, 8005, 10395, 10396, 25357 },
    },
    {
        abbrev = "LHW",
        label = "Lesser Healing Wave",
        castTime = 1.5,
        ids = { 8004, 8008, 8010, 10466, 10467, 10468 },
    },
    {
        abbrev = "CH",
        label = "Chain Heal",
        castTime = 2.5,
        ids = { 1064, 10622, 10623 },
    },
}

-- ============================================================
-- 3. Forever tracked spell data
-- ============================================================
-- Separated into three distinct visual tiers on WoW Forever:
--   1. FOREVER_STANCE_SPELLS : Permanent/long-duration active states (Aspects,
--      Stances, Forms, Seals, Shields, Stealth) anchored to the LEFT of the
--      primary swing bar so only the 1 active state is shown.
--   2. FOREVER_BUFF_SPELLS   : Temporary combat procs & short cooldown buffs
--      rendered in the Dynamic Priority Stack ABOVE the target debuffs, just
--      clear of their duration text, collapsing to 0px when no procs are active.
--   3. FOREVER_DEBUFF_SPELLS : Player-cast target debuffs (HARMFUL|PLAYER)
--      pinned directly above the bar with a 3px high-contrast duration bar
--      underneath each icon.
-- ============================================================

-- Active Stance / Aspect / Form / Seal / Shield spells (LEFT-side single slot).
-- Ordered from highest to lowest priority so AddAuraSlot("forever_stance")
-- always displays the primary active state without duration-text clutter.
ns.FOREVER_STANCE_SPELLS = {
    HUNTER = {
        -- Aspect of the Hawk r1-r8
        27044, 25296, 14322, 14321, 14320, 14319, 14318, 13165,
        -- Aspect of the Dragonhawk r1-r2 / Aspect of the Fox
        61847, 61846, 82661,
        -- Aspect of the Viper
        34074,
        -- Aspect of the Monkey
        13163,
        -- Aspect of the Cheetah / Aspect of the Pack
        5118, 13159,
        -- Aspect of the Beast (Forever r1-r4 + Classic ID)
        1299447, 1299446, 1299445, 13161, 13171,
        -- Aspect of the Wild r1-r4
        49071, 27045, 20190, 20043,
    },
    WARRIOR = {
        2457,  -- Battle Stance
        71,    -- Defensive Stance
        2458,  -- Berserker Stance
    },
    PALADIN = {
        -- Seal of Command r1-r5
        20920, 20919, 20918, 20915, 20375,
        -- Seal of Fury: ability + triggered buff ranks
        1311649, 1311656, 1311647, 20423, 20422, 20421, 20419, 20163,
        -- Seal of the Crusader r1-r6
        20308, 20307, 20306, 20305, 20162, 21082,
        -- Seal of Righteousness r1-r8
        20293, 20292, 20291, 20290, 20289, 20288, 20287, 21084, 20154,
        -- Seal of Wisdom r1-r3 / Seal of Light r1-r4 / Seal of Justice
        20357, 20356, 20166, 20349, 20348, 20347, 20165, 20164,
    },
    SHAMAN = {
        -- Lightning Shield r1-r7 (shows remaining orb charges in corner)
        10432, 10431, 8134, 945, 905, 325, 324,
        -- Water Shield
        52127,
    },
    DRUID = {
        9634,  -- Dire Bear Form
        5487,  -- Bear Form
        768,   -- Cat Form
        24858, -- Moonkin Form
        783,   -- Travel Form
        1066,  -- Aquatic Form
    },
    ROGUE = {
        -- Stealth r1-r4
        1787, 1786, 1785, 1784,
    },
}

-- Temporary combat procs & short cooldown buffs on the player (HELPFUL auras).
-- Permanent/passive/stance buffs (Aspects, Trueshot Aura, Seals, Shields,
-- Battle Shout, Totems, Weapon Imbues) are intentionally excluded so this row
-- stays completely empty (0x0 size) until an actual combat proc or CD fires.
ns.FOREVER_BUFF_SPELLS = {
    WARRIOR = {
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
        20049, 20050, -- Vengeance talent + rank-1 buff aura
        1310735, -- Unsealed Wrath (Forever: new, 15 s / 3 stacks)
    },
    SHAMAN = {
        30823, -- Shamanistic Rage
        16280, -- Flurry (Classic rank)
        16256, -- Flurry (Forever talent; buff aura is server-side)
        29180, -- Elemental Devastation
        425336, -- Rage of the Farseer (Forever: new, +30% attack speed, 25 s)
        408505, -- Maelstrom Weapon aura (Instant, 30 s, -20% Lightning Bolt)
        408498, -- Maelstrom Weapon talent/buff record (passive; harmless if not an aura)
        1223031, -- Improved Stormstrike (Forever: 15 s mana-regen buff)
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
        19574, -- Bestial Wrath
        3045,  -- Rapid Fire
        34692, -- The Beast Within
        6150,  -- Quick Shots
        34949, -- Rapid Killing
        34477, -- Misdirection
        19552, -- Deadly Aspects (Forever: new, +30% melee haste, 12 s)
    },
    ROGUE = {
        5171, 6774, -- Slice and Dice r1-r2 (Forever: 9-21 s by CP)
        13750, -- Adrenaline Rush
        13877, -- Blade Flurry (Forever: +20% attack speed, 15 s)
        14177, -- Cold Blood
        5277,  -- Evasion
        2983, 8696, 11305, -- Sprint r1-r3
        1856, 1857, -- Vanish r1-r2
        14179, -- Premeditation (Classic rank)
        14183, -- Premeditation (Forever: 20 s)
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
        -- Forever 1.60.1 (Primal Bite 407995 replaces Mangle and has no
        -- debuff); do not add them back.
    },
    SHAMAN = {
        8050, 8052, 8053, 10447, 10448, 29228,        -- Flame Shock (Forever: 12 s)
        17364,                                        -- Stormstrike (Forever: 12 s)
        8056, 8058, 10472, 10473,                     -- Frost Shock (Forever: 8 s slow)
        -- Earth Shock r1-r7 (2 s school lockout; harmless if the client
        -- exposes it as a plain debuff aura).
        8042, 8044, 8045, 8046, 10412, 10413, 10414,
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
        1265831,                                                       -- Savage Rend (Forever pet bleed, 18 s)
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
        1329256, -- Blood Splatter (passive; no aura, harmless)
        1328825, -- Poised (passive; no aura, harmless)
    },
    DRUID = {
        407995,  -- Primal Bite (replaces Mangle)
        16958,   -- Blood Frenzy (passive; no aura, harmless)
        1223246, -- Rend and Tear (passive; no aura, harmless)
        417051,  -- Natural Reaction (passive; no aura, harmless)
    },
    SHAMAN = {
        408341,  -- Fire Nova
    },
    PALADIN = {
        679,     -- Holy Strike
        1311606, -- Holy Shock (Forever: 10 s cooldown)
    },
    HUNTER = {
        1317257, -- Strider Kick
        19306,   -- Counterattack
        1495,    -- Mongoose Bite
        2973,    -- Raptor Strike
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

local AURA_FRAME_STRATA = "DIALOG"
local PROC_MAX_DURATION = 180
local LEFT_STANCE_MIN_SIZE = 18
local LEFT_STANCE_MAX_SIZE = 24
-- One icon-size step larger than the bar-derived stance size so the aspect /
-- stance / form slot beside the bar stays easy to read.
local LEFT_STANCE_SIZE_BONUS = 2
-- Native buff and debuff rows share one icon shape: the configured size is the
-- WIDTH and the height follows at a 30x25 default ratio, so both rows stay
-- identical whatever the per-class slider says.
local ICON_DEFAULT_WIDTH = 30
local ICON_HEIGHT_PER_WIDTH = 25 / 30
local MIN_BUFF_ICON_SIZE = 8

-- Gap between the top of the debuff row and the bottom of the buff row:
-- 2 px duration-text offset + ~12 px font height + 2 px breathing room.
local DEBUFF_TEXT_CLEARANCE = 16
local QUESTION_MARK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

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

-- Debuff bars exposed by the classic modules. The Forever module counts the
-- visible ones itself so it never needs a base-file hook (and never reads
-- aura data to place the rows).
local DEBUFF_BARS_BY_CLASS = {
    WARRIOR = { "warriorDeepWoundsBar", "warriorRendBar", "warriorThunderClapBar",
        "warriorDemoShoutBar", "warriorSunderArmorBar" },
    ROGUE = { "rogueRuptureBar" },
    PALADIN = { "paladinJudgementBar", "paladinSealVengeanceBar" },
    SHAMAN = { "shamanFlameShockBar" },
    DRUID = {},
    HUNTER = {},
}

--- Count the classic debuff bars that are currently visible for this class.
--  The bars are addon-owned frames, so IsShown() is a plain boolean.
--  @return (number) visible debuff bar count
local function CountVisibleDebuffBars()
    local names = DEBUFF_BARS_BY_CLASS[ns.playerClass]
    if not names then
        return 0
    end
    local count = 0
    for _, name in ipairs(names) do
        local bar = ns[name]
        if bar and bar.IsShown and bar:IsShown() then
            count = count + 1
        end
    end
    return count
end

--- Vertical offset (above the primary bar) for the native icon rows.
--  Icons sit above the tallest visible debuff bar, with a fixed gap when no
--  bar is visible. Self-contained: no base-file hook is required.
--  @return (number) offset in pixels
local function ComputeIconYOffset()
    local barHeight = ns.DEBUFF_BAR_HEIGHT or 8
    return 8 + (CountVisibleDebuffBars() * (barHeight + 2))
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
    ---@cast propertyEnum table
    if type(curveUtil) ~= "table" or type(curveUtil.CreateColorCurve) ~= "function"
        or type(propertyEnum) ~= "table" or propertyEnum.RemainingDuration == nil then
        return nil
    end

    local ok, curve = pcall(curveUtil.CreateColorCurve)
    if not ok or not curve then
        return nil
    end

    -- RemainingDuration is expressed in seconds. Red at 0-4s, white above.
    local createColor = GetGlobal("CreateColor")
    local pointsOk = pcall(function()
        local red = createColor and createColor(1, 0.25, 0.25, 1) or { r = 1, g = 0.25, b = 0.25, a = 1 }
        local white = createColor and createColor(1, 1, 1, 0.95) or { r = 1, g = 1, b = 1, a = 0.95 }
        curve:AddPoint(0, red)
        curve:AddPoint(4, red)
        curve:AddPoint(4.01, white)
        curve:AddPoint(3600, white)
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

-- Final-seconds window in which the native buff/proc and target-debuff rows
-- glow gold. Matches the tracked-icon glow window in SuperSwingTimer_ClassMods.lua
-- so every aura icon row on every client expires with the same 5-second cue.
local FOREVER_AURA_GLOW_SECONDS = 5.0
local FOREVER_AURA_GLOW_INTERVAL = 0.05
local FOREVER_GLOW_TEXTURE = "Interface\\Buttons\\WHITE8X8"
local expiringGlowCurve = nil
local foreverGlowHost = nil
local foreverGlowEntries = {}
local glowUpdateTimer = 0

-- Draw order used when the anchored AuraButton's level cannot be read as a
-- plain number. Our own aura containers sit at the default level inside the
-- AURA_FRAME_STRATA band, so this keeps the rim above them.
local FOREVER_GLOW_FALLBACK_LEVEL = 100

-- Counts overlays whose rim could not be built, and update passes that threw.
-- /sst diag auraGroup reports both, because a bare overlay frame has alpha but
-- no rim, which looks exactly like "the icon just doesn't glow".
local glowArtFailures = 0
local glowUpdateFailures = 0

local function IsForeverAuraGlowEnabled()
    local db = GetDB()
    if db and db.showForeverAuraGlow == false then
        return false
    end
    if db and db.showGlowEffects == false then
        return false
    end
    return true
end

local function IsForeverGlowGroupVisible(groupKey)
    local db = GetDB()
    if not db then
        return true
    end
    if groupKey == "forever_debuffs" then
        return db.showForeverDebuffIcons ~= false
    end
    if groupKey == "forever_buffs" then
        local key = BUFF_TOGGLE_BY_CLASS[ns.playerClass]
        if key then
            return db[key] ~= false
        end
    end
    return true
end

--- Step curve returning 0 for empty/cleared/permanent auras (0s) and above
--  FOREVER_AURA_GLOW_SECONDS, and 1 during that final window before expiry.
--  Uses CreateCurve (LuaCurveObject) so LuaDurationObject:EvaluateRemainingDuration
--  outputs an AllowedWhenTainted scalar suitable for Frame:SetAlpha without Lua branching.
local function GetForeverExpiringGlowCurve()
    if expiringGlowCurve then
        return expiringGlowCurve
    end
    local curveUtil = GetGlobal("C_CurveUtil")
    if type(curveUtil) ~= "table" or type(curveUtil.CreateCurve) ~= "function" then
        return nil
    end
    local ok, curve = pcall(curveUtil.CreateCurve)
    if not ok or not curve then
        return nil
    end
    local enumTbl = GetGlobal("Enum")
    local stepType = enumTbl and enumTbl.LuaCurveType and enumTbl.LuaCurveType.Step
    if stepType ~= nil and type(curve.SetType) == "function" then
        pcall(curve.SetType, curve, stepType)
    end
    local addOk = pcall(function()
        curve:AddPoint(0, 0)
        curve:AddPoint(0.01, 1)
        curve:AddPoint(FOREVER_AURA_GLOW_SECONDS + 0.01, 0)
    end)
    if not addOk then
        return nil
    end
    expiringGlowCurve = curve
    return curve
end

local function ResolveEntryDurationObj(entry)
    local dur = entry and entry.durationObj or nil
    if dur then
        return dur
    end
    local durBar = entry and entry.durationBar or nil
    if durBar and type(durBar.GetTimerDuration) == "function" then
        local ok, fetched = pcall(durBar.GetTimerDuration, durBar)
        if ok and fetched then
            entry.durationObj = fetched
            return fetched
        end
    end
    return nil
end

local function ApplyForeverGlowHostState()
    if not foreverGlowHost then
        return
    end
    local shouldRun = IsForeverAuraGlowEnabled()
        and #foreverGlowEntries > 0
        and (IsForeverGlowGroupVisible("forever_buffs") or IsForeverGlowGroupVisible("forever_debuffs"))
    if shouldRun then
        pcall(foreverGlowHost.Show, foreverGlowHost)
    else
        pcall(foreverGlowHost.Hide, foreverGlowHost)
    end
end

local function SetEntryOverlayAlpha(entry, alpha, isPlain)
    local overlay = entry.overlay
    if not overlay or not overlay.SetAlpha then
        return
    end
    if isPlain then
        if entry.lastPlainAlpha == alpha then
            return
        end
        entry.lastPlainAlpha = alpha
    else
        entry.lastPlainAlpha = nil
    end
    pcall(overlay.SetAlpha, overlay, alpha)
end

--- Refresh one overlay from its duration object.
--  Kept as a named function (not a per-tick closure) so the isolated call below
--  allocates nothing. A secret alpha is handed straight to SetAlpha, which is
--  SecretArguments = AllowedWhenTainted for the Alpha aspect; it is never
--  compared, formatted or cached.
--  @param entry (table) Registered glow entry
--  @param curve (LuaCurveObject|nil) Step curve, nil when the client has none
--  @param buffVisible (boolean) Player buff row toggle state
--  @param debuffVisible (boolean) Target debuff row toggle state
local function UpdateGlowEntry(entry, curve, buffVisible, debuffVisible)
    local dur = ResolveEntryDurationObj(entry)
    local groupVisible = true
    if entry.groupKey == "forever_buffs" then
        groupVisible = buffVisible
    elseif entry.groupKey == "forever_debuffs" then
        groupVisible = debuffVisible
    end
    if not groupVisible or not curve or not dur
        or type(dur.EvaluateRemainingDuration) ~= "function" then
        SetEntryOverlayAlpha(entry, 0, true)
        return
    end
    local evalOk, alpha = pcall(dur.EvaluateRemainingDuration, dur, curve)
    if not evalOk then
        SetEntryOverlayAlpha(entry, 0, true)
    elseif ns.IsSecretValue(alpha) then
        SetEntryOverlayAlpha(entry, alpha, false)
    elseif type(alpha) == "number" then
        SetEntryOverlayAlpha(entry, alpha, true)
    else
        SetEntryOverlayAlpha(entry, 0, true)
    end
end

local function UpdateForeverGlowEntries()
    if #foreverGlowEntries == 0 then
        return
    end
    if not IsForeverAuraGlowEnabled() then
        for i = 1, #foreverGlowEntries do
            SetEntryOverlayAlpha(foreverGlowEntries[i], 0, true)
        end
        return
    end

    local curve = GetForeverExpiringGlowCurve()
    local buffVisible = IsForeverGlowGroupVisible("forever_buffs")
    local debuffVisible = IsForeverGlowGroupVisible("forever_debuffs")

    for i = 1, #foreverGlowEntries do
        -- Per-entry isolation: one restricted overlay must not stop the rows
        -- behind it from updating. Buff entries are registered first, so a
        -- raise here used to leave the whole target-debuff row unglowing.
        if not pcall(UpdateGlowEntry, foreverGlowEntries[i], curve, buffVisible, debuffVisible) then
            glowUpdateFailures = glowUpdateFailures + 1
            SetEntryOverlayAlpha(foreverGlowEntries[i], 0, true)
        end
    end
end

local function OnForeverGlowHostUpdate(_, elapsed)
    if #foreverGlowEntries == 0 then
        return
    end
    glowUpdateTimer = glowUpdateTimer + (elapsed or 0)
    if glowUpdateTimer < FOREVER_AURA_GLOW_INTERVAL then
        return
    end
    glowUpdateTimer = 0
    UpdateForeverGlowEntries()
end

local function EnsureForeverGlowHost()
    if foreverGlowHost then
        return foreverGlowHost
    end
    local ok, host = pcall(CreateFrame, "Frame", nil, UIParent)
    if not ok or not host then
        return nil
    end
    pcall(function()
        host:SetSize(1, 1)
        host:SetPoint("CENTER")
        host:SetFrameStrata(AURA_FRAME_STRATA)
        host:EnableMouse(false)
        host:SetScript("OnUpdate", OnForeverGlowHostUpdate)
        host:Hide()
    end)
    foreverGlowHost = host
    return host
end

local function AddGlowRimEdges(parent, padOuter, thickness, r, g, b, a)
    local top = parent:CreateTexture(nil, "OVERLAY", nil, 6)
    top:SetColorTexture(r, g, b, a)
    top:SetBlendMode("ADD")
    top:SetPoint("TOPLEFT", parent, "TOPLEFT", -padOuter, padOuter)
    top:SetPoint("TOPRIGHT", parent, "TOPRIGHT", padOuter, padOuter)
    top:SetHeight(thickness)

    local bottom = parent:CreateTexture(nil, "OVERLAY", nil, 6)
    bottom:SetColorTexture(r, g, b, a)
    bottom:SetBlendMode("ADD")
    bottom:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", -padOuter, -padOuter)
    bottom:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", padOuter, -padOuter)
    bottom:SetHeight(thickness)

    local left = parent:CreateTexture(nil, "OVERLAY", nil, 6)
    left:SetColorTexture(r, g, b, a)
    left:SetBlendMode("ADD")
    left:SetPoint("TOPLEFT", parent, "TOPLEFT", -padOuter, padOuter - thickness)
    left:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", -padOuter, -padOuter + thickness)
    left:SetWidth(thickness)

    local right = parent:CreateTexture(nil, "OVERLAY", nil, 6)
    right:SetColorTexture(r, g, b, a)
    right:SetBlendMode("ADD")
    right:SetPoint("TOPRIGHT", parent, "TOPRIGHT", padOuter, padOuter - thickness)
    right:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", padOuter, -padOuter + thickness)
    right:SetWidth(thickness)
end

--- Resolve the draw-order level for a glow overlay.
--  An AuraButton's frame level is SecretReturnsForAspect FrameLevel on Forever
--  (SimpleFrameAPIDocumentation), so it can come back as a restricted number
--  that raises on math.max. ns.SafeNumber probes the value behaviourally and
--  answers nil, and the caller then uses a constant instead of guessing.
--  @param auraFrame (Frame|nil) Anchored AuraButton
--  @return (number) Plain frame level for the overlay
local function ResolveGlowOverlayLevel(auraFrame)
    if not (auraFrame and auraFrame.GetFrameLevel) then
        return FOREVER_GLOW_FALLBACK_LEVEL
    end
    local ok, level = pcall(auraFrame.GetFrameLevel, auraFrame)
    if not ok then
        return FOREVER_GLOW_FALLBACK_LEVEL
    end
    local plainLevel = ns.SafeNumber(level, nil)
    if type(plainLevel) ~= "number" then
        return FOREVER_GLOW_FALLBACK_LEVEL
    end
    return math.max(plainLevel + 8, 12)
end

--- Create an addon-owned expiring glow overlay anchored to an AuraButton.
--  IMPORTANT (anti-taint): this frame is parented to EnsureForeverGlowHost()
--  (UIParent), NEVER to Blizzard's AuraButton, and owns zero Lua scripts on the
--  anchored frame so ForbiddenAspect.UntrustedScriptExecution and
--  UntrustedLayoutScriptExecution cannot break or taint the AuraContainer.
local function CreateForeverGlowOverlay(auraFrame, width, height, groupKey, durationObj, durationBar)
    local host = EnsureForeverGlowHost()
    if not host or not auraFrame or (not durationObj and not durationBar) then
        return nil
    end
    local ok, overlay = pcall(CreateFrame, "Frame", nil, host, "DisableUntrustedLayoutScriptsTemplate")
    if not ok or not overlay then
        ok, overlay = pcall(CreateFrame, "Frame", nil, host)
    end
    if not ok or not overlay then
        return nil
    end
    ---@cast overlay Frame

    -- Step 1: the container frame. Its own operations cannot raise on secret
    -- aura data, so they stay out of the rim's pcall.
    pcall(function()
        overlay:SetSize(width, height)
        overlay:SetPoint("CENTER", auraFrame, "CENTER", 0, 0)
        overlay:SetFrameStrata(AURA_FRAME_STRATA)
        overlay:EnableMouse(false)
        overlay:SetAlpha(0)
    end)

    -- Step 2: draw order, on its own. This used to sit in the middle of the
    -- single setup pcall with math.max on the button's level, so a restricted
    -- level aborted the rim and left a bare, invisible overlay.
    local overlayLevel = ResolveGlowOverlayLevel(auraFrame)
    pcall(overlay.SetFrameLevel, overlay, overlayLevel)

    -- Step 3: the visible rim and its pulse. This is what makes the icon look
    -- like it glows, so it gets its own pcall and a counter: a bare overlay
    -- with alpha but no rim is indistinguishable from a missing glow.
    local artOk = pcall(function()
        local frameOk, artFrame = pcall(CreateFrame, "Frame", nil, overlay)
        local texTarget = (frameOk and artFrame) or overlay
        ---@cast texTarget Frame
        if frameOk and artFrame then
            ---@cast artFrame Frame
            artFrame:SetAllPoints(overlay)
            artFrame:EnableMouse(false)
            if artFrame.SetFrameLevel then
                artFrame:SetFrameLevel(overlayLevel)
            end
        end

        if texTarget.CreateTexture then
            -- Outer warm gold halo + crisp bright additive gold rim.
            AddGlowRimEdges(texTarget, 3, 2, 1.0, 0.72, 0.12, 0.55)
            AddGlowRimEdges(texTarget, 1, 2, 1.0, 0.92, 0.35, 1.0)
            local cornerWash = texTarget:CreateTexture(nil, "OVERLAY", nil, 5)
            if cornerWash and cornerWash.SetTexture then
                cornerWash:SetAllPoints(texTarget)
                cornerWash:SetColorTexture(1.0, 0.85, 0.25, 0.18)
                cornerWash:SetBlendMode("ADD")
            end
        end

        if frameOk and artFrame and type(artFrame.CreateAnimationGroup) == "function" then
            local agOk, ag = pcall(artFrame.CreateAnimationGroup, artFrame)
            if agOk and ag and type(ag.CreateAnimation) == "function" then
                local animOk, anim = pcall(ag.CreateAnimation, ag, "Alpha")
                if animOk and anim then
                    if anim.SetFromAlpha then anim:SetFromAlpha(1.0) end
                    if anim.SetToAlpha then anim:SetToAlpha(0.35) end
                    if anim.SetDuration then anim:SetDuration(0.4) end
                    if anim.SetOrder then anim:SetOrder(1) end
                    if ag.SetLooping then ag:SetLooping("BOUNCE") end
                    if ag.Play then ag:Play() end
                end
            end
        end
    end)
    if not artOk then
        glowArtFailures = glowArtFailures + 1
    end

    foreverGlowEntries[#foreverGlowEntries + 1] = {
        overlay = overlay,
        durationObj = durationObj,
        durationBar = durationBar,
        groupKey = groupKey,
        lastPlainAlpha = 0,
    }
    ApplyForeverGlowHostState()
    return overlay
end

local function ResizeForeverGlowOverlays(groupKey, width, height)
    for i = 1, #foreverGlowEntries do
        local entry = foreverGlowEntries[i]
        if entry.groupKey == groupKey and entry.overlay and entry.overlay.SetSize then
            pcall(entry.overlay.SetSize, entry.overlay, width, height)
        end
    end
end

function ns.RefreshForeverAuraGlows()
    ApplyForeverGlowHostState()
    UpdateForeverGlowEntries()
end

function ns.GetForeverAuraGlowCount()
    return #foreverGlowEntries
end

--- Report glow overlay failures: rim builds that threw, then update passes that
--  threw. /sst diag uses this to tell "the glow is disabled" apart from "the
--  rim never got built on this client".
function ns.GetForeverAuraGlowFailures()
    return glowArtFailures, glowUpdateFailures
end
ns.GetForeverExpiringGlowCurve = GetForeverExpiringGlowCurve
ns.FOREVER_GLOW_TEXTURE = FOREVER_GLOW_TEXTURE

--- Read the expiring-glow window so the settings label and the headless suite
--  report the value the curve actually uses.
function ns.GetForeverAuraGlowSeconds()
    return FOREVER_AURA_GLOW_SECONDS
end

--- Create and register one styled aura button.
--  Runs inside securecallfunction from the frame provider BEFORE
--  ApplyAccessRestrictions locks the button; every setup call must happen here.
--  @param frame (Frame) AuraButton created by the container
--  @param options (table) size / withBar / withCooldown / withGlow / isSlot flags
local function StyleAuraButton(frame, options)
    local width = options.width or options.size
    local height = options.height or options.size
    local ok = pcall(function()
        frame:SetSize(width, height)
        if options.isSlot then
            -- Anchor the single-slot indicator to its container BEFORE
            -- ApplyAccessRestrictions locks it, and hide until an aura assigns.
            local parent = frame.GetParent and frame:GetParent() or nil
            if parent then
                frame:ClearAllPoints()
                frame:SetAllPoints(parent)
            end
            if frame.Hide then
                frame:Hide()
            end
        end
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

    -- Remaining-duration text above the icon (suppressed for permanent stance slots).
    if not options.hideDurationText then
        pcall(function()
            local durationText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            durationText:SetPoint("BOTTOM", frame, "TOP", 0, 2)
            durationText:SetJustifyH("CENTER")
            durationText:SetFont(GetFontPath(), 12, "OUTLINE")
            durationText:SetTextColor(1, 1, 1, 0.95)
            local lowTimeColor = GetLowTimeTextColor()
            local textOpts = lowTimeColor and { textColor = lowTimeColor } or nil
            frame:SetDurationText(durationText, textOpts)
        end)
    end

    -- Stack / application count in the bottom-right corner.
    pcall(function()
        local countText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        countText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
        countText:SetJustifyH("RIGHT")
        countText:SetFont(GetFontPath(), 11, "OUTLINE")
        countText:SetTextColor(1, 1, 1, 1)
        frame:SetApplicationCount(countText)
    end)

    local durationBar = nil
    -- Optional thin duration bar under the icon (debuff group).
    if options.withBar then
        pcall(function()
            local bar = CreateFrame("StatusBar", nil, frame)
            bar:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -2)
            bar:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -2)
            bar:SetHeight(3)
            bar:SetStatusBarTexture(GetBarTexture())
            if bar.SetStatusBarColor then
                bar:SetStatusBarColor(0.95, 0.25, 0.20, 0.95)
            end
            if bar.CreateTexture then
                local bg = bar:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints()
                bg:SetColorTexture(0, 0, 0, 0.65)
            end
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
            durationBar = bar
        end)
    end

    -- Optional cooldown sweep (buff/debuff groups), matching the classic urgency cue.
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

    -- Secret-safe expiring glow via external UIParent-owned overlay (never
    -- for permanent stance/aspect slots). CustomAuraButtonInboundMixin does NOT
    -- expose private GetAuraDuration(), so read the persistent LuaDurationObject
    -- from a StatusBar attached via SetDurationBar() (creating an invisible 1x1
    -- proxy bar on buff rows that omit the visible duration strip).
    if options.withGlow and not options.isSlot then
        local durationObj = nil
        if type(frame.GetAuraDuration) == "function" then
            local durOk, dur = pcall(frame.GetAuraDuration, frame)
            if durOk and dur then
                durationObj = dur
            end
        end
        if not durationObj and not durationBar and type(frame.SetDurationBar) == "function" then
            pcall(function()
                local proxy = CreateFrame("StatusBar", nil, frame)
                proxy:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
                proxy:SetSize(1, 1)
                proxy:SetAlpha(0)
                if proxy.EnableMouse then
                    proxy:EnableMouse(false)
                end
                proxy:SetMinMaxValues(0, 1)
                proxy:SetValue(0)
                frame:SetDurationBar(proxy)
                durationBar = proxy
            end)
        end
        if not durationObj and durationBar and type(durationBar.GetTimerDuration) == "function" then
            local timerOk, dur = pcall(durationBar.GetTimerDuration, durationBar)
            if timerOk and dur then
                durationObj = dur
            end
        end
        if durationObj or (durationBar and type(durationBar.GetTimerDuration) == "function") then
            CreateForeverGlowOverlay(frame, width, height, options.glowGroupKey, durationObj, durationBar)
        end
    end
end

--- Create an AuraContainer frame, preferring DisableUntrustedLayoutScriptsTemplate.
--  Frames anchored to a container with groups inherit untrusted script execution
--  restrictions on WoW Forever.
--  @return (Frame|nil) container frame
local function CreateAuraContainerFrame()
    local ok, container = pcall(CreateFrame, "AuraContainer", nil, UIParent,
        "CustomAuraContainerTemplate, DisableUntrustedLayoutScriptsTemplate")
    if ok and container then
        return container
    end
    ok, container = pcall(CreateFrame, "AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
    if ok and container then
        return container
    end
    return nil
end

--- Create one native aura group container.
--  @param groupKey (string) unique group key inside the container
--  @param unitToken (string) "player" or "target"
--  @param filter (string) "HELPFUL" or "HARMFUL"
--  @param spellList (table) array of spell IDs to match
--  @param options (table) size / withBar / withCooldown / maxDuration
--  @return (Frame|nil) the container, or nil when creation failed
local function CreateAuraGroupContainer(groupKey, unitToken, filter, spellList, options)
    local container = CreateAuraContainerFrame()
    if not container then
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

        local candidateFilters = { includeSpellIDs = spellMap }
        if options.maxDuration then
            candidateFilters.maxDuration = options.maxDuration
        end

        local groupOptions = {
            candidateFilters = candidateFilters,
            maxFrameCount = maxFrames,
            layout = {
                elementWidth = options.width or options.size,
                elementHeight = options.height or options.size,
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
        -- Grow from the bottom-left, then anchor the container bottom-center
        -- to the bar. The container width is the row width, so the row is
        -- centered above the bar instead of starting at its center and
        -- extending right.
        container:SetFlowLayoutAnchorPoint("BOTTOMLEFT")
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
    stanceSlot = nil,
    shapeshiftIcon = nil,
    buffSize = 30,
    buffWidth = 30,
    buffHeight = 25,
    debuffSize = 30,
    debuffWidth = 30,
    debuffHeight = 25,
    lastYOffset = nil,
    lastBuffWidth = nil,
    lastBuffHeight = nil,
    lastDebuffWidth = nil,
    lastDebuffHeight = nil,
    lastDebuffSize = nil,
    lastDebuffPopulated = nil,
    lastBuffVisible = nil,
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

local function GetStanceToggle()
    local db = GetDB()
    if not db then
        return true
    end
    return db.showForeverStanceIcon ~= false
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
        size = ICON_DEFAULT_WIDTH
    end
    return size
end

--- Width and height for a native icon row.
--  The configured value is the WIDTH; the height follows the 30x25 default
--  aspect so the buff and debuff rows always match. Tiny configured values
--  clamp so the icons stay readable.
--  @param iconWidth (number|nil) configured icon width
--  @return (number) icon width, (number) icon height
function ns.GetForeverIconDimensions(iconWidth)
    local width = iconWidth
    if type(width) ~= "number" or width <= 0 then
        width = ICON_DEFAULT_WIDTH
    end
    local height = width * ICON_HEIGHT_PER_WIDTH
    width = math.floor(width + 0.5)
    height = math.floor(height + 0.5)
    if width < MIN_BUFF_ICON_SIZE then
        width = MIN_BUFF_ICON_SIZE
    end
    if height < MIN_BUFF_ICON_SIZE then
        height = MIN_BUFF_ICON_SIZE
    end
    return width, height
end

--- Buff proc icon width and height.
--  @param baseSize (number|nil) configured icon width
--  @return (number) icon width, (number) icon height
function ns.GetForeverBuffIconDimensions(baseSize)
    local base = baseSize
    if type(base) ~= "number" or base <= 0 then
        base = GetBuffSize()
    end
    return ns.GetForeverIconDimensions(base)
end

local function GetDebuffSize()
    local db = GetDB()
    local size = db and db.foreverDebuffIconSize or nil
    if type(size) ~= "number" or size <= 0 then
        size = ICON_DEFAULT_WIDTH
    end
    return size
end

--- Size of the left-side aspect / stance / form / seal / shield slot.
--  Tracks the primary swing bar height, clamped to the stance icon range,
--  plus one icon step (LEFT_STANCE_SIZE_BONUS) so the active state is easy to
--  read next to the bar.
--  @param bar (Frame|nil) anchor bar
--  @return (number) square icon size in pixels
function ns.GetForeverStanceIconSize(bar)
    local barH = bar and bar.GetHeight and bar:GetHeight() or 18
    if type(barH) ~= "number" or barH <= 0 then barH = 18 end
    if barH < LEFT_STANCE_MIN_SIZE then barH = LEFT_STANCE_MIN_SIZE end
    if barH > LEFT_STANCE_MAX_SIZE then barH = LEFT_STANCE_MAX_SIZE end
    return barH + LEFT_STANCE_SIZE_BONUS
end

--- Determine the left-hand anchor target frame and relative offset.
--  Respects class helper bars on the left (Hunter range helper, Rogue/Druid
--  energy tick, Shaman lightning tracker) so the stance icon never overlaps.
--  @param bar (Frame) anchor bar
--  @return targetFrame, relPoint, xOff, yOff
local function GetLeftAnchorTarget(bar)
    if ns.playerClass == "HUNTER" then
        if ns.hunterRangeHelperBar and ns.hunterRangeHelperBar.IsShown and ns.hunterRangeHelperBar:IsShown()
            and ns.hunterRangeHelperBar.GetAlpha and (ns.hunterRangeHelperBar:GetAlpha() or 0) > 0 then
            return ns.hunterRangeHelperBar, "LEFT", -3, 0
        end
    elseif ns.playerClass == "ROGUE" then
        if ns.rogueEnergyTickBar and ns.rogueEnergyTickBar.IsShown and ns.rogueEnergyTickBar:IsShown()
            and ns.rogueEnergyTickBar.GetAlpha and (ns.rogueEnergyTickBar:GetAlpha() or 0) > 0 then
            return ns.rogueEnergyTickBar, "LEFT", -3, 0
        end
    elseif ns.playerClass == "DRUID" then
        if ns.druidEnergyTickBar and ns.druidEnergyTickBar.IsShown and ns.druidEnergyTickBar:IsShown()
            and ns.druidEnergyTickBar.GetAlpha and (ns.druidEnergyTickBar:GetAlpha() or 0) > 0 then
            return ns.druidEnergyTickBar, "LEFT", -3, 0
        end
    elseif ns.playerClass == "SHAMAN" then
        if ns.shamanLightningContainer and ns.shamanLightningContainer.IsShown and ns.shamanLightningContainer:IsShown()
            and ns.shamanLightningContainer.GetAlpha and (ns.shamanLightningContainer:GetAlpha() or 0) > 0 then
            return ns.shamanLightningContainer, "LEFT", -3, 0
        end
    end
    return bar, "LEFT", -4, 0
end

local function SetShapeshiftBorderColor(frame, r, g, b, a)
    if not frame or not frame.edges then return end
    for _, edge in ipairs(frame.edges) do
        if edge and edge.SetColorTexture then
            edge:SetColorTexture(r, g, b, a)
        end
    end
end

--- Create the fallback shapeshift/stance icon frame.
--  Used for Warrior stances and Druid forms (from GetShapeshiftFormInfo)
--  and Hunter in-combat missing-aspect alerts.
local function EnsureShapeshiftIcon()
    local state = ns.foreverAura
    if state.shapeshiftIcon then
        return state.shapeshiftIcon
    end
    local ok, frame = pcall(CreateFrame, "Frame", nil, UIParent)
    if not ok or not frame then
        return nil
    end
    pcall(function()
        frame:SetFrameStrata(AURA_FRAME_STRATA)
        frame:EnableMouse(false)
        local icon = frame:CreateTexture(nil, "BACKGROUND")
        icon:SetAllPoints()
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        frame.icon = icon

        local edges = {
            { "TOPLEFT", -1, 1, "TOPRIGHT", 1, 1, "HEIGHT" },
            { "BOTTOMLEFT", -1, -1, "BOTTOMRIGHT", 1, -1, "HEIGHT" },
            { "TOPLEFT", -1, 1, "BOTTOMLEFT", -1, -1, "WIDTH" },
            { "TOPRIGHT", 1, 1, "BOTTOMRIGHT", 1, -1, "WIDTH" },
        }
        frame.edges = {}
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
            table.insert(frame.edges, texture)
        end
        frame:Hide()
    end)
    state.shapeshiftIcon = frame
    return frame
end

local STANCE_SPELL_PATTERNS_BY_CLASS = {
    HUNTER = { "^Aspect of " },
    PALADIN = { "^Seal of " },
    WARRIOR = { " Stance$" },
    DRUID = { " Form$", "^Tree of Life" },
    ROGUE = { "^Stealth" },
}

local function MatchesAnyPattern(name, patterns)
    if type(name) ~= "string" or not patterns then
        return false
    end
    for _, pat in ipairs(patterns) do
        if string.find(name, pat) then
            return true
        end
    end
    return false
end

--- Merge static class stance/aspect IDs with dynamically discovered spellbook and
--  shapeshift-bar IDs so custom WoW Forever ranks/aspects are always included.
local function DiscoverPlayerStanceSpells(className, baseList)
    local merged = {}
    if type(baseList) == "table" then
        AppendUnique(merged, baseList)
    end

    local getNumForms = GetGlobal("GetNumShapeshiftForms")
    local getFormInfo = GetGlobal("GetShapeshiftFormInfo")
    if type(getNumForms) == "function" and type(getFormInfo) == "function" then
        local okNum, numForms = pcall(getNumForms)
        if okNum and not ns.IsSecretValue(numForms) and type(numForms) == "number" and numForms > 0 then
            for i = 1, numForms do
                local ok, _, _, _, spellID = pcall(getFormInfo, i)
                local safeID = ok and ns.SafeNumber and ns.SafeNumber(spellID) or nil
                if type(safeID) == "number" and safeID > 0 then
                    AppendUnique(merged, { safeID })
                end
            end
        end
    end

    local patterns = STANCE_SPELL_PATTERNS_BY_CLASS[className]
    if not patterns then
        return merged
    end

    local cSpellBook = GetGlobal("C_SpellBook")
    if type(cSpellBook) == "table" and type(cSpellBook.GetNumSpellBookSkillLines) == "function"
        and type(cSpellBook.GetSpellBookSkillLineInfo) == "function"
        and type(cSpellBook.GetSpellBookItemInfo) == "function" then
        local bankEnum = GetGlobal("Enum")
        local playerBank = bankEnum and bankEnum.SpellBookSpellBank and bankEnum.SpellBookSpellBank.Player or 0
        local okLines, numLines = pcall(cSpellBook.GetNumSpellBookSkillLines)
        if okLines and type(numLines) == "number" then
            for lineIdx = 1, numLines do
                local okLine, lineInfo = pcall(cSpellBook.GetSpellBookSkillLineInfo, lineIdx)
                if okLine and type(lineInfo) == "table" and not lineInfo.isGuild and not lineInfo.offSpecID then
                    local offset = lineInfo.itemIndexOffset or 0
                    local count = lineInfo.numSpellBookItems or 0
                    for slot = offset + 1, offset + count do
                        local okItem, itemInfo = pcall(cSpellBook.GetSpellBookItemInfo, slot, playerBank)
                        if okItem and type(itemInfo) == "table" and not itemInfo.isPassive then
                            local sID = ns.SafeNumber and ns.SafeNumber(itemInfo.spellID or itemInfo.actionID) or nil
                            local sName = ns.SafeString and ns.SafeString(itemInfo.name) or nil
                            if not sName and sID and ns.GetSpellInfo then
                                sName = ns.GetSpellInfo(sID)
                            end
                            if type(sID) == "number" and sID > 0 and MatchesAnyPattern(sName, patterns) then
                                AppendUnique(merged, { sID })
                            end
                        end
                    end
                end
            end
        end
    else
        local getNumTabs = GetGlobal("GetNumSpellTabs")
        local getTabInfo = GetGlobal("GetSpellTabInfo")
        local getItemInfo = GetGlobal("GetSpellBookItemInfo")
        local getItemName = GetGlobal("GetSpellBookItemName")
        if type(getNumTabs) == "function" and type(getTabInfo) == "function"
            and type(getItemInfo) == "function" then
            local bookSpell = GetGlobal("BOOKTYPE_SPELL") or "spell"
            local okTabs, numTabs = pcall(getNumTabs)
            if okTabs and type(numTabs) == "number" then
                for tabIdx = 1, numTabs do
                    local okTab, _, _, offset, count = pcall(getTabInfo, tabIdx)
                    if okTab and type(offset) == "number" and type(count) == "number" then
                        for slot = offset + 1, offset + count do
                            local okItem, _, sID = pcall(getItemInfo, slot, bookSpell)
                            local safeID = okItem and ns.SafeNumber and ns.SafeNumber(sID) or nil
                            if type(safeID) == "number" and safeID > 0 then
                                local sName = nil
                                if type(getItemName) == "function" then
                                    local okName, rawName = pcall(getItemName, slot, bookSpell)
                                    if okName then
                                        sName = rawName
                                    end
                                end
                                sName = ns.SafeString and ns.SafeString(sName) or sName
                                if not sName and ns.GetSpellInfo then
                                    sName = ns.GetSpellInfo(safeID)
                                end
                                if MatchesAnyPattern(sName, patterns) then
                                    AppendUnique(merged, { safeID })
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return merged
end

local function GetActiveShapeshiftTexture()
    local getNumForms = GetGlobal("GetNumShapeshiftForms")
    local getFormInfo = GetGlobal("GetShapeshiftFormInfo")
    if type(getNumForms) ~= "function" or type(getFormInfo) ~= "function" then
        return nil
    end
    local okNum, numForms = pcall(getNumForms)
    if not okNum or ns.IsSecretValue(numForms) or type(numForms) ~= "number" or numForms <= 0 then
        return nil
    end
    for i = 1, numForms do
        local ok, texture, isActive = pcall(getFormInfo, i)
        if ok and not ns.IsSecretValue(isActive) and isActive == true
            and not ns.IsSecretValue(texture) and texture and texture ~= QUESTION_MARK_ICON then
            return texture
        end
    end
    return nil
end

--- Update the left-side stance icon (native aura slot or shapeshift fallback).
--  Never touches restricted stanceSlot post-creation, never paints a '?'
--  icon in combat, and never adds a glow to the stance/aspect icon.
--  @param bar (Frame) anchor bar
local function UpdateLeftStanceIcon(bar)
    local state = ns.foreverAura
    if not bar then
        return
    end

    local stanceVisible = GetStanceToggle()
    if not stanceVisible then
        if state.stanceContainer and state.stanceContainer.Hide then
            pcall(state.stanceContainer.Hide, state.stanceContainer)
        end
        if state.shapeshiftIcon and state.shapeshiftIcon.Hide then
            state.shapeshiftIcon:Hide()
        end
        return
    end

    local stanceSize = ns.GetForeverStanceIconSize(bar)
    local targetFrame, relPoint, xOff, yOff = GetLeftAnchorTarget(bar)

    -- Reposition and resize ONLY our container frame; the slot child was
    -- anchored via SetAllPoints(stanceContainer) before access restrictions.
    if state.stanceContainer then
        pcall(function()
            state.stanceContainer:ClearAllPoints()
            state.stanceContainer:SetPoint("RIGHT", targetFrame, relPoint, xOff, yOff)
            state.stanceContainer:SetSize(stanceSize, stanceSize)
            state.stanceContainer:Show()
        end)
    end

    -- Check native stance slot state safely: out of combat when native slot is
    -- confirmed plain shown, stand down so only one icon renders. In combat
    -- (where IsShown() may fail or return a secret boolean), prefer any verified
    -- shapeshift texture (Hunter Aspects, Warrior Stances, Druid Forms) so a
    -- secret-false slot never hides an active Aspect/Form.
    local slotPlainShown = false
    if state.stanceSlot and state.stanceSlot.IsShown then
        local slotShownOk, slotIsShown = pcall(state.stanceSlot.IsShown, state.stanceSlot)
        if slotShownOk and not ns.IsSecretValue(slotIsShown) and slotIsShown == true then
            slotPlainShown = true
        end
    end

    if slotPlainShown then
        if state.shapeshiftIcon and state.shapeshiftIcon.Hide then
            state.shapeshiftIcon:Hide()
        end
        return
    end

    -- Check ShapeshiftBar forms (Warrior stances, Druid forms, and clients where
    -- Hunter Aspects are exposed as ShapeshiftForms) using strictly non-secret flags.
    local activeTexture = GetActiveShapeshiftTexture()
    if activeTexture then
        local iconFrame = EnsureShapeshiftIcon()
        if iconFrame then
            pcall(function()
                iconFrame:ClearAllPoints()
                iconFrame:SetPoint("RIGHT", targetFrame, relPoint, xOff, yOff)
                iconFrame:SetSize(stanceSize, stanceSize)
                if iconFrame.icon and iconFrame.icon.SetTexture then
                    iconFrame.icon:SetTexture(activeTexture)
                end
                SetShapeshiftBorderColor(iconFrame, 0, 0, 0, 0.65)
                iconFrame:Show()
            end)
        end
        return
    end

    if state.shapeshiftIcon and state.shapeshiftIcon.Hide then
        state.shapeshiftIcon:Hide()
    end
end

--- True when the debuff row currently holds frames.
--  The container's height is derived from its aura frames, so the client hands
--  it back as a SECRET number while the row is populated; an empty flow layout
--  collapses to a plain 1. Comparing that height raises ("attempt to compare a
--  secret number"), so the secrecy probe must always run first. A secret height
--  therefore means "populated" and the buff row anchors to the container
--  instead of computing a pixel offset.
--  @param probeOk (boolean) whether GetHeight answered
--  @param height (number|nil) raw GetHeight result, possibly secret
--  @return (boolean) true when the debuff row reserves space
function ns.IsForeverDebuffRowPopulated(probeOk, height)
    if not probeOk then
        return false
    end
    if ns.IsSecretValue(height) then
        return true
    end
    return type(height) == "number" and height > 1
end

--- Probe the native debuff container for a populated row.
--  @param container (Frame|nil) debuff container
--  @return (boolean) true when the debuff row is populated
local function IsDebuffRowPopulated(container)
    if not container then
        return false
    end
    local ok, height = pcall(container.GetHeight, container)
    return ns.IsForeverDebuffRowPopulated(ok, height)
end

--- Reposition the native aura rows and the stance icon.
--  Stack order (bottom to top): bar -> target debuffs -> debuff duration text
--  -> player buff procs. Debuffs never move when procs appear; the proc row
--  appears above their text instead of pushing them up.
local function ApplyContainerAnchors()
    local state = ns.foreverAura
    local bar = GetAnchorBar()
    if not bar then
        return
    end
    local yOffset = ComputeIconYOffset()
    local buffVisible = GetBuffToggle()
    local debuffPopulated = GetDebuffToggle() and IsDebuffRowPopulated(state.debuffContainer) or false

    -- Target debuffs stay pinned to the bar; the proc row clears their
    -- duration text by anchoring to the debuff container itself. An empty
    -- debuff row collapses the proc row back onto the bar.
    if state.debuffContainer then
        pcall(function()
            state.debuffContainer:ClearAllPoints()
            state.debuffContainer:SetPoint("BOTTOM", bar, "TOP", 0, yOffset)
        end)
    end
    if state.buffContainer then
        local anchorTarget = debuffPopulated and state.debuffContainer or bar
        local anchorOffset = debuffPopulated and DEBUFF_TEXT_CLEARANCE or yOffset
        pcall(function()
            state.buffContainer:ClearAllPoints()
            state.buffContainer:SetPoint("BOTTOM", anchorTarget, "TOP", 0, anchorOffset)
        end)
    end

    UpdateLeftStanceIcon(bar)

    state.lastYOffset = yOffset
    state.lastBuffWidth = state.buffWidth
    state.lastBuffHeight = state.buffHeight
    state.lastDebuffSize = state.debuffSize
    state.lastDebuffPopulated = debuffPopulated
    state.lastBuffVisible = buffVisible
    state.lastAnchorBar = bar
end

--- Wrap classic icon updaters so they stand down while native Forever containers
-- are live. Functions cannot carry fields in Lua 5.1, so the "already wrapped"
-- state lives in this name-keyed table instead of on the function itself.
local wrappedLegacyUpdaters = {}
function ns.WrapLegacyIconUpdaters()
    local legacyFns = {
        "UpdateHunterAspect",
        "UpdateHunterBuffIcons",
        "UpdateWarriorBuffIcons",
        "UpdatePaladinBuffIcons",
        "UpdateShamanBuffIcons",
        "UpdateDruidBuffIcons",
        "UpdateRogueBuffIcons",
    }
    for _, fnName in ipairs(legacyFns) do
        local orig = ns[fnName]
        if type(orig) == "function" and not wrappedLegacyUpdaters[fnName] then
            local wrapped
            wrapped = function(...)
                if ns.foreverNativeAuraIcons then
                    if fnName == "UpdateHunterAspect" and ns.hunterAspectIcon and ns.hunterAspectIcon.Hide then
                        ns.hunterAspectIcon:Hide()
                    end
                    return
                end
                return orig(...)
            end
            wrappedLegacyUpdaters[fnName] = true
            ns[fnName] = wrapped
        end
    end
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
    local stanceList = DiscoverPlayerStanceSpells(ns.playerClass,
        ns.FOREVER_STANCE_SPELLS and ns.FOREVER_STANCE_SPELLS[ns.playerClass])
    if stanceList and #stanceList > 0 and ns.FOREVER_STANCE_SPELLS and ns.playerClass then
        ns.FOREVER_STANCE_SPELLS[ns.playerClass] = stanceList
    end
    if not buffList and not debuffList and (#stanceList == 0) then
        return false
    end

    state.buffSize = GetBuffSize() --[[@as number]]
    state.buffWidth, state.buffHeight = ns.GetForeverBuffIconDimensions(state.buffSize)
    state.debuffSize = GetDebuffSize() --[[@as number]]
    state.debuffWidth, state.debuffHeight = ns.GetForeverIconDimensions(state.debuffSize)

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
            width = state.buffWidth,
            height = state.buffHeight,
            withBar = false,
            withCooldown = true,
            withGlow = true,
            glowGroupKey = "forever_buffs",
            maxDuration = PROC_MAX_DURATION,
        })
        if container then
            state.buffContainer = container
        else
            state.initError = "buff container creation failed"
        end
    end

    -- Add native single-slot stance icon in its own container if available (zero glow).
    if stanceList and #stanceList > 0 then
        local stanceContainer = CreateAuraContainerFrame()
        if stanceContainer then
            local stanceSize = ns.GetForeverStanceIconSize(GetAnchorBar())
            pcall(function()
                stanceContainer:SetSize(stanceSize, stanceSize)
                stanceContainer:SetFrameStrata(AURA_FRAME_STRATA)
                stanceContainer:SetUnit("player")
                stanceContainer:SetEnabled(true)
                stanceContainer:Show()
            end)
            state.stanceContainer = stanceContainer

            if stanceContainer.AddAuraSlot then
                local stanceMap = ns.BuildAuraSpellIDMap(stanceList)
                local slotOk, slotFrame = pcall(stanceContainer.AddAuraSlot, stanceContainer, "forever_stance", "HELPFUL", {
                    candidateFilters = { includeSpellIDs = stanceMap },
                    initializeFrame = function(frame)
                        StyleAuraButton(frame, {
                            size = stanceSize,
                            isSlot = true,
                            withBar = false,
                            withCooldown = false,
                            withGlow = false,
                            hideDurationText = true,
                        })
                    end,
                })
                if slotOk and slotFrame then
                    state.stanceSlot = slotFrame
                end
            end
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
            width = state.debuffWidth,
            height = state.debuffHeight,
            withBar = true,
            withCooldown = true,
            withGlow = true,
            glowGroupKey = "forever_debuffs",
        })
        if container then
            state.debuffContainer = container
        else
            state.initError = (state.initError and (state.initError .. "; ") or "")
                .. "debuff container creation failed"
        end
    end

    if not state.buffContainer and not state.debuffContainer and not state.stanceContainer then
        return false
    end

    ns.foreverNativeAuraIcons = true
    ns.WrapLegacyIconUpdaters()
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
--  @param width (number) new icon width
--  @param height (number) new icon height
local function ResizeGroupFrames(container, groupKey, width, height)
    if not container or not container.GetAuraGroupFrameCount
        or not container.GetAuraGroupFrame then
        return
    end
    local ok, count = pcall(container.GetAuraGroupFrameCount, container, groupKey)
    if not ok then
        return
    end
    -- The count is derived from aura frames and can be secret; a numeric for
    -- limit would raise, so scrub it before the loop.
    local frameCount = ns.SafeNumber and ns.SafeNumber(count) or nil
    if type(frameCount) ~= "number" then
        return
    end
    for index = 1, frameCount do
        local frameOk, frame = pcall(container.GetAuraGroupFrame, container, groupKey, index)
        if frameOk and frame and frame.SetSize then
            pcall(frame.SetSize, frame, width, height)
        end
    end
end

local maintainTimer = 0
local MAINTAIN_INTERVAL = 0.15

--- Per-frame maintenance for the native groups and left stance slot.
--  Accumulates elapsed time to throttle periodic maintenance passes.
--  Pass 0 or nil to force an immediate un-throttled update.
--  @param elapsed (number|nil) seconds since the previous frame
function ns.UpdateForeverAuraIcons(elapsed)
    local state = ns.foreverAura
    if not ns.foreverNativeAuraIcons then
        return
    end

    if type(elapsed) == "number" and elapsed > 0 then
        maintainTimer = maintainTimer + elapsed
        if maintainTimer < MAINTAIN_INTERVAL then
            return
        end
        maintainTimer = 0
    else
        maintainTimer = 0
    end

    ns.WrapLegacyIconUpdaters()

    local buffVisible = GetBuffToggle()
    local debuffVisible = GetDebuffToggle()

    if state.buffContainer then
        pcall(function()
            if buffVisible then state.buffContainer:Show() else state.buffContainer:Hide() end
        end)
    end
    if state.debuffContainer then
        pcall(function()
            if debuffVisible then state.debuffContainer:Show() else state.debuffContainer:Hide() end
        end)
    end

    -- Size changes require a fresh layout definition. Both rows share the same
    -- 30x25 icon shape, so each row resizes with its own width/height pair.
    local buffSize = GetBuffSize()
    local buffWidth, buffHeight = ns.GetForeverBuffIconDimensions(buffSize)
    local debuffSize = GetDebuffSize()
    local debuffWidth, debuffHeight = ns.GetForeverIconDimensions(debuffSize)
    if (buffWidth ~= state.buffWidth or buffHeight ~= state.buffHeight)
            and state.buffContainer then
        local ok = pcall(function()
            state.buffContainer:SetAuraGroupLayout("forever_buffs", {
                elementWidth = buffWidth,
                elementHeight = buffHeight,
                elementSpacing = 3,
            })
            ResizeGroupFrames(state.buffContainer, "forever_buffs", buffWidth, buffHeight)
            ResizeForeverGlowOverlays("forever_buffs", buffWidth, buffHeight)
        end)
        if ok then
            state.buffSize = buffSize --[[@as number]]
            state.buffWidth = buffWidth
            state.buffHeight = buffHeight
        end
    end
    if (debuffWidth ~= state.debuffWidth or debuffHeight ~= state.debuffHeight)
            and state.debuffContainer then
        local ok = pcall(function()
            state.debuffContainer:SetAuraGroupLayout("forever_debuffs", {
                elementWidth = debuffWidth,
                elementHeight = debuffHeight,
                elementSpacing = 3,
            })
            ResizeGroupFrames(state.debuffContainer, "forever_debuffs", debuffWidth, debuffHeight)
            ResizeForeverGlowOverlays("forever_debuffs", debuffWidth, debuffHeight)
        end)
        if ok then
            state.debuffSize = debuffSize --[[@as number]]
            state.debuffWidth = debuffWidth
            state.debuffHeight = debuffHeight
        end
    end

    -- Re-anchor only when something that affects the layout changed. The
    -- debuff row contributes a populated flag, never a secret height.
    local yOffset = ComputeIconYOffset()
    local anchorBar = GetAnchorBar()
    local debuffPopulated = GetDebuffToggle() and IsDebuffRowPopulated(state.debuffContainer) or false
    local buffChanged = buffVisible ~= state.lastBuffVisible
    local debuffVisChanged = debuffVisible ~= state.lastDebuffVisible
    if buffChanged or debuffVisChanged then
        state.lastDebuffVisible = debuffVisible
        ns.RefreshForeverAuraGlows()
    end
    if anchorBar and (anchorBar ~= state.lastAnchorBar
            or yOffset ~= state.lastYOffset
            or buffWidth ~= state.lastBuffWidth
            or buffHeight ~= state.lastBuffHeight
            or debuffSize ~= state.lastDebuffSize
            or debuffPopulated ~= state.lastDebuffPopulated
            or buffChanged) then
        ApplyContainerAnchors()
    else
        UpdateLeftStanceIcon(anchorBar)
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
    initFrame:SetScript("OnUpdate", function(_, elapsed)
        if ns.foreverNativeAuraIcons then
            ns.UpdateForeverAuraIcons(elapsed)
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
--- Safe display value for the debuff container height.
--  Never compares a secret number: the probe is classified first.
--  @return (number|string) plain height in pixels, or "secret"/"none"/"unreadable"
local function GetDebuffRowProbe()
    local state = ns.foreverAura
    local container = state.debuffContainer
    if not container then
        return "none"
    end
    local ok, height = pcall(container.GetHeight, container)
    if not ok then
        return "unreadable"
    end
    if ns.IsSecretValue(height) then
        return "secret"
    end
    return type(height) == "number" and height or "nil"
end

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
    local stanceSpells = 0
    if ns.playerClass then
        local buffList = ns.FOREVER_BUFF_SPELLS[ns.playerClass]
        local debuffList = ns.FOREVER_DEBUFF_SPELLS[ns.playerClass]
        local stanceList = ns.FOREVER_STANCE_SPELLS and ns.FOREVER_STANCE_SPELLS[ns.playerClass]
        buffSpells = buffList and #buffList or 0
        debuffSpells = debuffList and #debuffList or 0
        stanceSpells = stanceList and #stanceList or 0
    end
    return {
        isForever = ns.isForever,
        hasAuraContainer = ns.hasAuraContainer,
        nativeActive = ns.foreverNativeAuraIcons,
        buffContainer = state.buffContainer ~= nil,
        debuffContainer = state.debuffContainer ~= nil,
        stanceContainer = state.stanceContainer ~= nil,
        stanceSlot = state.stanceSlot ~= nil,
        shapeshiftIcon = state.shapeshiftIcon ~= nil,
        buffFrames = buffCount,
        debuffFrames = debuffCount,
        buffWidth = state.buffWidth,
        buffHeight = state.buffHeight,
        debuffWidth = state.debuffWidth,
        debuffHeight = state.debuffHeight,
        debuffRow = GetDebuffRowProbe(),
        stanceIconSize = ns.GetForeverStanceIconSize(GetAnchorBar()),
        buffSpells = buffSpells,
        debuffSpells = debuffSpells,
        stanceSpells = stanceSpells,
        auraSecret = ns.IsAuraDataSecret(),
        initAttempts = state.initAttempts,
        initError = state.initError,
    }
end

if WoWUnit then ---@diagnostic disable-line: undefined-global
    ns._TestForeverStyleAuraButton = StyleAuraButton
    ns._TestForeverGlowTick = UpdateForeverGlowEntries
    ns._TestGetForeverGlowHost = function()
        return foreverGlowHost
    end
end
