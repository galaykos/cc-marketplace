---
name: inertia-best-practices
description: Use when writing or reviewing Inertia.js code in a Laravel app with the Vue, React, or Svelte adapter — prop hygiene, partial reloads, lazy vs deferred props, useForm, shared data, SSR — v1/v2/v3 and adapter advice pinned to the installed packages.
---

> Last verified: 2026-08-12 — https://github.com/inertiajs/inertia/releases

## Know the version before advising

Inertia is two packages that must agree — check both before recommending anything:

- `composer.lock` → `inertiajs/inertia-laravel` major governs server APIs: `Inertia::defer`,
  `Inertia::merge`, `Inertia::optional` need v2+ (v3 keeps them); v1 has `Inertia::lazy`.
- `package.json`/lockfile → the adapter (`@inertiajs/vue3`, `@inertiajs/react`, or
  `@inertiajs/svelte`) governs client APIs — `<Deferred>`, `<WhenVisible>`, `usePoll`, link
  prefetching, merge props need v2+ — and pins which idiom advice must use: the core API
  (useForm, Link, router, usePage) is the same across adapters, the framework glue is not.
- Never suggest APIs above the installed major; flag older workarounds (manual polling,
  hand-rolled prefetch, axios interceptor plumbing) only when an installed major replaces them.

## Props are the page's contract

Controllers return exactly what the page renders. Every prop is serialized into the page source
(the `data-page` attribute) — anyone can View Source it.

```php
// Bad: whole model — hidden-ish accessors, appended attributes, and relations leak into HTML
return Inertia::render('Users/Show', ['user' => $user]);

// Good: the page's contract, nothing else
return Inertia::render('Users/Show', [
    'user' => ['id' => $user->id, 'name' => $user->name, 'avatar' => $user->avatar_url],
]);
```

- Shape with API Resources or explicit arrays; `$request->all()` as a prop injects arbitrary
  client input into page state — never.
- Select only needed columns — shaping after `Model::all()` already paid the query cost.

## Partial reloads: don't refetch what didn't change

`router.reload({ only: ['results'] })` re-runs only the listed props — but a prop can only be
skipped if it is wrapped in a closure; a bare value is computed before Inertia can exclude it.

```php
return Inertia::render('Dashboard', [
    'filters' => $filters,                          // cheap, always sent
    'stats'   => fn () => $this->expensiveStats(),  // closure: skipped unless requested
]);
```

- v1: `Inertia::lazy(fn () => ...)` — omitted from first load, fetched explicitly via `only`.
- v2: `Inertia::defer(fn () => ...)` — page renders instantly, the prop arrives in an automatic
  follow-up request; render loading state with `<Deferred data="stats">`. Pass a group name to
  batch several deferred props into one request.
- Filter/sort/paginate visits need `preserveState: true` (keep form inputs) and
  `preserveScroll: true` (no jump to top) — the defaults preserve neither.

## v2 leverage (only when installed)

- **Polling**: `usePoll(5000)` replaces `setInterval` + `router.reload` — it throttles in
  background tabs and cleans up on unmount; hand-rolled intervals do neither.
- **Prefetch**: `<Link prefetch>` fetches on hover; `prefetch="mount"` for near-certain next pages.
- **Merge props**: `Inertia::merge(fn () => $page->items)` appends on reload instead of
  replacing — the infinite-scroll primitive; reset with `router.reload({ reset: ['items'] })`.

## v3 leverage (only when installed)

v3 (stable March 2026; floors: PHP 8.2+, Laravel 11+, React 19 / Svelte 5 adapters) keeps the
whole v2 server API. The `@inertiajs/vite` plugin replaces `createInertiaApp` resolve/setup
boilerplate and can serve SSR through the dev server with no separate Node process — once SSR
is on, which it is not by default (see below). Axios is gone (built-in XHR client; migrate
interceptors); ESM-only. `useHttp` is `useForm` for non-visit requests; `optimistic()` reverts.

## Forms: useForm is the default

`useForm` owns the whole lifecycle — data, errors, processing, recentlySuccessful. Server-side
validation failures flow back into `form.errors` automatically: there is no error plumbing to
write, no catch block, no error prop to define.

