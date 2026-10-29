# ultra-deep-research scripts: the comment text moved out of the code (2026-10-28)

The text below was moved verbatim on 2026-10-28 from the file named in the `##` heading, with only each comment's `# ` leader removed; the lines the file kept are not repeated here. A pointer by name was left in the file's header, `# Why, limits, history: rationale/derivations/plugin-ultra-deep-research.md § <heading>`. Standing: `recorded` — no gate reads this file, and its citations are as they stood on the day it moved.

## plugins/ultra-deep-research/scripts/verdict-lint.sh

### Header

```text
verdict-lint.sh — mechanical format check over verifier verdict blocks.
Usage: verdict-lint.sh [file]   (reads stdin when no file is given)

Enforces the two invariants agents/verifier.md declares but nothing checked:
  confirmed  => FETCH carries a verbatim quote ("...") AND a retrieval timestamp
  confirmed  => CORROBORATION names a real source (present, not "none found"/"n/a")
  unverifiable-this-session => FETCH carries a failure reason (non-empty)
plus basic shape: CLAIM present, VERDICT one of the four values.

Exit 0: every block passes. Exit 1: violations (one line each on stdout).
Exit 2: no verdict block found at all.

Residual (honest limitation): this is a FORMAT check. It proves a confirmed
verdict carries quote+timestamp+corroboration fields — not that the quote is
real, the fetch happened, or the corroborating source is independent. Those
stay with the orchestrator's judgment and the verifier's own rules.
```

