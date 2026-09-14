# Changelog

All notable changes to the `secret-scanning` plugin. Entries start at 0.5.0; earlier
releases were not recorded here and are not reconstructed.

## 0.6.0

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
## 0.6.0

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

### Added
- **A "What has teeth" table.** This was the one guard plugin whose README named no
  tier for any of its rules, while the convention it follows is this marketplace's own.
  Five rows, including the two things it cannot catch (a shell heredoc, an unlisted MCP
  key shape) and the one it deliberately refuses (an allow-file).
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
