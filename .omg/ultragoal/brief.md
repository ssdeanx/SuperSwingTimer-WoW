# Ultragoal Brief: Comprehensive Addon Deep Audit, Zero-Allocation Engine & Performance Modernization

## Objective

Conduct a deep audit of SuperSwingTimer against Blizzard's FrameXML source (`/home/sam/wow-ui-source/`, Classic Era 1.15.9 / TBC Anniversary 2.5.6) and implement enterprise-grade architectural optimizations, hot-path zero-allocation performance enhancements, event-filtering modernizations, and test automation:

1. **Unit-Filtered Event Registration**:
   - Modernize `SuperSwingTimer.lua` event registrations from global `RegisterEvent` to `RegisterUnitEvent("UNIT_AURA", "player", "target")` and unit-scoped power/spellcast events.
   - Eliminate massive raid-wide event churn in 25-man / 40-man environments.

2. **Hot-Path Zero Allocation & C++ Layout De-duplication**:
   - Optimize `SuperSwingTimer_State.lua` `HasActiveTimers()`: eliminate `pairs()` iterator allocations and dynamic table allocations; smart-sleep `OnUpdate` when completely idle with no active buffs.
   - Optimize `SuperSwingTimer_ClassMods.lua` `UpdatePlayerPowerBar()`: cache rendered power strings to eliminate string allocations every frame.
   - Optimize `SuperSwingTimer_UI.lua` `UpdateSparkPosition()` and `SyncBarLabelText()`: avoid `ClearAllPoints()` / `SetPoint()` and `SetText()` calls when pixel positions and label values are unchanged.

3. **Shaman Weaving & Latency Streamlining**:
   - Streamline `SuperSwingTimer_Weaving.lua`: reuse `ns.cachedLatency` instead of querying `GetNetStats()` repeatedly; unify buff scans in `GetLiveSpellHasteMultiplier` into a single-pass loop.

4. **Class Modules & UI Visual Polish**:
   - Validate and harden class modules across Warrior, Rogue, Paladin, Shaman, Druid, and Hunter.
   - Ensure pixel-perfect debuff bar stacking, Execute indicator glow, Hunter Auto Shot 15px alignment, and smooth Druid shapeshifting transitions.

5. **Headless Test Suite & Automated Verification**:
   - Provide a standalone CLI test execution runner for `SuperSwingTimer_Tests.lua` with mock WoW environment.
   - Add test coverage for new zero-allocation optimizations and DB v64 migration.

6. **Version Bump, Documentation & Zero-Lint Quality**:
   - TOC version bump to `v0.2.4`, DB schema migration to `v64`.
   - Update `CHANGELOG.md`, `README.md`, `MEMORY.md`, and `API_AUDIT_REPORT.md`.
   - Guarantee 0 luacheck warnings / errors across all files.

## Constraints & Architecture Boundaries

- Zero external library dependencies (pure native WoW Classic / TBC API).
- Full backward compatibility with existing SavedVariables (`SuperSwingTimerDB`) via migration function.
- Fail-open and safe nil guards across all class initializers.
- Zero luacheck warnings or errors across the entire codebase.
