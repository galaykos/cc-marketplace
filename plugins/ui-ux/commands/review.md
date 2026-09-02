---
description: Review UI code against the matching stack's best-practice skill
argument-hint: [files-or-diff]
---

Review the UI code in $ARGUMENTS (or the current diff if no argument) against the
ui-ux plugin skills. Steps:

1. Triage first: a trivial, single-file, or purely cosmetic change (a copy tweak, a
   single token) earns a one-line verdict — state it and stop. Take the full review
   below when the change touches layout, component structure, state, or accessibility,
   OR spans more than 5 files, OR exceeds 300 changed lines (a NEW file counts its full
   length as changed).
2. Detect which stacks the code uses (shadcn/ui, ReUI, Aceternity UI, Astryx, Material UI,
   Tailwind). Any other React component library — headless (Base UI, Radix, React Aria,
   Ark, Headless UI, Ariakit) or styled (Mantine, Chakra, Ant Design, HeroUI, …) — selects
   `component-libraries`, whose `references/library-map.md` names the signal and docs URL.
   Plain CSS/Grid/Flexbox/Bootstrap code gets the model's own review — no skill to load.
   Registry-sourced components are detected by their files under
   `components/ui/*` and imports of `motion`/`framer-motion`, not by a package.json entry.
   Animation/motion work is detected by any of: `framer-motion`/`motion`/`gsap`/`animejs` imports,
   `@keyframes` blocks, `transition-*`/`animate-*` utility classes or `transition:`/
   `animation:` CSS declarations, `animation-timeline`, `@starting-style`, or
   `document.startViewTransition` — any hit selects the motion-best-practices skill in
   addition to the stack skill(s).
   A data-dense app surface (dashboard, data table, admin/CRM screen, settings) with the
   craft-layer plugin installed additionally selects its `information-design` skill —
   the review then grades signal hierarchy, the four table states, density, and
   bulk-action affordances, not just stack idioms. craft-layer absent → record
   `information-design (craft-layer not installed)` under `Not checked:` in step 8.
3. Invoke the matching *-best-practices skill(s) from this plugin.
4. Read package.json and its lockfile to pin framework/library versions; findings must
   respect the installed versions — nothing already solved, nothing above them.
5. When uncertain, read the local digests first — `skills/motion-best-practices/references/motion.md`
   (plus sibling `animejs.md` and `gsap.md`), `skills/reui-best-practices/references/reui.md`,
   `skills/aceternity-best-practices/references/aceternity.md`, and
   `skills/astryx-best-practices/references/astryx.md`, `skills/mui-best-practices/references/mui.md`
   and `skills/component-libraries/references/library-map.md` — then verify version-sensitive
   literals (component/method names, props, options, versions) against the official docs
   for the installed version: MDN (https://developer.mozilla.org) for plain CSS,
   https://tailwindcss.com/docs, https://ui.shadcn.com/docs, https://reui.io/docs,
   https://ui.aceternity.com/components,
   https://motion.dev/docs, https://gsap.com/docs, and https://animejs.com/documentation/
   for animation libraries, https://astryx.atmeta.com/components for Astryx,
   https://mui.com/material-ui/ for Material UI (pin `@mui/x-*` separately — it has its
   own major), and the per-library URL in `library-map.md` for anything else. ReUI and
   Aceternity have no npm version to pin — their current docs page is the only source of truth.
6. Report findings as `path:line — severity — problem — fix`, sorted by
   severity (critical, high, medium, low).
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
