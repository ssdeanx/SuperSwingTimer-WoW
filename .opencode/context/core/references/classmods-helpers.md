# ClassMods Helper Registry

Source: `SuperSwingTimer_ClassMods.lua` (3132 lines)

Dispatch: `ns.InitClassMods()` at line 3494 — clears all callbacks, then calls Setup* based on `ns.playerClass`.

## Shared utilities (lines 1–159)

| Function | Purpose |
|----------|---------|
| `GetCurrentTime()` | `ns.GetAlignedTime()` → `GetTimePreciseSec()` → `GetTime()` |
| `GetOverlayParent(bar)` | `ns.GetOverlayFrame(bar)` → `bar` (fallback) |
| `GetHelpfulAuraData(unit, index)` | Classic-safe `UnitBuff`/`UnitAura` read, handles two parameter shapes |
| `EnsureVerticalHelperBar(name, anchor, width, texture)` | Creates vertical statusbar with border textures, background, shared styling |

### Constants
- `GCD_SPELL_ID = 61304`
- `WARRIOR_HEROIC_STRIKE_TINT = { r=1.0, g=0.92, b=0.20 }`
- `WARRIOR_CLEAVE_TINT = { r=0.20, g=0.80, b=0.25 }`
- `DRUID_MAUL_TINT = { r=1.0, g=0.78, b=0.10 }`
- `HUNTER_RAPTOR_TINT = { r=1.0, g=0.92, b=0.20 }`
- `DRUID_POWER_SHIFT_DURATION = 1.5` (ClassMods.lua:1930)
- `DRUID_ENERGY_TICK_DURATION = 2.0` (ClassMods.lua:1934)

## SetupRetPaladin() (lines 166–623)

### Callbacks registered on `ns`
| Callback | Implementation |
|----------|---------------|
| `ns.UpdatePaladinSealVisual` | `UpdateSealColorAndLabel()` |
| `ns.OnMeleeSwing` | Runs `UpdateSealBreakpointLine()` |
| `ns.OnBarsCreated` | Creates `sealTwistBreakpoint` texture, `sealTwistResealBreakpoint` texture, `paladinJudgementMarker` texture. All use `SetDrawLayer("OVERLAY", 0)` directly (not `SetTextureLayerAboveBar`). |

### Helpers

| Helper | Frame | Description |
|--------|-------|-------------|
| Seal twist zone | `ns.sealTwistBreakpoint` | Red proportional fill on MH right edge |
| Reseal marker | `ns.sealTwistResealBreakpoint` | 3px thin line, GCD-aware |
| Judgement marker | `ns.paladinJudgementMarker` | Gold marker when Judgement CD is available |
| Reckoning badge | `ns.mhBar.reckoningText` | "R1–R4" text right of MH bar |
| Libram swap badge | `ns.mhBar.paladinLibramText` | "Swap!" for 1.5s after libram item swap |

### Timing constants
- `PALADIN_TWIST_WINDOW = 0.4` seconds before swing landing
- Actual twist window = `PALADIN_TWIST_WINDOW + cachedLatency`
- `PALADIN_LIBRAM_SWAP_DURATION = 1.5` seconds
- Twist zone: `zoneWidth = min(max((twistWindow/duration)*barWidth, 1), barWidth*0.5)`
- Reseal tick: `(swingElapsed + gcdRemaining) / duration` modulo 1

### Key functions
| Function | Description |
|----------|-------------|
| `GetActivePaladinSeal()` | Scans player auras for seal family via `GetHelpfulAuraData`, returns `familyKey, auraSpellId, auraName` |
| `GetPerSealColor(familyKey)` | Reads `colors.sealColor<FamilyKey>` from DB, falls back to `ns.PALADIN_SEAL_COLORS` |
| `GetReckoningStackCount()` | Reads Reckoning buff (Spell ID 20178) stack count |
| `UpdateReckoningBadge()` | Shows/hides "R1–R4" text |
| `UpdatePaladinLibramSwapBadge()` | Shows "Swap!" text for 1.5s after relic slot swap |
| `UpdateJudgementMarker()` | Positions marker based on Judgement cooldown progress |
| `UpdateSealColorAndLabel()` | Applies per-seal color to MH bar + optional seal name label |
| `UpdateSealBreakpointLine()` | Positional update for twist zone + reseal line |

