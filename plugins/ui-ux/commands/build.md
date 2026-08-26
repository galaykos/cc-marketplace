---
description: Build or restyle a UI component/layout via ui-ux-engineer, using stack best-practice and token skills
argument-hint: [what-to-build]
---

Build the UI described in $ARGUMENTS (if empty, ask what to build and where). This is
the explicit entry point to the ui-ux-engineer worker — a build verb to complement
/ui-ux:review and /ui-ux:theme.

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
   Layout, responsive breakpoints, spacing rhythm, and element hierarchy are its job.

   Two conditional injections ride the same dispatch — the worker has no Skill tool, so
   a skill not injected here never reaches it:
   - **Motion.** When the request or target files carry animation signals — the same list
     /ui-ux:review step 2 detects (`framer-motion`/`motion`/`gsap`/`animejs` imports,
     `@keyframes`, `transition-*`/`animate-*` utilities, `animation-timeline`,
     `@starting-style`, `document.startViewTransition`) — inject the Read path to
     `skills/motion-best-practices/SKILL.md` plus the matching library digest
     (`references/motion.md` | `gsap.md` | `animejs.md`).
   - **Data-dense surfaces.** When the target is a dashboard, data table, admin/CRM
     screen, or settings surface and the craft-layer plugin is installed, inject the
     Read path to its `information-design` skill (SKILL.md +
     `references/dense-ui-patterns.md`); when craft-layer is absent, say so in the
     result rather than silently building without the dense-UI floor.

4. Keep accessibility in view while building: semantic elements, labels, focus order —
   then recommend `/a11y:audit` on the result for a thorough pass (a11y remediation is
   the a11y plugin's, not this build step's).

5. Return the changed files with a one-line rationale each, and note any visual decision
   that was assumed rather than specified — surface it for confirmation rather than
   silently choosing. Then offer the reviewer twin as a selectable choice
   (AskUserQuestion): "Run /ui-ux:review on the result now (Recommended)" / "Skip" —
   a standalone build otherwise ships self-graded, and the reviewer's adversarial
   pass plus Checked/Not-checked inventory is a check the builder never runs on
   itself. Headless: skip the question and name the review as not run.

6. When the build maps to real files, proceed via the ui-ux-engineer; if the request is
   still a visual decision between options (not yet decided), route to the staging path
   (`/shadcn-studio:stage` or `design-preview`) when either is installed, else fall back
   to taskmaster's `visual-decisions` mockup path when taskmaster is present, else decide
   via ASCII options inline — so the choice is made on concrete mockups without dead-ending
   on a missing command. Headless: take the decided lines above as binding, resolve what
   they leave open to the most COMMITTED reading consistent with them, and note every
   assumption. "Build to the most conventional interpretation" was the instruction here
   until it was read against its own output: it names the failure mode as the procedure,
   on the most reachable UI entry point in this marketplace, and it orders exactly the
   stacked centred document `craft-layer`'s composition gate exists to fail.
