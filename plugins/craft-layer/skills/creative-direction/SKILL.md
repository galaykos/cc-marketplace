---
name: creative-direction
description: Use before a craft build to fight generic, thin results on a landing page, SaaS, CRM, or app: classify the work-type archetype, dispatch the creative-director agent for a divergent concept (metaphor, voice, one signature interaction) that breaks sameness-fingerprint defaults, key a content-depth budget, and bias palette direction. Ships dials and registries, never templates or an idea catalog; feeds design-research, never replaces it.
---

## What this decides

This skill is the CREATIVE FRONT END of a craft build: it decides the distinctive
CONCEPT and the substance targets before `design-research` mines references (mining is
convergent — it averages toward the category norm). It is a **pure router**: every
subsystem's decision logic lives in a reference file; this body only routes, states the
seam, and holds the reuse boundaries. It decides:

- the **offer contract** (what the build sells) → `references/offer-contract.md`
- the **work-type archetype** and its dials → `references/archetypes.md`
- the **concept** (via the `creative-director` agent) → below
- the **content-depth budget** (anti-thinness) → `references/content-depth.md`
- the **palette DIRECTION** (not values) → `references/palette-strategy.md`
- what a build must **diverge from** (anti-sameness) → `references/sameness-fingerprint.md`
- the **MOVES taxonomy** it reasons from → `references/moves-taxonomy.md`

It does NOT generate tokens/palettes (`/ui-ux:theme`, `design-tokens`, `shadcn-theming`)
or mine references (`design-research`). It produces DIRECTION + a concept; those tools
own values and mining.

## The seam — runs before design-research

The `/craft-layer:craft` command owns the seam: it classifies the archetype, dispatches
the `creative-director` agent, then passes the chosen concept (and its divergence record)
as an INPUT into the `design-research` briefs. `design-research`'s mining method is
unchanged — it gains a concept input that biases the theme brief + build task. The
concept never reaches the build except through those briefs, so the command MUST thread
it; a concept generated and dropped is the failure this seam exists to prevent.

## Pin the offer contract before the concept

A distinctive page that never says what the product is, who buys it, what it costs, or what
to click has failed the commission. Before the archetype, pin ONE product under its real
name, the audience, the one primary action, the route list, the page length, and what is not
shipping — and ASK when the brief admits several products rather than building all of them.
The concept's metaphor is a design language, not a rebrand. A long scroll is legitimate when
DECLARED, and then carries its own rules. Slots, scope rule, and teeth live in
`references/offer-contract.md`; the craft audit checks it.

## Decide the archetype first

Classify the brief into one work-type archetype — creative/portfolio, marketing/campaign,
product/SaaS, editorial/content, or app/CRM — because every downstream dial (density,
motion energy, spine bias, depth target, palette mood) is archetype-keyed. Ambiguous or
multi-type → pick the nearest and adjust dials. A brief matching none (e-commerce, docs,
web3, game, community) uses the `general` fallback. The dial-set and the classification
rule live in `references/archetypes.md`.

## Generate the concept — dispatch the creative-director agent

The concept is DIVERGENT reasoning, so it is an agent, not a checklist: dispatch the
`creative-director` agent (`agents/creative-director.md`). It generates N blind concepts —
each a central metaphor, an editorial voice, and ONE signature interaction — seeded by the
anti-corpus differential (each must break ≥1 sameness-fingerprint default), scores them on
distinctiveness × brief-fit × feasibility (feasibility includes a usability floor), and
returns the winner plus a **structured divergence record** the audit later checks. The
agent owns the rubric; this skill only says WHEN to run it and WHAT it feeds.

## Content depth — kill thinness

Award-grade pages are substantial and specific, not skeletal. The per-archetype budget
(section-count + per-section word floors + a typed-slot specificity rule) lives in
`references/content-depth.md`. It is checked by the craft audit, not enforced here.

## Palette direction — mood + don't-repeat, not colour

This skill contributes only the archetype→mood mapping and a don't-repeat-recent-hues
nudge (driven by the fingerprint's recent-hue list). Colour and accent DIRECTION stay in
`design-research` (the briefer); the accent-contrast DERIVATION is owned by `theming-system`.
Generation stays `/ui-ux:theme`. Detail: `references/palette-strategy.md`.

## Anti-sameness — what to diverge from

The `sameness-fingerprint` registry (`references/sameness-fingerprint.md`) is the
source-of-truth of the recurring spine, component vocabulary, and recent hues. Naming
those there is cataloguing what to DIVERGE FROM — the anti-corpus — not a prescription.
The audit fails a build that matches the fingerprint on all-but-one axes with an empty
divergence record; an explicit request for a conventional design is a valid justification.

## MOVES taxonomy — categories, cached + opt-in live

The agent reasons from a taxonomy of MOVE CATEGORIES (hero archetypes, scroll devices,
type treatments, motion signatures) with when-to-use — categories, never enumerated named
moves (that would be the forbidden catalog). Cached by default; an opt-in live per-brief
research pass reuses `ultra-deep-research` when present and degrades to the cache when
absent. Detail: `references/moves-taxonomy.md`.

## Reuse — never duplicate

| Concern | Owned by |
| --- | --- |
| Palette / theme generation, contrast tooling | `/ui-ux:theme`, `shadcn-theming` |
| Token scales (spacing/type/radius/elevation/motion) | `design-tokens` |
| Reference mining → theme brief + build task | `design-research` (this skill feeds it) |
| Colour / accent DIRECTION | `design-research` |
| Accent-contrast derivation | `theming-system` (`accent-system.md`) |
| Live research provenance / licence discipline | `ultra-deep-research` (opt-in) |
| Content-depth + anti-sameness VERIFICATION | `/craft-layer:audit` (craft gate) |

Concept and DIRECTION belong here; values, mining, and generation belong to those.

## References

- `references/offer-contract.md` — deliverable scope, product identity, the offer-spine slots.
- `references/archetypes.md` — the work-type dial-set, classification rule, `general` fallback.
- `references/content-depth.md` — per-archetype section/word anchors + the typed-slot rule.
- `references/sameness-fingerprint.md` — the anti-corpus registry (spine, vocabulary, hues),
  seed + recency window + release-cadence upkeep.
- `references/palette-strategy.md` — archetype→mood + don't-repeat nudge; defers colour to
  design-research.
- `references/moves-taxonomy.md` — MOVE categories + when-to-use; the opt-in live pass and
  its probe→degrade fallback.

## Anti-patterns

- **Concept dropped** — generating a concept the craft command never threads into the
  briefs; it evaporates and the build defaults.
- **Router carries logic** — inlining a rubric, dial semantics, or anchors into this body
  instead of its reference file; the body must stay a router within 100–150 lines.
- **Duplicating generation** — restating palette/token/mining rules here instead of routing
  to their owners.
- **Idea catalog** — enumerating named moves or a template per archetype; ship categories,
  dials, and registries, never a design.
- **Novelty for its own sake** — a concept that diverges but worsens usability; the agent's
  feasibility floor exists to reject it.
- **Concept before contract** — generating a metaphor with no product, audience, price, or
  CTA pinned; the build then sells nothing, however distinctive it looks.
