---
name: coverage-check
description: Use after task-cards splits a spec into cards — verifies every spec success criterion is covered by a card and no card proves what the spec never asked, blocking execution handoff until each gap, orphan, and drift is resolved or accepted.
---

## Where this sits

This runs at the tail of task-cards: once `00-INDEX.md` and the card files are
written, and before the execution handoff. It is an independent verifier of
task-cards' own output — fresh eyes on the split, not the author re-reading its
own work, which is why the matrix build is dispatched to a subagent rather than
done by the thread that just wrote the cards. It checks documents against
documents; it is not code verification. work-verification and task-runner check
delivered code against criteria later — this checks that the criteria are all
represented in the cards first, so the run does not begin already missing a
requirement or carrying scope nobody asked for.

## What it checks

One correspondence: the spec's `## Success criteria` against every card's
`**Acceptance criteria:**`. The relationship is many-to-many — one criterion may
take several cards to satisfy, one card may serve several criteria. Match by
meaning, never by string equality: a criterion is covered when at least one
card's acceptance criteria would, if met, make that criterion true. You are
reading intent, not diffing text.

A second correspondence, when the spec has a `## Visual contract` section: each
binding visual/creative entry against the card(s) that build that surface. A
staged decision with no conforming card is a GAP; a card that alters a named
surface against the contract is drift. Keep it distinct from the criteria check —
a decision is not a success criterion.

## The two directions, and drift

Walk the correspondence both ways — a one-directional check misses half the
failures:

- **Forward — coverage.** For each success criterion, find the card(s) whose
  acceptance criteria satisfy it. A criterion with no such card is a **GAP**:
  scope the spec promised that the cards silently dropped.
- **Reverse — traceability.** For each card, find the criteria it serves. A card
  that serves none is an **ORPHAN**: work the cards added that the spec never
  asked for.
- **Drift.** A card whose acceptance criteria assert behavior traceable to no
  spec criterion and no spec decision is scope creep — flag it with the orphans.
  (A card doing setup for a criterion it does not itself prove is not drift; ask
  which criterion it serves before flagging.)

## The coverage matrix

The result is presented in the main thread and persisted into `00-INDEX.md` as a
`## Coverage` section so it travels with the run. A markdown table, then the
exceptions:

```
## Coverage

| Success criterion            | Covered by | Status  |
| ---------------------------- | ---------- | ------- |
| 1. Editing .sql nudges once  | 03, 06     | covered |
| 2. Absent plugin → no nudge  | 03         | covered |
| 3. Session index primes …    | —          | GAP     |

Orphans / drift: 07 (adds a metrics endpoint — no criterion or decision).
Accepted gaps: none.
```

No HTML, no separate file — the index is the single run view.

## Build the matrix — dispatch

Dispatch ONE read-only subagent (Read/Grep/Glob) to build the matrix. Give it
exactly two inputs — the spec file path and the cards directory — plus the
matching rules above and the `## Coverage` format above as its output contract.
Do not pass it the conversation, the ledger, or your own summary of either
document: a brief pre-digested by the cards' author re-imports the blind spots
this gate exists to escape. The subagent reads the spec's `## Success criteria`
(and `## Visual contract` when present) and every card's
`**Acceptance criteria:**`, walks both directions, and returns ONLY the
compressed `## Coverage` block in that exact format — no file dumps. The main
thread gets the matrix without re-ingesting the spec and cards; every finding
is then resolved here, in the main thread, through the gate below.

**Headless fallback.** When subagent dispatch is unavailable, build the matrix
inline: read the spec and every card yourself and apply the same rules and
format. The gate blocks identically — only the fresh-eyes property degrades,
so read both documents cold, end to end, before matching.

## The resolution gate

Do not proceed to the handoff while any finding is unresolved. Present the matrix,
then take each finding through a choice (AskUserQuestion; bare options when
headless):

- **GAP** → *Add a card* (hand the authoring to the task-cards skill — never
  write the card here) / *Fold into an existing card* (name it) / *Reclassify the
  criterion as a non-goal* (move it to the spec's non-goals) / *Accept as a known
  gap* (record it in the `## Coverage` section with a reason).
- **ORPHAN or DRIFT** → *Tie the card to a criterion* (name it) / *Add the missing
  criterion to the spec* (the card was right, the spec was thin) / *Drop the card*.
- **Staged-decision GAP or drift** (`## Visual contract`) → *Add or point a card*
  at the surface / *Defer the surface* (move it to non-goals, re-approval) /
  *Accept as covered elsewhere* (record it in `## Coverage`).

Loop until every finding is resolved or explicitly accepted, then write the final
`## Coverage` section — including accepted gaps and their reasons — and continue.

## Clean pass

When both directions map with no gap, orphan, or drift, say so in one line, write
the clean `## Coverage` matrix into `00-INDEX.md`, and let the handoff proceed. A
clean pass is the common case for a well-run grill; the gate earns its keep on the
runs where it is not.

## Worked example

A spec lists six success criteria. The card set covers five; criterion 4 ("a
malformed payload is rejected with a 422") maps to no card's acceptance criteria —
a GAP. Card 07 asserts "adds a Prometheus metrics endpoint", which no criterion or
decision mentions — DRIFT. Present the matrix, then: for the gap, the user picks
"Add a card" → hand off to task-cards to author the validation card; for card 07,
the user picks "Drop the card". Re-check, matrix clean, write `## Coverage`,
proceed.

## Anti-patterns

- **Authoring cards here.** "Add a card" hands off to task-cards; this skill never
  writes a card file. Splitting is task-cards' judgment, not this gate's.
- **String-matching criteria.** Coverage is about meaning — a criterion and the
  acceptance line that satisfies it rarely share words. Judge intent.
- **Proceeding on an unresolved gap.** A blocking gate that waves gaps through is
  the advisory gate it was chosen over. Every finding is resolved or accepted.
- **Flagging a legitimate non-goal as a gap.** The spec's `## Non-goals` are not
  criteria; do not demand cards for them.
- **Re-litigating an accepted gap.** Once recorded in `## Coverage` with a reason,
  it is settled for the run.
- **Summarizing the documents for the subagent.** Pass paths, not digests — the
  author's summary carries the author's blind spots into the check.
- **Letting the subagent resolve findings.** It returns the matrix, nothing more;
  every gap, orphan, and drift decision belongs to the main thread's gate.
