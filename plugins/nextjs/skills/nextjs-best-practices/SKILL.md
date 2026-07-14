---
name: nextjs-best-practices
description: Use when writing or reviewing Next.js App Router code — server vs client component boundaries, opt-in caching (fetch, revalidate, use cache), server actions, route handlers, streaming with Suspense, metadata API, next/image and next/font, async request APIs, version leverage 14 through 16.
---

## Server Components by default — place client boundaries deliberately

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
mental model is inverted. Opt in explicitly per data source, and tag what you cache:

```ts
const res = await fetch(url, { next: { revalidate: 3600, tags: ['posts'] } });
export const revalidate = 3600;        // segment-level ISR
export const dynamic = 'force-static'; // whole segment static
```

Invalidate by tag, not by hope: on Next 16, `revalidateTag(tag, profile)` takes a
`cacheLife` profile (`'max'` for most content) for stale-while-revalidate; the
single-argument form is deprecated. In server actions, `updateTag(tag)` gives
read-your-writes (user sees their edit immediately) and `refresh()` re-fetches uncached
data only. Same-render `fetch` calls are deduplicated automatically; wrap non-fetch
loaders (ORM calls) in React's `cache()` to get the same per-request memoization.

`'use cache'` (Cache Components) is opt-in behind `cacheComponents: true` in
`next.config.ts` — still not the default as of 16.2. It caches a file, component, or
async function with compiler-generated keys, tuned via `cacheLife()`/`cacheTag()`, and
completes the PPR story (`experimental.ppr`/`dynamicIO` flags are gone). Runtime values
are banned inside a cached scope: read `cookies()`/`headers()` in an uncached parent
and pass results in as arguments.

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
downloads desktop-size images on phones; the LCP hero gets `priority`. Next 16
tightened defaults: `qualities` is `[75]`, `minimumCacheTTL` is 4 hours, remote sources
use `images.remotePatterns` (`domains` is deprecated), local-IP optimization is blocked,
and local `src` with query strings needs `images.localPatterns`. `next/font` self-hosts
fonts with zero layout shift — use it instead of `<link>` to Google Fonts, and subset.

## proxy.ts (formerly middleware.ts)

Next 16 renames `middleware.ts` to `proxy.ts` (exported function `proxy`), running on
the Node.js runtime; the old filename is deprecated. Keep it thin — redirects,
rewrites, auth *checks* — not data fetching or heavy work on every request.

## Per-version leverage (advise at or below the floor)

Advising above the installed version is a finding; confirm boundaries against the docs.

- **14** — server actions stable; metadata API mature; `fetch` and GET route handlers
  are cached BY DEFAULT — the opposite of 15+; sync `params`/`cookies()` access normal.
- **15** — caching flipped to opt-in (fetch `no-store`, GET handlers and client router
  cache uncached); async request APIs introduced with sync access deprecated; React 19
  pairing; Turbopack dev stable; `after()` for post-response work.
- **16** (current stable line; 16.2 as of 2026-07) — Turbopack is the default bundler
  (webpack via `--webpack`); sync request-API access removed; `proxy.ts` replaces
  `middleware.ts`; Cache Components/`'use cache'` available behind `cacheComponents`;
  `revalidateTag(tag, profile)` + `updateTag()`/`refresh()`; React Compiler support
  stable (off by default); parallel route slots require explicit `default.js`; AMP and
  `next lint` removed; needs React 19.2+/Node 20.9+. 16.1: Turbopack FS caching stable
  in dev. 16.2: Build Adapters stable; root params usable inside `'use cache'`.

## Common mistakes

- `'use client'` on a page/layout, pulling the whole tree into the client bundle.
- Assuming `fetch` is cached (or, after upgrading from 14, that it still is).
- Reading `cookies()`/`headers()` inside a `'use cache'` scope instead of passing
  values in from an uncached parent.
- Skipping auth inside a server action because the UI hides the button.
- `try/catch` around `redirect()` in an action, swallowing the navigation throw.
- Awaiting all data in a layout, serializing what Suspense would stream in parallel.
- Server Components fetching the app's own route handlers over HTTP.
- `fill` images without `sizes`; LCP hero without `priority`.
- Sync `params`/`searchParams` access left in after a 16 upgrade — it throws.
- Missing `default.js` in a parallel route slot — a build failure on 16.

## Verify Against Current Docs

Caching defaults, request-API asynchrony, and the `use cache`/`cacheComponents` status
have all shifted across 14 → 15 → 16 and within 16.x minors. Before relying on memory
for version-sensitive behavior, check https://nextjs.org/docs and pin advice to the
`next` version actually installed in `package.json`/the lockfile.
