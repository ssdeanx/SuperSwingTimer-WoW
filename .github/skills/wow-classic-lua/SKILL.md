---
name: wow-classic-lua
description: This skill should be used when the user asks to "write WoW Classic Lua", "debug a WoW addon", "fix Classic/TBC addon APIs", "build a swing timer", "edit Blizzard UI code", or mentions `CombatLogGetCurrentEventInfo`, `UnitAttackSpeed`, `UnitSpellHaste`, or `UnitChannelInfo`.
version: 0.5.0
---

# WoW Classic Lua

## Purpose

Treat this skill as the operating guide for WoW Classic and TBC addon work.
Use it when building or debugging addon logic, event handling, timers, widgets,
FrameXML-style UI, slash-command config, or Blizzard API compatibility.

This skill is designed to be useful both for the current SuperSwingTimer repo and
for other Classic/TBC addons.

## Source-of-truth order

When API behavior is unclear, prefer sources in this order:

1. `warcraft.wiki.gg` Classic API and widget pages
2. Blizzard / extracted UI source such as `Gethe/wow-ui-source`
3. The current addon's proven local wrappers and patterns
4. Older Wowpedia/Fandom mirrors only as fallback context

Start with these pages first:

- `https://warcraft.wiki.gg/wiki/World_of_Warcraft_API/Classic`
- `https://warcraft.wiki.gg/wiki/API_CreateFrame`
- `https://warcraft.wiki.gg/wiki/Widget_API`
- `https://warcraft.wiki.gg/wiki/Widget_script_handlers`
- `https://warcraft.wiki.gg/wiki/XML_schema`
- `https://warcraft.wiki.gg/wiki/UIOBJECT_Frame`
- `https://warcraft.wiki.gg/wiki/UIOBJECT_StatusBar`

The reference pack under `references/` expands these into task-oriented notes.

## Workflow

1. Inspect workspace instructions and the current addon structure first.
2. Identify the affected subsystem:
	- event/state
	- timer math
	- widgets / UI layering
	- config panel
	- class-specific behavior
	- runtime safety (taint / combat lockdown / protected actions)
3. Load the matching reference file from this skill before coding.
4. Confirm the exact Classic/TBC API signature or event payload before relying on it.
5. Keep white-swing, spell-cast, channel, UI rendering, and config concerns separated.
6. Make the smallest correct change, then validate only the edited files.

## Core operating rules

- Prefer Classic/TBC-safe APIs and patterns over Retail assumptions.
- Reuse frames instead of recreating them repeatedly; created UI objects are
	generally long-lived in-session and are usually hidden/reused rather than
	repeatedly rebuilt.
- Use `OnUpdate` only for work that genuinely needs frame-by-frame motion.
- Use `C_Timer.After` or `C_Timer.NewTimer` only for one-shot or low-frequency UI
	work; do not replace live bar motion with timer callbacks.
- Treat latency as a predictive overlay input, not as a reason to rewrite the
	authoritative underlying swing timestamps.
- Keep draw-layer and sublayer decisions explicit when multiple textures or
	helper regions overlap.
- If a spellcast API is ambiguous, verify whether the spell is a cast or a
	channel before choosing `UnitCastingInfo()` or `UnitChannelInfo()`.
- If a config or UI feature is visible to the user, it usually belongs in
	SavedVariables and the config panel instead of a hidden constant.
- Treat secure/protected action paths as first-class constraints: avoid changing
	protected attributes in combat and avoid taint-prone patterns around secure
	frames.

## API priorities

- Use `CombatLogGetCurrentEventInfo` for combat-log driven swing events.
- Use `UnitAttackSpeed` for melee swing speed.
- Use `UnitRangedDamage` for ranged swing speed.
- Use `GetMeleeHaste` for melee-haste adjustments.
- Use `UnitSpellHaste` for cast-time breakpoint math.
- Use `UnitCastingInfo` and `UnitChannelInfo` to track active cast and channel windows.
- Use `GetSpellCooldown` for cooldown-based timing only with awareness that the
	values are not guaranteed to be updated immediately on the same
	`UNIT_SPELLCAST_SUCCEEDED` frame.
- Use `GetNetStats` for latency sampling; `latencyWorld` is usually the gameplay
	relevant value.
- Use `GetTimePreciseSec` or `GetTime` for frame timing, then apply cached
  latency only where the timing model requires it.

## Timer rules

- Keep main-hand, off-hand, and ranged timers independent.
- Treat parry haste as a swing-state adjustment, not a UI-only effect.
- Refresh latency frequently while timers are active.
- Prefer per-frame `OnUpdate` for live timer motion; reserve `C_Timer` for delayed one-shot work.
- Preserve white-hit accuracy at the end of each swing; avoid broad resets that restart the wrong hand.
- Keep Volley and other hunter channels on the ranged side; do not let them leak into shaman weave timing.
- Keep authoritative state transitions event-driven where possible; UI-only
	fallback rendering should not silently mutate core combat state.

