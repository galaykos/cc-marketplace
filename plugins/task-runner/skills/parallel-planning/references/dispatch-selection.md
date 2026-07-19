# Dispatch selection — S-card batching and auto-pick mechanism

Two computations `parallel-planning` runs once levels, disjoint groups, and the critical
path are known. Both are advisory inputs the runner honors per the rules at the end.

## S-card batching — the BATCH verdict

Today a lone S task is INLINE ("delegating an S task spends more on spawn than on work").
That is right for ONE S task and wrong for a *cluster* of them: the spawn tax a single
delegation cannot justify is amortized when one agent runs several disjoint S-cards.

Form batches per level, after disjoint grouping:

1. **Group by resolved worker.** Take the level's file-disjoint S-cards and group them by
   the worker their `Agent:` tag resolves to (`task-execution/references/routing.md`).
   Mixed-tag S-cards are **never** co-batched — a batch dispatches to ONE worker, so
   mixing tags would silently discard per-card specialist routing. Same-tag (or all
   `generic`) only.
2. **Threshold.** A same-worker disjoint group of **≥3** S-cards becomes a BATCH. A group
   of 1–2 stays INLINE (today's behavior — too small to amortize a spawn).
3. **Cap.** One batch holds at most **8 S-members** (S weight 1 each → weight ≤8 ≈ one L).
   A larger cluster splits into multiple batches of ≤8.
4. **Never spans levels.** All members share one dependency level; a batch is disjoint
   from every other concurrent unit in that level.

### The concurrency gate — the win exists only concurrently

A batch runs its members **sequentially** inside one agent. Sequential-in-a-subagent is
**slower** than sequential-in-the-main-thread (it adds a spawn plus a per-card re-verify
on return). The speedup is real ONLY when the batch runs **concurrently with a sibling
dispatch** at the same level. Therefore:

- Fire BATCH only when the level has **≥2 concurrent units** — two or more batches, or a
  batch alongside a delegate group. Their implementations overlap; wall-clock ≈ the
  largest concurrent unit.
- A **lone** batch (the only work at its level, no sibling dispatch) stays **INLINE** — a
  single agent booting to run cards sequentially is strictly slower than running them
  inline. Do not batch it just because ≥3 S-cards exist.

### Arithmetic

Critical path for a batched level = the summed weight of its **largest concurrent unit**
(largest batch or delegate group), not the level's total. State what each batch runs
concurrently with. A batched level clears the ≥1.5× delegate bar only via that concurrency
— never on "amortized spawn" alone.

### Output

    Level 0: tasks 01-06 — 6 disjoint S (generic) — BATCH ×2, 2 agents (3 each, concurrent)
    Level 0: tasks 01-03 — 3 disjoint S (generic) — INLINE (lone batch, no concurrent sibling)

## Auto-pick — the `Dispatch:` recommendation

`parallel-planning` emits one run-level recommendation:

    Dispatch: default            # the task-execution path
    Dispatch: workflow-tracks    # the --tracks path

- `default` — the `task-execution` serial spine. Its per-level `INLINE` / `DELEGATE` /
  `BATCH` verdicts already decide where subagents run **within** it; "subagent-parallel vs
  serial-inline" is emergent from those verdicts, not a separate mechanism.
- `workflow-tracks` — recommend when **≥2 dependency-independent, file-disjoint milestones**
  are track-eligible (the existing `track-orchestration` eligibility rule, `references/
  eligibility.md`). Otherwise `default`.

| Graph shape | `Dispatch:` |
|-------------|-------------|
| ≥2 independent, file-disjoint, track-eligible milestones | `workflow-tracks` |
| Everything else (flat list, single milestone, shared-file milestones) | `default` |

## How the runner honors this

Default-path per-level delegation is **already today's behavior** — a plain
`/task-runner:run` shows the plan then delegates disjoint groups (`task-execution/
SKILL.md` § Sequencing). BATCH is one more per-level verdict on that same path, so it
introduces **no new silent fleet** and needs no new confirmation.

The **only** genuinely new auto-engage is `workflow-tracks` — it spawns git worktrees:

- **Interactive:** display the recommended mechanism and pre-select it at the existing
  Run-now gate (`plan.md` step 4 / `run` handoff). The user still confirms. Never a
  silently spawned worktree fleet.
- **Hands-off (`Goal:` marker):** auto-engage (goal already auto-takes the plan gate).
- **Preconditions (both cases):** `workflow-tracks` engages only with a **non-base run
  branch + clean tree + per-milestone `Files:` sets**. Unmet → **downgrade to `default`**
  and write the downgrade reason **into the run report** (not merely printed), so a
  hands-off downgrade stays auditable.

Override + boundaries:

- **Explicit flags win.** A user `--tracks[=N]` forces tracks under
  `track-orchestration`'s own **create-or-refuse** contract (auto-picked tracks
  *downgrade*; explicitly-requested tracks *refuse with guidance* on a base/dirty branch).
  Absence-of-flag is the *only* trigger for auto-pick.
- **`--crew` is orthogonal** — a quality flag, not a dispatch flag; it never affects the
  `Dispatch:` computation and is honored independently.
