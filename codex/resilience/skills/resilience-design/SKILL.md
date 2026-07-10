---
name: resilience-design
description: Use when code crosses a process boundary — HTTP calls, queues, databases, third-party APIs, background jobs — to design timeout, retry, degradation, and delivery-semantics decisions instead of inheriting defaults that fail at 3am.
---

## Core rule

Every network call fails eventually. Not "might" — will: the dependency
restarts, the DNS entry goes stale, the vendor ships a bad deploy. The
design question is never whether the call fails but what happens then —
and that question gets answered at write time, deliberately, or at
incident time, expensively. A call site with no failure decision has one
anyway: whatever the library default is, discovered during the outage.

## Timeouts

Every outbound call gets an explicit timeout. Library defaults are
usually infinite (Python requests, many DB drivers) or wrong for your
context — an inherited 30s default inside a 5s request budget is a slow
failure generator.

- Set connect and read timeouts separately. Connect failures are fast
  and cheap to detect; read timeouts guard against a server that
  accepted the connection and then stalled.
- Propagate the budget: a caller's timeout must exceed the sum of its
  callees' worst-case attempts, or the caller gives up while a callee
  is still retrying into the void.

    caller budget:              2000ms
    callee: 3 tries x 800ms   = 2400ms   <- violates the budget
    fix:    2 tries x 800ms   = 1600ms   + headroom

- Too long ties up threads and connections; too short manufactures
  failures under normal jitter. Start from measured p99 plus margin,
  not a round number.

## Retries

Retry only idempotent operations. Retrying a non-idempotent write
duplicates the write — for a payment, that duplicates money. Order of
work: make the operation idempotent (idempotency keys, uniqueness
constraints), then add retries. Never the reverse.

- Exponential backoff with jitter. Backoff without jitter synchronizes
  failed clients into waves that hit the recovering service in lockstep.
- Cap attempts and total retry budget. A retry loop with no cap is an
  outage amplifier.
- A retry storm is a self-inflicted DDoS: the dependency slows, every
  caller retries, load triples, the dependency dies. Retry budgets and
  circuit breakers are the two brakes on that loop.
- Retry transport errors and 5xx/timeouts; never 4xx — the request is
  wrong and will be wrong again.

## Circuit breaking / fail fast

When a dependency is down, stop hammering it. After N consecutive
failures or an error-rate threshold, open the circuit: fail immediately
without making the call, probe occasionally, close when probes succeed.
The caller gets a fast, honest failure it can act on; the dependency
gets room to recover. A fallback returned in 5ms beats a request queued
behind a dead service for 30s — queueing forever is not patience, it is
resource exhaustion on layaway.

## Graceful degradation

Rank features by criticality before the outage, not during it. For each
dependency, write down what still works when it is down:

    recommendations down  -> show cached bestsellers
    search down           -> category browsing still works
    payment provider down -> accept order, charge asynchronously
    auth down             -> nothing works; that is the critical path

Cached or stale answers usually beat errors — a five-minute-old price
beats a 500 page. But degrade loudly: emit a log line and a metric every
time a fallback fires. Silent degradation means learning about the
outage from customers, or serving stale data for weeks, or never.

## Backpressure and queues

Bounded queues only. An unbounded in-memory queue is deferred OOM — it
converts "the consumer is slow" into "the process is dead" with a delay
long enough to make the crash mysterious. When the bound is hit, shed
load early and explicitly: reject at the front door with 429/503 rather
than accepting work you will silently drop later.

Pick delivery semantics per operation and write the choice down:

- At-most-once: fire and forget; loss acceptable (metrics, hints).
- At-least-once: duplicates possible; every consumer must be idempotent
  (most job queues live here).
- Effectively-once: at-least-once delivery plus idempotent processing —
  the practical target for anything touching money or state.

An undocumented choice is still a choice — just one nobody agreed to.

## Blast-radius containment

Bulkheads: give each dependency its own connection pool, thread pool,
or semaphore, so one slow dependency cannot exhaust shared resources
and take unrelated features down with it. Isolate the optional from the
critical path — the recommendations call must not be able to starve
checkout of connections. When a nice-to-have and a must-have share a
pool, the nice-to-have's bad day becomes the must-have's outage.

## Observability hooks

Every failure path emits a signal: a log line with context, a metric, a
span annotation. A swallowed exception is a future mystery — the 3am
incident where the system "just got slow" and nothing in the logs says
why. Fallback fired, circuit opened, retries exhausted, queue rejected:
each is an event worth counting. When the incident happens anyway, hand
it to the `cmd-debugging-debug` skill — but the quality of that debugging session is
decided now, by what the failure paths bothered to record.

## Worked micro-example: payment webhook handler

    receive webhook
      verify signature; reject bad ones (4xx class -- no retry)
      idempotency key = event id; already processed? return 200
      call charge API: connect 2s / read 5s, idempotency key set
      success -> record, return 200
      transient failure -> up to 2 retries, backoff + jitter
      retries exhausted -> dead-letter queue + metric, return 500
      degraded mode (charge circuit open): accept-and-queue --
        persist to bounded queue, return 200, drain when circuit
        closes; queue full -> 503, loudly

Every decision — timeouts, key, retry cap, DLQ, degraded mode — is in
the code before the first webhook arrives.

## Boundaries

- Infra-level HA and failover are the devops plugin's territory; this
  skill designs application-level failure handling.
- The inversion strategy in the approaches plugin (the `cmd-approaches-compare` skill)
  generates failure routes at design time — this skill supplies the
  standard mitigations for the routes it finds.
- Injection and authz gaps go to the `cmd-security-review` skill; a timeout will not
  fix a missing permission check.

## Anti-patterns

- Infinite default timeouts — the library's "no timeout" silently kept.
- Blind retry on POST — duplicated orders, duplicated charges.
- Catch-and-continue — the exception logged nowhere, handled never.
- Unbounded in-memory queues — OOM with a fuse timer.
- Resilience theater — a circuit breaker around an in-process function
  call; ceremony with no network boundary to protect.
