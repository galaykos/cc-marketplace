# toolchain-experts: the comment text moved out of the code (2026-10-22)

The text below was moved verbatim on 2026-10-22 from the files named in the `##` headings, with only each comment's `# ` leader removed; the lines each file kept are not repeated here. A pointer by name was left in each file, `# Why, limits, history: rationale/derivations/plugin-toolchain-experts.md § <heading>`. Standing: `recorded` — no gate reads this file, and its dates, measurements and citations are as they stood on the day it moved.

## plugins/toolchain-experts/scripts/detect-analyzers.sh

### Header: why this exists

```text
WHY THIS EXISTS. rationale/stack-skill-baselines.md measured four
best-practice checklists for these same stacks at zero-to-negative delta
against a blind control: restating public documentation is what a model
already does. What a blind model has no route to is the project's OWN
configuration — which analyzer is authoritative, what its baseline already
forgives, and which rules are switched off. This script emits that, so an
expert agent grades against the project instead of against memory.
```
