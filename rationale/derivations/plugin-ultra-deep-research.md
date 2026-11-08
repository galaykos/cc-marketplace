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

## plugins/ultra-deep-research/scripts/sources-check.sh

Added 2026-11-07 (Process track PR3; `rationale/plugin-landscape-comparison-2026-10-31.md` rank 7, after
199-bio's citation check, which has no licence, so the idea was reimplemented and no code copied). The verifier's
rule 1 ("fetch the cited source THIS session") and the researcher's "only cite pages you actually opened" were prose.
The check reads the agent's own transcript: WebFetch `input.url` plus every URL in those calls' results, because
WebFetch reports a cross-host redirect in its result rather than following it. URLs are compared after dropping a
fragment, trailing punctuation and trailing slashes, and with http folded to https.

## plugins/ultra-deep-research/hooks/verify-return.sh

Added 2026-11-07 with sources-check.sh. SubagentStop fields used: `agent_type` (also the matcher), `agent_id`,
`agent_transcript_path`, `last_assistant_message`, as the hooks reference lists them (fetched 2026-11-07). A
SubagentStop block is exit 2 with the reason on stderr, the same as candor's gate. The reason is built inside the
fail-open `{ … } 2>/dev/null` block and printed after it; the first draft printed it inside, where it was swallowed.
The bound of two blocks per agent keeps an agent that cannot fetch a page from looping.
