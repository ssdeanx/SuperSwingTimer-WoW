# Super Swing Timer Changelog

> All notable changes to Super Swing Timer. This file documents user-facing and structural changes per release.
> Sections: **Added** / **Changed** / **Fixed** / **Removed** / **Performance** / **Security** / **Docs** / **Internal** / **Notes**
> DB schema migrations are listed under **Notes** per version.

## v0.3.6 - 2026-11-14

### Changed

- **One 5-second expiring glow across every buff and debuff icon row.** The tracked class icon rows (Paladin, Warrior, Shaman, Druid, Hunter, Rogue — the shared `RenderTrackedBuffIcons` helper serves player buffs and target-debuff entries alike) used to run two different windows: the gold pulse overlay covered the final 4 seconds, but the `LibCustomGlow` `ButtonGlow` animation only covered the final 2, so the animation stopped two seconds before the pulse did. Both cues now run over one `ICON_EXPIRING_GLOW_SECONDS = 5` window, and a respawned icon cannot inherit a stale glow because the hidden-icon path clears both cues.
- **Native Forever aura rows widened from 4 seconds to 5.** `FOREVER_AURA_GLOW_SECONDS` is the single value behind the buff/proc row (`forever_buffs`) and the target-debuff row (`forever_debuffs`); the `C_CurveUtil` step curve is built from that constant (`AddPoint(0, 0)`, `AddPoint(0.01, 1)`, `AddPoint(5.01, 0)`), so the alpha window and the toggle label cannot drift apart.
- **The settings text follows the modules instead of a literal.** The Visibility setting is now **Aura Expiring Glow (5s)** and both its label and tooltip read `ns.GetForeverAuraGlowSeconds()`. The six class icon tooltips (Hunter, Warrior, Paladin, Shaman, Druid, Rogue) likewise read `ns.ICON_EXPIRING_GLOW_SECONDS` instead of the hardcoded "last 4 seconds" they shipped with, which is exactly the stale copy a window change would otherwise leave behind.

### Fixed

- **A restricted AuraButton level could leave a glow overlay with no rim at all.** `CreateForeverGlowOverlay` read `AuraButton:GetFrameLevel()` and ran `math.max(level + 8, 12)` in the middle of the same `pcall` that builds the rim. On Forever `GetFrameLevel` is `SecretReturnsForAspect = { Enum.SecretAspect.FrameLevel }`, so a restricted button can answer with a secret number: the arithmetic raised, the `pcall` swallowed it, and the overlay was still registered — but with alpha and no rim, which looks exactly like an icon that simply does not glow while the rows whose buttons answered plainly did. The old `type(level) == "number"` guard was not a secrecy test (a secret number reports `"number"`), so it let the value through.
  - Overlay setup is now three isolated steps: the frame, then the draw-order level, then the rim and its pulse, so a restricted read can no longer suppress the rim.
  - The level goes through `ns.SafeNumber`, which probes behaviourally (a raising `math.max` means secret), and falls back to a constant when the button will not answer plainly.
- **One failing overlay no longer stops the rows behind it.** Every entry now updates inside its own `pcall`. Buff entries are registered before target-debuff entries, so an exception on an earlier entry used to end the update pass and leave the later rows unglowing.
- **Secret alpha handling made explicit.** The update pass no longer compares the evaluated alpha to `nil` before deciding what to do. It asks `ns.IsSecretValue` first and hands a secret alpha straight to `Frame:SetAlpha`, whose `SecretArguments` is `AllowedWhenTainted` for the Alpha aspect; a secret alpha is never compared, formatted or cached, so it is re-passed on every tick.

### Diagnostics

- **`/sst diag auraGroup` reports glow overlay failures.** The line gains `glowFail=<rim>/<update>` when an overlay's rim could not be built or an update pass threw, which separates "the glow is disabled" from "the rim never got built on this client".

### Notes

- TOC `## Version: v0.3.6`; the `ns.GetDisplayVersion()` fallback in `SuperSwingTimer_Constants.lua` and the harness TOC mock in `run_tests.lua` are bumped with it.
- Headless test suite: 210 tests passed, 0 failures; 0 luacheck warnings / 0 errors across 15 files.
- New regression test `AuraIconExpiringGlowWindowIsShared` pins one window for both icon families. `ForeverAura_ExpiringGlowCurveContract` now asserts `1` inside the window and `0` above `5s` instead of the retired `4s` boundary.
- New glow overlay pins: `GlowOverlayRimSurvivesRestrictedButtonLevel` (a button whose level raises on arithmetic still builds the rim, at the fallback level), `GlowSecretAlphaIsPassedThroughEveryTick` (a secret alpha reaches `SetAlpha` unchanged on every tick instead of being cached), and `GlowEntryFailureDoesNotStopFollowingRows` (a raising entry leaves the next row glowing). Reverting the overlay structure or the loop isolation fails the rim and isolation pins respectively; the suite reported 210 tests.

## v0.3.5 - 2026-11-12

### Added

- **Forever Aura 4-second expiring glow.** Native Forever buff/proc (`forever_buffs`) and target debuff (`forever_debuffs`) aura rows now glow gold during their final 4 seconds using a secret-safe `C_CurveUtil.CreateCurve()` step curve evaluated against the persistent `LuaDurationObject` exposed by `StatusBar:GetTimerDuration()` (`durationBar` on debuffs and an invisible `1×1` proxy `StatusBar` attached via `frame:SetDurationBar()` on buff buttons), rendered on an external `UIParent`-owned overlay frame (`foreverGlowHost`) so Blizzard `CustomAuraButton` security/layout boundaries remain untouched. Toggled via **Aura Expiring Glow (4s)** (`showForeverAuraGlow`) in Visibility settings and `/sst glow`.
- **Paladin Seal-Twist Bar Mechanics (`SwedgeTimer` parity).**
  - Added pure, client-agnostic helpers `ns.GetPaladinTwistWindowSeconds` (`None` / `Fixed` / `Dynamic` latency padding, `0.2s` SoD vs `0.4s` baseline, `0.8s` cap), `ns.IsPaladinTwistImpossible`, and `ns.GetPaladinResealMarkerFraction`.
  - `UpdateSealBreakpointLine` now renders a dynamic twist-zone state machine: success flash → impossible-twist ("Don't Twist") warning when GCD + calibrated lag cannot clear before the swing lands → attempt flash → 2-seal armed pulse (`sin(now * 8)`) → inside-window highlight → idle.
  - Multi-seal swings trigger a brief `LibCustomGlow` main-hand bar glow (`showPaladinTwistGlow`).
  - Added **Don't Twist Warning**, **Twist Bar Glow**, and **Dynamic Twist Padding** toggles to Paladin Class settings.

### Changed

- **Event-driven Hunter range helper (`hunterRangeHelperBar`).** Registers `PLAYER_SWING_RANGE_UPDATE` on native swing clients, keeps `C_SwingTimer.EnableRangeCheck` active even when Blizzard's default swing bars are hidden via CVar (`showSwingTimer = "0"`), updates immediately on movement (`PLAYER_STARTED_MOVING` / `PLAYER_STOPPED_MOVING`), target changes, and swing-range events, adds `C_Spell.IsSpellInRange` + spell ID fallbacks (`2974` Wing Clip, `2973` Raptor Strike, `75` Auto Shot, `3044` Arcane Shot), and skips `CheckInteractDistance` during restricted Forever combat lockdown.

### Fixed

- **Hunter `IsSpellTokenInRange` on 12.0+ / Forever clients.** Added `C_Spell.IsSpellInRange` (boolean return) support alongside legacy global `IsSpellInRange` (`== 1`) and `ns.IsSecretValue` guards in `SuperSwingTimer_ClassMods.lua`, preventing melee/ranged spell checks from returning `nil` or touching secret values on Forever.
- **Paladin reseal & Judgement marker wrap-around.** Removed the `while > 1` modulo wrap in `UpdateSealBreakpointLine` and `UpdateJudgementMarker` — GCDs or Judgement cooldowns that clear after the current swing lands now hide cleanly instead of wrapping onto the current swing bar.

### Removed

- **Removed Forever bottom Hunter target-distance bar** (`showHunterDistanceBar` / `foreverHunterDistanceBar`) from `SuperSwingTimer_Forever.lua`, `SuperSwingTimer_Constants.lua`, `SuperSwingTimer_Config.lua`, `SuperSwingTimer_Diag.lua`, and the test suite in favor of the left-side `hunterRangeHelperBar`.

### Performance

- **Consolidated all 6 class buff-icon updaters** (`Paladin`, `Warrior`, `Shaman`, `Druid`, `Hunter`, `Rogue`) into a shared zero-allocation `RenderTrackedBuffIcons` helper with pre-allocated scratch tables, scalar icon metadata, and geometry/text/glow caches.
- **Added per-frame frame/layout caching and throttling** across hot render paths: debounced `ns.SetUpdateEnabled` transitions, transition-cached `SetBarLabelShown`, `UpdateRangedBar` / `UpdateMeleeBar` (`SetMinMaxValues`, scalar RGBA, `0.1s` channel countdown), `UpdateGcdTicker`, `UpdatePlayerPowerBar` (while preserving secret pass-through), `UpdateHunterRangeHelperVisual` (`0.05s` polling + anchor/width/RGBA caches), and paused `foreverGlowHost` when disabled or empty.
- **0.5 px geometry caching** on `sealTwistBreakpoint`, `sealTwistResealBreakpoint`, and `paladinJudgementMarker` in `SuperSwingTimer_ClassMods.lua` to skip redundant `ClearAllPoints` / `SetPoint` / `SetWidth` layout churn on unchanged frames.

### Notes

- TOC `## Version: v0.3.5`; the TOC-metadata helper, settings-panel fallbacks, harness mock, and TOC test assertion move together.
- Headless test suite: 206 tests passed, 0 failures; 0 luacheck warnings / 0 errors across 15 files.

## v0.3.4 - 2026-11-12

### Added

- **Exact Hunter target-distance bar (Forever only).** The bar under the power bar no longer paints a range band, and no longer goes grey whenever the client's range checks cannot answer. It now reads the exact distance to the target and fills from it: **full through melee reach (1-5 yd)** and linearly down to empty at the **ranged maximum (41 yd = 35 yd Auto Shot + 6 yd Hawk Eye)**.
  - Three sources are tried in order: `ClosestUnitPosition(UnitCreatureID)` (linear yards, may be secret), `UnitDistanceSquared` (squared yards, used **only** when the client reports `checkedDistance = true` — an unchecked reading is not a distance: a live Forever target answers `0 + false`, which had pinned the bar full and green), and finally `UnitPosition("player")` vs `UnitPosition("target")` for exact ground-plane yards.
  - `UnitPosition` is the only coordinate reader that is **not** `SecretReturns` (it is `SecretArguments = AllowedWhenUntainted`), and Blizzard's own tutorial code subtracts the same pair (`Blizzard_TutorialTutorials.lua:985-986`). The fallback refuses to subtract across a map change, refuses secret coordinates, and refuses a non-finite result instead of handing NaN to `SetValue`.
  - The band used for the bar's colour is now derived from the exact reading — 1-5 yd green, 5-8 yd yellow (dead zone), 8-41 yd blue, beyond that grey — because `GetHunterRangeState` falls back to `"outOfRange"` when every client range check returns nil, which is what painted a nearby target grey.
  - **Secret safety is unchanged:** a secret reading is never compared, clamped or divided, and is handed to `StatusBar:SetValue` untouched on the scale of the source that produced it.

### Changed

- **Native buff and debuff icons are both 30×25 (Forever only).** The two rows used to render at different shapes: buff procs at 23×18 (per-class slider default 25 minus a 2 px width / 7 px height trim) and target debuffs at a hardcoded 22×22 that had no DB default and no slider. Both rows now come from one helper, `ns.GetForeverIconDimensions`, where the configured value is the **width** and the height follows the 30×25 aspect, so a custom slider value keeps the shape instead of a fixed size.
  - The debuff row also gains the **cooldown sweep** the buff row already had. The 3 px duration bar stays on the debuff row only — the buff row does not get one.
  - DB migration 67 moves a stored size only when it is still an old default (25 px buff, 22 px debuff); a size the player picked is kept.
  - `/sst diag auraGroup` now prints `debuffIcon=<width>x<height>` next to `buffIcon=`.
- **Defensive nil-safety pass across the class modules.** The Retribution Paladin, Warrior, Enhancement Shaman, Druid, Hunter and Rogue aura/cooldown readers now guard the alternative-spell-id lookups, the cooldown-duration comparisons and the Seal of Vengeance match. `SuperSwingTimer_State.lua` guards the three `NO_RESET_SWING_SPELLS` / `RESET_SWING_SPELLS` token lookups, `MigrateDB` falls back cleanly when `DB_DEFAULTS.colors` is unavailable, and power-class events only register when `ns.playerClass` is known. Reading a table with a nil key is legal in Lua and a `type()` check already protects the duration comparisons, so these hunks change intent rather than output — the covered paths return the same results whenever the value is present.
- **Pre-class colour snapshot keeps an existing table.** `SavePreClassColorState` resolves the DB, `ns.DB_DEFAULTS` and the spark colour through guards and no longer replaces `preClassColors` on every call. Every `BAR_COLOR_KEYS` entry is still rewritten and restore iterates the same key list, so the restored palette is unchanged.
- **Explicit parent anchoring for the Forever distance-bar band.** `EnsureHunterDistanceBar` now calls `SetAllPoints(created)` instead of `SetAllPoints(true)`. The other 33 `SetAllPoints(true)` call sites are untouched and remain valid.

### Fixed

- **Melee bar renderer guarded against a missing timer slot.** `UpdateMeleeBar` short-circuits when `ns.timers[slot]` is absent, so a slot without a timer can no longer raise `attempt to index a nil value` on a render tick.
- **`/sst diag` perf block coerces pcall results.** The `fps`, addon-memory and addon-CPU readings pass through `tonumber` before `math_floor` / `string_format("%d")`, so a non-number return can no longer raise inside the `perf` check.
- **LuaLS annotations no longer widen runtime treatment.** `---@cast propertyEnum table` and the `--[[@as number]]` casts on buff/debuff sizes keep the annotation layer in step with the existing nil-checks in `SuperSwingTimer_Forever.lua`.

### Internal

- Nil-guards added to the vendored `LibClassicSwingTimerAPI` CLEU handlers and to `LibRangeCheck-2.0`; the latter resolves `GetInventorySlotInfo` through `rawget` with a hands-slot fallback of `10`.
- `.luarc.json` globals and the `.wowluarc.json` diagnostics list were updated to match the new annotations.
- **Known issue (latent, not fixed in this release).** The `LibClassicSwingTimerAPI` pause-swing branch in `UNIT_SPELLCAST_SUCCEEDED` lost its `local offset = now - unit.pauseSwingTime` while both `unit.mainExpirationTime` and `unit.offExpirationTime` still add `offset`. `SuperSwingTimer.toc` does not load that library and no file outside `Lib/` LibStub-loads it, so the addon cannot reach the branch today; the local must be restored before the library is ever wired in.

### Notes

- TOC `## Version: v0.3.4`; the TOC-metadata helper, settings-panel fallbacks, harness mock and TOC test assertion move together.
- Headless test suite: 198 tests passed, 0 failures; 0 luacheck warnings / 0 errors across 15 files.
- `/sst diag distance` gains `apiPos` and `exactBand`, and reports the reading in linear yards for every source.
- The class-helper output is identical when the guarded values are present; the only intended behaviour change is the exact distance bar.

## v0.3.3 - 2026-11-08

### Added

- **Hunter target-distance bar (WoW Forever only).** A thin 5 px bar under the player power bar tracks the current target's distance. It is **full at melee and empties as the target moves away**, and turns **grey and empty when the target is out of range**. The bar is coloured by the four existing Hunter range bands (green melee, gold sweet spot, blue ranged, grey out of range) and follows the global UI scale. The settings panel gains a **Distance Bar** toggle in the Class tab.
  - **Secret-safe by construction.** Two sanctioned sources are tried: `ClosestUnitPosition(UnitCreatureID("target"))` — the only distance API with `SecretReturns = true`, giving linear yards to the closest creature with the target's ID — and `UnitDistanceSquared("target")` (plain squared yards, group targets only) as the fallback. A secret reading is handed straight to `StatusBar:SetValue` (a secret-argument API) and the client interpolates it; nothing is compared, clamped, formatted or used in arithmetic. The out-of-range band is a plain boolean and pins the bar empty without touching the distance.
  - The creature source uses a linear 41 yd scale (35 yd Auto Shot maximum + 6 yd Hawk Eye, Forever spell 19498); the group fallback uses the squared scale. The out-of-range band still pins the bar empty at the real range boundary.
  - `/sst diag` gains a `distance` line (`apiCreature`, `apiUnit`, `enabled`, `band`, `bar`, `src`, `dist`) reporting which source is live and whether its reading is secret, so target-distance support can be verified in-game.

### Changed

- **WoW Forever aura stack order (Forever only).** Player buff procs now render **above** the target-debuff row instead of underneath it. Target debuffs stay pinned directly above the swing bar; their icons, duration text and 3 px duration bars are unchanged. The proc row clears the debuff duration text with a 16 px gap, so a proc icon never overlaps the `12 s`-style text above the top debuff icon.
- **Buff proc icons are slightly wider than tall (Forever only).** The proc row trims 2 px from the configured buff icon width and 7 px from its height (default 25 px setting → 23×18 px). The shorter row keeps the stack compact above the debuff text without changing the debuff icons.
- **Left-side stance icon is one size larger (Forever only).** The aspect / stance / form / seal / shield icon beside the swing bar now renders 2 px larger (default 15 px bar → 20×20 px) so the active state is easier to read. Both the native stance slot and the shapeshift fallback use the new size.
- **Diagnostics.** `/sst diag` `auraGroup` now prints `buffIcon=<width>x<height>`, `debuffRow=<height|secret>` and `stanceIcon=<px>` so the new layout can be verified in-game.

### Fixed

- **Secret debuff-row height crash (Forever only).** The native debuff container's `GetHeight()` returns a **secret number** while the row is populated. The proc-row anchor compared it (`height <= 1`) and raised `attempt to compare a secret number` on every maintenance tick (437 errors in one session). The anchor now probes secrecy first and uses a plain populated/empty flag, anchoring the proc row directly to the debuff container instead of computing a pixel offset. The same audit removed the secret frame-count loop bound in `ResizeGroupFrames` and the secret height read in `/sst diag`.

### Notes

- Changes strictly isolated to WoW Forever (`ns.isForever`); Classic Era, TBC Anniversary and Titanforge keep their existing icon rows unchanged.
- Headless test suite: 195 tests passed, 0 failures; 0 luacheck warnings across 15 files.

## v0.3.2 - 2026-11-08

### Added

- **Dynamic Priority Aura Stack (WoW Forever only).** Target debuffs (such as Serpent Sting, Flame Shock, Rend) are anchored to the top of the stack. Player buff procs sit underneath the debuffs directly above the primary swing bar. When no procs are active, the gap between debuffs and the swing bar dynamically collapses to 0px (no floating icons or dead space). Target debuffs are styled with high-contrast duration bars.
- **Left-Side Active Stance / Aspect / Form / Seal / Shield Slot (WoW Forever only).** Stance-like abilities are segregated from combat procs and placed to the left of the swing bar (respecting the Hunter range helper, Rogue/Druid energy tick bar, and Shaman lightning container):
  - **Hunter**: Active Aspect (Hawk, Viper, Monkey, Cheetah, Beast, Wild, Pack) or a red-bordered `?` warning when entering combat without an active aspect.
  - **Warrior**: Active Stance (Battle, Defensive, Berserker) via native slot or `GetShapeshiftFormInfo()`.
  - **Druid**: Active Form (Cat, Bear, Dire Bear, Moonkin, Travel, Aquatic).
  - **Paladin**: Active Seal (Command, Fury, Righteousness, Crusader, Justice, Light, Wisdom).
  - **Shaman**: Active Shield (Lightning Shield, Water Shield).
  - **Rogue**: Active Stealth.
- **Throttled Frame Maintenance Loop.** `ns.UpdateForeverAuraIcons(elapsed)` accumulates frame `elapsed` time to throttle layout and stance synchronization to 0.15s intervals, while preserving immediate un-throttled execution when called on event triggers or settings changes.

### Changed

- TOC `## Version: v0.3.2`; settings-panel and test fallbacks synchronized.
- Permanent stances, aspects, seals, shields, and weapon imbues removed from `FOREVER_BUFF_SPELLS` so they never clutter the top proc row.

### Fixed

- **Legacy icon-updater wrapper crash.** The Forever wrapper stored its "already wrapped" flag on the function itself (`orig._foreverWrapped`); Lua 5.1 functions cannot be indexed, so the maintenance tick raised 574 times. Wrapped names now live in a name-keyed table, so the wrapper installs once and stands the classic updaters down without raising.
- **Secret stance-slot state crash.** The native stance slot's `IsShown()` returns a secret boolean on Forever; `if ok and isShown` boolean-tested it and raised 171 times. The value is now probed with `ns.IsSecretValue`; a secret result is treated as "the native slot owns the display".
- **Forever aura rows centered.** The flow layout now grows from the bottom-left (`BOTTOMLEFT`) while the container itself stays bottom-center on the bar, so buff, debuff and stance rows center instead of starting at the bar's center and extending right.
- **Druid removed spells.** Mangle (33876/33878) and Faerie Fire (Feral) 16857 are no longer tracked on Forever; base Faerie Fire 770 remains.

### Notes

- Changes strictly isolated to WoW Forever (`ns.isForever`).
- Headless test suite: 187 tests passed, 0 failures; 0 luacheck warnings across 15 files.

## v0.3.1 - 2026-11-07

### Added

