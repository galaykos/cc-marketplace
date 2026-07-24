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

- a concrete **offer numeral** — a price, a fee %, a step count, a tier limit, a dimension:
  a fact the build itself DEFINES (the product's own terms), OR
- a defined **`{{typed slot}}`** placeholder the user fills — e.g. `{{customer_name}}`,
  `{{metric:forecast_accuracy}}`, `{{integration}}`, `{{scenario}}`.

**Offer numerals vs claim metrics — a numeral is not automatically specificity.** A numeral
counts only when it is part of the OFFER: something the design decides ($19/mo, 4% fee, 3
steps, 5 seats). A **claim / aggregate metric** — GMV, user/customer/creator counts, ratings,
"used by N teams", payout times — is a fact about the world the build CANNOT know, so it MUST
ship as a `{{metric:*}}` slot, **never as an invented literal.** A fabricated claim numeral
does not satisfy the rule — it fails it exactly like generic prose, the numeral only hides the
fabrication. Ship `{{metric:gmv}}`, not `$48M`; `{{metric:active_users}}`, not `12,400`.

And each page must carry **≥ N distinct typed slots**, where **N ≈ the count of the page's
entity/claim-bearing sections** (creators, testimonials, stats, logos) — NOT every section. An
offer-heavy page (pricing, features, steps) legitimately fills those blocks with offer numerals
and must not be forced to invent slots it does not need; the slot floor targets fabrication, not
honest concreteness. Depth = STRUCTURE + typed slots, never invented facts: ship `{{slots}}` for
the user to fill, never fabricate a number or a customer. A page with zero numerals and zero
slots FAILS regardless of word count.

## What the audit checks (teeth)

The craft audit (`/craft-layer:audit`) reads THIS file (injected as a Read path) and:

- counts sections against the archetype's range;
- greps each block for a numeral or a `{{slot}}`;
- counts distinct typed slots per page against N (entity/claim-bearing sections);
- flags any **claim/aggregate metric written as a literal** — GMV, user/creator counts,
  ratings, durations — that should be a `{{metric:*}}` slot.

A build under the section floor, a block carrying neither a numeral nor a slot, a page below
the slot count, or a fabricated claim numeral (a literal where a `{{metric:*}}` slot belongs),
is a finding. Offer numerals (price, fee, step counts) are not flagged. The numbers are the
anchor the reviewer cites — the check is objective, not an aesthetic judgment.

## Anti-patterns

- **Word-floor filler** — hitting the copy volume with generic prose and no numerals or
  slots; the specificity rule exists to fail exactly this.
- **Fabricated specifics** — inventing a metric or customer to satisfy specificity; ship a
  typed slot instead.
- **Treating anchors as a template** — building exactly 11 identical sections; the range is
  a floor and a shape, not a layout.
- **app/CRM skip** — assuming the thinness gate does not apply because it is an app; its
  marketing surface still owes the floor.
