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
| `/resilience:review [path-diff-or-design-doc]` | Review code or a design for failure-mode gaps — missing timeouts, unsafe retries, absent degradation paths — one line per finding |
| `/resilience:error-review [path-diff-or-design-doc]` | Audit error handling — empty or over-broad catches, swallowed exceptions, missing cause chains — one line per finding |
| `/resilience:concurrency-review [path-diff-or-design-doc]` | Audit concurrency hazards — check-then-act races, missing idempotency on retried paths, locks without TTL or fencing — one line per finding |
| `/resilience:observability-review [path-diff-or-design-doc]` | Audit code for observability gaps — unstructured logs, missing correlation IDs, secrets in logs, silent catch blocks — one line per finding |
| `/resilience:performance-review [path-diff-or-endpoint]` | Review code or a change for performance hotspots and cache-correctness gaps; each finding **measured** when a number backs it or **suspected** with the measurement that would confirm it |

```bash
/resilience:review app/Services/PaymentGateway.php
/resilience:observability-review src/api/
/resilience:performance-review app/Services/ReportBuilder.php
/resilience:review        # reviews the current diff
```

## Skills

| Skill | Fires when |
|---|---|
| `resilience-design` | Code crosses a process boundary — HTTP calls, queues, databases, third-party APIs, background jobs |
| `error-handling-design` | Code handles exceptions — catches, cause chains, user-facing errors |
| `concurrency-safety` | Code has concurrent writers or retried operations |
| `observability-design` | Code emits logs, metrics, spans, or health signals |
| `performance-tuning` | Something is measurably slow or heavy, or a cache is being designed |

## Agents

- **observability-engineer** (worker) — applies an observability audit's fix list as a
  diff: structured logs, request IDs, RED/USE metrics, trace spans, health signals —
  leaving infra-layer wiring to devops.
- **performance-engineer** (worker) — profiling, bundle size, caching, Core Web
  Vitals, N+1 queries, load testing — and never ships an optimization without a
  before/after measurement.

## Pairs well with

- **system-design** (event-driven skill) — delivery semantics, outbox, and DLQ review for message-driven designs
- **devops** — infra-layer wiring (collectors, dashboards, deploy config) the observability engineer defers to
- **database** — SQL statement and index idioms (`/database:review`) the performance review defers to instead of duplicating
- **task-runner** — the apply-now path hands findings to its executor when installed
