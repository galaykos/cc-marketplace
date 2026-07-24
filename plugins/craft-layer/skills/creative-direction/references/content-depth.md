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

**On a `long-scroll` build the range is a FLOOR, not a ceiling.** When the offer contract declares
`long-scroll` (`offer-contract.md`, Part 5), a page may run well past its archetype's section
count and that is not a finding — the extra length carries its own rules there (spine answered
early, CTA recurring, section shapes varied, wayfinding past ~8 sections, below-fold instruments
lazy). The specificity rule does not relax with length: every added section still owes an offer
numeral or a typed slot, and length reached by repeating one section shape is the anti-pattern
`anchors as template` at scale, not depth.

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

**Capability claims are the third category, and the one that slips through.** Between the offer
numerals the design legitimately decides and the aggregate metrics it obviously cannot, sits a
class of facts about what the REAL product does: coverage ("16 US metros at launch", "available
in 30 countries"), integrations ("works with Salesforce, HubSpot"), supported platforms, SLAs and
uptime figures, compliance certifications (SOC 2, HIPAA, GDPR), data-retention windows, staffing
and support hours. These read like offer terms — they are specific, they are not aggregates, they
sound like something the seller decides — but the BUILD does not know any of them, and inventing
one is worse than inventing a metric: a visitor can act on "SOC 2 certified" or "covers your
city" in a way they cannot act on a vanity number. Ship them as `{{capability:*}}` slots
(`{{capability:metro_coverage}}`, `{{capability:integrations}}`, `{{capability:compliance}}`),
manifested exactly like claim metrics — plausible sample + one marker + a source tag. A capability
claim written as an unmarked literal is a finding, however plausible it sounds.

The boundary test: could the DESIGN decide this, or only the business? Price, tier limits, step
counts, plan names → the design's terms, shown plainly. Where the product operates, what it
integrates with, what it is certified for, how fast it responds → the business's facts, slotted.

And each page must carry **≥ N distinct typed slots**, where **N ≈ the count of the page's
entity/claim-bearing sections** (creators, testimonials, stats, logos) — NOT every section. An
offer-heavy page (pricing, features, steps) legitimately fills those blocks with offer numerals
and must not be forced to invent slots it does not need; the slot floor targets fabrication, not
honest concreteness. Depth = STRUCTURE + typed slots, never invented facts: ship `{{slots}}` for
the user to fill, never fabricate a number or a customer. A page with zero numerals and zero
slots FAILS regardless of word count.

## Manifestation — a claim slot must render finished, not raw

A `{{metric:*}}` slot is a SOURCE contract, not what ships to the eye. Raw `{{mustache}}` left
in the rendered UI reads as broken — an unfinished demo, a weak award submission — and if it
ever ships unfilled it says nothing. So a claim metric renders as a **labeled illustrative
sample**, three parts, all required:

- a **plausible sample value** ("$48M raised", "1,240 members") — so the page looks finished;
- a **visible illustrative marker** — a "sample data" caption on the region, a chip, or a
  footnote — so the figure is never passed off as a real, verified claim;
- a **source tag** binding value → slot: a `data-metric="gmv"` attribute (or the
  `{{metric:gmv}}` kept in a comment) — so the real number swaps in cleanly and the audit can
  still find it.

This keeps BOTH honesty (clearly illustrative, never a fabricated claim asserted as real) and a
finished surface. A bare `{{metric:gmv}}` visible in the rendered output, and an unmarked
invented literal, are BOTH findings — the first unfinished, the second dishonest. (Offer
numerals need none of this — they are the design's own terms, shown plainly.)

**ONE marker per figure, at most one more per region — markers do not stack.** Honesty signals
feel free, so they multiply. A region acquires a chip on every figure, then a banner above them,
then an explanatory lede, then a headline that says the quiet part ("What it has done, once you
fill this in") — and a region whose whole job is to build belief now announces four times over
that it is unfinished. That is not more honest than one clear marker; it just reads as a
construction site. So: one marker beside the figure (the chip — disclosure belongs next to the
number it qualifies), OPTIONALLY one quiet footnote closing the region, nothing else. The region's
HEADLINE and lede are buyer-facing copy addressed to the READER, never to the operator who will
fill the slots; operator instructions live in the README.

**A slot with no plausible sample value is CUT, not shipped empty.** Manifestation needs a value
that can look finished, and some slots have none: a customer LOGO, a named company, a named
person — every sample is an invented entity, the exact fabrication this rule exists to stop.
Shipping the bare affordance instead (a dashed "logo slot" tile, a greyed placeholder grid) is
the raw-`{{mustache}}` failure in different clothes; it reads unfinished to every visitor. Drop
that sub-block and let the region stand on the slots that CAN render finished — metrics, and
quotes attributed by ROLE and SEGMENT rather than by an invented name. A region reduced this way
still satisfies its presence requirement; a grid of empty placeholders does not.

## What the audit checks (teeth)

The craft audit (`/craft-layer:audit`) reads THIS file (injected as a Read path) and:

- counts sections against the archetype's range — as a floor only when the offer contract
  declares `long-scroll`, in which case over-range is not a finding and the Part-5 long-page
  rules apply instead;
- greps each block for a numeral or a `{{slot}}`;
- counts distinct typed slots per page against N (entity/claim-bearing sections);
- flags any **claim/aggregate metric written as a literal** — GMV, user/creator counts,
  ratings, durations — that should be a `{{metric:*}}` slot;
- flags any **capability claim written as a literal** — geographic/market coverage, named
  integrations, supported platforms, SLA/uptime figures, compliance certifications, retention
  windows, support hours — that should be a `{{capability:*}}` slot;
- checks each claim metric's **manifestation** — it must render as the labeled-illustrative
  pattern (plausible value + a visible sample/illustrative marker + a `data-metric` or comment
  source tag), NOT as raw `{{mustache}}` in the output, NOT as an unmarked invented literal;
- counts the DISCLOSURE markers per region — more than one marker per figure plus one regional
  footnote is a finding (a stacked banner + chip + confessional headline/lede), as is a section
  headline or lede addressed to the operator instead of the reader;
- flags an **empty placeholder affordance** — a dashed/greyed tile grid standing in for logos or
  named customers, i.e. a slot shipped with no plausible sample value; it should have been cut.

A build under the section floor, a block carrying neither a numeral nor a slot, a page below
the slot count, a fabricated claim numeral (a literal where a `{{metric:*}}` slot belongs), OR
a claim rendered as raw `{{mustache}}` / an unmarked invented literal, is a finding. Offer numerals (price, fee, step counts) are not flagged. The numbers are the
anchor the reviewer cites — the check is objective, not an aesthetic judgment.

## Anti-patterns

- **Word-floor filler** — hitting the copy volume with generic prose and no numerals or
  slots; the specificity rule exists to fail exactly this.
- **Fabricated specifics** — inventing a metric or customer to satisfy specificity; ship a
  typed slot instead.
- **Invented capability** — a coverage, integration, certification, or SLA claim written as a
  literal because it sounded like an offer term; only the business knows it, so it is a slot.
- **Raw mustache shipped** — leaving `{{metric:*}}` visible in the rendered UI; render a
  labeled illustrative sample (value + "sample" marker + `data-metric` tag) so the page reads
  finished while staying honest.
- **Disclosure stack** — chip + banner + confessional lede + a headline addressed to the
  operator, all on one region; one marker per figure plus one footnote is the whole budget.
- **Empty placeholder grid** — shipping a logo/named-customer slot as dashed tiles because it
  has no plausible sample value; cut the sub-block, keep the region.
- **Treating anchors as a template** — building exactly 11 identical sections; the range is
  a floor and a shape, not a layout.
- **app/CRM skip** — assuming the thinness gate does not apply because it is an app; its
  marketing surface still owes the floor.
