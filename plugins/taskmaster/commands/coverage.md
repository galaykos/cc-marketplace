---
description: Verify a task-card set covers its spec's success criteria — flag gaps, orphans, and drift, and resolve each before execution
argument-hint: [tasks-dir-or-slug]
---

Run the coverage-check skill from this plugin on $ARGUMENTS (a
`taskmaster-docs/tasks/<slug>/` directory or a slug; if empty, use the most
recent `taskmaster-docs/tasks/*/00-INDEX.md`).

**Run-status line (always):** print ONE status line as the first visible output of
every run, boosted or not — a boosted run prints the ⚡ banner (owned by the
ultra/ultra-goal skill; the banner IS its status line); a standard run prints
`▷ taskmaster standard run — subagents inherit the session model (<model>) · boost: off`.


**Ultra flag:** run in Extreme Boost mode ONLY when $ARGUMENTS *begins* with a
bare `ultra` token (this command invoked as `/taskmaster:<cmd> ultra …`) or
contains the explicit `ultra-task`/`ultratask` token. A bare `ultra` that is not
the first token of THIS command's own arguments — e.g. an earlier command's own
intensity flag in a chained message, such as a `caveman ultra` preceding this
command — is NOT a taskmaster trigger and never boosts this run; only
`ultra-task`/`ultratask`
crosses a command boundary. The `ultra`/`ultra-task` token may carry a
`-<model>[-<effort>]` suffix — e.g. `ultra-sonnet-xhigh`, `ultra-task-opus` (model
∈ auto|opus|sonnet|haiku|fable, default auto (session model or opus, whichever is higher); effort ∈ low|medium|high|xhigh|max,
default xhigh) — resolved per the `ultra` skill's Variants section. On a match, strip the matched token and treat the run
as `ULTRA-TASK ACTIVE` per the taskmaster `ultra` skill (loop-until-dry coverage
sweeps on the Workflow path, capped at 3 rounds or first dry, and the ⚡ banner).

**Goal flag:** run in hands-off Extreme Boost mode ONLY when $ARGUMENTS *begins* with a
bare `goal` token (this command invoked as `/taskmaster:<cmd> goal …`) or contains
the explicit `ultra-goal`/`ultragoal` token. A bare `goal` that is not the first
token of THIS command's own arguments — e.g. an earlier command's flag in a chained
message — is NOT a taskmaster trigger and never activates this run; only
`ultra-goal`/`ultragoal` crosses a command boundary. The token may carry a
`-<model>[-<effort>]` suffix — e.g. `ultra-goal-sonnet-xhigh`, `goal-opus` (model ∈
auto|opus|sonnet|haiku|fable, default auto (session model or opus, whichever is higher); effort ∈ low|medium|high|xhigh|max, default
xhigh) — resolved per the taskmaster `ultra-goal` skill
(`skills/ultra-goal/SKILL.md`), the canonical owner of this mode. Ultra-goal implies
the full ULTRA-TASK boost: when an `ultra-task` token is also present its tier wins;
ultra-goal's suffix applies only when no ultra-task token is present. On a match,
strip the token and run as `ULTRA-GOAL ACTIVE` per that skill — standalone under
goal, auto-resolve every GAP/ORPHAN/DRIFT WITHIN this command (derive-then-take),
writing no execution marker; only task-cards stamps the `Goal: true` marker.

1. Resolve the target: the `00-INDEX.md` and the spec it links under
   `taskmaster-docs/specs/`.
2. Invoke the coverage-check skill — cross-check the spec's `## Success criteria`
   against every card's `**Acceptance criteria:**` in both directions (coverage
   and traceability), plus the drift check.
3. Present the coverage matrix, then take each GAP / ORPHAN / DRIFT through its
   resolution choice per the skill; block until every finding is resolved or
   explicitly accepted.
4. Write the `## Coverage` section into `00-INDEX.md`. On a clean pass, print the
   matrix and stop.
