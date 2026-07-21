---
name: nuxt-best-practices
description: Use when writing or reviewing Nuxt code — Nitro server routes and event-handler validation, hybrid rendering via routeRules, useFetch vs useAsyncData vs bare $fetch double-fetching, payload keys and dedup, Nuxt 4 shallow data refs, useState cross-request pollution, auto-imports discipline, runtimeConfig NUXT_ env overrides, useSeoMeta/useHead — pinned to the lockfile's nuxt version. Vue component rules live in vue3; raw Vite config in vite.
---

## Know the version before advising

- The locked `nuxt` entry (package-lock.json / yarn.lock / pnpm-lock.yaml / bun.lock)
  decides every default below — a `^3.17` constraint can resolve anywhere in 3.x; only
  the lock says whether the project runs Nuxt 3 or Nuxt 4 semantics.
- Nuxt 3 EOL: 2026-07-31; treat a Nuxt 3 lockfile as a migration flag —
  note it once, then advise within 3.x, never above it.
- Read `nuxt.config.ts` first: `compatibilityVersion`, `future`/`experimental` flags,
  and `routeRules` change which defaults apply regardless of the version number.
- Verify version-sensitive claims against https://nuxt.com for the locked minor, never
  from memory.

## Per-version leverage (advise at or below the floor)

- **Nuxt 3.x** (EOL 2026-07-31) — flat srcDir; deep-reactive data refs; stale data kept
  while refetching; `null` defaults for `data`/`error`. `compatibilityVersion: 4`
  (3.12+) opts into v4 behavior early.
- **Nuxt 4.0** (2025-07) — `app/` is the new srcDir (`server/`, `shared/`, `public/`,
  config stay at root); `useFetch`/`useAsyncData` data becomes `shallowRef` (opt out
  per call with `deep: true`); same-key calls share one `data`/`error`/`status`;
  refetch clears old data while pending; defaults are `undefined`; reactive keys
  refetch automatically.
- **Nuxt 4.1** (2025-09) — chunk stability via import maps (no cascading hash
  invalidation); opt-in Rolldown bundling; module dependency declarations.
- **Nuxt 4.2** (2025-10) — `useAsyncData` handlers receive an `AbortController` signal;
  Nitro integration split into `@nuxt/nitro-server`; opt-in Vite Environment API;
  experimental `extractAsyncDataHandlers` tree-shakes prerendered handlers.
- **Nuxt 4.3** (2026-01) — `#server` alias with import protection; route-rule layouts;
  Web-API naming (`status`/`statusText`) starts deprecating `statusCode`/
  `statusMessage` ahead of v5 / Nitro v3 / H3 v2.
- **Nuxt 4.4** (2026-03) — `createUseFetch`/`createUseAsyncData` factories; vue-router
  v5; typed layout props via `definePageMeta`; `payloadExtraction: 'client'`; `refresh`
  option on `useCookie`.

## Data fetching — the three tools

- `useFetch(url)` — the default for component data: fetches once during SSR, ships the
  result in the payload, hydrates without refetching. Sugar over
  `useAsyncData(url, () => $fetch(url))`.
- `useAsyncData(key, handler)` — same lifecycle for non-`$fetch` sources (SDK/CMS query
  layers, `Promise.all` of several calls).
- Bare `$fetch` in setup is the classic footgun: it runs on the server AND again on the
  client — double fetch, hydration drift, no dedup. Reserve `$fetch` for event handlers
  (submits, clicks) and for use inside `useAsyncData` handlers.

```js
const user = await $fetch('/api/user'); // Bad in setup: fetched on server, again on client
const { data: user } = await useFetch('/api/user'); // Good: once, hydrated from payload
```

## Keys, sharing, and payload discipline

- Keys dedupe: same-key calls share one `data`/`error`/`status`. Set explicit keys —
  auto-generation keys on file/line and breaks or collides when code moves.
- On Nuxt 4, same-key callers must agree on `deep`/`transform`/`pick`/`getCachedData`/
  `default`; only `server`/`lazy`/`immediate`/`dedupe`/`watch` may differ.
- Data refs are `shallowRef` on Nuxt 4 — replacing `data.value` is reactive, mutating a
  nested property is not; pass `deep: true` where in-place edits are the design.
- `pick`/`transform` shrink what enters the HTML payload, not the fetch itself —
  over-fetching still costs the server.
- `lazy: true` (or `useLazyFetch`) stops blocking navigation; `status`
  (`idle`/`pending`/`success`/`error`) must then drive the loading UI.
- Payload state serializes via devalue (Dates, Maps, Sets, refs survive); API-route
  responses are plain `JSON.stringify` — return plain data, not class instances.

