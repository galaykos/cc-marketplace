---
description: Review UI code against the relevant stack's best-practice skill (shadcn, ReUI, Aceternity, Tailwind, CSS3, Bootstrap, Grid, Flexbox)
argument-hint: [files-or-diff]
---

Review the UI code in $ARGUMENTS (or the current diff if no argument) against the
ui-ux plugin skills. Steps:

1. Detect which stacks the code uses (shadcn/ui, ReUI, Aceternity UI, Tailwind, plain CSS3,
   Bootstrap, Grid, Flexbox). Registry-sourced components are detected by their files under
   `components/ui/*` and imports of `motion`/`framer-motion`, not by a package.json entry.
2. Invoke the matching *-best-practices skill(s) from this plugin.
3. Read package.json and its lockfile to pin framework/library versions; findings must
   respect the installed versions — nothing already solved, nothing above them.
4. When uncertain, verify against the official docs for the installed version instead
   of memory: MDN (https://developer.mozilla.org) for CSS3/Grid/Flexbox,
   https://tailwindcss.com/docs, https://ui.shadcn.com/docs, https://reui.io/docs,
   https://ui.aceternity.com/components, https://getbootstrap.com/docs. ReUI and Aceternity
   have no npm version to pin — their current docs page is the only source of truth.
5. Report findings as `path:line — problem — fix`, ordered by severity.
6. Do not report formatting nits unless they change rendering behavior.
