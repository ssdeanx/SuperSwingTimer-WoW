# SoD Integration Plan — SuperSwingTimer (Completed in v0.2.1)

> **STATUS: COMPLETED (v0.2.1)**
> All 9-class SoD rune matrices, C_UnitAuras.GetPlayerAuraBySpellID O(1) optimization, event-driven Maelstrom Weapon (`408505`) stack tracking, Sudden Death proc alerts, UnitGUID fixes, and per-class resource bars are fully implemented and verified.

## Goal

Add Season of Discovery (SoD) support without breaking TBC Anniversary (2.5.6) or Classic Era (1.15.9). All SoD code isolated in `SuperSwingTimer_SoD.lua`. The revised plan addresses: (1) all 9 classes' relevant runes, (2) Shaman weaving mechanics, (3) CLEU timing accuracy, (4) buff/debuff aura instance ID fix, (5) API quality upgrades from the audit.

---

## Architecture Principle

**Zero base-code modifications.** Every SoD feature wires into existing hooks — SoD.lua is the ONLY file modified for SoD support. The pattern is:

1. SoD.lua sets `ns.sodFeature = function() end` or extends lookup tables
2. Existing code already calls `if ns.sodFeature then ns.sodFeature() end`
3. On Classic/TBC: function is never set (nil) → no-op. No if/else branches in core files.
4. Independent CLEU event frame in SoD.lua (no core hooks).

**Extension points used by SoD.lua:**

| Extension Point | What SoD Injects | Nil-Safety |
|---|---|---|
| `addSpellIds()` (local) | SoD rune IDs into `ns.NO_RESET_SWING_SPELLS`, `ns.RESET_SWING_SPELLS`, `ns.PAUSE_SWING_SPELLS`, and new per-class lookup tables | `GetSpellInfo(id)` returns nil on Classic/TBC → entry silently skipped |
| `ns.RegisterOnUpdateHook()` | Per-frame callbacks for Maelstrom polling, power bar updates, proc tracking | Hook runs but returns immediately when its function is nil |
| `ns.RegisterSpellcastSucceededHook()` | SoD rune cast detection (Lava Lash, Raging Blow, Molten Blast) | Empty hook table = no-ops |
| `ns.warriorRageBar` (frame) | SoD creates per-class bars (Shaman Maelstrom, Rogue CP, etc.) | Frame stays nil → Classic code checks `if ns.warriorRageBar then` — safe skip. Classic/TBC see no extra bars |
| New: **Independent CLEU event frame** (SoD.lua creates its own `CreateFrame(\"Frame\")` + `:RegisterEvent(\"COMBAT_LOG_EVENT_UNFILTERED\")`) | CLEU event interception for SoD proc detection | Frame not created on Classic/TBC → no CLEU event processing |
| New: `ns.buffTrackingTables` | Aura instance ID based buff/debuff tracking | Table nil on Classic/TBC → skip scan |
| Lookup tables per class | SoD-specific proc IDs, buff IDs, debuff IDs | Single ID check, nil-safe |

---

## 1. SoD Rune Ability Matrix — All 9 Classes

**Legend:** ✅ = we track // 🔲 = melee-related (should track) // ⬜ = passive/caster only (skip)  
**Spell IDs marked TBD (name) are resolved at runtime via `GetSpellInfo` name→ID.**

### Warrior (17 runes — 8 relevant)

