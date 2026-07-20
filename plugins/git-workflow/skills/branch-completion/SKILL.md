---
name: branch-completion
description: Use when implementation on a development branch is finished and the work needs a destination — full-suite verification gate, then merge / PR / keep / discard offered as explicit choices backed by state evidence, executed end to end, leaving no zombie branches or worktrees.
---

## Done code is not a done branch

"Implementation complete" describes the diff, not the branch. A branch is done
when its work has a destination — merged, in review, deliberately parked, or
deliberately destroyed — and its leftovers are gone. Everything between those
states is inventory: unmerged branches age into conflict farms, and every
"finished" branch nobody closed out is a decision someone postponed.

## The verification gate

Before any destination talk, run the project's FULL check suite — tests, lint,
type-check, build, whatever the repo defines — not just the tests near the
change. This mirrors the task-runner plugin's completion gate, and for the same
reason: local passes compose into global failures. A red suite ends the
conversation; there is nothing to merge, PR, or even park with a clear
conscience. Report the failures and fix them first — never present destination
options for a branch that does not pass.

## Evidence, then options

The user chooses the destination; this skill's job is to make that choice
informed. Gather state before asking:

```bash
git diff --stat "$BASE...HEAD"                          # what changed, how much
git rev-list --left-right --count "$BASE...HEAD"        # behind / ahead
git log --oneline "$BASE..HEAD"                         # the commits
```

Present that evidence plus the suite result, then the destination options —
the set depends on the base (see "The default branch is PR-only" below). For a
feature whose base is NOT the default branch, offer all four: merge locally,
push and open a PR, keep the branch open, discard the work. When the base IS
the default branch, drop "merge locally" — offer only push and open a PR, keep
the branch open, discard the work. Never assume which one applies: a branch
that looks obviously mergeable may be an experiment, and a scruffy spike may be
tomorrow's release. Interactive sessions ask via AskUserQuestion; headless
sessions report the evidence and the options, then stop — choosing a
destination is not automatable, and destructive defaults are how work
disappears.

## The default branch is PR-only

The default branch is never a local-merge destination — PR is the sole route
onto it. Resolve which branch that is before offering options:

```bash
def=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)
def=${def#origin/}                                  # e.g. origin/main -> main
[ -z "$def" ] && for b in main master; do           # no remote / HEAD unset:
  git show-ref --verify --quiet "refs/heads/$b" && def=$b && break
done                                                # main/master stay protected
```

The rule binds ONLY to that branch: merging a feature into any other base
(`develop`, a stacked parent) keeps all four options and the Merge protocol.
Two halts, both surfacing rather than acting:

- **HEAD is the default branch** with commits ahead of its upstream (work
  committed straight onto master/main, no feature branch): do not offer it a
  destination. Stop, show the commits, and route the user to move them onto a
  new branch and open a PR — offer to create the branch from here.
- **PR impossible** (base is the default branch but no remote / no `gh`): do
  not silently local-merge onto the default as a fallback. Report that a PR
  cannot be opened and stop; the default branch waits for a real PR.

## Merge protocol

This applies ONLY when the base is not the default branch — a feature based on
the default branch is finished via the PR protocol, never a local merge.

1. Update the base first: `git fetch`, then fast-forward the local base
   branch. Merging into a stale base produces a green merge that explodes on
   push.
2. Merge the feature branch into the base; resolve conflicts in favor of
   intent, not convenience.
3. Re-run the FULL suite on the merged result. The pre-merge pass certified
   the branch against an old base; the merged tree is new code nobody has
   tested. Conflict resolutions are edits like any other.
4. Only after the post-merge suite passes: remove the worktree, then delete
   the branch (`git branch -d` — if it refuses, something is not merged;
   investigate, do not reach for `-D`).

## PR protocol

Push with an upstream (`git push -u origin <branch>`), then write the title
and description from the ACTUAL diff — read `git diff "$BASE...HEAD"` again
rather than trusting session memory, which describes what was attempted, not
what survived. State what the change does, why, and how it was verified; link
the issues it closes. Keep the branch and its worktree alive — review feedback
lands here, and deleting the workspace under an open PR guarantees a rushed
re-setup at the worst moment.

## Keep-open protocol

Parking is a decision, not a default. Record why the branch stays open and
what is still missing, so the next session (or the next person) is not
reverse-engineering intent from a diff. A kept branch keeps its worktree; a
kept branch with no written reason is just a zombie with paperwork pending.

## Discard protocol

Destruction requires friction. Show exactly what dies — the branch name, the
commit list, the worktree path — and require the user to type the branch name
back as confirmation. A "yes" is not enough; typed-name confirmation is what
separates a deliberate discard from an autocomplete accident. Only then:
remove the worktree, `git branch -D <branch>`, and report what was destroyed.

## Refresh the project map

If the repo carries a committed `brain/INDEX.md` (brain plugin) whose `built:` stamp
is behind the merged result, offer `/brain index` (incremental) alongside the
destination step — a branch finish is exactly when the map went stale. Never run it
unasked; it edits committed files.

## No zombies

Cleanup has a fixed order because git enforces one: a branch checked out in
any worktree cannot be deleted, so the worktree goes first, then the branch,
then `git worktree prune` for stale registrations. After merge or discard,
verify the end state:

```bash
git worktree list       # only trees that should exist
git branch --list       # no leftover feature branch
```

Two caveats: never remove a worktree the harness or platform created — report
it instead and let the owner reclaim it — and never run `git worktree remove`
from inside the worktree being removed; `cd` to the main checkout root first.

## Anti-patterns

- Presenting merge/PR options before the full suite has passed — offering
  destinations for broken work.
- Skipping the post-merge suite because "it passed before the merge".
- Picking a destination for the user because it seemed obvious.
- PR descriptions written from memory of the session instead of the diff.
- Discarding on an untyped "yes", or force-deleting a branch because `-d`
  refused and `-D` was quicker than understanding why.
- Deleting the branch first, then wondering why the worktree is orphaned.
- Auto-merging in a headless run — no interlocutor, no destructive action.
- Finishing the merge and leaving the worktree behind "for now" — that is the
  zombie this skill exists to prevent.
- Merging a feature into the default branch locally instead of via a PR — the
  default branch is reached only through review.
- Committing directly on the default branch, then finishing it in place instead
  of moving the work to a branch and opening a PR.
