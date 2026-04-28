# WeakAuras Expert Guide

## What is WeakAuras?

WeakAuras is the most powerful in-game display engine for World of Warcraft, especially in Classic/TBC. It lets you create visual alerts, timers, icons, bars, text, and group layouts based on nearly any game event or condition.

WeakAuras works by combining:

- a **display** (icon, bar, text, texture, model, group)
- one or more **triggers** that decide when the display should show
- optional **actions** that run code or play effects on show/hide
- optional **load** conditions that limit when the aura is active

## Why use WeakAuras for TBC Classic?

WeakAuras is essential for TBC Classic because it can:

- track raid debuffs and crowd control windows
- show spell cooldowns, buff uptimes, and resource thresholds
- provide custom timing for swing/reset/ability windows
- react to combat log events, unit aura changes, and custom events
- create tailored visual helpers for hunter auto shot, paladin seal-twisting, shaman weaving, and more

## Expert-Level WeakAuras Concepts

These are the concepts you must master for higher-level WeakAuras work:

- **Display type choice**: choose the correct display type for the job instead of forcing everything into icons.
- **Trigger type selection**: prefer event-based triggers over Status/Every Frame checks.
- **Custom triggers**: use them for anything that built-in WeakAuras triggers cannot express.
- **Custom actions**: use On Init, On Show, and On Hide to manage state, timers, and side effects.
- **aura_env persistence**: store state between calls and share data across trigger/actions.
- **WeakAuras.ScanEvents**: raise your own internal events when you need delayed or aggregated updates.
- **Performance first**: use load conditions, avoid high-frequency global scans, and minimize custom code inside hot paths.

## Folder Layout for these docs

- `Introduction.md` — why WeakAuras, core concepts, and expert mindset.
- `Displays.md` — display types, properties, and visual patterns.
- `Triggers.md` — standard triggers, custom trigger structure, events, untrigger, duration info.
- `Actions.md` — actions, custom code, aura_env, custom events, timers, and animation hooks.
- `API-Helpers.md` — WeakAuras helper functions, custom event patterns, and safe API usage.
- `Expert-Patterns.md` — real advanced examples and performance best practices.
