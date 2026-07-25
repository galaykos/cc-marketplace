# Ambition tiers — how much visual reach the build owes

The contract already pins what a page must SELL and how it gets DECIDED. This file pins
how far it must REACH. Without it, "award winning", "go over the top" and "make it very
graphical" are unpinnable: they are adjectives in a prompt, they bind nothing downstream,
and the build satisfies every gate it has while ignoring them.

The tier is a SLOT in the offer contract, pinned from the user's own words, persisted with
the rest of it, and read back by the audit. It is the same mechanism `Mode` and `Length`
already use, and it works for the same reason — a decision nobody wrote down cannot be
checked.

## The three tiers

| Tier | Pinned when | The build owes |
| --- | --- | --- |
| `restrained` | the user asks for conventional, trust-first, understated, corporate, or "keep it simple" | the signature floor only |
| `standard` *(default)* | no ambition language either way | the signature floor only |
| `maximal` | the user asks for reach in ANY words | the signature floor **plus** the three reach floors below |

**Pinning `maximal` is a reading of intent, not a keyword match.** "award winning",
"awwwards", "dribbble", "over the top", "very graphical", "cinematic", "showpiece", "make it
pop", "with effects and animations" all pin it; so does naming heavy motion libraries as the
POINT of the brief rather than as a stack constraint. When the words are ambiguous, ASK —
`maximal` costs real bundle weight and build time, and pinning it silently is as wrong as
ignoring it.

`restrained` and `standard` differ in intent, not in floors. The split exists so an
explicitly conventional request is recorded as a DECISION — the same escape hatch
`sameness-fingerprint.md` already grants — rather than looking like a build that under-reached.

## The three reach floors (`maximal` only)

Each is checkable from the shipped tree. Each may be waived, but only in the divergence
record, with the brief reason — a waiver nobody wrote down is an under-reach.

### 1. Tier reach — at least three distinct motion capabilities

Count DISTINCT capabilities actually driving a surface. Both of these count, and each counts
once:

- a **tier** from `motion-tiers/references/tier-budgets.md` — UI-state/layout, Timeline/SVG,
  3D/WebGL, Sprites, Vector;
- a **sibling engine** — scroll-orchestration, page-transitions, kinetic-typography,
  interaction-fx, physics-motion, motion-sequencing, webgl-effects.

Count capabilities, not imports: two entry points into the same tier is one, and a dependency
in the manifest that nothing imports is zero. Two is what cheapest-that-fits produces on its
own — one for the signature, one for scroll — so three is the first count that forces a
decision the tier picker will not make by itself, because it takes the cheapest tier that fits
on every surface except the signature's.

This is a floor on REACH, not on weight. The cumulative motion budget does not move: the
third tier arrives lazily, below the fold, or on interaction. A build that clears this floor
by shipping a second eager engine has failed the budget instead, and traded one finding for
a worse one.

### 2. Graphic system — one authored visual system, not a mark set

At least one surface carries a visual system the build AUTHORED: generative or procedural
canvas, a WebGL/shader surface, a programmatic SVG system, a sprite system, or a
designer-authored vector asset. Rules, gutters, borders, type treatment and an icon set are
composition — they are not this.

The distinction that makes it checkable: a graphic system PRODUCES imagery from code or from
an asset, and would leave a visible hole if deleted. A mark set styles text and boxes that
still read fine without it.

This floor is reachable. It asks for art direction the flow can EXECUTE — code-authored
imagery — and never for commissioned illustration or photoreal 3D, which
`sourcing-decision.md` correctly routes to `commission` and which no orchestration layer
produces. See "What this does not buy" below.

### 3. Asset posture — an empty manifest is not a pass

At `maximal`, a provenance manifest whose every line declares first-party-and-nothing-shipped
does not satisfy the asset plan. The licence gate still passes on it — that gate asks whether
what shipped is DECLARED, and an all-in-code build genuinely owes a first-party
declaration — but the reach floor asks a second question: was an asset decision made, or was
none needed?

`sourcing-decision.md` already names this: "a build whose every asset resolves to first-party
has probably hit this ceiling rather than reasoned its way to a position." At `standard` that
is a note. At `maximal` it is a finding, because the user asked for the thing first-party
emptiness cannot deliver.

## What never moves

The reach floors raise what a build must REACH FOR. They lower nothing:

- `prefers-reduced-motion` on every tier, and the reduced-bundle fallback — unchanged.
- Per-tier AND cumulative motion budgets — unchanged. Reach is bought with lazy loading, not
  with bytes on first paint.
- Accent-vs-surface contrast at every size — unchanged.
- The licence and provenance gate — unchanged.
- Full accessibility, delegated to `/a11y:audit` — unchanged.

An `maximal` build that clears its reach floors by breaking a ceiling has not reached
further; it has shipped a defect with more moving parts. Where the two genuinely conflict,
the ceiling wins and the floor is waived in the record with that as the reason.

## What this does not buy

`maximal` raises the ceiling on art direction the flow can execute in code. It does not close
the gap the README names: commissioned illustration, photoreal 3D, bespoke type sculpture and
cinematic rendering are what the top of the field is built from, and they remain out of reach
for an orchestration layer. A `maximal` build is a build that reached as far as code-authored
craft goes — which is further than `standard`, and is not the same as the top of the field.

## Anti-patterns

- **Ambition as adjective** — "award winning" echoed in the contract's prose scope line and
  bound to no slot; it then reaches nothing and checks nothing.
- **Silent maximal** — pinning the tier from a brief that never asked, and spending the
  bundle on it.
- **Reach by weight** — clearing the tier floor with a second eager engine instead of a lazy
  one, trading a reach finding for a budget finding.
- **Decoration as system** — a cursor-reactive ambient background added to satisfy floor 2.
  The fingerprint registry already names that move; a system the concept does not need is a
  sameness finding whichever floor it was meant to clear.
- **Waiver by silence** — under-reaching without a recorded reason. The floors are waivable;
  the record is not optional.
