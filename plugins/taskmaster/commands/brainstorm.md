---
description: Shape a fuzzy idea into an approved design doc, then hand off to the taskmaster pipeline
argument-hint: [idea]
---

Run the brainstorm skill from this plugin on $ARGUMENTS (if empty, ask what
idea the user wants to explore). No implementation code, scaffolding, or file
creation beyond the design doc at any point.

**Ultra flag:** run in Extreme Boost mode ONLY when $ARGUMENTS *begins* with a
bare `ultra` token (this command invoked as `/taskmaster:<cmd> ultra …`) or
contains the explicit `ultra-task`/`ultratask` token. A bare `ultra` that is not
the first token of THIS command's own arguments — e.g. an earlier command's own
intensity flag in a chained message, such as a `caveman ultra` preceding this
command — is NOT a taskmaster trigger and never boosts this run; only
`ultra-task`/`ultratask`
crosses a command boundary. The `ultra`/`ultra-task` token may carry a
`-<model>[-<effort>]` suffix — e.g. `ultra-sonnet-xhigh`, `ultra-task-opus` (model
∈ opus|sonnet|haiku|fable, default opus; effort ∈ low|medium|high|xhigh|max,
default xhigh) — resolved per the `ultra` skill's Variants section. On a match, strip the matched token and treat the run
as `ULTRA-TASK ACTIVE` per the taskmaster `ultra` skill (the selected model on
reachable subagents, bounded Workflow fan-outs, and the ⚡ banner).

**Goal flag:** run in hands-off Extreme Boost mode ONLY when $ARGUMENTS *begins* with a
bare `goal` token (this command invoked as `/taskmaster:<cmd> goal …`) or contains
the explicit `ultra-goal`/`ultragoal` token. A bare `goal` that is not the first
token of THIS command's own arguments — e.g. an earlier command's flag in a chained
message — is NOT a taskmaster trigger and never activates this run; only
`ultra-goal`/`ultragoal` crosses a command boundary. The token may carry a
`-<model>[-<effort>]` suffix — e.g. `ultra-goal-sonnet-xhigh`, `goal-opus` (model ∈
opus|sonnet|haiku|fable, default opus; effort ∈ low|medium|high|xhigh|max, default
xhigh) — resolved per the taskmaster `ultra-goal` skill
(`skills/ultra-goal/SKILL.md`), the canonical owner of this mode. Ultra-goal implies
the full ULTRA-TASK boost: when an `ultra-task` token is also present its tier wins;
ultra-goal's suffix applies only when no ultra-task token is present. On a match,
strip the token and run as `ULTRA-GOAL ACTIVE` per that skill — auto-take every
design decision (deriving one first when none is labeled Recommended) and
auto-select the "Continue" handoff into `/taskmaster:task`, which carries hands-off
downstream; branch-finish/merge/PR stay manual.

1. Dispatch context-scout on the idea first (reuse the stack-scan inventory
   when that plugin is installed) — bound the option space with codebase facts
   before asking anything.
2. Size the idea: if it spans multiple independent subsystems, decompose and
   agree an order; brainstorm only the first piece now.
3. Refine through one-question-at-a-time dialogue per the skill — multiple
   choice preferred, visual questions through the visual-decisions skill (it
   asks fidelity consent on first use).
4. Propose 2–3 approaches with tradeoffs, recommendation first. Present the
   chosen design in sections with per-section approval.
5. Write the design doc to `taskmaster-docs/specs/YYYY-MM-DD-<slug>-design.md`, run the
   self-review pass, then have the user review the written doc and iterate to
   approval.
6. Handoff: ask via AskUserQuestion whether to continue into the taskmaster
   pipeline now — "Continue (Recommended)" runs /taskmaster:task with the
   design doc as input (grill seeds its ledger from the doc); "Stop here"
   prints that command for later. Headless: stop after the doc and print the
   command.
