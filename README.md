# Super Swing Timer

Melee and ranged swing timer for World of Warcraft Classic and TBC (including Anniversary Edition).

Super Swing Timer tracks white-hit swing timers across main hand, off hand, and ranged attacks. It is tuned for Classic/TBC mechanics such as next-melee-attack abilities, dual-wield desync, parry haste, extra-attack suppression, haste rescaling, druid form resets, ret paladin seal-breakpoint timing, and shaman weave breakpoints. Version v3.1.17 adds full support for the TBC Classic Anniversary 1.15+ engine with optimized API wrappers and synchronized Hunter Auto Shot timing.

## At a glance

| Area | What it covers |
| --- | --- |
| Hunter | Auto Shot cooldown sync, a separate 0.5s Auto Shot / Multi-Shot cast window, movement-safe green/red feedback, and a dedicated cast bar anchored under the ranged timer |
| Warrior | Heroic Strike and Cleave queue tints, Slam pause/extend timing, and next-melee queue cancellation support |
| Paladin | Aura-aware seal breakpoint logic with an end-marker and a reseal marker for twist timing |
| Shaman | Lightning Bolt / Chain Lightning / Healing Wave / Lesser Healing Wave / Chain Heal weave markers with per-family toggles |
| UI | Collapsible config sections, texture browsers, class-color palettes, border/background controls, lock/unlock drag support, and the Test Bars preview |

> CurseForge pages are easiest to read when they stick to standard Markdown tables, lists, inline code, and screenshots.
> This README avoids relying on Mermaid diagrams so the same content stays portable across CurseForge and GitHub.
> If you want diagrams, render them to PNG or SVG and embed the image instead of depending on a live diagram renderer.

## Key features

- All melee classes: Warrior, Rogue, Paladin, Shaman, Druid, and Hunter
- Hunter auto shot with `GetSpellCooldown(75)` + ranged-speed sync for the ranged timer, plus ranged-haste-aware fallback resync when `UnitRangedDamage()` is temporarily unavailable, a separate latency-aware 0.5s Auto Shot / Multi-Shot cast window, movement safety feedback that turns green when you stop before the breakpoint, a black threshold line showing when the cast window begins, and a dedicated 10px Auto Shot / Multi-Shot cast bar beneath the ranged timer
- Dual-wield tracking with independent MH and OH timers
- NMA detection for Heroic Strike, Cleave, Maul, and Raptor Strike
- Warrior queue colors for Heroic Strike, Cleave, and Slam so the MH bar clearly shows which special is queued
- Haste rescaling when weapon speed changes mid-swing
- Parry haste handling
- Extra attack suppression for Sword Spec and Windfury
- Druid form reset handling
- Ret Paladin seal breakpoint line that shows the actual strike-edge end marker plus a latency-aware reseal point on twist seals, with the full seal list from `docs/spellIds.md` covered by aura-name fallback and the breakpoint lines clamped above the bar texture
- Shaman weave assist for Lightning Bolt, Chain Lightning, Healing Wave, Lesser Healing Wave, and Chain Heal breakpoints, with color-coded family markers that stay above the MH bar texture and can be disabled individually
- Default MH / OH / ranged bar colors now follow your class color until you pick a custom color
- Customizable bars, separate MH/OH and ranged textures, glow/opaque indicator mode, compact spark settings with a 4px default spark width, alpha-enabled color pickers, configurable bar background tint and opacity, adjustable bar border color and thickness, widened drag hitboxes for easier bar movement, visibility, lock state, and the new Test Bars preview via `/sst`, `/super`, or `/superswingtimer`
- Toggle MH / OH / ranged bars plus the shaman weave helper and its family controls from the config panel or Blizzard's Interface Options → AddOns list
- Collapse or expand the major config sections so the `/sst` panel stays easier to scan while you tune textures, colors, timing, and weave settings, with stable row groups that keep the panel rendering cleanly
- Texture picker: bar and ranged texture rows now stay focused on bar-style textures from Blizzard, SharedMedia, WeakAuras, and installed addon media packs, while the spark and shaman weave spark rows open a dedicated thumbnail browser seeded with the WeakAuras `Square_FullWhite` preset surfaced as `Normal`.

## Timing model

