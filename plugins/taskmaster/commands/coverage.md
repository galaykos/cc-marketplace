---
description: Verify a task-card set covers its spec's success criteria — flag gaps, orphans, and drift, and resolve each before execution
argument-hint: [tasks-dir-or-slug]
---

Run the coverage-check skill from this plugin on $ARGUMENTS (a
`taskmaster-docs/tasks/<slug>/` directory or a slug; if empty, use the most
recent `taskmaster-docs/tasks/*/00-INDEX.md`).

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
