# Paladin — Class Reference

## Timing constants (source: source code)

| Constant | Value | Notes |
|----------|-------|-------|
| `GCD_DURATION` | `1.5` | Global cooldown for reseal marker (State.lua:824) |
| `ns.PALADIN_JUDGEMENT_COOLDOWN` | `10` | Base CD in seconds; talents reduce it (Constants.lua:311) |
| Seal twist window | `0.4 + ns.cachedLatency` | Computed inline in ClassMods — not a named constant |
| `ns.cachedLatency` | `GetNetStats()` world/home /1000 | Added to twist window; refreshed 0.05s cadence |
| `CAST_WINDOW` | `0.5` | Not directly used by paladin (shared constant) |
| Swing flash | `0.08s` | Bar flash on landing (State.lua:41) |

## Seal twist zone
- Three textures on MH bar: twist zone, reseal line, judgement marker
- **Twist zone**: Right-anchored proportional-width red fill zone (`{1,0,0,0.35}` default — `colors.sealTwist`)
- **Reseal line**: GCD-aware secondary marker positioned at `swingEnd - GCD` (where `GCD = 1.5s`)
- **Judgement marker**: Swing-end strike marker at exact swing landing position
- **MUST** use `SetDrawLayer("OVERLAY", 0)` for all three — never route through shaman weave code path (v0.0.8 bugfix)

### Twist zone math (ClassMods)
```
twistWindow  = 0.4 + cachedLatency
zoneWidth    = twistWindow / swingDuration * barWidth   // proportional to bar width
zonePosition = right-anchored (barWidth - zoneWidth, 0)
```
- Zone position re-computed every frame from current `t.duration` and `remaining`
- Default color changed from opaque black to transparent red in v33→v34 migration

## Seal families (source: Constants.lua:243-294)
| Family | Key | Label | Spell IDs | Twist? |
|--------|-----|-------|-----------|--------|
| Command | `COMMAND` | Seal of Command | `20375, 20915, 20918, 20919, 20920, 27170` | ✅ Yes |
| Corruption | `CORRUPTION` | Seal of Corruption | `348704` | ❌ |
| Blood | `BLOOD` | Seal of Blood | `31892` | ✅ Yes |
| Martyr | `MARTYR` | Seal of the Martyr | `348700` | ✅ Yes |
| Vengeance | `VENGEANCE` | Seal of Vengeance | `31801` | ❌ |
| Justice | `JUSTICE` | Seal of Justice | `20165, 31895` | ❌ |
| Wisdom | `WISDOM` | Seal of Wisdom | `20166, 20356, 20357, 27166` | ❌ |
| Righteousness | `RIGHTEOUSNESS` | Seal of Righteousness | `20154, 20287-20293, 27155` (9 ranks) | ❌ |
| Light | `LIGHT` | Seal of Light | `20166, 20347, 20348, 20349, 27160` | ❌ |
| Crusader | `CRUSADER` | Seal of the Crusader | `21082, 20162, 20305-20308, 27158` (7 ranks) | ❌ |

### Twist families (ns.PALADIN_SEAL_TWIST_FAMILIES)
```
COMMAND = true, BLOOD = true, MARTYR = true
```
Only these three get the red twist zone + reseal marker. Other families show only the judgement marker.

### Lookup tables (Constants.lua:296-364)
- `ns.PALADIN_SEAL_LOOKUP` — spell ID → family key
- `ns.PALADIN_SEAL_NAME_LOOKUP` — aura name → family key (preferred lookup path)
- `ns.GetPaladinSealFamilyBySpellId(spellId)` — returns family key or nil
- `ns.GetPaladinSealFamilyByAuraName(auraName)` — returns family key or nil
- Name lookup built from both `family.names` AND localized names via `ns.GetSpellInfo()`

## Seal colors (source: Constants.lua:368-379, DB_DEFAULTS:637-646)
| Family | Default Color | DB Key |
|--------|---------------|--------|
| Command | `{1.00, 0.85, 0.00, 1}` | `sealColorCOMMAND` |
| Blood | `{0.80, 0.10, 0.10, 1}` | `sealColorBLOOD` |
| Martyr | `{0.50, 0.30, 0.90, 1}` | `sealColorMARTYR` |
| Vengeance | `{1.00, 0.60, 0.10, 1}` | `sealColorVENGEANCE` |
| Corruption | `{0.85, 0.20, 0.60, 1}` | `sealColorCORRUPTION` |
| Justice | `{0.60, 0.60, 0.60, 1}` | `sealColorJUSTICE` |
| Wisdom | `{0.30, 0.50, 1.00, 1}` | `sealColorWISDOM` |
| Righteousness | `{1.00, 0.95, 0.70, 1}` | `sealColorRIGHTEOUSNESS` |
| Light | `{0.20, 0.80, 0.30, 1}` | `sealColorLIGHT` |
| Crusader | `{0.60, 0.80, 1.00, 1}` | `sealColorCRUSADER` |

## Judgement spells (Constants.lua:307-311)
```
ns.PALADIN_JUDGEMENT_SPELLS = { 20271, 20272, 34413, 54158 }
```
- `ns.PALADIN_JUDGEMENT_COOLDOWN = 10` (base seconds)

## Timing
- **Reseal timing**: `(swingElapsed + GCD) < swingDuration` → reseal marker visible
  - Uses `ns.GetGcdDuration()` = `1.5s`
  - GCD-aware: marker shows where to press the next seal after current swing lands
- **Twist window**: `0.4s + cachedLatency` from swing end
- Aura-driven seal detection: prefers `ns.GetPaladinSealFamilyByAuraName()` over `ns.GetPaladinSealFamilyBySpellId()`
- `ns.GetSpellInfo` wrapper for cross-version spell ID resolution
- Survives missing rank IDs via localized name fallback

## Visual layering (from bottom to top)
1. StatusBar fill (class color or manual, or per-seal color)
2. Red twist zone overlay (`SetDrawLayer("OVERLAY", 0)`)
3. Reseal line marker (`SetDrawLayer("OVERLAY", 0)`)
4. Judgement marker (`SetDrawLayer("OVERLAY", 0)`)
5. Shared spark (above everything)

## Config toggles (DB_DEFAULTS)
| Toggle | Default | Purpose |
|--------|---------|---------|
| `showPaladinSealColor` | `true` | Color MH bar by active seal |
| `showPaladinSealLabel` | `true` | Show seal name label on MH bar |
| `showPaladinJudgementMarker` | `true` | Show swing-end judgement marker |
| `showPaladinTwistFlash` | `true` | Flash twist zone when entering safe window |

---
**🔄 Sync hook:** If Paladin seal families, twist zone, judgement timing, or visual layering changes, update this file. Master protocol → `standards/code.md`
