<!-- markdownlint-disable -->

# SuperSwingTimer 8/10 → 10/10 Roadmap

> For Top Parse Pro Players — Zero Error Tolerance
> v0.0.8 bugfix release shipped. v0.0.9 = Phase 0 (critical bugs) + Phase 1 (quick wins)

## Current execution checklist

- [ ] Phase 0 — critical bug blockers (v0.0.9 target — see detail below)
- [x] Phase 1 — quick wins — **✅ ALL 4 ALREADY IMPLEMENTED** (swing landing flash, GCD ticker, rage dimming, energy tick countdown)
- [x] Phase 2 — class-specific pro gaps — **✅ ALL 27 ITEMS ALREADY IMPLEMENTED** (see Phase 12-14 for real remaining gaps)
- [x] Phase 5 — code-quality / final-polish cleanup (ongoing)
- [x] Phase 6 — tank utility & class polish
	- [x] Shield Block duration bar
	- [x] Ravage opener cue
	- [x] Prot warrior enemy-bar helpers — already covered by the existing enemy swing bar, which is usable for tanking/kiting target timing
- [x] Phase 7 — final release prep / in-game validation
- [x] Phase 8 — v0.0.8 bugfix release (2026-05-20 — CurseForge release pending)

## Phase 8: v0.0.8 Bugfix Release (2026-05-20 — COMPLETED)

| # | Fix | File | Root Cause |
|---|-----|------|------------|
| 1 | **Line 71 crash** — bare `local updateInterval = 0.016` before `ns` existed killed every non-hunter class | ClassMods.lua:71 | Stray local before namespace |
| 2 | **Paladin seal zone layering** — seal textures routed through shaman weave marker system instead of direct overlay | ClassMods.lua / UI.lua | Wrong layer API; swapped to `SetDrawLayer("OVERLAY", 0)` |
| 3 | **Missing `end` in UpdateShamanisticRageBadge** — cascade LSP errors from line 1507 to EOF | ClassMods.lua:1544 | Missing closing delimiter |
| 4 | **Shaman OnUpdate chain** — `prevOnUpdate` was undefined global; captured `ns.OnUpdate` directly, added bootstrap | ClassMods.lua:1537-1547 | Missing capture + bootstrap |
| 5 | **Indentation errors** — `end` depths wrong at lines 239-241; OnUpdate body unindented in `SetupEnhShaman()` | ClassMods.lua:239-241, 1200s | Formatting drift |
| 6 | **Latency refresh too slow** — `LATENCY_REFRESH_INTERVAL` 5.0s → 0.05s; wired into `HandleSpellcastDelayed` | State.lua | Tuning |
| 7 | **`strtrim` undefined** — `GetHunterRangedBarLabel()` and `ApplyHunterRangedBarLabel()` used `strtrim()` without importing | UI.lua:632,636 | Missing `rawget` import |

## Archived / future wishlist

- [ ] Hunter / other-class polish — deferred as a broad future wishlist item rather than a concrete shipped helper; the current addon already covers the shipped tank and class-polish slice

---

## Phase 9: LSP Health & Diagnostics Cleanup (v0.0.9 fringe)

| # | Item | Severity | Notes |
|---|------|----------|-------|
| 1 | **Full LSP zero-warning pass** across all 7 source files | LOW | Target: 0 linter warnings, 0 unused locals, 0 shadowed variables |
| 2 | **Global variable audit** — identify and localize remaining bare globals via `rawget` | LOW | Prevent accidental global creation in WoW's shared environment |
| 3 | **Lua diagnostic configuration** — markdown `.luarc.json` or per-file `---@diagnostic` annotations | LOW | Standardize lint baseline |

## Phase 10: Testing & Automation (v0.1.0+)

| # | Item | Effort | Why |
|---|------|--------|-----|
| 1 | **Automated test harness** — standalone Lua test runner for addon logic | 2 days | Catch regressions before in-game testing |
| 2 | **CurseForge release script** — automated metadata bump + ZIP packaging | 1 day | Reliable release workflow |
| 3 | **CI/CD pipeline** — GitHub Actions: lint + test + package on PR/tag | 1 day | Developer confidence |

## Phase 11: Integration & Ecosystem (v0.2.0+)

| # | Item | Effort | Why |
|---|------|--------|-----|
| 1 | **WeakAuras bridge v2** — richer state export (all bar states, latency, queue state) | 2 days | WeakAuras custom triggers for pro players |
| 2 | **Wago upload support** — generate Wago-compatible export string from config | 1 day | Share profiles via Wago |
| 3 | **Data-driven weakauras** — export GCD, swing, and special-budget as WeakAuras triggers | 2 days | Full WA integration suite |

