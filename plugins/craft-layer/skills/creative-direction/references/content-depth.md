# Content-depth budget — anti-thinness

Award-grade pages are substantial and SPECIFIC; skeletal pages with one heading and two
sentences per section read as unfinished. This budget sets, per archetype, how much
structure and copy a build owes — and makes "specific" checkable so word-count alone
cannot be gamed with filler.

These anchors are **tunable ranges, not a template**: they set a floor and a shape, never
a fixed layout or component. They are exempt from the kill-trigger's 1:1 rule because a
range is not a design.

## Per-archetype anchors

| Archetype | Sections (landing) | Per-block copy | Inner / detail pages |
| --- | --- | --- | --- |
| product/SaaS | 9–13 | feature blocks 40–90 words | 600–1200 words |
| marketing/campaign | 6–10 | 30–70 words | 300–800 words |
| editorial/content | 4–8 (long-form) | — (prose-led) | 800–2000 words |
| creative/portfolio | 5–8 | project blurbs 25–60 words | case studies 400–900 words |
| app/CRM | **5–8 marketing sections** | 30–70 words | in-app density → `information-design` |
| general (fallback) | 7–10 | 30–80 words | 500–1000 words |

**app/CRM is not a no-op.** Its marketing/front-door pages still owe the 5–8-section floor
and the specificity rule below; only the logged-in, data-dense app screens defer to
`information-design` (which governs data density, not marketing copy depth).

## The specificity rule (typed slots)

Volume without substance is still thin. Every section/feature block must carry at least ONE
of:

- a concrete **numeral** (a metric, a count, a price, a duration), OR
- a defined **`{{typed slot}}`** placeholder the user fills — e.g. `{{customer_name}}`,
  `{{metric:forecast_accuracy}}`, `{{integration}}`, `{{scenario}}`.

And each page must carry **≥ N distinct typed slots** (N ≈ the section count): named
entities, scenarios, metrics — not the same slot repeated. Depth = STRUCTURE + typed
slots, never invented facts: ship `{{slots}}` for the user to fill, never fabricate a
number or a customer. A page of generic marketing prose with zero numerals and zero slots
FAILS the content-depth gate regardless of word count.

## What the audit checks (teeth)

The craft audit (`/craft-layer:audit`) reads THIS file (injected as a Read path) and:

- counts sections against the archetype's range;
- greps each block for a numeral or a `{{slot}}`;
- counts distinct typed slots per page against N.

A build under the section floor, or with blocks carrying neither a numeral nor a slot, or
below the slot count, is a finding. The numbers are the anchor the reviewer cites — the
check is objective, not an aesthetic judgment.

## Anti-patterns

- **Word-floor filler** — hitting the copy volume with generic prose and no numerals or
  slots; the specificity rule exists to fail exactly this.
- **Fabricated specifics** — inventing a metric or customer to satisfy specificity; ship a
  typed slot instead.
- **Treating anchors as a template** — building exactly 11 identical sections; the range is
  a floor and a shape, not a layout.
- **app/CRM skip** — assuming the thinness gate does not apply because it is an app; its
  marketing surface still owes the floor.
