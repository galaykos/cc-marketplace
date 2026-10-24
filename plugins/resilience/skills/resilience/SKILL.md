---
name: resilience
description: Use when code crosses a process boundary (HTTP call, queue, database, third-party API, background job), handles errors (try/catch, error types, rethrow), has concurrent writers or retries, emits logs, metrics, traces or health checks, is slow or heavy or caches, or designs broker messaging (outbox, saga, DLQ) — timeouts, retries, circuit breakers, races, idempotency, observability, measure-first performance; one reference per concern.
---

Six runtime-quality concerns, one reference each. Read the core rule below for every concern
the change touches, then that concern's reference — only the ones the change selects, never
all six by default. `references/` sits beside this file: resolve each `references/…` path below
from this file's directory.

## Pick the references from the change

| The change touches | Read |
|---|---|
| a call across a process boundary — HTTP, database, third-party API, job dispatch — or its timeout, retry, circuit breaker, fallback or queue bound | `references/timeouts-retries.md` |
| an added or changed try/catch, error boundary, custom error type, rethrow, or a default substituted on error | `references/error-handling.md` |
| a shared write, check-then-act, lock, transaction, retried operation, or parallel writes to one row | `references/concurrency.md` |
| a log, metric, trace span, health check or alert | `references/observability.md` |
| a query or I/O in a loop, a cache, payload or bundle size, Core Web Vitals, or a measured slowness | `references/performance.md` |
| a broker, topic, queue consumer, event schema, outbox, saga or dead-letter queue | `references/messaging.md` |

A change with none of these reads none. Where two rows meet, one finding gets one owner:

- A catch block: `error-handling.md` decides whether it should EXIST, `observability.md` what a
  kept one EMITS.
- Duplicate delivery: the delivery design (dedup key, outbox, DLQ) is `messaging.md`; a race
  inside one consumer, or a retried call with no broker, is `concurrency.md`.

Standing: agent-graded — `/resilience:review` and `/code-review:review` name the references
they read on their `Checked:` line; nothing checks the pick.

## Timeouts, retries, degradation

Every network call fails eventually. Not "might" — will: the dependency
restarts, the DNS entry goes stale, the vendor ships a bad deploy. The
design question is never whether the call fails but what happens then —
and that question gets answered at write time, deliberately, or at
incident time, expensively. A call site with no failure decision has one
anyway: whatever the library default is, discovered during the outage.

## Error handling

Every error is one of two things: a bug or an event. A broken invariant
— null where the contract says never-null, an enum case that cannot
happen — is a bug; the only correct response is to crash loudly and fix
the code. A failed network call, a missing file, invalid user input:
these are events the program was always going to meet, and they deserve
designed handling. Most bad error handling comes from conflating the
two — recovering from bugs (hiding corruption) or crashing on events
(fragile software). Classify first; everything else follows.

## Concurrency

Two copies of your code will run the same lines at the same time — two
requests, a retry, a second queue worker, a user double-clicking. The
question is never whether concurrent execution happens but what breaks
when it does. Any read-check-write sequence that assumes the world
holds still between the read and the write is a race; the check alone
is never protection, because the world changes after you look.

## Observability

You cannot fix what you cannot see. Every production incident is
resolved at the speed of the telemetry the code bothered to emit — the
log line written at 2pm decides the length of the 3am incident. Design
each signal at write time, deliberately: what gets logged, what gets
counted, what gets traced, and what the health endpoint actually checks.

## Performance

The iron rule: **measure before, measure after.** An optimization without a
before/after number is a guess, and guesses do not ship. If you cannot measure the
cost, your first task is to build the measurement — a profiler trace, a timed run, a
bundle report, an `EXPLAIN` plan — not to start optimizing.

## Messaging

Asynchronous messaging trades a synchronous failure you can see for a distributed
one you cannot. Every guarantee you assume — "it arrives", "once", "in order" — is
false by default and must be designed for. The single rule that prevents most
production incidents: **assume at-least-once delivery and make every consumer
idempotent.** Everything in `references/messaging.md` serves that.
