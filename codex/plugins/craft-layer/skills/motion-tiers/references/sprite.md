# Tier 4 — sprites / sprite-sheets

Authoring detail behind tier 4 of `../SKILL.md`. Read on demand.

> **Last verified: 2026-07-27** — codec and byte claims (WebP/AVIF sizing, the
> sheet-vs-video crossover point).

## Pick the tier before you pick the sheet

Tier 4 is a strip of pre-rendered frames
flipped in sequence. It is the heaviest tier by bytes and the least flexible at runtime,
so reach for it only when the lighter tiers genuinely fail the fit test. This reference is
authoring guidance; generating, packing, or trimming the sheet itself is out of scope —
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

The worked layout note and the full snippets are in the second half of this file
(from "Sheet-layout note") — read them before writing the CSS or JS.

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

The full canvas `draw()` and a ping-pong variant are in the second half of this file.

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

---

## Sheet-layout note

A sprite sheet is a grid of equal-sized cells. Pin down four numbers before exporting:

- `cell_w`, `cell_h` — the pixel box of ONE frame, identical for every cell.
- `cols`, `rows` — how the frames are packed. A single row (`rows = 1`) is the easiest
  to drive because you only ever move along the x-axis.
- `frames` — total frame count (`cols × rows` minus any empty trailing cells).
- `fps` — playback rate; the loop's total duration is `frames / fps` seconds.

Horizontal strip vs grid:

```
strip (rows = 1):   [0][1][2][3][4][5][6][7]          sheet width  = frames × cell_w
grid  (cols = 4):   [0][1][2][3]                       sheet width  = cols  × cell_w
                    [4][5][6][7]                       sheet height = rows  × cell_h
```

For a strip, the CSS offset for frame `i` is `-i × cell_w` on x. For a grid, it is
`-(i % cols) × cell_w` on x and `-floor(i / cols) × cell_h` on y. Prefer the strip unless
the frame count makes the sheet too wide for your build tooling or the GPU max texture
size — then wrap to a grid.

## Worked CSS `steps()` loop (horizontal strip)

```css
:root {
  --cell: 96px;      /* cell_w = cell_h */
  --frames: 25;
  --fps: 24;
}
.sprite {
  width: var(--cell);
  height: var(--cell);
  background-image: url("effect.webp");
  background-repeat: no-repeat;
  /* sheet is (frames × cell) wide, one cell tall */
  background-size: calc(var(--cell) * var(--frames)) var(--cell);
  animation: sprite-play calc(var(--frames) / var(--fps) * 1s)
             steps(var(--frames)) infinite;
}
@keyframes sprite-play {
  /* end position pulls the strip left by its full width, minus the last cell
     that steps() already accounts for */
  to { background-position: calc(var(--cell) * var(--frames) * -1) 0; }
}

/* play once, then hold the final frame */
.sprite--once {
  animation-iteration-count: 1;
  animation-fill-mode: forwards;
}
```

`steps(N)` (equivalently `steps(N, end)`) makes `background-position` JUMP between the N
cell offsets rather than interpolate, which is what produces crisp frame flips. Using any
easing curve here would show blended half-frames.

## Canvas `requestAnimationFrame` player

Use this when you need variable speed, play/pause, or per-frame drawing a CSS animation
cannot express. It draws from a single `Image` onto a `<canvas>` and throttles to a fixed
fps independent of the display refresh rate.

```js
function createSpritePlayer(canvas, { src, cellW, cellH, frames, cols, fps }) {
  const ctx = canvas.getContext("2d");
  const img = new Image();
  const step = 1000 / fps;
  let frame = 0, last = 0, raf = null, playing = false;

  function draw(i) {
    const sx = (i % cols) * cellW;
    const sy = Math.floor(i / cols) * cellH;
    ctx.clearRect(0, 0, cellW, cellH);
    ctx.drawImage(img, sx, sy, cellW, cellH, 0, 0, cellW, cellH);
  }

  function tick(t) {
    if (t - last >= step) { frame = (frame + 1) % frames; draw(frame); last = t; }
    if (playing) raf = requestAnimationFrame(tick);
  }

  function play() {
    if (playing) return;
    if (matchMedia("(prefers-reduced-motion: reduce)").matches) { draw(0); return; }
    playing = true; last = 0; raf = requestAnimationFrame(tick);
  }
  function stop() { playing = false; if (raf) cancelAnimationFrame(raf); raf = null; }

  img.onload = () => draw(0);   // paint a poster frame immediately
  img.src = src;
  return { play, stop, draw };
}
```

Always call `stop()` on component unmount (React `useEffect` cleanup, Vue
`onUnmounted`, or `disconnectedCallback`) — an orphaned `requestAnimationFrame` keeps the
GPU and battery awake for a canvas no one can see.

## Ping-pong (yo-yo) variant

For an idle that eases back and forth instead of hard-cutting from last frame to first,
bounce the index between the ends instead of wrapping with modulo:

```js
let dir = 1;
function advance() {
  frame += dir;
  if (frame === frames - 1 || frame === 0) dir *= -1; // reverse at the ends
  return frame;
}
```

Swap `frame = (frame + 1) % frames` in `tick` for `frame = advance()`. The reduced-motion
poster-frame rule is unchanged: if the user prefers reduced motion, draw frame 0 once and
never start the loop.
