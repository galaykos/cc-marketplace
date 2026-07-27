# resilience

Failure-mode design for integration points: timeouts everywhere, retries with
backoff and idempotency, circuit breaking, graceful degradation, backpressure,
and delivery semantics — designed in at write time, not bolted on after the
outage.

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

The `error-handling` and `concurrency` plugins were merged into this one:
their `error-handling-design` and `concurrency-safety` skills now ship here,
and their review commands live on as `/resilience:error-review` and
`/resilience:concurrency-review`. Nothing was dropped in the merge.

## Example

```bash
/resilience:review app/Services/PaymentGateway.php
/resilience:review        # reviews the current diff
```

The review applies the `resilience-design` skill's checklist — the same skill
that triggers on its own whenever code crosses a process boundary (HTTP calls,
queues, databases, third-party APIs, background jobs) — and reports findings
sorted by severity with a concrete fix per line.

The merged skills fire on their own too: `error-handling-design` when code
handles exceptions (catches, cause chains, user-facing errors), and
`concurrency-safety` when code has concurrent writers or retried operations.

## Pairs well with

- **system-design** (event-driven skill) — delivery semantics, outbox, and DLQ review for message-driven designs
- **observability** — the logs and correlation IDs you need when a degradation path actually fires
