# WoW Forever (1.60.1.70790) gate audit — v0.3.0

**Evidence:** addon source at /home/sam/SuperSwingTimer-WoW and client source at
/home/sam/wow-ui-source, branch `forever`, read with `git show`/`git grep`.
Grades: `verified` (code/client source), `in-game`, `open`.

**Scope rule:** gate, never remove. Interface version out of scope.

## Client facts used (verified)

| Fact | Evidence |
|---|---|
| C_SwingTimer.EnableRangeCheck / IsTargetWithinSwingRange; PLAYER_SWING(swingDuration, swingType); PLAYER_SWING_RANGE_UPDATE | SwingTimerDocumentation.lua:11,23,43,54 |
| Enum.PlayerSwingType MainHand=0, OffHand=1, Ranged=2 | SwingTimerDocumentation.lua:71-81 |
| IsTargetWithinSwingRange returns nil when no check could be made | SwingTimerDocumentation.lua:23-39 |
| C_CombatLog.IsCombatLogRestricted() is the restriction query | CombatLogDocumentation.lua:69 |
| issecretvalue / scrubsecretvalues / scrub | FrameScriptDocumentation.lua:257,378,424 |
| C_Secrets predicates (HasSecretRestrictions, ShouldUnitSpellCastingBeSecret, ...) | SecretPredicateAPIDocumentation.lua |
| UnitAttackSpeed SecretWhenUnitStatsRestricted | UnitDocumentation.lua:682 |
| UnitCastingInfo / UnitChannelInfo SecretWhenUnitSpellCastRestricted | UnitDocumentation.lua:828,870 |
| UnitHealth SecretReturns; UnitHealthMax/UnitPower/UnitPowerMax SecretWhen* | UnitDocumentation.lua:1526,1472,2732 |
| UnitGUID / UnitName SecretWhenUnitIdentityRestricted | UnitDocumentation.lua:1241 (UnitGUID) |
| GetSpellCooldown SecretWhenCooldownsRestricted | SpellDocumentation.lua:309 |
| AuraData tables SecretWhenUnitAuraRestricted | UnitAuraDocumentation.lua:208,397 |
| UNIT_SPELLCAST_* spellID SecretWhenUnitSpellCastRestricted | UnitDocumentation.lua:4820,4848 |
| Legacy CombatLogGetCurrentEventInfo only under loadDeprecationFallbacks | Blizzard_DeprecatedCombatLog/Deprecated_CombatLog.lua:4-18 |
| Blizzard re-derives swing speed only on weapon change, not mid-swing | Blizzard_SwingTimer.lua:327-346 |

## Defects found and fixed (all verified)

| ID | File:line (pre-fix) | Defect | Fix applied |
|---|---|---|---|
| F1 | State.lua:118-120,706,753,755,794,811,813,829,830,905,906,979,981; ClassMods.lua:252-254 | `ns.SafeNumber(x) or tonumber(x)` re-read a value it had just proved secret | removed the `or tonumber` tail everywhere |
| F2 | Constants.lua:108-120 | IsRestrictedCombatLog returned true whenever C_SwingTimer existed, disabling every CLEU feature | now only C_CombatLog.IsCombatLogRestricted() |
| F3 | UI.lua:1573,2630,3057,3092; ClassMods.lua:675,794,7687 | UnitAttackSpeed compared raw (ADDON_LOADED path at 3057/2630) | ns.SafeNumber before every test |
| F4 | State.lua:131-142,996-1002 | legacy GetSpellCooldown returns compared raw | SafeNumber + secret-enabled guard |
| F5 | Constants.lua:261-279 | AuraData table could be secret; fields indexed before probing | table probed first; fields SafeString/SafeNumber |
| F6 | Constants.lua:125-143 | showSwingTimer forced to "1" on disable, original never restored | capture once in DB, restore on disable |
| F7 | State.lua:851-856 + 692-711 + UI.lua:1786 | PLAYER_SWING duration overwritten by throttled speed sync 0.1s later | t.nativeSwingUntil guards both syncs; cleared in ResetTimer |
| F8 | ClassMods.lua:4750,4798,4817,7829,7956,8455,8954,8955,8997,8998 | secret UnitPower/UnitHealth became 0 | skip update instead of substituting 0 |
| F9 | Constants.lua:226,229; UI.lua:1670; Weaving.lua:455,462 | UnitCastingInfo/UnitChannelInfo times used raw | ns.Scrub on the payload |
| F10 | State.lua:948-968 | UNIT_SPELLCAST_* spellID compared raw | ns.Scrub before every comparison |
| F11 | SoD.lua:331-334 | CLEU listener registered without the restriction gate | gate added; payload scrubbed |
| F12 | ClassMods.lua:5625-5645 | IsTargetWithinSwingRange un-pcall'd; nil semantics ambiguous | pcall + nil = unknown |
| F13 | State.lua:526,534,565-568 | UnitGUID/UnitName compared raw | secret-safe branches |
| F14 | SuperSwingTimer.lua:1223-1225 | UnitClass used as table key while identity-restricted | SafeString + UnitClassBase fallback |
| F15 | Diag.lua:391-414 | events check treated PLAYER_SWING and CLEU as exclusive | reports each registration independently |
| F16 | Weaving.lua:42; State.lua:239 | UnitSpellHaste/GetRangedHaste arithmetic on secret | SafeNumber first |
| F17 | SoD.lua:280-296 | GetPlayerAuraBySpellID fields compared raw | table/field probes |

