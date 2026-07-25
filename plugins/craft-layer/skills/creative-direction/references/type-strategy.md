# Type strategy — derive a typeface SPEC, never name a typeface

The sibling of `palette-strategy.md`. That layer contributes a mood and an
anti-repeat nudge for colour; this one runs the same job for type, with one
difference: type has hard, checkable constraints that colour does not, so this
layer derives a **spec** rather than an adjective.

**Why this exists.** Typography carries the largest single weight in the only
published award rubric, and it is the field a build most often defaults into.
The craft audit already gates that a typeface DECISION was made and recorded —
but a gate with no matching derivation turns a quality question into a
paperwork question: a build can record "system stack" and pass while never
having chosen anything. This file is the missing derivation.

**Ownership boundary (binding).** Type SCALES — sizes, line-heights, weights,
measure — are `plugins/ui-ux/skills/design-tokens/SKILL.md`. The static type
CONTRACT — zoom-safe fluid sizing, `text-wrap`, optical sizing, font-loading and
the licence-tier trap — is
`plugins/craft-layer/skills/kinetic-typography/references/type-system.md`.
Animated type is that skill's body. Generation and preview stay `/ui-ux:theme`.
This layer decides only WHICH SHAPE OF FACE the brief needs, and hands it on.

## The kill-trigger, restated for type

**Never name a family as an answer.** Naming families to DIVERGE from is the
anti-corpus exception and lives in `sameness-fingerprint.md`; naming one to USE
is a catalog, and a catalog is how an anti-sameness engine manufactures a new
sameness.

The test is mechanical: **if this file would need editing when a new typeface is
released, it has become a catalog.** Constraints survive new releases; answers
do not.

## Derive the spec — seven filters, hardest-cutting first

Each is a filter, not a preference. Run them in order; most briefs are fully
determined by the first three.

1. **Are numbers read down a column?** Any table, ledger, dashboard, price list
   or spec sheet → **tabular figures are REQUIRED**, and proportional-only faces
   are out. Ask first: it is the cheapest question and it eliminates most
   display faces immediately.
2. **Is there text below roughly 14px in a dense region?** → the face needs a
   text-optimised cut, or an `opsz` axis so one family covers display and text
   without shipping two. A display cut set small is the most common typographic
   failure in dense UI.
3. **Does the voice need display-vs-text contrast, and how much?** Resolves to
   one of three STRATEGIES — this is the decision, not the family:
   - **one variable family, weight-driven** — hierarchy from `wght` and size
     alone. Cheapest, most coherent, reads civic/documentary. The right default
     when the content is the argument.
   - **a superfamily** — sibling serif/sans/mono sharing metrics and
     proportions. Buys classification contrast without the metric clash.
   - **two contrasting families** — most expressive, most expensive, and the one
     most often chosen from habit rather than derivation. Requires an argument.
4. **Script and glyph coverage** — Latin-ext, Cyrillic, Greek, CJK, Arabic;
   plus any symbol set the content actually needs. Hard filter, and the one
   discovered too late most often. Check it against real content, not lorem.
5. **Licence class reachable** — an open licence (with its obligations: ship the
   licence text, honour a Reserved Font Name) or a commercial **web** tier.
   Never a desktop licence: the provenance manifest records the class and cannot
   see the tier, so a desktop-only purchase reads as compliant and is not.
6. **KB budget** — decides family count and axis subsetting, and it binds. Two
   families is a decision; three is usually an accident. A second family bought
   for one block is the classic overspend — price it per block before shipping
   it, and subset axes rather than shipping every axis a variable font offers.
7. **Anti-corpus** — read the type-family list in `sameness-fingerprint.md`.
   Those families and that pairing SHAPE are disqualified unless the brief
   argues for one on the merits; "it is what the template shipped with" is not
   an argument. Note in the spec what was avoided, as `palette-strategy.md` does
   for hues.

## Archetype → starting strategy

Directional, not prescriptive; the concept may override any row.

| Archetype | Starting strategy |
| --- | --- |
| creative/portfolio | contrast-led; type may BE the signature |
| marketing/campaign | one expressive display voice over a plain text face |
| product/SaaS | restrained; numerals and small-size legibility dominate |
| editorial/content | reading-first; long-form measure and rhythm dominate |
| app/CRM | single family, weight-driven; tabular figures non-negotiable |
| general (fallback) | single variable family until something argues otherwise |

## What reaches the theme brief

One line, in the brief's `type` slot — the SPEC plus what it avoided:

```
type <strategy> + <required axes/features> + <coverage> + <licence class>
     + <KB ceiling>; avoiding <anti-corpus entries>
```

The build then matches a real family against that spec. The spec is what gets
recorded with the decision and what the audit reads: a recorded family with no
spec behind it is a default wearing a decision's clothes.

**A deliberate system-font stack that satisfies its spec is a PASS** — for a
privacy-sensitive, offline, or extreme-budget brief it may be the correct
answer. The gate is never "did you ship a webfont".

## Anti-patterns

- **Naming a family here** — the kill-trigger. Ship filters; let the build match.
- **Skipping to strategy 3** — reaching for two families because pairings feel
  like design, without an argument the single-family route could not serve.
- **Adjectives instead of a spec** — "a modern sans" is not derivable and not
  checkable; it is what this layer exists to replace.
- **Deferring coverage and licence** — filters 4 and 5 are cheap before the
  choice and expensive after it.
- **Pricing the face but not the axes** — shipping every axis of a variable font
  when the spec needs one, or every subset when the content is one script.
- **Recording the family and not the spec** — the audit cannot tell a decision
  from a default without it.
