# git-workflow

Git workflow discipline: an isolated worktree per feature branch (proven-ignored
location, deps installed, baseline suite run before any change), a structured
finish protocol for development branches (verify, present options, merge/PR/park,
clean up), review-exchange rigor on both sides of a code review, and a guard
that keeps AI attribution out of git history.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install git-workflow@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/git-workflow:finish [branch]` | Verify the full suite, show branch state evidence (diffstat, ahead/behind, commits), ask PR / keep / discard (plus merge-locally only when the base is not the default branch — the default branch is reached via PR only), execute the choice including worktree and branch cleanup |
| `/git-workflow:clean-gone [--dry-run]` | Fetch with prune, list every local branch whose upstream is `[gone]` with its worktree, skip the current branch and any dirty worktree, ask once, then remove worktrees and `-D` the branches — the sweep for PRs merged and deleted somewhere other than `/git-workflow:finish` |

## Example

```bash
/git-workflow:finish                            # finish the current branch
/git-workflow:finish feature/orders-csv-export  # finish a named branch
```

The finish command never assumes a destination: a red suite stops it cold, a
green one gets state evidence and an explicit choice. The default branch is
PR-only — "merge locally" is offered only when the base is a non-default branch,
and committing straight onto the default branch routes you to a branch + PR
instead. Merges re-run the full suite on the merged result before any branch or
worktree is deleted; discards require typing the branch name back; headless runs
report options and touch nothing.

Credit: in `branch-completion`, the no-template PR body's before/after evidence and
reversibility line adapt rules from mattpocock/skills v1.2.3 (MIT, © 2026 Matt Pocock),
and the merge protocol's conflict rule (resolve from each side's intent, never `--abort`
to dodge a hunk) comes from an earlier (2026-09-02) read of mattpocock/skills. Both are
rewritten here rather than copied.

## No AI attribution in git history

A `PreToolUse` hook, `hooks/no-ai-trailer.sh`, denies any history-writing git or
`gh` command whose message carries a `Co-Authored-By: Claude …` trailer or a
"Generated with Claude Code" line — `git commit`, `merge`, `tag`, `notes`,
`rebase`, `cherry-pick`, `am`, and `gh pr` / `gh release` / `gh repo`
`create|merge|edit|comment` — and any `Write`/`Edit` that plants the same text
into a git message file (`COMMIT_EDITMSG`, `MERGE_MSG`, `SQUASH_MSG`,
`TAG_EDITMSG`, anything under `.git/`). It matches at a command position, so a
wrapper (`sudo`, `bash -c`, `VAR=1 …`, an absolute path, any `git` global option)
does not get past it. The deny reason tells the model to drop the lines and run
the same command again.

Why a hook and not a sentence: the host setting `attribution.commit: ""` in
`~/.claude/settings.json` switches off the host's own trailer, and nothing else.
The model still wrote the trailer from habit (observed on Claude Code 2.1.266,
2026-09-09, setting present since 2026-09-03), and a skill saying "never add AI
attribution" did not stop it. A rule nothing reads back is `recorded`; this is
the reader.

Nothing to configure. To disable it for a session that WANTS the trailer, set
`CLAUDE_AI_TRAILER=allow` in the hook's environment (Claude Code: the `env`
block of a settings file). Check a command by hand:

```bash
bash hooks/no-ai-trailer.sh --check 'git commit -m "x

Co-Authored-By: Claude <noreply@anthropic.com>"'   # exit 2 = deny
```

## What has teeth

Standing markers per the marketplace convention (see
`.claude/skills/authoring-skills/SKILL.md` in the marketplace repository).

| Control | Standing | What actually happens |
|---|---|---|
| AI trailer in a commit/merge/tag/notes/rebase/cherry-pick/am or `gh` pr/release/repo command | **gate** — blocks the tool call | `permissionDecision: deny`; the command does not run |
| AI trailer written into a git message file | **gate** | denied on `Write`/`Edit` whose path is a git message file |
| the matching rules | **gate**, tested | `scripts/__tests__/no-ai-trailer.test.sh`, run in CI with every plugin harness (recount the assertions there; none is quoted here) |
| a human `Co-authored-by:` trailer | **allowed by design** | only trailers naming Claude or Anthropic match |
| `git commit -F <pre-existing file>`, a repo `prepare-commit-msg` hook, `git config trailer.*`, a commit outside the session | **unenforceable** | the message never crosses a matched tool call; silence means "no known shape matched", not "history is clean" |
| finish / clean-gone / worktree protocols | **recorded** | prose the model follows; nothing reads it back |

Fail-open, deliberately: missing `jq`, unparseable input, any internal error —
the hook stays silent, exits 0, and the command proceeds. The harness asserts it.

## Mods (Claude Code ≥ 2.1.291)

Since 0.11.0 the plugin also ships a hooks module, `hooks/suggest.ts`, listed under
`modules` in `hooks/hooks.json` beside the classic trailer guard, which fires with or
without it.

- **Finish suggestion.** When a main-loop turn ends and task-runner's
  `.claude/task-runner/gate-pass.json` (at the git toplevel) records a green completion
  gate whose `head` is the current `HEAD` — every card done or parked, or no card counts
  at all (a plain run) — on a branch that is not the default branch (`origin/HEAD`, else
  `main` or `master`) and whose upstream (`@{u}`) is not already at that head, the prompt
  box offers `/git-workflow:finish` as a Tab-to-accept suggestion. It never runs the
  command; nothing happens until you accept and press Enter.
- **Once per gate head per session.** Counted only when Claude Code reports the suggestion
  shown; one not shown is offered again at the next turn end while the gate still matches
  `HEAD`. Nothing is offered while a phase sentinel is live: a `.claude/cc-phase.json`
  under two hours old that this session holds or that names no session.
- **What a finished branch looks like to it.** A pushed upstream at the gate head is read as
  finish's PR path having run. A branch finish kept open (never pushed), or merged locally
  into a non-default base by fast-forward, is still offered once per session; a branch
  pushed by hand without a PR is silenced as if finished.
- **Off switch.** `CC_SUGGEST=off` silences this marketplace's next-step suggestions
  (taskmaster, task-runner, code-review, git-workflow); there is no `/config` option.
  Another plugin's suggestion can take the one slot after this one, a suggestion shown and
  then replaced counts as shown, and Claude Code's own suggestion is not suppressed.
- **CLI floor.** With mods off in the host or on a CLI below 2.1.287 no module loads; on
  2.1.287-2.1.290 its turn-end hook passes through. It registers no `tool.call` hook when
  it runs (on CLI 2.1.291, `claude plugin validate --strict` still lists the shared kit's
  conditional one as `tool.call{tool=?}`), so 2.1.287's bug with plugin `tool.call` hooks
  in worktree subagents should not reach it — not measured on 2.1.287; if it does,
  upgrade the CLI or turn mods off.
- **What it trusts.** The gate record, not the tree: edits left uncommitted after a green
  gate do not move `HEAD`, so the suggestion still fires.

Standing: **gate** — `tests/suggest.test.ts` runs under `claude plugin test` in CI (the
marketplace repository's `scripts/mod-tests.sh`), so a regression in a tested case fails
the build; the sentinel's two-hour and no-session clauses rest on the shared kit's own
tests there. Untested here: the real prompt box (the test kit answers whether a suggestion
was shown), a subagent's turn end, and an unparseable gate record.

## Pairs well with

- **taskmaster** / **task-runner** — task-runner's `--tracks` runs milestones in
  worktrees; this plugin's finish protocol closes the run out
- **code-architecture** — its work-verification discipline backs every gate in
  this plugin
