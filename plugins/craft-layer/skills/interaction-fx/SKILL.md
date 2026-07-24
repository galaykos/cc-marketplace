---
name: interaction-fx
description: Use when adding a pointer micro-interaction — a custom cursor, magnetic button, tilt, or drag — or when a craft review flags a pointer effect that hides the real cursor, ignores touch, or lacks a reduced-motion path. Decides if it aids affordance or decorates, gives the cursor/magnetic/tilt/drag patterns on one rAF loop, and mandates accessibility (real cursor kept, pointer:coarse off, focus-visible parity) plus reduced-motion; references Framer and the one-writer gotcha by path.
---

## What this decides

This skill decides WHETHER a pointer effect aids affordance or is decoration, and WHICH
pattern to use — then pins the accessibility rules and the budget. It does NOT re-teach
the animation primitives: Framer / Motion springs, gestures, and `useSpring` live in
`plugins/ui-ux/skills/motion-best-practices/SKILL.md` (+ `references/motion.md`) — and the
one-writer-per-property trap lives in
`plugins/craft-layer/skills/motion-tiers/references/gotchas.md`. Reference both by path.

**Reconciliation with motion-tiers Tier 1:** Tier 1 (Framer) owns *element* animation —
enter/exit, layout, hover states on a component. This skill is the *pointer-driven
interaction layer* on top: effects that read the cursor position across the page (custom
cursor, magnetic pull, tilt-toward-pointer). Pick the tier for the element there; pick
the interaction here.

## Decide: does the pointer effect aid affordance?

Answer before adding anything; take the first that fits:

1. The control already reads as interactive (a button looks like a button) → **no cursor
   FX.** Do not add motion that competes with a clear affordance.
2. A single primary CTA needs pull → a **magnetic button** (bounded).
3. A card or media needs depth on hover → a **bounded tilt** (small `rotateX/Y`).
4. A bespoke pointer signature is genuinely the brand → a **custom cursor** — only with
   the accessibility rules below satisfied.
5. Touch, reduced-motion, or keyboard → **native affordances only**, no pointer FX.

Pointer FX earns its cost when it strengthens an affordance or a brand signature; a
cursor trail that says nothing is decoration competing with the content.

## The patterns

All four are transform/opacity only, spring-smoothed via Framer/Motion (idioms
referenced, not restated), and driven from ONE page-wide pointer loop. Keep the feel
subtle — a small displacement that trails the pointer reads as craft; a large one reads
as a toy and fights the click target underneath.

- **Custom cursor** — an element that follows the pointer (lerped toward the target each
  frame, never snapped), with hover states for interactive targets driven by one
  delegated listener. The real cursor stays visible unless the rule below is met.
- **Magnetic button** — translate the control toward the pointer within a small radius
  (a fraction of the offset), spring back on leave; the label may lead the container
  slightly for depth. Reset cleanly so the button never drifts off its hit area.
- **Hover tilt** — map pointer offset within the element to a bounded `rotateX/rotateY`
  (≈±6–10°), reset on leave. Transform only, `transform-style: preserve-3d` on the
  parent and `perspective` on the container; larger angles nauseate rather than delight.
- **Drag affordance** — a grabbable handle or carousel using Framer drag with inertia and
  constraints, with a visible grab cursor and a keyboard/scroll equivalent. Mechanics +
  the single shared pointer loop: `references/pointer-patterns.md`.

## Accessibility (non-negotiable)

- **Never hide the real cursor** (`cursor: none`) unless a keyboard-navigable equivalent
  exists AND the custom cursor conveys no information the pointer did not. When in doubt,
  keep the system cursor visible under the custom one.
- **`pointer: coarse`** (touch) disables custom-cursor, magnetic, and tilt — they need a
  hover pointer. Gate with `@media (hover: hover) and (pointer: fine)` / a matchMedia
  check.
- **`:focus-visible` parity** — any state a mouse hover reveals (a CTA's magnetic emphasis,
  a card's lift) must also appear on keyboard focus, so keyboard users are not stranded.

## prefers-reduced-motion (mandatory)

- Under `matchMedia('(prefers-reduced-motion: reduce)')`: no cursor follow, no magnetic
  pull, no tilt — the control keeps its static hover/focus state only.
- Gate the pointer loop in JS before it starts AND the effect CSS inside
  `@media (prefers-reduced-motion: reduce)`. A pointer rAF loop with no matchMedia guard
  is the classic miss.

## Perf budget

- Exactly **one** rAF pointer loop for the whole page — read the shared pointer position,
  write each active effect from it. A per-element rAF loop is a budget and a jank bug.
- Transform / opacity only (compositor); never animate `top`/`left`/`width` from the
  pointer. One writer per property per element (gotchas) — Framer OR a manual write,
  never both on the same transform.
- Throttle writes to frame cadence; passive `pointermove` listeners.

## References

- `references/pointer-patterns.md` — custom cursor, magnetic, tilt, and drag mechanics;
  the single shared pointer loop; the `(hover: hover)` / `pointer: coarse` gate.
- Framer/Motion springs, gestures, `useSpring`, drag:
  `plugins/ui-ux/skills/motion-best-practices/SKILL.md` + `references/motion.md`.
- One writer per property: `plugins/craft-layer/skills/motion-tiers/references/gotchas.md`.

## Anti-patterns

- **Hidden real cursor** — `cursor: none` with no keyboard equivalent; keyboard and
  fallback users lose the pointer entirely.
- **Cursor FX on touch** — magnetic/tilt/custom-cursor left on under `pointer: coarse`,
  where there is no hover pointer to drive them.
- **Two writers on one transform** — Framer and a manual rAF both writing the same
  element's transform; they fight each frame (gotchas).
- **Per-element rAF loops** — a loop per magnetic button instead of one shared pointer
  loop; needless main-thread cost.
- **No focus parity** — hover-only emphasis with no `:focus-visible` equivalent.
- **No reduced-motion gate** — a pointer loop with no `prefers-reduced-motion` branch.
- **Re-teaching Framer** here instead of referencing motion-best-practices.
