# Deep Audit Report — SuperSwingTimer-WoW

**Date:** 2026-10-14
**Scope:** Performance, quality, effectiveness, cross-branch compatibility (classic_era + classic_anniversary)
**Test baseline:** 82/82 passing, luacheck 0 warnings/errors

---

## 1. Executive Summary

The addon is well-engineered: clean module split, TSDoc on most functions, a headless test runner, luacheck-clean, and a thoughtful OnUpdate hook system. The two biggest risk areas are (a) cross-branch aura API differences that the `ns.UnitAura` normalizer only partially covers, and (b) ranged/auto-shot speed resolution on the Legion-based TBC 2.5.5+ client where `UnitRangedDamage` returns min damage instead of weapon speed. Both are already partially mitigated but have edge cases.

---

## 2. UnitAura Differences (classic_era vs classic_anniversary)

### 2.1 What the branches return

| Branch | Global `UnitAura` source | Return shape |
| --- | --- | --- |
| classic_era 1.13.x | C function | A: `name, rank, count, debuffType, duration, expTime, caster, stealable, spellID` (no icon) |
| classic_era 1.15.x | C function | B: `name, rank, icon(str), count, debuffType, duration, expTime, caster, stealable, spellID` |
| classic_anniversary 2.5.5+ (deprecation fallbacks ON) | Lua shim → `AuraUtil.UnpackAuraData` | C: `name, icon(FileID), applications, dispelName, duration, expTime, sourceUnit, stealable, nameplateShowPersonal, spellID, canApplyAura` |
| classic_anniversary 2.5.5+ (deprecation fallbacks OFF) | C function | B (original TBC shape, icon is a string path) |

### 2.2 Current normalizer (`ns.UnitAura` in Constants.lua)

The normalizer detects shape by `type(r3)` and `type(r10)`:

- `r3 == "string"` → Shape B/D (icon string)
- `r3 == "number" and r10 == "number"` → Shape C (TBC anniv)
- else → Shape A (classic 1.13)

### 2.3 Findings & recommendations

1. **Shape C detection is fragile when `spellID` is nil.** If an aura has no spellID (rare but possible for some auras), `r10` is nil and the normalizer falls through to Shape A, misreading `applications` as `count` and `dispelName` as `debuffType`, and losing the icon/spellID. **Fix:** also detect Shape C by checking `type(r4) == "string"` (dispelName) combined with `type(r7) == "string"` (sourceUnit like "player"/"target"), or by checking `type(r9) == "boolean"` (nameplateShowPersonal). Add a fallback: if `r3` is number and `r9` is boolean → Shape C.

2. **Icon type inconsistency.** Shape C returns `r2` (FileID number) as icon; Shape B returns a string path. Consumers (SoD.lua, ClassMods) store `icon` and pass to `SetTexture`. Both numbers and strings work with `SetTexture`, so this is fine, but any code doing string operations on `icon` would break. Audit consumers: `GetHelpfulAuraData`/`GetHarmfulAuraData` in ClassMods only store/pass through — OK. SoD.lua stores `icon` — OK.

3. **`UnitBuff`/`UnitDebuff` convenience wrappers** call `ns.UnitAura` with filter. Good. But SoD.lua and ClassMods call `ns.UnitAura(unit, idx, filter)` directly with up to 40 iterations. Consider capping and using `C_UnitAuras` directly on modern clients for O(1) lookup by spell ID (already done in SoD.lua via `GetPlayerAuraBySpellID`). **Recommendation:** extend the O(1) `GetPlayerAuraBySpellID` fast path to ClassMods aura scans where the unit is "player" and a spell ID is known.

4. **Missing `C_UnitAuras` direct path for non-player units.** `C_UnitAuras.GetAuraDataBySpellName` exists and is faster than linear scan. For target/focus auras, consider using it when available.

---

## 3. Auto Shot Differences (classic_era vs classic_anniversary)

### 3.1 Findings

