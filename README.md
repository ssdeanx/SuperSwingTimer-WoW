# Super Swing Timer

Melee, ranged, and current-target enemy swing timer for World of Warcraft Classic and TBC (including Anniversary Edition).

Super Swing Timer tracks white-hit swing timers across main hand, off hand, ranged attacks, and your current hostile target. It is tuned for Classic/TBC mechanics such as next-melee-attack abilities, dual-wield desync, parry haste, extra-attack suppression, haste rescaling, druid form resets, warrior Shield Block duration timing, rogue Sinister Strike end-window timing, a Rogue energy-tick helper plus Slice and Dice upkeep bar, ret paladin seal-breakpoint timing, shaman weave breakpoints, and current-target enemy swing detection, plus a Ravage opener cue for Cat Form druids. The current timing model keeps swing motion on a `GetTime()`-aligned precise clock, applies cached latency only to predictive windows such as Auto Shot safe-stop timing, rogue Sinister Strike queue guidance, and weave clip math, keeps Maul, Heroic Strike, Cleave, and Raptor Strike on separate next-attack paths, and avoids mixed clock-domain drift.

Status: final-prep / feature-complete. The active roadmap phases are closed, and any remaining ideas are tracked in the roadmap's archived / future wishlist section instead of being left open in the shipped checklist.

## At a glance

| Area | What it covers |
| --- | --- |
| Hunter | Auto Shot cooldown sync, a hunter-linked MH bar that only appears for real melee swings or queued Raptor Strike, a yellow Raptor queue tint, configurable movement-safe / late colors, Anniversary-safe auto-repeat state gating, Feign Death ranged reset handling, Readiness refresh handling for Rapid Fire, and a dedicated hunter bar that covers the hidden Auto Shot window plus real Steady Shot / Aimed Shot casts with clip-safety feedback (now accounts for the TBC 0.5s Steady Shot grace period for accurate safe/unsafe timing) and a live latency end slice |
| Warrior | Heroic Strike and Cleave queue tints with yellow/green MH bar coloring, Slam pause/extend timing with a live Slam cast bar above the MH bar, a Shield Block duration bar above the MH stack with configurable height and color, an Execute-phase `EXEC` badge on the rage bar, and next-melee queue cancellation support |
| Druid | Feral MH timing, form reset support, Maul queue tinting, Omen of Clarity glow, Ravage opener cue, a Power Shift duration bar, and an energy-tick timing bar |
| Paladin | Aura-aware seal breakpoint logic with a proportional-width red twist zone (right-anchored, matching Rogue Sinister Strike pattern) for Seal of Command, Blood, and Martyr timing, plus a GCD-aware reseal marker |
| Shaman | Lightning Bolt / Chain Lightning / Healing Wave / Lesser Healing Wave / Chain Heal weave markers with per-family toggles |
| UI | Collapsible config sections, top Quick Controls columns for Visibility + Key Colors, compact non-overlapping quick rows that now push later sections down automatically, slimmer 15px main bars with an 8px OH default, a 3-4px Rogue Slice and Dice bar above MH, a single 4px Rogue energy-tick helper to the left of MH, a scrolling full-preview bar-texture picker, mouse-wheel scrolling in `/sst`, class-color palettes, border/background controls, lock/unlock drag support, a red default enemy bar toggle, and the Test Bars preview |

> CurseForge pages are easiest to read when they stick to standard Markdown tables, lists, inline code, and screenshots.
> This README avoids relying on Mermaid diagrams so the same content stays portable across CurseForge and GitHub.
> If you want diagrams, render them to PNG or SVG and embed the image instead of depending on a live diagram renderer.

## Key features

