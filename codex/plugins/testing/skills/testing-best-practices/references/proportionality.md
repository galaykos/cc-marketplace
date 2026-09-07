# Test proportionality — how much suite is the right amount

**Standing: agent-graded.** No script measures this. A test-count gate would be the
percentage-chasing this skill already rejects, one level up. What follows is a
judgment aid for review, and the honest residual is that a reviewer has to apply it.

## The failure this exists for

Every surface that touches tests pushes the count UP — a verify command per card, a
negative control that proves the verify goes red, a behavioural gate, a coverage check
that flags an unproven criterion. Each is right on its own. Nothing anywhere pushes
back, and nobody measures the total.

Measured on one 30-card feature run, against the same repository's existing features:

| Metric | The repo's own features | The run | Overshoot |
|---|---|---|---|
| test : code | 0.78–1.31 : 1 | 3.44 : 1 | ~3x |
| tests per integration | 65 (a registrar API) | 520 (an OAuth + 2 APIs) | 8x |
| comment lines inside test files | — | 3,423 (23% of test lines) | — |

Part of that was legitimate: the new integration genuinely carried OAuth, a state
machine, a queued poll and five write endpoints against three read methods. Not 8x
worth. Each card's agent optimised locally, every gate passed green, and the aggregate
was first looked at when a human asked.

## Where the fat actually is, in order

1. **Prose inside test files.** A test should be readable from its name and its
   arrange/act/assert shape. A paragraph explaining what the test proves is a name
   that lost an argument. Cheapest cut available, zero coverage loss.
2. **Duplicate-layer assertions.** The same rule proved at the action, again at the
   controller, again in the browser. Pick the layer where the bug would actually
   escape — usually the endpoint for an authorization rule, the unit for a
   calculation — and prove it once. The others test the framework.
3. **Exhaustive datasets standing in for representative ones.** A 16-row
   normalisation table where 3 rows cover the classes (empty, typical, the one
   pathological case); an 11x5 sweep that raises 55 assertions about one rule.
4. **Tests that restate the spec.** If the card said it and the test asserts the same
   sentence in code, the test proves the developer read the card.

## What to protect, explicitly

A test that exists **because a mutation or a real defect proved the suite missed it**
is not fat, whatever the ratio says. Deleting it re-opens a confirmed bug. When
trimming, separate these first and put them beyond discussion — on the run above,
roughly 25 of the tests were in this class.

Regression tests for shipped incidents are the same case. So is any test whose
deletion would silence the only proof of a security boundary.

## The decision, in one question

For each test being considered: **if this behaviour broke, which test tells me first,
and would any other test also fail?** The first one is the test to keep. Tests that
would only fail alongside it are the duplicate layer, and they cost review attention
and CI minutes forever to re-prove something already proven.

## Deleting tests is the user's call

Never delete tests to hit a ratio — the same rule the comment-discipline skill states
about comments, for the same reason. Produce the list, name what each test proves and
which other test already proves it, and let the owner decide. A ratio is a prompt to
look, never a licence to cut.