## UI and widget rules

- `CreateFrame(frameType[, name, parent, template, id])` is the base entry
  point for most Classic UI work.
- Common frame types worth reaching for:
  - `Frame`
  - `Button`
  - `CheckButton`
  - `EditBox`
  - `ScrollFrame`
  - `Slider`
  - `StatusBar`
  - `GameTooltip`
- Use `Frame:CreateTexture()` and `Frame:CreateFontString()` for most custom
  visuals and labels.
- Keep texture layering explicit with `SetDrawLayer(layer, subLayer)`.
- Remember the layer order inside a frame: `BACKGROUND`, `BORDER`, `ARTWORK`,
  `OVERLAY`, `HIGHLIGHT`.
- Use `OnEvent` for event-driven state changes and a throttled `OnUpdate` only
  when the UI must animate live.
- For movable bars or panels, use `SetMovable(true)`, `EnableMouse(true)`,
  `RegisterForDrag("LeftButton")`, `StartMoving()`, and
  `StopMovingOrSizing()`.
- Prefer `GameTooltipTemplate` when creating tooltips.
- For dropdown-style Classic config UIs, use the old `UIDropDownMenu*` helpers,
  not Retail-only settings assumptions.

## Debugging checklist

- If a widget exists but is invisible, check:
  - parent visibility
  - frame strata
  - draw layer / sublayer
  - alpha
  - anchor points
  - whether a later `SetTexture()` or `SetStatusBarTexture()` reapplied styling
- If `OnUpdate` stops firing, confirm the frame and its parents are shown.
- If an event handler seems wrong, print or inspect the exact payload instead of
	assuming Retail-era argument order.
- Use `/fstack` to inspect frames and mouse focus in game.
- If a cast or channel helper seems wrong, compare `UnitCastingInfo()` and
	`UnitChannelInfo()` behavior on the exact spell.
- If a dropdown or template behaves oddly, inspect Blizzard's own FrameXML
	source before inventing a custom pattern.
- If secure action UI breaks only in combat, audit for combat-lockdown/taint
	issues before changing timer math.

## Addon structure rules

- Keep timer state in the state module, visuals in the UI module, configuration in the config module, and class-specific behavior in the class-mod module.
- Keep config values user-adjustable when introducing new visible behavior.
- Avoid hidden hard-coding when a setting belongs in `/sst`.
- Use `_` placeholders or helper functions to avoid unused locals, especially when unpacking CLEU payloads.

## Validation

- Run targeted diagnostics on the edited files after code changes.
- Verify event-index assumptions and timer resets against the Classic API before relying on them.
- Prefer narrow fixes over broad refactors unless the user explicitly asks for a redesign.
- For UI behavior changes, include an in-game check list:
	- `/reload`
	- open config (`/sst`)
	- enter combat and test normal visibility
	- leave combat and confirm idle reset behavior
	- move/lock bars and verify persisted anchors
	- test class-specific helper behavior on the affected class only

## Reference files in this skill

- `references/api-notes.md` - quick-start checklist and index
- `references/api-core.md` - combat, cast, cooldown, latency, and timing APIs
- `references/ui-frames-and-widgets.md` - `CreateFrame`, widgets, handlers, and examples
- `references/framexml-and-xml.md` - XML schema, FrameXML patterns, and source references
- `references/research-links.md` - curated current links for Classic/TBC addon work
- `references/superswingtimer.md` - project-specific architecture and proven patterns
- `references/runtime-safety.md` - taint/combat-lockdown/SavedVariables/performance guardrails
- `references/compatibility-matrix.md` - practical Classic/TBC API variance and fallback strategy
- `references/event-payload-cheatsheet.md` - high-risk event payload quick tables
- `references/verification-playbooks.md` - subsystem test checklists for in-game validation
- `references/operator-cheatsheet.md` - fastest incident routing for live coding/debug sessions
- `references/class-quickmaps.md` - class-specific ownership map for rapid file targeting
- `references/incident-first-5-minutes.md` - deterministic triage workflow for new bug reports

## Current research snapshot

These references were refreshed against `warcraft.wiki.gg` on 2026-05-30.
Relevant pages reviewed included the Classic API index, `CreateFrame`, Frame,
StatusBar, Texture, FontString, ScrollFrame, Slider, widget script handlers,
combat-log APIs, cast/channel APIs, `GetSpellCooldown`, `GetNetStats`, and XML
schema pages.
