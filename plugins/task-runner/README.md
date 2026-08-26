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

## Which model runs your cards

- **Workers inherit the session model.** Every worker agent ships `model: inherit`, so a card
  is implemented by whatever model you are running — batching does not change that.
- **Some agents carry a tier floor.** An agent listed in the role-floor registry is dispatched
  at `max(marker tier if present ELSE the session model, its floor)` — so a reviewer pinned to
  a stronger tier is never weaker than the session that wrote the code, and never caps it
  either. Registry and full rule:
  `plugins/orchestration/skills/delegation-contracts/references/role-floors.md`.
- **A boost raises further.** An `Ultra: true` / `Goal: true` marker in `00-INDEX.md` carries a
  `(model=…, effort=…)` tier into execution; workers and reviewers are dispatched at it.

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
full check suite passes — including api-docs-first's doc-drift check when installed.

Status lives in the task index and the conversation — no HTML dashboards.
HTML/preview artifacts are reserved for content that needs them: mockups,
interactive walkthroughs, demos.

## Staying near the ask when there is no card

`scope.sh` enforces a card's declared file list. Most turns have no card, and there
its first line exits — so `drift.sh` asks one question, once per request, when a
narrow ask has produced a wide change: **12+** files edited (p90 of 169 measured
local edit-turns), no breadth word in the request, half of them never named in it.

Advisory, and it counts **breadth only**: an unasked refactor inside a file you did
name is invisible to it. `CC_DRIFT=off` silences it.

## The run cannot end by narration

A run registers itself at start, and a Stop hook refuses to let it end while the
work is unfinished — no recorded behavioral-gate pass for the current HEAD, or
cards neither done nor parked. Ending a turn with "starting card 01 now" and no
tool call is blocked and fed back, so an announced next step actually happens
instead of leaving a dead turn the user waits on. An intentional pause is a tool,
not prose: a question via `AskUserQuestion`, or a parked card with a reason.

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
`scripts/reduction-record.sh` (a degraded panel, a downgraded dispatch, a narrowed
suite) record the cut with its reason and print it to the transcript at the moment of the
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
- **api-docs-first** — its doc-drift check (`/api-docs-first:drift`) joins the completion gate when installed
