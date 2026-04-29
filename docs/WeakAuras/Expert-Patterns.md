# WeakAuras Expert Patterns

## Advanced Custom Trigger Patterns

### Multi-Buff Tracking

Track the first active buff from a list and display its name, icon, stacks, and duration.

```lua
function(event, unit)
  if event ~= "UNIT_AURA" or unit ~= "player" then
    return false
  end

  local buffsToTrack = {
    {id = 47440, name = "Battle Shout"},
    {id = 47436, name = "Commanding Shout"},
    {id = 48162, name = "Prayer of Fortitude"}
  }

  for _, buff in ipairs(buffsToTrack) do
    local name, icon, count, _, _, duration, expirationTime = WA_GetUnitBuff("player", buff.id)
    if name then
      return true, {
        show = true,
        changed = true,
        name = name,
        icon = icon,
        stacks = count or 1,
        duration = duration,
        expirationTime = expirationTime,
        buffID = buff.id
      }
    end
  end

  return false
end
```

### Cooldowns with Charges

Handle spells that use charges and display both current charges and timer information.

```lua
function(event)
  if event ~= "SPELL_UPDATE_COOLDOWN" and event ~= "SPELL_UPDATE_CHARGES" then
    return false
  end

  local spellID = 49028 -- Death Coil example
  local currentCharges, maxCharges, start, duration = GetSpellCharges(spellID)

  if not currentCharges then
    local cdStart, cdDuration = GetSpellCooldown(spellID)
    if cdDuration and cdDuration > 0 then
      return true, {
        show = true,
        changed = true,
        charges = 0,
        maxCharges = 1,
        duration = cdDuration,
        expirationTime = cdStart + cdDuration
      }
    end
    return false
  end

  return true, {
    show = true,
    changed = true,
    charges = currentCharges,
    maxCharges = maxCharges,
    duration = duration,
    expirationTime = start + duration,
    ready = currentCharges == maxCharges
  }
end
```

### Raid Debuff Scanner

Scan raid members for a boss debuff, returning the first target found.

```lua
function(event, unit)
  if event ~= "UNIT_AURA" then
    return false
  end

  local debuffs = {28169, 28522, 29998}

  local function checkUnit(unitID)
    for _, debuffID in ipairs(debuffs) do
      local name, icon, count, _, _, duration, expirationTime = WA_GetUnitDebuff(unitID, debuffID)
      if name then
        return {
          unit = unitID,
          unitName = WA_ClassColorName(unitID, 12),
          debuffName = name,
          debuffIcon = icon,
          stacks = count or 1,
          duration = duration,
          expirationTime = expirationTime,
          spellID = debuffID
        }
      end
    end
    return nil
  end

  if unit then
    local result = checkUnit(unit)
    if result then
      return true, {
        show = true,
        changed = true,
        unpack(result)
      }
    end
  end

  for unitID in WA_IterateGroupMembers() do
    local result = checkUnit(unitID)
    if result then
      return true, {
        show = true,
        changed = true,
        unpack(result)
      }
    end
  end

  return false
end
```

### Combat Log Parsing

Parse `COMBAT_LOG_EVENT_UNFILTERED` for precise fight state, then keep the aura visible for a window.

```lua
function(event, ...)
  if event ~= "COMBAT_LOG_EVENT_UNFILTERED" then
    return false
  end

  local _, subEvent, _, sourceGUID, sourceName, _, _, destGUID, destName, _, _, spellID, spellName = ...

  if subEvent == "SPELL_DAMAGE" and spellID == 47450 then
    aura_env.lastMSTime = GetTime()
    aura_env.lastMSTarget = destName
    return true, {
      show = true,
      changed = true,
      targetName = destName,
      spellName = spellName,
      timestamp = GetTime()
    }
  end

  if aura_env.lastMSTime and (GetTime() - aura_env.lastMSTime) > 3 then
    aura_env.lastMSTime = nil
    return false
  end

  if aura_env.lastMSTime then
    return true, {
      show = true,
      changed = false,
      targetName = aura_env.lastMSTarget,
      spellName = "Mortal Strike"
    }
  end

  return false
end
```

### Custom Event Queueing

Use a timer to debounce noisy event streams and release a single custom event.

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

Then in the trigger:

```lua
function(event, ...)
  if event == "COMBAT_LOG_EVENT_UNFILTERED" then
    -- parse combat log, update aura_env data
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
      changed = true
    }
  end

  return false
end
```

### Bridging a swing-timer feed into WeakAuras

When an addon or helper library already emits swing-timer events, keep the aura trigger event-driven and map the payload into `aura_env.state`.
This is the cleanest way to mirror the addon’s start / update / stop flow, and it also gives you a place to carry a ranged safe-state flag
when the cast window turns green because the player stopped before the breakpoint.

```lua
-- On Init
function()
  aura_env.state = aura_env.state or {}
  aura_env.state.show = false
  aura_env.state.hand = nil
  aura_env.state.safe = false
end
```

```lua
-- Custom Trigger
function(event, hand, duration, expirationTime, safe)
  if event ~= "SWING_TIMER_START"
  and event ~= "SWING_TIMER_UPDATE"
  and event ~= "SWING_TIMER_STOP" then
    return false
  end

  -- Only track the hand you care about.
  if hand ~= "ranged" and hand ~= "mainhand" and hand ~= "offhand" then
    return false
  end

  if event == "SWING_TIMER_STOP" then
    return false
  end

  return true, {
    show = true,
    changed = true,
    hand = hand,
    duration = duration,
    expirationTime = expirationTime,
    progressType = "timed",
    safe = safe == true,
  }
end
```

#### Connection notes

- If your source addon already calls `WeakAuras.ScanEvents("SWING_TIMER_START", ...)`, you can listen for those events directly.
- If you need to forward the data to another aura, create a unique custom event name in `aura_env` and re-emit the payload with `WeakAuras.ScanEvents`.
- Keep the `safe` flag in the state table if you want the display to react to the green ranged safe-stop state.
- Use `aura_env.id` when you create your own custom relay event so duplicated auras do not collide.

## Performance Best Practices

- Avoid `Status` or custom frame polling when event-driven triggers will do.
- Filter events precisely; for example, only inspect `UNIT_AURA` when `unit == "player"`.
- Use `load` conditions to disable auras in irrelevant zones, specs, or combat states.
- Keep hot-path code short and simple.
- Cache repeated results outside loops.
- Use `WeakAuras.ScanEvents` rather than forcing repeated trigger refreshes.
- Prefer built-in WeakAuras triggers where possible; custom code should fill gaps, not replace everything.

## Debugging and Development Workflow

- Write WeakAuras code in an external editor for indentation and syntax highlighting.
- Use a Lua formatter such as StyLua if available.
- Test in-game after small incremental changes.
- Use unique custom event names to avoid collision.
- Prefer external editor development over in-game editing: it reduces syntax mistakes and improves maintainability.
- Keep the aura state deterministic and explicit.
- Use `WeakAuras.CustomValues` for cross-aura coordination when `aura_env` is not enough.

## Expert-Level Tips

- When building complex auras, divide responsibility:
  - trigger handles visibility and state updates
  - actions handle side effects
  - custom text handles display formatting
- Use `aura_env.state` in custom text and conditions to access the current trigger state.
- When tracking many targets or group members, scan only the changed unit first, then fallback to group scanning.
- Avoid global variables; use `aura_env` or `WeakAuras.CustomValues`.
- Document your own custom event names and shared helper functions.
