---
name: performance-tuning
description: Use when code is measurably slow or heavy, or when reviewing a change for performance — the MEASURING lens: measure-before-and-after discipline, hotspot checklist (N+1 detection, payload, bundle, Core Web Vitals), cache correctness (stampede, TTL, eviction), percentile load testing. Index/schema design → database; statement shape → sql. Not for unmeasured micro-optimizing.
---

# Performance tuning

The iron rule: **measure before, measure after.** An optimization without a
before/after number is a guess, and guesses do not ship. If you cannot measure the
cost, your first task is to build the measurement — a profiler trace, a timed run, a
bundle report, an `EXPLAIN` plan — not to start optimizing.

## The loop

1. **Reproduce and quantify** the slowness with a real measurement.
2. **Find the dominant cost.** Optimize the biggest contributor first; a 2% saving
   next to an 80% hotspot is noise. Ignore micro-wins while a dominant cost remains.
3. **One change at a time.** Batched unrelated changes make the re-measurement
   unattributable — you cannot tell which one helped.
4. **Re-measure and report before/after.** If the numbers do not improve, revert and
   say so. No change survives without its number.

A report that earns the change reads like this — a number, a cause, a number:

> Endpoint p95 240ms → 38ms. Query log showed 84 identical `SELECT … FROM roles`
> (N+1 over `user.roles`); added eager-load. Re-ran: 84 queries → 2, p95 confirmed 38ms.

## First, reach for the right measurement

Do not read code to guess the hotspot — take a reading. What to reach for per surface:

| Symptom | Measurement |
|---|---|
| Slow endpoint / job | request timing + query log (count + duration per query) |
| Slow SQL | `EXPLAIN` / `EXPLAIN ANALYZE` — read the plan, not the query |
| Heavy page load | bundle analyzer + Lighthouse/CWV on a throttled device |
| High CPU / memory | a sampling profiler (flame graph), not `print`-timing |
| Falls over under load | a load test with ramp-up and percentile output |

The reading names the dominant cost; everything below is how to remove the specific
cost you found, not a checklist to apply blind.

## Backend hotspots

- **N+1 queries** — count queries per request, not per loop iteration; the loop hides
  it. Eager-load or batch.
- **Missing indexes** — verify with the query plan, never intuition. An index on the
  wrong column is dead weight; on the right one, orders of magnitude.
- **Chatty I/O** — round trips to DB, cache, and external APIs dominate wall-clock;
  collapse N calls into one where the API allows.
- **Payload size** — over-fetching columns, unbounded collections, N-deep serializer
  graphs. Select what you use; paginate what you list.

## Frontend hotspots

- **Bundle size / code splitting** — analyze before and after; split on route and on
  heavy rarely-used deps. Ship less JS before optimizing the JS you ship.
- **Render-blocking resources** — scripts and styles on the critical path delay first
  paint; defer, async, or inline the critical minimum.
- **Images** — modern formats, explicit dimensions (CLS), lazy-load offscreen.
- **Core Web Vitals** — LCP, CLS, INP measured on realistic devices and networks, not
  a warm localhost. The lab lies about the tail.

## Cache correctness

A cache is a correctness surface, not just a speed trick. For every cache, state four
things — what is cached, where it lives, the TTL, and the invalidation trigger — then
check the failure modes:

- **Invalidation** — a cache with no invalidation story is a stale-read bug waiting to
  happen. Write path must bust or update the key it invalidates.
- **Stampede / dogpile** — when a hot key expires, N concurrent misses hammer the
  origin at once. Mitigate with a lock/single-flight, early recompute, or jittered
  TTLs — never a fleet of identical TTLs expiring in lockstep.
- **Eviction** — under memory pressure the store drops keys on its own policy (LRU/
  LFU); code must treat every hit as a possible miss, never assume presence.
- **Staleness bounds** — decide the maximum acceptable staleness per key and set TTL
  to it deliberately; "cache forever and hope" is a decision made by accident.
- **Key design** — include every input that changes the value (tenant, locale,
  version) or you serve one user's value to another.

## Load testing

- **Realistic scenarios** modeled on production traffic mix, not a synthetic best case.
- **Ramp-up**, not instant full load — find the knee, not just the cliff.
- **Percentiles, never averages** — report p50/p95/p99. The average hides the slow
  tail that users actually feel; p99 is a real user every hundred requests.

## Defer rule

- SQL query-shape and indexing idioms → `/sql:review` (and the dialect plugins). This
  skill counts the queries and reads the plan; the SQL skills fix the statement.
- Framework-idiom performance (React re-renders, Eloquent hydration) → `/react:review`,
  `/laravel:review`. Recommend, do not duplicate.
- Applying a batch of fixes → the shared `task-executor`; this skill decides *what* is
  slow and *why*, not the mechanical application.

## Anti-patterns

- **Optimizing without measuring** — the cardinal sin; you cannot know the hotspot by
  reading code.
- **Micro-optimizing the non-hotspot** — polishing a 2% path while 80% burns elsewhere.
- **Averages instead of percentiles** — a green average over a red p99.
- **Cache without invalidation** — trading a slow read for a wrong one.
- **Batched changes** — un-attributable wins; keep changes one at a time.
