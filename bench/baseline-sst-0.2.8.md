# Baseline — SuperSwingTimer v0.2.8 audit

**Status:** verified (local commands). Captured 2026-10-27T04:36-04:00.
**Supersedes:** nothing. First baseline for this release.

## Repo state

- Repo: `/home/sam/SuperSwingTimer-WoW`
- Branch: `main`, ahead of `origin/main` by the cleanup commit
- HEAD: `769bba8` — `docs: remove stale memory-bank and audit archives`
- Worktree after cleanup: clean except the new workshop files (`CAIRN.md`,
  `desks/`, `bench/`).
- The 23 deleted files were **intentionally removed** by the operator
  (stale memory-bank / audit archives that carried wrong information).
  They were committed as deletions, not restored. History remains in git.

## Gates (green baseline)

| Gate | Command | Result |
|---|---|---|
| Headless tests | `lua5.1 run_tests.lua` | **150/150 passed**, 0.066 s |
| Lua syntax | `luac5.1 -p` (14 files) | **OK** |
| Lint | `luacheck .` | **2 warnings / 0 errors** — `State.lua:1100:15 unused 'now'`, `State.lua:1116:15 unused 'now'` |

## Code size (lines)

| File | Lines | Role |
|---|---:|---|
| SuperSwingTimer_ClassMods.lua | 9368 | 6 class modules, power bar, debuff/buff bars |
| SuperSwingTimer_Config.lua | 5981 | settings studio + Blizzard canvas |
| SuperSwingTimer_UI.lua | 3124 | bars, render loop, move mode, apply* |
| SuperSwingTimer_Tests.lua | 2291 | headless + WoWUnit test cases |
| SuperSwingTimer.lua | 1859 | bootstrap, events, migrations, slash |
| SuperSwingTimer_Constants.lua | 1735 | spell tables, DB defaults, helpers |
| SuperSwingTimer_State.lua | 1548 | swing state machine, CLEU, cast handlers |
| SuperSwingTimer_Diag.lua | 1012 | error capture, report, profiler |
| SuperSwingTimer_Weaving.lua | 725 | Shaman weave math |
| run_tests.lua | 611 | headless harness + WoW API mocks |
| SuperSwingTimer_SoD.lua | 382 | Season of Discovery additive tables |
| SuperSwingTimer_Glow.lua | 263 | LibCustomGlow adapter |
| SuperSwingTimer_Hooks.lua | 75 | OnUpdate hook registry |
| Media/SuperSwingTimer_Media.lua | 30 | bundled texture registry |
| **Total** | **29004** | |

## Client-source evidence available locally

`/home/sam/wow-ui-source` is a git checkout with these branches:

| Branch | Version |
|---|---|
| `classic_era` (checked out) | 1.15.9.70003 |
| `classic_anniversary` | 2.5.6.70006 |
| `classic_titan` | 3.80.2.69815 |

Read via `git -C /home/sam/wow-ui-source show <branch>:<path>` so the
worktree is never disturbed. Key evidence used for the audit:

- `Blizzard_Deprecated/Deprecated_1_15_8.lua` and `Deprecated_2_5_5.lua`:
  with `loadDeprecationFallbacks`, `UnitAura`/`UnitBuff`/`UnitDebuff` are
  Lua shims over `C_UnitAuras` + `AuraUtil.UnpackAuraData`.
- `Blizzard_FrameXMLUtil/AuraUtil.lua:38-53`: `UnpackAuraData` order is
  `name, icon, applications, dispelName, duration, expirationTime,
  sourceUnit, isStealable, nameplateShowPersonal, spellId, canApplyAura, …`
  — identical on Era and Anniversary. This is what invalidates the
  positional Reckoning read (r4/r11) and validates the addon normalizer.

## Package inventory (release bloat baseline)

| Area | Size | Shipped today? | Notes |
|---|---:|---|---|
| `Lib/` total | 380 KB | partially | TOC loads only `LibStub` + `LibCustomGlow-1.0` (52 KB + 8 KB). |
| `Lib/LibClassicSwingTimerAPI` | 152 KB | no | reference lib; not loaded. |
| `Lib/LibRangeCheck-2.0` | 96 KB | no | not loaded. |
| `Lib/LibDBIcon-1.0` | 24 KB | no | not loaded. |
| `Lib/LibSharedMedia-3.0` | 20 KB | no | not loaded (optional lookup only). |
| `Lib/CallbackHandler-1.0`, `Lib/LibDetours-1.0` | 28 KB | no | not loaded. |
| `docs/` | 42 MB | no (repo only) | includes vendored other-addon copies under `docs/swedge/`. |
| `Logo.png` + duplicate PNG/JPEG | ~3.4 MB | no | only `Logo.tga` is referenced by the TOC icon. |
| `SuperSwingTimer_Tests.lua` + `run_tests.lua` | ~122 KB | yes in folder | neither is loaded by the TOC. |

There is no `.pkgmeta` / packager config, so any "zip the repo" release
would carry the whole payload above.

## Test-group baseline

| Group | Tests |
|---|---:|
| Core | 38 |
| Hunter | 23 |
| Diag | 22 |
| Reg (update-loop/restack) | 16 |
| Config | 9 |
| Weaving | 7 |
| UANorm (aura normalizer) | 7 |
| MoveMode | 7 |
| Auras | 7 |
| Combat | 6 |
| ClassMods | 6 |
| SoD | 2 |
| **Total** | **150** |

Coverage gaps visible from the group list: Paladin/Warrior/Rogue/Druid/
Shaman behavior is represented only by structural tests; no test for
`/sst reset` completeness, Feign Death, localized spell names, or the
Blizzard settings canvas.
