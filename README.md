# Super Swing Timer

Melee and ranged swing timer for World of Warcraft Classic and TBC.

Super Swing Timer tracks white-hit swing timers across main hand, off hand, and ranged attacks. It is tuned for Classic/TBC mechanics such as next-melee-attack abilities, dual-wield desync, parry haste, extra-attack suppression, haste rescaling, druid form resets, ret paladin seal-breakpoint timing, and shaman weave breakpoints.

## Key features

- All melee classes: Warrior, Rogue, Paladin, Shaman, Druid, and Hunter
- Hunter auto shot with `GetSpellCooldown(75)` + ranged-speed sync, a latency-aware 0.5s cast window, movement safety feedback that turns green when you stop before the breakpoint, a black threshold line showing when the cast window begins, and a dedicated 10px Auto Shot / Multi-Shot cast bar beneath the ranged timer
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
- Customizable bars, separate MH/OH and ranged textures, glow/opaque indicator mode, compact spark settings with a 4px default spark width, alpha-enabled color pickers, configurable bar background tint and opacity, adjustable bar border color and thickness, visibility, lock state, and the new Test Bars preview via `/sst`, `/super`, or `/superswingtimer`
- Toggle MH / OH / ranged bars plus the shaman weave helper and its family controls from the config panel or Blizzard's Interface Options → AddOns list
- Collapse or expand the major config sections so the `/sst` panel stays easier to scan while you tune textures, colors, timing, and weave settings, with stable row groups that keep the panel rendering cleanly
- Texture picker: bar and ranged texture rows now stay focused on bar-style textures from Blizzard, SharedMedia, WeakAuras, and installed addon media packs, while the spark and shaman weave spark rows open a dedicated thumbnail browser seeded with the WeakAuras `Square_FullWhite` preset surfaced as `Normal`.

## Installation

1. Download the latest release ZIP from [GitHub Releases](https://github.com/ssdeanx/SuperSwingTimer/releases/latest)
2. Extract the archive into your AddOns folder so the final path looks like:

   `World of Warcraft\_classic_\Interface\AddOns\SuperSwingTimer\`

3. Log in and play

## Usage

Bars appear automatically in combat. The ranged bar for Hunters also appears when auto-shot mode starts, and the smaller Auto Shot / Multi-Shot cast bar appears beneath it while those shots are active.

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
| Enhancement Shaman | MH + OH | Weave assist for LB, CL, HW, LHW, and CH breakpoints |
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
