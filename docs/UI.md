# Super Swing Timer UI Notes

This document captures the UI direction for `/sst`.

## Panel direction

- Use a scrollable custom panel instead of a flat, fixed-height stack.
- Keep the footer actions fixed outside the scrolling area so Reset and Close stay visible.
- Group options into visible, collapsible sections with stable row groups: Visibility, Appearance, Behavior, Colors, and Shaman Weave Assist.

## Layout patterns to keep

- Use compact row helpers for toggles, sliders with editable numeric fields, text inputs, and dropdown selector rows.
- Prefer data-driven refresh helpers so live preview updates stay in one place.
- Use a small subtitle under the title to explain what the panel controls.
- Avoid one dense vertical wall of controls; sectioning is the readability win.
- Keep the first interactive row in each collapsible section clearly below the section header so slider or row clicks never also hit the collapse toggle.
- Keep the top section as a two-column quick-control area with explicit column headers: left `Visibility`, right `Key Colors`, and use compact non-overlapping row spacing so the Rogue/Hunter quick rows do not crash into each other.
- Keep the quick color swatches visually strong: prefer flat high-contrast preview tiles over washed-out stock button art so the chosen bar colors are readable in the config panel.
- Keep the default live profile slimmer: 15px for the main shared bars, 8px for the derived OH bar, a slim 3-4px Rogue Slice and Dice helper above MH, and a default spark height that matches the slimmer main bars while still clamping to each host frame.

## Addon-specific UI goals

- Add dropdown layer selectors for each visible texture region:
  - bar fill layer
  - spark layer
  - weave marker layer
  - any new overlay layers later
- Keep the new enemy bar on the same shared bar/spark styling path as MH/OH so it picks up the existing texture, border, background, and spark controls, while keeping its own red default fill and separate visibility toggle.
- Keep the Rogue Sinister cue MH-only: a small latency-adjusted red end window should sit on the right end of the MH bar so Rogues can queue Sinister Strike into the swing landing without adding latency to the shared base timer clock, but keep that cue below the shared spark layer so the spark still reads cleanly through the red slice; when the MH bar is visible but the live swing timer has not started yet, fall back to the current MH weapon speed instead of hiding the cue entirely.
- Keep the Rogue helper set lean: a single 4px-wide vertical energy-tick bar to the left of MH is enough for the current test pass, and it should stay separate from the swing timers while matching the MH bar height.
- Keep the Rogue Slice and Dice helper directly above MH: a slim 3-4px duration bar that uses the shared bar texture/background/border styling, tracks the active buff from a Classic-safe `UnitBuff` / `UnitAura` helpful-aura read, hides whenever the MH bar is hidden or the buff is down, and tolerates slightly late aura events by rechecking on a short throttle.
- Keep visual cues on a dedicated overlay frame above the bar fill so breakpoint markers never depend on hover-sensitive HIGHLIGHT ordering.
- Keep the hunter Auto Shot / Multi-Shot cast bar separate from the ranged swing bar, but lock the Auto Shot hidden-window display to the same end-of-cycle red/green ranged window so movement pinning does not make the cast bar bounce; BC Classic instant Multi-Shot shots should still seed a short stored helper window when `UnitCastingInfo()` does not expose a live cast, transient `STOP_AUTOREPEAT_SPELL` events should not hard-reset a still-valid cycle, and `SPELL_UPDATE_COOLDOWN` should only seed a new ranged cycle when Blizzard's current auto-repeat spell state confirms Auto Shot is actually active.
- Keep the shared swing clock on a `GetTime()`-aligned `GetTimePreciseSec()` / `GetTime()` path and apply cached latency only to predictive windows such as Auto Shot safe-stop timing, hunter hidden-window sizing, and weave clip math.
- Keep spark tint independent from `Use Class Colors` and next-melee queue fill tints so the spark can stay white or use a manual color without losing contrast, and keep the main spark on a color-preserving blend mode so its visible tint does not warm from the bar fill underneath.
- Keep the main spark aligned to the actual rendered fill edge so width changes do not make it visibly trail behind the bar; for the thin 3px stock spark, lightly pixel-snap and nudge the anchor so it reads on the leading edge more cleanly.
- Toggling `Use Class Colors` on should not overwrite the stored manual MH/OH/ranged colors; toggling it back off should restore those saved manual colors.
- Make shaman weave overlays respect both the weave toggle and Minimal Mode so the class mod cannot re-show them after the visibility layer has hidden them.
- Add weave-assist presentation options:
  - show / hide weave overlay
  - tiny upper / lower spell-icon marker pair that follows the spell-haste-adjusted safe swing point
  - marker size, gap, alpha, and layer controls, with compact spark defaults that stay bar-height aligned instead of becoming a full-height glow
  - color selection by spell family
  - per-family enable / disable toggles for Lightning Bolt, Chain Lightning, Healing Wave, Lesser Healing Wave, and Chain Heal
