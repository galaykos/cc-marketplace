# Offer contract — what the build SELLS, pinned before what it looks like

A craft build can clear every motion, contrast, and depth gate and still fail the job it
was commissioned for: a visitor cannot tell what the product is, who it is for, what it
costs, or what happens when they click. The concept decides how a page FEELS; this
contract decides what it has to SELL. Pinned at the start of `/craft-layer:craft`, before
the creative-director agent runs, and threaded into both `design-research` briefs.

Like the archetype dials, this is a set of SLOTS to fill — never a layout, never a section
order.

## Part 1 — Deliverable scope (pin before writing a file)

Resolve all five, echo them to the user, then build:

| Field | Must resolve to |
| --- | --- |
| Product | ONE product, under its REAL name |
| Audience | who is buying, in a phrase |
| Primary action | the ONE thing a visitor should do (book a demo, start a trial, contact) |
| Routes | the exact page/route list that ships |
| Length | `standard` or `long-scroll` — see Part 5 |
| Mode | `one-shot` or `guided` — see Part 6 |
| Not shipping | what was considered and cut |

**One product per build.** When the brief admits several products, positionings, or
directions, ASK which one. Presenting options and then building all of them is a finding,
not a compromise: the visitor has to self-route before they know what either product is,
and each page's proof, pricing, and CTA get half the room they need.

**Internal artifacts are not routes.** A token/kit/design-system showcase is a useful build
artifact; it ships as a site route only when the user asked for one. Mounted in the product
nav it reads as an unfinished demo.

## Part 2 — Product identity survives the concept

The concept's central metaphor is a design LANGUAGE — voice, visual system, the one
signature interaction. It is not a rebrand. The real product name stays in `<title>`, the
hero, and the nav; a metaphor-derived nickname may sit beside it as a label for a surface
or a tier, never in place of it. A build whose shipped wordmark is a name the concept
invented is a finding — the buyer arrived looking for the product they were told about and
cannot find it.

## Part 3 — The offer spine (slots, archetype-scaled)

Every marketing / front-door page owes these answers, in whatever order and form the
concept chooses. Each is a SLOT with an owner, not a prescribed section:

| Slot | The visitor's question | Failure mode |
| --- | --- | --- |
| Plain-language what | "what is this?" — one sentence, no metaphor, above the fold | metaphor-only hero |
| Who it is for | "is this for me?" | audience never named |
| Problem / status quo | "why change?" | features with no stake |
| How it works | "what actually happens?" — 3–5 concrete steps | capability adjectives |
| Offer + price | "what does it cost?" — offer numerals or a `{{price:*}}` slot | pricing absent, no reason given |
| Proof | "why believe you?" — see Part 4 | omitted |
| Objection | "what is the catch?" — limits, requirements, what it is NOT | silence |
| Primary CTA | "what do I do?" — one verb, repeated, saying what happens next | several competing CTAs |

Method disclosure, spec sheets, and API tables are **supporting** material: they answer the
"how it works" and "objection" slots for a technical buyer. A page built ONLY of specs has
skipped every other slot — that is the most common way a craft build reads as
uninformative while being dense.

**Checking "plain-language" mechanically.** Whether a sentence is plain reads like taste, but the
concept makes it testable: the divergence record names the central METAPHOR, so that metaphor's
own vocabulary is the thing the plain-what line may not be built from. Take the metaphor's terms
(and their obvious cognates), then check the h1 and the sentence under it:

- the h1 is built from metaphor vocabulary and names no product capability → finding
  ("A rank is a position, not a score." under a navigation metaphor: an aphorism, not a what);
- the h1 is plain but the product's own name never appears within the first screen → finding;
- the h1 is plain and states the capability → pass, whatever the concept elsewhere.

Aphorisms fail for the same reason: a line that could head three different products in the
category has not said what this one does. The metaphor belongs in the eyebrow, the section heads,
the visual system, and the signature interaction — everywhere except the one sentence that has to
survive a reader who arrived knowing nothing.

Scale by archetype: marketing/campaign may fold several slots into one narrative;
product/SaaS owes most slots their own block; app/CRM front doors owe the full spine on the
marketing surface. Section COUNTS stay with `content-depth.md` — this file sets what must
be answered, that one sets how much.

## Part 4 — Proof is slotted, never deleted

Refusing to fabricate a testimonial, a customer logo, or an outcome metric is correct.
Deleting the proof slot to avoid the fabrication is a SECOND failure, and it is the one
that costs the sale. `content-depth.md` already owns the remedy: ship the region with
`{{metric:*}}` / `{{customer_name}}` slots rendered as labeled illustrative samples
(plausible value + visible sample marker + source tag). Structure ships; the user fills the
facts.

A page with no proof region at all — no testimonial, no logo, no outcome, no `{{metric:*}}`
— is a finding, whether it was dropped by oversight or on principle.

Two failure modes sit on the far side of that fix, both owned by `content-depth.md`: the
**disclosure stack** (a chip AND a banner AND a confessional lede AND a headline addressed to the
operator, so the region announces four times that it is unfinished) and the **empty placeholder
grid** (a logo slot shipped as dashed tiles because no plausible sample value exists for it —
cut that sub-block, keep the region). Getting proof back on the page is not enough; it has to
read as proof.

