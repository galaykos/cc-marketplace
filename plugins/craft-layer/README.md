# craft-layer

Create unique, high-craft, animated, **informative** web apps — CRMs, SaaS dashboards,
landing pages — on real projects across **React, Tailwind, Vite, Vue, Next, Nuxt, and
Laravel** (Inertia / Livewire). `craft-layer` is the orchestration layer that turns an
idea into a crafted app by composing the marketplace's existing UI/motion skills, adding
only what they lack: a research→brief playbook, a tiered motion **decision** system,
sprite guidance, information design, and a craft **audit**.

## The craft flow

`/craft-layer:craft <idea>` chains the whole path — it writes no framework code itself,
it orchestrates existing surfaces:

1. **`/craft-layer:research`** — mine reference designs + interaction/layout patterns,
   emit a theme brief and a build task.
2. **`/ui-ux:theme`** — generate design tokens (light/dark) + live preview from the brief.
3. **`/ui-ux:build`** — build components/layout, applying `design-tokens` and
   `information-design`.
4. **motion-tier selection** — pick a tier per surface via `motion-tiers`, each with its
   perf budget + `prefers-reduced-motion` + reduced-bundle fallback.
5. **`/craft-layer:audit`** — verify the craft gates (delegating a11y + performance).

## Skills

- **design-research** — a repeatable method to mine reference designs and patterns and
  emit briefs in the exact form `/ui-ux:theme` and `/ui-ux:build` consume.
- **motion-tiers** — the tier decision system: Framer Motion, anime.js, Three.js/R3F,
  and sprites — each with when-to-use, a perf budget, a `prefers-reduced-motion`
  fallback, a reduced-bundle fallback, and a per-framework tool binding — including
  **Tier 5 — Vector (Lottie / Rive)** for designer-authored vector motion.
- **sprite-motion** — sprite / sprite-sheet authoring: sheet formats, CSS `steps()` and
  `requestAnimationFrame` loops, reduced-motion poster frames, size budgets.
- **information-design** — hierarchy, data density, tables/dashboards, and when to reach
  for data-viz — for the data-dense CRM/SaaS targets.
- **scroll-orchestration** — the smooth-scroll substrate (Lenis) + scroll-driven
  animation contract; references `gsap.md` for ScrollTrigger and CSS scroll-driven as
  the reduced-bundle path.
- **kinetic-typography** — animated + variable-font type: split-text reveals,
  variable-font axes on scroll/hover, phrase cross-fades (references the split-text and
  gradient-clip/aria gotchas rather than re-teaching them).
- **page-transitions** — route/page view-transitions: the decision, shared-element
  choreography across React/Next/Nuxt/Astro, reduced-motion + unsupported-browser
  fallback (references the View Transitions API rather than re-teaching it).
- **webgl-effects** — postprocessing + custom shaders as an effect layer on Tier 3: the
  GPU-cost decision, scroll/pointer shader uniforms, a pass budget, and a
  static/reduced-motion fallback (references `threejs-best-practices` + `webgl-3d.md`).
- **interaction-fx** — pointer micro-interactions (custom cursor, magnetic, tilt, drag):
  the affordance-vs-decoration decision, the a11y rules, one rAF pointer loop, and
  reduced-motion (references Framer + the one-writer gotcha).

## Commands

- **`/craft-layer:craft`** — the idea→app orchestrator (chain above).
- **`/craft-layer:research`** — run the design-research playbook standalone.
- **`/craft-layer:audit`** — audit a project against the craft gates.

## Agent

- **craft-reviewer** — read-only reviewer for the craft gates (reduced-motion per tier,
  lazy + static-fallback 3D, per-tier budgets, sprite/asset budgets). Delegates a11y →
  `/a11y:audit` and performance → `/performance:review`.

## Reuse map

craft-layer **references, never re-teaches**, these existing skills:

| Concern | Owned by |
| --- | --- |
| Design-token scales | `plugins/ui-ux/skills/design-tokens` |
| Palette / theme generation | `plugins/ui-ux/skills/shadcn-theming` + `/ui-ux:theme` |
| Motion library idioms (Framer, GSAP, anime.js) | `plugins/ui-ux/skills/motion-best-practices` (+ `references/animejs.md`) |
| View Transitions API (page-transitions references it) | `plugins/ui-ux/skills/motion-best-practices` |
| Three.js / R3F correctness (webgl-effects references it) | `plugins/threejs/skills/threejs-best-practices` |
| Accessibility enforcement | `/a11y:audit` |
| Performance / Lighthouse | `/performance:review` |
| Chart form / color | the `dataviz` skill |

## Install

Ships in the **frontend-suite** bundle alongside `ui-ux`, `threejs`, `design-preview`,
and `a11y` — installing the suite gives craft-layer every surface it composes.
