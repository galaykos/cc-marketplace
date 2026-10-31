# secret-scanning

Blocks secrets before they reach disk.

## What has teeth

| Rule | Standing |
|---|---|
| A `Write`/`Edit`/`MultiEdit`/`NotebookEdit`, or an MCP `create_new_file`/`apply_patch`, whose new text (for apply_patch, the whole patch; for NotebookEdit, the cell's `new_source`) matches a high-confidence secret pattern | **gate** — PreToolUse `permissionDecision: "deny"`; the write never happens |
| A `Bash` command that writes a file through a heredoc (`cat > config/aws.php <<'PHP'`, `cat <<EOF \| tee -a f`) or `echo`/`printf` (`echo "K=…" >> .env.example`), whose heredoc body or echo/printf arguments match the same patterns (since 0.9.0) | **gate** — same deny, same patterns, same placeholder escape, naming the file the command writes |
| The pattern set itself (which shapes count as high-confidence), held in `hooks/patterns.tsv`, the one source the write guard and the redaction mod both read | **recorded** — the marketplace repository's `rationale/derivations/plugin-secret-scanning.md` (§ `plugins/secret-scanning/hooks/scan.sh`) argues the non-provider rules and the placeholder exemption, and § `plugins/secret-scanning/hooks/patterns.tsv` names the gitleaks rules the provider rows follow (since 0.15.7); `scripts/__tests__/scan-hook.test.sh` pins the behaviour, nothing pins the coverage |
| An unusable `hooks/patterns.tsv` (missing, CRLF, a malformed row, a pattern outside the regex dialect its header states) | **gate** — the write guard's one exception to fail-open: `scan.sh` denies every write it would scan, naming the file, the line and `CC_SECRET_SCAN=off`; `scan-hook.test.sh` runs each shape. The redaction mod logs it once and passes output through instead |
| Secrets in any tool's output, on Claude Code ≥ 2.1.291 — masked as `[REDACTED:<label>]`, or the result withheld (see Mods, below) | **gate** — `hooks/redact.ts`; `tests/redact.test.ts` runs under `claude plugin test` in CI (the marketplace repository's `scripts/mod-tests.sh`), so a regression in a tested case fails the build. A subagent's call is not tested (the test kit drops `agentId`) |
| A file attached with an `@` mention, or changed outside the session, whose text holds a secret, on Claude Code ≥ 2.1.291 | **gate** — the mod refuses the mention with a toast, and masks what the engine attaches either way; same tests, same CI step. A subagent's mention is not tested |
| A secret typed or pasted into the prompt box, on Claude Code ≥ 2.1.291 | **gate** for the decision: the mod paints it in the draft, and at submit asks Mask and send / Send as typed / Cancel, masking when nobody can answer. A slash command's arguments cannot be masked, so a command holding a secret is offered only Send as typed / Cancel and dropped otherwise (`tests/redact.test.ts`, "prompt box"). **Recorded**: the masked text, not the secret, is what reached the API in a live probe on 2.1.294 (marketplace repository `rationale/2026-10-08-secret-scanning-prompt-guard-probe.md`). Below 2.1.300 the host's changelog says its session-title request still carried the prompt as typed; the residuals below give each CLI version's gap |
| A `Write`/`Edit`/`MultiEdit`/`NotebookEdit` whose new text carries `[REDACTED:`, on Claude Code ≥ 2.1.291 | **gate** — the mod refuses it, naming `CC_SECRET_REDACT=off`, so a redacted read written back cannot replace the real value; same tests, same CI step |
| A `Bash` heredoc body or `echo`/`printf` argument carrying `[REDACTED:` that lands in a file (since 0.14.0), on any CLI, with or without mods | **gate** — `scan.sh` refuses it the same way unless `CC_SECRET_REDACT` is `off`, `0` or `false`; `scan-hook.test.sh` runs both write shapes, a command writing no file, stdout only and the off switches. Not refused: an MCP write tool, and the Bash writes the guard cannot read (`sed -i` text, interpreters, `cp`/`mv`; the "through Bash any other way" row below) |
| The mod and the write guard agree on what is a secret (one pattern file, two regex engines) | **gate** — `scripts/__tests__/pattern-parity.test.sh` runs one fixture set through `scan.sh` and the mod's matcher and fails on any disagreement it does not declare; it proves its fixtures, not every input, and its declared divergences (astral characters in a webhook tail, a NUL inside a key) are fixtures of their own |
| Invisible characters in a file this session wrote or read | **advisory** — `hooks/unicode-scan.sh` is a PostToolUse **warning**; it never blocks, once per model context (a session's main thread, each subagent) and file, again only when the file's invisible characters change, including past the six it names (`unicode-scan.test.sh` pins each) |
| A secret a Bash python, node, php, ruby, perl, deno, bun, cp, mv, install or patch run put in a file of a git repo (since 0.15.0) | **advisory** — the same `scan.sh`, registered on PostToolUse too (and on PostToolUseFailure for Bash, the event a command that exits non-zero fires), **warns** after the fact, naming the file and the pattern; it cannot deny, because the write has landed. It reads what each file git reports changed since the lane's previous call added: the whole file when HEAD lacks it, else its `+` lines against HEAD, so a line any uncommitted edit added is judged again. `scan-hook.test.sh` runs a python write, the first call in a repo, a run that wrote nothing, a placeholder, an Edit between two runs, a failed run and another session's marker. Misses: a writer it does not name (`npx prettier --write`, `make`, `git apply`), gitignored files, no git, a submodule's files, anything under `.claude/`, a file written then reverted, a `mv` or `cp -p` destination that keeps an older mtime, files past the eighth, text past 1 MiB per file, the first such run of each session (the marker holds the session's cksum; another session's reads as none); a `$HOME` root or a repo with `status.showUntrackedFiles=no` reads nothing; and anything else that changed a file since the lane's previous call (an IDE, a parallel agent) reads as this run's write |
| A secret reaching a file through Bash any other way — an interpreter or `cp`/`mv` before the write lands (the row above warns after it), `sed -i` replacement text, a here-string `<<<`, a `{ echo …; } > f` group, a `printf 'KEY=%s' value` pair the generic assigned-literal rule cannot join (a provider-shaped value still matches alone) — or a live key in a command that writes no file (`curl -H "Authorization: …"`) | **unenforceable here** — the guard reads only heredoc bodies and echo/printf arguments whose pipeline writes a file; `scan.sh`'s header `Misses:` line and its `cc_bash_write_chunks` `Misses:` line name each gap, and the marketplace repository's `rationale/derivations/plugin-secret-scanning.md` keeps why. `command-guard` owns destroying a live `.env`, not what enters a file |
| A secret introduced by an MCP server whose write tool uses key names this hook does not list | **unenforceable** — the extraction in `scan.sh` names the keys it knows (verified against the JetBrains MCP schema, 2026-09-14); a different server writes past it |
| Secrets already committed before this plugin was installed | **out of scope for the hooks** — that is `/secret-scanning:scan`, a command you run. Its scanner, `scripts/scan-range.sh <base>..HEAD \| --cached \| <path>…` (since 0.15.0), applies `hooks/patterns.tsv` through the write guard's own reader (`hooks/patterns.sh`) to the lines a range or the index added or to whole files, prints `file:line label` with the value masked and exits 1 on a match: **gate** for what it reports (`scan-range.test.sh` in CI) and wherever a CI step runs it, which nothing here wires. **Recorded**: that the command runs it before reading anything itself. Misses: a secret split across lines, a shape `patterns.tsv` does not list, a removed line still in history, binary files |

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
  for a session. Since 0.15.0 the same script also runs on PostToolUse: after a Bash
  interpreter, `cp`, `mv`, `install` or `patch` run it **warns** — never denies, the write
  has landed — on a secret in what each file git reports changed added (the "What has
  teeth" row above names how and what it misses). Its marker lives in the plugin's data
  dir, else under `<repo>/.claude/secret-scanning/` behind a `*` `.gitignore`.
- **PostToolUse hook** (`hooks/unicode-scan.sh`) — **warns**, never blocks, when a file
  this session wrote *or read* carries invisible characters — since 0.9.0 including up to
  8 files per `Bash` command that wrote them (redirect, `tee`, `sed -i`) under the
  project root (since 0.15.0 a relative one after a `cd`/`pushd` outside heredoc bodies is
  skipped: it was read against the session cwd, the wrong file), and since 0.15.0 up to 8 files a python, node, php, ruby, perl,
  deno, bun, cp, mv, install or patch run changed in git, each read whole
  (the misses the "What has teeth" interpreter row names): zero-width
  space/joiner/non-joiner, word joiner, soft hyphen, a mid-file BOM, the Unicode tag
  block, and the bidirectional overrides that make source display in an order different
  from the one it executes (the Trojan Source class, CVE-2021-42574), which get their
  own message. This is the one rule here whose subject the model cannot see, so no
  instruction substitutes for a scanner. Warn and PostToolUse on purpose: zero-width
  joiners are legitimate in emoji sequences and in Arabic, Persian and Indic text, and
  the interesting case is usually a file being READ, where blocking the read helps
  nobody. A leading BOM is an encoding and is exempt, and so is a lone BOM leading a line,
  or a tab-separated field, of a `*.log` file (where a CI step's output starts; since
  0.15.0); homoglyphs are out of scope. Once per model context — the main thread and each
  subagent, told apart by `agent_id` — and file, again only when the file's invisible
  characters change (since 0.15.0); every context that reads the hidden text is told. `CC_UNICODE_SCAN=off` (or `CC_REMIND=off`) disables it.
- **Hooks module** (`hooks/redact.ts`, Claude Code ≥ 2.1.291) — masks secrets in tool
  output and refuses a write carrying a mask; see Mods, below.
- **`/secret-scanning:scan`** — sweeps a path, diff, or the whole repo for secrets
  already in the tree (what the write-time hook never saw). It runs
  `scripts/scan-range.sh` first, so the pattern pass is the hook's `patterns.tsv`, read
  by the hook's own loader, not patterns the model recalls; with nothing named it scans
  the staged lines (`--cached`) when something is staged, then layers the review-time
  suspicions on top.
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
  would replace the real secret on disk. Since 0.14.0 `scan.sh` refuses the same marker in a
  Bash heredoc or `echo`/`printf` written to a file. So a whole-file rewrite of a file that
  holds a masked value (a `.env.example` with a real-looking key, a JWT test fixture) is
  refused either way; an `Edit` whose `old_string` and `new_string` leave the masked line
  out still works.
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

- **The prompt box** (since 0.13.0; `cc_secret_prompt` / `CC_SECRET_PROMPT`, default on).
  - **Painting.** While you type, `prompt.edit` paints each secret-pattern match in the draft
    red and underlined. It scans the first 100,000 characters, within the 50 ms that hook is
    allowed; a 100 KB draft measured 16 ms median and 24 ms on the worst input found.
  - **The question at Enter.** A prompt you typed (origin `composer`), sent from a phone or the
    web through Remote Control (`bridge`), or run with `claude -p` (`sdk`) that holds a match
    raises one question: Mask and send, Send as typed, or Cancel.
    - Mask replaces each match with `[REDACTED:<label>]`.
    - Cancel drops the prompt; the draft comes back with Up, from your local history.
    - A dismissed question, a typed answer or a `-p` run with nobody to ask sends the masked
      text, never the secret.
  - **Slash commands.** A slash command's arguments are expanded before this check runs, so a
    rewrite here never reaches the model. A command holding a secret is therefore offered only
    Send as typed or Cancel, and is dropped on anything else.
  - **Failure.** A check that fails keeps back a prompt holding a secret, and sends a clean one.
  - **Standing:** **Gate** — `tests/redact.test.ts`, "prompt box". **Recorded** — the live probe
    named in the table above.

Residuals, stated:

- **Where it fails open.** A hook failure before the tool runs lets the call through
  and its output passes unredacted. Below Claude Code 2.1.299 so does a call the host
  cannot hand this hook at all (a value nested past its limit); from 2.1.299 the host
  refuses that call, or withholds the result of one that ran (its changelog; in
  `claude plugin test` 2.1.300 refuses a 30,000-deep value, where 2.1.291's kit raised an
  error). An unusable `hooks/patterns.tsv` is logged once and
  every result then passes unredacted (the write guard denies instead). A
  withheld-output refusal that cannot return within the one-second grace of the hook's
  failure handler lets the result through, on 2.1.300 as on 2.1.291: 2.1.299's refusal
  does not cover it (re-measured in `claude plugin test` on both, the handler held 3 s).
  An unusable `hooks/patterns.tsv` also lets every `@` mention and
  attachment through unscanned.
- **Private keys.** A key body arriving without its `BEGIN` line in the same string — a
  `Read` with an offset, `tail`, a `Grep` hit inside a `.pem` — is never matched. A
  `BEGIN` literal in source code masks everything up to the next `END` literal in that
  string. A mask can name several labels joined by `, ` and can cover a large region.
- **Not scanned through `@`.** A mentioned PDF or image, which the engine sends as a
  document or image with no text to scan (the mention check's raw read of a compressed PDF
  matches nothing); an MCP resource mention; and text-bearing attachment kinds outside
  `file`, `already_read_file` and `edited_text_file`, such as `nested_memory` (a nested
  `CLAUDE.md`, an `@`-import in it included).
- **Not scanned.** Object keys, so a value under a key such as `password` in a structured
  (non-text) result passes unless a provider pattern matches it alone; context a hook
  seated above this one attaches (a managed-settings hook, a mod loaded above it); a `Map`, `Set`, `Buffer` or class instance; a
  `base64` or `data` field holding strict base64 of a
  non-text type (a `Bash` `stdout` holding image data is masked as text instead).
- **The prompt box.**
  - **Not painted:** a large paste that the prompt box collapses to `[Pasted text #1 +N lines]`,
    or a draft recalled with Up. Both are still checked at Enter. CLI 2.1.300's
    `prompt.change` hook, raised for a recall, a clear, an undo or a plugin's fill, does not
    close this. Its hook only observes: the host discards what it returns. Repainting
    through `$.prompt.fill` would rewrite the draft, resetting a `!` shell draft to prompt
    mode and moving the cursor to the end (2.1.300's own code). And registering it at all
    stops this module loading on 2.1.291, where `claude plugin validate` and
    `claude plugin test` both fail on `"prompt.change" is not an event` (measured). An
    event name must be a literal, so no version check can guard it.
  - **Not checked:** a prompt from a plugin, another session, a background task, a scheduled
    task or an MCP channel (any origin but `composer`, `bridge` and `sdk`).
  - **Send as typed sends the secret**, by your choice.
  - **Cancel's history:** the draft it keeps in history holds the secret, in the local
    `history.jsonl` (live probe, 2.1.294). From 2.1.295 the host no longer saves a dropped
    prompt as typed, so whether Up still brings Cancel's draft back is unmeasured.
  - **By CLI version**, each from the host's changelog and none re-measured here, since each
    needs a live session:
    - below 2.1.295, a prompt this check masked or dropped was still saved as typed, to
      `history.jsonl` and to the transcript's queued-prompt records, so Mask and send left
      the secret on disk, though not in the request;
    - below 2.1.296, Esc or an interrupt while the check ran could send the prompt unchecked;
    - below 2.1.299, a prompt with a pasted image, or an image the host could not read,
      could lose the mask and go as typed;
    - below 2.1.300, the session-title request and the OpenTelemetry `user_prompt` event
      carried the prompt as typed.

    The guard still runs from 2.1.291, the mods floor. Below each fix one path leaks, and
    turning the guard off there would leak on every path. Its version check could raise
    the floor; it does not.
- **Not matched.** The secret-access-key field of an AWS credentials CSV stays visible
  beside its masked key ID: it has no pattern of its own. NUL-interleaved UTF-16 text
  passes, though `scan.sh` denies writing it. From CLI 2.1.299 `Read` decodes a UTF-16LE
  file that opens with a byte-order mark, so its text is masked like any other. Measured
  through `claude mcp serve`: 2.1.291 returns the NUL-interleaved bytes, 2.1.300 the text.
  A file without the mark, one read through Bash, and every one below 2.1.299 still
  pass. An assigned literal whose name carries more
  than twelve `_`/`-` segments after its last keyword, or a segment over 64 characters
  between that keyword and the `:`/`=`, passes both the mod and `scan.sh`: the shared pattern bounds the name so JavaScript's
  regex stays linear.
- **Not refused.** A `[REDACTED:` token written through an MCP write tool, or through a
  Bash write `scan.sh` cannot read (`sed -i` text, interpreters, `cp`/`mv`). A Bash heredoc
  or `echo`/`printf` into a file is refused by `scan.sh` since 0.14.0.
- **Refused by mistake.** The same token in a file that quotes it on purpose — a spec, a
  test, this README, a script that greps for it — is refused too, even in a session that
  redacted nothing: the refusal reads the new text, not where it came from. Its reason says
  the token may have come from a redacted result; `CC_SECRET_REDACT=off` (or `0`, `false`)
  gets past it and also stops output redaction. Standing: **gate** — `tests/redact.test.ts`
  refuses all four tools with nothing redacted and pins the reason's full wording, and
  `scripts/__tests__/scan-hook.test.sh` the Bash refusal.
- **Untested.** Subagent calls (the test kit drops `agentId`) and the time-budget-overrun
  path end to end (only its refusal text is tested).
- **Signals.** The toast is transient; afterwards only the mask text and the model's note
  show that a result was redacted. The parity harness covers only its fixtures.
