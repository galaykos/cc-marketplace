---
name: vite-best-practices
description: Use when writing or reviewing Vite config or a Vite-built app — VITE_-prefix env security, optimizeDeps, code splitting (manualChunks), base for sub-path deploys, server.proxy, import.meta.glob, SSR externalization, plugin order, laravel-vite-plugin, @inertiajs/vite, Wayfinder and vite-plus — pinned to the lockfile's vite version.
---

> Last verified: 2026-08-02 — https://vite.dev/releases — npm:vite@8

## Know the version before advising

- The locked `vite` entry (package-lock.json / yarn.lock / pnpm-lock.yaml / bun.lock)
  is what actually builds the app — a `^5.0` constraint permits 5.0 through 5.x; only
  the lock says which minor is present and which defaults ship.
- The Node floor matters and CI must meet it: Vite 5 needs Node 18+; Vite 6
  supports 18 / 20 / 22; Vite 7 and 8 drop 18 and require 20.19+ or 22.12+. Green
  locally on Node 22 and red in CI on Node 18 is a floor mismatch, not a bug.
- Read `vite.config.{js,ts}` (and the mode-specific `.env` files it loads) before
  advising — half of this skill is config, and advice the config enforces is noise.
- Verify version-sensitive claims against https://vite.dev/ for the locked minor,
  never from memory — `build.target` defaults, `resolve.conditions`, the Environment
  API, the Node floor and Rolldown status all shift across majors. Recommend nothing above the locked version; flag no workaround
  the locked version has not yet killed.

## Per-version leverage (advise at or below the floor)

Advising above the locked version is a finding; confirm boundaries against the docs.

- **Vite 5** — Rollup 4 under the hood; `build.target` defaults to a modern-JS
  baseline (`'modules'`); the CJS Node API is deprecated, so `require('vite')` from a
  `.js` config warns — move the config to ESM.
- **Vite 6** — introduces the experimental Environment API (a refactor toward
  multiple build/dev environments); changes default `resolve.conditions` so
  `module`/`browser`/`node` are expected in the config value rather than injected
  internally — check the docs before relying on the old set.
