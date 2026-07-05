---
description: Dry-run parallelization plan for a task list — dependency levels, parallel groups, recommended subagent count, estimated speedup, inline-vs-delegate verdict. No execution.
---

Run the parallel-planning skill from this plugin on $ARGUMENTS (a taskmaster
`00-INDEX.md`, a tasks directory, a plan document, or an inline list; default:
the most recent `docs/tasks/*/00-INDEX.md`).

1. Build the dependency graph and per-task file sets from the list.
2. Compute levels, parallel groups, critical path, and the speedup estimate
   per the skill's model — show the arithmetic, not just the verdict.
3. Output the run-plan table (level / tasks / mode / agents / est. wall-clock)
   and the one-line verdict with its reason.
4. Do NOT execute. Offer: `/task-runner:run <list>` runs it (the runner asks
   which mode when the verdict recommends delegation).
