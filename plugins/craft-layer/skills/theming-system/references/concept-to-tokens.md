# Concept → tokens — the theme-brief handoff contract

This reference owns ONE thing: the SHAPE of the token-system-direction payload the theme
brief carries into `/ui-ux:theme`, so the generated system EXPRESSES the concept instead
of recolouring a default. It is a CONTRACT, not a generator: every entry is a ROLE plus a
direction adjective, never a value. It emits no hex, no functional-colour scalar, no named
colour used as a value.

It does NOT extract the concept and it does NOT map mood to tier relationships — those are
its neighbours' jobs. See **What this file does not do** below. This file is the format of
the block that rides between them.

## The seam — four owners, one flow

The concept travels extraction → mapping → **payload (here)** → generation. Each stage has
exactly one owner, and this file is only the third:

1. **EXTRACT the concept** — `creative-direction` (central metaphor · editorial voice ·
   signature interaction, plus the palette DIRECTION and divergence record) and
   `design-research` (`SKILL.md:71-79`, "Concept input", which receives that concept and
   biases the briefs). They decide WHAT the concept IS. This file never restates that.
2. **MAP mood → tier relationships** — `token-tiers.md` owns which tiers exist and how the
   concept's mood sets the RELATIONSHIPS between them (chroma / contrast-step / warmth as
   relationships, not values). This file never restates that mapping.
3. **CARRY the payload** — THIS file: the FORMAT of the compact token-system-direction
   block the theme brief carries, so the direction survives the handoff intact.
4. **GENERATE the values** — `/ui-ux:theme` resolves the direction to actual light/dark
   values along the `design-tokens` ramps. This file names no number.

## The payload — the token-system-direction block

`design-research` derives this block into the theme brief (card 06 threads the slot into
`design-research/references/brief-templates.md`; `/ui-ux:theme` then consumes the brief).
It is three lines, one per concept facet, each mapping the facet to a token-role DIRECTION —
adjectives and role names only, never a value:

```
metaphor → surfaces/ink/accent tier direction: <how the metaphor shapes the surface
           elevation feel, the ink hierarchy's register, and the accent's presence>
voice    → type/contrast direction: <how the editorial voice shapes the type pairing and
           how sharp or soft the steps between tiers and ink ranks read>
mood     → chroma/warmth direction: <how saturated the accent/tints sit relative to
           neutral, and the one temperature bias shared across neutrals and accent>
```

Direction-only example (no value is stated — each phrase is a role and an adjective):

```
metaphor → surfaces step like layered paper, ink settles into a calm three-rank
           hierarchy, accent stays a single restrained voice
voice    → humanist type with high display-to-body contrast; crisp, wide steps between
           surface tiers and ink ranks
mood     → focused accent against near-neutral surfaces; one warm temperature shared by
           neutrals and accent
```

Rules the payload obeys:

- **Roles and direction adjectives only.** Name the tier ROLE (surface / ink / accent) and
  the DIRECTION (warm/cool, crisp/soft, focused/expressive). Never a hex, a functional-colour
  scalar, or a named colour used as a value — `/ui-ux:theme` owns every number.
- **One coherent concept.** The three lines describe one system; they must read as the same
  metaphor · voice · mood the briefs carry, not three unrelated nudges.
- **Point, do not restate.** For WHICH tiers exist and how mood relates them, the payload
  defers to `token-tiers.md`; it carries the direction, it does not re-derive the map.

## What this file does not do

- It does not EXTRACT or generate the concept — `creative-direction` and `design-research`
  (`SKILL.md:71-79`) own metaphor · voice · mood; this file only carries them forward.
- It does not MAP mood to tier relationships — `token-tiers.md` owns chroma / contrast-step
  / warmth as tier RELATIONSHIPS; this file references that map, it does not restate it.
- It does not GENERATE values — `/ui-ux:theme` resolves the direction to light/dark values;
  `design-tokens` owns the numeric ramps.
- It emits no hex, no functional-colour scalar, and no named colour used as a value — the
  payload is direction all the way down.
