# v0.2.8 — full audit findings register

**Supersedes:** `bench/findings-sst-0.2.8.md` as of 2026-10-27T06:05-04:00.
The earlier register was scoped to the last two release deltas only; this one
covers the whole addon and carries the full evidence trail.

**Evidence:** this repo (HEAD `769bba8` + uncommitted v0.2.8 edits) and the
client sources at `/home/sam/wow-ui-source` read via `git show <branch>:<path>`
(`classic_era` 1.15.9.70003, `classic_anniversary` 2.5.6.70006,
`classic_titan` 3.80.2.69815).

**Grades:** `verified` (proved from code/client source, file:line given),
`in-game` (needs operator capture), `open` (hypothesis, not a defect).

## Baseline (re-run 2026-10-27T06:02-04:00)

| Gate | Result |
|---|---|
| `lua5.1 run_tests.lua` | 150/150, 0.066 s |
| `luac5.1 -p` (14 files) | OK |
| `luacheck .` | 0 warnings / 0 errors |

## Confirmed correct — do not churn

- Era interface **11509** everywhere (`SuperSwingTimer.toc:1`,
  `Diag.lua:239`, `Tests.lua:160`). No 11507 in addon code.
- All 45 `SetDrawLayer` calls use sublevels in `-1..7`.
- The CLEU main-hand branches write only the MH/OH timers
  (`State.lua:1347-1370`); the Hunter `OnMeleeSwing` callback only clears the
  Raptor tint (`ClassMods.lua:5863-5868`). A main-hand hit/miss cannot move the
  ranged timer. Locked in by `MainHandCLEU_DoesNotResetRangedTimer`.
- `ns.UnitAura` (`Constants.lua:178`) prefers `C_UnitAuras.GetAuraDataByIndex`
  and is nil-safe when the deprecation shim is absent.
- `C_Spell.GetSpellCooldown/GetSpellInfo/GetSpellTexture/IsAutoRepeatSpell/IsCurrentSpell`
  documented on all three branches
  (`Blizzard_APIDocumentationGenerated/SpellDocumentation.lua:108,190,357,407,436`).
- `UnitRangedDamage`/`GetRangedHaste` exist on Era
  (`Blizzard_CharacterFrame/Vanilla/PaperDollFrame.lua:543`).
- `SoD.lua:21-33` guards `C_Seasons`/`C_Engraving`.

## Defects

| ID | Finding | Grade | Evidence |
|---|---|---|---|
| D-01 | Blizzard-canvas "Minimal Mode" toggle is self-defeating: setter calls `ApplyMinimalMode()` with no argument, which coerces to `false` and writes it back | verified | `Config.lua:2362-2368` + `UI.lua:2593-2594` |
| D-02 | Reckoning stack count reads raw `UnitBuff` with the **wrapper's** tuple positions (4=count, 11=spellID), but the client returns 4=dispelName, 11=canApplyAura | verified | `ClassMods.lua:835` vs `AuraUtil.lua:38-53`; correct raw read at `ClassMods.lua:4181` |
| D-03 | `extraAttackPending` never expires; a granted extra attack that never surfaces swallows the next real swing and freezes the bar until combat ends | verified | `State.lua:55,639,1354,1368,1385`; only reset at `SuperSwingTimer.lua:1833` |
| D-04 | `/sst reset` restores ~69 of 104 `DB_DEFAULTS` keys; missing `barBorderSize`, `showAdvanced`, `showGlowEffects`, `showPowerBar`, `showSwingFlash`, `showGcdTicker` and ~25 class-overlay toggles | verified | `Config.lua:5712+` vs `Constants.lua` DB_DEFAULTS |
| D-05 | Entering combat writes `lockBars = true` into SavedVariables, destroying an unlocked preference permanently | verified | `SuperSwingTimer.lua:1773-1782` |
| D-06 | Localized Steady Shot never matched; `ns.STEADY_SHOT_NAME` defined but unused on the red-zone paths | verified | `State.lua:1175,1473` vs `Constants.lua:279` |
| D-07 | Two GCD durations: `GetGcdDuration()` returns constant 1.5, ignoring measured `ns.gcdDuration` | verified | `State.lua:1067-1070` vs `:947` |
| D-08 | `HandleSpellcastStop` and `HandleSpellcastChannelStop` are byte-identical | verified | `State.lua:1091-1119` |
| D-09 | Phantom ranged timer: every successful non-Hunter spellcast starts `timers.ranged` although `classConfig.ranged=false`, pinning the render loop | verified | `State.lua:1528-1534` + `CLASS_CONFIG` |
| D-10 | Hunter melee queue cleared before it is read, making `IsHunterMeleeBarVisible`'s queue term dead | open | `UI.lua:2650-2653` vs `State.lua:459-465` |
| D-11 | Dead code / duplicate doc blocks / `if true then` wrappers / no-op migrations / dead WoWUnit harness | verified | `State.lua:760-778,1204-1212,1291-1308`; `UI.lua:1806-1834`; `Constants.lua:471,493,566`; `ClassMods.lua:9358-9368`; `SuperSwingTimer.lua:406,419,420` |
| D-12 | Class setup failure handling inconsistent: only Shaman fails open; `pcall` result discarded, nothing reaches `/sst diag` | verified | `ClassMods.lua:9268-9306` |

