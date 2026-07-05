---
name: estimation
description: Use when sizing a task, card, or backlog — before committing to scope or sequencing — to classify effort honestly with reference anchors instead of optimism, and to flag what must be split or spiked first.
---

Estimates are comparisons, not prophecies. "This resembles X, which took Y"
beats a gut number every time, because the comparison carries the hidden
costs — the test that wouldn't pass, the config that wasn't where the docs
said — that the gut number silently drops. Never emit a size without naming
the completed piece of work it resembles.

## Size classes

Classes align with the task-runner plugin's parallel-planning weights
(S=1, M=3, L=8) so sizes feed directly into critical-path math.

- **S** (weight 1, ≲15 min) — single-file edit, config change, or a fix
  whose shape is already known. You could describe the diff before
  writing it.
- **M** (weight 3, ≲45 min) — one card-sized unit of work: a few files,
  one coherent change, a clear way to verify it. The default size for a
  well-cut task card.
- **L** (weight 8, multi-hour) — crosses modules or layers, needs its own
  verification plan. Usually a sign the task should be split into cards
  first: run it through /taskmaster:task instead of estimating it whole.
- **XL** (unsizeable) — contains at least one unknown you cannot bound.
  Not a task but a project, or a spike trigger. Never assign XL a weight;
  assign it a next action (split or spike).

## Reference-class calibration

Anchor every size to COMPLETED work in this repo or session, not to an
imagined ideal execution. "Like the auth middleware fix, and that was M"
is calibration; "feels like an hour" is a wish with a clock on it.

- Keep anchors project-local. A "simple endpoint" in a codebase you know
  is S; the same endpoint in this codebase is whatever the last endpoint
  here actually cost.
- If no completed local anchor exists for a class of work, that absence
  is itself information: treat the task as unfamiliar territory and apply
  the multiplier below.
- Refresh anchors as work completes — the best anchor is the most recent
  comparable task, because it priced in the repo's current friction.

## Uncertainty multipliers

When any of these apply, multiply the class up one step (S→M, M→L, L→XL)
or spike first:

- Unfamiliar territory (first time touching this subsystem): ×2.
- Undocumented external API (behavior discovered by poking it): ×2.
- "Should be easy" claims about legacy code: ×2 — that phrase is the
  most reliable predictor of a blown estimate in the catalog.

A spike — a time-boxed probe with a question, not a deliverable —
converts unknown to known and is almost always cheaper than carrying the
multiplier. See the approaches plugin's spike strategy, and use
/approaches:compare when the unknown is "which of these designs survives
contact with the code."

## Split triggers

Split before estimating further when any of these fire:

- Any L on the critical path — one long pole sets the wall-clock for the
  whole run, so break it into parallelizable M cards.
- Any task whose title needs "and" — two verbs is two tasks wearing one
  card.
- Any XL, always. Estimating an XL as a unit is fiction with a number on
  it; the honest output is a split proposal or a spike, never a weight.

## The 90% trap

The last 10% — edge cases, verification, integration — routinely costs
as much as the first 90%. Size to DONE, meaning verify passing, not to
demo, meaning "it worked when I ran the happy path once." If the mental
movie of the task ends at "and then it basically works," the estimate is
missing its second half.

## Estimate-vs-actual loop

Record the class when work starts; record the actual when it finishes.
The pattern of misses is the calibration data — one miss is noise, the
same miss twice is a finding.

- A miss of two or more classes (S that became L, M that became XL) is a
  retro finding: bring it to /retrospective:run so the cause gets banked
  instead of re-discovered.
- Never revise the original estimate after the fact; the gap IS the
  signal. A corrected history calibrates nothing.

## Feeds

/task-runner:plan consumes these classes directly as weights for its
critical-path and speedup math. Honest sizes upstream mean honest
wall-clock estimates downstream; one flattered L poisons the whole plan.

## Worked micro-example

A 13-card run, sized before execution:

    8 feature cards        M (3)  anchor: "like the settings page card"
    3 wiring cards         M (3)  anchor: "like the router hookup"
    1 cleanup card         S (1)  anchor: "like the lint pass"
    1 integration card     M (3)  flagged: uncertain (crosses two modules)

    Weighted sum: 12 x 3 + 1 = 37 units — 3x13-ish, i.e. "mostly M".

The one card that ran long was the integration card — the one flagged
uncertain at sizing time. The flag did its job: nobody was surprised,
and the runner had already kept it off the parallel groups.

## Anti-patterns

- **Precision theater** — hours with decimals ("3.5h") from a process
  with class-level resolution at best. The decimal is a costume.
- **Sizing to the happy path** — pricing the demo and forgetting the
  90% trap above.
- **Anchoring on the requester's hoped-for number** — "can this be done
  by Friday?" is a deadline, not evidence about size.
- **Re-estimating mid-task to hide a miss** — quietly promoting an M to
  an L at hour three destroys the estimate-vs-actual loop. Record the
  miss; that record is the only thing that makes the next estimate
  better.
