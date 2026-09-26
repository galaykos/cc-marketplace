---
name: inertia-best-practices
description: Use when writing or reviewing Inertia.js code in a Laravel app with the Vue, React, or Svelte adapter — prop hygiene, partial reloads, lazy vs deferred props, useForm, shared data, SSR — v1/v2/v3 and adapter advice pinned to the installed packages.
---

> Last verified: 2026-09-26 — https://inertiajs.com/docs/v3/getting-started/upgrade-guide — npm:@inertiajs/core@3.7

## Know the version before advising

Inertia is two packages that must agree — check both before recommending anything:

- `composer.lock` → `inertiajs/inertia-laravel` major governs server APIs: `Inertia::defer`,
  `Inertia::merge`, `Inertia::optional` need v2+ (v3 keeps them); `Inertia::lazy` is v1/v2 only.
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

- v1/v2: `Inertia::lazy(fn () => ...)` — omitted from first load, fetched explicitly via `only`.
  v2 added `Inertia::optional` with the same semantics and v3 REMOVED `lazy`; `defer` below is
  a separate, additional API, not the rename. Conflating the two is the common error here.
- v2: `Inertia::defer(fn () => ...)` — page renders instantly, the prop arrives in an automatic
  follow-up request; render loading state with `<Deferred data="stats">`. Pass a group name to
  batch several deferred props into one request.
- Filter/sort/paginate visits need `preserveState: true` (keep form inputs) and
  `preserveScroll: true` (no jump to top) — the defaults preserve neither.

## v2 leverage (only when installed)

- **Polling**: `usePoll(5000)` replaces `setInterval` + `router.reload` — it throttles
  background tabs by 90% and stops on unmount; hand-rolled intervals do neither. Server push
  (Echo + Reverb) instead, or reconciling pushed events with props: `references/realtime.md`.
- **Prefetch**: `<Link prefetch>` fetches on hover; `prefetch="mount"` for near-certain next pages.
- **Merge props**: `Inertia::merge(fn () => $page->items)` appends on reload instead of
  replacing — the infinite-scroll primitive; reset with `router.reload({ reset: ['items'] })`.

## v3 leverage and breaks (only when installed)

v3 (stable March 2026; floors: PHP 8.2+, Laravel 11+, React 19 / Svelte 5 adapters) keeps the
v2 server API except `Inertia::lazy`. The `@inertiajs/vite` plugin replaces `createInertiaApp`
resolve/setup boilerplate and can serve SSR through the dev server with no separate Node process
— once SSR is on, which it is not by default (see below). Axios is gone (built-in XHR client);
ESM-only. `useHttp` is `useForm` for non-visit requests; `optimistic()` reverts.

**The v2 → v3 boundary** — on a 3.x lockfile the left column breaks; on 1.x/2.x it is correct, so read the lockfile before "fixing" it. Standing: **agent-graded** in a review that loads this skill; no script compares a diff to the lockfile.

| v1/v2 | v3 |
|---|---|
| `<title inertia>` in `app.blade.php` | `<title data-inertia>` |
| `router.on('invalid')` / `router.on('exception')` | `'httpException'` / `'networkError'` |
| `router.cancel()` | `router.cancelAll()` — now also cancels async and prefetch; `cancelAll({ async: false, prefetch: false })` keeps the v2 scope |
| `Inertia::lazy(fn () => ...)` | `Inertia::optional(...)`, or `Inertia::defer(...)` to fetch it right after render |
| React `Page.layout = ArrowComponent` | `Page.layout = [ArrowComponent]`; arrays nest (`[Site, Nested]`) and carry props (`[Layout, { title: 'Dashboard' }]`). A render function `(page) => <Layout>{page}</Layout>` still works |
| axios interceptors | `http.onRequest` / `onResponse` / `onError` from the adapter package, or `http: axiosAdapter(instance)` in `createInertiaApp` |
| `config/inertia.php` `testing.page_paths` | `pages.paths` (the `testing` block moved under `pages`) |

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
- Upload UI binds `form.progress?.percentage` (v3 clears it in `onFinish`, not on response). Large files go straight to storage on a presigned URL
  (`Storage::temporaryUploadUrl()`, s3/local drivers), so `post_max_size` and a PHP worker never see the bytes; the form submits only the stored key, validated server-side as user input. Standing: **recorded**.

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

