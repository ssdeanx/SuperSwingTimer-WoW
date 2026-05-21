---
globs:
  - '**/*.md'
---

# Documentation Conventions — Super Swing Timer

## MUST
- README/public docs: no Mermaid diagrams, no emojis (CurseForge-safe)
- `.opencode/` and `memory-bank/` files: **Mermaid IS allowed** (AI-only, never CurseForge)
- CHANGELOG: `YYYY-MM-DD` dates, one bullet per change
- Update README + CHANGELOG + TOC when settings change

## Tone
- Professional, concise, technical
- AI agent audience for `.opencode/` files — dense, signal-rich, imperative
- Human audience for README/public docs — onboarding-friendly
- Point to authoritative files (`AGENTS.md`, `memory-bank/`) instead of inlining

---
**🔄 Sync hook:** If README/CHANGELOG conventions change, update MUST list. Master protocol → `standards/code.md`
