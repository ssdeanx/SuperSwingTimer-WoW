# WoW Forever native aura groups — v0.3.0

**Supersedes:** nothing (adds to bench/findings-sst-forever-0.3.0.md).
**Evidence:** addon source at /home/sam/SuperSwingTimer-WoW; client source at
/home/sam/wow-ui-source branch `origin/forever` (1.60.1.70790, commit eac30af),
read with `git show`/`git grep`. Class data: bench/forever-melee-changes.md
(ForeverDB 1.60.1.70862, 60.tools 1.60.1.70790).
Grades: `verified` (code/client source), `in-game`, `open`.

**Scope rule:** Forever-only changes. Classic Era / TBC Anniversary / Titanforge
keep the existing per-class icon groups byte-for-byte; the new module is inert
on those clients.

## Why the classic icon groups cannot work while restricted

`C_UnitAuras.GetAuraDataByIndex` is `SecretWhenUnitAuraRestricted`
(UnitAuraDocumentation.lua:208). While combat/encounter/challenge/PvP
restrictions are active every AuraData field except `auraInstanceID`,
`isFromPlayerOrPlayerPet`, `isHarmful`, `isHelpful`, `isNameplateOnly`,
`isRaid` may be secret (Structure AuraData). Tainted code cannot compare a
secret `spellId`, so "scan the aura list and match my tracked spell" is
impossible by design. `ns.UnitAura` correctly returns nil rather than raising,
which is why the classic icon groups and debuff bars go blank on Forever.

## Sanctioned replacement (verified)

The client ships intrinsic `AuraContainer` / `AuraButton` frames plus the
`CustomAuraContainerTemplate` / `CustomAuraButtonTemplate` templates
(Blizzard_AuraContainer.toc; Blizzard_CustomAuraContainer.xml). The addon
declares `candidateFilters.includeSpellIDs`; the **client** performs identity
matching in secure code and writes icon, duration, stacks and duration-bar
values through secret-safe widget APIs. No secret value enters addon logic.

Evidence chain:

| Fact | Evidence |
|---|---|
| Templates are loaded into the global environment so external code can instantiate them | Blizzard_AuraContainer.toc comment |
| `allowUntaintedCreation="true"` only on the container intrinsic/template | Blizzard_AuraContainer.xml, Blizzard_CustomAuraContainer.xml |
| Access restrictions are deferred past PLAYER_LOGIN for addons | Blizzard_AuraContainerUtil.lua:403 |
| `includeSpellIDs` is a set and is default-deny when identity matching is blocked | Blizzard_CustomAuraContainer.lua ValidateCandidateFilters / CanApplyIdentityCandidateFilters |
| Spell-ID matching allowed for helpful buffs on player/group, harmful on non-assistable | same |
| `initializeFrame` runs via securecallfunction before restrictions; errors swallowed | Blizzard_AuraContainerFrameProviders.lua:79 |
| `SetIcon`/`SetDurationText`/`SetApplicationCount`/`SetDurationBar`/`SetDurationCooldown` are addon-callable | Blizzard_CustomAuraButton.lua |
| `DenyTaintedAccessWhenAurasAreSecret` applies to buttons, not the container | Blizzard_AuraContainerShared.lua:108 |
| 9+ shipping addons create containers this way | bench/forever-auracontainer-usage.md §5 |

## Implementation

New file `SuperSwingTimer_Forever.lua` (TOC last; also loaded by run_tests):

1. **Detection** — `ns.isForever` = `C_SwingTimer` + `Enum.PlayerSwingType`
   (existing `ns.HasNativeSwingTimer`); `ns.hasAuraContainer` =
   `C_AuraContainerUtil` + sort enums.
2. **Secrecy helpers** — `ns.IsAuraDataSecret()` (`C_Secrets.ShouldAurasBeSecret`,
   fail closed on error), `ns.GetSpellAuraSecrecy` (`GetSpellAuraSecrecy`),
   `ns.IsSpellAuraReadable` (NeverSecret / AlwaysSecret / Contextual).
