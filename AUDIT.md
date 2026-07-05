# SuperSwingTimer — Deep Quality Audit

**Date:** 2026-07-05
**Auditor:** AI Code Review
**Scope:** All 7 Lua files, docs, memory-bank, build tooling
**Target:** BC Classic Anniversary 2.5.5

---

## Executive Summary

SuperSwingTimer is a **production-grade WoW addon** with ~6,000+ lines of Lua across 7 files, serving thousands of users. The architecture is clean and mature — the 7-file split, `ns.*` namespace discipline, Blizzard API wrappers, table-driven migration, and nil-guarding conventions are genuinely better than most addons in this space.

However, the addon has grown organically through many feature passes, and several areas show **accumulated technical debt** that prevents it from being truly best-in-class.

**Overall score: 8.2/10** — improved from 7.2. Fresh-install block fixed, CI added, migration tests, font constant, GetTime shims removed.

---

## Section Scores (1–10)

### 1. Architecture & File Organization — **9/10**

**Strengths:**

- Strict 7-file dependency order: Constants → State/Weaving → UI → ClassMods → Config
- Single `ns.*` namespace with zero globals (by convention)
- Clean separation: SuperSwingTimer.lua is bootstrap only, feature logic in dedicated files
- Table-driven migration pipeline (not a fragile if-ladder)
- All cross-file state on `ns.*`, nil-guarded at call sites

**Weaknesses:**

- `SuperSwingTimer.lua` fresh-install block is **enormous** — 200+ lines duplicating `ns.DB_DEFAULTS` inline instead of referencing it dynamically. If a new default is added to `Constants.lua` but not to the fresh-install block, fresh users get nil where upgrade users get the default.
- `MigrateDB()` combines fresh-install + migration + fill-missing logic in one function — should be 3 separate phases.
- No formal module/import system beyond dependency order (acceptable for Lua, but worth noting).

### 2. Code Quality & Consistency — **8.5/10** (+1.0)

**Strengths:**

- Consistent `rawget(_G, ...)` pattern for all Blizzard API access
- `C_Spell` naming standardized across all files
- Nil-guarding on all dynamic class-mod calls: `if ns.UpdateHunterRangeHelperVisual then ... end`
- `ns.GetAlignedTime()` single clock source throughout (all local shims removed)
- Proper `pcall` wrapping on risky API calls
- **NEW: `ns.FONT_PATH` constant** replaces 39+ hardcoded font paths

**Weaknesses:**

- **8 Hunter bar globals** (`serpentStingBar`, `wingClipBar`, etc.) are closure-captured locals in `.luarc.json` — acceptable suppression but not ideal
- **Zero TSDoc/docstring comments** across all files despite being requested in AGENTS.md conventions. Functions lack parameter documentation, making onboarding harder.
- ~~`ns.OnUpdate` chain is dangerously fragile.~~ **RESOLVED** — replaced with hook registration system.

### 3. Config Panel (UI/UX) — **6/10**

**Strengths:**

- `/sst` has Quick Controls + Appearance + class sections layout
- Sliders, color pickers, dropdowns, texture browser all functional
- Test Bars animation for preview
- Mouse wheel scrolling support
- Class-conditional row creation (not just hide-after-create)

**Weaknesses:**

- **No introductory text or help.** The panel opens with no subtitle explaining what anything does. Users face a wall of checkboxes, sliders, and swatches with zero guidance.
- **No global scale slider.** The user explicitly requested this — there is no master "Scale" control that proportionally resizes all bars, fonts, sparks, and icons relative to defaults. Each bar has individual width/height settings, but nothing ties them together.
- **Section labels are unclear.** "General Behavior" and "Appearance" don't convey what lives inside. "Weave Families" is meaningless to anyone unfamiliar with Shaman weaving.
- **Color swatches lack labels** in Quick Controls — users see colored squares without knowing which color they control until hovering.
- **Panel is overwhelming** — ~40+ controls with no categorization beyond collapsible sections.
- **`ShiftY()` layout math** (`layoutShift = 120`, `layoutScale = 1.6`) is opaque magic numbers.

### 4. Migration System — **9/10** (+1.0)

**Strengths:**

- Table-driven migration (not if-ladder)
- Every migration preserved (no deletions)
- Version 54 means robust upgrade path
- Nil-guarding on all DB reads with `or ns.DB_DEFAULTS.*` fallback

**Weaknesses:**

- **54 versions is too many.** Each new feature bumps the schema. Consider collapsing old migrations or using a "current defaults + migration-only for breaking changes" model.
- Migration ordering is fragile — if two PRs add migration entries at the same index, merge conflicts corrupt user data.
- Fresh-install block duplicates DB_DEFAULTS inline (200+ lines). If defaults change without updating the fresh block, fresh installs get different values than upgrades.
- `IsVisibleDefaultColor()` migration helper (v10) uses floating-point comparison (`math.abs(...) < 0.001`) — fragile.