## Part 5 — Page length is a declared decision

Plenty of landing pages are SUPPOSED to be a long scroll — a considered purchase, a technical
buyer, a category the reader does not know yet. Length is legitimate; unplanned length is not. So
the deliverable scope declares one:

| Length | Shape | Typical use |
| --- | --- | --- |
| `standard` | the archetype's `content-depth.md` anchors as written | most briefs |
| `long-scroll` | anchors are a FLOOR; sections may run well past the range | considered purchase, unfamiliar category, technical buyer who reads everything |

`long-scroll` scales the depth budget — it does not relax any other rule, and it adds four of its
own, because the failure modes of a long page are not the failure modes of a short one:

- **Spine-early.** Every offer-spine slot owes its FIRST answer inside roughly the opening third
  of the page. Depth after that is elaboration, not first mention. A visitor must never scroll
  eight screens to discover the price, the audience, or what the thing is; a long page that
  back-loads the spine reads as evasive, not thorough.
- **CTA cadence.** The primary action repeats through the scroll — as a rule of thumb every few
  sections, always the SAME verb — so intent can convert wherever it forms. One CTA at the top
  and one at the bottom of a twenty-section page wastes the middle.
- **Shape variety.** No long run of consecutive sections sharing one layout archetype. Twenty
  stacked text-left/figure-right blocks is where long scroll actually dies, and it is a
  content-depth failure (`anchors are not a template`) showing up at length.
- **Wayfinding + cost.** Past roughly eight sections the page owes an in-page affordance —
  anchor nav, progress, or section index — and every instrument below the fold mounts lazily.
  The cumulative motion budget is per PAGE, not per section: thirty reveal observers are cheap,
  thirty eager instruments are not (`motion-tiers/references/tier-budgets.md`).

An undeclared long page is a finding the same way an undeclared second product is: not because
long is wrong, but because nobody decided it.

## Part 6 — One-shot or guided

A `one-shot` run generates the whole page from the contract and the concept, and
the user first sees it finished. That is the right mode for a small page, a
re-run, or a headless invocation — and it is the mode in which a misread brief
survives the entire build.

A `guided` run decides the page section by section with the user before it is
built: the spine slots become a batched decision agenda, each section is offered
as two or three structurally different treatments, and the picks land in a ledger
the build and the audit both read. Owned by the `section-decisions` skill and
runnable standalone as `/craft-layer:sections`.

Declare `guided` when the brief is broad or ambiguous, when the page is the whole
deliverable rather than one screen among many, or when the user asked for options.
Declare it in the same prompt as the rest of the contract — it is a scope
decision, not a separate ceremony. The mode is also the honest answer to "I am not
sure what I want yet": guided costs a handful of exchanges and removes the risk
that forty minutes of building answers the wrong question.

`guided` changes nothing else in this contract. Every rule in Parts 1–5 still
holds; the user is choosing between options that already satisfy them.

## What the audit checks (teeth)

`/craft-layer:audit` reads THIS file (injected as a Read path) and verifies:

- a deliverable-scope block exists and the shipped route list MATCHES it;
- exactly ONE product identity across the shipped routes;
- the real product name appears in `<title>` and the hero;
- every offer-spine slot is answered on each marketing page — grep for a plain-language
  what-line, an audience phrase, a step sequence, price or `{{price:*}}`, a proof region,
  an objection/limits block, and one repeated primary-CTA verb;
- the plain-what line is checked AGAINST the divergence record's metaphor vocabulary, not by
  taste — an h1 built from the metaphor and naming no capability is a finding;
- a proof region EXISTS (slotted per Part 4) rather than being absent;
- on a `guided` run, a section ledger exists and the built page conforms to it
  (`section-decisions/references/section-ledger.md` owns that check);
- the declared LENGTH matches what shipped, and on `long-scroll`: every spine slot answered
  first within roughly the opening third, the primary CTA recurring through the scroll on one
  verb, no long run of identically-shaped sections, an in-page wayfinding affordance past
  ~8 sections, and below-fold instruments mounting lazily against the per-page motion budget.

Each miss is one finding naming the slot it belongs to. The gate checks PRESENCE, never
taste.

## Anti-patterns

- **Spec sheet as sales page** — full method disclosure with no plain-language what, no
  named audience, no price, no CTA.
- **Metaphor as brand** — the concept's nickname replaces the product's real name.
- **Two products, one site** — options presented, then all of them built.
- **Kit page as a route** — the design-system showcase mounted in the product nav.
- **Proof deleted for honesty** — fabrication avoided by removing the region instead of
  shipping a slot.
- **Aphorism as headline** — a line that could head any product in the category standing where
  the plain-language what belongs.
- **Back-loaded spine** — a long page that makes the reader scroll past the fold-count to find
  what it is, who it is for, or what it costs.
- **Scroll as sprawl** — length nobody declared, reached by repeating one section shape until
  the page feels substantial.
- **Contract as template** — reading the slot table as a fixed section order; the concept
  decides form, the contract decides what must be answered.
