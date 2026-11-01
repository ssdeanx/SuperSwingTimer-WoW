# workshop map

Root: `./` — Path A, existing directory, local-only. This file is the map
(`README.md` stays the addon readme).

## skill family

- `workshop-create` — this scaffold
- `desk-open` — create and resume desks (`journal.md` + `.signals/`)
- `desk-journal` — write and read journal entries
- `bench-read` — read shared artifacts
- `signal-write` — emit signals: hands-up, blocked, done, checkpoint,
  partnership

## layout

- `desks/` — one folder per desk: `journal.md` + `.signals/`
  (see `desks/README.md`)
- `bench/` — shared files: findings, verdicts, drafts, reports
  (see `bench/README.md`)
- `hands-up.md` — operator escalation trail. Real hands-ups are also
  `signal-write` escalation signals in the raising desk's `.signals/`
  plus a `[signal:hands-up]` marker in that desk's journal
- `CAIRN.md` — operating disposition, verbatim from `workshop-create`
- `workshop.md` — this map

## opening a desk (per `desk-open`)

1. Name it: short, descriptive, kebab-case.
2. If `desks/<name>/journal.md` exists, the desk is live — read it and
   resume, never overwrite.
3. Otherwise create `journal.md` + `.signals/` and write the first entry:
   purpose, scope, next step.

## sessions (per `desk-open`, `desk-journal`, `signal-write`)

1. Start: read the journal, check the bench.
2. Work. Emit signals for state changes that affect the room
   (escalation sorts above execution on the dashboard).
3. End: append a journal entry — done, state, next step.

## this project

SuperSwingTimer is a WoW addon (Lua 5.1). The workshop root is the addon
repo, so workshop files are never addon code:

- Never reference `desks/`, `bench/`, `workshop.md`, `CAIRN.md`, or
  `hands-up.md` from any `.toc` load list.
- Exclude all of them from release zips.
- Gates: `lua5.1 run_tests.lua`, `luac5.1 -p <file>`, `luacheck .`.

## what this desk learned

**Client contract**

- `classic_era` 1.15.9 = normal Era, hardcore, and SoD. CLEU and
  `UNIT_SPELLCAST_*` carry **numeric spell IDs**.
- `classic_anniversary` 2.5.6 = TBC. Payloads carry **localized spell
  names**.
- `classic_titan` 3.80.2 is the third client. Matchers must keep both
  shapes working; new matching is additive only.
- SoD is not a separate client. Its rune IDs are additive entries in the
  same Era tables.

**How the hunter path actually works (read from current files)**

- Auto Shot start: CLEU `SPELL_CAST_SUCCESS` → `StartRangedSwing`
  (`SuperSwingTimer_State.lua:1375-1382`), `SPELL_UPDATE_COOLDOWN` →
  `StartRangedSwing` when auto-repeat is active and the timer is idle
  (`SuperSwingTimer.lua:1680-1703`), and
  `START_AUTOREPEAT_SPELL` (`SuperSwingTimer.lua:1751-1754`).
- `StartRangedSwing` dedupes at 0.25 s or latency + 0.05, then calls
  `StartSwing("ranged")` (`State.lua:847-869`).
- `StartSwing("ranged")` takes `duration` and `lastSwing` from
  `GetAutoShotCooldown()` when a cooldown is returned; otherwise it uses
  the cached `t.speed`, then `UnitRangedDamage`, then 2.0
  (`State.lua:787-802`).
- The red-zone hold is `ShouldKeepHunterRangedTimerActive`
  (`UI.lua:60-121`): red-zone flag within 1.0 s, then cycle-end +
  latency + `STEADY_SHOT_GRACE`, then auto-repeat, then cooldown, then
  the cast-bar predicate.
- The hidden Auto Shot cast window starts at `cycleEnd - 0.5` and its
  end is extended by latency + 0.15 + grace when the Steady flag is
  recent (`UI.lua:425-470`).
- The display decision is `ShouldShowHunterCastBar` (`UI.lua:501-537`):
  stored cast state → live cast → hidden window. `UpdateHunterCastBar`
  prefers live cast over stored state, then the hidden window
  (`UI.lua:984-1085`).

**Release history quirk**

- The v0.2.7 commit (`448fc9b`) carries the v0.2.6 code changes as well,
  and its parent TOC still said `v0.2.5`. The v0.2.8 bump goes from
  `v0.2.7` → `v0.2.8` with no skip.

**Verification path**

- In-game verification is `/sst diag`; the operator no longer uses
  WoWUnit. `SuperSwingTimer_Tests.lua` is not in the production TOC and
  is only the input to the headless suite.
- No CI. The operator zips and uploads manually.

**Operator rules for this repo**

- Trace the code; do not guess or assume.
- Do not edit files without explicit approval.
- Comments must state purpose; no unused code.
- Audit findings need file:line evidence; runtime/API behavior is
  unverified until confirmed in-game.
