# Framework seams — wiring a view transition into each router

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

## React (client router)

Wrap the state commit that changes the route in `flushSync` inside the transition
callback, so React has actually committed the new DOM before the second snapshot:

- `document.startViewTransition(() => flushSync(() => setRoute(next)))`.
- Without `flushSync`, React may batch the update past the snapshot and the transition
  captures the old view twice. Guard the whole thing behind the reduced-motion + support
  checks from motion-best-practices.

## Next.js (App Router)

- App Router navigations are async; use the framework's view-transition integration
  (the `next-view-transitions` pattern or the built-in experimental flag current at
  build time) rather than hand-wrapping `router.push`, because the commit is not
  synchronous. Assign `view-transition-name` on the shared element in both the list and
  the detail route so the names match across the RSC boundary.

## Nuxt / Vue Router

- Nuxt ships first-class view-transition support (an app config flag) that wraps route
  changes for you; when hand-rolling, use a `router.afterEach` / `beforeResolve` guard to
  start the transition around the resolved navigation, not around the raw push.
- Put matching `view-transition-name`s on the persistent element in both route
  components.

## Astro (cross-document / MPA)

- Astro's `<ClientRouter />` (View Transitions) uses the native cross-document path:
  `@view-transition { navigation: auto }` plus `transition:name` directives on elements.
  This degrades to a normal full page load where unsupported — no JS wrapper needed.
- Prefer this for content/marketing sites; it needs no client router.

## Verify the seam

- The shared element tweens between its two positions (not a whole-page fade only).
- Reduced-motion and unsupported browsers navigate instantly with no error.
- No element keeps a `view-transition-name` after the transition settles.
