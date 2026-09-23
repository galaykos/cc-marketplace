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
web-dev:frontend-reviewer                 opus
code-architecture:architecture-reviewer   opus
code-architecture:system-architect        opus
taskmaster:spec-adversary                 opus
ultra-deep-research:verifier              sonnet
```

A floor is the agent's own pin, reinterpreted — not a raise. `frontend-reviewer`'s verdict
is Reasoning-class, so an `inherit` pin would let a Sonnet session judge code with a
Sonnet-class verdict. `verifier` floors at `sonnet` because the risk is the *ceiling*, not
the level: capped at sonnet, an adversarial refuter would audit claims produced under a
stronger session.

An agent with no row here is **unfloored** — that is the correct default, not an oversight.

## The rule — two classes, one rule each

A single formula cannot serve both classes: one formula turns an explicit low-tier marker
(`Ultra: true (model=haiku)`) into a no-op for unfloored agents.

    FLOORED (every agent in the registry above — count it there, not here):
        model: = max( marker tier if a marker is present else session model,
                      role floor )
        ladder: haiku < sonnet < opus < fable

    UNFLOORED (every other agent):
        marker tier if a marker is present; otherwise omit `model:` entirely.

`auto` is not an explicit tier — it resolves per this plugin's
`verification-panels/references/dispatch-tier.md` (session model or opus, whichever is
higher), and only the resolution enters the max.

**For a floored agent under a marker this equals `ultra/SKILL.md`'s
`max(marker tier, frontmatter tier)`**; with no marker, the *session model* takes the
marker's place.

Worked cases:

| Case | Result |
|---|---|
| unboosted, fable session, `code-reviewer` | `max(fable, opus)` = fable |
| unboosted, sonnet session, `code-reviewer` | `max(sonnet, opus)` = opus |
| `Ultra: true (model=haiku)` marker, `code-reviewer` | `max(haiku, opus)` = opus |
| `Ultra: true (model=haiku)` marker, an `inherit` worker | haiku — the explicit-marker lever holds |
| a batch worker under any marker | the marker tier — it is unfloored |
| unboosted, opus session, `verifier` | `max(opus, sonnet)` = opus |
| unboosted, haiku session, `verifier` | `max(haiku, sonnet)` = sonnet |

A floor below `opus` is not a weaker floor — it is the same rule at the agent's own level.
`sonnet` is where `verifier` already sat; the row only stops it capping there.

Effort is **not** floored: the Agent tool has no `effort` parameter, so frontmatter `effort:`
stands. Effort remains a `Workflow`-path concern.

## Resolving this file

It lives in `task-runner`, which a consumer
plugin may not have installed. Probe in order:

1. `${CLAUDE_PLUGIN_ROOT}/skills/delegation-contracts/references/role-floors.md` (task-runner itself)
2. `${CLAUDE_PLUGIN_ROOT}/../task-runner/skills/delegation-contracts/references/role-floors.md`
3. `find ~/.claude/plugins/cache -path '*/delegation-contracts/references/role-floors.md'`
4. `plugins/task-runner/skills/delegation-contracts/references/role-floors.md`
5. Miss → omit `model:` and log one line on the dispatch site's own output surface (a
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

## Residual — main-thread PROACTIVE dispatch is not covered (Honest limitation law: `.claude/skills/authoring-skills/SKILL.md` (in the marketplace repository) "The four laws".)

`system-architect` has no dispatcher file anywhere; it is auto-dispatched by the main
thread from its `Use PROACTIVELY` description, and `code-reviewer` / `architecture-reviewer`
are likewise auto-dispatchable outside task-runner. No skill mediates those dispatches, so no
registry read happens and no floor applies. This registry governs **skill-mediated dispatch**.
Stated rather than silently accepted.
