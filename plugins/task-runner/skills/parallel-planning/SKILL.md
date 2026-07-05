---
name: parallel-planning
description: Use before executing any task list of three-plus tasks — or when asked "subagents or inline?" — to compute the parallelization plan: dependency levels, disjoint-file groups, recommended agent count, estimated speedup, and an inline-vs-delegate verdict the user can accept or override.
---

"Subagents or inline?" is a calculation, not a preference question. The task
list already contains the answer: its dependency graph bounds what can run
concurrently, its file sets bound what can run safely, and task sizes bound
whether spawning an agent costs more than it saves. Compute the plan, show
the arithmetic, recommend — and leave the pick to the user.

## Inputs

From the task list (taskmaster cards, a plan's steps, a todo list):

- Dependencies: each task's `Depends on` (or inferred ordering).
- File sets: the files each task lists. Tasks without file lists cannot be
  proven disjoint — treat them as conflicting until listed.
- Size class per task: S (≲15 min — single-file edit, config change),
  M (≲45 min — a card-sized unit), L (longer — should probably be split
  before planning; flag it).

## The computation

1. Topo-sort into levels: level 0 = no dependencies, level N = depends only
   on earlier levels. Cycles are a task-list bug — halt and report.
2. Within each level, group tasks whose file sets are mutually disjoint.
   Shared-file tasks stay serial within the level (or get the shared edit
   extracted into its own task — the better fix).
3. Critical path = the dependency chain with the largest summed size weight
   (S=1, M=3, L=8). Serial cost = sum of all weights.
4. Theoretical speedup = serial cost / critical-path cost. This is the
   ceiling; overhead lowers it.
5. Overhead per delegated task: agent spawn + context load (~1–2 min
   equivalent), PLUS the runner re-verifying every returned task itself
   (never trust "done" — task-execution skill rule), PLUS card-writing tax
   if tasks are not yet self-contained.
6. Recommended agent count = min(widest group, 6). Past ~6 concurrent
   agents, coordination and re-verification serialize anyway; more agents
   add queue, not speed.

## The verdict rule

Recommend DELEGATE when ALL hold:

- Adjusted speedup ≥ 1.5× (theoretical speedup after overhead).
- Every parallel task passes the fresh-session test: executable from its
  own text with zero conversation context (taskmaster card standard).
- File sets provably disjoint — no two concurrent tasks touch one file.
- Parallel tasks are size M or better; delegating an S task spends more on
  spawn than on work.

Otherwise recommend INLINE. Borderline (1.2–1.5×): present both, note the
tie, default inline — predictability beats a thin win.

The recommendation is OPTIONAL by contract: present the table, take the
user's pick. Never silently spawn a fleet.

## Output shape

    Level 0: tasks 01-08 — disjoint files — DELEGATE, 6 agents (8 tasks queue into 6 slots)
    Level 1: task 09 — serial — INLINE
    Level 2: tasks 10-12 — disjoint — DELEGATE, 3 agents
    Level 3: task 13 — integration, shared files — INLINE
    Serial cost 34 units; critical path 9 units; ceiling 3.8x; adjusted ~2.9x
    Verdict: DELEGATE levels 0 and 2 — est. wall-clock ~1/3 of serial.

Show the arithmetic. A verdict without the numbers is a vibe.

## Worked example (real run)

Thirteen cards shipping eight marketplace plugins: level 0 held eight
plugin-creation cards, each touching only its own `plugins/<name>/` dir —
provably disjoint, all size M, fresh-session-ready. Delegated 8 agents:
wall-clock ≈ the slowest single card. Serial estimate: 8× that. Levels for
the meta-plugin (1 scaffold → 3 dependents) ran as one inline task plus a
3-agent group; the final registry card stayed inline because it edited the
three shared files (marketplace.json, README, CHANGELOG) every parallel
variant would have fought over.

## Replanning mid-run

The plan is priced once, then reality edits it:

- A delegated task fails re-verification twice → it reverts to inline
  (task-execution rule); recompute the remaining levels with it serialized.
- A parked task blocks nothing outside its chain → the rest of its level
  proceeds unchanged; its dependents shift to blocked, not attempted.
- New tasks appended mid-run (scope-lock follow-ups) join the LAST level or
  later — never injected into a level already executing.
- Replan the numbers only when the graph changes; a slow-but-passing task
  is not a graph change.

## Failure modes this prevents

- Fleet reflex: spawning agents for a serial chain — dependency levels of
  width 1 gain zero from delegation, pay full overhead.
- Merge-conflict parallelism: two agents editing one file; the file-set
  disjointness gate exists for this.
- Micro-delegation: S tasks shipped to agents that spend longer booting
  than working.
- Context-starved agents: delegating tasks that only make sense with the
  conversation — the fresh-session gate catches these before they fail.
- Trust-the-claim: skipping runner re-verification to make the speedup
  number look better; re-verify cost is part of the honest estimate.

## Boundaries

- Decomposing work INTO tasks is code-architecture's task-orchestration
  skill; this skill takes the decomposition as given and prices execution.
- Execution discipline (scope lock, bounded fix loops, evidence) is the
  task-execution skill — the plan feeds it, never replaces it.
