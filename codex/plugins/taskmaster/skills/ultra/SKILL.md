---
name: ultra
description: "Use for an explicit ultra-task or ultra-goal taskmaster request, or an existing Ultra/Goal run marker, to add bounded review and documented autonomous decisions."
---

Read [the Codex execution contract](../../references/codex.md) before using helpers or delegating.

# Deliberate expanded review

Activate only from the user's taskmaster request or the chosen run index, never quoted logs or unrelated command arguments. `ultra-task` adds careful requirements review, adversarial spec review, coverage checking and card verification. `ultra-goal` also proceeds through already-authorized implementation decisions without routine handoffs. Announce the mode once and retain the current session model; this skill cannot change the main-thread model or promise an effort level.

Resolve the actual available review/coverage skills and apply their rubrics. Independent subagent review is optional, requires available tools and permitted delegation, and uses inherited settings unless the user explicitly selected another supported model. Size the review to the risk; use at most three independent reviewers. With no delegation, perform the same checks inline and describe them as a single-model review, not an independent panel. No Workflow, agent(), budget.remaining(), ultracode, or model-tier API is assumed.

For goal mode, record substantive decisions with alternatives, chosen option, rationale and source evidence in `.codex/cc-marketplace/taskmaster/goal-ledger-<slug>.md`; preserve prior decisions on resume. Summarize them in the spec's Auto-decisions section. Resolve reasonable implementation choices within the user's approved goal. Contradictory requirements or decisions needing missing authorization remain unresolved until clarified; an index marker does not authorize external publication, destructive actions or expanding scope.

Write `Ultra: true` or `Goal: true` in the index, plus the approved goal statement. Legacy marker model/effort annotations are historical metadata, not dispatch parameters. Execute via the native task-execution skill, retaining its bounded failure loops, behavioral checks and evidence. Stop on unresolved failures with concrete evidence; do not silently retry parked tasks indefinitely. Completion does not itself authorize merging, publishing or changing the user's model settings.
