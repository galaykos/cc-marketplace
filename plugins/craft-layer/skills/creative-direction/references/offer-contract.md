# Offer contract — what the build SELLS, pinned before what it looks like

A craft build can clear every motion, contrast, and depth gate and still fail the job it
was commissioned for: a visitor cannot tell what the product is, who it is for, what it
costs, or what happens when they click. The concept decides how a page FEELS; this
contract decides what it has to SELL. Pinned at the start of `/craft-layer:craft`, before
the creative-director agent runs, and threaded into both `design-research` briefs.

Like the archetype dials, this is a set of SLOTS to fill — never a layout, never a section
order.

## Part 1 — Deliverable scope (pin before writing a file)

Resolve every row below, echo them to the user, then build:

| Field | Must resolve to |
| --- | --- |
| Raw brief | the user's request in their OWN words, verbatim — the line an upgrade sharpens and never replaces |
| Upgraded brief | the sharpened objective, the constraints the brief IMPLIES but never states, and what it left UNDECIDED — see Part 1a |
| Product | ONE product, under its REAL name |
| Audience | who is buying, in a phrase |
| Archetype | the work-type archetype classified from `archetypes.md` — it keys the content-depth anchors the audit counts against, so it must persist with the rest |
| Primary action | the ONE thing a visitor should do (book a demo, start a trial, contact) |
| Routes | the exact page/route list that ships |
| Route horizon | routes the site is KNOWN to be getting later, named and not built — see Part 7 |
| Length | `standard` or `long-scroll` — see Part 5 |
| Mode | `one-shot` or `guided` — see Part 6 |
| Ambition | `restrained`, `standard`, or `maximal` — see Part 7 and `ambition-tiers.md` |
| Boost | `ultra-craft` or `none` — see Part 7; a boost that was only spoken cannot be checked |
| Not shipping | what was considered and cut |

**One product per build.** When the brief admits several products, positionings, or
directions, ASK which one. Presenting options and then building all of them is a finding,
not a compromise: the visitor has to self-route before they know what either product is,
and each page's proof, pricing, and CTA get half the room they need.

**Internal artifacts are not routes.** A token/kit/design-system showcase is a useful build
artifact; it ships as a site route only when the user asked for one. Mounted in the product
nav it reads as an unfinished demo.

## Part 1a — The brief pair, and marking what was inferred

Before any row above is pinned, the raw brief is UPGRADED — and the upgrade is echoed with
the contract and persisted inside it, in this shape:

```
Raw brief: <the user's request, verbatim>
Upgraded brief:
  Objective: <the same job, said precisely>
  Implies: <constraints the brief entails but never states>
  Undecided: <the calls it leaves open for someone else to make>
Ambition: maximal (inferred ← "make it pop")
Mode: one-shot (inferred ← no mode words in the brief)
Audience: logistics ops leads
```

Four rules bind it:

- **Sharpen, never replace.** The upgrade says the user's job precisely; it does not widen
  the scope, swap the product, or add a route nobody asked for. Where the sharpened reading
  and the raw line disagree, the raw line wins.
- **Marked means inferred.** A row the user stated is written plain — `Audience` above. A row
  the run DERIVED carries `(inferred ← <the phrase or signal>)`, so the basis travels with the
  value. Mode, ambition, boost, archetype, palette mood, type strategy, stack, motion tier and
  content depth are the rows this most often applies to.
- **A readout, not a question.** The pair is shown, not asked about; it costs a `one-shot` run
  no exchange. The user corrects it if it is wrong, at the moment correcting it is cheap.
- **Persisted, not just spoken.** Both the pair and every mark are written into
  `craft/offer-contract.md` with the rest of the rows. A mark that lives only in the echo
  evaporates with the transcript, and a mis-inferred row then propagates through the whole
  build unchallenged.

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
uninformative while being dense. It is also what a run reaches for when it could not get
the real copy: unable to fetch the client's own marketing page, it fills every slot with
the neutral infrastructure facts it does have. Locating the copy is the fix, and
`content-source.md` owns it — including the observation that a client's published risk
warning or disclaimer usually answers the **objection** slot better than anything this
build would write, which is why those blocks reproduce in full rather than being trimmed.

**Checking the REGISTER mechanically — presence is not the same as answered.** A slot can be
answered and still fail, because the paragraph above is a rule nothing greped for. A build
answered all eight slots in an INTEGRATOR's voice — `POST /api/task` for what it is, a bearer
token scope for who it is for, a `workspace_id` global scope for why change — and would have
passed this gate green while reading as API documentation to the buyer it was commissioned for.