| Rune | Slot | Effect | Track? | Spell ID |
|---|---|---|---|---|
| Blood Frenzy | Chest | Rend +100% dmg, +4% AP per tick | ✅ Buff ID in `ns.WARRIOR_BLOOD_FRENZY_BUFF_IDS` | 412507 |
| Raging Blow | Chest | 115% weapon dmg, enrage-gated | ✅ `NO_RESET_SWING` | 402911 |
| Warbringer | Chest | Charge usable in combat/stances | ⬜ Utility — no swing impact | — |
| Flagellation | Chest | No-armor rage from dmg | ⬜ Passive — no tracking needed | — |
| Victory Rush | Hands | Instant attack + heal on kill | ✅ `NO_RESET_SWING` | 34428 |
| Quick Strike | Hands | 2H instant attack | ✅ `NO_RESET_SWING` | 429765 |
| Single-Minded Fury | Hands | DW: 3% AS stacking, 10% MS | 🔲 Has swing speed modifier | TBD (name) |
| Frenzied Assault | Legs | 2H: +30% AS, +2 rage/hit | ✅ **Critical** — swing speed modifier | TBD (name) |
| Consumed by Rage | Legs | Enrage at 60+ rage, WW strikes offhand | 🔲 Enrage state affects abilities | — |
| Furious Thunder | Legs | Thunder Clap +6% attack speed slow | 🔲 **Affects enemy swing speed** | — |
| Devastate | Hands | Shield + Sunder = dmg + threat | ✅ `NO_RESET_SWING` | TBD (name) |
| Blood Surge | Waist | 30% chance free instant Slam | 🔲 Swing modifier (Slam instant) | TBD (name) |
| Precise Timing | Waist | Slam instant, 6s CD | 🔲 Swing modifier | TBD (name) |
| Endless Rage | Head | +25% rage from all damage | ✅ Buff ID in `ns.WARRIOR_ENDLESS_RAGE_BUFF_IDS` | 403349 |
| Sudden Death | Back | 10% chance Execute at any HP | ✅ Proc tracking → `ns.WARRIOR_SUDDEN_DEATH_BUFF_IDS` | 440114 |
| Taste for Blood | Head | Rend dmg procs Overpower | 🔲 Proc tracking via CLEU | TBD (name) |
| Shield Mastery | Head | +10% phys dmg with shield, disarm reduction | ⬜ Tank passive | — |

### Rogue (16 runes — 7 relevant)

| Rune | Slot | Effect | Track? | Spell ID |
|---|---|---|---|---|
| Saber Slash | Chest | CP-generating attack, bleed | ✅ `NO_RESET_SWING` | 402780 |
| Main Gauche | Chest | Parry + offhand counterattack | ✅ `NO_RESET_SWING` | 409509 |
| Envenom | Chest | Finisher, consume poisons | ✅ `NO_RESET_SWING` | 32645 |
| Secret Technique | Legs | Powerful finisher | ✅ `NO_RESET_SWING` | 426640 |
| Slice and Dice | — | Already tracked | ⬜ Already works | 5171 |
| Mutilate | Hands | Dual-wield CP builder | ✅ `RESET_SWING` or `NO_RESET`? | 409510 |
| Blade Dance | Hands | +dodge, generates CP when dodging | 🔲 CP generation tracking | TBD (name) |
| Shadowstep | Feet | Teleport behind target | ⬜ Movement — no swing impact | — |
| Shuriken Toss | Legs | Ranged CP builder | 🔲 Ranged attack tracking | TBD (name) |
| Between the Eyes | Waist | Stun + ranged finisher | ⬜ No swing impact | — |
| Roll the Bones | Back | Random combat buffs | 🔲 Buff tracking | TBD (name) |
| Poison Knife | Wrist | Instant poison ranged attack | ⬜ No swing impact | — |
| Deadly Brew | Waist | Free poisons on finishers | ⬜ Passive | — |
| Shadow Strike | Head | Shadowstep + strike | ✅ `NO_RESET_SWING` | TBD (name) |
| Quick Draw | Cloak | Ranged attack, slows | ⬜ Ranged, no swing impact | — |
| Crimson Tempest | Cloak | AoE bleed finisher | ✅ `NO_RESET_SWING` | TBD (name) |

### Shaman (15 runes — 6 key + Maelstrom)

| Rune | Slot | Effect | Track? | Spell ID |
|---|---|---|---|---|
| **Maelstrom Weapon** | Chest | Melee hits reduce cast time for offensive spells | ✅ **Critical** — full stack tracking + weave modifier | **408505** |
| **Lava Lash** | Chest | Off-hand attack, +100% dmg if flaming | ✅ `NO_RESET_SWING` — already registered | 408507 |
| **Molten Blast** | Hands | AoE fire dmg, spreads Flame Shock | ✅ `NO_RESET_SWING` | 408247 |
| **Shamanistic Rage** | Hands | 25% dmg reduction, mana regen from AP | 🔲 Buff tracking + resource bar | TBD (name) |
| **Dual Wield** | Legs | Allows DW, 10% hit penalty | 🔲 **Changes weapon tracking** | — |
| **Water Shield** | Chest | Mana regen, charges | ⬜ Resource passive | — |
| **Earth Shield** | Hands | Healing charges | ⬜ Healer — no swing impact | — |
| **Healing Rain** | Legs | AoE heal | ⬜ Healer | — |
| **Lava Burst** | Legs | Guaranteed crit after Flame Shock | ⬜ Cast spell — no swing | — |
| **Ancestral Guidance** | Waist | Healing -> damage | ⬜ Passive | — |
| **Spirit Walk** | Waist | Move while casting, cleanse | ⬜ Utility | — |
| **Fire Nova** | Feet | Instant AoE around Flame Shock target | ✅ `NO_RESET_SWING`? | TBD (name) |
| **Spirit of the Alpha** | Back | Taunt, take more dmg, deal more dmg | ⬜ Tank utility | — |
| **Two-Handed Mastery** | Head | 2H weapon +35% weapon dmg | 🔲 Swing dmg modifier | TBD (name) |
| **Feral Spirit** | Back | Summon wolves | ⬜ Pet summon | — |

