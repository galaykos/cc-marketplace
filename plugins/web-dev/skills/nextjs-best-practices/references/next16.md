# Next.js 16 — the operational detail behind the body's one bullet

> Last verified: 2026-09-26 — https://nextjs.org/blog/next-16-3 — npm:next@16.3
> (16 GA 2025-10; 16.1 2025-12; 16.2 2026-03; 16.3 2026-08 — 16.3.6 current as of this stamp.
> Cross-read against the docs bundled in next@16.3.6 at `node_modules/next/dist/docs/`.)

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
  (`export default function proxy(...)`). The docs endorse OPTIMISTIC auth checks here —
  read the session from the cookie and redirect, no database call, since it runs on every
  route including prefetches — and say it "should not be your only line of defense". A
  matcher change, or a Server Function moved to another route, silently drops its
  coverage: verify again in the data access layer, each server action and each route
  handler (the body's server-actions rule applies). Source: nextjs.org/docs/app/guides/
  authentication, "Optimistic checks with Proxy"; the bundled `proxy` file-convention page.
- The `runtime` segment option is not available in `proxy.ts` — setting it throws; Proxy
  runs on Node.js.
- Migration is mechanical (`npx @next/codemod` handles the rename); having BOTH files
  is an error.

## Caching: explicit, keyed, opt-in

- Cache Components (`cacheComponents: true`) + `'use cache'` directives are the 16
  caching model; `revalidateTag(tag, profile)` takes a cache-life profile, plus
  `updateTag()` (read-your-writes within the request) and `refresh()` (client refresh
  of uncached data). Root params (`next/root-params`, 16.3) are readable inside
  `'use cache'`.
- Do not retrofit `'use cache'` onto a 15.x app without the flag — the directive
  errors when `cacheComponents` is off.

## Debugging and deploys

- 16.2: `next start --inspect` attaches a Node debugger to the PRODUCTION server —
  the right tool when an issue reproduces only in prod builds.
- 16.2: the Adapters API is stable — deployment platforms hook the build officially;
  bespoke output-directory surgery in CI is now the wrong layer.

## 16.3 additions (2026-08-03) an agent will not know

- `catchError` from `next/error` (stable; `unstable_catchError` in 16.2) builds a component-
  level error boundary in a Client Component that lets `notFound()`/`redirect()` through and
  hands the fallback a `retry()` that re-fetches Server Components. Do not hand-roll a React
  error boundary that swallows those throws. `error.tsx`'s `unstable_retry` is now `retry`.
- `next/root-params`: `import { lang } from 'next/root-params'; await lang()` reads a param
  defined above the root layout from any Server Component — not in Client Components, Server
  Actions or route handlers yet. Replaces prop-drilling `[lang]`.
- Instant Navigations, opt-in and both requiring `cacheComponents: true`:
  `partialPrefetching: true` (links prefetch the static shell; `prefetch={true}` fetches
  more), and the `instant` segment export — `true` validates that navigation into the
  segment renders instantly, `false` opts out. `export const instant = false` is the
  `[block]` fix Next prints for "uncached data during prerendering"; `[stream]` (a
  `<Suspense>` fallback) and `[cache]` (`'use cache'`) are the other two. Do not add either
  without the flag.
- `next dev` writes the `nextjs-agent-rules` block into `AGENTS.md` and a `CLAUDE.md` that
  imports it; `agentRules: false` opts out. The body's first section covers what to do with it.
- Turbopack supports `import.meta.glob`; `next build` type-checks with TypeScript 7 once the
  project's own TypeScript dependency is bumped to 7; the Turbopack disk cache now also
  speeds up `next build`, on by default.

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
- `next/image`'s `priority` prop is deprecated for `preload`; the docs prefer
  `loading="eager"` or `fetchPriority="high"` for the LCP image in most cases.
- Removed outright: AMP support, `next lint` (run ESLint/Biome directly). Floors:
  React 19.2+, Node 20.9+.

## When NOT to apply

Against a 14/15 lockfile none of this exists — the body's per-version rule governs;
in particular do not rename middleware.ts or add `'use cache'` below 16.
