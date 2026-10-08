# secret-scanning

Blocks secrets before they reach disk.

## What has teeth

| Rule | Standing |
|---|---|
| A `Write`/`Edit`/`MultiEdit`/`NotebookEdit`, or an MCP `create_new_file`/`apply_patch`, whose new text (for apply_patch, the whole patch; for NotebookEdit, the cell's `new_source`) matches a high-confidence secret pattern | **gate** — PreToolUse `permissionDecision: "deny"`; the write never happens |
| A `Bash` command that writes a file through a heredoc (`cat > config/aws.php <<'PHP'`, `cat <<EOF \| tee -a f`) or `echo`/`printf` (`echo "K=…" >> .env.example`), whose heredoc body or echo/printf arguments match the same patterns (since 0.9.0) | **gate** — same deny, same patterns, same placeholder escape, naming the file the command writes |
| The pattern set itself (which shapes count as high-confidence), held in `hooks/patterns.tsv`, the one source the write guard and the redaction mod both read | **recorded** — the marketplace repository's `rationale/derivations/plugin-secret-scanning.md` (§ `plugins/secret-scanning/hooks/scan.sh`) argues the non-provider rules and the placeholder exemption; `scripts/__tests__/scan-hook.test.sh` pins the behaviour, nothing pins the coverage |
| An unusable `hooks/patterns.tsv` (missing, CRLF, a malformed row, a pattern outside the regex dialect its header states) | **gate** — the write guard's one exception to fail-open: `scan.sh` denies every write it would scan, naming the file, the line and `CC_SECRET_SCAN=off`; `scan-hook.test.sh` runs each shape. The redaction mod logs it once and passes output through instead |
| Secrets in any tool's output, on Claude Code ≥ 2.1.291 — masked as `[REDACTED:<label>]`, or the result withheld (see Mods, below) | **gate** — `hooks/redact.ts`; `tests/redact.test.ts` runs under `claude plugin test` in CI (the marketplace repository's `scripts/mod-tests.sh`), so a regression in a tested case fails the build. A subagent's call is not tested (the test kit drops `agentId`) |
| A file attached with an `@` mention, or changed outside the session, whose text holds a secret, on Claude Code ≥ 2.1.291 | **gate** — the mod refuses the mention with a toast, and masks what the engine attaches either way; same tests, same CI step. A subagent's mention is not tested |
| A `Write`/`Edit`/`MultiEdit`/`NotebookEdit` whose new text carries `[REDACTED:`, on Claude Code ≥ 2.1.291 | **gate** — the mod refuses it, naming `CC_SECRET_REDACT=off`, so a redacted read written back cannot replace the real value; same tests, same CI step. Not refused through `Bash` or an MCP write tool |
| The mod and the write guard agree on what is a secret (one pattern file, two regex engines) | **gate** — `scripts/__tests__/pattern-parity.test.sh` runs one fixture set through `scan.sh` and the mod's matcher and fails on any disagreement it does not declare; it proves its fixtures, not every input, and its declared divergences (astral characters in a webhook tail, a NUL inside a key) are fixtures of their own |
| Invisible characters in a file this session wrote or read | **advisory** — `hooks/unicode-scan.sh` is a PostToolUse **warning**; it never blocks, once per file per session |
| A secret reaching a file through Bash any other way — an interpreter (`python open()`, `php file_put_contents`), `cp`/`mv` of a file that already holds one, `sed -i` replacement text, a here-string `<<<`, a `{ echo …; } > f` group, a `printf 'KEY=%s' value` pair the generic assigned-literal rule cannot join (a provider-shaped value still matches alone) — or a live key in a command that writes no file (`curl -H "Authorization: …"`) | **unenforceable here** — the guard reads only heredoc bodies and echo/printf arguments whose pipeline writes a file; `scan.sh`'s header `Misses:` line and its `cc_bash_write_chunks` `Misses:` line name each gap, and the marketplace repository's `rationale/derivations/plugin-secret-scanning.md` keeps why. `command-guard` owns destroying a live `.env`, not what enters a file |
| A secret introduced by an MCP server whose write tool uses key names this hook does not list | **unenforceable** — the extraction in `scan.sh` names the keys it knows (verified against the JetBrains MCP schema, 2026-09-14); a different server writes past it |
| Secrets already committed before this plugin was installed | **out of scope** — that is `/secret-scanning:scan`, a command you run, not a hook |

