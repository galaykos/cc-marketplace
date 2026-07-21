---
name: parallel-planning
description: Use before executing any task list of three-plus tasks — or when asked "subagents or inline?": computes dependency levels, disjoint-file groups, agent count, estimated speedup, and an inline-vs-delegate verdict the user can override.
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
- Parallel tasks are size M or better; a *lone* S task spends more on spawn
  than on work — but a **same-worker disjoint S-cluster (≥3)** BATCHes into one
  agent when its level has a concurrent sibling (see Batching below).

Otherwise recommend INLINE. Borderline (1.2–1.5×): present both, note the tie, default
inline — predictability beats a thin win.

INLINE is a claim, not a fallback. On a level holding ≥2 tasks with disjoint file sets,
INLINE must NAME the coupling forcing it — the shared file, the predicate two cards would
each implement, the registry every variant edits, or a lone batch with no concurrent
sibling. No nameable reason → DELEGATE (or BATCH) per the rules above. "Simpler serial"
is not one; nor is a blanket INLINE across a long run's every level — the shape this catches.

The recommendation names each level's verdict AND a run-level `Dispatch:`
mechanism (below); it is the Run-now default and, under a `Goal:` marker,
auto-taken. The default path may delegate disjoint groups/batches as it does
today, but a `workflow-tracks` pick never spawns a worktree fleet without the
Run-now confirmation or the Goal marker. Present the table, then offer the pick
(delegate per plan / inline / adjust).

## Batching and dispatch mechanism

Two extra outputs, both detailed in `references/dispatch-selection.md`:

- **BATCH** a level's file-disjoint **same-worker** S-cards (≥3, ≤8 per batch)
  into one shared agent — but ONLY when the batch runs concurrently with a
  sibling dispatch; a *lone* batch is slower than inline (sequential-in-a-subagent
  adds a spawn over sequential-in-main-thread). One commit per card; per-card
  verify + negative-control + scope check on return; mid-batch park-one-continue.
- **`Dispatch:`** ∈ {`default`, `workflow-tracks`}: `workflow-tracks` when ≥2
  dependency-independent, file-disjoint, track-eligible milestones exist, else
  `default` (whose per-level verdicts decide subagent use within it). The default
  path delegates as today; `workflow-tracks` auto-engages only at the Run-now
  confirmation / under a `Goal:` marker, and only if track preconditions hold
  (else downgrade to `default`, noted in the run report).

## Output shape

    Level 0: tasks 01-08 — disjoint files — DELEGATE, 6 agents (8 tasks queue into 6 slots)
    Level 1: task 09 — serial — INLINE
    Level 2: tasks 10-12 — disjoint — DELEGATE, 3 agents
    Level 3: task 13 — integration, shared files — INLINE
    Serial cost 34 units; critical path 9 units; ceiling 3.8x; adjusted ~2.9x
    Verdict: DELEGATE levels 0 and 2 — est. wall-clock ~1/3 of serial.
    Dispatch: default (per-level verdicts above) — workflow-tracks only with ≥2 independent milestones

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

## Milestone tracks (--tracks)

Beyond the per-level card groups above, check for **milestone-level** concurrency. Read
each milestone's normalized `Files:` set from the 00-INDEX (see task-cards'
`references/milestone-file-sets.md`). When **two or more milestones** are
dependency-independent and file-disjoint and touch no shared/registry file, print a
`Dispatch: workflow-tracks` recommendation (above). It becomes the Run-now default
(interactive) or is auto-taken under a `Goal:` marker, and engages only if track
preconditions hold — never a worktree fleet without that confirmation/marker
(`references/dispatch-selection.md`). This is coarser than the per-card levels above —
the unit is a whole milestone, matching the `track-orchestration` skill's eligibility rule.

## Boundaries

- Decomposing work INTO tasks is code-architecture's task-orchestration
  skill; this skill takes the decomposition as given and prices execution.
- Execution discipline (scope lock, bounded fix loops, evidence) is the
  task-execution skill — the plan feeds it, never replaces it.
- Writing the dispatch prompts and returns is the orchestration plugin's
  delegation-contracts skill; adversarial review, its verification-panels.
