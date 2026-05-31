# Druid — Class Reference (v0.0.9 streamlined)

> **⚠️ v0.0.9 streamlining:** Removed form colors/labels, Omen glow, Tiger's Fury badge,
> Faerie Fire badge, Power Shift bar, Energy Tick bar, Rage dim, and Ravage opener cue.
> These features were stripped because they weren't looking right and were better off without.
> Only Maul queue tint + form-reset timer handling remain active.

```
  DRUID FEATURE MAP (v0.0.9+)
  ┌────────────────────────────────────────────┐
  │  Maul queue tint           ACTIVE    ✅    │
  │  Form-reset timer delay    ACTIVE    ✅    │
  │  ├─ Form colors            STRIPPED  ❌    │
  │  ├─ Form labels            STRIPPED  ❌    │
  │  ├─ Ravage opener cue      DISABLED  ⛔    │
  │  ├─ Omen of Clarity glow   STRIPPED  ❌    │
  │  ├─ Rage dimming           STRIPPED  ❌    │
  │  ├─ Power Shift bar        STRIPPED  ❌    │
  │  ├─ Energy Tick bar        STRIPPED  ❌    │
  │  ├─ Tiger's Fury badge     STRIPPED  ❌    │
  │  ├─ Faerie Fire badge      STRIPPED  ❌    │
  │  ├─ Mangle timer           DISABLED  ⛔    │
  │  └─ Rip tracker            DISABLED  ⛔    │
  └────────────────────────────────────────────┘
```

## Form tracking (source: Constants.lua:487-499)

### Form IDs (ns.DRUID_FORM_IDS)
| Form | Spell ID | Constant key |
|------|----------|-------------|
| Cat Form | `768` | Cat |
| Bear Form | `5487` | Bear |
| Dire Bear Form | `9634` | DireBear |

### Form detection
- `GetShapeshiftForm()` returns form index (0 = caster, 1 = bear/dire bear, 2 = cat, 4 = moonkin)
- CLEU `SPELL_AURA_APPLIED` with spellId in `DRUID_FORM_IDS` → triggers MH swing reset
- `ns.druidFormChangeTime` stores the timestamp of last form change

### Form colors (legacy — DB keys still exist, handler stripped)
| Form index | Color | DB Key |
|------------|-------|--------|
| `0` (caster) | `nil` — uses default MH color | — |
| `1` (bear/dire bear) | `{0.80, 0.15, 0.10}` — red | `druidFormBear` |
| `2` (cat) | `{0.90, 0.70, 0.10}` — gold/orange | `druidFormCat` |
| `4` (moonkin) | `{0.30, 0.55, 0.90}` — blue | `druidFormMoonkin` |

### Form reset handling (State.lua:1088-1095)
```
CLEU SPELL_AURA_APPLIED with spellId in DRUID_FORM_IDS:
  ResetTimer("mh")
  druidFormChangeTime = eventTime
  OnDruidFormChange(spellId)
```
- Form change hard-resets the MH swing timer (new form = new swing cadence)
- Applies `DRUID_FORM_CHANGE_DELAY_BONUS` to prevent timer skating

## Maul (bear) — source: Constants.lua:423-427
| Property | Value |
|----------|-------|
| Spell IDs | `6807, 6808, 6809, 8972, 9745, 9880, 9881, 26996, 48479, 48480` |
| Tint | Bear-yellow on MH fill (`DRUID_MAUL_TINT = {r=1.0, g=0.78, b=0.10}` — distinct from Warrior yellow) |
| State | `ns.druidQueuedMeleeSpell` (class-local) |
- Landed-hit reset via `IsQueuedMeleeHitForPlayerClass()` in CLEU `SPELL_DAMAGE`/`SPELL_MISSED`
- Interrupted/failed Maul restores via `ns.ClearDruidQueueTint()` (druid-specific, not warrior's)
- Queue detection: `IsCurrentSpell(maulName)` via `ns.RegisterSpellcastSucceededHook`

## Config toggles (DB_DEFAULTS — many legacy)
| Toggle | Default | Status |
|--------|---------|--------|
| `showDruidFormColors` | `true` | **Legacy** — handler stripped v0.0.9 |
| `showDruidRavageCue` | `true` | **Legacy** — `ns.UpdateDruidRavageCue = nil` |
| `showDruidPowerShiftBar` | `true` | **Legacy** — handler stripped v0.0.9 |
| `showDruidEnergyTickBar` | `true` | **Legacy** — handler stripped v0.0.9 |
| `showDruidOmenGlow` | `true` | **Legacy** — handler stripped v0.0.9 |
| `showDruidRageDim` | `true` | **Legacy** — handler stripped v0.0.9 |
| `showDruidTigerFuryBadge` | `true` | **Legacy** — handler stripped v0.0.9 |
| `showDruidFaerieFireBadge` | `true` | **Legacy** — handler stripped v0.0.9 |
| `showDruidMangleTimer` | `true` | **Legacy** — `ns.UpdateDruidMangleTimer = nil` |
| `showDruidRipTracker` | `true` | **Legacy** — `ns.UpdateDruidRipTracker = nil` |

## Key spell IDs
| Spell | ID | Constant |
|-------|----|----------|
| Tiger's Fury | `5217` | `ns.DRUID_TIGER_FURY_ID` |
| Ravage | `6785` | `ns.RAVAGE_ID` |

## Timing constants (source: source code)
| Constant | Value | Notes |
|----------|-------|-------|
| `GCD_DURATION` | `1.5` | Global cooldown (State.lua:824) |
| `SPEED_CHECK_INTERVAL` | `0.10` | Melee speed resync throttle (State.lua:537) |
| Swing flash | `0.08s` | Bar flash on landing (State.lua:41) |
| Swing start fallback | `2.0` | Generic placeholder when no weapon speed known (State.lua:621) |

---
**🔄 Sync hook:** If Druid form tracking, Maul queue tint, or form-reset handling changes, update this file. Master protocol → `standards/code.md`