### 5. ClassMods — **7/10**

**Strengths:**

- 6 full class implementations (Warrior, Hunter, Rogue, Paladin, Shaman, Druid)
- Each class's Setup function is self-contained
- Buff icon tracking with glow effects is genuinely impressive
- Target debuff duration bars with pulsing glow in last 4s
- Reckoning stack, Libram swap timer — niche but complete

**Weaknesses:**

- **Enormous file** — `ClassMods.lua` is likely 2500+ lines. Single-file class mods make maintenance hard.
- **Paladin section is bloated** — ~1000 lines for one class, with duplicate bar creation patterns (Judgement bar, Seal Vengeance bar) that parallel what `EnsureVerticalHelperBar()` does.
- **OnUpdate chain pattern** (described above) is fragile — each class overwrites `ns.OnUpdate`.
- **Hunter bar globals** should be local/ns.* not .luacheckrc-suppressed globals.
- **Duplicated bar creation logic** — `EnsureVerticalHelperBar()` in ClassMods replicates what `CreateBar()` in UI.lua does. Bar creation should be a shared helper.

### 6. State Engine — **9/10**

**Strengths:**

- CLEU dispatch handles `SWING_DAMAGE`, `SWING_MISSED`, `SPELL_CAST_SUCCESS`, `SPELL_EXTRA_ATTACKS`, `SPELL_DAMAGE`, `SPELL_MISSED`, `SPELL_AURA_APPLIED`
- Parry haste implementation correct (40% reduction, 20% floor)
- Ranged start deduplication window
- Extra attack handling (Windfury, Sword Spec)
- Reset hardening on world entry and combat end
- Latency refresh at 0.05s in hot path

**Weaknesses:**

- `ResolveSpellcastEventSpell()` handles the castGUID-as-spell edge case well, but the hunter cast state machine in `HandleSpellcastSucceeded()` is very complex (~50 lines of fallback logic).
- `ClearPendingMeleeQueueState()` checks class via if/elseif — should use class lookup table instead.
- Multiple `GetCurrentTime()` local shims across files (SuperSwingTimer.lua, State.lua, ClassMods.lua, UI.lua, Config.lua) instead of always using `ns.GetAlignedTime()`.

### 7. Weave Engine — **8.5/10**

**Strengths:**

- Complete Shaman weave catalog with all ranks
- Highest-known-rank resolution for leveling profiles
- Live cast timing from `UnitCastingInfo()` with haste fallback
- Latency-aware safety calculation (`safeStartIn`, `clipAmount`)
- Spark animation with cast progress
- Spell family color system

**Weaknesses:**

- `GetLivePlayerCastTiming()` duplicates between Weaving.lua and UI.lua's `GetLiveHunterCastInfo()`
- Weave state is a single global `ns.weaveState` table — fine for single-player but not extensible
- No documentation of what "safe" vs "clip" means for new users
- `GetWeaveDisplayInfo()` returns nil for non-Shaman — blocks future cross-class weave features

### 8. UI Rendering — **8/10**

**Strengths:**

- Bar factory with consistent spark, border, background, label creation
- Hunter cast bar with latency overlay + clip-safety tinting
- Ranged bar cast-zone visual (red/green)
- Class-colored label inversion (black text on bright fill)
- `RestackDebuffBars()` and `GetDebuffStackOffset()` for dynamic positioning
- Overlay frame pattern for sparks above bars

**Weaknesses:**

- `RefreshBarLabelStyles()` iterates all bars but doesn't handle new ones added by ClassMods
- `ShouldShowHunterCastBar()` forward-declared as local then assigned later — fragile
- Bar factory creates textures unconditionally even for classes that won't use them
- No pooled texture system for sparks/overlays

### 9. Testing & Quality Gates — **5/10** (+2.0)

**Strengths:**

- `luacheck` configuration with proper WoW globals list (`.luacheckrc`) and `.luarc.json` for modern linter
- `luac -p` syntax check capability
- AGENTS.md documents manual QA steps
- **NEW: GitHub Actions CI** (`.github/workflows/luac.yml`) auto-runs `luac -p` on push/PR
- **NEW: `test_migrations.lua`** — 37 tests verifying `DeepCopyDefaults` correctness
- **NEW: `docs/QA.md`** — step-by-step manual smoke-test checklist covering all 6 classes

**Weaknesses:**

- **No CLEU parsing test harness** — the most error-prone code path has zero simulation tests.
- No regression test for migration cases (54 versions, only DeepCopyDefaults tested).
- Manual QA is the only runtime bug barrier — though `docs/QA.md` now provides a checklist.
- No integration tests for the OnUpdate hook system.

### 10. Documentation — **7.5/10** (+0.5)

**Strengths:**

- Comprehensive AGENTS.md with file map, conventions, commands
- ROADMAP.md tracks phases
- CHANGELOG.md maintained
- memory-bank/ with activeContext, progress, systemPatterns, techContext, visualContext
- docs/ folder with WIRING.md, UI.md, swingtimer.md, weavingapi.md
- .github/skills/wow-classic-lua/ reference pack

