---
description: Review message-driven code or design for delivery-semantics, idempotency, outbox, saga, and DLQ gaps against event-driven
argument-hint: [path-diff-or-design-doc]
---

Review the target's event-driven design — you audit the messaging architecture, not
implement it.

1. Determine scope from $ARGUMENTS — a design/RFC, producer/consumer code, broker
   config, or a diff. If empty, locate producers, consumers, and queue/topic config in
   the repo and review those.

2. Invoke the `event-driven` skill from this plugin and apply its checklist: delivery
   semantics named (assume at-least-once), consumer idempotency (dedup key + idempotent
   effect, recorded atomically with the work), the outbox pattern wherever a state
   change must publish an event (no dual write), topic/partition design (partition key
   = ordering scope), event schema versioning (additive, forward/backward compatible),
   sagas with compensating actions for every fallible step, and DLQ + retry with a
   monitored depth.

3. Output findings one line each:
   path-or-section:line — severity — problem — fix
   Order by severity. A non-idempotent consumer on an at-least-once queue, or a dual
   write with no outbox, is always critical (silent data corruption).

4. Defer, do not duplicate: in-process framework-queue usage → the stack plugin;
   service-boundary ownership → `/system-design:review`; single-consumer races →
   `/concurrency:review`.

5. When findings exist, offer the next step as a selectable choice (AskUserQuestion):
   "Apply the fixes now (Recommended)" / "Report only". On apply, hand the finding
   list to the shared `task-executor`. In headless or non-interactive runs, report only.
