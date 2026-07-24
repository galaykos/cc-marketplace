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

Each archetype sets five dials. Values are directional (low / medium / high, or a bias),
never pixels or components.

| Archetype | Tone | Density | Motion energy | Spine bias | Depth target |
| --- | --- | --- | --- | --- | --- |
| creative/portfolio | expressive, confident | low, generous whitespace | high — motion is the signature | work-led (grid/case-studies first) | medium (case studies carry it) |
| marketing/campaign | persuasive, punchy | medium | medium–high, one hero moment | narrative arc to a single CTA | medium |
| product/SaaS | credible, precise | high, information-dense | medium, restrained | problem→solution→proof→pricing | high (many sections + specifics) |
| editorial/content | authoritative, calm | text-first | low, reading-safe | long-form flow, few interruptions | very high (long inner pages) |
| app/CRM | efficient, trustworthy | high (data) | low on marketing, none in-app | front-door pages → app entry | medium marketing; in-app defers to information-design |
| **general (fallback)** | neutral, adaptable | medium | medium | hero→value→proof→CTA | medium (mid-range anchors) |

## How the dials feed downstream

- **Tone + motion energy** seed the creative-director agent's concept (voice + the single
  signature interaction) and the palette mood (`palette-strategy.md`).
- **Density + spine bias** inform the build task `design-research` writes.
- **Depth target** selects the row in `content-depth.md`.

## The `general` fallback

When no archetype fits, use `general`: medium on every dial, the mid-range content-depth
anchors, and a hero→value→proof→CTA spine bias. The agent still generates a divergent
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