- Texture selection for the MH/OH and ranged bars should use a scrolling full-preview list that stretches each bar texture behind its label, keeps a fixed-height visible window with scroll support, and stays focused on bar-style textures from Blizzard fallbacks, WeakAuras bars, and any installed LibSharedMedia statusbar packs. The spark row and the shaman weave spark row should stay on the dedicated thumbnail browser seeded with the Normal `Square_FullWhite` preset, while the collapsed bar rows show the current texture as a miniature preview bar instead of a small icon.
- The enemy bar should be toggleable from `/sst`, default to red, store its own anchor, expose its own color swatch, and follow the same preview / lock-drag flow as the other primary bars.
- Auto Shot safe/unsafe feedback should expose its own color swatches in `/sst` so players can tune both the ranged cast-window fill and the overlay tint without changing the base ranged-bar color.
- Rogue Sinister cue color should expose its own swatch in `/sst` so the helper can stay visible without forcing the main MH bar itself to turn red.
- Make the row controls obvious: toggles use the right-side checkbox, selector settings use the right-side dropdown, and sliders expose a right-side editable numeric field.
- Include a `Lock / Unlock Bars` control plus a temporary `Test Bars` action so players can preview and reposition the bars without fighting the normal combat visibility rules.
- Make the unlocked bars easy to grab by giving them a slightly larger drag hit area and using actual drag handlers (`OnDragStart` / `OnDragStop`) on the anchor bars, and expose a bar border size control so the frame outline can be tuned instead of being fixed at a single pixel thickness.
- Reset Defaults should restore the saved bar positions as well as the cosmetic settings, and the preview flow should force created bars visible after the normal visibility pass so Test Bars remains dependable.
- Let every main bar color swatch open the color picker with opacity support so the class-color palette can still be tuned with alpha.
- Add hover tooltips to explain what each row changes so the panel remains understandable without memorizing the labels.
- Keep the panel responsive and straightforward to scan.

## Texture browser constraint

- WoW does not expose a full API that enumerates every texture file on disk.
- The addon should therefore provide:
  - a preset texture browser for common UI assets gathered from Blizzard fallbacks, LibSharedMedia registrations, and curated addon texture packs
  - a manual texture path entry for any custom or packaged texture

## Blizzard references checked

- `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_Settings.lua`
- `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_SettingsPanel.lua`
- `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_CategoryList.lua`
- `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_ImplementationReadme.lua`
- Warcraft Wiki `StatusBar:SetOrientation()` and `ScrollFrame` / `UIPanelScrollFrameTemplate` notes: keep the main `/sst` panel on the current scroll-frame path, and treat `HybridScrollFrame` as a future-only optimization for very long virtualized picker lists rather than a risky late release rewrite.

## Notes for the addon

- Keep the panel Classic/TBC-safe.
- Use the current custom UI path first; do not depend on Blizzard's new settings UI for compatibility.
- Preserve live preview behavior when changing colors, textures, or visibility, but keep the normal gameplay bars combat-driven and reset hidden/idle bars back to empty so combat entry does not show stale full fills from the previous cycle.
- Avoid letting UI-only hunter fallback rendering write new authoritative cast state unless there is a real live cast to persist.
- Reuse named bar frames (especially OH) across equipment swaps instead of niling them out and recreating the same global frame name later.
