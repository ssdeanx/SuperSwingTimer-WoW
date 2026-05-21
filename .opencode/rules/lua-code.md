---
globs:
  - '**/*.lua'
---

# Lua Code — Cross-Cutting Rules (any .lua file)

## MUST (load-bearing, all files)
- **MUST** use the local `GetCurrentTime()` (delegates to `ns.GetAlignedTime()`) for all swing timing — DO NOT call `ns.GetCurrentTime()`, it does NOT exist
- **MUST** use `ns.GetSpellInfo` wrapper (not bare `GetSpellInfo`)
- **MUST** keep swing-math on `OnUpdate`; `C_Timer` only for one-shot/low-freq delays
- **MUST** declare `ns = ...` BEFORE any `local` variables (bare `local` before `ns` kills every non-hunter class)
- **MUST** end every function/block with matching `end` (cascade errors destroy LSP)
- **MUST** import Blizzard globals via `rawget(_G, "strtrim")` when needed
- **MUST** fix LSP errors as they appear (auto-shown on edit) — zero diagnostics before committing

## Session discipline
- **One task per `/clear`** — reset context between unrelated tasks
- **Re-read modified files** if they become relevant again mid-session
- **Keep failures visible** — failed compilation helps recovery, don't clean it away
- **For complex work** — also load `subsystem/*.md` for the specific file you're editing

---
**🔄 Sync hook:** If Lua patterns/rules change, update MUST/SHOULD lists here. Master protocol → `standards/code.md`


