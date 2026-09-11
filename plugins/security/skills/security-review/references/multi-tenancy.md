# Multi-tenancy: tenant scoping is authorization

A row another tenant can read is an IDOR, whatever the policy layer says. Every rule
here is one a from-memory review gets wrong because the framework *looks* like it
handles it. Standing: recorded — `/security:review` applies it; no script checks it.

## Global scope vs per-query filter — where each silently fails

A global scope (Laravel `addGlobalScope`, a Prisma `$extends` query hook, a Django
custom manager) is a default, not a guarantee: the ORM applies it on the paths it
owns and the leaks live on the paths it does not.

- **Raw and base-builder queries.** `DB::table()`, `DB::select()`, `->toBase()`,
  Prisma `$queryRaw` / `$executeRaw`, Django `.raw()` and `cursor.execute()` see no
  scope. Reports, exports and "fast paths" are written this way — grep for these first.
- **Explicit opt-outs.** `withoutGlobalScope(TenantScope::class)` is legitimate on an
  operator console and a finding on any tenant-facing route; treat each call site as
  a privileged operation and keep it off user paths.
- **Relations through an unscoped parent.** Scoping `Post` does not scope
  `Comment::find($id)`; scoping the child does not stop `$anyTenantPost->comments`.
  Django uses `_base_manager` (a plain `Manager`) for forward related access
  (`comment.post`), bypassing the filtering default manager unless
  `Meta.base_manager_name` names it. A Prisma hook that injects `where.tenantId` on
  `findMany` does not touch a nested `include` — included rows come back unfiltered.
- **Aggregates and counts.** Prisma's `count`, `aggregate` and `groupBy` are separate
  operations a hook wired for `findMany`/`findFirst` misses; a count that differs per
  caller leaks existence.
- **`findUnique` cannot take the filter.** It accepts unique fields only, so a hook
  cannot add `tenantId`; declare `@@unique([tenantId, id])` and query on the pair.
- **Writes.** `Model::insert()`, `createMany`, `updateMany`, `deleteMany`, `upsert`
  skip model events, so the `creating` observer that stamps `tenant_id` never runs —
  the column is null or attacker-supplied. `firstOrCreate` scopes the find, not the create.
- **Cursor / keyset pagination.** `WHERE id > :cursor` without the tenant predicate
  walks into the next tenant's rows once the caller's run out, and a cursor minted for
  A replayed under B reveals whether A's ids exist. The tenant goes in the keyset
  `WHERE`; the cursor is opaque and bound to the tenant (signed, or encoded and compared).
- **Drizzle has no global scope.** Every query carries the filter by hand or the
  database enforces it (RLS below); a "scoped table" helper is convention, not a gate.

## Where the tenant id comes from

The tenant is a property of the authenticated principal — session, token claim,
verified membership — never of the request alone. `X-Tenant-Id`, `?tenant_id=`, a
body field, a subdomain or a route segment (`/tenants/{tenant}/...`) is a *claim*;
accept it only after checking the principal belongs to that tenant, then scope the
rest of the request to it. Nested params (`/tenants/{t}/projects/{p}`) need both
checks — membership in `t` and `p` belonging to `t` — which Laravel `scopeBindings()`
does and default route-model binding does not.

## The IDOR-at-scale shape, and the test

One missing predicate is every row of one table for every tenant. The test is
mechanical and belongs in the suite, not in a review comment:

1. Two tenants, one principal each, one resource each.
2. As A, hit every verb on B's id — GET, PUT/PATCH, DELETE — and every list/search
   endpoint with B's ids or filters (`?ids[]=`, `?owner=`, autocomplete).
3. Expect **404**, not 403, wherever existence is itself confidential (invoices,
   patients, documents — most things). A 403 confirms the id is real; so does a
   different error body, a slower response, or a validation rule (`unique:users,email`
   over the whole table) that says "already taken" for another tenant's value.
4. Repeat through every entry point that skips HTTP: jobs, commands, websockets, exports.

