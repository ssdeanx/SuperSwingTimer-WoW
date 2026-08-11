-- ============================================================
-- SuperSwingTimer_SoD.lua
-- Season of Discovery (SoD 1.15.9) isolated feature module.
--
-- This file provides full Season of Discovery support while
-- strictly preserving compatibility with Classic Era (1.15.9)
-- and TBC Anniversary (2.5.6).
--
-- ZERO BASE-CODE MODIFICATION GUARANTEE:
-- All SoD rune classifications, Maelstrom Weapon weave helpers,
-- and isolated CLEU proc trackers reside strictly within this file.
-- Core files remain 100% untouched. SoD does NOT create extra UI bars.
-- ============================================================

local _, ns = ...

-- ============================================================
-- 1. Environment Detection: Is SoD Active?
-- ============================================================
local function IsSoDActive()
    local C_Seasons = rawget(_G, "C_Seasons")
    if C_Seasons and type(C_Seasons.GetActiveSeason) == "function" then
        local season = C_Seasons.GetActiveSeason()
        -- 2 = Enum.SeasonID.SeasonOfDiscovery
        if season == 2 then
            return true
        end
    end

    local C_Engraving = rawget(_G, "C_Engraving")
    if C_Engraving and type(C_Engraving.IsEngravingEnabled) == "function" then
        if C_Engraving.IsEngravingEnabled() then
            return true
        end
    end

    return false
end

ns.isSoD = IsSoDActive()

-- ============================================================
-- 2. Helper: Add spell IDs & localized names to lookup table
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
-- 3. Comprehensive Rune Ability Matrix — All 9 Classes
-- ============================================================

-- NO_RESET_SWING_SPELLS: SoD instant attacks that do NOT reset swing timer
addSpellIds(ns.NO_RESET_SWING_SPELLS, {
    -- Warrior SoD Runes
    429765, -- Quick Strike (2H instant filler)
    402911, -- Raging Blow (Enrage-gated instant)
    407133, -- Devastate (Shield + Sunder attack)
    407135, -- Devastate rank variant
    413380, -- Blood Surge Slam (Instant Slam proc)
    413399, -- Blood Surge proc
    426956, -- Precise Timing (Instant Slam 6s CD)
    426940, -- Rampage Rune active spell ID
    426942, -- Rampage Proc Buff Aura ID

    -- Rogue SoD Runes
    402780, -- Saber Slash (CP attack + bleed)
    409509, -- Main Gauche (Parry counterattack)
    400011, -- Envenom rank variant
    426640, -- Secret Technique (Finisher)
    409510, -- Mutilate (DW dual strike)
    409513, -- Mutilate rank variant
    400029, -- Shadow Strike (Stealth strike)
    409898, -- Quick Draw (Ranged strike)
    424785, -- Poison Knife (Ranged offhand throw)
    412096, -- Crimson Tempest (AoE finisher)

    -- Shaman SoD Runes
    408507, -- Lava Lash (Off-hand attack)
    408247, -- Molten Blast (AoE fire strike)
    408331, -- Fire Nova (Instant AoE)

    -- Paladin SoD Runes
    409553, -- Crusader Strike (Melee attack)
    409456, -- Hammer of the Righteous (Melee AoE)
    407778, -- Divine Storm (AoE Holy strike)
    409540, -- Rebuke (Interrupt)

    -- Hunter SoD Runes
    415320, -- Flanking Strike (Melee pet strike)
    425711, -- Carve (Frontal AoE)
    415318, -- Melee Specialist (Instant Raptor Strike rune)
    425515, -- Dual Wield Specialization (Melee DW rune)
    415423, -- Aspect of the Viper (Melee mana return)
    53209,  -- Chimera Shot (Ranged strike)
    409433, -- Chimera Shot variant
    53301,  -- Explosive Shot (Ranged explosive)
    409552, -- Explosive Shot variant

    -- Druid
    3355,   -- Mangle (Cat)
    409805, -- Mangle (Cat rune variant)
    33878,  -- Mangle (Bear)
    409804, -- Mangle (Bear rune variant)
    414644, -- Lacerate (Bear bleed strike)
    417141, -- Berserk (Cat/Bear form)
    407988, -- Savage Roar (Finisher)
    414689, -- Sunfire (Cat)
    414684, -- Sunfire (Bear)

    -- Warlock
    403835, -- Shadow Cleave (Metamorphosis melee attack)
})

