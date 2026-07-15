-- ============================================================
-- SuperSwingTimer_SoD.lua
-- Season of Discovery rune ability spell IDs and classifications.
--
-- This file injects SoD-specific spell IDs into the existing
-- swing classification tables defined in Constants.lua.
-- Safely no-ops on TBC Anniversary / Classic Era 1.15 where
-- these spell IDs don't exist — ns.GetSpellInfo() returns nil
-- and the name lookups silently skip unrecognized spells.
-- ============================================================

local _, ns = ...

-- ============================================================
-- Helper: add spell IDs + their localized names to a lookup
-- ============================================================
local function addSpellIds(lookup, ids)
    if not lookup then return end
    for _, id in ipairs(ids) do
        lookup[id] = true
        if type(ns.GetSpellInfo) == "function" then
            local name = ns.GetSpellInfo(id)
            if name then
                lookup[name] = true
            end
        end
    end
end

-- ============================================================
-- NO_RESET_SWING_SPELLS
-- SoD instant attacks verified to NOT reset the swing timer:
--   "Quick Strike, Raging Blow and Overpower do not reset the
--    timer" — Blizzard forums, Season of Discovery
-- ============================================================

-- Quick Strike (Warrior — 2H instant filler, 20 Rage)
-- NOTE: 429748 and 425428 are the rune passive (action bar override).
--       429765 is the actual cast that fires UNIT_SPELLCAST_START.
addSpellIds(ns.NO_RESET_SWING_SPELLS, {
    429765
})

-- Raging Blow (Warrior — enrage-gated instant, 8s CD)
-- NOTE: 425429 is the rune passive; 402911 is the actual cast.
addSpellIds(ns.NO_RESET_SWING_SPELLS, {
    402911
})

-- Flanking Strike (Hunter — instant melee + Raptor Strike synergy, 30s CD)
-- NOTE: 425757 is the rune passive; 415320 is the actual cast.
addSpellIds(ns.NO_RESET_SWING_SPELLS, {
    415320
})

-- Lava Lash (Shaman — instant off-hand weapon attack, 6s CD)
-- NOTE: 409953 is the rune passive; 408507 is the actual cast.
addSpellIds(ns.NO_RESET_SWING_SPELLS, {
    408507
})

-- Carve (Hunter — instant frontal AoE, 6s CD)
addSpellIds(ns.NO_RESET_SWING_SPELLS, {
    425711
})

-- Divine Storm (Paladin — instant AoE Holy damage, 10s CD)
-- NOTE: 409924 is the rune passive; 407778 is the actual cast.
addSpellIds(ns.NO_RESET_SWING_SPELLS, {
    407778
})

-- ============================================================
-- SoD debuff spell IDs for tracking via existing debuff bar
-- infrastructure. These IDs exist only on Classic Era/SoD 1.15.x
-- and are nil-safe on TBC Anniversary.
-- ============================================================

-- Rend (Warrior bleed, massively buffed by Blood Frenzy rune)
-- Classic ranks: 772, 6546, 6547, 6548, 11572, 11573, 11574
if not ns.WARRIOR_REND_IDS then
    ns.WARRIOR_REND_IDS = {}
end
addSpellIds(ns.WARRIOR_REND_IDS, {
    772, 6546, 6547, 6548, 11572, 11573, 11574
})

-- Blood Frenzy (Warrior — buff applied by the rune)
if not ns.WARRIOR_BLOOD_FRENZY_BUFF_IDS then
    ns.WARRIOR_BLOOD_FRENZY_BUFF_IDS = {}
end
addSpellIds(ns.WARRIOR_BLOOD_FRENZY_BUFF_IDS, {
    412507
})

-- Sudden Death proc buff (Warrior — enables Execute any health %)
-- 440113 = rune passive (hidden); 440114 = visible proc buff
if not ns.WARRIOR_SUDDEN_DEATH_BUFF_IDS then
    ns.WARRIOR_SUDDEN_DEATH_BUFF_IDS = {}
end
addSpellIds(ns.WARRIOR_SUDDEN_DEATH_BUFF_IDS, {
    440114
})

-- Endless Rage (Warrior — 25% more rage from damage)
-- 403218 = rune passive; 403349 = the actual ability
if not ns.WARRIOR_ENDLESS_RAGE_BUFF_IDS then
    ns.WARRIOR_ENDLESS_RAGE_BUFF_IDS = {}
end
addSpellIds(ns.WARRIOR_ENDLESS_RAGE_BUFF_IDS, {
    403349
})

-- Flanking Strike damage debuff (Hunter — 9% increased damage taken, 10s)
if not ns.HUNTER_FLANKING_STRIKE_DEBUFF_IDS then
    ns.HUNTER_FLANKING_STRIKE_DEBUFF_IDS = {}
end
addSpellIds(ns.HUNTER_FLANKING_STRIKE_DEBUFF_IDS, {
    415320
})
