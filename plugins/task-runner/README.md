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
| `/task-runner:run [tasks-dir-index-or-list]` | Execute a task list — a taskmaster `00-INDEX.md`, a plan's task sequence, or an inline list |

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
full check suite passes — including docs-upkeep's drift check when installed.

Status lives in the task index and the conversation — no HTML dashboards.
HTML/preview artifacts are reserved for content that needs them: mockups,
interactive walkthroughs, demos.

## The run cannot end by narration

A run registers itself at start, and a Stop hook refuses to let it end while the
work is unfinished — no recorded behavioral-gate pass for the current HEAD, or
cards neither done nor parked. Ending a turn with "starting card 01 now" and no
tool call is blocked and fed back, so an announced next step actually happens
instead of leaving a dead turn the user waits on. An intentional pause is a tool,
not prose: a question via `AskUserQuestion`, or a parked card with a reason.

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
- **docs-upkeep** — its drift check joins the completion gate when installed
