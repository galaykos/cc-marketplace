---
name: section-decisions
description: Use when a craft build should be decided section by section with the user instead of generated in one shot — staged treatments per spine slot, picks recorded in the section ledger the build and audit read.
---

## What this decides

A one-shot craft build shows the user nothing until it is finished, so every
misread of the brief survives the whole run and surfaces at review. This skill
inserts the checkpoint: the user picks each section's TREATMENT before it is
built. It decides:

- the **agenda** — which sections come up for decision, and in what order → below
- the **round structure** and its batching → `references/decision-rounds.md`
- what a valid **option set** is (and is not) → below
- the **section ledger** the picks land in → `references/section-ledger.md`

It does NOT author mockups, run preview servers, generate palettes, or invent a
catalogue of section designs. Those belong to the surfaces in Reuse, and to the
concept the creative-director agent already produced.

## The agenda is derived, never invented

The offer contract (`../creative-direction/references/offer-contract.md`) already
enumerates what a page owes: plain-language what, audience, problem, how-it-works,
price, proof, objection, primary CTA. That IS the agenda — one decision per spine
slot, in spine order, so a section can never be decided that the contract did not
ask for and no slot can be quietly skipped.

Two adjustments, both contract-driven: `content-depth.md` sets how many sections
the archetype owes, so a slot may resolve into more than one section; and on a
`long-scroll` build the agenda gains an ORDER-AND-RHYTHM decision, because
sequence and section-shape variety are where long pages fail (Part 5).

Inventing an agenda item outside the contract is the failure this rule prevents —
it reintroduces the sprawl the contract exists to stop.

## Rounds, not an interrogation

Eight slots asked one at a time is an exhausting flow that gets abandoned halfway,
which is worse than one-shot: the user ends up owning half the page. Decisions are
therefore BATCHED into rounds — structure settled across the page before any
single section's treatment — with a cap on rounds and an explicit
decide-the-rest-for-me exit available at every step. The round shapes, the
batching rule, the cap, and the degradation paths live in
`references/decision-rounds.md`.

## Options must be structurally different

Two or three options per decision, and they must differ in STRUCTURE — what the
section is, how it argues — not in decoration. Three shades of the same stacked
block is a fake choice that costs the user a decision and returns nothing.

Each option carries: a one-line description of the shape, the one-line tradeoff,
and what the pick LOCKS downstream (a component, an instrument, a data need).
Options are reasoned from the MOVE CATEGORIES in
`../creative-direction/references/moves-taxonomy.md` and constrained by the
concept's metaphor, voice, and signature interaction — an option that contradicts
the concept is not on the menu. Never ship a named-design catalogue; generate
against the brief.

## Staging — reuse, never re-teach

This skill decides WHAT to ask. How an option is drawn belongs to surfaces that
already own it, in fidelity order:

| Need | Owned by |
| --- | --- |
| Consent gate, fidelity ladder, ASCII + shell HTML mockups | `taskmaster:visual-decisions` |
| Real project components on a live server | `/design-preview:preview` |
| Greenfield / non-React component variants | `/shadcn-studio:stage` |
| Colour or theme IS the decision | `/ui-ux:theme` |
| Validating the ASSEMBLED page after the picks | `taskmaster:experience-walkthrough` |

Every one is optional. When none is installed, decisions degrade to plain
multiple-choice questions with written option descriptions — the agenda, the
rounds, and the ledger all still work. Do not re-implement a mockup pipeline
here.

## The section ledger

Picks are worthless if the build does not read them. Each decision appends to a
section ledger — slot, chosen option, what it locks, and the one-line why — which
`design-research`'s build task carries into `/ui-ux:build`, and which the craft
audit reads to check the built page against what was actually chosen. Schema,
location, and the conformance rule: `references/section-ledger.md`.

A ledger written and never threaded is the same failure as a concept generated
and dropped.

## Boundary against taskmaster

taskmaster clarifies REQUIREMENTS into a spec and cards; this decides SECTION
TREATMENT for a page whose scope the offer contract already pinned. When a
taskmaster spec or a `## Visual contract` section exists, CONSUME it — treat its
decisions as already-made ledger entries and ask only about what it left open.
Re-interrogating settled requirements is the duplication to avoid.

## Reuse — never duplicate

| Concern | Owned by |
| --- | --- |
| Which sections a page owes | `creative-direction` (`offer-contract.md`) |
| How many sections, how deep | `creative-direction` (`content-depth.md`) |
| The concept the options must honor | `creative-direction` + the creative-director agent |
| MOVE categories the options are reasoned from | `creative-direction` (`moves-taxonomy.md`) |
| Drawing an option | `taskmaster:visual-decisions`, `/design-preview:preview` |
| Building the picked section | `/ui-ux:build` |
| Checking the built page against the ledger | `/craft-layer:audit` |

## References

- `references/decision-rounds.md` — round shapes, batching rule, round cap, the
  decide-the-rest-for-me and headless degradations.
- `references/section-ledger.md` — ledger schema, where it lives, how the build
  task carries it, and the audit's conformance rule.

## Anti-patterns

- **Invented agenda** — decisions for sections the offer contract never asked
  for; the agenda is derived from the spine, not brainstormed.
- **Fake options** — two or three variants of one structure, so the user spends
  a decision and the page gains nothing.
- **One-at-a-time interrogation** — eight ungrouped questions; batch into rounds
  and always leave the decide-the-rest exit open.
- **Re-teaching mockups** — authoring an HTML/ASCII pipeline here instead of
  routing to the surfaces that own it.
- **Ledger dropped** — picks recorded, then a build that ignores them.
- **Second taskmaster** — re-interrogating requirements a spec already settled.