3. **Buff group** — one `AuraContainer` on `player`, filter `HELPFUL`,
   `includeSpellIDs` = the class buff list, flow layout anchored bottom-centre
   above the swing bar. Icons, duration text, stack text and border match the
   classic look; the 4 s glow is replaced by a DurationTextBinding colour curve
   (red <= 4 s), which the client evaluates against the secret duration.
4. **Debuff group** — one `AuraContainer` on `target`, filter `HARMFUL|PLAYER`,
   `includeSpellIDs` = the class debuff list, plus a 3 px duration bar under
   each icon. This is the "own icon group" the request asked for; the classic
   thin bars stay as they are.
5. **Hand-over, not replacement** — the classic per-class icon groups are
   never wrapped or disabled. They keep running and hide themselves while aura
   data is secret (because `ns.UnitAura` returns nil instead of reading a
   restricted field), so every classic feature is preserved while auras are
   readable: cooldown-only icons (Kill Command, Readiness, Lay on Hands,
   Hammer of Justice, Bash), the 4 s glow and the exact duration formatting.
   The native buff row is shown only while `ns.IsAuraDataSecret()` is true, so
   the two rows never display the same aura simultaneously. The native debuff
   row is additive and always available.
6. **Anchoring** — reuses `ns.debuffStackIconOffset`, published by the classic
   `RestackDebuffBars`, so the native rows sit exactly where the classic icon
   groups sat (8 px above the tallest visible debuff bar).
7. **Diagnostics** — `/sst diag` gains `auraGroup: native=... buff=true(N) debuff=true(N) secret=... tries=...`.

## Forever class data folded in (from bench/forever-melee-changes.md)

Added buffs: Warrior Bloodthirst 23881, Reckless Swings 1329555; Paladin Seal of
the Crusader 21082, Seal of Command 20375, Seal of Fury 1311649, Vengeance 20049,
Unsealed Wrath 1310735; Shaman Flurry 16256, Rage of the Farseer 425336,
Maelstrom Weapon 408498, Windfury Totem 8512, Grace of Air 8835; Hunter Deadly
Aspects 19552, Aspect of the Beast 13161; Rogue Ghostly Strike 14278, Venom
1329328.

Added debuffs: Rogue Hemorrhage 16511; Druid Lacerate 1328617, Faerie Fire 770,
Demoralizing Roar 99; Shaman Stormstrike 17364, Frost Shock 8056, Earth Shock
8042; Paladin Judgement of the Crusader 20188, Light 20185, Wisdom 20186, Fury
20183; Hunter Hunter's Mark 1130, Lacerating Strikes 1310533.

Removed (do not exist in Forever): Mangle 33876/33878, Faerie Fire (Feral)
16857, Seal of Vengeance/Corruption 31803-31804/53736-53743.

## Open (needs in-game evidence)

| Item | Why it is open |
|---|---|
| Warrior Slam 1240193 + Improved Slam 12862 | Forever Slam has a 15 s cd and Improved Slam removes the swing delay. The addon still uses the Classic pause path; changing it needs in-game confirmation of the cast/PLAYER_SWING interaction. |
| Windfury extra swing animation | If the proc fires PLAYER_SWING, it must be filtered; unknown whether it does. |
| Deep Wounds / Sunder Armor / Thunder Clap / Rend aura IDs | Cast IDs verified; the aura IDs Blizzard derives server-side are not published. |
| AuraContainer creation on the live client | Verified against client source and shipping addons, not a live session. `/sst diag` `auraGroup` line is the in-game proof. |

## Gates

- `lua5.1 run_tests.lua` — 184/184 (new group SST-ForeverAura, 10 tests,
  including a recording-container test that exercises SetUnit / AddAuraGroup /
  includeSpellIDs / initializeFrame styling).
- `luacheck .` — 0 warnings / 0 errors across 15 files.
- `luac5.1 -p` clean on every changed file.

## Aura-ID audit (2026-11-07, second pass)

