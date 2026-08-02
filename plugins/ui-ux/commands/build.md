---
description: Build or restyle a UI component/layout via ui-ux-engineer, using stack best-practice and token skills
argument-hint: [what-to-build]
---

Build the UI described in $ARGUMENTS (if empty, ask what to build and where). This is
the explicit entry point to the ui-ux-engineer worker — a build verb to complement
/ui-ux:review and /ui-ux:theme.

1. Detect the stack from the repo (shadcn, ReUI, Aceternity, Astryx, Tailwind, Bootstrap,
   plain CSS3, Grid/Flexbox, React/Vue) so the right best-practice skill and token
   conventions apply. A component registry already present in the tree is a detection
   signal, not a suggestion — build in the one the project has rather than beside it.

2. When the stack is ReUI or Aceternity and the registry-source plugin's MCP tools
   are available (`registry_search` / `registry_get` — load via ToolSearch), query
   them BEFORE proposing or writing any component: real current names, props, and
   install commands come from the registry, never from memory — reciting a
   remembered component API is the exact failure registry-source exists to stop.
   Unavailable → say so and verify against the live docs URL instead.

3. Dispatch the `ui-ux-engineer` worker with the request, instructing it to apply this
   plugin's relevant skills: the matching stack best-practice skill (shadcn/reui/
   aceternity/astryx/tailwind), `design-tokens` for
   spacing/type/radius/elevation/motion
   from the scale (no magic numbers), and `shadcn-theming` when colors are in play.
   When the request names a registry block to adapt, that registry's best-practice skill is
   the one that governs it, and the block is restyled to the project's own tokens rather
   than shipped in the registry's defaults.
   Naming those skills does not load them — the worker has no `Skill` tool. Resolve each
   one (and each token of its `bestpractices-skill:` frontmatter) to an installed
   `SKILL.md` and inject `Read <abs-path>` per hit, skipping misses
   (`orchestration:delegation-contracts` § Skill priming). Unprimed, it restyles from
   recalled convention rather than from the token scale it was told to obey.
   Layout, responsive breakpoints, spacing rhythm, and element hierarchy are its job.

4. Keep accessibility in view while building: semantic elements, labels, focus order —
   then recommend `/a11y:audit` on the result for a thorough pass (a11y remediation is
   the a11y plugin's, not this build step's).

5. Return the changed files with a one-line rationale each, and note any visual decision
   that was assumed rather than specified — surface it for confirmation rather than
   silently choosing.

6. When the build maps to real files, proceed via the ui-ux-engineer; if the request is
   still a visual decision between options (not yet decided), route to the staging path
   (`/shadcn-studio:stage` or `design-preview`) when either is installed, else fall back
   to taskmaster's `visual-decisions` mockup path when taskmaster is present, else decide
   via ASCII options inline — so the choice is made on concrete mockups without dead-ending
   on a missing command. Headless: build to the most conventional interpretation and note
   assumptions.