## SetupWarrior() (lines 625–1222)

### Callbacks registered on `ns`
| Callback | Implementation |
|----------|---------------|
| `ns.OnMeleeSwing` | Runs queue tint + Shield Block bar update |
| `ns.UpdateWarriorQueueTint` | Sets `WARRIOR_HEROIC_STRIKE_TINT` or `WARRIOR_CLEAVE_TINT` on MH bar |
| `ns.ClearWarriorQueueTint` | Clears queue color from MH bar |
| `ns.UpdateWarriorRageBar` | Updates rage bar value + color |
| `ns.UpdateWarriorShieldBlockBar` | Updates Shield Block duration bar |

### Helpers

| Helper | Frame | Description |
|--------|-------|-------------|
| Rage bar | `ns.warriorRageBar` | Slim horizontal bar below MH/OH, color from `colors.warriorRageBarColor` |
| Shield Block bar | `ns.warriorShieldBlockBar` | Slim bar above MH stack when Shield Block buff active |
| Flurry counter | (text on MH bar) | "⚡1–3" showing remaining Flurry charges |
| Execute badge | (text on rage bar) | "EXEC" label when target HP < 20% |
| Enrage badge | (text) | Shows during Enrage buff |

### Key functions
| Function | Description |
|----------|-------------|
| `GetWarriorRageBarColor()` | Reads DB color, defaults to `{0.80,0.20,0.10,0.85}` |
| Flurry charge read | Reads Flurry buff (Spell ID 12319/12321/12972) via `GetHelpfulAuraData` |
| Shield Block detection | Reads `UnitBuff("player", "Shield Block")` + Spell IDs for ranks |
| Rage bar update | Reads `UnitPower("player", 1)` — rage 0–100 |
| Enrage detection | Reads Enrage (Spell ID 12317/13020/13021) buff duration |

### Timing
- Flurry: 3 charges, each swing consumes 1, charge counter decrements on swing
- Shield Block: 10s duration, 10s base CD (+ Shield Mastery talent reduction)

## SetupEnhShaman() (lines 1223–1612)

### Callbacks registered on `ns`
| Callback | Implementation |
|----------|---------------|
| `ns.OnMeleeSwing` | Runs `UpdateWeaveVisuals()`, Windfury ICD, Flurry badge |
| `ns.OnBarsCreated` | Creates weave spark + triangle marker frames |

### Helpers

| Helper | Frame | Description |
|--------|-------|-------------|
| Weave spark | `ns.weaveSpark` | Cast progress spark on MH bar |
| Weave triangle top | `ns.weaveTriangleTop` | Spell icon above MH bar at breakpoint |
| Weave triangle bottom | `ns.weaveTriangleBottom` | Spell icon below MH bar at breakpoint |
| Windfury ICD tracker | `ns.windfuryIcdBar` | 3px vertical bar right side of MH: green/ready → orange/winding → red/recharging |
| Flurry stack badge | (text on MH bar) | Shows remaining Flurry charges |

### Key functions
| Function | Description |
|----------|-------------|
| `UpdateWeaveVisuals()` | Positional update for weave spark + markers |
| `ApplyWeaveMarkerTexture()` | Sets texture, size, alpha, blend mode for marker |
| Windfury ICD | 3s ICD tracked from WF proc events |
| `GetWeaveDisplayInfo()` (in Weaving.lua) | Returns cast info for active weave spell |

### Timing
- Breakpoint: `castWindow = castTime + cachedLatency`
- Marker position: `((timer.duration - castWindow) / timer.duration) * barWidth`
- Windfury ICD: 3 seconds

## SetupDruid() (lines 1613–2240)

