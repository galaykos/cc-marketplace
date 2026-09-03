---
description: Remove local branches whose upstream is [gone], worktrees first — lists, asks once, skips dirty ones.
argument-hint: "[--dry-run]"
allowed-tools: Bash(git fetch:*), Bash(git branch:*), Bash(git worktree:*), Bash(git status:*), Bash(git rev-parse:*)
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
2. Build the list: one row per `[gone]` branch — name, last subject, and the worktree
   path if `git worktree list` shows one for it. Exclude the current branch (a `*`
   row) and any branch whose worktree has uncommitted changes (`git -C <path> status
   --porcelain` non-empty): print those as **skipped, with the reason** rather than
   deleting under them.
3. With `--dry-run` in `$ARGUMENTS`, print the list and stop.
4. Otherwise ask once (AskUserQuestion): delete all listed / pick by name / stop. A
   headless session prints the list and the commands below and stops — this deletes
   local history, so it never runs without a pick.
5. For each picked branch, in this order:

   ```bash
   git worktree remove <path>        # only when a worktree row exists; not --force
   git branch -D <branch>            # -D: a gone upstream means the merge happened remotely
   git worktree prune
   ```

   `-D` is deliberate: `-d` refuses branches git cannot prove merged, and a squash
   merge never looks merged locally. The `[gone]` marker is the evidence instead — the
   remote accepted and deleted it. That is also why step 2 excludes anything dirty:
   `[gone]` says the remote is done, not that local work was pushed.
6. Report one line per branch (removed / skipped and why), then the remaining
   worktree list.

## Standing

Recorded. Nothing checks that the dirty-worktree exclusion ran; the `allowed-tools`
list is the only mechanical bound and it permits every git command this needs,
including the deletion. Ported from the official `commit-commands` plugin's
`/clean_gone` recipe, with the confirm step and the dirty-worktree guard added.
