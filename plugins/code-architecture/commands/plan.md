---
description: Produce a file-level implementation plan before writing code
---

Invoke the plan-before-code skill from this plugin against $ARGUMENTS (the feature or change
described there, or the current uncommitted diff/context if no argument is given). Steps:

1. Invoke the plan-before-code skill and follow its procedure.
2. Output a file map: every file to create or touch, with a one-sentence responsibility each.
3. Output the interfaces between the units in that map: signatures, data shapes crossing
   boundaries, and error/validation ownership.
4. Output a task sequence: dependency order, and which tasks (if any) are independent enough to
   parallelize, per the task-orchestration skill.
5. Do not write implementation code in this step. The output is the plan only — code comes
   after the plan is reviewed.
