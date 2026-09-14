# Suggested Commands

## Code Quality & Linting

- `luacheck .`: Run linter across all 11 Lua files using root `.luacheckrc`. Zero warnings/errors expected.
- `luacheck <file>`: Run linter on a specific file (e.g. `luacheck SuperSwingTimer_ClassMods.lua`).

## Code Exploration

- `codegraph explore "<query>"`: Query symbol definitions, call hierarchies, and cross-file usages via CodeGraph.

## In-Game WoW Commands

- `/sst`: Open addon options and configuration panel.
- `/sst test`: Toggle temporary preview bars for visual alignment and positioning.
- `/sst lock` / `/sst unlock`: Toggle bar frame lock for dragging.
- `/sst reset`: Reset bar positions and restore configuration defaults.
- `/ssttest`: Execute in-game WoWUnit test suite across all 7 test groups.

## Serena Memory Verification

- `serena memories check`: Run from project root to check for stale memories and broken references.