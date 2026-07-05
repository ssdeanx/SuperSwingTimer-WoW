# SuperSwingTimer — Remaining Work Plan

**Date:** 2026-07-05
**Codebase:** 8 Lua files, 20,706 total lines
**Current schema:** DB v54

---

## Current State Summary

| Phase | Total | Done | Pending |
|-------|-------|------|---------|
| 1 — Critical Fixes | 4 | 4 | 0 |
| 2 — UX Overhaul | 5 | 5 | 0 |
| 3 — Testing Infrastructure | 4 | 3 | 1 |
| 4 — Polish & Documentation | 4 | 1 | 3 |
| 5 — File Splitting | 5 | 1 | 4 |

**Correction found vs AUDIT.md:** Color swatch labels are **already done** — `CreateColorButton()` creates text labels next to every swatch. AUDIT.md Phase 2 item "Color swatch labels in Quick Controls" should be marked complete.

---

## Task Inventory (ordered by priority within groups)

### Group A — Data Integrity (Critical)

#### A1. Replace fresh-install block with DeepCopyDefaults

**Why:** The 155-line inline block (SuperSwingTimer.lua:70–224) manually copies every field from `ns.DB_DEFAULTS`. Adding a default in Constants.lua without updating this block silently produces nil for fresh installs — a data corruption risk that has already happened with `showWarriorShieldBlockBar`, `warriorBuffIconSize`, and `shamanBuffIconSize` (which required individual nil-guards in the fill section below).

**What:**
1. Add a `DeepCopyDefaults(t)` helper function before the fresh-install block
2. Replace lines 70–224 with `SuperSwingTimerDB = DeepCopyDefaults(ns.DB_DEFAULTS)`
3. Ensure proper deep-copy of nested tables (`colors`, `positions`, `weaveSpellFamilies`)
4. Remove the post-fresh "fill missing fields" nil-guards that exist only because the inline copy was incomplete

**Files affected:**
- `SuperSwingTimer.lua` — replace fresh block + delete redundant nil-guards

**Risk:** LOW. Deep copy is a standard Lua pattern. The function runs only on fresh install (no DB), so existing users are unaffected. Verify by comparing output with current inline block field-by-field.

**Validation:** Confirm `DeepCopyDefaults(ns.DB_DEFAULTS)` produces a table with identical keys and values as the current inline block. Run `luac -p` on modified file.

---

#### A2. Collapse legacy migrations (v1–v40)

**Why:** 51 migration entries (753 lines) for DB schema versions most users passed years ago. Keeping them forever bloats the file and adds merge-conflict surface area. Collapsing v1–v40 into a single `"legacy"` step is safe if no user is below v40.

**What:**
1. Confirm no user is below v40 (check CurseForge/CFTools install history or hard-cut)
2. Replace migration entries for versions 3–40 with a single `["legacy"] = function(db) ... end` entry
3. Add a version-check guard: if version is below 3, the fresh-install block already sets v54
4. Keep versions 41–54 as-is (recent, users might be on any of these)

**Files affected:**
- `SuperSwingTimer.lua` — migration table

**Risk:** MEDIUM-HIGH. If a user below v40 exists and the collapsed legacy code doesn't handle all transition paths correctly, their settings corrupt. Mitigation: audit the collapsed migrations to ensure every key set by v3–v40 is covered.

**Validation:** Write a test function that runs the collapsed legacy step against a v3 DB snapshot and verifies the output matches running all 37 individual steps sequentially.

---

### Group B — Config Panel UX (Medium Priority)

#### B1. Config panel comprehensive help text

**Why:** The current subtitle ("Opening /sst previews the bars...") is a single sentence. New users face ~40 controls without explanation of what each section does or how bars behave.

**What:**
1. Replace the single-line subtitle with a 3–4 line help blurb:
   - What the addon does (swing timer with class overlays)
   - How to use the panel (left column = visibility toggles, right column = color swatches)
   - Where to find class-specific controls (expand class section at bottom)
   - Where to read more (link to /sst help slash command)
2. Add section-level descriptions beneath each collapsible header

**Files affected:**
- `SuperSwingTimer_Config.lua` — subtitle creation, section header descriptions