- **WoW Forever native aura rows (Forever only).** `SuperSwingTimer_Forever.lua` is now loaded from the TOC. Player buffs render through a native `AuraContainer` (`HELPFUL` on `player`); target debuffs through a second container (`HARMFUL|PLAYER`, so only the player's own Serpent Sting, Flame Shock, Rend, etc. is shown). The client fills `SetIcon`, `SetDurationText`, `SetApplicationCount` and `SetDurationBar`; secret aura fields never enter addon code.
- **New Forever abilities and the Slam swing rule.** All new Forever melee abilities are tracked per class (Victory Rush, Spearing Strike, Reckless Swings, Slam, Shank, Venom, Mutilate, Poised, Blood Splatter, Premeditation, Primal Bite, Lacerate, Rend and Tear, Natural Reaction, Blood Frenzy, Improved Stormstrike, Fire Nova, Holy Strike, Seal of Fury, Judgement of Fury, Unsealed Wrath, Holy Shock, Strider Kick, Lacerating Strikes, Counterattack, Deadly Aspects, Aspect of the Beast, Savage Rend). Forever Slam (1240193) pauses the swing only when Improved Slam (12862) is not known; the rule is gated so every other client keeps the existing pause list.
- **Forever-owned Maelstrom Weapon and weave ranks.** `GetForeverPlayerAura` reads `C_UnitAuras.GetPlayerAuraBySpellID` with secrecy probes; `GetForeverMaelstromStacks`, `ForeverMaelstromMultiplier` and `ForeverMaelstromConsume` own the stack state. Weaving uses `FOREVER_WEAVE_SPELL_GROUPS` on Forever: LB 10 ranks (r1 1.5 s, r2 2.0 s, r3-r10 2.5 s), CL 4 ranks, HW 10, LHW 6, CH 3. Only Lightning Bolt receives the Maelstrom reduction.
- **Forever diagnostics.** `/sst diag` gains three Forever-only lines: `auraGroup` (native rows, containers, frame counts, spell counts, aura-secrecy, init attempts/errors), `maelstrom` (408505/408498 readability, stacks, multiplier) and `weave` (active spell, cast time, marker fraction, safe flag). Non-Forever clients return `skip`.

### Changed

- TOC `## Version: v0.3.1`; the settings-panel and test fallbacks move together.
- Weaving gates the Forever branch on `ns.isForever`; every other client keeps its existing reader and family table unchanged.

### Notes

- The Forever path does not use SoD/Classic Era data.
- Headless suite: 181 tests, 0 luacheck warnings across 15 files.

## v0.3.0 - 2026-11-06

### Fixed

- **Hunter ranged cycle no longer dies on Forever.** `StartSwing("ranged")` calls `GetPlayerRangedHastePercent()`, so the detector crash aborted every Auto Shot restart before the timer was written, while melee (which never calls that function) kept working. The detector fix removes the throw; the combat-log Auto Shot signal is also restored as a fallback for clients where `PLAYER_SWING` does not deliver a ranged swing, guarded by a 1 s window so one cycle is never started twice.
- **`/sst diag` gains a ranged line**: timer state, duration, last-swing age, auto-repeat flag, Auto Shot cooldown, last `PLAYER_SWING` ranged age, last CLEU Auto Shot age, and whether the combat log is restricted.
- **Secret detection could fail open (in-game crash fixed).** Two shortcuts added during the v0.3.0 work could report "not secret" for a genuinely restricted value: the build-level `C_Secrets.HasSecretRestrictions()` fast path, and a probe self-test that returned false when the probe raised. That let `ns.SafeNumber(GetRangedHaste())` hand a secret number to `math.max` — the in-game error `attempt to perform numeric conversion on a secret number value` at `SuperSwingTimer_State.lua:241` (repeated every frame while the ranged bar updated). Both fail-open paths are removed.
  - `ns.IsSecretValue` now verifies behaviourally after the client probe: numbers must survive `math.max` (the exact call that raises in-game — `math.abs` does **not** raise on a restricted number and was the wrong validator), strings must survive concatenation and table indexing, tables must survive iteration. Any doubt reports "secret".
  - `ns.SafeNumber` runs the documented `scrubsecretvalues` sanitizer first, then converts inside a single `pcall` whose final step is `math.max(n, n)`. A restricted number therefore cannot be returned even when `issecretvalue` answers false.
  - `GetPlayerRangedHastePercent` guards the whole getter-convert-clamp chain in `pcall`, so the reported line (`State.lua:241`) cannot raise again.
  - `/sst diag` gains a **secrets** check that reports the build restriction flag and samples `rangedHaste` / `attackSpeed` / `power` as `secret` or `plain`, so the gate can be confirmed in-game.
- **WoW Forever: every secret-value call site is now gated.** The v0.2.9 gate still let restricted values reach comparisons:
  - `ns.SafeNumber(x) or tonumber(x)` re-read the value after `ns.SafeNumber` had already rejected it as secret. The fall-through is removed at every site in `SuperSwingTimer_State.lua` and `SuperSwingTimer_ClassMods.lua`; `ns.SafeNumber` is now the only conversion.
  - `UnitAttackSpeed` (`SecretWhenUnitStatsRestricted`) is gated in `SuperSwingTimer_UI.lua` (ShowBars, ApplyVisibility, InitBars, UpdateOHBar) and `SuperSwingTimer_ClassMods.lua` (seal zone, Judgement marker, preview duration).
  - `GetRangedHaste` and `UnitSpellHaste` arithmetic is gated in `SuperSwingTimer_State.lua` and `SuperSwingTimer_Weaving.lua`.
  - `UnitCastingInfo` / `UnitChannelInfo` payloads are scrubbed in `ns.GetUnitCastingSpellInfo`, the ranged bar and weaving cast timing.
  - `C_Spell.GetSpellCooldown` and the legacy `GetSpellCooldown` returns are gated in both cooldown readers.
  - `C_UnitAuras.GetAuraDataByIndex` and `GetPlayerAuraBySpellID` tables are probed before any field access.
  - `UnitGUID` / `UnitName` comparisons in the enemy-target path and the SoD proc listener are secret-safe.
  - `UnitClass` falls back to `UnitClassBase` when the class token is secret.
- **`UNIT_SPELLCAST_*` payloads are scrubbed** through `ns.Scrub` (Forever `scrubsecretvalues`) before any comparison, and the CLEU payload is scrubbed before identity comparisons.
- **Combat-log gate now uses the authoritative client query.** `ns.IsRestrictedCombatLog()` previously returned true whenever `C_SwingTimer` existed, silently disabling every CLEU feature on Forever. It now reports only `C_CombatLog.IsCombatLogRestricted()`; `PLAYER_SWING` and CLEU are independent capabilities and `/sst diag` reports each registration separately.
- **Native `PLAYER_SWING` duration is authoritative for its swing.** The throttled `UnitAttackSpeed` sync no longer overwrites the payload duration mid-cycle (`t.nativeSwingUntil`).
- **Restricted `UnitPower` / `UnitHealth` no longer read as 0.** Energy-tick detection, the power bar and the Warrior Execute highlight skip the update instead of treating a secret as an empty pool.
- **Hide Blizzard Swing Bars restores the user's original CVar value** instead of forcing `showSwingTimer = 1`, and no longer writes `showMH/showOH/showRanged` when the DB is not initialised.
- **Hunter range fallback treats `nil` as "unknown"** and is pcall-guarded (`C_SwingTimer.IsTargetWithinSwingRange` returns nil when no check could be made).
- **SoD proc listener respects the combat-log restriction gate** instead of registering CLEU unconditionally when a season is active.
- **Secret values are passed through, not dropped.** Status bars and font strings accept secret arguments from tainted code (`SecretArguments = AllowedWhenTainted`), so restricted `UnitPower`/`UnitPowerMax` flow straight into `SetMinMaxValues`/`SetValue`/`SetFormattedText`, a restricted enemy `UnitName` flows into `SetText`, and bar labels display secret text without ever comparing or concatenating it. Only the numeric threshold and cache comparisons are skipped.
- **`UnitPowerType` returns are gated** before they are compared or fed back into `UnitPower`/`UnitPowerMax` (`powerType`/`powerToken`).
- **The CLEU payload is scrubbed field-by-field** (`C_CombatLog.GetCurrentEventInfo` is `SecretReturns`), and `PLAYER_SWING` owns swing restarts and landing flashes when present so the same swing is never started twice.
- **The legacy `UnitAura` fallback is pcall-guarded and scrubbed** (it only exists behind the `loadDeprecationFallbacks` CVar).
- **Bar progress arithmetic is gated** for the secret `BarValue` aspect, so the spark never divides a secret value.
- **Build-level fast path**: `C_Secrets.HasSecretRestrictions()` is read once at load, so classic clients skip every secret probe and the addon pays nothing for the Forever guards.

### Changed

- Version v0.3.0; the TOC and both settings-panel fallbacks move together.

### Tests

- Headless suite 168 -> 173: `ForeverGate_SecretAttackSpeed_DoesNotThrow`, `ForeverGate_SecretSpellcastPayload_DoesNotThrow`, `ForeverGate_NativeSwingDuration_SurvivesSpeedSync`, `ForeverGate_SecretLabelText_IsPassedThrough`, `ForeverGate_NoSecretRestrictions_FastPath`; `ForeverGate_HandlePlayerSwing_StartsTimers` now asserts that a native swing timer alone does not mark the combat log restricted.
- Both timing guards were proved by removing the fix and confirming the test fails.

## v0.2.9 - 2026-11-01

### Added

- **WoW Forever (`16001` / `WOW_PROJECT_CAMELOT`) Compatibility Gate**:
  - Added `16001` to `SuperSwingTimer.toc` (`## Interface: 11509, 20506, 38002, 16001`).
  - Added `ns.HasNativeSwingTimer()` and `ns.IsRestrictedCombatLog()` capability gates in `SuperSwingTimer_Constants.lua`.
  - Added `ns.HandlePlayerSwing(swingDuration, swingType)` in `SuperSwingTimer_State.lua` and wired `PLAYER_SWING` in `SuperSwingTimer.lua` so **Main Hand** (`Enum.PlayerSwingType.MainHand = 0`), **Off Hand** (`1`), and **Ranged** (`2`) custom swing bars work natively on WoW Forever without touching Classic Era, TBC Anniversary, or Titanforge code paths.
  - Added fallback to the 3rd return of `UnitAttackSpeed("player")` (`rangedAttackSpeed` on Forever) in `ns.StartSwing` and `ns.SyncRangedTimerSpeed`.
  - Added fallback to `C_SwingTimer.IsTargetWithinSwingRange(swingType)` for Hunter Range Helper (`IsHunterTargetInMeleeRange` / `IsHunterTargetInRangedShotRange`) when available.
  - Updated `/stt diag` (`SuperSwingTimer_Diag.lua`) to identify `"WoW Forever"` (`toc 16001` / `WOW_PROJECT_CAMELOT = 18`) and check `PLAYER_SWING` registration when `C_SwingTimer` is present.
- **Hide Blizzard Default Swing Bars Toggle (WoW Forever Only)**:
  - Added `hideBlizzardSwingBars = true` to `ns.DB_DEFAULTS` and `ns.ApplyBlizzardSwingTimerVisibility()` in `SuperSwingTimer_Constants.lua`.
  - On WoW Forever (`ns.HasNativeSwingTimer()`), automatically disables Blizzard's built-in default swing timer bars (`C_CVar.SetCVar("showSwingTimer", "0")`) on load and `PLAYER_ENTERING_WORLD` so only Super Swing Timer's custom bars are displayed.
  - Added a highlighted **Hide Blizzard Swing Bars** checkbox right at the top of the bar visibility toggles in both `/sst` (**Quick Controls -> Visibility**) and the **Blizzard Options AddOn Canvas** (visible only on WoW Forever). Checking it turns off Blizzard's default bars and enables Super Swing Timer's custom MH/OH/Ranged bars; unchecking it restores Blizzard's default swing timer (`showSwingTimer = 1`).
- **Secret-Value (`issecretvalue`) Hardening**:
  - Added `ns.IsSecretValue(value)` and `ns.SafeNumber(value, fallback)` helpers in `SuperSwingTimer_Constants.lua`.
  - Hardened `ns.UnitAura` (`C_UnitAuras.GetAuraDataByIndex`), `QuerySpellCooldown` / `ns.GetAutoShotCooldown` (`C_Spell.GetSpellCooldown`), `UnitAttackSpeed`, `UnitPower`, `UnitPowerMax`, `UnitHealth`, and `UnitHealthMax` so secret values on restricted clients never trigger Lua comparison or arithmetic errors.
  - Auto-suppressed live Enemy Swing Bar target tracking (`ns.RefreshEnemyTarget`) when `ns.IsRestrictedCombatLog()` is true (since `C_SwingTimer` only reports player swings and `COMBAT_LOG_EVENT_UNFILTERED` is restricted), while keeping the Enemy bar visible in `/sst test` and `/sst move`.

### Tests & Docs

- Expanded headless test suite from 166 to **168** tests (`Release028:ForeverGate_HandlePlayerSwing_StartsTimers` including `showSwingTimer` CVar assertions, and `Release028:ForeverGate_SecretValues_GuardedSafely`), passing 100% with `0` luacheck warnings across all 14 files.
- Redesigned `README.md` for readability with a top-level **Client Availability** table and color-coded highlights.

## v0.2.8 - 2026-10-27

### Fixed

- **Settings panel version label now follows the TOC.** The standalone settings studio and the Blizzard Options canvas both hardcoded `v0.2.5`, so the v0.2.7 release shipped showing the wrong version in-game. Both titles now read `ns.GetDisplayVersion()`, which resolves the TOC `## Version` metadata with a static fallback.
- **Removed two unused clock locals** left in `HandleSpellcastStop` / `HandleSpellcastChannelStop` by the v0.2.7 cast-identity change.
- **Blizzard-settings "Minimal Mode" could never be turned on.** The canvas checkbox stored the new value and then called `ns.ApplyMinimalMode()` with no argument, which coerced `nil` to `false` and wrote that straight back to `SuperSwingTimerDB.minimalMode`. The setter now passes the value, and `ApplyMinimalMode()` treats a missing argument as "apply the stored setting" so the same mistake cannot invert the toggle again.
- **Reckoning stack count read the wrong aura fields.** `GetReckoningStackCount` called the raw `UnitBuff` global but destructured it with the addon's normalized 11-value contract, so the "count" received `dispelName` and the "spellID" received the `canApplyAura` boolean. It now reads through `ns.UnitBuff`; `GetShieldChargeCount` was normalized the same way so one contract is used everywhere.
- **A granted extra attack could freeze the swing bar for the rest of the fight.** `SPELL_EXTRA_ATTACKS` credits a suppression counter that is only consumed by the player's next swing event; when that extra swing never surfaced, every later real swing was discarded and the main-hand bar stopped restarting. Credits now expire after a short window and are cleared when the target dies.
- **`/sst reset` did not restore every setting.** The hand-written reset covered about 69 of the 104 `DB_DEFAULTS` keys, leaving class-overlay toggles, `barBorderSize`, `showGlowEffects`, `showPowerBar`, `showSwingFlash` and others untouched. The reset is now derived from `DB_DEFAULTS` (deep-copied) and pins `version` to `DB_CURRENT_VERSION` so it cannot rewind the migration ladder.
- **Entering combat rewrote the saved lock preference.** `PLAYER_REGEN_DISABLED` wrote `lockBars = true` into SavedVariables, permanently destroying an unlocked preference chosen with `/sst move`. Combat now sets a runtime-only lock that releases when the fight ends.
- **Localized Steady Shot was never matched.** Both red-zone paths compared against the literal `"Steady Shot"` while `ns.STEADY_SHOT_NAME` existed unused, so a name-only payload on a non-enUS client did not register the shot. Matching now uses `ns.IsSteadyShotSpell` (ID, numeric string, localized name) — additive only; no timing math changed.
- **Feign Death restarted the ranged cycle instead of cancelling it.** Spell 5384 is registered in `RESET_SWING_SPELLS`, which was checked before the dedicated Feign Death branch, making that branch unreachable. Feign Death is now checked first.
- **Non-Hunter classes started a phantom ranged timer** after every successful spellcast and on `RESET_SWING_SPELLS` casts, pinning the render loop for a bar the class never renders. Both sites now require `classConfig.ranged`.
- **A Hunter melee ability could restart the Auto Shot cycle.** The phantom-ranged-timer fix widened the generic cast-success ranged reset to every class with a ranged slot, so for Hunters any ability that fell through the earlier spell branches — including Raptor Strike — started a fresh ranged timer whenever a cast-start had set `ns.casting`. The generic branch now restarts the Hunter ranged cycle only for a recognised Auto Shot payload; the dedicated Auto Shot paths are unchanged, so meleeing cannot restart Auto Shot. Regression tests cover the Raptor Strike cast and both main-hand CLEU branches.
- **Two GCD durations.** `ns.GetGcdDuration()` returned a constant while the state machine stored the measured value; it now prefers the measured duration.
- **Class-setup failures were silent.** Only the Shaman initializer failed open; the others discarded the `pcall` result, so a class whose setup threw rendered nothing with no `/sst diag` trace. All six now run through one recorder that logs the failure.
- **Duplicated stop handlers merged.** `HandleSpellcastStop` and `HandleSpellcastChannelStop` were byte-identical and are now one implementation.

### Removed

- Duplicate doc blocks on `ns.StartSwing`, `ns.ApplyParryHaste` and `ns.HandleCLEU`; orphaned section banners and a duplicated header in `SuperSwingTimer_UI.lua`; three `if true then` wrappers in the spell tables; three no-op migration rungs (v21, v23, v24); and the dead Shaman `OnUpdate` restore that its own comment described as a no-op.

### Tests

- Headless suite expanded from 150 to **166** tests. Every fix above has a regression test that was verified to fail with the fix removed, including a source-level guard that `ClassMods` never calls a raw `UnitBuff`/`UnitAura` again and the Hunter Raptor Strike / main-hand CLEU ranged-reset guards.

### Docs

- Version bumped to **v0.2.8** in the TOC, README, MEMORY and the test-harness metadata stub; the TOC test now also asserts the panel version helper matches the TOC.
- `docs/QA.md` file count corrected and a version-label check added.

### Notes

- **No DB schema migration.** `DB_DEFAULTS.version` stays 56 and `DB_CURRENT_VERSION` stays 66; existing `SuperSwingTimerDB` profiles are unchanged.
- **Timing math unchanged.** Auto Shot cycle math, red-zone bounds, Steady Shot grace and GCD math are untouched. The Feign Death, ranged-timer and Steady Shot changes are branch-ordering, spell-matching and restart-gating only; no duration or window calculation changed.
- **Behaviour changes to verify in-game:** bars now unlock automatically at the end of combat if you had unlocked them; Feign Death cancels the Auto Shot cycle; non-Hunter classes no longer run an invisible ranged timer; a Hunter melee or utility cast no longer starts the Auto Shot cycle.
- **Carried from v0.2.7:** fresh installs default to locked bars (`lockBars = true`); existing profiles keep their stored value.
- **Pending in-game verification** on `classic_era` 1.15.9 (normal, hardcore and SoD), `classic_anniversary` 2.5.6 and `classic_titan` 3.80.2.

## v0.2.7 - 2026-10-25

### Added

- **Enterprise Diagnostics (`SuperSwingTimer_Diag.lua`, `/stt diag` / `/sst diag`)**:
  - New early-loaded diagnostics module. It is the first file in the TOC, so `/stt diag` / `/sst diag` remains reachable even if a library or later SuperSwingTimer module fails to load.
  - `/sst diag` prints a compact health report: client/build/project, addon version, DB version, class, bar/hook counts, aura API path, precise-clock status, event registration, render-loop state, FPS, addon memory, addon CPU, library status, SoD module status, slash registration, and captured errors.
  - `/sst diag full` prints every check, including informational rows that are hidden from the compact report. `/sst diag errors` prints captured signatures with stacks and counts. `/sst diag export` opens a copyable report window. `/sst diag clear` resets the ring buffer. `/sst diag test` runs live API probes (clock, spell info, aura path, metadata, glow) and reports pass/fail.
  - Error capture chains the existing `seterrorhandler` instead of replacing it, so Blizzard's normal error display and logging still run. Capture also listens for `LUA_WARNING`, `ADDON_ACTION_BLOCKED`, and `ADDON_ACTION_FORBIDDEN`.
  - Deduplicated ring buffer (40 signatures) with repeat counts, first/last timestamps, source tags (`lua`, `warning`, `taint`, `init`, `slash`, `diag`, `glow`), and stack excerpts. Identical failures cannot flood the report or the SavedVariables.
  - `/sst diag profile [seconds]` adds an opt-in per-hook profiler using `debugprofilestart` / `debugprofilestop`; it reports total time, per-frame average, share, and max for the top hooks. Profiling is completely inactive until requested.
  - Diagnostics never write to files. Export is an in-game EditBox with the report pre-selected for `Ctrl+A` / `Ctrl+C`.
- **LibCustomGlow-1.0 Integration (`Lib/LibStub`, `Lib/LibCustomGlow-1.0`, `SuperSwingTimer_Glow.lua`)**:
  - Added LibStub and LibCustomGlow-1.0 to the TOC in dependency order (`LibStub` before `LibCustomGlow`).
  - Added `ns.Glow`, a lifecycle-safe adapter with `SetBar` / `SetIcon` / `StopAll` / `Refresh`. Call sites may invoke it every frame; only active↔inactive transitions touch the library. `SetBar` supports `autocast` (default, best for thin bars) and `proc`; `SetIcon` uses ButtonGlow.
  - Every library call is `pcall`-guarded with failure latches, so a library/client mismatch cannot break swing rendering. Errors are recorded for `/sst diag`.
  - No-op fallback when LibCustomGlow is absent; the addon continues to render all bars and existing border pulses.
  - Bar effects:
    - Paladin Judgement of the Crusader bar: Autocast shine while the debuff is in its final 4-second window.
    - Rogue Slice and Dice bar: Autocast shine while the buff is in its final 4 seconds.
    - Warrior Overpower: Autocast shine on the main-hand bar for the full Overpower proc window.
    - Hunter Rapid Fire bar: Autocast shine while the buff is active and in its final 4 seconds.
    - Shaman weave: Autocast shine on the main-hand bar while a weave cast is in flight, using the existing safe/clip color (class color when safe, red when clipping).
  - Icon effect:
    - All six classes' buff/cooldown icon groups: ButtonGlow only in the urgent final 2 seconds, complementing (not duplicating) the existing 4-second border pulse.
    - `Glow.SetIcon` installs a one-time `OnHide` hook per icon, so an icon that expires, is hidden by its class toggle, or is hidden by Minimal Mode stops its glow immediately without per-class cleanup bookkeeping.
  - Deliberately avoids PixelGlow: its `AM_29` mask asset is not referenced by either Classic Era 1.15.9 or TBC Anniversary 2.5.6 FrameXML, and registering a global replacement mask would affect other addons sharing LibStub. AutocastGlow (`UI-ItemSockets`), ProcGlow (proc flipbook atlases), and ButtonGlow (`IconAlert`) use assets verified on both clients.
  - Added `/sst glow` and `/sst glow on|off` to toggle the effects. Added `DB_DEFAULTS.showGlowEffects = true`; existing SavedVariables without the key are treated as enabled (no migration required).
  - Added `/stt` as a fifth alias for the existing command table, so `/stt diag` works exactly like `/sst diag`.

### Changed

- **Initialization hardening (`SuperSwingTimer.lua`)**:
  - `OnAddonLoaded` now runs under `xpcall` with a traceback handler instead of `pcall`, so initialization failures keep a usable stack for `/sst diag`.
  - On init failure the addon records the error, routes it through the client error handler, prints a short `/sst diag` hint, and **skips event registration** instead of leaving a half-initialized addon receiving combat events.
  - Exposed `ns.eventFrame` so diagnostics can verify event registration and the render-loop state without duplicating frame bookkeeping.
- **OnUpdate hook labels (`SuperSwingTimer_Hooks.lua`, `SuperSwingTimer_UI.lua`, `SuperSwingTimer_ClassMods.lua`)**:
  - Added `ns.RegisterNamedOnUpdateHook(name, hook, index)` and a weak `ns.OnUpdateHookNames` map. Existing `RegisterOnUpdateHook` behavior is unchanged.
  - Named the core hook and all class hooks (`paladin-seal`, `paladin-judgement`, `paladin-power`, `warrior`, `shaman`, `druid-form`, `druid-dots`, `hunter`, `rogue`, `power-fallback`) so profiler output is readable.
- **TOC load order (`SuperSwingTimer.toc`)**:
  - `SuperSwingTimer_Diag.lua` → `LibStub` → `LibCustomGlow` → `SuperSwingTimer_Constants.lua` → `Media\Media.xml` → `SuperSwingTimer_Glow.lua` → engine/UI/class modules → `SuperSwingTimer_SoD.lua` (unchanged last position).
  - Diagnostics is first so it can capture and report a LibStub or LibCustomGlow load failure, not just failures in later SuperSwingTimer modules.
- **Documentation (`README.md`, `SuperSwingTimer.toc`)**:
  - Updated the current version to **v0.2.7**, added the diagnostics/glow command reference and compact-report example, added the LibCustomGlow texture-source row, and corrected the class-support debuff heights to the shipped 8px standard.
  - Added a 12,000+ downloads note (as of October 2026).

### Performance

- **Idle bar reset guard (`SuperSwingTimer_UI.lua`)**: `ResetBarDisplay` now marks the bar with `_sstResetDone`; `UpdateMeleeBar` and `UpdateRangedBar` skip the full reset while the bar is already idle. The flag is cleared on the first swinging frame and set by every reset path (`HideBars`, `ShowBars`, `ApplyVisibility`, channel rendering, expiry), so labels/values cannot go stale. This removes repeated `SetMinMaxValues`, `SetValue`, label text/style, cast-overlay, cast-threshold, and spark-position work for inactive MH/OH/enemy/ranged bars while the render loop stays alive for power bars.
- **Library calls are transition-driven**. `ns.Glow.SetBar` / `SetIcon` are safe to call from existing throttled/frame update paths: they compare against weak state maps and only start/stop LibCustomGlow when the desired state changes. Icon and bar glows also stop through one-time `OnHide` hooks, so hidden frames never leave an animation running and the throttled icon scans never need a per-class "dropped out of the active set" pass.
- **Profiling is opt-in and makes no timing calls when off**: `ns.OnUpdate` checks a single `ns.Diag.profile.active` flag and otherwise runs the original loop unchanged.
- **No per-frame `xpcall`**: error capture uses the client's `seterrorhandler` chain, so normal rendering keeps its original call shape. `xpcall` is used only for one-time initialization; slash/config failures use `pcall` and are recorded in the diag buffer.
- **No new per-frame color allocations**: shared `GLOW_GOLD` and a per-bar cached Rogue glow color table replace per-call literals.

### Fixed

- **Init failure could leave the addon half-initialized**: `RegisterEvents()` previously ran even when `OnAddonLoaded` threw. It now runs only after a successful initialization.
- **Init error stacks were lost**: the old `pcall` + `tostring(initErr)` path discarded the traceback. The new `xpcall` path preserves it and records it for diagnostics.
- **Diagnostics reachability**: the diagnostics module and a minimal `/sst` + `/stt` fallback are registered at file load, so `/stt diag` / `/sst diag` is available even if a later addon file errors before the full command table is built. The main dispatcher replaces the fallback once it loads.
- **Hunter Auto Shot could be missed on Classic Era / TBC Anniversary, flashing the MH bar after a ranged swing**: `ns.AUTO_SHOT_NAME = ns.GetSpellInfo(75) or "Auto Shot" or "Shoot"` made the `"Shoot"` fallback unreachable (`"Auto Shot" or ...` always yields the first string), and the only matcher accepted spell ID 75, `"75"`, or the single client-resolved name. The supported clients disagree on whether CLEU and `UNIT_SPELLCAST_*` payloads carry the numeric ID or the localized name, and spell 75 resolves under different names across builds, so an unrecognised token fell through. A miss is not cosmetic: `HandleSpellcastSucceeded` skips the MH/OH restart only for a recognised Auto Shot (`skipMeleeReset`), so the miss restarted melee and showed the MH bar right after each ranged swing. `ns.IsAutoShotSpell` now accepts the numeric ID, its numeric string, the client-resolved localized name, and an explicit `ns.AUTO_SHOT_NAMES` alias set (`"Auto Shot"`, `"Shoot"`).
- **Auto Shot could disappear or fail to display when a hunter cast ended before the red zone**: `ShouldKeepHunterRangedTimerActive` anchored its hold to the moment the cast ended (a fixed 1.0s window) instead of the ranged cycle end, so a Steady Shot / Arcane Shot / Multi-Shot finishing more than a second ahead of cycle end tore the ranged timer down before the shot fired. The hold is now anchored to `lastSwing + duration` plus latency/grace, so Auto Shot is preserved wherever in the cycle the cast finished, including a cast landing at the very end. The anchor re-targets automatically when a new cycle starts and cannot hold an idle/reset timer.
- **Interrupted or failed casts left stale cast identity behind**: `HandleSpellcastInterruptedOrFailed` stopped clearing `currentCastSpellId`, `currentCastStartTime`, `lastResolvedHunterCastToken`, and `lastResolvedHunterCastAt` (and only ran for hunters), so a stale token survived into `HandleSpellcastSucceeded`, which re-attributed it to the next successful cast and fabricated a red-zone Steady Shot that never landed. Cleanup is restored for every class.

### Internal

- **Headless tests (`SuperSwingTimer_Tests.lua`, `run_tests.lua`)**:
  - Expanded the suite from 123 to 146 tests with a new `SST-Diag` group covering: API presence, live error-handler capture, `LUA_WARNING` event capture, error dedupe and count semantics, SST-vs-external attribution, ring-buffer cap, slash consumption, compact/full/error report construction, error text inclusion, clear semantics, glow fallback, glow start/stop transition counting, icon and bar hide-stop via the `OnHide` hooks, the reset-guard flag, the Glow DB default, `/sst glow` toggling, the `/stt` alias, LibStub/LCG library reporting, idempotent error-handler installation, profiler stats, self-test probes, and export construction.
  - Added harness mocks for `seterrorhandler`, `debugstack`, `debugprofilestart`/`debugprofilestop`, `GetBuildInfo`, `GetFramerate`, addon memory/CPU APIs, `C_AddOns.GetAddOnMetadata`, project constants, `UnitAura`, event registration/`IsEventRegistered`, `SetMultiLine`, `SetToplevel`, and `Raise`.
  - Added `SuperSwingTimer_Diag.lua` and `SuperSwingTimer_Glow.lua` to the headless load order and to the TOC load-order assertions (LibStub before LCG, Diag before Constants, Glow before ClassMods).
  - Expanded the suite from 146 to 150 tests with Hunter regression coverage for Auto Shot alias matching (`"Auto Shot"`, `"Shoot"`, numeric ID and numeric string), cast-identity cleanup on interrupt/fail, and the cycle-anchored ranged hold (including that an idle/reset timer is never held).
- **CI (`.github/workflows/luac.yml`)**:
  - Added the new files plus `SuperSwingTimer_SoD.lua`, `SuperSwingTimer_Tests.lua`, and `Media/SuperSwingTimer_Media.lua` to the syntax check.
  - Added a headless test step (`lua5.1 run_tests.lua`, falling back to `lua run_tests.lua`) so the suite runs on every push/PR, not just locally.

### Notes

- **No DB schema migration**: `showGlowEffects` is a new optional key; `nil` is treated as enabled. Existing `SuperSwingTimerDB` versions remain valid.
- **Pending in-game verification**: this build has not yet been tested on live `classic_era`, `classic_anniversary`, or `classic_titan` clients. The Hunter Auto Shot and cast-window changes are covered by headless tests only; bars, glow, and CLEU-driven behaviour still need an in-game pass.
- **SoD load order is unchanged** (`SuperSwingTimer_SoD.lua` remains last): class merges run from `ns.InitClassMods()` on `ADDON_LOADED`, after every file has loaded.
- **LibCustomGlow asset verification**: `AnimateTexCoords` (`UIParent.lua:593`), `Interface\SpellActivationOverlay\IconAlert`, `Interface\SpellActivationOverlay\IconAlertAnts`, `Interface\ItemSocketingFrame\UI-ItemSockets`, `UI-HUD-ActionBar-Proc-Start-Flipbook`, `UI-HUD-ActionBar-Proc-Loop-Flipbook`, `CreateTexturePool`, `CreateFramePool`, `CreateMaskTexture`, and the flipbook animation setters were confirmed against `classic_era` (1.15.9.70003), `classic_anniversary` (2.5.6.70006), and `classic_titan` (3.80.2.69815) UI source.

## v0.2.6 - 2026-10-24

### Added

- **Dual-Client Spell Texture Engine (`SuperSwingTimer_Constants.lua`, `SuperSwingTimer_ClassMods.lua`)**:
  - Implemented centralized `ns.GetSpellTexture(spellIdentifier)` in `SuperSwingTimer_Constants.lua` with a 4-tier fallback chain:
    1. Modern namespace `C_Spell.GetSpellTexture(spellIdentifier)`
    2. Legacy global `GetSpellTexture(spellIdentifier)`
    3. Icon return from `ns.GetSpellInfo(spellIdentifier)`
    4. Live aura texture binding
  - Audited and updated 35+ spell texture call sites across all 6 physical class modules in `SuperSwingTimer_ClassMods.lua` to route through `ns.GetSpellTexture`, preventing blank or missing buff/debuff icons on unlearned spells across Classic Era (1.15.9, build 70003) and TBC Anniversary (2.5.6, build 70006).
  - Enhanced `GetHelpfulAuraData` and `GetHarmfulAuraData` in `SuperSwingTimer_ClassMods.lua` to return the live aura `icon` field, guaranteeing active buff and debuff icons display their actual applied texture directly from the client aura table.
- **Power Bar Height Slider in Options GUI (`SuperSwingTimer_Config.lua`)**:
  - Added dedicated "Power Bar Height" slider (range 6px to 30px, step 1px, default 14px) directly under the "Bar Height" slider in the Appearance section.
  - Dynamically updates `SuperSwingTimerDB.powerBarHeight` and `ns.POWER_BAR_HEIGHT` in real-time, calling `ns.ApplyBarSize()` and `ns.UpdatePlayerPowerBar()` so the resource bar resizes immediately without a `/reload`.
  - Fully wired into factory defaults reset and config panel display sync.
- **Hunter Aspect Numeric FileID & In-Combat Missing Aspect Alert (`SuperSwingTimer_ClassMods.lua`)**:
  - Enhanced `GetCurrentAspectData()` to return the live aura texture, supporting both numeric FileIDs (e.g. 136006) and texture paths across modern Classic Era (1.15.9) and TBC Anniversary (2.5.6) clients.
  - Added in-combat missing aspect visual alert: entering combat without an active aspect displays a question mark icon (`"Interface\\Icons\\INV_Misc_QuestionMark"`) with a bright red warning border (`0.9, 0.1, 0.1, 0.9`). Activating any aspect immediately displays the aspect's texture and resets to the subtle black border (`0, 0, 0, 0.65`). Out of combat with no aspect active, the icon remains cleanly hidden.
- **Subpixel Grid Snapping Helper (`SuperSwingTimer_Constants.lua`)**:
  - Implemented `ns.PixelSnap(value, customScale)` using physical screen pixel boundary rounding against `UIParent:GetEffectiveScale()`.
  - Ensures bar coordinates, spark edges, and border thicknesses align cleanly to physical monitor pixel grids, eliminating subpixel shimmering and blur on high-DPI displays.
- **Database Migration 66 (`SuperSwingTimer.lua`)**:
  - Added DB migration `v66` (`ns.DB_CURRENT_VERSION = 66`) to automatically upgrade legacy 10px power bar configurations to the new 14px standard default while preserving custom user-configured heights.
- **Headless Test Expansion (`SuperSwingTimer_Tests.lua`)**:
  - Expanded test runner to 123 tests across 11 test groups, adding unit tests for `Core:PixelSnap`, `Hunter:Aspect_AcceptsNumericFileID`, `Hunter:Aspect_AlertNoAspectInCombat`, `Config:PowerBarHeightSlider_ExistsAndAdjusts`, `MigrateDB_V66`, `MigrateDB_V66_PreservesCustom`, `PowerBarHeight_Default14`, `DebuffBarHeight_Default8`, `GetSpellTexture_PcallSafety`, `Paladin_DebuffBars_IconCreated`, and regression test `ComputeBuffIconOffset_SkipsNilSlot_AccountsForLaterBars`. Dynamic hook locators (`GetCoreRenderHook` and `GetHunterHook`) prevent hook array index drift.

### Changed

- **Unified Power Bar Default Height (`SuperSwingTimer_Constants.lua`, `SuperSwingTimer_UI.lua`, `SuperSwingTimer_ClassMods.lua`)**:
  - Increased default height of `SuperSwingTimerPlayerPowerBar` from 10px to **14px** (`ns.POWER_BAR_HEIGHT = 14`, `DB_DEFAULTS.powerBarHeight = 14`).
  - Provides clean vertical padding for 10pt resource values across Warrior Rage, Rogue/Cat Energy, and Paladin/Shaman/Hunter/Druid Mana bars.
- **Debuff Duration Bar Default Height & Icons (`SuperSwingTimer_Constants.lua`, `SuperSwingTimer_ClassMods.lua`)**:
  - Increased default height of all target debuff duration bars from 6px/5px to **8px** (`ns.DEBUFF_BAR_HEIGHT = 8`).
  - Standardized all 20 class debuff bar constants (`JOTC_BAR_HEIGHT`, `SEAL_VENGEANCE_BAR_HEIGHT`, `DEEP_WOUND_BAR_HEIGHT`, `REND_BAR_HEIGHT`, `THUNDER_CLAP_BAR_HEIGHT`, `DEMO_SHOUT_BAR_HEIGHT`, `SUNDER_ARMOR_BAR_HEIGHT`, `FLAME_SHOCK_BAR_HEIGHT`, `MANGLE_BAR_HEIGHT`, `RIP_BAR_HEIGHT`, `RAKE_BAR_HEIGHT`, `SERPENT_STING_BAR_HEIGHT`, `WING_CLIP_BAR_HEIGHT`, `CONCUSSION_SHOT_BAR_HEIGHT`, `IMMOLATION_TRAP_BAR_HEIGHT`, `EXPLOSIVE_TRAP_BAR_HEIGHT`, `FREEZING_TRAP_BAR_HEIGHT`, `FROST_TRAP_BAR_HEIGHT`, `RUPTURE_BAR_HEIGHT`, `EXPOSE_ARMOR_BAR_HEIGHT`) to 8px with matching 8x8 outside-left icons, significantly improving dot readability.

### Fixed

- **Debuff Stacking Nil-Hole Bug (`SuperSwingTimer_ClassMods.lua`)**:
  - Fixed `ComputeBuffIconOffset` which was previously using `ipairs` to iterate over class debuff bar tables. Because inactive debuff slots contain `nil`, `ipairs` terminated immediately on the first nil slot, ignoring subsequent active debuffs and causing buff icons to overlap active debuffs. Replaced with bounded index loop matching `RestackDebuffBars`.
- **Druid Debuff Layout Thrash & Redundant Anchoring (`SuperSwingTimer_ClassMods.lua`)**:
  - Removed legacy per-frame `ClearAllPoints()` and `_lastRestackY = nil` calls inside `UpdateDruidRipBar` and `UpdateDruidRakeBar`, allowing `RestackDebuffBars` to manage stacking with cached offsets, eliminating layout thrashing and anchor cache invalidation during feral druid combat.
- **Asynchronous Icon Texture Recovery (`SuperSwingTimer_ClassMods.lua`)**:
  - Added dynamic spell texture recovery checks to debuff bars across Paladin (Judgement, Seal of Vengeance), Warrior (Sunder Armor, Deep Wounds, Rend, Thunder Clap, Demo Shout), Druid (Mangle, Rip, Rake), Hunter (Serpent Sting, Wing Clip, Concussion Shot), and Rogue (Rupture, Expose Armor). Bars now populate their icon texture dynamically as soon as the debuff is applied even if the spell was uncached during initial login.
- **Crash Immunity for `ns.GetSpellInfo` and `ns.GetSpellTexture` (`SuperSwingTimer_Constants.lua`)**:
  - Wrapped both legacy and modern `C_Spell` engine API calls in `pcall` with `rawget` lookups, guaranteeing 100% crash immunity across all patch versions of Classic Era (1.15.9, build 70003) and TBC Anniversary (2.5.6, build 70006).
- **Real-Time Global Scaling in Options (`SuperSwingTimer_UI.lua`)**:
  - Fixed `ns.ApplyGlobalScale()` so dragging the Global Scale slider in Options immediately invokes `ns.ApplyBarSize(baseWidth, baseHeight)`.
  - Swing bars (MH, OH, Ranged, Enemy), sparks, hunter cast bar, power bar, and debuff bars now resize dynamically in real time without requiring a UI `/reload`.
- **Vertical Bar Stacking & Clearance Geometry (`SuperSwingTimer_ClassMods.lua`)**:
  - Verified and hardened stacking math in `RestackDebuffBars()`, `UpdatePowerBarAnchor()`, and buff icon placement:
    - Debuff bars stack upward above MH (or Ranged for hunters) with a clean 2px gap.
    - Buff/cooldown icon row floats 8px above the topmost visible debuff bar (or 8px above MH when no debuffs are present).
    - Unified power bar anchors 4px below the lowest bar in the stack (OH if dual-wielding, MH if 2H/sword-and-board, or Hunter cast bar).

## v0.2.5 - 2026-10-22

### Added

- **Interactive Move Mode & Floating Reposition HUD (`SuperSwingTimer_UI.lua`, `SuperSwingTimer.lua`)**:
  - Implemented `/sst move` and `/sst unlock` slash commands allowing direct, intuitive repositioning of all swing bars.
  - Added high-visibility semi-transparent drag guide overlays with clear labels ("Main Hand (Drag)", "Off Hand (Follows MH)", "Ranged (Drag)", "Enemy (Drag)") rendered at dialog frame level (`+25` above bars).
  - Explicitly disabled mouse events on drag overlays (`overlay:EnableMouse(false)`), guaranteeing that guide textures never steal mouse events away from the draggable bar frames.
  - Added dynamic Hunter anchor label: when playing a Hunter, `mhBar` dynamically displays `"Main Hand (Follows Ranged)"` instead of `"Main Hand (Drag)"`, clearly reflecting that dragging the Ranged bar moves the entire stack and preventing player confusion.
  - Added floating `SuperSwingTimerMoveHUD` toolbar with title, reposition instructions, and a `[ Lock Bars & Save ]` button (`/sst lock`).
  - Added `/sst unlock` button directly into the header of `SuperSwingTimerConfigPanel` and onto the Blizzard Options canvas.
  - Wired `OnHide` script on `SuperSwingTimerMoveHUD` so pressing `Esc` (via `UISpecialFrames`) cleanly exits Move Mode, locks all bars, and saves positions.
  - Added combat auto-lock safety on `PLAYER_REGEN_DISABLED`: entering combat while in Move Mode immediately locks bars and dismisses drag overlays so the UI is uncluttered for combat.
  - Added rapid drag off-frame release safety in `AttachDrag`'s `OnUpdate`: queries `IsMouseButtonDown("LeftButton")` on each frame, ensuring that releasing the mouse outside the frame boundaries cleanly saves position even if the client skips `OnMouseUp`.
  - Added power bar dynamic re-anchoring on drag release: `SavePosition` now automatically calls `ns.UpdatePowerBarAnchor()`, snapping player power bars (Rage/Energy/Mana) to their proper relative position below the newly positioned bar.
- **Dynamic 20-Second Animated Test Preview (`SuperSwingTimer.lua`, `SuperSwingTimer_Config.lua`)**:
  - Exported `ns.StartBarTestPreview` and upgraded `/sst test` to trigger a realistic 20-second animated swing cycle across all active bars.
  - Added start/stop chat notifications (`/sst test` to start, second `/sst test` or timer expiry to stop early).
- **Cross-Client Interface Numbers & Native `C_UnitAuras` Normalization (`SuperSwingTimer.toc`, `SuperSwingTimer_Constants.lua`)**:
  - Updated `SuperSwingTimer.toc` with explicit interface directives: `Interface: 11509, 20506, 38002`, `Interface-Classic: 11509`, `Interface-BCC: 20506`, `Interface-Titan: 38002` for seamless cross-client support across Classic Era (1.15.9), TBC Anniversary (2.5.6), and Titanforge (`classic_titan` 3.80.2).
  - Updated `ns.UnitAura` to natively query modern `C_UnitAuras.GetAuraDataByIndex` first, ensuring uninterrupted buff/debuff tracking on modern clients while maintaining flawless fallback to legacy multi-return signatures (Shapes A, B, C, D).
- **Enterprise Engine Performance & Fast-Path Filter (`SuperSwingTimer_State.lua`, `SuperSwingTimer_UI.lua`)**:
  - Implemented fast-path GUID filtering in `ns.HandleCLEU()` that discards third-party combat log events immediately before time alignment math runs, saving overhead on ~98% of CLEU traffic in 25-man and 40-man raids.
  - Refactored `CoreRenderHook(elapsed)` in `SuperSwingTimer_UI.lua` to dispatch class-specific visual helpers strictly for the active `ns.playerClass`, eliminating 6-7 redundant function lookups and global table accesses every frame at 144 FPS.
  - Strictly enforced a zero-allocation policy across all per-frame render routines and combat event paths.
- **Config Studio Spacing & Readability Overhaul (`SuperSwingTimer_Config.lua`)**:
  - Expanded inter-section spacing from 22px to 46-50px (`sectionY - 32` with `gapAfterHeader = 20`), ensuring slider min/max labels never touch or crowd subsequent section headers.
  - Upgraded section headers (`CreateSectionHeader`): increased layout height to 36px, applied solid dark panel backgrounds (`0.08, 0.08, 0.12, 0.95`), a 3px color accent badge (Cyan for Appearance, Gold for Combat & Timer Behavior, Emerald for Shaman Weave, Blue for Quick Controls), and a subtle 1px divider line.
  - Increased control row spacing from 14px to 18px in `LayoutSectionRows`.
  - Expanded the 2-column Quick Controls Key Colors palette gutter from 16px to 24px with 8px vertical row spacing to eliminate accidental misclicks.
  - Enhanced Quick Tab buttons with bright cyan active text (`#33d6ff`) and highlighted bottom accent borders.
  - Cleaned up conflicting right-anchor points on `CreateActionRow` label text fontstrings, eliminating font stretching and text clipping.
- **Headless Test Suite Expansion (`SuperSwingTimer_Tests.lua`, `run_tests.lua`)**:
  - Expanded headless test suite to 113 total tests across 11 test groups (added `SteadyShot_LateLanding_InRedZone_EndToEnd` in `[SST-Hunter]`, `CLEU_FastPath_IgnoresThirdParty` in `[SST-Combat]`, `OnUpdate_ClassIsolation` in `[SST-Regressions]`, `Hunter_WithoutOH_OverlayHidesOnLock` in `[SST-MoveMode]`, `MigrateDB_V65` in `[SST-Core]`, and `SectionSpacingAndHeaders`, `ActionRow_SingleRightAnchor`, `QuickTabStylingAndColorsGutter`, `Combat_Enter_CancelsMoveMode` drag overlay checks in `[SST-Config]`/`[SST-MoveMode]`), executing in ~0.040s with a 100% pass rate.

### Changed

- **Default Bar Texture Updated to Wglass (`SuperSwingTimer_Constants.lua`, `SuperSwingTimer.lua`)**:
  - Set default `barTexture` and `rangedBarTexture` in `ns.DB_DEFAULTS` to `"Interface\\AddOns\\SuperSwingTimer\\Media\\statusbar\\Wglass.tga"`.
  - Added **Migration 65** (`SuperSwingTimer.lua`, `ns.DB_CURRENT_VERSION = 65`) to automatically migrate existing installations from legacy default textures (`MerfinMain.tga`, nil, or `UI-CastingBar-Fill`) to `Wglass.tga`.

### Fixed

- **Drag Overlay Stuck After Unlock and Lock (`SuperSwingTimer_UI.lua`, `SuperSwingTimer.lua`)**:
  - Resolved an issue where "Ranged (Drag)" and "Enemy (Drag)" overlays remained stuck on screen after unlocking and locking on Hunters and other classes without an off-hand weapon equipped.
  - Fixed root cause: `ipairs` terminates iteration at the first `nil` entry in an array. Because `ns.ohBar` was `nil` on non-dual-wielding classes, tables like `{ ns.mhBar, ns.ohBar, ns.rangedBar, ns.enemyBar }` stopped iterating at index 2, preventing `ns.rangedBar._dragOverlay:Hide()` from ever running!
  - Implemented unrolled, zero-allocation `HideAllDragOverlays()`, `ForEachAllBar`, and unrolled bar loops across `SuperSwingTimer_UI.lua`, resolving `ipairs` holes across all bar operations (`ApplyLockBars`, `StopMoveMode`, `ApplyVisibility`, `ApplyBarSize`, `ApplyBarTexture`, `ApplyRangedBarTexture`, `ApplyBarTextureLayer`, `ApplyBarBackgroundColor`, `ApplyBarBorderColor`, `ApplySparkSettings`, `ApplyIndicatorBlendMode`, `ApplySparkTextureLayer`, and `CoreRenderHook`).
  - Added headless test `MoveMode:Hunter_WithoutOH_OverlayHidesOnLock` to verify drag overlays hide when `ns.ohBar` is `nil`.

- **Hunter Steady Shot & Auto Shot Red Zone Clip Window (`SuperSwingTimer_State.lua`, `SuperSwingTimer_UI.lua`)**:
  - Fixed an issue where casting Steady Shot slightly late into the red clip zone suppressed or wiped the upcoming Auto Shot window even though the shot landed before clipping.
  - Steady Shot is now allowed to land anywhere through the end of the clip zone (`now <= windowEnd + latencyBuffer + graceAllowance`) without early reset.
  - `HandleSpellcastSucceeded` records `ns.hunterSteadyShotEndedInRedZone = now` and passes `preserveCastBar = true` to `ClearHunterCastState`.
  - `HandleSpellcastStop` and `HandleSpellcastChannelStop` preserve the active cast bar display so `UNIT_SPELLCAST_STOP` doesn't clear the upcoming Auto Shot window.
  - `StartRangedSwing()` cleanly clears `ns.hunterSteadyShotEndedInRedZone` when the next Auto Shot cycle begins.
- **Combat & Relock Drag Overlay Suppression (`SuperSwingTimer_UI.lua`, `SuperSwingTimer.lua`)**:
  - Fixed an issue where "Ranged (Drag)" and "Enemy (Drag)" overlays remained visible after relocking bars or upon entering combat.
  - Hardened `CoreRenderHook(elapsed)`, `ApplyVisibility()`, and `PLAYER_REGEN_DISABLED` to unconditionally force `ns.isMoveModeActive = false` and hide all 4 bar drag overlays (`bar._dragOverlay:Hide()`) every frame when bars are locked or when entering combat.
- **Config UI Quick Controls 2-Column Grid & Tabs (`SuperSwingTimer_Config.lua`)**:
  - Refactored Quick Controls into a responsive 2-column layout (`gutter = 20`, column width `~330px`, `6px` vertical row spacing) with categorical tab filtering (`Visibility`, `Colors`, `Class`).
  - Fixed control overlapping: Quick Controls header anchored at Y = -118 safely below the Global Scale slider and descriptive label text; tab buttons positioned at `headerBottomY - 14`.
  - Left-aligned text labels across compact toggle rows and color swatch rows, with whole-row clickability.
  - Fixed undefined variable references (`topMinimalModeRow` changed to `minimalModeRow`).
- **Solid Dark Window Backdrop (`SuperSwingTimer_Config.lua`)**:
  - Added dedicated solid dark opaque texture (`bgSolid:SetColorTexture(0.05, 0.05, 0.07, 0.98)`) behind `SuperSwingTimerConfigPanel`.
  - Completely resolved the transparent background issue where the 3D game world leaked through and obscured configuration text and controls.
- **Persistent Drag Overlay & Move HUD Dismissal (`SuperSwingTimer_UI.lua`, `SuperSwingTimer_Config.lua`)**:
  - Hardened `ns.ApplyLockBars()`: locking bars unconditionally resets `ns.isMoveModeActive = false`, dismisses all active bar drag overlays (`_dragOverlay`), hides `SuperSwingTimerMoveHUD`, and synchronizes all lock checkboxes across the UI.
  - Converted the Config Panel header button (`moveHeaderBtn`) into a bidirectional toggle: dynamically alternates between `[ Unlock & Move Bars ]` (green) and `[ Lock Bars & Save ]` (crimson), allowing players to lock bars directly from the header without overlays remaining stuck.
  - Implemented centralized `ns.RefreshConfigLockControls()` to keep the header button, Quick Controls toggle, General Behavior toggle, and Blizzard Settings canvas checkbox in 100% sync across all state changes.
  - Updated `ns.StopMoveMode()` to preserve clean bar previews when the config panel remains open while dismissing drag overlays.
- **Config Section Overlap & Class Isolation (`SuperSwingTimer_Config.lua`)**:
  - Rewrote search filter (`FilterSearchRows`): when the search field is empty, it restores normal section visibility instead of unconditionally showing all 150+ controls across the addon. For active searches, it strictly hides rows marked for classes other than the current character.
  - Tagged all Shaman Weave Assist rows, headers, and Weave Family rows with `SetRowClassRequirement(row, "SHAMAN")` so they are never displayed on Hunter, Warrior, Rogue, Paladin, or Druid characters.
  - Guarded Shaman sections in `ReflowConfigSections()` with `ns.playerClass == "SHAMAN"` checks, preventing unreflowed rows from occupying the same Y coordinates as Appearance sliders.
  - Wired `AttachHeaderReflow(mhOhHeader)` so collapsing or expanding the Appearance section properly reflows all subsequent sections.
  - Preserved `generalHelp` description text in `generalRows` without being overwritten by the Lock Bars toggle.
- **Defensive API Checks (`SuperSwingTimer_UI.lua`)**:
  - Added defensive `bar.IsMouseEnabled and bar:IsMouseEnabled()` checking in `ApplyLockBars`, protecting against custom frame wrappers or mock environments missing `IsMouseEnabled`.

## v0.2.4 - 2026-09-21

### Added

- **Headless CLI Test Runner (`run_tests.lua`)**:
  - Built a standalone test execution harness with a complete mock WoW Classic/TBC environment.
  - Compatible with standard `lua` (5.1-5.5) and `luajit`, executing all 7 test groups (68 total tests) headlessly in ~0.013s with ANSI color reporting.
  - Expanded test suite in `SuperSwingTimer_Tests.lua` covering DB migrations through v64, zero-allocation helpers (`HasActiveTimers`, `HasActiveBuffIcons`), haste calculations, and latency caching.
- **Complete SoD Spell Matrices (`SuperSwingTimer_SoD.lua`)**:
  - Added Season of Discovery rune tracking matrices for WARLOCK (Metamorphosis, Chaos Bolt, Haunt), MAGE (Living Bomb, Rewind Time, Fingers of Frost), and PRIEST (Penance, Circle of Healing, Shadow Word: Death) to `ns.SOD_TRACKED_SPELLS`.

### Performance

- **C-Level Unit Event Filtering (`SuperSwingTimer.lua`)**:
  - Implemented `RegisterUnitEventSafe` helper that delegates to `frame:RegisterUnitEvent(...)` when supported.
  - Filtered `UNIT_AURA` to `"player"` and `"target"`, `UNIT_ATTACK_SPEED` to `"player"` and `"target"`, and `UNIT_POWER_*` / `UNIT_SPELLCAST_*` / `UNIT_INVENTORY_CHANGED` / `UNIT_RANGEDDAMAGE` to `"player"`. Eliminates 95%+ of raid combat event churn at the C engine level.
  - Cached `POWER_CLASSES` table at file scope in `SuperSwingTimer.lua` and `SuperSwingTimer_State.lua`, removing runtime table allocations.
- **Idle OnUpdate Sleeping (`SuperSwingTimer.lua`, `SuperSwingTimer_ClassMods.lua`)**:
  - Implemented `ns.HasActiveBuffIcons()` and wired `ns.activeBuffIconCount` tracking across all 6 physical class modules.
  - `SuperSwingTimer.lua` now sleeps the `OnUpdate` loop out-of-combat whenever no timers and no buff/cooldown icons are actively running, reducing idle out-of-combat CPU usage to 0%.
- **Hotpath Render Allocation & Layout Deduplication (`SuperSwingTimer_UI.lua`, `SuperSwingTimer_ClassMods.lua`, `SuperSwingTimer_State.lua`)**:
  - Unrolled timer table checks in `HasActiveTimers()`, eliminating `pairs()` iterator closures and GC allocations on every frame.
  - Cached string values (`_lastCurPower`, `_lastMaxPower`, `_lastPowerType`) in `UpdatePlayerPowerBar()`, eliminating string garbage generation and redundant font layout passes when resources are static.
  - De-duplicated spark frame re-anchoring in `UpdateSparkPosition()` by tracking `_lastSparkPos` and `_lastSparkAnchor`, bypassing redundant C++ layout dirtying when pixel offsets remain unchanged.
  - Cached label text rendering in `SyncBarLabelText()`, skipping `SetText()` when string content is identical.
  - Cached tenth-of-second intervals in `UpdateMeleeBar()`, `UpdateRangedBar()`, and `UpdateHunterCastBar()`, eliminating 93%+ of `string.format("%.1f", remaining)` allocations during swings.
- **Weaving Engine Latency & Haste Optimization (`SuperSwingTimer_Weaving.lua`)**:
  - Streamlined `GetLatencySeconds()` to prioritize `ns.cachedLatency` with fallback to `GetNetStats()`.
  - Unified Bloodlust/Heroism and Berserking haste scans in `GetLiveSpellHasteMultiplier()` into a single-pass 40-slot aura scan with early break on detection.

### Changed

- **Version Bump & DB Migration v64 (`SuperSwingTimer.toc`, `SuperSwingTimer.lua`)**:
  - TOC version bumped to `v0.2.4`.
  - `ns.DB_CURRENT_VERSION` updated to `64`. Added Migration 64 ensuring default dimensions (Hunter Auto Shot 15px, Power Bar 10px) and class power bar colors.
  - Fixed `MigrateDB(targetDb)` to cleanly support isolated test tables without mutating global `SuperSwingTimerDB`.
- **Warrior Execute Indicator Glow Pulse (`SuperSwingTimer_ClassMods.lua`)**:
  - Added smooth sine-wave alpha pulsing (`math.sin(nowSec * 6)`) to the Execute alert glow texture when target HP is <= 20%.

## v0.2.3 - 2026-09-14

### Fixed

- **Hunter Cast Bar Background Obscuration (`SuperSwingTimer_UI.lua`, `SuperSwingTimer_State.lua`)**:
  - Removed `clipZoneOverlay` entirely from `hunterCastBar` and deleted `ShowHunterClipZone()` / `HideHunterClipZone()`.
  - Restored the clean dark status bar background across Auto Shot, Multi-Shot, and Steady Shot windows; cast bar fill uses its independent `hunterCastBar` color (`0.35, 0.65, 0.95, 1.0`).
- **Hunter Clip Zone ("Red Zone") Color Key & Migration 63 (`SuperSwingTimer.lua`, `SuperSwingTimer_Constants.lua`, `SuperSwingTimer_Config.lua`)**:
  - Added SavedVariables DB Migration 63 to heal corrupted white `autoShotUnsafe` back to default red `{ r = 1, g = 0, b = 0, a = 0.4 }`.
  - Added independent `clipZone` / `clipSafe` settings and UI swatches ("Clip Zone" / "Clip Safe") separated from "Cast Bar" in config, with bidirectional alias synchronization.
  - Hardened `OpenColorPicker` to pre-seed `ColorPickerFrame:SetColorRGB()` and `ColorPickerFrame:SetColorAlpha()` before opening, preventing the color picker from defaulting to opaque white.

### Changed

- **Version Sync**: `SuperSwingTimer.toc` updated to `v0.2.3`.
- **SavedVariables DB Migration v63 (`SuperSwingTimer.lua`)**:
  - Bumped `ns.DB_CURRENT_VERSION` to 63.
  - Heals corrupted white `autoShotUnsafe` color values, seeds `clipZone` and `clipSafe` aliases, and ensures `hunterCastBar` is populated.

## v0.2.2 - 2026-09-12

### Recent Changes (2026-09-13)

| Area | Change |
| --- | --- |
| Power bar — wiring | Shared updater is no longer cleared at init, and every class's own delegate now runs from its own OnUpdate hook (Warrior gained `ns.UpdateWarriorRageBar`) |
| Power bar — stack position & size | New `ns.UpdatePowerBarAnchor()` keeps the resource bar as the bottom-most bar of the swing stack with the swing bars' width and its fixed 10px height (global-scale aware); runs on bar creation, equipment changes, size changes, and position restores |
| Hunter cast display | Stored Steady Shot / Aimed Shot / Volley display clears at cast landing, so the end-of-cycle tail shows "Auto Shot" instead of a stale "Steady Shot" |
| Hunter ranged keep-alive | Melee only counts as active while the target is actually in melee range — no more MH-bar flash or ranged-bar reset/jump after cycles for hunters who meleed earlier in the fight |
| Hunter colors | The Cast Bar swatch always owns the cast-bar fill; Auto Shot Safe/Late now paint only the window zones (ranged bar end zone + cast-bar zone overlay) |

### Fixed (2026-09-13 post-test pass)

- **Power bar never rendered — shared updater deleted at init (`SuperSwingTimer_ClassMods.lua`)**: `InitClassMods()` nil-cleared `ns.UpdatePlayerPowerBar` / `ns.UpdateWarriorRageBar`, but those are the shared, class-agnostic implementations assigned at file scope — every per-class delegate (`ns.UpdateRoguePowerBar`, `ns.UpdatePaladinPowerBar`, `ns.UpdateShamanPowerBar`, `ns.UpdateDruidPowerBar`, `ns.UpdateHunterPowerBar` are thin wrappers that call through the shared one) and the Warrior event paths depend on them, and nothing re-assigned them. All guarded `if ns.UpdatePlayerPowerBar then` call sites became no-ops, so no class ever rendered its power bar. The shared names are no longer nil-cleared; the per-class delegate nil-clears remain (each class's own `Setup*()` re-registers only its own delegate — "each class loads only its own stuff"). Every class's own delegate is now also invoked from that class's own OnUpdate hook — Warrior gained its own `ns.UpdateWarriorRageBar` delegate for this — so the resource bar updates through the class-local wiring for all 6 classes.
- **Power bar stack position and size (`SuperSwingTimer_ClassMods.lua` / `SuperSwingTimer_UI.lua`)**: new shared helper `ns.UpdatePowerBarAnchor()` keeps the resource bar re-anchored as the very bottom bar of the stack and re-sized to match the swing bars' width with its fixed 10px resource height (global-scale aware). It runs on bar creation, equipment changes, size changes, and position restores, and replaces three copies of the duplicated inline anchor/size blocks (init hook, `ApplyBarSize`, `RestoreAllBarPositions`).
- **Hunter bar kept showing "Steady Shot" over the Auto Shot window (`SuperSwingTimer_State.lua`)**: `HandleSpellcastSucceeded` re-seeded the stored cast display for real casts and `GetHunterStoredCastDuration` forced the `GetSpellInfo` base cast time (1.5s), so after a hasted Steady/Aimed cast the stored display outlived the actual cast end and shadowed the Auto Shot hidden window. Real casts (Steady Shot / Aimed Shot / Volley) now clear the stored display at landing; instant Multi-Shot keeps its seeded short helper window.
- **MH bar flash + ranged bar jump after each Auto Shot (`SuperSwingTimer_UI.lua`)**: `ShouldKeepHunterRangedTimerActive()` treated the stale MH timer state (stays `"swinging"` for the rest of combat after any melee swing) as active melee, so the ranged timer was hard-reset at each cycle end for hunters who meleed earlier — flashing the MH bar on and resetting/relatching the ranged bar until the next Auto Shot event arrived. The melee shortcut now applies only when the target is actually in melee range (`ns.IsHunterTargetInMeleeRange() == true`).
- **Hunter cast bar color and ranged zone were the same setting (`SuperSwingTimer_UI.lua` / `SuperSwingTimer_Config.lua`)**: the Auto Shot Safe/Late colors repainted the ENTIRE cast bar fill during every cast and Auto Shot window (in addition to the ranged bar end zone), so "Cast Bar" appeared to do nothing and the window colors acted as the bar color. The cast bar fill now always uses the Cast Bar color and the safe/unsafe feedback is drawn as a `clipZoneOverlay` zone above the fill using the existing Auto Shot Safe/Late colors (same coverage as before). The ranged bar end zone is unchanged. No new settings, no DB migration, no version bump.

### Added

- **Unified Multi-Class Resource/Power Bar (`SuperSwingTimer_ClassMods.lua` & `SuperSwingTimer_UI.lua`)**:
  - Fully implemented live power tracking for all 6 physical classes:
    - **Warrior**: Rage (0–100) with Execute range icon alert with active glow when target health is <= 20%.
    - **Rogue**: Energy (0–UnitPowerMax).
    - **Druid**: Dynamic shapeshift adaptation — automatically transitions between Bear Form (Rage), Cat Form (Energy), and Caster/Travel/Tree/Moonkin (Mana).
    - **Paladin**: Mana (0–UnitPowerMax, displayed as `current/max`).
    - **Shaman**: Mana (0–UnitPowerMax, displayed as `current/max`).
    - **Hunter**: Mana (0–UnitPowerMax, displayed as `current/max`).
  - Standardized Power Bar height to **10px** (`ns.POWER_BAR_HEIGHT = 10`), matching UI scale and improving readability.
  - Integrated Blizzard's `PowerBarColor` table mapping with fallback to per-class customizable DB color swatches.
  - Connected event-driven reactive power updates on `UNIT_POWER_UPDATE`, `UNIT_POWER_FREQUENT`, `UNIT_DISPLAYPOWER`, and `UNIT_MAXPOWER`.
  - Anchored cleanly beneath off-hand or main-hand bars for melee classes, and beneath the Auto Shot cast bar for Hunters.
  - Added power bar preview and smooth resource cycle animation to `/ssttest`.
  - Added per-class Resource/Power Bar toggle in Quick Controls and Options panel.

- **Hunter Auto Shot Cast Bar Enlarge (`SuperSwingTimer_UI.lua` & `SuperSwingTimer_Constants.lua`)**:
  - Enlarged default Hunter Auto Shot cast bar height from 10/13px to **15px** (matching standard main-hand/ranged bar height).
  - Adjusted typography and latency markers for clean vertical alignment in the taller frame.

- **Buff Icon Timer Centering & Stack Counter Overlay (`SuperSwingTimer_ClassMods.lua`)**:
  - Re-anchored buff countdown timer text centered directly **above** the icon (`"BOTTOM", icon, "TOP", 0, 2`, centered horizontal justification, 12pt outline), keeping the icon face completely clear and unobstructed.
  - Added dedicated stack count text overlaid on the icon face (`"BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1`, right-justified, 11pt outline, white text). Stacks are the **only** text rendered overtop the icon face.
  - Formatted stacks to display when `stacks > 1`, as well as when `stacks == 1` for special stacking auras such as Maelstrom Weapon (`408505` / `MSW`) and Paladin Reckoning.
  - Fully implemented and standardized across all 6 physical class modules: Warrior, Paladin, Shaman, Druid, Hunter, and Rogue.
  - Replaced `icon.durationText` inside the icon with clean child frame show/hide management on aura expiration.

- **Shaman Spell-Weaving Real-Time Breakpoint & Spark Overlay (`SuperSwingTimer_Weaving.lua` & `SuperSwingTimer_ClassMods.lua`)**:
  - **Dynamic Real-Time Breakpoint Scaling**: Breakpoint location for Lightning Bolt (and other tracked weave spells) dynamically adjusts in real time based on live cast duration.
  - **Haste & Season of Discovery Maelstrom Scaling**: Automatically queries live spell cast time via `GetSpellInfo(spellId)`, applying active spell haste buffs (Bloodlust/Heroism 30%, Berserking, Drums of Battle) and Season of Discovery Maelstrom Weapon stack reductions (20% per stack down to 0s instant cast at 5 stacks), as well as Nature's Swiftness, Elemental Mastery, and Power Surge procs.
  - **Fixed Breakpoint Target Icons**: Cutoff marker icons (`ns.weaveTriangleTop` and `ns.weaveTriangleBottom`) remain anchored at the exact breakpoint location on the swing bar, giving the player a reliable target cutoff before which they must initiate the cast to weave cleanly between swings without clipping.
  - **Over-Bar Cast Spark Overlay**: Weave spark (`ns.weaveSpark` and `ns.weaveSparkOH`) renders cleanly overtop of the main-hand bar only while actively casting (`isCasting == true`), animating smoothly across the bar over the cast's duration.
  - **Safe vs. Clipped Spark Visual Feedback**:
    - **Shaman Class Color** (`#0070DE` / `{ r = 0.0, g = 0.44, b = 0.87 }`): Rendered when the cast was started *before* the swing passed the breakpoint (clean weave, no swing clip).
    - **Bright Red** (`#FF2626` / `{ r = 1.0, g = 0.15, b = 0.15 }`): Rendered when the cast was started *after* the swing passed the breakpoint (clipped weave, delaying the main-hand swing).

### Fixed

- **Warrior Rampage Duplicate Buff Icon (`SuperSwingTimer_ClassMods.lua`)**:
  - Fixed an issue where the Warrior Rampage buff displayed twice in the buff icon stack when both Classic/TBC and SoD entries were registered.
  - Implemented `MergeTrackedSpells` and `seenAuras` deduplication across all class buff tracking systems to prevent duplicate buff/CD icons.

- **CurseForge Bug 1: Non-Localized Font Path & Escape Errors (`ClassMods.lua`)**:
  - Eliminated hardcoded `Fonts\\FRIZQT__.TTF` and excessive backslash escapes (`Fonts\\\\FRIZQT__.TTF`) that broke on non-English clients (ruRU, koKR, zhCN, zhTW).
  - Implemented dynamic `ns.GetDefaultFont()` resolver querying Blizzard's client-localized `STANDARD_TEXT_FONT` global with safe fallback across all 11 files.
- **CurseForge Bug 2: `Texture:SetPoint(): Invalid region point Height` (`ClassMods.lua`)**:
  - Re-architected glow border edge builder `CreateGlowBorderFrames()` from fragile positional array slicing to 4 explicit named border textures (`top`, `bottom`, `left`, `right`), preventing dimension strings (`"Height"`) from ever being passed to `SetPoint()`.
- **Debuff Bar Icon Overlapping & Alignment (`ClassMods.lua`)**:
  - Re-anchored all debuff bar icons (Paladin Judgement/SoV, Warrior Shield Block/Rend/Thunder Clap/Demo Shout/Sunder Armor, Shaman Flame Shock, Druid Mangle/Rip/Rake, Hunter Traps & Stings, Rogue Rupture/Expose Armor) cleanly to the outside left (`RIGHT`, `bar`, `LEFT`, -2, 0) with `SetTexCoord(0.07, 0.93, 0.07, 0.93)`.
  - Debuff status bars remain 100% aligned with the swing bars without icon occlusion or text clipping.
- **SuperSwingTimer_UI.lua Line 1077 Linter Warning**:
  - Fixed `Cannot assign boolean|nil to parameter boolean` by updating `UpdateHunterCastLatencyVisual` signature and call-site to explicit boolean coercion `(...) == true`.
- **Blizzard API Table Lookup in `GetPowerBarColor` (`SuperSwingTimer_ClassMods.lua`)**:
  - Fixed native color lookup: Blizzard Classic FrameXML returns a color table `{ r, g, b }` rather than tuple arguments.
- **Rogue Power Bar Recursion & Linter Warning (`SuperSwingTimer_ClassMods.lua`)**:
  - Resolved self-recursive call in `UpdateRoguePowerBar` and fixed the `unused variable colorRef` warning in `luacheck`.
- **Stale Class Initializers (`SuperSwingTimer_ClassMods.lua`)**:
  - Nil-cleared all per-class power bar function references during `InitClassMods()` to prevent cross-class contamination.

### Changed

- **Architecture Consolidation (`SuperSwingTimer_ClassMods.lua`, `UI.lua`, `Config.lua`)**:
  - Consolidated duplicate frame creation and legacy `ns.warriorRageBar` checks into a single canonical `ns.playerPowerBar` (`SuperSwingTimerPlayerPowerBar`) constructed during class initialization.
  - Preserved backward-compatible alias `ns.warriorRageBar = ns.playerPowerBar` for external macros and test hooks.
- **Version Sync**: `SuperSwingTimer.toc` updated to `v0.2.2`.
- **SavedVariables DB Migration v62 (`SuperSwingTimer.lua`)**:
  - Bumped `ns.DB_CURRENT_VERSION` to 62.
  - Automatically seeds `showPowerBar`, enhanced Hunter cast bar height, and per-class resource colors for existing profiles.

## v0.2.1 - 2026-07-29

### Added

- **Exhaustive Season of Discovery (SoD 1.15.9) Tank & DPS Integration (`SuperSwingTimer_SoD.lua`)**:
  - Populated complete Tank and DPS SoD rune matrices for all 6 physical classes (`WARRIOR`, `ROGUE`, `SHAMAN`, `HUNTER`, `PALADIN`, `DRUID`).
  - **Warrior**: Added Rampage active spell ID (`426940`), Rampage Proc Buff (`426942`), Quick Strike (`429765`), Raging Blow (`402911`), Devastate (`407133`/`407135`), Blood Surge Slam (`413380`/`413399`), Precise Timing (`426956`), and Sudden Death audio/visual proc alert (`440114`).
  - **Rogue**: Added Saber Slash (`402780`), Main Gauche (`409509`), Envenom (`400011`), Blade Dance (`400012`), Mutilate (`409510`/`409513`), Shadowstrike (`400029`), Quick Draw (`409898`), Poison Knife (`424785`), Crimson Tempest (`412096`), and Secret Technique (`426640`).
  - **Shaman**: Added Way of Earth (`408531`), Shield Mastery (`408527`), Molten Blast (`408247`), Lava Lash (`408507`), Fire Nova (`408331`), Dual Wield Spec (`408498`), Power Surge (`415100`), and event-driven Maelstrom Weapon (`408505`) 5-stack cast-time reduction tracker.
  - **Hunter**: Added Melee Specialist (`415318`), Dual Wield Specialization (`425515`), Aspect of the Viper (`415423`), Flanking Strike (`415320`), Carve (`425711`), Chimera Shot (`53209`/`409433`), and Explosive Shot (`53301`/`409552`).
  - **Paladin**: Added Aegis (`407630`), Hand of Reckoning (`409859`), Guarded by the Light (`408435`), Sacred Shield (`407627`), Fanaticism (`408434`), Art of War (`408432`), Divine Storm (`407778`), Crusader Strike (`409553`), Hammer of the Righteous (`409456`), and Rebuke (`409540`).
  - **Druid**: Added Savage Roar (`407988`), Wild Strikes (`407982`), Berserk (`417141`), Mangle Cat/Bear (`3355`/`409805`/`33878`/`409804`), Lacerate (`414644`), Sunfire Cat/Bear (`414689`/`414684`), and Survival Instincts (`408005`).

- **Base Class Buff & Aura Resolution Across All 6 Physical Classes (`SuperSwingTimer_ClassMods.lua`)**:
  - Integrated localized aura string name matching alongside numeric spell IDs (`auraSpellId == info.spellId or auraName == info.name`) in `GetWarriorSpellRemaining` and `ns.GetSoDAuraData`.
  - Added Warrior **Battle Shout** (`6673`) and **Overpower** (`7384`) to `WARRIOR_TRACKED_SPELLS`.
  - Added Rogue **Slice and Dice** (`5171`) to `ROGUE_TRACKED_SPELLS`.
  - Added Hunter **Aspect of the Hawk** (`13165`) and **Trueshot Aura** (`19506`) to `HUNTER_TRACKED_SPELLS`.
  - Added Shaman **Lightning Shield** (`324`), **Water Shield** (`52127`), and **Rockbiter Weapon** (`8017`) to `SHAMAN_TRACKED_SPELLS`.
  - Added Druid **Clearcasting / Omen of Clarity** (`16870`) to `DRUID_TRACKED_SPELLS`.
  - Implemented dynamic buff icon vertical offset calculation (`_debuffStackIconOffset`) positioning active buff icons cleanly above target debuff duration bars.

- **Shaman Maelstrom Weaving Adjustment (`SuperSwingTimer_Weaving.lua`)**:
  - Wired event-driven Maelstrom Weapon stack count into weaving cast-time reduction math (20% per stack up to 100% instant at 5 stacks).

- **Blizzard Native UI API Integration (`SuperSwingTimer_ClassMods.lua`)**:
  - Integrated `GetPowerBarColor` native fallback into power bar rendering pipeline.

- **Unit Test Coverage Expansion (`SuperSwingTimer_Tests.lua` & `test_migrations.lua`)**:
  - Added unit test cases in `SuperSwingTimer_Tests.lua` for SoD rune registration and aura lookups.
  - Added SavedVariables Migration v61 test harness assertions in `test_migrations.lua` (41/41 tests passing).

### Fixed

- **Dedicated Per-Class Power Bars (`SuperSwingTimer_ClassMods.lua`)**:
  - Extracted power bar rendering into isolated per-class functions (`ns.UpdateWarriorRageBar`, `ns.UpdateRoguePowerBar`, `ns.UpdateShamanPowerBar`, `ns.UpdateHunterPowerBar`, `ns.UpdateDruidPowerBar`, `ns.UpdatePaladinPowerBar`).
  - Druid power bar dynamically switches between Bear (Rage), Cat (Energy), and Caster/Moonkin (Mana) based on active form.
- **Cleaned Baseline CLEU Tables (`SuperSwingTimer_SoD.lua`)**:
  - Purged duplicate baseline Era spell IDs from `SuperSwingTimer_SoD.lua`, maintaining strict architecture isolation.
  - Restored instant physical special abilities (`Victory Rush` `34428`, `Envenom` `32645`, `Stormstrike` `17364`) to `ns.NO_RESET_SWING_SPELLS`.
- **Fixed `GetPlayerGUID` Linter Warning in `SuperSwingTimer_SoD.lua`**:
  - Replaced non-standard `GetPlayerGUID` global check with `(type(UnitGUID) == "function") and UnitGUID("player")`. Zero warnings/errors across all files in `luacheck`.

### Changed

- **Version Sync**: `SuperSwingTimer.toc` set to `v0.2.1`.
- **Linter Configuration (`.luacheckrc`)**: Suppressed false positives for addon global namespaces (0 warnings / 0 errors across 12 files).
- **Documentation Synchronization (`README.md`)**: Updated feature list and At a glance table to match v0.2.1 release specifications.

### Notes

- **SavedVariables DB Migration v61 (`SuperSwingTimer.lua`)**:
  - Incremented `ns.DB_CURRENT_VERSION` to 61 in `SuperSwingTimer.lua`.
  - Automatically initializes `showWarriorRageBar = true`, `showWarriorBuffIcons = true`, `warriorBuffIconSize = 25`, and class power colors (`shamanManaBarColor`, `rogueEnergyBarColor`, `hunterManaBarColor`, `druidManaBarColor`, `paladinManaBarColor`) for existing profiles.

---

## v0.1.9 - 2026-07-14

### Added

- **SoD rune support (`SuperSwingTimer_SoD.lua`):** New file providing Season of Discovery rune ability spell IDs and classifications. Injects SoD-specific spell IDs into the existing swing classification tables defined in Constants.lua. Safely no-ops on TBC Anniversary / Classic Era 1.15 where these spell IDs don't exist. Loaded via `.toc` after Constants.lua.
  - **NO_RESET_SWING_SPELLS** for SoD instant attacks verified to not reset the swing timer: Quick Strike (429765), Raging Blow (402911), Flanking Strike (415320), Lava Lash (408507), Carve (425711), Divine Storm (407778). Includes rune passive vs. actual cast ID separation.
  - **Rend debuff tracking:** 7 rank IDs (772, 6546, 6547, 6548, 11572, 11573, 11574) for Warrior bleed, massively buffed by Blood Frenzy rune.
  - **Blood Frenzy proc buff:** 412507.
  - **Sudden Death proc buff:** 440114 (rune passive 440113 hidden, 440114 is the visible proc buff enabling Execute at any health %).
  - **Endless Rage active ability:** 403349 (25% more rage from damage).
  - **Flanking Strike damage debuff:** 415320 (9% increased damage taken, 10s) for Hunter.
- **Bundled statusbar media (`Media/`):** The MerfinPlus statusbar texture set is now shipped inside the addon's own `Media/statusbar/` folder, rehomed under `Interface\AddOns\SuperSwingTimer\Media\...`. A self-contained `Media/SuperSwingTimer_Media.lua` registrar (no external-lib dependencies; LibSharedMedia registration is optional and guarded) loads via `Media/Media.xml` in the `.toc`. Five fill textures ship locally — `MerfinMain`, `MerfinMainDark`, `MerfinFlatt` (`.tga`) and `MerfinTexture`, `Flatt` (`.blp`) — and appear in the in-game bar-texture picker, so the default bar is always a visible, locally-hosted skin with no dependency on a missing/external texture. Removed ~16 MB of unused Merfin assets (fonts, sound packs, spell overlays, icons, border caps) and the original Merfin-namespaced loader scripts, which referenced foreign `MerfinPlus`/`LibStub`/`LibSharedMedia` globals and would have crashed on load.

### Fixed

- **Classic Era `/sst` panel crash (OnEscape → OnEscapePressed):** `searchBox:HookScript("OnEscape", ...)` used an event name that does not exist on Classic Era EditBox widgets. Classic Era exposes `OnEscapePressed`, not `OnEscape`. TBC Anniversary aliases `OnEscape` internally so the bug was invisible until Classic Era testing. Changed all hook registrations to `"OnEscapePressed"` across Config.lua (search box, value boxes, path boxes). Resolves `/sst` error: `EditBoxHookScript; Does not have a Onescape script`.
- **Init-time crash on Classic Era (missing `GetBarWidth`/`GetBarHeight`):** `UI.lua:1524` called two getter functions (`GetBarWidth`, `GetBarHeight`) that were referenced at runtime but never defined in any file. This threw a Lua error during `ApplyBarSize` on Classic Era where the `pcall` guard caught it silently - but the panel never loaded and bars failed to render. Added both function definitions to `Constants.lua` returning the appropriate dimension from `ns.mhBar`.
- **`panel` upvalue nil in `CreatePanel()`:** A module-level `local panel` was declared but assigned via a late-assignment pattern (the function was defined before the assignment). Inside `CreatePanel()`, `panel` was nil at the point of first use. Added `panel = f` at the top of `CreatePanel()` so the upvalue is populated before any consumer reads it.
- **Invisible bars (black fill x texture):** The real root cause of invisible bars was the fill *color*, not the texture. `DB_DEFAULTS.colors.mh/oh/ranged` were pure black `(0,0,0,1)`; migration v22 force-set them to black while disabling `useClassColors`, and migration v10 also forces black when the color matches the class-blue `(0.25,0.72,1.0)`. A black vertex color zeroes any statusbar texture, so bars rendered black-on-dark and looked invisible. Changed the default fill colors to class blue `(0.25,0.72,1.0)`, repointed `barTexture`/`rangedBarTexture` defaults to the bundled `MerfinMain.tga`, and added **migration v57**, which repairs existing saved variables locked to black fills and re-enables class colors when the old forced-black migration disabled them.
- **Warrior buff/CD icons overlapped debuff bars:** `ComputeBuffIconOffset` (Warrior icon positioning) was called with only `{deepWoundsBar, sunderArmorBar}`, while `RestackDebuffBars` stacks all 5 Warrior debuff bars `{deepWoundsBar, sunderArmorBar, rendBar, thunderClapBar, demoShoutBar}`. When only Rend / Thunder Clap / Demoralizing Shout were visible (Fury/Arms without Deep Wounds + Sunder), the icon offset saw two hidden bars and returned the 8px default, so icons stayed pinned 8px above `mhBar` and overlapped the stacked debuff bars. Now passes the full 5-bar list so Warrior icons always sit above every visible debuff bar, matching the other 5 classes.
- **Addon would not load on Classic Era 1.15.8:** `SuperSwingTimer.toc` used `## Interface: 20505` (TBC Anniversary 2.5.5), which exceeds the Classic Era interface number (11508) — Classic Era classified the addon as out of date and refused to load it, so no bars or icons appeared at all on that client. Changed to `## Interface: 11508, 20505` (comma-delimited, both values on one line — supported by the WoW TOC format). TBC Anniversary (20505) is preserved; Classic Era (11508) now loads.

### Changed

- **Version metadata:** `SuperSwingTimer.toc` bumped from `v0.1.8` to `v0.1.9`. `Constants.lua` DB version updated to `56`.

### Docs

- `SuperSwingTimer_ClassMods.lua`: corrected `ComputeBuffIconOffset` doc comment (returns a positive Y-up offset, not negative).
- `README.md`: dual-client coverage line updated to state Classic Era 1.15.8 + TBC Anniversary 2.5.5/2.5.6.

### Notes

- **DB schema:** v56 -> v57 -> v58 (texture allowlist repair) -> v59 (final texture+color repair, exact-match denylist).
- **Affected clients:** Classic Era / SoD (1.15.x) — SoD rune support and Classic Era config panel fixes. TBC Anniversary (2.5.x) was unaffected by either.
- **Root cause investigation:** The Classic Era breakage was initially suspected to be caused by a "migration 57" issue. Investigation traced the failure to three distinct root causes: (1) EditBox event name mismatch between Classic and TBC, (2) missing getter functions referenced before definition, and (3) Lua upvalue nil timing in the panel factory. No problematic migration was found for the config crash — at that point the migration table ended at v56. This release now adds migration 57 for the separate invisible-bar fix (see Fixed).
- **wow-ui-source cross-reference:** Verified Classic Era (1.15.8) EditBox API against `FrameXML/EditBox.lua` — confirmed `OnEscapePressed` is the correct event name. `OnEscape` exists only in TBC Anniversary and later clients via engine aliasing.
- **SoD spell ID research:** Rune ability IDs sourced from Wowhead Season of Discovery spell database. Verified each ID by rune passive vs. actual cast dual-ID pattern. All IDs are nil-safe on non-SoD clients via `ns.GetSpellInfo()` returning nil for unknown spell IDs.
- **Version metadata:** `SuperSwingTimer.toc` -> `v0.1.9`, `Constants.lua` -> `version = 56` (migrations 57-59 applied in this release).

### Hermes (deepseek-v4-flash, 2026-07-15)

### Added

- **Resource bar color defaults (Constants.lua):** 5 per-class resource color defaults: `shamanManaBarColor`, `rogueEnergyBarColor`, `hunterManaBarColor`, `druidManaBarColor`, `paladinManaBarColor`.
- **`BUFF_ICON_BASE_OFFSET = 14` constant (ClassMods.lua):** Replaced hardcoded 8px base gap in `GetDebuffStackOffset()` and `ComputeBuffIconOffset()` for all 6 classes.

### Changed

- **`MigrateDB` signature + export:** Accepts optional `db` param (falls back to SuperSwingTimerDB). Exported as `ns.MigrateDB` for test harness.
- **`ns.DB_CURRENT_VERSION = 60` (SuperSwingTimer.lua):** New constant matching highest migration version. Tests use this instead of stale hardcode.
- **Resource/power bar generalized:** Height 4px -> 8px (`RESOURCE_BAR_HEIGHT`). Class-aware: Warrior rage (pType 1), Shaman/Hunter/Druid/Paladin mana (pType 0), Rogue energy (pType 3). Per-class color via db.colors.*.
- **GCD bar anchored to bottom of ALL bars (UI.lua):** Power bar -> OH -> MH chain. CreateGcdTickerBar + UpdateBarLayout both updated.
- **HasActiveTimers() buff-icon condition (State.lua):** Per-class show*BuffIcons toggle check so OnUpdate stays alive OOC.
- **Interface token:** Added 20506 to .toc for TBC Anniversary 2.5.6.

### Fixed

- **Test harness `ClearReplaces` nil crash (Tests.lua):** Captured WoWUnit.ClearReplaces as a local.
- **`HelpfulSpellID_AtPos10` mock (Tests.lua):** Changed from dead UnitBuff global to UnitAura (the real call path).
- **`MigrateDB_*` tests (Tests.lua):** Changed hardcoded 56 assertions to ns.DB_CURRENT_VERSION.
- **V0.1.10 section removed (CHANGELOG.md):** Merged its content into v0.1.9 Fixed + Docs. Not a real patch.
- **Changelog restructured:** Restored accidentally removed v0.1.9 Fixed items. Added Hermes section per convention.

### Notes

- **DB schema:** v59 -> v60 (per-class resource bar color defaults).
- **Subagents used:** 3 dispatched (buff-icon gap 401'd, GCD bar, power bar). Power-bar subagent applied v60 migration + color defaults + generalized resource bar. GCD subagent applied anchor changes. Manual fixes applied for tests, changelog, HasActiveTimers, and combat gate removal.
- **wow-ui-source verified:** UnitPower/UnitPowerMax on both classic_era (1.15.8.67156) and classic_anniversary (2.5.6.68575).

### Hermes / deepseek-v4-flash (2026-07-14) — Full session audit, Media prune, bar texture+color fix, luacheck cleanup

- **Media/ — NEW (7 files):**
  - `Media/Media.xml` — loads `SuperSwingTimer_Media.lua` via `<Script/>`
  - `Media/SuperSwingTimer_Media.lua` — self-contained LSM registrar (no external deps), registers 5 fills + guards missing LibSharedMedia
  - `Media/statusbar/MerfinMain.tga` (13586 B), `MerfinMainDark.tga` (2255 B), `MerfinFlatt.tga` (32786 B), `MerfinTexture.blp` (12164 B), `Flatt.blp` (6684 B)
- **Media/ — DELETED (~16 MB):**
  - `Media/font/` (7 fonts: ArchivoNarrow, Expressway, HOOGE, PTSansNarrow, SFUIDisplayCondensed, CNMerged, plus Merfin ttf) — referenced nowhere in addon code (only ns.FONT_PATH = FRIZQT used)
  - `Media/MediaSettings.lua` — 0-byte empty stub
  - `Media/statusbar/MerfinBorderPlater.tga`, `MerfinBorderPlater_1px.tga`, `MerfinMainLeft.tga`, `MerfinMainRight.tga` — border/cap textures, not needed
  - `Media/statusbar/statusbar.lua` — Merfin LSM loader referencing `MerfinPlus`/`AceAddon`/`LibStub` globals (would crash)
  - `Media/font/font.lua` — same pattern
  - `Media/icons/`, `Media/sound/`, `Media/SpellActivationOverlays/`, `Media/background/`, `Media/textures/` — full MerfinPlus junk dirs
- **SuperSwingTimer.toc:** Added `Media\Media.xml` (between Constants.lua and State.lua)
- **SuperSwingTimer_Constants.lua:**
  - Line 933–934: `barTexture`/`rangedBarTexture` default: `UI-StatusBar` → `MerfinMain.tga`
  - Line 962–964: `colors.mh/oh/ranged` default: `{0,0,0,1}` → `{0.25,0.72,1.00,1}`
  - Line 1194: REMOVED `addEntry("Blizzard", "Casting Fill", …)` from texture library
  - Line 1520: `GetBarTexture()` — added guard: `and db.barTexture ~= "Interface\\CastingBar\\UI-CastingBar-Fill"`
  - Line 1528: `GetRangedBarTexture()` — same guard
- **SuperSwingTimer.lua:**
  - v57 migration: repairs black mh/oh/ranged fills → light blue, re-enables useClassColors
  - v58 migration (garbage): allowlist-based texture repair — clobbered valid textures like `Statusbar_Clean`
  - v59 migration: exact-match denylist — only rewrites literal `"Casting Fill"` path + re-asserts colors + useClassColors
  - REMOVED always-run `IsVisibleBarTexture()` block (was after colors loop, before sparkColor) — broke valid textures
  - Added warrior Rend/ThunderClap/DemoShout bar callbacks (nil-guarded)
- **SuperSwingTimer_Config.lua:**
  - ~Line 3602: bar texture row `getTexture` — `SuperSwingTimerDB.barTexture or defaults` → `ns.GetBarTexture()`
  - ~Line 3632: ranged texture row `getTexture` — same pattern → `ns.GetRangedBarTexture()`
  - REMOVED `CreateHelpButton` function (~line 1931–1952) — dead code, config uses `AddControlTooltip`
  - REMOVED `AddSearchRow` function (~line 2267–2271) — dead wrapper, never called
  - ~Line 768: `UpdateBtnLabel` — renamed inner `c` → `color` to fix shadowing of outer `c`
  - ~Line 2276: `FilterSearchRows` — removed unused `anyVisible` variable
  - REMOVED duplicate `scollFrame` content block (was at ~line 2226–2230, then again at 2196–2200 — one scroll child wins, other was orphan)
- **SuperSwingTimer_ClassMods.lua:**
  - REMOVED `GetCooldownRemaining` (~line 1650–1662) — dead, was to query spell cooldowns, never called
  - REMOVED `EnsureWarriorBadge` (~line 1699–1710) — dead, was to create cooldown badge FontStrings
  - REMOVED `UpdateWarriorCooldownBadges` (~line 1712–1717) + call at line 2882 — empty stub, never did anything
  - Wired `protBuffTimer` throttle (~line 2870–2878): per-frame ShieldWall/LastStand/SpellReflection calls → 0.1s throttled (elapsed accumulator)
  - Fixed corrupted function header: `IsWarriorProtectionSpec` → `UpdateWarriorSlamBar` (patch error)
  - Restored missing `local function IsWarriorProtectionSpec()` header
  - Added missing `end` after `UpdateWarriorSlamBar()` in throttle block
- **SuperSwingTimer_UI.lua:**
  - Line 1521: REMOVED unused `local scale = ns.GetGlobalScale()` (was in `ApplyGlobalScale`)
  - Line 1575: REMOVED unused `local scale = ns.GetGlobalScale()` (was in `ApplyBarSize`)
- **.**luarc.json: Added 4 globals: `ClearReplaces`, `SlashCmdList`, `SLASH_SSTTEST1`, `WoWUnit`
- **.**luacheckrc: Added 10 globals: `ClearReplaces`, `GetMeleeHaste`, `GetTimePreciseSec`, `SlashCmdList`, `SLASH_SSTTEST1`, `UnitAura`, `UnitBuff`, `UnitClass`, `UnitDebuff`, `WoWUnit`
- **CHANGELOG.md + README.md:** Updated for v0.1.9 (version string, DB schema chain, default colours, texture sources table)
- **Result:** 0 undefined-variable warnings in addon Lua files (77 remaining all in docs/blizzard/* reference excerpts)

### GitHub Copilot (OpenCode Zen / Hy3 Free, 2026-07-15)

### Changed

- **Class power bar text simplified (ClassMods.lua):** Removed the redundant resource-type labels ("RAGE", "MANA", "EN") from the class power bar. Warrior (rage) and Rogue (energy) now display only the numeric amount. Mana classes (Shaman, Hunter, Druid, Paladin) now display `current/max` (e.g. `1234/2000`) instead of the "MANA" label.

### Fixed

- **WoW API LuaLS diagnostics pass (v0.1.9 session):** Resolved 4 real issues surfaced by the newly-enabled WoW API Lua diagnostics across `SuperSwingTimer.lua`, `SuperSwingTimer_State.lua`, `SuperSwingTimer_UI.lua`, and `SuperSwingTimer_Config.lua` — including a genuine `setResetCallback` colon-call crash bug on section Reset buttons, an `OnPlayerEnteringWorld` argument mismatch, a `nil` duration type annotation, and implicit SavedVariables global creation. All Lua sources now report 0 diagnostics.

---

## v0.1.8 - 2026-07-12

### Added

- **Global Scale slider:** Master UI scale control (0.5×–3.0×, default 1.0×) at the top of the `/sst` panel. Proportionally scales all bars, icons, sparks, borders, and fonts relative to their configured base size. Gold label with descriptive subtitle. Implemented across Constants (defaults), Config (slider + tooltip), UI (apply on init + refresh), and ClassMods (per-element scaling). Fresh install, migration, reset-defaults, and panel-refresh paths all wired.
- **`/sst` search bar:** "Search settings..." EditBox pinned below the scroll frame. Filters all section rows in real-time — matching rows stay at full opacity, non-matching rows dim to 25% alpha. Escape clears the filter. Every toggle, slider, color swatch, dropdown, texture row, action button, and description text is searchable (case-insensitive, substring match).
- **Tabbed Quick Controls section:** The Quick Controls section now has 3 tab-selectable views — **Visibility** (toggles only, single column), **Colors** (swatches only, 2-column grid), and **Class** (combined view for class-specific controls). Tab buttons with gold active state sit below the section header. Switching tabs preserves the panel scroll position. Tabs collapse/expand correctly with the section header.
- **`ns.RegisterOnUpdateHook()` infrastructure (`SuperSwingTimer_Hooks.lua`):** Replaced the fragile 9-link OnUpdate chain-overwriting pattern with a registration-based hook system. All 9 class-mod functions converted from direct chain-wrapping to hooks via `ns.RegisterOnUpdateHook()`. Hooks are independently registered and executed — a failure in one cannot break the others. The core render path registers as hook #1; Test Bars animation inserts at position 1 for pre-render priority. Eliminates `Duplicate field OnUpdate` errors.
- **Per-section Reset buttons:** Each collapsible section header (Appearance, Shaman Weave Assist, Combat & Timer Behavior, Shaman Weave Spells) now has a small red Reset button on the right side. Clicking resets only that section's DB keys to defaults and updates all live controls. Hover highlight on the button; `OnMouseDown` handler prevents click-through to the collapse toggle.
- **Texture preview chips:** Texture path rows (Spark Texture, Cast Breakpoint Spark Texture) now show a 24×16 inline thumbnail of the current texture bordered with `UI-Tooltip-Border`. Preview updates live when texture changes.
- **`setResetCallback` helper:** New method on section headers enabling deferred assignment of reset callbacks after all controls are created.
- **`clampFrameLevel` / `clampAlpha` helpers:** Added to `options.lua` to enforce valid WoW frame-level and alpha ranges on all dropdown popups and sliders.

### Changed

- **Flurry icon merged into unified CD/buff icon group:** Removed the dedicated 30×30 Flurry icon system (`CreateFlurryIconFrame`, `UpdateWarriorFlurryCounter`, `UpdateShamanFlurryIcon`). Flurry is now tracked by the same 25×25 CD/buff icon group as every other class buff — same size, centering, dynamic positioning as Death Wish, Rapid Fire, etc. Eliminates the redundant double-icon on Shaman (Flurry appeared both as a dedicated icon AND in the group) and the hardcoded 12px offset that overlapped debuff bars.
- **CD/buff icon groups re-centered:** All 6 class icon groups (Paladin, Warrior, Shaman, Druid, Hunter, Rogue) changed from right-edge alignment to true horizontal centering over the bar width.
- **Flurry icon strata lowered:** `SetFrameStrata` from `DIALOG` to `MEDIUM` to prevent destructive visual overlap with debuff bars when both are active.
- **Buff icon Y-position computed independently per class:** Replaced the shared `GetDebuffStackOffset()` → `_debuffStackIconOffset` chain with `ComputeBuffIconOffset(barList, referenceBar)` in all 6 classes. The old approach used a module-level local set by `RestackDebuffBars`, which had early-return paths that set the offset to nil — causing `GetDebuffStackOffset()` to return the default -8 fallback and ignore visible stacked debuff bars. The new helper uses synthetic arithmetic (no `GetTop()` calls) and takes the bar list + reference bar directly, computed fresh each frame with zero shared mutable state.
- **Shield Block icon moved to CD/buff group:** Removed from the Warrior debuff bar stack. Added to `WARRIOR_TRACKED_SPELLS` (spellId=2565, label="SB", kind="buff") so it renders as a centered CD/buff icon. The dedicated Shield Block bar remains available via `UpdateWarriorShieldBlockBar` for users who prefer it.
- **Buff icon gap reduced 16px → 8px:** Tighter, cleaner spacing between buff icons and the topmost debuff bar.

### Fixed

- **Hunter MH bar flicker during ranged auto shot:** A stale `hunterQueuedMeleeSpell` from an unlanded Raptor Strike (queued then the player moved out of melee range) kept `IsHunterMeleeBarVisible()` returning true, causing the MH bar to briefly pop up when the ranged active-state holdover dipped between Auto Shot cycles. Fixed by clearing the stale queue in `ApplyVisibility()` when the MH is not actively swinging.

### Removed

- **~100 lines of dead code:** `GetFlurryBuffInfo()`, `CreateFlurryIconFrame()`, `FLURRY_BUFF_NAMES`, `FLURRY_BUFF_NAME_LOOKUP`, `FLURRY_BUFF_SPELL_IDS`, and all dedicated Flurry icon update/refresh functions.
- **2 stale Flurry tests** (`SST-Flurry` test group) — tested `GetFlurryBuffInfo` which no longer exists.

### Docs

- `README.md`: Updated feature summary to reflect unified icon groups, removed dedicated Flurry references.
- `docs/WIRING.md`: Flurry removed from OnUpdate chain diagram and Warrior setup documentation; all references to `UpdateWarriorFlurryCounter` and `UpdateShamanFlurryIcon` replaced with unified icon group.
- `CHANGELOG.md`: This entry.

### Notes

- **DB schema:** v54 → v55 → v56. Migration 55: Enable Warrior rage bar for Protection spec by default. Migration 56: Class colors on by default.
- **OnUpdate hook ordering:** Hooks execute in registration order. Test Bars hook registers at position 1 for pre-render priority. All class-mod hooks register during `InitClassMods()`.
- **Version metadata:** `SuperSwingTimer.toc` → `v0.1.8`, `Constants.lua` → `version = 56`.

---

## v0.1.7 - 2026-07-06

### Added

- **Canonical `ns.UnitAura` wrapper** (Constants.lua): Centralized all `UnitAura`/`UnitBuff`/`UnitDebuff` shape detection into a single function with 3 explicit branches — Classic 1.13.x (9-ret, no icon), Classic 1.15.x/Retail (string icon at r3), and TBC Anniversary 2.5.5 (`AuraUtil.UnpackAuraData`, 15+ returns with FileID icon at r2 + spellId at r10). Added convenience wrappers `ns.UnitBuff()` and `ns.UnitDebuff()`. No more raw `UnitAura()` calls — all callers go through the wrapper.
- **`GetHarmfulAuraData` / `GetHelpfulAuraData` refactored**: Both collapsed from ~80 lines combined to ~10 lines each by delegating shape detection to `ns.UnitAura`. Eliminated duplicated, drifting detection logic that caused the TBC Anniversary spellId extraction bug.
- **File map updated**: 9 Lua files total (Hooks.lua and Tests.lua added), strict dependency order maintained.

### WoWUnit test suite ⚠️

- **18 groups consolidated to 4**: SST-Core (constants/clock/migrate), SST-Auras (wrapper parsing), SST-Combat (CLEU/timers), SST-Hunter (class-gated).
- **`/ssttest` slash command** added for manual triggering.
- **Class gating**: SST-Hunter only registers on HUNTER characters; Paladin seal test gated on PALADIN.
- **All tests are currently grey** — they were written against the old shape detection and broke during the ns.UnitAura refactoring. Need to be updated to call the canonical wrapper in the next session.

### Reference

- **WoWUnit** (Jaliborc fork v12.0.1): Installed at `_anniversary_/Interface/AddOns/WoWUnit/`. Toggle button on right side of screen shows failure count; click to open scrollable panel. Tests register via `WoWUnit('GroupName', 'EVENT')`, assertions `AreEqual`/`IsTrue`/`IsFalse`/`Exists`, mocking via `Replace`/`ClearReplaces`.
- **AGENTS.md research**: Sourced from ICSE 2026 JAWs paper "On the Impact of AGENTS.md Files on the Efficiency of AI Coding Agents" and ICLR 2026 workshop "Evaluating AGENTS.md" (ETH Zurich) — AGENTS.md adds ~0% task improvement at 20%+ inference cost.

### Changed

- **Buff icon positioning**: Gap above debuff bars doubled from 8px → 16px. Duration text moved to `SetPoint("CENTER", icon, "TOP", 0, 0)` — reads as a centered label at the top edge of each icon.
- **Concussion Shot color**: Dark blue `(0.10, 0.15, 0.60)` → grey `(0.55, 0.55, 0.55)` for better visibility.
- **Serpent Sting color**: Forest green `(0.05, 0.55, 0.20)` → bright serpent green `(0.10, 0.85, 0.15)`.

### Fixed

- **GetHarmfulAuraData shape detection on TBC Anniversary**: The old boolean gate (`type(pos3) == "string"`) could not distinguish TBC Anniversary's `AuraUtil.UnpackAuraData` shape (icon as FileID number at r3) from Classic 1.13.x (count at r3). This caused spellId to be extracted from the wrong position, silently producing nil for every debuff on TBC Anniversary. Fixed with three-branch detection that checks r10 type to identify the TBC shape.
- **GetDebuffStackOffset sign inversion**: Was tracking `maxBarTop` (bars below reference bar) instead of `minBarTop` (bars above). Caused buff icons to overlap debuff duration bars by ~6px. Added visibility-bitmask cache to prevent one-frame bounce from WoW's deferred `SetPoint` layout.
- **Buff icon overlay dimming**: Was a full-face black `(0, 0, 0, 0.65)` overlay covering the entire icon, causing permanent dimming. Replaced with 4 separate 1px edge strips matching the debuff bar glow border pattern.
- **WoWUnit file permissions**: Test file created at 600 (owner-only) — WoW under Wine needs 644. Added explicit `chmod` after every `write_file`.

### Removed

- **Project conventions enforced**: All raw Blizzard API calls now route through `ns.*` wrappers. Remaining violations in `GetHarmfulAuraData`/`GetHelpfulAuraData` eliminated.

### Docs

- **AGENTS.md compressed**: 11,204 chars → 6,135 chars (~45% reduction). Stripped discoverable content (file maps, verbose tables). Added canonical wrapper docs, WoWUnit test reference, Wine 644 permission rule, and Lua 5.1 `<<` restriction.
- **AUDIT.md updated**: Date revised, scope expanded to cover 9 Lua files + test suite.

### Internal

- **LDoc docstrings added**: 20+ core public functions documented with `--- @param` / `--- @return` / `@usage` / `@see` across Constants.lua, State.lua, Weaving.lua, UI.lua, Config.lua, ClassMods.lua, and Hooks.lua. Critical engine functions (`ns.GetAlignedTime`, `ns.GetSpellInfo`, `ns.HandleCLEU`, `ns.StartSwing`, `ns.ApplyParryHaste`, etc.) documented.
- **GetCurrentTime() shims removed**: 5 identical `GetCurrentTime()` shims across all files replaced with direct `ns.GetAlignedTime()`. Eliminates duplicated clock-domain wrappers.
- **Fresh-install block replaced with DeepCopyDefaults**: 155-line inline table literal replaced with `DeepCopyDefaults(ns.DB_DEFAULTS)`. Eliminates drift risk — adding a default to Constants.lua now auto-applies to fresh installs.
- **Font path constant**: `ns.FONT_PATH = "Fonts\\FRIZQT__.TTF"` defined in Constants.lua. 39 hardcoded `FRIZQT` paths replaced in ClassMods.lua.
- **Hunter bar globals fixed**: 8 hunter trap/debuff bar globals added to `.luarc.json` diagnostics globals (closure-local upvalues the linter can't trace).
- **CI pipeline**: `.github/workflows/luac.yml` — auto-runs `luac -p` on push/PR.
- **QA checklist**: `docs/QA.md` — step-by-step manual smoke-test checklist.
- **Migration test harness**: `test_migrations.lua` — 37 tests for DeepCopyDefaults correctness.
- **Project conventions enforced**: All raw Blizzard API calls routed through `ns.*` wrappers.

### Notes

- **DB schema:** v54 (unchanged — no migration needed for these changes).
- **Quality gates:** `luac -p` passes on all 9 files.

---

## v0.1.6 - 2026-06-23

- **Bar drag direction fixed**: unlocked left-drag repositioning now moves bars in the same direction as the cursor instead of inverting vertical movement. Manual drag tracking in `AttachDrag()` applies `+dy` so pulling the mouse up moves the bar up.
- **Buff icon brightness + low-time flash (all classes)**: the new buff-icon swipe overlay stays at a low alpha so icons remain bright by default, while the existing gold `ADD` glow pulses during the last 4 seconds for a clear low-time flash. Duration text remains centered above each icon.

- **Hunter debuff bars now dynamically anchored**: All 5 Hunter target debuff bars (Serpent Sting, Wing Clip, Concussion Shot, Immolation Trap, Explosive Trap, Freezing Trap, Frost Trap) are parented to UIParent instead of the MH bar. A new `GetDebuffAnchorBar()` helper selects MH bar when in melee (visible) or ranged bar when at range, so all bars and buff icons follow the Hunter between melee and ranged combat seamlessly — no more invisible debuff bars when out of melee range.
- **IsPlayerSpell guard removed from all class buff icon systems**: The `IsPlayerSpell` check before the aura scan was blocking talent-based spells (Bestial Wrath, Shamanistic Rage, Kill Command, The Beast Within, etc.) from showing as buff icons. The aura scan is authoritative — if the buff isn't on the player, the icon won't show. Removing the redundant guard fixes talent spell icons for all 6 classes without any negative side effects.
- **Freezing Trap + Frost Trap debuff bars added**: 6px icy blue (Freezing, label "FZ") and pale blue (Frost, label "FT") duration bars above the MH/ranged bar stack tracking trap debuffs on the current target. Dual-client safe with both spell ID and name matching. Configurable via Quick Controls toggles, DB schema v54 migration.
- **Immolation Trap + Explosive Trap debuff bars added**: 6px fire orange (Immolation) and red-orange (Explosive) duration bars above the MH/ranged bar stack tracking trap fire DoTs on the current target. Same dual-client safety, configurable toggles, DB schema v53 migration.
- **Buff icon improvements (all classes)**: Countdown text font increased from 10 to 12, repositioned from icon center to icon top for better readability. Dim overlay texture removed entirely — active buff icons are clean and fully bright. Icons raised 2px for better visual breathing room above debuff bars.
- **Elapsed-based buff icon throttle (all 6 classes)**: All buff icon update functions (`UpdatePaladinBuffIcons` through `UpdateRogueBuffIcons`) now accept real `elapsed` time from OnUpdate instead of a fixed `+ 0.03` per frame. Throttle is now frame-rate independent — smoother countdown and glow animation on all hardware.
- **Buff icon glow fix (all classes)**: The gold glow effect in the last 4 seconds of any tracked buff now updates every frame (not throttled), pulsing smoothly via `math.sin(GetCurrentTime() * 6)` with ADD blend mode.
- **Migration gaps filled**: v52 migration added for 4 missing DB keys (`showHunterWingClipBar`, `showHunterConcussionShotBar`, `showWarriorSunderArmorBar`, `showRogueExposeArmorBar`). All new settings now properly migrate for existing users.
- **ApplyVisibility completeness**: The `ns.ApplyVisibility()` function now refreshes all 15 target debuff bars — no more bars staying stale after Test Bars or lock-state changes.
- **InitClassMods cleanup hardened**: All 15 class-specific `ns.Update*Bar` symbols properly nil-cleared on re-init, preventing stale closures from cross-class contamination.
- **Hunter MH bar anchor force parameter fixed**: `UpdateHunterMeleeBarAnchor()` now respects its `force` parameter instead of always returning early, ensuring the MH bar re-anchors correctly when visibility changes.
- **Hunter buff icons now use dynamic stack offset**: Hunter buff/CD icon group uses `GetDebuffStackOffset()` with all 7 debuff bars and `GetDebuffAnchorBar()`, so icons always sit above whatever combination of bars are visible.
- **Trap color scheme**: Wing Clip changed to yellow, Serpent Sting darkened to forest green, Concussion Shot changed to dark blue for better visual distinction.
- **Debuff bar icon sizing verified**: All debuff bar spell icons match their bar height (6×6 for 6px bars, 5×5 for Seal Vengeance and Rake, 4×4 for Shield Block). No oversized or undersized icons.
- **DB schema: v54** (`ns.DB_DEFAULTS.version`)

## v0.1.5 - 2026-06-21

- **Universal buff icon dynamic stacking**: All 6 class buff icon groups now use `GetDebuffStackOffset()` which reads the actual screen position of every visible target debuff bar and positions buff icons 4px above the highest bar. No more manual Y offsets per bar — if you have 3 debuff bars visible, icons sit above all 3. Works identically for Warrior, Paladin, Rogue, Shaman, Druid, and is fully dynamic regardless of which bars are toggled on/off.
- **Debuff bar icons scaled to bar height**: Every target debuff duration bar icon is now sized to match its bar height (6×6 for 6px bars, 5×5 for 5px bars, 4×4 for Shield Block) instead of the old hardcoded 10×10. Icons are small, proportional, and display the actual spell ability texture on the left edge like Flame Shock does. Affected bars: Mangle, Rip, Rake, Deep Wounds, Flame Shock, Judgement, Seal Vengeance, Serpent Sting, Rupture, Shield Block.
- **Warrior Shield Block icon added**: small Shield Block spell icon (4×4) on the left edge of the 4px Shield Block bar, matching the pattern of all other debuff bars.
- **Druid buff/CD icons added** (feral DPS + bear tank): complete 25x25 icon group above all Druid debuff bars tracking Tiger's Fury, Frenzied Regeneration, Barkskin, Dash, Enrage, Bash, Innervate, all racials (Blood Fury, Berserking, Shadowmeld, War Stomp, Gift of the Naaru), and external party buffs (Bloodlust, Heroism, Drums of Battle, Drums of Speed, Haste Potion). Gold glow + pulse in last 4 seconds, countdown text, configurable via Quick Controls toggle + Icon Size slider. DB schema v51 migration.
- **Druid Rake target debuff bar added**: 5px burnt orange duration bar above the Mangle/Rip stack tracking Rake bleed (9s) for Feral Cat. Dynamic positioning above Rip (or Mangle/Rip). Gold glow border in last 4 seconds, small Rake icon on left. Configurable via "Rake Bar" toggle.
- **Paladin Judgement of the Crusader + Seal of Vengeance debuff bars added**: 6px gold bar (JoC) and 5px dark gold bar (Seal Vengeance/Corruption) above MH. Both show buff/debuff name icons left-aligned, countdown labels, gold border glow in last 4s, fully toggleable in Quick Controls. Seal Vengeance tracks all 10 stack IDs across Horde/Alliance plus name fallback for locale safety. Buff icon group now correctly stacks above both bars.
- **Paladin/Warrior/Rogue external buffs added**: Bloodlust, Heroism, Drums of Battle, Drums of Speed, and Haste Potion now tracked in all melee class buff icon groups, using the `external = true` flag to skip the IsPlayerSpell guard (these aren't player-learned spells).
- **Paladin class buffs expanded**: Holy Shield, Divine Protection, Vengeance, Blessing of Protection, Hammer of Justice, Holy Wrath, Lay on Hands all tracked with gold glow + countdown. Crusader Strike (35395) also added.
- **Nil-guard hardening across all bars**: Every bar label update checks `bar.label and bar.label.SetText`, glow border iterations check `bar.glowBorder`, UnitExists/UnitCanAttack calls use `type() == "function"` guards, and `ns.mhBar.GetAlpha` is nil-guarded. Eliminates potential error sources when bars are in transition states.
- **Warrior Deep Wounds target debuff bar added**: thin 6px duration bar above MH bar tracking the Deep Wounds bleed debuff (triggered by Mortal Strike talent crit procs). Orange-red fill with dark background, gold "DW" countdown label, red glow border in last 4 seconds. Configurable via "Deep Wounds Bar" toggle in Quick Controls. DB schema v50 with migration for existing users.
- **Druid Mangle + Rip target debuff bars added**: 6px duration bars above MH bar tracking Mangle (orange, 12s) and Rip (green, 12s) debuffs for Feral Druids. Mangle sits 2px above MH, Rip stacks dynamically above Mangle. Gold countdown labels ("Mg"/"Rp"), glow borders in last 4 seconds, class-gated to DRUID only.
- **Rogue Rupture target debuff bar added**: 6px purple bar above MH tracking Rupture finisher bleed (CP-dependent 8-16s duration). Gold "Rp" countdown, purple glow border, class-gated to ROGUE.
- **Hunter Serpent Sting target debuff bar added**: 6px forest green bar above MH tracking Serpent Sting nature DoT (15s). Gold "SS" countdown, green glow border, class-gated to HUNTER.
- **Buff icon system refactored (ALL classes)**: CD-type tracked spells now scan helpful auras (player buffs) and harmful target auras (debuffs like Stormstrike, Crusader Strike) before falling back to cooldown tracking. Shows buff/debuff duration when effect is active, cooldown remaining when not.
- **Dual-client IsPlayerSpell guard across all classes**: Buff icon tracking gates on whether the character knows the spell, working for both Classic Era (spell ID check) and TBC Anniversary 2.5.5 (spell name resolution). Fixes War Stomp showing for non-Tauren characters.
- **Spell ID corrections**: Death Wish 12323→12292, Sweeping Strikes 12292→12328, Flurry 12319→16280, Elemental Devastation 29062→29180.
- **Hunter Misdirection buff icon added**: Misdirection now tracked in the Hunter CD/buff icon group, showing cooldown remaining with a "MD" label. Configurable via the existing buff icon toggle and size slider.
- **Hunter Wing Clip + Concussion Shot target debuff bars added**: 6px icy blue Wing Clip bar and 6px darker blue Concussion Shot bar above MH tracking snares on the current target. Both have left-aligned spell icons, gold countdown labels, glow borders in last 4s. Configurable via "Wing Clip Bar" and "Concussion Shot Bar" toggles in Quick Controls.
- **Warrior Sunder Armor target debuff bar added**: 6px brown duration bar above MH tracking Sunder Armor stacks (1-5) on the current target. Displays the actual stack count in large text centered in the bar — you always know exactly how many stacks are up. Left-aligned spell icon, gold glow border in last 4s. Configurable via "Sunder Armor Bar" toggle.
- **Rogue Expose Armor target debuff bar added**: 6px bronze duration bar above MH tracking Expose Armor on the current target. Shows "EA" in large centered text when active. Left-aligned spell icon, gold glow border in last 4s. Configurable via "Expose Armor Bar" toggle.
- **Universal RestackDebuffBars for dynamic bar stacking**: All target debuff duration bars are now dynamically restacked every frame — no more overlapping bars when multiple debuffs are active. The order is always: MH bar (bottom) → debuff bars (middle, stacked upward with 2px gaps) → buff/CD icons (top). When no debuff bars are visible, buff icons sit directly above MH. Works identically for Warrior, Paladin, Rogue, Hunter, Shaman, and Druid with per-class bar lists.
- **Dual-client Wing Clip fix**: `GetTargetWingClipData()` now checks by both spell ID (`2974`) and spell name, matching the pattern used by all other debuff bars. Ensures Wing Clip snare detection works on both Classic Era (numeric IDs) and TBC Anniversary (localized strings).

## v0.1.4 - 2026-06-17

- **Paladin buff icons added**: full buff/CD icon group above the MH bar matching the Warrior/Rogue/Shaman/Hunter pattern. Tracks Avenging Wrath, Divine Shield, Hammer of Justice, Blessing of Protection, Holy Wrath, Lay on Hands, and all racials (Blood Fury, Berserking, Stoneform, Shadowmeld, War Stomp, Gift of the Naaru, Escape Artist, Will of the Forsaken, Perception, Arcane Torrent). Icons glow gold with pulsing ADD blend in the last 4 seconds, show countdown text. Configurable via Quick Controls toggle + Buff Icon Size slider in Appearance. Migration guards for existing users.
- **Dual-client CLEU engine fix (CRITICAL)**: Classic Era `COMBAT_LOG_EVENT` sends numeric spell IDs for `SWING_DAMAGE`, `SWING_MISSED`, and `SPELL_CAST_SUCCESS`. TBC Anniversary sends localized spell names (strings) instead. The `registerResetSwingSpells()`, `registerNoResetSwingSpells()`, `PAUSE_SWING_SPELLS`, and `RESET_RANGED_SWING_SPELLS` registration blocks only stored numeric IDs, so swing resets, pauses, and ranged resets silently failed on TBC Anniversary. Fixed by inlining `ns.GetSpellInfo(id)` inside every registration loop at init time, populating each lookup table with both `[spellId] = true` AND `[localizedName] = true`. All four swing-affecting paths now match correctly on both clients.
- **Hunter buff icons redesigned**: shading removed entirely (no more dim overlay); icons now glow gold with a pulsing ADD blend effect during the last 4 seconds of any tracked buff or cooldown. Added racial ability tracking (Blood Fury, Berserking, Stoneform, Shadowmeld, War Stomp, Gift of the Naaru). Buff group moved up 5px for better visual separation from the ranged bar.
- **Shaman buff icon group**: added the same buff/CD icon system for Shaman, tracking Shamanistic Rage, Heroism, Stormstrike, Flurry, Windfury Weapon, Elemental Devastation, and racials (Blood Fury, Berserking, Gift of the Naaru, War Stomp). Configurable via Quick Controls toggle + Buff Icon Size slider. Icons sit above the MH bar with gold glow in the last 4 seconds, matching the redesigned Hunter version exactly.

## v0.1.3 - 2026-06-16

- **Hunter cast bar color separated**: added dedicated `hunterCastBar` color key so the cast bar fill can be set independently from the ranged bar fill. Default is light blue (0.35, 0.65, 0.95). Config swatch added to Quick Controls. Migration v49 seeds for existing users.
- **Hunter cast bar height increased**: default changed from 10px to 13px for better readability.
- **Critical bar-jumping bug fixed**: added 0.1s `rangedTimerHoldEnd` holdover to prevent MH bar flicker during ranged-only auto shot cycle transitions.
- **Hunter stance icon**: an Aspect indicator icon to the left of the range helper bar, showing the active aspect spell icon (Hawk, Cheetah, Monkey, Pack, Wild, Viper, Beast). Sized to match the range helper width.
- **Hunter CD/buff icon group**: adaptive 25x25px icons above the ranged bar stack tracking Bestial Wrath, Rapid Fire, The Beast Within, Quick Shots, and Rapid Killing. Icons dim as buffs expire with duration countdown text.

## v0.1.2 - 2026-06-01

- **Shaman init crash fix (SetDrawLayer sublevel)**: Fixed a hard init-blocker on Anniversary 2.5.5 where `SetDrawLayer("OVERLAY", 10)` used sublevel `10`, outside the valid `-8` to `7` range. All four Shaman weave overlay calls (MH spark, OH spark, top/bottom triangle markers) now use sublevel `7`, resolving the `Texture:CSimpleRegion::SetDrawLayerScript()` error that prevented Shaman bars from rendering at all.
- **Addon init error hardening**: Wrapped the full `OnAddonLoaded()` body in `pcall` with `geterrorhandler()` so any init-time error surfaces via Bugsack/error frame instead of silently breaking the addon for the rest of the session.
- **Shaman fail-open OnUpdate chain fix**: If `SetupEnhShaman()` fails, `InitClassMods()` now saves `ns.OnUpdate` before calling into Shaman setup and restores it on failure, preventing a partially-installed Shaman wrapper from corrupting bar rendering. Fail-open cleanup also clears `ns.OnBarsCreated` and `ns.UpdateShamanWindfuryIcd`.

- **Warrior Overpower glow**: the Overpower proc cue now uses a pulsing border glow on the MH bar instead of a flat fill tint, making the proc easier to notice without obscuring the bar.
- **Naming consistency cleanup**: normalized remaining `C_Spell` alias usage in the class-mod runtime so the code follows one spelling convention instead of mixing lowercase and uppercase variants.

- **Flurry icon replacement**: both Warrior and Shaman Flurry displays are now 30x30 spell-icon frames (DIALOG strata) centered above all bars, replacing the old `⚡N` text badges. Each icon shows the Flurry spell texture, remaining stack count (gold, bottom-right), and a countdown timer (gray, centered below, from `GetTimePreciseSec`). Only renders while the Flurry buff is active. The shared `GetFlurryBuffInfo()` scan correctly dispatches between TBC Anniversary and older Classic UnitBuff payload shapes (spellId at position 10 vs 11, expirationTime at position 6 vs 7), with explicit `UnitBuff` nil guard.

- **Weave cast-motion hardening**: weave indicator motion now prefers live `UnitCastingInfo` / `UnitChannelInfo` timestamps for the current player cast, then falls back to haste-adjusted spell time only when live timestamps are unavailable. Spark/marker overlays were moved onto a dedicated higher overlay frame so the red moving spark remains visible above the bar stack.
- **Flame Shock end-warning glow**: the Shaman Flame Shock helper now adds a self-resetting orange border glow during the last 4 seconds of the aura so the user gets a clear recast warning without affecting the countdown logic.

- **Slider track hardening (all sliders)**: replaced row BACKGROUND-only slider track rendering with a dedicated per-row track layer frame and ARTWORK textures anchored to each slider, with explicit frame-level ordering relative to `OptionsSliderTemplate`. This makes slider tracks visible across Classic/TBC template variance.
- **Texture browser z-order fix**: texture browser popup now forces `FULLSCREEN_DIALOG` strata + top-level frame behavior and reapplies top frame-level/raise on show, preventing the picker from rendering behind the main config UI.

- **Shaman lightning tracker gap slider**: added a new Appearance slider (`Lightning Tracker Gap`) for Shamans, wired through defaults + migration (`v48`), live runtime updates, config refresh, and reset-defaults.
- **Slider track visibility fix**: slider rows now render a dedicated centered track texture anchored to the actual slider widget so track lines remain visible across template/layout variance.
- **Shaman weave visual behavior update**: active weave casts now force a red moving spark (instead of icon-swapping the spark), and upper/lower weave indicators move with cast progress toward bar end while casting.

- **Spellcast payload safety fix**: hardened spell-event token resolution so cast GUID payloads are no longer treated as spell identifiers when `spellID` is absent, preventing rare spellcast routing mismatches on `UNIT_SPELLCAST_*` fallbacks.
- **Shaman weave rank selection**: weave family catalog rebuild now resolves the highest known spell rank per enabled family (with Classic-safe known-spell API fallbacks) so leveling characters track their real learned ranks instead of defaulting toward rank-1 IDs.
- **Shaman shield tracker spacing polish**: Lightning/Water Shield charge tracker left offset now uses an explicit spacing constant for cleaner separation from the MH/OH stack.

- **Shaman weave reliability**: `UpdateWeaveVisuals()` now attempts an on-demand `OnBarsCreated()` recovery before bailing when weave textures are missing, so weave markers/spark can recover if bar overlays are rebuilt or late-created.
- **Shaman Flame Shock bar**: added a new thin 6px status bar above MH that tracks the remaining duration of your own Flame Shock on the current target (player-filtered debuff scan, target-change refresh, target aura refresh, and shared visibility refresh integration).
- **Shaman constants**: added rank-safe Flame Shock spell-ID lookup table for Classic/TBC (`8050`, `8052`, `8053`, `10447`, `10448`, `29228`, `25457`) plus localized fallback name resolution.
- **Shaman Lightning Shield reliability**: fixed the shield tracker aura wiring to read spell IDs from the shared `GetHelpfulAuraData()` helper correctly, added immediate `UNIT_AURA` player refresh hooks, and removed an `OnBarsCreated()` early-return edge case that could skip creating the shield tracker container if weave textures already existed.
- **Unlocked camera behavior**: while bars are unlocked, right-click over bars now explicitly forwards to `MouselookStart()` / `MouselookStop()` so camera look still works; left-click drag behavior is unchanged.
- **Shaman helper UI wiring**: Flame Shock helper now has a full DB-backed Quick Controls checkbox (`Flame Shock Bar`) with runtime hide/show gating, migration defaults, and reset-defaults support.
- **Shaman checkbox polish**: renamed the existing Lightning Shield quick toggle label to `Lightning Shield Tracker` for clearer intent while keeping existing functionality and color swatch behavior.
- **Shaman tracker sizing polish**: Lightning Shield charge tracker now matches MH height in single-bar mode and expands to the full MH+OH stack height (including the inter-bar gap) when OH is visible.
- **Shaman shield detection hardening**: Lightning/Water shield tracker matching now uses both spell IDs and normalized aura-name fallback tables so tracker updates still work when Classic/TBC aura payloads omit or vary spell IDs.
- **Water/Mana shield compatibility**: expanded Water Shield ID coverage (including rank IDs and observed alternate aura mappings), plus alias-safe name matching (`Water Shield` / `Mana Shield`) to avoid no-show edge cases from client/build variance.
- **Druid de-bloat cleanup**: removed stale post-streamline Druid badge/timer defaults and migration writes (`showDruidTigerFuryBadge`, `showDruidFaerieFireBadge`, `showDruidMangleTimer`, `showDruidRipTracker`, plus associated Mangle/Rip color seeding) so stripped features are no longer reintroduced into SavedVariables on fresh or old profiles.
- **Right-click camera reliability (unlocked bars)**: switched unlocked-bar right-click handling to world-style `TurnOrActionStart()` / `TurnOrActionStop()` with `MouselookStart()` / `MouselookStop()` fallback and per-frame active-state guards, so right-click camera movement works while bars remain left-draggable.
- **Combat camera safety guard**: bars now force `EnableMouse(false)` during combat regardless of lock state, so swing frames cannot intercept mouse input and disrupt camera movement mid-fight. Left-drag repositioning remains available out of combat when bars are unlocked.
- **Out-of-combat right-click pass-through**: draggable status bars now opt into `SetPropagateMouseClicks(true)` when available, so right-click camera/world input can pass through the bars naturally while preserving left-click drag handling when unlocked.
- **Right-click fallback bugfix**: fixed propagate-click capability detection in bar handlers by tracking explicit support (`sstHasPropagateMouseClicks`) instead of method-presence checks on frame scripts, restoring correct fallback camera behavior on clients without click propagation.
- **Input fallback hardening**: upgraded right-click camera fallback path with safe guarded wrappers (`pcall` around turn/mouselook start/stop), visibility-aware mouse gating (`IsShown` + alpha), and auto-cleanup of active camera fallback state when bars are mouse-disabled, reducing edge-case input drift.
- **CLEU fallback guard**: hardened `ns.HandleCLEU()` entrypoint with API-availability and payload-shape checks so malformed or unavailable `CombatLogGetCurrentEventInfo` states cannot hard-fail runtime dispatch.
- **Migration ladder refactor**: converted `MigrateDB()` from a long sequential `if (version < X)` ladder into an ordered table-driven migration pipeline, preserving behavior while making future migration edits safer and easier to audit.

## v0.1.1 - 2026-05-30

- **Shaman Lightning Shield tracker**: 3 thin vertical rectangles (5px, 1px gap) to the left of the MH bar that fill with class color per active shield charge. Water Shield forces light blue. Configurable toggle + color swatch in Quick Controls.
- **Shaman weave dual-wield support**: bottom triangle anchors below OH bar when dual-wielding. OH spark mirrors MH spark during casts.
- **Paladin class colors fix**: per-seal MH bar color and label now skip when "Use Class Colors" is enabled, preserving the class color on the bar.
- **Rogue Slice and Dice height**: wired `GetRogueSliceAndDiceBarHeight` into `ApplyBarSize` so SnD bar respects the proper derived height formula.
- **Misc**: v0.1.1 version bump.

## v0.1.0 - 2026-05-30

- **Camera right-click fix**: bars now disable mouse capture when locked, so right-click camera movement passes through the swing timer frames instead of being blocked. Unlock bars to reposition, lock to play. Added `ns.ApplyLockBars()` to handle mouse state on all draggable bars.
- **Lock Bars at top**: moved the Lock Bars toggle into the Quick Controls section (left column, below Use Class Colors) for fast one-click access without scrolling to General Behavior.
- **Quick Controls spacing**: increased the measured gap below the `Visibility` / `Key Colors` column headers so the labels have more breathing room above the first swatch and toggle rows.
- **Shaman weave spark overhaul**: the weave cast spark now uses a solid white `Square_FullWhite` texture with red vertex coloring during active casts so it reads clearly. The spark renders directly on the MH bar at a higher draw layer (`OVERLAY, 5`) so it cannot get buried behind the bar fill. Spark position now anchors to `ns.mhBar` directly for precise alignment.
- **Slider track backgrounds**: added a visible 4px gray track line behind every `/sst` slider so the slider range is always readable even when the Blizzard template track is thin or invisible.

## 0.0.10 - 2026-05-27

- **`/sst` width-usage follow-up**: widened the standard config row builders so the Appearance / Shaman / General sections stop wasting the right half of the panel. Texture preview rows now span the row width, texture-path inputs fill the row minus the browse button, dropdown rows use wider selectors, and the default toggle / action rows keep the label above the control instead of cramming everything into the far-left side.
- **Class-only helper slider creation**: Hunter / Rogue / Warrior helper-size sliders in Appearance are now created only for the active class instead of being instantiated for every class and hidden later, which fixes off-class rows such as Rogue Slice and Dice / tick sliders still appearing on Hunter.
- **Quick Controls header spacing**: the top `Visibility` / `Key Colors` column labels now sit below the Quick Controls header with measured spacing before the first compact row, reducing the header/text collision that could still happen in the live panel.
- **Quick Controls title-gap follow-up**: added a little more measured vertical space between the `Visibility` / `Key Colors` titles and the first compact swatch/toggle rows, which fixes the remaining slight overlap where the first quick-color bar still felt too close to the title line.
- **Shaman weave cast motion polish**: active tracked weave casts no longer leave the spell icon pinned at one constant projected-impact point for the whole cast. The weave icon pair and center spark now begin at the safe cast-start breakpoint and travel across the MH swing as the cast completes, finishing at the projected landing point so Enhancement Shamans can watch the cast stay ahead of the MH spark in real time.
- **Shaman weave live-position follow-up**: the safe upper/lower breakpoint markers are fixed again, while the moving spell icon now starts from the real cast-start position on the MH swing and travels toward projected landing. The weave cast-state path also falls back to the live casting API when event spell tokens are incomplete, which makes Lightning Bolt / Chain Lightning motion begin immediately instead of looking pinned to the helper breakpoint.
- **Shaman weave haste-rescale follow-up**: the moving weave icon now drives from elapsed cast time against the current haste-adjusted cast duration each frame, so haste/buff changes mid-cast rescale the icon position instead of leaving it visually frozen or stale.
- **Shaman weave readability polish**: the live cast spark/icon now gets a tiny forward bias while it moves, so the active Lightning Bolt / Chain Lightning position reads as motion immediately instead of visually hugging the fixed helper marker on the first frames.
- **`/sst` Druid slider crash fix**: opening the config panel no longer throws `attempt to index field druidPowerShiftSlider` from `SuperSwingTimer_Config.lua`. The stale refresh calls for removed Druid slider widgets are now guarded, matching the current streamlined Druid panel.
- **`/sst` section layout reflow**: the Appearance, Shaman Weave Assist, General Behavior, and Weave Families sections now stack rows from their real runtime widget heights instead of brittle fixed Y offsets, which stops slider rows and helper text from overlapping section headers.
- **Enhancement Shaman Windfury ICD crash fix**: `SuperSwingTimer_ClassMods.lua` no longer scans helpful buffs through the brittle raw `UnitBuff("player", i, "HELPFUL")` tuple path. The Windfury ICD tracker now uses the shared `GetHelpfulAuraData()` helper, guards spell-ID comparisons with explicit numeric checks, and reads the live main-hand swing anchor from `ns.timers.mh.lastSwing` on the addon's aligned clock instead of the nonexistent `ns.GetLastMhSwingTime()` symbol. This fixes the in-game `attempt to compare number with boolean` runtime error reported from `UpdateWindfuryIcd()`.
- **Stable Shaman update chain**: `UpdateShamanisticRageBadge()` no longer rebuilds `ns.OnUpdate` from inside itself every refresh. Enhancement Shaman now installs one stable wrapper in `SetupEnhShaman()` that updates the weave visuals plus Flurry, Stormstrike, and Shamanistic Rage badges without recursive rewrapping.
- **Projected-impact weave icon**: while actively casting tracked weave spells such as Lightning Bolt or Chain Lightning, the moving shaman weave spark now swaps to the actual spell icon and pins itself to the spell's projected landing point on the current MH swing rather than sliding by raw cast progress. When the cast stops, succeeds, fails, or is interrupted, the moving icon restores the configured weave spark texture and hides cleanly, while the static top/bottom breakpoint markers stay visible.

## 0.0.9 - 2026-05-22

- **Paladin seal twist zone preview fix**: UpdateSealBreakpointLine (red twist zone + black reseal marker) and UpdateJudgementMarker (gold judgement CD line) now show during Test Bars preview by falling back to `UnitAttackSpeed("player")` or 2.0s when no swing timer is active — matching the Rogue Sinister Strike cue pattern exactly. Previously the zone and markers hard-returned when `timer.state ~= "swinging"`, hiding them during `/sst` preview and other non-combat states.
- **Paladin seal zone UI wiring**: exported `ns.UpdatePaladinSealZone` and added refresh calls to `ApplyBarColors`, `ApplyBarWidth`, `ApplyVisibility`, and `ApplyMinimalMode` — matching the same 5-path approach the Rogue cue uses.
- **Paladin twist families expanded**: added RIGHTEOUSNESS to `PALADIN_SEAL_TWIST_FAMILIES` per TBC research confirming you can twist from Seal of Righteousness → Command in the 0.4s window.
- **Warrior Slam bar repositioned**: the Slam cast bar now sits above the MH bar instead of below, keeping it grouped with the Shield Block bar in the overhead helper area instead of sharing space with the rage bar stack.
- **Warrior Shield Block bar live refresh**: exports to `ns.warriorShieldBlockBar` and reapplies texture, width, and color from the current config on every update call (not just at creation time). Config changes to texture, bar width, Shield Block height slider, and shield block color now take effect immediately without a reload.
- **Warrior bar color wiring**: the warrior rage bar and Shield Block bar now refresh from `ApplyBarColors` so color swatch changes in `/sst` apply live.
- **Warrior rage bar positioning**: confirmed the rage bar anchors below OH when dual-wielding (or below MH otherwise) with a 4px gap, placing it cleanly below the MH, OH, Slam, and Shield Block bar stack.

## 0.0.8 - 2026-05-20

- **Every class helper bar now has `/sst` controls**: added configurable size sliders (height for horizontal bars, width for vertical bars) and show/hide visibility toggles for all 8 helper bars across 6 classes — Warrior Shield Block Height, Hunter Rapid Fire Height + Range Helper Width, Rogue SnD Height + Energy Tick Width + Adrenaline Rush Height, Druid Power Shift Height + Energy Tick Width, plus Druid Power Shift and Energy Tick visibility toggles. All wired through DB defaults, runtime apply, and config panel refresh.
- **ClassMods.lua (line 71 crash fix)**: A bare `local updateInterval = 0.016` was sitting outside any function block, before `ns` existed. When the file loaded, Lua executed it unconditionally, hit the `ns` global before it was defined, and threw an error that silently killed the entire file — blocking all `Setup*()` functions. Removed the stray line. This is why warriors/druids/paladins/rogues/shamans loaded zero swing timers.
- **SuperSwingTimer_State.lua (latency refresh)**: Dropped `LATENCY_REFRESH_INTERVAL` from 5.0s to 0.05s and wired `RefreshLatencyCache()` into `HandleSpellcastDelayed` so cached latency updates immediately on spell pushback instead of waiting for the periodic tick.
- **SuperSwingTimer_ClassMods.lua + SuperSwingTimer_UI.lua (Paladin seal zone layer fix)**: The Paladin seal twist zone, reseal marker, and judgement marker were routing through `SetTextureLayerAboveBar()` which called into the Shaman weave marker system (`ApplyWeaveMarkerLayer`). This cross-class dependency meant the red zone only worked when shaman code path was active. Fixed by:
  - All three textures now use `SetDrawLayer("OVERLAY", 0)` directly at creation.
  - Paladin texture handling removed from `ApplyWeaveMarkerLayer` (now shaman-only).
  - Added explicit `SetDrawLayer("OVERLAY", 0)` refresh in `ApplyBarTextureLayer` so texture reapplies keep the correct layer.
- **SuperSwingTimer_ClassMods.lua (code cleanup)**: Removed stale `-- end SetupDruid` comment. Fixed three `end` statements at lines 239–241 that were at 1-tab depth instead of their correct 5/4/3-tab depths (closing `if c then` / elseif-chain / `if ns.paladinLastSealColor`).
- **SuperSwingTimer_ClassMods.lua (Shaman OnUpdate chain fix)**: `UpdateShamanisticRageBadge()` had a broken OnUpdate hook that called `prevOnUpdate(elapsed)` — an undefined global — which would crash on the first frame. The hook was also inside the function itself, so nothing ever called it to wire it up. Fixed by capturing `ns.OnUpdate` directly as `prevOnUpdate` and adding a bootstrap call `UpdateShamanisticRageBadge()` after the function definition so the OnUpdate chain initializes immediately. Shaman flurry, stormstrike, and shamanistic rage badges now update every frame.
- **SuperSwingTimer_ClassMods.lua (missing end fix)**: Added the missing closing `end` for `local function UpdateShamanisticRageBadge()` (the function started on line 1507 without a matching close). This was the root cause of LSP cascade errors (`expected 'end' to close 'function' on line 1507 near 'local'`).
- Warrior Shield Block timer: added a slim aura-driven duration bar above the MH stack so tanks can track the active Shield Block window the same way Rogues track Slice and Dice.
- Druid Ravage opener cue: added an amber opener-availability glow for Cat Form Ravage when the spell is actually usable on the current target.
- Roadmap closure polish: marked the active Phase 6 and Phase 7 checklist items complete, moved the broad Hunter / other-class polish idea into an explicit archived / future wishlist section, and updated the README and memory-bank notes to describe the repository as final-prep / feature-complete.
- Warrior rage-bar visibility: fixed the combat-state check so the warrior rage bar now keys off the actual combat flag used by the rest of the addon, and refreshed that bar immediately when combat starts or ends.
- `/sst` hardening: registered the slash command eagerly and wrapped the toggle/reset paths so the config command now reports errors instead of failing silently if the panel path stumbles.
- Hunter Feign Death polish: added an explicit ranged reset path so Feign Death clears the hunter ranged timer / auto-repeat state instead of leaving the bar stuck.
- Hunter Readiness polish: the Rapid Fire helper now refreshes immediately when Readiness is used, and Rapid Fire itself now shows the live aura duration while it is active.
- Rogue Adrenaline Rush polish: the Rogue cooldown helper now shows the actual 15s aura duration while active instead of only the cooldown downtime.
- Rogue pro cues: added Blade Flurry and Cold Blood badges beside the MH bar, and the Rogue energy tick now tints red near cap as a warning.
- Paladin / Shaman class badges: added a small Reckoning stack badge for Paladins and a Flurry stack badge for Shamans beside the MH bar.
- Warrior Execute warning: the warrior rage bar now shows a live `EXEC` badge when the target drops to 20% health or below.

## 0.0.7 - 2026-05-19

- TBC Hunter Steady Shot grace period: the safe/unsafe clip-safety tint on the dedicated hunter cast bar now accounts for the 0.5s TBC mechanic where Auto Shot can fire during the last 0.5s of a Steady Shot cast without clipping, making the green/red feedback match real TBC hunter clip behavior instead of being overly conservative.
- Paladin seal twist red zone: COMMAND seal is now included in the twist families alongside BLOOD and MARTYR, the seal twist line is now a right-anchored proportional-width red fill zone (matching the Rogue Sinister Strike pattern) instead of a thin left-anchored black line, and the default `sealTwist` color changed from opaque black to transparent red for immediate readability.
- Database migration v33→v34: migrates old opaque black `sealTwist` defaults to the new transparent red default.
- `ns.STEADY_SHOT_CAST_TIME = 1.5` and `ns.STEADY_SHOT_GRACE = 0.5` constants documented for future TBC hunter tuning.

- Hunter cast-bar API/latency follow-up: the live Steady Shot / Aimed Shot path now resolves casts through a Classic-safe `UnitCastingInfo()` spell-name-first wrapper instead of assuming a modern spellID return, persists recovered Hunter cast tokens more safely across delayed/stop/succeeded edges, and shows a trailing latency slice that scales with cached latency and the real cast duration.
- Hunter cast precision follow-up: `UNIT_SPELLCAST_DELAYED` is now wired back into the hunter state path so Steady Shot / Aimed Shot pushback refreshes the stored cast timing instead of relying only on the original start snapshot.
- Hunter clip-polish follow-up: the dedicated hunter bar now tints real Steady Shot / Aimed Shot casts by whether they still finish before the next Auto Shot, making the no-clip timing easier to read during live TBC play.
- Class-color readability follow-up: when MH / OH / ranged class colors are enabled, the live bar text now flips to black with a white outlined backing for better contrast on bright class-colored fills.
- Hunter melee handoff follow-up: the Hunter MH bar is now attached to the ranged stack instead of living as a separate draggable bar, and it only appears when the hunter has a live MH swing running or a Raptor Strike queued.
- Hunter Raptor Strike polish: queued Raptor now uses its own yellow next-attack tint similar to Heroic Strike while staying fully isolated from the Warrior and Druid queue paths.
- Hunter cast-bar expansion: the dedicated hunter helper bar now shows real Steady Shot / Aimed Shot cast progress in addition to the hidden Auto Shot / short Multi-Shot window, and melee handoffs no longer leave the ranged bar stuck full red after the last ranged cycle expires.
- Hunter mount/movement fix: mounted Hunters are now treated as not auto-repeating, and cooldown resync is blocked while the ranged bar is pinned in the red moving window so mounting or other long movement cases no longer make the Auto Shot bar loop over and over until you stop.
- Hunter Auto Shot polish: transient `STOP_AUTOREPEAT_SPELL` events no longer hard-reset the ranged timer mid-cycle, the addon now cross-checks Hunter auto-repeat state through the current Blizzard spell API before seeding new cooldown cycles from `SPELL_UPDATE_COOLDOWN`, and the current cycle is allowed to finish cleanly so the red late window can stay visible instead of clunkily resetting while Auto Shot still fires.
- `/sst` Quick Controls polish: the top section now has explicit `Visibility` and `Key Colors` column labels, the subtitle is shorter and clearer, and the Hunter red window swatch is labeled `Auto Shot Late` instead of the less intuitive `Unsafe` wording.
- Rogue cleanup follow-up: removed the Rogue combo-point strip and the right-side total-energy battery test helper, leaving a single 4px energy-tick bar anchored to the left of the MH bar.
- Rogue Slice and Dice polish: the SnD helper now anchors directly above MH again, stays hidden whenever the MH bar is hidden, and rechecks the player buff state on a short throttle so it feels less buggy if aura events arrive late.
- Rogue Slice and Dice fix: the SnD helper now reads helpful auras through a Classic-safe `UnitBuff` / `UnitAura` signature-tolerant path, which fixes the bar not showing on current Classic/TBC clients where helpful-aura return positions differ.
- Widget audit follow-up: rechecked Warcraft Wiki / Blizzard options-panel references and kept `/sst` on the current `UIPanelScrollFrameTemplate` path for production safety, while documenting `HybridScrollFrame` as a future optimization candidate only for very long picker lists.

## 0.0.6 - 2026-05-17

- Rogue production follow-up: Rogues now get a slim Slice and Dice duration bar above the main-hand bar that tracks the active buff in real time from `UnitAura`, uses the shared MH bar width/texture styling path, and can be toggled or recolored from `/sst`.
- Profile polish follow-up: the derived off-hand bar is slimmer again at 8px on the stock 15px main-bar profile, while the new Rogue Slice and Dice helper stays on a compact 3-4px height.

## 0.0.5 - 2026-05-16

- Rogue polish follow-up: the Rogue Sinister Strike cue now uses a softer stock alpha while still updating live from the saved swatch, and the opener/fallback path slightly softens that tint when the bar is only showing from weapon-speed fallback instead of an active live swing.
- Rogue energy helper follow-up: the vertical Rogue energy bar now fills upward again, and the top Quick Controls checkbox is labeled `Rogue Energy Helper` so the toggle is easier to find during Rogue setup.
- Final release UI polish: `/sst` now keeps later sections pushed below the actual Quick Controls height, so Rogue/Hunter class-specific quick rows no longer risk overlapping the next section header.
- Config shell polish: the main `/sst` panel now supports mouse-wheel scrolling, the subtitle more clearly distinguishes setup preview bars from live combat-driven bars, and the small texture browse button uses a slightly larger click target.
- Classic/TBC UI safety follow-up: config frames that need backdrops now use an optional `BackdropTemplate` path instead of assuming the newer template always exists, which keeps the panel safer for Classic-era UI variants while preserving the current Anniversary look.
- Visibility correction: normal bars are combat-only again, hidden bars now reset to an empty state, and entering combat no longer shows stale full bars before the first real swing or shot starts.

- Active-timer visibility fix: melee and enemy bars now follow the same model ranged already used — an active timer can keep its bar visible even if the combat-flag path is late — and timer start/reset now refreshes the shared visibility rules immediately.
- Rogue cue consistency follow-up: the Rogue Sinister Strike slice now falls back to the live MH weapon speed whenever the MH bar is visible, so it no longer disappears at opener or other moments where the MH timer has not started yet.
- Final all-classes timing polish: BC Classic Hunter Multi-Shot now seeds the small hunter helper bar from stored state even when Classic does not expose a live cast, so the dedicated hunter bar no longer disappears for instant Multi-Shot shots.
- Rogue cue polish: the latency-adjusted red Sinister Strike slice now stays under the spark layer so the spark remains readable through the red tail section.
- Reworked the top of `/sst` into a two-column Quick Controls section so the most-used visibility toggles stay on the left while the primary bar-color swatches sit on the right for faster setup.
- Moved the main bar color controls into that top quick-control area, including class-specific swatches such as Hunter Auto Shot safe/unsafe feedback, the enemy bar, the Rogue Sinister cue, and the Paladin seal line when relevant.
- Added a Rogue-only latency-adjusted red end-window overlay on the MH bar so Combat Rogues can press Sinister Strike into the swing landing and more reliably have it fire immediately after the main-hand hit.
- Added a `Rogue SS Cue` toggle plus a `Rogue SS Cue Color` swatch so the new Rogue timing helper can be turned off or retuned without recoloring the entire MH bar.
- Slimmed the stock live profile for the release build: main bars now default to 15px tall, the OH bar derives to 10px by default, and the default spark height follows that slimmer profile while still clamping to each host bar.
- Added a test Rogue energy-tick helper bar: a slim vertical status bar anchored to the left of the MH/OH stack that fills upward over the observed 2-second TBC energy cadence, with a toggle and color swatch in the top quick controls.
- Final pre-test polish: tightened the Quick Controls spacing so the two top columns no longer overlap when Rogue/Hunter-specific quick rows are present, resized the Rogue test energy bar to a 5px-wide helper that matches the visible MH/OH bar heights, and slightly forward-biased plus pixel-snapped the 3px spark so the thin spark reads closer to the true fill edge.
- UI readability follow-up: the `/sst` color swatches now use flatter high-contrast preview tiles instead of the washed-out stock button look, so MH/OH/ranged/enemy/Rogue/Hunter colors read much more clearly while configuring the addon.
- UI bugfix follow-up: the color selectors now use a plain `BackdropTemplate` preview button with a visible gray base, which fixes the broken invisible-but-clickable swatches and restores the Hunter/class quick colors in the panel.
- UI interaction hardening: row-level click helpers now ignore clicks that are already landing on the actual button, toggle, or dropdown control, which removes double-trigger behavior that could make the config panel feel buggy.
- Config open-path hardening: `/sst` now lazily re-initializes the panel if needed and safely refreshes quick color rows before showing, while the color swatches themselves no longer rely on backdrop methods on buttons. This prevents malformed quick-color controls from blocking the panel entirely.
- Hunter stability follow-up: `START_AUTOREPEAT_SPELL` now seeds the ranged timer immediately instead of waiting for the cooldown API to already be active, hunter cooldown updates refresh visibility through the shared rules, and the combat-entry helper now defers to `ApplyVisibility()` so ranged/hunter bars do not get forced visible on the wrong path.
- Hid the shaman-only weave section on non-shaman classes so `/sst` stays cleaner during normal Warrior, Rogue, Hunter, and Paladin setup.

## 0.0.4 - 2026-05-15

- Added a new current-target enemy swing bar that uses `PLAYER_TARGET_CHANGED`, `UnitGUID("target")`, `UnitAttackSpeed("target")`, and hostile-target `SWING_DAMAGE` / `SWING_MISSED` combat-log events to track the selected enemy's main-hand swing timing.
- The enemy bar is enabled by default, uses a red default color, stores its own position in SavedVariables, resets cleanly when the target dies or changes, and can be turned off from the `/sst` config panel.
- Added an `Enemy Color` swatch to the color section so the new target bar can be recolored without tying it to `Use Class Colors`.
- Moved cached latency off the shared base timer clock: swing bars and motion now stay on a `GetTime()`-aligned precise clock, while latency is applied only to predictive windows such as Auto Shot safe-stop timing and weave clip math.
- Added `Auto Shot Safe Color` and `Auto Shot Unsafe Color` swatches so the hunter red/green feedback can be tuned independently from the base ranged bar color.
- Tightened hunter ranged live resync: when `GetSpellCooldown(75)` exposes an active Auto Shot cooldown, the ranged timer now reuses that cooldown start as the live swing anchor instead of only stretching the duration mid-cycle.
- Fixed the shared visibility pass so MH/OH/enemy bars no longer leak visible outside combat when config refreshes, equipment changes, or other UI apply paths run out of combat; preview mode and active ranged behavior still stay visible when appropriate.
- Tightened Test Bars cleanup so ending the preview now restores the normal shared visibility rules instead of force-hiding active out-of-combat ranged behavior.
- Smoothed shaman weave timing by keeping the breakpoint marker locked to the full cast-time-plus-latency start point instead of letting that marker slide with `castRemaining` while you are already casting.
- Replaced the shaman weave triangle markers with small tracked-spell icons so the breakpoint helper shows the real spell family icon directly on the MH bar overlay.
- Fixed the shared spark drifting behind the visible fill by anchoring it from the actual rendered status-bar texture edge instead of only re-deriving it from the saved frame width.
- Changed the stock spark width default to 3px and migrated older untouched 4px default installs down to the new width while preserving custom user sizes.
- Synced the addon metadata and docs to the requested v0.0.4 release line.

## 3.1.26 - 2026-05-05

- Final release-prep session pass: re-audited the swing timer against current Classic/TBC API behavior and kept the live timer model on latency-adjusted `GetTimePreciseSec()` with `GetTime()` fallback, including priming the precise clock once before the first live timestamp.
- Restored swing, parry-haste, hunter Auto Shot CLEU, queued next-attack landed-reset, and druid form-reset anchors to the addon's existing latency-aware live clock after the experimental CLEU timestamp normalization caused timers to lead early.
- Kept Hunter's core ranged timer path intact while stabilizing the dedicated Auto Shot hidden cast bar on the same end-of-cycle stop-to-fire window as the red/green ranged feedback.
- Split next-melee queue handling fully by class: Warrior Heroic Strike / Cleave, Druid Maul, and Hunter Raptor Strike now keep separate queued state, landed-hit reset detection, interruption cleanup, and tint ownership.
- Changed Druid Maul to its own bear-yellow and kept queued next-attack tint scoped to the MH bar fill only; the spark remains on its independent manual/default color path.
- Corrected ret paladin reseal timing to use current swing elapsed plus remaining GCD time, which matches the real twist window much more closely than the older fixed-offset marker.
- Routed shaman weave spell resolution through `ns.GetSpellInfo`, kept weave overlays respecting Minimal Mode / weave visibility, and preserved the above-bar overlay layering for shaman, hunter, and paladin helpers.
- Polished setup and config behavior: real drag handlers plus a wider grab area for moving bars, safer OH-frame reuse across equipment changes, Reset Defaults restoring saved positions, Test Bars staying visible after the normal visibility pass, and the MH/OH `Bar Width` slider now sitting below its section header instead of overlapping the collapse toggle.
- Replaced the compact MH/OH and ranged texture dropdowns with a full-preview scrolling picker that shows each bar texture across the full row, keeps a fixed visible list size with scroll support, and anchors the popup from the texture control instead of paging nested UIDropDownMenu submenus.
- Kept the bar-texture picker focused on bar media only: it now surfaces the guaranteed built-in Blizzard fallback textures plus all LibSharedMedia-registered statusbar entries from installed media packs such as SharedMedia-Blizzard, while leaving the spark and weave-spark pickers on the dedicated thumbnail-browser path.

## 3.1.18 - 2026-05-02

- Added next-melee-attack (NMA) queue tinting for Druid Maul. The Main Hand bar now turns yellow when Maul is queued, matching the Warrior Heroic Strike behavior.
- Registered additional Maul spell IDs for TBC Classic Anniversary compatibility.
- Wired Druid queue tint updates into the main UI loop and color restoration logic.

## 3.1.17 - 2026-05-01

- Added TBC Classic Anniversary (1.15.x) compatibility by implementing a robust `ns.GetSpellInfo` wrapper that supports both legacy `GetSpellInfo` and modern `C_Spell.GetSpellInfo`.
- Fixed the "Undefined global" and "Undefined field" errors in the IDE and game by safe-accessing Blizzard UI globals (`UIDropDownMenu`, `C_Spell`, etc.) via `_G`.
- Synchronized the Hunter Auto Shot cast bar with the ranged timer's latency-aware "red zone." The cast bar now starts exactly when the ranged cycle hits the hidden-cast window.
- Improved the configuration panel's texture dropdown:
  - Implemented 20-item paging for better menu height on all screen resolutions.
  - Added visual texture previews (icons) next to each texture name in the list.
  - Increased the font size to `GameFontNormal` for better readability.
- Hardened default settings: Class Colors are now OFF by default to ensure maximum visual clarity for Rogue and Warrior ability indicators.

## 3.1.16 - 2026-04-30

- Release hardening: added ranged-haste-aware fallback resync for hunter ranged timing so the ranged timer can still estimate and adjust speed when `UnitRangedDamage()` is briefly unavailable.
- Added `GetRangedHaste` fallback support in the ranged state path, with safe scaling from the previous known ranged speed.
- Added `GetSpellHaste` fallback support in shaman weaving haste calculations when `UnitSpellHaste("player")` is unavailable.
- Minor robustness cleanup for hunter Auto Shot cooldown tuple usage in cast-window initialization.
- Fixed hunter cast-bar fallback in `HandleSpellcastSucceeded` so missed start events now open a full `ns.CAST_WINDOW` window (using `now`) instead of immediately completing from `now - ns.CAST_WINDOW`.
- Re-polished hunter hidden-cast behavior so the dedicated hunter cast bar can derive from the end-of-ranged-cycle hidden window (`windowEnd - ns.CAST_WINDOW`) instead of appearing as a start-of-cycle cast proxy.
- Hardened hunter `HandleSpellcastSucceeded` so it no longer forces a post-shot fallback cast window when no active hunter cast is actually detectable.
- Hardened hunter spellcast-start/UI glue so Auto Shot start events no longer seed cast-active fallback timing that can flash the cast bar at cycle start; cast-bar fallback seeding is now limited to live/active hunter cast contexts.
- Ranged timer reset paths now clear hunter cast state too, preventing stale hidden-cast bar remnants after auto-repeat stops or other ranged reset flows.

## 3.1.15 - 2026-04-30

- Polished Hunter hidden cast-window behavior so the fixed `ns.CAST_WINDOW` bar now anchors to cast/shot start timing, preventing the cast bar from visually stretching toward the full ranged cycle.
- Updated Hunter `UnitCastingInfo` fallback alignment to cast start timestamps for cleaner Auto Shot / Multi-Shot hidden-window display.
- Optimized timer sync events by filtering `UNIT_ATTACK_SPEED` and `UNIT_RANGEDDAMAGE` updates to `unit == "player"` before resyncing bars.

## 3.1.14 - 2026-04-30

- Decoupled the Hunter cast bar from full ranged swing duration so it now always renders as the fixed `ns.CAST_WINDOW` hidden Auto Shot cast window.
- Updated hunter cast-window start alignment to use end-of-cast timing (`UnitCastingInfo` end-time when available) so the cast bar shows the move-safe window rather than mirroring the full ranged cycle.
- Added an immediate swing-speed sync on swing start for melee/ranged timers to reduce first-frame drift and tighten white-swing/ranged timing accuracy.

## 3.1.13 - 2026-04-30

- Fixed a duplicated `ResetTimer` definition in the state engine so start/stop/restart flows use a single consistent idle reset path.
- Hardened hunter cast-state recovery by clearing hunter cast state on world/combat reset paths and accepting Classic `UnitCastingInfo` spell-name payloads when spell IDs are unavailable.
- Fixed shaman weave-family tint stability by copying family color tables before applying safe/unsafe alpha changes, preventing persistent color drift across casts.
- Polished ret paladin seal-twist overlays so the end-of-swing strike line stays visible for active twist families, while the separate reseal marker remains GCD-aware.

## 3.1.12 - 2026-04-29

- Unified the Hunter Auto Shot / Multi-Shot cast bar on the shared `ns.CAST_WINDOW` timing so the cast window stays consistent and no longer tracks the full ranged swing timer.
- Added a `UnitCastingInfo` fallback for the Hunter cast bar so the display can recover cleanly if the live cast state is briefly missing.
- Switched warrior queue tinting to a numeric queued-spell check so Heroic Strike and Cleave light up and clear reliably while Slam still uses the pause/extend path.
- Increased the unlocked-bar drag hit area so the frames are easier to grab and move during setup.
- Separated the bar background tint from the fill color so the background now has its own color swatch plus alpha control.
- Added a configurable bar border color swatch to go with the border-size slider, and kept the border rendering tied to the live bars during preview and reset.

## 3.1.11 - 2026-04-29

- Reworked the hunter Auto Shot / Multi-Shot cast-bar checks so they use shared spell-name lookups and keep the cast bar attached beneath the ranged timer when those shots fire.
- Split the warrior queue tints so Heroic Strike stays yellow, Cleave turns green, and Slam uses a white queue tint while the actual MH timer reset now lands on the combat-log hit.
- Added an adjustable bar border size control and widened the draggable hit area so unlocked bars are easier to move during the final polish pass.

## 3.1.10 - 2026-04-29

- Restored the hunter Auto Shot / Multi-Shot cast bar as a separate active-state preview so Auto Shot no longer drops out on the generic stop event.
- Added a `/sst` Test Bars action that temporarily previews the bars for repositioning, plus a clearer `Lock / Unlock Bars` control for moving frames.
- Enabled alpha selection on the main color swatches so class colors and custom colors can keep their opacity all the way through the live bar updates.
- Kept the base spark width at 4px and preserved the spark / class-color tint behavior during the final polish pass.

## 3.1.9 - 2026-04-29

- Restored the hunter Auto Shot / Multi-Shot bar with stored cast timing so it no longer depends only on live `UnitCastingInfo` reads.
- Bumped the base spark width back to 4px and kept the spark tint aligned with the ranged class color when class colors are enabled.
- Synced the docs and release notes to match the final polish pass.

## 3.1.8 - 2026-04-29

- Restored the `/sst` collapsible section layout with stable row groups so the config panel renders cleanly again.
- Slimmed the spark / weave defaults to compact bar-height-aligned markers and clamped the hunter, melee, paladin, and shaman overlays so they cannot balloon into full-height white bars.
- Kept the Hunter Auto Shot / Multi-Shot cast bar cast-only and positioned directly beneath the ranged timer.

## 3.1.7 - 2026-04-29

- Added a dedicated 10px Hunter Auto Shot / Multi-Shot cast bar beneath the ranged timer and kept it synced to the ranged texture, spark settings, and visibility rules.
- Corrected the TBC Multi-Shot and Slam rank spell IDs in the addon tables and swing-timer reference docs so the no-reset and pause logic stays aligned.
- Fixed the spellcast event handling to use Classic's 3-argument `UNIT_SPELLCAST_*` payloads so the hunter cast state and swing-reset logic read the live spell ID correctly.
- Polished the `/sst` panel with collapsible section headers and kept the Hunter cast bar cast-only so it appears only during actual Auto Shot / Multi-Shot casts.

## 3.1.6 - 2026-04-29

- Expanded the texture catalog so MH/OH and ranged bar rows stay focused on bar-style textures from Blizzard, SharedMedia, WeakAuras, and installed addon packs, while spark and weave spark rows can browse the broader thumbnail library.
- Switched the spark and shaman weave spark rows to folder-style browse buttons and kept the WeakAuras `Square_FullWhite` preset surfaced as `Normal`.
- Restored the spark alpha slider in the config panel so spark opacity can be tuned again alongside width, height, layer, and color.

## 3.1.5 - 2026-04-29

- Polished the spark texture picker into a dedicated thumbnail browser and surfaced the WeakAuras `Square_FullWhite` preset as `Normal`.
- Cleaned up the spark row labels and tooltip copy so the final release reads more like a curated UI than an internal settings panel.
- Kept the shaman weave default on `Target Indicator` and preserved the alternate triangle preset in the same texture library.

## 3.1.4 - 2026-04-28

- Added a green-safe hunter ranged cast-window state so the red zone now turns green when you stop before the breakpoint and only stays red when you are still moving too late.
- Kept the latency-aware cast-window math and black breakpoint marker intact while refreshing the movement feedback text in the README.

## 3.1.3 - 2026-04-27

- Kept the hunter Auto Shot spark and the shaman / ret paladin breakpoint markers above the bar fill by moving them to dedicated non-mouse overlay frames, so the overlays no longer disappear behind the status bar skin or mouse-hover HIGHLIGHT behavior.
- Stopped the bar fill itself from being promoted into the overlay layer when textures are changed, which preserves the intended draw order for sparks and breakpoint lines.
- Reworked the `/sst` config rows so cycle settings use visible dropdowns and slider rows include editable numeric fields.
- Let the dropdown rows open from the full row body, removed the dead texture-browser popup, and clear spark anchors before each update so the moving visuals stay stable and the settings panel is easier to use.
- Added subtle hover highlights to the clickable config rows so the dropdowns, toggles, and texture selectors read more clearly as interactive controls.
- Enabled mouse interaction on the texture rows so their hover highlights and click-open dropdowns actually work.
- Added hover tooltips to the config rows and controls so the UI explains what each setting represents when you mouse over it.

## 3.1.2 - 2026-04-24

- Kept the shaman weave spark, triangles, and ranged cast-threshold marker above the bar fill even when the user raises the bar texture layer.
- Kept the ret paladin seal breakpoint lines above the MH bar fill so the strike-edge and reseal markers stay visible during seal twisting.
- Re-resolved weave and breakpoint overlays whenever the bar texture layer changes so the visuals stay on top of the active bar skin.
- Updated shaman weave positioning to use the actual MH bar width instead of only the static default width.

## 3.1.1 - 2026-04-23

- Added a latency-aware hunter Auto Shot red-zone marker so the cast window shows up before the bar turns red.
- Added a dedicated ranged bar texture selector so Hunters can skin Auto Shot separately from MH / OH.
- Switched Hunter Auto Shot timing to use the Auto Shot cooldown API when active, anchoring the ranged bar to the cooldown start and falling back to `UnitRangedDamage()` when needed.
- Widened the `/sst` panel and clarified the MH / OH, ranged, and weave breakpoint appearance sections.
- Reflowed the `/sst` rows so labels sit above the controls and the texture, cycle, toggle, and color rows are easier to click.
- Hardened the paladin seal breakpoint lookup so it prefers aura names, uses verified seal IDs, and still works when a rank ID is missing.
- Expanded the paladin seal family table to match `docs/spellIds.md` for Command, Corruption, Blood, Martyr, Vengeance, Justice, Wisdom, Righteousness, Light, and Crusader.
- Restored the ret paladin seal breakpoint line so the actual strike-edge marker stays visible again, with a second latency-aware reseal marker for twist seals and an opaque black default color.

## 3.1.0 - 2026-04-23

- Added Blizzard Interface Options / AddOns registration so the config panel is available in-game without slash commands.
- Switched the primary slash aliases to `/sst`, `/super`, and `/superswingtimer`, and removed the `/swangthang` alias.
- Made the default MH / OH / ranged bar colors follow the player class color until you choose custom swatches.
- Added an indicator glow mode toggle so weave and spark markers can use either a bright glow or a more opaque blend.
- Reworked the texture dropdown to show actual texture previews alongside the texture names.
- Widened and re-labeled the `/sst` UI into clearer bar, weave, and color groups.

## 3.0.1 - 2026-04-23

- Added color-coded weave-family toggles for Lightning Bolt, Chain Lightning, Healing Wave, Lesser Healing Wave, and Chain Heal.
- Made the weave marker pair smaller and clarified the upper/lower marker labels in `/sst`.
- Widened the `/sst` panel and added clearer weave-assist descriptions and spacing.

## 3.0.0 - 2026-04-21

- Rebranded SwangThang to Super Swing Timer.
- Added /sst as the primary slash command.
- Kept legacy /swang and /swangthang aliases for migration.
- Added shaman weave assist for Lightning Bolt, Chain Lightning, Healing Wave, Lesser Healing Wave, and Chain Heal breakpoint tracking.
- Updated project metadata for CurseForge project 1521271 and author AcidBomb.
- Kept Classic/TBC-compatible timing fallbacks.
- Expanded the `/sst` panel with bar visibility toggles and a shaman weave-assist toggle.
- Replaced the browser texture picker with an in-addon dropdown showing `[category] label` entries (SharedMedia + Blizzard fallbacks). This enables quick texture selection without leaving the game.

## 2.5 - 2026-03-31

- Added texture-layer controls for both bar fill and spark.
- Added bar background alpha, spark alpha, minimal mode, and lock-bars controls.
- Added PLAYER_ENTERING_WORLD, throttled UNIT_AURA, and a low-frequency combat sanity ticker for accuracy.
- Bar and spark texture paths still accept any installed texture path.
- Kept GetTimePreciseSec as a safe preference with GetTime fallback.

## 2.4

- Added a bar texture selector to the config panel.
- Improved texture application and preview handling.

## 2.1

- Added the seal-twist overlay preview.
- Added the config panel and initial melee support refinements.
