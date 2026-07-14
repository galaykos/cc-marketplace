---
description: Review UI code against the relevant stack's best-practice skill (shadcn, ReUI, Aceternity, Tailwind, CSS3, Bootstrap, Grid, Flexbox)
argument-hint: [files-or-diff]
---

Review the UI code in $ARGUMENTS (or the current diff if no argument) against the
ui-ux plugin skills. Steps:

1. Triage first: a trivial, single-file, or purely cosmetic change (a copy tweak, a
   single token) earns a one-line verdict — state it and stop. Take the full review
   below when the change touches layout, component structure, state, or accessibility,
   OR spans more than 5 files, OR exceeds 300 changed lines (a NEW file counts its full
   length as changed).
2. Detect which stacks the code uses (shadcn/ui, ReUI, Aceternity UI, Tailwind, plain CSS3,
   Bootstrap, Grid, Flexbox). Registry-sourced components are detected by their files under
   `components/ui/*` and imports of `motion`/`framer-motion`, not by a package.json entry.
3. Invoke the matching *-best-practices skill(s) from this plugin.
4. Read package.json and its lockfile to pin framework/library versions; findings must
   respect the installed versions — nothing already solved, nothing above them.
5. When uncertain, verify against the official docs for the installed version instead
   of memory: MDN (https://developer.mozilla.org) for CSS3/Grid/Flexbox,
   https://tailwindcss.com/docs, https://ui.shadcn.com/docs, https://reui.io/docs,
   https://ui.aceternity.com/components, https://getbootstrap.com/docs. ReUI and Aceternity
   have no npm version to pin — their current docs page is the only source of truth.
6. Report findings as `path:line — problem — fix`, ordered by severity.
7. Do not report formatting nits unless they change rendering behavior.
8. Close with a coverage inventory and a self-refute pass: state `Checked: …` and
   `Not checked: … (why)` so it is explicit which stacks and surfaces were covered, what
   was clean, and what was skipped — not only what broke. Then run one adversarial
   self-refute pass over your highest-severity findings; if a finding does not survive
   it, drop or downgrade it with a note.
9. When findings exist, offer the fix as a selectable choice (AskUserQuestion):
   "Apply now" / "Report only". On an apply pick, dispatch the finding list down the
   static chain `ui-ux:ui-ux-engineer → task-runner:task-executor if installed → inline`
   — never leave the user to retype findings. Bare instructions only when headless.
