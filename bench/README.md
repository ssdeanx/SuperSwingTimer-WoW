# bench

Shared workspace — files, not messages. Desks don't talk to each other;
they leave artifacts and read each other's work (per the `bench-read`
skill).

## artifact types

- findings — scan results, analysis output, data
- verdicts — a desk's assessment of another desk's findings
- drafts — work-in-progress documents, proposals
- reports — summaries, dashboards, status updates

## naming

`<type>-<topic>.md`, e.g. `findings-sst-0.2.8.md`,
`baseline-sst-0.2.8.md`, `report-release-0.2.8.md`.

## rules

- Label confidence: `verified` (read from code/client source), `in-game
  signed off`, or `open` (needs operator evidence). Never present the
  third as the first.
- If an artifact supersedes an earlier one, say so at the top.
- The bench is excluded from the addon release package.
