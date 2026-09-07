---
name: command-coverage
description: "Verify a task-card set covers its spec's success criteria — flag gaps, orphans, and drift, and resolve each before execution"
---

Read [the Codex execution contract](../../references/codex.md) before using helpers or delegating.

Run the coverage-check skill from this plugin on the user-supplied arguments (a
`taskmaster-docs/tasks/<slug>/` directory or a slug; if empty, use the most
recent `taskmaster-docs/tasks/*/00-INDEX.md`).

For an explicit ultra-task or ultra-goal request, load the native ultra skill. Keep session model settings; goal mode continues only already-authorized work.

**Goal in this command:** standalone under goal, auto-resolve every
GAP/ORPHAN/DRIFT WITHIN this command (derive-then-take), writing no execution
marker; only task-cards stamps the `Goal: true` marker.

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
