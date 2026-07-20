# approaches

Solution-approach deliberation before non-trivial implementation: generate 2-3
structurally different approaches, compare trade-offs, and commit with a stated
kill-trigger — backed by a strategy catalog (tracer bullet, walking skeleton,
spike, strangler fig, inversion, Polya) mapped to the risk each one beats, and
a blind opinion round where four parallel opinion-lens personas (Standards
Purist, Quality-over-Speed, Pragmatist-Minimalist, Skeptic-Investigator) argue
rework-shaped tasks.

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

## Example

```bash
/approaches:compare add rate limiting to the public API
/approaches:opinions migrate the session store from files to Redis
```

A `UserPromptSubmit` hook watches plain prompts for rework-shaped keywords
(refactor, rewrite, restructure, migrate, redesign, ...) and prints a one-line
nudge toward `/approaches:opinions`. It never blocks the prompt and stays
silent on slash commands.

## Pairs well with

- **code-architecture** — hands the chosen approach to a file-level plan before coding
- **taskmaster** — deliberation steps aside when the grill/brainstorm pipeline already owns the task
