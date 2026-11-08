---
description: Review code or a design for runtime-quality gaps. Covers failure modes (timeouts, retries, degradation), error handling, concurrency hazards, observability, performance hotspots, cache correctness, event-driven delivery. One line per finding; --concern narrows to one rubric.
argument-hint: [path-diff-or-design-doc] [--concern failure|errors|concurrency|observability|performance|events|all]
---

Review the target in $ARGUMENTS against this plugin's rubrics — audit it, do not rewrite it.

Parse `--concern <name>` (also `--concern=<name>`) out of $ARGUMENTS first; the remainder
is the target. The names and the skill each loads:

| `--concern` | skill | what it audits |
|---|---|---|
| failure | `resilience-design` | timeouts, retries with backoff and idempotency, circuit breaking, degradation, backpressure, delivery semantics at every process boundary |
| errors | `error-handling-design` | empty or over-broad catches, swallowed exceptions, message-string branching, missing cause chains, internals leaking to users |
| concurrency | `concurrency-safety` | check-then-act races, missing idempotency on retried paths, unguarded parallel writes, locks without TTL or fencing |
| observability | `observability-design` | unstructured logs, missing correlation IDs, secrets in logs, silent catch blocks, cardinality bombs, dishonest health checks |
| performance | `performance-tuning` | N+1 queries, missing indexes, chatty I/O, payload and bundle size, render-blocking resources, Core Web Vitals, cache invalidation / stampede / staleness |
| events | `event-driven` | broker and topic design, schema versioning, outbox, sagas, DLQ, consumer idempotency |

An unknown name aborts with one line printing that list. `--concern all` loads every rubric.

1. Determine scope from the target — a file, directory, diff/branch reference, or design
   document. If empty, default to recent changes (`git diff` against the merge base,
   falling back to the latest commits).

   **Diff risk score, inform only.** When the scope is a diff (a branch, a ref, or the
   default recent changes), run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/diff-risk.sh"` from the
   repository and print its table before the findings. It scores each touched file from
   its git history: reverts, fixes, and a fix soon after a change. It reads the checked-out
   HEAD and working tree, so add `--base <ref>` only with the base side of the target
   (`<ref>` of `<ref>..HEAD` or `<ref>...HEAD`, or a bare commit sha); the checked-out
   branch and the default take no flag. When the target is another branch, or a range
   ending at one, skip the score and print `Not checked: diff risk (target not checked out)`.
   Read the top-scored files with extra care in the deep pass.
   The score never blocks, never skips the triage below and never changes which rubrics
   step 3 loads; a non-zero exit prints its one line and the review goes on. Standing:
   **recorded** for the extra care, which no check reads back; the scoring itself is a
   **gate** where run, by `scripts/__tests__/diff-risk.test.sh` in CI.

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

3. Choose the rubrics. With `--concern`, load that one skill from this plugin and nothing
   else. Without it, load `resilience-design` always, then add each other skill whose
   surface the scope actually touches — catch blocks or custom error types load
   `error-handling-design`; shared state, retried operations or locks load
   `concurrency-safety`; log, metric, span or health-check calls load
   `observability-design`; queries, caches, bundles or the render path load
   `performance-tuning`; producers, consumers, brokers or outbox tables load
   `event-driven`. Name the
   loaded set in the Checked line of step 6; a rubric not loaded is `Not checked`, with
   the reason being that its surface is absent from the scope. Apply each loaded skill's
   checklist across the scope — cite the skill's rubric, do not restate it here.

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
   decision behind an event → code-architecture's `system-design` skill. Recommend
   each; do not run it from here.

6. Close with a coverage inventory and a self-refute pass. State `Checked: …` (the
   rubrics loaded and the surfaces read) and `Not checked: … (why)` so it is explicit
   what was covered, what was clean, and what was skipped — not only what broke. Then
   run one adversarial self-refute pass over every critical finding; if a finding does
   not survive it, drop or downgrade it with a note.

7. When findings exist, offer the next step as a selectable choice (AskUserQuestion):
   Apply all / Apply critical+high only / Report only — with `performance-tuning` loaded,
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