### Paladin (16 runes — 6 relevant)

| Rune | Slot | Effect | Track? | Spell ID |
|---|---|---|---|---|
| Crusader Strike | Chest | Melee attack, refreshes Judgements | ✅ `NO_RESET_SWING` | 409553 |
| Hammer of the Righteous | Chest | Melee AoE, +threat with righteous fury | ✅ `NO_RESET_SWING` | 409456 |
| Divine Storm | Hands | AoE Holy dmg | ✅ `NO_RESET_SWING` | 407778 |
| Seal of Martyrdom | Legs | Melee seal, party heals | 🔲 Seal tracking | TBD (name) |
| Sacred Shield | Waist | Prot buff | ⬜ Tank — no swing impact | — |
| Hand of Reckoning | Waist | Taunt | ⬜ Tank | — |
| Sheath of Light | Back | +spell dmg from AP, spell crit heals | 🔲 Buff tracking | TBD (name) |
| Holy Shock | Legs | Instant heal/dmg | ⬜ Healer | — |
| Beacon of Light | Hands | Heal transfer | ⬜ Healer | — |
| Avenger's Shield | Back | Ranged shield stun | ⬜ Tank | — |
| Righteous Vengeance | Head | Extra Holy dmg on crit | 🔲 Proc tracking | TBD (name) |
| Vindicator | Chest | +holy dmg, heal on Judgement | ⬜ Passive | — |
| Seal of Blood | Head | Melee seal, self-dmg, more dmg | 🔲 Seal tracking | TBD (name) |

### Hunter (15 runes — 8 relevant)

| Rune | Slot | Effect | Track? | Spell ID |
|---|---|---|---|---|
| **Flanking Strike** | Chest | Melee attack, Raptor Strike synergy | ✅ `NO_RESET_SWING` + `ns.HUNTER_FLANKING_STRIKE_DEBUFF_IDS` | 415320 |
| **Carve** | Chest | AoE melee attack | ✅ `NO_RESET_SWING` | 425711 |
| **Raptor Fury** | Legs | Raptor Strike extra hit | 🔲 Proc tracking on melee hit | TBD (name) |
| **Explosive Shot** | Hands | Ranged explosive | ✅ `NO_RESET_SWING` (ranged classification) | 53301 |
| **Chimera Shot** | Chest | Ranged, refreshes sting | ✅ `NO_RESET_SWING` | 53209 |
| **Kill Command** | Hands | Pet attack | ⬜ Pet — no swing impact | — |
| **Sniper Training** | Waist | Standing still = +dmg | ⬜ Passive — no tracking | — |
| **Lone Wolf** | Back | +30% all dmg without pet | ⬜ Passive | — |
| **Master Marksman** | Feet | +crit after auto-shot crits | 🔲 Buff proc tracking | TBD (name) |
| **Serpent Spread** | Wrist | Multi-target Serpent Sting | ⬜ Ranged passive | — |
| **Hit and Run** | Head | Raptor Strike = +15% MS | 🔲 Movement modifier | TBD (name) |
| **Rapid Killing** | Back | Kill = AP boost | 🔲 Buff tracking | TBD (name) |
| **Focused Shot** | Legs | Cast time reduces with focus | ⬜ Ranged cast | — |
| **Symbiotic Strike** | Cloak | Kill = extra focus | ⬜ Resource passive | — |
| **Arcane Vulnerability** | Cloak | Arcane Shot = vuln debuff | ⬜ Ranged debuff | — |