-- PAUSE_SWING_SPELLS: Spells with cast time that pause swing timer
addSpellIds(ns.PAUSE_SWING_SPELLS, {
    400320, -- Spellfrost Bolt (Mage)
    412510, -- Chronostatic Preservation (Mage)
})

-- ============================================================
-- 4. Buff & Debuff Tracking Tables
-- ============================================================

-- Warrior
ns.WARRIOR_REND_IDS = ns.WARRIOR_REND_IDS or {}
addSpellIds(ns.WARRIOR_REND_IDS, { 772, 6546, 6547, 6548, 11572, 11573, 11574 })

ns.WARRIOR_BLOOD_FRENZY_BUFF_IDS = ns.WARRIOR_BLOOD_FRENZY_BUFF_IDS or {}
addSpellIds(ns.WARRIOR_BLOOD_FRENZY_BUFF_IDS, { 412507 })

ns.WARRIOR_SUDDEN_DEATH_BUFF_IDS = ns.WARRIOR_SUDDEN_DEATH_BUFF_IDS or {}
addSpellIds(ns.WARRIOR_SUDDEN_DEATH_BUFF_IDS, { 440114 })

ns.WARRIOR_ENDLESS_RAGE_BUFF_IDS = ns.WARRIOR_ENDLESS_RAGE_BUFF_IDS or {}
addSpellIds(ns.WARRIOR_ENDLESS_RAGE_BUFF_IDS, { 403349 })

-- Hunter
ns.HUNTER_FLANKING_STRIKE_DEBUFF_IDS = ns.HUNTER_FLANKING_STRIKE_DEBUFF_IDS or {}
addSpellIds(ns.HUNTER_FLANKING_STRIKE_DEBUFF_IDS, { 415320 })

-- Shaman
ns.SHAMAN_MAELSTROM_WEAPON_ID = 408505

-- Rogue
ns.ROGUE_BLADE_DANCE_BUFF_IDS = ns.ROGUE_BLADE_DANCE_BUFF_IDS or {}
addSpellIds(ns.ROGUE_BLADE_DANCE_BUFF_IDS, { 400012 })

