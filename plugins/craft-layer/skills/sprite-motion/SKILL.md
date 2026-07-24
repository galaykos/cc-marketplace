---
name: sprite-motion
description: Use when animating a pre-rendered raster frame sequence that is too custom for Lottie yet too short to justify video — sprite sheets played with CSS steps() or a requestAnimationFrame loop, covering sheet-format basics, a poster-frame prefers-reduced-motion fallback, and a KB size budget. Tier 4 of craft-layer motion-tiers.
---

## Pick the tier before you pick the sheet

Sprite motion is tier 4 of `../motion-tiers/SKILL.md` — a strip of pre-rendered frames
flipped in sequence. It is the heaviest tier by bytes and the least flexible at runtime,
so reach for it only when the lighter tiers genuinely fail the fit test. This skill is
authoring GUIDANCE; generating, packing, or trimming the sheet itself is out of scope —
that is design-tool or build-step work, not something you hand-roll here.

Run the decision top-down and stop at the first row that fits:

- **CSS / SVG animation** — transforms, opacity, path morphs: anything parametric and
  resolution-independent. Cheapest, ships no extra asset, and is the default.
- **Lottie** — vector art exported from After Effects (`lottie-web` / `dotLottie`).
  Scales crisply, stays tiny while the source is vector, and is scriptable. Prefer it
  over a sprite whenever the animation can be expressed as vectors.
- **Sprite sheet** — pre-rendered raster frames no vector tool can express: textured
  explosions, hand-painted cel animation, per-pixel shading, a short looping character
  idle. Fixed resolution, deterministic playback, zero runtime math.
- **Video** (`<video muted autoplay loop playsinline>`, WebM/AV1) — long footage,
  photographic content, or any clip past a few seconds where a sheet blows the budget.

The sprite sits between Lottie and video: choose it only when the frames are raster AND
the sequence is short. If either premise breaks — the art is really vector, or the clip
runs long — step back up or down a tier instead of forcing a giant sheet.

## Sheet-format basics

- **Layout.** A horizontal strip (one row) is simplest to drive; a grid packs more
  frames but forces you to advance both axes. Keep every cell the SAME width and height
  so one offset step moves exactly one frame.
- **Frame count.** Fewer frames = smaller file. Most UI loops read fine at 12–24 fps;
  you rarely need 60 discrete frames. Trim leading/trailing duplicate frames.
- **Encoding.** Prefer WebP (or AVIF) over PNG for photographic or gradient frames — it
  typically halves the bytes. Reserve PNG for hard-edged pixel art needing lossless
  transparency. Never ship a sheet as a chain of separate `<img>` requests.
- **Dimensions.** Size the on-screen frame to its real display box; a 512px sheet cell
  scaled down to a 48px icon wastes bytes and memory every frame.

The worked layout note and the full snippets live in
`references/sheet-and-loop.md` — read it before writing the CSS or JS.

## Play it with CSS `steps()`

For a fixed-fps loop with no scrubbing, CSS is the whole engine. Put the strip in
`background-image`, make the box exactly one cell, and animate `background-position` with
`steps(N)` so it JUMPS between frames instead of smearing between them:

```css
.spinner {
  width: 96px; height: 96px;                 /* one cell */
  background: url("loader.webp") 0 0 / 2400px 96px; /* 25-frame strip */
  animation: play 1s steps(25) infinite;     /* steps() = no interpolation */
}
@keyframes play { to { background-position: -2400px 0; } }
```

The `steps(25)` timing function is the sprite-specific trick: a normal ease would blend
positions and show half-frames. Match the step count to the frame count exactly.

## Or drive it with `requestAnimationFrame`

Reach for JS when you need variable speed, play/pause, ping-pong, or a canvas target.
Advance an index on a fixed frame interval and cancel the loop on cleanup — never leave a
rAF running after the element unmounts:

```js
let frame = 0, last = 0, raf;
const step = 1000 / 24;                       // 24 fps
function tick(t) {
  if (t - last >= step) { frame = (frame + 1) % FRAMES; draw(frame); last = t; }
  raf = requestAnimationFrame(tick);
}
raf = requestAnimationFrame(tick);
// teardown: cancelAnimationFrame(raf);
```

The full canvas `draw()` and a ping-pong variant are in `references/sheet-and-loop.md`.

## `prefers-reduced-motion`: freeze to a poster frame

A flipping sprite is exactly the large, repetitive motion that triggers vestibular
discomfort, so it MUST have a reduced-motion path — this is an accessibility requirement,
not polish. The right fallback is a POSTER FRAME: stop advancing and hold one
representative still frame (usually frame 0 or the resting pose).

```css
@media (prefers-reduced-motion: reduce) {
  .spinner { animation: none; background-position: 0 0; } /* freeze to frame 0 */
}
```

In JS, gate the loop the same way and paint one frame instead of starting `tick`:

```js
if (matchMedia("(prefers-reduced-motion: reduce)").matches) draw(0);
else raf = requestAnimationFrame(tick);
```

Do not merely slow the loop or drop to instant looping — hold a single static frame.

## Size budget

Bytes are the sprite's failure mode; set a ceiling before you export.

- **Soft ceiling: ~150 KB** for a decorative loop (spinner, small idle). Comfortable on
  any connection, so it can load eagerly.
- **Hard ceiling: ~500 KB** for a hero/feature sprite. Past this, lazy-load it below the
  fold and never block first paint on it.
- **Over ~500 KB, the sprite is the wrong tier.** A big raster sheet that heavy almost
  always loses to a muted looping WebM/AV1 video, which compresses inter-frame
  redundancy the sheet cannot. Switch tiers rather than shipping the megabyte.

Estimate up front: `cell_w × cell_h × frames`, then apply your codec's rough
compression ratio. If the estimate clears the ceiling, cut frames, shrink the cell, drop
to WebP/AVIF, or move to video — in that order.

## Anti-patterns

- Shipping a looping sprite with NO `prefers-reduced-motion` poster frame — an
  accessibility failure, not a style choice.
- Using a non-`steps()` timing function, so frames smear together instead of flipping.
- Leaving a `requestAnimationFrame` loop running after unmount (memory + battery leak);
  always `cancelAnimationFrame` on teardown.
- Loading frames as many separate `<img>` requests instead of one sheet.
- Rendering a sheet cell far larger than its on-screen box, paying for pixels nobody sees.
- Forcing a long or photographic clip into a sprite when a muted `<video>` loop is
  smaller and simpler.
- Reaching for a sprite when the art is actually vector — that is Lottie's tier.