There is no allow-file: a refused write is refused on every retry (history: the marketplace repository's
`rationale/derivations/plugin-secret-scanning.md` § Header: PLACEHOLDER EXEMPTION (0.5.0)). The escapes it does have
are a value that announces itself as a placeholder (below) and, since 0.6.1,
`CC_SECRET_SCAN=off` for a session — named in the deny message itself, because an
off-switch documented only in a changelog is not reachable by the person it exists for.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install secret-scanning@cc-plugins-marketplace
```

## What's included

- **PreToolUse hook** (`hooks/scan.sh`) — denies any `Write`/`Edit`/`MultiEdit`/`NotebookEdit`,
  an MCP `apply_patch`/`create_new_file`, or (since 0.9.0) a `Bash`
  command whose heredoc body or `echo`/`printf` arguments land in a file, whose incoming
  text carries a high-confidence secret (cloud keys, private-key blocks, provider tokens,
  assigned secret literals, a credential embedded in a `postgres://`/`mysql://`/
  `mongodb://`/`redis://`/`amqp://`/`https://` URL, a Slack incoming-webhook URL).
  The Bash path exists because the host steers file writes through heredocs: in one
  measured session 233 of the main thread's 238 file writes went through Bash, and this
  guard saw none of them. Fail-open on every error but one: an unusable
  `hooks/patterns.tsv` (the single pattern source) denies every write it would scan,
  naming the file, the line and `CC_SECRET_SCAN=off`. `CC_SECRET_SCAN=off` disables it
  for a session.
- **PostToolUse hook** (`hooks/unicode-scan.sh`) — **warns**, never blocks, when a file
  this session wrote *or read* carries invisible characters — since 0.9.0 including up to
  8 files per `Bash` command that wrote them (redirect, `tee`, `sed -i`) under the
  project root: zero-width
  space/joiner/non-joiner, word joiner, soft hyphen, a mid-file BOM, the Unicode tag
  block, and the bidirectional overrides that make source display in an order different
  from the one it executes (the Trojan Source class, CVE-2021-42574), which get their
  own message. This is the one rule here whose subject the model cannot see, so no
  instruction substitutes for a scanner. Warn and PostToolUse on purpose: zero-width
  joiners are legitimate in emoji sequences and in Arabic, Persian and Indic text, and
  the interesting case is usually a file being READ, where blocking the read helps
  nobody. A leading BOM is an encoding and is exempt; homoglyphs are out of scope. Once
  per file per session. `CC_UNICODE_SCAN=off` (or `CC_REMIND=off`) disables it.
- **Hooks module** (`hooks/redact.ts`, Claude Code ≥ 2.1.291) — masks secrets in tool
  output and refuses a write carrying a mask; see Mods, below.
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

## Mods (Claude Code ≥ 2.1.291)

Since 0.11.0 the plugin also ships a hooks module, `hooks/redact.ts`, listed under
`modules` in `hooks/hooks.json` beside the classic hooks, which fire with or without it
(probed on CLI 2.1.282 and 2.1.291; older CLIs untested). With mods off in the host,
on a CLI below 2.1.287 (which loads no module), on 2.1.288-2.1.290, with
`CC_SECRET_REDACT=off`, or with the `/config` option `cc_secret_redact` off, the module
passes every call through and the classic hooks work exactly as before. On CLI 2.1.287
with mods on the module still registers its hook (the version check runs inside it), and
that CLI's own bug — a plugin's `tool.call` hook breaking Bash and file search in
worktree subagents, fixed in 2.1.288 — applies even with redaction switched off: upgrade
the CLI or turn mods off. An organization that sets `allowManagedModsOnly` refuses the
module and leaves only the classic guard (per the CLI's built-in sec-default mod
documentation, not measured). Each rule's
standing is in the table at the top.

- **Redaction.** Every tool's result — any tool, main loop and subagents, every string
  however nested — has each secret-pattern match outside the placeholder escape replaced
  by `[REDACTED:<label>]` (`[REDACTED:an AWS access key ID]`) before the model or the
  transcript sees it, using the write guard's `hooks/patterns.tsv`. A redacted result
  carries one line for the model naming the labels, saying the value is unchanged at its
  source and forbidding writing the placeholder back; a toast names the count and the
  labels, never a value.
- **Errors and attached context.** An errored result whose error text, stored result or
  attached context holds a secret is answered with a refusal carrying the redacted error
  text. Context a hook seated beneath this one attached is passed on verbatim (CLI 2.1.291
  skips a hook that edits it), so when that context holds a secret the call is answered with a
  refusal instead: its text is the result, redacted, plus a line naming the labels and
  `CC_SECRET_REDACT=off`; that context never reaches the model.
