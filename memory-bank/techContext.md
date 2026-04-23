# Tech Context

## Runtime environment

- World of Warcraft Classic/TBC addon Lua.
- Uses Blizzard UI APIs, combat log events, unit spellcast events, and status-bar textures.
- SavedVariables: `SuperSwingTimerDB`, plus legacy migration sources `SwangThangDB` and `HunterTimerDB`.

## Timing and API constraints

- Prefer `GetTimePreciseSec()` when available, fall back to `GetTime()`.
- Use `GetNetStats()` latency as part of swing and weave math.
- Use `UnitAttackSpeed()` / `UnitRangedDamage()` for live speed state.
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
