# Milestone file-sets in 00-INDEX

When a card set is grouped into milestones, each milestone's entry in `00-INDEX.md`
carries a **`Files:`** line — the normalized union of the paths that milestone's cards write.
This is what `/task-runner:run --tracks` reads to decide which milestones can run
concurrently (see `task-runner/skills/track-orchestration/references/eligibility.md`).

## The rule

For each milestone, collect the `path` of every `<file>` in its cards' `<facts>` (both
`mode="edit"` and `mode="create"`; never a `<must-not>` file, which the card may not touch)
and **normalize** each:

1. take the `path` attribute alone — the line lives in its own `line` attribute; on a
   legacy bold-label card strip a trailing `:line` / `:line-range` and any `(…)` annotation,
2. make it repo-relative (no `./`, no absolute prefix),
3. keep a directory entry (trailing `/`) as a prefix covering everything beneath it.

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
fall back to a serial run** (with a warning). A legacy card's line numbers and annotations
must be stripped, or `foo.ts:12` and `foo.ts:99` would look disjoint while editing the same file.

This line is authoring metadata only; it does not change how a serial run executes.
