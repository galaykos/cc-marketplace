---
description: Build or restyle a UI component/layout via ui-ux-engineer, using stack best-practice and token skills
argument-hint: [what-to-build]
---

Build the UI described in $ARGUMENTS (if empty, ask what to build and where). This is
the explicit entry point to the ui-ux-engineer worker — a build verb to complement
/ui-ux:theme; review runs through the /code-review:review fan-in.

**A decided spec in $ARGUMENTS BINDS.** When the request carries decided lines —
`Composition:`, `Graphic system:`, `Signature:`, `Copy voice:`, `Banned vocabulary:`,
`Spine regions:`, `Decided:`, `Locks:`, `Motion:`, `Ambition:` — they OUTRANK every
default in the skills below, and they are carried into the worker dispatch verbatim
rather than summarised. Those lines are the only channel by which a decided art
direction reaches this command; a build that silently resolves them back to the stack
default has discarded the decision and produced the generic result the caller ran a
concept stage to avoid. When a decided line and a best-practice default conflict, the
decided line wins and the conflict is reported — not quietly resolved toward the
convention.

1. Detect the stack from the repo (shadcn, ReUI, Aceternity, Astryx, Material UI, Tailwind,
   Bootstrap, plain CSS3, Grid/Flexbox, React/Vue) so the right best-practice skill and
   token conventions apply. Any other component library — headless or styled — is governed
   by `ui-libraries:component-libraries` and its `references/library-map.md` (the `ui-libraries`
   plugin; not installed → say so and work from the library's docs URL). A component library or
   registry already present in the tree is a detection signal, not a suggestion — build in
   the one the project has rather than beside it; the UI layer is library-agnostic and no
   skill here gets to pick a second one.

2. When the stack is shadcn, ReUI or Aceternity and a registry MCP is connected
   (shadcn's own server, or ReUI's hosted `mcp.reui.io` — load its tools via
   ToolSearch), query it BEFORE proposing or writing any component: real current
   names, props, and install commands come from the registry, never from memory —
   reciting a remembered component API is the exact failure a registry MCP exists to
   stop. No server connected: the fallback is the library's own docs URL in
   `ui-libraries:component-libraries` (`references/library-map.md`), never recall.
   Unavailable → say so and verify against the live docs URL instead.
   **Any** registry block follows `skills/shadcn-best-practices/references/registries.md`,
   not only a ReUI or Aceternity one. That covers an `@namespace/item` from the CLI's
   directory, a `components.json` `registries` entry, or a registry URL. The reference
   supplies `view`/`--dry-run` before `add`, `{style}` matched to the base, keys through env
   headers, and the duplicate-package check. Inject its Read path into the step 3 dispatch.
   Standing: recorded. No gate checks that the dispatch carries it.

3. Dispatch the `ui-ux-engineer` worker with the request, instructing it to apply this
   plugin's relevant skills: the matching stack best-practice skill (shadcn/tailwind here;
   reui/aceternity/astryx/mui, or `component-libraries` for any other, from the `ui-libraries`
   plugin as `ui-libraries:<skill>`), `design-tokens` for
   spacing/type/radius/elevation/motion
   from the scale (no magic numbers), and `shadcn-theming` when colors are in play.
   When the request names a registry block to adapt, `references/registries.md` (step 2)
   governs the install. That registry's best-practice skill governs the block too when one
   exists (ReUI, Aceternity). Either way the block is restyled to the project's own tokens
   rather than shipped in the registry's defaults.
   Layout, responsive breakpoints, spacing rhythm, and element hierarchy are its job.

   **No decided lines → name the defaults to leave out.** With no art direction the
   model falls back on a few house styles, and "avoid a generic look" only swaps one
   default for another; a list of named patterns works. When $ARGUMENTS carries no
   `Banned vocabulary:` or `Signature:` line, the dispatch names these five as left out
   unless the request asks for one OR the project's existing tokens or components already
   use it (a `rounded-full` button variant, a warm surface token — step 1's build-in-what-
   the-project-has rule outranks this list): a cream or off-white page background, an
   italic accent word in headings, numbered `01 / 02 / 03` section labels, monospace
   labels with no data argument, pill-shaped buttons as the one silhouette. These are the
   MODEL's fallbacks, not a framework's — stock Bootstrap or untouched shadcn is a
   different generic, and step 1 already owns it. When craft-layer is
   installed, hand the worker the Read path to its
   `skills/creative-direction/references/sameness-fingerprint.md` instead — the fuller
   registry the five belong to. Standing: recorded — the worker may still pick them.

   Two conditional injections ride the same dispatch — the worker has no Skill tool, so
   a skill not injected here never reaches it:
   - **Motion.** When the request or target files carry animation signals — the same list
     the review fan-in detects (`framer-motion`/`motion`/`gsap`/`animejs` imports,
     `@keyframes`, `transition-*`/`animate-*` utilities, `animation-timeline`,
     `@starting-style`, `document.startViewTransition`) — inject the Read path to
     `skills/motion-best-practices/SKILL.md` plus the matching library digest
     (`references/motion.md` | `gsap.md` | `animejs.md`).
   - **Data-dense surfaces.** When the target is a dashboard, data table, admin/CRM
     screen, or settings surface and the craft-layer plugin is installed, inject the
     Read path to its `information-design` skill (SKILL.md +
     `references/dense-ui-patterns.md` + `references/product-packages.md`, the package
     selector for grids, charts and the other product-layer libraries); when craft-layer is
     absent, say so in the result rather than silently building without the dense-UI floor.

4. Keep accessibility in view while building: semantic elements, labels, focus order —
   then recommend `/ui-ux:audit` on the result for a thorough pass (a11y remediation is
   the audit command's and `a11y-engineer`'s, not this build step's).

5. Return the changed files with a one-line rationale each, and note any visual decision
   that was assumed rather than specified — surface it for confirmation rather than
   silently choosing. Then offer the reviewer twin as a selectable choice
   (AskUserQuestion): "Run /code-review:review on the result now (Recommended)" / "Skip" —
   a standalone build otherwise ships self-graded, and the reviewer's adversarial
   pass plus Checked/Not-checked inventory is a check the builder never runs on
   itself. Headless: skip the question and name the review as not run.

6. When the build maps to real files, proceed via the ui-ux-engineer; if the request is
   still a visual decision between options (not yet decided), route to
   the real-component rung of `taskmaster:visual-decisions` when installed, else fall back
   to taskmaster's `visual-decisions` mockup path when taskmaster is present, else decide
   via ASCII options inline — so the choice is made on concrete mockups without dead-ending
   on a missing command. Headless: take the decided lines above as binding, resolve what
   they leave open to the most COMMITTED reading consistent with them, and note every
   assumption. The most conventional reading is the wrong default here: it produces the
   stacked, centred document `craft-layer`'s composition gate exists to fail.
