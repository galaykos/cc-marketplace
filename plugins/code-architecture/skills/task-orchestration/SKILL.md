---
name: task-orchestration
description: Use when breaking work into tasks or delegating to subagents — independently verifiable units, dependency sequencing, parallel independent work.
---

## What counts as a task

A task is the **smallest unit of work that can be independently verified** — it has a clear
done-condition someone (or something) can check without needing the rest of the work to also be
finished. "Refactor the auth module" is not a task, it's a project. "Extract `hashPassword` into
`lib/crypto.ts` with a unit test covering empty-string and unicode input" is a task: you can
verify it in isolation and know it's done.

If you can't state how you'd verify a task is complete without reference to other unfinished
tasks, it's too large or too entangled — split it further or fix the dependency.

## Dependency ordering

Before assigning or running tasks, build the dependency graph:

1. **List tasks**, each with its file-level footprint (which files it reads/writes — this comes
   directly out of plan-before-code's file map).
2. **Draw edges**: task B depends on task A if B needs an interface, type, or file that A
   creates or changes. Shared-state edges count too — if both tasks write the same file, that's
   a dependency (or a signal to split the file's responsibilities further).
3. **Topologically order**: tasks with no incoming edges can start immediately; everything else
   waits for its dependencies to clear review.
4. Re-check the graph when a task's scope changes — a dependency discovered mid-task should
   update the plan, not get silently absorbed into the current task.

## Parallelize only independent work

Two tasks are safe to run in parallel (concurrently, or dispatched to separate subagents) only
if **neither reads a still-changing output of the other and neither writes to shared state**.
Concretely:

- Safe to parallelize: task A adds a new file `services/export.ts`; task B adds a new file
  `services/import.ts`. No shared files, no shared runtime state, no ordering requirement.
- Not safe: task A and task B both edit `routes/index.ts` to register their new endpoints —
  same file, race on the edit. Either sequence them or give each task its own insertion point
  reviewed together at the end.
- Not safe: task B's tests assume task A's migration has already run against the dev database
  — shared state (the DB), so B waits for A.
- When in doubt, sequence. A false "these are independent" costs you a merge conflict or a
  flaky test; a false "these must be sequential" only costs some wall-clock time.

## Review gates between tasks

Don't chain unreviewed tasks indefinitely — errors compound silently. Put a verification/review
checkpoint after each task (or each small batch of independent parallel tasks) before starting
work that depends on it:

- Run the task's own success criteria (see work-verification) before marking it done.
- For tasks with downstream dependents, confirm the *interface* produced matches what was
  planned — a passing test suite doesn't guarantee the function signature is what task B
  expects.
- If a task fails its gate, stop the tasks that depend on it rather than letting them build on
  a broken foundation; fix or re-plan first.

## Worked decomposition example

Feature: "Users can tag notes and filter the notes list by tag."

| task | depends on | files touched | verify by |
|---|---|---|---|
| 1. Add `tags: string[]` to Note schema + migration | — | `models/note.ts`, migration file | migration runs clean on a scratch DB; existing note tests still pass |
| 2. `addTagToNote` / `removeTagFromNote` service functions | 1 | `services/tags.ts` | unit tests: add, remove, dedupe, tag on nonexistent note |
| 3. `filterNotesByTag` query function | 1 | `services/notes.ts` | unit test: returns matching notes, empty array for unknown tag |
| 4. Tag input UI on note editor | 2 | `components/NoteEditor.tsx` | manual check: add/remove tag persists across reload |
| 5. Tag filter dropdown on notes list | 3 | `components/NotesList.tsx` | manual check: selecting a tag filters the list |

Tasks 2 and 3 both depend only on task 1 (the schema), touch different files, and share no
runtime state — safe to dispatch in parallel once task 1's gate passes. Tasks 4 and 5 likewise
depend on their respective service tasks but not on each other — parallel again. Sequential
chain is only 1 → {2,3} → {4,5}, not five serial steps.

## Delegating tasks to subagents

The same rules apply, with sharper edges, when tasks are handed to separate subagents rather
than done sequentially by one worker:

- **Each subagent's prompt should be self-contained**: the task's responsibility, its file
  footprint, the interfaces it must satisfy (inputs/outputs agreed in the plan), and its
  success criteria. A subagent can't infer context it wasn't given.
- **Never dispatch two subagents against the same file concurrently.** Even "small, unrelated"
  edits to one file will conflict or silently overwrite each other. Split the file's
  responsibilities first, or sequence the edits.
- **Give each subagent a narrow, verifiable done-condition**, not "improve X" — an
  unbounded task can't be gated, and you won't know when to move to the next step.
- **Collect and gate results before starting dependents.** Don't fire off the next wave of
  parallel tasks until the previous wave's outputs have been checked against their interfaces
  and success criteria — a subagent reporting success is itself a claim that needs the
  evidence discipline from work-verification.

## Common mistakes

- Treating "independent" as "I don't see an obvious conflict" instead of verifying no shared
  files or state — leads to silent overwrites when run in parallel.
- Skipping the review gate between waves, so a broken interface from task 1 propagates silently
  into tasks 2 and 3 before anyone notices.
- Writing tasks around code structure ("edit lines 40-80") instead of around responsibility —
  makes tasks hard to verify independently and prone to overlap.

## When to apply

Apply this whenever a piece of work is larger than a single sitting, or before dispatching to
multiple subagents/collaborators. For solo, small changes, the overhead of formal decomposition
isn't worth it — but the moment you're tempted to say "and also" while describing the task,
that's the seam where it should split.

Dispatching the resulting tasks to subagents — prompt contracts, compressed returns,
verification panels — is the orchestration plugin's job.