## Laravel starter kits (`laravel new`, Laravel 12+)

The React, Vue and Svelte kits are Inertia apps (Inertia 3 today; Laravel 12-era kits shipped Inertia 2 — the lockfile decides) whose shape Breeze-trained memory gets wrong. Standing: **recorded** — no script inspects the app's layout.

- Pages: lowercase `resources/js/pages/`, rendered as `Inertia::render('dashboard')`. UI: shadcn/ui (React), shadcn-vue or shadcn-svelte — owned code the shadcn CLI copies into `resources/js/components/ui/`, not a dependency.
- URLs: Wayfinder's generated imports (`@/routes/...`, `@/actions/App/Http/Controllers/...`), not Ziggy's `route()`. Disabling a Fortify feature means deleting its route imports too, or the build fails.
- Auth: Fortify — routes follow `config/fortify.php` features, custom logic lives in `app/Actions/Fortify/`; there are no auth controllers to edit. Teams are a kit option (`/{current_team}/...` URLs), not Jetstream.
- Breeze and Jetstream "will no longer receive additional updates" (Laravel 12 release notes): keep existing installs working; never scaffold either into a new app.

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
  React, `*.svelte` on Svelte; `./pages/` in starter kits — match the directory's real case)
  yields one chunk per page; `{ eager: true }` bundles every page into the entry — first-load
  bloat on anything sizable. On v3 the Vite plugin owns this.
- **SSR is opt-in and fails silently.** `ssr.enabled = true` pointing at no reachable SSR server
  does NOT error — Inertia falls back to client rendering, so the browser looks perfect while
  View Source is an empty `#app`. Enabling it takes ALL of: an SSR entry file, an `--ssr` build
  target (v1/v2 `ssr.js`; v3 the Vite plugin's SSR option), that bundle deployed, and the SSR
  process running. Miss one and you shipped CSR while believing the opposite.
- v3 adds two first-party checks — use them beside the curl proof below, not instead of it: `ssr.throw_on_error` in
  `config/inertia.php` (dev/CI) turns the silent fallback into an exception; `php artisan inertia:check-ssr` after deploy
  confirms the SSR server answers. The v3 SSR server needs Node 22+.
- Verify, never assume: `curl -s <url> | grep -ci "<a word from the headline>"` must be non-zero.
  That one command separates a page search engines and AI crawlers can read from one they see
  blank — and no browser check, screenshot or passing test suite can tell you which you built.
- SSR pays off on SEO- and share-facing pages (marketing, listings, profiles); a login-walled
  dashboard can skip it. Everywhere keep `window`/`document` out of setup/render — gate browser
  APIs behind `onMounted` (Vue) or `useEffect` (React), which never run during the server render.

## Scope by model tier

**All models** — every rule above: the version gates, the prop contract, the footguns.
**Compensation (worker-tier)** — the detect → pin → verify order the `/code-review:review`
fan-in runs (detect the adapter from the lockfiles, pin the version, verify each rule),
followed literally; a Fable-class session may compress it once the lockfiles are read. **Skip** — a diff touching no page component, no controller returning `Inertia::render`,
no shared-data middleware and no `useForm` earns a one-line verdict.

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

v1 → v2: `optional` beside `lazy`, deferred props, `usePoll`, prefetch, merge props. v2 → v3
(3.7 current at the stamp; 2.3.x still ships under npm's `legacy` tag): the boundary table above,
axios removed, ESM-only, entry/SSR wiring in `@inertiajs/vite`.

Pin advice to the lockfiles and check https://inertiajs.com before asserting any
version-sensitive fact — the stamp above records what the author checked, not what
your project has installed.
