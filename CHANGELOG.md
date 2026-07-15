# Super Swing Timer Changelog

> All notable changes to Super Swing Timer. This file documents user-facing and structural changes per release.
> Sections: **Added** / **Changed** / **Fixed** / **Removed** / **Performance** / **Security** / **Docs** / **Internal** / **Notes**
> DB schema migrations are listed under **Notes** per version.

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