## Behaviour preserved on Classic Era / TBC Anniversary / Titanforge

Every guard is capability-gated: `issecretvalue` / `scrubsecretvalues` /
`C_CombatLog.IsCombatLogRestricted` do not exist on those clients, so
`ns.IsSecretValue` returns false, `ns.Scrub` returns its arguments unchanged,
and `ns.SafeNumber` returns the same number `tonumber` did. No feature was
removed; the CLEU/PLAYER_SWING split still follows the client capability.

## Verification

- `lua5.1 run_tests.lua` 171/171
- `luac5.1 -p` all 14 files OK
- `luacheck .` 0 warnings / 0 errors
- Regression proofs (fix removed in a temp copy, test fails):
  - t.nativeSwingUntil guard removed -> ForeverGate_NativeSwingDuration_SurvivesSpeedSync fails
  - `or tonumber` restored -> ForeverGate_SecretAttackSpeed_DoesNotThrow fails

## Open (needs in-game evidence)

- Whether 1.60.1 actually restricts unit stats/power/cooldowns in normal play;
  every path is now gated either way.
- Hunter range helper quality on Forever: IsTargetWithinSwingRange may return
  nil until a range check is enabled; behaviour is now "unknown", never
  "out of range".
---

## Second pass (2026-11-06, post-review) — pass-through + coverage

Operator asked for a second full pass: enterprise-grade quality, no feature lost
to secret data, and correct pass-through. Findings below are new since the first
pass; all are `verified`.

### Pass-through rule (client-documented)

Status bars and font strings accept secret arguments from tainted code:
- `SetValue` / `SetMinMaxValues`: `SecretArguments = "AllowedWhenTainted"`,
  `SecretArgumentsAddAspect = { Enum.SecretAspect.BarValue }`
  (SimpleStatusBarAPIDocumentation.lua:229-232, 355-358).
- `SetText` / `SetFormattedText`: `SecretArguments = "AllowedWhenTainted"`,
  aspect `Enum.SecretAspect.Text` (SimpleFontStringAPIDocumentation.lua:539-542, 664-667).
- `GetValue` / `GetText` then return a secret (`SecretReturnsForAspect`), so the
  addon must never read them back into arithmetic or comparisons.

Therefore a secret value is *displayed*, not dropped; only the numeric logic is
skipped.

### New findings and fixes

| ID | File:line (pre-fix) | Defect | Fix |
|---|---|---|---|
| F18 | ClassMods.lua:8960-9050 | Secret UnitPower/UnitPowerMax were skipped, losing the power bar entirely | raw values passed to SetMinMaxValues/SetValue/SetFormattedText; only thresholds/cache skipped |
| F19 | ClassMods.lua:4595,4605,8970 | UnitPowerType returns (powerType, powerToken) are SecretWhenUnitPowerRestricted, compared raw and fed back into UnitPower | SafeNumber/SafeString before use; class fallback when nil |
| F20 | State.lua:600,617 | Secret UnitName was replaced with "Enemy" | raw name kept and passed to SetText (AllowedWhenTainted); only comparison avoided |
| F21 | UI.lua:283-300,346-356 | SyncBarLabelText compared cached text (secret text would raise) | secret branch passes text straight to SetText without comparing |
| F22 | UI.lua:165-184 | GetMinMaxValues/GetValue can return secret after a pass-through bar; arithmetic would raise | secret BarValue short-circuits to fraction 0 |
| F23 | State.lua:1460-1560 | C_CombatLog.GetCurrentEventInfo is SecretReturns; only 3 of 7 used fields were scrubbed. CLEU + PLAYER_SWING could both start the same swing | all 7 fields scrubbed + IsSecretValue bail; nativeSwingOwnsSwings keeps PLAYER_SWING as the single owner of swing starts/flashes |
| F24 | Constants.lua:380-418 | Legacy UnitAura fallback (loadDeprecationFallbacks) read raw, un-pcall'd | pcall + scrub + nil bail |
| F25 | Constants.lua:135-145 | No build-level capability gate; every value probed even on classic | C_Secrets.HasSecretRestrictions() read once; classic skips all probes |
| F26 | State.lua:566 | UnitAttackSpeed("target") compared raw | ns.SafeNumber |

### Coverage re-check

