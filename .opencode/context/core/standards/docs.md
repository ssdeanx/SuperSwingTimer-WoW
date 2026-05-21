# Documentation Standards — Super Swing Timer

> Reference: `docs/` directory for supplementary docs; `AGENTS.md` for changelog format.
> **Source of truth for format: `CHANGELOG.md` and `README.md` in the project root.**

## MUST rules
- **MUST** update README + CHANGELOG + TOC when adding a new setting
- **MUST** keep README CurseForge-safe: no Mermaid diagrams, no emojis (unless asked)
  - Mermaid IS fine in `.opencode/` and `memory-bank/` files (these are AI-agent-only)
- **MUST** date format: `YYYY-MM-DD` in CHANGELOG
- **MUST** use inline code for Lua APIs, file names, variables
- **MUST** keep `docs.md` CHANGELOG format description in sync with actual `CHANGELOG.md`

## README structure (in order)
1. One-liner description + "final-prep / feature-complete" status
2. At-a-glance table (class → what it covers)
3. Key features (bullet list by class)
4. Timing model table (situation → what you see → why it matters)
5. Texture sources table (source → used for → notes)
6. Installation (step-by-step with expected path)
7. Usage (bars table with defaults, commands table)
8. Class support table
9. Configuration (command table, panel options)
10. GitHub Issues link, changelog reference

## CHANGELOG format
```
## vX.Y.Z (YYYY-MM-DD)
- {what changed} — {why it matters, one sentence}
```
- Bold for critical bugfixes (`**bold**`)
- One bullet per change, not paragraphs
- Prefix bullet by category when helpful: `feat:`, `fix:`, `docs:`, `refactor:`
- Each version section must match the actual release notes in `CHANGELOG.md`

## Tone
- Professional, concise, technical
- Not onboarding prose — the audience is the AI agent, not new human users
- Prefer pointers to authoritative files over inlining summaries (e.g., "See `docs/swingtimer.md`")

---
**🔄 Sync hook:** If README sections or CHANGELOG format change, update this file. Master protocol → `standards/code.md`