**Direct debuffs — aura ID equals the cast ID.** Verified from the Wowhead Forever
buff tooltip record (`id="btt<ID>"` on the raw page): Serpent Sting 25295,
Flame Shock 29228, Rend 11574, Thunder Clap 6343, Demoralizing Shout 1160,
Sunder Armor 7386. The same "Apply Aura" pattern is used by Hunter's Mark,
Wing Clip, Stormstrike, Hemorrhage, Faerie Fire, Rake, Rip, Lacerate and the
Judgements, so their cast IDs are the aura IDs.

**Triggered talents — separate aura IDs.** These are listed alongside the
ability ID: Flurry 12320 (talent 12319), Vengeance 20050 (talent 20049),
Seal of Fury 1311647 (ability 1311649), Venom 1310703 (ability 1329328),
Deep Wounds 12721 (talent 12834). Open: the Bloodthirst self-buff and the
Shaman Flurry buff aura IDs are not published; the ability IDs stay in the
lists as fallbacks.

**Rank audit (Forever, from ForeverDB class ability pages):**

| Spell | Forever ranks added/fixed |
|---|---|
| Serpent Sting | r9 25295 added (was TBC 27019 only) |
| Hunter's Mark | 14323, 14324, 14325 added |
| Wing Clip | 14267, 14268 added |
| Flame Shock | already complete (8050/8052/8053/10447/10448/29228) |
| Frost Shock | 8058, 10472, 10473 added |
| Rupture | r6 11275 added |
| Rake | r4 is 9904; 9907 is Faerie Fire (shared table bug fixed) |
| Faerie Fire | 778, 9749, 9907 added |
| Demoralizing Roar | 1735, 9490, 9747, 9898 added |
| Lacerate | 1328617/1328616/414644/1235826/1235827 added |
| Judgements | full Crusader/Light/Wisdom/Fury rank sets added |
| Buffs | Battle Shout, Overpower, Divine Shield/BoP/Protection, seals, Holy Shield, Lightning Shield, Rockbiter, Windfury, totems, Aspect of the Hawk/Beast, SnD, Sprint, Vanish + triggered buffs |

**New-ability candidates** (per class, merged into both native groups; a
non-aura ID is a no-op): Victory Rush 402927, Spearing Strike 1310222, Slam
1240193, Shank 1329283, Mutilate 399956, Primal Bite 407995, Fire Nova 408341,
Holy Strike 679, Strider Kick 1317257, Counterattack 19306.

## Weaving on Forever

- Maelstrom Weapon aura `408505` (Instant, 30 s, -20% Lightning Bolt; verified
  Wowhead Forever + ForeverDB) and talent `408498` (Enhancement tier 6, 5
  ranks). Forever only: scan 408505 first, 408498 as fallback; apply the
  reduction to **Lightning Bolt only**; reset stale stacks when the aura is
  unreadable; clear the cache on a successful Lightning Bolt.
- The breakpoint marker is recomputed from the live MH swing duration every
  frame, and `ClearWeavePreview()` now runs when the render loop idles so the
  previous swing's marker cannot stay on screen.
- `/sst diag` gains `maelstrom` and `weave` lines (Forever + Shaman only).
- Open: in restricted combat the stack count may be secret; the native icon row
  displays the real stacks, while the weave math falls back to zero stacks
  (conservative) until the aura is readable again.

## Per-class separation (2026-11-07, third pass)

Class lists are pure. `ns.FOREVER_BUFF_SPELLS[class]` and
`ns.FOREVER_DEBUFF_SPELLS[class]` contain only that class's IDs;
`ns.FOREVER_NEW_ABILITY_CANDIDATES[class]` is per class. Shared buffs live in
`ns.FOREVER_SHARED_BUFFS` (Bloodlust 2825, Heroism 32182, Drums 35476/35477,
Haste Potion 28507) and racials are keyed by race in
`ns.FOREVER_RACIAL_BUFFS` (Orc/Troll/Draenei/BloodElf/Human/Dwarf/Gnome/
Undead-Scourge/NightElf). The container's `includeSpellIDs` set is assembled
at creation from class list + shared + the player's own race, so no class list
carries another class's or another race's IDs. Tests assert the separation
(Hunter has no Slam, Warrior has no Aspect of the Hawk, Shaman has no Serpent
Sting, and Bloodlust/Blood Fury are absent from class lists).