**Risk:** LOW. Text-only changes.

**Validation:** Visual inspection in-game that text renders correctly and doesn't overflow panel width.

---

#### B2. Rename section headers

**Why:** "General Behavior" and "Weave Families" don't convey what's inside. Users don't know "General Behavior" contains tooltip controls and swing flash toggles, or that "Weave Families" means Shaman only.

**What:**
- `"General Behavior"` → `"Combat & Timer Behavior"`
- `"Weave Families"` → `"Shaman Weave Spells"`
- Optionally review other section headers for clarity

**Files affected:**
- `SuperSwingTimer_Config.lua` — section header strings at lines 3519, 3801

**Risk:** LOW. String-only change.

**Validation:** Visual inspection.

---

#### B3. Apply tooltips to all controls

**Why:** `AddControlTooltip()` infrastructure exists but is only used on ~11 controls. Quick Toggle controls (Show MH, Show OH, Show Ranged, Show Enemy, Use Class Colors, etc.) and many sliders lack tooltips.

**What:**
1. Audit every control in the panel and categorize: has tooltip, needs tooltip, intentionally simple
2. For Quick Toggle rows, use the existing `tooltipText` option passed to `AddQuickToggle()`
3. For sliders, add tooltips explaining what the value does (e.g., "Width of the main hand swing bar in pixels before global scale is applied")
4. For color swatches, add tooltips matching the label text
5. Consider using the Blizzard GameTooltip rather than a custom frame to match WoW conventions

**Files affected:**
- `SuperSwingTimer_Config.lua` — tooltip additions across most control creation sites

**Risk:** LOW. No behavioral changes — tooltip text only.

**Validation:** Hover each control in-game and verify tooltip appears and describes the control accurately.

---

### Group C — Code Quality (Medium Priority)

#### C1. Font path constant

**Why:** `"Fonts\\FRIZQT__.TTF"` is hardcoded 38 times in ClassMods.lua. If Blizzard ever changes the font path, 38 sites need updating. A single constant fixes this.

**What:**
1. Add `ns.FONT_PATH = "Fonts\\FRIZQT__.TTF"` to `Constants.lua`
2. Replace all 38 occurrences in `ClassMods.lua` with `ns.FONT_PATH`
3. No other files hardcode FRIZQT (confirmed)

**Files affected:**
- `SuperSwingTimer_Constants.lua` — one-line addition
- `SuperSwingTimer_ClassMods.lua` — 38 replacements

**Risk:** LOW. Mechanical text replacement, no behavioral change.

**Validation:** `luac -p` passes. Quick check that font strings render correctly in-game.

---

#### C2. Enterprise-grade LDoc on public functions (incremental)

**Why:** AGENTS.md mandates LDoc docstrings on all public functions (`ns.*`). Currently only 4 functions have them. Rather than a single massive doc pass, adopt policy: **every new or modified public function gets full LDoc**.

**What:**
1. Priority A: Core API functions that other files call — `ns.StartSwing()`, `ns.OnUpdate()`, `ns.RefreshLatencyCache()`, `ns.GetAlignedTime()`, `ns.Scale()`, `ns.RegisterOnUpdateHook()`
2. Priority B: Config apply functions — `ns.ApplyGlobalScale()`, `ns.ApplyBarSize()`, `ns.ResetConfigDefaults()`
3. Priority C: ClassMods setup functions — `SetupPaladin()`, `SetupWarrior()`, `SetupHunter()`, `SetupRogue()`, `SetupShaman()`, `SetupDruid()`
4. Priority D: All remaining `ns.*` exported functions

**Files affected:** All 8 Lua files, incrementally.

**Risk:** LOW. Comments only, no behavioral change.

**Validation:** No validation needed beyond author review (no tooling to verify docstring accuracy).

---

### Group D — Architecture (Longer-term)

#### D1. Split ClassMods.lua (8,309 lines)

**Why:** The largest file in the project (3.3× the AUDIT estimate). Single-file maintenance is error-prone — OnUpdate hooks, bar creation, and per-class logic are interleaved.

