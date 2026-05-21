# Rogue — Class Reference

## Timing constants (source: source code)

| Constant | Value | Notes |
|----------|-------|-------|
| `GCD_DURATION` | `1.5` | Global cooldown (State.lua:824) |
| `ns.cachedLatency` | `GetNetStats()` world/home /1000 | Applied to SS cue window only |
| `CAST_WINDOW` | `0.5` | Shared constant used as SS cue window base |
| Energy tick cadence | `2.0s` | Classic/TBC energy regen tick |
| Swing flash | `0.08s` | Bar flash on landing (State.lua:41) |

## Bar heights/widths (source: Constants.lua, SuperSwingTimer.lua:800-810)
```
OH height:                     math.max(6, mhHeight - 7)                         // 8px from 15px MH
SnD height:                    math.max(3, math.min(4, floor(mhHeight * 0.3)))   // 3-4px
Combo point height:            math.max(2, math.min(4, floor(mhHeight * 0.27)))  // 2-4px
Energy tick width:             ns.ROGUE_ENERGY_TICK_BAR_WIDTH                    // DB `rogueEnergyTickBarWidth` (4), slider 2-20
SnD bar height:                ns.ROGUE_SLICE_AND_DICE_BAR_HEIGHT                // DB `rogueSliceAndDiceBarHeight` (4), slider 2-10
Adrenaline Rush bar height:    ns.ROGUE_ADRENALINE_RUSH_BAR_HEIGHT               // DB `rogueAdrenalineRushBarHeight` (4), slider 2-20
```

## Sinister Strike cue
### Window math (UI.lua)
```
GetRangedCastWindow() = CAST_WINDOW + cachedLatency  // 0.5 + latency
```
- Latency-adjusted red end-window overlay on MH bar
- Marks optimal press window relative to swing landing
- Cue window = `CAST_WINDOW + cachedLatency` seconds from the end of the MH swing
- Falls back to MH weapon speed when MH bar not active (opener)
- Under the shared spark layer (spark stays readable)
- Default alpha: `{r=1, g=0, b=0, a=0.35}` (`colors.rogueSinister` in DB_DEFAULTS)
- Updated from configured swatch (Quick Controls color picker)

## Energy helper
- One slim 4px vertical bar to the left of the MH bar (NOT paired — the right-side battery bar was removed)
- Fills on the Classic/TBC 2-second energy-tick cadence
- Re-syncs from likely natural energy gains
- Color: `colors.rogueEnergyTick` → `{r=1.0, g=0.82, b=0.18, a=1}` (yellow-gold)
- Controlled by `showRogueEnergyTick` toggle
- Optional countdown text: `showRogueEnergyCountdown` → shows seconds until next tick (State.lua:3060 area)

## Combo points
- 5-box strip directly above MH bar (5 boxes max)
- Driven by `GetComboPoints("player", "target")`
- Refreshed on `UNIT_COMBO_POINTS` + `PLAYER_TARGET_CHANGED`
- Sized to full MH width, `math.max(2, math.min(4, floor(mhHeight * 0.27)))`-tall boxes
- Color: `colors.rogueComboPoints` → `{r=1.0, g=0.18, b=0.12, a=0.95}` (red)
- Dedicated Quick Controls toggle + color swatch
- Note: combo point strip was removed in v0.0.5 cleanup, restored under separate toggle

## Slice and Dice
| Property | Value |
|----------|-------|
| Spell ID | `5171` (`ns.ROGUE_SLICE_AND_DICE_ID`) |
| Bar height | `math.max(3, math.min(4, floor(mhHeight * 0.3)))` (3-4px) |
| Anchored | Directly above MH bar (above combo point strip if visible) |
| Color | `colors.rogueSliceAndDice` → `{r=0.95, g=0.82, b=0.22, a=0.95}` (gold) |
| Toggle | `showRogueSliceAndDice` |
- Reads player buff via `UnitBuff`/`UnitAura` — Classic-safe signature-tolerant helper (`ns.GetSpellInfo` wrapper)
- Refreshed on a short throttle (not every frame)
- Shared bar width/texture/background/border styling
- Hides with MH bar

## Key spell IDs
| Spell | ID | Constant |
|-------|----|----------|
| Adrenaline Rush | `13750` | `ns.ROGUE_ADRENALINE_RUSH_ID` |
| Slice and Dice | `5171` | `ns.ROGUE_SLICE_AND_DICE_ID` |

## Extra helpers (ClassMods)
- **Adrenaline Rush bar**: Duration/cooldown helper, toggled by `showRogueAdrenalineRushBar`
- **Blade Flurry badge**: Visual indicator during BF uptime
- **Cold Blood badge**: Badge shown when Cold Blood is active
- **Energy cap warning tint**: Bar tints when energy is near/draining

## Visibility rules
- All Rogue bars are combat-only (shared `ApplyVisibility()` path)
- SS cue, SnD bar, energy tick all hide when MH bar hides
- Energy countdown text on energy-tick bar (optional via `showRogueEnergyCountdown`)

---
**🔄 Sync hook:** If Rogue helper cue math, energy cadence, SnD, or combo point behavior changes, update this file. Master protocol → `standards/code.md`
