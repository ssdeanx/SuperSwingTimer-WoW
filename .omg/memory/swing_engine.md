# Melee Swing Engine & Combat Mechanics

## 1. CLEU Event Handling (`SuperSwingTimer_State.lua`)

- **Primary Listener**: `COMBAT_LOG_EVENT_UNFILTERED` parsed in `ns.HandleCLEU()`.
- **Subevents Tracked**:
  - `SWING_DAMAGE`: Slot determined by `cleuArg21` (true = `oh`, false/nil = `mh`).
  - `SWING_MISSED`: Slot determined by `cleuArg13` (true = `oh`, false/nil = `mh`). Miss type in `cleuArg12`.
  - `SPELL_EXTRA_ATTACKS`: `cleuArg15` specifies count. Increments `ns.extraAttackPending`. Extra attacks from Windfury, Sword Specialization, Hand of Justice, or Thrash Blade do **not** restart the swing cycle.
  - `SPELL_DAMAGE` / `SPELL_MISSED`: Checks `IsQueuedMeleeHitForPlayerClass(spellId)` (Heroic Strike, Cleave, Maul, Raptor Strike) to start the MH swing on the queued hit.
  - `SWING_MISSED` (Target = Player): Checks `cleuArg12 == "PARRY"` to apply player Parry Haste.

## 2. Parry Haste Calculation (`ns.ApplyParryHaste`)

Classic World of Warcraft parry haste model:

- When the player parries an incoming attack, their next main-hand swing is reduced by 40% of weapon speed:
  $$\text{reduction} = 0.40 \times \text{duration}$$
- Hard floor limit: A parry cannot reduce the remaining swing time below 20% of the weapon speed:
  $$\text{floor} = 0.20 \times \text{duration}$$
- If remaining time is already $\le 20\%$, no reduction occurs.
- Timer shift: `t.lastSwing = now + newRemaining - t.duration`.

## 3. Mid-Swing Haste Changes (`ns.RescaleTimer`)

- When a haste proc occurs mid-swing (e.g., Flurry, Slice and Dice, Bloodlust, haste potion):
  - The remaining swing duration scales proportionally with the speed ratio:
    $$\text{ratio} = \frac{\text{newSpeed}}{\text{oldDuration}}, \quad \text{newRemaining} = \text{remaining} \times \text{ratio}$$
  - `t.duration = newSpeed`
  - `t.lastSwing = now + newRemaining - newSpeed`
- This prevents the bar from jarringly jumping or resetting to 0% progress when haste changes.

## 4. Queued Melee Specials & Slam

- **On-Next-Hit Abilities**: Heroic Strike, Cleave, Maul, and Raptor Strike queue for the next melee swing.
  - While queued, the main-hand bar tints to the queued spell color.
  - When the swing lands (via `SPELL_DAMAGE`), the hit is recognized as the swing completion and restarts the MH cycle.
- **Warrior Slam**:
  - Hard-cast spell (1.5s base) that resets or pauses the melee swing.
  - SuperSwingTimer pauses the swing progress and extends the timer duration by the Slam cast time.

## 5. Overpower Dodge Detection (Warrior)

- When `SWING_MISSED` or `SPELL_MISSED` occurs with `missType == "DODGE"`:
  - Sets `ns.warriorOverpowerProcUntil = eventTime + 5.0` (5.0s active window).
  - Triggers the Overpower ready visual and audio cue.
