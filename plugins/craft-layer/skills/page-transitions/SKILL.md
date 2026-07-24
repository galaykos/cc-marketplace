---
name: page-transitions
description: Use when adding motion between routes or pages — a shared element that persists across a navigation, a full-page crossfade, or an SPA route change — or when a craft review flags a page transition with no reduced-motion or unsupported-browser fallback. Decides whether a route transition earns its cost, choreographs shared elements via view-transition-name across React/Next/Nuxt/Astro, and mandates reduced-motion plus an instant-navigation fallback; references the View Transitions API by path.
---

## What this decides

This skill decides WHETHER a route or page change earns a transition and HOW to
choreograph it across the frameworks craft-layer targets. It does NOT re-teach the View
Transitions API — `document.startViewTransition`, the `@view-transition { navigation }`
at-rule, feature-detection, and Motion's `animateView` already live in
`plugins/ui-ux/skills/motion-best-practices/SKILL.md` — reference by path, never copy.

**Reconciliation:** motion-best-practices owns the *API* (how to call the browser's
view-transition primitives and the reduced-motion snippet). This skill owns the
*page-level decision + choreography*: when a navigation deserves a transition, which
element persists across it, and how each router commits the DOM so the snapshot is
correct. Different jobs — pick the API there, pick the transition here.

## Decide: does a page transition earn its cost?

Answer before adding anything; take the first that fits the navigation:

1. The two views share no spatial relationship (unrelated pages) → **no transition.** A
   native, instant navigation reads as faster. Do not crossfade for polish.
2. An element persists across the nav — a thumbnail that becomes the hero, a list row
   that opens into a detail — → a **shared-element transition** on that one element.
3. The whole page changes mood (marketing → app, section → section) → a **full-page
   crossfade or clip**, no shared element.
4. Reduced-bundle target, or a browser without the API → **instant navigation**, no
   transition. The fallback below is mandatory, not optional.

A page transition costs a snapshot of both states and a blocked paint during the swap;
spend it only where it carries continuity the eye would otherwise lose.

## Shared-element choreography

The whole trick is one persistent name, assigned for the duration of the nav only:

- Give the element the SAME `view-transition-name` in the outgoing and incoming views
  (e.g. `view-transition-name: card-42`). The browser matches the two snapshots by name
  and tweens position/size between them.
- The name must be **unique while live** — two elements sharing a name at snapshot time
  breaks the capture. Derive it from a stable id (`card-${id}`), not a constant.
- Assign it late and clear it after: set the name just before navigating, remove it once
  the transition settles, so an off-screen list of 50 cards never holds 50 live names.
- Only the ONE continuous element gets a name; everything else rides the default
  root crossfade. Naming many elements fights itself and janks.

## Framework seams

Each router commits the DOM differently; the transition must wrap the commit, not race
it. The per-framework wiring (React `startViewTransition` + `flushSync`, the Next.js App
Router hook, Nuxt/Vue Router `useRouter` guard, Astro's native cross-document path) and
the name-lifecycle helper live in `references/framework-seams.md`. The rule they share:
the snapshot must be taken with the OLD DOM present and released with the NEW DOM
committed — never call the transition around an async commit that has not landed yet.

## Unsupported browsers — feature-detect and fall through

- Feature-detect (`if (!document.startViewTransition) { navigate(); return }`) and let
  the navigation happen instantly. Detection detail is in motion-best-practices — apply
  it; never block or delay a navigation waiting on a capability the browser lacks.
- Cross-document (`@view-transition { navigation: auto }`) already degrades to a normal
  page load where unsupported; do not polyfill it.

## prefers-reduced-motion (mandatory)

No page transition ships without this:

- Gate the JS path behind `matchMedia('(prefers-reduced-motion: reduce)')` — when
  reduced, navigate instantly with no `startViewTransition` wrapper.
- Gate the CSS with `@media (prefers-reduced-motion: reduce)` to drop the
  `::view-transition-*` animations (the snippet is in motion-best-practices) so reduced
  users land on the new page at once, correct and un-animated.
- A shared-element move is motion too — reduced-motion means the element simply appears
  in its new place, not that it flies there slowly.

## Perf budget

- A transition blocks paint for its duration — keep it short (≈200–400ms) so navigation
  never feels gated on animation.
- Snapshot cost scales with named elements and painted area; name ONE element, not a
  grid. Large fixed backgrounds captured every nav are a hidden cost.
- No new runtime dependency: the API is native. Motion's `animateView` is optional and
  only when you already ship Motion — do not add a library for page transitions.

## References

- `references/framework-seams.md` — React (`startViewTransition` + `flushSync`), Next.js
  App Router, Nuxt/Vue Router, Astro cross-document; the `view-transition-name` lifecycle
  helper (assign-before / clear-after).
- View Transitions API, `@view-transition`, feature-detection, the reduced-motion
  snippet, and Motion `animateView`:
  `plugins/ui-ux/skills/motion-best-practices/SKILL.md`.

## Anti-patterns

- **Transition on every nav** — crossfading unrelated pages; it taxes each navigation
  and reads as slower, not more premium.
- **Name collision** — two live elements sharing one `view-transition-name` at snapshot
  time; the capture breaks and the transition no-ops or flickers.
- **Blocking the nav** — awaiting the API on a browser that lacks it, or wrapping an
  async commit that has not landed, so navigation stalls.
- **Naming everything** — a `view-transition-name` on every card; the transitions fight
  and jank. One continuous element only.
- **No reduced-motion / no fallback** — a transition with no `prefers-reduced-motion`
  branch or no instant-navigation path for unsupported browsers.
- **Re-teaching the API** — restating `startViewTransition` / `@view-transition` here
  instead of referencing motion-best-practices.
