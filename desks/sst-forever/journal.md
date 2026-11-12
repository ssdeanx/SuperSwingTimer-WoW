# Desk: sst-forever

**Purpose:** make SuperSwingTimer load and run correctly on WoW Forever (1.60.1.70790)
by gating every Forever-restricted path, without changing behavior on Classic Era,
TBC Anniversary, or Titanforge.

**Scope:** /home/sam/SuperSwingTimer-WoW (write), /home/sam/wow-ui-source
(read-only, branch `forever`). No game install folders. No destructive git.

**Rule from operator:** do not remove features to make Forever work — gate them.
Interface version is correct and out of scope.

**Evidence grades:** verified (addon code / wow-ui-source), in-game, open.

## 2026-11-06 — Desk opened; Forever gate audit

- state: open
- did:
  - Confirmed Forever API surface from origin/forever:
    C_SwingTimer.{EnableRangeCheck, IsTargetWithinSwingRange}, PLAYER_SWING
    (swingDuration, swingType), PLAYER_SWING_RANGE_UPDATE, Enum.PlayerSwingType
    {MainHand=0, OffHand=1, Ranged=2}.
  - Confirmed secret-value predicates: C_Secrets.HasSecretRestrictions,
    ShouldUnitSpellCastingBeSecret, ShouldUnitStatsBeSecret, ShouldUnitPowerBeSecret,
    ShouldUnitIdentityBeSecret; sanitizers `scrub` / `scrubsecretvalues`;
    `issecretvalue`.
  - Confirmed secret-returning APIs the addon calls: UnitAttackSpeed,
    UnitRangedDamage, UnitCastingInfo, UnitChannelInfo, UnitHealth, UnitHealthMax,
    UnitPower, UnitPowerMax, UnitGUID, UnitName, GetSpellCooldown, C_Spell.GetSpellCooldown.
- next: gate every call site; add Forever regression tests; bump version.

## 2026-11-06 — [signal:done] Forever gate hardened; v0.3.0 prepared

- state: done (working tree; in-game verification pending)
- did:
  - Audited every Forever-restricted call site against origin/forever docs
    (secret markers, C_SwingTimer, C_CombatLog.IsCombatLogRestricted,
    scrubsecretvalues). 17 defect groups fixed, all additive gates.
  - Removed the `SafeNumber(x) or tonumber(x)` fall-through that re-read
    secret values; hardened aura/cooldown tables, cast payloads, spellcast
    payloads, GUID/name comparisons, power/health reads.
  - Corrected the CLEU gate to the authoritative client query; kept
    PLAYER_SWING ownership of the native swing duration.
  - Bumped TOC + Lua fallbacks + tests + README + CHANGELOG to v0.3.0.
  - Gates: 171/171 tests, luac clean, luacheck 0/0.
  - Bench: bench/findings-sst-forever-0.3.0.md.
- next: operator in-game check on WoW Forever (/sst diag), then tag/zip v0.3.0.


## 2026-11-06 — Second pass: pass-through + full coverage

- state: done (working tree; in-game verification pending)
- did:
  - Re-scanned all 194 secret-bearing function entries in origin/forever docs
    against every runtime file; remaining call sites are gated.
  - Implemented pass-through: secret UnitPower/UnitPowerMax now render through
    SetMinMaxValues/SetValue/SetFormattedText, secret enemy UnitName renders
    through SetText, bar labels display secret text without comparing it.
    (SetValue/SetMinMaxValues/SetText/SetFormattedText are AllowedWhenTainted.)
  - Gated UnitPowerType (powerType/powerToken), the secret BarValue readback in
    GetBarProgressFraction, the legacy UnitAura fallback, and the CLEU payload
    (7 fields).
  - PLAYER_SWING is now the single owner of swing starts/flashes when present,
    so CLEU cannot double-start the same swing.
  - Removed all truthiness tests on raw secret API returns (8 sites).
  - Added C_Secrets.HasSecretRestrictions() build-level fast path.
  - Tests 171 -> 173; bench findings updated (F18-F27).
- next: operator in-game check on WoW Forever (/sst diag), then tag/zip v0.3.0.


## 2026-11-07 — Hotfix: ranged cycle + fail-open detector

