---
description: Run an opinion-round — four parallel blind opinion-lens personas argue the approach, synthesized to one pick + kill-trigger — before implementation.
---

Run the opinion-round skill on $ARGUMENTS (if empty, ask for a one-paragraph
task description first). Do not write implementation code.

1. Explicit invocation BYPASSES the skill's size gate — the user asked, so run
   the round even for smaller or single-file tasks.
2. The double-run guard still applies: if approach-deliberation or a prior
   opinion round already ran for this task, say so and stop.
3. The taskmaster defer rule still applies: if a taskmaster pipeline
   (grill/brainstorm/cards) is active on the same task, step back and let it
   finish.
4. Dispatch four parallel BLIND `opinion-lens` subagents, one fixed persona
   each (Standards Purist, Quality-over-Speed, Pragmatist-Minimalist,
   Skeptic-Investigator). Each dispatch carries the task description, the repo
   path, and its own persona brief ONLY — never sibling takes, never a
   main-thread draft plan. If subagents are unavailable, skip the round entirely — no
   inline role-play.
5. Synthesize inline: build the convergence table from the four takes, then
   ONE pick with its kill-trigger — the concrete discovery mid-implementation
   that would flip the choice. One round hard cap, no re-dispatch.
6. On a structural split (takes disagree on the file-level shape of the plan),
   do not pick silently — present the competing plans via AskUserQuestion and
   let the user choose.