### Callbacks registered on `ns`
| Callback | Implementation |
|----------|---------------|
| `ns.OnMeleeSwing` | Clears queue tint, updates form color |
| `ns.OnDruidFormChange` | Re-applies form-specific color to MH bar, resets power shift + energy tick timers |
| `ns.OnBarsCreated` | Creates Ravage cue overlay |
| `ns.UpdateDruidQueueTint` | Sets `DRUID_MAUL_TINT` on MH bar |
| `ns.ClearDruidQueueTint` | Clears Maul tint |
| `ns.UpdateDruidRavageCue` | Shows amber glow when Ravage usable |
| `ns.UpdateDruidFormColors` | Re-applies form tint to MH bar |
| `ns.UpdateDruidOmenGlow` | Green flash on Omen of Clarity proc |
| `ns.UpdateDruidTigerFuryBadge` | Shows Tiger's Fury uptime badge |
| `ns.UpdateDruidPowerShiftBar` | Updates Power Shift duration bar under MH |
| `ns.UpdateDruidEnergyTickVisual` | Updates energy tick progress left of MH |
| `ns.UpdateDruidFaerieFireBadge` | Shows Faerie Fire debuff badge on target |

### Helpers

| Helper | Frame | Description |
|--------|-------|-------------|
| Form color | `ns.mhBar` | Direct color override per form (Bear=red, Cat=gold, Moonkin=blue) |
| Form label | `ns.mhBar` | "Bear", "Cat", "Moonkin" text |
| Maul queue tint | `ns.mhBar` | Amber tint when Maul queued |
| Ravage cue | `ns.druidRavageCue` | Amber glow overlay when Ravage usable in Cat Form |
| Omen glow | `ns.mhBar` | Green flash when Omen of Clarity procs |
| Rage dim | `ns.mhBar` | 40% alpha in Bear form when < 15 rage |
| Power Shift bar | `druidPowerShiftBar` (local) | Duration bar under MH: 1.5s fill, shows "PS X.Xs" label |
| Energy tick bar | `druidEnergyTickBar` (local) | Vertical bar left of MH: 2s energy tick cadence with countdown text |
| Tiger's Fury badge | (text on MH bar) | Shows TF remaining duration |
| Faerie Fire badge | (text on MH bar) | Shows FF debuff active on target |

### Key functions
| Function | Description |
|----------|-------------|
| `UpdateFormColor()` | Sets MH bar color based on `GetShapeshiftForm()`: 1=Bear, 3=Cat, 4=Moonkin |
| `UpdateFormLabel()` | Shows form name text on MH bar |
| `UpdateRavageCue()` | Checks Cat Form + behind target + energy ≥ Ravage cost + Ravage usable |
| `MaulQueued` state | `ns.druidQueuedMeleeSpell` tracks if Maul is queued |
| Omen proc | Flash MH bar green for Omen of Clarity (Spell ID 16864) proc |
| Rage dim | Below 15 rage in Bear form → set MH bar alpha to 0.4 |
| `UpdateDruidPowerShiftBar()` | 1.5s fill bar under MH, tracks `ns.druidPowerShiftStartTime` |
| `EnsureDruidEnergyTickBar()` | Creates 4px-wide vertical bar left of MH with countdown text |
| `UpdateDruidEnergyTickVisual()` | 2s energy tick cadence, resets on `ns.druidEnergyTickStartTime` |

### Druid state variables
- `ns.druidPowerShiftStartTime` — start time of current Power Shift window
- `ns.druidEnergyTickStartTime` — start time of current energy tick window

### Timing
- Power Shift window: 1.5s (DRUID_POWER_SHIFT_DURATION)
- Energy tick cadence: 2.0s (DRUID_ENERGY_TICK_DURATION)

### Form IDs
- Bear = 768 (GetShapeshiftForm returns 1)
- Cat = 5487 (GetShapeshiftForm returns 3)
- Moonkin = 24858 (GetShapeshiftForm returns 4)

### Form colors
- Bear: `colors.druidFormBear` → `{0.80,0.15,0.10,1.0}`
- Cat: `colors.druidFormCat` → `{0.90,0.70,0.10,1.0}`
- Moonkin: `colors.druidFormMoonkin` → `{0.30,0.55,0.90,1.0}`

## SetupHunter() (lines 2223–2658)

