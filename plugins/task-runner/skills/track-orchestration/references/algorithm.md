# Track orchestration algorithm

The step-by-step the `track-orchestration` orchestrator runs. It is the executable form
of that skill's contract. All git commands are pinned with `-C`; no command relies on an
inherited cwd.

## Definitions

- **run branch** — the dedicated non-base branch the run commits to. Preconditions: not
  a base/protected branch (master/main), and the main tree is clean. Otherwise create or
  require one before launching any track.
- **cap** — `min(eligible, 4)` by default, or the `--tracks=N` value clamped to `[1,6]`.
- **`<wt>`** — a track's worktree path, `.claude/worktrees/<run-branch>-track-<slug>`.

## 0. Setup

1. Verify the run-branch precondition; establish the run branch.
2. Write a liveness marker `.claude/task-runner/tracks-run-<id>.lock` (a unique id).
3. Detect orphans: for each `<run-branch>-track-*` entry in `git worktree list` with no
   live lock, offer cleanup (headless: skip, log). Never list foreign worktrees.

## 1. Classify (per references/eligibility.md)

Read each milestone's normalized `Files:` set. A milestone is **track-eligible** iff its
file-set is disjoint from every other candidate's, it touches no shared/registry file,
and its dependency milestones are not blocking. Everything else is a **serial milestone**
(run by the orchestrator in the main tree, in dependency order). If the index has no
`Files:` lines, or 0–1 milestone is eligible → warn and fall back to `task-execution`.

## 2. Wave loop (strict dependency waves — fork-join)

Repeat until no eligible milestone remains:

1. **Select** the launchable eligible milestones (all their dependency milestones have
   merged), up to `cap`, whose file-sets are also disjoint from each other.
2. **Create** each track's worktree + branch and its worktree-local dir:
   ```
   git branch <run-branch>-track-<slug> <run-branch>
   git worktree add .claude/worktrees/<run-branch>-track-<slug> <run-branch>-track-<slug>
   mkdir -p <wt>/.claude/task-runner
   ```
3. **Dispatch** the wave as ONE `Workflow` `agent()` batch (this blocks until all
   return — that is why scheduling is wave-granular, not rolling). Each track-worker
   dispatch carries the contract in §Dispatch below. Set a per-dispatch timeout.
4. **Await** the whole batch. Update `00-INDEX.md` statuses (only the orchestrator writes
   it): `running(worktree)` → `merged` / `parked(reason)`.
5. **Merge greens** (§Merge). A merge unblocks dependent milestones for the next wave.
6. Interleave any now-unblocked **serial** milestones (run inline in the main tree).

## Dispatch (the track-worker contract)

The prompt to each track-worker contains, in order:

1. The delegation-contracts **discipline preamble** verbatim (Read
   `plugins/orchestration/skills/delegation-contracts/references/discipline-preamble.md`
   and paste it).
2. The worktree **absolute path**, and: *"Your cwd resets between bash calls. Pin every
   command to this worktree with `git -C <abs>` or absolute paths. Do NOT touch any path
   outside it. Do NOT write `00-INDEX.md` (you do not have it)."*
3. The milestone's card **text** inline, in dependency order.
4. *"Run these cards INLINE yourself — do not route to specialist agents (you are a leaf
   and cannot). Apply each card's `Skills to apply` as guidance only."*
5. Under ultra: *"Dispatched at model=<model>"* (and effort=<effort> only because this is
   a Workflow `agent()` dispatch).
6. *"When done: `git -C <abs> add -A && git -C <abs> commit -m '<milestone> (track)'`,
   then return: touched files, the exact verify command + its tail output, and the commit
   sha. If you cannot finish, return a park reason instead — do not force a pass."*

## Merge (per track, on the orchestrator)

1. `git -C <wt> diff --name-only <run-branch>...` → the track's **actually-touched** set.
   If any touched path is undeclared AND overlaps another track's set → **park** (do not
   merge); reason = undeclared overlap + the paths.
2. Else `git -C <repo> merge --no-ff <run-branch>-track-<slug>` into the run branch. A
   textual conflict → `git merge --abort`, **park** with the conflicting files; never
   auto-resolve.
3. On clean merge → status `merged` (record the sha). Keep the worktree+branch for now
   (removed only after a green final gate).

## 3. Serial milestones + final gate

1. After the wave loop, run every remaining **serial** milestone inline in the main tree,
   in dependency order (normal per-card execution, Part A routing available here).
2. Run **one** full project check suite on the merged run branch.
3. **Green** → delete merged track branches, `git worktree remove` their (clean)
   worktrees, drop the lock, hand off to `git-workflow:finish` on the run branch.
4. **Red** (semantic breakage can survive a clean merge — per-track green was verified
   against a base lacking the other tracks) → do NOT rollback. Preserve the run branch,
   all track branches, and their worktrees; report the failure and point the user at the
   retained branches for bisection.

## Partial failure & timeouts

- A track that does not return by its timeout → `parked(timeout)`; retain its worktree.
- Any parked track (conflict / undeclared overlap / timeout) → its dependent milestones
  are blocked; send them to the backlog.
- Merge the greens and run the final gate on what merged. If the merged set is empty, or
  a parked root cascaded the whole graph, report the run **failed / no-op** — never a
  green completion.

## Cleanup ownership (never touch foreign work)

Every remove/delete targets ONLY names matching this run's `<run-branch>-track-*`,
cross-checked against `git worktree list`. Parked/dirty worktrees are retained (never
`git worktree remove --force`) so evidence survives. Foreign worktrees under
`.claude/worktrees/` and any other live run's worktrees are never touched.

## Consumer-repo caveat

This marketplace repo has no dependency install. A consumer repo with dependencies must,
per `git-workflow:worktree-isolation`, install deps (`npm ci` / `composer install`) and
copy untracked env/fixtures into each fresh worktree, and optionally run a baseline,
BEFORE the track-worker's first edit — otherwise its verify fails in a bare worktree.
The "~200–500ms + disk per worktree" cost is for no-install repos; with installs the
per-worktree setup dominates and may erase the parallelism win for small milestones.
