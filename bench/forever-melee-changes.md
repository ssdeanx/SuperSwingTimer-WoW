# WoW Forever (1.60.1.70790) — melee class changes affecting swing timing, buffs and debuffs

**Prepared for:** SuperSwingTimer (melee swing-timer addon)
**Build basis:** launch client **1.60.1.70790** (2026-11-05). Spell data read from the Forever client by ForeverDB at build **1.60.1.70862** (Nov 7 hotfix) and by 60.tools at **1.60.1.70790**. Classic baseline = Classic Era **1.15.9.69722**.
**Status of facts:** every row carries a source URL and a confidence grade. Nothing here is inferred from memory of Classic; where a value could not be sourced it is marked **UNVERIFIED**.

---

## 1. Summary — what Forever changed for melee

Forever is not "Classic plus a few talents". Melee combat was re-tuned in five ways that a swing timer actually cares about:

1. **Attack-speed modifiers were multiplied and moved around.** Slice and Dice is unchanged (9–21 s by combo point, Improved SnD +45%), but Forever adds **Rage of the Farseer** (Enhancement: +30% attack speed for 25 s, new), **Deadly Aspects** (Hunter: Aspect of the Beast auto-attacks can proc +30% melee haste for 12 s), a reworked **Flurry** (3 ranks for 10/20/30% for 3 swings, Warrior; 6/12/18/24/30% for Shaman, 3 swings), and keeps **Blade Flurry** (+20%, 15 s) and **Seal of the Crusader** (40% faster attacks, self). These are the buffs a swing timer must fold into swing duration.
2. **Warrior Slam was rebuilt as a cooldown strike.** Slam now has a **15 s cooldown** and a new rank 1 at level 20, and the Arms talent **Improved Slam** explicitly makes Slam *no longer interrupt or delay the melee swing* — the single most important melee-timing change in the expansion for Warrior. Warriors without Improved Slam still eat the swing delay.
3. **Most raid debuffs kept their duration, but Paladin judgements were massively extended.** Judgement of the Crusader, Light and Wisdom all went from **10 s to 40 s**; Demoralizing Shout 30→45 s; Thunder Clap's cooldown went *up* 4→6 s (its 10 s, 20% attack-speed slow is unchanged). Sunder Armor, Rend and Deep Wounds are numerically the same as Classic.
4. **Feral was renamed and re-scoped.** Mangle is gone as a player ability; the bear capstone is **Primal Bite (407995)**, and **Lacerate (1328617)** is now a Feral talent (5 stacks, 15 s bleed). **Faerie Fire (Feral) (16857) no longer exists** — the talent was removed and the spell 404s in the client; plain Faerie Fire (770) is now usable in cat/bear forms.
5. **New melee buttons with their own windows.** Warrior: Victory Rush (402927), Spearing Strike (1310222), Reckless Swings (1329555, 8 s). Rogue: Shank (1329283, 10 s cd, off-hand strike that is *not* a swing), Venom (1329328, 6 s), Mutilate (399956). Paladin: Holy Strike (679) baseline at 6, Seal of Fury (1311649, 30 s), Judgement of Fury (20183, 3 s taunt). Hunter: a real melee Survival kit — Strider Kick (1317257), Lacerating Strikes (1310533, 21 s bleed), weapon-based Counterattack (19306).

Things the brief asked about that **do not exist in Forever**: Seal of Vengeance / Seal of Corruption (0 records in the client), Sudden Death (only SoD rune records), Crusader Strike as a Paladin spellbook ability, Faerie Fire (Feral), Mangle (cat/bear). Enhancement Shaman **cannot learn Dual Wield** in Forever, so there is no off-hand swing to time for Shaman.

---

## 2. Master table

Legend for **type**: `buff` = on the player, `debuff` = on the target, `cd` = cooldown/ability window.
**spellId** is the cast/ability ID as recorded in the Forever client. Where the tracked aura has a different ID than the cast spell, the aura ID is called out; if not called out it is **UNVERIFIED** (Blizzard does not expose it in these pages).

### Warrior

