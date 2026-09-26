# Framework seams — wiring a view transition into each router

> Last verified: 2026-09-26 — https://nextjs.org/docs/app/guides/view-transitions — npm:react@19.3

Read on demand from the page-transitions SKILL. The API itself (how
`document.startViewTransition` works, `@view-transition`, feature-detection, the
reduced-motion snippet) is NOT re-taught here — it lives in
`plugins/ui-ux/skills/motion-best-practices/SKILL.md`. This file is only the
router-specific seam: how each framework commits the new DOM so the snapshot is honest.

## The shared rule

`startViewTransition(callback)` snapshots the CURRENT DOM, runs your `callback` to swap in
the new DOM, then snapshots again and tweens. So the callback must synchronously commit
the new view. If the router commits asynchronously (a suspended route, a fetch), the
snapshot is taken before the DOM changes and the transition captures nothing. Always
feature-detect first and fall through to a plain navigation when the API is absent.

## The `view-transition-name` lifecycle

Assign a unique name just before navigating; clear it once the transition settles:

- On the source element, set `el.style.viewTransitionName = 'card-' + id` immediately
  before triggering the nav.
- After `transition.finished` (or the framework's after-navigation hook), clear it
  (`el.style.viewTransitionName = ''`) so no two elements ever hold the same live name.
- Derive the name from a stable id; never a constant shared by siblings.

## Automatic names: `match-element` and `view-transition-class`

- `view-transition-name: match-element` has the browser name each element by identity —
  no id helper for an in-page list. Same-document only: the names cannot cross documents
  (MDN). Chrome 137, Safari 18.4, Firefox 144.
- `view-transition-class` gives many named elements one class, so a single
  `::view-transition-group(.card)` rule styles them all. Chrome 125, Safari 18.2,
  Firefox 144.

## React 19.3+ — `<ViewTransition>`

- `import { ViewTransition } from 'react'` — stable since React 19.3. It animates only
  updates marked as Transitions: `startTransition`, a `<Suspense>` reveal, or
  `useDeferredValue`. A plain `setState` does not animate.
- Shared element: wrap the element in `<ViewTransition name={'photo-' + id}>` in both
  views; each name must be unique across the app at any time. `addTransitionType` inside
  `startTransition` picks a direction-specific animation.
- Below 19.3, or outside React's tree: wrap the commit in `flushSync` inside the transition
  callback — `document.startViewTransition(() => flushSync(() => setRoute(next)))` —
  or React may batch the update past the snapshot and capture the old view twice. Guard
  it behind the reduced-motion + support checks from motion-best-practices.

## Next.js (App Router)

- Follow Next's view-transitions guide for the installed version. As of 16.3 it works
  with no configuration: `import { ViewTransition } from 'react'` (the App Router's bundled
  React includes it); route navigations are transitions, so it animates on `<Link>`.
  Neither the `next-view-transitions` package nor an experimental flag is needed.
- `transitionTypes` on `<Link>` (and on `router.push` / `replace`) tags direction.
  Put the directional wrapper in each `page.tsx`, not the layout — layouts persist, so
  enter and exit never fire there.
- A shared-element morph plays only when the destination renders in the same commit (a
  prefetched page); a destination that suspends first gets its enter animation instead.
- Its reduced-motion CSS zeroes `::view-transition-*` durations; keep it.

## Nuxt / Vue Router

- Nuxt ships an experimental implementation (`experimental.viewTransition` in
  `nuxt.config`, per-page overrides in `definePageMeta`) that wraps route changes for you
  and skips them under `prefers-reduced-motion: reduce` unless set to `'always'`. When
  hand-rolling, use a `router.afterEach` / `beforeResolve` guard to start the transition
  around the resolved navigation, not around the raw push.
- Put matching `view-transition-name`s on the persistent element in both route
  components.

## Astro — two different mechanisms

- **Native cross-document (MPA):** `@view-transition { navigation: auto; }` in the CSS
  of both pages, and matching `view-transition-name`s. No `<ClientRouter />`, no added
  JS, no change to existing scripts — real page loads that animate where supported
  (cross-document: Chrome 126, Safari 18.2, not Firefox; MDN limited availability) and
  load plainly elsewhere. Prefer this for content and marketing sites.
- **`<ClientRouter />`** (`astro:transitions`) intercepts navigation and turns the site
  into a single-page app. It brings persistent elements (`transition:persist`), shared
  state and fallback strategies for unsupported browsers — and the cost: scripts must
  re-initialise on `astro:page-load`. Take it only for what it adds.

## Cross-document shared elements: `pageswap` / `pagereveal`

On a multi-page site the element to name depends on the link clicked. In `pageswap` (the
outgoing page; `event.viewTransition` and `event.activation` with the destination entry)
name the clicked element; in `pagereveal` (the incoming page) name its counterpart; clear
both after `viewTransition.finished`. Chrome 123/124, Safari 18.2, no Firefox (MDN:
limited availability) — elsewhere the navigation is a plain load.

## Verify the seam

- The shared element tweens between its two positions (not a whole-page fade only).
- Reduced-motion and unsupported browsers navigate instantly with no error.
- No element keeps a `view-transition-name` after the transition settles.
