$null = [Console]::In.ReadToEnd()

$systemMessage = @"
Load and follow `.github/skills/wow-classic-lua/SKILL.md` at the start of this session.
Also read:
- `memory-bank/activeContext.md`
- `memory-bank/progress.md`
- `memory-bank/copilot-rules.md`

For WoW Classic Lua work:
- inspect `SuperSwingTimer_State.lua` first for timing bugs
- keep white-hit, parry, melee-haste, and ranged-channel paths separate
- use targeted diagnostics on touched Lua files after edits
- do not delete files unless explicitly requested
- verify Classic API behavior with documentation before changing timer logic
"@

[ordered]@{
  continue = $true
  systemMessage = $systemMessage
} | ConvertTo-Json -Depth 5 -Compress
