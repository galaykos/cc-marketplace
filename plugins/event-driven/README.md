# event-driven

Cross-broker message-driven architecture discipline — the guarantees you assume are
false by default.

- **`event-driven` skill** — delivery semantics (assume at-least-once), consumer
  idempotency (the load-bearing pattern), the outbox for atomic state-change-and-
  publish, topic/partition design, event schema versioning, sagas with compensation,
  and dead-letter handling. Broker-selection quick reference included.
- **`/event-driven:review`** — audit a design or producer/consumer code for the
  idempotency, outbox, ordering, saga, and DLQ gaps that become silent data corruption.

Scope: the architecture across brokers (Kafka, SQS, RabbitMQ, Redis Streams). In-process
framework queues (Laravel queues, Sidekiq, Celery) as usage belong to the stack plugin;
service-boundary ownership belongs to system-design.