### Druid (16 runes — 6 relevant)

| Rune | Slot | Effect | Track? | Spell ID |
|---|---|---|---|---|
| Mangle (Cat) | Chest | CP-generating bleed | ✅ `NO_RESET_SWING` | 3355 |
| Mangle (Bear) | Chest | Rend +threat | ✅ `NO_RESET_SWING` | 33878 |
| Savage Roar | Legs | +30% melee dmg | 🔲 CP tracking | TBD (name) |
| Survival Instincts | Chest | +20% health | ⬜ Tank | — |
| Berserk | Hands | Energy regen, no shapeshif cost | ✅ `NO_RESET_SWING` (Cat form) | TBD (name) |
| Moonkin Form | Chest | Caster form | ⬜ Caster | — |
| Lifebloom | Hands | HoT | ⬜ Healer | — |
| Wild Growth | Legs | AoE HoT | ⬜ Healer | — |
| Living Seed | Back | Heal on crit | ⬜ Healer | — |
| Starsurge | Waist | Instant arcane dmg | ⬜ Caster | — |
| Eclipse | Head | Solar/Lunar empower | ⬜ Caster | — |
| Sunfire | Wrist | AoE arcane DoT | ⬜ Caster | — |
| Skull Bash | Feet | Interrupt | ⬜ Utility | — |
| Frenzied Regeneration | Waist | Heal while enraged | ⬜ Tank | — |
| Renewal | Cloak | Instant self-heal | ⬜ Utility | — |
| Heart of the Wild | Head | +stats in all forms | 🔲 Form switching detection | TBD (name) |

### Mage (16 runes — 1 relevant)

Mage runes are almost all caster-oriented. Only Living Flame touches melee range.

| Rune | Slot | Effect | Track? | Spell ID |
|---|---|---|---|---|
| Living Flame | Chest | Moving flame AoE | ⬜ Caster | — |
| Burnout | Chest | +crit/-hit | ⬜ Caster | — |
| Fingers of Frost | Hands | Auto-proc | ⬜ Caster — but might need tracking for weave | TBD (name) |
| Missile Barrage | Legs | Arcane proc | ⬜ Caster | — |
| All others | — | Pure caster | ⬜ Skip entirely | — |

### Priest (16 runes — 0 relevant)

All priest runes are healing/shadow caster oriented. No melee interaction. **Skip entirely.**

### Warlock (16 runes — 1 relevant)

Warlock tank exists but doesn't affect the addon's scope significantly.

| Rune | Slot | Effect | Track? | Spell ID |
|---|---|---|---|---|
| Metamorphosis | Hands | Demon form, melee tank | ⬜ Tank — skip for v1 | — |
| Demonic Grace | Legs | +dodge +crit self buff | ⬜ No swing impact | — |
| All others | — | Caster/pet | ⬜ Skip for v1 | — |

---

## 2. Shaman Weaving — Full Mechanics

### Maelstrom Weapon (408505)

**How it works:** Each melee auto-attack (main hand and off hand) grants 1 stack of Maelstrom Weapon (up to 5). Each stack reduces cast time and mana cost of off-hand attack spells (Lightning Bolt, Chain Lightning, Lava Burst) by 20%. At 5 stacks, they become instant and free.

**What we need to track:**
1. **Stack count** — `UnitBuff("player", "Maelstrom Weapon")` → read `count`
2. **Stack gain** — CLEU `SWING_DAMAGE` from player (both MH and OH) → increment stack
3. **Stack consumption** — CLEU `SPELL_CAST_SUCCESS` for Lava Burst, Lightning Bolt → reset to 0
4. **Cast time override** — `effectiveCastTime = baseCastTime * max(1 - 0.20 * stacks, 0.20)`
5. **Weave safe window** — When `stacks >= 3`, weaving Lava Burst (1.5s base → 0.9s at 3 stacks) is worth it. At 5 stacks, instant — optimal weave point.

**Implementation approach (revised):**
- Use `C_UnitAuras.GetPlayerAuraBySpellID(408505)` for structured stack data (count, duration, expirationTime) instead of raw `UnitBuff`
- Use CLEU `SWING_DAMAGE` for stack gain (already fires on every melee hit)
- Use CLEU `SPELL_CAST_SUCCESS` for stack consumption
- No OnUpdate polling needed — event-driven stack tracking

### Shaman Resource Bar