- All melee classes: Warrior, Rogue, Paladin, Shaman, Druid, and Hunter
- Current-target enemy swing bar that tracks your selected hostile target from `PLAYER_TARGET_CHANGED`, `UnitGUID("target")`, `UnitAttackSpeed("target")`, and hostile `SWING_DAMAGE` / `SWING_MISSED` combat-log events, while ignoring off-hand hits so the single enemy bar stays readable
- Hunter auto shot with `GetSpellCooldown(75)` + ranged-speed sync for the ranged timer, plus ranged-haste-aware fallback resync when `UnitRangedDamage()` is temporarily unavailable; while the cooldown API is active, live ranged resync also reuses the cooldown start anchor instead of only stretching duration mid-cycle; the addon now also cross-checks real Hunter auto-repeat state through Blizzard's current spell API before letting `SPELL_UPDATE_COOLDOWN` seed a new cycle, treats mounted Hunters as not auto-repeating, blocks cooldown re-anchors while the bar is pinned in the red moving window, and no longer hard-resets the current ranged timer on transient stop events; the shared swing clock stays on a `GetTime()`-aligned `GetTimePreciseSec()` / `GetTime()` path while cached latency is applied only to predictive windows, the Hunter MH bar is anchored to the ranged stack and only appears for a live melee swing or a queued Raptor Strike, queued Raptor now uses its own yellow next-attack tint without sharing Warrior or Druid queue state, melee handoffs no longer leave the ranged bar stuck full red after the last ranged cycle expires, and the dedicated 10px hunter bar beneath ranged now resolves live Steady Shot / Aimed Shot casts through a Classic-safe `UnitCastingInfo()` spell-name-first path while tinting those casts by whether they still fit before the next Auto Shot and shading the final latency slice at the end of the bar
- Off-hand timing now requires a real off-hand weapon speed instead of fabricating hidden OH cycles, and the OH frame is reused cleanly across equipment swaps
- Dual-wield tracking with independent MH and OH timers
- NMA detection for Heroic Strike, Cleave, Maul, and Raptor Strike
- Warrior and Druid queue colors for Heroic Strike, Cleave, and Maul so the MH bar clearly shows which special is queued, while the spark remains on its own manual/default color for readability and Maul queue state stays isolated from the Warrior queue-cleanup path
- Warrior Shield Block now has its own slim duration bar above the MH stack, and Druid Ravage now gets an opener-ready amber cue when Cat Form Ravage is actually usable on the current target
- Haste rescaling when weapon speed changes mid-swing, while keeping live swing anchors on the addon's aligned precise timer path so bars do not lead early from alternate CLEU clock remapping
- Parry haste handling using the standard Classic 40% reduction with a 20% remaining-time floor
- Extra attack suppression for Sword Spec and Windfury
- Druid form reset handling
- Ret Paladin seal breakpoint line that shows the actual strike-edge end marker plus a GCD/swing-aware reseal point on twist seals, with the full seal list from `docs/spellIds.md` covered by aura-name fallback and the breakpoint lines clamped above the bar texture
- Shaman weave assist for Lightning Bolt, Chain Lightning, Healing Wave, Lesser Healing Wave, and Chain Heal breakpoints, with color-coded family timing, small breakpoint spell icons that stay above and below the MH bar texture, resolve spell names through the shared spell-info wrapper, and stay hidden when Minimal Mode or the weave toggle disables them
- Optional class colors for MH / OH / ranged bar fills, with the spark color kept independent so queue tints and white/manual spark colors stay readable, turning class colors off restoring the saved manual bar colors instead of leaving the class tint behind, and live bar text now flipping to black with a white outlined backing while class colors are enabled for better readability on bright fills
- Rogue latency-adjusted main-hand end window that turns red on the final slice of the MH bar so Combat Rogues can press Sinister Strike into the swing landing and more reliably fire it immediately after the main-hand hit, while the spark stays layered above that red slice for readability, the default alpha stays a little softer for clearer bar reading, and the helper now falls back to the live MH weapon speed whenever the MH bar itself is visible
- Rogue Slice and Dice helper: a slim duration bar above the MH bar that uses the shared bar texture path, matches MH width, tracks the active Slice and Dice buff in real time from a Classic-safe helpful-aura read (`UnitBuff` / `UnitAura` signature tolerant), rechecks its aura state on a short throttle for smoother live updates, and stays hidden whenever the buff is down or the MH bar itself is hidden
- Rogue energy-tick helper: one slim 4px vertical bar to the left of the MH bar that fills on the Classic/TBC 2-second energy-tick cadence, re-syncs from likely natural energy gains, and keeps the swing timer stack cleaner than the earlier paired test helper
- Customizable bars, separate MH/OH and ranged textures, glow/opaque indicator mode, compact spark settings with a 3px default spark width, a slight forward-biased pixel-snapped spark edge so the thin spark reads closer to the live fill edge, alpha-enabled color pickers, configurable bar background tint and opacity, adjustable bar border color and thickness, widened drag hitboxes plus real drag handlers for easier bar movement, reset-to-default position restore, visibility, lock state, and the Test Bars preview via `/sst`, `/super`, or `/superswingtimer`
- Toggle MH / OH / ranged / enemy bars, the Rogue Sinister Strike cue, the Rogue Slice and Dice bar, the Rogue Energy Tick checkbox, plus the shaman weave helper and its family controls from the config panel or Blizzard's Interface Options → AddOns list
- Collapse or expand the major config sections so the `/sst` panel stays easier to scan while you tune textures, colors, timing, and weave settings, with stable row groups that keep the panel rendering cleanly
- Texture picker: the MH/OH and ranged texture rows now open a scrolling full-preview list that keeps each texture stretched behind its label, stays focused on bar-style textures from Blizzard, WeakAuras, and installed LibSharedMedia media packs, and keeps the spark / shaman weave spark rows on the dedicated thumbnail browser seeded with the WeakAuras `Square_FullWhite` preset surfaced as `Normal`.

