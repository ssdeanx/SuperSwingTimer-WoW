# Shaman — Class Reference

## Timing constants (source: source code)

| Constant | Value | Notes |
|----------|-------|-------|
| `ns.cachedLatency` | `GetNetStats()` world/home /1000 | Added to every breakpoint position |
| `GCD_DURATION` | `1.5` | Global cooldown (State.lua:824) |
| `SPEED_CHECK_INTERVAL` | `0.10` | Melee speed resync throttle (State.lua:537) |

## Weave system
- Breakpoint math lives entirely in `_Weaving.lua` — owns no swing state, hooks into MH bar update
- Spell catalog with cast times for all relevant shaman spells (LB, CL, HW, LHW, CH)
- Breakpoint markers on MH bar: positioned at `castTime + cachedLatency` from swing end
- Weave spark shows cast progress (separate from main swing spark)
- Uses family-specific colors for visual distinction

### Breakpoint math
```
breakpointPosition  = swingEnd - (castTime + cachedLatency)
markerBarPosition   = breakpointPosition / swingDuration * barWidth
```
- Breakpoint marker stays **fixed** at `castTime + cachedLatency` start point (does not move)
- Weave spark animates cast progress separately
- Cached latency is added so the marker accounts for reaction time

## Spell families & colors (source: Constants.lua:504-526)
| Family | Abbrev | Label | Color | Cast time |
|--------|--------|-------|-------|-----------|
| Lightning Bolt | `LB` | Lightning Bolt | `{0.45, 0.75, 1.00}` light blue | 3.0s→2.5s with talents |
| Chain Lightning | `CL` | Chain Lightning | `{0.15, 0.45, 0.95}` dark blue | 2.5s→2.0s |
| Healing Wave | `HW` | Healing Wave | `{0.25, 0.90, 0.35}` green | 3.0s→2.5s |
| Lesser Healing Wave | `LHW` | Lesser Healing Wave | `{0.55, 1.00, 0.55}` light green | 1.5s→1.0s |
| Chain Heal | `CH` | Chain Heal | `{1.00, 0.90, 0.20}` yellow | 2.5s→2.0s |

### Spell IDs per family (ordered highest→lowest rank)
| Family | Spell IDs |
|--------|-----------|
| LB | `403, 529, 548, 915, 943, 6041, 10391, 10392, 15207, 15208, 25448, 25449` |
| CL | `421, 930, 2860, 10605, 25439, 25442` |
| HW | `331, 332, 547, 913, 939, 959, 8005, 10395, 10396, 25357, 25391, 25396` |
| LHW | `8004, 8008, 8010, 10466, 10467, 10468, 25420` |
| CH | `1064, 10622, 10623, 25422, 25423` |

## Breakpoint markers
- Uses **tracked spell's small icon** (from `GetSpellInfo(spellId)`) — NOT triangle textures
- Top marker above MH bar, bottom arrow below MH bar
- Positioned at: swingEnd - (castTime + cachedLatency)
- Visible only when weave helper is toggled on (`showWeaveAssist` + per-family toggle)
- Tied to MH bar width (respects user width setting — does not use static default)
- Marker layer: `weaveMarkerLayer` (default `"OVERLAY"`)
- Triangle textures: `weaveTriangleTopTexture` / `weaveTriangleBottomTexture`
- Triangle default: `UI-ScrollBar-ScrollDownButton-Arrow` / `UI-ScrollBar-ScrollUpButton-Arrow`
- Triangle size: 6px (`weaveTriangleSize`), gap: 1px (`weaveTriangleGap`), alpha: 1 (`weaveTriangleAlpha`)

## Weave spark
- Shows real-time cast progress on the MH bar
- Separate from main swing spark — uses `weaveSparkTexture` (default: `target_indicator.tga`)
- Width: 3px (`weaveSparkWidth`), Height: 15px (`weaveSparkHeight`), Alpha: 0.95 (`weaveSparkAlpha`)
- Layer: `weaveSparkTextureLayer` (default `"OVERLAY"`)
- Blend mode follows `indicatorBlendMode` (default `"ADD"`)

## Family toggles (per-family, all default `true`)
```
weaveSpellFamilies = { LB = true, CL = true, HW = true, LHW = true, CH = true }
```
- Each family independently enable/disable-able via config
- `ns.GetWeaveFamilyEnabled(abbrev)` checks `db.weaveSpellFamilies[abbrev]`
- `ns.SetWeaveFamilyEnabled(abbrev, enabled)` sets + dirties spell catalog

## Weave visibility
- Master toggle: `showWeaveAssist` (default `true`)
- Per-family toggles in `weaveSpellFamilies` table
- Respects Minimal Mode (`ns.IsMinimalMode()`)
- Config panel section hidden on non-shaman classes via `playerClass == "SHAMAN"` guard
- Spell catalog rebuild triggered by `ns.weaveState.spellCatalogDirty = true`

## Spell resolution
- Spell names resolved through `ns.GetSpellInfo` wrapper (Classic/TBC-safe)
- TBC rank support: all ranks from rank 1 through max rank in each family
- Haste math falls back from `UnitSpellHaste("player")` to `GetSpellHaste()` when needed
- Catalog built at init, dirtied when family toggles change

## Key spell IDs
| Spell | ID | Constant |
|-------|----|----------|
| Stormstrike | `17364` | `ns.SHAMAN_STORMSTRIKE_ID` |
| Shamanistic Rage | `30823` | `ns.SHAMANISTIC_RAGE_ID` |

## Extra helpers (ClassMods)
- **Shamanistic Rage badge**: `UpdateShamanisticRageBadge()` — shows during SR uptime
  - OnUpdate chain bootstrapped — captures `ns.OnUpdate` directly as `prevOnUpdate` (v0.0.8: no `prevOnUpdate` global)
  - Bootstrap call needed for initialization
- **Windfury ICD tracking**: `showShamanWindfuryIcd` toggle → shows internal cooldown countdown
- **Flurry stack badge**: `showWarriorFlurryCounter` — shows current Flurry stacks

---
**🔄 Sync hook:** If Shaman weave breakpoint math, spell catalog, haste scaling, or marker visuals change, update this file. Master protocol → `standards/code.md`
