---
name: event-driven
description: Use when designing or reviewing message-driven architecture — brokers/queues, topic and partition design, event schema versioning, delivery semantics (at-least-once vs exactly-once), the outbox pattern, sagas, dead-letter queues, and consumer idempotency. For in-process framework queues use the stack plugin; this is the cross-broker discipline.
---

# Event-driven architecture

Asynchronous messaging trades a synchronous failure you can see for a distributed
one you cannot. Every guarantee you assume — "it arrives", "once", "in order" — is
false by default and must be designed for. The single rule that prevents most
production incidents: **assume at-least-once delivery and make every consumer
idempotent.** Everything below serves that.

## Choosing the transport

Match the tool to the guarantee you need, not the hype:

| Need | Reach for |
|---|---|
| Ordered, replayable log; many consumers; high throughput | Kafka / Redpanda |
| Simple work queue; managed; at-least-once | SQS / RabbitMQ |
| Lightweight streams already on Redis | Redis Streams |
| In-process background jobs, one app | the framework queue (Laravel/Sidekiq/Celery) |

Do not reach for Kafka to run three background jobs; do not run a payment saga on
fire-and-forget. The transport's weakest guarantee is your architecture's guarantee.

## Delivery semantics — name yours

- **At-least-once** is what real brokers give you (Kafka, SQS, RabbitMQ, Redis
  Streams). A message can be delivered twice: a consumer crashes after acting but
  before acking, and redelivery repeats the side effect. This is the default; design
  for it.
- **Exactly-once** is a marketing word for "at-least-once delivery + idempotent
  processing" (or a broker's transactional scope that rarely spans your database).
  Do not rely on a broker's exactly-once flag to protect a payment; make the handler
  idempotent instead.
- **At-most-once** (fire and forget) drops messages on failure — acceptable only for
  data you can afford to lose (metrics samples), never for state changes.

## Consumer idempotency — the load-bearing pattern

A handler must produce the same result whether it runs once or five times:

- **Dedup key** — every message carries a stable ID; the consumer records processed
  IDs and skips repeats, atomically with its work (same transaction, or a unique
  constraint on the effect).
- **Idempotent effect** — prefer operations that are naturally repeatable: `SET
  status='paid'` over `balance = balance + 10`; an upsert over an insert.
- **Effect + dedup in one transaction** — record "processed message X" and the state
  change together, or a crash between them reintroduces the double-apply you were
  preventing.

## The outbox pattern — atomic "change state AND publish"

You cannot atomically write your database AND publish to a broker — two systems, no
shared transaction. A crash between them either loses the event or publishes a change
that rolled back. The outbox fixes it: within the local transaction, write the event
to an `outbox` table alongside the state change; a separate relay polls the outbox and
publishes, marking rows sent. The state change and the intent-to-publish commit
together; the relay's at-least-once publish is covered by consumer idempotency.

## Topic and partition design

- **Topic per event type or per aggregate** — not one firehose everyone filters. The
  granularity is your coupling surface.
- **Partition key = ordering scope.** Order is guaranteed only within a partition, so
  key by the entity whose events must stay ordered (`order_id`), never randomly. Wrong
  key = events for one order processed out of order across partitions.
- **Schema is a contract.** Version events; add fields, never repurpose or remove them
  without a migration. Consumers must tolerate unknown fields (forward-compat) and
  missing new ones (backward-compat). A breaking schema change is a coordinated
  deploy, not a field rename.

## Sagas — multi-step workflows without a distributed transaction

A business process spanning services (order → payment → shipping) has no global
transaction. A saga sequences local transactions, each publishing the event that
triggers the next, with a **compensating action** for each step that can fail after a
prior step committed (refund on ship-failure). Design the compensations first; a saga
without them is a half-completed order with no way back.

## Dead-letter queues and poison messages

A message that fails every retry (malformed, references deleted data) must not block
the partition forever. After a bounded retry count with backoff, route it to a DLQ —
off the hot path, retained for inspection and manual replay. A DLQ with no alarm and
no one watching is a silent data-loss bucket; monitor its depth.

## Defer rule

- In-process framework queues (Laravel queues, Sidekiq, Celery) as *usage* → the
  stack plugin. This skill owns the cross-broker architecture, not the API.
- The service-boundary decision (which service owns which event) → `system-design`.
- Concurrency hazards inside a single consumer → `/concurrency:review`.

## Anti-patterns

- **Assuming exactly-once** — trusting a broker flag instead of idempotent handlers.
- **Non-idempotent consumer** — `balance += x` on an at-least-once queue; double-apply
  on redelivery.
- **Dual write** — writing the DB then publishing without an outbox; lost or phantom
  events on a crash between them.
- **Random partition key** — ordering silently broken across partitions.
- **Saga without compensation** — a failed step leaves committed prior steps stranded.
- **Unmonitored DLQ** — poison messages vanish into a bucket no one watches.
