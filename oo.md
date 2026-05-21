# SuperSwingTimer class mod roadmap audit

I treated the runtime `.lua` symbols as the source of truth and used the roadmap only as the item list. Result:

- Implemented: 27
- Partially implemented: 0
- Missing: 0

Everything in the runtime `.lua` source is now implemented.

## Hunter

| Item | Status | File / symbol refs | Notes |
|---|---|---|---|
| Feign Death auto-shot reset | Implemented | `c:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_State.lua:1073-1105` | Feign Death now clears the hunter ranged timer and auto-repeat state through a dedicated branch. |
| Multi-Shot weave helper | Implemented | `c:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_UI.lua:780-835`; `c:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_Constants.lua:94-100,178-191` | Folded into the dedicated hunter cast-bar / hidden-window path. |
| Rapid Fire CD + duration bar | Implemented | `c:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_ClassMods.lua:1809-1905`; `c:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_Config.lua:1930-2252` | Active buff and cooldown handling are both wired. |
| Readiness reset | Implemented | `c:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_ClassMods.lua:1809-1905`; `c:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_State.lua:1138-1148` | Hunter cooldown bar now refreshes immediately when Readiness resets Rapid Fire. |
| Auto-shot range zone | Implemented | `c:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_UI.lua:730-835`; `c:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_Config.lua:2235-2249` | Green/red cast-zone overlay on the ranged bar edge. |

## Warrior

| Item | Status | File / symbol refs | Notes |
|---|---|---|---|
| Flurry remaining swings | Implemented | `c:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_ClassMods.lua:891-935`; `c:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_Config.lua:2052-2329` | Shows the ⚡1–3 counter on the MH bar. |
| Execute phase trigger | Implemented | `c:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_ClassMods.lua:753-763` | The warrior rage bar now shows a live `EXEC` badge when the target is at or below 20% health. |
| Slam cast bar | Implemented | `c:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_State.lua:800,847-863,920`; `c:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_ClassMods.lua:831-907,1149-1152` | Slam now has a stand-alone MH cast bar widget in addition to the pause/extend handling. |
| BT / WW CD markers | Implemented | `c:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_ClassMods.lua:831-907,1149-1152` | Bloodthirst and Whirlwind now show cooldown countdown badges beside the MH bar. |
| Overpower proc flash | Implemented | `c:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_State.lua:1014-1033`; `c:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_ClassMods.lua:907-1152` | A yellow `OP` flash now appears on the MH bar after player attacks are dodged. |

## Rogue

| Item | Status | File / symbol refs | Notes |
|---|---|---|---|
| Adrenaline Rush CD + active | Implemented | `c:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_ClassMods.lua:2542-2586`; `c:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_Config.lua:2038-2286` | Rogue Adrenaline Rush now shows the real aura duration when active and the cooldown when it is down. |
| Blade Flurry remaining | Implemented | `c:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_ClassMods.lua:2134-2163` | A small BF countdown badge now appears beside the MH bar while Blade Flurry is active. |
| Energy cap warning | Implemented | `c:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_ClassMods.lua:2437-2445` | The Rogue energy tick bar now tints red as energy approaches or reaches 100. |
| Cold Blood indicator | Implemented | `c:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_ClassMods.lua:2165-2189` | A small CB badge now appears beside the MH bar while Cold Blood is active. |

## Paladin

| Item | Status | File / symbol refs | Notes |
|---|---|---|---|
| Reckoning tracking | Implemented | `c:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_ClassMods.lua:416-459` | A small Reckoning stack badge now appears beside the MH bar while the buff is active. |
| Libram swap timer | Implemented | `c:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_ClassMods.lua:467-599`; `c:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_State.lua:1032-1033` | Relic-slot swaps now show a short `LIB` countdown badge beside the MH bar. |
| Judgement CD countdown | Implemented | `c:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_ClassMods.lua:346-498`; `c:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_Constants.lua:282-289` | Gold marker is positioned from the cooldown and swing timing. |

## Druid

| Item | Status | File / symbol refs | Notes |
|---|---|---|---|
| Omen of Clarity proc | Implemented | `c:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_ClassMods.lua:1436-1460`; `c:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_Config.lua:2066-2220` | Green flash/proc glow is present. |
| Power-shift tracker | Implemented | `c:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_ClassMods.lua:1779-2219`; `c:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_UI.lua:2290-2293`; `c:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_State.lua:1075` | Cat-form entry now seeds a short `PS` window bar so the power-shift timing is visible. |
| Tiger's Fury CD + duration | Implemented | `c:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_ClassMods.lua:1975-2219`; `c:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_UI.lua:2290-2293` | Tiger's Fury now shows active duration and cooldown in the MH-side badge. |
| Energy tick (cat form) | Implemented | `c:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_ClassMods.lua:2084-2219`; `c:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_UI.lua:2291-2292`; `c:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_State.lua:994-995,1047-1048` | Cat form now has its own energy tick helper with a countdown and vertical tick bar. |
| Faerie Fire ready | Implemented | `c:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_ClassMods.lua:2158-2219`; `c:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_UI.lua:2293` | A `FF` ready cue now appears when a Faerie Fire variant is usable on the current target. |

## Shaman

| Item | Status | File / symbol refs | Notes |
|---|---|---|---|
| Windfury internal CD | Implemented | `c:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_ClassMods.lua:1112-1161`; `c:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_Config.lua:1962-2415` | 3s ICD tracker bar is present. |
| Stormstrike CD marker | Implemented | `c:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_ClassMods.lua:1485-1545` | Stormstrike now shows a cooldown countdown badge beside the MH bar. |
| Flurry remaining swings | Implemented | `c:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_ClassMods.lua:1162-1200` | Shaman now gets a small Flurry stack badge beside the MH bar, matching the existing warrior-style buff counter pattern. |
| Weave cast bar | Implemented | `c:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_Weaving.lua:1-260`; `c:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_ClassMods.lua:962-1109` | Real cast-progress data drives the MH weave overlay/spark. |
| Shamanistic Rage CD | Implemented | `c:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_ClassMods.lua:1509-1545` | Shamanistic Rage now shows an active-duration or cooldown badge beside the MH bar. |

### Bottom line

All roadmap items in the runtime `.lua` source are now implemented.

Current summary:

- **Implemented:** 27
- **Partially implemented:** 0
- **Missing:** 0
