---
description: Dry-run parallelization plan for a task list — dependency levels, parallel groups, recommended subagent count, estimated speedup, inline-vs-delegate verdict. No execution.
---

Run the parallel-planning skill from this plugin on $ARGUMENTS (a taskmaster
`00-INDEX.md`, a tasks directory, a plan document, or an inline list; default:
the most recent `taskmaster-docs/tasks/*/00-INDEX.md`).

1. Build the dependency graph and per-task file sets from the list.
2. Compute levels, parallel groups, critical path, and the speedup estimate
   per the skill's model — show the arithmetic, not just the verdict.
3. Output the run-plan table (level / tasks / mode / agents / est. wall-clock)
   and the one-line verdict with its reason, plus the run-level **`Dispatch:`**
   recommendation (`{default, workflow-tracks}` — see
   `skills/parallel-planning/references/dispatch-selection.md`). `BATCH` levels
   and the `Dispatch:` line are part of the same computed plan.
4. Do NOT execute yet. Offer the next step as a selectable choice
   (AskUserQuestion): "Run now with this plan (Recommended)" / "Stop here".
   On "Run now", proceed exactly as `/task-runner:run <list>` would, using the
   computed run-level machinery (the `Dispatch:` pick — `default` or, at this
   confirmation, `workflow-tracks`) with the per-level `INLINE`/`DELEGATE`/`BATCH`
   verdicts as the within-run schedule. Print the bare command only when headless.

**Goal marker** — when the list's `00-INDEX.md` carries `Goal: true` (hands-off,
requires task-runner ≥0.11.0), the step-4 AskUserQuestion is auto-taken to the computed
verdict ("Run now with this plan"): proceed exactly as `/task-runner:run <list>` would,
no prompt. Halts and the completion gate still surface.
