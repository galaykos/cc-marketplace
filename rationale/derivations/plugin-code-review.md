# code-review hooks: the comment text moved out of the code (2026-10-26)

The text below was moved verbatim on 2026-10-26 from the files named in the `##` headings, with only each comment's `# ` leader removed; the lines each file kept are not repeated here. A pointer by name was left in each file, `# Why, limits, history: rationale/derivations/plugin-code-review.md § <heading>`. Standing: `recorded` — no gate reads this file, and its dates, measurements and citations are as they stood on the day it moved.

## plugins/code-review/hooks/review-debt.sh

### Header, THE RULE

Moved when the reminder stopped saying "Per-card reviews do not cover cross-card changes." (code-review 0.34.1): the clause spoke of task-runner cards to users who never ran task-runner.

```text
  - Both lines say per-card reviews do not cover cross-card changes: in a 2026-10-13
    session the model declined the nudge citing the per-card reviews of an unregistered
    run, and whole-branch passes in the same retro found defects no card's review could see.
```
