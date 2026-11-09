# Decision rounds — batching, caps, and how this degrades

A guided build competes with a one-shot build on TOTAL cost to the user, not on
thoroughness. Eight sections asked one at a time is roughly twenty exchanges;
users abandon that halfway and end up owning half a page, which is worse than the
one-shot they were avoiding. These rules keep a guided run inside a handful of
exchanges.

## The three rounds

Decisions are grouped so that each round settles one KIND of question across the
whole page, cheapest and most consequential first. A later round never reopens an
earlier one.

### Round 1 — Shape (one exchange, whole page)

The page's skeleton, decided once: which spine slots get their own section, which
combine, what order they run in, and — on `long-scroll` — the rhythm (where the
heavy instruments sit, where the page breathes, where the CTA recurs).

Present as two or three whole-page outlines, ASCII or a numbered section list,
each a genuinely different argument order (problem-first vs. capability-first vs.
proof-first). One exchange, one pick. This is the highest-leverage decision on the
page and the cheapest to draw.

### Round 2 — Treatment (batched, 3–4 sections per exchange)

For each section from Round 1, how it argues: the shape of the block, whether it
carries an instrument, what the visitor does there. Batch 3–4 sections into one
exchange as parallel questions (`AskUserQuestion` takes up to four), so eight
sections cost two exchanges rather than eight.

Order the batches by consequence: the sections carrying the plain-what, the price,
and the proof come first. If the user exits early, the decisions that mattered are
already made.

### Round 3 — Signature (one exchange, at most)

Only for the ONE section carrying the concept's signature interaction. This is the
single decision worth full-fidelity staging (real components, live preview), and
it is only worth it once. If the concept's signature is already unambiguous, skip
this round rather than manufacture a choice.

Skipping the ROUND never skips the ROW. Write the `signature` ledger row either way —
`source: auto` when unambiguous — because the craft flow's motion step resolves the build
task's `Signature:` line from it and the audit greps that section for the named mechanism.
A signature nobody assigned to a section is the concept evaporating one step from the build.

## The cap

**Three rounds, and a hard ceiling of six exchanges including any iteration.** At
the cap, decide the remainder against the concept and the archetype defaults,
report what was auto-decided, and proceed. A guided flow that outlives the user's
patience has failed even if every answer was good.

Iteration on a single pick is capped at two revisions, matching the preview
surfaces' own limit; past that, take the closest option and note the reservation
in the ledger.

## Always-available exits

Offer these as real options, not as a fallback mentioned once:

- **"Decide the rest for me"** — available at every exchange. Auto-decides the
  remaining agenda against the concept + archetype defaults, writes ledger entries
  marked `auto`, and proceeds to the build. This is the graceful path back to
  one-shot behaviour and must never be treated as failure.
- **"Show me one option"** — user wants a recommendation rather than a menu:
  present the strongest option and ask only for a yes/change-it.
- **Fidelity refusal** — the mockup consent gate (`taskmaster:visual-decisions`)
  is declined, or no staging surface is installed: every decision becomes a plain
  multiple-choice question with written option descriptions. The agenda, rounds,
  ledger, and audit conformance all still work; only the drawing is lost.

## Staging on a design-kit board

When the design-kit plugin is installed, a round can draw its options as artboards with
`/design-kit:design` instead of written descriptions. Standing: **recorded** — no script reads a
board or checks that its pick reached the ledger.

- **One board per decision, one artboard per option.** Round 1's board holds the two or three
  whole-page outlines. A Round 2 section gets a board only when the user wants it drawn, so a batch
  stays one exchange. Round 3's one signature decision is the one most worth a board. The board's
  brief is the decision: the slot, the concept's metaphor and voice, and how the options differ in
  structure. The option rule still binds — artboards that differ in decoration are a fake choice.
- **Read the pick back, then write the row.** Take the pick `/design-kit:design` reads back from the
  board, never a retyped summary. `choice` is the picked artboard's title and shape, `why` its
  trade-off line, `locks` what it commits plus every text edit and knob value the read-back
  reported (each is a requirement), `source: user`, and `staged` the board and artboard number.
- **Stop at the pick.** The board's own next-step offer (render it in the codebase, build it now)
  belongs to a standalone design run. Here the next step is the next decision, and the build reads
  the ledger.
- **The cap still counts.** A board revision is one of the two revisions a pick allows, every board
  exchange counts toward the six, and "Decide the rest for me" stays beside the pick question.

## Headless / non-interactive runs

With no interactive user (a scheduled or piped run), do not stall waiting for a
pick. Auto-decide the entire agenda, mark every ledger entry `auto`, and print the
agenda with what was chosen so a human can review and rerun any single decision
later. A guided skill that hangs a headless run is a defect, not a safeguard.

## What a round is NOT

- **Not a grill.** No ambiguity ledger, no convergence loop, no re-asking until
  the answer is airtight — that is `taskmaster:grill`'s job, on requirements.
  Here, a pick is final when made.
- **Not an approval queue.** The user is choosing between options, not signing
  off on work already done. Never present a built section and ask "is this ok?" —
  that is a review, and it costs the rebuild the checkpoint existed to prevent.
- **Not per-component.** The unit is a SECTION. Button variants and card anatomy
  are the build's business, decided by tokens and the component skills.

## Anti-patterns

- **Round creep** — a fourth and fifth round because more could be decided;
  the cap is the feature.
- **Reopening a settled round** — revisiting page order during treatment; carry
  the reservation into the ledger instead and let the walkthrough catch it.
- **Exit buried** — offering "decide the rest for me" only after the user has
  already shown fatigue, rather than at every exchange.
- **Manufactured choice** — inventing a third option to fill a menu when the
  brief genuinely admits two.