### Callbacks registered on `ns`
| Callback | Implementation |
|----------|---------------|
| `ns.OnMeleeSwing` | Handles MH swing start, Raptor queue tint |
| `ns.OnRangedSwing` | Handles ranged swing start |
| `ns.OnBarsCreated` | Creates range helper bar, rapid fire bar |
| `ns.UpdateHunterQueueTint` | Sets `HUNTER_RAPTOR_TINT` on MH bar |
| `ns.ClearHunterQueueTint` | Clears Raptor tint |
| `ns.UpdateHunterRangeHelperColor` | Updates range helper color based on target distance |
| `ns.UpdateHunterRangeHelperVisual` | Shows/hides/updates range helper |

### Helpers

| Helper | Frame | Description |
|--------|-------|-------------|
| Range helper bar | `ns.hunterRangeHelperBar` | Vertical 4-state bar: green(melee)/yellow(sweet)/blue(ranged)/red(OOR) |
| Rapid Fire bar | `ns.hunterRapidFireBar` | Thin 4px bar below ranged: shows RF cooldown + duration |
| Raptor queue tint | `ns.mhBar` | Yellow tint when Raptor Strike queued |
| Cast bar tint | `ns.hunterCastBar` | Safe/unsafe color based on movement status + clip math |
| Latency slice | `ns.hunterCastBar` | Trailing opacity slice for cached latency |

### Key functions
| Function | Description |
|----------|-------------|
| `UpdateRangeHelper()` | Reads `IsSpellInRange("Auto Shot")`, `CheckInteractDistance`, sets 1 of 4 colors |
| `UpdateRapidFireBar()` | Reads RF cooldown `GetSpellCooldown(3045)` + buff duration |
| `AutoShotSafe()` / `AutoShotUnsafe()` | Color apply based on movement stop timestamp + breakpoint |
| `TrapLauncher` state | `tr .TrapLauncherToggleTracker` — tracks trap launcher state |
| Feign Death handling | `ns.hunterFeigningDeath` — blocks ranged updates during FD |

### Timing
- Auto Shot breakpoint: `ns.CAST_WINDOW (0.5) + cachedLatency`
- Steady Shot: 1.5s cast, 0.5s grace period
- Rapid Fire: 15s buff duration, 40s (5m with talents) CD
- Range helper refreshes on `UNIT_RANGEDDAMAGE`, `PLAYER_STOPPED_MOVING`, `PLAYER_STARTED_MOVING`

## SetupRogue() (lines 2659–3476)

### Callbacks registered on `ns`
| Callback | Implementation |
|----------|---------------|
| `ns.OnMeleeSwing` | Runs SS cue, energy tick sync |
| `ns.OnBarsCreated` | Creates SS zone, energy tick bar, combo point strip, SnD bar, AR bar |
| `ns.UpdateRogueSinisterAssistColor` | Updates SS zone color from DB |
| `ns.UpdateRogueSinisterAssistVisual` | Shows/hides SS zone |
| `ns.UpdateRogueEnergyTickColor` | Updates energy tick color |
| `ns.UpdateRogueEnergyTickVisual` | Shows/hides energy tick bar |
| `ns.UpdateRogueComboPointColor` | Updates CP bar color |
| `ns.UpdateRogueComboPointVisual` | Shows/hides CP strip |
| `ns.UpdateRogueSliceAndDiceColor` | Updates SnD color |
| `ns.UpdateRogueSliceAndDiceVisual` | Shows/hides SnD bar |
| `ns.HandleRogueComboPointsChanged` | Refreshes CP display on `UNIT_COMBO_POINTS` |
| `ns.HandleRogueEnergyPowerUpdate` | Refreshes energy tick on `UNIT_POWER_UPDATE` |
| `ns.HandleRogueSliceAndDiceAura` | Refreshes SnD on `UNIT_AURA` |

### Helpers

| Helper | Frame | Description |
|--------|-------|-------------|
| SS cue zone | `ns.rogueSinisterAssistZone` | Red tail overlay on MH bar (right-end window) |
| Energy tick bar | `ns.rogueEnergyTickBar` | 4px vertical bar left of MH, fills on 2s energy tick cadence |
| Energy total bar | `ns.rogueEnergyTotalBar` | Right-side battery bar showing remaining energy |
| Combo point strip | `ns.rogueComboPointContainer` | 5-box strip above MH, driven by `GetComboPoints("player","target")` |
| Slice and Dice bar | `ns.rogueSliceAndDiceBar` | Slim bar above MH, tracks SnD buff via `GetHelpfulAuraData` |
| Adrenaline Rush bar | `ns.rogueAdrenalineRushBar` | Thin 3px bar below MH, tracks AR cooldown + duration |
| Blade Flurry badge | (text on MH bar) | Shows BF active |
| Cold Blood badge | (text on MH bar) | Shows CB active |

