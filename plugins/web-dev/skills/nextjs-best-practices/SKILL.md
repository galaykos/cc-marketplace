---
name: nextjs-best-practices
description: Use when writing or reviewing Next.js App Router code — server vs client component boundaries, opt-in caching (fetch, revalidate, use cache), server actions, route handlers, streaming with Suspense, next/image and next/font, version leverage 14 through 16.
---

> Last verified: 2026-10-31 — https://nextjs.org/blog/next-16-4 — npm:next@16.4

## Read the installed version's docs first

Caching defaults, request APIs and `use cache` shifted across 14 → 15 → 16 **and within 16.x
minors**: pin advice to the `next` version in the lockfile and read that version's docs. On
16.2+ they ship in `node_modules/next/dist/docs/` (the nextjs.org/docs tree, whose default path
documents only the newest release); on 16.1 and earlier, `npx @next/codemod@canary agents-md`
downloads a matching copy to `.next-docs/`. On 16.3+, `next dev` writes a managed block
(`<!-- BEGIN:nextjs-agent-rules -->` … `END`) into `AGENTS.md`, plus a `CLAUDE.md` importing
it, when it detects a coding agent. Do not delete it from a diff — `next dev` re-adds it; commit
it and keep project rules outside the markers (`agentRules: false` opts out). Standing: recorded.

## Server Components by default — place client boundaries deliberately

Server-side fetching in Server Components needs no client cache library; a client
cache (TanStack Query/SWR) belongs only behind a `'use client'` boundary — data that
is interactive, user-specific, or refetching/mutating in the browser.

Everything under `app/` is a Server Component until a module says `'use client'`. The
directive marks a module-graph boundary, not a single file: everything a client module
imports becomes client code too. Push boundaries to the leaves (the button, the form),
and pass server-rendered content *through* client components as `children` instead of
importing it into them. Props crossing the boundary must be serializable — no functions
(except server actions), no class instances. Add `import 'server-only'` to modules that
touch secrets so a client import fails the build instead of leaking.

```tsx
// Bad: page-level 'use client' drags the whole subtree into the bundle
'use client';
export default function Page() { /* fetch moves to useEffect, SEO gone */ }
// Good: interactive leaf only; server content flows through as children
<ClientCarousel>{await ProductCards()}</ClientCarousel>
```

## Caching is opt-in — nothing is cached unless you ask (15+)

Since Next.js 15, `fetch` defaults to `no-store`, GET route handlers are uncached, and
the client router cache uses `staleTime: 0` for pages — the Next 14 cached-by-default
mental model is inverted. Read `next.config` first: `cacheComponents` picks the model.

`cacheComponents` off (15.x; 16 apps that never set it) — opt in per source, tag what you cache:

```ts
const res = await fetch(url, { next: { revalidate: 3600, tags: ['posts'] } });
export const revalidate = 3600;        // segment-level ISR
export const dynamic = 'force-static'; // whole segment static
```

`next.config` has `cacheComponents: true` (the `create-next-app` default from 16.4, announced as
the default in 17) → those two exports and `fetchCache` error, `dynamicParams` fails the build,
`runtime` is unsupported, `generateStaticParams` returning `[]` errors. Cache with `'use cache'` +
`cacheLife('hours')`/`cacheTag()`, in memory per instance unless `'use cache: remote'` or a cache
handler backs it. Per-export mapping: `references/next16.md` § Cache Components on.

Invalidate by tag, not by hope: on Next 16, `revalidateTag(tag, profile)` takes a
`cacheLife` profile (`'max'` for most content) for stale-while-revalidate; the
single-argument form is deprecated. In server actions, `updateTag(tag)` gives
read-your-writes (user sees their edit immediately) and `refresh()` re-fetches uncached
data only. Same-render `fetch` calls are deduplicated automatically; wrap non-fetch
loaders (ORM calls) in React's `cache()` to get the same per-request memoization.

