# Scroll acts — the scene scroll drives, and what it costs

`orchestration-decision.md` decides WHETHER scroll motion earns its cost and WHICH engine
drives it. This file owns what the engine then drives: an ACT — a scene held while scroll
moves through it, rather than a reveal that fires as scroll passes.

Three acts, and nothing else belongs here. Each states its mechanism, when it earns its cost,
and the three states it owes: reduced-motion, no-JS, and failure. An act missing any of the
three does not ship.

The engine, the contract and the budget stay with the SKILL.md and gsap.md — this file never
re-teaches ScrollTrigger.

## Act 1 — the pinned act

**Mechanism.** A scene is pinned while scroll drives progress through it. The page does not
advance until the act completes; scroll becomes the act's transport rather than the page's.

**When it earns its cost.** The sequence is part of the argument — a process with ordered
steps, a comparison that only reads in order, a claim built from parts. Never to make a static
section feel longer.

- **Reduced-motion:** no pin. The scene's states render as stacked content in document order,
  and scroll behaves natively. The act's information survives as sections.
- **No JS:** the same stacked content. The pin is the enhancement; the stack is the page.
- **Failure:** a pin that cannot compute its bounds releases and the scene scrolls normally.
  Never a scene the visitor is trapped inside.

## Act 2 — the scrubbed frame sequence

**Mechanism.** A run of pre-rendered frames is decoded and drawn to a canvas, indexed by
scroll progress through a pinned range. Scroll position maps to frame index; the visitor moves
through the frames in either direction at their own rate.

**When it earns its cost.** The frames carry something a static image cannot: a transformation,
a passage of time, an assembly, a rotation the visitor needs to control. A sequence whose
frames are decorative is a very expensive fade.

**Signature eligibility.** A sequence the visitor can only watch advance is an entrance reveal
with more frames — it counts toward `maximal`'s floor 1 (the tier-reach count) and never toward the
signature floor. It becomes signature-grade only when the visitor can scrub back and forth, hold a
state, and compare states, which is the "interrogate, operate, compare, steer" of the
three-part test. The test itself lives in
`plugins/craft-layer/skills/creative-direction/references/moves-taxonomy.md` — apply it, do
not restate it.

### Budget

The numbers are policy caps and live in
`plugins/craft-layer/skills/motion-tiers/references/tier-budgets.md`. They are SEPARATE from
the cumulative motion-JS budget: a sequence is images, the budget meters script, and neither
buys the other. Both bind.

- ≤ 1.5 MB transferred for the whole sequence
- ≤ 90 frames
- AVIF primary with a WebP fallback
- longest edge ≤ 1600 px
- decode-ahead window ≤ 8 frames held as `ImageBitmap`
- nothing fetched until the act is within one viewport of entry

**Over-cap remedy: fewer frames, never a longer download.** A sequence over budget drops
frames across the same scroll range — the act gets coarser, not heavier. Rendering at a lower
resolution or stretching the scroll range does not discharge the cap.

**Slow networks opt out entirely.** Under `save-data`, or an `effectiveType` of `4g` or below,
the sequence does not load and the static path ships. A visitor on a metered connection has
already told you the answer.

**Memory.** Every `ImageBitmap` outside the decode window is `.close()`d. An unreleased window
is a GPU-memory leak, and it is the failure this budget line exists to prevent — the transfer
cap alone does not catch it, because the bytes are already spent by then.

### The three states

- **Reduced-motion:** the sequence's FINAL frame, plus the information the sequence conveys,
  carried in text or a static graphic beside it. The final state is what
  `scroll-orchestration/SKILL.md` mandates for every scroll surface; the information is what
  `moves-taxonomy.md` mandates for every signature. One frame satisfies the first and not the
  second, which is why both are named here.
- **No JS / pre-decode:** the FIRST frame, shipped as a real eager `<img>`. It is the poster,
  it is eligible as the LCP element, and it is what a print, a prerender or a full-page
  screenshot captures.
- **Failure:** a frame fetch that fails or aborts mid-scrub pins the act to the last decoded
  frame and stops. It never blanks the canvas, never blocks scroll, and never retries in a
  loop. A half-loaded sequence must fail to something readable.

The reduced-motion frame and the poster frame are DIFFERENT frames. Shipping one frame for
both means either the poster spoils the act or the reduced-motion state stops mid-argument.

## Act 3 — the scroll-revealed panel

**Mechanism.** Content overlays the page and holds attention as scroll reaches it — dimming
what is behind, occupying the viewport, releasing when scroll continues.

**When it earns its cost.** A single point in the argument deserves the whole viewport and
loses its force inline. Rare by construction: two of these on one page is a layout, not
an emphasis.

**It is not a dialog.** The panel stays in normal document order with no focus trap, no focus
steal, and no `role="dialog"`. A visitor scrolling with the keyboard must never be captured by
something they did not open. Where the concept genuinely needs a focus-trapping dialog, it
opens on a user ACTION — a click or a key — and scroll may set that moment up but never
triggers it.

This rule is graded by `agents/craft-reviewer.md`'s scroll-act checklist item — read there, not
merely asserted here. It is NOT enforced by
`plugins/craft-layer/template/craft-gates/gates.spec.ts`, whose tab-stop assertion is scoped to
`table, [role="grid"], [role="listbox"]` and would not see a scroll-triggered trap. Do not
treat a green gate run as evidence this rule held.

- **Reduced-motion:** the panel is an inline section. No overlay, no dim, no hold.
- **No JS:** the same inline section, in document order.
- **Failure:** a panel that cannot bind to its scroll range renders inline rather than
  half-overlaid.

## Anti-patterns

- **Act as pacing** — pinning a scene so the page feels longer. The pin costs the visitor
  their scroll; it has to buy them something.
- **Sequence as fade** — 90 frames to accomplish a cross-dissolve.
- **Play-forward sequence sold as a signature** — passes two of the three tests and is still
  an entrance.
- **One frame for both static states** — the poster spoils the act, or the reduced-motion
  reader is left mid-argument.
- **Scroll-triggered dialog** — a focus trap the visitor never opened, in a page whose gate
  run does not look for it.
- **Named site patterns** — this file holds mechanisms with budgets. The moment it starts
  listing "the split-scroll gallery from site X" it has become the idea-catalog
  `moves-taxonomy.md` forbids one directory over.
