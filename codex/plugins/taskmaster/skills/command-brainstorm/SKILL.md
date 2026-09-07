---
name: command-brainstorm
description: "Shape a fuzzy idea into an approved design doc, then hand off to the taskmaster pipeline"
---

Read [the Codex execution contract](../../references/codex.md) before using helpers or delegating.

Run the brainstorm skill from this plugin on the user-supplied arguments (if empty, ask what
idea the user wants to explore). No implementation code, scaffolding, or file
creation beyond the design doc at any point.

For an explicit ultra-task or ultra-goal request, load the native ultra skill. Keep session model settings; goal mode continues only already-authorized work.

**Goal in this command:** auto-take every design decision (derive-then-take) and
auto-select the "Continue" handoff into `taskmaster:command-task`, which carries
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
6. Handoff: ask via a user question using the available interaction tool whether to continue into the taskmaster
   pipeline now — "Continue (Recommended)" runs taskmaster:command-task with the
   design doc as input (grill seeds its ledger from the doc); "Stop here"
   prints that command for later. Headless: stop after the doc and print the
   command.
