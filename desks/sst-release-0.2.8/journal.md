# Desk: sst-release-0.2.8

**Purpose:** audit-traced preparation of SuperSwingTimer v0.2.8 — complete
code-smell audit, evidence-backed fixes, release artifacts.

**Scope:** the addon repos files in `/home/sam/SuperSwingTimer-WoW`:
14 runtime Lua files, TOC, Media, release docs, tests, CI. Client truth
from `/home/sam/wow-ui-source` branches `classic_era` (1.15.9.70003),
`classic_anniversary` (2.5.6.70006), `classic_titan` (3.80.2.69815).

**Write scope for code:** only after the Phase 1 findings register is
reviewed. No destructive git. No changes under `Lib/`.

**Handoff style:** audit artifacts live on the bench; journal entries stay
short. Verification levels are always labeled:
`verified` (code/client-source), `in-game`, or `open`.

---

## 2026-10-27 — Desk opened; baseline captured; audit started

- state: open
- did:
  - Committed the 23 intentional stale-doc deletions (`769bba8`), so the
    worktree is clean before any code work.
  - Created the workshop scaffold (`CAIRN.md`, `desks/`, `bench/`).
  - Baseline: HEAD `769bba8` on `main`; `lua5.1 run_tests.lua` 150/150;
    `luac5.1 -p` clean; `luacheck .` 2 warnings (`State.lua:1100`,
    `State.lua:1116`). Artifact: `bench/baseline-sst-0.2.8.md`.
  - Read-only audit seed: 28 findings traced with file:line, including
    Feign Death branch ordering, Blizzard-canvas minimal-mode no-op,
    incomplete `/sst reset`, stale v0.2.5 titles, WeakAuras texture
    default, localized Steady Shot mismatch, Reckoning stack parse,
    SoD isolation coupling, and release-packaging bloat.
- next: finish the per-file sweep, publish `bench/findings-sst-0.2.8.md`
  with a coverage matrix, then stop for operator review before editing code.

## 2026-10-27 — Full addon audit; v0.2.8 hardening plan approved

- state: open
- did:
  - Audited all 14 runtime Lua files (29,030 lines) read-only against the three
    client sources; re-ran the gates (150/150, luacheck 0/0, luac OK).
  - Published the full register to `bench/findings-sst-0.2.8.md`, superseding
    the delta-only version: 12 verified defects (D-01..D-12), 4 risks, 7 perf
    candidates, 4 structure items.
  - Highest-value finds: Minimal Mode toggle self-defeating (D-01); Reckoning
    aura tuple read at the wrong positions (D-02); `extraAttackPending` never
    expires and can freeze the swing bar (D-03); `/sst reset` misses ~30 keys
    (D-04); combat persists `lockBars=true` into SavedVariables (D-05).
  - Confirmed as NOT broken: Era interface 11509, all draw-layer sublevels,
    aura wrapper nil-safety, `C_Spell` availability on all three clients.
  - Raised a hands-up signal for the 6 operator decisions.
- next: implement D-01..D-12 with a regression test per fix, then Part C perf.


## 2026-10-27 — v0.2.8 hardening pass implemented (13 defects)

- state: done
- did:
  - Fixed D-01..D-09, D-11 (partial), D-12 plus newly verified D-13 (Feign
    Death branch unreachable behind RESET_SWING_SPELLS). Working tree only,
    not committed. Suite 150 -> 162 tests; luacheck 0/0; luac clean.
  - Proved every new regression test by removing its fix: 11/11 fail without
    it. Two harness pitfalls found and corrected: HandleCLEU keys off the
    cached UnitGUID (not GetPlayerGUID), and SetMockTime must be rawget-guarded
    like AdvanceMockTime or luacheck flags it.
  - Raised D-14: ~30 ns.Apply* functions write SuperSwingTimerDB, so applying a
    value persists it. That is why the old incomplete /sst reset still looked
    correct for some keys, and it blocks the P-01 DB cache.
  - Corrected the register: the WoWUnit block in ClassMods is NOT dead code
    (ns._Test is read by the headless suite).
- next: D-10 needs operator intent; Part B (per-flavor TOC + in-game matrix),
  Part C perf (P-01 blocked on D-14), Part D restructure. All still open.

## 2026-10-29 — Hunter Raptor Strike / Auto Shot audit; D-15 fixed

- state: done (working tree; in-game verification pending)
- did:
  - Traced the CLEU main-hand path: `SWING_DAMAGE`/`SWING_MISSED` write only
    `timers.mh`/`timers.oh`; no ranged writer is reachable from it. Added
    `MainHandCLEU_DoesNotResetRangedTimer` to lock that in.
  - Found D-15: the v0.2.8 D-09 fix widened the generic cast-success ranged
    reset from `IsHunterCastSpell` to `classConfig.ranged`, so Raptor Strike
    (and any Hunter utility cast) could call `StartRangedSwing` whenever a
    cast-start had set `ns.casting`. Gate narrowed to `IsAutoShotSpell`.
  - Added four regression tests (Raptor Strike, main-hand CLEU hit/miss, Auto
    Shot CLEU, "Shoot" alias). `RaptorStrikeCast_DoesNotRestartRangedCycle`
    was proved to fail with the gate reverted. Suite 162 -> 166; luacheck 0/0;
    luac clean.
  - Corrected the v0.2.8 changelog claim that swing-reset behavior was
    untouched; only timing math was.
- next: operator in-game check on Era 1.15.9 and TBC 2.5.6 — Raptor Strike at
  melee range must not start the ranged bar unless an Auto Shot damage event
  occurs; optional `/eventtrace` confirms whether `UNIT_SPELLCAST_START`
  fires for 2973. v0.2.8 stays the release version (unreleased).
