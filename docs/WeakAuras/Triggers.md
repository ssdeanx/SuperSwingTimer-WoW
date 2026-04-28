# WeakAuras Triggers

## Trigger Types

WeakAuras triggers determine when an aura should show. The most common types are:

- **Aura / Buff / Debuff** — standard unit aura checks.
- **Status** — periodic polling for health, power, combat state, etc.
- **Event(s)** — respond to specific game events such as `UNIT_AURA` or `SPELL_UPDATE_COOLDOWN`.
- **Custom** — run Lua code to decide visibility.
- **Automatic** — built-in event-driven detection for common spell conditions.

## Custom Trigger Structure

Custom triggers are the most flexible option.

### Basic Pattern

```lua
function(event, ...)
  -- event: name of the event that fired
  -- ...: event-specific arguments

  local shouldShow = false

  if event == "UNIT_AURA" then
    shouldShow = WA_GetUnitBuff("player", "Battle Shout") ~= nil
  end

  if shouldShow then
    return true, {
      show = true,
      changed = true,
      value = 1,
      name = "Battle Shout"
    }
  end

  return false
end
```

### Return Values

Custom triggers can return:

- `true` to show the aura
- `false` to hide the aura
- `true, stateTable` to show with extra state

When returning a state table:

- always include `show = true` when you want the aura visible
- include `changed = true` when the displayed state changed
- use `changed = false` when the aura is still visible and only non-visual state is updated

The state table can include:

- `show`
- `changed`
- `value`
- `total`
- `duration`
- `expirationTime`
- `icon`
- `name`
- `stacks`
- `progressType`

### Event Handling

In an event-based trigger, the first argument is the event name.

```lua
function(event, unit, ...)
  if event == "UNIT_AURA" and unit == "player" then
    local name = WA_GetUnitBuff("player", "Arcane Intellect")
    return name ~= nil
  end

  if event == "PLAYER_TARGET_CHANGED" then
    return UnitExists("target")
  end

  return false
end
```

### Status Type

Use `Status` when continuous polling is acceptable, but avoid it unless necessary.

```lua
function()
  local health = UnitHealth("player")
  local maxHealth = UnitHealthMax("player")
  local percent = (health / maxHealth) * 100

  if percent < 35 then
    return true, {
      show = true,
      changed = true,
      health = percent
    }
  end

  return false
end
```

## Duration Info

For timer displays, use the Duration Info function to provide the duration and expiration time.

```lua
function()
  local _, _, _, _, _, duration, expirationTime = WA_GetUnitBuff("player", 47440)
  if duration and duration > 0 then
    return duration, expirationTime
  end

  local start, cdDuration = GetSpellCooldown(47440)
  if cdDuration and cdDuration > 0 then
    return cdDuration, start + cdDuration
  end

  return 0, 0
end
```

## Untrigger

Untrigger code defines when an aura should hide.

```lua
function()
  local name = WA_GetUnitBuff("player", "Battle Shout")
  if not name then
    return true
  end

  if not UnitAffectingCombat("player") then
    return true
  end

  return false
end
```

If no untrigger is provided, WeakAuras hides the aura automatically when the trigger returns `false`.

## Custom Event Triggers

Custom events let you raise your own event names and respond to them in trigger code.

```lua
function(event, ...)
  if event == "COMBAT_LOG_EVENT_UNFILTERED" then
    -- parse combat log data
    return false
  end

  if event == aura_env.customEventName then
    local id = ...
    if id == aura_env.id then
      return true, {
        show = true,
        changed = true
      }
    end
  end

  return false
end
```

## Recommended Event List

- `UNIT_AURA`
- `UNIT_POWER_UPDATE`
- `SPELL_UPDATE_COOLDOWN`
- `SPELL_UPDATE_CHARGES`
- `COMBAT_LOG_EVENT_UNFILTERED`
- `PLAYER_TARGET_CHANGED`
- `UNIT_HEALTH`
- `UNIT_SPELLCAST_SUCCEEDED`
- `UNIT_SPELLCAST_START`

## Load Conditions

WeakAuras supports load conditions that limit when auras are active. Use them to keep auras disabled when they are irrelevant.

Common load conditions:

- class or specialization
- talent or covenant
- zone or instance type
- group type and size
- combat state
- player role

Use load conditions whenever the aura should only be active in one spec, zone, or encounter.

## Performance Tips

- Use event triggers instead of per-frame polling.
- Filter unit events by `unit == "player"` or the specific unit you care about.
- Avoid expensive loops on every event when you can update only changed state.
- Cache spell IDs, names, and lookup values outside tight loops.
- Prefer built-in triggers whenever possible and reserve custom code for the hard cases.