## Hybrid rendering — routeRules

```ts
routeRules: {
  '/': { prerender: true },       // rendered at build time
  '/blog/**': { isr: 3600 },      // CDN cache, regenerated hourly (Netlify/Vercel)
  '/search': { swr: 60 },         // server-side cache, stale-while-revalidate
  '/admin/**': { ssr: false },    // client-only island
  '/old': { redirect: '/new' },
}
```

- `swr` caches on the server/proxy and revalidates in the background; `isr` pushes the
  cache to the CDN — CDN-level `isr` currently needs Netlify or Vercel.
- `ssr: false` renders in-browser only — SEO-relevant pages don't belong behind it.
- Hybrid rendering is unavailable under `nuxt generate`, and a fully prerendered build
  ships no server — `server/api` routes vanish in production; use `nuxt build`.

## Nitro server routes

- `server/api/*` and `server/routes/*` export `defineEventHandler`; the filename maps
  to the path, `[id].ts` to a param (`getRouterParam`), a `.post.ts` suffix to the method.
- Read input with `getQuery` and `readBody`/`readValidatedBody` — a validated body is
  the API boundary; never trust the raw shape.
- `defineCachedEventHandler`/`cachedFunction` cache at the Nitro layer (`maxAge`, keyed) —
  cheaper than component-layer caching and shared across renders.
- Nitro deploys by preset (node-server, vercel, netlify, cloudflare, …) — give
  platform-specific advice only after reading the configured preset.
- `runtimeConfig`: top-level keys stay server-only, `public.*` reaches the client. At
  runtime only `NUXT_`-prefixed uppercase env vars override (`NUXT_API_SECRET` →
  `apiSecret`, `NUXT_PUBLIC_API_BASE` → `public.apiBase`), and the key must already
  exist in config; the built server does not read `.env` files.

## State — useState, not module-scope refs

- A `ref` created at module scope lives for the whole server process — state shared
  across requests, one user's data leaking into another's response, plus memory leaks.
  Highest-severity Nuxt state bug.
- `useState(key, init)` is the SSR-safe ref: server value ships in the payload, restores
  on hydration, and is shared by every component using the key. Values must survive
  serialization — no classes, functions, or symbols.
- Wrap keys in composables for typing; `clearNuxtState` resets; `callOnce` handles
  one-time init in app.vue. Pinia (`@pinia/nuxt`) for real stores — the vue3 skill's
  `storeToRefs` rules apply there.

```js
export const user = ref(null); // Bad: module scope — shared across every SSR request
export const useUser = () => useState('user', () => null); // Good: per-request, hydrated
```

## Auto-imports discipline

- Nuxt auto-imports its own composables plus `components/`, `composables/`, and
  `utils/`; Nitro separately auto-imports `server/utils/`. App and server are distinct
  contexts — an app composable is not available in `server/api`, and vice versa.
- `#shared` (the `shared/` dir) is importable from both sides; `#server` (4.3+) guards
  server-internal imports. An import-protection build error is a boundary violation to
  fix, not to suppress.
- Explicit `import { useFetch } from '#imports'` stays available and keeps grep honest;
  disable auto-imports (`imports.autoImport: false`) only as a team decision.

## Common footguns

- Bare `$fetch` in setup — double fetch and hydration drift.
- Module-scope `ref` for shared state — cross-request pollution.
- Mutating nested properties of a Nuxt 4 data ref and expecting a re-render
  (`shallowRef` default).
- `ssr: false` route rules on pages that needed SEO; `nuxt generate` on an app with
  server routes.
- Env vars that silently don't override `runtimeConfig` — wrong `NUXT_` prefix, casing,
  or a key absent from config.
- `window`/`document` access during SSR without `import.meta.client` or `<ClientOnly>`.
- Meta tags via raw `useHead` with user content (use `useHeadSafe`), or `name` vs
  `property` OG mistakes (use `useSeoMeta`'s typed flat keys); `titleTemplate` as a
  function belongs in app.vue, not nuxt.config; `app.head` is static, never reactive.
- Advising Nuxt 4 semantics (shallow data, `undefined` defaults, `app/` dir) against a
  Nuxt 3 lockfile — or vice versa.

## Verify Against Current Docs

Data-fetching semantics, directory layout, and rendering defaults moved between Nuxt 3
and 4, and minors keep shipping (4.4 fetch factories, 4.3 `#server`, v5/Nitro v3 ahead).
Confirm version-sensitive claims against https://nuxt.com for the exact locked version,
and read `nuxt.config.ts` first so you don't flag what the config already handles.
