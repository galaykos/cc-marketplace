# Behavioral testing for skills — the baseline loop

A skill is a behavioral claim: "with this text loaded, the model acts
differently, and better." The repo's gates check structure (frontmatter, line
budgets, references resolving); none of them can check that claim. This loop
does, manually. Standing: **recorded** — nothing runs it for you, and saying
so is the point.

## The loop (TDD for documentation)

1. **RED — watch it fail without the skill.** Run the target scenario in a
   session WITHOUT the skill installed. Capture what the model actually does
   and, verbatim, how it justifies the behavior the skill exists to prevent.
   No failure to capture → the skill restates what the model already does —
   don't ship it; that is bloat with a trigger attached.
2. **GREEN — write the minimal skill that fixes the observed failure.** Address
   the recorded violations, not imagined ones. Re-run the same scenario with
   the skill loaded; the failure should not reproduce.
3. **REFACTOR — hunt the loopholes.** Vary the scenario (time pressure, sunk
   cost, an instruction that half-contradicts the skill) and record any new
   rationalization the model invents around the rule. Add the counter to the
   body, re-test. The verbatim rationalizations are the most valuable artifact
   — keep them in the test notes.

## Scenario design

- Test the trigger too: give the request that SHOULD fire the skill to a
  session where it is installed and see whether the description wins the
  dispatch. A skill that fires on the wrong prompts, or not at all, fails
  regardless of body quality.
- For discipline skills (rules the model is tempted to break under pressure),
  scenarios must include the temptation — a scenario with nothing at stake
  proves nothing.
- Keep scenarios re-runnable: a one-paragraph setup, the exact prompt, the
  expected behavior, the failure signature. Store them beside the skill or in
  the PR description.

## What this catches that nothing else does

Structural gates catch malformed skills; this catches USELESS ones — bodies
that restate model defaults, descriptions that lose every dispatch, rules the
model routes around. Those ship green through every script in this repo.