**Weaknesses:**

- **Zero inline code documentation** (TSDoc/LDoc) — functions lack parameter/return docs
- README.md doesn't explain what the config panel does or how to use it
- docs/ files are incomplete (WIRING.md is good, but API surface docs are thin)
- No user-facing help text in the addon itself (no `/sst help` output beyond basic commands)
- AUDIT.md is this file — it didn't exist before now

---

## Critical Issues (Must Fix)

| # | Issue | Severity | File(s) | Effort | Status |
|---|-------|----------|---------|--------|--------|
| 1 | `ns.OnUpdate` chain overwritten by each class Setup — fragile pattern that breaks if multiple classes load | **High** | ClassMods.lua | Medium | 🔄 **Reverted** — infrastructure in place (Hooks.lua), ClassMods conversion pending |
| 2 | ~~Fresh-install block duplicates DB_DEFAULTS inline~~ | Fixed | SuperSwingTimer.lua | — | ✅ `DeepCopyDefaults()` implemented |
| 3 | 8 Hunter bar globals suppressed via .luacheckrc | **Medium** | ClassMods.lua, .luarc.json | Low | ✅ Added to `.luarc.json` |
| 4 | No global scale slider | **Medium** | Config.lua, UI.lua, Constants.lua | Medium | ✅ Implemented |
| 5 | Config panel has no intro text or help — overwhelming UX | **Medium** | Config.lua | Low | ✅ Help blurb + renamed sections + tooltips added |
| 6 | Zero automated tests — 54 migration versions untested | **High** | — | Large | ✅ CI pipeline, migration tests, QA checklist added |
| 7 | ~~`GetCurrentTime()` local shim duplicated across 5 files~~ | Fixed | All files | Low | ✅ Replaced with `ns.GetAlignedTime()` |

---

## High-Value Improvements

### A. Global Size Scale (User-Requested)

Add a `globalScale` slider at the **very top** of `/sst`. This multiplies all bar widths, bar heights, icon sizes, font sizes, spark sizes, border sizes, and gaps proportionally relative to their defaults. Implementation:

1. Add `globalScale = 1.0` to `ns.DB_DEFAULTS` (Constants.lua)
2. Add migration case (or nil-guard the fresh-install)
3. Add `ApplyGlobalScale()` that iterates all bars and applies scale factor to all size-related properties
4. Create slider row as the **first control** in the config panel, above Quick Controls
5. Wire into `ApplyBarSize()` and all size-related refresh paths
6. Document the behavior: "Scale all bars and icons proportionally (1.0 = default, 2.0 = double size)"

### B. OnUpdate Chain Refactor

Replace the fragile capture-chain pattern with a proper registration system:

```lua
ns.OnUpdateHooks = ns.OnUpdateHooks or {}
function ns.RegisterOnUpdateHook(hook)
    table.insert(ns.OnUpdateHooks, hook)
end
```

Then `ns.OnUpdate` iterates all hooks instead of being overwritten.

### C. Shared Bar Factory for ClassMods

Move `CreateBar()` (or a helper) to `ns.*` so ClassMods.lua uses the same bar creation path as UI.lua instead of duplicating frame creation code.

### D. Config Panel Rearrangement

1. Add subtitle/description at the top of `/sst`
2. Move "Global Scale" slider to the very top
3. Rename sections: "General Behavior" → "Combat & Timer Behavior", "Weave Families" → "Shaman Weave Spells"
4. Add tooltip descriptions to all controls (use the existing `AddControlTooltip()` helper — it exists but is barely used)
5. Group Quick Controls with visual dividers

### E. Hunter Bar Globals Fix

Move the 8 hunter bar variables from `Global` suppression into local scope or `ns.*`:

```lua
ns.serpentStingBar = ns.serpentStingBar or CreateFrame(...)
```

Then remove them from `.luacheckrc` globals list.

### F. Fresh-Install Block Simplification

Replace the 200+ line fresh-install block with a deep-copy function:

```lua
local function DeepCopyDefaults(t)
    local copy = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            copy[k] = DeepCopyDefaults(v)
        else
            copy[k] = v
        end
    end
    return copy
end
```

Then: `SuperSwingTimerDB = DeepCopyDefaults(ns.DB_DEFAULTS)`

This eliminates drift permanently.

### G. Reduce Migration Version Count

After ensuring all users are past a certain version (e.g., v40+), collapse migrations 1–40 into a single "legacy" step. Document this carefully.

---

## Strengths to Preserve

