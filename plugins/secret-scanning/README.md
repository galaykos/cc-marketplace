# secret-scanning

Blocks secrets before they reach disk.

## What has teeth

| Rule | Standing |
|---|---|
| A `Write`/`Edit`/`MultiEdit`/`NotebookEdit`, or an MCP `create_new_file`/`apply_patch`, whose new text matches a high-confidence secret pattern | **gate** — PreToolUse `permissionDecision: "deny"`; the write never happens |
| The pattern set itself (which shapes count as high-confidence) | **recorded** — `hooks/scan.sh`'s header argues each one; `scripts/__tests__/scan-hook.test.sh` pins the behaviour, nothing pins the coverage |
| Invisible characters in a file this session wrote or read | **advisory** — `hooks/unicode-scan.sh` is a PostToolUse **warning**; it never blocks, once per file per session |
| A secret written through a shell heredoc (`cat > .env <<EOF`) | **unenforceable here** — no file-write tool is involved, so no PreToolUse matcher sees it. `command-guard` classifies the command, not its content |
| A secret introduced by an MCP server whose write tool uses key names this hook does not list | **unenforceable** — the extraction in `scan.sh` names the keys it knows (verified against the JetBrains MCP schema, 2026-09-14); a different server writes past it |
| Secrets already committed before this plugin was installed | **out of scope** — that is `/secret-scanning:scan`, a command you run, not a hook |

There is no allow-file, deliberately: `hooks/scan.sh` explains why a
per-repo exception list is the wrong shape for this guard. The escapes it does have
are a value that announces itself as a placeholder (below) and, since 0.6.1,
`CC_SECRET_SCAN=off` for a session — named in the deny message itself, because an
off-switch documented only in a changelog is not reachable by the person it exists for.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install secret-scanning@cc-plugins-marketplace
```

## What's included

- **PreToolUse hook** (`hooks/scan.sh`) — denies any `Write`/`Edit`/`MultiEdit`/
  `NotebookEdit`, or an MCP `apply_patch`/`create_new_file`, whose incoming text
  carries a high-confidence secret (cloud keys, private-key blocks, provider tokens,
  assigned secret literals). Fail-open: any error or a missing `jq` allows the write,
  so the guard never wedges a session. `CC_SECRET_SCAN=off` disables it for a session.
- **PostToolUse hook** (`hooks/unicode-scan.sh`) — **warns**, never blocks, when a file
  this session wrote *or read* carries invisible characters: zero-width
  space/joiner/non-joiner, word joiner, soft hyphen, a mid-file BOM, the Unicode tag
  block, and the bidirectional overrides that make source display in an order different
  from the one it executes (the Trojan Source class, CVE-2021-42574), which get their
  own message. This is the one rule here whose subject the model cannot see, so no
  instruction substitutes for a scanner. Warn and PostToolUse on purpose: zero-width
  joiners are legitimate in emoji sequences and in Arabic, Persian and Indic text, and
  the interesting case is usually a file being READ, where blocking the read helps
  nobody. A leading BOM is an encoding and is exempt; homoglyphs are out of scope. Once
  per file per session. `CC_UNICODE_SCAN=off` (or `CC_REMIND=off`) disables it.
- **`/secret-scanning:scan`** — sweeps a path, diff, or the whole repo for secrets
  already in the tree (what the write-time hook never saw).
- **`secret-scanning` skill** — the patterns, the placeholder escape the deny message
  offers, remediation (rotate, don't just delete), and honest limits.

High-confidence by design: it under-flags rather than over-blocks, so pair it with a
full scanner (gitleaks, trufflehog) in CI. A matched value that announces itself as a
placeholder passes — it ends in `EXAMPLE` (AWS's own documentation convention,
`AKIAIOSFODNN7EXAMPLE`), is one character repeated, or carries a
placeholder word (`example`, `placeholder`, `changeme`, `your-`, `dummy`, `redacted`,
`sample`, `fake`, `todo`, `xxxx`). The repeated-character form is narrower than it
reads and this line used to claim otherwise: it tests the WHOLE matched value, so
`SECRET=` plus a run of zeros passes while `AKIA` plus sixteen zeros denies — the
provider prefix is part of the match and breaks the repetition. Measured 2026-09-15;
for a provider shape, use a word. Until 0.5.0 that sentence was aspiration: the deny was unbounded,
there was no allow-file and no off-switch, and the AWS example key matches the AKIA
shape by construction, so a fixture write was refused on every retry with no exit but a
heredoc around the guard.
The test reads the VALUE only — `EXAMPLE_TOKEN=<real value>` still denies — and every
match in a write is checked, so a placeholder beside a real key still denies. Residual,
stated: a real secret that happens to contain one of those words passes.

Since 0.3.0 the deny path has its own fixture harness (`scripts/__tests__/`,
CI-globbed) — every pattern proven to deny, fail-open proven to stay open. Writing it
found and fixed a real regression: the private-key pattern begins with dashes, and
without `grep -- ` it had been parsed as options and NEVER matched. That deny is live
for the first time; the harness exists so a silent regression like it cannot ship
green again.
