---
name: concurrency-safety
description: Use when code has concurrent writers or retried operations — race conditions, check-then-act, optimistic vs pessimistic locking, distributed locks, retry idempotency — the locking/CAS mechanics that make two executions of the same lines safe. Money semantics → payments; broker delivery, outbox, DLQ → system-design:event-driven.
---

## Core rule

Two copies of your code will run the same lines at the same time — two
requests, a retry, a second queue worker, a user double-clicking. The
question is never whether concurrent execution happens but what breaks
when it does. Any read-check-write sequence that assumes the world
holds still between the read and the write is a race; the check alone
is never protection, because the world changes after you look.

## Check-then-act races

The canonical bug: read a value, decide based on it, write — with a
gap in between that another writer can enter.

    if balance >= amount:     <- both requests read 100
        balance -= amount     <- both withdraw; balance goes negative

Same shape everywhere: unique-slug checks ("no row with this name yet,
insert it"), seat booking ("seat free, reserve it"), signup limits,
inventory decrements. Fixes, in order of preference:

- Atomic single statement: `UPDATE ... SET balance = balance - :amt
  WHERE id = :id AND balance >= :amt`, then inspect affected rows. The
  check and the write happen as one operation or not at all.
- Unique constraint: let the database reject the duplicate slug/seat
  and handle the constraint violation. The constraint is the check.
- A lock held around the whole read-check-write, when the atomicity
  cannot be expressed in one statement.

An application-level SELECT followed by an INSERT guarded only by an
if-statement is a race with a latency-sized window.

## Optimistic vs pessimistic

Two working strategies; contention level picks between them.

- Optimistic: version column or ETag. Read the version, write with
  `WHERE version = :read_version`; zero rows affected means someone
  else won — reload and retry (bounded retries, then surface the
  conflict). Cheap when conflicts are rare; retry storms when hot.
- Pessimistic: `SELECT ... FOR UPDATE` inside a transaction. Blocks
  other writers up front. Right when conflicts are frequent or the
  retry is expensive; wrong as a default — held locks serialize
  throughput and invite deadlocks.

Low contention: optimistic. Hot rows (counters, a single account,
flash-sale inventory): pessimistic, or restructure to avoid the hot
row entirely.

## Idempotency

Any operation that can be retried will be retried — by the HTTP
client, the queue, the user's second click. Processing twice must
equal processing once.

- Give retried operations an idempotency key (payment intent id,
  webhook event id, message id). Store processed keys under a unique
  constraint; a duplicate key means return the recorded result, not
  re-execute the work.
- The key must come from the caller or the event, not be generated at
  processing time — a fresh UUID per attempt deduplicates nothing.
- Key storage and the side effect must commit together, or the crash
  between them re-opens the duplicate window.

## Queue and consumer safety

At-least-once delivery means duplicates WILL arrive — not might.
Design every consumer as if each message arrives twice.

- Dedup by message id before side effects; every side effect sits
  behind an idempotency guard.
- Visibility timeout must exceed worst-case processing time. When
  processing outlasts the timeout, the message reappears and a second
  worker starts the same job while the first still runs — a duplicate
  you manufactured yourself.
- Two consumers on one queue is concurrency even if each one is
  single-threaded. Ordering guarantees usually die at the second
  consumer; do not design as if they survive.

## Distributed locks

TTL plus fencing tokens, or do not bother.

- No expiry: the holder crashes, the lock lives forever, everything
  waits for a process that will never return. A lock without TTL is a
  scheduled outage.
- No fencing: the holder pauses (GC, network), the TTL expires,
  another worker takes the lock — now two holders write. A fencing
  token (monotonic counter checked by the resource) lets storage
  reject the stale holder. A lock without fencing is a race with
  extra steps.
- Prefer making the operation idempotent or atomic over locking it;
  a distributed lock is the last resort, not the first tool.

## Async pitfalls

- Fire-and-forget promises: an unawaited async call whose rejection
  vanishes. Await it, or hand it to a supervisor that logs and
  retries; "kicked it off" is not "it happened".
- Shared mutable state across awaits: every `await` is a yield point
  where other code runs; state read before the await can be stale
  after it. Re-read or pass values; do not cache across the gap.
- `Promise.all` with writes to the same row: parallel UPDATEs race or
  deadlock. Writes to shared state get sequenced or batched into one
  statement; `Promise.all` is for independent work.

## Transactions

A transaction gives atomicity — all writes or none — not mutual
exclusion. Two transactions can both read balance 100 and both commit
a decrement; whether that is allowed depends on the isolation level,
and common defaults allow it. A transaction does not protect against
check-then-act across two statements, lost updates at default
isolation, or anything touching a second system — an API call inside
a transaction is not rolled back. Atomic statements or explicit locks
do the excluding; the transaction makes the result all-or-nothing.

## Worked micro-example: webhook-driven payment credit

    receive webhook (at-least-once: duplicates expected)
      key = event id; INSERT INTO processed_events (unique on key)
        duplicate-key error -> already handled, return 200
      UPDATE accounts SET balance = balance + :amt WHERE id = :id
      both statements in one transaction -> key and credit commit
        together; a crash before commit means redelivery redoes both
      external side effects (email) queued after commit, keyed

## Boundaries

- Engine-specific lock mechanics — gap locks, `SKIP LOCKED`, advisory
  locks, isolation-level quirks — belong to the mysql/mariadb/
  postgresql plugins; this skill picks the strategy, they supply the
  syntax and semantics.
- Retry and backoff policy for the conflicts and failures this skill
  surfaces is the resilience plugin's territory (/resilience:review);
  this skill makes retries safe, that one makes them polite.

## Anti-patterns

- The if-check as protection — "we check first" describes the race,
  not the fix.
- Idempotency key generated at processing time — deduplicates nothing.
- SELECT-then-INSERT upsert with no unique constraint underneath.
- Distributed lock with no TTL, or a TTL with no fencing token.
- Retrying a non-idempotent operation because "it usually works".
- Sleep-based coordination — a timing assumption is a race deferred.
