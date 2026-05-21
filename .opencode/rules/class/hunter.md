# Hunter — Class Reference

## Timing constants (source: SuperSwingTimer_Constants.lua)

| Constant | Value | Notes |
|----------|-------|-------|
| `ns.CAST_WINDOW` | `0.5` | Shared hidden hunter/ranged cast window in TBC |
| `ns.STEADY_SHOT_CAST_TIME` | `1.5` | TBC Steady Shot — **haste-immune** |
| `ns.STEADY_SHOT_GRACE` | `0.5` | Auto Shot fires during last 0.5s of SS without clipping |
| `GetRangedCastWindow()` | `CAST_WINDOW + cachedLatency` | Latency-adjusted cast window |
| `ns.cachedLatency` | `GetNetStats()` world/ home /1000 | Refreshed every 0.05s during casts |
| `LATENCY_REFRESH_INTERVAL` | `0.05` (from `SuperSwingTimer.lua:22`) | Refresh throttle, wired into `HandleSpellcastDelayed` |
| `SPEED_CHECK_INTERVAL` | `0.10` (from `State.lua:537`) | Melee/ranged speed resync throttle |
| `RANGED_START_DEDUPE_WINDOW` | `0.25` (from `State.lua:26`) | Dedupe window = `max(0.25, cachedLatency + 0.05)` |
| `HUNTER_CAST_BAR_HEIGHT` | `10` | Height of dedicated hunter cast bar |
| `HUNTER_CAST_BAR_GAP` | `2` | Gap between ranged bar and hunter cast bar |
| `HUNTER_RANGE_HELPER_WIDTH` | `7` | Width of the orange helper bar segment |

## Auto Shot timing
| Source | Details |
|--------|---------|
| Spell ID | `75` (`ns.AUTO_SHOT_ID`) |
| Cooldown API | `GetSpellCooldown(75)` / `GetSpellCooldown("Auto Shot")` as active cooldown source |
| Speed fallback | `UnitRangedDamage("player")` for ranged speed |
| Haste fallback | `EstimateSpeedFromHaste()` when both cooldown and ranged damage are unavailable |
| Reactive trigger | `SPELL_UPDATE_COOLDOWN` |
| Mount handling | Not auto-repeating while mounted — ignore cooldown re-anchors; `IsMounted()` check |
| Auto-repeat check | `C_Spell.IsAutoRepeatSpell()` with `pcall` fallback to `ns.hunterAutoRepeatActive` |
| Feign Death | ID `5384` — resets ranged timer, clears auto-repeat state |
| Readiness | ID `23989` — triggers `ForceHunterRapidFireRefresh` on `SPELLCAST_SUCCEEDED` |

## Steady Shot (TBC)
- **Spell ID**: `34120`
- **Cast time**: 1.5s fixed (haste-immune in TBC)
- **Grace period**: 0.5s — Auto Shot fires during last 0.5s of Steady Shot without clipping
- Safe/unsafe clip-safety tint on cast bar: green (safe), red (unsafe)
- `ns.IsHunterActualCastSpell(34120)` lookup via `HUNTER_ACTUAL_CAST_SPELLS` table
- `UnitCastingInfo("player")` resolved through `ns.GetUnitCastingSpellInfo()` — Classic-safe spell-name-first path

## Cast bar
- **Height**: 10px (`ns.HUNTER_CAST_BAR_HEIGHT`)
- Anchored 2px below ranged timer (`ns.HUNTER_CAST_BAR_GAP`)
- Tied to ranged texture/spark/visibility rules
- Shows real Steady Shot/Aimed Shot cast progress + hidden Auto Shot window
- `ns.CAST_WINDOW = 0.5` for hidden window duration
- Latency slice shaded at end of cast for no-clip timing — width = `cachedLatency / duration * barWidth`
- Bar alpha = 0 when no cast active; `ClearHunterCastState()` hides it

