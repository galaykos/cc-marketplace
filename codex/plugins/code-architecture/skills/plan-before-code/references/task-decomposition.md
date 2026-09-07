# Worked task decomposition

Merged here on 2026-08-21 from the `task-orchestration` skill. <!-- removed-ok -->
Its rules are in the SKILL body under "Split into tasks"; the table below is the
demonstration, and it is the one part of that skill nothing else stated.

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

## Common mistakes

- Treating "independent" as "I see no obvious conflict" instead of verifying no
  shared files or state — that is how a parallel wave silently overwrites itself.
- Skipping the gate between waves, so a broken interface from task 1 propagates
  into tasks 2 and 3 before anyone notices.
- Writing tasks around code structure ("edit lines 40-80") instead of around
  responsibility — those are hard to verify independently and tend to overlap.
