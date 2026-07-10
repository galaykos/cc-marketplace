---
name: cmd-task-runner-run
description: "Use when the user asks to execute a task list with scope lock, bounded verify-fix loops, and a full-suite completion gate."
---

_This skill wraps the `/task-runner:run` command; pass the command's input as the skill's argument (`$ARGUMENTS`)._


Invoke the task-execution skill from this plugin and run the task list in
$ARGUMENTS — a taskmaster `00-INDEX.md` path, a tasks directory, a plan's task
sequence, or an inline list. If no argument, look for the most recent
`taskmaster-docs/tasks/*/00-INDEX.md`; if none exists, ask for the list.

1. Load the tasks and their order/dependencies; show the run plan (order, parallel
   groups, verify command per task) before executing.
2. Execute per the task-execution skill: one task in progress, scope locked, the
   exact verify command per task, at most three fix cycles before parking; after
   each task's verify passes, run the reviewer pass per the skill (conditional
   on the review plugins installed).
3. Update status in the index only; collect scope-lock follow-ups as a backlog
   list, never as in-run detours. No status HTML — the index and the
   conversation are the run's views (per the task-execution skill).
4. Finish with the full project check suite and the completion report table
   (task / status / verify command / evidence), parked tasks with reasons, and
   the follow-up backlog.

5. Handoff — on a green completion report, if the git-workflow plugin is
   installed, ask via AskUserQuestion: "Finish the branch now (Recommended)"
   / "Stop here — I'll finish it later"; on finish, proceed exactly as
   the `cmd-git-workflow-finish` skill would. If tasks were parked, offer instead: "Retry
   parked tasks now" / "Stop here" — one offer, not both. Headless: print
   the exact next command.
