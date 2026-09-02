---
name: worktree-isolation
description: Use when feature work needs isolation from the current workspace — one worktree per branch, deps and baseline suite BEFORE any change, lifecycle ending at removal; also when a worktree is not worth the setup.
---

## One branch, one directory

A worktree gives a branch its own checkout against the same object store: the
main directory keeps its dirty state, its running dev server, its half-done
experiment, while the feature gets a clean tree. That beats stash-and-switch,
which destroys flow twice per interruption, and beats a second clone, which
forks remotes and doubles fetches. The unit is strict: one worktree per feature
branch. A worktree that hosts three features in sequence inherits the previous
feature's stale deps and leftover artifacts — a clone with extra steps.

## Prefer the harness's own worktree

Claude Code ships `EnterWorktree` / `ExitWorktree`. `EnterWorktree` creates the
worktree under `.claude/worktrees/`, switches the session's working directory
into it, and prompts the user to keep or remove it at session exit; `Agent`'s
`isolation: "worktree"` does the same for one subagent and auto-cleans it if the
agent changed nothing. When those tools are available, use them — a
harness-created worktree is a harness-tracked worktree, and the exit prompt is a
lifecycle guarantee this skill can only ask for. Everything below still applies
inside it: the baseline run, the dependency install, the one-branch-one-directory
unit.

Two constraints come with the tool. It refuses to create a second worktree from
inside a worktree session (pass `path` to switch into an existing one instead),
and the harness only reaches for it on an explicit request — the tool's own rule
is to use it only when the user or project instructions say "worktree". Neither
changes what you do; both change the error you get if you assume otherwise.

## Where it lives

Never place a worktree bare inside the repo's working tree: git sees a whole
untracked checkout, status becomes noise, and one careless `git add -A` commits
it. Safe locations, in preference order:

1. `.claude/worktrees/<branch>` — where `EnterWorktree` puts them, so a hand-made
   worktree lands where the harness and the rest of this marketplace already look
   (`task-runner`'s track orchestration uses the same root). Confirm it is ignored;
   Claude Code's own `.gitignore` line usually covers it.
2. An existing project convention — if a different worktree directory is already
   in use, join it rather than inventing a second one.
3. A sibling directory outside the tree: `../<repo>-worktrees/<branch>` — the right
   answer outside a git repo, or when the worktree must outlive the checkout.
4. Any other project-local directory that is PROVEN ignored, only after
   `git check-ignore -q <dir>` exits 0. Not ignored → add it to `.gitignore`,
   commit that, then create the worktree.

## Detect isolation before creating it

If `git rev-parse --git-dir` and `git rev-parse --git-common-dir` resolve to
different paths, this session is already inside a linked worktree — creating
another from here nests isolation nobody asked for. One caveat: submodules
also split those paths; if `git rev-parse --show-superproject-working-tree`
prints anything, treat the checkout as a normal repo, not a worktree.

## Create

```bash
git worktree add "$LOCATION/$BRANCH" -b "$BRANCH"   # from the base commit
cd "$LOCATION/$BRANCH"
```

Branch from an up-to-date base (`git fetch` first); a worktree cut from a
week-old main starts life with a merge conflict on layaway.

## Setup is part of creation

A fresh worktree contains source, not an environment. Install dependencies
lockfile-faithfully — `npm ci`, `composer install`, `pip install -r`,
`go mod download` — never an update command that mutates the lockfile just to
get running. Untracked files do not travel: `.env`, local certificates, seeded
fixtures exist only in the original checkout. Copy what the app needs
deliberately, item by item; a blind directory copy drags in the exact state the
worktree exists to escape.

## Baseline before the first edit

Run the project's full check suite BEFORE touching anything, and record the
result. This is the attribution line: every failure after it belongs to this
feature; every failure before it is pre-existing. Skip the baseline and the
first red test triggers an archaeology dig through someone else's history.

If the baseline is red, stop and report the failing names — proceeding on a
red baseline requires the user's explicit go-ahead, with the known failures
written down so they are never mistaken for regressions later.

## When a worktree is overkill

The setup cost is real: dependency install plus a full baseline run. Skip the
worktree when isolation cannot outlive that cost — a single-file fix on a
clean tree, a doc correction, any change finished before the next context
switch. Branch in place instead. The worktree earns its keep when work spans
sessions, when the main checkout must stay runnable, or when parallel agents
each need a tree of their own.

## Dev servers, ports, shared state

The main checkout's dev server keeps serving the main checkout — it never sees
worktree edits, and "why isn't my change showing" wastes an afternoon. Run a
second server from the worktree on its own port; two watchers on one port
silently fight over it. Databases, docker volumes, and caches are usually
shared per-machine, not per-tree: a migration run from the worktree rewrites
the schema under the main server too. Name that blast radius before running it.

## The lifecycle ends at REMOVE

Create → work → merge or abandon → remove. There is no "keep around" state:
stale worktrees rot — their deps drift from the lockfile, their base commit
ages, they pin disk, and they hold refs hostage (`git branch -d` refuses while
any worktree has the branch checked out). Recreating a worktree costs minutes;
auditing a six-week-old one costs trust.

Removal runs from the MAIN checkout root, never from inside the tree being
removed (the command fails when CWD is the victim):

```bash
git worktree remove <path>
git worktree prune            # clears stale registrations
git branch -d <branch>        # merged work
git branch -D <branch>        # only for an explicitly confirmed discard
```

Order matters: worktree first, branch second — and only remove worktrees this
workflow created; a harness-provided workspace is the harness's to reclaim. That
cuts both ways under `.claude/worktrees/`: a tree another owner created — the
harness via `EnterWorktree`, or a live `task-runner --tracks` run holding its
`<run-branch>-track-*` trees until the final gate — is not yours to remove, and
`git worktree list` is the check that tells you which is which.

Per-agent worktrees for parallel subagent WRITERS are the orchestration
plugin's delegation-contracts skill; this skill covers feature branches.

## Anti-patterns

- A project-local worktree directory whose ignore status was assumed, not
  proven with `git check-ignore`.
- Hand-rolling `git worktree add` when `EnterWorktree` was available — the
  session stays in the old directory and the exit-time keep/remove prompt never
  fires, so the lifecycle rule above has nothing enforcing it.
- Creating a worktree from inside a worktree because detection was skipped.
- First edit before the baseline run — every later failure is now ambiguous.
- Bootstrapping with `npm install` / `composer update` and diffing the
  lockfile before writing a single line of feature code.
- One long-lived worktree recycled across features.
- `rm -rf` on the directory, leaving git's registration dangling — removal is
  `git worktree remove` plus `prune`, nothing less.
- Keeping a merged branch's worktree "just in case" — the case never comes,
  and recreation is cheaper than rot.
