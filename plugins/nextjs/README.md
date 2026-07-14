# nextjs

Next.js best practices: Server Components by default with deliberate `'use client'`
boundaries, the opt-in caching model (fetch cache, `revalidate`, tags, `use cache`
behind `cacheComponents`), server actions as public endpoints, route handlers,
streaming with `loading.tsx` and Suspense, the metadata API, and `next/image` /
`next/font` optimization.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install nextjs@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/nextjs:review [files-or-diff]` | Review App Router pages, actions, and handlers against the skill, pinned to the installed Next.js version from the lockfile |

## Example

```bash
/nextjs:review app/products/page.tsx app/actions/checkout.ts
/nextjs:review        # reviews the current diff
```

Advice pins to the installed Next.js version, so guidance matches the caching
defaults and APIs your release actually ships — the 14 → 15 → 16 flips matter.

## Pairs well with

- **react** — component-level hooks and render review inside these routes
- **typescript** — the type layer this framework review skips
- **performance** — bundle size and Core Web Vitals beyond the framework defaults