| class | spec | spell | spellId | type | duration / stacks | change vs Classic Era 1.15.x | source | conf |
|---|---|---|---|---|---|---|---|---|
| Warrior | Arms/Prot | Rend (rank 7; r1 = 772) | 11574 | debuff | 21 s (rank 7); 9/12/15/18/21 s by rank | **SAME** numbers, all ranks | https://foreverdb.net/spell/11574 | high |
| Warrior | Arms | Deep Wounds (talent) | 12834 | debuff | 12 s | **SAME** duration and %; tooltip reworded only | https://foreverdb.net/spell/12834 | high (debuff aura ID UNVERIFIED) |
| Warrior | Prot/Arms | Sunder Armor (r1) | 7386 | debuff | 30 s, **5 stacks** | **SAME** (r1 −90 armor/stack) | https://foreverdb.net/spell/7386 | high |
| Warrior | Prot | Thunder Clap (r1) | 6343 | debuff (attack speed) | 10 s, **20% slower attacks**, 4 targets | cooldown **6 s (was 4 s)**; usable in Battle **or** Defensive Stance | https://foreverdb.net/spell/6343 · https://foreverdb.net/class/Warrior/changes | high |
| Warrior | all | Demoralizing Shout (r1) | 1160 | debuff | **45 s (was 30 s)** | stronger effect all ranks (r5 −196 vs −140) | https://foreverdb.net/spell/1160 | high |
| Warrior | all | Battle Shout (r1) | 6673 | buff | **180 s (was 120 s)** | weaker effect all ranks (r7 139 vs 232 AP) | https://foreverdb.net/spell/6673 | high |
| Warrior | Fury | Bloodthirst | 23881 | buff (self) | **10 s**, +10% move speed | damage 45% AP + 30; **new 10 s buff** ("duration 10 sec instead of none") | https://foreverdb.net/spell/23881 | high |
| Warrior | all | Slam (rank 1) | 1240193 | cd | **15 s cooldown** | **NEW rank 1 at 20**; Classic had no cooldown; cd 18 s→15 s in beta | https://foreverdb.net/spell/1240193 · official notes | high |
| Warrior | Arms | Improved Slam (talent) | 12862 | passive | — | −2.5/−5 s Slam cd, −0.5 s cast/GCD, **and Slam no longer interrupts or delays your melee swing** | https://foreverdb.net/class/Warrior/talents | high |
| Warrior | Fury | Reckless Swings | 1329555 | buff | **8 s**, 4 attacks | **NEW**; 15 s cd, costs 25% base health, +5 rage per attack | https://foreverdb.net/spell/1329555 · official notes | high |
| Warrior | all | Victory Rush | 402927 | cd | 20 s window after a kill | **NEW** (SoD rune); 30 s cd (vs 8 s in SoD) | https://foreverdb.net/spell/402927 | high |
| Warrior | Arms | Spearing Strike | 1310222 | cd | 20 s | **NEW**; 75% WD (+75% vs giants/dragonkin/mounted) | https://foreverdb.net/spell/1310222 · https://www.60.tools/changes/warrior | high |
| Warrior | Arms | Sweeping Strikes | 12292 | buff | 5 attacks | same behaviour | https://foreverdb.net/spell/12292 | medium |
| Warrior | Fury | Death Wish | 12328 | buff | **30 s** | +20% physical, **+5% damage taken** (was −20% armor/resist) | https://foreverdb.net/spell/12328 | high |
| Warrior | Fury | Recklessness | 1719 | buff | **15 s** | tooltip only; numbers identical | https://foreverdb.net/spell/1719 | high |
| Warrior | Arms | Retaliation | 20230 | buff | **15 s** | cooldown **15 min (was 30 min)** | https://foreverdb.net/spell/20230 | high |
| Warrior | Prot | Shield Wall | 871 | buff | **12 s (was 10 s)** | weaker effect; cd **15 min (was 30)** | https://foreverdb.net/class/Warrior/changes | high |
| Warrior | Prot | Shield Block | 2565 | buff | **7 s (was 5 s)**, 2 blocks | duration only | https://foreverdb.net/spell/2565 | high |

### Rogue

