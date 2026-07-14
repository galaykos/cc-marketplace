---
name: node-backend-best-practices
description: Use when writing or reviewing server-side Node.js code in Express 5, NestJS 11, or Fastify 5 — async error propagation, validation at the boundary (zod, class-validator, JSON Schema), middleware vs DI vs plugin-encapsulation architecture, streaming and backpressure, graceful shutdown, config/env discipline, and per-framework footguns. Language-level rules live in the javascript/typescript plugins.
---

## The three composition models — work with the grain

- Express is a linear middleware pipeline: the order of `app.use` IS the
  architecture. Auth before routes, body parsing before validation, the 4-arity
  error handler registered last. There is no module system — impose one (a router
  per domain, services as plain functions behind it) or the app flattens into one
  file.
- NestJS is DI-first: providers own logic, controllers stay thin (decode request,
  call service, shape response). Use guards/pipes/interceptors/filters in their
  lanes instead of Express-style middleware bolted onto Nest.
- Fastify composes via encapsulated plugins: a decorator, hook, or route
  registered inside a plugin exists only in that plugin's subtree. Share
  deliberately with `fastify-plugin`; in Fastify, accidental global state is the
  smell, not the default.
- Pick per project, not per file: raw Express middleware inside Nest, or
  module-level singletons bypassing Fastify's plugin tree, forfeit the
  framework's guarantees.

## Async error handling

- Express 5 forwards rejected promises from handlers and middleware to the error
  middleware automatically — `asyncHandler` wrappers are dead weight; delete
  them. Express 4 still needs the wrapper (or `next(err)` in every catch).
- The error middleware signature is still `(err, req, res, next)` — four
  arguments, registered after all routes; with three arguments Express treats it
  as a regular middleware and errors skip it.
- NestJS: throw `HttpException` subclasses (or domain errors mapped by an
  exception filter); never touch `res` from a service. One global filter shapes
  the error contract; per-controller filters are the exception.
- Fastify: async handlers propagate thrown errors to `setErrorHandler` (scoped
  per plugin context). Return the payload, or `return reply.send(...)` — a
  floating un-returned `reply.send` in an async handler is a race.
- Split operational errors (expected, 4xx, message for the client) from
  programmer errors (5xx, log with stack, alert). Never leak stack traces or
  driver messages to clients.
- `unhandledRejection`/`uncaughtException` handlers log and crash; they are a
  flight recorder, not a recovery strategy.

## Validation at the boundary

- Validate every external input where it enters — body, params, query, headers —
  then pass typed, parsed data inward. Inner layers assume valid data.
- Express: zod per route (`schema.safeParse`) in a thin validation step; infer
  the TS type from the schema so validation and types cannot drift.
- NestJS: global `ValidationPipe` with `whitelist: true` and `transform: true`
  (mass-assignment defense); DTO classes carry class-validator decorators. Or
  wire zod through a custom pipe — one mechanism per app, not both.
- Fastify: JSON Schema on the route (`schema.body/params/querystring`) compiles
  to fast ajv validators, and `schema.response` doubles as an output allowlist:
  fast-json-stringify serializes ONLY declared fields — leak protection, and the
  footgun when a "missing" response field was simply never declared.
- Coerce and bound every numeric input (pagination limits, ids); reject unknown
  fields at the edge instead of sanitizing deep in services.

## Streaming and backpressure

- `stream.pipeline` (or `node:stream/promises`), never chained `.pipe()` —
  pipeline propagates errors and destroys every stream on failure; `.pipe()`
  leaks the source when the destination dies.
- Never buffer whole uploads or exports in memory: stream multipart to storage,
  stream DB/file responses out. Set body-size limits on every parser
  (`express.json({ limit })`, Fastify `bodyLimit`) — the default is your DoS
  budget.
- Respect backpressure: honor `write()` returning false and wait for `drain`
  (pipeline does this for you). Fastify: `return reply.send(stream)`; Express:
  `pipeline(stream, res, cb)`.

## Graceful shutdown

- On SIGTERM: flip readiness to failing, stop accepting (`server.close()` /
  `app.close()` / `fastify.close()`), let in-flight requests finish under a
  deadline, then close pools/queues/subscribers, then exit. Keep a kill-timer
  (`setTimeout(...).unref()`) that force-exits when the deadline passes.
- `server.close()` alone waits on keep-alive sockets — also call
  `server.closeIdleConnections()` or track sockets yourself.
- NestJS: `app.enableShutdownHooks()` (off by default) plus
  `onApplicationShutdown` in the providers that own connections. Fastify:
  `onClose` hooks in the plugin that opened the resource; `fastify.close()`
  runs them for you.
- Order matters: HTTP drained BEFORE the DB pool closes, or in-flight requests
  die on a closed pool.

## Config and environment discipline

- Validate the environment once at boot against a schema (zod/envalid; Nest
  `ConfigModule` with a `validate` function) and crash on failure — a missing
  secret must kill the deploy, not surface later as `undefined`.
- One typed config module; `process.env` reads scattered through business code
  are hidden untestable inputs. `.env` files are a dev convenience — production
  reads real environment/secret stores — and `NODE_ENV=production` is
  load-bearing for framework and library behavior.
- Never log the config object; secrets end up in log aggregators.

## Event-loop discipline

- No sync I/O or CPU-heavy sync crypto/zlib (`fs.*Sync`, `pbkdf2Sync`,
  `gzipSync`) on the request path — one call stalls every concurrent request.
- Offload real CPU work (hashing, images, big JSON transforms) to
  `worker_threads` (piscina); watch `monitorEventLoopDelay` in production.

## Per-framework footguns

- Express 5 routing (path-to-regexp 8): bare `*` throws at startup — wildcards
  are named (`/*splat`; `{/*splat}` to also match the root) and capture an
  ARRAY; `:param?` is gone — optionals use braces (`/:file{.:ext}`); regex
  characters in string paths are unsupported; unmatched params are omitted from
  `req.params`, not `''`. `npx @expressjs/codemod upgrade` automates most of it.
- Express: middleware registered after a route never runs for it —
  `app.use(cors())` after the router is the classic. Behind a proxy, set
  `trust proxy` precisely (hop count or subnet, never bare `true`) or rate
  limiting keys on the load balancer's IP.
- NestJS: one request-scoped provider makes every consumer up the chain
  per-request (latency and memory) — prefer durable providers or redesign.
  Circular imports need `forwardRef` on BOTH sides; better, extract the shared
  piece. Nest 11 defaults to the Express 5 adapter — `@Get('users/*')` breaks
  exactly like raw Express; use named wildcards.
- Fastify: decorators and hooks are encapsulated — "decorator not defined"
  usually means a missing `fastify-plugin` wrapper, not a load-order bug.
  `await register(...)` (or `after()`) before using a plugin's decorators.
  `reply.raw` bypasses hooks and serialization — last resort only.

## Version reality (verified 2026-07)

- Express 5.2 is stable and production-recommended; 4.x is in maintenance with
  EOL no sooner than 2026-10 — new code targets 5.
- NestJS 11 is current (requires Node >= 20); v12 (full ESM) is in prerelease,
  expected ~Q3 2026.
- Fastify 5.x is current (requires Node >= 20); 4.x support ended 2025-06.
- Node 24 is Active LTS, 22 is in maintenance; run production on an LTS line.
