# Motion depth — motion.dev recipes the SKILL body has no room for

> Last verified: 2026-07-22 — https://motion.dev/docs — npm:motion@12

Read on demand from motion-best-practices. Everything here assumes the `motion`
npm package (v12 line); `framer-motion` is a legacy alias — never import it.
Re-verify version-sensitive literals live at https://motion.dev/docs before use.

## Packages and imports

- Vanilla JS: `import { animate, scroll, inView, stagger, spring } from "motion"`.
- Smallest bundle: `import { animate } from "motion/mini"` — the 2.3kb mini
  `animate()` drives HTML/SVG styles through native browser APIs.
- React: `import { motion } from "motion/react"` — components, gestures, hooks.
- Mini vs hybrid trade-off: the hybrid `animate` (18kb) adds independent
  transforms (`x`, `rotate`), CSS variables, SVG paths, animation sequences,
  colors/strings/numbers, and plain JS objects on top of mini's style tweens.
  The hybrid engine pairs browser-native animation performance with a JS
  engine for what the browser alone cannot animate.

## animate()

- `animate(target, keyframes, options)` — target is a selector, element, or
  array; options include `duration`, `delay`, `ease`, `repeat`, `type`.
- Returns playback controls: `play()`, `pause()`, `stop()`, plus `then()` for
  promise-style chaining; `onUpdate` receives the latest values per frame.
- Stagger a matched group: `animate(".item", { x: 300 }, { delay: stagger(0.1) })`.

## Springs and easing

- Named eases: `"linear"`, `"easeIn"`/`"easeOut"`/`"easeInOut"`,
  `"backIn"`/`"backOut"`/`"backInOut"`, `"circIn"`/`"circOut"`/`"circInOut"`,
  `"anticipate"`, `"steps"`; cubic bezier as a four-number array
  (`ease: [0.39, 0.24, 0.3, 1]`); custom easing is any fn mapping 0–1 → 0–1.
- Springs: `{ type: "spring" }` in options; or import `spring` from `"motion"`
  and pass `{ type: spring, stiffness: 300 }` — this also upgrades the mini
  `animate` to spring easing without pulling in the full hybrid bundle.

## scroll()

- `scroll(callback)` streams 0–1 scroll progress; `scroll(animation, options)`
  binds an animation's progress to scroll position.
- Options: `container` (default `window`), `target` (element tracked within
  the container), `axis` (`"y"` default, or `"x"`), `offset` (default
  `["start start", "end end"]` — edge names, numbers, px, %, viewport units).
- Uses the ScrollTimeline API where possible — hardware-accelerated, smooth
  under main-thread load; returns a cleanup function; 5.1kb.

## inView()

- `inView(target, callback, options)` — target is a selector, Element, or
  array; the callback receives `(element, IntersectionObserverEntry)`.
- Return a function from the callback to run when the element leaves the
  viewport; the gesture keeps firing on every subsequent enter/leave.
- Options: `root` (default `window`), `margin`, `amount` (`"some"` default,
  `"all"`, or a 0–1 proportion). Built on IntersectionObserver; 0.5kb.

## React component model

- `<motion.div>` (any HTML/SVG tag: `motion.button`, `motion.circle`, …)
  animates via props: `initial` → `animate`, `transition` to tune type,
  duration, easing, delay; `exit` runs on removal — only inside
  `<AnimatePresence>`, which holds the element in the DOM until exit finishes.
- Changing values in `animate` auto-transitions; `initial={false}` disables
  the mount animation. `layout` animates size/position/reorder changes;
  `layoutId` animates between completely different elements.
- `useScroll()` returns `scrollYProgress` for scroll-linked component motion.
- Variants: define named states once via the `variants` prop, then reference
  them by name in `animate` and gesture props.

## Gesture props (React)

- `whileHover`, `whileTap`, `whileFocus`, `whileDrag` (enable with `drag`),
  `whileInView` — each takes a target object or variant name and reverts when
  the gesture ends.
- Event callbacks: `onHoverStart`/`onHoverEnd`, `onTapStart`/`onTap`/
  `onTapCancel`, `onPan` (pan has no `while-` prop).

Reduced motion: the SKILL body's `prefers-reduced-motion` rule applies
unchanged — every Motion usage ships a reduced-motion branch.
