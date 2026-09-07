---
name: track-orchestration
description: "Use for explicitly requested parallel milestone tracks with isolated Git worktrees and a sole index-writing orchestrator."
---

Read [the Codex execution contract](../../references/codex.md) before using helpers or delegating.

Read the native task-execution skill first. Tracks require at least two independent milestones with complete declared Files sets, available permitted subagent tools, and a dedicated non-base run branch. Preserve user changes; a dirty worktree is not a reason to stash or discard them silently. If isolation or delegation is unavailable, disclose the reason and execute serially.

The orchestrator alone writes 00-INDEX.md. Create one owned branch/worktree per eligible milestone and record ownership under `.codex/cc-marketplace/task-runner/`. Use actual Git worktree commands or available native tools, with explicit absolute working directories. Pass the worker the milestone's full card text, scope and verification contract, worktree path, and available skill paths. Workers execute their cards serially without redelegation or index edits. Inherit supported session settings; marker tier annotations are not model parameters.

Launch a dependency wave of independent milestones within actual concurrency limits, await all workers, inspect results, then integrate successful tracks before launching the next wave. Shared files and unmet dependencies remain serial. Require each worker's changed-file list, exact verification evidence, and commit SHA when commits are part of the authorized workflow.

Check the committed diff against the recorded base (`git diff --name-only <base>...<track-branch>`) AND uncommitted changes; a plain working-tree diff misses committed scope violations. Park undeclared overlap or a merge conflict with evidence rather than guessing through it. Integrate only verified owned tracks within the authorized run branch. Re-review the actual integrated diff and rerun behavior/integration checks; isolated passes are stale after merge.

Update milestone state between waves: queued, running(path), merged(commit), parked(reason); mark dependents blocked. Retain branches/worktrees while checks fail or findings remain. Remove only this run's clean, merged worktrees after integration passes and cleanup is authorized; never force-remove dirty or foreign worktrees. Report all retained paths and unresolved tracks. Do not claim source transcript-based reviewer records or Stop gates verified the run; direct observed evidence is the completion contract.
