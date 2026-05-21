# Super Swing Timer API Notes

This document stores the API facts we should rely on while building the `/sst` UI.

## Classic/TBC API points that matter here

- Frame creation and scripts: `CreateFrame`, `SetScript`, `OnUpdate`, `OnShow`, `OnHide`.
- Bars and overlays: `StatusBar`, `SetStatusBarTexture`, `SetStatusBarColor`, `SetDrawLayer`, `SetAlpha`.
- UI controls: `ScrollFrame`, `EditBox`, `CheckButton`, `Slider`, `UIDropDownMenu` helpers.

## Weaving logic inputs

- `GetNetStats()` for latency estimation.
- `UnitSpellHaste()` when available for cast-time scaling.
- `UnitCastingInfo()` for active cast timing.
- `GetSpellInfo()` for resolving ranks and cast times.

## Hunter ranged timing inputs

- `GetSpellCooldown(75)` / `GetSpellCooldown("Auto Shot")` for the active Auto Shot cooldown when the client exposes it.
- `UnitRangedDamage()` for ranged weapon speed; the first return value is the ranged speed, and it reflects ranged haste rather than melee haste.
- `START_AUTOREPEAT_SPELL` and `STOP_AUTOREPEAT_SPELL` are the auto-shot mode toggles and carry no payload on the current Classic/TBC API.
- `C_Spell.IsAutoRepeatSpell(75)` / `C_Spell.IsAutoRepeatSpell("Auto Shot")` is the current Blizzard spell-API path for confirming whether Auto Shot is still actively auto-repeating, which is safer than trusting transient stop events by themselves.
- `IsMounted()` is available on Classic/TBC clients and should override any lingering Hunter auto-repeat state while the player is mounted.
- `SPELL_UPDATE_COOLDOWN` is a reactive start/resync signal for Auto Shot because it fires when the internal Auto Shot cooldown begins, not when that cooldown finishes; it is useful as a secondary ranged sync hint, but it is not the authoritative `shot landed / can move again` marker.
- `UnitCastingInfo()` can still expose hunter casts by localized spell name when a stable spell ID is missing, so Auto Shot / Multi-Shot detection should keep the name fallback path alive.
- Hidden hunter cast-bar helpers should anchor to the same end-of-cycle stop-to-fire window as the ranged red/green zone without rewriting the authoritative ranged swing anchor.
- Authoritative MH/OH/ranged timers should stay on the addon's `GetTime()`-aligned precise clock (`GetTimePreciseSec()` + one-time offset, with `GetTime()` fallback); cached latency belongs in safe-window math (hunter stop-to-fire, weave clip math), not in the stored swing timestamps themselves.

## Enemy target timing inputs

- `PLAYER_TARGET_CHANGED` is the correct target-swap signal for resetting or seeding current-target enemy state.
- `UnitGUID("target")` identifies the tracked hostile target for the enemy bar.
- `UnitAttackSpeed("target")` is verified on Warcraft Wiki for `"target"` and should be used as the current target melee-speed source.
- Enemy swing starts should come from `COMBAT_LOG_EVENT_UNFILTERED` via the tracked target GUID on `SWING_DAMAGE` / `SWING_MISSED`.
- If the addon only exposes one enemy bar, ignore off-hand flags on enemy swing events so the bar stays readable and does not restart twice per dual-wield cycle.

## Classic/TBC compatibility helpers

- `ns.GetSpellInfo()` should be preferred over raw `GetSpellInfo()` in addon code so localized spell-name lookup keeps working across Classic/TBC Anniversary clients that expose `C_Spell.GetSpellInfo()`.

## StatusBar / texture reminders

- `StatusBar:SetStatusBarTexture(asset)` sets the fill texture.
- Draw-layer control should be done via `GetStatusBarTexture():SetDrawLayer()`.
- `StatusBar:SetStatusBarColor()` controls the fill tint.
- `StatusBar:SetValue()` and `StatusBar:SetMinMaxValues()` drive the actual timer fill.
- Spark textures should keep their own tint source; queued-attack fill colors and class-colored bar fills should not silently recolor the spark.
- `TextureBase:SetRotation()` can help orient a marker if a triangle asset is used.

## Blizzard source files worth checking

- `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_Settings.lua`
- `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_SettingsPanel.lua`
- `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_CategoryList.lua`
- `Interface/AddOns/Blizzard_SharedXML/Mainline/UIDropDownMenu.lua`
- `Interface/AddOns/Blizzard_FrameXMLBase/GradualAnimatedStatusBar.lua`

## Compatibility reminder

- Keep the addon compatible with Classic / TBC-era behavior and avoid assuming Retail-only systems.
