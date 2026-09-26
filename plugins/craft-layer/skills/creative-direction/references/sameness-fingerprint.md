# Sameness fingerprint — the anti-corpus registry

This registry is the source-of-truth of what craft builds have OVERUSED — the recurring
spine, the recurring component vocabulary, and the recent palette hues. The
creative-director agent must make its concept DIVERGE from this, and the audit fails a
build that matches it with no justified departure.

**Anti-corpus exception (binding).** Naming specific components and hues HERE is
cataloguing what to diverge FROM — the opposite of prescribing them. This file is exempt
from the kill-trigger / "no deliverable names a specific colour/component" rule, which
targets PRESCRIBING a colour/component as the design, never cataloguing overused ones.

## The registry

Refreshed **on each craft-layer release** (a deliberate registry, not auto-derived — an
auto-derived fingerprint rots and drifts silently). Recency window: **last 3 releases /
last 5 palettes**. Seeded and refreshed from evidence gathered across craft-layer releases.

### Recurring spine (overused section order)
- hero → logo/trust marquee → stat/bento block → feature grid → "how it works" →
  magnetic CTA. A build that reproduces this order end-to-end has diverged on nothing
  structural.
- **The category-default spine** (a second spine, and it retires differently — see the
  category-default note below): centred hero with one large headline, a subhead and two
  buttons → a three-column feature grid → a logo wall → a testimonial carousel → a
  pricing table → a repeated CTA → a four-column footer. This is the order generated
  marketing pages converge on, and it is recognised faster than any individual component
  on it. Reproducing it in order is the structural tell even when every component is
  restyled. Evidence for this specific ordering is 2026 teardown reporting whose sources
  echo each other, so treat the ORDER as the durable finding and any accompanying
  statistic as unverified.

### Recurring component vocabulary (overused signature moves)
- kinetic variable-weight headline
- rotating-word / phrase cross-fade slot
- magnetic CTA button
- tilt-on-hover cards
- the glass-card grid — backdrop-blur translucent cards with hairline white/10 borders as
  the default card treatment. A category default like the violet gradient (see the
  category-default note below): it retires on category movement, not on the recency window.
- logo marquee
- scroll-driven bento/stat reveal
- default stock imagery (the generic stock-photo hero — imagery chosen off-the-shelf, not art-directed)
- default icon set (an untouched off-the-shelf icon pack — no consistency or metaphor choice made)
- emoji standing in for the icon system — pictographs (🚀 ⚡ 🔒 ✨) as feature and section
  icons because no icon decision was made at all; the single fastest visual identifier of a
  generated page. A category default (see the note below), and the vocabulary entry with a
  mechanical check: the `emoji-as-icon` assertion in `template/craft-gates/divergence.mjs`.
- oversized-type hero as the default opening — type standing in for a hero image because it
  is the current default, not because the brief earned a typographic hero
- WebGL floating-objects / cursor-reactive background — an ambient 3D layer that carries no
  argument (distinct from a 3D surface the concept actually needs)
- scrollytelling as the default page STRUCTURE — scroll driving the sequence because that is
  what pages do now, rather than because the sequence is the argument
- the generated-web composition: gradient hero + one geometric sans + a four-card grid
- **the data-artefact hero** — a chart, plot or board that depicts no screen the product
  has, standing in as the hero image. It is where a build lands when it cannot commission
  imagery, so it arrives by default rather than by argument. Two consecutive craft-layer
  builds reached it independently, which is what put it on this list. A brief that genuinely
  sells its data has earned it; a brief that simply had no other option has not, and should
  say so in the divergence record rather than claiming it as a departure.
  **Split 2026-09-26 — the interface specimen is NOT this entry.** When the product IS a
  screen (a console, an app, a CRM), its own UI on the front door is the category's PROOF
  CONVENTION: the audience checks for the real product before anything else, and the design
  corpus refresh found it leading a third to two-fifths of infrastructure and business-software
  front doors, strongest tier included (counts and sites: `rationale/2026-09-25-design-capability-corpus/`).
  Diverging from it pushes those briefs off the one premium hero the flow can build in code.
  The divergence moves to its EXECUTION: the generic executions are catalogued under
  Category-default chrome below, and `moves-taxonomy.md` carries the category.
- (a build leaning only on these has no brief-specific signature move)

### Type families the category defaults to (avoid unless argued for)
- the neutral geometric/grotesque UI sans that generated pages reach for first — Inter and
  Geist by name, and any face chosen because it is what a starter template shipped with.
  Naming them here is the anti-corpus exception above: they are catalogued as defaults to
  DIVERGE from, never as a recommendation, and they remain perfectly good typefaces that a
  brief may still argue for on the merits.
- the two-family serif-display-over-grotesque-text pairing, when it is reached for as the
  house move rather than derived. This is a SHAPE, not a family: a build can diverge on
  both families and still be repeating the pairing strategy.