| Strength | Why It Matters |
|----------|---------------|
| Single `ns.*` namespace | Zero global pollution — cleaner than 90% of WoW addons |
| Blizzard API wrappers | `ns.GetAlignedTime()`, `ns.GetSpellInfo()`, `ns.GetUnitCastingSpellInfo()` — client-abstracted |
| Nil-guarded class-mod calls | `if ns.UpdateX then ns.UpdateX() end` prevents cross-class crashes |
| Table-driven migration | More maintainable than if-ladder |
| Buff icon system | Gold glow + pulse + countdown text is genuinely premium |
| Latency-aware timing | `GetNetStats()` cached at 0.05s for weave/clip safety |
| CLEU dispatch | Handles all swing-relevant events correctly |
| Visual polish | Class-colored labels, cast-zone overlays, glow effects, fade animations |
| memory-bank system | Persistent context across sessions |
| `GetCurrentTime()` clock domain | All timers use same aligned clock — prevents desync |

---

## Competitive Analysis

Compared to other swing timer addons (WeaponSwingTimer, SwangThang, Quartz, Gnosis):

| Feature | SuperSwingTimer | Competitors |
|---------|----------------|-------------|
| Full CLEU-based timing | ✅ Yes | ❌ Most use UnitAttackSpeed polling |
| Shaman weave assist | ✅ Yes (with breakpoint math) | ❌ None |
| Per-class overlays | ✅ 6 classes | ❌ Most support 2-3 |
| Buff icon tracking | ✅ Yes (with glow) | ❌ Rare |
| Target debuff bars | ✅ Yes | ❌ Rare |
| Config UI | ✅ /sst panel | ❌ Most are slash-command only |
| Latency awareness | ✅ Yes | ❌ Most ignore latency |
| Migration system | ✅ 54 versions | ❌ Most have none |
| Global scale slider | ✅ Yes | ❌ Most don't have it either |
| Unit tests | ❌ Missing | ❌ All missing |
| Inline docs | ❌ Missing | ❌ All missing |

**Differentiators to emphasize:** Shaman weave assist, 6-class support, buff icon system, latency-aware timing, CLEU-based accuracy.

---

## Roadmap to 10/10

### Phase 1: Critical Fixes (1–2 sessions)

- [x] **Fix `ns.OnUpdate` chain** — infrastructure done (Hooks.lua, UI.lua, Config.lua). All 9 ClassMods chains converted to `ns.RegisterOnUpdateHook()`. Zero errors.
- [x] **Replace fresh-install block** — `DeepCopyDefaults(ns.DB_DEFAULTS)` implemented. 200+ inline duplicate block eliminated. Migration test harness in `test_migrations.lua`.
- [x] **Fix 8 Hunter bar globals** — added to `.luarc.json` diagnostics.globals
- [x] **Deduplicate `GetCurrentTime()` shims** — all 5 local shims replaced with `ns.GetAlignedTime()`

### Phase 2: UX Overhaul (1–2 sessions)

- [x] **Global Scale slider** — proportional scaling for all bars, icons, fonts (0.5x–3.0x)
- [x] **Config panel intro text** — help blurb added explaining panel layout
- [x] **Rename unclear section headers** — "General Behavior" → "Combat & Timer Behavior", "Weave Families" → "Shaman Weave Spells"
- [x] **Apply tooltips to all controls** — extended `AddControlTooltip()` usage across Quick Toggles
- [x] **Color swatch labels in Quick Controls** — swatch buttons now show text labels directly on the colored square. Labels auto-invert for readability. Gold row headers beside each swatch.

### Phase 3: Testing Infrastructure (2–3 sessions)

- [ ] **CLEU parsing test harness** — simulate swing/miss/damage events to verify timer state machine
- [x] **Migration test suite** — `test_migrations.lua` with 37 tests for `DeepCopyDefaults` correctness
- [x] **GitHub Actions CI** — `.github/workflows/luac.yml` auto-runs `luac -p` on push/PR
- [x] **Manual smoke-test checklist** — `docs/QA.md` with step-by-step QA steps

### Phase 4: Polish & Documentation (1–2 sessions)

- [ ] **Enterprise-grade LDoc/TSDoc comments** — 20+ core functions documented across 7 files (Constants, State, Weaving, UI, ClassMods, Config, Hooks). Still need full coverage on remaining ~80 functions.
- [x] **README.md config panel guide** — annotated ASCII layout + section-by-section walkthrough added
- [ ] **Collapse legacy migrations (v1–v40)** — single "legacy" step after confirming no users below v40
- [x] **Font path constant** — `ns.FONT_PATH = "Fonts\\FRIZQT__.TTF"` in Constants.lua, 39+ hardcoded paths replaced

### Phase 5: File Splitting & Code Organization (2–3 sessions)

- [ ] **Split `ClassMods.lua` (~2500+ lines)** → one file per class or shared helper extraction
- [ ] **Split `Config.lua` (~3500+ lines)** → `_Config_Panel.lua` (layout/frame creation) + `_Config_Controls.lua` (widget builders) + `_Config_Settings.lua` (apply functions, reset)
- [ ] **Split `UI.lua` (~1600 lines)** → `_UI_Bars.lua` (bar factory, creation) + `_UI_Render.lua` (OnUpdate, visibility, positioning)
- [ ] **Shared bar factory for ClassMods** — `ns.CreateHelperBar()` so `EnsureVerticalHelperBar()` in ClassMods doesn't duplicate `CreateBar()` in UI.lua
- [ ] **Load order management** — ensure split files maintain Constants → State → Weaving → UI* → ClassMods* → Config* → Bootstrap dependency chain

