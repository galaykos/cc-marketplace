---
name: systematic-debugging
description: Use when facing any bug, failing test, or unexpected behavior, BEFORE proposing or applying a fix — enforces root-cause-first discipline: reproduce deterministically, read the actual error (the first one, not the last), check what changed, run one-hypothesis-one-experiment cycles, bisect when hypotheses run out, and verify the fix against the original reproduction plus the full suite. Three failed fix cycles trigger a stop-and-requestion rule instead of a fourth attempt.
---

## The iron law

No fix before root cause. A fix without a diagnosis is a guess wearing a
commit message — the symptom may vanish, but you don't know what you changed,
whether the bug will return, or what broke instead. Everything below exists to
make that guess impossible to ship.

The law binds hardest exactly when breaking it is most tempting: production is
down, the fix "seems obvious", two attempts already failed. Systematic is
faster than thrashing; it only feels slower.

## Phase 1 — reproduce deterministically

A bug you can't reproduce isn't fixed, it's dormant.

- Find the exact input, steps, and environment that trigger the failure every
  time — versions, data, config, seed, clock, whatever it could depend on.
- Script it when at all possible: one command that fails now and must pass
  later. That script is the yardstick every candidate fix is measured against,
  and the seed of the regression test.
- Flaky reproduction is a finding, not a blocker: narrow it (fixed seed,
  frozen time, forced ordering) until it fails on demand.
- Not reproducible at all → gather evidence (logs, inputs, timings); do not
  advance to fixes on a bug you cannot summon.

## Phase 2 — read the ACTUAL error

Read the message verbatim, not the shape of it. The text, the stack trace, the
line numbers routinely name the answer that ten minutes of guessing will miss.

- In a cascade, the FIRST error is the cause; the last is just the loudest
  survivor. Scroll up. A wall of type errors after a broken import starts at
  the import.
- Separate what the error says from what you assume it means. "Connection
  refused" says nothing about your query.
- Quote the exact text in notes and report — a paraphrased error smuggles in
  interpretation.

## Phase 3 — what changed?

Bugs rarely materialize in untouched code. Before theorizing, diff reality:

- `git log` / `git diff` since the last known-good state — including commits
  that look unrelated.
- Dependency movement: lockfile diffs, transitive updates, CI image bumps.
- Config and environment: env vars, feature flags, credentials, data shape.

"It worked yesterday" plus an honest changelog is often the whole diagnosis.

## Phase 4 — one hypothesis, stated so it can die

Write ONE falsifiable sentence: "X is the root cause because Y; if true, Z
must be observable." Not "something with caching". If no observation could
disprove it, it is a mood, not a hypothesis.

Then design the smallest experiment that can kill it: a log line at the
suspect boundary, a debugger breakpoint, a five-line repro script, a query run
by hand. An experiment is NOT a fix attempt — it changes your knowledge, not
the code's behavior.

- Hypothesis survives → tighten it and test again until it is a diagnosis.
- Hypothesis dies → progress. Form the next one from what the experiment
  showed; never stack a fix on top of a dead hypothesis.

One variable at a time, always. Shotgun fixes — change five things, rerun —
destroy the evidence: even when the symptom disappears you have learned
nothing, and four of the five changes are now unexplained mutations.

## When hypotheses run out: bisect

Stop theorizing and binary-search the space instead:

- `git bisect` between known-good and known-bad commits, driven by the Phase 1
  repro script.
- Bisect the input: half the failing payload, half the config, half the test
  file — whichever half still fails contains the bug.
- Bisect the stack: swap a suspect component for a known-good stub; the
  failure either survives (bug is elsewhere) or dies (you have surrounded it).

Bisection is mechanical and O(log n); it works precisely when insight is dry.

## The fix — justified, then verified

The fix must follow FROM the diagnosis: "the root cause is A, therefore the
change is B", stated so a reviewer nods. If the fix does not obviously follow,
the diagnosis is not finished.

Verification is two-part, both mandatory:

1. The ORIGINAL Phase 1 reproduction now passes — not a related test, not a
   re-description of it, the exact one.
2. The full suite passes — the fix broke nothing else.

Then the reproduction graduates into the suite as a permanent regression test.
A bug that got in once has proven the road exists.

## Three failed fixes → question the level

The task-runner park rule, applied to diagnosis: after three fix cycles that
did not hold, stop. The problem is no longer the bug; it is your model of the
bug. A blind fourth attempt is where corruption starts — deleted assertions,
weakened checks, plausible-sounding fiction.

Ask, in order: wrong layer (patching the caller when the callee lies)? wrong
component (the "obviously broken" one is fine)? wrong assumption (the
invariant nobody ever tested)? Re-enter Phase 1 with the failed fixes as new
evidence, or escalate with a report of what was tried and ruled out.

## Defense in depth — after, never instead

Input validation, tighter types, better error messages, retries: worth adding
once the root cause is fixed, as insurance around it. Added INSTEAD of a
root-cause fix they are camouflage — the bug remains, now harder to see.

## The report

Name which kind of fix shipped; never let one impersonate the other:

- **Cause fix**: root cause stated, with the evidence chain — repro →
  experiments → diagnosis → fix → verification output.
- **Symptom fix**: pressure relieved, cause still at large — list what was
  ruled out and what investigation remains. Legitimate under fire, dishonest
  when unlabeled.

## Anti-patterns

- Fixing without reproducing — you cannot verify what you cannot trigger.
- Reading the last error instead of the first; debugging the cascade's tail.
- Stacking multiple changes per attempt, then guessing which one "worked".
- "It works now" without knowing why — the bug is scheduling its comeback.
- Deleting or skipping the failing test to make the build green.
- Blaming the framework, compiler, or library before your own diff — the bug
  is in your code, statistically, near-always.
- Bolting on validation and retries as a substitute for a diagnosis.
