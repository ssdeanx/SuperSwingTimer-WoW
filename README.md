# Super Swing Timer

Melee, ranged, and current-target enemy swing timer for World of Warcraft Classic and TBC (including Anniversary Edition).

Super Swing Timer tracks white-hit swing timers across main hand, off hand, ranged attacks, and your current hostile target. It is tuned for Classic/TBC mechanics such as next-melee-attack abilities, dual-wield desync, parry haste, extra-attack suppression, haste rescaling, druid form resets, rogue Sinister Strike end-window timing, a test Rogue energy-tick helper, ret paladin seal-breakpoint timing, shaman weave breakpoints, and current-target enemy swing detection. The current timing model keeps swing motion on a `GetTime()`-aligned precise clock, applies cached latency only to predictive windows such as Auto Shot safe-stop timing, rogue Sinister Strike queue guidance, and weave clip math, keeps Maul, Heroic Strike, Cleave, and Raptor Strike on separate next-attack paths, and avoids mixed clock-domain drift.

## At a glance

| Area | What it covers |
| --- | --- |
| Hunter | Auto Shot cooldown sync, a separate 0.5s Auto Shot / Multi-Shot cast window, configurable movement-safe / unsafe colors, and a dedicated cast bar anchored under the ranged timer |
| Warrior | Heroic Strike and Cleave queue tints, Slam pause/extend timing, and next-melee queue cancellation support |
| Paladin | Aura-aware seal breakpoint logic with an end-marker and a reseal marker for twist timing |
| Shaman | Lightning Bolt / Chain Lightning / Healing Wave / Lesser Healing Wave / Chain Heal weave markers with per-family toggles |
| UI | Collapsible config sections, top quick-control columns for toggles + bar colors, compact non-overlapping quick rows, slimmer 15px main bars with a 10px OH default, a 5px Rogue energy test bar that matches the visible melee-stack heights, a scrolling full-preview bar-texture picker, class-color palettes, border/background controls, lock/unlock drag support, a red default enemy bar toggle, and the Test Bars preview |

> CurseForge pages are easiest to read when they stick to standard Markdown tables, lists, inline code, and screenshots.
> This README avoids relying on Mermaid diagrams so the same content stays portable across CurseForge and GitHub.
> If you want diagrams, render them to PNG or SVG and embed the image instead of depending on a live diagram renderer.

## Key features