## Timing model

| Situation | What you see | Why it matters |
| --- | --- | --- |
| Auto Shot / Multi-Shot / Steady Shot | A dedicated hunter cast bar under the ranged timer: Auto Shot locks to the same end-of-cycle hidden cast window as the ranged red/green zone, BC Classic instant Multi-Shot shots use a short stored shot window when no live cast data is available, and real Steady Shot / Aimed Shot casts now use a Classic-safe `UnitCastingInfo()` lookup, safe/unsafe tinting (accounting for the 0.5s TBC Steady Shot grace period where Auto Shot can fire during the last 0.5s without clipping), and a latency slice on the trailing edge | Shows the stop-to-fire window near cycle end without Auto Shot bounce, keeps instant Multi-Shot feedback visible on Classic/TBC clients that do not expose a normal live cast, and gives Hunters a live read on whether a cast is likely to clip the next Auto Shot (now with correct TBC grace-period timing) plus how much end-of-cast latency cushion remains |
| Rogue Sinister Strike | A red tail slice on the MH bar that scales with latency and uses a softer default alpha | Highlights the best press-into-the-landing window so Sinister Strike can fire immediately after the main-hand hit more reliably without overpowering the spark/readout |
| Rogue Slice and Dice | A slim bar above the MH frame that uses the main bar width and tracks the buff's remaining time | Gives Rogues a clean real-time read on SnD upkeep without cluttering the main swing bar |
| Rogue energy tick | One 4px vertical bar to the left of the MH bar that shows the next likely energy pulse cadence | Gives Rogues a quick read on the next energy tick without adding extra clutter or touching the authoritative swing timers |
| Paladin seal-twist zone | A proportional-width red fill zone anchored to the right end of the MH bar for Seal of Command, Blood, and Martyr, with the zone width matching `(0.4s + latency) / swingDuration * barWidth`, plus a separate thin GCD/swing-aware reseal marker line | Makes the safe twist-before-landing period immediately visible as a red right-hand tail (same visual pattern as the Rogue Sinister Strike cue), with the reseal marker showing where to press the next seal |
| Queued next-melee tint | MH bar tint changes to show the queued next-melee attack while the spark keeps its manual/default tint | Shows the queued state and helps you cancel or preserve rage before the hit lands without losing the spark contrast |
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

Opening `/sst` previews the bars for setup, but the live gameplay bars remain combat-driven and stay hidden out of combat unless you are using preview/test mode. Hidden or idle live bars reset to an empty state so entering combat no longer shows stale full bars from the previous cycle. The ranged bar for Hunters also appears when auto-shot mode starts, and the smaller hunter cast bar appears beneath it for the fixed Auto Shot hidden cast window (`ns.CAST_WINDOW` plus cached latency) instead of the full ranged cooldown cycle; BC Classic instant Multi-Shot shots now seed that helper with a short stored shot window when the client does not expose a live cast, while real Steady Shot / Aimed Shot casts use a Classic-safe `UnitCastingInfo()` path plus a trailing latency slice that scales with the current cached latency and cast duration.

| Bar | Default | Meaning |
| --- | --- | --- |
| Ranged | Black | Auto Shot cooldown |
| Ranged | Green by default | Safe stop before the cast-window breakpoint (configurable) |
| Ranged | Red by default | Cast window - you are still moving (configurable) |
| Enemy | Red | Current hostile target main-hand swing cooldown |
| Hunter Cast | Ranged color | Auto Shot hidden-window bar, stored short Multi-Shot shot bar, or real Steady Shot / Aimed Shot cast progress beneath the ranged timer, with a trailing latency slice on live cast-time shots |
| Main Hand | Black | MH swing cooldown |
| Off Hand | Black | OH swing cooldown |

The main commands are `/sst`, `/super`, and `/superswingtimer`. `/swang` remains as a legacy alias.

## Class support

