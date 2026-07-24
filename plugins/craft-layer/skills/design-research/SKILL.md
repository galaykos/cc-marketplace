---
name: design-research
description: Use when starting or restyling a UI/app build and you need to turn reference designs into buildable direction — mine live sites, pattern galleries, and the target's brand assets for interaction/layout PATTERNS plus color/type/spacing/motion token direction, then emit a freeform theme brief for /ui-ux:theme and a component/layout task for /ui-ux:build. Does not generate palettes or token scales itself.
---

# Design research

Design research is the front-half of a craft build: it turns reference designs and
real product patterns into two briefs the existing build tools already consume — a
theme brief for `/ui-ux:theme` and a component/layout task for `/ui-ux:build`. It
invents no new file format; every artefact it emits is a plain string one of those
commands reads. Its output is DIRECTION, not tokens: it decides what to build and how
it should feel, then hands generation to the tools that own it.

## Mine before you brief

Never write a brief from a single screenshot or a colour alone. A brief carrying only a
hue produces a recoloured default; craft lives in the PATTERNS — how a hero stacks, how
a card reveals, how a table breathes. Collect the sources first, extract both patterns
and token direction, then write. The full method is in `references/mining-method.md`.

## Source checklist — where to look

Pull from three lanes, not one:

- **Live products in the same category** — the real thing users compare against
  (Linear, Stripe, Vercel for SaaS; the target's actual competitors). Walk flows and
  states, not just the landing hero.
- **Pattern galleries** — Mobbin, Godly, Land-book, Refactoring UI, Page Flows,
  UI Sources — for a spread of ONE pattern (pricing tables, empty states, onboarding),
  so you borrow a convention rather than copy a page.
- **The target's own brand assets** — existing marketing site, logo, brand guide,
  product screenshots, app-store listing. The brand already made colour and type
  decisions; honour them before inventing new ones.

Capture each source as a URL plus one line on WHY it earns a place — the specific
pattern or feel you are borrowing — so every brief line traces back to evidence.

## Extract PATTERNS and token direction

Every source yields two kinds of finding; capture BOTH or the brief is colour-only.

**Interaction & layout patterns** (the craft, carried into the build task):

- Layout skeleton — grid columns, hero composition, nav shape, content density.
- Component patterns — card anatomy, table/list density, form rhythm, empty states.
- Interaction — hover/focus affordances, disclosure, scroll behaviour, transitions.
- Motion — what animates, entrance vs micro-interaction, the overall energy.

**Token direction** (adjectives handed to generation, not values decided here):

- Colour — brand hue family, warmth, light/dark priority, surface chroma.
- Type — serif/sans/mono mix, display-vs-body contrast, weight range.
- Spacing & density — airy vs compact, the base rhythm.
- Radius & elevation — sharp vs soft, flat vs shadowed.

Record direction as adjectives and references, never as hex or px — `/ui-ux:theme` and
the token scales own the exact numbers. The extraction worksheet is in
`references/mining-method.md`.

## Emit two briefs

Fill the annotated templates in `references/brief-templates.md`; each names the command
that consumes it.

1. **Theme brief → `/ui-ux:theme`** — one freeform string blending brand colour, a vibe
   ("warm editorial", "high-contrast fintech"), and any reference site the palette
   should echo. This IS the `[brand-color-vibe-or-reference]` argument the command
   takes; it then runs its own stack detection, palette generation, and live preview.
   Hand it intent — never hex values or a token file.
2. **Build task → `/ui-ux:build`** — a component/layout task naming what to build,
   where, and which extracted PATTERNS to apply (grid, card anatomy, density, motion
   energy). This IS the `[what-to-build]` argument; the worker applies `design-tokens`
   and the stack best-practice skill. The theme brief carries colour; the build task
   carries structure and interaction.

Keep the two consistent: the vibe in the theme brief and the patterns in the build task
must describe one product, not two.

## When to preview

A brief encodes a decision. When the decision is still open — two layout directions, two
motion energies — stage it before committing. Route the undecided fork to
`/design-preview:preview` (its `[decision-description]` argument), which renders the
options with the project's own components. Decided direction goes straight to the briefs;
only genuinely open questions preview.

## Reuse map

This skill mines and briefs; it does NOT re-teach generation. Reference, never copy:

| Concern | Owned by |
| --- | --- |
| Token scales (spacing/type/radius/elevation/motion) | `plugins/ui-ux/skills/design-tokens/SKILL.md` |
| Palette / theme generation, contrast, dark mode | `plugins/ui-ux/skills/shadcn-theming/SKILL.md` |
| Palette + live preview from the theme brief | `/ui-ux:theme` |
| Component/layout build from the build task | `/ui-ux:build` |

Token DIRECTION belongs in the brief; token VALUES belong to those skills.

## References

- `references/mining-method.md` — the source checklist and extraction worksheet in full.
- `references/brief-templates.md` — fill-in templates for the theme brief and the build
  task, each annotated with its consuming command.

## Anti-patterns

- **Colour-only brief** — a hue with no patterns; yields a recoloured default, not craft.
  Capture layout and interaction or do not brief.
- **Inventing a format** — a JSON "token-intent" file nothing reads. The only outputs are
  the `/ui-ux:theme` string and the `/ui-ux:build` task.
- **Deciding token values** — hand-picking hex/px in the brief instead of direction; that
  is `design-tokens` and `shadcn-theming`'s job.
- **Single source** — one screenshot mined for everything; use three lanes or it is
  copying, not researching.
- **Re-teaching the reuse skills** — restating scales or palette rules here instead of
  linking their paths.
- **Previewing the decided** — staging a direction already chosen, or briefing one still
  open; preview only genuine forks.
