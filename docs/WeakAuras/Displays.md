# WeakAuras Displays

## Display Types

WeakAuras supports several display types. Choose the display type that best fits the information you want to show.

- **Icon**: best for single buffs, debuffs, cooldowns, and ability alerts.
- **Progress Bar**: ideal for timers, resource tracking, and cooldown progress.
- **Text**: good for dynamic strings, numeric values, and custom messages.
- **Texture**: used for custom graphics, overlays, and shaped progress.
- **Model**: renders in-game 3D models when supported.
- **Group**: organizes multiple displays into structured layouts.

## Common Display Properties

Displays share common properties:

- Position and size
- Scale and rotation
- Color and transparency
- Border, background, and glow
- Text font, size, and formatting
- Animation start, main, and finish effects

### Position and Size

Use anchors to position a display relative to the screen, other WeakAuras, or UI frames.

```lua
region:SetWidth(width)
region:SetHeight(height)
region:ClearAllPoints()
region:SetPoint("CENTER", UIParent, "CENTER", xOffset, yOffset)
```

### Display State

A display can be:

- hidden
- showing
- loading
- in error state

WeakAuras only renders the display when the trigger returns `true` and the aura is active.

## Display Data from Triggers

Trigger code can send display-specific data to the region.

```lua
return true, {
  show = true,
  changed = true,
  icon = "Interface\\Icons\\Spell_Nature_Bloodlust",
  duration = 40,
  expirationTime = GetTime() + 40,
  value = 100,
  total = 100,
  stacks = 1,
  name = "Bloodlust"
}
```

Common display fields:

- `show`
- `changed`
- `duration`
- `expirationTime`
- `value`
- `total`
- `stacks`
- `icon`
- `name`

## Sub-Regions

Displays can include sub-regions such as:

- text overlays
- borders
- glows
- backgrounds
- tick markers
- additional textures

Use sub-regions to add layered visual cues without creating extra auras.

## Performance and Best Practices

- Use the smallest display type that fits the need.
- Avoid updating display properties every frame when not necessary.
- Group related displays to reduce overhead.
- Disable or hide displays when they are not needed.
- Prefer event-based triggers over frame-update or status polling.

## Example Patterns

### Icon Display

An icon display is a classic choice for buff/debuff tracking.

```lua
-- Icon with cooldown overlay for a spell
return true, {
  show = true,
  changed = true,
  icon = "Interface\\Icons\\Spell_Holy_BlessingOfProtection",
  duration = 30,
  expirationTime = GetTime() + 30
}
```

### Progress Bar

A bar display is perfect for cooldowns and resource thresholds.

```lua
return true, {
  show = true,
  changed = true,
  value = currentPower,
  total = maxPower,
  progressType = "static"
}
```