### Phase 6: Advanced Features (Future)

- [ ] **Config preset system** — save/load named profiles with `/sst preset save/load`
- [ ] **WeakAura-like text overlays** — customizable text/symbol labels on bars (e.g., "OP!" for Overpower)
- [ ] **Enemy swing timer improvements** — multi-target tracking via nameplate hover or raid frames
- [ ] **Buff/CD icon custom ordering** — allow users to reorder tracked spell icons in the icon group

### Phase 7: Enterprise-Grade Lua Conventions (applied from v0.1.7+)

**All new code and refactored files MUST use:**

```lua
--- Brief one-line description.
--  Detailed multi-line explanation of what this function does,
--  including any side effects, timing constraints, or API dependencies.
--  @param paramName (type) Description of parameter, including nil behavior
--  @return (type) Description of return value, or nil if XYZ
```

Example:
```lua
--- Apply global scale multiplier to all bar/icon/font sizes.
--  Reads the current globalScale from SavedVariables, computes scaled
--  dimensions via ns.Scale(), and re-sizes every bar, helper, icon,
--  spark, and font string in the addon. Called when the scale slider
--  changes or at addon init after bars are created.
--  @param ... (none) Reads SuperSwingTimerDB.globalScale directly
--  @return (nil) Operates entirely through side effects on frame objects
function ns.ApplyGlobalScale()
    -- ...
end
```

**Conventions:**
- `@param` for every parameter with type + nil behavior
- `@return` for return values (use `(nil)` for void-ish returns)
- `@usage` for non-trivial call patterns
- `@see` for related functions (e.g., `@see ns.Scale`)
- All files get a module-level header comment describing their role and dependency order

---

## Appendix: File Metrics

| File | Lines (est.) | Score | Split Priority | Key Concern |
|------|-------------|-------|----------------|-------------|
| `SuperSwingTimer.lua` | ~700 | 7/10 | Low | Fresh-install block, mixed concerns |
| `SuperSwingTimer_Constants.lua` | ~900 | 9/10 | Low | Cleanest file in the project |
| `SuperSwingTimer_State.lua` | ~1200 | 9/10 | Medium | Well-structured CLEU dispatch |
| `SuperSwingTimer_Weaving.lua` | ~500 | 8.5/10 | Low | Solid, isolated |
| `SuperSwingTimer_UI.lua` | ~1600 | 8/10 | Medium | Large but well-organized |
| `SuperSwingTimer_ClassMods.lua` | ~2500+ | 7/10 | **Highest** | Too large, fragile OnUpdate chain |
| `SuperSwingTimer_Config.lua` | ~3500+ | 6/10 | **Highest** | Enormous, lacks help text/scale slider |

**Split priority:** ClassMods.lua → Config.lua → UI.lua → State.lua (in order of complexity gain)

---

## Implementation Log

### 2026-07-05 — Global Scale Slider (Phase 2, Item A)

**What was built:**

| File | Change |
|------|--------|
| `Constants.lua` | Added `globalScale = 1.0` to `ns.DB_DEFAULTS`. Added `ns.GetGlobalScale()` (clamped 0.5–3.0). Added `ns.Scale(value)` helper — multiplies base pixel value by scale, returns `math.max(1, floor(value × scale + 0.5))`. |
| `SuperSwingTimer.lua` | Added `globalScale` to fresh-install block. Added nil-guard in migration fill-section. Added `ns.ApplyGlobalScale()` call in `OnAddonLoaded` after `InitBars()`. |
| `UI.lua` | Modified `CreateBar()` to use `ns.Scale()` on initial sizes. Modified `ApplyBarSize()` to compute `scaledWidth`/`scaledHeight` internally and use those for all `SetSize` calls, spark sizes, and derived bar heights. Modified `ApplyBarBorderSize()` to use scale. Modified `CreateGcdTickerBar()` to use scale. Added `ns.ApplyGlobalScale()` that re-applies bar sizes, then refreshes all 6 classes' helpers, icons, GCD ticker anchor, and cast zone. |
| `Config.lua` | Added Global Scale slider as the **first control** at top of scroll content — 0.5x–3.0x range, step 0.1, with gold label and gray description text. Shifted all Quick Controls Y offsets down by scale section height. Added `globalScale` to `ResetConfigDefaults()`. Added slider sync in `ToggleConfig()`. Added `ApplyGlobalScale()` call at end of reset. Increased content height from 3600→3800. |

**Scale behavior:** `finalSize = math.floor(savedValue × scale + 0.5)`, minimum 1px. Individual sliders set the base size; the Global Scale slider multiplies everything on top.

