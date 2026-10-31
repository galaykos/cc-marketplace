---
description: Remove local branches whose upstream is [gone], worktrees first — lists, asks once, skips dirty ones.
argument-hint: "[--dry-run]"
allowed-tools: Bash(git fetch:*), Bash(git branch:*), Bash(git worktree:*), Bash(git status:*), Bash(git rev-parse:*), Bash(bash "${CLAUDE_PLUGIN_ROOT}/scripts/gone-branches.sh")
---

# /git-workflow:clean-gone

Sweep the branches a finished PR leaves behind. `branch-completion` cleans up the
branch it just finished; this command catches the ones finished elsewhere — merged
from the web UI, deleted by a teammate, squash-merged by a bot.

## Context (preloaded)

- Current branch: !`git branch --show-current`
- Upstream state after prune: !`git fetch --prune --quiet 2>/dev/null; git branch -vv | grep '\[gone\]' || echo "(no [gone] branches)"`
- Worktrees: !`git worktree list`

## Steps

1. If the prune output says no `[gone]` branches, say so and stop.
2. Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/gone-branches.sh"`. Its first line names the
   default branch it compared against and how it found it; every other line is
   `<class>\t<branch>\t<worktree or ->\t<detail>`. On exit 1 (not a repo, no
   default branch) print its message and stop.
3. Build three lists from its rows, each with the branch's worktree path if any:
   - **Merged**: `merged` and `content-merged` rows (a squash or rebase merge reads
     as the second), with the detail.
   - **Unmerged**: `unmerged` rows, with the commits the detail names. A `[gone]`
     upstream says the remote branch was deleted, not that its commits landed: a
     closed PR or a branch sweep deletes unmerged work too, and a commit made after
     the last push never reached the remote at all.
   - **Skipped**: `skipped` rows (current, default, main-worktree, dirty or
     unreadable worktree), with the reason. Nothing here deletes them.
4. With `--dry-run` in `$ARGUMENTS`, print the lists and stop.
5. Otherwise ask once (AskUserQuestion): delete every merged branch / pick by name /
   stop. The first option never includes an unmerged branch; drop it when the merged
   list is empty. For each unmerged branch the user names, show its commits and this
   warning, then confirm that branch alone (delete / keep): "`<branch>`'s commits are
   not on `<default>` and its remote branch is gone, so this may be the only copy."
   A headless session prints the lists and the commands below and stops — this
   deletes local history, so it never runs without a pick.
6. For each picked branch, in this order, with every `<branch>` and `<path>`
   single-quoted (a refname can hold `$(…)`; a `'` inside one becomes `'\''`):

   ```bash
   git worktree remove '<path>'      # only when the row names a worktree; not --force
   git branch -D '<branch>'
   git worktree prune
   ```

   On a merged or content-merged branch `-D` is needed, not reckless: a squash or
   rebase merge never looks merged to `-d`, so the script's check is the evidence. On
   an unmerged branch `-D` runs only after the per-branch confirm in step 5.
7. Report one line per branch (removed / skipped and why), then the remaining
   worktree list.

## Standing

Gate for the classification: `scripts/__tests__/gone-branches.test.sh` builds
merged, squash-merged, rebase-merged, deleted-unmerged, committed-after-push and
dirty-worktree branches against a bare origin and asserts each one's class. Recorded
for everything after it: the pick is the user's, and nothing checks that an unmerged
branch was deleted only after its confirm. `allowed-tools` pre-approves the commands
it lists and restricts nothing. Ported from the official `commit-commands` plugin's
`/clean_gone` recipe, with the confirm step, the dirty-worktree guard and the merge
classification added.
