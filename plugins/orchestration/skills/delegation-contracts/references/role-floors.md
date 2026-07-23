# Role-tier floors

Read on demand from delegation-contracts § Model and effort tiering. This file answers one
question: **which agents must never run below the session model, and how a dispatcher
computes that.**

A `model:` pin in agent frontmatter is a **ceiling as well as a floor**. The Agent tool has
no "minimum model" concept — omit `model:` and frontmatter governs; pass `model: X` and X
wins absolutely. So an opus-pinned judge in a session above opus reviews code written by a
stronger model than itself. The registry below is the list of agents where that matters, and
the rule that fixes it.

## Registry

Reasoning-class agents whose frontmatter tier is a FLOOR, not a ceiling:

```
code-review:code-reviewer                 opus
code-architecture:architecture-reviewer   opus
system-design:system-design-reviewer      opus
system-design:system-architect            opus
taskmaster:spec-adversary                 opus
ultra-deep-research:verifier              sonnet
```

A floor is the agent's own pin, reinterpreted — not a raise. `verifier` floors at `sonnet`
because the defect was the *ceiling*, never the level: it kept an adversarial refuter at
sonnet while the claims it audits were produced under a stronger session.

An agent with no row here is **unfloored** — that is the correct default, not an oversight.

## The rule — two classes, one rule each

A single formula cannot serve both classes; trying to write one is how an earlier draft
silently turned an explicit low-tier marker (`Ultra: true (model=haiku)`) into a no-op.

    FLOORED (the six above):
        model: = max( marker tier if a marker is present else session model,
                      role floor )
        ladder: haiku < sonnet < opus < fable

    UNFLOORED (every other agent): UNCHANGED from today.
        marker tier if a marker is present; otherwise omit `model:` entirely.

`auto` is not an explicit tier — it resolves per `taskmaster/skills/ultra/SKILL.md`
§ Fixed tier first (session model or opus, whichever is higher), and only the
resolution enters the max.

**For a floored agent under a marker this is exactly `ultra/SKILL.md`'s existing
`max(marker tier, frontmatter tier)`.** The only new behavior is that the *session model*
takes the marker's place when no marker is present. Nothing else about dispatch changes.

Worked cases:

| Case | Result | vs before |
|---|---|---|
| unboosted, fable session, `code-reviewer` | `max(fable, opus)` = fable | **fixed** — was opus |
| unboosted, sonnet session, `code-reviewer` | `max(sonnet, opus)` = opus | unchanged |
| legacy `Ultra: true (model=haiku)` marker, `code-reviewer` | `max(haiku, opus)` = opus | unchanged |
| legacy `Ultra: true (model=haiku)` marker, an `inherit` worker | haiku | unchanged — the explicit-marker lever survives |
| a batch worker under any marker | the marker tier | unchanged — it is unfloored |
| unboosted, opus session, `verifier` | `max(opus, sonnet)` = opus | **fixed** — was sonnet |
| unboosted, haiku session, `verifier` | `max(haiku, sonnet)` = sonnet | unchanged |

A floor below `opus` is not a weaker floor — it is the same rule at the agent's own level.
`sonnet` is where `verifier` already sat; the row only stops it capping there.

Effort is **not** floored: the Agent tool has no `effort` parameter, so frontmatter `effort:`
stands. Effort remains a `Workflow`-path concern.

## Resolving this file

It lives in `orchestration`, which a consumer plugin may not have installed. Probe in order:

1. `${CLAUDE_PLUGIN_ROOT}/../orchestration/skills/delegation-contracts/references/role-floors.md`
2. `find ~/.claude/plugins/cache -path '*/delegation-contracts/references/role-floors.md'`
3. `plugins/orchestration/skills/delegation-contracts/references/role-floors.md`
4. Miss → omit `model:` and log one line on the dispatch site's own output surface (a
   task-runner run report, else the run's status output):
   `role-floors.md unresolved — floors not applied`

**That degradation reinstates the defect.** It is accepted only because it is *visible*.
Falling back to frontmatter is not "safe" — frontmatter-as-ceiling is the bug. Registry rows
equalling frontmatter values buys compatibility with an older runner, nothing more.

## What is deliberately NOT here

- **Breadth and mechanical pins.** `approaches:opinion-lens`, `brain:indexer`,
  `hindsight:transcript-miner` and `ultra-deep-research:researcher` pin `sonnet` and are
  *correct* running below the session model — see `taskmaster/skills/ultra/references/dispatch-tiers.md`
  § Role → tier ladder. Flooring them would be the "uniform model for every stage"
  anti-pattern this skill names.

`ultra-deep-research` splits across both classes deliberately, and the split is the ladder,
not an oversight: `researcher` is a breadth shard — N in parallel, one facet each, fetch and
extract against a verbatim-quote gate, merged after — so it stays native. `verifier` is one
agent per claim told to *break* it under ordered provenance rules, the same shape as
`spec-adversary`, so it takes a row. Producer and auditor land in different classes because
the work differs, not because one was missed.

## Residual — main-thread PROACTIVE dispatch is not covered

`system-design-reviewer` has no dispatcher file anywhere; it is auto-dispatched by the main
thread from its `Use PROACTIVELY` description, and `code-reviewer` / `architecture-reviewer`
are likewise auto-dispatchable outside task-runner. No skill mediates those dispatches, so no
registry read happens and no floor applies. This registry governs **skill-mediated dispatch**.
Stated rather than silently accepted.
