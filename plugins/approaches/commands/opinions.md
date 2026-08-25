---
description: Deliberate the change shape as a blind panel — four parallel opinion-lens personas, one pick + kill-trigger — before implementation.
---

Run the `approach-deliberation` skill on $ARGUMENTS in its BLIND PANEL mechanism
(that skill's `references/blind-panel.md`). If $ARGUMENTS is empty, ask for a
one-paragraph task description first. Do not write implementation code.

1. Explicit invocation BYPASSES the skill's size gate — the user asked, so run
   the round even for smaller or single-file tasks.
2. The double-run guard still applies: if a deliberation already ran for this
   task — the marker names it — say so and stop.
3. The taskmaster defer rule still applies: if a taskmaster pipeline
   (grill/brainstorm/cards) is active on the same task, step back and let it
   finish.
4. Run the panel exactly as `references/blind-panel.md` specifies — the persona
   roster, the blind-dispatch contract, the convergence table, the kill-trigger and
   the one-round cap are all owned there and already in context from the opening instruction above.
   Do not restate them here: the four persona names appear in several files, and a
   rename that misses one produces a panel with three personas and a typo.
5. Surface the pick — never self-approve it. Aligned or detail-divergent takes:
   one AskUserQuestion, "Proceed with <pick> (Recommended)" vs the strongest
   alternative. Structural split (takes disagree on the file-level shape):
   present the competing plans as the options instead. Proceed without asking
   only under CC_AUTOPROCEED=on or a hands-off goal run, recording the pick.