**What:**
1. Extract shared utilities into `SuperSwingTimer_ClassMods_Shared.lua` (~200 lines: `EnsureVerticalHelperBar()`, `CreateClassBuffIcon()`, `QuerySpellCooldown()`, `GetFlurryBuffInfo()`)
2. Split each class into its own file:
   - `SuperSwingTimer_ClassMods_Paladin.lua` (~1,500 lines)
   - `SuperSwingTimer_ClassMods_Warrior.lua` (~1,200 lines)
   - `SuperSwingTimer_ClassMods_Rogue.lua` (~1,200 lines)
   - `SuperSwingTimer_ClassMods_Hunter.lua` (~800 lines)
   - `SuperSwingTimer_ClassMods_Shaman.lua` (~800 lines)
   - `SuperSwingTimer_ClassMods_Druid.lua` (~800 lines)
3. Update `.toc` load order
4. Verify all cross-file `ns.*` references resolve correctly
5. Remove old `SuperSwingTimer_ClassMods.lua`

**Files affected:**
- New files: 7
- `SuperSwingTimer.toc` — load order
- Old `SuperSwingTimer_ClassMods.lua` — deleted

**Risk:** HIGH. Largest refactor in the plan. Risk of missing cross-references, OnUpdate hook registration ordering, or `ns.*` namespace collisions. Requires extensive manual QA.

**Validation:**
1. `luac -p` on all files
2. Load in-game: no Lua errors on addon load
3. Class overlays appear for current class
4. All 6 classes render overlays correctly when logged in

---

#### D2. Split Config.lua (4,674 lines)

**Why:** Second-largest file. Merges panel layout, control builders, apply functions, and reset logic.

**What:**
1. Extract widget builders → `SuperSwingTimer_Config_Widgets.lua` (`CreateLabeledSliderRow()`, `CreateColorButton()`, `AddQuickToggle()`, etc.)
2. Extract apply/reset functions → `SuperSwingTimer_Config_Apply.lua` (`Apply*()` functions, `ResetConfigDefaults()`)
3. Keep panel layout in existing file → trimmed `SuperSwingTimer_Config.lua`
4. Update `.toc` load order

**Files affected:**
- New files: 2
- `SuperSwingTimer.toc` — load order
- `SuperSwingTimer_Config.lua` — trimmed

**Risk:** MEDIUM. Control builders and apply functions are well-encapsulated. Risk is missing a global variable reference.

**Validation:** Open `/sst` in-game, verify all controls render, all sliders/buttons respond, reset works.

---

#### D3. Split UI.lua (2,725 lines)

**Why:** Third-largest file. Bar creation, OnUpdate render, and positioning are tightly coupled.

**What:**
1. Extract bar factory → `SuperSwingTimer_UI_Bars.lua` (`CreateBar()`, `CreateGcdTickerBar()`, `CreateHelperVerticalBar()`, `RefreshBarLabelStyles()`)
2. Extract render loop → `SuperSwingTimer_UI_Render.lua` (hook functions, `UpdateSwingBars()`, `UpdateRangedBarFormat()`, `UpdateCastZoneVisual()`)
3. Keep positioning and drag logic in existing file
4. Update `.toc` load order

**Files affected:**
- New files: 2
- `SuperSwingTimer.toc` — load order
- `SuperSwingTimer_UI.lua` — trimmed

**Risk:** HIGH. Bar creation and rendering are tightly coupled to names like `ns.mhBar`, `ns.ohBar`, etc.

**Validation:** Enter combat in-game, verify all bars render correctly with proper positioning.

---

### Group E — Testing Infrastructure (Ongoing)

#### E1. luac -p syntax check CI

**Why:** No CI at all. `luac -p` is available on Linux and catches syntax errors immediately.

**What:**
1. Create a `.github/workflows/luac.yml` that runs `luac -p` on all 8 files
2. Run on every push and PR
3. Add a status badge to README.md

**Files affected:**
- `.github/workflows/luac.yml` — new
- `README.md` — optional badge

**Risk:** LOW. CI-only change.

---

#### E2. Migration test suite

**Why:** 51 migration versions, zero tests. A single bad migration corrupts user data.

