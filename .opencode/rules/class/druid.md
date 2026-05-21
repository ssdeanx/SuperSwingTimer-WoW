# Druid — Class Reference

## Timing constants (source: source code)

| Constant | Value | Notes |
|----------|-------|-------|
| `GCD_DURATION` | `1.5` | Global cooldown (State.lua:824) |
| `SPEED_CHECK_INTERVAL` | `0.10` | Melee speed resync throttle (State.lua:537) |
| `ns.cachedLatency` | `GetNetStats()` world/home /1000 | Applied to Ravage cue reactivity |
| Swing flash | `0.08s` | Bar flash on landing (State.lua:41) |
| Swing start fallback | `2.0` | Generic placeholder when no weapon speed known (State.lua:621) |

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

### Form colors (source: Constants.lua:494-499, DB_DEFAULTS:651-653)
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
- Druid power shifts also tracked via `ns.druidPowerShiftStartTime`

## Maul (bear) — source: Constants.lua:423-427
| Property | Value |
|----------|-------|
| Spell IDs | `6807, 6808, 6809, 8972, 9745, 9880, 9881, 26996, 48479, 48480` |
| Tint | Bear-yellow on MH fill (`{r=0.90, g=0.70, b=0.10}` — distinct from Warrior yellow) |
| State | `ns.druidQueuedMeleeSpell` (class-local, like Warrior HS/Cleave) |
- Landed-hit reset via `IsQueuedMeleeHitForPlayerClass()` in CLEU `SPELL_DAMAGE`/`SPELL_MISSED`
- Interrupted/failed Maul restores queued state through `ns.ClearDruidQueueTint()` (druid-specific cleanup path, not warrior's)
- Name-based lookups built from ID table via `addSpellNamesToLookup()`

## Ravage (cat opener) — source: Constants.lua:111-112
| Property | Value |
|----------|-------|
| Spell ID | `6785` (`ns.RAVAGE_ID`) |
| Cue color | `{r=1.00, g=0.72, b=0.16, a=0.28}` amber — `colors.ravageCue` |
| Toggle | `showDruidRavageCue` (default `true`) |

### Opener cue logic (ClassMods)
- Only glows when **all** conditions met:
  1. Player is in Cat Form (`GetShapeshiftForm() == 2`)
  2. Valid hostile target selected (`UnitCanAttack("player", "target")`)
  3. Behind the target (positional check)
  4. Enough energy for Ravage (60 energy)
  5. Ravage is actually learnable/known by the player
- Driven by `GetComboPoints`, target state, player form
- Wired through SavedVariables defaults + config toggle
- Event refresh hooks for form/target changes (`UPDATE_SHAPESHIFT_FORM`, `PLAYER_TARGET_CHANGED`)
- UI update path via `PostBarUpdate`

## Key spell IDs
| Spell | ID | Constant |
|-------|----|----------|
| Tiger's Fury | `5217` | `ns.DRUID_TIGER_FURY_ID` |
| Ravage | `6785` | `ns.RAVAGE_ID` |

## Extra helpers (ClassMods)
- **Omen of Clarity glow**: `showDruidOmenGlow` toggle → glows MH bar when OoC proc is active
  - Default color: `colors.omenGlow = {r=0.20, g=1.0, b=0.30, a=0.80}` (green)
- **Rage dimming**: `showDruidRageDim` toggle → dims bar when rage is low (bear form utility)
- **Power Shift bar**: `showDruidPowerShiftBar` toggle → fills a 1.5s duration bar under MH (default `DRUID_POWER_SHIFT_DURATION`)
  - Height: `druidPowerShiftBarHeight` (default 4, slider 2–20)
  - State: `ns.druidPowerShiftStartTime` tracks the start time
- **Energy Tick bar**: `showDruidEnergyTickBar` toggle → fills a 2.0s energy pulse bar left of MH (default `DRUID_ENERGY_TICK_DURATION`)
  - Width: `druidEnergyTickBarWidth` (default 4, slider 2–20)
  - State: `ns.druidEnergyTickStartTime` tracks the tick cadence
  - Shows countdown text (`"X.Xs"`)
- **Tiger's Fury badge**: Updates TF remaining duration on MH bar text
- **Faerie Fire badge**: Shows FF debuff active on current target

## Config toggles (DB_DEFAULTS)
| Toggle | Default | Purpose |
|--------|---------|---------|
| `showDruidFormColors` | `true` | Color MH bar by active form |
| `showDruidRavageCue` | `true` | Show Ravage opener cue |
| `showDruidPowerShiftBar` | `true` | Show Power Shift duration bar under MH |
| `showDruidEnergyTickBar` | `true` | Show energy tick bar left of MH |
| `showDruidOmenGlow` | `true` | Omen of Clarity proc glow |
| `showDruidRageDim` | `true` | Dim bar on low rage (bear) |

---
**🔄 Sync hook:** If Druid form tracking, Maul, Ravage cue, or Omen Clarity behavior changes, update this file. Master protocol → `standards/code.md`