- **Write-back refusal.** A `Write`, `Edit`, `MultiEdit` or `NotebookEdit` whose new text
  carries `[REDACTED:` is refused, naming `CC_SECRET_REDACT=off`: writing the placeholder
  would replace the real secret on disk.
- **Failure.** Once the tool has run, a redaction that throws or overruns its time
  budget withholds the output with a refusal naming the failure and
  `CC_SECRET_REDACT=off`; the tool's effects stand.
- **`@` mentions** (since 0.12.0). A file named after an `@` in a prompt is read with no
  `tool.call`, so the redaction above never sees it. Two checks cover it. First the
  module reads the file itself, only the mentioned lines when the mention names some
  (`@.env#L3`; an offset or limit below 1 widens the scan), and when a pattern matches
  outside the placeholder escape it refuses the mention: nothing of the file reaches the
  prompt, and a toast names the file and labels, since the refusal's own reason goes only
  to the debug log. Claude can still `Read` the file, which the redaction masks. A file the
  module cannot read (missing, or over the 4 MiB a plugin may read) is left to the engine,
  and so to the second check. A scan that throws or overruns its budget refuses the
  mention, with a toast naming `CC_SECRET_REDACT=off`. **Gate** — `tests/redact.test.ts`,
  "@-mentions".
- **Attached files** (since 0.12.1). The text the engine attaches for a mentioned file
  (`file`, `already_read_file`) and for a file changed outside the session
  (`edited_text_file`) passes the same patterns on its way to the model: each match is
  masked as `[REDACTED:<label>]`, a line for the model names the labels and forbids writing
  them back, and a toast counts them. This catches what the first check cannot read: a file
  over 4 MiB, a notebook's decoded cells. The transcript keeps the engine's unmasked
  record; only the model's copy is masked. A redaction that fails after the file was read
  leaves the attachment out. **Gate** — `tests/redact.test.ts`, "attached files".

Residuals, stated:

- **Where it fails open.** A hook failure before the tool runs lets the call through
  and its output passes unredacted. An unusable `hooks/patterns.tsv` is logged once and
  every result then passes unredacted (the write guard denies instead). A
  withheld-output refusal that cannot return within the one-second grace of the hook's
  failure handler lets the result through. An unusable `hooks/patterns.tsv` also lets every `@` mention and
  attachment through unscanned.
- **Private keys.** A key body arriving without its `BEGIN` line in the same string — a
  `Read` with an offset, `tail`, a `Grep` hit inside a `.pem` — is never matched. A
  `BEGIN` literal in source code masks everything up to the next `END` literal in that
  string. A mask can name several labels joined by `, ` and can cover a large region.
- **Not scanned.** Object keys, so a value under a key such as `password` in a structured
  (non-text) result passes unless a provider pattern matches it alone; context a hook
  seated above this one attaches (a managed-settings hook, a mod loaded above it); a `Map`, `Set`, `Buffer` or class instance; a
  `base64` or `data` field holding strict base64 of a
  non-text type (a `Bash` `stdout` holding image data is masked as text instead).
- **Not matched.** The secret-access-key field of an AWS credentials CSV stays visible
  beside its masked key ID: it has no pattern of its own. NUL-interleaved UTF-16 text
  passes, though `scan.sh` denies writing it. An assigned literal whose name carries more
  than twelve `_`/`-` segments after its last keyword, or a segment over 64 characters
  between that keyword and the `:`/`=`, passes both the mod and `scan.sh`: the shared pattern bounds the name so JavaScript's
  regex stays linear.
- **Not refused.** A `[REDACTED:` token written through `Bash` or an MCP write tool.
- **Refused by mistake.** The same token in a file that quotes it on purpose — a spec, a
  test, this README — is refused too, even in a session that redacted nothing: the refusal
  reads the new text, not where it came from. Its reason says the token may have come from
  a redacted result; `CC_SECRET_REDACT=off` gets past it and also stops output redaction.
  Standing: **gate** — `tests/redact.test.ts` refuses all four tools with nothing redacted
  and pins the reason's full wording.
- **Untested.** Subagent calls (the test kit drops `agentId`) and the time-budget-overrun
  path end to end (only its refusal text is tested).
- **Signals.** The toast is transient; afterwards only the mask text and the model's note
  show that a result was redacted. The parity harness covers only its fixtures.
