# Ultragoal Brief: Addon Deep Audit, Power Bar Architecture, Hunter Auto Shot Enlarge, and Version Bump

## Objective

Deep audit and comprehensive enhancement of SuperSwingTimer (Classic Era 1.15.9 / TBC Anniversary 2.5.6):

1. **TOC Version Update**: Bump version from v0.2.1 to v0.2.2 in `SuperSwingTimer.toc`, DB migration to v62, and sync documentation.
2. **Multi-Class Power/Resource Bar**: Implement a unified, high-performance power bar that accurately displays:
   - Rage for Warriors (with Execute warning)
   - Energy for Rogues
   - Dynamic Form-based Power for Druids (Rage in Bear, Energy in Cat, Mana in Caster/Travel/Tree/Moonkin)
   - Mana for Paladins, Shamans, and Hunters
   - Correct Blizzard API integration (`PowerBarColor[powerToken]`, `UnitPowerType`, `UnitPower`, `UnitPowerMax`)
   - Event-driven reactive updates (`UNIT_POWER_UPDATE`, `UNIT_POWER_FREQUENT`, `UNIT_DISPLAYPOWER`, `UNIT_MAXPOWER`)
3. **Hunter Auto Shot Enhancement**: Increase default Hunter cast bar height from 10/13px to 15px (matching standard bar height), ensuring clean typography and marker alignment.
4. **Configuration & Preview**: Add per-class power bar toggles and color controls in Quick Controls, and integrate into live test previews.
5. **Codebase Quality & Optimizations**: Resolve all lint issues (luacheck 0 warnings), remove dead recursion, optimize event hooks, and add unit test coverage.

## Constraints & Architecture Boundaries

- Zero external library dependencies (pure native WoW Classic / TBC API).
- Backward compatibility with existing SavedVariables (`SuperSwingTimerDB`) via migration function.
- Fail-open and safe nil guards across all class initializers.
- Zero luacheck warnings or errors across the entire codebase.

