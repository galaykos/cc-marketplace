# resilience

Runtime quality in one plugin — does it stay up, can you see it, is it fast.

- **Failure-mode design** for integration points: timeouts everywhere, retries with
  backoff and idempotency, circuit breaking, graceful degradation, backpressure, and
  delivery semantics — designed in at write time, not bolted on after the outage —
  with the error-handling (catches, cause chains, user-facing errors) and concurrency
  (check-then-act races, retry idempotency, locks) disciplines.
- **Observability** with judgment: structured JSON logs with correlation IDs, log
  levels that mean something, RED/USE metrics without cardinality bombs,
  trace-context propagation, symptom-based alerting, honest health checks.
- **Performance** with measure-first discipline: N+1/index/payload/bundle/Core Web
  Vitals hotspots, cache correctness (stampede, TTL, eviction, staleness), and
  percentile load testing.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install resilience@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/resilience:review [path-diff-or-design-doc] [--concern …]` | One runtime-quality audit, one line per finding. Without `--concern` it loads the failure-mode rubric and adds each other rubric whose surface the scope touches; `--concern failure\|errors\|concurrency\|observability\|performance\|events\|all` loads exactly one (or all). Performance findings are **measured** when a number backs them or **suspected** with the measurement that would confirm them. Findings route by rubric: observability → the observability-engineer worker, performance → the performance-engineer worker, the rest → task-runner |

```bash
/resilience:review app/Services/PaymentGateway.php
/resilience:review --concern observability src/api/
/resilience:review --concern performance app/Services/ReportBuilder.php
/resilience:review        # reviews the current diff, rubrics chosen by what it touches
```

Until 2026-09-14 each concern was its own command (`error-review`, `concurrency-review`,
`observability-review`, `performance-review`); one entry with a flag costs the host's
skill listing one line instead of five, and the code-review fan-in already loads all six
rubrics in one pass.

## Skills

| Skill | Fires when |
|---|---|
| `resilience-design` | Code crosses a process boundary — HTTP calls, queues, databases, third-party APIs, background jobs |
| `error-handling-design` | Code handles exceptions — catches, cause chains, user-facing errors |
| `concurrency-safety` | Code has concurrent writers or retried operations |
| `observability-design` | Code emits logs, metrics, spans, or health signals |
| `performance-tuning` | Something is measurably slow or heavy, or a cache is being designed |
| `event-driven` | Message-driven architecture is designed or reviewed — brokers, topics, schema versioning, delivery semantics, outbox, sagas, DLQ, consumer idempotency (system-design was merged into code-architecture on 2026-09-14 and this skill moved here) |

## Agents

- **observability-engineer** (worker) — applies the observability findings of a review as a
  diff: structured logs, request IDs, RED/USE metrics, trace spans, health signals —
  leaving infra-layer wiring to devops.
- **performance-engineer** (worker) — profiling, bundle size, caching, Core Web
  Vitals, N+1 queries, load testing — and never ships an optimization without a
  before/after measurement.

## Evals

`evals/` holds six cases. Run them with the control arm — without it a grader
passing proves nothing about the skills, only that the model can review code:

```bash
claude plugin eval ./plugins/resilience --ablation with-without --runs 5 \
  --no-publish --trust-plugin
```

No `--allow-tools` grant is needed: every case declares `Read, Glob, Grep, Skill`
and none is gated. No case ships a `scaffold_script`, so `--scaffold` is not part
of the invocation. Add `--max-cost-usd 0` to load-check the suite for free — that
is what `scripts/eval-cases.sh` does on every CI run, and it is the only eval step
CI has; nothing here runs a model.

**Five of the six are regression guards, and that is a limitation, not a result.**
`timeout-and-retry`, `idempotency-only`, `idempotency-only-ts`, `retry-amplification`
and `breadth-review` all sit at the control ceiling: the base model passes them
unaided, so they can catch the plugin breaking something and can never show it
helping. `liveness-probe-dependency` is the first case written with headroom above
that ceiling — a liveness probe wired to a dependency check, which the control arm
reads as a well-instrumented service. Its delta is **unmeasured**; when it is run,
state the run count and the vote spread with the number or do not state the number.

## Pairs well with

- **code-architecture** (system-design skill) — the service boundaries whose failure modes this plugin reviews
- **devops** — infra-layer wiring (collectors, dashboards, deploy config) the observability engineer defers to
- **database** — SQL statement and index idioms (its sql skill, loaded by `/code-review:review`) the performance review defers to instead of duplicating
- **task-runner** — the apply-now path hands findings to its executor when installed
- **craft-layer** — a consumer: its `craft-reviewer` yields to
  `/resilience:review --concern performance` for the audit step (`craft-layer/lane.tsv`).
  Frame-budget, `requestAnimationFrame` and compositor questions route to ui-ux's
  `motion-best-practices` skill instead — `performance-tuning` carries no
  frame-budget material (grep it before trusting this line)
