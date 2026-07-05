---
description: Grill a task until zero ambiguity, decide visual choices with mockups, then emit a spec and single-prompt task cards
argument-hint: [task-description]
---

Run the full grill-me pipeline on $ARGUMENTS (if empty, ask for a one-paragraph task
description first). Do not write implementation code at any step.

1. Invoke the grill skill from this plugin. Dispatch the context-scout agent on the
   task description and fold its report into the ambiguity ledger BEFORE asking the
   user anything.
2. Run batched question rounds per the grill skill until every ledger row is CLEAR
   or explicitly accepted as ASSUMED. Switch to the visual-decisions skill whenever
   a choice is visual or structural (layout, flow, architecture shape, data shape).
3. Write the spec to `docs/specs/YYYY-MM-DD-<slug>.md`: goal, decisions with
   sources, accepted assumptions, non-goals, success criteria.
4. Invoke the task-cards skill to split the spec into single-prompt task cards
   under `docs/tasks/YYYY-MM-DD-<slug>/` with a `00-INDEX.md`.
5. Final output: the ledger summary (counts of CLEAR/ASSUMED), the spec path, the
   card list in execution order with parallel groups marked, and the exact command
   to start card 01.
