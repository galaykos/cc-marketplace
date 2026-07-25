# Palette strategy — direction, not colour

This layer contributes exactly two things to the theme brief, and nothing else: an
archetype→mood MAPPING and a don't-repeat-recent-hues NUDGE. It emits DIRECTION
(adjectives, a mood, a "not this hue family"), never hex, never a token scale.

**Ownership boundary (binding).** Colour and accent DIRECTION — the brand hue family,
warmth, light/dark priority, surface chroma — live in `design-research` (its token-direction
extraction; the briefer). The accent-contrast DERIVATION is owned by `theming-system`
(`skills/theming-system/references/accent-system.md`), not design-research and not this
layer. This layer does NOT restate or duplicate any of them. Generation of actual palette
values stays `/ui-ux:theme` / `shadcn-theming`.

## Archetype → mood mapping

A starting mood per archetype the concept can push against (directional, not prescriptive):

| Archetype | Palette mood (direction) |
| --- | --- |
| creative/portfolio | high-contrast or unexpected; colour as signature |
| marketing/campaign | energetic, one saturated hero accent |
| product/SaaS | confident, restrained, trust-forward |
| editorial/content | calm, reading-safe, low-chroma surfaces |
| app/CRM | neutral, legible, data-safe accents |
| general (fallback) | balanced, mid-chroma |

The mood is one adjective phrase handed to the theme brief; the concept's metaphor may
override it (a "midnight observatory" SaaS concept can pull product/SaaS toward deep-dark).

## Don't-repeat-recent nudge

Read the recent-hue list in `sameness-fingerprint.md` (last 5 palettes). The brief should
avoid landing in the SAME hue family as a recent build unless the brief specifically
demands it. This needs no separate state — the fingerprint IS the memory. State the
avoided families in the brief ("not lime-editorial, not navy/gold") so `/ui-ux:theme`
generates away from them.

One entry on that list is not self-repetition and does not age out with the window: the
purple/violet gradient is the CATEGORY default that generated pages converged on, and readers
identify it as machine-made about as fast as they see it. Treat it as a tell, not as a
neutral hue choice — a palette landing there costs the build its authored feel before a word
is read. Carry it into the brief explicitly ("not the violet-gradient default") rather than
hoping generation wanders elsewhere, since it is exactly where generation goes by default.

## What reaches the theme brief

Only: the mood phrase + the avoid-these-hues note. Everything else about colour (hue
family, contrast, dark/light) comes from `design-research`. Two surfaces must not both
emit the full colour direction — this one is the mood + anti-repeat layer on top.

## Anti-patterns

- **Duplicating the accent owners** — restating hue family / warmth (design-research's
  direction) or the accent-contrast DERIVATION (`theming-system`'s) here; this layer only
  adds mood + anti-repeat.
- **Deciding values** — putting hex or a token scale in the brief; ship direction, let
  `/ui-ux:theme` generate.
- **Ignoring the recent-hue list** — shipping the same palette family as the last build
  because nothing nudged away from it.