- **Vite 7** — requires Node 20.19+ / 22.12+; default `build.target` becomes
  `'baseline-widely-available'` (a higher floor than 5/6's `'modules'`), so a bundle
  fine on 6 may need an explicit lower `target` for old browsers; on 7 Rolldown is
  still opt-in via `rolldown-vite`.
- **Vite 8** (2026-03) — Rolldown replaces Rollup + esbuild as the single bundler
  (Oxc transforms, Lightning CSS minify); `build.rollupOptions` is deprecated and
  auto-converted (renamed `build.rolldownOptions`); ESM-only package; Node floor
  unchanged from 7.

## Env security — client bundles are public

- Only `VITE_`-prefixed variables reach client code via `import.meta.env`;
  everything else is stripped from the browser bundle by design.
- Putting a secret in a `VITE_` var ships it to every browser — `VITE_STRIPE_SECRET`
  is in JS anyone can view-source. Only public / publishable values belong there.
- Never reference `process.env.SECRET` in client code — in the browser it is
  `undefined` (a bug) or, if a plugin injects it, a leak. Server secrets stay
  server-side, read via the runtime's own env, never the client bundle.
- `loadEnv(mode, cwd, prefix)` reads env files in config; mode files
  (`.env`, `.env.production`, `.env.local`) layer by mode with `.local` gitignored.
  `envPrefix` widens the exposed prefix — a deliberate risk; never set it to `''`.

## Dep pre-bundling / optimizeDeps

- On first dev start Vite pre-bundles deps into ESM (esbuild through 7, Rolldown on
  8) and caches them in `node_modules/.vite` — why the first cold start is slow and
  later ones fast. A dep found mid-session forces a re-bundle and full reload; that
  flash is the cost of a late-discovered import, not a bug.
- `optimizeDeps.include` forces a linked / deep-imported / dynamically-imported dep
  into pre-bundling when the crawl misses it; `exclude` keeps an already-ESM dep out.
  `--force` (or deleting `.vite`) rebuilds the cache after a dependency change.
- `include`/`exclude` hacks that paper over a broken dep export are debt — fix the
  export or pin the dep; link the upstream issue in a comment on any entry you keep.

## Code splitting

- Dynamic `import()` at route boundaries is the primary split — each route becomes
  its own chunk loaded on navigation, so the initial payload stays small.
- Shape vendor chunks with `build.rollupOptions.output.manualChunks` (Vite 8:
  `rolldownOptions`; `manualChunks` deprecated for Rolldown `codeSplitting`) — one
  giant vendor chunk means any dep change busts the whole cache; the function form
  groups by package. Do not over-split: split by change-frequency, not file count.
- `import.meta.glob('./routes/*.ts')` bulk-imports matches as lazy dynamic imports
  (a map of path → loader), each its own chunk; `{ eager: true }` inlines them into
  the main bundle when you need every module up front (accepting the bundle cost).

## base and dev server.proxy

- `base` must match the deploy sub-path or every hashed asset 404s. Root deploy
  keeps the default `'/'`; a project served at `/app/` needs `base: '/app/'`. Drive
  it from env (`base: process.env.VITE_BASE ?? '/'`) when one build deploys to
  different paths rather than hard-coding one environment.
- `server.proxy` forwards dev API calls to a backend so the browser talks to one
  origin and CORS never arises in dev
  (`server: { proxy: { '/api': 'http://localhost:3000' } }`). Dev-only — production
  has no Vite server and needs its own reverse proxy or CORS config; "works
  locally" proves nothing about production.

## define pitfalls

- `define` does raw text substitution at build time, not a variable binding —
  values must be `JSON.stringify`'d or the replacement injects a bare identifier:
  `define: { __API__: JSON.stringify(url) }`, never `{ __API__: url }`. Prefer
  `import.meta.env` for config; reserve `define` for global constants and flags,
  and note replacements land everywhere the token appears, including in strings.

## Asset handling

- Files in `public/` are copied verbatim with no hashing, referenced by
  root-absolute path (`/favicon.ico`) — for files needing a stable URL or that
  tooling can't import. Imported assets (`import logo from './logo.png'`) get
  content-hashed filenames and cache-bust for free; prefer importing.
- Query suffixes change resolution: `?url` yields the resolved URL, `?raw` the
  file's text, `?worker` a Web Worker constructor.

## build.target and browserslist

- `build.target` sets the syntax floor the bundler (esbuild ≤7, Oxc on 8) transpiles down to — match
  the browsers you support. Vite does not read `.browserslistrc`; if the project
  uses browserslist elsewhere, keep `build.target` aligned by hand or the two
  disagree about what ships.

## SSR

- SSR externalizes deps by default (loaded from `node_modules` at runtime, not
  bundled); `ssr.noExternal` forces a package to be bundled — needed for CSS-importing
  or ESM-only deps the Node runtime can't load. `ssrLoadModule` runs a module through
  Vite's SSR transform in dev; meta-frameworks wrap it, so touch it only in custom SSR.

## Library mode

- `build.lib` (entry + formats + name) builds a distributable, not an app. List
  every peer/runtime dependency in `rollupOptions.external` (Vite 8: `rolldownOptions`) so they are NOT bundled —
  bundling React into a component library ships two copies and breaks hooks;
  externalize and let the consumer provide them.

## Plugin order, apply, and HMR

- Plugins run in array order; `enforce: 'pre'` moves one ahead of core plugins,
  `enforce: 'post'` after — order decides which sees the untransformed source.
  `apply: 'build'` / `apply: 'serve'` scopes a plugin to one command, so a
  build-only transform doesn't slow the dev server (and vice versa).
- `import.meta.hot` exists only in dev; guard every use
  (`import.meta.hot?.accept(...)`) so it tree-shakes out of the production bundle
  instead of throwing. HMR boundaries are dev ergonomics, never a correctness
  mechanism the app depends on.

## Laravel and Inertia

Sources, read 2026-10-23: https://laravel.com/docs/13.x/vite, https://inertiajs.com/docs/v3, the npm registry. Re-read them for the locked versions.

- **One plugin major per Vite major.** `laravel-vite-plugin` 2.x peers `vite ^7`, 3.x `^8`; Vite 8 needs 3.0.0+. Read both lock
  entries first. Its source lives on the repo's `3.x` branch; `main` is stale at 0.8.1.
- **`laravel({ input, refresh })`.** `input` is required; an Inertia app works best with the JS entry alone and its CSS imported
  from JS. `refresh: true` full-reloads on saves under `resources/views`, `routes`, `lang`, `app/View/Components` and
  `app/Livewire`, and also when an AI tool writes its state files: add `server.watch.ignored: ['**/.claude/**', '**/.cursor/**']`.
- **Defaults it sets:** output `public/build`, `manifest.json`, `publicDir: false`, `assetsInlineLimit: 0`, an `@` alias to
  `/resources/js`. A custom `hotFile`, `buildDirectory` or manifest name must be set in vite.config AND through the `Vite::`
  facade (`useHotFile`, `useBuildDirectory`, `useManifestFilename`), or Blade looks in the wrong place.
- **Vite 8 drops glob-imported assets.** Rolldown tree-shakes an unused `import.meta.glob`, so images imported only for
  `Vite::asset()` silently leave the manifest. 3.x lists them in `assets: ['resources/images/**']` instead.
- **Fonts (3.1.0+):** `fonts: [google(…), bunny(…), fontsource(…), local(…)]` from `laravel-vite-plugin/fonts` self-hosts them and
  feeds Blade's `@fonts` (laravel/framework 13.7.0+). Metric-matched fallbacks need the optional `fontaine` package and are skipped
  without it. Fonts belong in `fonts`, not `assets`.
- **`@inertiajs/vite`** (Inertia v3, Vite 7 or 8) goes after `laravel()`. Its `pages` shorthand builds the lazy `import.meta.glob`
  resolver (default `./pages` and `./Pages`), and it serves dev-mode SSR with no separate Node process. Production still runs
  `vite build && vite build --ssr` and `php artisan inertia:start-ssr`. With `ssr: false`, or a manual `setup` callback, the SSR
  entry goes back on `laravel({ ssr })`. Page and app wiring → `laravel:inertia-best-practices`.
- **`@laravel/vite-plugin-wayfinder`** (0.x; Wayfinder is beta) runs `php artisan wayfinder:generate` at build start and on
  changes under `routes/**/*.php` and `app/**/Http/**/*.php`. The build therefore needs PHP, and a cached route table generates
  stale routes: run `php artisan route:clear` before `npm run build`. It declares no Vite peer range.
- **`vite-plus`** (Vite+, CLI `vp`, stable since 1.0 on 2026-09-28) replaces `vite` through a package-manager override, and its
  config imports `defineConfig` from `vite-plus`. `vp build` runs the built-in build, not the `package.json` script (`vp run build`
  does). No source says the Laravel, Inertia or Wayfinder plugins work under it: verify a real build before advising a move.

## Scope by model tier

**All models** — every rule above: the version gates, the boundaries, the footguns. Facts
do not scale down with the model. **Compensation (worker-tier)** — the detect → pin →
verify order the `/code-review:review` fan-in runs (detect the stack from the lockfile,
pin the version, verify each rule), followed literally, every skill in scope applied
to every file in scope; a Fable-class session may compress it once the lockfile is read.
**Skip** — a diff touching no `vite.config.*`, no `.env*`, no `import.meta` and no dynamic `import()` earns a one-line verdict; do not walk the rubric to prove it.

## Anti-patterns

Names only — each rule is stated once above, in the section that owns it.

- Secrets behind `VITE_` vars, or `process.env.SECRET` in client code — see Env security.
- Missing `base` on a sub-path deploy — see base and dev server.proxy.
- `optimizeDeps` include/exclude hacks masking a broken dep export — see Dep pre-bundling.
- One unsplit vendor chunk, or hundreds of micro-chunks — see Code splitting.
- `define` values without `JSON.stringify` — see define pitfalls.
- Assuming `build.target` follows `.browserslistrc` — see build.target and browserslist.
