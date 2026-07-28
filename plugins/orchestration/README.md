# orchestration

Subagent orchestration discipline: delegation contracts (self-contained
prompts, compressed evidence-backed returns, model/effort tiering,
scout-then-fanout, writer isolation), verification panels (refuter voting,
judge panels, loop-until-dry, completeness critic), plus the shared
apply-fixes contract and the fleet mapping for review-only plugins.

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

Two discipline skills load on demand: **delegation-contracts** when
dispatching subagents or reading their reports back, and **verification-panels**
when deciding whether an agent's findings can be trusted or judging competing
attempts. Naming a new agent, and arbitrating which reviewer fires on an edit,
belong to `claude-authoring`'s **authoring-agents** skill. A third,
**ultra-assess**, is armed by a
UserPromptSubmit hook: writing "ultra-assess" in a prompt injects the Extreme
Boost directive for assessment-shaped runs — inventory, audit, gap-analysis —
escalating reasoning subagents to a fixed auto/xhigh tier (the session model or
opus, whichever is higher; no suffix grammar) and mandating red-team plus
completeness-critic passes over the findings. Output is a findings backlog,
never task cards.

One parallel-execution rule is easy to miss because it produces no error and no
symptom: a per-agent scope lock scopes each agent's VERIFY command too. For a
cross-cutting property — a banned vocabulary, "no gradient fills", a token
discipline — N agents each honestly report green over their own files and the
property is verified nowhere; and a tree-wide command (`tsc`, a build, the test
suite) run while siblings are still writing reports on their half-saved files
rather than on the runner's own diff. Both need **one tree-wide gate, run by the
orchestrator after fan-in**:
`skills/delegation-contracts/references/tree-wide-gates.md`.

## Example

```bash
/orchestration:review taskmaster-docs/tasks/checkout/00-INDEX.md
/orchestration:review    # audits the most recent task-card index
```

## Pairs well with

- **task-runner** — the parallelize-or-inline verdict and execution loop these contracts feed
- **taskmaster** — produces the card indices with parallel groups that the review command audits
- **code-architecture** — task-orchestration decomposes the work these contracts then dispatch
- **claude-authoring** — owns agent authoring: the naming taxonomy and PROACTIVE-trigger arbitration live in its `authoring-agents` skill
