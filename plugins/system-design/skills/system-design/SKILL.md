---
name: system-design
description: Use when shaping system-level structure — service boundaries, data ownership, scaling path, caching layers, sync vs async integration, single points of failure — before or while structural implementation happens. For code-level module structure use code-architecture; for the domain model itself use domain-modeling.
---

# System design

The level above the code: how the system's parts split, who owns which data, how
load scales, where caches sit, which hops are synchronous. Map what exists before
proposing anything — read the code, configs, and manifests (docker-compose, k8s
specs, CI, entrypoints, connection strings) and write down the real services,
stores, queues, external deps, and the data flows between them. No design on a
blank imagined system.

## The rule: boundaries follow data ownership, not org charts

Split a service where **data ownership and change cadence diverge** — never just to
make deploys feel modern. Two things that always change together and share the same
data belong in one service; splitting them buys you a distributed transaction and a
network hop for nothing. The cost of a boundary is a permanent API, versioning, and
a failure mode between the halves; make it earn that.

## Questions that decide a split

Before drawing a boundary, answer these — a "no" on the first two is a strong signal
to keep it one service:

1. Do the two halves own **different data** that changes on **different cadences**?
2. Would they **scale**, **fail**, or **deploy** independently in practice?
3. Is the API between them **stable enough** to version, or will it churn every
   feature? (A boundary across a churning seam is a tax on every change.)
4. Who is **on call** for each half? A boundary no team owns end-to-end rots.

> Worked example: "split checkout from catalog?" Catalog is read-heavy, changes
> hourly, owned by merchandising; checkout is write-heavy, transactional, owned by
> payments, and must not go down when catalog reindexes. Different data, cadence,
> scaling, failure domain, and team → split. "Split cart from checkout?" Same team,
> same request path, shared session data, always deploy together → one service; a
> boundary here only buys a network hop mid-transaction.

## Data ownership

- Every piece of data has **exactly one owning service**. Others read it via its API
  or a replicated copy — never by reaching into its store. A shared database two
  services both write is not two services; it is one service with two deploys and a
  hidden coupling that breaks silently.
- Replication is a deliberate choice with a staleness budget, not an accident of
  convenience. State how the copy goes stale and who tolerates it.

## Scaling path

- **Vertical first.** Go horizontal only when a *measured* bottleneck says so, and
  name the measurement. Horizontal scaling buys throughput and costs you state
  coordination, cache coherence, and a class of race conditions you did not have.
- Identify the actual constraint — CPU, memory, I/O, a single lock, a hot row —
  before scaling the thing next to it. Adding replicas behind a single-writer
  database moves the queue, it does not shorten it.

## Caching layers

Every cache added ships with its invalidation strategy and staleness tolerance
**stated up front** — no cache without an answer to "how does it go stale, and who
cares". Name where it sits (client, CDN, app, database) and what busts it on write.
The correctness failure modes (stampede, eviction, key design) are performance-tuning
territory; the *placement* decision — which layer owns which data's cache — is here.

## Sync vs async integration

- Synchronous when the caller needs the result to proceed and can tolerate the
  callee's latency and failure as its own. Asynchronous (queue/event) when the caller
  can proceed without the result.
- **Every async hop names its failure modes**: lost messages, duplicates, ordering,
  poison messages, and back-pressure. An event-driven design that has not answered
  "what happens on redelivery" is a data-corruption bug on a timer. (The delivery-
  semantics detail — outbox, sagas, DLQ, idempotency — is the event-driven plugin's.)

## Single points of failure

Name each SPOF the design keeps and why keeping it is acceptable — or what removes it
later. An unnamed SPOF is one discovered in an incident; a named one is a decision.

## Present options, record rejections

When the choice is non-obvious, put at least two viable shapes on the table, each
with what it costs and what it buys, recommend one, and say why the others lose. A
design decision recorded without its rejected alternatives is not reviewable — it is
an assertion. Implement the chosen shape in the smallest reviewable increments: one
boundary move, one schema change, one integration swap per step.

## Defer rule

- Code-level structure (units, interfaces, file placement, cohesion) →
  `code-architecture` and its architecture-reviewer.
- The domain model itself (bounded contexts, aggregates, ubiquitous language) →
  `domain-modeling` in this plugin.
- REST contract detail (paths, verbs, status, payloads) → `api-design`.
- Cache correctness mechanics and load-test numbers → `performance-tuning`.
- Local environment topology → `dev-env`.

## Anti-patterns

- **Boundaries by org chart** — services drawn to match teams, not data ownership.
- **Shared write database** — two services writing one store, coupled invisibly.
- **Scale-before-measure** — replicas added against an unidentified bottleneck.
- **Cache without invalidation** — a stale-read bug traded for a latency win.
- **Silent async hop** — a queue with no answer for duplicates, loss, or ordering.
- **Decision without alternatives** — a shape chosen with no rejected options shown.
