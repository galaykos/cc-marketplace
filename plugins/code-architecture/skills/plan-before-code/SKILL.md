---
name: plan-before-code
description: Use before writing any non-trivial code, AFTER the approach shape is settled — which files change, what each new unit owns, the interfaces, where code lives.
---

## The procedure: file map, then interfaces, then code — Compensation (worker-tier)

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
   which depend on those. This becomes your task order — see Split into tasks.
5. **Only then write code**, file by file, against the interfaces you defined. If reality forces
   an interface change mid-implementation, stop and update the map — don't let the map silently
   go stale.

## Split into tasks

A task is the **smallest unit of work that can be independently verified** — a
done-condition someone can check without the rest of the work being finished.
"Refactor the auth module" is a project; "extract `hashPassword` into
`lib/crypto.ts` with a unit test covering empty-string and unicode input" is a
task. If you cannot state how you would verify it without referring to other
unfinished tasks, it is too large or too entangled.

Order them from the file map you just built:

1. Task B depends on task A when B needs an interface, type, or file A creates or
   changes. **Shared writes count** — two tasks editing one file is a dependency,
   or a signal to split that file's responsibilities.
2. Tasks with no incoming edges start immediately; the rest wait for their
   dependencies to clear review.
3. Re-check the graph when a task's scope changes. A dependency discovered
   mid-task updates the plan; it is not silently absorbed.

**Parallel only when neither task reads a still-changing output of the other and
neither writes shared state** — including the database a test assumes. When in
doubt, sequence: a wrong "independent" costs a merge conflict or a flaky test, a
wrong "sequential" costs wall-clock time only.

**Gate between waves.** Run a task's own success criteria before marking it done
(see work-verification), and for anything with dependents confirm the produced
INTERFACE matches what was planned — a passing suite does not prove the signature
is what the next task expects. A failed gate stops its dependents rather than
letting them build on it.

Worth doing whenever the work is larger than one sitting or is about to be
dispatched to several workers; the moment you say "and also" while describing a
task is the seam. Worked decomposition: `references/task-decomposition.md`.
Phrasing and verifying the dispatch is orchestration:delegation-contracts;
pricing the parallelism is task-runner:parallel-planning.

## Worked example

Feature request: *"Add a `/export` endpoint that lets a user download their notes as
Markdown."*

**File map:**

| file | responsibility |
|---|---|
| `routes/export.ts` | HTTP route: parse request, call service, stream response |
| `services/noteExporter.ts` | Turn a user's notes into a single Markdown string |
| `services/noteExporter.test.ts` | Unit tests for the Markdown conversion |

Nothing else changes. No new database table, no new config, no shared "exporter
framework" — one format is requested, so one function handles it.

**Interfaces defined before code:**

```ts
// routes/export.ts calls:
function exportNotesAsMarkdown(notes: Note[]): string

// Note shape (already exists in models/note.ts, confirming the fields we need):
type Note = { id: string; title: string; body: string; createdAt: Date }
```

Decisions locked in at this step, not discovered mid-coding:

- The route owns fetching notes and authorization; the service is pure
  (`Note[] -> string`) with no knowledge of HTTP or the database. That is what makes
  it unit-testable without mocking a request.
- Errors: `exportNotesAsMarkdown` never throws for empty input — it returns an empty
  document. The route is responsible for 404 if the user does not exist.

Task sequencing for this example, and the fuller narrative: `references/worked-example.md`.

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

## Draw structural changes: current vs target

When the plan moves boundaries — a new service, a changed data flow, a split
module — prose plans hide the disagreement that matters: what the reader thinks
exists today vs what you found in the code. Render both as one artifact:

- One self-contained HTML file with two inline-SVG panels side by side:
  **current** (how it works — boxes/arrows drawn from code evidence, each box
  citing its file) and **target** (how it should work after the change), the
  changed elements visually marked.
- The current panel must come from the codebase, not intention — a mismatch
  between the drawn current state and the actual code is a plan bug caught
  free of charge.
- Serve it on the live preview URL pattern (port `${PREVIEW_PORT:-8123}`, `modules.html` —
  its own slot; `diagram.html` is reserved for taskmaster's ERD, and two skills
  writing one file clobber each other mid-decision. Auto-reload — see the
  taskmaster plugin's visual-decisions skill when
  installed; plain `file://` open works too). Get a yes on the target picture
  BEFORE writing the task sequence — redrawing an arrow is cheaper than
  re-planning six tasks.
- Skip the artifact for non-structural changes; a diagram of a renamed method
  is theater.

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
Split into tasks) and tested independently, because neither implementation needs to see the
other's internals — only the contract. Skipping this step is what produces integration surprises:
both sides "work" alone and then don't fit together.

## Scale the planning to the change — All models (the skip-clause)

This procedure is a dial, not a binary switch (markers per authoring-skills' model-tier scoping):

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

## Edits made without a plan

Read `references/surgical-edits.md` for the everyday edit this ceremony does not cover: surfacing
assumptions first, every changed line traceable to the request, the orphan rule, vague ask to verifiable
goal. `surgical-coding` was merged in here (Karpathy guidelines, MIT); its trigger — "outside a planned pipeline" — could not be evaluated at fire time.

## When to apply

Apply this before any change that touches more than one file, introduces a new module, or adds
a new responsibility to the codebase. Skip the ceremony for a true one-line fix — but if you're
tempted to skip it and then find yourself improvising structure as you type, that's the signal
to stop and make the map.