The fix is scoped, never a whole-page jargon grep: a page owes `how it works` and `objection`
their spec detail, and firing on a correct limits list would teach builds to strip the very
concreteness this contract asks for. So the check needs to know WHICH region answers WHICH
slot, and `register-corpus.md` owns all three parts of it — the slot → region mapping carried
on the build task's `Spine regions:` line (written at every tier, so a `one-shot` run produces
it with no ledger), the corpus of register markers, and the `spine-register` assertion in
`template/craft-gates/divergence.mjs` that reads both. Only **plain-what**, **audience** and
**problem** are graded; the other five slots are unchecked by construction. Density is not the
defect — a buyer's question answered with an integrator's fact is.

**Checking "plain-language" mechanically.** Whether a sentence is plain reads like taste, but the
concept makes it testable: the divergence record names the central METAPHOR, so that metaphor's
own vocabulary is the thing the plain-what line may not be built from.

This only works if the record still EXISTS at audit time. The creative-director agent returns it
and writes no files, so the craft flow must persist it — alongside the pinned contract, never in
the shipped tree — and inject it into the audit. **Fixed names, so a later session can find them
without being told:** in a `craft/` directory under the run's working area (the taskmaster docs
area when the project has one, otherwise the session scratch area), as
`craft/offer-contract.md`, `craft/divergence-record.md`, `craft/content-source.md`,
`craft/build-task.md`, `craft/section-ledger.md`, and `craft/reference-board.md`. The last two
are conditional — a ledger on a `guided` run, a board at the `ultra-craft` boost — but every
one of the six is a first-class stamped artifact under Part 8, and `craft/build-task.md` is
read by `divergence.mjs` directly. The audit
globs for `**/craft/offer-contract.md` and its siblings; a persistence rule with no filename is
the same as no persistence at all. Fixed names are also collidable names — a second run in one
session writes the same paths — so each artifact carries the RUN STAMP that tells the runs
apart, and the tiebreak for a glob that matches more than one is Part 8. An audit with no
contract and no record cannot run these checks and must SAY so rather than pass silently; a
gate that quietly no-ops is worse than an absent one.

With the record in hand, take the metaphor's terms (and their obvious cognates), then check the
h1 and the sentence under it:

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

**`one-shot` is the default** when the user names no mode. `guided` is entered by saying so —
"guided", "section by section", "give me options", "ask me as you go" anywhere in the request,
or by running `/craft-layer:sections`. There is no flag to memorize; the mode is pinned in the
contract like every other row, and echoed back with it.

A `one-shot` run generates the whole page from the contract and the concept with
exactly ONE exchange carved out: the CONCEPT FORK. Before any artifact is
persisted, the run presents 2–3 concept candidates — each a deck draw, a central
metaphor, an editorial voice and one signature move — and the user picks the one
the build runs on. **That one exchange also carries the CONTENT-SOURCE question** —
does copy for this page already exist? — as a second question inside the same
`AskUserQuestion` call, never a second call, because the exchange is already open
and it is the cheapest question in the flow (`content-source.md` owns the rules and
the `source: none-located` default). ONE exchange, two questions; the cap does not
move. Everything else about `one-shot` is unchanged: no section
rounds, no per-treatment questions, no colour-by-colour approval; after the fork
the page arrives finished. The fork binds at every tier, this one included,
because the concept is the single decision a whole build inherits — and a
headless or unanswered run auto-picks, so the mode stays genuinely unattended.
That keeps `one-shot` right for a small page, a re-run, or a headless
invocation — and it is still the mode in which a misread brief survives the
entire build.

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

## Part 7 — Ambition, and the routes that are not here yet

Two rows that exist because a build kept answering a question the contract could not hold.

**Ambition** pins how far the page must REACH — `restrained`, `standard` (the default when
the user says nothing either way), or `maximal` when the brief asks for reach in any words.
The tiers, the pinning vocabulary, the four reach floors `maximal` adds, and the ceilings
that never move regardless are owned by `ambition-tiers.md`. Pin it here, echo it with the
rest, and persist it: a quality bar carried only as prose in a scope line binds nothing, and
"award winning" in the brief with no slot to land in is exactly how a build clears every gate
it has while ignoring what it was asked for.

**Boost** records whether the run was explicitly boosted with `ultra-craft`. Ambition is
what the OUTPUT owes; the boost is how hard the PIPELINE worked to get there — live dated
research, a reference board the user confirmed before tokens existed, guided section rounds,
escalated concept and review tiers, a red-team of the shipped tree. `craft-layer:ultra-craft`
owns the contract; a boosted run pins `Ambition: maximal` and `Mode: guided` rather than
reading them, so the three rows move together and only this one records WHY. `none` is the
default and the common answer.