- All melee classes: Warrior, Rogue, Paladin, Shaman, Druid, and Hunter
- Current-target enemy swing bar that tracks your selected hostile target from `PLAYER_TARGET_CHANGED`, `UnitGUID("target")`, `UnitAttackSpeed("target")`, and hostile `SWING_DAMAGE` / `SWING_MISSED` combat-log events, while ignoring off-hand hits so the single enemy bar stays readable
- Hunter auto shot with `GetSpellCooldown(75)` + ranged-speed sync for the ranged timer, plus ranged-haste-aware fallback resync when `UnitRangedDamage()` is temporarily unavailable; while the cooldown API is active, live ranged resync also reuses the cooldown start anchor instead of only stretching duration mid-cycle; the shared swing clock now stays on a `GetTime()`-aligned `GetTimePreciseSec()` / `GetTime()` path while cached latency is applied only to the Auto Shot safe-stop window, a separate latency-aware 0.5s Auto Shot / Multi-Shot cast window, configurable safe/unsafe window colors, a black threshold line showing when the cast window begins, and a dedicated 10px hunter cast bar beneath the ranged timer that now locks Auto Shot to the same end-of-cycle hidden window as the red/green ranged feedback while Multi-Shot continues to use live cast timing
- Off-hand timing now requires a real off-hand weapon speed instead of fabricating hidden OH cycles, and the OH frame is reused cleanly across equipment swaps
- Dual-wield tracking with independent MH and OH timers
- NMA detection for Heroic Strike, Cleave, Maul, and Raptor Strike
- Warrior and Druid queue colors for Heroic Strike, Cleave, and Maul so the MH bar clearly shows which special is queued, while the spark remains on its own manual/default color for readability and Maul queue state stays isolated from the Warrior queue-cleanup path
- Haste rescaling when weapon speed changes mid-swing, while keeping live swing anchors on the addon's aligned precise timer path so bars do not lead early from alternate CLEU clock remapping
- Parry haste handling using the standard Classic 40% reduction with a 20% remaining-time floor
- Extra attack suppression for Sword Spec and Windfury
- Druid form reset handling
- Ret Paladin seal breakpoint line that shows the actual strike-edge end marker plus a GCD/swing-aware reseal point on twist seals, with the full seal list from `docs/spellIds.md` covered by aura-name fallback and the breakpoint lines clamped above the bar texture
- Shaman weave assist for Lightning Bolt, Chain Lightning, Healing Wave, Lesser Healing Wave, and Chain Heal breakpoints, with color-coded family timing, small breakpoint spell icons that stay above and below the MH bar texture, resolve spell names through the shared spell-info wrapper, and stay hidden when Minimal Mode or the weave toggle disables them
- Optional class colors for MH / OH / ranged bar fills, with the spark color kept independent so queue tints and white/manual spark colors stay readable, and turning class colors off restores the saved manual bar colors instead of leaving the class tint behind
- Rogue latency-adjusted main-hand end window that turns red on the final slice of the MH bar so Combat Rogues can press Sinister Strike into the swing landing and more reliably fire it immediately after the main-hand hit
- Rogue test energy-tick helper: a 5px vertical bar to the left of the MH/OH stack that fills upward on the Classic/TBC 2-second energy cadence, matches the visible melee-bar heights (25px at the stock 15px MH + 10px OH profile), and re-syncs itself when likely natural energy gains are observed
- Customizable bars, separate MH/OH and ranged textures, glow/opaque indicator mode, compact spark settings with a 3px default spark width, a slight forward-biased pixel-snapped spark edge so the thin spark reads closer to the live fill edge, alpha-enabled color pickers, configurable bar background tint and opacity, adjustable bar border color and thickness, widened drag hitboxes plus real drag handlers for easier bar movement, reset-to-default position restore, visibility, lock state, and the Test Bars preview via `/sst`, `/super`, or `/superswingtimer`
- Toggle MH / OH / ranged / enemy bars, the Rogue Sinister Strike cue, the Rogue energy tick helper, plus the shaman weave helper and its family controls from the config panel or Blizzard's Interface Options → AddOns list
- Collapse or expand the major config sections so the `/sst` panel stays easier to scan while you tune textures, colors, timing, and weave settings, with stable row groups that keep the panel rendering cleanly
- Texture picker: the MH/OH and ranged texture rows now open a scrolling full-preview list that keeps each texture stretched behind its label, stays focused on bar-style textures from Blizzard, WeakAuras, and installed LibSharedMedia media packs, and keeps the spark / shaman weave spark rows on the dedicated thumbnail browser seeded with the WeakAuras `Square_FullWhite` preset surfaced as `Normal`.

## Timing model

| Situation | What you see | Why it matters |
| --- | --- | --- |
| Auto Shot / Multi-Shot | A dedicated hunter cast bar under the ranged timer: Auto Shot locks to the same end-of-cycle hidden cast window as the ranged red/green zone, while Multi-Shot keeps its live cast timing | Shows the stop-to-fire window near cycle end without Auto Shot bounce, while the ranged bar and cast helper stay on the same latency-aware clock |
| Rogue Sinister Strike | A red tail slice on the MH bar that scales with latency | Highlights the best press-into-the-landing window so Sinister Strike can fire immediately after the main-hand hit more reliably |
| Rogue energy tick | A 5px vertical bar to the left of the MH/OH stack that matches the visible melee-bar heights and fills upward over the observed 2-second tick cadence | Gives Rogues a quick read on the next likely energy pulse without touching the authoritative swing timers |
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
| Ranged | Green by default | Safe stop before the cast-window breakpoint (configurable) |
| Ranged | Red by default | Cast window - you are still moving (configurable) |
| Enemy | Red | Current hostile target main-hand swing cooldown |
| Hunter Cast | Ranged color | Auto Shot hidden-window bar or live Multi-Shot cast bar beneath the ranged timer |
| Main Hand | Black | MH swing cooldown |
| Off Hand | Black | OH swing cooldown |

