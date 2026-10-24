---
description: Review code or a design for runtime-quality gaps — failure modes (timeouts, retries, degradation), error handling, concurrency hazards, observability, performance hotspots and cache correctness, event-driven delivery — one line per finding; --concern narrows to one rubric.
argument-hint: [path-diff-or-design-doc] [--concern failure|errors|concurrency|observability|performance|events|all]
---

Review the target in $ARGUMENTS against this plugin's rubrics — audit it, do not rewrite it.

Parse `--concern <name>` (also `--concern=<name>`) out of $ARGUMENTS first; the remainder
is the target. The names and the reference each reads from this plugin's `resilience` skill
(`${CLAUDE_PLUGIN_ROOT}/skills/resilience/references/`):

| `--concern` | reference | what it audits |
|---|---|---|
| failure | `references/timeouts-retries.md` | timeouts, retries with backoff and idempotency, circuit breaking, degradation, backpressure, delivery semantics at every process boundary |
| errors | `references/error-handling.md` | empty or over-broad catches, swallowed exceptions, message-string branching, missing cause chains, internals leaking to users |
| concurrency | `references/concurrency.md` | check-then-act races, missing idempotency on retried paths, unguarded parallel writes, locks without TTL or fencing |
| observability | `references/observability.md` | unstructured logs, missing correlation IDs, secrets in logs, silent catch blocks, cardinality bombs, dishonest health checks |
| performance | `references/performance.md` | N+1 queries, missing indexes, chatty I/O, payload and bundle size, render-blocking resources, Core Web Vitals, cache invalidation / stampede / staleness |
| events | `references/messaging.md` | broker and topic design, schema versioning, outbox, sagas, DLQ, consumer idempotency |

An unknown name aborts with one line printing that list. `--concern all` reads every reference.

1. Determine scope from the target — a file, directory, diff/branch reference, or design
   document. If empty, default to recent changes (`git diff` against the merge base,
   falling back to the latest commits).

2. Run a triage pass before the deep read. A trivial, single-file, or purely mechanical
   change earns a one-line verdict — state it and stop. Treat the change as risky and
   take the deep pass when it touches auth, data, migrations, concurrency, hot paths,
   queries, caching or the render path, OR spans more than 5 files, OR exceeds 300
   changed lines (a NEW file counts its full length as changed).

   **Hand up when the scope is not this plugin's alone.** If the resolved scope contains
   files outside this plugin's surface and `/code-review:review` is installed, hand the
   WHOLE scope to it and stop. It is the fan-in for overlapping review surfaces and loads
   every matching stack skill — including the rubrics here the diff selects — in one pass; running the
   per-concern passes beside it produces the duplicate findings the fan-in exists to
   prevent. Deferring is not a smaller answer.

3. Choose the rubrics. Load this plugin's `resilience` skill. With `--concern`, read that
   one reference and nothing else. Without it, read `references/timeouts-retries.md`
   always, then add each other reference whose surface the scope actually touches — catch
   blocks or custom error types read `references/error-handling.md`; shared state, retried
   operations or locks read `references/concurrency.md`; log, metric, span or health-check
   calls read `references/observability.md`; queries, caches, bundles or the render path
   read `references/performance.md`; producers, consumers, brokers or outbox tables read
   `references/messaging.md`. Name the read set in the Checked line of step 6; a reference
   not read is `Not checked`, with the reason being that its surface is absent from the
   scope. Apply each read reference's checklist across the scope — cite the reference, do
   not restate it here.

4. Report findings one line each, sorted by severity (critical, high, medium, low):
   `locator — severity — [CONFIRMED|PLAUSIBLE] problem — fix` — the locator is
   `path:line`, or the section/heading for a design-doc review. Mark a finding
   `CONFIRMED` only with a traced call path, an executed check, or a reproduction; absent
   the ability to execute, findings stay `PLAUSIBLE` — that is acceptable, not a
   failure. No finding without evidence and a concrete fix; no praise, no padding.

   **Performance findings carry one extra field.** This is a static review: flag a
   performance finding as **measured** only if a real number backs it; otherwise mark it
   **suspected** and name the measurement that would confirm it —
   `path:line — severity — suspected problem — measurement-that-confirms — fix`. Never
   assert a win without a before/after number.

5. Defer, do not duplicate. SQL statement and index idioms and framework-idiom review →
   `/code-review:review`, the fan-in that loads database's sql skill and the laravel /
   web-dev stack skills for whatever the diff touches; infra-layer observability wiring
   (collectors, dashboards, deploy config) → `/devops:review`; the service-boundary
   decision behind an event → code-architecture's `system-architect` agent. Recommend
   each; do not run it from here.

6. Close with a coverage inventory and a self-refute pass. State `Checked: …` (the
   rubrics loaded and the surfaces read) and `Not checked: … (why)` so it is explicit
   what was covered, what was clean, and what was skipped — not only what broke. Then
   run one adversarial self-refute pass over every critical finding; if a finding does
   not survive it, drop or downgrade it with a note.

7. When findings exist, offer the next step as a selectable choice (AskUserQuestion):
   Apply all / Apply critical+high only / Report only — with `references/performance.md` read,
   the middle option is "Measure first, then decide". On an apply pick, dispatch the finding
   list down the static chain, grouped by rubric: observability findings →
   `resilience:observability-engineer`, performance findings →
   `resilience:performance-engineer`, everything else → `task-runner:task-executor` if
   installed → inline. Never leave the user to retype findings as instructions. In a
   headless or non-interactive run, report only and print the apply command instead of
   dispatching.

You may close by recommending an ultra-assess re-run (task-runner's, only when that
plugin is installed) when the change was large or high-risk — recommend it only,
never self-execute it.
