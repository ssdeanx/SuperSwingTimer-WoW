# Project Map — SuperSwingTimer

## Modules & Responsibilities

| File | Responsibilities | Key Symbols / Exports |
| --- | --- | --- |
| `SuperSwingTimer.toc` | Manifest & Load Order | Interface: `11509, 20506`, Version: `v0.2.3` |
| `Media/SuperSwingTimer_Media.lua` | Texture Asset Registration | Local statusbar textures (`MerfinMain`, `MerfinMainDark`, `MerfinFlatt`) |
| `SuperSwingTimer_Constants.lua` | Clock Engine & Spell Tables | High-precision timing (`GetTimePreciseSec()`), `ns.GetSpellInfo()`, `ns.UnitAura()`, `RESET_SWING_SPELLS`, `NO_RESET_SWING_SPELLS`, `PAUSE_SWING_SPELLS` |
| `SuperSwingTimer_State.lua` | CLEU Event & Swing Tracking | `ns.HandleCLEU()`, `ns.StartSwing()`, `ns.timers` (`mh`, `oh`, `ranged`, `enemy`), `ns.RefreshLatencyCache()` |
| `SuperSwingTimer_Weaving.lua` | Shaman Spell-Weaving Engine | `ns.RefreshWeavingState()`, `ns.RebuildWeaveSpellCatalog()`, `ns.maelstromCastTimeMultiplier` cast reduction |
| `SuperSwingTimer_Hooks.lua` | OnUpdate Dispatcher | `ns.RegisterOnUpdateHook()`, `ns.OnUpdateHooks` array |
| `SuperSwingTimer_UI.lua` | Bar Frame & Visual Rendering | `ns.mhBar`, `ns.ohBar`, `ns.rangedBar`, `ns.enemyBar`, spark rendering, Hunter Auto Shot 15px dark-background cast bar |
| `SuperSwingTimer_ClassMods.lua` | Class Mods & Power Bars | `SetupWarrior()`, `SetupRogue()`, `SetupEnhShaman()`, `SetupHunter()`, `SetupDruid()`, `SetupRetPaladin()`, `SuperSwingTimerPlayerPowerBar` (`ns.playerPowerBar` at 10px; Rage, Energy, Mana), debuff bars |
| `SuperSwingTimer_Config.lua` | `/sst` Options Panel | Slash command options frame, dropdowns, sliders, color swatches (Clip Zone / Clip Safe / Cast Bar) |
| `SuperSwingTimer_SoD.lua` | Season of Discovery (1.15.9) | `ns.isSoD` gating, rune spell classifications, Maelstrom Weapon stack tracker, Sudden Death proc alerts, `ns.SOD_TRACKED_SPELLS` (9 classes), `ns.GetSoDAuraData` |
| `SuperSwingTimer_Tests.lua` | In-Game WoWUnit Test Suite | 7 test suites (`SST-Core`, `SST-Auras`, `SST-Combat`, `SST-Hunter`, `SST-SoD`, `SST-ClassMods`, `SST-Weaving`), `/ssttest` command |
| `SuperSwingTimer.lua` | Addon Bootstrap | `ADDON_LOADED`, `PLAYER_LOGIN`, `MigrateDB` (v63), `/sst` registration |
