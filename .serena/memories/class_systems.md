# Class Modules & Visual Systems

## Unified Player Power Bar
- Single frame `SuperSwingTimerPlayerPowerBar` (`ns.playerPowerBar`) across all physical classes.
- Standardized height: 10px (`ns.POWER_BAR_HEIGHT = 10`), anchored beneath lowest active swing bar.
- Tracks: Warrior (Rage), Rogue (Energy), Druid (dynamic Rage/Energy/Mana per shapeshift), Paladin/Shaman/Hunter (Mana).
- Warrior Execute indicator: texture 5308 with red pulse border glow at $\le 20\%$ target HP; text label hidden.

## Target Debuff Duration Bars
- Anchored above main-hand bar for active player debuffs (Sunder, Rend, Flame Shock, Mangle, Serpent Sting, Rupture, etc.).
- Icon placed strictly outside to the left (`RIGHT`, `bar`, `LEFT`, -2, 0) with `SetTexCoord(0.07, 0.93, 0.07, 0.93)`.
- Bar aligns 100% with swing bar width at $X=0$.

## Buff & Cooldown Icons
- Timer text centered strictly above the icon (`"BOTTOM", icon, "TOP", 0, 2`, 12pt outline). Icon face completely clear of timer text.
- Stack count text on bottom-right of icon face (`"BOTTOMRIGHT"`, 11pt outline, white text).
- Gold pulsing glow in last 4 seconds before expiration.

## Related Memories
- Main architecture map: `mem:core`
- UI and typography conventions: `mem:conventions`
- Hunter ranged engine: `mem:ranged_engine`
