# Entrance choreography — the defaults that make motion read designed

Read on demand from motion-best-practices. The sibling digests own library
idioms; this file owns the SEQUENCING decisions — what moves when, how far, in
what order — which no library API makes for you. Durations and easings
themselves come from the motion token scale (the `design-tokens` skill); this
file decides how those tokens are arranged in time. Animation that skips these
decisions reads as applied — an effect dropped onto a finished page — rather
than designed.

## Order follows hierarchy, not the DOM

Entrance order is a claim about what matters: the container or primary element
first, supporting siblings after. An order that is really DOM order — or worse,
alphabetical — tells the eye nothing, and the sequence reads as accidental
because it is. Decide it the way you decided the visual hierarchy; it is the
same decision, played in time.

## Stagger numbers

- Sibling stagger: 40–80ms between items. Below ~40ms the steps fuse into one
  blob; above ~80ms the list feels like it is waiting for itself.
- Cap the whole sequence at ~0.8–1s. Larger groups shrink the interval to stay
  under the cap — twelve cards at 80ms is a full second before the last one
  exists, and nobody forgives that twice.

## Distance, opacity, and the fallback rule

- Entrance translate distance comes from the spacing scale — 8–24px. A
  translate that is also a spacing step moves in the rhythm the layout already
  established; an arbitrary 37px slide is a magic number that happens to move.
- Opacity starts at ~0.2, not 0: a fully invisible element whose animation
  fails to fire stays invisible, while a 0.2 start degrades to slightly-dim
  content instead of a blank page — the fallback-safe rule the craft skills
  already apply.

## Overlap, proportion, exits

- Overlap successive tweens — the next starts at ~60–80% of the previous, not
  after it. Strictly chained motion reads mechanical; real things do not queue.
- Duration is proportional to distance and size: small elements fast, a
  full-screen surface slower. One duration for everything makes big moves feel
  rushed and small ones sluggish at the same time.
- Exits run 20–30% shorter than their entrances — leaving needs less
  explanation than arriving.

## One easing family

One easing family per build. Mixed curve families on a page read as components
imported from different products — which, when easing is picked per-tween, is
exactly what happened.

## Reduced motion

All of the above is choreography for people who can watch it. The SKILL body's
`prefers-reduced-motion` rule is the hard gate: under `reduce`, the sequence
collapses to instant appearance or an opacity-only fade, in a single step.
