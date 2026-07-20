---
name: domain-modeling
description: Use when modeling a business domain — bounded contexts, ubiquitous language, entities vs value objects, aggregates and roots, domain events, context mapping. The DDD toolkit for domains that earn it, not CRUD.
---

# Domain modeling

Domain-Driven Design is a toolkit for **complex domains** — where the business rules,
not the database, are the hard part. It is overkill for CRUD: if the app is forms
over tables with no invariants worth protecting, a plain model and a service layer
beat aggregates and value objects. Reach for DDD when the same word means different
things to different teams, when invariants span several records, or when the domain
logic keeps leaking into controllers and jobs.

## Ubiquitous language

One language per context, shared by code and domain experts. If the business says
"policy" and the code says "record", every conversation pays a translation tax and
bugs hide in the gap. Name classes, methods, and events in the domain's words. When
experts disagree on a word's meaning, that is not a naming quibble — it is two
bounded contexts arguing to be born.

## Bounded contexts

A bounded context is the boundary within which a model and its language are
consistent. "Customer" in Sales (a lead with a pipeline stage) is not "Customer" in
Support (a ticket history) or Billing (a payment method and dunning state) — same
word, three models. Forcing one shared Customer object across all three is the
canonical DDD failure: it becomes a god-object owned by no team, and every context
warps it.

- Draw context boundaries where the language changes meaning.
- One context = one model = one team's mental model. It usually maps to a service
  boundary, but need not — a modular monolith can host several contexts.

## Where to start

Do not start from tables. Start from behavior:

1. **List the domain events** — the facts the business cares about, in its words
   (`OrderPlaced`, `InvoiceIssued`). These reveal the real workflow.
2. **Find the invariants** — the rules that must always hold ("an order's total
   equals the sum of its lines"; "a subscription cannot be active and unpaid"). Each
   invariant that spans several records names a candidate **aggregate**.
3. **Draw the aggregate around the invariant** — the smallest cluster that must be
   consistent in one transaction to keep that rule true.

> Worked example: an `Order` aggregate roots `OrderLine` children and a `Money` total.
> The invariant "total = Σ lines" holds inside one transaction on the root; adding a
> line goes *through* `Order`, never straight to `OrderLine`. `Customer` is referenced
> by ID — a different aggregate, a different transaction, an `OrderPlaced` event
> between them.

## Tactical building blocks

- **Value object** — defined by its attributes, no identity, immutable. `Money`,
  `DateRange`, `Address`. Two values with equal attributes are equal. Prefer these:
  they carry invariants (a `Money` can't go negative if you don't let it) and have no
  lifecycle to manage.
- **Entity** — defined by identity, not attributes. A `User` is the same user across
  a name change. Has a lifecycle; equality is by ID.
- **Aggregate** — a cluster of entities and value objects with one **aggregate root**
  as the only entry point. Outsiders reference the root, never its innards. The
  aggregate is the **consistency + transaction boundary**: invariants across its
  members hold within one transaction; anything spanning aggregates is eventually
  consistent, via domain events.
- **Domain event** — a fact that happened in the language of the domain
  (`OrderPlaced`, `PaymentCaptured`), the mechanism by which one aggregate reacts to
  another without a synchronous coupling.

## Aggregate design rules

- **Keep aggregates small** — ideally the root plus the value objects that must be
  consistent with it. A giant aggregate serializes writes and becomes a contention
  hotspot.
- **Reference other aggregates by ID**, not by object — a direct object link smuggles
  in a transaction boundary you did not intend.
- **One aggregate per transaction** as the default. Need two? Use a domain event and
  accept eventual consistency, or reconsider the boundary.

## Context mapping

Contexts must talk; the map names *how*:

- **Shared kernel** — two contexts share a small agreed model. High coupling; only
  between teams that coordinate closely.
- **Customer/Supplier** — downstream context's needs shape the upstream's API.
- **Anti-corruption layer (ACL)** — the downstream wraps the upstream behind a
  translation layer so a legacy or external model does not leak in and corrupt its
  language. The default when integrating anything you do not control.
- **Published language / Open host** — a well-documented shared interface (events,
  an API) many contexts consume.

## Defer rule

- Where contexts become *services*, and the data-ownership/scaling of those services
  → `system-design`.
- Persisting aggregates (schema, migrations, transaction mechanics) →
  `database-engineer` and the SQL plugins.
- The event delivery machinery (broker, outbox, saga, DLQ) → the event-driven skill (this plugin).

## Anti-patterns

- **Anemic domain model** — entities that are bags of getters/setters with all logic
  in "service" classes; DDD's shape without its substance.
- **One shared Customer** — a single model forced across contexts that mean different
  things by it.
- **God aggregate** — a huge consistency boundary that serializes every write.
- **DDD on CRUD** — aggregates and value objects over forms-on-tables with no
  invariants; ceremony that buys nothing.
- **Cross-aggregate transaction as default** — two aggregates in one transaction
  instead of an event; the coupling you built DDD to avoid.