## Risks

| ID | Finding | Grade |
|---|---|---|
| R-01 | Single comma-delimited `## Interface: 11509, 20506, 38002` — **operator-confirmed intentional and working** (2026-10-27). Blizzard's own addons use per-flavor suffix TOCs, but this addon's comma list is the intended multi-client mechanism. Do not change it and do not re-raise it as a risk. | closed by operator |
| R-02 | Red-zone flag is set when a Steady Shot is interrupted/failed, holding the ranged timer for a shot that never landed | open |
| R-03 | `SPELL_UPDATE_COOLDOWN` handler does repeated `C_Spell` probes and is hot | verified (cost), impact unmeasured |
| R-04 | `State.lua:736-739` comment claims `UnitRangedDamage` returns damage on 2.5.5; client source treats return 1 as attack speed | comment unverified |

## Performance candidates

| ID | Finding | Evidence |
|---|---|---|
| P-01 | ~560 direct `SuperSwingTimerDB` global reads | Config 377, UI 64, ClassMods 58, Constants 34 |
| P-02 | `ns.GetSpellInfo`/`GetSpellTexture` re-`rawget` + `pcall` every call, 137 sites | `Constants.lua:69-109` |
| P-03 | `ns.GetAlignedTime()` C call many times per frame | State ×26, UI ×8 |
| P-04 | `SetMinMaxValues` re-set every frame | `UI.lua:1760,1801` |
| P-05 | `UpdateSparkPosition` 4 geometry C calls per bar per frame | `UI.lua:186-231` |
| P-06 | `HasActiveTimers()` full scan + global DB lookup per event | `State.lua:260-349` |
| P-07 | `ApplyVisibility` runs ~30 optional calls + API probes per invocation | `UI.lua:2628-2804` |

## Structure

| ID | Finding |
|---|---|
| S-01 | `ClassMods.lua` 9,368 lines + `Config.lua` 5,981 = 53% of the codebase |
| S-02 | `InitClassMods` manually nils ~90 `ns.Update*` symbols |
| S-03 | 66-step migration ladder with no-op steps inside the bootstrap |
| S-04 | ~400-line `if/elseif` OnEvent dispatcher |

## Open questions for the operator (hands-up)

1. D-10 — Hunter Raptor Strike queue: show the MH bar between swings, or only mid-swing?
2. R-02 — should an interrupted Steady Shot hold the ranged timer?
3. D-05 — is "lock on combat start" wanted at all, or drop it?
4. D-02 — is the Reckoning badge visible/used for your Prot Paladin?
5. Are `MAGE/PRIEST/WARLOCK` (all toggles false) meant to get only the enemy bar?
6. Keep pre-1.15 legacy aura shapes, or delete them?

## Verification

In-game matrix still pending: Era 1.15.9 (normal/hardcore/SoD), Anniversary
2.5.6, Titan 3.80.2 — load, `/sst diag`, one swing cycle, one Hunter cycle,
one class overlay, plus the D-01/D-04/D-05 checks.

---

## Status after implementation (2026-10-27T06:20-04:00)

**All fixes below are in the working tree and uncommitted.** Every one has a
regression test that was executed with the fix removed and confirmed to fail.

| ID | Status | Regression test | Proven to fail without fix |
|---|---|---|---|
| D-01 | Fixed | `MinimalMode_NilArgumentKeepsStoredValue` | yes |
| D-02 | Fixed | `ClassModsUsesOnlyWrappedAuraCalls` | yes |
| D-03 | Fixed | `ExtraAttack_CreditExpires` + `ExtraAttack_StillSuppressesTheCreditedSwing` | yes (both directions) |
| D-04 | Fixed | `ResetConfigDefaults_RestoresEveryDefaultKey` | yes |
| D-05 | Fixed | `CombatLock_DoesNotRewriteSavedPreference` | yes |
| D-06 | Fixed | `LocalizedSteadyShot_RegistersRedZone` | yes |
| D-07 | Fixed | `GcdDuration_FollowsMeasuredValue` | yes |
| D-08 | Fixed | `SpellcastStopHandlers_ShareOneImplementation` | yes |
| D-09 | Fixed | `MeleeClass_CastDoesNotStartRangedTimer` (all 8 non-Hunter classes) | yes |
| D-10 | **Open** — awaiting operator intent | — | — |
| D-11 | Fixed (partial, see correction) | — | — |
| D-12 | Fixed | — (no test; init-path diagnostic only) | — |
| D-13 | Fixed | `FeignDeath_CancelsRangedCycle` | yes |
| D-15 | Fixed | `RaptorStrikeCast_DoesNotRestartRangedCycle` (+ `MainHandCLEU_DoesNotResetRangedTimer`, `AutoShotCLEU_StartsRangedCycle`, `AutoShotShootAlias_StillStartsRangedCycle`) | yes (Raptor test) |

