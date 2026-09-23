---
name: coverage-check
description: Use after task-cards splits a spec into cards — verifies every spec success criterion has a card and no card proves what the spec never asked, holding the execution handoff until findings resolve (agent-graded; no script enforces it).
---

## Where this sits

Standing: the INVOCATION is `recorded` — nothing schedules or observes it (the card-lint
observer reads the three card linters' records, never this skill's); the resolution hold
below is `agent-graded`. Runs at the tail of `task-cards`, once `00-INDEX.md` and the
cards are written, before the execution handoff. It verifies task-cards' own output with
fresh eyes — hence the subagent — and checks documents against documents;
`work-verification` and `task-runner` check delivered code later.

## What it checks

One correspondence: the spec's `## Success criteria` against every card's
`<proof>` criteria (`<criterion>` elements; `**Acceptance criteria:**` on a legacy card). The relationship is many-to-many — one criterion may
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

Walk the correspondence both ways — one direction misses half the failures:

- **Forward — coverage.** For each success criterion, find the card(s) whose criteria
  satisfy it. None → a **GAP**: scope the spec promised that the cards silently dropped.
- **Reverse — traceability.** For each card, find the criteria it serves. None → an
  **ORPHAN**: work the spec never asked for.
- **Drift.** A card whose criteria assert behavior traceable to no spec criterion and no
  spec decision is scope creep — flag it with the orphans. (Setup for a criterion the card
  does not itself prove is not drift; ask which criterion it serves first.)

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

Dispatch ONE read-only subagent (Read/Grep/Glob) with exactly two inputs — the spec
path and the cards directory — plus the matching rules and the `## Coverage` format
above as its output contract. Never pass it the conversation, the ledger, or your own
summary: a brief pre-digested by the cards' author re-imports the blind spots this gate
exists to escape. It reads `## Success criteria` (and `## Visual contract` when present)
and every card's `<criterion>` elements, walks both directions, and returns ONLY the
`## Coverage` block — no file dumps. Every finding is then resolved in the main thread.

**Headless fallback.** No subagent dispatch → build the matrix inline with the same
rules and format; only the fresh-eyes property degrades, so read both documents cold,
end to end, before matching.

## The resolution gate

Standing: **agent-graded — no script enforces this.** The hold below is this
skill's instruction to the executing agent, judged in-thread; no build gate
backs it. Do not proceed to the handoff while any finding is unresolved. Present the matrix,
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

Six criteria, five covered; criterion 4 ("a malformed payload is rejected with a 422")
maps to no card — GAP. Card 07 asserts "adds a Prometheus metrics endpoint", named by no
criterion or decision — DRIFT. Present the matrix; the user picks "Add a card" for the
gap (task-cards authors it) and "Drop the card" for 07. Re-check, clean, write
`## Coverage`, proceed.

## Anti-patterns

- **Authoring cards here.** "Add a card" hands off to task-cards; splitting is its judgment.
- **String-matching criteria.** A criterion and the line that satisfies it rarely share words.
- **Proceeding on an unresolved gap.** Nothing but this instruction stops a wave-through.
- **Flagging a non-goal as a gap.** `## Non-goals` are not criteria.
- **Re-litigating an accepted gap.** Recorded with a reason, it is settled for the run.
- **Summarizing the documents for the subagent, or letting it resolve findings.** Paths,
  not digests; it returns the matrix, the main thread decides.
