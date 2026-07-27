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

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install approaches@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/approaches:compare [task]` | Compare 2-3 structurally different approaches to a task — trade-off table, pick, kill-trigger — before any implementation |
| `/approaches:opinions [task]` | Run an opinion-round on a task — four parallel blind opinion-lens personas argue the approach, synthesized inline to one pick + kill-trigger — before any implementation |
| `/approaches:build-vs-buy [capability]` | Build-vs-buy check before implementing a capability — existing-solution search, health table, take/wrap/write verdict |
| `/approaches:size [task-or-list]` | S/M/L/XL sizing per item with anchor comparison, uncertainty flag, and split recommendation for anything L+ |
| `/approaches:rollout [feature-description]` | Rollout plan for a feature about to ship — flag strategy, compatibility window, exposure stages, rollback trigger and path |
| `/approaches:pattern [problem-description]` | Suggest (or reject) a design pattern for a described problem |

## Example

```bash
/approaches:compare add rate limiting to the public API
/approaches:opinions migrate the session store from files to Redis
```

## Pairs well with

- **code-architecture** — hands the chosen approach to a file-level plan before coding
- **taskmaster** — deliberation steps aside when the grill/brainstorm pipeline already owns the task
