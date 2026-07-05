---
description: Shorthand for /taskmaster:task — grill a task until zero ambiguity, then emit a spec and single-prompt task cards
argument-hint: [task-description]
---

<!-- Alias of task.md — keep the pipeline steps in sync with commands/task.md -->

Run the full taskmaster pipeline on $ARGUMENTS (if empty, ask for a one-paragraph task
description first). Do not write implementation code at any step.

1. If the stack-scan plugin is installed (the installed-versions skill or
   /stack-scan:report is available), run its inventory first and hand the
   required-vs-installed table to context-scout as hard constraints. If it is not
   installed, skip this — context-scout falls back to reading manifests itself.
2. Invoke the grill skill from this plugin. Dispatch the context-scout agent on the
   task description and fold its report into the ambiguity ledger BEFORE asking the
   user anything.
3. Run batched question rounds per the grill skill until every ledger row is CLEAR
   or explicitly accepted as ASSUMED. For whole-experience tasks, slice first per
   the grill skill's big-task rule. Switch to the visual-decisions skill whenever
   a choice is visual or structural (layout, flow, architecture shape, data shape).
4. For multi-screen or whole-experience tasks (three-plus screens, or a flow whose
   sequence is itself a requirement), invoke the experience-walkthrough skill once
   visual decisions land: assemble the accepted picks into one clickable demo on
   the live preview URL, walk the user through it with a task script, and fold
   every discovered gap back into the ledger before freezing anything.
5. Write the spec to `docs/specs/YYYY-MM-DD-<slug>.md`: goal, decisions with
   sources, accepted assumptions, non-goals, success criteria — plus the
   walkthrough file path and cross-screen contracts when step 4 ran.
6. Invoke the task-cards skill to split the spec into single-prompt task cards
   under `docs/tasks/YYYY-MM-DD-<slug>/` with a `00-INDEX.md`, grouped into
   milestones when the run is large.
7. Final output: the ledger summary (counts of CLEAR/ASSUMED), the spec path, the
   card list in execution order with parallel groups (and milestones) marked, and
   the exact command to start card 01. If the task-runner plugin is installed,
   name `/task-runner:run docs/tasks/YYYY-MM-DD-<slug>/00-INDEX.md` as that
   command; otherwise give the card path to run manually.
