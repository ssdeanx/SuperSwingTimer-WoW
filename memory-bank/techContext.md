# Tech Context

## Runtime environment

- World of Warcraft Classic/TBC addon Lua.
- **Target Environments**:
  - Classic Era & Season of Discovery: Interface `11509` (1.15.x).
  - TBC Anniversary: Interface `20506` (2.5.6).
- Uses Blizzard FrameXML APIs, combat log events (`COMBAT_LOG_EVENT_UNFILTERED`), unit spellcast events (`UNIT_SPELLCAST_*`), and status-bar textures.
- SavedVariables: `SuperSwingTimerDB` (Schema Migration `v63`), with automatic migration from legacy sources `SwangThangDB` and `HunterTimerDB`.

## Timing and API constraints

- **High-Precision Clock Engine**: Driven by `GetTimePreciseSec()` for sub-millisecond precision, with `GetTime()` as fallback backup.
- Use `GetNetStats()` latency as part of swing, auto shot clip detection, and weave math.
- Use `UnitAttackSpeed()` / `UnitRangedDamage()` for live attack speed state.
- Keep in mind Classic-era API differences when reasoning about events or frame methods.

## UI and texture notes

- Bar and spark textures are configurable through SavedVariables.
- Weave markers use separate textures for the spark and the top/bottom triangles.
- The current weave overlay is anchored to the MH bar, not a standalone frame.

## Important implementation detail

The weave overlay logic now keeps breakpoint markers visible even when `info.isCasting` is false. The more important remaining concern is whether melee swing timestamps stay aligned enough for the MH bar to remain visually stable after a landed swing.

## Known separation of concerns

- `weavingapi.md` is a reference for the WeakAuras-style weave helper and should not be confused with the addon’s own `SuperSwingTimer_Weaving.lua` implementation.
- The addon’s live weave logic depends on the cast window returned by `SuperSwingTimer_Weaving.lua` and the class-mod overlay that draws it on the MH bar.
