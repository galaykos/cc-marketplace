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

1. Load the tasks and their order/dependencies; show the run plan (order, parallel
   groups, verify command per task) before executing.
2. Execute per the task-execution skill: one task in progress, scope locked, the
   exact verify command per task, at most three fix cycles before parking; after
   each task's verify passes, run the reviewer pass per the skill (conditional
   on the review plugins installed), plus the full crew pass when `--crew` is set.
3. Update status in the index only; collect scope-lock follow-ups as a backlog
   list, never as in-run detours. No status HTML — the index and the
   conversation are the run's views (per the task-execution skill).
4. Finish with the full project check suite and the completion report table
   (task / status / verify command / evidence), parked tasks with reasons, and
   the follow-up backlog.

5. Handoff — on a green completion report, if the git-workflow plugin is
   installed, ask via AskUserQuestion: "Finish the branch now (Recommended)"
   / "Stop here — I'll finish it later"; on finish, proceed exactly as
   /git-workflow:finish would. If tasks were parked, offer instead: "Retry
   parked tasks now" / "Stop here" — one offer, not both. Headless: print
   the exact next command.
