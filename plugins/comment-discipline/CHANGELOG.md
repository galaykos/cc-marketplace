# Changelog

All notable changes to the comment-discipline plugin.

## 0.6.1

### Fixed
- **One-shot markers now key on `transcript_path`, falling back to `session_id`.**
  PostToolUse is the only hook channel that reaches subagents at all, and a subagent
  shares its parent's `session_id` while getting its own transcript — so a
  session-keyed marker the parent already claimed deduped the worker's nudge away.
  The advisory was structurally silent in the one context where most fan-out code is
  written. `scripts/lib/plugin-checks.sh`'s new `pc_context_key` gates it.

## 0.6.0

### Fixed

- **Every file in a git worktree was exempt from the guard.** `scan.sh` skipped
  `*/.claude/*` to spare the Claude configuration directory. This marketplace
  places worktrees at `.claude/worktrees/<branch>` — `worktree-isolation` says
  so, and `track-orchestration` literally runs
  `git worktree add .claude/worktrees/<run-branch>-track-<slug>` — so the
  pattern exempted every source file a track run wrote. A 73-file run drew no
  warning, and this was one of two independent reasons for that silence.

  Exclusions are now tested against a logical path with the worktree prefix
  stripped (`hooks/paths.sh`), so a file is judged by where it sits in the
  checkout. `.claude/` inside a worktree stays exempt, as does the main tree's.

### Added

- **`hooks/density.sh` — a comment VOLUME lane**, the gap `scan.sh` cannot close
  by design. `scan.sh` detects KINDS of bad comment, one pattern per comment; a
  file can be 81% comment with every line individually defensible, and the
  observed `GoogleClient.php` (180 comment lines to 33 of code) passed every
  kind check correctly. `density.sh` measures the written file against the
  comment density of its own siblings and warns when it is an outlier.

  Three properties it turns on, each with a smoke assertion:
  - **The baseline is pre-existing code** — siblings come from what git already
    TRACKS, minus anything this session wrote. A fan-out writing 30 uniformly
    dense files into a new package would otherwise take its baseline from its
    own output, find no outlier, and certify the drift it just created.
  - **The sibling walk stops at the repository root.** Without that bound a
    repo with no tracked code walks out of the project and averages unrelated
    files, then reports that as "its siblings".
  - **The line floor counts comment + code, not code alone.** A code-shaped
    floor excludes exactly the worst case: a 223-line file with 33 code lines.

  Warn-only, at most 3 warnings per session, one per file, fail-open. It cannot
  see the AGGREGATE across a fan-out — each subagent is warned in its own
  context and nothing sums the run. The `density-ledger.jsonl` it writes is
  machine-local and read by nothing today; that is a dataset for revisiting the
  thresholds, not a feedback loop.

### Notes

- Verified against the run that prompted it: the original pre-trim
  `GoogleClient.php` reports `5.4:1 comment-to-code … its siblings run 1.0:1`.
  A sibling file at 1.36:1 stays silent — elevated, inside the 2x band, and
  warning on it would be the noise the multiplier exists to prevent.
- Thresholds (2.0x the sibling median, absolute floor 0.8) are calibrated on one
  observed failure in one repository. Stated in the hook header, not implied.
