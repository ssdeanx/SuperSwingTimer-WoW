# Visual Context - `/sst` Config UI

## Purpose

Only visual go in this file, Do not fill it up with useless bloat, and update, make more visuals, including using ascii, all mermaid diagrams, and other visual tools to make this as visual as possible, and less text, and more visuals, diagrams, ascii art, tables, charts, and graphs.

## High-level ASCII layout

```bash
+----------------------------------------------------------------------------------+
| Super Swing Timer                                                       [X]      |
| Subtitle / preview behavior note    (you have text from below in here)           |
|----------------------------------------------------------------------------------|
| Quick Controls         (you have text from below in here)                        |
|----------------------------------------------------------------------------------|
| Visibility Column (never see this row)                           Key Colors Column|
| [toggle row]                                [color row]                           |
| [toggle row]                                [color row]                           |
| [toggle row]                                [color row]                           |
|----------------------------------------------------------------------------------|
| Appearance              (you have text from below in here)                        |
|----------------------------------------------------------------------------------|
| Bar Width  (never see this row)                                                   |
| [---------------------------- slider track ---------------------------] [ 240 ]   |
| 100                                                                       400     |
|                                                                                  |
| Bar Height  (never see this row)                                                  |
| [---------------------------- slider track ---------------------------] [  14 ]   |
| 10                                                                         40     |
| (both these sections are not aligned correctly half is off page)                  |
| MH/OH Bar Texture                                   [preview / picker control]    |
| MH/OH Texture Layer                                 [dropdown]                    |
| Ranged Bar Texture                                  [preview / picker control]    |
| Spark Texture                                       [path box] [browse]           |
| Spark Alpha                                         [slider] [value]             |
| Spark Color                                         [swatch]                      |
| Spark Layer                                         [dropdown]                    |
| Spark Width                                         [slider] [value]             |
| Spark Height                                        [slider] [value]             |
| Bar Background Color                                [swatch]                      |
| Bar Background Alpha                                [slider] [value]             |
| Indicator Glow Mode                                 [dropdown]                    |
| Bar Border Color                                    [swatch]                      |
| Bar Border Size                                     [slider] [value]             |
|----------------------------------------------------------------------------------|
| Shaman Weave Assist   (you have text from below in here)                         |
|----------------------------------------------------------------------------------|
| ...    (always row text thats up ^)                                              |
|----------------------------------------------------------------------------------|
| General Behavior   (you have text from below in here)                            |
|----------------------------------------------------------------------------------|
| ...                                                                              |
|----------------------------------------------------------------------------------|
| Weave Families        (you have text from below in here)                         |
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
Class quick toggles                      Class quick colors
```
