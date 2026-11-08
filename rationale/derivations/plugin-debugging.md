# Derivations — debugging

Each section holds what made a check exist, its measurements and history, so the file's own header stays three lines.

## plugins/debugging/hooks/fix-chain.sh

Added 2026-11-07 (Process track, gitignored `taskmaster-docs/integration-roadmap-2026-11-07.md` item PR1). In session
4552acb6 of `rationale/session-retro-2026-11-05.md` (issue 17) fixes #68–#72 each exposed the next failure: about 5 h
and 6 PRs before anything stopped the chain. `hooks/remind.sh` fires on stuck-loop phrases in the prompt and did not
fire until "am I a joke to you?"; the `suggest.ts` mod offers `/debugging:debug` in the prompt box after the same Bash
command fails twice, which a chain of shipped fixes never does. The signal used here is the commit history: two fix
commits made since the session's first prompt that touch a common file. The first prompt records the session start
(epoch seconds, keyed on the transcript path), so a chain that began in an earlier session is not seen. Merge commits
add no files, so a PR chain counts through its fix-named branch commits. Harness: `scripts/__tests__/fix-chain.test.sh`.

## plugins/debugging/scripts/ci-triage.sh

Added 2026-11-08 (Coding track, gitignored `taskmaster-docs/integration-roadmap-2026-11-07.md` item CT1, from G11 and the
2026-10-31 items DB-1/DB-2). "CI is red" is a symptom the skill's Phase 2 rule, read the FIRST error, applies to, but a
failed-step log reaches the model only as a wall of `gh run view --log-failed` output whose last line,
`##[error]Process completed with exit code 1.`, is the loudest survivor and never the cause. The script does the
selection and the extraction, and nothing else: it neither reruns jobs nor fetches artifacts.

- **gh surface.** Flags were read from `gh run list --help` and `gh run view --help` on gh 2.46.0 (2026-11-08):
  `--branch`, `--commit`, `-L`, `--json`, `--jq`, `--log-failed`, `-R`. `run list --json` offers `databaseId` and
  `conclusion`; `run view --json` adds `jobs`. With no token and an empty `GH_CONFIG_DIR`, `gh run list`, `gh run view`
  and `gh pr view` all exit 4 and print "To get started with GitHub CLI, please run: gh auth login" before any request
  (probed offline the same day); the script maps that, `HTTP 401` and "Bad credentials" to its exit 3. NOT observed live:
  the `jobs[].steps[]` JSON shape and the `--log-failed` line shape (`<job>\t<step>\t<timestamp> <text>`, a BOM on a
  step's first line) come from gh's source and GitHub's log format, and the harness's stub encodes that reading. No real
  repository was queried.
- **Selection.** Failed means `failure`, `timed_out` or `startup_failure` (cancelled is not). The newest such run among
  the last 50 wins, even when a later run passed: the residual named in the header. `--pr` reads the head commit
  (`gh pr view --json headRefOid`) and lists runs on that commit, so a failure on an earlier push is not reported as
  the PR's state.
- **First error.** Patterns, first match in log order wins: pytest `E   ` lines and `FAILED`/`ERROR` summaries, PHPUnit
  "There was/were N failure(s)/error(s):", Jest `●` (not `● Console`), a `FAIL` line (Jest, Vitest, go), `--- FAIL:`,
  `panic:`, a Python traceback, `error:`/`error[E…]:`/`error TS…:` after a line start, `: ` or ` - ` (gcc, clang, rustc,
  tsc, javac), `file.go:L:C:`, a generic `XxxError:`/`Exception:`/`ERROR:`/`FATAL:`/`fatal:`, `##[error]` and `npm ERR!`.
  The exit-code annotation is excluded. Context is 3 lines before (go prints the message above `--- FAIL:`) and 6 after
  (PHPUnit and Jest print it below). No match prints the last 10 lines and says so. The harness covers seven formats;
  `● Console`, `npm ERR!`, tracebacks, `panic:`, `file.go:L:C:` and the pytest summary lines have no case of their own.
- **Untrusted text.** Workflow authors (a fork's PR included) control the log, the job and step names and the commit
  title. The title is never printed. Names are stripped and cut at 120 bytes, the log at 240 bytes per line and 8 MiB in
  total. A NUL, a BOM, CSI and OSC escapes, C1 controls, bidi overrides and every other control byte but tab and newline
  are stripped before anything is matched. The block prints inside a fence one backtick longer than the longest run in it,
  so a fence in the log cannot close it, after a line saying it is data. Nothing from the log reaches `eval`, a command
  substitution or an argument position; the harness plants `$(touch …)` and backticks and checks no file appears.
- **Exit 4.** The roadmap named 0/1/2/3. A network error, an unknown repository, run or PR is none of them, and reporting
  it as "no failed run" would be false, so it has its own code.

## plugins/debugging/hooks/probe-guard.sh

Added 2026-11-08 (same roadmap item, DB-2). The skill tags every temporary probe with one unique `[DEBUG-<id>]` prefix
so cleanup is one grep, and its verification step 3 is that grep. It was `recorded`: "no hook runs the grep, so a
survivor is yours to find". This hook checks the one moment a survivor becomes history, the commit, and only that.

- **What it reads.** The staged diff (`git diff --cached -U0 -G'\[DEBUG-'`), added lines only, with new-file line
  numbers from the hunk headers. `-a`/`--all` (found in the commit's own options after quoted values are dropped; a short
  cluster stops at `m F c C t`, which take a value) switches to `git diff HEAD`, the tracked changes `-a` would stage;
  with no HEAD yet it stays on the index. Pathspec, `--only` and `--include` commits take working-tree content the hook
  does not read: named in the header. `--amend` reads the same staged diff; a marker already in the commit being amended
  is not seen.
- **Command position.** The anchor and wrapper tokens copy git-workflow's `no-ai-trailer.sh` `GIT_WRITE_RE` with the
  verb `commit` only, plus a `-C <dir>` / `-c <key>=<value>` pair between `git` and the verb. Matched case-insensitively
  so `GIT_AUTHOR_NAME=x git commit` counts. The diff is read in the payload's cwd, so a `cd` or `git -C` into ANOTHER
  repository earlier in the command is missed; inside the same repository the index is the same.
- **Git safety.** `--no-ext-diff`, `--no-textconv`, `-c core.fsmonitor=false` and `GIT_OPTIONAL_LOCKS=0`: no repository
  config runs a command from the hook, and it takes no index lock just before the commit that needs one.
  `-c diff.relative=false` and explicit `a/`/`b/` prefixes keep paths whole whatever the user's diff config says.
- **Ask, not deny.** The roadmap asked for an ask. `.claude/skills/authoring-hooks/SKILL.md` records that an unanswered
  ask idles a background run and is a deny under `-p` (session retro 2026-10-13); a headless commit that stages a probe
  is therefore refused, which is the cost of the check. A doc line that quotes the marker (this plugin's own SKILL.md and
  harnesses) asks too: approve it.
- **Timeout.** 10 s. A PreToolUse hook killed at its timeout is a non-blocking error, so the commit proceeds: fail open.
- **Lane.** `permissionDecision` brings a Pre/PostToolUse hook under `pc_lanes_coverage`, so it has the row
  `debugging:probe-guard` with the new noun `debug-probe-commit-consent`. The off switch `CC_PROBE_GUARD` mirrors the
  plugin's `cc_probe_guard` option, as command-guard, database and git-workflow do for their ask guards.
  Harness: `scripts/__tests__/probe-guard.test.sh`; four mutants (worktree diff, any git verb, any added line, no value
  stop in a short cluster) each fail at least one of its cases.
