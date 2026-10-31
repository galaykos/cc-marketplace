---
name: coverage-check
description: Use after task-cards splits a spec into cards. Verifies every spec success criterion has a card and no card proves what the spec never asked. Holds the execution handoff until findings resolve (agent-graded; no script enforces it).
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
card's acceptance criteria would, if met, make that criterion true.

A second correspondence, when the spec has a `## Visual contract` section: each
binding visual/creative entry against the card(s) that build that surface. A
staged decision with no conforming card is a GAP; a card that alters a named
surface against the contract is drift. Keep it distinct from the criteria check —
a decision is not a success criterion.

## The two directions, and drift

Walk the correspondence both ways — one direction misses half the failures:

- **Forward — coverage.** For each success criterion, find the card(s) whose criteria
  satisfy it. None → a **GAP**: scope the spec promised that the cards silently dropped.
  Named only in a card's `<must>` or prose, never in its `<criterion>`/`<verify>` → a
  **PLACEMENT**, not a GAP: the card does the work and nothing proves it.
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
Recommended: 3 → Add a card (none touches the index) · 07 → Drop the card (nothing asks for it).
```

No HTML, no separate file — the index is the single run view.

## Build the matrix — dispatch

Dispatch ONE read-only subagent (Read/Grep/Glob) with exactly two inputs — the spec
path and the cards directory — plus the matching rules and the `## Coverage` format
above as its output contract. Never pass it the conversation, the ledger, or your own
summary: a brief pre-digested by the cards' author re-imports the blind spots this gate
exists to escape. It reads `## Success criteria` (and `## Visual contract` when present)
and every card's `<criterion>` elements, walks both directions, and returns ONLY the
`## Coverage` block — no file dumps. The main thread adds the `Recommended:` line (a
resolution and a why per finding) and resolves every finding.

**Headless fallback.** No subagent dispatch → build the matrix inline with the same
rules and format; only the fresh-eyes property degrades, so read both documents cold,
end to end, before matching.

## The resolution gate

Standing: **agent-graded — no script enforces this**; the hold is judged in-thread.
Do not proceed to the handoff while any finding is unresolved. Present the
matrix with its `Recommended:` line, each pick one of these options:

- **PLACEMENT** → no question: move it into that card's `<criterion>`, extend its
  `<verify>` to detect it, list each edit in one line, and continue. It becomes a GAP to
  ask about only when no command the card can run would detect it.
- **GAP** → *Add a card* (hand the authoring to the task-cards skill — never
  write the card here) / *Fold into an existing card* (name it) / *Reclassify the
  criterion as a non-goal* (move it to the spec's non-goals) / *Accept as a known
  gap* (record it in the `## Coverage` section with a reason).
- **ORPHAN or DRIFT** → *Tie the card to a criterion* (name it) / *Add the missing
  criterion to the spec* (the card was right, the spec was thin) / *Drop the card*.
- **Staged-decision GAP or drift** (`## Visual contract`) → *Add or point a card*
  at the surface / *Defer the surface* (move it to non-goals, re-approval) /
  *Accept as covered elsewhere* (record it in `## Coverage`).

If any finding needs a choice, ask ONE AskUserQuestion batch (bare options when
headless; at most four questions, overflow into a second batch):

- **Own question** for each finding whose recommendation is not a card edit — it
  accepts, reclassifies, defers or adds a criterion: its options, the recommended
  first, marked (Recommended).
- **One shared question** for card edits (add, fold, point, tie or drop a card). In
  `/taskmaster:task` with task-runner installed and no run yet authorized it also
  carries the run, asked even with no card edits: "Apply the recommended resolutions
  and start execution now?" → "Apply and run now (Recommended)" / "Apply, stop here" /
  "Walk through each"; the run starts after the card lints. Otherwise: "Apply the
  recommended resolutions?" → "Apply all (Recommended)" / "Walk through each".
  Walking through asks each as above; the handoff then asks to run.

Loop until every finding is resolved or explicitly accepted (a re-check finding gets
the run-free ask), then write the final
`## Coverage` section — including accepted gaps and their reasons — and continue.

## Clean pass

When both directions map with no gap, orphan, or drift, say so in one line, write
the clean `## Coverage` matrix into `00-INDEX.md`, and let the handoff proceed.

## Anti-patterns

- **Authoring cards here.** "Add a card" hands off to task-cards; splitting is its judgment.
- **String-matching criteria.** A criterion and the line that satisfies it rarely share words.
- **Proceeding on an unresolved gap.**
- **Flagging a non-goal as a gap.** `## Non-goals` are not criteria.
- **Re-litigating an accepted gap.** Recorded with a reason, it is settled for the run.
- **Summarizing the documents for the subagent, or letting it resolve findings.**
