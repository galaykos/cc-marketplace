# Changelog

All notable changes to the `secret-scanning` plugin. Entries start at 0.5.0; earlier
releases were not recorded here and are not reconstructed.

## 0.12.0 — 2026-10-08

- **A file attached with an `@` mention is checked too.** An `@`-mention is read with no `tool.call`, so 0.11.0's output redaction never saw it (its changelog listed this as not redacted), and the CLI lets a hook refuse such a read but not rewrite it. `hooks/redact.ts` now reads the mentioned file, or only the lines a mention names (`@.env#L3`), and refuses the mention when a pattern from `hooks/patterns.tsv` matches outside the placeholder escape: nothing of the file reaches the prompt, and a toast names the file and the labels, because the refusal's reason goes only to the debug log. Claude can still `Read` the file, which the redaction masks. A file the module cannot read is left to the engine; a scan that throws or overruns its budget refuses the mention with a toast naming `CC_SECRET_REDACT=off`. Same switches as the redaction. Six cases in `tests/redact.test.ts`. Not tested: a subagent's mention, and a mention on a live CLI.

## 0.11.0 — 2026-10-06

- **The secret patterns and placeholder words live in `hooks/patterns.tsv`, and `scan.sh` fails closed on it.** `scan.sh` reads the file on the first write with text to scan. A missing or unreadable file, a line carrying a carriage return (a CRLF file), a row that is not four non-empty TAB-separated fields, an unknown kind or flag, a pattern starting or ending with a space, a pattern holding `[[:`, `[[.`, `[[=`, a `[:class:]`, `(?` or a backreference, a backslash before any character but `] . [ + * ? ( ) { } | ^ $ / -` (GNU grep reads `\d` as `d`; `\b \B \w \W` differ from JavaScript on non-ASCII letters and `\s \S` on U+00A0 and U+FEFF, so those are refused too), a pattern `grep -E` cannot compile on its own row, a pattern that matches the empty string, a placeholder row matching a fixed secret-shaped probe, or no `secret` row denies that write with a reason naming the file, the line and `CC_SECRET_SCAN=off`; a Bash command that writes no file still passes, and every other error still fails open. The patterns match as before with two changes. The assigned-literal rule now allows at most twelve `_`/`-` name segments of 1-64 characters after the keyword (it was unbounded), which keeps the same row linear in JavaScript's backtracking engine — a thirteenth segment after the last keyword, or a 65-character segment between the last keyword and the `:`/`=`, is no longer denied; pattern-parity pins a twelve-segment deny whose last segment is 64 characters and a thirteen-segment allow through both engines. And the credential-in-URL rule excludes a literal space where it excluded `[[:space:]]`, so whitespace other than a space or newline inside a URL's userinfo (a tab, a carriage return) no longer stops the match and such a URL now denies. The file's header states its regex dialect, the subset GNU `grep -E` and JavaScript `RegExp` without the `u` or `v` flag read the same. 22 new cases in `scan-hook.test.sh` run a temp copy of the hook against a missing file and each malformed shape. The README states the exception to fail-open; the one-line plugin description is unchanged. Not checked in the file: a backslash inside brackets, a collating element later in a bracket, a placeholder word a real secret can contain. Not tested: BSD grep (macOS).
- **Tool output is redacted on Claude Code 2.1.291 or later.** A hooks module, `hooks/redact.ts`, listed under `modules` in `hooks/hooks.json` beside the classic hooks, masks each secret-pattern match in every tool's result (any tool, main loop and subagents, every string however nested) as `[REDACTED:<label>]` before the model or the transcript sees it, with `hooks/patterns.tsv` and its placeholder escape. A redacted result carries one model-facing line naming the labels and forbidding write-back, and one toast names the count and the labels, never a value. An errored result is checked in its error text, the result the transcript stores and any context attached beneath; a match in any of them answers the call with a refusal whose text is the redacted error text. Context that another plugin's hook attached beneath this one is carried verbatim, because CLI 2.1.291 skips a hook that changes such an entry; when any of it holds a secret, the whole call is answered with a refusal instead, whose text is the result as the model would have read it, redacted, plus a line naming the labels and `CC_SECRET_REDACT=off`, so neither the result nor that context reaches the model. Both refusals repeat the ban on writing a placeholder back. When redaction fails after the tool has run (the hook throws or overruns its time budget), the call is answered with a refusal naming the failure (its message redacted, or only its kind while no patterns are loaded) and `CC_SECRET_REDACT=off` rather than the unredacted output; a failure before the tool runs lets the call through. A `Write`, `Edit`, `MultiEdit` or `NotebookEdit` whose new text carries `[REDACTED:` is refused with a reason saying the token may have come from a redacted result and naming `CC_SECRET_REDACT=off`, which also stops output redaction. A `base64` field, or a `data` field beside `media_type` or `mimeType`, is left unmasked only when its text, line breaks aside, is strict base64 (padding only at the end) and its type is not text, JSON, XML or PEM, so a chance match cannot corrupt an image while text filed under those names is still scanned. Off: `CC_SECRET_REDACT=off` or the new `/config` option `cc_secret_redact`; below 2.1.291 every call passes through and the classic hooks work as before, except that on CLI 2.1.287 with mods on the registered hook still triggers that CLI's own tool.call bug (Bash and file search failing in worktree subagents, fixed in 2.1.288) even with redaction off. `hooks/cc-kit.ts` is a byte copy of the marketplace's shared mod kit. 22 cases in `tests/redact.test.ts` run under `claude plugin test`.
- Not redacted: a file attached with an `@` mention (`prompt.mention` raises no `tool.call`); object keys, which are never scanned, so a secret held as an object's value under a key such as `api_key`, which only the assigned-literal rule would catch, passes; a bare base64-shaped token inside a binary-typed `base64` or `data` field; and any result when the refusal for a failed redaction cannot itself be returned within the one-second grace of the hook's failure handler. Not refused: a `[REDACTED:` token written through Bash or an MCP `apply_patch`/`create_new_file`. Refused by mistake: the same token in a file that quotes it on purpose (a spec, a test, this plugin's README), even in a session that redacted nothing. Masked as text, not skipped as bytes: a Bash `stdout` holding image data. A pattern file that fails to load is logged once and every result passes through. Not tested: a subagent's call (the test kit drops `agentId`).

## 0.10.3 - 2026-10-05

- **Hook comments cut to contract and limits; behaviour unchanged.** The shared blocks in `hooks/scan.sh` and `hooks/unicode-scan.sh` keep each function's contract and limits in a few lines; the derivations and history moved to the marketplace repository's `rationale/`. After this cut both hooks parsed to the same code as before (bash's own parser, comments ignored); `unicode-scan.sh` was then refactored (next entry).
- **The rest of the hook and test comments are cut to a contract line per file, plus off-switch and `Misses:` lines where it reads one or had a residual; behaviour unchanged.** The derivations and history, including the argument for the non-provider patterns and the placeholder exemption, moved to the marketplace repository's `rationale/derivations/plugin-secret-scanning.md`, which an install does not contain. `unicode-scan.sh` names its marker age `MARKER_TTL_MIN=1440` and its Bash-target cap `MAX_BASH_TARGETS=8`, so its code differs and instead of a parse comparison: 6 new pins in `unicode-scan-pins.test.sh` passed on the old and the new code, and a run of the old against the new hook found 0 divergences in 58 input pairs (output, exit status and every file left behind compared). `scan.sh` and both existing tests parse to the same code as before. Limits now written down, behaviour unchanged: `unicode-scan.sh`'s header names an MCP `apply_patch` and a file that is not valid UTF-8 as unread. Not tested: bash 5, and hooks firing in parallel.
- **`NotebookEdit` cells are now scanned.** Earlier releases matched `NotebookEdit` but never read the cell's `new_source`, so a secret in a cell was written although the README's gate row listed it; `scan.sh` now denies one as it denies a `Write`, naming the notebook (a cell delete is not scanned), and `unicode-scan.sh` reads the notebook a `NotebookEdit` wrote.
- `lane.tsv` names `NotebookEdit` in both hooks' triggers, as their matchers already did.

## 0.10.2 - 2026-10-01

- The shared Bash-write parsers end a command at a lone `&`. Text a command writes after a backgrounded one is now read (`sleep 1 & echo "<text>" > f` was skipped), and a heredoc body is no longer judged as the content of a file a later command on the same line writes (in `cat <<EOF & echo done > log.txt` the body was attributed to `log.txt`). `scan.sh` carries both updated blocks.
- **`unicode-scan.sh` reads a write after a lone `&`:** the shared `cc_bash_write_targets` block now ends a command at a lone `&`, so a write after one is read (`echo x & sed -i s/a/b/ f.json` used to return nothing) and words after one are no longer taken for `sed`/`perl`/`tee` operands; `cmd |& tee f` is read; a `-`-led file after `sed … --` or `perl -i` is returned.
- Not read by `scan.sh`: text in a command that a `&` inside `$(( ))` or `${ }` ends early. Not read by `unicode-scan.sh`: a `>& file` redirect, a bare `-x` operand with no `/` or `.` in it, and operands after a `&` inside `$(( ))` or `${ }` (that `&` ends the command). Over-read, harmless: a `-`-led argument to a perl script that contains `/` or `.`.

## 0.10.1 - 2026-10-01

- **`unicode-scan.sh` reads `sed -i` edits correctly:** the shared `cc_bash_write_targets` block now returns every file a `sed -i` / `perl -i` command edits instead of its last word, never a trailing redirect (`sed -i … tsconfig.json 2>/dev/null` used to yield `2>/dev/null`), and recognises GNU `--in-place[=SUF]` and BSD `-I`. So every file such a command edits is scanned after the write, not a redirect word.
- `scan.sh` carries the same block; what it judges on Bash is unchanged (heredoc bodies and `echo`/`printf` text, not the result of a `sed -i` edit).
- Still not read: a globbed operand (`tests/*.js`), a `\` line continuation, sed or perl reached through another word (`gsed`, `/usr/bin/sed`, `xargs`, `find -exec`), and a dot-named file right after a bare `-i` when another file follows (read as BSD's backup suffix).

## 0.10.0 - 2026-09-30

- **Off-switches are now `/config` options:** `cc_remind`, `cc_secret_scan`, `cc_unicode_scan`, under `/config` (or `/plugin configure secret-scanning`), each with today's default. The environment variable (`CC_REMIND`, `CC_SECRET_SCAN`, `CC_UNICODE_SCAN`) still overrides its option, and `CC_REMIND` / `CC_BOOST` set in the shell still mute every plugin at once. An interactive `/plugin install` now shows a Configure dialog for these options; it is optional — Esc keeps the defaults.

## 0.9.1 - 2026-09-29

- The Bash chunk extractor in `hooks/scan.sh` moved to the shared block
  `templates/blocks/bash-write-chunks.md` as `cc_bash_write_chunks` (formerly the hook-local
  `cc_secret_bash_chunks`), so other content guards reuse one byte-locked copy instead of
  forking it. No behaviour change: the function body is byte-identical and its output for the
  same commands is unchanged.

## 0.9.0 - 2026-09-25

- `hooks/hooks.json` quotes `${CLAUDE_PLUGIN_ROOT}` in every hook command. Claude Code 2.1.282's `plugin validate --strict` rejects the unquoted form (an install path with a space splits into several words); the marketplace's CI pin moved to 2.1.282 with it.

### Added
- **The write guard now reads Bash writes.** `hooks/scan.sh` matched the host write tools
  only, and its own header named a heredoc as the way around it. Measured 2026-09-25
  (`rationale/2026-09-25-session-plugin-usage-review.md`, finding 1): the host steers file
  writes through Bash, and in one session 233 of the main thread's 238 file writes went
  through `cat > file <<EOF`. The only deny guard on that path never ran. `Bash` is now in the
  PreToolUse matcher. When a command has a write target (the shared
  `cc_bash_write_targets` block), the guard scans two things: heredoc bodies whose
  pipeline redirects or tees to a file, and the arguments of `echo`/`printf` segments
  whose pipeline does. The deny names the file. The patterns and the placeholder escape
  are the Write path's, through one scanner function (`scan_for_secret`), not a copy.
  `echo "STRIPE_SECRET=<live key>" >> .env.example` denies. The documented AWS example key
  in a PHP heredoc passes. PHP `->`/`=>` in a body is not read as a redirect.
- Stated as NOT caught: a command with no write target (a live key in a `curl -H`
  header), interpreter writes, `cp`/`mv` of a file that already holds a secret, `sed -i`
  replacement text, a here-string, a `{ echo …; } > f` group. command-guard still owns
  destroying a live `.env`. This guard owns a secret entering any file.
- **`unicode-scan` checks Bash-written files too.** It scans up to 8 write targets per
  `Bash` call that now exist as regular files under the project root. A relative target
  resolves against the payload `cwd`, so a `../file` written from a subdirectory is found.
  A Bash call with no write target exits after one awk pass. Neither hook writes
  `.claude/` state (the one-shot marker lives in `$TMPDIR`), so no state-root conversion
  was needed.

### Fixed
- **A clean first touch no longer spends a file's one warning.** `unicode-scan` claimed
  its once-per-file-per-session marker before scanning, so a file read or written clean
  first was never checked again that session, and invisible characters written into it
  later went unreported — "warns once" behaved as "checks once". Bash coverage made that
  the common path (a file created by one heredoc, appended by the next). The marker is now
  claimed only when a warning is printed (atomic `mkdir`, so two concurrent hooks on one
  file still report once). A harness case pins it and fails against 0.8.0.

### Changed
- The skill's "what the guard blocks" and "Limits" sections, the README standing table, and
  `lane.tsv` now say the guard sees Bash, and they list what it still cannot see. The skill
  gains one anti-pattern: after a deny, do not reroute the write through `python open()`,
  `cp` or `sed -i`.

## 0.8.0

### Added
- **URL-embedded credentials now deny.** A `DATABASE_URL` DSN in a `.env`, a tfvars
  connection string, a compose `AMQP_URL:`, a Helm values DSN and an HTTPS basic-auth
  URL all reached disk silently: the credential is not a provider key and carries no
  `password=`-shaped operator, so neither the provider tier nor the generic
  assigned-literal rule could see it. One pattern over the `postgres://`, `mysql://`,
  `mongodb://` (plus `+srv`), `redis://`, `amqp://` and `https://` schemes now denies it, and
  a second denies a Slack incoming-webhook URL (`hooks.slack.com/services/T…/B…/…`),
  which is a bearer credential in URL clothing. The generic `{24,}` rule was
  deliberately NOT widened.
- The password run excludes `/?#` (RFC 3986 userinfo cannot contain them, which keeps
  an ordinary URL with a port and a mailto-ish query out) and refuses a leading `$` or
  `{`, so the CORRECT shape — a DSN whose password is a `${DB_PASS}` substitution — is
  not denied on every retry. The existing placeholder escape applies unchanged: a DSN
  whose password is the word `changeme` passes. Stated residual: a DSN whose password is
  the literal word `password` **denies**, because that word is not one of the escape's
  placeholder words; a real password that
  begins with `$` or `{`, one under six characters, and any scheme outside the list are
  not caught. Fixtures for every row above in `scripts/__tests__/scan-hook.test.sh`.

### Changed
- `lane.tsv` now declares the `unicode-scan` PostToolUse hook (`invisible-character-report`); it was registered in hooks.json and undeclared in the lane file.

## 0.7.0

### Fixed
- **The skill told the model the opposite of what the hook does.** Since 0.5.0 a matched
  value that announces itself as a placeholder is RELEASED, and the skill still said
  `AKIAIOSFODNN7EXAMPLE` "is denied … this is the guard's commonest false positive",
  then offered "splitting the literal so the written text never contains the full
  pattern" as a working escape. Measured against the shipped hook: that write returns no
  decision, exit 0. So the one artifact the model actually reads on a deny was pointing
  it at the one move this guard exists to catch, while the real escape — named in the
  deny message itself — went unmentioned. The skill now states the placeholder test (the
  value, never the variable name), names `CC_SECRET_SCAN=off`, and forbids literal
  splitting outright. The residual moved with it: the anti-pattern list now names
  dressing a real value in a placeholder word, which is the bypass the exemption bought.
- **The README named a harness file that does not exist** — `scripts/__tests__/scan.test.sh`;
  the file is `scan-hook.test.sh`.
- **The "one character repeated" escape was documented wider than it is.** The README
  offered a run of zeros as a placeholder form; the test reads the WHOLE matched value,
  so a provider pattern's literal prefix breaks the repetition. Measured: `SECRET=` plus
  26 zeros passes, `AKIA` plus sixteen zeros denies. Both README and skill now say a
  provider-shaped fixture needs a word, and the deny reason already only offered words.
  (Found by the guard denying the edit that spelled the denying value out — the same
  mention-versus-write blindness `command-guard` documents. The examples here are
  described, not spelled, the way `hooks/scan.sh`'s own header handles its Stripe case.)
- **`unicode-scan` was undocumented in the README.** 0.6.0 added a second hook — a
  PostToolUse warning for invisible and bidirectional characters in any file the session
  wrote or read — and the README's "What's included" and "What has teeth" listed neither
  it nor `CC_UNICODE_SCAN=off`. Both now carry it, at the advisory tier it actually has.
- **The README described the deny as having no escape** in the present tense
  ("the deny is unbounded and has no allow-file") one release after `CC_SECRET_SCAN=off`
  shipped. Reworded as history, with the live escapes named.

### Changed
- The skill's description adds the triggers it was missing — "hardcoded credential",
  "API key or token", "connection string with a password", and the denied-write case,
  which is the moment the body is most needed and the one phrasing that never routed to
  it. The body dropped 12 lines of design argument — the "Why a hook, not a rule"
  section and the opening paragraph told a reader who cannot act on it why a hook beats
  prose (`rationale/measured-zero-shapes.md`, shape 4), and the README already carries
  that case. Measured net after the corrections above: 113 → 112 lines, 6,155 → 6,372
  bytes. The always-on cost of the description moved with it — **+14 tokens over
  `scripts/context-budget-baseline.json`, which needs a targeted `--update-baseline`
  for this one entry.**

## 0.6.1

### Fixed
- **The write-time block now has an off-switch.** `CC_SECRET_SCAN=off` disables it for a session. Until now the only way out was uninstalling the plugin — the one deny in the marketplace with no escape at all.

## 0.6.0

Two releases shipped under this one version number — `unicode-scan` landed after the
MCP write fix without a bump, so the entries are merged here rather than split across
two `0.6.0` headings that a consumer could not order or tell apart.

### Added
- **`unicode-scan`: a PostToolUse warning for invisible characters** in any file this
  session wrote or read — zero-width space/joiner/non-joiner, word joiner, soft hyphen,
  a mid-file BOM, the Unicode tag block, and the bidirectional overrides that make
  source display in an order different from the one it executes (the Trojan Source
  class, CVE-2021-42574), which get their own message because the consequence is
  different. This is the one rule here whose subject the model cannot see: the bytes do
  not render, they survive copy-paste, and no instruction helps with a character that is
  never shown. Warn, not deny, and on PostToolUse rather than Pre, for two measured
  reasons: zero-width joiners are legitimate in emoji sequences and in Arabic, Persian
  and Indic text, and the interesting case is usually a file being READ, where blocking
  the read helps nobody. A leading BOM is an encoding, not a hider, and is exempt. It
  does not catch homoglyphs. `CC_UNICODE_SCAN=off` (or `CC_REMIND=off`) disables it;
  `scripts/__tests__/unicode-scan.test.sh` drives 16 cases.
- **A "What has teeth" table.** This was the one guard plugin whose README named no
  tier for any of its rules, while the convention it follows is this marketplace's own.
  Five rows, including the two things it cannot catch (a shell heredoc, an unlisted MCP
  key shape) and the one it deliberately refuses (an allow-file).

### Fixed
- **A secret written through an MCP file tool is blocked.** The matcher was
  `Write|Edit|MultiEdit`, so a session driving an IDE — which writes every file through
  its own MCP server — wrote past this guard entirely, while the README read as
  universal. It now also matches `NotebookEdit` and any tool whose name ends
  `apply_patch` or `create_new_file`, and reads their payloads: `pathInProject` + `text`
  for a created file, and the whole patch body for `apply_patch`, whose added lines are
  what a secret rides in on. Keys verified against the shipped JetBrains MCP schema on
  2026-09-14. Residual, now stated in the README: a server using different key names
  still writes past it.

## 0.5.0

### Fixed
- **A fixture write could not get past the guard.** The deny is unbounded and has no
  allow-file, and the reason text's own advice — "use an obviously-fake value" — was
  unfollowable for the shapes that actually came up: AWS's documented example key
  `AKIAIOSFODNN7EXAMPLE` matches the AKIA shape by construction, and an
  `.env.example` line such as `STRIPE_SECRET=` followed by a test-key prefix and a
  run of `x`s matches the assigned-literal shape. Every retry was refused; the only exits were a
  Bash heredoc around the guard or uninstalling it. A matched VALUE is now released
  when it announces itself as a placeholder: it ends in `EXAMPLE`, is one character
  repeated, or carries a placeholder word (`example`, `placeholder`, `changeme`,
  `your-`/`your_`, `dummy`, `redacted`, `sample`, `fake`, `todo`, `xxxx`). The test
  reads the value only, never the variable name, and every match in a write is
  checked. Residual, stated in the hook header: a real secret containing one of those
  words passes. Ten harness cases (`scripts/__tests__/scan-hook.test.sh`) cover both
  directions.
- Deny reasons read "contain an AWS access key ID" / "an assigned secret literal"
  instead of "a AWS …" / "a assigned …", and now say what a fixture value must look
  like to pass.