-- ============================================================
-- SoD Tracked Spells per Class (wired into ClassMods icon groups)
-- ============================================================
ns.SOD_TRACKED_SPELLS = {
    WARRIOR = {
        { spellId = 412507, name = "Blood Frenzy", label = "BF", kind = "buff" },
        { spellId = 440114, name = "Sudden Death", label = "SD", kind = "buff" },
        { spellId = 402911, name = "Raging Blow", label = "RB", kind = "cd" },
        { spellId = 429765, name = "Quick Strike", label = "QS", kind = "cd" },
        { spellId = 402877, name = "Flagellation", label = "Flag", kind = "buff" },
        { spellId = 403349, name = "Endless Rage", label = "ERg", kind = "buff" },
        { spellId = 426942, name = "Rampage", label = "Ramp", kind = "buff" },
        { spellId = 407133, name = "Devastate", label = "Dev", kind = "cd" },
        { spellId = 34428,  name = "Victory Rush", label = "VR", kind = "cd" },
        { spellId = 402913, name = "Enraged Regeneration", label = "EReg", kind = "buff" },
        { spellId = 403338, name = "Intervene", label = "Vene", kind = "cd" },
    },
    ROGUE = {
        { spellId = 400012, name = "Blade Dance", label = "BD", kind = "buff" },
        { spellId = 402780, name = "Saber Slash", label = "SS", kind = "cd" },
        { spellId = 409509, name = "Main Gauche", label = "MG", kind = "buff" },
        { spellId = 32645,  name = "Envenom", label = "Env", kind = "buff" },
        { spellId = 400016, name = "Shadowstep", label = "Step", kind = "cd" },
        { spellId = 426640, name = "Secret Technique", label = "ST", kind = "cd" },
        { spellId = 409510, name = "Mutilate", label = "Mut", kind = "cd" },
        { spellId = 409844, name = "Rolling with the Punches", label = "RwtP", kind = "buff" },
        { spellId = 409503, name = "Unfair Advantage", label = "UA", kind = "buff" },
        { spellId = 424785, name = "Poison Knife", label = "PK", kind = "cd" },
    },
    SHAMAN = {
        { spellId = 408505, name = "Maelstrom Weapon", label = "MSW", kind = "buff" },
        { spellId = 425336, name = "Shamanistic Rage", label = "SR", kind = "buff" },
        { spellId = 408507, name = "Lava Lash", label = "LL", kind = "cd" },
        { spellId = 408247, name = "Molten Blast", label = "MB", kind = "cd" },
        { spellId = 408696, name = "Spirit of the Alpha", label = "Alpha", kind = "buff" },
        { spellId = 408531, name = "Way of Earth", label = "WoE", kind = "buff" },
        { spellId = 408527, name = "Shield Mastery", label = "SMast", kind = "buff" },
        { spellId = 415100, name = "Power Surge", label = "PSurge", kind = "buff" },
        { spellId = 408498, name = "Dual Wield Specialization", label = "DW", kind = "buff" },
        { spellId = 408490, name = "Lava Burst", label = "LvB", kind = "cd" },
        { spellId = 408331, name = "Fire Nova", label = "FN", kind = "cd" },
    },
    HUNTER = {
        { spellId = 415320, name = "Flanking Strike", label = "FS", kind = "cd" },
        { spellId = 425711, name = "Carve", label = "Carve", kind = "cd" },
        { spellId = 53209,  name = "Chimera Shot", label = "CS", kind = "cd" },
        { spellId = 53301,  name = "Explosive Shot", label = "ES", kind = "cd" },
        { spellId = 415318, name = "Melee Specialist", label = "MSpec", kind = "buff" },
        { spellId = 425515, name = "Dual Wield Specialization", label = "DW", kind = "buff" },
        { spellId = 415423, name = "Aspect of the Viper", label = "Viper", kind = "buff" },
        { spellId = 415317, name = "Lone Wolf", label = "LWolf", kind = "buff" },
    },
    PALADIN = {
        { spellId = 409553, name = "Crusader Strike", label = "CS", kind = "cd" },
        { spellId = 407778, name = "Divine Storm", label = "DS", kind = "cd" },
        { spellId = 409456, name = "Hammer of the Righteous", label = "HotR", kind = "cd" },
        { spellId = 425447, name = "Sheath of Light", label = "SoL", kind = "buff" },
        { spellId = 407627, name = "Sacred Shield", label = "SS", kind = "buff" },
        { spellId = 409540, name = "Rebuke", label = "Reb", kind = "cd" },
        { spellId = 407630, name = "Aegis", label = "Aegis", kind = "buff" },
        { spellId = 409859, name = "Hand of Reckoning", label = "HoR", kind = "cd" },
        { spellId = 408435, name = "Guarded by the Light", label = "GbtL", kind = "buff" },
        { spellId = 408434, name = "Fanaticism", label = "Fan", kind = "buff" },
        { spellId = 408432, name = "Art of War", label = "AoW", kind = "buff" },
    },
    DRUID = {
        { spellId = 407988, name = "Savage Roar", label = "SR", kind = "buff" },
        { spellId = 407982, name = "Wild Strikes", label = "WS", kind = "buff" },
        { spellId = 417141, name = "Berserk", label = "Zerk", kind = "buff" },
        { spellId = 409805, name = "Mangle", label = "Mangle", kind = "cd" },
        { spellId = 408005, name = "Survival Instincts", label = "SI", kind = "buff" },
        { spellId = 407993, name = "Lacerate", label = "Lac", kind = "cd" },
        { spellId = 407995, name = "Skull Bash", label = "SBash", kind = "cd" },
    },
}

