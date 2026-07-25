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

### Recurring component vocabulary (overused signature moves)
- kinetic variable-weight headline
- rotating-word / phrase cross-fade slot
- magnetic CTA button
- tilt-on-hover cards
- logo marquee
- scroll-driven bento/stat reveal
- default stock imagery (the generic stock-photo hero — imagery chosen off-the-shelf, not art-directed)
- default icon set (an untouched off-the-shelf icon pack — no consistency or metaphor choice made)
- oversized-type hero as the default opening — type standing in for a hero image because it
  is the current default, not because the brief earned a typographic hero
- WebGL floating-objects / cursor-reactive background — an ambient 3D layer that carries no
  argument (distinct from a 3D surface the concept actually needs)
- scrollytelling as the default page STRUCTURE — scroll driving the sequence because that is
  what pages do now, rather than because the sequence is the argument
- the generated-web composition: gradient hero + one geometric sans + a four-card grid
- (a build leaning only on these has no brief-specific signature move)

### Recent palette hues (avoid repeating)
- editorial lime (light)
- navy + gold (dark)
- aubergine + coral/apricot + mint (dark)
- purple/violet gradient — see the category-default note below
- (the don't-repeat-recent nudge in `palette-strategy.md` reads this list)

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

## How divergence is measured (teeth)

The creative-director agent returns a **divergence record**: for each departure,
{ fingerprint axis (spine / a named vocabulary move / recent hue) · the entry it replaces ·
the brief reason }. A concept must break **≥ 1** default (K floor = 1; more is better).

The audit fails a build when BOTH hold — stated as counts, so the check is falsifiable:
- the build reproduces the recurring SPINE in order end-to-end, **and** ships ≥ 3 of the
  registry's named vocabulary moves unbroken; AND
- the divergence record is present but empty, placeholder, or every entry it claims is
  contradicted by what actually shipped (a record naming a broken default the build still
  contains counts as placeholder — check each entry against the source, do not take the
  record's word for it).

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