- **the per-script default face — `Noto Sans <script>` and its siblings.** Everything above
  this line is Latin, and that was the whole gap: a Hebrew build shipped Noto Sans Hebrew and
  cleared the check, because Inter's ROLE in a non-Latin script is played by a different name.
  Noto is Google's universal-coverage fallback set — what an unstyled page renders in, what
  the CLI installs, and what gets named when a brief asks for "a font that supports" a script.
  It is chosen by not choosing, which is the definition this section uses. Enforced as a
  PATTERN in `template/craft-gates/divergence.mjs` rather than as rows here, because a list
  would need one entry per writing system and would be wrong the day one was missing. For
  some scripts the quality alternatives are genuinely few — waive it with that reason, and
  the waiver is the argument this section asks for.
- `type-strategy.md` reads this list the way `palette-strategy.md` reads the hues below.

### Recent palette hues (avoid repeating)
- editorial lime (light)
- navy + gold (dark)
- aubergine + coral/apricot + mint (dark)
- purple/violet gradient — see the category-default note below
- **warm cream + high-contrast serif + terracotta/clay accent** (light; the cream near
  `#F4F1EA`, the accent near `#D97757`) — a category default, and a doubly bad one on a
  client brief: that accent is Anthropic's own Claude-interaction colour, so the page
  reads as "the model's house style" rather than the client's. Entered 2026-09-03 from
  the official `frontend-design` skill's calibration list.
- **near-black + one acid-green or vermilion accent** (dark) — the other category
  default the same source names; same standing, same entry date.
- **tinted-navy near-black + a radial blue glow + a dotted grid** (dark), often with a
  diagonal light beam — the developer-infrastructure category default. Entered 2026-09-26
  from the design corpus: about a third of that group's dark heroes sit on it, stacked on the
  weaker pages, while the group's strongest front doors are mostly light. Agent-graded — the
  hue band in `divergence.mjs` covers violet, not this.

### Category-default chrome (the small tells)

Template furniture that appears whatever the subject. None of these is wrong; each is
a default reached for without a decision, and a reader identifies three of them together
as generated faster than any palette. Catalogued to DIVERGE from, per the anti-corpus
exception; the craft-reviewer reads shipped markup against this list:

- a tracked-out ALL-CAPS eyebrow label above every heading
- meta strings joined with middle dots (`A · B · C`) and labels shaped `WORD — fragment`
- one word of a headline accented by a gradient fill, or accented at all while stacked with a
  "New" pill above it and an underline or glow on it. **Narrowed 2026-09-26:** about a fifth
  of the corpus's business-software heroes accent a word, its premium tier included, so
  presence is not the tell — execution is. A tonal step, a weight or classification swap, or
  the product's own UI set into the line reads argued; the gradient and the stack read
  generated. An italic accent word still owes its argument: the playbook row below names it.
- numbered markers (`01 / 02 / 03`) on content that is not a sequence
- `→` appended to every link and button label
- a monospace face for small data labels with no data argument
- pill-shaped (fully rounded) buttons as the one button silhouette, with no radius
  argument — the Opus 5.5 playbook (claude.dev, 2026-09-22) names it beside the cream
  background, the italic accent word, the `01 / 02 / 03` labels and the monospace label
  as the five defaults a model falls back on with no direction; four were already here
- tinted near-black (`#0B0B0B`, `#111`) standing in for black
- identical rounded cards with one border-radius for every hierarchy level and the same
  soft grey shadow (`rgba(0,0,0,.1)`) under each — the SaaS card kit
- a broadsheet layout: hairline rules, zero radius, dense newspaper columns, on a
  subject that is not editorial
- fade-and-slide-up entrance on every section plus a hover transition on every card —
  scattered motion where one orchestrated moment would land (`motion-tiers.md` owns the
  budget; this row only names the default)

Source: the official `frontend-design` skill's calibration list, 2026-09-03, cross-checked
against the vocabulary above so nothing is listed twice. Standing: **agent-graded for the
list, `gate` for three rows.** The eyebrow, the middle-dot meta string and the trailing
arrow are mechanical, and since 0.16.0 they ride the `copy-register` assertion in
`template/craft-gates/divergence.mjs` through the lexicon block below — read LIVE from this
file. Every other row here is the craft-reviewer reading shipped markup, and no script fails
a build over it.

**Added 2026-09-26 from the design corpus** (1,530 scanned sites; counts and sites stay in
`rationale/2026-09-25-design-capability-corpus/`). Each is a default the corpus found stacked
on its weaker pages and absent from its strongest. Agent-graded, like the rows above:

- the interface specimen's generic execution — a traffic-light browser frame as the default
  wrapper, floating toast chips over it, a glow puddle under it, a tilted perspective on the
  data, lorem or "Project 1" rows, an upscaled raster screenshot. The argued execution is a
  crisp specimen built from the product's own components, fictional-but-specific data
  (`content-depth.md`'s mock carve-out), fixed polarity, cropped with intent — execution
  rules in `plugins/craft-layer/skills/information-design/references/product-mock.md`
- an announcement chip ("New", "Introducing X ›") or a rating/award badge row above the
  headline, carrying no real news
- floating stat tiles with no referent — a figure with no source, period or subject
- AI signified only by a sparkle glyph, an orb or a glow, where the product could show a
  receipt instead: a run log, a status chip, an outcome
- support signified by headset stock photography
- (the don't-repeat-recent nudge in `palette-strategy.md` reads this list)

### Recurring copy register (category default)

The copy half of the fingerprint: the machine-copy lexicon a reader identifies as
generated in one line, the way the violet gradient is identified in one glance.
Catalogued to DIVERGE from, per the anti-corpus exception above — a build leaning on
these has authored nothing:

- the supercharge / seamlessly / unlock / elevate / empower / effortless verb family
- the three-adjective fragment headline — "Effortless. Powerful. Secure."
- "Take X to the next level"
- "not just X, it's Y"
- "game-changing" / "revolutionary" intensifiers
- the "for humans and agents" formula, and a headline that is just "Agentic ___" — entered
  2026-09-26: a quarter of the corpus's infrastructure sites name agents in their title or
  meta, against a sixth corpus-wide, and the formula repeats verbatim across them
- the registry headline "UI library for design engineers" — entered 2026-09-26: component
  registries lead with it word for word, over the category-default spine's centred pill and
  two buttons

A category default, so it ages on category movement, never the recency window. Standing:
agent-graded — the craft-reviewer reads shipped copy against this list — and, where the
phrase list is mechanical, gated: the `copy-register` assertion in
`template/craft-gates/divergence.mjs` flags the multi-word phrases only, so a lone
"seamless" in honest copy never fires.

### The copy lexicon, as the gate reads it

`divergence.mjs`'s `copy-register` assertion reads THIS block when `CLAUDE_PLUGIN_ROOT` is
set and falls back to a frozen snapshot otherwise, printing which one it used and its date
on every run — the same contract as `register-corpus.md`. It is the mechanical subset of the
two sections above: the multi-word phrases from the copy register, plus the three
category-default chrome rows a machine can see. The last three rows are the 2026-09-26 corpus
entries; the `agentic headline` row matches only a WHOLE copy chunk of at most six words
starting "Agentic", so a sentence using the word in running text never fires, and a nav item
or card title reading "Agentic X" does — waive that with its reason.

<!-- copy-lexicon:start -->
```
supercharge your :: gi :: 1 :: \bsupercharge\s+your\b
seamlessly integrate :: gi :: 1 :: \bseamlessly\s+integrat\w*
take your * to the next level :: gi :: 1 :: \btake\s+your\s+[^<>.!?]{0,60}?to\s+the\s+next\s+level\b
effortless. powerful. :: gi :: 1 :: \beffortless\.\s*powerful\.
unlock the power :: gi :: 1 :: \bunlock\s+the\s+power\b
game-changing :: gi :: 1 :: \bgame-chang(?:ing|ers?)\b
all-caps eyebrow :: g :: 3 :: ^\s*[A-Z][A-Z0-9&'’]*(?:\s+[A-Z0-9&'’]+){1,4}\s*$
middle-dot meta string :: g :: 1 :: ·[^·\n]{1,60}·
trailing arrow :: g :: 3 :: [^→\n]{0,40}[^\s→]\s*→\s*$
for humans and agents :: gi :: 1 :: \bfor\s+(?:both\s+)?(?:humans\s+and\s+(?:ai\s+)?agents|(?:ai\s+)?agents\s+and\s+humans)\b
agentic headline :: gi :: 1 :: ^\s*(?:the\s+)?agentic\s+[\w'’-]+(?:\s+[\w'’-]+){0,4}\s*[.!]?\s*$
for design engineers :: gi :: 1 :: \b(?:ui\s+library|components?)\s+for\s+design\s+engineers\b
```
<!-- copy-lexicon:end -->

Format: `label :: flags :: min :: pattern`, one per line, JavaScript regular-expression
source, matched against reader-visible copy one text chunk at a time. A pattern that will
not compile is reported and DROPPED rather than silently ignored.

**`min` is why the three chrome rows do not fire on honest pages.** Their registry entries
say "above EVERY heading" and "appended to EVERY link" — repetition is the tell, and one
`Read more →` is a choice. So the eyebrow and the arrow need **three** distinct chunks
before either is a finding, while a meta string needs two middle dots in ONE chunk (`A · B · C`)
because a single ` · ` between a copyright line and a phone number is the shape every real
footer ships. A row that fires on correct pages is waived into silence within one run, which
is the anti-pattern `register-corpus.md` names.

**Declared limits.** The eyebrow row sees ALL-CAPS text, not letter-spacing, so an eyebrow
set in small-caps or `text-transform: uppercase` over mixed-case source is invisible here —
that half stays the craft-reviewer's. Three all-caps labels that are not eyebrows (a
data-table header row rendered as text) fire it, and the waiver lane is the answer. The
arrow row reads `→` only, never an SVG chevron or an `::after` pseudo-element.

### Two sources of sameness, and they age differently

Most entries above are SELF-repetition: what craft-layer itself has produced lately, retired
by the recency window.

The last hue and the last vocabulary entry are a CATEGORY default instead — the look generated
pages converged on, which readers now identify as machine-made in about a second. It arises
from a feedback loop rather than from this plugin: the web holds far more generic pages than
distinctive ones, models reproduce the most frequent pattern, that output returns to the web,
and the next model trains on it. A category default does NOT retire on the recency window. It
leaves the registry when the category moves, which is a judgement made at refresh time.

The practical consequence for the concept: landing in the category default is worse than
landing in a merely conventional design, because it reads as unauthored rather than as
restrained. The escape hatch still applies — an explicitly requested conventional design is a
valid justification — but "conventional" and "generated-looking" are not the same request.

## How divergence is measured (agent-graded, over a scripted floor)

**Standing: `agent-graded`.** The K count, the different-axes rule and both failure
conditions below are read and judged by `/craft-layer:audit`; no assertion in
`template/craft-gates/divergence.mjs` counts departures or reads the divergence record's
entries. What IS scripted is a floor under the registry, not this section: the type-family
and copy-register lists above are loaded LIVE from this file, and the hue band, the repeat
window, emoji-as-icon and the utility-layer palette/font are encoded in the script. A build
can clear every one of those and still reproduce the spine end-to-end — which is exactly
what the judgement below exists to catch, and exactly why calling it teeth was wrong.

The creative-director agent returns a **divergence record**: for each departure,
{ fingerprint axis (spine / a named vocabulary move / recent hue) · the entry it replaces ·
the brief reason }. **K — how many defaults a concept must break — SCALES WITH THE PINNED
AMBITION: `restrained` 1, `standard` 2, `maximal` 3.** A flat floor of one let a single
departure discharge the whole gate however far the brief asked the build to reach.

The departures must land on **different fingerprint axes** — the spine, a named vocabulary
move, a recent hue, a type family or the pairing SHAPE. Three departures all inside the
vocabulary list are one departure wearing three hats, and count once. When a tier's K
genuinely cannot be reached on distinct axes, say so in the record with the reason; padding
the record with same-axis entries is the failure this rule names.

The audit carries TWO independent failure conditions, stated as counts so each is
falsifiable:
- **A present record that is hollow fails ON ITS OWN** — empty, placeholder, or every entry
  it claims contradicted by what actually shipped (a record naming a broken default the
  build still contains counts as placeholder — check each entry against the source, do not
  take the record's word for it). A build that reports a divergence it did not make has told
  the gate something false, and that is a finding whatever the page looks like.
- **The build reproduces the recurring SPINE in order end-to-end AND ships ≥ 3 of the
  registry's named vocabulary moves unbroken, with nothing in the record justifying it.**
  The justification clause is deliberate and is what keeps this from being a blanket OR: a
  `restrained` build that was ASKED for the conventional spine and says so passes, while a
  blanket OR would fail it by construction.

A non-empty record is not automatically a pass. A record that is ABSENT is not a failure
either: the gate had no input, so it is reported `not checked` — a build is never failed for
not having saved a file.

The reviewer greps and compares the record against this registry — it does not judge
whether the result is beautiful. **Escape hatch:** an explicit user request for a
conventional / trust-first design is a valid divergence justification (the gate never
forces unwanted novelty).

## Upkeep

At each craft-layer release, add any signature move or palette that has recurred across
builds, and drop hues outside the window. Accepted staleness: the gate detects sameness
against the last-release snapshot, so a pattern that goes viral mid-release is invisible
until the next refresh — a known, bounded blind spot.

Category defaults are refreshed from evidence outside this plugin — what the wider web
converged on since the last release — and are entered with the reason, not just the name, so
a later refresh can tell whether the default has moved. `moves-taxonomy.md`'s opt-in live
pass is the mechanism when it is available; a plain read of current design coverage is the
fallback, and either way what lands here is a CATEGORY to diverge from, never a copied
design.

## Anti-patterns

- **Auto-deriving the fingerprint** — scraping past builds to build it; it rots and the
  gate silently weakens. Curate it.
- **Reading it as a prescription** — treating the vocabulary list as components to USE; it
  is a list to diverge FROM.
- **Never refreshing** — a stale fingerprint lets the newest, most-repeated defaults pass.