| class | spec | spell | spellId | type | duration / stacks | change vs Classic Era 1.15.x | source | conf |
|---|---|---|---|---|---|---|---|---|
| Rogue | all | Slice and Dice | 5171 | buff | **9/12/15/18/21 s** by CP | **SAME** as Classic (rank 1 20%, rank 2 at 42 = 30%); also no longer stands a sitting target up | https://foreverdb.net/spell/5171 · official notes | high |
| Rogue | all | Improved Slice and Dice (talent) | 14165 | passive | — | **+45% SnD duration** (3 ranks) | https://foreverdb.net/class/Rogue/talents | high |
| Rogue | all | Rupture | 1943 | debuff | **8/10/12/14/16 s** by CP | **less damage all 6 ranks** (r6 105 vs 180) | https://foreverdb.net/spell/1943 | high |
| Rogue | Assassination | Blood Splatter (talent) | 1329256 | passive | — | **NEW**: +6 s Rupture, +9 s Garrote | https://foreverdb.net/class/Rogue/talents | high |
| Rogue | all | Expose Armor (r1) | 8647 | debuff | **30 s** | **stronger all 5 ranks**: r5 −450/CP vs −340 | https://foreverdb.net/spell/8647 | high |
| Rogue | Subtlety | Hemorrhage | 16511 | debuff | **15 s** | **changed**: now +15% **Rupture and Garrote** damage from that Rogue (was flat physical damage, 30 charges) | https://foreverdb.net/spell/16511 | high |
| Rogue | Combat | Blade Flurry | 13877 | buff | **15 s** | **+20% melee attack speed** + cleave | https://foreverdb.net/spell/13877 | high |
| Rogue | Combat | Adrenaline Rush | 13750 | buff | **15 s** | +100% Energy regen | https://foreverdb.net/spell/13750 | high |
| Rogue | Subtlety | Ghostly Strike | 14278 | buff | **7 s** | +15% dodge; now 180% WD with dagger | https://foreverdb.net/spell/14278 | high |
| Rogue | Subtlety | Premeditation | 14183 | buff | **20 s (was 10 s)** | combo points window doubled | https://foreverdb.net/spell/14183 | high |
| Rogue | Assassination | Cold Blood | 14177 | buff | next attack | 100% crit | https://foreverdb.net/class/Rogue/talents | high |
| Rogue | all | Shank | 1329283 | cd | **10 s** (rank 2 at 44) | **NEW**: off-hand strike, 50% WD, +15 Energy, **cannot miss** | https://foreverdb.net/spell/1329283 · official notes | high |
| Rogue | Assassination | Venom (talent) | 1329328 | buff | **6 s** | **NEW**: Shank grants +30% poison damage, +20% apply chance | https://foreverdb.net/spell/1329328 | high |
| Rogue | Assassination | Mutilate | 399956 | cd | — | **NEW** capstone (SoD origin), 90% WD both weapons, 2 CP | https://foreverdb.net/spell/399956 | high |
| Rogue | all | Poised | 1328825 | passive | — | **NEW**: out of combat at full Energy, next ability costs 10 less | https://foreverdb.net/spell/1328825 | high |

### Feral Druid (cat / bear)

