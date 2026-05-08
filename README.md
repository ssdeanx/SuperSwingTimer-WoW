# Super Swing Timer

Melee and ranged swing timer for World of Warcraft Classic and TBC (including Anniversary Edition).

Super Swing Timer tracks white-hit swing timers across main hand, off hand, and ranged attacks. It is tuned for Classic/TBC mechanics such as next-melee-attack abilities, dual-wield desync, parry haste, extra-attack suppression, haste rescaling, druid form resets, ret paladin seal-breakpoint timing, and shaman weave breakpoints. The current timing model stays on the addon's latency-adjusted precise clock, keeps Maul, Heroic Strike, Cleave, and Raptor Strike on separate next-attack paths, and avoids alternate CLEU clock-domain remapping that can make live bars lead early.

## At a glance

| Area | What it covers |
| --- | --- |
| Hunter | Auto Shot cooldown sync, a separate 0.5s Auto Shot / Multi-Shot cast window, movement-safe green/red feedback, and a dedicated cast bar anchored under the ranged timer |
| Warrior | Heroic Strike and Cleave queue tints, Slam pause/extend timing, and next-melee queue cancellation support |
| Paladin | Aura-aware seal breakpoint logic with an end-marker and a reseal marker for twist timing |
| Shaman | Lightning Bolt / Chain Lightning / Healing Wave / Lesser Healing Wave / Chain Heal weave markers with per-family toggles |
| UI | Collapsible config sections, a scrolling full-preview bar-texture picker, class-color palettes, border/background controls, lock/unlock drag support, and the Test Bars preview |

> CurseForge pages are easiest to read when they stick to standard Markdown tables, lists, inline code, and screenshots.
> This README avoids relying on Mermaid diagrams so the same content stays portable across CurseForge and GitHub.
> If you want diagrams, render them to PNG or SVG and embed the image instead of depending on a live diagram renderer.

## Key features

- All melee classes: Warrior, Rogue, Paladin, Shaman, Druid, and Hunter
- Hunter auto shot with `GetSpellCooldown(75)` + ranged-speed sync for the ranged timer, plus ranged-haste-aware fallback resync when `UnitRangedDamage()` is temporarily unavailable, a separate latency-aware 0.5s Auto Shot / Multi-Shot cast window, movement safety feedback that turns green when you stop before the breakpoint, a black threshold line showing when the cast window begins, and a dedicated 10px hunter cast bar beneath the ranged timer that now locks Auto Shot to the same end-of-cycle hidden window as the red/green ranged feedback while Multi-Shot continues to use live cast timing
- Off-hand timing now requires a real off-hand weapon speed instead of fabricating hidden OH cycles, and the OH frame is reused cleanly across equipment swaps
- Dual-wield tracking with independent MH and OH timers
- NMA detection for Heroic Strike, Cleave, Maul, and Raptor Strike
- Warrior and Druid queue colors for Heroic Strike, Cleave, and Maul so the MH bar clearly shows which special is queued, while the spark remains on its own manual/default color for readability and Maul queue state stays isolated from the Warrior queue-cleanup path
- Haste rescaling when weapon speed changes mid-swing, while keeping live swing anchors on the addon's latency-aware timer path so bars do not lead early from alternate CLEU clock remapping
- Parry haste handling using the standard Classic 40% reduction with a 20% remaining-time floor
- Extra attack suppression for Sword Spec and Windfury
- Druid form reset handling
- Ret Paladin seal breakpoint line that shows the actual strike-edge end marker plus a GCD/swing-aware reseal point on twist seals, with the full seal list from `docs/spellIds.md` covered by aura-name fallback and the breakpoint lines clamped above the bar texture
- Shaman weave assist for Lightning Bolt, Chain Lightning, Healing Wave, Lesser Healing Wave, and Chain Heal breakpoints, with color-coded family markers that stay above the MH bar texture, resolve spell names through the shared spell-info wrapper, and stay hidden when Minimal Mode or the weave toggle disables them
- Optional class colors for MH / OH / ranged bar fills, with the spark color kept independent so queue tints and white/manual spark colors stay readable, and turning class colors off restores the saved manual bar colors instead of leaving the class tint behind
- Customizable bars, separate MH/OH and ranged textures, glow/opaque indicator mode, compact spark settings with a 4px default spark width, alpha-enabled color pickers, configurable bar background tint and opacity, adjustable bar border color and thickness, widened drag hitboxes plus real drag handlers for easier bar movement, reset-to-default position restore, visibility, lock state, and the Test Bars preview via `/sst`, `/super`, or `/superswingtimer`
- Toggle MH / OH / ranged bars plus the shaman weave helper and its family controls from the config panel or Blizzard's Interface Options → AddOns list
- Collapse or expand the major config sections so the `/sst` panel stays easier to scan while you tune textures, colors, timing, and weave settings, with stable row groups that keep the panel rendering cleanly
- Texture picker: the MH/OH and ranged texture rows now open a scrolling full-preview list that keeps each texture stretched behind its label, stays focused on bar-style textures from Blizzard, WeakAuras, and installed LibSharedMedia media packs, and keeps the spark / shaman weave spark rows on the dedicated thumbnail browser seeded with the WeakAuras `Square_FullWhite` preset surfaced as `Normal`.

