# Season of Discovery (SoD) Mechanics

## Architecture & Isolation
- All SoD-specific logic is strictly isolated in `SuperSwingTimer_SoD.lua`.
- Gated by `ns.isSoD` check (Classic Era build with SoD active).

## Tracked Spells & Runes
- Comprehensive rune classification across 9 classes (`ns.SOD_TRACKED_SPELLS`).
- Shaman: Maelstrom Weapon (`408505`), Lava Lash, Molten Blast, Way of Earth.
- Warrior: Sudden Death (`440114`) Execute proc alerts, Raging Blow, Flagellation.
- Paladin: Sheath of Light, Art of War, Crusader Strike.
- Rogue: Shadowstrike, Quick Draw, Between the Eyes.
- Druid: Sunfire, Wild Strikes, Savage Roar, Starsurge.
- Hunter: Chimera Shot, Flanking Strike, Beast Mastery.

## Aura Handling
- `ns.GetSoDAuraData` parses modern/SoD aura payloads safely without leaking globals or assuming fixed tuple lengths.

## Related Memories
- Main architecture map: `mem:core`
- Shaman weaving: `mem:weaving`
- Class modules: `mem:class_systems`