`'use cache'` works only with `cacheComponents: true`. It caches a file, component, or async
function with compiler-generated keys, tuned via `cacheLife()`/`cacheTag()`, and completes the PPR
story (`experimental.ppr`/`dynamicIO` flags are gone). Runtime values are banned inside a cached
scope: read `cookies()`/`headers()` in an uncached parent and pass results in as arguments.

## Request APIs are async — await everything (sync access removed in 16)

`params`, `searchParams`, `cookies()`, `headers()`, and `draftMode()` are Promises.
Next 15 warned on sync access; Next 16 removed it. Reading `searchParams` or calling
`cookies()` also opts the route into dynamic rendering — keep such reads out of
segments you want static.

```tsx
export default async function Page({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
}
```

## Server actions are public HTTP endpoints

`'use server'` exports become POST endpoints callable by anyone with the action ID —
the hidden submit button is not an access control. Authenticate and authorize *inside*
every action, validate `formData`/arguments with a schema, and re-check invariants the
UI already "guaranteed". Use actions for mutations, not reads (they run sequentially).
After a mutation, expire what changed (`updateTag`/`revalidatePath`) or `redirect()`.
`redirect()` works by throwing — a wrapping `try/catch` swallows the navigation, so
call it after the try block or rethrow.

## Route handlers

`route.ts` exports HTTP verbs (`GET`, `POST`, …) and cannot share a segment with
`page.tsx`. GET is uncached by default on 15+ (metadata routes like `sitemap.ts` stay
static). Route handlers are for external consumers — webhooks, mobile clients. A Server
Component fetching your own route handler adds an HTTP hop to your own server; call the
shared data-access function directly instead.

## Live data: server-sent events, never a socket server in a handler

Push updates with server-sent events: a `GET` route handler returning a `ReadableStream`
as `text/event-stream`, read by an `EventSource` opened in a client effect and closed in
its cleanup. Never host a WebSocket server in a route handler — on serverless hosts the
connection closes on timeout or once the response is generated; use a managed realtime
service or a separate long-lived server. Streams get cut, so give each event an `id:`
(the browser resends `Last-Event-ID`) and refetch current state on every reconnect before
applying new events — anything sent while disconnected is otherwise lost. Standing: recorded.

## Maps, rich-text editors, charts: client-only, destroyed on unmount

They own their DOM: create the instance in an effect inside a `'use client'` component and
destroy it in the cleanup. `'use client'` still prerenders on the server, so a library that
reads `window` at import (Leaflet 1.9) needs `next/dynamic(..., { ssr: false })`, called from
a Client Component (it throws in a Server Component). Tiptap wants `immediatelyRender: false`;
MapLibre 6 has no default export. The cross-stack rules (Livewire, Inertia) and the editor-HTML
XSS rule: `references/client-widgets.md`. Standing: recorded.

## Streaming: loading.tsx and Suspense

