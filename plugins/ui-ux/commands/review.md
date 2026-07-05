---
description: Review UI code against the relevant stack's best-practice skill (shadcn, Tailwind, CSS3, Bootstrap, Grid, Flexbox)
---

Review the UI code in $ARGUMENTS (or the current diff if no argument) against the
ui-ux plugin skills. Steps:

1. Detect which stacks the code uses (shadcn/ui, Tailwind, plain CSS3, Bootstrap, Grid, Flexbox).
2. Invoke the matching *-best-practices skill(s) from this plugin.
3. Report findings as `path:line — problem — fix`, ordered by severity.
4. Do not report formatting nits unless they change rendering behavior.