-- ============================================================
-- 5. Safe Aura Data Fetcher with Player Caster Filter
-- ============================================================
function ns.GetSoDAuraData(unit, targetSpellId, filter)
    if not targetSpellId then return nil end

    local targetMap = {}
    if type(targetSpellId) == "table" then
        for _, val in ipairs(targetSpellId) do
            if type(val) == "number" then
                targetMap[val] = true
                if ns.GetSpellInfo then
                    local sName = ns.GetSpellInfo(val)
                    if sName then targetMap[sName] = true end
                end
            elseif type(val) == "string" then
                targetMap[val] = true
            end
        end
    elseif type(targetSpellId) == "number" then
        targetMap[targetSpellId] = true
        if ns.GetSpellInfo then
            local sName = ns.GetSpellInfo(targetSpellId)
            if sName then targetMap[sName] = true end
        end
    elseif type(targetSpellId) == "string" then
        targetMap[targetSpellId] = true
    end

    -- O(1) direct lookup optimization via C_UnitAuras when querying player self-buffs
    local C_UnitAuras = rawget(_G, "C_UnitAuras")
    if unit == "player" and C_UnitAuras and type(C_UnitAuras.GetPlayerAuraBySpellID) == "function" then
        if type(targetSpellId) == "number" then
            local auraData = C_UnitAuras.GetPlayerAuraBySpellID(targetSpellId)
            if auraData then
                return {
                    name = auraData.name,
                    rank = nil,
                    icon = auraData.icon,
                    count = auraData.applications or auraData.count or 0,
                    debuffType = auraData.dispelName,
                    duration = auraData.duration or 0,
                    expirationTime = auraData.expirationTime or 0,
                    unitCaster = auraData.sourceUnit,
                    isPlayerCaster = (auraData.sourceUnit == "player"),
                    spellID = auraData.spellId or targetSpellId,
                }
            end
        end
    end

    if not ns.UnitAura then return nil end

    filter = filter or "HELPFUL"
    local idx = 1
    while idx <= 40 do
        local name, rank, icon, count, debuffType, duration, expTime, unitCaster, _, _, spellID = ns.UnitAura(unit, idx, filter)
        if not name then break end

        if (spellID and targetMap[spellID]) or (name and targetMap[name]) then
            return {
                name = name,
                rank = rank,
                icon = icon,
                count = count or 0,
                debuffType = debuffType,
                duration = duration or 0,
                expirationTime = expTime or 0,
                unitCaster = unitCaster,
                isPlayerCaster = (unitCaster == "player"),
                spellID = spellID or targetSpellId,
            }
        end
        idx = idx + 1
    end

    return nil
end

-- ============================================================
-- 6. Standalone Event Listener for SoD Procs & Maelstrom Tracking
-- ============================================================
if ns.isSoD then
    local sodEventFrame = CreateFrame("Frame")
    sodEventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    sodEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

    ns.maelstromStacks = 0
    ns.maelstromCastTimeMultiplier = 1.0

    local function ResetMaelstrom()
        ns.maelstromStacks = 0
        ns.maelstromCastTimeMultiplier = 1.0
    end

    sodEventFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" then
            ResetMaelstrom()
            return
        end

        if event == "COMBAT_LOG_EVENT_UNFILTERED" then
            local getInfo = rawget(_G, "CombatLogGetCurrentEventInfo")
            if not getInfo then return end

            local _, subevent, _, sourceGUID, _, _, _, _, _, _, _, spellID = getInfo()
            local playerGUID = (type(UnitGUID) == "function") and UnitGUID("player") or nil

            if not playerGUID or sourceGUID ~= playerGUID then return end

            -- Shaman Maelstrom Weapon stack gain/consumption
            if subevent == "SWING_DAMAGE" or subevent == "SWING_MISSED" then
                local auraData = ns.GetSoDAuraData("player", ns.SHAMAN_MAELSTROM_WEAPON_ID, "HELPFUL")
                if auraData then
                    ns.maelstromStacks = math.min(auraData.count, 5)
                    ns.maelstromCastTimeMultiplier = math.max(1.0 - (0.20 * ns.maelstromStacks), 0.0)
                    if ns.maelstromStacks == 5 and type(PlaySound) == "function" then
                        PlaySound(8960) -- Proc sound kit ID
                    end
                end
            elseif subevent == "SPELL_CAST_SUCCESS" then
                -- Spells that consume Maelstrom stacks
                if spellID == 408498 or spellID == 408500 or spellID == 408490 then
                    ResetMaelstrom()
                end

                -- Warrior Sudden Death proc audio alert
                if spellID == 440114 and type(PlaySound) == "function" then
                    PlaySound(8960)
                end
            end
        end
    end)
end
