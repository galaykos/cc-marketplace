# orchestration

Subagent orchestration discipline: delegation contracts (self-contained
prompts, compressed evidence-backed returns, model/effort tiering,
scout-then-fanout, writer isolation), verification panels (refuter voting,
judge panels, loop-until-dry, completeness critic), and agent conventions
(engineer/reviewer naming taxonomy, one-surface PROACTIVELY arbitration, the
shared apply-fixes contract).

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install orchestration@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/orchestration:review [plan-or-prompts]` | Audit a planned fan-out or drafted subagent prompts against delegation-contracts and verification-panels — contract gaps, missing verify stages, tier mismatches; report-only |

## How it works

Three discipline skills load on demand: **delegation-contracts** when
dispatching subagents or reading their reports back, **verification-panels**
when deciding whether an agent's findings can be trusted or judging competing
attempts, and **agent-conventions** when naming a new agent or arbitrating
which reviewer fires on an edit. A fourth, **ultra-assess**, is armed by a
UserPromptSubmit hook: writing "ultra-assess" in a prompt injects the Extreme
Boost directive for assessment-shaped runs — inventory, audit, gap-analysis —
escalating subagents to auto/xhigh by default — the session model or opus,
whichever is higher (overridable via an
`ultra-assess-<model>[-<effort>]` suffix) and mandating red-team plus
completeness-critic passes over the findings. Output is a findings backlog,
never task cards.

## Example

```bash
/orchestration:review taskmaster-docs/tasks/checkout/00-INDEX.md
/orchestration:review    # audits the most recent task-card index
```

## Pairs well with

- **task-runner** — the parallelize-or-inline verdict and execution loop these contracts feed
- **taskmaster** — produces the card indices with parallel groups that the review command audits
- **code-architecture** — task-orchestration decomposes the work these contracts then dispatch
- **claude-authoring** — scaffolds new agents that agent-conventions keeps in taxonomy
