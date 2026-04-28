# WeakAuras Actions

## What are Actions?

Actions are code or effects that run when a WeakAura state changes. They are configured in the Actions tab and support several hooks:

- **On Init** — runs once when the aura is created or loaded.
- **On Show** — runs when the aura becomes active.
- **On Hide** — runs when the aura hides.
- **Custom** — can run on animation, start, and finish events.

Actions are useful for:

- initializing `aura_env` state
- starting or cancelling timers
- sending chat messages or alerts
- modifying display properties at runtime
- triggering secondary auras via `WeakAuras.ScanEvents`

## `aura_env` and Persistent State

`aura_env` is the persistent storage table for a WeakAura. Use it to store data that survives multiple trigger calls.

Example:

```lua
function()
  aura_env.customEventName = "MY_UNIQUE_EVENT_" .. aura_env.id
  aura_env.timer = nil
  aura_env.bySource = {}
end
```

### Why use `aura_env`?

- `aura_env` is isolated per aura
- it avoids global pollution
- it preserves state across trigger executions
- it is accessible from trigger, actions, and custom text functions

## Custom Actions and Events

Custom actions are often used with custom event queuing.

### Queueing a custom event

```lua
function aura_env.queue()
  if aura_env.timer then
    if not aura_env.timer:IsCancelled() then
      aura_env.timer:Cancel()
    end
    aura_env.timer = nil
  end

  aura_env.timer = C_Timer.NewTimer(3, function()
    WeakAuras.ScanEvents(aura_env.customEventName, aura_env.id)
  end)
end
```

This pattern is useful when:

- you receive a flood of high-frequency events
- you need to aggregate multiple combat log hits
- you want a short debounce before updating the aura

### Custom event trigger pattern

```lua
function(event, ...)
  if event == "COMBAT_LOG_EVENT_UNFILTERED" then
    -- parse relevant combat log args
    -- store values in aura_env, then queue the custom event
    aura_env.queue()
    return false
  end

  if event == aura_env.customEventName then
    local id = ...
    if id ~= aura_env.id then
      return false
    end

    aura_env.timer = nil
    return true, {
      show = true,
      changed = true,
      value = 1
    }
  end

  return false
end
```

## WeakAuras API Helpers

WeakAuras exposes helper functions for use inside custom code.

Common helpers:

- `WA_GetUnitBuff(unit, spellIdOrName)`
- `WA_GetUnitDebuff(unit, spellIdOrName)`
- `WA_IterateGroupMembers()`
- `WA_ClassColorName(unit, fontSize)`

Sometimes custom code uses global helpers from WeakAuras itself:

- `WeakAuras.ScanEvents(eventName, ...)`
- `WeakAuras.CustomValues`

> Note: `WeakAuras.ScanEvents` uses event names across all active auras, so avoid generic custom event names and always validate the payload using `aura_env.id`.

### Using `WeakAuras.CustomValues`

`WeakAuras.CustomValues` is a shared table that can be used by multiple auras to store and retrieve values.

```lua
WeakAuras.CustomValues = WeakAuras.CustomValues or {}
WeakAuras.CustomValues.myValue = 42
```

```lua
local currentValue = WeakAuras.CustomValues.myValue
```

This is most useful for cross-aura coordination when `aura_env` is not enough.

## Strong Action Patterns

### Initialize Unique Event Names

Use a unique event name per aura to avoid collisions:

```lua
function()
  aura_env.customEventName = "SOMETHING_UNIQUE_" .. aura_env.id
end
```

### Manage timers safely

Always cancel existing timers before replacing them.

```lua
if aura_env.timer and not aura_env.timer:IsCancelled() then
  aura_env.timer:Cancel()
end
```

### Print or announce safely

```lua
if aura_env.config.announce then
  SendChatMessage(message, "SAY")
else
  print(message)
end
```

## Display Control from Actions

Actions can also modify display state directly through `aura_env` values.

```lua
aura_env.lastTriggered = GetTime()
aura_env.state = aura_env.state or {}
aura_env.state.show = true
```

However, reliable display changes should still be driven by trigger returns.

## Custom Text and Dynamic Output

Custom text functions can read trigger state through `aura_env.state`.

```lua
function()
  if aura_env.state and aura_env.state.show then
    return string.format("%s: %d", aura_env.state.name or "Spell", aura_env.state.stacks or 0)
  end
  return ""
end
```

## Expert Action Guidelines

- Use On Init for setup only.
- Use On Show for side effects when the aura becomes visible.
- Use On Hide for cleanup.
- Avoid heavy logic in actions; keep the trigger responsible for state.
- Use `WeakAuras.ScanEvents` for event-driven refresh rather than forcing manual updates.
- Keep custom event names unique and deterministic.