Elements to display:
- **Mana bar** (baseline) — `UnitPower("player", 0)` / `UnitPowerMax("player", 0)`
- **Weapon imbue** — `GetWeaponEnchantInfo()` → show current imbue (Windfury, Flametongue, Rockbiter, Frostbrand)
- **Flame Shock debuff** — `C_UnitAuras.GetDebuffDataByIndex("target", index)` → check debuff presence for Molten Blast/Lava Burst synergy

Maelstrom Weapon is tracked as a player buff via `C_UnitAuras` — its stack count feeds into the weave helper calculation, not a resource bar.

### Weave Helper Overrides

SoD.lua registeres:
```lua
ns.RegisterOnUpdateHook(function()
    if not C_UnitAuras then return end
    local auraData = C_UnitAuras.GetPlayerAuraBySpellID(408505)
    local stacks = auraData and auraData.count or 0
    if ns.maelstromStacks ~= stacks then
        ns.maelstromStacks = stacks
        -- Recalculate weave safe window
        if ns.RecalculateWeaveWindow then
            ns.RecalculateWeaveWindow()
        end
    end
end)
```

---

## 3. CLEU Server Timestamp (Minor — Optional)

`ns.GetAlignedTime()` returns `GetTimePreciseSec() + (GetTime()_init − GetTimePreciseSec()_init)`. Both functions share the same epoch. GetTimePreciseSec gives sub-ms precision from there. The CLEU server timestamp (position 1) is the same epoch — negligible difference for relative swing timing.

**Decision: Skip.** Not worth touching core State.lua.

---

## 4. Buff/Debuff Aura Instance ID Fix

### Current Problem

The addon uses index-based aura scanning via `GetHelpfulAuraData(unit, index)` and `GetHarmfulAuraData(unit, index, filter)`. These return `spellID` from position 11 of `UnitAura`. The SoD lookup tables match on spellID:

```lua
-- ClassMods.lua ~line 2398
if type(auraSpellId) == "number" and ns.WARRIOR_REND_IDS and ns.WARRIOR_REND_IDS[auraSpellId] then
```