- state: done (working tree; awaiting in-game confirmation)
- did:
  - Traced the 120x "numeric conversion on a secret number" error to
    GetPlayerRangedHastePercent, which StartSwing("ranged") calls before writing
    the timer. Every ranged start aborted; melee was unaffected.
  - Removed both fail-open paths in ns.IsSecretValue (build-flag fast path and
    probe self-test) and added behavioural probes; SafeNumber now pcall-wraps
    tonumber and re-verifies the result.
  - Restored the CLEU Auto Shot fallback with a 1s native-start guard.
  - Added /sst diag "secrets" and "ranged" lines for in-game proof.
  - Tests 173/173; bench updated with the root-cause trace.
- next: operator reinstalls, runs /sst diag, and reports the secrets/ranged lines.


## 2026-11-07 — Forever native aura groups (buffs/debuffs) + class data

- state: done (working tree; in-game verification pending)
- did:
  - Root cause: C_UnitAuras.GetAuraDataByIndex is SecretWhenUnitAuraRestricted;
    while restrictions are active every AuraData field except auraInstanceID /
    isHelpful / isHarmful / isFromPlayerOrPlayerPet / isNameplateOnly / isRaid
    may be secret, so the classic scan-and-match path cannot identify an aura.
    ns.UnitAura correctly returns nil, which is why buff icons and debuff bars
    went blank on Forever.
  - New SuperSwingTimer_Forever.lua (loaded last, inert off Forever) declares
    the tracked spell IDs to the client's AuraContainer intrinsics
    (CustomAuraContainerTemplate). The client matches auras in secure code and
    writes icon/duration/stacks/bar values; no secret value enters addon logic.
  - Buff row (player, HELPFUL) shown only while ns.IsAuraDataSecret(); classic
    icon groups keep running whenever auras are readable (cooldown-only icons,
    4s glow and formatting preserved). Debuff row (target, HARMFUL|PLAYER) is
    additive and always available, with a 3px duration bar and stack count.
  - Anchoring reuses ns.debuffStackIconOffset published by RestackDebuffBars.
  - Forever class data from bench/forever-melee-changes.md folded in: new
    Warrior/Rogue/Druid/Shaman/Paladin/Hunter buffs and debuffs; removed Mangle,
    Faerie Fire (Feral), Seal of Vengeance/Corruption.
  - /sst diag "auraGroup" line; Forever Debuff Icon Group toggle.
  - Tests 173 -> 184 (SST-ForeverAura incl. recording-container wiring test).
- open: live-client check of AuraContainer creation (/sst diag auraGroup);
  Slam 1240193 + Improved Slam 12862 swing-delay rule; Windfury proc
  PLAYER_SWING filtering; server-derived debuff aura IDs.
- next: operator reinstalls, reports /sst diag auraGroup + secrets lines, then
  verify buffs/debuffs in combat on Forever.

## 2026-11-07 — Shaman weaving + Forever rank/aura-ID audit

- state: done (working tree; in-game verification pending)
- did:
  - Maelstrom Weapon: aura 408505 (Instant, 30 s, -20% Lightning Bolt; verified
    on Wowhead Forever + ForeverDB), talent 408498 (Enhancement tier 6, 5
    ranks). Forever only: scan 408505 then 408498; apply the reduction to
    Lightning Bolt only; reset stale stacks when the aura is unreadable; clear
    the cache on a successful Lightning Bolt.
  - Weave marker: recomputed from the live MH swing duration every frame, and
    ClearWeavePreview() now runs when the render loop idles so a previous
    swing's breakpoint cannot stay on screen.
  - Debuff ownership: the native row uses HARMFUL|PLAYER (client own-caster
    filter), so another hunter's Serpent Sting or shaman's Flame Shock never
    replaces yours on a shared mob.
  - Aura-ID audit: direct debuffs use the cast ID (verified Serpent Sting
    25295, Flame Shock 29228, Rend 11574, Thunder Clap 6343, Demo Shout 1160,
    Sunder Armor 7386); triggered talents differ (Flurry 12320, Vengeance
    20050, Seal of Fury 1311647, Venom 1310703, Deep Wounds 12721).
  - Rank audit: Serpent Sting 25295, Hunter's Mark 14323-14325, Wing Clip
    14267/14268, Frost Shock 8058/10472/10473, Rupture 11275, Rake 9904 (9907
    is Faerie Fire; shared table bug fixed), Faerie Fire/Demo Roar/Lacerate/
    Judgement ranks, all verified buff ranks + triggered buff IDs.
  - New Forever abilities added as per-class candidates.
  - /sst diag: maelstrom + weave lines.
  - Tests 184 -> 191.
