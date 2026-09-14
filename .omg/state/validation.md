# Validation Protocols & Command Rules — SuperSwingTimer

## Static Analysis Protocol

- Command: `luacheck .`
- Expected: 0 warnings, 0 errors across all 11 Lua files.

## In-Game WoWUnit Test Protocol

- Slash Command: `/ssttest` inside World of Warcraft.
- Test Groups: 7 registered suites (`SST-Core`, `SST-Auras`, `SST-Combat`, `SST-Hunter`, `SST-SoD`, `SST-ClassMods`, `SST-Weaving` including migration test coverage).

## Policy Guardrails

1. **Zero Git Modification**: Do NOT execute `git` commands under any circumstances.
2. **Version Synchronization**: Version string MUST match `v0.2.3` (migration `v63`) across `SuperSwingTimer.toc`, `CHANGELOG.md`, `README.md`, and memories.
3. **SoD Gating**: All Season of Discovery (1.15.9) logic MUST remain strictly in `SuperSwingTimer_SoD.lua`.
4. **Color Picker Safety**: Never invoke `ColorPickerFrame` without pre-seeding `ColorPickerFrame:SetColorRGB()` and alpha.
