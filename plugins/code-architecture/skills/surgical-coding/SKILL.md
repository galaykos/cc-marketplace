---
name: surgical-coding
description: Use when writing, editing, or refactoring code — the always-on discipline outside a planned pipeline: surface assumptions, competing interpretations over silent picks, changed lines traceable to the request, vague asks made verifiable.
---

## Where this fits

The taskmaster/task-runner pipeline enforces this discipline through commands
and cards. This skill is the ALWAYS-ON version for the other 80% of coding —
the quick fix, the small feature, the "just change X" — where no pipeline runs
but the same failure modes bite. Adapted from Andrej Karpathy's observations
on LLM coding pitfalls (multica-ai/andrej-karpathy-skills, MIT). Bias is
caution over speed; for genuinely trivial edits, judgment applies.

## Surface assumptions before code

Confusion hidden at the start becomes a rewrite at the end:

- State load-bearing assumptions explicitly before implementing; if one is a
  guess, ask instead of guessing silently.
- Multiple readings of the request? Present them and let the user pick — a
  silently chosen interpretation is a coin flip billed as work.
- See a simpler approach than what was asked? Say so BEFORE building the asked
  one. Pushback with a reason is a service; compliance with a flaw is not.
- Something unclear mid-implementation: stop, name precisely what is unclear,
  ask. "Powering through" confusion produces confident wrong code.

## Every changed line traces to the request

The one-question review for any diff: can each changed line be traced directly
to what the user asked? Lines that can't are scope creep wearing a diff:

- No "improving" adjacent code, comments, or formatting the request never
  mentioned. Match the file's existing style even where you'd choose
  differently — consistency beats preference in someone else's file.
- No refactoring things that aren't broken while passing through. Unrelated
  dead code, tempting renames, misaligned patterns: FLAG them (a sentence, a
  follow-up task), never fix them silently in the same change.
- The pipeline version of this rule is task-runner's scope lock; this is the
  same contract without the card.

## The orphan rule

Precise cleanup boundary — the part scope discipline usually gets wrong in
both directions:

- Orphans YOUR change created — imports now unused, variables now dead, a
  helper whose last caller you removed — are yours to delete in the same
  change. Leaving them is littering.
- Dead code that was ALREADY dead before your change is not yours to delete,
  however tempting — mention it and move on. Deleting it hides your actual
  change inside noise and turns a two-line review into an archaeology dig.
- Tests are orphans too: a test asserting behavior YOUR change removed gets
  updated or deleted with the change — but never weakened to pass while still
  pretending to assert the old behavior.
- The change direction of the same rule: before altering a shared symbol's
  signature or behavior, find its call sites (grep, IDE find-references) and
  update — or explicitly flag — every caller the change breaks. A caller you
  never looked for is a runtime break you shipped, not a cleanup you deferred.

## Simplicity floor

Minimum code that solves the stated problem:

- Nothing speculative: no config knobs, extension points, or "flexibility"
  the request didn't ask for — the yagni-check skill carries the full
  checklist; this is its inline reflex.
- No abstractions for single-use code; the second caller earns the
  abstraction, not the imagined one.
- No error handling for states that cannot occur — handling impossible
  errors is how 50-line functions become 200.
- The gut check: would a senior engineer reading this diff call it
  overcomplicated? If maybe, rewrite before showing it.

## Vague ask in, verifiable goal out

Transform the request before starting, not after finishing:

- "Add validation" → "these five invalid inputs get rejected with 422 —
  test proves it."
- "Fix the bug" → "this reproduction fails now, passes after" (the tdd skill
  in the testing plugin carries the red-green mechanics).
- "Refactor X" → "full suite green before AND after, diff shows no behavior
  change."

For multi-step work, a three-line plan with a verify per step beats a
paragraph of intent:

```
1. Extract totals into service   → verify: existing invoice tests green
2. Wire cron export to service   → verify: artisan export:run emits file
3. Delete inline duplicate       → verify: full suite green
```

Strong criteria let the loop run without hand-holding; "make it work" is a
criterion that outsources judgment back to the user one message at a time.
The work-verification skill governs the completion claim itself: evidence
before assertions, always.

## Anti-patterns

- Coding through an ambiguity you noticed and didn't raise.
- Silently picking one of two readings of the request.
- A diff where a third of the lines answer to nobody's request.
- Reformatting a file to make one edit — the change drowns in noise.
- Deleting pre-existing dead code inside an unrelated change.
- Leaving your own orphaned imports for the linter to complain about.
- Speculative parameters and single-implementation interfaces.
- Declaring done against "make it work" instead of a runnable check.
