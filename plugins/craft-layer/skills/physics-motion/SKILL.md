---
name: physics-motion
description: Use when a surface needs real 2D physics — objects that fall, collide, or drag (matter.js), not a spring a library already covers — or when a review flags a physics sim with no body budget, reduced-motion path, or keyboard route.
---

## What this decides

This skill decides WHETHER a surface needs a real 2D physics simulation (versus a spring
or tween) and HOW to run one within budget. It does not re-teach spring/tween motion —
Framer/Motion springs and gesture drag live in
`plugins/ui-ux/skills/motion-best-practices/SKILL.md` — and it honours the one-writer trap
in `plugins/craft-layer/skills/motion-tiers/references/gotchas.md`. Reference both by path.

**Reconciliation with motion-tiers:** physics-motion is a motion SOURCE / engine — like
scroll-orchestration is a scroll engine — not a `motion-tiers` rendering tier. The
simulation produces positions/angles each frame; a tier renders them (Tier 1 DOM
transforms, or a canvas). Pick a tier for the element; use this to DRIVE it when the
motion is genuinely physical. Physics has no native browser API, so a library (matter.js)
is a justified dependency — the one place the native-first rule does not apply.

## Decide: does the motion need real physics?

Answer before adding anything; take the first that fits:

1. A spring or ease conveys it — a button settle, a drawer, a hover lift → **not
   physics.** Use Framer/anime (motion-best-practices); a physics engine is overkill.
2. Objects must **collide, stack, or fall under gravity** (a pile that settles, tossed
   cards that bump) → a **matter.js world.**
3. **Drag with real inertia + constraints** (throw-and-settle, a pinboard) → matter.js
   with a mouse constraint.
4. Reduced-motion, low-power, or a data/content surface → **static layout, no
   simulation** (the fallback below).

Physics costs a stepped simulation on the main thread every frame; spend it only where the
weight, collision, or inertia is the point.

## Run one world (the engine)

- ONE matter.js `Engine` + `World` per surface, stepped from a SINGLE loop (the engine
  runner or your own rAF) — never two loops. Enable body sleeping so settled bodies stop
  costing CPU.
- Add static bounds (walls/floor) so bodies never escape the viewport; cap the body count
  (see budget). Lazy-init on viewport/interaction, not at page load.
- Setup, the sync, the mouse/drag constraint, walls, sleeping, and the rapier (wasm)
  alternative: `references/physics-patterns.md`.

## Driving DOM vs canvas

- **DOM**: read each body's `position`/`angle` in the loop and write `transform:
  translate()/rotate()` to the matching element — transform/opacity only, ONE writer per
  element (gotchas: never let physics and another tween fight the same transform).
- **Canvas**: render bodies to a `<canvas>` for many bodies (cheaper than many DOM nodes).
  Choose by body count — dozens of DOM elements is fine; hundreds want canvas.
- Sync once per frame from the ONE loop; never write element transforms from a separate
  observer or event. Recompute static walls on resize so bounds track the viewport.

## Accessibility

- A draggable/throwable object is a pointer affordance — any content or action it gates
  MUST also be reachable by keyboard and in the static fallback. Never make physics the
  only path to information.
- Every drag needs a single-pointer, non-dragging route to the same outcome — a
  click/tap control, not just a tab stop (SC 2.5.7; `ui-ux:a11y-audit` owns it).
- Respect focus and do not trap it inside a physics canvas.

## prefers-reduced-motion (mandatory)

- When reduced, do NOT start the simulation — render the objects in their rest
  arrangement, so the surface reads correctly with zero motion. Honour a runtime change
  by tearing the world down. The physics runner is the classic miss.
- Gate both layers and land on the static final state — mechanism and the three ways
  it is missed: `../motion-tiers/references/reduced-motion.md`.

## Perf budget

- One world, one step loop, body sleeping on, a body-count ceiling (≈tens for DOM,
  more for canvas), static bounds. Lazy-init; dispose the world on unmount.
- Transform/opacity only when driving DOM; one writer per property (gotchas).
- Do not run physics off-screen — pause the runner when the surface leaves the viewport.

## References

- `references/physics-patterns.md` — matter.js engine/world setup, the body↔DOM sync, the
  mouse/drag constraint, walls, sleeping, canvas rendering, and the rapier (wasm) alt.
- Spring/tween alternative + gesture drag: `plugins/ui-ux/skills/motion-best-practices/SKILL.md`.
- One writer per property: `plugins/craft-layer/skills/motion-tiers/references/gotchas.md`.

## Anti-patterns

- **Physics for a spring** — a whole engine for a settle a spring does; wasteful and heavier.
- **Two writers on one transform** — matter.js and a tween both writing an element's
  transform; they fight each frame (gotchas).
- **Uncapped bodies** — an unbounded body count or no sleeping; the step cost balloons.
- **No reduced-motion gate** — a simulation loop with no `prefers-reduced-motion` branch
  and no static settled layout.
- **Drag-only affordance** — content reachable only by throwing/dragging, with no keyboard
  route or static fallback.
- **Off-screen simulation** — stepping a world for a surface that is not visible.
