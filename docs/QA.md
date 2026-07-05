# SuperSwingTimer — Manual QA Checklist

Run through this checklist before every release.

---

## 1. Addon loads cleanly

- [ ] No Lua errors on login or reload (`/reload`)
- [ ] `luac -p` passes on all 8 Lua files
- [ ] `/sst` opens config panel without errors
- [ ] `/sst help` displays slash command reference

## 2. Swing timers

- [ ] Enter combat → MH/OH/ranged bars appear with correct weapon speeds
- [ ] Swing lands → timer resets (CLEU `SWING_DAMAGE` / `SWING_MISSED`)
- [ ] Off-hand swings with dual-wield (MH + OH bars both active)
- [ ] Ranged auto-shot cycle resets correctly after each shot
- [ ] Enemy bar tracks current target's swing timer
- [ ] `/target` switching updates enemy bar

## 3. Class overlays

- [ ] Each class tested:
  - **Warrior:** Shield Block bar, Slam cast bar, rage bar, Flurry counter, Overpower cue
  - **Hunter:** Range helper, rapid fire bar, buff icons, serpent sting / wing clip / trap / concussion shot debuff bars
  - **Rogue:** Sinister Strike cue, energy tick, combo points, Slice & Dice, Rupture, Expose Armor, Adrenaline Rush, energy countdown
  - **Paladin:** Seal color tint, seal label, Judgement marker, twist flash, Judgement bar, Seal Vengeance bar, buff icons
  - **Shaman:** Weave assist overlays (LB/CL/HW/LHW/CH), Windfury ICD, Lightning Shield tracker, Flame Shock bar, buff icons
  - **Druid:** Energy tick, Mangle/Rip/Rake debuff bars, buff icons
- [ ] Non-current class overlays are hidden (nil-guarded, no errors)

## 4. Config panel

- [ ] `/sst` opens and all tabs/sections render
- [ ] Global Scale slider (0.5–3.0) resizes all bars proportionally
- [ ] Each toggle: enable → bar appears, disable → bar hides
- [ ] Each color swatch: click → color picker opens → color applies to correct bar
- [ ] Sliders change bar dimensions
- [ ] Texture browsers show available textures
- [ ] "Test Bars" animation runs without errors

## 5. Reset and migration

- [ ] `/sst reset` restores all defaults without errors (slash command only)
- [ ] Fresh install (delete `SuperSwingTimerDB` via `/script`) → all defaults present, no nil fields
- [ ] Upgrade from v53 → v54: all new fields populated with defaults

## 6. Dual-client awareness

- [ ] Test on **Classic Era (1.15.x):** CLEU `SWING_DAMAGE` / spell ID payloads
- [ ] Test on **TBC Anniversary (2.5.5):** CLEU localized string payloads
- [ ] `ns.GetSpellInfo(id)` returns correct results on both clients
- [ ] `ns.GetAlignedTime()` returns consistent values on both clients
