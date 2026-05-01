# Rules for Copilot

## Core Principle: No Guessing

- **MANDATORY**: Always search for and verify the actual Blizzard API behavior before editing or implementing changes.
- Use `warcraft.wiki.gg` (TBC/Classic sections) and the `Gethe/wow-ui-source` repository (Blizzard_APIDocumentation) as the source of truth.
- Do not assume modern (Retail) API signatures work in TBC Classic Anniversary (2.5.5 or 1.15.8).

## Load order

- Always read `memory-bank/projectBrief.md`, `memory-bank/activeContext.md`, and this file before starting a new task.
- Load the smallest set of additional memory-bank files needed for the current task.

## Repository rules

- Treat `SuperSwingTimer.lua` as bootstrap only; keep feature logic in the dedicated subsystem files.
- Keep swing-timer math event-driven and preserve OnUpdate rendering for live bar motion.
- Keep shaman weave logic isolated from the general swing-state engine.
- Update SavedVariables defaults, migration, runtime apply functions, config panel, and docs together when settings change.

## Classic/TBC guidance

- Verify Classic-era API behavior before assuming modern Blizzard functionality.
- Prefer timing-safe patterns that account for latency and precise time when available.
- Always handle API fallbacks (e.g., `C_Spell.GetSpellInfo` vs `GetSpellInfo`) to support TBC Anniversary 1.15+ clients.
- Avoid introducing Retail-only assumptions into the addon.

## Memory-bank guidance

- Save important decisions, blockers, and current bug theories in the memory-bank immediately.
- Prefer concise, durable facts over raw investigation chatter.
- Keep the active context updated after meaningful progress so a later session can resume cleanly.

## Current critical insight

- The shaman weave breakpoint visuals should be driven by the current cast window and latency-aware timing, then drawn on the MH bar canvas.
- Breakpoint markers likely need to stay visible even when the player is not actively casting; only the live spark should remain cast-progress dependent.
- The swing engine should refresh latency while the active update loop is running, not only on a slow ticker, so white-hit end timing stays tight.
- Use `GetMeleeHaste()` when adjusting parry haste so the remaining swing shift reflects live melee haste instead of a flat static reduction.
- Keep hunter channel behavior on the ranged side; it should not leak into shaman weave timing or the MH swing-reset path.
- Prefer `_` placeholders or `select()` over binding unused CLEU return values in the state engine so the timing file stays lean and easy to audit.