## Other shots
| Shot | Type | Cast Time | CD | Notes |
|------|------|-----------|----|-------|
| Multi-Shot | Instant | 0 | 6s | Hidden ~0.5s shot window; ranks 1-6 (IDs 2643, 14288, 14289, 14290, 25294, 27021) |
| Aimed Shot | Cast | varies by rank | — | Ranks 1-7 (IDs 19434, 20900-20904, 27065) |
| Raptor Strike | Next-attack queue | — | — | Queued MH, yellow tint; IDs 2973, 14260-14266, 27014 |

## Spell ID tables (source: Constants.lua)
- `HUNTER_CAST_SPELLS` — All 19 spell IDs (Auto Shot + Multi-Shot + Steady Shot + Aimed Shot + Volley)
- `HUNTER_ACTUAL_CAST_SPELLS` — Only Steady Shot + Aimed Shot ranks (8 IDs)
- `HUNTER_CAST_SPELL_NAMES` / `HUNTER_ACTUAL_CAST_SPELL_NAMES` — Name-based lookups built from ID tables
- Volley name added to both name tables (`ns.HUNTER_CAST_SPELL_NAMES["Volley"] = true`)
- Helper functions: `ns.IsHunterCastSpell()`, `ns.IsHunterActualCastSpell()`, `ns.IsAutoShotSpell()`, `ns.IsMultiShotSpell()`

## State flags
- `rangedState` tracks auto-repeat active/inactive via `ns.hunterAutoRepeatActive`
- `hunterCastState` (`ns.hunterCastActive`, `ns.hunterCastSpellId`, `ns.hunterCastStartTime`, `ns.hunterCastDuration`)
- `hunterCastBar` frame with `.latencyOverlay` and `.latencyMarker` children
- `lastResolvedHunterCastToken` / `lastResolvedHunterCastAt` — cache for cast-spell resolution
- `STOP_AUTOREPEAT_SPELL` cleans up state but doesn't hard-reset mid-cycle
- `UNIT_SPELLCAST_DELAYED` refreshes stored Hunter Steady Shot / Aimed Shot timing via `SeedHunterStoredCastState()`

## Range Helper bar
- Orange bar-fill segment tied to the hunter helper bar (the dedicated cast/helper bar below ranged)
- Default width: 7px (`ns.HUNTER_RANGE_HELPER_WIDTH`)
- Indicates the range-finder visibility: shows when target is within optimal ranged weapon range
- Toggle: `showHunterRangeHelper` (default `true`)
- Visual states: green (in melee range), yellow (sweet spot), red (too far), blue (out of range)
- Colors: `colors.hunterRangeMelee` / `hunterRangeSweetSpot` / `hunterRangeRanged` / `hunterRangeOutOfRange`

## Rapid Fire bar
- Duration/cooldown bar for Rapid Fire (`3045`)
- Toggle: `showHunterRapidFireBar` (default `true`)
- Height: `ns.HUNTER_RAPID_FIRE_BAR_HEIGHT` (default 4, slider 2-20)
- Readiness (`23989`) triggers forced refresh on `SPELLCAST_SUCCEEDED`
- Color: `colors.rapidFireBar` → `{r=0.20, g=0.60, b=1.00, a=1}`

## Key spell IDs (supplementary)
| Spell | ID | Constant |
|-------|----|----------|
| Wing Clip | `1` | `ns.WING_CLIP_ID` |
| Readiness | `23989` | `ns.READINESS_ID` |
| Feign Death | `5384` | `ns.FEIGN_DEATH_ID` |
| Rapid Fire | `3045` | — |

## Ranged timer hidden cast window (source: UI.lua)
```
windowStart = (lastSwing + duration) - GetRangedCastWindow()
windowEnd   = lastSwing + duration
```
- Cached on `t.hiddenCastWindowStart` / `t.hiddenCastWindowDuration` to prevent frame-by-frame drift
- Cleared on ranged reset, new start, or when `now > windowEnd` and not moving
- If the player is still moving when the window ends, the start re-anchors to current time (keeps red zone alive)

## Rotation (TBC reference)
- 1:1 rotation (1 Steady per 1 Auto)
- 1:2 at high haste
- French rotation (5:5:1:1) available for min-max

---
**🔄 Sync hook:** If Hunter timing, spell IDs, state flags, or cast behavior changes, update this file. Master protocol → `standards/code.md`
