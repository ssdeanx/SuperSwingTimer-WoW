# Super Swing Timer

Melee and ranged swing timer for World of Warcraft Classic and TBC.

Super Swing Timer tracks white-hit swing timers across main hand, off hand, and ranged attacks. It is tuned for Classic/TBC mechanics such as next-melee-attack abilities, dual-wield desync, parry haste, extra-attack suppression, haste rescaling, druid form resets, ret paladin seal-breakpoint timing, and shaman weave breakpoints.

## Key features

- All melee classes: Warrior, Rogue, Paladin, Shaman, Druid, and Hunter
- Hunter auto shot with `GetSpellCooldown(75)` + ranged-speed sync, a latency-aware 0.5s cast window, movement safety feedback, and a black threshold line showing when the cast window begins
- Dual-wield tracking with independent MH and OH timers
- NMA detection for Heroic Strike, Cleave, Maul, and Raptor Strike
- Haste rescaling when weapon speed changes mid-swing
- Parry haste handling
- Extra attack suppression for Sword Spec and Windfury
- Druid form reset handling
- Ret Paladin seal breakpoint line that shows the end-of-swing twist point on the base seal and the earlier reseal point on the twist seal, both latency-aware, with the full seal list from `docs/spellIds.md` covered by aura-name fallback
- Shaman weave assist for Lightning Bolt, Chain Lightning, Healing Wave, Lesser Healing Wave, and Chain Heal breakpoints, with color-coded family markers you can disable individually
- Default MH / OH / ranged bar colors now follow your class color until you pick a custom color
- Customizable bars, separate MH/OH and ranged textures, glow/opaque indicator mode, spark settings, colors, alpha, visibility, and lock state via `/sst`, `/super`, or `/superswingtimer`
- Toggle MH / OH / ranged bars plus the shaman weave helper and its family controls from the config panel or Blizzard's Interface Options → AddOns list
- Texture picker: the in-addon dropdown now shows texture previews plus `[category] label` entries (SharedMedia + Blizzard fallbacks) — no browser popup required.

## Installation

1. Download the latest release ZIP from [GitHub Releases](https://github.com/ssdeanx/SuperSwingTimer/releases/latest)
2. Extract the archive into your AddOns folder so the final path looks like:

   `World of Warcraft\_classic_\Interface\AddOns\SuperSwingTimer\`

3. Log in and play

## Usage

Bars appear automatically in combat. The ranged bar for Hunters also appears when auto-shot mode starts.

| Bar | Default | Meaning |
| --- | --- | --- |
| Ranged | Black | Auto Shot cooldown |
| Ranged | Red | Cast window - do not move |
| Main Hand | Black | MH swing cooldown |
| Off Hand | Black | OH swing cooldown |

The main commands are `/sst`, `/super`, and `/superswingtimer`. `/swang` remains as a legacy alias.

## Class support

| Class | Bars | Special |
| --- | --- | --- |
| Hunter | Ranged + MH | Auto Shot cooldown sync, 0.5s cast window, and movement clipping protection |
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
- Adjust bar, ranged, and spark textures, layers, sizes, alpha, and the tiny upper/lower weave markers that follow spell haste
- Switch indicator glow between a bright additive style and a more opaque blend
- Toggle minimal mode and bar locking
- Change colors for MH, OH, ranged, and the paladin seal breakpoint line, or keep MH / OH / ranged on class colors
- Labels sit above the controls in `/sst`, and the rows themselves are clickable so texture, cycle, toggle, and color changes are easier to hit

## Feedback

Found a bug or want a feature? Open an issue at:
[GitHub Issues](https://github.com/ssdeanx/SuperSwingTimer/issues)

## Changelog

See `CHANGELOG.md` for the release history.
