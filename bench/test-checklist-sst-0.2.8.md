# v0.2.8 — in-game test checklist

**Build under test:** working tree `HEAD 769bba8` + the v0.2.8 edits.
**What this release changes:** the 13 hardening fixes in `CHANGELOG.md`
(including the Hunter ranged-restart gate), plus the TOC-driven version label.
**What it does not change:** Auto Shot cycle math, red zone, Steady Shot grace,
GCD math, DB schema.

## 1. Load

- [ ] Copy the addon folder to the client; `/reload`
- [ ] No Lua errors on load
- [ ] `/sst diag` prints a header

## 2. Version surfaces

- [ ] `SuperSwingTimer.toc` line 8 reads `## Version: v0.2.8`
- [ ] **Blizzard Options** → AddOns → Super Swing Timer: title shows `v0.2.8`
- [ ] **`/sst` standalone panel**: title shows `v0.2.8`
- [ ] **`/sst diag`** header shows `v0.2.8`
- [ ] No surface still shows `v0.2.5` or `v0.2.7`

If one surface differs, note the exact label text and which client.

## 3. Regression smoke (must be unchanged)

- [ ] Bars appear and swing normally; MH/OH/ranged/enemy as your class expects
- [ ] Hunter: Auto Shot cycle visible and resets after each shot
- [ ] Hunter: Steady Shot in the normal window does not clip the next Auto Shot
- [ ] Hunter: no MH-bar flash after a ranged swing
- [ ] Hunter: Raptor Strike at melee range does **not** start or restart the
      ranged bar unless an Auto Shot damage event actually occurs (the v0.2.8
      regression this build fixes)
- [ ] Movement in the pre-Auto-Shot window still blocks the shot as before
- [ ] Class overlays for your class render (power bar, buff/debuff icons)
- [ ] `/sst` opens and toggles still work
- [ ] `/sst reset` still runs without error (completeness is a known parked
      issue; this release does not change it)

## 4. Clients

- [ ] `classic_era` 1.15.9 — normal Era
- [ ] `classic_era` hardcore (same binary; quick load check is enough)
- [ ] `classic_era` SoD (if you have a SoD character)
- [ ] `classic_anniversary` 2.5.6
- [ ] `classic_titan` 3.80.2 (if available)

## 5. If something is wrong, capture

1. Client + interface number
2. Exact label/symptom
3. `/sst diag` compact output
4. For hunter timing: Steady Shot end time, Auto Shot start time, movement
   state, and whether the shot fired in-game.
5. For the Raptor Strike / Auto Shot symptom: Blizzard EventTrace
   (`/eventtrace`) filtered to `UNIT_SPELLCAST_START` — note whether spell
   2973 starts before `UNIT_SPELLCAST_SUCCEEDED` — plus the combat-log line
   showing whether an Auto Shot damage event actually occurred.

Do not change timing code from a report alone; the red-zone model is pinned
and current Steady/Auto Shot behavior is confirmed working.