**What:**
1. Write a `test_migrations.lua` script (runnable via `lua` CLI with a mock WoW environment)
2. For each migration version 3→54, create a mock DB with that version's fields
3. Run `MigrateDB()` on each mock and verify output matches expected schema
4. Test edge cases: nil values, partial data, corrupt data

**Files affected:**
- `test_migrations.lua` — new (standalone test file)

**Risk:** LOW. Standalone test file, no addon code changes.

---

#### E3. Manual smoke-test checklist

**Why:** Current QA relies on developer memory. A scripted checklist prevents skipped steps.

**What:**
1. Write a `.kilo/qa-checklist.md` or `docs/QA.md` with step-by-step instructions
2. Cover: combat entry, swing events, class overlays, config panel, reset, dual-client
3. Add a shell script that prints the checklist interactively

**Files affected:**
- `docs/QA.md` — new

**Risk:** LOW. Documentation only.

---

## Execution Order

```
Phase A (Data Safety)        Phase B (Config UX)          Phase C (Code Quality)       Phase D (Architecture)
┌─────────────────────┐      ┌─────────────────────┐     ┌─────────────────────┐      ┌─────────────────────┐
│ A1 DeepCopyDefaults │  →   │ B1 Help text        │     │ C1 Font constant    │      │ D1 Split ClassMods  │
│ A2 Legacy collapse  │      │ B2 Rename headers   │  →  │ C2 LDoc (increm.)   │  →   │ D2 Split Config     │
└─────────────────────┘      │ B3 Tooltips          │     └─────────────────────┘      │ D3 Split UI         │
                             └─────────────────────┘                                   └─────────────────────┘
                                                                                       
Phase E (Testing — independent, parallel)
┌─────────────────────┐
│ E1 CI pipeline      │  →  (runs automatically after other changes)
│ E2 Migration tests  │  →  (pre-requisite for A2)
│ E3 QA checklist     │  →  (anytime)
└─────────────────────┘
```

**Recommended first step:** A1 (DeepCopyDefaults) — highest impact, lowest risk, removes a real drift bug.

**Parallel work possible:** B1/B2/B3 and C1 can be done in a single pass since they all touch Config.lua.

---

## Risk Register

| # | Risk | Likelihood | Impact | Mitigation |
|---|------|-----------|--------|------------|
| R1 | DeepCopyDefaults copies a field that shouldn't be in user DB | Low | Medium — extra key in SavedVariables | Audit `ns.DB_DEFAULTS` for helper functions or metadata before implementing |
| R2 | Legacy migration collapse skips a side effect from v3–v40 | Low | **High** — user settings corrupted | Write test that runs both paths and diffs output; keep old code in a comment for recovery |
| R3 | File split introduces runtime nil-reference to a cross-file `ns.*` symbol | Medium | Medium — Lua error on load | Add nil-guards at export boundaries; load test each class |
| R4 | LDoc comments drift from implementation | High | Low — cosmetic only | Enforce in code review; no automated check available |

## Rollback Strategy

Every task in this plan is a simple file revert. No database schema changes are involved (except A2 which is migration code, not schema). Before implementing A2, dump the current migration table to a backup file for instant revert.

---

## Appendix: Updated AUDIT.md Scorecard

| Section | Old Score | Adjusted Score | Reason |
|---------|-----------|----------------|--------|
| 1. Architecture | 9/10 | 9/10 | No change |
| 2. Code Quality | 7.5/10 | **8/10** | GetCurrentTime dedup completed |
| 3. Config Panel | 6/10 | **6.5/10** | Global Scale + basic subtitle added, swatch labels were already done |
| 4. Migration | 8/10 | 8/10 | No change |
| 5. ClassMods | 7/10 | **6/10** | File is actually 8,309 lines (not 2,500 as estimated) |
| 6. State Engine | 9/10 | 9/10 | No change |
| 7. Weave Engine | 8.5/10 | 8.5/10 | No change |
| 8. UI Rendering | 8/10 | 8/10 | No change |
| 9. Testing | 3/10 | 3/10 | No change |
| 10. Documentation | 7/10 | 7/10 | No change |
| **Overall** | **7.2/10** | **7.3/10** | Marginal improvement from critical fixes |