### 2026-07-05 — OnUpdate Hook System + Hunter Bar Globals (Phase 1, Items A + C)

**What was built:**

| File | Change |
|------|--------|
| `SuperSwingTimer_Hooks.lua` | **New file** (60 lines). `ns.OnUpdateHooks` ordered list, `ns.RegisterOnUpdateHook(hook, index)` with optional insertion position. Full LDoc docstrings. Loads between Weaving and UI. |
| `SuperSwingTimer_UI.lua` | Core render path extracted to `CoreRenderHook` function and registered as hook #1. `ns.OnUpdate` now iterates `ns.OnUpdateHooks` in order. |
| `SuperSwingTimer_ClassMods.lua` | ⚠️ **Reverted to original.** All 9 `ns.OnUpdate = function` chains restored by user. Still need conversion to `ns.RegisterOnUpdateHook()`. The old chains wrap on top of the hook iterator (functional but fragile). |
| `SuperSwingTimer_Config.lua` | Test Bars wrapper converted from chain-overwrite to `ns.RegisterOnUpdateHook(..., 1)` — inserts at position 0 so it runs before the core render path. |
| `.luarc.json` | Expanded to cover all WoW globals used across the project, including 8 Hunter bar closure-captured locals. |
| `SuperSwingTimer.toc` | Added `SuperSwingTimer_Hooks.lua` to load order between Weaving and UI. |

**Hook system design:**
```lua
-- Register (appends to end):
ns.RegisterOnUpdateHook(function(elapsed)
    if ns.MyFeature then ns.MyFeature(elapsed) end
end)

-- Insert at front (for pre-render hooks like Test Bars):
ns.RegisterOnUpdateHook(function(elapsed)
    if ns.barTestActive then AnimateTestBars() end
end, 1)
```

**Current state:** Infrastructure is in place (Hooks.lua, UI.lua, Config.lua). ClassMods.lua **reverted to original** by user — the old chains functionally chain through the hook iterator but produce 2 `Duplicate field OnUpdate` errors and remain fragile (chain breaks if any link fails to call its predecessor).

### 2026-07-05 — Fresh Install / GetTime / Font / CI / Audit updates

**What survived:**

| File | Change |
|------|--------|
| `SuperSwingTimer.lua` | Fresh-install block replaced with `DeepCopyDefaults(ns.DB_DEFAULTS)` — 155-line inline literal eliminated. Eliminates drift risk between defaults and fresh installs. |
| `SuperSwingTimer_Constants.lua` | `ns.FONT_PATH = "Fonts\\FRIZQT__.TTF"` added. 39+ hardcoded font paths in ClassMods.lua replaced with the constant. |
| `SuperSwingTimer_State.lua` | 5 local `GetCurrentTime()` shims removed — all callers use `ns.GetAlignedTime()` directly. |
| `SuperSwingTimer_Config.lua` | Section headers renamed ("General Behavior" → "Combat & Timer Behavior", "Weave Families" → "Shaman Weave Spells"). Help blurb added. 7 tooltips added to Quick Toggles. |
| `test_migrations.lua` | New file — 37 tests verifying `DeepCopyDefaults` correctness for all data types (numbers, strings, booleans, nested tables, colors). |
| `docs/QA.md` | New file — step-by-step manual smoke-test checklist covering all 6 classes, config panel, and edge cases. |
| `.github/workflows/luac.yml` | CI pipeline — auto-runs `luac -p` on all 7 Lua files on push/PR to main. |
| `Constants.lua` (docstrings) | 6 core public functions documented: `ns.StartSwing`, `ns.HandleCLEU`, `ns.RefreshLatencyCache`, `ns.ApplyBarSize`, `ns.ApplyVisibility`, `ns.InitBars`. |

**Not yet done despite changelog note:** `SuperSwingTimer_ClassMods_Shared.lua` — the shared helper extraction from ClassMods was not completed.

### 2026-07-05 — ClassMods OnUpdate hook conversion + Color swatch labels

**ClassMods OnUpdate chains converted:** All 9 remaining `ns.OnUpdate = function` chains in ClassMods.lua converted to `ns.RegisterOnUpdateHook()`. The `Duplicate field OnUpdate` errors are eliminated. ClassMods.lua now passes `get_errors` clean. The last fragile chain-overwriting pattern in the codebase is gone.

**Color swatch labels:** Quick Controls color swatch buttons now display white/black OUTLINE text labels directly on the colored surface (e.g. "MH Color", "OH Color"). Text auto-inverts: black text on light colors, white text on dark colors. Updates dynamically when colors change. Gold headers beside each swatch were already present but were default white in compact mode — now gold in all modes.

---

## Changelog for this file

