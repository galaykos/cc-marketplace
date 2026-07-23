---
description: Build or restyle a UI component/layout via ui-ux-engineer, using stack best-practice and token skills
argument-hint: [what-to-build]
---

Build the UI described in $ARGUMENTS (if empty, ask what to build and where). This is
the explicit entry point to the ui-ux-engineer worker — a build verb to complement
/ui-ux:review and /ui-ux:theme.

1. Detect the stack from the repo (shadcn/Tailwind, Bootstrap, plain CSS3, Grid/Flexbox,
   React/Vue) so the right best-practice skill and token conventions apply.

2. Dispatch the `ui-ux-engineer` worker with the request, instructing it to apply this
   plugin's relevant skills: the matching stack best-practice skill (shadcn/tailwind/
   bootstrap/css3/grid/flexbox), `design-tokens` for spacing/type/radius/elevation/motion
   from the scale (no magic numbers), and `shadcn-theming` when colors are in play.
   Layout, responsive breakpoints, spacing rhythm, and element hierarchy are its job.

3. Keep accessibility in view while building: semantic elements, labels, focus order —
   then recommend `/a11y:audit` on the result for a thorough pass (a11y remediation is
   the a11y plugin's, not this build step's).

4. Return the changed files with a one-line rationale each, and note any visual decision
   that was assumed rather than specified — surface it for confirmation rather than
   silently choosing.

5. When the build maps to real files, proceed via the ui-ux-engineer; if the request is
   still a visual decision between options (not yet decided), route to the staging path
   (`/shadcn-studio:stage` or `design-preview`) when either is installed, else fall back
   to taskmaster's `visual-decisions` mockup path when taskmaster is present, else decide
   via ASCII options inline — so the choice is made on concrete mockups without dead-ending
   on a missing command. Headless: build to the most conventional interpretation and note
   assumptions.
