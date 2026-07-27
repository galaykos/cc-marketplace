---
description: Turn a product or reference into buildable design direction — mine patterns via design-research, then hand a theme brief to /ui-ux:theme and a build task to /ui-ux:build
argument-hint: [product-or-reference]
---

Invoke the `design-research` skill from this plugin and turn $ARGUMENTS (a product to
design, or a reference site/app to draw from) into buildable direction. If $ARGUMENTS is
empty, ask what product or reference to research before doing anything else.

**Carry the concept when one exists.** `/craft-layer:craft` runs this as its step 1 after
generating a concept, so before mining, read `craft/divergence-record.md` and
`craft/offer-contract.md` from the run's working area when they are present (the craft flow
persists them there). They are inputs to step 1 below: the concept's metaphor, voice, and
signature interaction bias what mining elaborates and which defaults it breaks, and the
contract's spine slots say which sections the build task owes. Absent — a standalone run with
no prior craft step — mine unbiased and say so. A concept that never reaches these briefs
evaporates, which is the failure the craft flow's step 0 exists to prevent.

1. **Mine patterns and token direction.** Apply the `design-research` skill to pull from
   its three source lanes — live products in the same category, pattern galleries, and
   the target's own brand assets — and record, per source, BOTH the interaction/layout
   PATTERNS and the token DIRECTION (colour, type, spacing, radius, motion) as adjectives
   and references, never hex or px.
2. **Emit the theme brief.** Write one freeform string blending brand colour, a vibe, and any
   reference the palette should echo — this is `/ui-ux:theme`'s `[brand-color-vibe-or-reference]`
   argument. Hand it intent, not values; `/ui-ux:theme` runs its own stack detection, palette
   generation, and live preview.
   Then apply the `ui-ux:theming-system` skill to DERIVE the token-system-direction block the brief
   carries alongside that string, in exactly the shape and line set
   `plugins/ui-ux/skills/theming-system/references/concept-to-tokens.md` defines (it owns the contents — do not
   work from a summary of them). Roles and direction only, never a value. Carry the
   palette-strategy mood phrase and avoid-hues note in the brief too. Without this the block
   the brief claims to carry does not exist and `/ui-ux:theme` receives a bare vibe string.
3. **Emit the build task for `/ui-ux:build`.** Write a component/layout task naming what
   to build, where, and which mined PATTERNS to apply (grid, card anatomy, density, motion
   energy) — this is the `[what-to-build]` argument. Keep it consistent with the theme
   brief: the vibe and the patterns must describe one product, not two.
4. **Optionally preview open forks via `/design-preview:preview`.** When a decision is
   still open — two layout directions, two motion energies — offer to stage it with
   `/design-preview:preview` (its `[decision-description]` argument) before committing.
   Decided direction goes straight to the briefs; only genuine forks preview.

When both briefs are ready:

- **Standalone invocation** — ask via AskUserQuestion: "Hand off to /ui-ux:theme and
  /ui-ux:build now (Recommended)" / "Report the briefs only".
- **Invoked as `/craft-layer:craft`'s step 1** — do NOT ask, and do NOT hand off. Report the
  two briefs and return; the craft chain runs `/ui-ux:theme` at its step 2 and `/ui-ux:build`
  at its step 6, with section decisions, the asset plan and the motion decisions in between.
  Building here would
  produce the page before the user has decided a single section.
- **Headless** — report the two briefs and the exact next commands, and take no action
  unprompted.