The main commands are `/sst`, `/super`, and `/superswingtimer`. `/swang` remains as a legacy alias.

## Class support

| Class | Bars | Special |
| --- | --- | --- |
| Hunter | Ranged + MH + cast bar | Auto Shot cooldown sync, 0.5s cast window, movement clipping protection with green/red safe-stop feedback, and a dedicated Auto Shot / Multi-Shot cast bar |
| Warrior | MH + OH | Heroic Strike, Cleave, and Slam handling |
| Rogue | MH + OH | Dual-wield tracking plus a latency-adjusted MH end-window cue for Sinister Strike timing and a test vertical energy tick helper |
| Paladin | MH | Seal breakpoint line |
| Enhancement Shaman | MH + OH | Weave assist for LB, CL, HW, LHW, and CH breakpoints with spell-haste fallback support (`UnitSpellHaste` → `GetSpellHaste`) |
| Feral Druid | MH | Form label, form reset support, and Maul queue tinting |
| Mage / Priest / Warlock | None | No auto-attack bars |

Enemy bar support is not class-restricted: if you have a hostile target selected, the addon can track that target's main-hand swing timer with the red default enemy bar.

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

- Use a top Quick Controls section with a left toggle column and right color-swatch column so the most-used visibility and bar-color settings stay together, with compact non-overlapping row spacing that fits the Rogue/Hunter quick options cleanly
- The `/sst` color swatches now use clearer flat preview tiles so the chosen bar colors are easier to read at a glance while configuring the addon
- Show or hide the main-hand, off-hand, ranged, enemy, Rogue Sinister Strike cue, and Rogue energy tick helper windows as appropriate for your class
- Enable or disable the shaman weave assist and individual spell families
- Adjust bar, ranged, spark, and weave-spark textures; the bar and ranged rows now use a scrolling full-preview list for bar-style media from Blizzard, WeakAuras, and LibSharedMedia packs, while spark textures still use the thumbnail browser; tune layers, sizes, alpha, and the tiny upper/lower weave markers that follow spell haste; the stock bars now default to a slimmer 15px height with the OH bar derived down to 10px, the spark default height matches that slimmer profile and clamps to the host bar, and the breakpoint overlays now live on a dedicated overlay frame so they stay above the bar fill without relying on hover-sensitive HIGHLIGHT layering
- Switch weave-indicator glow between a bright additive style and a more opaque blend; the main swing spark stays on a color-preserving blend so white/manual spark tints stay visually accurate
- Toggle minimal mode, lock / unlock bars, tune the bar border size, and run the Test Bars preview; Reset Defaults now also restores the saved anchor positions
- Change colors for the bar background, bar border, MH, OH, ranged, Rogue Sinister cue, Rogue energy tick helper, Auto Shot safe/unsafe feedback, enemy, spark, and the paladin seal breakpoint line; MH / OH / ranged can use class colors while the Rogue cue, Rogue energy tick helper, Auto Shot feedback, enemy bar, and spark keep their own separate manual/default tint and opacity
- Labels sit above the controls in `/sst`, the rows are clickable, and hover tooltips explain what each setting does; the right-side checkbox, dropdown, or editable number field is the control for each row

## Feedback

Found a bug or want a feature? Open an issue at:
[GitHub Issues](https://github.com/ssdeanx/SuperSwingTimer/issues)

## Changelog

See `CHANGELOG.md` for the release history.
