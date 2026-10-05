---
name: systematic-debugging
description: Use when asked to debug, or facing a bug, crash, stack trace, failing test or unexpected behavior, BEFORE proposing or applying a fix — reproduce, read the FIRST error, one hypothesis one experiment, bisect, verify against the original repro.
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
- The command checks the symptom the user reported — the wrong value, the
  exact message — not "exits non-zero" and not a different failure nearby. Run
  it once and keep its output. No test reaches the bug → the cheapest loop
  that does still asserts that symptom.
- Flaky reproduction is a finding, not a blocker: narrow it (fixed seed,
  frozen time, forced ordering) until it fails on demand. Too rare to narrow →
  raise the failure rate first (loop it, add load); that is a step toward the
  on-demand repro, never a substitute for it.
- Not reproducible at all → gather evidence (logs, inputs, timings); do not
  advance to fixes on a bug you cannot summon.

Then shrink the repro: cut one input, caller or config value per run until any
further cut turns it green; a payload too big to cut piece by piece is halved,
as bisection below does. Keep the unshrunk command too — it is the original
repro the fix is verified against; the shrunk one is what graduates into the
regression test. Standing: recorded.

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

## State-changing moves need the same diagnosis

A restart, a cache wipe, a reinstall, a config edit: each is a fix attempt wearing
a chore's clothes, and each destroys evidence — the hung process, the poisoned
entry — that no rerun recovers. A signal that pattern-matches a known failure
("this always means the cache") may have a different cause this time. Check that
the evidence supports THIS action against THIS cause, as Phase 4 demands of a code
fix; run blind under fire only after recording what it will destroy, and label the
outcome a symptom fix.

## Phase 3 — what changed?

Bugs rarely materialize in untouched code. Before theorizing, diff reality:

- `git log` / `git diff` since the last known-good state — including commits
  that look unrelated.
- Dependency movement: lockfile diffs, transitive updates, CI image bumps.
- Config and environment: env vars, feature flags, credentials, data shape.

"It worked yesterday" plus an honest changelog is often the whole diagnosis.

## Phase 4 — one hypothesis, stated so it can die

First list the rival explanations the evidence still allows and the observation
that would separate them — a lone candidate is the one you anchor on. Then pick
one to test; listing rivals is not testing them. Standing: recorded.

Write ONE falsifiable sentence: "X is the root cause because Y; if true, Z
must be observable." Not "something with caching". If no observation could
disprove it, it is a mood, not a hypothesis.

Then design the smallest experiment that can kill it: a log line at the
suspect boundary, a debugger breakpoint, a five-line repro script, a query run
by hand. An experiment is NOT a fix attempt — it changes your knowledge, not
the code's behavior. Tag every probe you add with one unique prefix for the
investigation (`[DEBUG-a4f2]`): cleanup is then a single grep, and an untagged
probe is the one that ships. A loop that needs a credential reads it from the
environment, so the secret never lands in the transcript, and what you quote back
is the few response lines that matter — never the headers.

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

List every caller of the function the fix touches: a guard at the reported call site
repairs one path. When every listed caller wants the corrected behavior, fix the function
they share; otherwise fix the reported path and name the callers left unfixed. When the
callers cannot be listed (an exported API, dynamic dispatch), fix the reported path and
say so in the report. Listing is reading, not fixing: the change stays minimal, and a
shared fix that needs a decision you were not given is reported with its options, not made.
Standing: recorded.

Verification is three-part, all mandatory:

1. The ORIGINAL Phase 1 reproduction now passes — not a related test, not a
   re-description of it, the exact one.
2. The full suite passes — the fix broke nothing else.
3. `grep` for the investigation's `[DEBUG-…]` prefix returns nothing — every probe
   is gone. Standing: recorded; no hook runs the grep, so a survivor is yours to find.

Then the shrunk reproduction graduates into the suite as a permanent regression test.
A bug that got in once has proven the road exists. Put the test where the bug's
real call pattern replays — the callers and order that produced it, not only the
function the fix touched. When only a shallower seam is reachable, ship the test
there and report the missing seam as a structural finding: the test cannot fail
on the original path, so nothing guards that path yet. Standing: recorded.

## Three failed fixes → question the level

The task-runner park rule, applied to diagnosis: after three fix cycles that
did not hold, stop. The problem is no longer the bug; it is your model of the
bug. A blind fourth attempt is where corruption starts — deleted assertions,
weakened checks, plausible-sounding fiction.

Ask, in order: wrong layer (patching the caller when the callee lies)? wrong
component (the "obviously broken" one is fine)? wrong assumption (the
invariant nobody ever tested)? Re-enter Phase 1 with the failed fixes as new
evidence, or escalate with a report of what was tried and ruled out. When the
approaches plugin is installed, `/approaches:consult` is that escalation made
cheap — it accepts a stuck-debug brief from the SECOND failed cycle, one
earlier than this hard stop, so consider it before the third attempt, not
after.

## Defense in depth — after, never instead

Input validation, tighter types, better error messages, retries: worth adding
once the root cause is fixed, as insurance around it. Added INSTEAD of a
root-cause fix they are camouflage — the bug remains, now harder to see.

## The report

Name which kind of fix shipped; never let one impersonate the other:

- **Cause fix**: root cause stated, with the evidence chain — repro →
  experiments → diagnosis → fix → verification output — the callers left
  unfixed or unlistable, and any missing regression seam.
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