## Timing model

| Situation | What you see | Why it matters |
| --- | --- | --- |
| Auto Shot / Multi-Shot | A dedicated hunter cast bar under the ranged timer: Auto Shot locks to the same end-of-cycle hidden cast window as the ranged red/green zone, while Multi-Shot keeps its live cast timing | Shows the stop-to-fire window near cycle end without Auto Shot bounce, while the ranged bar and cast helper stay on the same latency-aware clock |
| Heroic Strike / Cleave / Maul | MH bar tint changes to show the queued next-melee attack while the spark keeps its manual/default tint | Shows the queued state and helps you cancel or preserve rage before the hit lands without losing the spark contrast |
| Slam | MH bar pauses and resumes instead of behaving like a next-melee queue ability | Preserves Slam's unique pause/extend mechanic while keeping the raw swing anchor stable through the pause/extend step |
| Shaman weave | Small breakpoint markers stay above the MH bar fill | Makes the cast breakpoint readable without covering the swing bar |

## Texture sources

| Source | Used for | Notes |
| --- | --- | --- |
| Blizzard | Bar textures | Built-in fallback skins are always available in the scrolling bar-texture picker |
| SharedMedia | Bar / ranged textures | Any installed LibSharedMedia statusbar pack, including SharedMedia-Blizzard when present, shows up automatically |
| WeakAuras media | Spark and weave thumbnail browsers | `Square_FullWhite` is surfaced as `Normal` in the picker |
| Installed addon packs | Extra texture catalogs | Bar-style textures are auto-discovered when the pack exposes them |

## Installation

1. Download the latest release ZIP from [GitHub Releases](https://github.com/ssdeanx/SuperSwingTimer/releases/latest)
2. Extract the archive into your AddOns folder so the final path looks like:

   `World of Warcraft\_classic_\Interface\AddOns\SuperSwingTimer\`

3. Log in and play

## Usage

Bars appear automatically in combat. The ranged bar for Hunters also appears when auto-shot mode starts, and the smaller hunter cast bar appears beneath it for the fixed Auto Shot hidden cast window (`ns.CAST_WINDOW` plus cached latency) instead of the full ranged cooldown cycle; live Multi-Shot casts still use their normal cast timing.

| Bar | Default | Meaning |
| --- | --- | --- |
| Ranged | Black | Auto Shot cooldown |
| Ranged | Green | Safe stop before the cast-window breakpoint |
| Ranged | Red | Cast window - you are still moving |
| Hunter Cast | Ranged color | Auto Shot hidden-window bar or live Multi-Shot cast bar beneath the ranged timer |
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
| Feral Druid | MH | Form label, form reset support, and Maul queue tinting |
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
- Adjust bar, ranged, spark, and weave-spark textures; the bar and ranged rows now use a scrolling full-preview list for bar-style media from Blizzard, WeakAuras, and LibSharedMedia packs, while spark textures still use the thumbnail browser; tune layers, sizes, alpha, and the tiny upper/lower weave markers that follow spell haste; the spark / weave spark defaults are intentionally slim and clamp to the host bar height, and the breakpoint overlays now live on a dedicated overlay frame so they stay above the bar fill without relying on hover-sensitive HIGHLIGHT layering
- Switch weave-indicator glow between a bright additive style and a more opaque blend; the main swing spark stays on a color-preserving blend so white/manual spark tints stay visually accurate
- Toggle minimal mode, lock / unlock bars, tune the bar border size, and run the Test Bars preview; Reset Defaults now also restores the saved anchor positions
- Change colors for the bar background, bar border, MH, OH, ranged, spark, and the paladin seal breakpoint line; MH / OH / ranged can use class colors while the spark keeps its own separate manual/default tint and opacity
- Labels sit above the controls in `/sst`, the rows are clickable, and hover tooltips explain what each setting does; the right-side checkbox, dropdown, or editable number field is the control for each row

## Feedback

Found a bug or want a feature? Open an issue at:
[GitHub Issues](https://github.com/ssdeanx/SuperSwingTimer/issues)

## Changelog

See `CHANGELOG.md` for the release history.
