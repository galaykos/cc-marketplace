# Sprite sheet layout, `steps()`, and the rAF loop — worked reference

Read this alongside `../SKILL.md`. It expands the three things the body keeps compact:
the sheet layout math, a fully worked CSS `steps()` loop, and a canvas
`requestAnimationFrame` player with a ping-pong variant.

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
