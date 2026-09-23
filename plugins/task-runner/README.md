# task-runner

Disciplined task execution: one task at a time, scope locked, bounded verify-fix
inner loop (max three cycles, then park with evidence), no unbounded outer loop,
full-suite completion gate.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install task-runner@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/task-runner:run [tasks-dir-index-or-list] [--tracks[=N]] [--crew] [--sweep]` | Execute a task list — a taskmaster `00-INDEX.md`, a plan's task sequence, or an inline list |
| `/task-runner:plan [task-or-list]` | The computed subagents-vs-inline verdict: dependency levels, agent count, speedup estimate |

## Boundary with Claude Code's built-in `/run` and `/batch`

The host's `/run` launches the project's app to see a change working — unrelated to
`/task-runner:run`, which executes a task list. The host's `/batch` fans work out as
one background subagent per worktree and opens a PR for each; `--tracks` also runs
milestones as worktree tracks but keeps the sole-writer merge rule — one orchestrator
merges every track, no per-track PR.

## Subagent discipline

The orchestration plugin was merged into this one on 2026-09-14: it shipped no
agent, and every one of its readers was already here. Two skills load on demand —
**delegation-contracts** when dispatching subagents, writing an agent prompt or
reading a report back (self-contained prompts, compressed evidence-backed returns,
model/effort tiering, scout-then-fanout, writer isolation, the role-floor registry
in `references/role-floors.md`, the tree-wide gate an orchestrator runs after
fan-in in `references/tree-wide-gates.md`), and **verification-panels** when
deciding whether an agent's findings can be trusted or judging competing attempts
(refuter voting, judge panels, loop-until-dry, completeness critic). The
`ultra-assess` boost hook is armed by writing "ultra-assess" in a prompt: it
injects the Extreme Boost directive for assessment-shaped runs (inventory, audit,
gap-analysis) and points at `verification-panels/references/ultra-assess.md`.

What has teeth there: the four string-checkable prompt-contract elements
(absolute path, scope lock, return shape, data-not-prose closer) are checked by
`scripts/dispatch-lint.sh` — run it over any drafted prompt file before
dispatch; a fixture harness runs in CI. Whether the scope lock locks the RIGHT
scope stays agent-graded. Orchestration's review command, which used to wrap
the lint, was retired with the merge: it reviewed prompts, not code, and the
lint plus the skill's own checklist are what it ran.

## Which model runs your cards

- **Workers inherit the session model.** Every worker agent ships `model: inherit`, so a card
  is implemented by whatever model you are running — batching does not change that.
- **Some agents carry a tier floor.** An agent listed in the role-floor registry is dispatched
  at `max(marker tier if present ELSE the session model, its floor)` — so a reviewer pinned to
  a stronger tier is never weaker than the session that wrote the code, and never caps it
  either. Registry and full rule:
  `plugins/task-runner/skills/delegation-contracts/references/role-floors.md`.
- **A boost raises further.** An `Ultra: true` / `Goal: true` marker in `00-INDEX.md` carries a
  `(model=…, effort=…)` tier into execution; workers and reviewers are dispatched at it. A
  `Goal: true (boost=off)` marker (taskmaster `goal-lean`, since 0.32.0) raises nothing and
  runs no code red-team: it is hands-off at the standard tier.

Not every agent tracks the session model, and that is deliberate: breadth and mechanical roles
(persona lenses, scouts, index builders) pin a mid tier by design, which can sit above or below
your session. The registry above says which agents floor and which do not.

## Example

```bash
/task-runner:run taskmaster-docs/tasks/2026-07-05-orders-csv-export/00-INDEX.md
/task-runner:run           # picks the most recent taskmaster-docs/tasks/*/00-INDEX.md
```

Each task runs its EXACT verify command; three failed fix cycles park the task
with evidence instead of drifting. After a task's verify passes, a conditional
reviewer pass runs when the review plugins are installed — code-reviewer on
every task; ui-ux, architecture, and security reviewers only when the task's
content warrants them. Blocker/major findings re-enter the bounded fix loop.
The run only completes when every task is done or parked AND the project's
full check suite passes — including api-design's doc-drift check when installed.

Status lives in the task index and the conversation — no HTML dashboards.
HTML/preview artifacts are reserved for content that needs them: mockups,
interactive walkthroughs, demos.

## Staying near the ask when there is no card

`scope.sh` warns, once per edit outside the set, when a card has declared its file
list — it never blocks. Most turns have no card, and there its first line exits — so
`drift.sh` asks one question, once per request, when a narrow ask has produced a wide
change: **12+** files edited (p90 of 169 measured local edit-turns), no breadth word in
the request, half of them never named in it.

Advisory, and it counts **breadth only**: an unasked refactor inside a file you did
name is invisible to it. `CC_DRIFT=off` silences it.

## Counting the subagents a fan-out actually spawned

`spawn-cap.sh` counts subagent dispatches per session and **asks** — a permission prompt,
never a refusal — once the count crosses 20, then at every doubling (40, 80, …). Subagent
turns do not appear in the transcript and they are billed, so a fan-out planned as three
agents and grown to thirty is invisible until the invoice; this is the only place it gets
counted. `ask` rather than `deny` because a large fan-out is sometimes right — the claim is
not that thirty is wrong, only that thirty should be a decision somebody made. Thresholds
double instead of firing every time, because asking at 21, 22, 23 trains reflexive approval.

It counts dispatches, not cost: twenty haiku calls and twenty opus calls are one number
here and not one bill. It cannot see an agent a subagent spawns through another mechanism,
and it says nothing about whether the fan-out was a good idea — that is
`/task-runner:plan`, which is prose. `CC_SPAWN_CAP=<n>` moves the first threshold;
`CC_SPAWN_CAP=off` disables it.

## The run cannot end by narration

A run registers itself at start, and a Stop hook — clause 4 of candor's gate since
2026-09-14, this plugin's `hooks/completion-gate.sh` before that; install candor or
the run can end by narration — refuses to let it end while the work is unfinished — no recorded behavioral-gate pass for the current HEAD, or
cards neither done nor parked. Ending a turn with "starting card 01 now" and no
tool call is blocked and fed back, so an announced next step actually happens
instead of leaving a dead turn the user waits on. An intentional pause is a tool,
not prose: a question via `AskUserQuestion`, or a parked card with a reason.

That sentinel outlives the session that wrote it, so a session opened cold used to meet
the Stop block at the end of its first turn knowing nothing about the run — and the
cheapest-looking escape was deleting the sentinel of a live one. `hooks/announce.sh`
(SessionStart, `startup|resume|clear`) says one line when the project has a registered
run: slug, branch, how many index cards are still open, and the declared arc phase.
**Standing: advisory** — SessionStart context informs a turn and cannot block one; the
teeth are still the Stop gate. It reads three files and writes nothing, is silent when
no run is registered, and leaves compaction to skill-router's capsule. It cannot tell a
live run from an abandoned one, and the card count is the index's bookkeeping rather
than the work.

## Nothing gets quietly dropped

A real run reviewed card 01, dropped the reviewer pass on cards 02-08 to save context,
reported "all 8 done, none parked", and passed every gate; the user found out by asking,
and closing the gap turned up a real bug. The step next to it — the per-card negative
control — could not be skipped that way, because a script writes its record and the gate
counts them. The reviewer pass was prose.

So the mandated passes now leave evidence a run cannot author for itself:

| Mandated step | Evidence | Gate |
|---|---|---|
| per-card reviewer pass | `rv-seen-*` written by a PostToolUse hook that sees the dispatch's `RV-CARD` marker | records ≥ done cards |
| behavioral gate | `bg-<head>.json` written by `behavioral-gate.sh` itself | must exist for the reported HEAD, and its verdict must be a passing one |
| red-team panel (boosted runs that shipped code) | `rt-lens-*` / `rt-critic-*` from the same observer | 3 lenses + 1 critic, or a recorded degradation |

Skips stay possible and stop being silent. `scripts/review-skip.sh` (per card) and
`scripts/reduction-record.sh` (`--kind redteam|dispatch|suite|coverage|other` — a degraded
panel, a downgraded dispatch, a narrowed suite, a dropped coverage pass, anything
else) record the cut with its reason and print it to the transcript at the moment of the
decision; in an interactive session a PreToolUse hook asks you to approve it first. The
completion gate then refuses a clean stop unless the closing report names each recorded
id. Design carve-outs — a track leaf, a reviewer plugin that is not installed — record an
exemption and never prompt.

Records written before the current registration are ignored, so a re-registration re-arms
every check and last week's run cannot satisfy this one.

What this does NOT prove: that a reviewer read carefully, that a reason is honest, or
anything at all in a run that never registered. Depth is invisible to a parent hook —
a subagent's transcript is a separate file.

The block is bounded twice over: it fires only on the branch the run registered
itself on, and at most once per commit — so a genuine stop costs one extra turn,
each new commit re-arms the gate for the next card, and a sentinel left behind by
an abandoned run cannot nag every stop in the repo. That sentinel is
`.claude/task-runner/active-run.json`; deleting it retires a run that will never
finish. Set `TASK_RUNNER_STOP_GATE=warn` to downgrade the block to a printed
reminder everywhere.

## Pairs well with

- **taskmaster** — produces the task cards this plugin executes
- **code-architecture** — its work-verification discipline applies to the whole run
- **code-review / ui-ux / security** — power the per-task reviewer pass when installed
- **api-design** — its doc-drift check (`/api-design:drift`) joins the completion gate when installed
