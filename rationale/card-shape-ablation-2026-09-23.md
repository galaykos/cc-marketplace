# Card shape ablation — bold labels vs role tags, 2026-09-23

The question: does a task card written with role-named XML tags (`<goal>`,
`<facts>`, `<must>`, `<must-not>`, `<proof>`) get executed better than the same
card written with taskmaster's bold-label Markdown template? The hypothesis was that
tags "show intent" a bold label cannot.

## Method

One task, one fixture repo, two card texts with identical content and identical
wrapper prompt. Fresh `general-purpose` subagents on Haiku 4.5, four runs per arm,
dispatched concurrently. Haiku was chosen as the weakest reader available so a
format effect would be visible if one exists.

The fixture (`/tmp/card-sim`, not tracked) was a four-file Python package with a
baseline suite. The card asked for an extract-and-round refactor and carried five
deliberate traps:

- an exact cross-card signature that must not change (`<interface>`);
- a tempting out-of-scope bug fix in a sibling file (`<must-not>`);
- a project skill file the executor must read first, whose one checkable rule was
  `__all__` in every new module (`<skill>`);
- a public method that must become a pure delegation (`<criterion>`);
- a Verify line naming one specific test (`<verify>`).

Scored by script on seven binary checks: verify passes, full suite passes, the
out-of-scope file is untouched, the signature matches by AST, `__all__` present,
the method delegates with no arithmetic by AST, no stray files.

## Result

| arm | runs | 7/7 | miss |
|---|---|---|---|
| Markdown bold labels | 4 | 3 | one run never opened the skill file and omitted `__all__` |
| XML role tags | 4 | 4 | — |

All eight produced near-identical code. The single miss is one run in four with no
matching pattern in the other three, which this repository's own eval rule
(`CLAUDE.md`, "Three runs cannot separate a regression from a flake") says not to
read as a delta. One soft signal: three of four tagged runs quoted the skill's
"round once at the end" rule back in a docstring; one of four Markdown runs did.
The tagged `<skill>` element seems to raise that instruction's salience. It did not
change the code.

## What it says

- **The control arm passed.** Both cards stated every trap explicitly ("even though
  the fix is obvious", "exactly this signature"). Once the intent is in the words,
  the delimiter around them does not matter to the reader. Per this repo's eval
  doctrine, a case whose control passes cannot measure the treatment; this one
  measured that the trap phrasing works, not that tags do.
- **The reading side gains nothing measurable from tags.** Zero delta at N=4 on a
  weak model with a deliberately trapped card.
- **The authoring side is where the shape can earn its place**, and only if the
  structural rules become a script. A `<must-not>` without a `reason` attribute is
  visibly incomplete and a lint can refuse it; a bold "Out of scope:" line with no
  why is complete-looking prose nothing checks. That is what
  `plugins/taskmaster/scripts/card-shape-lint.sh` does, and why the shape shipped
  despite this result.

## What was not measured

- Whether an AMBIGUOUS Markdown card (a prohibition buried in a Context bullet with
  no "do not") fares worse than its tagged twin. That is the case where a reading
  delta could exist. Not run; the authoring gate was worth having regardless.
- Any model above Haiku. A stronger reader is expected to narrow, not widen, a
  reading delta.
- More than four runs per arm.

Standing of this record: `recorded`. Nothing re-runs it.
