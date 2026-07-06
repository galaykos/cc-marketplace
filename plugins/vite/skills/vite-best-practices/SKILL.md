---
name: vite-best-practices
description: Use when writing or reviewing Vite config or a Vite-built app — VITE_-prefix env security as the lead rule, dep pre-bundling and optimizeDeps, code splitting with dynamic import and manualChunks, base for sub-path deploys, dev server.proxy, define stringify pitfalls, import.meta.glob, public vs imported asset handling, build.target/browserslist alignment, SSR externalization, library mode, plugin enforce/apply order, HMR guards, all pinned to the vite version in the lockfile. The TypeScript type layer and framework rules live in their own plugins.
---

## Know the version before advising

- The locked `vite` entry (package-lock.json / yarn.lock / pnpm-lock.yaml / bun.lock)
  is what actually builds the app — a `^5.0` constraint permits 5.0 through 5.x; only
  the lock says which minor is present and which defaults ship.
- The Node floor matters and CI must meet it: Vite 5 needs Node 18+; Vite 6
  supports 18 / 20 / 22; Vite 7 dropped 18 and requires 20.19+ or 22.12+. Green
  locally on Node 22 and red in CI on Node 18 is a floor mismatch, not a bug.
- Read `vite.config.{js,ts}` (and the mode-specific `.env` files it loads) before
  advising — half of this skill is config, and advice the config enforces is noise.
- Verify version-sensitive claims against https://vite.dev/ for the locked minor,
  never from memory. Recommend nothing above the locked version; flag no workaround
  the locked version has not yet killed.

## Per-version leverage (advise at or below the floor)

Advising above the locked version is a finding. Keep these conservative; confirm
boundaries against the docs.

- **Vite 5** — Rollup 4 under the hood; `build.target` defaults to a modern-JS
  baseline (`'modules'`); the CJS Node API is deprecated, so `require('vite')` from a
  `.js` config warns — move the config to ESM.
- **Vite 6** — introduces the experimental Environment API (a refactor toward
  multiple build/dev environments); changes default `resolve.conditions` so
  `module`/`browser`/`node` are expected in the config value rather than injected
  internally — check the docs before relying on the old set.
- **Vite 7** — requires Node 20.19+ / 22.12+; default `build.target` becomes
  `'baseline-widely-available'` (a higher floor than 5/6's `'modules'`), so a bundle
  fine on 6 may need an explicit lower `target` for old browsers; Rolldown is opt-in
  via `rolldown-vite`, not the default yet. Unsure which minor flipped a default?
  State the capability and pin the check to https://vite.dev/.

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

- On first dev start Vite pre-bundles deps with esbuild into ESM and caches them in
  `node_modules/.vite` — why the first cold start is slow and later ones fast. A dep
  found mid-session forces a re-bundle and full reload; that flash is the cost of a
  late-discovered import, not a bug.
- `optimizeDeps.include` forces a linked / deep-imported / dynamically-imported dep
  into pre-bundling when the crawl misses it; `exclude` keeps an already-ESM dep out.
  `--force` (or deleting `.vite`) rebuilds the cache after a dependency change.
- `include`/`exclude` hacks that paper over a broken dep export are debt — fix the
  export or pin the dep; leave a comment on any entry you keep.

## Code splitting

- Dynamic `import()` at route boundaries is the primary split — each route becomes
  its own chunk loaded on navigation, so the initial payload stays small.
- Shape vendor chunks with `build.rollupOptions.output.manualChunks` — one giant
  vendor chunk means any dep change busts the whole cache; the function form groups
  by package. Do not over-split: hundreds of tiny chunks cost request overhead.
  Split by change-frequency, not by file count.
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

- `build.target` sets the syntax floor esbuild transpiles down to — it must match
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
  every peer/runtime dependency in `rollupOptions.external` so they are NOT bundled —
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

## Anti-patterns

- Secrets behind `VITE_` vars, or `process.env.SECRET` in client code — both ship
  to the browser. Server secrets never touch the client bundle.
- Missing `base` on a sub-path deploy — assets 404 the moment it's not at root.
- `optimizeDeps` include/exclude hacks that mask a broken dep export, committed
  instead of fixing the dep.
- One unsplit vendor chunk (or hundreds of micro-chunks) instead of splitting by
  change-frequency at route boundaries.
- `define` values without `JSON.stringify` — raw substitution injects a bare
  identifier and breaks the build or the value.
- Assuming `build.target` follows `.browserslistrc` — Vite does not read it.

## Verify Against Current Docs

Config surface and defaults shift across majors. Confirm any version-sensitive
option — `build.target` defaults, `resolve.conditions`, the Environment API, Node
floor, Rolldown status — against https://vite.dev/ for the exact vite version in the
lockfile, and read `vite.config.{js,ts}` before advising so you don't flag what the
config already handles.
