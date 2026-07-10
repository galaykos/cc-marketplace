---
name: work-verification
description: Use before claiming any work is done — define success criteria up front, run the verification commands, show evidence, never assert without output.
---

## Define success criteria before starting work

Decide what "done" means *before* you write the code, not after, while you're motivated to
believe it already works. Success criteria should be concrete and checkable by someone who
didn't write the change:

- The exact command(s) that must succeed (`npm test`, `pytest tests/test_export.py`, `npm run
  lint`, a specific curl request and expected status code).
- The expected output or behavior, stated in advance — not "it should work" but "returns 200
  with `{ok: true}`" or "all 42 tests pass, 0 failed."
- Any manual check required (e.g., "clicking Export downloads a `.md` file containing the note
  title as an H1").

Writing these down first prevents the natural drift toward whatever the code happens to do
being retroactively declared correct.

## Evidence before assertion

**Never claim "it passes," "it works," or "tests are green" without having just run the command
and looked at its actual output in this session.** Memory of a similar change working before,
confidence in the code, or the fact that it "should" pass are not evidence. The only acceptable
basis for a completion claim is: you ran the exact command, and you are looking at output that
demonstrates the criterion was met.

```
# Not evidence — an assertion with nothing backing it:
"I've updated the function, so the tests should pass now."

# Evidence — command run, output shown, claim matches output:
$ npm test -- tags.test.ts
 PASS  services/tags.test.ts
  ✓ addTagToNote adds a new tag (4 ms)
  ✓ addTagToNote dedupes existing tag (2 ms)
  ✓ removeTagFromNote removes a tag (1 ms)
Tests: 3 passed, 3 total
"All 3 tests pass — output above."
```

If you haven't run the command yet, the correct claim is "not yet verified," not an optimistic
guess dressed up as a result.

## Exact-command + expected-output discipline

When reporting verification, state three things together, every time:

1. **The exact command run** (copyable, with any relevant flags/paths) — not a paraphrase.
2. **The actual output** (or the relevant excerpt of it — don't cherry-pick only the passing
   part if there were also warnings or skipped tests; report those too).
3. **How the output maps to the success criterion** — "criterion was 0 failed; output shows
   `Tests: 12 passed, 0 failed` — criterion met."

This discipline also applies to lint/type-check/build steps, not just tests — a green test
suite with a red type-checker is not "done."

## What to do when verification fails

- **Report the failure plainly**, with the same command + actual output discipline used for
  success. Don't soften a failing result into "mostly working" or bury it after a paragraph of
  unrelated context.
- **Don't re-run the same command hoping for a different result** without changing something —
  if it's flaky, say so explicitly and investigate the flakiness rather than retrying silently
  until green.
- **Don't narrow the check to dodge the failure** (e.g., switching from the full test suite to
  just the file you touched) unless that narrowing is disclosed and justified — silently
  shrinking scope to manufacture a pass is worse than reporting the original failure.
- **Fix or escalate, don't declare done anyway.** If the failure is out of scope for the current
  task (e.g., a pre-existing failing test unrelated to your change), name it explicitly as a
  known, pre-existing issue rather than silently ignoring it or claiming full success.

## Before / after

**Before:** "I refactored the export service and updated the tests. This should handle the
edge cases correctly now." (No command was run. "Should" is doing all the work.)

**After:** "Ran `npm test -- noteExporter.test.ts`: `Tests: 5 passed, 5 total`, including the
new empty-notes-array case. Ran `npm run lint`: `0 problems`. Both criteria from the task
(tests pass, lint clean) are met — output above."

## Checklist before claiming done

- [ ] Success criteria were written down (even informally) before or during the work, not
      invented after the fact to match whatever happened.
- [ ] The exact verification command(s) were actually run in this session.
- [ ] The actual output is visible and quoted, not summarized from memory.
- [ ] The output was compared line-by-line against the criterion, including warnings or partial
      failures that a quick skim might miss.
- [ ] Any failing or skipped check is named explicitly, not omitted from the report.
- [ ] If verification wasn't possible (e.g., no test harness exists), that limitation is stated
      plainly instead of substituting an assertion for evidence.

## Verification is proportional, not theatrical

This doesn't mean every one-line change needs a paragraph of ceremony — it means the *claim*
made should never exceed the *evidence* gathered. For a trivial fix, running the single
relevant test and quoting its result is enough. For a larger change, the criteria and commands
are correspondingly broader (full suite, lint, type-check, a manual smoke check). Scale the
rigor to the risk, but never skip straight to the conclusion.

## When to apply

Apply this before every claim of completion, in every task handoff, and especially before
committing, opening a PR, or telling a user something is fixed. It is the last gate before work
is considered done — treat "I verified it" as a claim that itself needs the command and output
to back it up.
