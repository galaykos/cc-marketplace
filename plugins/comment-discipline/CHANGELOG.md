# Changelog

All notable changes to the comment-discipline plugin.

## 0.6.8

### Changed
- Doc staleness is named as api-design's docs-upkeep skill; api-docs-first merged into <!-- removed-ok -->
  api-design on 2026-09-02.

## 0.6.7

### Changed
- **Meta-prose compressed to a one-line standing tag.** Sections narrating this
  skill's relationship to its siblings — boundary tours, "what this is NOT" lists,
  and in places the repository's own drift history — are replaced by a `Standing:`
  line on the rule they qualify. No actionable rule changed, and every named
  cross-skill reference was preserved: those names are what make the skills they
  point at reachable, and a re-scan confirmed none was orphaned.

## 0.6.6

### Added
- **"What is enforced, and what is advice" — the skill now names its own teeth.**
  It shipped a `PreToolUse` **deny** and never mentioned it: zero occurrences of
  `hook`, `deny`, `PreToolUse` or `density` in the body. Two of the seven kill-cases
  (restatement of the next line, commented-out code) are gates; the other five are
  warnings; the skill presented all seven at one standing. The accurate description
  existed only in README.md, which the model never loads.
- **The "deleting comments to hit a ratio" anti-pattern is reconciled with
  `hooks/density.sh`**, which measures exactly a ratio. Measuring one to find a file
  worth reading is not acting on the number instead of the comments — the hook's own
  header said so and the skill did not, so a model that loaded this skill and then
  got a density warning had been told the warning was the anti-pattern.

## 0.6.5

### Changed
- **Manifest description cut from 1,086 to 674 characters.** It was the longest in
  the marketplace and the only one over `validate.sh`'s 700-char clarity guideline
  by more than 300. The description is the marketplace listing line — what a user
  reads before installing — and the guideline is about clarity, not token cost:
  `context-budget.sh` meters FRONTMATTER descriptions on skills, commands and
  agents, and does not count this one, so this release saves no measured context.
  The detail it carried — the six noise categories, the two hook lanes, the
  terminal-prose hook — was already in this plugin's README, so nothing was lost,
  only de-duplicated. Behaviour unchanged: no skill, hook or command was touched.

- **Every hook entry now declares a `timeout`.** `density.sh` 10s, `scan.sh` 15s, `verbosity.sh` 5s, `scan.sh` 15s. Before this release the
  plugin expressed no opinion about how long its own hook may hold a turn and
  relied entirely on the host default; a hook that blocks — a slow network mount,
  a large transcript — stalled the user with no per-hook ceiling. Sizes are per
  script, not one house number: 5s for a jq-only classifier, 10s for git/find
  work, 15s where the script shells out to the network, a package manager or
  node. No hook logic changed.

## 0.6.4

### Added
- **Build files are now governed: `Dockerfile`, `Dockerfile.*`, `Containerfile`,
  `Makefile`, `GNUmakefile`, `*.dockerfile`, `*.mk`.** A Dockerfile is an imperative
  step list, not a document — `# copy src to app` above `COPY src /app` restates its
  next line exactly the way `// increment the counter` does above `counter++`, and
  `*.sh` has been governed for that reason since the start. Extensionless names are
  matched by basename.

### Unchanged, deliberately
- **YAML stays out.** `docker-compose.yml`, CI workflows and k8s manifests use
  comments for navigation (`# the web service` above a service block), which this
  rule explicitly does not govern. The exclusion is now stated in the source rather
  than implied by the absence of an extension.

## 0.6.3

### Fixed
- **The PreToolUse deny was silently absent in every real session, and the density
  warning had no bounds.** 0.6.2's context-key change read `.transcript_path //
  .session_id` — correct — and then interpolated the value straight into a filename.
  `transcript_path` is an absolute path, so `scan.sh` built
  `…/blocked-/Users/…/x.jsonl-<key>` and `density.sh` built `…/density-/Users/…/x.jsonl`,
  whose parent directories are never created. Every state write failed. Because
  `scan.sh` correctly withholds the deny when its marker cannot land — a bound that
  cannot be recorded is not a bound — the effect was that the plugin's only blocking
  tooth stopped firing entirely, with nothing in the transcript saying so. In
  `density.sh` the failure went the other way: `warned` was always 0, so the 3-warning
  cap, the per-file dedup, and the filter that keeps a run's own output out of its own
  baseline all disengaged, and a track run could raise the sibling median to match the
  dense code it had just written. Both keys are now hashed with the same `cksum` idiom
  `code-review/hooks/conventions.sh` and `lean/hooks/budget.sh` already used.
- **The smoke harnesses could not see it.** `comment-discipline-hook-tests.sh` and
  `comment-density-tests.sh` sent `session_id` and no `transcript_path`, so 40+ cases
  only ever exercised the fallback branch and stayed green throughout. Both now assert
  the real payload shape: the deny fires, the second edit of one file is bounded, the
  cap engages, and the state file actually lands on disk.

## 0.6.2

### Changed
- **`/comment-discipline:review` hands the whole scope to `/code-review:review`** when the resolved
  scope reaches outside this plugin's stack surface and that plugin is installed.
  `code-review` already declared itself the fan-in for overlapping review surfaces, but
  only the aggregator knew it — entering through a stack command left the other stacks
  in a multi-stack diff unreviewed, or produced the duplicate findings the fan-in exists
  to prevent. The clause lives in `templates/blocks/triage.md`, shared by all 26
  generated stack reviews.

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
