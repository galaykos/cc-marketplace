# taskmaster

Interrogation-first task clarification: batched clarifying questions against an
ambiguity ledger, ASCII/HTML mockups on a single always-live preview URL for
visual decisions, then a spec and single-prompt task cards.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install taskmaster@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/taskmaster:task <description>` | Run the full pipeline: interrogate → spec → task cards |
| `/taskmaster <description>` | Shorthand alias for the same pipeline |
| `/taskmaster:brainstorm <idea>` | Upstream of the pipeline: shape a fuzzy idea into an approved design doc (one question at a time, 2–3 explored approaches, sectional approval), then hand off to `/taskmaster:task` |

Run it with a one-paragraph task description:

```bash
/taskmaster Add CSV export to the orders page with date-range filtering
```

Without arguments it asks for a description first. The pipeline then:

1. Runs the stack-scan inventory first when that plugin is installed, so
   constraints come from lockfiles instead of guesses
2. Dispatches the context-scout agent to scan the codebase before asking you anything
3. Asks batched clarifying questions until every item in the ambiguity ledger is
   resolved (visual/structural choices are decided via mockups on a live preview URL);
   whole-experience tasks get sliced into screens/flows first and grilled slice by slice
4. For multi-screen work, assembles the accepted picks into an **interactive
   clickable walkthrough demo** on the same preview URL — every screen, state
   variant, and failure exit navigable — and walks you through it with a task
   script; gaps found by clicking become ledger rows before the spec freezes
5. Writes a spec to `docs/specs/YYYY-MM-DD-<slug>.md` (including the walkthrough
   path and cross-screen contracts when one was built)
6. Emits single-prompt task cards to `docs/tasks/YYYY-MM-DD-<slug>/` with a
   `00-INDEX.md`, grouped into independently shippable milestones on big runs
7. When task-runner is installed, asks "Start execution now?" — one approval and
   it hands the index straight to the task-execution discipline, no manual
   `/task-runner:run` needed (still printed as the fallback if you decline)

A reminder hook also nudges you toward `/taskmaster` when it detects a short,
feature-shaped prompt (build/add/implement…) with thin detail.

## Conversation example

A good starting prompt is one paragraph: the goal, hard constraints, and pointers
to existing code if you know them. Don't pre-answer design questions — the
interrogation surfaces those. Here's how a session flows:

```text
You:     /taskmaster Add CSV export to the orders page. Users should be able
         to export the current filtered view with a date range. Needs to handle
         large order sets. Follow existing export patterns if any exist.

Claude:  Scanned the codebase first (context-scout): orders page at
         resources/js/Pages/Orders/Index.vue, an existing queued + chunked XLSX
         export in app/Exports/InvoiceExport.php, Laravel 11.34 and
         maatwebsite/excel 3.1 installed (composer.lock).

         Round 1 — 4 questions:
         1. Columns: all 14 order fields, or the 6 visible in the table?
         2. Large sets: stream the download, or queue + email a link like
            InvoiceExport does?
         3. Date range filters on created_at or updated_at?
         4. Who can export — every role that sees the page, or admin only?

You:     1: the visible 6. 2: queue + email, same as invoices.
         3: created_at. 4: admin and manager.

Claude:  Round 2 — 1 question, 1 assumption:
         1. Filename: orders-2026-07-05.csv okay?
         A1. Assuming UTF-8 with BOM for Excel compatibility (matches
             InvoiceExport) — accept as ASSUMED?

You:     Both fine.

Claude:  Ledger: 5 CLEAR, 1 ASSUMED.
         Spec: docs/specs/2026-07-05-orders-csv-export.md
         Cards: docs/tasks/2026-07-05-orders-csv-export/
           01 export class · 02 controller + route + policy · 03 UI button ·
           04 feature tests (02 and 03 run in parallel after 01)
         Start: /task-runner:run docs/tasks/2026-07-05-orders-csv-export/00-INDEX.md
```

Notice what the starting prompt does and doesn't do: it states the goal, one
performance constraint, and a pointer ("follow existing export patterns") — but
leaves column choice, delivery mechanism, and permissions open. Those come out
grounded in what context-scout actually found, so the answers become decisions
in the spec instead of assumptions buried in code.

## Companion plugins

taskmaster works standalone but reaches full potential alongside
[stack-scan](../stack-scan/), [task-runner](../task-runner/), and
code-architecture — see the [marketplace README](../../README.md#optimal-setup-the-taskmaster-workflow-suite)
for the full workflow suite.

## Contents

- **Skills**: brainstorm (fuzzy idea → approved design doc, upstream of
  everything), grill (interrogation + ambiguity ledger + big-task slicing),
  visual-decisions (mockups on a live preview URL), experience-walkthrough
  (interactive clickable demo of the whole assembled flow), task-cards
  (spec → milestone-grouped single-prompt cards)
- **Agent**: context-scout — read-only codebase reconnaissance before questioning
- **Hook**: thin-feature-prompt reminder on UserPromptSubmit