**Route horizon** is the honest form of "this is the front door, not a landing page".
`Routes` stays what SHIPS this run — the audit checks the shipped list against it, and that
check only works if the list is exact. The horizon holds routes the site is known to be
getting later (contact, knowledge base, FAQ, changelog, careers) which are NOT being built
now. It changes no gate; it changes the BUILD, because a page designed as a terminal
single-purpose landing page and a page designed as a front door with siblings coming are
different structures — nav, footer, and how much a section tries to carry all differ. A
horizon nobody recorded means the build optimises for the wrong one and gets rebuilt.

An empty horizon is a valid answer and the common one. Naming a route in the horizon and
then shipping it is a scope finding like any other; naming one and stubbing it into the nav
as a dead link is worse.

## Part 8 — The run stamp, so a second run cannot inherit the first's artifacts

The fixed names in Part 3 are what make these files findable without being told. They are
also what makes them COLLIDABLE: a second craft run in the same session writes the same
paths, and a run that stopped early leaves its artifacts sitting exactly where the next
audit globs. That has happened — a previous run's contract was read as the current run's,
and a person caught it rather than a gate. Per-run SUBDIRECTORIES are not the fix; they
would break the fixed-name rule above and the fixed-depth resolution in
`template/craft-gates/divergence.mjs`, which would then find no contract and no record and
switch two live assertions off in silence.

So every artifact in `craft/` opens with a RUN STAMP — the first line under the title,
above every other row:

```
Run: 2026-07-26T14:32Z · clickinator · /Users/dev/src/clickinator-craft-test
```

Three fields, in this order, on one line beginning `Run:`, separated by ` · ` (space,
middle dot, space):

| Field | Shape | Why it is there |
| --- | --- | --- |
| Run instant | ISO-8601 UTC to the MINUTE — `YYYY-MM-DDTHH:MMZ` | a date alone cannot separate two runs in one session, which is the failing case |
| Product slug | the contract's product name, lowercased, non-alphanumerics collapsed to `-` | names the run in a form a reader recognises at a glance |
| Target project root | the ABSOLUTE path of the project being built | the only field that can prove an artifact belongs to THIS target |

The stamp is computed ONCE, at step 0, and copied BYTE-IDENTICAL onto every artifact the
run persists — contract, divergence record, content source, build task, section ledger,
reference board. Identical is the whole mechanism: two artifacts belong to the same run if
and only if their stamps match exactly, so re-reading the clock per file defeats it. `Run:`
is deliberately not a deck-axis name and not `Brand echo:` — the same key-collision rule
`concept-deck.md` states for the negative-constraints block applies here, because the
divergence gate parses every `Key: value` line of the record it reads.

### The tiebreak, when the glob returns more than one

`**/craft/offer-contract.md` can match several files at once: a session-scratch copy and a
taskmaster-docs copy, an abandoned run's leftovers, a sibling project vendored into the
tree. One rule resolves it, with two consumers — the audit's glob and `divergence.mjs`'s
`craft-stamp` assertion — and it never ends in a silent pick:

1. **A different project is not a candidate.** Drop every match whose third stamp field is
   not the project being audited. A filter, not a tie: an artifact stamped to another
   project is evidence of nothing here, and it is the exact shape the collision took.
2. **One candidate left → it wins.**
3. **Several left → the strictly NEWEST run instant wins**, and only when the run's other
   artifacts carry that same stamp. A newest contract beside a build task from the previous
   run is not a resolution; it is the stale-artifact case this part exists to catch.
4. **Anything else is UNDECIDABLE, and undecidable is REPORTED** — two candidates sharing
   one instant, one candidate stamped while another is not, sibling artifacts disagreeing.
   The audit reports `not checked (ambiguous craft artifacts: <n> matched — <path> <stamp>,
   …)`, lists every candidate with its stamp, and grades nothing from any of them. Same
   standing as every other missing input: never a pass, never a fail, and never a silent
   pick of whichever the glob happened to return first.
5. **Exactly one candidate carrying NO stamp** is used and reported as
   `stamp absent (pre-stamp artifact) — not attributable to this run`. Runs that predate
   this rule wrote none, and refusing to read their artifacts would break every project
   that has one.

Two artifacts of one run whose stamps DISAGREE are a finding in their own right: one of
them was left by an earlier run, and every gate reading it is grading this build against
another run's decisions. Detectable rather than merely unlikely is the point —
`divergence.mjs`'s `craft-stamp` assertion checks stamp agreement across the contract, the
divergence record, the build task and the content source on every audit, and fails when
they disagree, when one is stamped to another project, or when one carries no stamp while a
sibling does. Steps 1 and 3's agreement clause are therefore SCRIPTED; picking between
several glob matches spread across directories is graded by the audit reading this list.

## What the audit checks (teeth)

