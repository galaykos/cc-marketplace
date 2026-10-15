---
description: Execute a task list with scope lock, bounded verify-fix loops, and a full-suite completion gate
argument-hint: [tasks-dir-index-or-list] [--tracks[=N]] [--crew] [--sweep]
---
<!-- host-ok --> Shares its name with the host's /run, which launches and drives the project's app; this executes a task list.

Invoke the task-execution skill from this plugin and run the task list in
$ARGUMENTS — a taskmaster `00-INDEX.md` path, a tasks directory, a plan's task
sequence, or an inline list. If no argument, look for the most recent
`taskmaster-docs/tasks/*/00-INDEX.md`; if none exists, ask for the list.

**`--tracks[=N]`** — if `$ARGUMENTS` includes `--tracks`, establish the run branch first
(`track-orchestration`'s run-branch precondition), then register the run on it with step 1's
`scripts/register-run.sh`, again if a route registered earlier: candor's completion clause
and the spawn cap apply a run only on the branch it registered on. Then run via the
`track-orchestration` skill from this plugin instead of the serial path below:
independent milestones run as concurrent git-worktree tracks. `N` is clamped to
`[1,6]`; `--tracks=1` warns and runs serial; `--tracks=0`, negative, or non-integer is a
usage error (do not run); bare `--tracks` uses the default cap `min(eligible, 4)`. With
no `--tracks` — or when the index lacks per-milestone `Files:` sets or has 0–1 eligible
milestone — run the serial `task-execution` path below.

**`--sweep`** — at-scale mechanical change (a codemod, a rename, "replace every X
with Y") rather than a task list. Bounded by a residual gate instead of a card count:

1. FREEZE the target set before editing anything —
   `bash "${CLAUDE_PLUGIN_ROOT}/scripts/sweep-residual.sh" --freeze --id <id> --pattern <ere>`.
   Enumerate in FOUR passes, not one: the direct form; the aliased, re-exported or
   barrel form; the dynamic or string-constructed reference; and non-code carriers
   (config, CI yaml, docs, fixtures, i18n keys). What one grep misses is invisible
   to the gate too, so the passes are the work, not ceremony.
2. Execute in COMMITTED BATCHES through the ordinary inner loop, one commit per
   batch, so every step is bisectable and a bad batch reverts alone.
3. MEASURE after each batch: `--measure --id <id>`. Exit 2 = residual survives,
   4 = the target set moved (a file carrying the pattern appeared after the freeze
   — re-freeze deliberately, never edit the state file), 5 = cannot measure. The
   residual must strictly DECREASE batch over batch; a batch that does not move it
   is a batch that edited the wrong thing.
4. FINISH at zero, or record every survivor with
   `--allow --id <id> --file <path> --reason "<why it stays>"`. A survivor with no
   written reason is not allowed — that is the difference between an allowlist and
   a suppression comment.

Why the gate exists: handed twelve occurrences where three sit behind an aliased
import and one is built at runtime, the honest failure is not knowledge. It is that
nothing re-runs the enumeration after the edits, so a green suite over the paths
that HAVE tests reads as a finished migration. Batches are disjoint by
construction, so they are exactly what `--tracks` already consumes.

**`--crew`** — a bare boolean opt-in (default off; `--crew=<value>` is a usage error). When
present, after each **directly-dispatched** card's build verify passes, run the per-card
crew per `skills/task-execution/references/crew.md`: the read-only reviewers concurrently
(a `Bash`-holding reviewer, security-engineer included, runs serially), then a sequential
**test-files-only** `test-engineer` authoring pass (scope-locked by the diff-vs-declared
check), then an unconditional card-verify re-run and a fresh bounded fix loop. Combos:
`--crew`; `--tracks[=N] --crew`; `--tracks=1 --crew` — crew applies only to serial cards /
non-eligible milestones, **never** inside a track leaf or any delegated parallel-group leaf.
`--crew` is the **sole** trigger: no hook, no `Ultra: true` marker, and no
`ultra-task`/`ultra-assess` run engages crew; without `--crew` no crew step runs.

**Auto-pick (no dispatch flag)** — when `$ARGUMENTS` includes no dispatch flag (`--tracks`
absent), consult `parallel-planning`'s `Dispatch:` recommendation
(`skills/parallel-planning/references/dispatch-selection.md`) and honor it:

- `Dispatch: default` → the serial `task-execution` path below; its per-level
  `INLINE`/`DELEGATE`/`BATCH` verdicts decide subagent use and need no extra
  confirmation. A **BATCH** level
  dispatches each same-worker disjoint S-batch as one agent per
  `skills/task-execution/references/routing.md` § Batch dispatch — one commit per card,
  and per-card verify + negative-control + scope check + reviewer pass on return.
- `Dispatch: workflow-tracks` → engage the `--tracks` path, but only under the **Run-now
  confirmation** (interactive) or a **`Goal:` marker** (hands-off), AND only if track
  preconditions hold (non-base run branch + clean tree + per-milestone `Files:` sets). If
  preconditions are unmet, **downgrade to the default path**, record it with
  `scripts/reduction-record.sh --kind dispatch --id <milestone|run> --reason "<why>"`,
  and name it in the run report — the record makes that disclosure mandatory (the
  completion gate blocks a report that omits it) instead of a rule nothing read. Auto-picked
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
   and the user waits on a turn that already ended. Register the run first, in the
   same step: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/register-run.sh" --index <00-INDEX.md> --session "<this session id>"`
   (an inline list: `--slug <name>`). It writes `.claude/task-runner/active-run.json`
   (`slug`, `base`, `branch`, `start_sha`, `index_path`), which arms candor's Stop-hook
   completion clause on this branch only; deletes the `gate-pass.json` and
   `bg/bg-<HEAD>.json` an earlier run left, which that clause would trust for HEAD;
   creates `rv/`, `rt/`, `bg/`, `nc/` and `reductions/`, each arming one record check by
   existing; and writes the `build` arc phase sentinel through taskmaster's writer, so the
   reminder hooks that own an earlier phase stand down. A second call for the same index on
   the same branch resumes the run rather than discarding its records (`--fresh` starts
   over). The task-execution skill's step 1 and `/task-runner:plan`'s "Run now" call the
   same script, so no route runs unregistered. Records older than the registration are
   ignored by the clause. It also seeds `.claude/task-runner/env-notes.md` once, with "never
   read `.env`"; the preamble has every worker read it, so write an environment fact there
   (a host binary's path, a container shim, a capped test command), never into each dispatch.
2. Execute per the task-execution skill: one task in progress, scope locked, the
   exact verify command per task, at most three fix cycles before parking; after
   each task's verify passes, run the reviewer pass per the skill (conditional
   on the review plugins installed), plus the full crew pass when `--crew` is set.
3. Update status in the index only; collect scope-lock follow-ups as a backlog
   list, never as in-run detours. No status HTML — the index and the
   conversation are the run's views (per the task-execution skill).
4. First the **whole-range review**: invoke `/code-review:review <start_sha>..HEAD` (Skill
   tool; `start_sha` is in `active-run.json`) with `RV-RANGE: <first 12 of HEAD>` in its
   arguments and a lens for knowledge duplicated across cards. The review observer records
   that marker, and candor's clause 4 requires the record at the closing HEAD. Required:
   per-card passes never substitute, because they cannot see what changed across cards.
   Fix its findings through the bounded fix loop; a commit after the review moves HEAD, so
   mark a pass over `<reviewed head>..HEAD` with the new HEAD. A skip needs the user's
   approval and `scripts/review-skip.sh --card range-<HEAD12> --reason "<why>"` (no
   code-review installed: `--exempt no-reviewer-installed`), and appears under `Skipped:`.
   Then finish with BOTH completion gates, never one alone:
   - the full project check suite (catches lint/type/build regressions), AND
   - the **behavioral-gate** on the run's changed files —
     `${CLAUDE_PLUGIN_ROOT}/scripts/behavioral-gate.sh --isolate --changed "<the run's
     touched files>" [--entrypoint <bin>] [--differential 'flag::with::without']
     [--runner '<cmd>::<empty-output-regex>'] [--runner-for <lang> '<cmd>::<empty-output-regex>']`,
     run from the repo root after committing, in background Bash with `timeout: 7200000`:
     a foreground call ends by 10 minutes, a background one by 30 unless told more (CLI
     2.1.285+; from 2.1.288 in `-p`, SDK, CI and cloud only), and neither stop leaves a verdict.
     `--isolate` builds, verifies and removes its own worktree of HEAD, under the repo's
     gitignored `.claude/task-runner/iso/`, and never touches
     the live `.env`; do NOT hand-build a checkout (`git worktree add`, `cd /tmp/…`,
     `cp .env…`, `key:generate`) — that improvisation destroyed a live `.env` once. Without
     `--isolate` the gate refuses to run in a registered run's live tree. The gate resolves a
     runner for py, js/ts, go, php, rust, ruby and java/kotlin on its own; for any other
     language pass `--runner` with the suite command and the output that means it ran
     nothing (`skills/behavioral-gate/references/runners.md`), or the run cannot close. A
     suite that runs only in a container replaces the built-in with `--runner-for <lang>`
     (`--runner` adds, and the failing host runner still decides); the isolated tree is
     `$BG_TREE_REL` from the repo root (so `/app` must mount the repo root), single-quoted
     so the gate expands it, and the suite needs its own `timeout`, because the gate's cap
     kills the `docker exec` client, not the suite inside the container:
     `--runner-for php 'docker exec -w "/app/$BG_TREE_REL" app timeout 1700 vendor/bin/pest::No tests found'`.
     The replacement must still print that language's test count, or a sibling runner's
     (`skills/behavioral-gate/references/runners.md`), or the verdict is `unverifiable-suite`. Under
     `--isolate` the verdict record lands in the live repo's `.claude/task-runner/bg`, which
     the Stop hook reads; `--record-dir` overrides it. The repo suite may be a
     static linter that never executes the new code; the behavioral-gate is what proves
     it ran. A green suite alone does NOT close the run.
   - **No runner in the project** — `no-behavioral-coverage` because a changed language
     has no test runner here at all (React files in a repo with no JS runner) is the one
     red verdict with a recorded exit: run
     `bash "${CLAUDE_PLUGIN_ROOT}/scripts/reduction-record.sh" --kind coverage --id bg-<first 12 chars of HEAD> --reason "<which files, why no runner>"`
     for the HEAD the gate ran on, then record the gate pass below as for a green gate.
     candor's Stop gate accepts that verdict only with that record for that HEAD. Code
     whose runner exists but has no tests is not this case: write the tests.
   On BOTH green (or the recorded no-runner exit), record the pass to `.claude/task-runner/gate-pass.json` as ONE JSON
   object — `{"head":"<git rev-parse HEAD>"}` for a plain run; for a taskmaster-index
   run the SAME single object also carries
   `"index_path":"<00-INDEX.md>","cards_total":N,"cards_done":N,"cards_parked":N` from
   the index bookkeeping (JSON integers, all three counts together — never a second
   write that would clobber `head`) — and only THEN, with every card done or parked
   and the counts recorded, rename `active-run.json` to `closed-run.json` (`mv`, which
   keeps its time) **and clear the phase sentinel** (delete `.claude/cc-phase.json` at the
   repo root), then print the
   completion report table (task / status / verify command / evidence), parked tasks
   with reasons, the follow-up backlog, and every recorded reduction by id and reason —
   `bg-<HEAD12>` when the no-runner exit was taken. When cards touched UI, the report also carries one Screens table (screen · width · before · after · not observed) per `skills/task-execution/references/ui-walk.md`, whose walk is also the `--evidence` for that no-runner record.
   The rename, not a delete: the stop after the report is where candor's clause 4 reads
   the records (reviewer, control, range, disclosure), and it retires `closed-run.json`
   when they hold. The review observer and the skip-consent ask still treat it as the run,
   so a review that block asks for is recorded; every other hook reads only
   `active-run.json`, so the run reads as ended at once. Without candor nothing retires
   the closed file, and the next registration deletes it.
   If either gate is RED, other than
   that recorded exit, the run is not
   complete — do not print a done report. A run may not report complete while any card
   is neither done nor parked; the completion gate checks the recorded card counts for
   index runs.

5. Handoff — on a green completion report, if the git-workflow plugin is
   installed, ask via AskUserQuestion: "Finish the branch now (Recommended)"
   / "Stop here — I'll finish it later"; on finish, proceed exactly as
   /git-workflow:finish would. If tasks were parked, offer instead: "Retry
   parked tasks now" / "Stop here" — one offer, not both. Headless: print
   the exact next command.

**Goal marker** (`Goal: true` in `00-INDEX.md`) — hands-off
execution per the task-execution skill. The step-1 run plan is displayed, then execution
proceeds without waiting. The step-5 green branch-finish gate is
EXEMPT from take-Recommended — under Goal it ALWAYS resolves to "Stop here" regardless of
which option is labeled Recommended (never auto-run branch merge/PR). The parked "Retry
parked tasks now" offer is bounded to one auto-retry on forward progress (a task moved
parked→done), else auto-take "Stop here" and surface the parked list. Halts-with-evidence,
mis-specified-task halts, and the full-suite + behavioral-gate completion gate are never suppressed.
