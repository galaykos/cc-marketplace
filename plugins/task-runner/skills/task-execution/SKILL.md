---
name: task-execution
description: Use when executing a list of defined tasks (grill-me task cards, a plan's task sequence, a todo list) — one task at a time, scope locked to the current task, a bounded implement-verify-fix inner loop per task, explicit status tracking, and a halt-with-evidence protocol instead of drifting or looping forever.
---

## The contract

One task in progress at any moment. The current task's definition — its files, its
change, its acceptance criteria, its verify command — is the whole world until it
passes or is formally parked. Starting task N+1 while task N is unverified is the
root of "90% done" projects where nothing actually works.

## Scope lock

- Touch only files the task lists (plus files the verify command itself demands,
  e.g. a missing test fixture). Wanting to edit an unlisted file is a signal, not
  an errand: stop, record it as a follow-up task in the index/backlog, continue.
- "While I'm here" is banned. Adjacent dead code, tempting refactors, unrelated
  bugs — record, do not touch. The diff for a task should read as exactly that
  task and nothing else.
- If the task turns out to be mis-specified (wrong file, impossible criterion),
  do not silently reinterpret it — halt the task, state the mismatch, fix the
  task definition first, then execute the corrected task.

## The inner loop (bounded, Ralph-style)

Per task, loop — but with a hard ceiling:

1. Implement the change the task describes.
2. Run the task's verify command — the EXACT command, not a cheaper stand-in.
3. Pass → done: record evidence (command + tail of output) and flip status.
4. Fail → diagnose from the actual output, fix, go to 2.
5. **Three failed fix cycles → halt the task.** Report what was tried, the exact
   failing output, and the current hypothesis. A fourth blind attempt is where
   corruption starts: deleted assertions, weakened criteria, hallucinated fixes.

Never make the loop pass by weakening the check: no skipping tests, no editing
acceptance criteria mid-task, no swapping the verify command for one that happens
to pass, no `|| true`. The check is the task; gaming it is failing it silently.

## No unbounded outer loop

The bounded inner loop above is the good part of the Ralph pattern. The infinite
outer loop ("keep going until everything works, forever") is not adopted:
unbounded self-looping amplifies drift — each blind retry compounds the previous
misunderstanding, and token burn scales with confusion, not progress. Instead:

- The outer loop is the task list itself: finite, ordered, visible.
- Each pass through the list is deliberate; a task that halts stays halted until
  its definition is fixed — it is not silently retried on the next pass.
- When every task is done or explicitly parked, the run ENDS with a report. No
  self-restart.

## Sequencing and status

- Execute in index order, respecting `Depends on`; parallel groups may be
  delegated to subagents ONLY if their file sets are disjoint — otherwise serial.
- Status lives in one place (the task index / todo list, e.g. grill-me's
  `00-INDEX.md`): pending → in_progress (exactly one) → done | parked(reason).
  Task definitions themselves stay immutable during the run.
- A parked task never blocks unrelated tasks; dependency-blocked tasks are marked
  blocked-by, not attempted anyway.

## Drift tripwires

Stop and re-read the current task the moment any of these appears:

- An edit touching a file the task does not list.
- Rewriting the goal in softer words than the acceptance criteria use.
- Running a different verify command than the task specifies "because it is
  faster" or "basically equivalent".
- Working on something because it is interesting rather than because it is the
  current task.
- More than ~30 minutes (or one context-refill) inside one fix cycle without new
  information — that is attempt-churn, count it as a failed cycle.

## Delegating parallel groups

When a parallel group goes to subagents, each subagent receives its task verbatim
plus the scope-lock rules — and the runner re-runs every task's verify command
itself when the subagent returns. A subagent reporting "done, tests pass" is a
claim; the runner's own execution of the verify command is the evidence. One
failed re-verification sends the task back with the failing output; a second
failure reclaims it for inline execution. Never mark a delegated task done on
the subagent's word alone.

## Evidence format

Evidence recorded per task is boringly literal: the exact command as run, its
exit code, and the last relevant lines of output (the failing assertion, the
"N passed" summary — not the whole log). Manual checks that cannot be commands
("dialog renders centered") are recorded as manual, with what was observed.
"Verified ✓" with nothing attached is not evidence and does not close a task.

## Completion protocol

The run is complete only when:

1. Every task is done or parked-with-reason — none silently skipped.
2. The project's FULL check suite (tests, lint, type-check, build — whatever the
   repo defines) passes at the end, not just each task's local verify: local
   passes can compose into a global failure.
3. The final report is a table: task / status / verify command / evidence line,
   plus the parked list with reasons and the follow-up backlog collected by the
   scope lock.

Claiming completion without the full-suite run is asserting, not verifying — the
work-verification discipline (code-architecture plugin) applies to the whole run.
