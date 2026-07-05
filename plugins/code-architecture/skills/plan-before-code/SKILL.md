---
name: plan-before-code
description: Use before writing any non-trivial code — decide which files change, what each new unit owns, interfaces between units, and where code should live, before writing it.
---

## The procedure: file map, then interfaces, then code

Writing code before deciding where it lives is how you end up with a 400-line function that
does five things, or three files that all half-implement the same responsibility. Do the
structural thinking on paper (or in a plan message) first — it's cheap to change a bullet list,
expensive to change five files after the fact.

1. **List every file you expect to touch or create.** Be concrete: exact paths, not "some
   utility file." If you can't name the file yet, you don't understand the change yet.
2. **Assign one responsibility per file.** Write it as a single sentence: "this file parses the
   config", "this file renders the list item". If the sentence needs "and", split the file.
3. **Define the interfaces between units** before writing bodies: function signatures, the
   shape of data crossing a boundary, which side owns validation, what errors can cross the
   boundary and how. This is the contract implementation must satisfy.
4. **Sequence the work**: which files have no dependencies on the others (write/test first),
   which depend on those. This becomes your task order (see task-orchestration).
5. **Only then write code**, file by file, against the interfaces you defined. If reality forces
   an interface change mid-implementation, stop and update the map — don't let the map silently
   go stale.

## Worked mini-example

Feature request: "Add a `/export` endpoint that lets a user download their notes as Markdown."

**File map:**

| file | responsibility |
|---|---|
| `routes/export.ts` | HTTP route: parse request, call service, stream response |
| `services/noteExporter.ts` | Turn a user's notes into a single Markdown string |
| `services/noteExporter.test.ts` | Unit tests for the Markdown conversion |

Nothing else changes. No new database table, no new config, no shared "exporter framework" —
one format is requested, so one function handles it.

**Interfaces defined before code:**

```ts
// routes/export.ts calls:
function exportNotesAsMarkdown(notes: Note[]): string

// Note shape (already exists in models/note.ts, just confirming the fields we need):
type Note = { id: string; title: string; body: string; createdAt: Date }
```

Decisions locked in at this step, not discovered mid-coding:
- The route owns fetching notes from the DB and authorization; the service is pure
  (`Note[] -> string`) and has no knowledge of HTTP or the database. That's what makes it
  unit-testable without mocking a request.
- Errors: `exportNotesAsMarkdown` never throws for empty input — it returns an empty document.
  The route is responsible for 404 if the user doesn't exist.

**Task sequence:** write `noteExporter.ts` + its test first (no dependencies), then wire
`routes/export.ts` against the now-verified function.

With this map in hand, writing the actual code is close to mechanical — the hard decisions
(what owns what, what crosses the boundary) are already made.

## Before / after

**Before (code-first):** you start typing the route handler, realize halfway through that
Markdown generation needs the note's tags too, bolt on a query for tags inline in the route,
then realize the same generation logic is now needed for a scheduled export job, so you copy
the whole handler body into a cron file and tweak it. Two divergent implementations, one of
which is untested.

**After (plan-first):** the file map surfaces "tags are needed" before code exists, so the
interface is `exportNotesAsMarkdown(notes: NoteWithTags[])` from the start. The pure service
function is trivially reusable from both the route and the cron job because it never depended
on HTTP in the first place.

## Red flags that you skipped this step

- You're not sure which file a new piece of logic belongs in while you're writing it.
- A function's signature changed three times during implementation because callers kept
  discovering new needs.
- Two files end up doing overlapping things because neither had a clearly scoped responsibility.
- You can't describe what a file does in one sentence without "and".
- You find yourself creating a file that wasn't in the map, with no clear reason it's needed —
  either the map was incomplete or the new file is scope creep; figure out which before writing
  into it.

## Interfaces are the load-bearing part

The file list is scaffolding; the interfaces are the actual contract. When two units communicate
across a boundary, write down, before either side has a body:

- The function/method signature: name, parameters, return type.
- The shape of data crossing the boundary — a type, not a vague description.
- Which side validates input, and what happens on invalid input (throw? return a result type?
  sentinel value?).
- Whether the boundary is synchronous or async, and whether it can partially fail.

Two units built against an agreed interface can be written in parallel (see
task-orchestration) and tested independently, because neither implementation needs to see the
other's internals — only the contract. Skipping this step is what produces integration surprises:
both sides "work" alone and then don't fit together.

## Scale the planning to the change

This procedure is a dial, not a binary switch:

- A one-line bug fix in a single function doesn't need a file map — you already know the file
  and the responsibility isn't changing.
- A new function added to an existing, well-scoped file needs a one-line interface note, not a
  full table.
- A new feature spanning multiple files, or any change that adds a new module/service boundary,
  warrants the full procedure: file map, one-sentence responsibilities, explicit interfaces,
  and a task sequence.

The test isn't "did I fill out every section" — it's "could someone else read my plan and know
exactly which file to open and what it should expose, without guessing." If yes, you've planned
enough regardless of how much of the template you used.

## When to apply

Apply this before any change that touches more than one file, introduces a new module, or adds
a new responsibility to the codebase. Skip the ceremony for a true one-line fix — but if you're
tempted to skip it and then find yourself improvising structure as you type, that's the signal
to stop and make the map.
