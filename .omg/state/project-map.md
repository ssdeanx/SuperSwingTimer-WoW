# Project Map — SuperSwingTimer

## Modules & Responsibilities

| File | Responsibilities | Key Symbols / Exports |
| --- | --- | --- |
| `SuperSwingTimer.toc` | Manifest & Load Order | Interface: `11509, 20506`, Version: `v0.2.1` |
| `Media/SuperSwingTimer_Media.lua` | Texture Asset Registration | Local statusbar textures (`MerfinMain`, `MerfinMainDark`, `MerfinFlatt`) |
| `SuperSwingTimer_Constants.lua` | Clock Engine & Spell Tables | `ns.GetAlignedTime()`, `ns.GetSpellInfo()`, `ns.UnitAura()`, `RESET_SWING_SPELLS`, `NO_RESET_SWING_SPELLS`, `PAUSE_SWING_SPELLS` |
| `SuperSwingTimer_State.lua` | CLEU Event & Swing Tracking | `ns.HandleCLEU()`, `ns.StartSwing()`, `ns.timers` (`mh`, `oh`, `ranged`, `enemy`), `ns.RefreshLatencyCache()` |
| `SuperSwingTimer_Weaving.lua` | Shaman Spell-Weaving Engine | `ns.RefreshWeavingState()`, `ns.RebuildWeaveSpellCatalog()`, `ns.maelstromCastTimeMultiplier` cast reduction |
| `SuperSwingTimer_Hooks.lua` | OnUpdate Dispatcher | `ns.RegisterOnUpdateHook()`, `ns.OnUpdateHooks` array |
| `SuperSwingTimer_UI.lua` | Bar Frame & Visual Rendering | `ns.mhBar`, `ns.ohBar`, `ns.rangedBar`, `ns.enemyBar`, spark rendering, Hunter Auto Shot / cast bar |
| `SuperSwingTimer_ClassMods.lua` | Class Mods & Power Bars | `SetupWarrior()`, `SetupRogue()`, `SetupEnhShaman()`, `SetupHunter()`, `SetupDruid()`, `SetupRetPaladin()`, `ns.UpdateWarriorRageBar()` (Rage, Energy, Mana), debuff bars |
| `SuperSwingTimer_Config.lua` | `/sst` Options Panel | Slash command options frame, dropdowns, sliders, color swatches |
| `SuperSwingTimer_SoD.lua` | Season of Discovery (1.15.9) | `ns.isSoD` gating, rune spell classifications, Maelstrom Weapon stack tracker, Sudden Death proc alerts, `ns.SOD_TRACKED_SPELLS` (9 classes), `ns.GetSoDAuraData` |
| `SuperSwingTimer_Tests.lua` | In-Game WoWUnit Test Suite | 6 test suites (`SST-Core`, `SST-Auras`, `SST-Combat`, `SST-Hunter`, `SST-SoD`, `SST-ClassMods`), `/ssttest` command |
| `SuperSwingTimer.lua` | Addon Bootstrap | `ADDON_LOADED`, `PLAYER_LOGIN`, `MigrateDB`, `/sst` registration |
| `test_migrations.lua` | Standalone CLI Test Harness | `DeepCopyDefaults` & SavedVariables migration test runner (37/37 passing) |
