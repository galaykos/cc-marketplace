---
description: Create a crafted web app (CRM, SaaS, landing page) end to end — orchestrates design-research, token + component build, motion-tier selection, and a craft audit by chaining the marketplace's existing UI/motion surfaces.
argument-hint: [product-idea]
---

# /craft-layer:craft

Turn a product idea into a distinctive, animated, informative web app. This command
**orchestrates** existing surfaces — it writes no framework build logic itself; each
step hands off to the command or skill that owns it. Run the steps in order, carrying
each step's output into the next.

`$ARGUMENTS` is the product idea (e.g. "a SaaS analytics dashboard for logistics
teams"). If empty, ask for a one-line product idea and the target stack
(React/Next/Vue/Nuxt/Laravel) before starting.

## Steps

1. **Research → briefs.** Run `/craft-layer:research $ARGUMENTS`. It applies the
   `design-research` skill to mine reference designs and interaction/layout **patterns**,
   and emits two briefs: a freeform theme brief and a component/layout build task. Detect
   the target stack here if not already known.

2. **Tokens.** Pass the theme brief to `/ui-ux:theme` to generate design tokens
   (light/dark) with a live colour preview. Do not hand-roll palettes — `/ui-ux:theme`
   owns generation.

3. **Build.** Pass the build task to `/ui-ux:build` to lay out components and screens,
   applying `design-tokens` and, for data-dense CRM/SaaS surfaces, the
   `information-design` skill (hierarchy, density, tables/dashboards, when-to-dataviz).

4. **Motion.** For each animated surface, select a tier via the `motion-tiers` skill's
   decision — Framer Motion, anime.js, Three.js/R3F, or sprites (the `sprite-motion`
   skill covers the last). Apply the tier's **perf budget**, its `prefers-reduced-motion`
   fallback, and its reduced-bundle fallback. Keep any 3D lazy-loaded with a static
   fallback per `motion-tiers/references/webgl-3d.md`.

5. **Audit.** Run `/craft-layer:audit` on the result to verify the craft gates
   (reduced-motion per tier, lazy + static-fallback 3D, per-tier budgets, sprite/asset
   budgets) and, via its delegation, accessibility and performance. Resolve any failed
   gate before declaring the surface done.

## Notes

- Reuse over rebuild: this command never re-teaches token, motion-library, or R3F
  detail — those live in `design-tokens`, `motion-best-practices`, and
  `threejs-best-practices`. It sequences them.
- Stop points are natural after step 2 (tokens approved) and step 3 (skeleton built);
  a user can run any step's command standalone.
