---
name: command-run
description: Use to execute task cards, an index, or an explicit task list, with optional tracks, crew review, or a bounded mechanical sweep.
---

Resolve the requested index/directory/list; absent an input, use the most recent unambiguous `taskmaster-docs/tasks/*/00-INDEX.md`, or ask for the intended list. Load the native task-execution skill, display the dependency order and verification plan, and continue the authorized work.

`--tracks[=N]` explicitly selects native track-orchestration. N must be a positive integer; 1 means serial, larger values are capped at actual available worker capacity. Bare tracks uses up to four eligible workers within the tool/policy limit. Missing disjoint milestone file sets or unavailable delegation falls back to serial with the reason. No implicit Workflow batch API is required.

`--crew` adds a read-only review followed by a test-focused pass on directly executed cards. Discover role rubrics and permitted tools from the active catalog, or perform the passes inline. Test edits stay within declared scope, and exact verification runs again afterward. Keep the same bounded failure budget; the flag does not authorize unrelated test rewrites or weakening checks.

`--sweep` selects a mechanical migration: freeze the enumerated target set before edits, covering direct, alias/re-export, dynamic/string and non-code occurrences; work in bounded batches; measure residual matches after each batch. Resolve this plugin's sweep-residual.sh and inspect its help before using its freeze/measure/allow protocol. A surviving occurrence needs a documented reason; unexplained survivors or moved target sets require correction before completion. Commit batches only when commits are within the authorized workflow.

Track run status, deviations, verification output and parked reasons in the task index. Use `.codex/cc-marketplace/` for supported helper state. Do not create legacy active-run/reviewer sentinel files merely to arm unsupported transcript gates. Finish with the native execution skill's integration and behavioral evidence, not source-host gate-pass claims.
