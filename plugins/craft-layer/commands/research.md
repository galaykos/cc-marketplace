---
description: Turn a product or reference into buildable design direction — mine patterns via design-research, then hand a theme brief to /ui-ux:theme and a build task to /ui-ux:build
argument-hint: [product-or-reference]
---

Invoke the `design-research` skill from this plugin and turn $ARGUMENTS (a product to
design, or a reference site/app to draw from) into buildable direction. If $ARGUMENTS is
empty, ask what product or reference to research before doing anything else.

1. **Mine patterns and token direction.** Apply the `design-research` skill to pull from
   its three source lanes — live products in the same category, pattern galleries, and
   the target's own brand assets — and record, per source, BOTH the interaction/layout
   PATTERNS and the token DIRECTION (colour, type, spacing, radius, motion) as adjectives
   and references, never hex or px.
2. **Emit the theme brief and hand to `/ui-ux:theme`.** Write one freeform string
   blending brand colour, a vibe, and any reference the palette should echo — this is the
   `[brand-color-vibe-or-reference]` argument. Hand it intent, not values; `/ui-ux:theme`
   runs its own stack detection, palette generation, and live preview.
3. **Emit the build task for `/ui-ux:build`.** Write a component/layout task naming what
   to build, where, and which mined PATTERNS to apply (grid, card anatomy, density, motion
   energy) — this is the `[what-to-build]` argument. Keep it consistent with the theme
   brief: the vibe and the patterns must describe one product, not two.
4. **Optionally preview open forks via `/design-preview:preview`.** When a decision is
   still open — two layout directions, two motion energies — offer to stage it with
   `/design-preview:preview` (its `[decision-description]` argument) before committing.
   Decided direction goes straight to the briefs; only genuine forks preview.

When both briefs are ready, ask via AskUserQuestion: "Hand off to /ui-ux:theme and
/ui-ux:build now (Recommended)" / "Report the briefs only". Headless: report the two
briefs and the exact next commands, and take no action unprompted.