Full scan of all 194 secret-bearing function entries in
`Interface/AddOns/Blizzard_APIDocumentationGenerated/*.lua` (origin/forever)
cross-referenced against every runtime .lua file. Remaining APIs the addon
touches are all gated: UnitAttackSpeed, UnitRangedDamage, UnitPower,
UnitPowerMax, UnitPowerType, UnitHealth, UnitHealthMax, UnitGUID, UnitName,
UnitClass, UnitSpellHaste, GetRangedHaste, UnitCastingInfo, UnitChannelInfo,
C_Spell.GetSpellCooldown, GetSpellCooldown, C_UnitAuras.GetAuraDataByIndex,
C_UnitAuras.GetPlayerAuraBySpellID, C_CombatLog.GetCurrentEventInfo,
UnitAura (legacy), issecretvalue/scrubsecretvalues. Frame getters are only read
on frames the addon itself populates, except the power bar, which is handled by
the secret BarValue guard.

### Verification (second pass)

- 173/173 tests, luac clean, luacheck 0/0.
- New tests: ForeverGate_SecretLabelText_IsPassedThrough,
  ForeverGate_NoSecretRestrictions_FastPath.
### Follow-up within the second pass

- Removed every `type(api) == "function" and api(...) or nil` pattern that
  applied `or` to a raw API return (8 sites: UnitAttackSpeed x3,
  UnitRangedDamage x2, UnitPower/UnitPowerMax, UnitName). Truthiness on a secret
  value is not a documented-safe operation; each site now assigns inside an
  `if type(...) == "function"` block and converts with ns.SafeNumber/SafeString
  afterwards.
- `ns.Scrub` now strips secrets itself (fixed arity 11) when
  `scrubsecretvalues` is unavailable or raises, so callers can always trust
  its output.
- SoD aura `applications or count` replaced with two SafeNumber calls.
---

## Hotfix 2026-11-07 — in-game report: hunter ranged bar never resets

**Symptom (operator, in-game):** "hunter ranged bar is not resetting and auto shot
isnt firing other then first shot, melee swing is working."

**Evidence:** the preceding in-game error was
`attempt to perform numeric conversion on a secret number value` at
`SuperSwingTimer_State.lua:241` (120x), thrown from
`GetPlayerRangedHastePercent` via `SyncRangedTimerSpeed`.

**Root cause (verified by code path):** `ns.StartSwing("ranged", ...)` calls
`GetPlayerRangedHastePercent()` before it writes the timer. The fail-open secret
detector (see below) made that function convert a secret number, so **every
ranged start threw before `t.state`/`t.lastSwing` were set**. Melee never calls
that function, which is exactly why melee kept working.

**Detector fail-open (verified):** `ns.IsSecretValue` had two shortcuts that
could answer "not secret" for a restricted value:
1. `C_Secrets.HasSecretRestrictions() == false` disabled all probing.
2. A probe self-test returned `false` when `issecretvalue(1)` raised.
Both removed. Detection now: client probe (only trusted when it says "secret")
→ behavioural probe (math.abs for numbers, upper + table-index for strings,
`next` for tables). `SafeNumber` also pcall-wraps `tonumber` and re-verifies
the converted value with the arithmetic probe.

**Ranged resilience:** the CLEU `SPELL_CAST_SUCCESS` Auto Shot branch is restored
as a fallback when `PLAYER_SWING` does not deliver a ranged swing, guarded by a
1 s window against `rangedTimer.lastNativeStartAt` so one cycle is never started
twice. Melee stays owned by `PLAYER_SWING`.

**Diagnostics added:** `/sst diag` now reports
`secrets: restrictions=... rangedHaste=secret|plain attackSpeed=... power=...`
and
`ranged: state=... dur=... lastSwing=... repeat=... cd=... swingEvent=... cleuAutoShot=... cleuRestricted=...`.

**Regression test:** `ForeverGate_ProbeFailure_DoesNotDisableGuard` fails with the
old self-test restored (proved in a temp copy) and passes with the fix.
---

## Hotfix 2 2026-11-07 — the 120x error persisted (2944x)

**Symptom:** identical traceback, `State.lua:241`, `haste=<secret number>`,
after the first detector fix.

**Why the first fix missed it:** the behavioural probe used `math.abs`. The
in-game error proves `math.max` raises on a restricted number, but `math.abs`
does not — so `ns.IsSecretValue` answered "plain", `SafeNumber` handed the
secret back, and the call-site `math.max` raised.

**Fix (three independent layers):**
1. `ns.IsSecretValue` numeric probe is now `pcall(math.max, value, value)`.
2. `ns.SafeNumber` = `IsSecretValue` → `ns.Scrub(value)` (documented
   `scrubsecretvalues`, returns nil for a secret) → `pcall(ToPlainNumber)`
   where `ToPlainNumber` ends in `math.max(number, number)`.
3. `GetPlayerRangedHastePercent` wraps getter + `tonumber` + `math.max` in one
   `pcall`; any failure returns 0.

**Proof:** new test `ForeverGate_ConversionGuard_CatchesUndetectedSecret`
simulates the client exactly — `issecretvalue` returns false and `math.max`
raises for the sentinel — and asserts `SafeNumber` returns the fallback. It
fails when the conversion guard is removed (verified in a temp copy).

**Remaining unknown (open):** whether the client's `pcall` preserves the taint
context. If it does not, layers 1-2 could be bypassed, which is why layer 3
exists and why `/sst diag` reports the live `secrets` line.
