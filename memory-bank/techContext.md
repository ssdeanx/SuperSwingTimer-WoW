# Tech Context

## Runtime environment

- World of Warcraft Classic/TBC addon Lua.
- **Target runtime is BC Classic Anniversary Edition (2026), patch line 2.5.5**, not the 2021 BC Classic launch branch.
- Uses Blizzard UI APIs, combat log events, unit spellcast events, and status-bar textures.
- SavedVariables: `SuperSwingTimerDB`, plus legacy migration sources `SwangThangDB` and `HunterTimerDB`.

## Anniversary branch notes (future-context baseline)

- Verified source context: warcraft.wiki.gg page for BC Classic Anniversary confirms 2026 release timeline and current 2.5.5 line.
- For addon engineering, no high-confidence evidence was found that Anniversary 2.5.5 invalidates this addon's core API families (`UnitAura` / `UnitBuff` / `UnitDebuff`, `UNIT_SPELLCAST_*`, CLEU timer paths) compared to late BC Classic behavior.
- Differences observed in public references are mostly gameplay/system-layer (e.g., account-wide attunement flow, Edit Mode availability), not direct breakpoints for swing-timer API contracts.
- Continue using defensive parsing in aura/cast helpers because Classic-family payload optionality is the bigger risk than branch identity.

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
