# Scrub vs trigger vs parallax

The one scroll decision `../SKILL.md` does not make. Its "Choose the engine"
section picks Lenis+ScrollTrigger vs native CSS scroll-driven — a different axis.
This picks the mental model.

Four other sections used to live here — whether scroll motion earns its cost, the
single-scroll-contract rule, engine sizing, and reduced-motion — each restating a
section of the SKILL body heading-for-heading, including the same KB figures.
They were deleted on 2026-07-27 rather than kept in sync by hand.


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
