---
name: tdd
description: Use when implementing a feature or fixing a bug and the change should be test-driven — the red-green-refactor loop (one failing test, watched failing for the right reason, minimum code to pass, refactor on green only), test lists as a burn-down plan, red-green regression proof for bug fixes, taskmaster acceptance criteria as failing tests, when TDD is the wrong tool, and the anti-patterns that fake the loop.
---

## The loop

Red, green, refactor — one behavior per pass, order non-negotiable:

1. **Red.** Write ONE test for the next behavior on the list. Run it and
   watch it fail.
2. **Verify the failure.** It must fail on the assertion — "expected X, got
   undefined" — not on an import error, a typo, or a broken fixture. A test
   that dies before reaching its assertion proves nothing about the
   behavior; repair the error and re-run until the failure is the one you
   meant.
3. **Green.** Write the minimum code that makes the test pass. Run it,
   watch it pass, and confirm the rest of the suite stayed green.
4. **Refactor.** Clean up on green only, re-running after each move.
5. Cross the behavior off. Next behavior, back to 1.

What to assert and which framework idioms to use live in
testing-best-practices; this skill is the workflow that produces the tests.

## Red is the point

A test never seen failing is unverified. It may pass vacuously — asserting
nothing, asserting a tautology, exercising a mock instead of the code — and
a vacuous test is worse than none, because it reports safety that does not
exist. The failing run is the only direct evidence the test CAN fail, which
is the only property that makes it worth keeping. Skipping red because "it
obviously fails" discards the single observation the discipline exists to
produce. Tests written after the implementation pass on their first run, so
that evidence is unobtainable — which is why after-the-fact tests, whatever
their coverage number, are not TDD.

## Green buys nothing extra

The minimum to pass often feels dumb — return the constant, handle the one
case, ignore the parameter. That feeling is correct, not a problem. If the
hardcoded return is wrong, the NEXT test on the list forces it out; if no
test on the list would ever force it out, either the list is missing a
behavior or the constant genuinely is the requirement. Generality is bought
with the next failing test, never with speculation — the yagni-check
discipline (code-architecture plugin) applied at test granularity. Building
the flexible version "while you're in there" produces untested branches by
definition, since no red test demanded them.

## Refactor includes the tests

On green, clean both sides: dedupe setup into factories and shared helpers,
extract builders, rename tests whose names drifted from what they assert.
Two hard lines:

- Never weaken an assertion to make a refactor pass. An assertion in the
  way of a refactor is either wrong (a previous cycle's bug — fix it as
  one) or right (the change alters behavior — it is not a refactor).
- Never add behavior during refactor. A new idea mid-cleanup goes on the
  test list and gets its own red test.

## The test list

Before the first test, jot the behaviors as a checklist: happy path, each
validation rule, each boundary, each failure mode. That is the plan — burn
it down one cycle per line. Cases discovered mid-cycle are appended to the
list, not folded into the current cycle; the test in front of you stays
about one behavior. The list is done when it is empty and no behavior you
would be embarrassed to lose is missing from the suite.

## Bug fixes: red-green regression proof

A bug fix ships with a test that fails on the unfixed code — that is the
definition of a regression test, and the failing run is its certificate.

- Fix not yet written: write the reproducing test first, watch it fail
  with the bug's symptom, then fix until green.
- Fix already written (or applied reflexively before testing): revert the
  fix, run the test — it MUST fail; restore the fix — it passes. A test
  that passes against the reverted code does not guard this bug; rewrite
  it until the revert turns it red.

Record the failing output, not just the final green — the same evidence
discipline as the task-runner plugin's task-execution skill: "verified"
with nothing attached is a claim, not evidence.

## Cycle size

Minutes, not hours. One behavior in, one green out. A red phase that drags
means the step was too big — back up, split the behavior into smaller
lines on the list, take the smallest. A test that is painful to write is
design feedback, not a testing problem: interfaces that are hard to drive
from a test are hard to drive from calling code.

## Taskmaster cards

A card's acceptance criteria ARE its test list. Before implementing the
card, translate each criterion into a failing test; the card is done when
all of them are green and each failing run was observed. A criterion that
cannot be phrased as a test is too vague to verify — halt and fix the card
first, the same rule task-execution applies to mis-specified tasks.

## When TDD is the wrong tool

- Exploratory spikes: when the solution's shape is unknown, spike freely
  without tests — then throw the spike away and TDD the real thing.
  Keeping the spike and back-filling tests is testing after with extra
  steps; "adapting it as reference" is the same thing in disguise.
- Pure glue and configuration with no logic to get wrong.
- Generated code owned by its generator.

The exemption list is short and does not include "too simple to test
first" — that phrase is how untested code ships. Simple code means the
test is cheap, not optional.

## Anti-patterns

- Tests written after the implementation, presented as TDD. Coverage, yes;
  evidence the tests work, no.
- Batching five red tests before writing any code. Failures stop pointing
  at one behavior, and the minimum-to-pass discipline collapses.
- Skipping the red run because "it obviously fails". Obvious is not
  observed.
- Going green on a failure never read — the test failed on a typo, the
  code got written, the test passes, and what it verifies is unknown.
- Asserting implementation details so the refactor step breaks green. The
  loop punishes this immediately; the fix is behavior-level assertions
  (testing-best-practices), not skipping refactors.
- Hardcoded returns that no later test forces out — the loop gamed from
  the inside. The missing entry belongs on the test list; add it.
- Deleting or skipping a red test to get to green. Red says the code is
  wrong; the test is innocent until the assertion itself is proven wrong.
