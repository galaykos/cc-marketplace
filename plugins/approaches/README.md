# approaches

Solution-approach deliberation before non-trivial implementation: generate 2-3
structurally different approaches, compare trade-offs, and commit with a stated
kill-trigger — backed by a strategy catalog (tracer bullet, walking skeleton,
spike, strangler fig, inversion, Polya) mapped to the risk each one beats, and
a blind opinion round where four parallel opinion-lens personas (Standards
Purist, Quality-over-Speed, Pragmatist-Minimalist, Skeptic-Investigator) argue
rework-shaped tasks.

The `build-vs-buy`, `estimation`, `rollout`, and `design-patterns` plugins were
merged into this one: their skills (build-vs-buy, estimation, rollout-planning,
pattern-selection) now ship here, their commands live on below, and
build-vs-buy's UserPromptSubmit reminder hook moved over intact — it now nudges
toward `/approaches:build-vs-buy`. Nothing was dropped in the merge.

The fresh-take plugin was merged into this one on 2026-09-14: `/approaches:consult` composes a
facts-only brief and dispatches the blind `consultant` agent (stronger-model,
read-only) at the two key moments — stuck after repeated failed fixes, or one
keystroke from something irreversible — and its `hooks/consult-remind.sh` nudge
on irreversible-command tokens came with it. Both are `decide`-phase blind second
opinions, the same shape as the opinion panel; the plugin boundary carried nothing.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install approaches@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/approaches:compare [task]` | Compare 2-3 structurally different approaches to a task — trade-off table, pick, kill-trigger — before any implementation |
| `/approaches:opinions [task]` | Deliberate a task's shape as a blind panel — four parallel opinion-lens personas argue it, synthesized inline to one pick + kill-trigger — before any implementation |
| `/approaches:build-vs-buy [capability]` | Build-vs-buy check before implementing a capability — existing-solution search, health table, take/wrap/write verdict |
| `/approaches:size [task-or-list]` | S/M/L/XL sizing per item with anchor comparison, uncertainty flag, and split recommendation for anything L+ |
| `/approaches:rollout [feature-description]` | Rollout plan for a feature about to ship — flag strategy, compatibility window, exposure stages, rollback trigger and path |
| `/approaches:pattern [problem-description]` | Suggest (or reject) a design pattern for a described problem |
| `/approaches:consult [topic]` | A blind stronger-model second opinion at a key moment — stuck debugging (from the second failed cycle) or an imminent irreversible action. Facts-only brief, `scripts/brief-lint.sh` rejects leaning phrasing mechanically; returns a Take, Risks and one Alternative. Advice only — never blocks, gates or edits |

## Example

```bash
/approaches:compare add rate limiting to the public API
/approaches:opinions migrate the session store from files to Redis
```

## Hooks

| Event | Script | Does |
| --- | --- | --- |
| `UserPromptSubmit` | `hooks/remind.sh` | build-vs-buy nudge when the prompt carries a making verb and a commodity-capability noun; `decide` phase, stands down once the arc has moved on |
| `UserPromptSubmit` | `hooks/consult-remind.sh` | one advisory line naming `/approaches:consult` on an irreversible-command token (`rm -rf`, `reset --hard`, `drop table`, `migrate:fresh`, `force push`) or a repeated-attempt phrase; `any` phase — a guard, not a step. The stuck-loop phrases belong to debugging's reminder |
| `SessionStart` (compact) | `hooks/compact-recovery.sh` | re-injects the deliberation marker after a compaction so a settled shape is not re-deliberated |

The consult nudge only suggests the command; it may repeat on later matching
prompts, and ignoring it is always legitimate. The consult itself dispatches a
stronger-model subagent — a spend decision, which is why this plugin is not in
always-on-suite.

## Pairs well with

- **code-architecture** — hands the chosen approach to a file-level plan before coding
- **taskmaster** — deliberation steps aside when the grill/brainstorm pipeline already owns the task
- **debugging** — owns the stuck moment at three failures; `/approaches:consult` is the cheap exit one cycle earlier
