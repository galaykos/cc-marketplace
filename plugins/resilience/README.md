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

## Example

```bash
/resilience:review app/Services/PaymentGateway.php
/resilience:review        # reviews the current diff
```

The review applies the `resilience-design` skill's checklist — the same skill
that triggers on its own whenever code crosses a process boundary (HTTP calls,
queues, databases, third-party APIs, background jobs) — and reports findings
sorted by severity with a concrete fix per line.

## Pairs well with

- **error-handling** — what the code does once a failure surfaces: catches, cause chains, user-facing errors
- **concurrency** — races, idempotency on retried paths, and lock hazards around the same call sites
- **event-driven** — delivery semantics, outbox, and DLQ review for message-driven designs
- **observability** — the logs and correlation IDs you need when a degradation path actually fires