| class | spec | spell | spellId | type | duration / stacks | change vs Classic Era 1.15.x | source | conf |
|---|---|---|---|---|---|---|---|---|
| Druid | Feral (cat) | Rip | 1079 | debuff | **12 s** (all CP) | **+~25%** base and AP scaling | https://foreverdb.net/spell/1079 | high |
| Druid | Feral (cat) | Rake | 1822 | debuff | **9 s** | **+~25%** (r1 27 + 60 vs 19 + 39) | https://foreverdb.net/spell/1822 | high |
| Druid | Feral (bear) | Lacerate (talent) | 1328617 | debuff | **15 s, 5 stacks** | **NEW talent** (SoD spell, retuned: less damage, 15 Rage) | https://foreverdb.net/spell/1328617 | high |
| Druid | Feral (bear) | Primal Bite | 407995 | cd | 6 s (per class guide) | **NEW** — Blizzard's renamed Mangle capstone; high threat | https://foreverdb.net/spell/407995 · https://foreverdb.net/class/Druid/abilities | medium |
| Druid | Feral | Mangle (cat 33876 / bear 33878) | — | — | — | **REMOVED** — both IDs 404 in the Forever client | https://foreverdb.net/spell/33876 | high |
| Druid | Feral | Faerie Fire | 770 | debuff | **40 s**, −175 armor | **SAME** numbers, but now **usable in cat/bear/dire bear** | https://foreverdb.net/spell/770 | high |
| Druid | Feral | Faerie Fire (Feral) | 16857 | — | — | **REMOVED** (talent gone, spell 404s) | https://foreverdb.net/class/Druid/changes | high |
| Druid | Feral (bear) | Demoralizing Roar | 99 | debuff | **30 s** | **stronger** all 5 ranks (r1 −46 vs −30) | https://foreverdb.net/spell/99 | high |
| Druid | Feral (cat) | Tiger's Fury | 5217 | buff | **6 s** | +15% physical damage (Classic value UNVERIFIED) | https://foreverdb.net/spell/5217 | medium |
| Druid | Feral (bear) | Blood Frenzy (talent) | 16958 | passive | — | now **also** grants +1 combo point on cat crits | https://foreverdb.net/class/Druid/talents | high |
| Druid | Feral | Rend and Tear (talent) | 1223246 | passive | — | **NEW**: +3/6/9/12/15% melee damage on bleeding targets | https://foreverdb.net/class/Druid/talents | high |
| Druid | Feral | Natural Reaction (talent) | 417051 | passive | — | **NEW**: +5% dodge, 5 Rage per dodge | https://foreverdb.net/class/Druid/talents | high |

### Enhancement Shaman

| class | spec | spell | spellId | type | duration / stacks | change vs Classic Era 1.15.x | source | conf |
|---|---|---|---|---|---|---|---|---|
| Shaman | Enh | Stormstrike | 17364 | debuff | **12 s** | **changed**: 150% normalized WD; **cd 6 s (was 8 s)**; debuff now +20% to *your* LB/CL/Earth Shock (was 2 charges of +20% Nature) | https://foreverdb.net/spell/17364 · official notes | high |
| Shaman | Enh | Improved Stormstrike (talent) | 1223031 | buff | 15 s | **NEW**: 50/100% mana regen while casting; Stormstrike cd reset on dodge/parry | https://foreverdb.net/class/Shaman/talents | high |
| Shaman | Enh | Maelstrom Weapon (talent) | 408498 | buff | **30 s, 5 stacks** | **NEW**: melee hits reduce next Lightning Bolt cast time/mana by 4%/stack (20% at 5) | https://foreverdb.net/spell/408498 | high |
| Shaman | Enh | Rage of the Farseer (talent) | 425336 | buff | **25 s** | **NEW**: **+30% attack speed** (swing-speed buff) | https://foreverdb.net/spell/425336 | high |
| Shaman | Enh | Flurry (talent) | 16256 | buff | 3 swings | **6/12/18/24/30%** attack speed after melee crit (was 5/10/15/20/25%) | https://foreverdb.net/spell/16256 · official notes | high |
| Shaman | Enh | Windfury Weapon | 8232 | imbue | 60 min | **SAME** proc (20% chance, 2 extra attacks); now animates an extra swing | https://foreverdb.net/spell/8232 · official notes | high |
| Shaman | Enh | Windfury Totem | 8512 | buff aura | **5 min (was 2 min)** | duration; 20% chance for 1 extra attack | https://foreverdb.net/spell/8512 | high |
| Shaman | Enh | Grace of Air Totem | 8835 | buff aura | **5 min (was 2 min)** | duration only | https://foreverdb.net/spell/8835 | high |
| Shaman | all | Flame Shock | 8050 | debuff | **12 s** | more damage all ranks; Call of Flame adds **+9 s** | https://foreverdb.net/spell/8050 | high |
| Shaman | Enh | Earth Shock | 8042 | debuff | 2 s lockout | more damage | https://foreverdb.net/spell/8042 | high |
| Shaman | Enh | Frost Shock | 8056 | debuff | **8 s**, 50% slow | more damage | https://foreverdb.net/spell/8056 | high |
| Shaman | Enh | Lightning Shield | 324 | buff | **10 min, 3 charges** | unchanged shape | https://foreverdb.net/spell/324 | high |
| Shaman | Enh | Fire Nova | 408341 | cd | — | **NEW** baseline at 12 (SoD rune), no totem item needed | https://foreverdb.net/class/Shaman/changes | high |
| Shaman | Enh | Dual Wield | — | — | — | **NOT LEARNABLE in Forever** → no off-hand swing | https://foreverdb.net/class/Shaman/changes · https://www.warcrafttavern.com/forever/guides/enhancement-shaman/ | high |

