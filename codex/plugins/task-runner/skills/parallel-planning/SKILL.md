---
name: parallel-planning
description: "Use to assess dependency and file-set constraints before parallelizing an existing task list."
---

Read [the Codex execution contract](../../references/codex.md) before using helpers or delegating.

Read task dependencies, exact file sets, and size estimates. Topologically sort the tasks; cycles require correction. Within each level group only mutually disjoint files; shared registries, generated outputs, and implicit interfaces count as coupling. Missing file sets make independence unproven.

Compute serial size weight and critical path using S=1, M=3, L=8 as explicitly unmeasured heuristic units. Their ratio is a speedup ceiling, not a time prediction. Include dispatch context and runner re-verification overhead in the recommendation. Small tasks can share one worker only when that batch has useful concurrent sibling work; otherwise inline avoids overhead.

Report each level's tasks, dependencies, file conflicts, and INLINE/DELEGATE recommendation. Actual worker count is bounded by the current tool's available capacity and policy, never an assumed six slots. If delegation is unavailable or disallowed, name that constraint and run inline. Delegation recommendations do not create user-owned Codex tasks.

Recommend milestone worktree tracks only when the user requested tracks and at least two milestones have complete disjoint file sets and satisfied dependency prerequisites. Follow the native track-orchestration skill for isolation and merge checks. A Goal marker alone is not permission to override the current delegation policy. Recompute when dependencies, task scope, or failures change the graph.
