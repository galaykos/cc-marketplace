---
description: Execute a task list with scope lock, bounded verify-fix loops, and a full-suite completion gate
argument-hint: [tasks-dir-index-or-list] [--tracks[=N]] [--crew]
---

Invoke the task-execution skill from this plugin and run the task list in
$ARGUMENTS — a taskmaster `00-INDEX.md` path, a tasks directory, a plan's task
sequence, or an inline list. If no argument, look for the most recent
`taskmaster-docs/tasks/*/00-INDEX.md`; if none exists, ask for the list.

**`--tracks[=N]`** — if `$ARGUMENTS` includes `--tracks`, run via the
`track-orchestration` skill from this plugin instead of the serial path below:
independent milestones run as concurrent git-worktree tracks. `N` is clamped to
`[1,6]`; `--tracks=1` warns and runs serial; `--tracks=0`, negative, or non-integer is a
usage error (do not run); bare `--tracks` uses the default cap `min(eligible, 4)`. With
no `--tracks` — or when the index lacks per-milestone `Files:` sets or has 0–1 eligible
milestone — run the serial `task-execution` path below (backward compatible).

**`--crew`** — a bare boolean opt-in (default off; `--crew=<value>` is a usage error). When
present, after each **directly-dispatched** card's build verify passes, run the per-card
crew per `skills/task-execution/references/crew.md`: the read-only reviewers concurrently
(a `Bash`-holding reviewer and the `security-review` skill run serially), then a sequential
**test-files-only** `test-engineer` authoring pass (scope-locked by the diff-vs-declared
check), then an unconditional card-verify re-run and a fresh bounded fix loop. Combos:
`--crew`; `--tracks[=N] --crew`; `--tracks=1 --crew` — crew applies only to serial cards /
non-eligible milestones, **never** inside a track leaf or any delegated parallel-group leaf.
`--crew` is the **sole** trigger: no hook, no `Ultra: true` marker, and no
`ultra-task`/`ultra-assess` run engages crew; without `--crew` the run is exactly as today.

**Auto-pick (no dispatch flag)** — when `$ARGUMENTS` includes no dispatch flag (`--tracks`
absent), consult `parallel-planning`'s `Dispatch:` recommendation
(`skills/parallel-planning/references/dispatch-selection.md`) and honor it:

- `Dispatch: default` → the serial `task-execution` path below; its per-level
  `INLINE`/`DELEGATE`/`BATCH` verdicts decide subagent use as today (default-path
  delegation is existing behavior, **not** a new silent fleet). A **BATCH** level
  dispatches each same-worker disjoint S-batch as one agent per
  `skills/task-execution/references/routing.md` § Batch dispatch — one commit per card,
  and per-card verify + negative-control + scope check + reviewer pass on return.
- `Dispatch: workflow-tracks` → engage the `--tracks` path, but only under the **Run-now
  confirmation** (interactive) or a **`Goal:` marker** (hands-off), AND only if track
  preconditions hold (non-base run branch + clean tree + per-milestone `Files:` sets). If
  preconditions are unmet, **downgrade to the default path** and write the downgrade
  reason **into the run report** so a hands-off downgrade stays auditable. Auto-picked
  tracks downgrade — they never refuse; an *explicit* `--tracks` keeps
  `track-orchestration`'s create-or-refuse contract.

An **explicit** dispatch flag always overrides auto-pick. `--crew` is **orthogonal** — a
quality flag, not a dispatch flag — and never affects the `Dispatch:` decision.

1. Load the tasks and their order/dependencies; show the run plan (order, parallel
   groups, verify command per task) before executing. **The plan is DISPLAYED, not an
   approval gate** — continue into the first task in the SAME turn that shows it, with
   the tool call in the same message. Inside a live run a turn ends through a TOOL, never
   through prose: need a decision → ask it with `AskUserQuestion` (which is not a stop);
   blocked → park the task with a reason. Prose that announces the next task and then
   ends the turn ("starting card 01 now") binds nothing — the run reads live, is dead,
   and the user waits on a turn that already ended. Register the run for the
   completion-gate Stop hook: write `.claude/task-runner/active-run.json`
   (`{"slug":"<tasks-dir-name>","base":"<merge-base with the default branch>",`
   `"branch":"<git rev-parse --abbrev-ref HEAD>"}`; for a taskmaster-index run also
   include `"index_path":"<00-INDEX.md>"` — the hook uses it to require card counts in
   the gate pass) so the hook can enforce that a behavioral-gate pass is recorded before
   the run stops clean. `branch` scopes enforcement to the run's own branch, so a
   sentinel left by an abandoned run never blocks unrelated work elsewhere in the repo.
2. Execute per the task-execution skill: one task in progress, scope locked, the
   exact verify command per task, at most three fix cycles before parking; after
   each task's verify passes, run the reviewer pass per the skill (conditional
   on the review plugins installed), plus the full crew pass when `--crew` is set.
3. Update status in the index only; collect scope-lock follow-ups as a backlog
   list, never as in-run detours. No status HTML — the index and the
   conversation are the run's views (per the task-execution skill).
4. Finish with BOTH completion gates, never one alone:
   - the full project check suite (catches lint/type/build regressions), AND
   - the **behavioral-gate** on the run's changed files —
     `${CLAUDE_PLUGIN_ROOT}/scripts/behavioral-gate.sh --changed "<the run's touched
     files>" [--entrypoint <bin>] [--differential 'flag::with::without']`, run from a
     disposable checkout/temp so it never mutates the live tree. The repo suite may be a
     static linter that never executes the new code; the behavioral-gate is what proves
     it ran. A green suite alone does NOT close the run.
   On BOTH green, record the pass to `.claude/task-runner/gate-pass.json` as ONE JSON
   object — `{"head":"<git rev-parse HEAD>"}` for a plain run; for a taskmaster-index
   run the SAME single object also carries
   `"index_path":"<00-INDEX.md>","cards_total":N,"cards_done":N,"cards_parked":N` from
   the index bookkeeping (JSON integers, all three counts together — never a second
   write that would clobber `head`) — and only THEN, with every card done or parked
   and the counts recorded, remove `active-run.json` (removing it earlier, or with a
   card unaccounted for, is what the Stop hook exists to catch — the sentinel stays
   until the counts prove completeness), then print the
   completion report table (task / status / verify command / evidence), parked tasks
   with reasons, and the follow-up backlog. If either gate is RED the run is not
   complete — do not print a done report. A run may not report complete while any card
   is neither done nor parked; the completion gate checks the recorded card counts for
   index runs.

5. Handoff — on a green completion report, if the git-workflow plugin is
   installed, ask via AskUserQuestion: "Finish the branch now (Recommended)"
   / "Stop here — I'll finish it later"; on finish, proceed exactly as
   /git-workflow:finish would. If tasks were parked, offer instead: "Retry
   parked tasks now" / "Stop here" — one offer, not both. Headless: print
   the exact next command.

**Goal marker** (`Goal: true` in `00-INDEX.md`, requires task-runner ≥0.11.0) — hands-off
execution per the task-execution skill. The step-1 run plan is displayed, then execution
proceeds without waiting. The step-5 green branch-finish gate is
EXEMPT from take-Recommended — under Goal it ALWAYS resolves to "Stop here" regardless of
which option is labeled Recommended (never auto-run branch merge/PR). The parked "Retry
parked tasks now" offer is bounded to one auto-retry on forward progress (a task moved
parked→done), else auto-take "Stop here" and surface the parked list. Halts-with-evidence,
mis-specified-task halts, and the full-suite + behavioral-gate completion gate are never suppressed.
