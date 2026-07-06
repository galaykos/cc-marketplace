---
description: Run a second-opinions round on a task — three fixed personas argue the approach, converge to one pick + kill-trigger — before any implementation.
---

Run the second-opinions skill on $ARGUMENTS (if empty, ask for a one-paragraph
task description first). Do not write implementation code.

1. Explicit invocation BYPASSES the skill's size gate — the user asked, so run
   the round even for smaller or single-file tasks.
2. The double-run guard still applies: if approach-deliberation or a prior
   opinion round already ran for this task, say so and stop.
3. Run the persona round as the skill defines it: each fixed persona
   (Standards Purist, Quality-over-Speed, Skeptic-Investigator) gives its take
   (at most 5 lines: approach, top risk, dissent) — three takes, no more.
4. Converge: trade-off/convergence table, then ONE pick with its
   kill-trigger — the concrete discovery mid-implementation that would flip
   the choice. One round hard cap, no extensions.
5. On a structural split (personas disagree on the file-level shape of the
   plan), do not pick silently — present the competing plans via
   AskUserQuestion and let the user choose.
6. If the decision-records plugin is installed, offer capturing the pick as an
   ADR via /decision-records:new; when it is not installed, skip silently.
