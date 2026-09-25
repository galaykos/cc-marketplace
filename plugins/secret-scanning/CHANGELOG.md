# Changelog

All notable changes to the `secret-scanning` plugin. Entries start at 0.5.0; earlier
releases were not recorded here and are not reconstructed.

## 0.9.0 - 2026-09-25

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
