# WeakAuras API Helpers

## Core WeakAuras helpers

WeakAuras exposes helper functions and reusable data for custom trigger and action code.

### `WA_GetUnitBuff(unit, spellIdOrName)`

Returns buff information for a unit.

```lua
local name, icon, count, _, _, duration, expirationTime = WA_GetUnitBuff("player", 47440)
```

### `WA_GetUnitDebuff(unit, spellIdOrName)`

Returns debuff information for a unit.

```lua
local name, icon, count, _, _, duration, expirationTime = WA_GetUnitDebuff("target", 233496)
```

### `WA_IterateGroupMembers()`

Iterates party/raid members safely for group scanning.

```lua
for unit in WA_IterateGroupMembers() do
  -- check each raid/party unit
end
```

### `WA_ClassColorName(unit, fontSize)`

Returns a class-colored name string for display purposes.

```lua
local className = WA_ClassColorName("player", 14)
```

### `WeakAuras.ScanEvents(eventName, ...)`

Raises a custom event inside WeakAuras. Use it with custom event triggers.

```lua
WeakAuras.ScanEvents(aura_env.customEventName, aura_env.id)
```

#### Safety notes

- Avoid reusing the same custom event name across unrelated auras.
- If you duplicate an aura template, make sure the name is unique per instance.
- Use `aura_env.id` in the event payload to distinguish the target aura.

Example:

```lua
if event == aura_env.customEventName then
  local id = ...
  if id ~= aura_env.id then
    return false
  end
  return true
end
```

### `WeakAuras.CustomValues`

A shared table that can be used for cross-aura communication.

```lua
WeakAuras.CustomValues = WeakAuras.CustomValues or {}
WeakAuras.CustomValues.myValue = 123
```

```lua
local currentValue = WeakAuras.CustomValues.myValue
```

Use this when you need to pass values between auras or maintain global state without polluting the global namespace.

### Useful WoW API helpers for WeakAuras

WeakAuras custom code often uses World of Warcraft’s API directly.

- `GetSpellCooldown(spellID)` — cooldown start and duration
- `GetSpellCharges(spellID)` — charge count and cooldown info
- `UnitPower(unit, powerType)` — resource current value
- `UnitPowerMax(unit, powerType)` — resource maximum value
- `UnitHealth(unit)` — current health
- `UnitHealthMax(unit)` — maximum health
- `UnitExists(unit)` — unit existence check
- `UnitAffectingCombat(unit)` — combat status
- `UnitName(unit)` — unit name lookup
- `UnitTokenFromGUID(guid)` — convert GUID to unit token
- `GetTime()` — current time for duration tracking

## Custom event parsing patterns

### Combat log triggers

`COMBAT_LOG_EVENT_UNFILTERED` is the core event for combat log parsing.

```lua
function(event, ...)
  if event ~= "COMBAT_LOG_EVENT_UNFILTERED" then
    return false
  end

  local _, subEvent, _, sourceGUID, sourceName, _, _, destGUID, destName, _, _, spellID = ...

  if subEvent == "SPELL_DAMAGE" and spellID == 12345 then
    return true, {
      show = true,
      changed = true,
      spellName = "Example"
    }
  end

  return false
end
```

### Custom event queueing

Debounce noisy streams by queueing a custom event.

```lua
function aura_env.queue()
  if aura_env.timer and not aura_env.timer:IsCancelled() then
    aura_env.timer:Cancel()
  end

  aura_env.timer = C_Timer.NewTimer(0.1, function()
    WeakAuras.ScanEvents(aura_env.customEventName, aura_env.id)
  end)
end
```

### `C_Timer.NewTimer(seconds, callback)`

Use this WoW API helper for delayed processing.

```lua
aura_env.timer = C_Timer.NewTimer(3, function()
  WeakAuras.ScanEvents(aura_env.customEventName, aura_env.id)
end)
```
