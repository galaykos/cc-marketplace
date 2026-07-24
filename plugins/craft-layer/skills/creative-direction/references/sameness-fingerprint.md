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
last 5 palettes**. Seeded from the smoke-test evidence documented in the backlog.

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
- (a build leaning only on these has no brief-specific signature move)

### Recent palette hues (avoid repeating)
- editorial lime (light)
- navy + gold (dark)
- aubergine + coral/apricot + mint (dark)
- (the don't-repeat-recent nudge in `palette-strategy.md` reads this list)

## How divergence is measured (teeth)

The creative-director agent returns a **divergence record**: for each departure,
{ fingerprint axis (spine / a named vocabulary move / recent hue) · the entry it replaces ·
the brief reason }. A concept must break **≥ 1** default (K floor = 1; more is better).

The audit fails a build when BOTH hold:
- it matches the fingerprint on all-but-one axes (spine + vocabulary), AND
- the concept's divergence record is empty or placeholder.

The reviewer greps and compares the record against this registry — it does not judge
whether the result is beautiful. **Escape hatch:** an explicit user request for a
conventional / trust-first design is a valid divergence justification (the gate never
forces unwanted novelty).

## Upkeep

At each craft-layer release, add any signature move or palette that has recurred across
builds, and drop hues outside the window. Accepted staleness: the gate detects sameness
against the last-release snapshot, so a pattern that goes viral mid-release is invisible
until the next refresh — a known, bounded blind spot.

## Anti-patterns

- **Auto-deriving the fingerprint** — scraping past builds to build it; it rots and the
  gate silently weakens. Curate it.
- **Reading it as a prescription** — treating the vocabulary list as components to USE; it
  is a list to diverge FROM.
- **Never refreshing** — a stale fingerprint lets the newest, most-repeated defaults pass.
