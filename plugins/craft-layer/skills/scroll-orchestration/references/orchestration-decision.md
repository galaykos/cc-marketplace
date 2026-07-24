# The scroll-orchestration decision

Read on demand from scroll-orchestration. This is the long form of the SKILL's
"does scroll motion earn its cost?" gate: when to orchestrate scroll at all, which
effect to reach for, and the one contract that keeps them from fighting.

## Does scroll motion earn its cost?

Scroll motion is expensive: main-thread work, a KB budget, an accessibility surface,
and a maintenance cost. Add it only when it does a JOB the static page cannot:

- **Earns it:** communicating progress through a long narrative, revealing dense
  content in digestible beats, a signature hero moment, spatial storytelling where
  position carries meaning.
- **Does NOT earn it:** "premium feel" with no content job, motion on a
  utility/dashboard/form surface, parallax on a page users came to read fast, smooth
  scroll added because a competitor has it.

Default to native scroll. Make the surface justify every effect against its cost.

## Scrub vs trigger vs parallax

Three distinct mental models — pick ONE per scene, never blend:

- **Trigger (play-on-enter)** — the animation runs once when the element enters, on
  its own clock. Use for reveals and one-shot emphasis. In GSAP: `toggleActions`
  (see gsap.md). In CSS: `view()` timeline. Cheapest; the default for reveals.
- **Scrub (progress-bound)** — animation progress is tied to scroll position and
  scrubs both ways. Use for progress bars, draw-on effects, a scene that reads as
  "you control it." In GSAP: `scrub: <number>` for smoothing. Do not also set
  `toggleActions` on the same trigger — one model per trigger.
- **Parallax (differential motion)** — layers move at different rates to fake depth.
  It is scrub applied to `transform` on multiple layers; keep displacement small,
  compositor-only (`transform`/`opacity`), and never on text users must read.

Rule of thumb: reveal → trigger; "I control the timeline" → scrub; depth → parallax.
When two feel plausible, pick the cheaper (trigger < scrub < parallax).

## The single-scroll-contract rule

The one non-negotiable: exactly ONE source of truth for scroll position per axis.
Mixing native scroll, a smooth-scroll lib, and scroll-driven CSS causes drift and
jitter because each reads a different position. The full failure mode is documented
in `plugins/craft-layer/skills/motion-tiers/references/gotchas.md` — do not
re-derive it; the two legal contracts are:

1. **Native scroll + CSS scroll-driven** (`css-scroll-driven.md`) — browser is the
   single truth; zero JS. The reduced-bundle default.
2. **Lenis feeding ScrollTrigger** (`lenis-substrate.md`) — Lenis owns position,
   ScrollTrigger reads it via `lenis.on('scroll', ScrollTrigger.update)`.

Never run both on the same axis. A horizontal gallery may use contract 2 on X while
the page uses contract 1 on Y only if the axes never overlap for one element.

## Engine sizing (feed the SKILL's budget)

- Native CSS scroll-driven ≈ 0KB JS, off-main-thread — always the reduced-bundle and
  below-the-fold choice.
- Lenis ≈ 3KB gzip; ScrollTrigger ships inside GSAP (size it from gsap.md). Both count
  against the surface motion budget owned by `motion-tiers`.
- ScrollTrigger mechanics — one trigger per scene, `.refresh()` after layout, cleanup,
  `gsap.matchMedia()` — live in
  `plugins/ui-ux/skills/motion-best-practices/references/gsap.md`. Reference, never copy.

## Reduced-motion is part of the decision

A scene with no `prefers-reduced-motion` answer is not done. Trigger reveals collapse
to their visible end state; scrub/parallax are removed (not just slowed); Lenis is
never instantiated. See `SKILL.md` and `lenis-substrate.md` for the exact gates.