`/craft-layer:audit` reads THIS file (injected as a Read path) and verifies:

- the artifacts it graded are THIS run's — every glob match is resolved by the Part 8 stamp
  (a match stamped to another project is dropped, the newest agreeing stamp wins, an
  undecidable set is reported with every candidate and its stamp and grades nothing), and
  artifacts whose stamps disagree are one finding naming the file left over from the earlier
  run. `divergence.mjs`'s `craft-stamp` assertion carries the scripted half; no stamp on any
  artifact → `not checked`, never a pass;
- a deliverable-scope block exists and the shipped route list MATCHES it;
- exactly ONE product identity across the shipped routes;
- the real product name appears in `<title>` and the hero;
- every offer-spine slot is answered on each marketing page — grep for a plain-language
  what-line, an audience phrase, a step sequence, price or `{{price:*}}`, a proof region,
  an objection/limits block, and one repeated primary-CTA verb;
- the plain-what line is checked AGAINST the divergence record's metaphor vocabulary, not by
  taste — an h1 built from the metaphor and naming no capability is a finding;
- the three BUYER slots — plain-what, audience, problem — are checked against the REGISTER
  corpus, scoped by the build task's `Spine regions:` mapping. This one is SCRIPTED, not
  agent-graded: `divergence.mjs`'s `spine-register` assertion, exit 1 on a hit, waivable in
  `.craft-layer/waivers.json`. No `Spine regions:` line, or no mapped anchor in the tree →
  `not checked`, never a pass. Method disclosure inside `how it works` and `objection` is
  legal and is not checked there (`register-corpus.md`);
- a proof region EXISTS (slotted per Part 4) rather than being absent;
- ledger conformance is NOT checked here — `section-decisions/references/section-ledger.md`
  owns it, and skips entirely when no ledger exists (a one-shot build is not a finding);
- the declared AMBITION is honored — at `maximal`, the four reach floors in
  `ambition-tiers.md` (three distinct motion CAPABILITIES — a tier or a sibling engine, each
  counted once, never three tiers — one authored graphic system, an asset
  posture that is not all-first-party-emptiness, and one surface whose `Motion:` entry carries
  `(escalated ← <reason>)` off the cheapest tier that fit it), each waivable only by a reasoned
  entry in the divergence record. No ambition row → `not checked`, never a pass and never a fail;
- the declared BOOST left its evidence — at `ultra-craft`, a `craft/reference-board.md`
  carrying dated fetched sources, a section ledger (guided was binding, so its absence is a
  miss rather than a one-shot), and a red-team record naming what it attacked. No boost row
  or `none` → `not checked`;
- no route in the ROUTE HORIZON shipped as a dead nav link — the horizon names what is
  coming, and a stub in the nav is a broken promise rather than a preview;
- when a `craft/content-source.md` exists, the INGESTED COPY was reproduced rather than
  rewritten — claims, prices, tier and product names verbatim, legal blocks in full and not
  behind an interaction, every gaps-table row shipped as a visible `{{lorem}}` rather than as
  invented copy, and every source row's fetch date inside the declared staleness window
  (`content-source.md` owns the rules). No artifact → `not checked`;
- the declared LENGTH matches what shipped, and on `long-scroll`: every spine slot answered
  first within roughly the opening third, the primary CTA recurring through the scroll on one
  verb, no long run of identically-shaped sections, an in-page wayfinding affordance past
  ~8 sections, and below-fold instruments mounting lazily against the per-page motion budget.

Each miss is one finding naming the slot it belongs to. The gate checks PRESENCE, never
taste.

## Anti-patterns

- **Spec sheet as sales page** — full method disclosure with no plain-language what, no
  named audience, no price, no CTA.
- **Every slot answered, in the wrong register** — the harder version of the one above, and
  the one that passes a presence gate: each slot IS answered, and each is answered for
  whoever will call the API. Graded by `spine-register` (`register-corpus.md`).
- **Copy invented where copy existed** — the client's published page went unfetched or
  unasked-for, so the slots were filled from the product's spec facts. The anti-pattern
  above, with its most common cause.
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
- **Ambition in the prose, not the slot** — "award winning" echoed in the scope sentence and
  pinned to no row; it reaches nothing, checks nothing, and the build under-delivers against
  a bar it was told.
- **Horizon in the nav** — routes named as coming later, then stubbed into the navigation as
  dead links so the page looks fuller.
- **Contract as template** — reading the slot table as a fixed section order; the concept
  decides form, the contract decides what must be answered.
- **Last run's contract, this run's audit** — a second run in one session landing on the
  first run's artifacts at the same fixed paths, and every gate grading a build against
  decisions taken for a different product. Unstamped, it is invisible until someone reads
  the file.
