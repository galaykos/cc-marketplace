# Motion depth — motion.dev recipes the SKILL body has no room for

> Last verified: 2026-10-06 — https://motion.dev/docs — npm:motion@14

Read on demand from motion-best-practices. Everything here assumes the `motion`
npm package (14.x); `framer-motion` is a legacy alias — never import it.
Re-verify version-sensitive literals live at https://motion.dev/docs before use.

Read 2026-10-06 from the motion CHANGELOG and the 14.0.0 npm tarballs
(motion.dev refused the connection that day). 14.0.0 (2026-10-02) removes only
internal APIs that 13.5.1 had restored for framer-motion 13.0–13.4
compatibility; no public API changed. The breaking change that matters is
still 13.0's (2026-08-05): the automatic `@emotion/is-prop-valid` detection is
gone. A CSS-in-JS tree (styled-components, Emotion) that relied on it must pass
the filter explicitly — `<MotionConfig isValidProp={isPropValid}>` — or style
props leak onto DOM elements as attributes. Imports and recipes are otherwise
unchanged from v12. Bundle sizes below are motion.dev's figures as read
2026-09-26; 13.3–13.5 shrank `animate`, `scroll` and `<m>`, so treat them as
upper bounds.

## Packages and imports

- Vanilla JS: `import { animate, scroll, inView, stagger, spring } from "motion"`.
- Smallest bundle: `import { animate } from "motion/mini"` — the 2.3kb mini
  `animate()` drives HTML/SVG styles through native browser APIs.
- React: `import { motion } from "motion/react"` — components, gestures, hooks.
- React reduced bundle: `import { LazyMotion, domAnimation, m } from "motion/react"` —
  `m.*` components inside `<LazyMotion features={domAnimation}>` cut the initial
  cost to ~6KB with the animation features lazy-loaded; `domMax` when drag or
  layout projection is needed, and `features` accepts an async loader for
  code-splitting. This is the React bundle path — `motion/mini` is the vanilla
  `animate()` only and cannot render `m.`/`motion.` components.
- Mini vs hybrid trade-off: the hybrid `animate` (18kb) adds independent
  transforms (`x`, `rotate`), CSS variables, SVG paths, animation sequences,
  colors/strings/numbers, and plain JS objects on top of mini's style tweens.
  The hybrid engine pairs browser-native animation performance with a JS
  engine for what the browser alone cannot animate.
