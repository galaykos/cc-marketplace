# MOVES taxonomy — categories the concept reasons from

The creative-director agent reasons from a taxonomy of MOVE CATEGORIES — not a list of
finished moves. The distinction is the whole difference between a mechanism and the
forbidden idea-catalog: this file names CATEGORIES and WHEN they earn their cost; the
agent DERIVES a specific move for the brief. If every build picked a named move off a
list, the anti-sameness engine would manufacture a new sameness.

**Categorical line (binding).** Categories + when-to-use ONLY. No enumerated named moves,
no "use the split-scroll gallery from site X." A category tells the agent WHAT KIND of
move is available and when it fits; the concrete move is brief-derived.

## The categories

- **Hero archetype** — the organizing shape of the first screen (editorial statement /
  living system / product-in-motion / spatial scene / typographic). When: the hero must
  carry the concept's metaphor, not just a headline over an image.
- **Scroll device** — how scroll drives meaning (pinned scrollytelling / horizontal act /
  scrub-reveal / parallax depth / section morph). When: the sequence itself is part of the
  argument; never for decoration (see `scroll-orchestration`, and
  `plugins/craft-layer/skills/scroll-orchestration/references/scroll-acts.md` for what an act costs and what it owes).
- **Type treatment** — how type behaves (variable-axis / kinetic reveal / oversized
  editorial / rotating slot / annotation). When: type is a focal element and motion serves
  reading (see `kinetic-typography`; one focal type animation per surface).
- **Motion signature** — the ONE interaction that is the brand's fingerprint (pointer
  field / magnetic pull / physics accent / WebGL surface / sprite character). When: it
  strengthens an affordance or the brand; one per build (see `interaction-fx`,
  `webgl-effects`, `physics-motion`, `motion-tiers` tier 4).
- **Layout system** — the spatial logic (asymmetric grid / bento / editorial columns /
  canvas/free / split). When: the structure itself signals the concept.

Each category points at the craft skill that OWNS its execution — this taxonomy chooses
the KIND of move; the tier/engine skills build it.

## What makes a move a SIGNATURE — the three-part test

The signature floor says "entrance reveals never count." That is asserted in several
places and, until now, defined in none — so a well-built arrival animation passes review
by looking effortful. It is a mechanism question, and it has a mechanism answer. A
candidate signature must satisfy **all three**; two out of three is an entrance reveal
wearing better clothes.

1. **Repeatable.** Can the visitor make it happen again, deliberately, without reloading
   the page? An arrival fires once per element per load and is over. If seeing it twice
   requires a refresh, it is an entrance.
2. **Driven, not fired.** Is progress a continuous function of an input the visitor
   controls moment to moment — pointer position, a drag, a control they operate, scroll
   offset while a scene is held — or is it a one-shot timeline that runs to completion
   once something crosses a threshold? Fired is an entrance; driven is a mechanism.
3. **Changes what the surface AFFORDS, not how it arrives.** This is the decisive one and
   the one that fails most candidates. Ask: with the motion deleted, what is lost? If the
   answer is "the static design, arriving less gracefully", it is an entrance reveal —
   its end state IS the static design. A signature lets the visitor DO something the
   static surface does not offer: interrogate, operate, compare, steer.

**Test 3 is not a licence to hide information in motion.** Reduced-motion and no-JS paths
still owe the same INFORMATION — that is not negotiable and is checked separately. What a
signature adds is affordance and expression: the static state must say the same things,
while the signature is how a visitor *works* them.

A scroll-linked draw or fade satisfies 1 and 2 whenever it is bound to a scroll range
rather than a trigger, and still fails 3, because the completed state is simply the
design. Passing the first two is why these get shipped as signatures by mistake.

**Where the line falls for a scroll act.** The same reasoning cuts a longer scroll act in
two, and it is worth stating because the expensive half is the one that fails. A sequence
the visitor can only watch ADVANCE — scroll moves it forward, and forward is the only
direction it has — is an entrance reveal with more frames however many frames there are.
It counts toward `maximal`'s floor 1 (the tier-reach count) and never toward the signature floor. The same
sequence PASSES test 3 when the visitor can scrub back and forth, hold a state, and
compare two states against each other: that is the "interrogate, operate, compare, steer"
above, arriving through scroll rather than through a pointer. The question is never how
much was rendered. It is whether scroll merely advances the act, or the visitor works it.

Applying the test is the audit's job (`/craft-layer:audit`) and the concept's job
(`agents/creative-director.md` scores feasibility against it). Neither may satisfy it by
naming a move from the categories above — the test judges the MECHANISM the brief
derived, not its family.

## Cached by default

The taxonomy above is the cached divergence palette, refreshable with the fingerprint at
release cadence. It seeds the agent's reasoning; it does not supply the answer.

## Opt-in live per-brief research pass

When maximum freshness is wanted, an OPT-IN live pass distills fresh move CATEGORIES for
the specific brief (Awwwards/FWA/Godly/Land-book classes of pattern), folded into the
concept as direction — never copied assets or a literal design.

- **Reuse, do not build a scraper.** The live pass presence-PROBES the `ultra-deep-research`
  plugin and runs through it. `ultra-deep-research` is a SEPARATE plugin and is NEVER a
  declared dependency of craft-layer (a declared dependency would make craft-layer a
  bundle).
- **Probe → degrade.** If `ultra-deep-research` is absent, offline, rate-limited,
  paywalled, or returns nothing → degrade to the cached taxonomy and log one line. The
  build never blocks on the live pass. (Same probe→miss→degrade shape as the role-floor
  registry resolution.)
- **Licence safety** lives in `ultra-deep-research`'s provenance gate and is only claimed
  when that plugin is present; the pass distills MOVES (patterns), never copies.

## Anti-patterns

- **Enumerated catalog** — listing named moves the agent picks from; that is the forbidden
  idea-catalog and manufactures new sameness.
- **Bespoke scraper** — building live research into craft-layer instead of reusing
  `ultra-deep-research`, or declaring it a dependency.
- **Blocking on the live pass** — failing the build when the optional pass is unavailable
  instead of degrading to the cache.
- **Copying a design** — lifting a specific site's layout as "the move"; distill the
  category, derive the move.
