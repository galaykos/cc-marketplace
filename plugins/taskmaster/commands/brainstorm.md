---
description: Shape a fuzzy idea into an approved design doc, then hand off to the taskmaster pipeline
argument-hint: [idea]
---

Run the brainstorm skill from this plugin on $ARGUMENTS (if empty, ask what
idea the user wants to explore). No implementation code, scaffolding, or file
creation beyond the design doc at any point.

<!-- boost-preamble:start — byte-identical across the 5 taskmaster commands; scripts/validate.sh enforces parity and hook-token agreement -->
**Run-status line (always):** print ONE status line as the first visible output of
every run — a boosted run prints the ⚡ banner (owned by the taskmaster `ultra`
skill; the banner IS its status line); a standard run prints
`▷ taskmaster standard run — session <model> · subagents inherit it unless their agent pins a tier · effort: <effort> · boost: off` — substitute `<model>` with the session model and `<effort>` with `$CLAUDE_EFFORT` (resolve via `echo ${CLAUDE_EFFORT:-inherit}`); when the harness does not expose it, that prints the literal `inherit`.

**Boost flags:** Extreme Boost fires ONLY when $ARGUMENTS *begins* with a bare
`ultra` (boost) or `goal` (hands-off) token, or contains the explicit
`ultra-task`/`ultratask` or `ultra-goal`/`ultragoal` token. Only the explicit
tokens cross a command boundary — a bare token owned by an earlier chained
command (e.g. `caveman ultra` preceding this command) NEVER triggers this run.
No tier suffixes: the tier is fixed at model=auto, effort=xhigh (`auto` =
session model or opus, whichever is higher — escalate, never downgrade). On a
match, strip the matched token and apply the taskmaster `ultra` skill
(`skills/ultra/SKILL.md`) — `ULTRA-TASK ACTIVE`, or `ULTRA-GOAL ACTIVE` in Goal
mode for `goal`/`ultra-goal` — ⚡ banner first, `Ultra:`/`Goal:` markers per
that skill.
<!-- boost-preamble:end -->

**Goal in this command:** auto-take every design decision (derive-then-take) and
auto-select the "Continue" handoff into `/taskmaster:task`, which carries
hands-off downstream; branch-finish/merge/PR stay manual.

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