- `framer-motion-3d` is deprecated on npm (last release 12.4.13, 2025-03-11);
  never add it. Motion's own replacement (13.2+) is `import { threeEffect }
  from "motion/three"`: register it via `animate.addEffect(threeEffect)` to
  animate meshes, materials and uniforms directly. Otherwise damp values
  toward a target in R3F's `useFrame`, drive them with GSAP, or use
  `@react-spring/three` (10.x). Standing: recorded.

## animate()

- `animate(target, keyframes, options)` — target is a selector, element, or
  array; options include `duration`, `delay`, `ease`, `repeat`, `type`.
- Returns playback controls: `play()`, `pause()`, `stop()`, plus `then()` for
  promise-style chaining; `onUpdate` receives the latest values per frame.
- Stagger a matched group: `animate(".item", { x: 300 }, { delay: stagger(0.1) })`.

## Springs and easing

- Named eases: `"linear"`, `"easeIn"`/`"easeOut"`/`"easeInOut"`,
  `"backIn"`/`"backOut"`/`"backInOut"`, `"circIn"`/`"circOut"`/`"circInOut"`,
  `"anticipate"`; cubic bezier as a four-number array
  (`ease: [0.39, 0.24, 0.3, 1]`); `steps(n)` is an imported function, not a
  name; custom easing is any fn mapping 0–1 → 0–1.
- Springs: `{ type: "spring" }` in options; or import `spring` from `"motion"`
  and pass `{ type: spring, stiffness: 300 }` — this also upgrades the mini
  `animate` to spring easing without pulling in the full hybrid bundle.
- Which tool for which motion: springs for interactive, gesture-driven work —
  hover, tap, drag, layout — because a spring retargets smoothly when
  interrupted mid-flight (a half-finished hover reversing reads continuous,
  where a bezier restarts); duration + bezier for entrances/exits and
  scroll-linked motion, where timing is choreographed rather than reactive.
- Two defaults worth naming: snappy UI response
  `{ type: "spring", visualDuration: 0.25, bounce: 0.2 }` — Motion's perceptual
  spring API, sized by how long the motion LOOKS rather than its settle time —
  and gentle settle `{ stiffness: 170, damping: 26 }` for larger surfaces.
  anime.js v4 has a perceived form too (`spring({ duration, bounce })`); its
  own digest covers it.

## scroll()

- `scroll(callback)` streams 0–1 scroll progress; `scroll(animation, options)`
  binds an animation's progress to scroll position.
- Options: `container` (default `window`), `target` (element tracked within
  the container), `axis` (`"y"` default, or `"x"`), `offset` (default
  `["start start", "end end"]` — edge names, numbers, px, %, viewport units).
- A WAAPI animation binds to a native `ScrollTimeline` (no `target`, no
  `offset`) or `ViewTimeline` (a `target` whose `offset` maps to a view range)
  where the browser supports it — smooth under main-thread load. Callbacks,
  JS-driven values and every other offset track scroll on the main thread
  (14.0.0 source). Returns a cleanup function; 5.1kb.

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

## Reduced motion: what `MotionConfig` does NOT cover

Reduced motion: the SKILL body's `prefers-reduced-motion` rule applies
unchanged — every Motion usage ships a reduced-motion branch.

- `<MotionConfig reducedMotion="user">` disables transform and layout
  animations on `motion` components and keeps animating `opacity` and
  `backgroundColor`. It is not a tree-wide kill switch.
- Scroll-linked motion is not an animation it can stop: a `useScroll` →
  `useTransform` value bound to `style` keeps moving. Branch on
  `useReducedMotion()` and pass a static value instead of the motion value
  (Motion's own parallax recipe does this).
- An opacity pulse or a vanilla `animate()` / `scroll()` call is outside it
  too; gate those with the same hook or the subscribed media query.

Standing: recorded — no check reads a Motion tree for this.

## Animated counters: the number is content

Crawlers, no-JS visitors, link previews, screen readers and reduced-motion
users read the markup, not the animation:

- Render the final value in the server markup; counting is an enhancement on
  top of it.
- Never snap a visible final value back to the start to count it up — that is
  a flash on hydration. Count only a number still out of view when the script
  runs (reset it there, animate on enter); one already on screen stays put.
- Keep the accessible text at the final value while it ticks:
  `aria-hidden="true"` on the ticking node beside a visually hidden final
  value, or an equivalent.
- Under `prefers-reduced-motion: reduce`, skip the count entirely.

Registry counters break this (their shadcn items, read 2026-10-06): Magic UI's
NumberTicker server-renders its `startValue` (default 0) and React Bits'
CountUp renders an empty span, then writes its `from` value on mount; both
tick `textContent` from `useSpring`, read no reduced-motion preference and set
no ARIA. `MotionConfig` never reaches a `useSpring` value (14.0.0 source), so
wrapping them changes nothing — adapt the item or write the counter.
Standing: recorded — no check reads a counter.

## Motion+ is paid, and not in `motion`

Ticker, Carousel, AnimateNumber, splitText, ScrambleText, Cursor and
Typewriter are Motion+ components (https://motion.dev/plus): a paid
membership, installed from a private registry with a token. None of them
ships in the open-source `motion` package (14.0.0 checked), so importing one
from `motion` or `motion/react` fails. Only Motion's versions are paid: split
and scrambled text are free elsewhere — GSAP's SplitText and
ScrambleTextPlugin ship in the standard `gsap` package, and anime.js core has
`splitText()` and `scrambleText()` (`references/animejs.md`). Without a
membership, build the marquee or carousel by hand (and give it the SC 2.2.2
pause control `a11y-audit` names); a number roll follows the counter section
above. Standing: recorded.
