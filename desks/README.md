# desks

One folder per desk. A desk is one focus, held long enough to produce
something another desk can read.

## shape

```
desks/<name>/
  journal.md      # appended, dated entries
  .signals/       # JSON signals, one file per signal
```

A desk with a `journal.md` is **live** — read it and resume, never
overwrite it.

## opening a desk (per `desk-open`)

1. Name it: short, descriptive, kebab-case (`release-0.2.8`, `swing-engine`).
2. If `desks/<name>/journal.md` exists, the desk is live. Read it and resume.
3. Otherwise create the folder with `journal.md` and `.signals/`, then write
   the first entry: purpose, scope, next step.

## journal entry shape (per `desk-journal`)

Each entry is short and dated:

```
## YYYY-MM-DD — <what happened>

- state: done | open | blocked
- did: ...
- next: ...
```

Leave enough that a session starting from zero can pick up the trail.

## signals (per `signal-write`)

Write one JSON file per signal into `desks/<name>/.signals/` and add a
short `[signal:<type>]` marker to the journal. Signals are for state
changes that affect the operator or another desk, not routine progress.