### Retribution Paladin

| class | spec | spell | spellId | type | duration / stacks | change vs Classic Era 1.15.x | source | conf |
|---|---|---|---|---|---|---|---|---|
| Paladin | all | Judgement | 20271 | cd | — | tooltip only, numbers identical | https://foreverdb.net/spell/20271 | high |
| Paladin | Ret/Prot | Judgement of the Crusader | 20188 | debuff | **40 s (was 10 s)** | stronger all ranks (r6 161 vs 140) | https://foreverdb.net/spell/20188 | high |
| Paladin | all | Seal of the Crusader | 21082 | buff | **30 s** | **SAME** numbers (tooltip reworded): 40% faster attacks; melee strikes refresh the Judgement | https://foreverdb.net/spell/21082 | high |
| Paladin | Ret | Holy Strike | 679 | cd | **10 s** (per class guide) | **NEW baseline**, level 6; 25% WD + 11–14 Holy | https://foreverdb.net/spell/679 · https://foreverdb.net/class/Paladin/abilities | high |
| Paladin | Prot | Seal of Fury | 1311649 | buff | **30 s** | **NEW**; +6 Holy per swing, absorb shield while a shield is equipped | https://foreverdb.net/spell/1311649 | high |
| Paladin | Prot | Judgement of Fury | 20183 | debuff | **3 s taunt (was 4 s)** | **NEW**; damages and taunts | https://foreverdb.net/spell/20183 · official notes | high |
| Paladin | Ret | Seal of Command | 20375 | buff | **30 s** | **SAME** as Classic | https://foreverdb.net/spell/20375 | high |
| Paladin | Ret | Vengeance (talent) | 20049 | buff | **30 s, 5 stacks** | 3/6/9% per stack (3 ranks), refreshed by crits | https://foreverdb.net/spell/20049 | high |
| Paladin | Ret | Unsealed Wrath (talent) | 1310735 | buff | **15 s, 3 stacks** | **NEW**: melee attacks store seal copies | https://foreverdb.net/spell/1310735 | high |
| Paladin | all | Judgement of Light | 20185 | debuff | **40 s (was 10 s)** | duration | https://foreverdb.net/class/Paladin/changes | high |
| Paladin | all | Judgement of Wisdom | 20186 | debuff | **40 s (was 10 s)** | duration | https://foreverdb.net/class/Paladin/changes | high |
| Paladin | Holy | Holy Shock (talent) | 1311606 | cd | **10 s cd (was 30 s)** | retuned damage, tier 5 | https://foreverdb.net/class/Paladin/changes | high |
| Paladin | — | Seal of Vengeance / Seal of Corruption | — | — | — | **DOES NOT EXIST** (0 records in client) | https://foreverdb.net/spells?q=Seal%20of%20Vengeance | high |
| Paladin | — | Crusader Strike | — | — | — | **NOT a Paladin ability** (absent from spellbook and change list; a client record 1319259 exists with no documented source) | https://foreverdb.net/class/Paladin/abilities | medium |

### Hunter (melee aspects / Survival)