### Key functions
| Function | Description |
|----------|-------------|
| `UpdateSSAssist()` | Red zone width: `(0.4 + cachedLatency) / duration * barWidth` right-anchored |
| `UpdateEnergyTick()` | 2s tick cadence, fills bar from 0→1 over 2s, resets on likely energy gain |
| `UpdateComboPoints()` | Reads `GetComboPoints()`, fills N of 5 boxes with `colors.rogueComboPoints` |
| `UpdateSliceAndDice()` | Reads SnD buff via `GetHelpfulAuraData`, tracks `rogueSliceAndDiceDuration + expirationTime` |
| `UpdateAdrenalineRush()` | Reads AR cooldown `GetSpellCooldown(13750)` |

### Timing
- SS cue window: `0.4 + cachedLatency` seconds before swing landing
- Energy tick: every 2.0 seconds (20 energy per tick)
- SnD: 30s base, each CP adds ~6s, max ~66s (5 CP + 3s glyph)
- AR: 15s duration, 3m (180s) cooldown
- CP: max 5 points, per `GetComboPoints("player", "target")`

## State variables tracked per class

| Variable | Type | Class | Description |
|----------|------|-------|-------------|
| `ns.warriorQueuedMeleeSpell` | spell ID or nil | Warrior | Currently queued HS/Cleave |
| `ns.druidQueuedMeleeSpell` | spell ID or nil | Druid | Currently queued Maul |
| `ns.hunterQueuedMeleeSpell` | spell ID or nil | Hunter | Currently queued Raptor Strike |
| `ns.rogueLastEnergy` | number | Rogue | Last known energy value for tick detection |
| `ns.rogueEnergyTickStartTime` | number | Rogue | Time of last energy tick reset |
| `ns.rogueComboPointCount` | number | Rogue | Current CP on target |
| `ns.rogueSliceAndDiceDuration` | number | Rogue | SnD duration seconds |
| `ns.rogueSliceAndDiceExpirationTime` | number | Rogue | SnD buff end time |
| `ns.rogueSliceAndDiceNextRefreshAt` | number | Rogue | Throttle for next aura recheck |
| `ns.paladinLibramLastItemId` | item ID | Paladin | Last libram in relic slot |
| `ns.paladinLibramSwapStartTime` | number | Paladin | Time of last libram swap |
| `ns.hunterFeigningDeath` | boolean | Hunter | FD state flag |
| `ns.druidPowerShiftStartTime` | number | Druid | Start time of Power Shift window |
| `ns.druidEnergyTickStartTime` | number | Druid | Start time of energy tick window |

## Event hooks registered by ClassMods
Dispatched from main event handler in `SuperSwingTimer.lua`:
- `UNIT_COMBO_POINTS` → `ns.HandleRogueComboPointsChanged`
- `UNIT_POWER_UPDATE` → `ns.HandleRogueEnergyPowerUpdate` (if mana/energy)
- `UNIT_AURA` → `ns.HandleRogueSliceAndDiceAura`
- `UPDATE_SHAPESHIFT_FORM` → `ns.OnDruidFormChange`
- `PLAYER_TARGET_CHANGED` → (re-evaluates Ravage cue, SS cue)
- `UNIT_SPELLCAST_START/SUCCEEDED/DELAYED/FAILED` → (cast detection per class)

## OnUpdate class hooks
Last section of ClassMods.lua (line 3477+) registers class-specific `OnUpdate` handlers that run every frame:
- Paladin: seal breakpoint line + judgement marker position
- Warrior: rage bar updater (throttled)
- Shaman: weave visual updater
- Druid: form color + ravage cue
- Hunter: range helper refresh
- Rogue: energy tick + SnD + SS cue + CP strip

---
**🔄 Sync hook:** If ClassMods helper frames, callbacks, timing constants, or per-class Setup functions change, update this file. Master protocol → `standards/code.md`