```js
const form = useForm({ name: '', avatar: null });
form.post('/users', { preserveScroll: true }); // errors + processing handled for you
```

- Validate in a FormRequest; client-side checks are UX sugar, not the gate.
- `form.transform((data) => ({ ...data, tags: data.tags.split(',') }))` shapes at submit time.
- Files: a `File` in form data switches the request to `FormData` automatically; use
  `forceFormData: true` when nesting hides it. Uploads cannot ride PUT — use `form.post` with
  `_method: 'put'` spoofing.
- Disable submit on `form.processing`; show success via `form.recentlySuccessful`.

## Shared data: small, lazy, universal

`HandleInertiaRequests::share()` ships with EVERY response — each byte there is a tax on every
page. Share only what the layout truly needs: auth identity, flash, permission flags.

```php
public function share(Request $request): array
{
    return [
        ...parent::share($request),
        'auth'  => ['user' => $request->user()?->only('id', 'name', 'avatar_url')],
        'flash' => fn () => ['message' => $request->session()->get('message')],
    ];
}
```

Closures defer evaluation and let partial reloads skip them. Flash must be a closure — evaluated
eagerly it is consumed on the wrong request and the redirect that needed it renders nothing.

## Navigation and redirects

- `<Link>` for every internal navigation. A raw `<a>` to an Inertia route triggers a full page
  load — client state gone, bundle re-parsed. That is a bug, not a style nit.
- External or OAuth redirects: `Inertia::location($url)` — returning a normal redirect to an
  external URL from an XHR visit dies silently on CORS.
- Redirects after PUT/PATCH/DELETE must be 303 so the browser follows with GET, not the original
  verb — `inertia-laravel` middleware converts these, so keep it current and don't bypass it.
- After mutations: `redirect()->back()->with('message', ...)` — never return JSON from an
  Inertia controller; flash-through-shared-props is the response channel.

## Code splitting and SSR

- v1/v2: `resolvePageComponent(name, import.meta.glob('./Pages/**/*.vue'))` (`*.tsx`/`*.jsx` on
  React, `*.svelte` on Svelte) yields one chunk per page; `{ eager: true }` bundles every page
  into the entry — first-load bloat on anything sizable. On v3 the Vite plugin owns this.
- **SSR is opt-in and fails silently.** `ssr.enabled = true` pointing at no reachable SSR server
  does NOT error — Inertia falls back to client rendering, so the browser looks perfect while
  View Source is an empty `#app`. Enabling it takes ALL of: an SSR entry file, an `--ssr` build
  target (v1/v2 `ssr.js`; v3 the Vite plugin's SSR option), that bundle deployed, and the SSR
  process running. Miss one and you shipped CSR while believing the opposite.
- Verify, never assume: `curl -s <url> | grep -ci "<a word from the headline>"` must be non-zero.
  That one command separates a page search engines and AI crawlers can read from one they see
  blank — and no browser check, screenshot or passing test suite can tell you which you built.
- SSR pays off on SEO- and share-facing pages (marketing, listings, profiles); a login-walled
  dashboard can skip it. Everywhere keep `window`/`document` out of setup/render — gate browser
  APIs behind `onMounted` (Vue) or `useEffect` (React), which never run during the server render.

## Anti-patterns

- Fetching page data with axios/fetch next to Inertia props — two data channels, two auth paths,
  no partial-reload story. Props are the data layer; async endpoints are for true widgets only.
- Mirroring `auth.user` or permissions into a Pinia/Zustand/Redux store — shared props already
  are the store, refreshed per navigation; the copy goes stale at the first server-side change.
- Asserting a page is server-rendered because SSR is configured, without ever reading the
  response body — configured and rendering are different states, and only one is checkable.
- Expensive props computed unconditionally instead of behind closures/defer, making every
  partial reload pay full price.

## Major-version deltas

v1 → v2: `lazy` → `optional`, deferred props, `usePoll`, prefetch, merge props. v3 (v3.6
current; v2.x still maintained): axios removed, ESM-only, entry/SSR wiring in `@inertiajs/vite`.
