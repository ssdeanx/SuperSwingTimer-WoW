# Visual Context - `/sst` Config UI

## Visual Context Update (2026-05-31 - Druid quick-control correction)

- The `/sst` Quick Controls panel now includes a Druid-specific `Druid Energy Tick` checkbox and matching `Druid Energy Tick` color swatch when the player class is DRUID.
- The Appearance section also exposes a `Druid Tick Width` slider for the restored Cat-form energy helper.
- Current intended Druid live visual scope is now explicitly narrow: Cat-form energy tick on the left of MH plus Maul queue tint on MH; old Tiger's Fury / Faerie Fire / Mangle / Rip helper rows are not part of the supported live UI.

## Purpose

Only visual go in this file, Do not fill it up with useless bloat, and update, make more visuals, including using ascii, all mermaid diagrams, and other visual tools to make this as visual as possible, and less text, and more visuals, diagrams, ascii art, tables, charts, and graphs.

## High-level ASCII layout (current)

```bash
+----------------------------------------------------------------------------------+
| Super Swing Timer                                                       [X]      |
| Subtitle / preview behavior note                                                 |
|----------------------------------------------------------------------------------|
| Quick Controls (2 compact columns)                                               |
|----------------------------------------------------------------------------------|
| Visibility Column                      Key Colors Column                         |
| [checkbox rows]                             [swatch rows]                        |
| - Use Class Colors                          - MH/OH/Ranged/Enemy                 |
| - Show MH/OH/Ranged/Enemy                   - Hunter / Rogue / Warrior           |
| - Lock Bars                                 - Shaman Lightning Shield             |
| - Class quick toggles                       - Paladin/Seal/Windfury/etc           |
|----------------------------------------------------------------------------------|
| Appearance                                                                       |
|----------------------------------------------------------------------------------|
| Bar Width                                                                        |
| [---------------------------- slider track ---------------------------] [ 240 ]  |
| 100                                                                       400    |
|                                                                                  |
| Bar Height                                                                       |
| [---------------------------- slider track ---------------------------] [  14 ]  |
| 10                                                                         40    |
|                                                                                  |
| MH/OH Bar Texture                                   [preview / picker control]   |
| MH/OH Texture Layer                                 [dropdown]                   |
| Ranged Bar Texture                                  [preview / picker control]   |
| Spark Texture                                       [path box] [browse]          |
| Spark Alpha                                         [slider] [value]             |
| Spark Color                                         [swatch]                     |
| Spark Layer                                         [dropdown]                   |
| Spark Width                                         [slider] [value]             |
| Spark Height                                        [slider] [value]             |
| Bar Background Color                                [swatch]                     |
| Bar Background Alpha                                [slider] [value]             |
| Indicator Glow Mode                                 [dropdown]                   |
| Bar Border Color                                    [swatch]                     |
| Bar Border Size                                     [slider] [value]             |
|----------------------------------------------------------------------------------|
| Shaman Weave Assist                                                              |
|----------------------------------------------------------------------------------|
| Show Weave Assist [x]                                                            |
| Weave Marker Layer [dropdown]                                                    |
| Weave Spark Texture [path] [browse]                                              |
| Weave Spark Width/Height [slider + value]                                        |
| Weave Triangle Top/Bottom [path rows]                                            |
| Weave Triangle Size/Gap/Alpha [slider rows]                                      |
|                                                                                    |
| Quick Controls (Shaman class rows)                                               |
| [x] Lightning Shield Tracker                                                     |
| [x] Flame Shock Bar                                                              |
| [swatch] Lightning Shield                                                        |
| [swatch] Windfury ICD                                                            |
|----------------------------------------------------------------------------------|
| General Behavior                                                                 |
|----------------------------------------------------------------------------------|
| ...                                                                              |
|----------------------------------------------------------------------------------|
| Weave Families                                                                   |
|----------------------------------------------------------------------------------|
| ...                                                                              |
|----------------------------------------------------------------------------------|
|                                   [Reset Defaults]                               |
+----------------------------------------------------------------------------------+
```

## Quick Controls layout intent

```bash
Quick Controls

LEFT COLUMN                              RIGHT COLUMN
----------------------------------       ----------------------------------
Use Class Colors                         MH Color
Show Main Hand                           OH Color
Show Off Hand                            Ranged Color
Show Ranged                              Enemy Color
Show Enemy Bar                           Hunter / Rogue / Warrior quick colors
Lock Bars                                Shaman / Paladin / class quick colors
Shaman: Lightning Shield Tracker         Lightning Shield swatch
Shaman: Flame Shock Bar                  Windfury ICD swatch

(Keep a small extra gap between the column title line and the first compact row.)
```

## Shaman helper mini-map

```text
                (above MH)
         +-----------------------+
         |   Flame Shock 6px     |   <- toggle: Flame Shock Bar
         +-----------------------+
         |        MH BAR         |
         +-----------------------+
   [|||]                           <- toggle: Lightning Shield Tracker
                                    single-bar: height = MH
         +-----------------------+
         |        OH BAR         |
         +-----------------------+
                                    dual-wield: height = MH + gap + OH
```
