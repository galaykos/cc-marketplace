# secret-scanning

Blocks secrets before they reach disk.

- **PreToolUse hook** (`hooks/scan.sh`) — denies any `Write`/`Edit`/`MultiEdit` whose
  incoming text carries a high-confidence secret (cloud keys, private-key blocks,
  provider tokens, assigned secret literals). Fail-open: any error or a missing `jq`
  allows the write, so the guard never wedges a session.
- **`/secret-scanning:scan`** — sweeps a path, diff, or the whole repo for secrets
  already in the tree (what the write-time hook never saw).
- **`secret-scanning` skill** — the patterns, why a hook beats advice, remediation
  (rotate, don't just delete), and honest limits.

High-confidence by design: it under-flags rather than over-blocks, so pair it with a
full scanner (gitleaks, trufflehog) in CI. Obvious placeholders and fixtures pass; a
denial always offers the fixture escape.