`loading.tsx` wraps its segment in an automatic Suspense boundary; explicit
`<Suspense>` lets the static shell flush while slow subtrees stream in. Await data in
the component that needs it, not in a shared layout — a layout-level await blocks every
child. Start independent fetches before awaiting (`Promise.all`, or pass the promise
down and unwrap with React's `use`) to avoid request waterfalls.

## Metadata API

Export `metadata` (static) or `generateMetadata` (dynamic) from pages/layouts — server
side only. A `fetch` shared between `generateMetadata` and the page is deduplicated, so
duplicating the query is free of double cost only if the calls match. Prefer file
conventions — `opengraph-image.tsx`, `icon.tsx`, `sitemap.ts`, `robots.ts` — over
hand-rolled `<head>` tags. On 16, metadata image routes receive async `params`.

## Image and font optimization

`next/image` needs `width`/`height` or `fill` (CLS protection); `fill` without `sizes`
downloads desktop-size images on phones; the LCP hero loads eagerly — `priority` on 14/15,
but 16 deprecates `priority` for `preload` and its docs prefer `loading="eager"` or
`fetchPriority="high"` (standing: recorded). Next 16 tightened the image defaults (`qualities`,
`domains` → `remotePatterns`, `localPatterns`): `references/next16.md`. `next/font` self-hosts
fonts with zero layout shift — use it instead of `<link>` to Google Fonts, and subset.

## proxy.ts (formerly middleware.ts)

Next 16 renames `middleware.ts` to `proxy.ts` (exported function `proxy`), running on
the Node.js runtime; the old filename is deprecated. Keep it thin — redirects, rewrites,
and *optimistic* auth checks that read the session cookie only, with no database call (it
runs on every route, prefetches included). It is never the only line of defence: a matcher
change or a Server Function moved to another route silently drops its coverage, so verify
auth again in the data access layer, every server action and every route handler.
Standing: recorded — the docs' own rule; no script here reads a `proxy.ts`.

## Per-version leverage (advise at or below the floor)

Advising above the installed version is a finding; confirm boundaries against the docs.

- **14** — server actions stable; metadata API mature; `fetch` and GET route handlers
  are cached BY DEFAULT — the opposite of 15+; sync `params`/`cookies()` access normal.
- **15** — caching flipped to opt-in (fetch `no-store`, GET handlers and client router
  cache uncached); async request APIs introduced with sync access deprecated; React 19
  pairing; Turbopack dev stable; `after()` for post-response work.
- **16** (current stable line; 16.4.3 as of 2026-10-31) — Turbopack is the default bundler
  (webpack via `--webpack`); sync request-API access removed; `proxy.ts` replaces
  `middleware.ts`; Cache Components/`'use cache'` behind `cacheComponents`, which
  `create-next-app` turns on from 16.4; `revalidateTag(tag, profile)` + `updateTag()`/`refresh()`;
  React Compiler support stable (off by default); parallel route slots require explicit
  `default.js`; AMP and `next lint` removed; needs React 19.2+/Node 20.9+. 16.3 adds `catchError`,
  `next/root-params`, `partialPrefetching` and `export const instant`. Per-change operational
  detail (what breaks, escape hatches, the 16.x minors): read `references/next16.md`.

## Scope by model tier

**All models** — every rule above: the version gates, the boundaries, the footguns. Facts
do not scale down with the model. **Compensation (worker-tier)** — the detect → pin →
verify order the `/code-review:review` fan-in runs (detect the stack from the lockfile,
pin the version, verify each rule), followed literally, every skill in scope applied
to every file in scope; a Fable-class session may compress it once the lockfile is read.
**Skip** — a diff touching no server/client boundary, no data fetch, no `app/` route and no `next.config.*` earns a one-line verdict; do not walk the rubric to prove it.

## Common mistakes

- `'use client'` on a page/layout, pulling the whole tree into the client bundle.
- Assuming `fetch` is cached (or, after upgrading from 14, that it still is).
- `export const revalidate`/`dynamic` in a `cacheComponents: true` app — an error there, not ISR.
- Reading `cookies()`/`headers()` inside a `'use cache'` scope instead of passing
  values in from an uncached parent.
- Skipping auth inside a server action because the UI hides the button.
- `try/catch` around `redirect()` in an action, swallowing the navigation throw.
- Awaiting all data in a layout, serializing what Suspense would stream in parallel.
- Server Components fetching the app's own route handlers over HTTP.
- `fill` images without `sizes`; an LCP hero loaded lazily, or given the deprecated `priority` on 16.
- Sync `params`/`searchParams` access left in after a 16 upgrade — it throws.
- Missing `default.js` in a parallel route slot — a build failure on 16.
- Proxy as the only auth check, or a database call inside it.
- A WebSocket server in a route handler; an event stream with no resync on reconnect.
- Deleting the `nextjs-agent-rules` block from `AGENTS.md` in a diff.
