# Super Swing Timer

Melee and ranged swing timer for World of Warcraft Classic and TBC.

Super Swing Timer tracks white-hit swing timers across main hand, off hand, and ranged attacks. It is tuned for Classic/TBC mechanics such as next-melee-attack abilities, dual-wield desync, parry haste, extra-attack suppression, haste rescaling, druid form resets, ret paladin seal twisting, and shaman weave breakpoints.

## Key features

- All melee classes: Warrior, Rogue, Paladin, Shaman, Druid, and Hunter
- Hunter auto shot with a 0.5s cast window and movement safety feedback
- Dual-wield tracking with independent MH and OH timers
- NMA detection for Heroic Strike, Cleave, Maul, and Raptor Strike
- Haste rescaling when weapon speed changes mid-swing
- Parry haste handling
- Extra attack suppression for Sword Spec and Windfury
- Druid form reset handling
- Ret Paladin seal-twist timing overlay
- Shaman weave assist for Lightning Bolt, Chain Lightning, Healing Wave, Lesser Healing Wave, and Chain Heal breakpoints
- Customizable bars, textures, spark settings, colors, alpha, visibility, and lock state via /sst
- Toggle MH / OH / ranged bars and the shaman weave helper from the config panel

- Texture picker: the `/sst` texture selector is an in-addon dropdown showing `[category] label` entries (SharedMedia + Blizzard fallbacks) — no browser popup required.

## Installation

1. Download the latest release ZIP from [GitHub Releases](https://github.com/AcidBomb/SuperSwingTimer/releases/latest)
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

The main command is `/sst`. Legacy aliases `/swang` and `/swangthang` remain available for migration.

## Class support

| Class | Bars | Special |
| --- | --- | --- |
| Hunter | Ranged + MH | 0.5s cast window and movement clipping protection |
| Warrior | MH + OH | Heroic Strike, Cleave, and Slam handling |
| Rogue | MH + OH | Dual-wield tracking |
| Paladin | MH | Seal-twist overlay |
| Enhancement Shaman | MH + OH | Weave assist for LB, CL, HW, LHW, and CH breakpoints |
| Feral Druid | MH | Form label and form reset support |
| Mage / Priest / Warlock | None | No auto-attack bars |

## Configuration

Type `/sst` to open the config panel.

| Command | Action |
| --- | --- |
| `/sst` | Open or close the config panel |
| `/sst reset` | Restore default settings |
| `/sst help` | Show command help |

## Config panel options

- Show or hide the main-hand, off-hand, and ranged bars
- Enable or disable the shaman weave assist text
- Adjust bar and spark textures, layers, sizes, and alpha
- Toggle minimal mode and bar locking
- Change colors for MH, OH, ranged, and seal-twist overlays

## Feedback

Found a bug or want a feature? Open an issue at:
[GitHub Issues](https://github.com/AcidBomb/SuperSwingTimer/issues)

## Changelog

See `CHANGELOG.md` for the release history.
