---
name: api-design
description: Use when designing or reviewing your own REST APIs — resource naming and nesting, the honest status-code set, RFC 9457 problem+json errors, cursor vs page pagination, whitelisted filtering/sorting, URL versioning and what counts as breaking, Idempotency-Key semantics, contract hygiene (ISO 8601, string IDs, minor-unit money), Laravel apiResource/FormRequest/API Resource mapping. Consuming third-party API docs lives in the api-docs-first plugin.
---

## Resources are nouns

- Plural, kebab-case nouns: `/purchase-orders`, `/order-items`. The HTTP method is
  the verb; a verb in the path (`/getOrders`, `/orders/create`) duplicates it.
- Nest one level max: `/orders/{id}/items` reads as ownership. Deeper nesting
  forces callers to carry three IDs to address one row — promote to a top-level
  resource and filter instead: `/order-items?filter[order]=...`.
- Non-CRUD actions become sub-resources first (`POST /orders/{id}/refunds`
  creates a refund you can later GET); a verb only as last resort when nothing is
  created: `POST /orders/{id}/cancel`. Never GET for anything that mutates —
  crawlers and prefetchers will call it.
- Identifiers live in the path; everything else is a query param. A path segment
  is an address, not a filter.

## Status codes: the small honest set

Use 200/201/202/204, 301/303/304, 400/401/403/404/409/410/422/429, 500/503 —
and stop. Every other code is a trivia question for your consumers.

- 201 with a `Location` header for creation; 202 when work is queued and a
  status endpoint exists; 204 for deletes and bodyless updates.
- 401 = we do not know who you are (missing/expired credentials); 403 = we know
  exactly who you are and the answer is no. Backwards, these break every
  client's token-refresh logic.
- 404 for absent resources — and for resources the caller must not know exist.
  A 403 on `/users/{id}` confirms the ID is real; return 404 when existence
  itself is the secret.
- 409 = state conflict (duplicate, stale version, "already cancelled");
  422 = the request is semantically invalid regardless of state. Validation
  failures are 422; reserve 400 for malformed syntax (unparseable JSON).
- Never 200 with an error body. Monitoring, caches, retry middleware, and every
  HTTP client branch on the status code; lying to them disables all of it.

## Errors: RFC 9457, one shape

- `Content-Type: application/problem+json` with `type`, `title`, `status`,
  `detail`, `instance`, plus extension members for machine-readable specifics.
  One error shape for the entire API — a client should parse errors once.
- Validation failures carry an `errors` map of field → messages as an extension
  member, still inside the problem document, not a second bespoke format.
- Include a request/correlation ID (in `instance` or an extension) that also
  appears in your logs; "it failed at 3pm" becomes a one-line grep.
- `detail` is for humans debugging; `type` is for code branching. Clients
  matching on English prose is a contract you did not mean to sign.

## Pagination

- Cursor/keyset for anything unbounded or feed-like: opaque `cursor` param in,
  `next_cursor` out. Offset re-reads every skipped row and duplicates/drops
  items when rows insert mid-scroll — the sql plugin's keyset section is the
  storage half of this rule.
- `page`/`per_page` only for small bounded admin-style sets. Cap `per_page`
  server-side; an uncapped limit is self-service denial of service.
- Return `total` only when it is cheap; a `COUNT(*)` over millions of rows to
  decorate page 1 pays for a number nobody scrolls to. Omit it, don't fake it.
- Pick one home for pagination metadata — `Link` header or a `meta` block —
  and use it everywhere. Two conventions means every client implements both.

## Filtering and sorting

- Explicit whitelisted params: `?filter[status]=shipped&sort=-created_at`.
  Every filterable field and sortable column is an allowlist entry backed by an
  index — sort params reach ORDER BY, which cannot be parameter-bound.
- Reject unknown params with 400 and name the offender. Silently ignoring
  `?fliter[status]=` returns the unfiltered set and the caller ships the bug.
- `-` prefix for descending, comma for multiple: `?sort=-created_at,id`.

## Versioning

- URL major version (`/v1/`) as the pragmatic default: visible in logs,
  testable with curl, routable at the proxy. Header versioning is purer, and
  nobody can see which version a request used.
- Additive changes never bump: new endpoints, new optional fields, new enum
  values clients were told to tolerate.
- Breaking = removing/renaming fields, changing a type or format, tightening
  validation on existing input, changing status codes or the error shape,
  making optional required. Any of these behind the same `/v1/` is a silent
  contract violation — bump or don't ship.
- Two live versions max, with a published sunset date for the old one.

## Idempotency

- GET/PUT/DELETE are idempotent by definition — write handlers that honor it:
  DELETE of an already-deleted thing is 204 or 404, never 500.
- POST that creates money-adjacent things (payments, orders) takes an
  `Idempotency-Key` header: the first request executes and caches the response;
  a retry with the same key returns the cached response — same status, same
  body. The same key with a different payload is a 409.
- Keys expire (24h is common) and scope per endpoint per caller. Without this,
  every network timeout is a potential double charge.

## Contract hygiene

- Timestamps: ISO 8601 UTC with offset (`2026-07-05T12:00:00Z`). Epoch integers
  make every consumer guess seconds vs milliseconds.
- IDs are strings (ULID/UUID) even when storage uses integers — JavaScript
  corrupts integers above 2^53, and string IDs let storage change later.
- Money: integer minor units plus ISO 4217 currency
  (`{"amount": 1999, "currency": "EUR"}`). A float for money is a rounding bug
  with an invoice attached.
- Booleans are `true`/`false`, never `"Y"`/`1`/`"yes"`; enums are lowercase strings.
- Document what null vs absent means (usual PATCH contract: null = clear the
  field, absent = leave unchanged) — undefined semantics break partial updates.

## Laravel mapping

- `Route::apiResource` for CRUD; custom actions as named routes beside it, not
  a `Route::any` catch-all.
- FormRequest per write endpoint — failed validation already returns 422 with
  an errors map; reshape it to problem+json once in the exception handler's
  `render`, for every exception type.
- API Resources (`JsonResource`) for every response — a raw model in `return`
  leaks new columns into the contract the day a migration runs. `whenLoaded`
  for relations keeps eager loading honest.
- `->cursorPaginate()` for feeds, `->paginate()` for bounded lists; both emit
  `meta`/`links` blocks — keep them, don't hand-roll a second envelope.
- Policies for authorization (`authorize` in the FormRequest or controller) →
  403; named `RateLimiter` limiters per consumer tier → 429 with `Retry-After`.

## Anti-patterns

- Verbs in paths (`/createOrder`, `/orders/delete/{id}`) — the method is the verb.
- `{"success": true, "data": ...}` envelopes — the status code already says it;
  the envelope just makes every client unwrap twice.
- 200 for errors, 500 for validation failures, 403 when you mean 401.
- Offset pagination on an infinite feed — duplicates on insert, gaps on delete.
- Silently ignoring unknown query params, then "the filter works locally".
- Breaking changes behind the same version because "only one client uses it".
- Different error shapes from validation, auth failures, and crashes.
- PATCH that requires the full object — that is PUT wearing a costume.
- Timestamps in local time, IDs as JSON numbers, money as floats.
