# task-runner

Disciplined task execution: one task at a time, scope locked, bounded verify-fix
inner loop (max three cycles, then park with evidence), no unbounded outer loop,
full-suite completion gate.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install task-runner@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/task-runner:run [tasks-dir-index-or-list]` | Execute a task list — a taskmaster `00-INDEX.md`, a plan's task sequence, or an inline list |

## Example

```bash
/task-runner:run taskmaster-docs/tasks/2026-07-05-orders-csv-export/00-INDEX.md
/task-runner:run           # picks the most recent taskmaster-docs/tasks/*/00-INDEX.md
```

Each task runs its EXACT verify command; three failed fix cycles park the task
with evidence instead of drifting. The run only completes when every task is
done or parked AND the project's full check suite passes.

Status lives in the task index and the conversation — no HTML dashboards.
HTML/preview artifacts are reserved for content that needs them: mockups,
interactive walkthroughs, demos.

## Pairs well with

- **taskmaster** — produces the task cards this plugin executes
- **code-architecture** — its work-verification discipline applies to the whole run