- open: in-combat Maelstrom stacks may be secret (the native icon displays
  them; the weave math falls back to 0); Bloodthirst / Shaman Flurry buff aura
  IDs are not published; live AuraContainer check still pending.
- next: operator runs /sst diag (auraGroup, maelstrom, weave) and checks
  Serpent Sting / Flame Shock ownership in combat.

## 2026-11-12 — [signal:done] v0.3.4 bump + audit of 7d52a77

- **Worked on:** audited HEAD `7d52a77` ("harden nil-safety") via `git diff HEAD~1`
  after confirming the worktree was clean; bumped the release to **v0.3.4** across
  `SuperSwingTimer.toc:8`, `SuperSwingTimer_Constants.lua:59`,
  `SuperSwingTimer_Config.lua:2233,2531`, the TOC assertion
  `SuperSwingTimer_Tests.lua:152` and the harness mock `run_tests.lua:111`; added the
  `## v0.3.4 - 2026-11-12` CHANGELOG section and synced README (badge, What's New,
  settings mock, Recent Releases).
- **Audit result:** nearly every "nil-safety" hunk in `SuperSwingTimer_ClassMods.lua`
  and `SuperSwingTimer_State.lua` is a provable no-op (reading a table with a nil key
  is legal, and the duration comparisons already sit behind `type()` checks). The one
  real guard is `SuperSwingTimer_UI.lua:1798` `if not t or t.state ~= "swinging"`.
- **Finding (latent defect, NOT fixed):** `LibClassicSwingTimerAPI.lua:635-648` lost
  `local offset = now - unit.pauseSwingTime` while lines 638/647 still add `offset`.
  Unreachable in the shipped addon — the TOC loads neither vendored swing lib nor
  LibRangeCheck, and nothing outside `Lib/` references them. Invisible to both linters
  (`.luacheckrc` excludes `Lib`; `.luarc.json` gained an `offset` global).
- **State:** gates 195/195 tests, `luacheck .` 0 warnings / 0 errors in 15 files,
  `luac5.1 -p` clean. Worktree carries the 7-file version/docs diff, uncommitted.
  No product-code fix applied (not authorized). Mnemon: Document
  `SuperSwingTimer v0.3.4 release (2026-11-12)` created, 6 facts + pointer refreshed.
- **Next step:** operator decides on the `offset` restore (and dropping the `.luarc`
  global), then verifies v0.3.4 in-game; `MEMORY.md` still says v0.2.7 / 150 tests.

## 2026-11-12 — exact distance bar + stance `?` diagnosis

- **Worked on:** operator reported the Forever distance bar stuck grey and the
  aspect/stance icon showing `?` with the combat/encounters CVar on. Rebuilt
  `SuperSwingTimer_Forever.lua` §10 so the bar reads **exact yards**:
  `ClosestUnitPosition` → `UnitDistanceSquared` (sqrt; `checkedDistance == false`
  now ACCEPTED because it only means "not range-checked", see
  `Blizzard_UnitFrame/Shared/CompactUnitFrame.lua:1069`) → `UnitPosition`
  player/target with same-map, secret and finite guards. Fill is
  `(yards-5)/(41-5)*max`: full at ≤5 yd, empty at ≥41 yd.
- **Band contract (operator-stated):** 1-5 green, 5-8 yellow dead zone, 8-41
  blue, beyond 41 grey. `ns.GetForeverDistanceBandFromYards` now owns the colour
  because `GetHunterRangeState` falls back to `"outOfRange"` when every client
  range check answers nil — that fallback was painting a 20 yd target grey.
- **Secret safety:** secret readings still pass straight to `SetValue` untouched
  and are never compared, clamped or divided; coordinates that are secret return
  nil rather than being subtracted.