Gates after implementation: `lua5.1 run_tests.lua` **166/166**,
`luacheck .` **0 warnings / 0 errors**, `luac5.1 -p` clean.

### New findings raised during implementation

**D-13 (new, verified, fixed) — Feign Death branch was unreachable.**
Spell 5384 is registered in `ns.RESET_SWING_SPELLS`
(`SuperSwingTimer_Constants.lua:816-832`) and `HandleSpellcastSucceeded` tested
that table before the dedicated Feign Death branch, so for a Hunter the
`RESET_SWING_SPELLS` arm always won and a Feign Death **restarted** the ranged
cycle instead of cancelling auto-shot. The branch is now checked first.

**D-14 (new, verified, NOT fixed — architectural).** About thirty
`ns.Apply*` functions write straight into `SuperSwingTimerDB`
(`SuperSwingTimer_UI.lua`: `ApplyBarSize`, `ApplyBarBorderSize`,
`ApplyBarTexture`, `ApplyRangedBarTexture`, `ApplyBarTextureLayer`,
`ApplyBarBackgroundColor`, `ApplyBarBorderColor`, `ApplySparkSettings`,
`ApplySparkTextureLayer`, `ApplySparkColor`, `ApplyIndicatorBlendMode`,
`ApplyWeave*`, `ApplyHunterRangedBarLabel`, …). Applying a value therefore
persists it, which:
- masked gaps in the old `/sst reset` (a skipped key was rewritten by the
  trailing `Apply*` fan-out — this is why the first attempt to prove the D-04
  test by skipping `barBorderSize` did not fail; `ApplyBarBorderSize` wrote it
  back), and
- makes the DB a moving target for any caching work (P-01).

Not fixed here: separating set from apply touches every config row and needs its
own regression pass. Tracked as the prerequisite for P-01.

**D-15 (new, verified, fixed) — v0.2.8 widened the generic ranged reset to
Hunters.** The D-09 phantom-timer fix changed `shouldResetRanged` from
`playerClass ~= "HUNTER"` + `IsHunterCastSpell` to `classConfig.ranged`
(`SuperSwingTimer_State.lua:1539`). Since `CLASS_CONFIG.HUNTER.ranged` is true
(`SuperSwingTimer_Constants.lua:964-974`), any Hunter success that fell through
to the generic branch — Raptor Strike, Wing Clip, Hunter's Mark — called
`StartRangedSwing` whenever a cast-start had set `ns.casting`
(`State.lua:1041`). The branch now restarts the Hunter ranged cycle only for an
`IsAutoShotSpell` payload. `RaptorStrikeCast_DoesNotRestartRangedCycle` fails
with the gate reverted and passes with it. Trigger frequency in-game depends on
whether the client emits `UNIT_SPELLCAST_START` for instant melee abilities;
the gate is correct either way. The v0.2.8 changelog note claiming swing-reset
behavior was untouched was corrected to "restart-gating only; no timing math".

### Corrections to the original register

- **D-11 over-claimed.** The WoWUnit block at `SuperSwingTimer_ClassMods.lua`
  is **not** dead code: `SuperSwingTimer_Tests.lua:19` reads `ns._Test`, and the
  headless runner installs a WoWUnit mock before loading the addon, so that
  block is load-bearing for the headless suite (166 tests at this revision). It was left in place. Removed
  instead: duplicate doc blocks, orphan section banners, three `if true then`
  wrappers, three no-op migration rungs (v21/v23/v24) and the Shaman
  `OnUpdate` restore that its own comment called a no-op.
- **R-04** remains a comment-only inaccuracy (not touched).

### Correction — TOC Interface mechanism is intended

The operator confirmed on 2026-10-27 that the single TOC line
`## Interface: 11509, 20506, 38002` is deliberate and works across all three clients.
R-01 is therefore **closed, not open**: do not split into per-flavor TOC files and do not
report the comma list as a defect or unverified risk. The Mnemon entry that called it
'unproven' was soft-deleted and replaced with the operator-confirmed decision.