| Class | Bars | Special |
| --- | --- | --- |
| Hunter | Ranged + MH + cast bar | Auto Shot cooldown sync, a ranged-linked MH bar that only appears for live melee / queued Raptor Strike, yellow Raptor queue tint, movement clipping protection with green/red safe-stop feedback, real auto-repeat gating for cleaner cycle starts, and a dedicated hunter helper bar for the hidden Auto Shot window plus real Steady Shot / Aimed Shot casts with live no-clip feedback and a latency end slice |
| Warrior | MH + OH + Shield Block | Heroic Strike, Cleave, Shield Block timing, and Slam handling |
| Rogue | MH + OH + Rogue helpers | Dual-wield tracking plus a latency-adjusted MH end-window cue for Sinister Strike timing, a slim Slice and Dice duration bar directly above MH with Classic-safe helpful-aura parsing, a dedicated Adrenaline Rush duration/cooldown bar with adjustable height, Blade Flurry and Cold Blood badges, a Rogue energy-cap warning tint, and a single vertical energy-tick helper to the left of MH |
| Paladin | MH | Seal breakpoint line plus a small Reckoning stack badge |
| Enhancement Shaman | MH + OH | Weave assist for LB, CL, HW, LHW, and CH breakpoints with spell-haste fallback support (`UnitSpellHaste` → `GetSpellHaste`), Windfury ICD tracking, and a Flurry stack badge |
| Feral Druid | MH | Form label, form reset support, Maul queue tinting, Omen of Clarity glow, Ravage opener cue, a Power Shift duration bar under MH, and an energy-tick timing bar to the left of MH, both with configurable size and show/hide toggles |
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

- Use a top Quick Controls section with a clearly labeled left `Visibility` column and right `Key Colors` column so the most-used visibility and bar-color settings stay together, with compact non-overlapping row spacing that fits the Rogue/Hunter quick options cleanly
- The `/sst` color swatches now use clearer flat preview tiles so the chosen bar colors are easier to read at a glance while configuring the addon
- The main `/sst` panel now supports mouse-wheel scrolling, keeps later sections pushed below the real Quick Controls height, and labels preview mode more clearly so setup feels closer to a Blizzard-quality options panel
- Show or hide the main-hand, off-hand, ranged, enemy, Rogue Sinister Strike cue, the Rogue Slice and Dice bar, and the Rogue energy-tick helper as appropriate for your class
- Show or hide the Warrior Shield Block timer, Druid Ravage opener cue, Druid Power Shift bar, Druid Energy Tick bar, and Rogue Adrenaline Rush bar from the class-specific quick rows alongside the existing Rogue, Hunter, and shaman helpers; every helper bar also has an adjustable height or width slider in the MH/OH section of `/sst`
- Enable or disable the shaman weave assist and individual spell families
- Adjust bar, ranged, spark, and weave-spark textures; the bar and ranged rows now use a scrolling full-preview list for bar-style media from Blizzard, WeakAuras, and LibSharedMedia packs, while spark textures still use the thumbnail browser; tune layers, sizes, alpha, and the tiny upper/lower weave markers that follow spell haste; the stock bars now default to a slimmer 15px height with the OH bar derived down to 8px, the Rogue Slice and Dice helper clamped to a slim 3-4px profile above MH, the spark default height matches that slimmer profile and clamps to the host bar, and the breakpoint overlays now live on a dedicated overlay frame so they stay above the bar fill without relying on hover-sensitive HIGHLIGHT layering
- Switch weave-indicator glow between a bright additive style and a more opaque blend; the main swing spark stays on a color-preserving blend so white/manual spark tints stay visually accurate
- Toggle minimal mode, lock / unlock bars, tune the bar border size, and run the Test Bars preview; Reset Defaults now also restores the saved anchor positions
- Change colors for the bar background, bar border, MH, OH, ranged, Rogue Sinister cue, Rogue Slice and Dice helper, Rogue tick bar, Shield Block timer, Ravage cue, Auto Shot safe/unsafe feedback, enemy, spark, and the paladin seal breakpoint line; MH / OH / ranged can use class colors while the Rogue cue, Rogue Slice and Dice helper, Rogue energy tick, Shield Block timer, Ravage cue, Auto Shot feedback, enemy bar, and spark keep their own separate manual/default tint and opacity
- Labels sit above the controls in `/sst`, the rows are clickable, and hover tooltips explain what each setting does; the right-side checkbox, dropdown, or editable number field is the control for each row

## Feedback

Found a bug or want a feature? Open an issue at:
[GitHub Issues](https://github.com/ssdeanx/SuperSwingTimer/issues)

## Changelog

See `CHANGELOG.md` for the release history.