| Situation | What you see | Why it matters |
| --- | --- | --- |
| Auto Shot / Multi-Shot | A dedicated 0.5s hunter cast bar under the ranged timer, derived from the end of the ranged cycle hidden cast window, plus the ranged cooldown bar itself | Shows the stop-to-fire window near cycle end so you can hold still to fire, then move after the shot without clipping the next cycle |
| Heroic Strike / Cleave | MH bar tint changes to show the queued next-melee attack | Shows the queued state and helps you cancel or preserve rage before the hit lands |
| Slam | MH bar pauses and resumes instead of behaving like a next-melee queue ability | Preserves Slam's unique pause/extend mechanic |
| Shaman weave | Small breakpoint markers stay above the MH bar fill | Makes the cast breakpoint readable without covering the swing bar |

## Texture sources

| Source | Used for | Notes |
| --- | --- | --- |
| Blizzard | Bar textures | Built-in skins are always available |
| SharedMedia | Bar / ranged textures | Any installed SharedMedia pack shows up automatically |
| WeakAuras media | Spark and weave thumbnail browsers | `Square_FullWhite` is surfaced as `Normal` in the picker |
| Installed addon packs | Extra texture catalogs | Bar-style textures are auto-discovered when the pack exposes them |

## Installation

1. Download the latest release ZIP from [GitHub Releases](https://github.com/ssdeanx/SuperSwingTimer/releases/latest)
2. Extract the archive into your AddOns folder so the final path looks like:

   `World of Warcraft\_classic_\Interface\AddOns\SuperSwingTimer\`

3. Log in and play

## Usage

Bars appear automatically in combat. The ranged bar for Hunters also appears when auto-shot mode starts, and the smaller Auto Shot / Multi-Shot cast bar appears beneath it only for the fixed hidden cast window (`ns.CAST_WINDOW`), not for the full ranged cooldown cycle.

| Bar | Default | Meaning |
| --- | --- | --- |
| Ranged | Black | Auto Shot cooldown |
| Ranged | Green | Safe stop before the cast-window breakpoint |
| Ranged | Red | Cast window - you are still moving |
| Hunter Cast | Ranged color | Auto Shot / Multi-Shot cast bar beneath the ranged timer |
| Main Hand | Black | MH swing cooldown |
| Off Hand | Black | OH swing cooldown |

The main commands are `/sst`, `/super`, and `/superswingtimer`. `/swang` remains as a legacy alias.

## Class support

| Class | Bars | Special |
| --- | --- | --- |
| Hunter | Ranged + MH + cast bar | Auto Shot cooldown sync, 0.5s cast window, movement clipping protection with green/red safe-stop feedback, and a dedicated Auto Shot / Multi-Shot cast bar |
| Warrior | MH + OH | Heroic Strike, Cleave, and Slam handling |
| Rogue | MH + OH | Dual-wield tracking |
| Paladin | MH | Seal breakpoint line |
| Enhancement Shaman | MH + OH | Weave assist for LB, CL, HW, LHW, and CH breakpoints with spell-haste fallback support (`UnitSpellHaste` → `GetSpellHaste`) |
| Feral Druid | MH | Form label and form reset support |
| Mage / Priest / Warlock | None | No auto-attack bars |

## Configuration

Type `/sst`, `/super`, or `/superswingtimer` to open the config panel.

| Command | Action |
| --- | --- |
| `/sst` | Open or close the config panel |
| `/super` | Open or close the config panel |
| `/superswingtimer` | Open or close the config panel |
| `/sst reset` | Restore default settings |
| `/sst help` | Show command help |

## Config panel options

- Show or hide the main-hand, off-hand, and ranged bars
- Enable or disable the shaman weave assist and individual spell families
- Adjust bar, ranged, spark, and weave-spark textures; choose from Blizzard, SharedMedia, WeakAuras, and installed addon media packs; tune layers, sizes, alpha, and the tiny upper/lower weave markers that follow spell haste; the spark / weave spark defaults are intentionally slim and clamp to the host bar height, and the breakpoint overlays now live on a dedicated overlay frame so they stay above the bar fill without relying on hover-sensitive HIGHLIGHT layering
- Switch indicator glow between a bright additive style and a more opaque blend
- Toggle minimal mode, lock / unlock bars, tune the bar border size, and run the temporary Test Bars preview
- Change colors for the bar background, bar border, MH, OH, ranged, and the paladin seal breakpoint line, or keep MH / OH / ranged on class colors while still adjusting opacity from the color picker
- Labels sit above the controls in `/sst`, the rows are clickable, and hover tooltips explain what each setting does; the right-side checkbox, dropdown, or editable number field is the control for each row

## Feedback

Found a bug or want a feature? Open an issue at:
[GitHub Issues](https://github.com/ssdeanx/SuperSwingTimer/issues)

## Changelog

See `CHANGELOG.md` for the release history.
