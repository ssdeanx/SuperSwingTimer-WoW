# Active Context

## Active Context Update (2026-04-23 - Blizzard options, class colors, and preview polish)

- Registered the addon in Blizzard's Interface Options / AddOns flow and added TOC icon metadata for the addon list.
- Switched the primary slash aliases to `/sst`, `/super`, and `/superswingtimer`, removing the old `/swangthang` alias.
- Default MH / OH / ranged bar colors now follow the player's class color until custom swatches are chosen; a `Use Class Colors` toggle now makes that mode explicit.
- Added an `Indicator Glow Mode` toggle so sparks and weave markers can switch between bright additive glow and a more opaque blend.
- Reworked the texture dropdown into a preview-based picker, widened and relabeled the `/sst` panel, and tightened the row spacing/section labels.
- Targeted diagnostics on the touched runtime files are clean after the UI pass.

## Active Context Update (2026-04-23 - weave family controls and UI polish)

- Added color-coded, individually disable-able weave-family toggles for Lightning Bolt, Chain Lightning, Healing Wave, Lesser Healing Wave, and Chain Heal.
- Made the weave marker pair smaller and clearer by retitling the controls as upper/lower marker settings.
- Widened the `/sst` panel and added a bottom legend/description block for the weave families.
- Targeted diagnostics on the edited runtime files are clean after the weave/UI pass.

## Current focus

1. UI validation in-game for the Blizzard options panel, texture preview dropdown, and class-color toggle behavior.
2. Any follow-up polish for the weave marker spacing, icon choice, or tooltip copy after client testing.
3. Memory-bank persistence and production-ready planning notes.

## What we know right now

- The live feature plan in `memory-bank/weaveapi-swingtimer-ui` now covers the runtime addon, config/media UI, release docs, metadata, and diagnostics surface.
- The weave breakpoint uses the current cast window (cast remaining or cast time plus latency) while still being drawn on the MH bar canvas.
- The main-hand swing timer now refreshes latency in the active update loop, so end-of-swing timing stays closer to live network state.
- Parry haste now scales from the player's current melee haste (`GetMeleeHaste()` / `GetHaste()` fallback) instead of a flat reduction.
- The config panel now has Blizzard AddOns registration, class-color defaults for the main bars, and an indicator glow/opaque mode for sparks and weave markers.
- Texture selection now uses preview thumbnails plus labels instead of a plain text-only picker.
- A new WoW Classic Lua skill now exists at `.github/skills/wow-classic-lua` for loading at the start of future sessions.
- White-hit handling still stays split by hand, and ranged reset spells keep their own path.
- The overlay keeps the breakpoint triangles visible while the MH timer is active; the spark remains cast-only.
- The weave spark tracks cast progress instead of swing progress.
- Texture selection in the config panel uses a dropdown list of SharedMedia/Blizzard entries with category labels instead of a browser window.
- Targeted diagnostics on the edited runtime files are clean.

## Likely bug area

- `SuperSwingTimer_State.lua` for white-hit timing, parry haste, and clean CLEU handling.
- `SetupEnhShaman()` / `UpdateWeaveVisuals()` in `SuperSwingTimer_ClassMods.lua` for breakpoint placement.

## Working assumptions

- The cast window is the breakpoint source; the MH bar is just the visual surface the breakpoint is drawn onto.
- The triangle markers represent the safe cast threshold based on cast remaining / cast time and latency.
- The spark remains tied to cast progress while the breakpoint markers stay visible whenever weave assist is enabled and the MH timer is active.

## Next steps

- Keep the state engine lean by removing any leftover unused CLEU unpacking when it appears.
- Preserve the SharedMedia dropdown, cast-spark behavior, and ranged-channel handling as the current working state.
