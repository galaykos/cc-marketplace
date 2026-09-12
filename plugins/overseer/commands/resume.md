---
description: Resume the open overseer program in this session from its persisted state
argument-hint: [milestone-id]
---

Invoke the `overseer` skill from this plugin and continue the program recorded under
`.claude/overseer/`. Read it with `${CLAUDE_PLUGIN_ROOT}/scripts/program.sh status`;
when there is no program, say so and point to `/overseer:start` (do not invent one).

1. Reconcile state with git per the skill's **Resume** rule — does each milestone's
   branch exist, is it merged, is a task-runner index still open for it. The board's
   `model:` tier binds every dispatch this session writes; it is not re-chosen on resume.
2. Pick the milestone: `$ARGUMENTS` when it names an id, else
   `${CLAUDE_PLUGIN_ROOT}/scripts/program.sh next`.
3. When the board shows `0/0 done` (a program with no milestones), the roadmap step never
   ran: hand over to `/overseer:start`, which re-opens Discover → Clarify → Charter.
4. Re-enter the **Deliver** loop at that milestone's recorded status: `queued` → brief,
   `briefed` → execute, `building` → continue or re-run execution, `accepting` → run
   acceptance again from scratch, `parked` → surface the reason and ask whether to retry.