This fails when:
1. Multiple applications of the same spell on the same unit (e.g., 5 warriors' Rends on one target) — spellIDs match but you can't identify YOUR application
2. The same buff from different casters (e.g., two Shamans casting Earth Shield) — spellID is the same
3. Stacks of the same buff (e.g., Maelstrom Weapon) — spellID is the same, need to check count from the INSTANCE that belongs to YOU
4. Debuffs where `caster ~= "player"` — the spellID matches but the aura belongs to another player

### Fix: Switch to `C_UnitAuras` with aura instance ID

Replace `GetHarmfulAuraData` / `GetHelpfulAuraData` in SoD-specific tracking with:

```lua
-- SoD.lua
local C_UnitAuras = rawget(_G, "C_UnitAuras")

function ns.GetSoDAuraData(unit, spellId, filter)
    if not C_UnitAuras or type(C_UnitAuras.GetAuraDataBySpellName) ~= "function" then
        return nil  -- Fallback: not available on Classic/TBC
    end
    local auraData = C_UnitAuras.GetUnitAuraBySpellID(unit, spellId)
    if not auraData then return nil end

    return {
        auraInstanceID = auraData.auraInstanceID,
        count = auraData.count or 0,
        duration = auraData.duration,
        expirationTime = auraData.expirationTime,
        caster = auraData.caster,      -- VERY important: who cast this?
        isHarmful = auraData.isHarmful,
        isHelpful = auraData.isHelpful,
        spellID = auraData.spellID,
    }
end
```

For debuffs, also filter by caster:
```lua
local data = C_UnitAuras.GetUnitAuraBySpellID("target", REND_SPELL_ID)
if data and data.caster == "player" then
    -- This is YOUR Rend on the target — track it
end
```

### Comparison: Old vs New

| Aspect | Old (spellID) | New (aura instance ID) |
|---|---|---|
| Match method | `spellID == LOOKUP_KEY` | `spellID == TARGET_SPELL AND caster == "player"` |
| Stack count | From `UnitAura` `count` position | From `auraData.count` |
| Duration | From `UnitAura` `duration` position | From `auraData.duration` |
| Expiration | From `UnitAura` `expirationTime` | From `auraData.expirationTime` |
| Caster check | Manually via CLEU only | `auraData.caster` built-in |
| Instance uniqueness | Same spellID for all apps | `auraInstanceID` is globally unique |
| Client support | Universal (Classic/TBC/Retail) | Both classic_era and classic_anniversary |
| Failure mode | Wrong buff/debuff shows | Only yours shows — correct |

### Affected lookup tables

These tables in SoD.lua need the aura-instance-ID tracking approach:

| Table | What it tracks | Issue | Fix |
|---|---|---|---|
| `ns.WARRIOR_REND_IDS` | Rend debuff | Multiple warriors' Rends show as one | Filter by `caster == "player"` |
| `ns.WARRIOR_BLOOD_FRENZY_BUFF_IDS` | Blood Frenzy proc | Self-only buff, but spellID resolves to first match | Use `C_UnitAuras.GetPlayerAuraBySpellID(412507)` |
| `ns.WARRIOR_SUDDEN_DEATH_BUFF_IDS` | Sudden Death proc | Self-only buff | Use `GetPlayerAuraBySpellID(440114)` |
| `ns.WARRIOR_ENDLESS_RAGE_BUFF_IDS` | Endless Rage | Passive — always active, no aura check needed | Remove scan; just check if player has the rune |
| `ns.HUNTER_FLANKING_STRIKE_DEBUFF_IDS` | Flanking Strike debuff on target | Your FS debuff vs another hunter's | Filter by `caster == "player"` |

---

## 5. Truly New APIs (not yet used — from audit)

Already-used APIs removed from this section (the audit doc flagged them as unused, but they're in ClassMods.lua): `GetSpellTexture`, `CheckInteractDistance`, `UnitPowerMax`.

| API | Where to Use | What It Replaces | Benefit |
|---|---|---|---|
| `C_Spell.DoesSpellExist(id)` | Every SoD gate check | `GetSpellInfo(id) and true or false` | Boolean return, cleaner |
| `GetClassicExpansionLevel()` | Init block in SoD.lua | Nothing — no version detection | `0=Classic/SoD, 1=TBC` |
| `GetWeaponEnchantInfo()` | Shaman resource bar | Nothing — no enchant display | Show Windfury/Flametongue/Rockbiter |
| `C_Spell.IsSpellUsable(id)` | Weave helper | Nothing — shows regardless | Gray out when spell can't be cast |
| `PlaySound(soundKitID)` | Proc alerts | Nothing — no audio | Alert on Maelstrom 5-stack, Sudden Death |
| `C_UnitAuras.GetPlayerAuraBySpellID(id)` | Buff/debuff tracking | `UnitBuff("player", index)` scan | O(1) lookup + caster field |
| `C_UnitAuras.GetUnitAuraBySpellID(unit, id)` | Debuff tracking | `GetHarmfulAuraData()` | Structured data with `caster` |
| `GetInventoryItemLink("player", slotId)` | Weapon tooltip | Nothing | Show weapon name on swing bar |

All added via `rawget` nil-safety pattern.

---

## 6. Implementation Order

### Phase A: Foundation (no SoD.lua changes needed)

1. ~~CLEU timestamp fix~~ **Skipped** — `GetAlignedTime()` is already `GetTimePreciseSec() + offset`. No change to State.lua CLEU handler.

2. **`C_Spell.DoesSpellExist`** — Replace `GetSpellInfo(id)` nil-checks in SoD.lua
   - File: SoD.lua — change `addSpellIds` to prefer `C_Spell.DoesSpellExist(id)` instead of `ns.GetSpellInfo(id)` for the gating check
   - Retain `ns.GetSpellInfo(id)` for name resolution (needed for name-keyed lookups)

3. **`GetClassicExpansionLevel`** — Add init block
   ```lua
   if type(GetClassicExpansionLevel) == "function" then
       ns.expansionLevel = GetClassicExpansionLevel()  -- 0 = Classic, 1 = TBC
   end
   ```

### Phase B: SoD Rune Registration

4. **Expand `addSpellIds`** — Add all relevant SoD rune spell IDs (per matrix above, ~50+ IDs)
   - Create per-class lookup tables: `ns.SOD_WARRIOR`, `ns.SOD_ROGUE`, etc.
   - Each table gates: `if C_Spell.DoesSpellExist(RUNE_ID) then -- SoD mode`

5. **Per-class flag** — After registration, set `ns.playerIsSoD = true` if any SoD spell exists:
   ```lua
   ns.playerIsSoD = C_Spell and C_Spell.DoesSpellExist and C_Spell.DoesSpellExist(MAELSTROM_WEAPON_ID)
   ```

### Phase C: Per-Class Power Bars

**Current state (critical):** `ns.warriorRageBar` is only created in `SetupWarrior()`. For all 5 other melee classes (Shaman, Rogue, Hunter, Druid, Paladin) there is NO power bar — `ns.warriorRageBar` is nil. Existing code guards with `if ns.warriorRageBar then ... end`, so a nil bar silently does nothing. SoD.lua must create the missing bars for those classes.

6. **Create SoD power bar frames** — Only when `ns.playerIsSoD` is true
   - Shaman: Mana + weapon imbue via `GetWeaponEnchantInfo` (Windfury/Flametongue). Maelstrom is tracked as a buff, not a bar.
   - Rogue: Energy + Combo Points via `GetComboPoints`
   - Hunter: Mana + Raptor Strike status
   - Druid: Form-aware (Mana/Rage/Energy) + CP via `GetComboPoints`
   - Paladin: Mana + Holy Power equivalent

7. **Per-class power bar creation** — SoD.lua checks player class at init and creates ONE bar for this character (not a dispatch table for all 6):
   ```lua
   local class = select(2, UnitClass("player"))
   if class == "SHAMAN" and C_Spell.DoesSpellExist(MAELSTROM_WEAPON_ID) then
       ns.CreateShamanResourceBar() -- own frame, own update loop, zero core changes
   elseif class == "ROGUE" and (C_Spell.DoesSpellExist(SABER_SLASH_ID) or GetComboPoints) then
       ns.CreateRogueEnergyBar()
   elseif class == "DRUID" and (C_Spell.DoesSpellExist(MANGLE_CAT_ID) or GetComboPoints) then
       -- Form-aware: Mana/Rage/Energy + CP
       ns.CreateDruidResourceBar()
   elseif class == "HUNTER" and C_Spell.DoesSpellExist(FLANKING_STRIKE_ID) then
       ns.CreateHunterResourceBar()
   elseif class == "PALADIN" and C_Spell.DoesSpellExist(CRUSADER_STRIKE_ID) then
       ns.CreatePaladinResourceBar()
   end
   -- WARRIOR: existing ns.warriorRageBar already works untouched
   ```
   Each `ns.CreateXxxResourceBar()` creates a separate frame with its own `OnUpdate` callback via `ns.RegisterOnUpdateHook`. The existing `ns.warriorRageBar` + `ns.UpdateWarriorRageBar` are never touched.

### Phase D: Shaman Weaving

8. **Maelstrom Weapon tracking** — Event-driven via SoD.lua's own CLEU frame:
   - **Stack gain** — CLEU `SWING_DAMAGE` from player (both MH & OH) → increment via SoD's frame handler
   - **Stack consumption** — CLEU `SPELL_CAST_SUCCESS` for Lava Burst, Lightning Bolt → reset to 0
   - **Current stack count** — `C_UnitAuras.GetPlayerAuraBySpellID(408505).count` for accurate snapshot
   - Store `ns.maelstromStacks` on every change
   - Recalculate weave safe window when stacks change

9. **Weave safe window** — SoD.lua stores `ns.maelstromCastTimeMultiplier` and calculates the reduced cast time in its own helper. No modification to Weaving.lua:
   ```lua
   -- SoD.lua, in the Maelstrom aura update handler:
   local stacks = auraData and auraData.count or 0
   ns.maelstromStacks = stacks
   ns.maelstromCastTimeMultiplier = math.max(1 - 0.20 * stacks, 0)  -- 5 stacks = instant (0s)
   ```
   The SoD weave helper uses: `effectiveTime = baseCastTime * ns.maelstromCastTimeMultiplier`
   to determine if weaving a spell between swings is worth it. The core Weaving.lua `ns.AutoShotSpellcastStartTime` calculation is untouched.

10. **Weave helper icons** — Use `GetSpellTexture` to show Maelstrom icon + stack count on helper

### Phase E: Proc Tracking

11. **Buff scanning** — Use `C_UnitAuras.GetPlayerAuraBySpellID` for:
    - Blood Frenzy (412507)
    - Sudden Death (440114)
    - Endless Rage (403349) — passive, check rune existence, not aura
    - Shamanistic Rage buff
    - Blade Dance buff

12. **Debuff scanning** — Use `C_UnitAuras.GetUnitAuraBySpellID("target", id)` with caster filter:
    - Rend (any rank) — `caster == "player"`
    - Flanking Strike — `caster == "player"`
    - Flame Shock — `caster == "player"` (for Shaman weaving synergy)

### Phase F: Audio & Visual

13. **Proc alerts** — `PlaySound(soundKitID)` on:
    - Maelstrom Weapon reaches 5 stacks
    - Sudden Death procs
    - Blood Frenzy activates

14. **Weave helper icons** — `GetSpellTexture(spellId)` for all registerd spells

---

## Dependencies

- **No base-code file modifications:** State.lua, ClassMods.lua, Weaving.lua, Constants.lua remain unchanged
- **SoD.lua uses:**
  - `ns.RegisterOnUpdateHook()` and `ns.RegisterSpellcastSucceededHook()` — defined in Hooks.lua (RegisterOnUpdate) and State.lua (RegisterSpellcastSucceeded)
  - **Independent CLEU event frame** — SoD.lua creates `CreateFrame("Frame")` + `RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")`. Zero changes to State.lua.
  - **Per-class bar frames** — SoD.lua creates ONE bar for the player's class. Does not touch `ns.UpdateWarriorRageBar` or `ns.warriorRageBar`.
- **All SoD-specific frames** created in SoD.lua gated by `C_Spell.DoesSpellExist(sodRuneId)`
- **All nil-safety** is from the WoW API itself: `C_UnitAuras` is nil on Classic/TBC without SoD, `GetSpellInfo` returns nil for non-existent rune spells

## API Verification

Full 52-API audit at `docs/api-quality-audit.md`. 62-API compatibility check at `API_AUDIT_REPORT.md`. Verified on both branches:
- `origin/classic_era` (1.15.9, build 68940)
- `origin/classic_anniversary` (2.5.6, build 68941)

Key findings: all APIs exist on both branches. Three nil-guarded APIs (`GetSpellHaste`, `InterfaceOptions_AddCategory`, `LibStub`) are the only unavailable ones — all already guarded. No new API gaps for any SoD feature.

All verified on both classic_era and classic_anniversary branches. Nil-safety pattern documented in `API_AUDIT_REPORT.md`.

### P1 — implement in SoD.lua init
- `C_Spell.DoesSpellExist(spellId)` — cleaner SoD gating
- `GetClassicExpansionLevel()` — client version detection
- `GetWeaponEnchantInfo()` — Shaman imbue bar
- `C_UnitAuras.GetPlayerAuraBySpellID(spellId)` — O(1) self-buff check (replaces index scan)

### P2 — implement as needed
- `GetComboPoints("player")` — Rogue/Druid CP bar
- `UnitAttackPower("player")` — AP on swing bar tooltip
- `UnitDamage("player")` — damage range on swing bar
- `C_Spell.IsSpellUsable(spellId)` — weave helper graying
- `PlaySound(soundKitID)` — proc audio alerts
- `C_UnitAuras.GetUnitAuraBySpellID(unit, spellId)` — debuff tracking with caster field
- `C_UnitAuras.GetAuraDataBySpellName(unit, name)` — named aura lookup
- `GetInventoryItemLink("player", slotId)` — weapon tooltip

Already in use (ClassMods.lua — not new): `GetSpellTexture`, `CheckInteractDistance`, `UnitPowerMax`.

---

## Key Design Decisions

1. **No core file modifications** — State.lua, Weaving.lua, ClassMods.lua, Constants.lua stay untouched. SoD.lua only.
2. **`C_UnitAuras` replaces index-based scanning** for SoD buff/debuff tracking. Uses `GetPlayerAuraBySpellID` (self) and `GetUnitAuraBySpellID` with caster filter (target). Falls back to index scanning on Classic non-SoD.
3. **Per-class SoD lua table** for rune IDs (`ns.SOD_RUNES[class]`), not global mixins. Clean class dispatch at runtime.
4. **Shaman weaving is event-driven** — stack gain from CLEU, stack consumption from CLEU, stack peek from `C_UnitAuras`. OnUpdate only as fallback.
5. **Aura instance ID tracking** means debuffs are correctly scoped to the player. No more seeing other warriors' Rends on your swing bar.