- `UnitRangedDamage("player")` on TBC 2.5.5+ (Legion-based client) returns **min damage** instead of weapon speed. The addon already handles this via cached `t.speed` from `GetAutoShotCooldown()` (spell 75).
- On classic_era, `UnitRangedDamage` returns weapon speed correctly (first return value).
- `GetAutoShotCooldown()` uses `C_Spell.GetSpellCooldown` with legacy fallback and name-based lookup. Good.
- `ns.hunterAutoRepeatActive` tracks auto-repeat state via `C_Spell.IsAutoRepeatSpell` / legacy. Good.

### 3.2 Recommendations

1. **Cache invalidation on weapon swap.** When the hunter swaps ranged weapons, `t.speed` may be stale until the next auto-shot. Consider hooking `PLAYER_EQUIPMENT_CHANGED` to invalidate `t.speed` and re-resolve via `UnitRangedDamage` (classic) or force a `GetAutoShotCooldown` refresh.

2. **Haste changes.** `SyncRangedSpeedWithHaste` already handles haste. But `UnitRangedDamage` on classic_era returns base speed (not haste-adjusted). The addon uses `EstimateSpeedFromHaste` as fallback. Verify this path is exercised in tests (it is — `SST-Weaving` covers haste scaling).

3. **Auto-shot cast window.** The hidden cast window (`hiddenCastWindowStart/Duration`) is invalidated on speed change. Good. Ensure it's also invalidated on haste change (currently `SyncRangedSpeedWithHaste` sets `t.hastePercent` but does it reset the window? Check: in the autoShotStart branch it sets `t.hiddenCastWindowStart = nil`. In the fallback branches it does NOT reset the window. **Potential bug:** if speed changes via the fallback path, the hidden cast window may be stale. **Fix:** reset `t.hiddenCastWindowStart/Duration` in all branches of `SyncRangedSpeedWithHaste`.

---

## 4. Performance Findings

### 4.1 OnUpdate hot path

- `ns.OnUpdate` iterates `ns.OnUpdateHooks` (array) every frame. Good — O(n) with n ≈ 10-15 hooks. No allocation.
- `CoreRenderHook` calls `UpdateMeleeBar`/`UpdateRangedBar` etc. each frame. These are the hot functions. Need to verify they don't allocate tables per frame.

### 4.2 Specific hot-path concerns

1. **`pairs()`/`ipairs()` in render path.** 203 `pairs` + 167 `ipairs` across files. Many are in config/initialization, but some may be in per-frame code. **Recommendation:** audit `UpdateMeleeBar`, `UpdateRangedBar`, `UpdateGcdTicker` for per-frame table allocation; hoist constant tables to module scope.

2. **String concatenation in loops.** 258 `for` loops. Check for `..` inside loops building frame names. **Recommendation:** use `string.format` with cached format strings, or pre-compute names.

3. **`GetTime()` vs `GetTimePreciseSec()`.** 8 calls to `GetTime()` remain (in ClassMods lines 210, 1394, 1587, 8922; Constants 12, 34; Weaving 23). The addon has a precise clock (`ns.GetAlignedTime()`). **Recommendation:** replace remaining `GetTime()` calls with `ns.GetAlignedTime()` for consistency and precision, except where WoW API expects `GetTime()` domain (cooldown timestamps). Actually `GetAlignedTime()` IS aligned to GetTime() domain, so it's safe.

4. **`pcall` in hot path.** `GetAutoShotCooldown` uses `pcall(C_Spell.GetSpellCooldown, ...)`. This is called from `StartSwing` and `SyncRangedSpeedWithHaste`, not every frame, so acceptable. But `C_Spell.GetSpellCooldown` may be called frequently during haste sync. Consider caching the cooldown result for ~0.1s.

5. **Aura scanning loops.** ClassMods scans up to 40 auras per frame in some hooks (e.g., Seal Vengeance, debuff bars). **Recommendation:** cache aura results and only re-scan on `UNIT_AURA` events, not every frame. The addon already has event-driven updates in places; ensure aura-dependent visuals use event invalidation rather than per-frame polling.

### 4.3 Memory

- `DeepCopyDefaults` in MigrateDB allocates a full copy of defaults on first load. Fine (once).
- SavedVariables migration runs on every load. The `IsVisibleDefaultColor` helper is defined inside `MigrateDB` — minor closure allocation. Not hot.

---

## 5. Quality Findings

### 5.1 Error handling

