# Changelog — code-review

Consumer-facing changes only. A version bump with nothing here is a number; this
file is what makes an upgrade readable. Newest first.

## 0.12.5

### Changed
- **Every hook entry now declares a `timeout`.** `conventions.sh` 15s. Before this release the
  plugin expressed no opinion about how long its own hook may hold a turn and
  relied entirely on the host default; a hook that blocks — a slow network mount,
  a large transcript — stalled the user with no per-hook ceiling. Sizes are per
  script, not one house number: 5s for a jq-only classifier, 10s for git/find
  work, 15s where the script shells out to the network, a package manager or
  node. No hook logic changed.

## 0.12.4

### Changed
- **The debt ratchet names its standing**: `unenforceable` against the model
  itself — `--update-baseline` is runnable by any session, so the command now
  states the line can be reset by the session that crossed it, and forbids
  running it to green a red report. The gate that would block that write does
  not exist yet.
- **Stack fan-in routing** no longer names removed plugins (react, php, vue3,
  livewire); `.tsx`/`.jsx`/`.vue` now fall to the baseline pass, laravel rides
  composer.json, and the sql lane pairs with mariadb only.

## 0.12.3

### Changed
- No behaviour change. `conventions.sh` was already correct — it hashes the
  context key through `cksum` before that key becomes a filename, which is what
  keeps its one-shot working when the host sends a `transcript_path` (an
  absolute path). Nothing had ever tested that: every case in its harness sent
  `session_id` only, so the branch that runs in production never executed. Three
  sibling hooks in this marketplace lacked the same hashing and shipped broken
  behind an equally green suite. The harness now proves the hook still speaks and
  still bounds its one-shot under a path-shaped key, and `pc_harness_payload`
  fails the build if that coverage is ever removed.

## 0.12.2

### Fixed
- **One-shot markers now key on `transcript_path`, falling back to `session_id`.**
  PostToolUse is the only hook channel that reaches subagents at all, and a subagent
  shares its parent's `session_id` while getting its own transcript — so a
  session-keyed marker the parent already claimed deduped the worker's nudge away.
  The advisory was structurally silent in the one context where most fan-out code is
  written. `scripts/lib/plugin-checks.sh`'s new `pc_context_key` gates it.

## 0.12.1 — 2026-08-16

### Added
- **`lane.tsv`** — `code-reviewer` declares `stack-agnostic-diff-review` and the
  deference edges it already documented in prose (architecture, security, frontend and
  UI reviewers). `terse:terse-reviewer` declares the same territory and yields to this
  one, so the two no longer both claim a diff with nothing arbitrating.

## 0.12.0 — 2026-08-15

### Changed
- **`code-reviewer` now triages before the deep read**, on the same thresholds
  `commands/review.md` already used. The command had the triage; the agent did not — and
  the agent is the one dispatched automatically, on every task's diff, with no condition
  (`task-runner`'s execution skill and its reviewer-routing reference both say *always*).
  It ships `model: opus` / `effort: xhigh`, so a 20-line mechanical change was drawing a
  full neighbourhood read that the same plugin's command would have answered in one line.

  The short lane is a **conjunction**: single-file AND purely mechanical AND under the
  thresholds (5 files / 300 changed lines). Any doubt on any clause takes the full pass,
  and since this agent has no `Bash`, a dispatch naming a path rather than a diff counts
  as doubt. The full pass is mandatory regardless of size on auth, data, migrations,
  concurrency, **money, PII, and irreversible operations** — the last three are new here,
  added so this list, `coding-entry`'s risk clause and `lean:cost-model`'s blast-radius
  trigger name the same set.

  Two deliberate limits on the saving. The short lane closes with `not reviewed —
  mechanical, below triage threshold`, never `merge-ready`: a verdict on an unread diff
  would be a claim the agent did not earn. And it **never** drops the per-criterion lines
  that `task-runner`'s reviewer dispatch injects — that audit is the review's floor, and
  a return without it is re-dispatched, which would have cost more than the full pass.

  **Upgrade note.** Automated per-task reviews of mechanical diffs get shorter and now
  say so explicitly. Thresholds are restated here rather than only referenced, so they
  can drift from `commands/review.md`; nothing checks that they agree.

### Added
- One rule: **a finding that would not change what the author does next is not a
  finding.** Review output is itself a cost, and the marketplace had no statement of that
  anywhere. This is the theater test applied to findings rather than to gates.

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
