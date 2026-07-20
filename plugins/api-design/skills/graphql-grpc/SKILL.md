---
name: graphql-grpc
description: Use when designing or reviewing a GraphQL or gRPC API — GraphQL schema design, the N+1/dataloader problem, resolver authorization, query depth/complexity limiting, pagination and error handling; gRPC protobuf design, streaming, deadlines, and versioning. These are distinct paradigms from REST with distinct failure modes; for REST use api-design.
---

# GraphQL & gRPC APIs

Neither is REST, and applying REST habits to them fails in specific ways. GraphQL's
flexibility is its risk surface — a client can ask for anything, including your
database on its knees. gRPC's contract is a compiled artifact — the `.proto` is the
API, and evolving it wrong breaks every client silently.

## Which paradigm

| Situation | Reach for |
|---|---|
| Many clients, varied data needs, one round trip | GraphQL |
| Public API, cacheable resources, broad tooling | REST (→ api-design) |
| Service-to-service, low latency, streaming, typed contract | gRPC |
| Browser ↔ gRPC | gRPC-Web or a gateway; not raw gRPC |

Do not pick GraphQL for a two-endpoint internal service, or gRPC for a browser-first
public API. The wrong paradigm is a permanent tax.

## GraphQL: the N+1 problem is the default

A naive resolver runs one query per field per item — 100 users each resolving `posts`
is 101 queries. This is the single biggest GraphQL performance failure and it is the
default behavior, not an edge case.

- **Batch with a DataLoader** per request: collect the keys resolved in one tick, issue
  one batched query, distribute results. Every relationship resolver that hits a data
  source needs one.
- Measure query counts per operation in dev; a graph that looks fine on one object melts
  on a list.

## GraphQL: authorization at the resolver, not the gateway

REST authorizes per endpoint; GraphQL has one endpoint, so **authorization is per field
and per object**, in the resolver, against the authenticated user. A query can reach any
node in the graph — `user(id: 5) { paymentMethods }` — so every sensitive field checks
the viewer's right to it. "Authenticated" is not "authorized to see this node".

## GraphQL: bound the query, shape the errors

- **Depth and complexity limits** — a client can nest `friends { friends { friends …}}`
  into an exponential query. Cap query depth and assign field-cost complexity budgets;
  reject over-budget queries before execution.
- **Pagination** — cursor-based (Relay connections) over offset for stable, scalable
  lists; never return an unbounded collection field.
- **Errors** — GraphQL returns `200` with an `errors` array; partial success is normal.
  Use typed error extensions (codes), never leak internals in messages, and design
  clients to read `errors`, not just `data`.
- **Schema is the contract** — deprecate fields with `@deprecated`, add before you
  remove, and never repurpose a field's meaning.

## gRPC: the proto is the API

- **Field numbers are forever.** Never reuse or renumber a field tag — old clients
  decode by number. Add new fields with new numbers; `reserved` the numbers and names
  you retire so they can't be reused by accident.
- **Backward/forward compatibility** — unknown fields are preserved, not errors; make new
  fields optional with sensible defaults. A required-field mindset breaks rolling deploys.
- **Streaming** — pick deliberately: unary, server-stream, client-stream, or bidi. A
  stream needs flow control and a termination contract; a bidi stream with no backpressure
  plan floods the slow side.
- **Deadlines, always** — every call carries a deadline/timeout propagated across hops;
  a gRPC call without one hangs a thread until the connection dies. Propagate the
  remaining budget downstream, don't reset it per hop.
- **Status codes** — use the canonical gRPC codes (`NOT_FOUND`, `INVALID_ARGUMENT`,
  `DEADLINE_EXCEEDED`), not a string in the message.

## Reviewing the API

GraphQL:
- Every data-source relationship resolver batches through a DataLoader (no N+1).
- Authorization is enforced per field/object in resolvers, against the viewer.
- Query depth and complexity are capped; no unbounded collection fields.
- Cursor pagination on lists; typed error codes; no internals in error messages.

gRPC:
- No proto field number is ever reused/renumbered; retired ones are `reserved`.
- New fields are optional with defaults; rolling deploys stay compatible.
- Every call sets and propagates a deadline; streams have flow control + termination.
- Canonical status codes, not error strings.

## Defer rule

- REST contract design (paths, verbs, status codes, RFC 9457 problems) → the `api-design` skill (this plugin).
- The datastore query the resolver runs (indexing, statement shape) → `database-design`.
- Token/scope auth mechanics behind the resolver check → `security:api-auth`.

## Anti-patterns

- **N+1 resolvers** — no DataLoader; one query per field per row.
- **Gateway-only authz on GraphQL** — a single endpoint with per-field data but no
  per-field checks.
- **Unbounded query** — no depth/complexity limit; one client query exhausts the DB.
- **Reusing a proto field number** — silent decode corruption for old clients.
- **gRPC call with no deadline** — a hung thread waiting on a dead peer.
- **Offset pagination on a large graph** — slow, unstable pages.
- **Introspection open in production** — the full schema handed to any attacker; disable
  or gate it on public GraphQL endpoints.
- **Required proto fields** — a compatibility trap; prefer optional-with-default.