- Heavy use of `rawget(_G, ...)` for WoW API access — good for testability and nil-safety.
- `pcall` used in `GetAutoShotCooldown` and a few other spots. Good.
- Missing nil checks in a few places: `ns.timers[slot]` is checked in `StartSwing`. Good.

### 5.2 Code organization

- `SuperSwingTimer_ClassMods.lua` is 9202 lines — very large. **Recommendation:** split into per-class modules (e.g., `ClassMods_Hunter.lua`, `ClassMods_Paladin.lua`) loaded conditionally. This reduces parse time and memory for non-relevant classes. However, this is a large refactor; weigh against benefit.

- `SuperSwingTimer_Config.lua` is 5385 lines. Consider splitting UI config from data.

### 5.3 Testing

- 82 tests, all passing. Good coverage of GCD ticker, rogue gate, restack, weaving.
- **Gap:** No tests for `ns.UnitAura` normalizer across the 4 shapes. **Recommendation:** add unit tests feeding mock return tuples for Shapes A/B/C/D and assert normalized output. This is high-value given the cross-branch risk.

- **Gap:** No tests for `SyncRangedSpeedWithHaste` fallback branches or hidden cast window invalidation.

### 5.4 Documentation

- TSDoc is thorough. Good.
- `API_AUDIT_REPORT.md` exists — review for staleness.

### 5.5 Linting

- luacheck clean. Good.
- Consider adding `luacheck` to CI (GitHub Actions) if not present.

---

## 6. Effectiveness Findings

### 6.1 Cross-branch compatibility

- The addon targets both classic_era and classic_anniversary via a single codebase with runtime detection. This is the right approach.
- The `ns.UnitAura` normalizer is the linchpin. Strengthening it (finding 2.3.1) is the highest-impact fix.

### 6.2 Hunter-specific

- Auto-shot speed resolution is robust but has the hidden-cast-window staleness edge case (finding 3.2.3).
- Range helper visual (`UpdateHunterRangeHelperVisual`) — verify it uses `UnitRange` correctly.

### 6.3 Event-driven vs polling

- The addon uses OnUpdate hooks for rendering (correct — bars need per-frame updates).
- Aura-dependent logic should be event-driven (`UNIT_AURA`). Verify ClassMods hooks don't re-scan auras every frame unnecessarily.

---

## 7. Recommended Action Plan (prioritized)

### P0 (correctness / cross-branch)

1. Strengthen `ns.UnitAura` Shape C detection (add boolean/position checks) — prevents spellID loss on TBC anniv.
2. Reset `hiddenCastWindowStart/Duration` in all branches of `SyncRangedSpeedWithHaste`.
3. Add unit tests for `ns.UnitAura` normalizer (Shapes A/B/C/D).

### P1 (performance)

1. Audit `UpdateMeleeBar`/`UpdateRangedBar`/`UpdateGcdTicker` for per-frame table allocation; hoist constants.
2. Replace remaining `GetTime()` calls with `ns.GetAlignedTime()`.
3. Cache `GetAutoShotCooldown` result for ~0.1s to reduce `pcall` overhead.
4. Move aura scanning to event-driven invalidation where possible.

### P2 (quality / maintainability)

1. Split `SuperSwingTimer_ClassMods.lua` into per-class modules (large refactor — schedule separately).
2. Add `luacheck` to CI.
3. Review `API_AUDIT_REPORT.md` for staleness.

### P3 (effectiveness)

1. Extend O(1) `GetPlayerAuraBySpellID` fast path to ClassMods aura scans.
2. Hook `PLAYER_EQUIPMENT_CHANGED` to invalidate ranged speed cache.

---

## 8. Notes on wow-ui-source reference

- `classic_era` branch (1.15.9): `UnitAura` is C-level, returns icon as string (Shape B). `UnitRangedDamage` returns weapon speed.
- `classic_anniversary` branch (2.5.6): `UnitAura` is deprecated shim (if fallbacks on) returning `UnpackAuraData` shape (Shape C); `UnitRangedDamage` returns min damage on 2.5.5+.
- `AuraUtil.UnpackAuraData` is identical between branches (15 fields).
- Deprecated shims (`Deprecated_1_15_8.lua`, `Deprecated_2_5_5.lua`) are identical.

---

*End of audit.*