---

## Phase 0: Critical Bugs (Fix IMMEDIATELY — v0.0.9 blockers)

| # | Issue | File | Severity |
|---|-------|------|----------|
| 1 | **DB_DEFAULTS.version = 35, migration chain ends at v38** — Fresh installs re-run v36→v37→v38 every login. v36 migration overwrites saved rage bar toggle with default. | Constants.lua:522 / SST.lua:84 | 🔴 CRITICAL |
| 2 | **`showPaladinSealColor/Label/JudgementMarker/TwistFlash` not in non-fresh-install fill path** — Existing users upgrading from before these fields existed get `nil`. `~= false` check saves them (nil→true), but crisp fix needed. | SST.lua:168-220 | 🟠 HIGH |
| 3 | **`GetSpecialization()` returns nil if no spec chosen** — Protection spec-hide silently fails, rage bar shows when it shouldn't. | ClassMods.lua | 🟠 HIGH |
| 4 | **OH bar base color never stored** — Druid form color toggle leaves OH bar tinted. MH stores `mhBarBaseColor`, ranged stores `rangedBarBaseColor`, enemy stores `enemyBarBaseColor`. OH missing. | UI.lua:2010-2014 | 🟠 HIGH |

---

## Phase 1: Quick Wins (Highest Impact — v0.0.9)

| # | Feature | Why Pro Players Need It | Effort |
|---|---------|------------------------|--------|
| 1 | **Swing landing flash** — 50ms bright white pulse on spark when MH/OH/ranged swing lands. Satisfying + confirms the hit. | Game feel, hit confirmation | 0.5 day |
| 2 | **GCD ticker** — 1.5s GCD visible as a thin strip/overlay on bars. Essential for twist/weave/HS timing. | Core mechanic for all melee | 1 day |
| 3 | **Druid insufficient rage dimming** — Dim MH bar when below 15 rage (Maul cost) for bear form. | Bear Maul optimization | 0.5 day |
| 4 | **Rogue energy tick countdown** — Show exact ms until next energy tick on the existing tick bar or as a text label. | Perfect energy pooling | 1 day |

---

## Phase 2: Class-Specific Pro Gaps (v0.1.0)

### Hunter — 5 gaps
| # | Gap | Why | Effort |
|---|-----|-----|--------|
| 1 | **Feign Death auto-shot reset** | No FD handler → bar can stay stuck | 1 day |
| 2 | **Multi-Shot weave helper** | Auto→Multi→Steady rotation sync with ranged bar | 2 days |
| 3 | **Rapid Fire CD + duration bar** | 40s CD / 15s duration — major DPS CD | 1 day |
| 4 | **Readiness reset** | Resets RF/MS CDs, bar should flash | 1 day |
| 5 | **Auto-shot range zone** | Green/red glow indicator on ranged bar edge | 1 day |

### Warrior — 5 gaps
| # | Gap | Why | Effort |
|---|-----|-----|--------|
| 1 | **Flurry remaining swings** | 3 swings after crit — swing counter badge | 1 day |
| 2 | **Execute phase trigger** | Below 20% health: rage bar glows | 1 day |
| 3 | **Slam cast bar** | 1.5s cast bar like hunter | 2 days |
| 4 | **BT / WW CD markers** | Sync with swing timers | 1 day |
| 5 | **Overpower proc flash** | Yellow flash when dodge occurs | 1 day |

### Rogue — 4 gaps
| # | Gap | Why | Effort |
|---|-----|-----|--------|
| 1 | **Adrenaline Rush CD + active** | 3min CD / 15s duration bar | 1 day |
| 2 | **Blade Flurry remaining** | 15s duration bar above SnD | 1 day |
| 3 | **Energy cap warning** | Bar color shift near 100 energy | 0.5 day |
| 4 | **Cold Blood indicator** | Diamond icon when CB is up | 0.5 day |

### Paladin — 3 gaps
| # | Gap | Why | Effort |
|---|-----|-----|--------|
| 1 | **Reckoning tracking** | Stack count badge on MH bar | 1 day |
| 2 | **Libram swap timer** | ICD tracker for libram swapping | 2 days |
| 3 | **Judgement CD countdown** | MS-remaining on judgement marker | 1 day |

### Druid (Feral) — 5 gaps
| # | Gap | Why | Effort |
|---|-----|-----|--------|
| 1 | **Omen of Clarity proc** | Free ability glow on bar | 1 day |
| 2 | **Power-shift tracker** | Energy gain window visualization | 2 days |
| 3 | **Tiger's Fury CD + duration** | 30s CD / 6s duration bar | 1 day |
| 4 | **Energy tick (cat form)** | Same tick bar as rogue | 0.5 day |
| 5 | **Faerie Fire ready** | Off-GCD OoC proc opportunity | 1 day |

