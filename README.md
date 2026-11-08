# Super Swing Timer <span style="color:#00ccff">v0.3.2</span>

A fast, customizable **Main Hand**, **Off Hand**, **Ranged**, and **Enemy** swing timer for World of Warcraft Classic and WoW Forever clients — with class-specific rotation helpers, target debuff bars, and a unified player power bar.

- Discord: [https://discord.gg/nnbN4Naad](https://discord.gg/nnbN4Naad)

**<span style="color:#2ecc71">12,000+ downloads</span>** — thank you to everyone using the addon and reporting feedback!

---

## What's New in v0.3.2

- **WoW Forever native aura rows.** Player buffs and your own target debuffs now render through the client's native aura display — icons, stacks and duration bars — centered above the swing bar.
- **Active stance / aspect / form / seal / shield slot.** One dedicated icon to the left of the bar shows your current state: Hunter aspects, Warrior stances, Druid forms, Paladin seals, Shaman shields, Rogue stealth. Hunters get a warning when entering combat without an aspect.
- **Dynamic aura stack.** Target debuffs stay pinned above your player procs; when you have no procs, the gap collapses so nothing floats in mid-air.
- **Forever Shaman weave.** Maelstrom Weapon is read through the Forever client API; only **Lightning Bolt** receives the cast-time reduction (Chain Lightning stays 2.5 s on Forever).
- **Slam timing.** With **Improved Slam**, Slam no longer delays your melee swing; without the talent the cast still pushes the swing.
- **Forever diagnostics.** `/sst diag` now shows `auraGroup`, `maelstrom` and `weave` lines so you can see exactly what the client is exposing.

---

## Client Availability

| Client Version | TOC Interface | Swing Bars | Enemy Swing Bar | Class Helpers, Auras & Debuffs | Status |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Classic Era & Season of Discovery** | `11509` | <span style="color:#2ecc71">**Full Support**</span> | <span style="color:#2ecc71">**Supported**</span> | <span style="color:#2ecc71">**Full Support**</span> (incl. SoD Runes) | <span style="color:#2ecc71">**Ready**</span> |
| **TBC Anniversary Edition** | `20506` | <span style="color:#2ecc71">**Full Support**</span> | <span style="color:#2ecc71">**Supported**</span> | <span style="color:#2ecc71">**Full Support**</span> | <span style="color:#2ecc71">**Ready**</span> |
| **Titanforge (WotLK Classic)** | `38002` | <span style="color:#2ecc71">**Full Support**</span> | <span style="color:#2ecc71">**Supported**</span> | <span style="color:#2ecc71">**Full Support**</span> | <span style="color:#2ecc71">**Ready**</span> |
| **WoW Forever** | `16001` | <span style="color:#2ecc71">**Full Support**</span> (native timer) | <span style="color:#e67e23">**When combat log is readable**</span> | <span style="color:#2ecc71">**Supported**</span> (native aura rows) | <span style="color:#00ccff">**Ready**</span> |

> **WoW Forever:** Super Swing Timer uses the client's native swing timer for Main Hand, Off Hand and Ranged, and the client's native aura display for player buffs and your own target debuffs. Restricted combat values are displayed by the client where required; the addon never guesses a hidden value. A **Hide Blizzard Swing Bars** toggle (on by default on Forever) hides Blizzard's own swing bars and restores your original setting when unchecked.

---

## Quick Start & Slash Commands

Type `/sst` in chat to open the settings window. Bars stay hidden out of combat during normal play and appear automatically when you enter combat, start Auto Shot, or open `/sst`.

| Command | Action |
| :--- | :--- |
| `/sst` or `/super` | Open or close the **Super Swing Timer** settings panel |
| `/sst move` or `/sst unlock` | <span style="color:#2ecc71">**Unlock bars**</span> and display draggable anchor overlays |
| `/sst lock` | <span style="color:#e67e23">**Lock bars**</span> in their current position and save |
| `/sst test` | Toggle a **20-second animated preview** of all active bars |
| `/sst glow` | Toggle `LibCustomGlow` proc and expiring-icon animations on/off |
| `/sst reset` | Reset all settings and bar positions to factory defaults |
| `/stt diag` | Print a compact health & diagnostics summary (`/stt diag full` for all checks) |

---

## Installation

1. Download the latest release ZIP from [GitHub Releases](https://github.com/ssdeanx/SuperSwingTimer/releases).
2. Extract the archive into your client's `AddOns` folder so the path matches:
   - **Classic Era / SoD**: `World of Warcraft\_classic_era_\Interface\AddOns\SuperSwingTimer\`
   - **TBC Anniversary**: `World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\`
   - **Titanforge**: `World of Warcraft\_classic_titan_\Interface\AddOns\SuperSwingTimer\`
   - **WoW Forever**: `World of Warcraft\_classic_forever_\Interface\AddOns\SuperSwingTimer\`
3. Launch the game or `/reload`.

---

## Class Highlights

| Class | Supported Bars & Visuals | Key Rotation Helpers |
| :--- | :--- | :--- |
| **<span style="color:#abd473">Hunter</span>** | Ranged + Linked MH + Cast Bar + Range Helper + Aspect Icon + CD Icons + 7 Debuff Bars | Auto Shot cooldown sync, **Steady Shot / Aimed Shot** no-clip coloring (with TBC 0.5s grace period & trailing latency slice), yellow **Raptor Strike** queue tint, **4-state Range Helper** (Melee / Sweet Spot / Ranged / Out of Range), missing-aspect combat warning, and 7 target debuff bars (Serpent Sting, Wing Clip, Concussive Shot, Traps). |
| **<span style="color:#c79c6e">Warrior</span>** | MH + OH + Shield Block Bar + Rage Bar + CD Icons + Debuff Bars | **Heroic Strike** (yellow) and **Cleave** (green) queue tints on MH, **Slam** pause/extend timing with live cast bar (Forever: no delay with Improved Slam), **Shield Block** duration bar, **Overpower** proc glow, `EXEC` badge in Execute range, plus **Deep Wounds** and **Sunder Armor** target debuff bars. |
| **<span style="color:#fff569">Rogue</span>** | MH + OH + SnD Bar + Energy Tick + Energy Bar + CD Icons + Debuff Bar | Latency-adjusted red **Sinister Strike** landing window at the end of MH, slim **Slice and Dice** duration bar, vertical 4px **2s Energy Tick** bar with energy-cap warning tint, **Adrenaline Rush** bar, and **Rupture** target debuff bar. |
| **<span style="color:#f58cba">Paladin</span>** | MH + Mana Bar + CD Icons + Debuff Bars | Aura-aware **Seal Twist Zone** (proportional red tail for `0.4s + latency` on Seal of Command / Blood / Martyr) with a GCD-aware reseal marker line, **Reckoning** stack badge, and **Judgement** / **Seal of Vengeance** target debuff bars. |
| **<span style="color:#0070de">Shaman</span>** | MH + OH + Shield Charges + Mana Bar + CD Icons + Debuff Bar | **Weave Assist** for Lightning Bolt, Chain Lightning, Healing Wave, Lesser Healing Wave, and Chain Heal (auto-resolving highest known rank; **Forever: Maelstrom Weapon, Lightning Bolt only**), moving active-cast spark, **3-charge Lightning/Water Shield** tracker, **Windfury** ICD tracking, and **Flame Shock** debuff bar. |
| **<span style="color:#ff7d0a">Druid</span>** | Feral MH + Form Power Bar + Energy Tick + CD Icons + Debuff Bars | Instant Cat/Bear form swing resets, bear-yellow **Maul** queue tint, Cat **2s Energy Tick** helper, **Clearcasting** proc tracking, dynamic form-switching power bar (Rage / Energy / Mana), and **Rip**, **Rake** and **Lacerate** target debuff bars. |

- **<span style="color:#e74c3c">Enemy Swing Bar</span>** *(All Classes)*: Tracks your current hostile target's main-hand swing timer in red whenever the combat log is available.

---

## Understanding Bar Colors

| Bar / Indicator | Default Color | What It Means |
| :--- | :--- | :--- |
| **Main Hand / Off Hand / Ranged** | <span style="color:#40b8ff">**Class Blue**</span> *(or Class Color)* | Active weapon or Auto Shot swing progress |
| **Hunter Safe Zone** | <span style="color:#2ecc71">**Green**</span> | Safe to move before Auto Shot locks in |
| **Hunter Clip / Red Zone** | <span style="color:#e74c3c">**Red**</span> | Auto Shot wind-up window — stand still to fire |
| **Hunter Cast Bar** | <span style="color:#59a6f2">**Light Blue**</span> | Live Steady / Aimed / Multi-Shot cast progress beneath the ranged bar |
| **Hunter Range Helper** | <span style="color:#2ecc71">**Green**</span> / <span style="color:#f1c40f">**Yellow**</span> / <span style="color:#3498db">**Blue**</span> / <span style="color:#95a5a6">**Gray**</span> | Melee / Deadzone (Sweet Spot) / Ranged / Out of Range |
| **Next-Melee Queue (HS / Maul / Raptor)** | <span style="color:#f1c40f">**Yellow**</span> *(Cleave: <span style="color:#2ecc71">**Green**</span>)* | Next-melee ability is queued on your next main-hand swing |
| **Rogue Sinister / Paladin Twist Tail** | <span style="color:#e74c3c">**Red Right-End Slice**</span> | Optimal latency-adjusted window to press Sinister Strike or twist seals |
| **Enemy Swing Bar** | <span style="color:#e74c3c">**Red**</span> | Current hostile target's main-hand swing cooldown |

---

## Customization & Settings (`/sst`)

```text
+------------------------------------------------------------------+
| Super Swing Timer v0.3.2            [ Unlock & Move Bars ]  [X]  |
| Global Scale [=====slider (0.5x–3.0x)=====] [1.0]               |
|------------------------------------------------------------------|
| Quick Controls (Tabs: [ All ] [ Visibility ] [ Colors ] [ Class ])|
| Column 1 (Toggles)         |  Column 2 (Color Swatches)          |
| [x] Use Class Colors       |  MH Color     [■]                   |
| [x] Show Main Hand         |  OH Color     [■]                   |
| [x] Show Off Hand          |  Ranged Color [■]                   |
| [x] Lock Bars              |  Enemy Color  [■]                   |
|------------------------------------------------------------------|
| > Appearance (Width, Height, Power Bar Height, Textures, Spark)  |
| > Combat & Timer Behavior (Minimal Mode, Flash, GCD, Test Bars)  |
| > Shaman Weave Assist / Spells (Shaman only)                     |
+------------------------------------------------------------------+
```

- **Global Scale (`0.5x` – `3.0x`)**: Proportionally scales all bars, icons, sparks, borders, and fonts in real time.
- **Power Bar Height (`6px` – `30px`, default `14px`)**: Independently resize the unified Rage / Energy / Mana bar anchored below your swing stack.
- **Built-in & SharedMedia Textures**: Ships with custom statusbar textures and auto-discovers installed `LibSharedMedia` or `WeakAuras` textures.
- **Interactive Move Mode (`/sst move`)**: Left-click and drag any bar group while right-click preserves camera mouselook. Automatically locks if combat begins.
- **Per-class toggles**: Show or hide buff rows, debuff rows, stance icons, and the class helper bars independently.

---

## Diagnostics & Profiling (`/stt diag`)

`/stt` is a short alias for `/sst`. Diagnostics load first in the TOC so they remain available even if a later module encounters an error.

| Command | Description |
| :--- | :--- |
| `/stt diag` | Compact health report showing client, TOC, DB version, FPS/memory/CPU, and any warnings |
| `/stt diag full` | Detailed status across all subsystems (client, metadata, libs, DB, class, aura, timing, events, loop, perf, glow, SoD, Forever) |
| `/stt diag errors` | View captured error signatures, stack traces, and repeat counts |
| `/stt diag export` | Open a copyable report window (`Ctrl+A`, `Ctrl+C`) for bug reports |
| `/stt diag test` | Run live self-tests on clock, spell info, aura wrapper, metadata, and glow |
| `/stt diag profile [sec]` | Profile per-hook `OnUpdate` CPU time over `N` seconds (default `5s`) |

---

## Recent Releases

### <span style="color:#00ccff">v0.3.2</span> (2026-11-08)

- **<span style="color:#2ecc71">WoW Forever Dynamic Aura Stack</span>**: Target debuffs are pinned to the top of the stack above the primary bar; player procs sit directly below them. When no procs are active, the gap collapses to 0px.
- **<span style="color:#2ecc71">Active Stance & Aspect Slot</span>**: Stances, forms, aspects, seals, shields and stealth get one dedicated icon to the left of the bar, with an in-combat warning for Hunters missing an aspect.
- **<span style="color:#2ecc71">Centered Aura Rows</span>**: Buff and debuff rows now center above the swing bar instead of growing to the right.
- **<span style="color:#2ecc71">Forever Shaman Weave & Slam</span>**: Maelstrom Weapon reduces Lightning Bolt only; Slam no longer delays the swing when Improved Slam is known.
- **<span style="color:#2ecc71">Stability</span>**: Fixed two Forever-only errors (legacy icon-updater wrapper and a secret stance-slot state read).

### <span style="color:#00ccff">v0.3.1</span> (2026-11-07)

- **<span style="color:#2ecc71">WoW Forever Native Auras</span>**: Player buffs and target debuffs render through the client's native aura display; debuffs are own-caster only.
- **<span style="color:#2ecc71">Forever-Owned Maelstrom + Weave Ranks</span>**: Verified Forever ranks for Lightning Bolt, Chain Lightning and the heal families.
- **<span style="color:#2ecc71">New Forever Abilities</span>**: Victory Rush, Spearing Strike, Reckless Swings, Shank, Mutilate, Primal Bite, Lacerate, Holy Strike, Seal of Fury, Strider Kick, Lacerating Strikes and more.
- **<span style="color:#2ecc71">Forever Diagnostics</span>**: `auraGroup`, `maelstrom` and `weave` lines in `/sst diag`.

### <span style="color:#00ccff">v0.3.0</span> (2026-11-06)

- **<span style="color:#2ecc71">WoW Forever Support</span>**: Native swing timer, secret-value gating, Hunter ranged cycle fixes, Hide Blizzard Swing Bars, and a `secrets` diagnostic line.

*(See [CHANGELOG.md](CHANGELOG.md) for the complete version history.)*

---

## Feedback & Issues

Found a bug or have a feature request? Please open an issue on [GitHub Issues](https://github.com/ssdeanx/SuperSwingTimer/issues) and include the output of `/stt diag export` if reporting a bug.