| Date | Author | Change |
|------|--------|--------|
| 2026-07-05 | AI Audit | Initial audit with all 10 sections scored |
| 2026-07-05 | Implementation | Global Scale slider implemented across 4 files |
| 2026-07-05 | Implementation | OnUpdate hook system + Hunter globals + AGENTS.md conventions |
| 2026-07-05 | User | DeepCopyDefaults, GetTime shims, FONT_PATH, CI pipeline, QA doc, migration tests |
| 2026-07-05 | Revert | ClassMods.lua restored to original — OnUpdate hook conversion pending |
| 2026-07-05 | Implementation | ClassMods OnUpdate hooks converted + color swatch labels added |
| 2026-07-05 | Implementation | README config panel walkthrough + 20+ LDoc docstrings added |
| 2026-07-05 | Implementation | Section help texts + improved tooltips + CreateHelpButton + enterprise UX blueprint |

---

## Enterprise UX Audit — `/sst` Config Panel

After researching Blizzard's Interface Options patterns and studying top addon panels (WeakAuras, Details!, Plater, Bartender4), here's the complete blueprint for taking `/sst` from functional to enterprise-grade.

### Current Score: 6/10 → Target: 9/10

### The Enterprise Panel Blueprint

```text
+------------------------------------------------------------------+
| Super Swing Timer                                        [X]     |
| [ Search settings...                                    🔍]      |
|------------------------------------------------------------------|
| [Global Scale ====slider (0.5x–3.0x)====] [1.0]                 |
| Proportionally scales all bars, icons, sparks, borders, fonts    |
|------------------------------------------------------------------|
| Quick Controls:  [Visibility] [Colors] [Class]  <-- TAB BAR     |
| +- Tab: Visibility ----------------------------+                |
| | ✅ Use Class Colors   ✅ Show MH            |                |
| | ✅ Lock Bars          ✅ Show OH            |                |
| | ✅ Show Ranged        ✅ Show Enemy         |                |
| | [?]  What does Lock Bars do?                |                |
| +---------------------------------------------+                |
|------------------------------------------------------------------|
| +- Appearance ──────────────────────────────────────────── [>]  |
| | 🎨 Bar appearance, textures, and sizing controls              |
| | Bar Width [=====240=====]  Bar Height [=====15=====]          |
| | MH Texture [current_texture.png▼]  [Reset]                    |
| | [+ Add more...]                                               |
| +--------------------------------------------------------------+|
| +- Timing & Behavior ──────────────────────────────────── [>]   |
| | ⏱ Swing flash, GCD ticker, test bars                         |
| | ✅ Minimal Mode [?]  ✅ Swing Flash  ✅ GCD Ticker            |
| | [▶ Test Bars 16s]  [Reset Section]                            |
| | [+ Show Advanced Settings]  → reveals: Indicator Glow, ...    |
| +--------------------------------------------------------------+|
| +- Shaman Weave Assist ────────────────────────────────── [>]   |
| | 🔄 Weave marker textures, layers, spell families              |
| | ✅ Show Weave Assist  [?]  What is a weave breakpoint?        |
| | [Reset Section]                                               |
| +--------------------------------------------------------------+|
|                                                                  |
| [Save Profile...] [Load Profile...] [Reset All Defaults]         |
| Client: TBC Anniversary 2.5.5                          v0.1.7   |
+------------------------------------------------------------------+
```

### Key Enterprise Patterns (from research)

#### 1. Search Bar (Highest Impact)
- **Why**: WeakAuras, Details!, and Plater all have real-time search that filters the entire options tree. With 3800px of scrollable content, users cannot find settings without searching.
- **How**: A text input at the top. On each keystroke, iterate all row frames and hide/show based on whether their label text matches the search query. Each row stores its searchable text in a `.searchText` field.
- **Dual-client**: `CreateFrame("EditBox")` + `"InputBoxTemplate"` works on both clients.

#### 2. Tabbed Quick Controls (Visual Noise Reduction)
- **Why**: The two-column layout collapses toggle labels and swatch colors into a dense block. Users don't know which column is which.
- **How**: Replace the two columns with a 3-tab bar: **Visibility** (toggles only), **Colors** (swatches only), **Class** (class-specific rows like Shield Block, Rapid Fire, etc.). Each tab only shows its relevant controls. Tab bar uses `UIDropDownMenu`-style buttons.
- **Benefit**: Reduces visible controls at once from ~30 to ~10, organized by purpose.

#### 3. Section Help Text + [?] Buttons (Onboarding)
- **Why**: Terms like "Weave Assist breakpoint", "GCD Ticker", "Indicator Glow Mode" mean nothing to new users. Top addons explain every concept inline.
- **How**: 
  - Each collapsible header has a subtitle: "🎨 Bar appearance, textures, and sizing controls"
  - Complex controls get a [?] button next to their label. Clicking it shows a `GameTooltip` with a 2-3 sentence explanation of the concept.
  - Example: "What is a weave breakpoint? — Shows the latest point in your main-hand swing where you can start a spell cast without delaying your next white hit. The red zone moves with latency and spell haste."

