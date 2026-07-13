---
name: track-orchestration
description: Use when /task-runner:run is invoked with --tracks[=N] to execute a taskmaster card set's independent milestones as concurrent subagent "tracks" — each milestone in its own git worktree+branch, dispatched in strict dependency waves via Workflow, committed then merged by a single sole-writer orchestrator with a preserve-for-bisect final gate. Not for serial runs (that is task-execution). Trigger words: tracks, concurrent milestones, parallel milestones, --tracks, milestone teams, run milestones in parallel.
---

## What this is

The `--tracks` execution mode. One main-thread orchestrator (this skill) runs the
**independent milestones** of a `00-INDEX.md` as concurrent tracks — each a subagent in
its own git worktree — to cut wall-clock. The serial one-card-at-a-time path
(`task-execution`) is unchanged and remains the default; `--tracks` is opt-in.

Read `references/algorithm.md` for the step-by-step algorithm and the exact git and
dispatch commands, and `references/eligibility.md` for how milestone independence is
computed. This file is the contract those references implement.

## The contract

- **Sole index writer.** Only this orchestrator writes `00-INDEX.md`. Track-workers
  never write it, and it never travels into a worktree (it lives in gitignored
  `taskmaster-docs/`). Per-track/per-card status is written by the orchestrator
  **between waves** — a wave is a blocking batch, so status cannot update mid-wave;
  race-freedom comes from the single sequential orchestrator, not from locking.
- **Strict dependency waves, not rolling.** Fan-out is fork-join: a Workflow `agent()`
  batch blocks until all its tracks return. Milestones therefore run in waves — launch
  every currently-launchable eligible milestone (deps already merged) as ONE batch,
  await the whole batch, merge the greens, then compute the next wave. There is no
  merge-on-green-mid-flight.
- **Milestone-level eligibility.** A whole milestone is track-eligible or it is not
  (never split its cards — that inverts dependencies). Non-eligible milestones — those
  that share a file with another candidate, touch a shared/registry file, or still have
  an unmet dependency — run **serially in the main tree by the orchestrator**, in
  dependency order, interleaved with the waves.
- **One worktree + one branch per track.** Named `<run-branch>-track-<slug>` where
  `<slug>` is a git-ref-safe milestone slug. The orchestrator creates the worktree and
  its `<wt>/.claude/task-runner/` directory before dispatch.

## Track-worker dispatch

Each track-worker is a leaf subagent. Its dispatch prompt carries:

- the milestone's card **text** inline (workers never read the gitignored index),
- the worktree **absolute path**, and the rule that a subagent's cwd resets between bash
  calls — so **every command must be pinned** (`git -C <wt> …` or absolute paths),
- the delegation-contracts **discipline preamble** verbatim,
- the instruction to run its cards **inline** — no per-card specialist routing (a leaf
  cannot spawn sub-workers or see the agent registry; per-card routing is a serial-mode
  feature only), and **never** to write `00-INDEX.md`,
- under ultra, the `model` (always) and `effort` (Workflow path only) from the index
  `Ultra:` marker.

The worker **commits** its milestone's work to its track branch and returns a compact
evidence report: touched files, verify evidence, and the commit sha — or a park reason.
A worker that does not return within its dispatch timeout is treated as a parked-timeout.

## Status the orchestrator writes

Between waves, the orchestrator updates each milestone's status in `00-INDEX.md`. The
per-track lifecycle is:

- `queued` — eligible, waiting for a free slot or an unmet dependency to merge.
- `running(worktree)` — dispatched to a track-worker in its worktree this wave.
- `merged` — its branch merged clean into the run branch (with the commit sha).
- `parked(reason)` — a merge conflict, an undeclared-overlap, or a timeout; retained
  for inspection and listed in the backlog.

This stays inside the single 00-INDEX view — no separate dashboard or run board (the
"no status theater" rule holds). The status is a plain reflection of where each track
is, written only by the orchestrator turn, never by a worker.

## Merge, park, and partial failure

- Before merging a green track, diff its worktree's **actually-touched** files
  (`git -C <wt> diff --name-only`) against the milestone's declared file-set. Any
  undeclared file overlapping another track → **park** the track (do not merge).
- A textual merge conflict → **park** with the conflicting files as evidence; never
  auto-resolve (a conflict means the disjoint guarantee was violated — surface it).
- Partial failure: merge the greens, run the serial milestones, run the final gate on
  the merged result, and report parked/timed-out tracks (and dependents blocked behind
  them) as a follow-up backlog. If the merged set is empty or a parked root cascades the
  whole graph, report the run **failed / no-op** — never a green completion.

## Final gate and the red-gate protocol

After all tracks merged and serial milestones ran, run one full project check suite on
the merged run branch. Disjoint files do **not** prevent semantic breakage, and each
track's in-worktree green was verified against a base that lacked the other tracks — so
per-track green is stale after merge. Therefore:

- **Retain** every track branch and worktree until the final gate is green.
- On a **red** final gate over cleanly merged tracks, do **not** auto-rollback: report
  the failure and **preserve** the run branch + all track branches + worktrees so the
  user can bisect which track's change broke integration.
- Only after a **green** final gate: delete merged track branches, remove their
  worktrees, then hand off to `git-workflow:finish` on the single run branch.

## Preconditions, cleanup, and degradation

- **Run branch.** Tracks require a dedicated non-base run branch and a clean main tree.
  If invoked on a protected/base branch (master/main) or a dirty tree, create or require
  a run branch first, or refuse with guidance — track merges must never land on a base
  branch and must reach the `git-workflow:finish` gate.
- **Ownership + liveness.** Write a `.claude/task-runner/tracks-run-<id>.lock` marker.
  Worktrees live under `.claude/worktrees/`. Cleanup and orphan detection touch **only**
  worktrees/branches in this run's `<run-branch>-track-*` namespace, cross-checked
  against `git worktree list`; foreign worktrees and any other live run's worktrees are
  never targeted. Parked/dirty worktrees are retained (never `--force`-removed) so
  evidence survives.
- **Degradation / kill-trigger.** If the index lacks per-milestone `Files:` sets, or
  0–1 milestone is eligible, warn and fall back to the serial `task-execution` path. If
  worktree/merge orchestration proves flaky in practice, `--tracks` degrades to a
  warning + serial run — the default path is always available.
