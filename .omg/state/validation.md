# Validation Protocols & Command Rules — SuperSwingTimer

## Static Analysis Protocol
- Command: `luacheck .`
- Expected: 0 warnings, 0 errors across all 12 Lua files.

## CLI Unit Test Protocol
- Command: `lua test_migrations.lua`
- Expected: 37/37 passed, 0 failed.

## In-Game WoWUnit Test Protocol
- Slash Command: `/ssttest` inside World of Warcraft.
- Test Groups: 6 registered suites (`SST-Core`, `SST-Auras`, `SST-Combat`, `SST-Hunter`, `SST-SoD`, `SST-ClassMods`).

## Policy Guardrails
1. **Zero Git Modification**: Do NOT execute `git` commands under any circumstances.
2. **Version Synchronization**: Version string MUST match `v0.2.1` across `SuperSwingTimer.toc`, `CHANGELOG.md`, `README.md`, and `docs/`.
3. **SoD Gating**: All Season of Discovery (1.15.9) logic MUST remain strictly in `SuperSwingTimer_SoD.lua`.
