---
name: SuperSwingTimer Memory Bank Instructions
description: Repo-specific memory and context workflow for the SuperSwingTimer WoW addon.
argument-hint: Use this file to load only the right memory context, preserve decisions, and keep documentation in sync with addon changes.
agent: agent
applyTo: ['**.md', '**.prompt.md', '**/memory-bank/**']
---

# SuperSwingTimer Memory Bank Instructions

## Purpose

This file defines how to manage persistent context in this repository.

Goals:

1. Preserve implementation decisions across chat resets.
2. Keep context loading efficient (required core + task-specific files).
3. Keep docs/memory in sync with shipped code behavior.
4. Prevent drift between AGENTS, memory-bank files, and runtime code.

---

## Runtime baseline (critical)

- This repo targets **World of Warcraft: Burning Crusade Classic Anniversary Edition**.
- Active baseline: **2026 runtime, 2.5.5 patch family**.
- Do not treat this project as launch-era 2021 BC Classic by default.
- If behavior differences are uncertain, prioritize Anniversary-targeted references and in-game validation.

---

## Required context loading order

### Always load first

```markdown
1. memory-bank/memory-bank-instructions.md
2. memory-bank/projectBrief.md
3. memory-bank/activeContext.md
4. memory-bank/copilot-rules.md
```

### Then load on demand

```markdown
- Architecture/pattern changes → + systemPatterns.md, techContext.md
- Product/UX intent changes → + productContext.md, visualContext.md
- Status/progress sync → + progress.md
- Feature/task deep work → + memory-bank/<feature>/*.md
```

---

## Memory Bank Structure

```markdown
/memory-bank/
├── `projectbrief.md` ← ALWAYS LOAD: scope, goals
├── `activeContext.md` ← ALWAYS LOAD: current focus
├── `copilot-rules.md` ← ALWAYS LOAD: safety rules
│
├── `productContext.md` ← ON DEMAND: user problems, UX goals
├── `systemPatterns.md` ← ON DEMAND: architecture patterns
├── `techContext.md` ← ON DEMAND: tech stack, constraints
├── `progress.md` ← ON DEMAND: completion status
│
└── <feature>/ ← PER-FEATURE CONTEXT
├── `prd.md` # Requirements (user stories, acceptance criteria)
├── `design.md` # Architecture (diagrams, data models, APIs)
├── `tasks.md` # Task breakdown (TASK_ID, effort, dependencies)
└── `context.md` # SCRATCHPAD: decisions, blockers, notes
```

### File Dependency Hierarchy

```mermaid
flowchart TD
    PB[projectbrief.md<br/>ALWAYS LOAD] --> PC[productContext.md]
    PB --> SP[systemPatterns.md]
    PB --> TC[techContext.md]

    /memory-bank/
    ├── `projectBrief.md` ← ALWAYS LOAD: scope, goals
    TC --> AC

    ├── `memory-bank-instructions.md` ← ALWAYS LOAD: this protocol
    AC --> P[progress.md]
    AC --> CR[copilot-rules.md<br/>ALWAYS LOAD]

    AC --> FC[Feature Context]
    ├── `visualContext.md` ← ON DEMAND: real UI/layout expectations
    FC --> PRD[prd.md]
    FC --> DES[design.md]
    FC --> TSK[tasks.md]
        ├── `prd.md` # Requirements
        ├── `design.md` # Implementation design
        ├── `tasks.md` # Task breakdown
        └── `context.md` # Session notes, blockers, decisions

## The Four Context Strategies
    ---

    ## Mandatory update rule after code changes

    When addon code or behavior changes, update all relevant memory/docs before ending the task.

    Minimum expected updates:

    1. `AGENTS.md` current progress (what changed + why)
    2. `memory-bank/activeContext.md` (current focus + decisions)
    3. `memory-bank/progress.md` (completed work + validation status)
    4. Behavior docs impacted by change (README/CHANGELOG/docs/*)

    For config/settings changes, confirm this checklist:

    - `ns.DB_DEFAULTS` in `SuperSwingTimer_Constants.lua`
    - SavedVariables normalization/migration in `SuperSwingTimer.lua`
    - Runtime apply path (`SuperSwingTimer_UI.lua` and/or class mods)
    - Config row/toggle in `SuperSwingTimer_Config.lua`
    - Documentation updates (README/CHANGELOG + relevant docs)
    - TOC version/notes if release metadata changed

    ---

    ## Validation protocol (repo-specific)

    Use targeted diagnostics first:

    1. Run `get_errors` on each edited file before finishing.
    2. Fix all errors in touched files.
    3. Re-run `get_errors` on the same files.

    Avoid default project-wide lint/typecheck unless explicitly requested by user.

    ---

    ## Context quality rules

    - Keep entries factual and implementation-specific.
    - Prefer concrete file paths and behavior descriptions over vague summaries.
    - Record only high-confidence external findings; mark uncertain items as "verify in-game".
    - Avoid copying generic boilerplate from unrelated stacks/frameworks.

    ---

    ## Anti-patterns to avoid

    | ❌ Avoid | ✅ Do instead |
    | --- | --- |
    | Treating project as 2021 BC Classic baseline | Use Anniversary 2026 / 2.5.5 baseline |
    | Leaving AGENTS/memory stale after edits | Update AGENTS + activeContext + progress every code pass |
    | Writing feature changes without config/migration wiring | Follow full settings checklist above |
    | Overloading memory with generic text | Keep concise, repo-specific entries |
    | Relying on one external source | Cross-check with warcraft.wiki.gg and in-game behavior |

    ---

    ## Quick recovery sequence (after reset)
### 1. WRITE: Persist Decisions
    ```markdown
    1. Read memory-bank-instructions.md
    2. Read projectBrief.md + activeContext.md + copilot-rules.md
    3. Read progress.md
    4. Read feature-specific context files only if needed
    5. Resume with targeted get_errors checks on touched files
| Validation library | Zod          | Better TypeScript inference than TypeBox |
| Queue type         | Database     | Persistence required per NFR-3           |
| Rate limit         | 100/min/user | Balance UX with system load              |

    _Last updated: 2026-05-30_
    _Version: 3.0.0_
- When context window is 80%+ full
