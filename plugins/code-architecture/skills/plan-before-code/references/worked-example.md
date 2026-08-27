# Plan-before-code — the worked example

Moved out of the SKILL body on 2026-08-21 to make room for the task-split rules
merged in from the `task-orchestration` skill. <!-- removed-ok --> **The file map and
interfaces were returned to the body on 2026-08-27** when the line ceiling rose to
200 — the skill instructs "define the interfaces before writing bodies" and could not
be applied without them. What stays here is the task sequencing and the longer
narrative: depth a reader chooses, not the demonstration the procedure depends on.

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