- **Gates:** 196/196 tests, luacheck 0/0 in 15 files, `luac5.1 -p` clean.
  Mutation proof: removing the position source fails `DistanceBar_ReadsCreatureDistanceFirst`;
  removing the exact-band override fails `DistanceBar_UpdatesFromDistanceApi`.
- **Stance `?` (still open):** the marker is drawn only for HUNTER + inCombat +
  inactive native slot + no shapeshift form. `stanceContainer:SetEnabled(true)`
  is a no-op (`SetEnabled` is not on the container mixin); `AddAuraSlot` shape is
  valid. `/sst diag` `auraGroup` now prints `stanceSlot=` and `shapeshiftIcon=`
  to separate "slot never created" from "slot exists, no aura matched".
- **Next step:** operator runs `/sst diag` (auraGroup + distance) in-game on
  Forever with the CVar on, then we pin the stance root cause.

## 2026-11-12 — 30×25 aura icons + sweep on both rows

- **Worked on:** operator asked for buff and debuff icons at 30w×25h, the same
  cooldown swipe on buffs, and (after checking) the answer was "debuffs can keep
  bar but not buffs, cooldown sweep on both".
  - Measured first: buffs rendered **23×18** (slider default 25 minus
    `BUFF_ICON_WIDTH_TRIM=2` / `BUFF_ICON_HEIGHT_TRIM=7`), debuffs **22×22**
    hardcoded — `db.foreverDebuffIconSize` had no DB default and no slider.
  - Added `ns.GetForeverIconDimensions(iconWidth)` (width = configured value,
    height = width × 25/30, 8 px clamp), deleted the trim constants, and routed
    buff + debuff dimensions through it. Debuff container now receives
    `width`/`height` and `withCooldown = true`; buffs unchanged
    (`withBar = false, withCooldown = true`).
  - DB: six per-class `*BuffIconSize` defaults → 30, `foreverDebuffIconSize = 30`,
    schema 66 → **67** with a step that only moves a stored 25/22 (custom sizes kept).
  - `/sst diag auraGroup` prints `debuffIcon=`.
- **Gates:** 198/198 tests, luacheck 0/0 in 15 files, `luac5.1 -p` clean.
  Mutations: 1:1 aspect fails `IconRows_ShareThirtyByTwentyFiveShape`; renaming the
  v67 step breaks the migration ladder tests.
- **Not verified:** the in-game look (30×25 proportion, debuff sweep) — operator
  needs to eyeball it after reload.
- **Next step:** operator checks icons in-game; stance `?` still needs the
  `auraGroup` readout (`stanceSlot=`) from a restricted encounter.

## 2026-11-12 — distance bar 0.0 yd regression + 0-test harness

- **Symptom:** operator reported the bar stuck green. His `/sst diag` line proved
  it: `band=outOfRange exactBand=melee src=unit dist=0.0yd` — `UnitDistanceSquared`
  answers **0 + checkedDistance=false** for a live hostile target on Forever.
- **Cause:** my v0.3.4 change accepted unchecked `UnitDistanceSquared` readings, so
  the bar read 0.0 yd → full + melee-green permanently. Blizzard gates on the same
  flag (`CompactUnitFrame.lua:1069`).
- **Fix:** the reader now requires `checkedDistance == true` (or a secret flag) for the
  squared source and otherwise falls through to exact `UnitPosition` math. Tests
  updated (checked converts; unchecked 0 and unchecked 400 both rejected). Mutation:
  re-accepting unchecked readings fails `DistanceBar_ReadsCreatureDistanceFirst`.
- **Harness regression found:** operator commit `8f3a094` switched groups to
  `WoWUnit:New(...)` but `run_tests.lua` only implemented `__call`, so the suite
  discovered **0 groups** while still printing "ALL TESTS PASSED". Added
  `WoWUnitMock:New`; also fixed the test's `ClosestUnitPosition` mock (it guarded on
  `unit ~= "target"` but the API takes a creature ID). Now 14 groups / 198 tests.
- **Still ambiguous:** if "ranged bar" means the Auto Shot swing bar, green is
  `useClassColors` (default true) returning the Hunter class colour for `ranged` — not
  a bug. Asked the operator to confirm which bar before touching colour logic.
- **Next step:** new `/sst diag` should show `src=position` (or a real `dist`), and the
  stance `?` still needs a restricted-encounter `auraGroup` readout.
