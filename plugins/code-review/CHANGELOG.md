# Changelog — code-review

Consumer-facing changes only. A version bump with nothing here is a number; this
file is what makes an upgrade readable. Newest first.

## 0.11.0 — 2026-08-14

### Fixed
- **`scripts/debt-scan.sh` now counts Pest skips.** `P_SKIP` covered PHPUnit's
  `markTestSkipped`/`markTestIncomplete` but not Pest's chained `->skip()` /
  `->todo()`, which is the idiomatic form in Pest — so a Pest suite's quarantined
  tests counted **zero** while the same project's PHPUnit-style skips counted
  normally. Pest is not fringe in this marketplace: it ships `php` and `laravel`
  plugins, and `testing`'s flake-hunt runner table lists Pest by name.

  **Upgrade note.** `skipped_tests` will RISE on any Pest project the first time
  this version runs, so an existing `.claude/debt-baseline.json` may fail
  `--check` on a tree nobody changed. That is the ratchet reporting debt it
  previously could not see, not new debt — re-run `--update-baseline` once to
  re-level, and read the delta as a one-off correction.

### Added
- **Per-runner skip fixtures** in `scripts/__tests__/debt-scan.test.sh`. The
  aggregate assertion was satisfied by a single `it.skip` in one TypeScript
  fixture, which is precisely how the Pest gap survived a green harness — nothing
  ever asked whether a PHP suite's skips were visible at all. Seven runners
  (Pest ×2, PHPUnit, vitest, pytest, go, JUnit) are now each asserted in an
  isolated tree.

## 0.10.0 — 2026-08-02

### Added
- **`hooks/conventions.sh`** — a PostToolUse hook that fires once per session, on
  the first code write, naming the PATHS of the files defining this project's
  conventions (`.editorconfig`, formatter, linter, pre-commit) plus the CI command
  that enforces them. It emits locations, never a summary of their contents: a
  distilled checklist injected before the model reads the source measurably
  narrows the review. Silence it with `CC_CONVENTIONS=off`, or `CC_REMIND=off` for
  every advisory nudge in this marketplace.
- **`scripts/debt-scan.sh`** and a `--debt` lane on `/code-review:review` — five
  language-agnostic debt categories (suppressions, skipped tests, bare markers,
  deprecated-symbol references, feature flags) counted against a committed
  `.claude/debt-baseline.json`. `--check` exits 2 when any category GREW;
  `--update-baseline` accepts growth deliberately. `--age` resolves first-seen
  dates by git pickaxe, which turns "340 TODOs" into "11 older than two years".

### Changed
- `/code-review:review`'s apply pick now names a dispatch target
  (`task-runner:task-executor if installed → inline`). It was the flagship
  fan-in command and the only one whose apply pick named nothing, so findings
  died in chat while 31 chassis siblings routed theirs.
- `code-smells` now states its boundary with Claude Code's built-in `simplify`
  skill, which covers overlapping ground and applies fixes. Use the host skill for
  a quick cleanup pass; use this one when the question is which smell, and whether
  it is a smell at all.

### Notes
- The debt scanner counts OCCURRENCES, not severity. It answers "is this getting
  worse", never "is this bad".
