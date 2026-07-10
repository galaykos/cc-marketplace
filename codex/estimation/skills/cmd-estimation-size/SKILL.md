---
name: cmd-estimation-size
description: "Use when the user asks to size a task or task list — S/M/L/XL class per item with anchor comparison, uncertainty flag, and split recommendation for anything L+."
---

_This skill wraps the `/estimation:size` command; pass the command's input as the skill's argument (`$ARGUMENTS`)._


Run the estimation skill from this plugin on $ARGUMENTS (a single task
description, an inline list, a plan document, or a tasks directory; default:
the active task list in this session).

1. Collect the task(s) from $ARGUMENTS. If empty, use the active task list
   (most recent todo list, task cards, or plan in this conversation).
2. Apply the estimation skill to each item: pick the S/M/L/XL class by
   comparing against a completed anchor from this repo or session, apply
   uncertainty multipliers where they trigger, and check split triggers
   for anything L or larger.
3. Output a table with one row per task:
   task | class | anchor it resembles | uncertainty flag | split?
4. End with a totals line: the weighted sum of classes (S=1, M=3, L=8;
   XL rows are excluded from the sum and marked "split or spike first"),
   e.g. "Total: 8 tasks, weight 21 (2 S + 5 M + 1 L, 1 XL unsized)".
5. When the input was a task list of three-plus items, offer the next step
   as a selectable choice (AskUserQuestion): "Compute the parallelization
   plan with these weights (Recommended)" / "Stop here" — on yes, proceed
   as the `cmd-task-runner-plan` skill would.
