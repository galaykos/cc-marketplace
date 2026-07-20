# concurrency

Application-level concurrency safety: check-then-act races, optimistic vs
pessimistic locking, idempotency keys for retried operations, queue-consumer
dedup under at-least-once delivery, distributed locks with TTL and fencing,
and async parallel-write pitfalls — safe when two copies run at once.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install concurrency@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/concurrency:review [path-diff-or-design-doc]` | Audit code for concurrency hazards — check-then-act races, missing idempotency on retried paths, unguarded parallel writes, locks without TTL or fencing — one line per finding |

## Example

```bash
/concurrency:review app/Jobs/ProcessPayment.php
/concurrency:review         # reviews the current diff
```

Findings are severity-sorted (`path:line — severity — problem — fix`) and close
with a `Checked / Not checked` coverage inventory, so silence means verified,
not skipped.

## Pairs well with

- **system-design** (event-driven skill) — delivery semantics, outbox, and saga review for the queues these consumers sit on
- **resilience** — the timeout/retry gaps that turn one execution into two in the first place
- **database** — schema, index, and pooling review beneath the row-level locking strategies
