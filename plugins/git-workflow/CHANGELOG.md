# Changelog — git-workflow

Consumer-facing changes only. Newest first. Started at 0.13.5; earlier versions have no entries rather than invented ones.

## 0.13.7 — 2026-10-31

- **`/git-workflow:clean-gone` no longer deletes a branch just because its upstream is `[gone]`.** A remote branch can be deleted unmerged (a closed PR, a branch sweep), and a commit made after the last push never reached the remote, yet the command ran `git branch -D` on all of them. The new `scripts/gone-branches.sh` sorts each `[gone]` branch into merged, content-merged (squash and rebase merges), unmerged or skipped against the default branch; `commands/clean-gone.md` offers only the first two in its one delete-all pick and deletes an unmerged branch only when it is named and confirmed on its own after a warning. Every printed command single-quotes the branch. `scripts/__tests__/gone-branches.test.sh` covers each class.

## 0.13.6 — 2026-10-28

- **Comments cut to what a reader needs; behaviour unchanged.** `hooks/merge-checks.sh` (shared-block comments): each keeps a header saying what it does and misses, and one line per trap the code cannot show; the history moved to the marketplace repository's rationale/derivations/, which an install does not contain.

## 0.13.5 — 2026-10-28

- **Hook comments cut to what a reader needs; behaviour unchanged.** `hooks/merge-checks.sh`, `hooks/no-ai-trailer.sh`: each keeps a header saying what it catches and misses, and one line per trap the code cannot show; the history moved to the marketplace repository's rationale/derivations/plugin-git-workflow.md, which an install does not contain. Every hook parses to the same code as before (comments ignored).
