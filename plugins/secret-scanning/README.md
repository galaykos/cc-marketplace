# secret-scanning

Blocks secrets before they reach disk.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install secret-scanning@cc-plugins-marketplace
```

## What's included

- **PreToolUse hook** (`hooks/scan.sh`) — denies any `Write`/`Edit`/`MultiEdit` whose
  incoming text carries a high-confidence secret (cloud keys, private-key blocks,
  provider tokens, assigned secret literals). Fail-open: any error or a missing `jq`
  allows the write, so the guard never wedges a session.
- **`/secret-scanning:scan`** — sweeps a path, diff, or the whole repo for secrets
  already in the tree (what the write-time hook never saw).
- **`secret-scanning` skill** — the patterns, why a hook beats advice, remediation
  (rotate, don't just delete), and honest limits.

High-confidence by design: it under-flags rather than over-blocks, so pair it with a
full scanner (gitleaks, trufflehog) in CI. A matched value that announces itself as a
placeholder passes — it ends in `EXAMPLE` (AWS's own documentation convention,
`AKIAIOSFODNN7EXAMPLE`), is one character repeated (`xxxx…`, `0000…`), or carries a
placeholder word (`example`, `placeholder`, `changeme`, `your-`, `dummy`, `redacted`,
`sample`, `fake`). Until 0.5.0 that sentence was aspiration: the deny is unbounded and
has no allow-file, and the AWS example key matches the AKIA shape by construction, so a
fixture write was refused on every retry with no exit but a heredoc around the guard.
The test reads the VALUE only — `EXAMPLE_TOKEN=<real value>` still denies — and every
match in a write is checked, so a placeholder beside a real key still denies. Residual,
stated: a real secret that happens to contain one of those words passes.

Since 0.3.0 the deny path has its own fixture harness (`scripts/__tests__/`,
CI-globbed) — every pattern proven to deny, fail-open proven to stay open. Writing it
found and fixed a real regression: the private-key pattern begins with dashes, and
without `grep -- ` it had been parsed as options and NEVER matched. That deny is live
for the first time; the harness exists so a silent regression like it cannot ship
green again.
