# Changelog — security

Consumer-facing changes only. Newest first. Started at 0.12.6; earlier versions have no entries rather than invented ones.

## 0.13.2 — 2026-11-21

- **`/security:review`'s short lane is a conjunction**: single-file AND mechanical AND no security-relevant surface, or the full audit (same fix as code-review 0.38.2).
- **`/security:review`'s self-refute pass drops or downgrades a `critical` finding only on a cited contradiction**: a line or command output (the guard, binding or middleware that blocks the path, a semgrep or audit result), named in the note. A doubt with no citation keeps the finding at its severity, marked `PLAUSIBLE`. Why: a same-model second look with no outside signal flips true findings as readily as false ones (Huang et al., ICLR 2024), so the pass could argue a real critical away.
- Standing: recorded (the reviewing model follows it; nothing reads a review's notes back).

## 0.13.1 — 2026-11-16

- **`security-engineer` checks before writing new code and before handing back.** Before adding a helper, class, component, factory or status list it greps the repo for one and extends what exists; it extracts a shape on its second use; after fixing a pattern it greps sibling files for the same pattern; it keeps a card's `<invariant>`, `<reuse>` and `<interface>` lines and reports how each invariant holds. Before hand-back it runs the project's own linters and analyzers on every touched file, tests included, in addition to the tests, and reports an analyzer whose config skips one of them. Why: reviews of two real runs traced most post-build fix rounds to cross-card contract gaps and code rewritten beside an existing helper, and one run never ran its configured analyzer.
- Standing: agent-graded (agent text; no harness reads a worker's return).

## 0.13.0 — 2026-11-14

- **The write scan's marker with no plugin data dir moves to `.cc-artifacts/security/`** (was `.claude/security/`), through the shared plugin-state block in `hooks/write-scan.sh`. It starts fresh: the first Bash call after the upgrade only sets the marker.
- Standing: gate for the path (`templates/blocks/plugin-state.md`, held byte-identical by `pc_shared_blocks`); no test of this plugin asserts the fallback location.

## 0.12.9 — 2026-11-08

- **`/security:review` runs semgrep when it is already installed.** On a full audit it runs `semgrep scan --json` over the scope: offline with the project's own `.semgrep.yml` or `.semgrep/` rules, otherwise with the public `p/default` ruleset, which it downloads from semgrep.dev without sending code. `--config auto` is never used, because it sends the project URL and needs metrics on. Each hit becomes a finding ranked by the review's exploitability triage and merged with a manual finding on the same line. When semgrep is not installed, the coverage line says so and the review goes on. It never installs semgrep. Standing: recorded — nothing checks the run happened.
- The `security-review` skill names the semgrep route too, so `/code-review:review`'s skill fan-in reaches it. Its command carries `--disable-version-check`, as `/security:review`'s does, so the run makes no version call.

## 0.12.8 — 2026-10-31

- **The write scan no longer warns on prose.** The five rows with no file-type gate (`mass-assignment-open`, `blade-unescaped`, `client-bundle-secret`, `raw-sql-interpolation`, `raw-html-sink`) skipped no doc file, so a Markdown report quoting `{!! $x !!}` drew `blade-unescaped`. Every row now skips `.md`, `.mdx`, `.txt` and `.rst`, and every row but `client-bundle-secret` also skips `.json`, `.yaml`, `.yml` and `.lock`: a CI workflow, a compose file or `eas.json` sets build env there, so a public-prefixed secret in one still warns. Residual: that row still warns on a JSON or YAML file that only names such a variable. `write-scan.test.sh` pins each row silent in a `.md` and warning in its code file; six of those cases fail against 0.12.7.

## 0.12.7 — 2026-10-28

- **Comments cut to what a reader needs; behaviour unchanged.** `hooks/write-scan.sh` (shared-block comments): each keeps a header saying what it does and misses, and one line per trap the code cannot show; the history moved to the marketplace repository's rationale/derivations/, which an install does not contain.

## 0.12.6 — 2026-10-28

- **Hook comments cut to what a reader needs; behaviour unchanged.** `hooks/write-scan.sh`: each keeps a header saying what it catches and misses, and one line per trap the code cannot show; the history moved to the marketplace repository's rationale/derivations/plugin-security.md, which an install does not contain. Every hook parses to the same code as before (comments ignored).
