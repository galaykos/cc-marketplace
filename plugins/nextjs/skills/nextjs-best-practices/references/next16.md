# Next.js 16 — the operational detail behind the body's one bullet

> Last verified: 2026-08-12 — https://nextjs.org/blog/next-16-2
> (16 GA 2025-10; 16.1 2025-12; 16.2 2026-03 — current as of this stamp.)

The SKILL body compresses Next 16 into one bullet; this file is the per-change
operational detail — what breaks, what the escape hatch is, what an agent should
NOT do by default.

## Bundler: Turbopack is the default

- `next dev` and `next build` run Turbopack; webpack remains via `next build --webpack`
  (and `next dev --webpack`). A custom `webpack()` function in next.config is IGNORED
  under Turbopack — its presence with no `--webpack` flag is dead config and the #1
  silent migration miss. Port loaders to `turbopack.rules` or keep the flag.
- 16.1 added Turbopack filesystem caching for `next dev` (compiler artifacts persist
  across restarts); 16.2 made `next dev` startup ~400% faster and rendering ~50%
  faster. Perf advice premised on "dev server cold starts are slow" is stale.

## proxy.ts replaces middleware.ts

- Same request-interception role, renamed and clarified: `middleware.ts` → `proxy.ts`
  (`export default function proxy(...)`). Keep auth CHECKS out of it — it runs before
  the request reaches a route, but it is an optimization/routing layer, not the authz
  boundary; verify again server-side (the body's server-actions rule applies).
- Migration is mechanical (`npx @next/codemod` handles the rename); having BOTH files
  is an error.

## Caching: explicit, keyed, opt-in

- Cache Components (`cacheComponents: true`) + `'use cache'` directives are the 16
  caching model; `revalidateTag(tag, profile)` takes a cache-life profile, plus
  `updateTag()` (read-your-writes within the request) and `refresh()` (client refresh
  of uncached data). Root params are usable inside `'use cache'` since 16.2.
- Do not retrofit `'use cache'` onto a 15.x app without the flag — the directive
  errors when `cacheComponents` is off.

## Debugging and deploys

- 16.2: `next start --inspect` attaches a Node debugger to the PRODUCTION server —
  the right tool when an issue reproduces only in prod builds.
- 16.2: the Adapters API is stable — deployment platforms hook the build officially;
  bespoke output-directory surgery in CI is now the wrong layer.

## Smaller 16.x facts an agent gets wrong from 15-era memory

- Sync request-API access is REMOVED (not deprecated): `cookies()`, `headers()`,
  `params`, `searchParams` are async-only. The 15-era codemod-added `await` is now
  mandatory.
- Parallel route slots require an explicit `default.js` — a missing one is a build
  error in 16, not a silent 404.
- React Compiler support is stable but OFF by default — do not enable it in a diff
  unprompted; it changes memoization semantics repo-wide.
- `<Link transitionTypes={[...]}>` (16.2) passes View Transition types on navigation —
  the supported route-transition mechanism; do not hand-roll `startViewTransition`
  wrappers around router pushes.
- `icon.png` and `icon.svg` side by side both emit `<link>` tags (16.2) — SVG for
  modern browsers, PNG fallback; no config needed.
- Removed outright: AMP support, `next lint` (run ESLint/Biome directly). Floors:
  React 19.2+, Node 20.9+.

## When NOT to apply

Against a 14/15 lockfile none of this exists — the body's per-version rule governs;
in particular do not rename middleware.ts or add `'use cache'` below 16.
