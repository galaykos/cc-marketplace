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

## No AI attribution in git history

A `PreToolUse` hook, `hooks/no-ai-trailer.sh`, denies any `git commit`, `git
merge`, `git tag`, `gh pr create` / `gh pr merge` whose message carries a
`Co-Authored-By: Claude …` trailer or a "Generated with Claude Code" line, and
any `Write`/`Edit` that plants the same text into a git message file
(`COMMIT_EDITMSG`, `MERGE_MSG`, anything under `.git/`). The deny reason tells
the model to drop the lines and run the same command again.

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
| AI trailer in a commit/merge/tag/PR command | **gate** — blocks the tool call | `permissionDecision: deny`; the command does not run |
| AI trailer written into a git message file | **gate** | denied on `Write`/`Edit` whose path is a git message file |
| the matching rules | **gate**, tested | `scripts/__tests__/no-ai-trailer.test.sh`, run in CI with every plugin harness (recount the assertions there; none is quoted here) |
| a human `Co-authored-by:` trailer | **allowed by design** | only trailers naming Claude or Anthropic match |
| `git commit -F <pre-existing file>`, a repo `prepare-commit-msg` hook, `git config trailer.*`, a commit outside the session | **unenforceable** | the message never crosses a matched tool call; silence means "no known shape matched", not "history is clean" |
| finish / clean-gone / worktree protocols | **recorded** | prose the model follows; nothing reads it back |

Fail-open, deliberately: missing `jq`, unparseable input, any internal error —
the hook stays silent, exits 0, and the command proceeds. The harness asserts it.

## Pairs well with

- **taskmaster** / **task-runner** — a worktree per task run, and the finish
  protocol to close the run out
- **code-architecture** — its work-verification discipline backs every gate in
  this plugin
