---
description: Red-team a frozen taskmaster spec — a blind adversary hunts edge cases, assumptions, conflicts, failure/security gaps; resolve each before cards
argument-hint: [spec-path-or-slug]
---

Run the spec-redteam skill from this plugin on $ARGUMENTS (a
`taskmaster-docs/specs/<name>.md` path or a slug; if empty, use the most recent
spec under `taskmaster-docs/specs/`).

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
as `ULTRA-TASK ACTIVE` per the taskmaster `ultra` skill (an N=3 blind adversary
panel on the Workflow path, subagents at the selected model, and the ⚡ banner).

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
goal, auto-resolve every hole WITHIN this command (derive-then-take
Amend/Accept/Dismiss) while security/auth/data-loss holes are NEVER auto-accepted,
writing no execution marker; only task-cards stamps the `Goal: true` marker.

1. Resolve the target spec file.
2. Invoke the spec-redteam skill — apply its blast-radius gate; when met, dispatch
   the blind `spec-adversary` agent on the spec path and present the holes grouped
   by lens.
3. Resolve each hole with the skill's blocking gate (Amend the spec / Accept as
   known risk / Dismiss as non-issue); on a trivial spec, print the skip note.
