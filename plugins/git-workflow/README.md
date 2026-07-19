# git-workflow

Git workflow discipline: an isolated worktree per feature branch (proven-ignored
location, deps installed, baseline suite run before any change), a structured
finish protocol for development branches (verify, present options, merge/PR/park,
clean up), and review-exchange rigor on both sides of a code review.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install git-workflow@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/git-workflow:finish [branch]` | Verify the full suite, show branch state evidence (diffstat, ahead/behind, commits), ask PR / keep / discard (plus merge-locally only when the base is not the default branch — the default branch is reached via PR only), execute the choice including worktree and branch cleanup |

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

## Pairs well with

- **taskmaster** / **task-runner** — a worktree per task run, and the finish
  protocol to close the run out
- **code-architecture** — its work-verification discipline backs every gate in
  this plugin
