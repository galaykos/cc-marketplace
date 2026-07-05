---
description: Execute a task list with scope lock, bounded verify-fix loops, and a full-suite completion gate
argument-hint: [tasks-dir-index-or-list]
---

Invoke the task-execution skill from this plugin and run the task list in
$ARGUMENTS — a taskmaster `00-INDEX.md` path, a tasks directory, a plan's task
sequence, or an inline list. If no argument, look for the most recent
`taskmaster-docs/tasks/*/00-INDEX.md`; if none exists, ask for the list.

1. Load the tasks and their order/dependencies; show the run plan (order, parallel
   groups, verify command per task) before executing.
2. Execute per the task-execution skill: one task in progress, scope locked, the
   exact verify command per task, at most three fix cycles before parking.
3. Update status in the index only; collect scope-lock follow-ups as a backlog
   list, never as in-run detours. For runs past ~3 tasks, keep the live run
   board (per the task-execution skill) regenerated at every status flip and
   give the user its URL at run start.
4. Finish with the full project check suite and the completion report table
   (task / status / verify command / evidence), parked tasks with reasons, and
   the follow-up backlog. Kill the run-board server if one was started.
