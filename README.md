# cc-plugins-marketplace: Claude Code Plugin Marketplace

cc-plugins-marketplace is a self-hosted marketplace of best-practice plugins for Claude Code. Each plugin bundles skills, commands, and agents that enforce code quality standards across your projects—from React and Vue to Laravel and beyond.

## Installation

To add the cc-plugins-marketplace marketplace to your Claude Code config:

```bash
/plugin marketplace add galaykos/cc-marketplace
```

Or with the full URL:

```bash
/plugin marketplace add https://github.com/galaykos/cc-marketplace
```

Then install individual plugins:

```bash
/plugin install <plugin>@cc-plugins-marketplace
```

For example:

```bash
/plugin install react@cc-plugins-marketplace
/plugin install laravel@cc-plugins-marketplace
/plugin install code-architecture@cc-plugins-marketplace
```

## Plugins

| Plugin | Description | Commands |
|--------|-------------|----------|
| **ui-ux** | UI/UX best practices: shadcn/ui, Tailwind, CSS3, Bootstrap, CSS Grid, Flexbox + ui-ux-reviewer agent | `/ui-ux:review` |
| **react** | React: hooks, render/memo, state management, patterns | `/react:review` |
| **react-native** | React Native: list performance, navigation, platform code, animations | `/react-native:review` |
| **vue2** | Vue 2.7: Composition API, reactivity, migration readiness | `/vue2:review` |
| **vue3** | Vue 3: script setup, composables, ref/reactive, Pinia | `/vue3:review` |
| **php** | PHP: strict types, === discipline, PSR conventions, version-aware 8.1–8.5 leverage map, exceptions, boundary security | `/php:review` |
| **laravel** | Laravel: Eloquent N+1, form requests, service layer, queues, policies | `/laravel:review` |
| **livewire** | Livewire 3: components, wire:model, performance, Alpine interop | `/livewire:review` |
| **sql** | SQL (engine-agnostic): sargable predicates, joins, index logic, NULL traps, transactions, keyset pagination, migrations | `/sql:review` |
| **mysql** | MySQL 8.0+: InnoDB clustered PK, utf8mb4, strict sql_mode, online DDL, gap locks, 8.0–8.4 leverage | `/mysql:review` |
| **mariadb** | MariaDB 10.6+: not-MySQL divergences, RETURNING, sequences, system versioning, UUID type, Galera | `/mariadb:review` |
| **postgresql** | PostgreSQL 14+: MVCC/vacuum, timestamptz/jsonb, index arsenal, lock-aware migrations, 14–18 leverage | `/postgresql:review` |
| **code-architecture** | Engineering process: plan-before-code, YAGNI, task orchestration, work verification, low-cognitive-load, KISS/DRY simplicity + architecture-reviewer agent | `/code-architecture:plan`, `/code-architecture:verify`, `/code-architecture:yagni` |
| **design-patterns** | Design patterns: selection, fitting, anti-patterns | `/design-patterns:suggest` |
| **api-docs-first** | API-docs-first: verify docs before writing integration code | `/api-docs-first:check` |
| **taskmaster** | Interrogation-first clarification: ambiguity ledger, batched questions, mockups on one always-live preview URL for visual decisions, single-prompt task cards + context-scout agent | `/taskmaster:task` |
| **task-runner** | Disciplined execution: one task at a time, scope lock, bounded verify-fix loop (3 cycles max), full-suite completion gate | `/task-runner:run` |
| **stack-scan** | Required-vs-installed inventory from composer/npm/yarn/pnpm/bun manifests, lockfiles, runtime pins, docker/CI images | `/stack-scan:report` |

## Usage

Skills auto-trigger based on context (e.g., `react-best-practices` activates when writing React code). Commands like `/react:review` are invoked manually. You can also invoke them from the command line or via the plugin menu.

### Running taskmaster

Install the plugin, then start it with a one-paragraph task description:

```bash
/plugin install taskmaster@cc-plugins-marketplace
/taskmaster:task Add CSV export to the orders page with date-range filtering
```

If you run `/taskmaster:task` without arguments, it asks for a task description first. The pipeline then:

1. Dispatches the context-scout agent to scan the codebase before asking you anything
2. Asks batched clarifying questions until every item in the ambiguity ledger is resolved (visual/structural choices are decided via mockups on a live preview URL)
3. Writes a spec to `docs/specs/YYYY-MM-DD-<slug>.md`
4. Emits single-prompt task cards to `docs/tasks/YYYY-MM-DD-<slug>/` with a `00-INDEX.md`

Execute the resulting cards with the task-runner plugin: `/task-runner:run docs/tasks/<date>-<slug>/00-INDEX.md`.

A reminder hook also nudges you toward `/taskmaster:task` when it detects a short, feature-shaped prompt (build/add/implement…) with thin detail.

### Conversation example

A good starting prompt is one paragraph: the goal, hard constraints, and pointers to existing code if you know them. Don't pre-answer design questions — the interrogation surfaces those. Here's how a session flows:

```text
You:     /taskmaster:task Add CSV export to the orders page. Users should be able
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

Notice what the starting prompt does and doesn't do: it states the goal, one performance constraint, and a pointer ("follow existing export patterns") — but leaves column choice, delivery mechanism, and permissions open. Those come out grounded in what context-scout actually found, so the answers become decisions in the spec instead of assumptions buried in code.

### Optimal setup: the taskmaster workflow suite

taskmaster works standalone, but it reaches its full potential with three companion plugins installed alongside it:

```bash
/plugin install stack-scan@cc-plugins-marketplace
/plugin install taskmaster@cc-plugins-marketplace
/plugin install task-runner@cc-plugins-marketplace
/plugin install code-architecture@cc-plugins-marketplace
```

How the pieces fit together:

| Plugin | Role in the workflow |
|--------|----------------------|
| **stack-scan** | Runs first. Inventories the actual installed versions (lockfiles, runtime pins, docker images) so taskmaster's context-scout cites real constraints instead of guesses |
| **taskmaster** | Clarifies the task: interrogation → spec → single-prompt task cards |
| **task-runner** | Executes the cards one at a time with scope lock, bounded verify-fix loops, and a full-suite completion gate |
| **code-architecture** | Supplies the process gates used throughout: plan-before-code, YAGNI checks, and the work-verification discipline task-runner applies to the whole run |

The full loop for a feature:

```bash
/stack-scan:report                                    # ground truth: what's actually installed
/taskmaster:task <one-paragraph task description>     # interrogate → spec → task cards
/task-runner:run docs/tasks/<date>-<slug>/00-INDEX.md # execute cards, verify each one
/code-architecture:verify                             # final verification pass
```

Each plugin degrades gracefully when a companion is missing — taskmaster scans manifests itself without stack-scan, and task-runner accepts any task list, not just taskmaster cards. But installed together, version facts flow into clarifying questions, cards flow into disciplined execution, and verification gates close the loop.

If you work on a specific stack, add its review plugin on top (e.g. `laravel` + `mysql` for a Laravel app, `react` + `ui-ux` for a React frontend) — stack-scan's inventory feeds those review commands too.

## Contributing

To add a new plugin:

1. Create a directory: `plugins/<name>/.claude-plugin/`
2. Add a `plugin.json` manifest (see existing plugins for examples)
3. Update `.claude-plugin/marketplace.json` with your plugin entry
4. Run `bash scripts/validate.sh` to verify the structure

All plugins are versioned at `0.5.0` and owned by Ivan-WG <public@galayko.com>.
