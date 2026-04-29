# WeakAuras Documentation

This folder contains expert-level WeakAuras documentation for TBC Classic.

## Available Guides

- `Introduction.md` — overview, core concepts, and expert mindset.
- `Displays.md` — display types, properties, and visual patterns.
- `Triggers.md` — built-in triggers, custom trigger structure, events, duration info, and untrigger logic.
- `Actions.md` — actions, custom event patterns, aura_env, and advanced action design.
- `API-Helpers.md` — WeakAuras helper functions, custom event patterns, and safe API usage.
- `Expert-Patterns.md` — advanced custom trigger examples, queueing, combat log parsing, and performance best practices.

## How to use these docs

Read the files in order for a progressive understanding:

1. `Introduction.md`
2. `Displays.md`
3. `Triggers.md`
4. `Actions.md`
5. `API-Helpers.md`
6. `Expert-Patterns.md`

Each file contains code examples suitable for TBC Classic WeakAuras custom code.

If you are wiring a swing-timer feed into a WeakAura, start with `Expert-Patterns.md` for the bridge example, then
use `Triggers.md` and `Actions.md` to split the trigger/state flow from any cleanup or relay logic.