| class | spec | spell | spellId | type | duration / stacks | change vs Classic Era 1.15.x | source | conf |
|---|---|---|---|---|---|---|---|---|
| Hunter | all | Hunter's Mark | 1130 | debuff | **120 s** | stronger AP all ranks; **cannot be stacked by rank** | https://foreverdb.net/spell/1130 · official notes | high |
| Hunter | all | Serpent Sting | 1978 | debuff | **15 s** | lower base (r1 15 vs 20 over 15 s) but **AP coef/tick 5% (was 3%)** | https://foreverdb.net/spell/1978 · official notes | high |
| Hunter | all | Wing Clip | 2974 | debuff | **10 s**, 50% slow | **SAME** all ranks | https://foreverdb.net/spell/2974 | high |
| Hunter | Surv | Mongoose Bite | 1495 | cd | — | **weapon-based**: WD + 15 (was flat 25) | https://foreverdb.net/spell/1495 | high |
| Hunter | Surv | Raptor Strike | 2973 | cd | — | less damage on 5 of 8 ranks | https://foreverdb.net/spell/2973 | high |
| Hunter | all | Aspect of the Beast | 13161 | buff | — | **4 ranks** (was 1); grants **melee AP +50** at r1 | https://foreverdb.net/spell/13161 | high |
| Hunter | Surv | Deadly Aspects (talent) | 19552 | buff (proc) | **12 s**, +30% melee haste | **NEW melee branch**: Aspect of the Beast autos have 2–10% chance to grant melee haste | https://foreverdb.net/spell/19552 · https://foreverdb.net/class/Hunter/talents | high |
| Hunter | Surv | Strider Kick (talent) | 1317257 | cd | 3 s speed | **NEW**: 100% melee WD, +30% move speed 3 s | https://foreverdb.net/spell/1317257 | high |
| Hunter | Surv | Lacerating Strikes (talent) | 1310533 | debuff | **21 s bleed** | **NEW**: Mongoose Bite bleeds for 40% of its damage | https://foreverdb.net/spell/1310533 | high |
| Hunter | Surv | Counterattack | 19306 | debuff (root) | **5 s** | **weapon-based** now: 50% WD + 26 (was flat 40) | https://foreverdb.net/class/Hunter/talents | high |
| Hunter | pet | Savage Rend | 1265831 | debuff | **18 s bleed** | **NEW pet ability** (Beast Training); +?% bleed damage taken | https://foreverdb.net/spell/1265831 | high |

### Explicitly absent / unverifiable

| item | finding | source | conf |
|---|---|---|---|
| Sudden Death (Warrior) | Only SoD rune records (440113/440495); **no Warrior talent or ability** | https://foreverdb.net/spells?q=Sudden%20Death | high |
| Mangle (Druid) | Removed; replaced by Primal Bite / Lacerate | https://foreverdb.net/spell/33876 | high |
| Dual Wield (Shaman) | Not learnable; Enhancement is 2H/1H+shield | https://foreverdb.net/class/Shaman/changes | high |
| Blessing of Salvation / Light | Removed from the game | https://foreverdb.net/class/Paladin/changes · official notes | high |
| Deep Wounds **aura** ID | Cast/talent ID is 12834; the bleed aura ID is not published | — | UNVERIFIED |
| Sunder Armor / Thunder Clap **aura** IDs | Cast IDs 7386 / 6343 confirmed; aura IDs not published | — | UNVERIFIED |
| Classic value for Tiger's Fury damage % | Forever shows 15% / 6 s; Classic figure not sourced | — | UNVERIFIED |

---

## 3. Addon implications for SuperSwingTimer

**Add / track (new IDs that a Forever client can actually see):**
- Warrior: `402927` Victory Rush, `1310222` Spearing Strike, `1329555` Reckless Swings, `1240193` Slam (cooldown-driven, 15 s).
- Rogue: `1329283` Shank — **treat as an off-hand *strike*, not an off-hand swing** (it must not restart the OH timer), `1329328` Venom, `399956` Mutilate, `1328825` Poised.
- Druid: `1328617` Lacerate (5 stacks, 15 s), `407995` Primal Bite, `1223246` Rend and Tear, `417051` Natural Reaction.
- Shaman: `408498` Maelstrom Weapon (5 stacks, 30 s), `425336` Rage of the Farseer (**+30% attack speed, 25 s** — must rescale the swing bar), `408341` Fire Nova.
- Paladin: `679` Holy Strike (10 s cd), `1311649` Seal of Fury (30 s), `20183` Judgement of Fury (3 s), `1310735` Unsealed Wrath (15 s / 3 stacks).
- Hunter: `1317257` Strider Kick, `1310533` Lacerating Strikes (21 s bleed), `19306` Counterattack, `19552` Deadly Aspects proc (**+30% melee haste, 12 s**), `13161` Aspect of the Beast.

