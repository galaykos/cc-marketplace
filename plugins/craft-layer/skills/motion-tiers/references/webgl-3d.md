# Tier 3 — WebGL / 3D: lazy-load and static-fallback rules

Tier 3 (Three.js / R3F) is budget-gated because it is the only tier whose bundle-KB is
measured in hundreds, not tens. These rules govern WHEN it is allowed to load and WHAT
renders in its place. They do NOT teach R3F — renderer choice, disposal, the render
loop, and R3F correctness live in
`plugins/threejs/skills/threejs-best-practices/SKILL.md`. Read it before writing any
scene; this file only sets the loading and fallback contract on top of it.

## The two-render contract

Every tier-3 surface ships two renders:

1. **The static fallback** — a poster image, `<video poster>`, or a flat SVG that
   captures the hero frame. This is what the initial HTML contains and what a crawler,
   a slow connection, and a reduced-motion user see.
2. **The 3D upgrade** — the WebGL scene, loaded only after the fallback is on screen and
   the load is affordable. The upgrade replaces the fallback in place; a failed or
   deferred load simply leaves the fallback showing.

If you cannot produce the static fallback, you are not ready to ship the 3D — the
fallback is the source of truth for the surface, the scene is the enhancement.

## Lazy-load rules

- **Never in the initial bundle.** Code-split the `three` + R3F chunk behind a dynamic
  import; the entry bundle must not carry WebGL. (SSR frameworks additionally keep it
  off the server render — Next `dynamic(..., { ssr: false })`, Nuxt `.client` /
  `<ClientOnly>`; see `framework-bindings.md`.)
- **Load on intent, not on mount.** Trigger the import from an `IntersectionObserver`
  when the surface nears the viewport, or from a user interaction (a "view in 3D"
  button) — not eagerly at page load where it competes with LCP.
- **Gate on capability and preference.** Skip the upgrade entirely when
  `prefers-reduced-motion: reduce` matches, when the Save-Data header / low-end signals
  are present, or when WebGL is unavailable — the fallback already covers all three.
- **One renderer, reused.** Do not create a renderer per route or per view; browsers cap
  GPU contexts. Dispose the scene and the renderer on unmount. The how-to for renderer
  choice, `setAnimationLoop`, DPR capping, and disposal is in `threejs-best-practices`.

## Static fallback rules

- The fallback is a real asset in the initial render, not a spinner and not a blank
  canvas — a spinner that never resolves on a WebGL-less device is a broken surface.
- Match the fallback's dimensions and aspect ratio to the canvas so the 3D upgrade
  swaps in without layout shift (reserve the box; no CLS).
- Budget the fallback like any hero image (compressed WebP/AVIF) — it ships to everyone,
  so it must itself be cheap; it is also the reduced-bundle path for this tier.

## prefers-reduced-motion within the scene

If a reduced-motion user does opt into the 3D (explicit interaction), the scene must not
auto-move: freeze the animation loop and render a single static frame — no auto-rotation,
no drifting camera, no parallax. Frame-rate-independent stepping and render-on-demand
from `threejs-best-practices` make the frozen frame cheap. The safe default remains the
static fallback; the frozen scene is only for an explicit opt-in.

## Review checklist (delegates to threejs-best-practices for the how)

- [ ] `three`/R3F chunk is dynamically imported, absent from the entry bundle.
- [ ] A static poster / `<video poster>` fallback renders first, sized to avoid CLS.
- [ ] Upgrade triggers on viewport / interaction, gated by reduced-motion + Save-Data.
- [ ] Scene freezes to one static frame under `prefers-reduced-motion: reduce`.
- [ ] Renderer reused and disposed on unmount (per `threejs-best-practices`).
