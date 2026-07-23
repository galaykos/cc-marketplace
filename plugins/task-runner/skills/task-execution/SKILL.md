---
name: task-execution
description: Use when executing a list of defined tasks (taskmaster cards, a plan's sequence, a todo list) — one task at a time, scope locked, bounded implement-verify-fix loop per task, status tracking, halt-with-evidence instead of drifting.
---

## The contract

One task in progress at any moment. Its definition — the files, the change, the acceptance
criteria, the verify command — is the whole world until it passes or is formally parked.
Starting task N+1 while task N is unverified is the root of "90% done" projects that don't work.

## Scope lock

- Touch only files the task lists (plus files the verify command itself demands, e.g. a
  missing test fixture). Wanting to IMPROVE an unlisted file is a signal, not an errand:
  record a follow-up task in the index/backlog, continue. But evidence the current change
  BREAKS an unlisted file is a mis-scoped/blast-radius signal → halt-with-evidence or flag the orchestrator, never a silent follow-up (detection points in `references/routing.md`).
- "While I'm here" is banned. Adjacent dead code, tempting refactors, unrelated
  bugs — record, do not touch. The diff should read as exactly that task, nothing else.
- If the task is mis-specified (wrong file, impossible criterion), do not silently
  reinterpret it — halt, state the mismatch, fix the definition, then execute the corrected task.

## The inner loop (bounded, Ralph-style)

Per task, loop — but with a hard ceiling:

1. Implement the change the task describes.
2. Run the task's verify command — the EXACT command, not a cheaper stand-in.
3. Pass → run the negative-control gate before flipping (`references/negative-control.md`):
   `discriminating` → record evidence + flip; `vacuous`/`invalid-control` → back into this
   loop (verify has no teeth); `isolation-halt` → halt. Manual/visual skips need the recorded why-non-automatable note.
4. Fail → diagnose from the actual output, fix, go to 2.
5. **Three failed fix cycles → halt the task.** Report what was tried, the exact
   failing output, and the current hypothesis. A fourth blind attempt is where
   corruption starts: deleted assertions, weakened criteria, hallucinated fixes.

Never make the loop pass by weakening the check: no skipping tests, no editing
acceptance criteria mid-task, no swapping the verify command for one that happens
to pass, no `|| true`. The check is the task; gaming it is failing it silently.

## Reviewer pass (per task)

After the task's verify command passes — and before its status flips to done — run a
conditional reviewer pass on the diff of a **directly-dispatched** card (a parallel-group/track leaf gets none — see `references/reviewer-routing.md`):

- **code-reviewer** (code-review plugin): every task's diff, no condition.
- **ui-ux-reviewer** (ui-ux plugin): only when the diff touches UI files — components, styles, templates.
- **architecture-reviewer** (code-architecture plugin): only on structural
  tasks — new modules, boundary changes, or API changes.
- **security review** (security plugin): only on tasks touching auth, input validation, or dependencies.

Each fires only if its plugin is installed; a missing reviewer is skipped silently, never a failure.
**Concurrent by default:** the resolved read-only reviewers dispatch as ONE concurrent batch
over the card diff; a `Bash`-holding reviewer is excluded from the batch and run serially; the
inline security-review skill runs after the batch joins (`references/reviewer-routing.md`
§ Concurrent dispatch — baseline behavior, not `--crew`-gated).
Plus the card's `Agent:` tag adds a primed domain reviewer per `references/reviewer-routing.md`, augmenting the four above (dedup duplicates; a tag route may suppress the baseline gate it subsumes, e.g. security); the opt-in `--crew` flag additionally runs a sequential test-only `test-engineer` authoring pass per `references/crew.md`.

**Upgraded statement:** when `00-INDEX.md` carries a `## Upgraded statement` blockquote
(the `> `-prefixed section task-cards writes), read it as binding context for every task
— it sharpens the shared goal, NEVER a license to widen, drop, or reinterpret a card;
cards stay the sole scope authority, halt-with-evidence unchanged. Absent → as today.

**Extreme Boost:** when `00-INDEX.md` carries an `Ultra: true` or `Goal: true` marker,
dispatch the reviewer, delegated worker, and **code-redteam** panel agents with the resolved `model:` override — excluding
`opinion-lens` — so the boost reaches execution even in a fresh session; code-redteam never reads the index itself, so pass it the resolved `(model, effort)`. A batch carries no tier override of its own — it dispatches like any other card (`references/routing.md` § Batch dispatch). Read BOTH
markers: tier from `Ultra:` when present, ELSE from `Goal:` (a lone `Goal:` still
escalates workers — goal implies the boost); the autonomy axis comes from `Goal:`. A
trailing `(model=…, effort=…)` sets the tier — `model=auto` resolves HERE, to the executing session's model or opus, whichever is higher (haiku<sonnet<opus<fable); a malformed one falls to the marker's legacy default (`Ultra:`→opus/xhigh, `Goal:`→opus/xhigh). Announce the tier once at
run start, boosted or not: `⚡ Ultra run — workers model=<marker-model>→<resolved>, effort=<effort>` / `▷ Standard run — workers inherit the session model (<model>) · effort: <effort>` (standard `<effort>` = `$CLAUDE_EFFORT` when the harness exposes it — `echo ${CLAUDE_EFFORT:-inherit}` — else the literal `inherit`). The Agent tool escalates model
only (marker `effort` applies on the `Workflow` path). Delegated stack implementers also
get delegation-contracts § Skill priming (resolve+inject `Read <abs-path>` per `Skills to
apply`). Under the marker, ALSO run the **code-redteam** pass (its skill) over the produced
diff — at each serial milestone boundary and once before completion (in `--tracks`: once on the merged branch) — routing confirmed
findings to reopen the targeted card under a fresh budget. **Under `Goal:`** (hands-off): auto-take
pipeline gates — the run-plan preview is DISPLAYED, then execution proceeds without
waiting; post-run "Retry parked" is bounded to at most ONE auto-retry, and only on
forward progress (a task moved parked→done), else surface the parked list and stop.
Halt-with-evidence, mis-specified-task halts, and the full-suite completion gate are
UNCHANGED and NEVER suppressed under Goal.

Blocker/major findings send the task back into the fix loop; each such round counts toward
the SAME three-cycle ceiling as verify failures (under `--crew`, the crew loop uses its own fresh budget) — so the reviewer pass cannot loop unboundedly. Minor findings go to the
follow-up backlog, not the current diff; after a reviewer-driven fix, re-run the verify command before re-review.

## No unbounded outer loop

The bounded inner loop is the good part of the Ralph pattern; the infinite outer loop is not
adopted — unbounded self-looping amplifies drift, and token burn scales with confusion, not
progress. The outer loop is the task list itself: finite, ordered, visible. A halted task
stays halted until its definition is fixed — never silently retried. When every task is done
or parked, the run ENDS with a report, no self-restart.

## Sequencing and status

- Execute in index order, respecting `Depends on`; parallel groups (and disjoint
  same-worker S-card batches) may be delegated ONLY if file sets are disjoint — else serial.
- Status lives in one place (the task index / todo list, e.g. taskmaster's
  `00-INDEX.md`): pending → in_progress (exactly one) → done | parked(reason).
  Task definitions themselves stay immutable during the run.
- A parked task never blocks unrelated tasks; dependency-blocked tasks are marked
  blocked-by, not attempted anyway.

## No status theater

No status dashboards, run boards, or progress pages — the index table plus the conversation
already show every flip, and a run-board page goes stale; the index is the single view. HTML
artifacts (or a localhost preview) are reserved for content that earns the medium — UI
mockups, walkthroughs, demos; a table a message can carry is not a file.

## Drift tripwires

Stop and re-read the current task the moment any of these appears:

- An edit touching a file the task does not list.
- Rewriting the goal in softer words than the acceptance criteria use.
- Running a different verify command than specified — "faster" or "basically equivalent".
- Working on something because it is interesting rather than because it is the current task.
- More than ~30 minutes (or one context-refill) inside one fix cycle without new
  information — attempt-churn; count it as a failed cycle.

## Delegating parallel groups

Only the main `/task-runner:run` orchestrator routes and delegates; a delegated worker
is a leaf that executes and never re-routes. Per card the runner follows
`references/routing.md`: read the card's `Agent:` tag → resolve to the first reachable
specialist (else `task-executor`) → arm a per-card scope file → Read and paste the
delegation-contracts discipline preamble verbatim into the dispatch, plus the
`## Upgraded statement` block when the index carries one → dispatch → on return run the
diff-vs-declared-files scope check, re-run the task's verify command, then the
negative-control per returned card (routing.md step 6, standard exemptions).
A subagent's "done, tests pass" is a claim; the runner's own verify plus that teeth check
is the evidence. One failed re-verification sends the task back; a second reclaims it inline.

## Evidence format

Evidence recorded per task is boringly literal: the exact command as run, its exit code, and
the last relevant lines of output (the failing assertion, the "N passed" summary — not the
whole log). Manual checks ("dialog renders centered") are recorded as manual, with what was observed; "Verified ✓" alone is not evidence and closes nothing.

## Completion protocol

The run is complete only when:

1. Every task is done or parked-with-reason — none silently skipped.
2. The project's FULL check suite passes at the end (local passes can compose into a global
   failure) AND the **behavioral-gate** actually runs the produced code (see its skill:
   `scripts/behavioral-gate.sh --changed <run's files>`) — the repo suite may be a static
   linter that never executes new code. docs-upkeep's drift check, if installed, joins this gate.
3. The final report is a table: task / status / verify command / evidence line, plus the
   parked list with reasons and the follow-up backlog collected by the scope lock.

Claiming completion without the full-suite run is asserting, not verifying — the
work-verification discipline (code-architecture plugin) applies to the whole run.
