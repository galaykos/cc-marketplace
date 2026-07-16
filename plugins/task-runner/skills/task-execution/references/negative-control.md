# Negative control — run-time red-before-green (B3b)

The inner loop accepts a card when its verify command exits 0. But a verify that passes
whether the code works or not proves nothing — the empty-suite-reports-PASS class of
false-green. Before a card flips to done, the negative control proves the verify actually
**discriminates** working code from broken code.

## The gate

After the card's verify passes and before the status flips, run:

```
${CLAUDE_PLUGIN_ROOT}/scripts/negative-control.sh --verify "<the card's exact verify>" --target <impl-file> --auto
```

It works entirely in an isolated temp copy — the live working tree is never mutated. It
applies a targeted disabling of the feature under test, re-runs the verify there, and
requires the result to go RED **by assertion failure**. Then it confirms the verify is GREEN
on the un-mutated copy and discards the temp.

## Exit codes and loop handling

| Exit | Meaning | Inner-loop action |
|------|---------|-------------------|
| 0 | discriminating — assertion-red on the disabled feature, green on the real one | record evidence, flip status to done |
| 2 | vacuous — verify stayed green even with the feature disabled | back into the SAME bounded 3-cycle loop: the verify has no teeth, sharpen it |
| 4 | invalid-control — the red was a build/collection/import error, not an assertion | back into the same loop: the mutation or verify is wrong, not the feature |
| 5 | isolation/restore failure | halt-with-evidence (do not flip; the gate could not run safely) |
| 3 | usage | fix the invocation |

A `vacuous` or `invalid-control` result consumes the card's existing 3-cycle budget — it does
NOT open a new loop. On the third failed cycle, halt the card as usual.

## Exemptions

- **Manual / visual verify lines** ("dialog renders centered") have no executable command to
  run red-then-green — skip the control with an explicit note in the evidence line; do not
  silently pass, and do not fabricate a control.
- **`--target` cannot be resolved** (the card names no single implementation file) — skip
  with a note and rely on the behavioral-gate + reviewer pass; record that the control was
  not applicable.

## Under ultra-goal (hands-off)

A `vacuous` result is NOT auto-taken. Under `Goal:`, a card that cannot pass the negative
control after its bounded budget **parks-and-stops** with evidence — the hands-off run does
not close a card whose verify has no teeth. `isolation-halt` (exit 5) always halts,
regardless of mode.
