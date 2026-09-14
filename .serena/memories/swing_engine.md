# Melee Swing Engine & Combat Mechanics

## CLEU Event Routing (`SuperSwingTimer_State.lua`)
- Primary event: `COMBAT_LOG_EVENT_UNFILTERED` handled in `ns.HandleCLEU()`.
- `SWING_DAMAGE`: Slot determined by `cleuArg21` (true = `oh`, false/nil = `mh`).
- `SWING_MISSED`: Slot in `cleuArg13`. Miss type in `cleuArg12`.
- `SPELL_EXTRA_ATTACKS`: `cleuArg15` specifies count; increments `ns.extraAttackPending`. Extra attacks (Windfury, HoJ, Sword Spec, Thrash Blade) do not reset swing timer.
- `SPELL_DAMAGE` / `SPELL_MISSED`: Handled via `IsQueuedMeleeHitForPlayerClass` (Heroic Strike, Cleave, Maul, Raptor Strike) to start MH swing on queued landing.
- Player parries: `cleuArg12 == "PARRY"` triggers `ns.ApplyParryHaste`.

## Parry Haste Math (`ns.ApplyParryHaste`)
- When player parries an incoming attack: swing reduction = $0.40 \times \text{duration}$.
- Hard floor: Remaining swing time cannot drop below 20% of weapon speed ($0.20 \times \text{duration}$).
- If remaining time $\le 20\%$, reduction is 0.

## Mid-Swing Haste Rescaling (`ns.RescaleTimer`)
- Procs mid-swing (Flurry, Slice and Dice, Bloodlust, haste pots) rescale remaining time proportionally:
  $$\text{newRemaining} = \text{remaining} \times (\text{newSpeed} / \text{oldDuration})$$
- Prevents bar jumping or resetting to 0% on attack speed change.

## Queued Specials & Slam
- Queued abilities tint the MH bar while pending and restart swing cycle upon damage landing.
- Warrior Slam (1.5s base) pauses swing progress and extends duration by cast time.

## High-Precision Clock Domain
- Engine runs on `GetTimePreciseSec()` for sub-millisecond precision.
- `GetTime()` is used strictly as an automatic fallback when unavailable.

## Related Memories
- Main architecture map: `mem:core`
- Shaman weaving: `mem:weaving`
- Class modules: `mem:class_systems`
