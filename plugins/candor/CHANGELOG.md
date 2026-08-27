# Changelog

All notable changes to the `candor` plugin.

## 0.1.2

### Changed
- **Every hook entry now declares a `timeout`.** `gate.sh` 15s. Before this release the
  plugin expressed no opinion about how long its own hook may hold a turn and
  relied entirely on the host default; a hook that blocks — a slow network mount,
  a large transcript — stalled the user with no per-hook ceiling. Sizes are per
  script, not one house number: 5s for a jq-only classifier, 10s for git/find
  work, 15s where the script shells out to the network, a package manager or
  node. No hook logic changed.

## 0.1.1

### Fixed
- One measurement, two numbers: `CHANGELOG.md` said ~3.8k assistant messages
  across 47 transcripts, `hooks/gate.sh:148` said ~3.3k across the same 47 with
  the same two-step resolver. Aligned on the figure in the code comment nearest
  the script that produced it. Recorded as a judgment, not a re-measurement — the
  original run is not reproducible from here.

## 0.1.0 — 2026-08-18

Initial release.

### Added

- `hooks/gate.sh` — a blocking `Stop` hook with two falsifiable clauses.
  Clause 1 fails a turn whose final message cites a `path/file.ext:NNN` that does
  not resolve under `cwd` or points past the file's last line. Clause 2 fails a
  turn that retracts a position ("you're right", "my mistake", "I stand
  corrected") after challenge-shaped pushback that carried no correction of its
  own, when no tool ran between the challenge and the retraction.
  Modes: `CC_CANDOR_GATE=block` (default) `| warn | off`. Fails open on missing
  `jq`, an unreadable transcript, or empty text. One block per distinct final
  message.
- Citation resolver ladder, forced by measurement rather than theory: cwd-relative,
  then a full-suffix match, then the basename. Only a basename that exists
  **nowhere** counts as fabrication. Over 47 real transcripts (~3.3k assistant
  messages) a two-step version flagged mostly ABBREVIATED paths —
  `craft-layer/asset-sourcing/SKILL.md` for a file that really lives at
  `plugins/craft-layer/skills/asset-sourcing/SKILL.md` — which is the
  false-positive class that gets a gate switched off. The accepted residual: a
  real filename cited under the wrong directory now passes silently. Elided paths
  (`plugins/x/.../SKILL.md:74`) are skipped as prose, not resolved.
- `scripts/candor-scan.sh` + `/candor:check` — report-only measurement of a
  session transcript across six axes: the two gated ones plus flattery openers,
  apologies, defensive phrasing and emotional intensifiers. Always exits 0.
  Citations resolve against the transcript's own recorded `cwd`, printed in the
  report — pointing the scan at a session that ran elsewhere previously reported
  78 real paths as missing in a single transcript. The `defensive` axis dropped
  the bare `you asked for` pattern for the same reason: 4 hits on a 719-message
  transcript, all of them neutral back-references. The citation axis is
  backward-looking by nature (it resolves a whole session's history against
  today's tree); the gate is not, and both say so.
- `skills/straight-talk/SKILL.md` — the six orderings the gate cannot check:
  evidence before claim, disagreement before concession, reversal-as-finding,
  "I don't know" plus the settling command, scope honesty, correction without
  performance. Carries the standing table for which of them have teeth.
- `lane.tsv` — territory declaration; the Stop gate yields to
  `code-architecture:evidence-gate` on completion-claim territory, which it does
  not duplicate.
- Three author-time harnesses, 64 cases. `install.test.sh` is the one that would
  catch a plugin working only in-tree: it copies the plugin to a temp directory,
  resolves the hook by expanding `${CLAUDE_PLUGIN_ROOT}` from `hooks/hooks.json`,
  fails if that path lands back inside this repository, and drives it against a
  consumer project that is not a git repository, with full-shape transcript
  entries.
