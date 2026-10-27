# Ultragoal Brief: v0.2.6 Compatibility Audit, Visual Scaling & Bar Sizing Modernization

## Objective

Conduct a comprehensive deep audit of SuperSwingTimer for version `v0.2.6` focusing on:

1. **Dual-Client Compatibility**: Complete verification and hardening between `classic_era` (1.15.9 / 70003) and `classic_anniversary` (2.5.6 / 70006).
   - Centralize spell texture resolution with `ns.GetSpellTexture(spellIdentifier)` (`C_Spell.GetSpellTexture` -> `GetSpellTexture` -> `GetSpellInfo` icon -> live aura fallback).
   - Guarantee buff icon and debuff bar icon textures resolve identically across both client versions.
2. **Global Scaling Fix in Options**:
   - Ensure `ns.ApplyGlobalScale()` triggers `ns.ApplyBarSize(width, height)` so that moving the Global Scale slider in options immediately and dynamically updates all swing bars, sparks, power bar, hunter cast bar, debuff bars, and GCD ticker without requiring a `/reload`.
3. **Bar Sizing & Stacking Geometry**:
   - Answer user queries and document defaults: MH (240x15), OH (240x15), Ranged (240x15), Hunter Cast (240x15), Power Bar (240x10 -> 240x14), Debuff bars (240x6 -> 240x8).
   - Enlarge Player Power Bar default height from 10px to 14px for improved vertical padding and typography legibility.
   - Enlarge Debuff Bars from 6px (and 5px) to 8px and scale their associated spell icons from 6x6 to 8x8 (matching bar height) or larger.
   - Validate stacking geometry in `RestackDebuffBars` (2px spacing between bars, 8px clearance for buff icons).
4. **Automated Verification & Zero-Warning Lint**:
   - Expand `SuperSwingTimer_Tests.lua` and `run_tests.lua` with test coverage for v0.2.6 features.
   - DB schema migration to `v65`.
   - Maintain 0 luacheck warnings/errors under `luacheck .`.
   - Bump version to `v0.2.6` across TOC, changelog, and documentation.

## Constraints & Architecture Boundaries

- Pure native WoW Classic / TBC Anniversary API (zero external runtime dependencies).
- Backward-compatible SavedVariables migration (`SuperSwingTimerDB`).
- Zero luacheck warnings or errors (`luacheck .`).