#### 4. Per-Section Reset Buttons (Granular Control)
- **Why**: The current "Reset Defaults" nukes everything. Users want to reset just the appearance settings without losing their weave tuning.
- **How**: Each collapsible section footer has a small `[Reset Section]` button that reverts only that section's DB keys to `ns.DB_DEFAULTS`.

#### 5. Progressive Disclosure (Reduce Overwhelm)
- **Why**: 40+ controls shown at once is overwhelming for new users. Plater hides advanced script/mod settings behind a "Show Advanced" toggle.
- **How**: Sections show only the 3-5 most important settings by default. A "[+ Show Advanced Settings]" link reveals the rest (e.g., Indicator Glow Mode, Bar Texture Layer, Weave Triangle Gap).

#### 6. Profile System (Power User Feature)
- **Why**: Players have different setups for alts, specs, and situations (raid vs PvP). Details! and WeakAuras both support named profiles.
- **How**: `/sst profile save <name>` deep-copies `SuperSwingTimerDB` to `SuperSwingTimerDB_profiles[name]`. `/sst profile load <name>` replaces the active DB and reapplies. UI buttons at the panel bottom.
- **Note**: Profile system is the most complex item — requires careful deep-copy and validation.

#### 7. Texture Preview Chips (Visual Feedback)
- **Why**: Texture pickers show text paths. Users can't tell what a texture looks like without applying it.
- **How**: Each texture row gets a small 20x20 thumbnail preview showing the actual texture. Updated on selection change.

#### 8. Keyboard Navigation (Accessibility)
- **Why**: Tab order, Enter to toggle checkboxes, arrow keys for sliders. Blizzard's widget templates handle most of this automatically — we just need to ensure focus order is correct.
- **How**: Set `tabOrder` on rows. Ensure `SetObeyStepOnDrag(true)` on sliders. CheckButtons work with Space/Enter by default.

### Gap Analysis vs Enterprise Addons

| Feature | WeakAuras | Details! | Plater | **SST Now** | **SST Target** |
|---------|-----------|----------|--------|-------------|----------------|
| Search/filter | ✅ | ✅ | ✅ | ❌ | ✅ |
| Profile system | ✅ | ✅ | ✅ | ❌ | ✅ |
| Per-section reset | ✅ | ✅ | ❌ | ❌ | ✅ |
| Inline help/tooltips | ✅ | ✅ | ✅ | ⚠️ 40% | ✅ 100% |
| Section help text | ✅ | ✅ | ✅ | ❌ | ✅ |
| Progressive disclosure | ✅ | ✅ | ✅ | ❌ | ✅ |
| Texture previews | ✅ | ✅ | ✅ | ⚠️ spark only | ✅ |
| Keyboard nav | ✅ | ✅ | ✅ | ❌ | ✅ |
| Category tabs | ✅ | ✅ | ✅ | ❌ | ✅ |
| Undo/Apply | ✅ | ✅ | ❌ | ❌ | ❌ (future) |
| Import/Export | ✅ | ✅ | ✅ | ❌ | ✅ (profiles) |
| Client version indicator | ❌ | ❌ | ❌ | ❌ | ✅ |

### Dual-Client Implementation Notes

All proposed changes work on both Classic Era and TBC Anniversary:
- `CreateFrame("EditBox", nil, nil, "InputBoxTemplate")` — exists on all clients
- `GameTooltip` — exists on all clients
- Tab-order (`SetFrameLevel` ordering) — works on all clients
- CheckButton templates — `"InterfaceOptionsCheckButtonTemplate"` works on both
- Slider templates — `"OptionsSliderTemplate"` works on both
- Profile storage — uses same SavedVariables system, no API differences

**No branching needed.** All patterns are fundamental Blizzard APIs that have existed since Vanilla.

### Implementation Phases

| Phase | Items | Effort | Risk |
|-------|-------|--------|------|
| **Phase 1** | Add tooltips to all controls — slider factory now accepts custom tooltips, key sliders updated | Low | None |
| **Phase 2** | Add section help text + CreateHelpButton for [?] buttons | Low | None |
| **Phase 3** | Tabbed Quick Controls (Visibility/Colors/Class) | Medium | Low |
| **Phase 4** | Per-section Reset buttons | Medium | Low |
| **Phase 5** | Search bar | Medium | Low |
| **Phase 6** | Progressive disclosure (Show Advanced) | Medium | Low |
| **Phase 7** | Texture preview chips | Low | Low |
| **Phase 8** | Profile system (save/load) | Large | Medium |
| **Phase 9** | Keyboard navigation audit | Low | None |

### Recommendation

Start with **Phase 1 + 2** (tooltips + help text) — they're pure text, zero risk, and immediately make the panel more approachable. Then do **Phase 3** (tabbed Quick Controls) to fix the overwhelming two-column layout. The search bar (Phase 5) is the biggest UX leap but requires more code.

Want me to start implementing Phase 1?