Sequential ids make step 2 free; UUIDs raise the guessing cost and fix nothing
about authorization — a leaked UUID is still a leak.

## Cross-tenant joins and reports

A join carries the tenant on both sides — `ON o.customer_id = c.id AND o.tenant_id =
c.tenant_id` — or a foreign key pointing at another tenant's row is joinable. The
schema-level fix is a composite key: `(tenant_id, id)` as the referenced unique and a
composite FK, so a cross-tenant reference cannot be inserted at all. Reports are
where scopes are dropped on purpose: operator routes only, never a tenant-facing one
built from a query that starts on the global table.

## Contexts that lose the tenant

The tenant lives in the request; these run without one:

- **Queued jobs.** The worker has no session. Carry the tenant id in the payload and
  re-establish the context there (Laravel: job middleware initialising tenancy from
  the serialized id; Celery/RQ: an explicit `tenant_id` argument — a contextvar
  captured at enqueue time is gone in the worker process).
- **Scheduled commands.** Cron runs for no tenant; iterate tenants explicitly and set
  the context per iteration. A command that "just queries" queries the global table.
- **Websockets.** Authorize the channel join with the tenant in the channel name
  (`tenant.{id}.orders`) checked against the principal's tenant; a room named by
  resource id alone is joinable by anyone who guesses it. A connection outlives
  membership — a revoked user keeps receiving until the socket is closed.
- **CLI, seeders, REPL.** No context, full table; services reused from request code
  inherit the leak.

## Caches, keyed without the tenant

`cache()->remember('settings', ...)` serves A's settings to B. The tenant belongs in
every key (`"{$tenantId}:settings"`), in HTTP cache `Vary` (a CDN caches by URL and
`/dashboard` is the same URL for everyone), and in memoized permission checks. One
Redis behind database-per-tenant shares the namespace unless the prefix follows the
connection.

## File storage

The path derives from the resolved tenant (`tenants/{id}/uploads/...`), never from a
client-supplied path or filename — `../` or an absolute path moves the write into
another tenant's prefix. Signed URLs are minted after the ownership check and expire;
a bucket listing is a cross-tenant listing unless IAM enforces the prefix
(`s3:prefix` conditions), not the application's habit.

## Database-per-tenant, row-level, and RLS

- **Database-per-tenant** isolates by connection; the failure is forgetting to
  switch — jobs, commands and the REPL run on the default connection, usually the
  landlord DB or the last tenant touched.
- **Row-level** (a `tenant_id` column everywhere) is where every rule above applies.
  Lead composite indexes with `tenant_id` so scoped queries are also the fast ones.
- **Postgres RLS** makes the database the gate:
  `ALTER TABLE orders ENABLE ROW LEVEL SECURITY;` then
  `CREATE POLICY tenant_isolation ON orders USING (tenant_id = current_setting('app.tenant')::uuid) WITH CHECK (tenant_id = current_setting('app.tenant')::uuid);`
  and `SET LOCAL app.tenant = '<uuid>'` at the top of each transaction. Three traps:
  - **The owner trap.** Table owners and superusers bypass RLS. The app usually
    connects as the role that ran the migrations — the owner — so the policies apply
    to nobody. Connect as a separate non-owner role without `BYPASSRLS`, or
    `ALTER TABLE orders FORCE ROW LEVEL SECURITY`. Verify: select as the app role
    with no setting — zero rows.
  - **`SET` vs `SET LOCAL`.** Under transaction pooling (PgBouncer) a plain `SET`
    outlives the transaction and rides the connection to the next tenant's request.
  - **`USING` is not `WITH CHECK`.** `USING` filters rows read, updated and deleted;
    only `WITH CHECK` constrains rows written — `USING` alone lets an insert land in
    another tenant.
  A missing setting must fail closed: `current_setting('app.tenant', true)` returns
  NULL and matches nothing — good; a `COALESCE(..., tenant_id)` "convenience" turns
  that into every row. Views run as their owner and skip RLS unless created
  `WITH (security_invoker = true)` (Postgres 15+).
