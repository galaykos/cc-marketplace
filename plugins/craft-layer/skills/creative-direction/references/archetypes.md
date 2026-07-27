# Work-type archetypes — the dial-set

An archetype is a set of DIALS, not a template. It biases defaults; the concept and the
build still differ per brief. Classify first, then read the dials as starting positions
the concept can push against (a marketing brief that wants restraint, a SaaS brief that
wants theatre — the dial is where you start, not where you must land).

## Classify the brief

The `/craft-layer:craft` command (or the creative-director agent's first move) picks ONE
archetype from the product description and audience:

- **creative/portfolio** — a studio, designer, agency, or showcase whose product IS the
  craft. Distinctiveness is the deliverable.
- **marketing/campaign** — a launch, event, or single-narrative page selling one idea.
- **product/SaaS** — a tool sold on capability and trust; information-dense, conversion-led.
- **editorial/content** — a publication, essay, report, or long-form story; reading is the job.
- **app/CRM** — a logged-in product surface; the marketing pages are a front door to a
  data-dense app.

Ambiguous or multi-type → pick the NEAREST and adjust dials (a "SaaS for creatives" leans
product/SaaS on structure, creative/portfolio on motion energy). A brief that matches NONE
(e-commerce/storefront, docs site, web3/dapp, game, community/forum) → the **`general`
fallback** below.

## The dials

Each archetype sets six dials. Values are directional (low / medium / high, or a bias),
never pixels or components.

| Archetype | Tone | Density | Motion energy | Spine bias | **Composition bias** | Depth target |
| --- | --- | --- | --- | --- | --- | --- |
| creative/portfolio | expressive, confident | low, generous whitespace | high — motion is the signature | work-led (grid/case-studies first) | broken grid · layered depth · off-axis | medium (case studies carry it) |
| marketing/campaign | persuasive, punchy | medium | medium–high, one hero moment | narrative arc to a single CTA | full-bleed panels · asymmetric split | medium |
| product/SaaS | credible, precise | high, information-dense | medium, restrained | problem→solution→proof→pricing | strict column grid · asymmetric split | high (many sections + specifics) |
| editorial/content | authoritative, calm | text-first | low, reading-safe | long-form flow, few interruptions | **centred spine** — its home | very high (long inner pages) |
| app/CRM | efficient, trustworthy | high (data) | low on marketing, none in-app | front-door pages → app entry | asymmetric split (persistent rail) | medium marketing; in-app defers to information-design |
| **general (fallback)** | neutral, adaptable | medium | medium | hero→value→proof→CTA | drawn, with no bias applied | medium (mid-range anchors) |

**Composition bias exists because a page can pass every other gate and still be the wrong
shape.** Spine bias orders the sections; composition bias is how they occupy space, and the
two are independent — the same problem→solution→proof→pricing order builds as a strict grid,
a split, or a stack of full-bleed panels, and those are three different products to look at.
The values name options from `concept-deck.md` Axis 1; the dial is a starting position the
draw and the concept can push against, exactly like every other dial here.

**Centred spine is editorial's home and everywhere else it needs an argument.** It is the
shape a build lands on when nothing decides, because it is the shape prose defaults to — one
measure, top to bottom, no exceptions. That makes it simultaneously the RIGHT answer for a
publication and the tell of a page that never chose. A run that draws it outside
editorial/content should be able to say why in one line; the `composition-shape` assertion in
`template/craft-gates/divergence.mjs` fails the undecided version and takes a waiver for the
deliberate one. A marketing/campaign brief that ships editorial's composition has not
under-reached on motion or colour — it has answered a different archetype's question.

## How the dials feed downstream

- **Tone + motion energy** seed the creative-director agent's concept (voice + the single
  signature interaction) and the palette mood (`palette-strategy.md`).
- **Density + spine bias** inform the build task `design-research` writes.
- **Composition bias** weights the Axis 1 draw in `concept-deck.md` and reaches the build task
  as a named structure, not as an adjective. It must arrive somewhere a builder reads: a
  composition that lived only in this table is the one the page silently defaults away from.
- **Depth target** selects the row in `content-depth.md`.

## The `general` fallback

When no archetype fits, use `general`: medium on every dial, the mid-range content-depth
anchors, and a hero→value→proof→CTA spine bias. Composition is the one dial `general` does
NOT set to a middle value — there is no middle composition, and the nearest thing to one is
the centred spine this file just warned about. `general` leaves Axis 1 to the draw unweighted. The agent still generates a divergent
concept — the fallback sets neutral dials, it does not skip creative direction. Prefer a
nearest-archetype match with adjusted dials over `general` whenever one is defensible;
`general` is the floor, not the default.

## Anti-patterns

- **Archetype as template** — treating a row as a layout to reproduce; it is a set of
  starting dials the concept pushes against.
- **Skipping classification** — running the concept with no archetype, so density/depth/
  palette have nothing to key on.
- **Forcing a fit** — jamming a genuinely novel brief into a poor archetype instead of
  `general` with adjusted dials.