**Update values (same spell ID, new duration):**
- Demoralizing Shout `1160` 30→**45 s**; Battle Shout `6673` 120→**180 s**; Shield Block `2565` 5→**7 s**; Shield Wall `871` 10→**12 s**; Judgement of the Crusader `20188` 10→**40 s**; Judgement of Light `20185` / Wisdom `20186` 10→**40 s**; Hunter's Mark `1130` →**120 s**; Premeditation `14183` 10→**20 s**; Thunder Clap `6343` cooldown 4→**6 s**.

**Attack-speed modifiers the swing engine must fold in (Forever-specific):**
Seal of the Crusader `21082` (40% faster attacks), Blade Flurry `13877` (+20%, 15 s), Slice and Dice `5171` (9–21 s, ×1.45 with Improved SnD), Rage of the Farseer `425336` (+30%, 25 s), Deadly Aspects `19552` (+30%, 12 s), Flurry `16256` (Shaman, up to +30% for 3 swings), Warrior Flurry (3 ranks, up to +30% for 3 swings), Troll Berserking (15 s, racial).

**Swing-delay rules to special-case:**
- **Slam** `1240193`: with **Improved Slam `12862`** it explicitly *no longer interrupts or delays the melee swing*; without the talent it still delays. The timer should key off whether the talent is known rather than assuming Classic behaviour.
- **Windfury Weapon / Windfury Totem**: Blizzard now animates an *additional weapon swing* — if that fires a swing event, it must be filtered out of the swing timer (it is a proc animation, not a new swing cycle).

**Remove / stop tracking:**
- `16857` Faerie Fire (Feral) — spell no longer exists.
- Mangle `33876`/`33878` — removed; replaced by `407995` / `1328617`.
- Seal of Vengeance / Corruption, Crusader Strike, Sudden Death — never existed in Forever; any Classic-era config for them is dead weight.
- Shaman off-hand swing timer — Dual Wield is not learnable, so an OH bar for Enhancement is meaningless.

**Caveat for whoever implements this:** the IDs above are the *cast/ability* IDs that appear in the Forever client and on ForeverDB/60.tools. Aura IDs for debuffs Blizzard derives server-side (Deep Wounds, Sunder Armor, Thunder Clap, Rend ticks) are not published and must be confirmed in-game with `/sst diag` before hard-coding them.

---

## 4. Sources and method

- **ForeverDB** — per-spell pages (rank tables "Forever vs Classic Era", tooltips, cooldowns, durations) and per-class change/ability/talent pages. Data extracted from the Forever client, stated build **1.60.1.70862**. Examples: https://foreverdb.net/spell/5171, https://foreverdb.net/class/Warrior/changes, https://foreverdb.net/class/Druid/abilities.
- **60.tools** — independent client extraction at **1.60.1.70790**; class change pages list every changed spell/talent with its spell ID ("Client data. Forever client, build 1.60.1.70790, spell NNNNN"). https://www.60.tools/changes/warrior
- **Wowhead (Forever)** — mirrors Blizzard's official development notes and hosts Forever spell pages used to cross-check IDs (e.g. `spell=5171` shows "Added in patch 1.60.1"). https://www.wowhead.com/forever/news/wow-forever-official-development-notes-and-class-tuning-383704 — original: https://us.forums.blizzard.com/en/wow/t/2360696/9
- **Warcraft Tavern** — Enhancement Shaman guide used only to corroborate the 2-handed (no Dual Wield) reality. https://www.warcrafttavern.com/forever/guides/enhancement-shaman/
- **Cross-checks performed:** new Warrior IDs agree between 60.tools and ForeverDB (Spearing Strike `1310222`, Reckless Swings `1329555`); SnD `5171` present on Wowhead Forever with "Added in patch 1.60.1"; Mangle/Faerie Fire (Feral)/Seal of Vengeance return 404 or zero records.
- **Discrepancy noted:** Blizzard's notes say "Voice of Truth removed" and "Improved Seal of Fury removed", while the 1.60.1.70862 client still lists both as Paladin entries. Client data (ForeverDB) was preferred for IDs; treat these two as build-churn items and verify in-game.

*Report generated 2026-11-07. No addon .lua/.toc file was modified.*
