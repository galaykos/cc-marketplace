# Milestone file-sets in 00-INDEX

When a card set is grouped into milestones, each milestone's entry in `00-INDEX.md`
carries a **`Files:`** line — the normalized union of that milestone's cards' `Files`.
This is what `/task-runner:run --tracks` reads to decide which milestones can run
concurrently (see `task-runner/skills/track-orchestration/references/eligibility.md`).

## The rule

For each milestone, collect every `Files` path from its cards and **normalize** each:

1. strip a trailing `:line` / `:line-range` suffix,
2. strip any parenthetical annotation `(…)`,
3. make it repo-relative (no `./`, no absolute prefix),
4. keep a directory entry (trailing `/`) as a prefix covering everything beneath it.

Emit the deduplicated set as a `Files:` line on the milestone, e.g.:

```
### Milestone B — export works for admins only
Files: app/Export/, app/Http/Controllers/ExportController.php, routes/api.php
Cards: 04, 05, 06
```

## Why

Two milestones are safe to run as concurrent tracks only if their file-sets are
disjoint. Without a machine-readable, normalized `Files:` set the orchestrator cannot
prove disjointness, so **an index without per-milestone `Files:` lines makes `--tracks`
fall back to a serial run** (with a warning). Line numbers and annotations must be
stripped, or `foo.ts:12` and `foo.ts:99` would look disjoint while editing the same file.

This line is authoring metadata only; it does not change how a serial run executes.