### Shaman — 5 gaps
| # | Gap | Why | Effort |
|---|-----|-----|--------|
| 1 | **Windfury internal CD** | ~3s ICD counter bar | 1 day |
| 2 | **Stormstrike CD marker** | 10s CD marker on MH | 1 day |
| 3 | **Flurry remaining swings** | Swing counter badge | 1 day |
| 4 | **Weave cast bar** | Real cast progress for weave spells | 2 days |
| 5 | **Shamanistic Rage CD** | 1min CD tracker | 1 day |

---

## Phase 3: Cross-Class Systems (v0.1.1)

| # | Feature | Why | Effort |
|---|---------|-----|--------|
| 1 | **Global Cooldown ticker (full)** | GCD visible on ALL main bars | 1 day |
| 2 | **Haste tracking per class** | Verify every class rescales on haste change | 1 day |
| 3 | **Parry haste for all melee** | 40% reduction, 20% floor — verify all classes | 1 day |
| 4 | **Extra attack visual** | Sword Spec / Windfury / Reckoning → "+1" flash | 1 day |
| 5 | **OnUpdate performance audit** | Early-return paths, frame-skip throttle | 2 days |
| 6 | **Event handler leak check** | Verify unregister on disable/reload | 1 day |

---

## Phase 4: UI/UX Polish for Pro Feel (v0.2.0)

| # | Improvement | Effort |
|---|-------------|--------|
| 1 | **Bar tooltip on hover** — "MH: 1.2s | Speed: 2.6 | Haste: 8% | Next: 2.4s" | 1 day |
| 2 | **Multi-profile support** — PvP / PvE / Raid profiles via `/sst profile <name>` | 3 days |
| 3 | **Import/Export string** — Share config as a single chat command | 2 days |
| 4 | **Embedded font** — Cleaner sans-serif for bar text | 1 day |
| 5 | **Minimal mode v2** — 2px bars, no labels, spark only | 1 day |
| 6 | **Sound cue** — Optional tick on swing landing | 2 days |
| 7 | **Config search** — `/sst search "rage"` jumps to section | 1 day |

---

## Phase 5: Code Quality (Ongoing)

| # | Issue | Severity | Fix |
|---|-------|----------|-----|
| 1 | **`ns.GetCurrentTime` unused export** — Constants.lua sets it, nobody calls it. Dead code or future trap. | LOW | Remove or mark as available utility |
| 2 | **`PALADIN_TWIST_WINDOW = 0.4` local in ClassMods vs `ns.CAST_WINDOW = 0.5`** — Docs say 0.4, code says 0.5 for hunter. Intentional but inconsistent naming. | LOW | Move PALADIN_TWIST_WINDOW to Constants |
| 3 | **Druid `SetupDruid` wraps `ns.HandleSpellcastSucceeded`** — Fragile replacement pattern. No other class wraps it today, but collision-prone. | MED | Convert to callback chain |
| 4 | **Hardcoded 2.0s fallback for enemy/MH/OH/ranged speed** — Visible bar snap on race conditions | MED | Use class-specific defaults |
| 5 | **Config: Rogue Combo Points toggle UI** — DB, migration, and Quick Controls row are already wired; keep as a regression check if future refactors touch the Rogue panel | ✅ RESOLVED | None |

---

## 📌 NOTE: Phase 2 Class Gaps Status

**All 27 items across 6 classes in Phase 2 are already implemented** — the roadmap was never updated after the features shipped. See new Phase 12-14 for the **real** remaining gaps.

---

## Phase 12: Feral Druid Expansion (v0.0.9/v0.1.0)

The roadmap's old 5-item druid list (Omen of Clarity, Powershift tracker, Tiger's Fury CD, Energy tick, Faerie Fire ready) are all already implemented (43 druid features total). The **real** remaining druid gaps for top-parsing ferals:

| # | Gap | Why | Effort |
|---|-----|-----|--------|
| 1 | **Savage Roar duration bar** — Thin bar/main-hand overlay showing SR remaining time. Core feral rotational buff. | Current: none. WA-only feature. | 1 day |
| 2 | **Rip debuff tracker** — Show remaining Rip duration on target as MH bar text or separate bar. Essential for bleed snapshot planning. | Current: none. WA-only feature. | 1 day |
| 3 | **Mangle (cat) debuff tracker** — Show Mangle uptime on target. 30% Shred damage boost, must stay up. | Current: none. WA-only feature. | 1 day |
| 4 | **Berserk CD + duration bar** — 3min CD / 15s duration. Major feral DPS cooldown. | Current: none. | 1 day |
| 5 | **Powershift mana gauge** — Show "X shifts remaining before OOM" as badge/bar. Critical for sustain. | Current: no mana tracking. WA-only feature. | 1 day |
| 6 | **Feral leeway indicator** — Visual marker of the 0.5s gap window in the powershift cycle where OoC/Faerie Fire fits without cycle delay. | Current: none. Advanced feral optimization. | 2 days |
| 7 | **Cat form combo points** — Rogue has 5-box CP strip above MH; feral has none. Needs: form-aware CP bar for cat. | Current: Rogue-only. Copy existing system. | 1 day |
| 8 | **Full energy pool visualization** — Beyond the tick bar: show current energy + next tick arrival on MH bar. | Current: tick bar only, no pool % on MH. | 1 day |

## Phase 13: Competitive Parity (v0.1.0)

Gaps identified from **WeaponSwingTimer-Queuing** (skad___ fork, 112k downloads, updated Apr 2026 for TBC 2.5.5):

| # | Gap | Competitor Has | Effort |
|---|-----|----------------|--------|
| 1 | **Slam delay indicator + GCD spark** — A bar overlay at the end of the swing timer showing the safe Slam window, plus a line spark one GCD (1.5s) ahead of the swing timer marking the latest time to cast MS/WW without delaying Slam. | WST-Queuing | 2 days |
| 2 | **Partial OH progress simulation** — OH timer capped at 45% when no attack is queued (matching real OH behavior where the swing only advances while attacking). Resets to 45% on target change. | WST-Queuing | 1 day |

## Phase 14: Parsing WeakAuras Bridge (v0.1.1)

Features that top parsing players currently rely on WeakAuras for, which SST could natively integrate:

| # | Feature | WA Ecosystem | Effort |
|---|---------|-------------|--------|
| 1 | **Feral bleed snapshot power indicator** — Show relative damage % of current Rip vs next Rip (like FeralSnapshots addon). WA: MoonBunnie's Feral Bleed Power, FeralSnapshots. | 7+ WAs, 1 dedicated addon | 3 days |
| 2 | **Energy pooling alert** — MH bar tint shift when energy crosses ability thresholds (42=Shred, 48=Shred with OoC, 30=Rip). WA: Jdotb's Energy Bar. | 5+ energy WAs | 1 day |
| 3 | **Powershift rotation timer** — Visual indicator showing the exact 4-second cycle cadence for shift→cast→cast→shift. WA: Weave's Feral Bar, Zia's Feral Bar. | 4 dedicated feral bar WAs | 2 days |
| 4 | **Omen of Clarity PPM prediction** — Instead of just showing active proc, predict next likely proc window based on PPM (3.5 PPM for Omen). WA: none (addon gap). | No WA does this | 2 days |
| 5 | **Warrior Sword Spec / extra attack counter** — Show current extra attack proc rate per swing. WA: various swing timer fixes. | WA #1759, #3141 | 2 days |

---

## Execution Strategy

```
v0.0.8  🔄 Phase 8 (bugfix release) — Code done, CurseForge release pending
v0.0.9  🔴 Phase 0 (critical bugs) = NEXT  | Phase 1 ✅ all 4 quick wins already implemented
v0.1.0  — Phase 12 (Feral druid expansion) + Phase 13 (Competitive parity)
v0.1.1  — Phase 14 (Parsing WA bridge) + Phase 3 (cross-class systems) + Phase 9 LSP health
v0.2.0  — Phase 4 (UI polish) + Phase 10 (testing/automation)
v0.3.0  — Phase 11 (integration & ecosystem)
```

## Effort Summary

| Phase | Items | Estimated Days |
|-------|-------|----------------|
| Phase 0 (Critical bugs) | 4 | 1 |
| Phase 1 (Quick wins) | 4 | ✅ ALL IMPLEMENTED |
| Phase 2 (Class gaps) | 27 | ✅ ALL 27 IMPLEMENTED |
| Phase 3 (Cross-class) | 6 | 7 |
| Phase 4 (UI polish) | 7 | 11 |
| Phase 5 (Code quality) | 5 | 3 (ongoing) |
| Phase 8 (v0.0.8 bugfix) | 7 | 🔄 CurseForge release |
| Phase 9 (LSP/diagnostics) | 3 | 1 |
| Phase 10 (Testing/automation) | 3 | 4 |
| Phase 11 (Integration) | 3 | 5 |
| Phase 12 (Druid expansion) | 8 | 9 |
| Phase 13 (Competitive parity) | 2 | 3 |
| Phase 14 (Parsing WA bridge) | 5 | 10 |
| **TOTAL** | **84** | **~56 days** |
