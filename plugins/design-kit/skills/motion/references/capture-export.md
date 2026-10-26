# Capture, checks and export — the recording half of `motion`

Never screen-record in real time: dropped frames and a visible seam. Step a fake clock and
screenshot every frame. Write the recorder per project (Node + Playwright); nothing in this plugin
ships one yet.

## Deterministic capture

Load the page as `?capture&static=1` — `capture` hands the clock to the recorder, `static=1` keeps
design-kit's preview server from injecting its live-reload stream, which would keep the page from
settling. Write frames into `.design-kit/motion/<slug>/.frames/`, a dot directory the server neither
lists nor watches.

Three details decide whether the loop is smooth and the seam clean; all three are in the snippet.

```js
await page.clock.install({ time: 0 });
await page.goto(url + '?capture&static=1', { waitUntil: 'load' });
await page.evaluate(() => document.fonts.ready);
await page.clock.pauseAt(10000);
const loopTime = [];
for (let i = 0; i < frames; i++) {
  // 1. whole milliseconds that average exactly 1000/60 (17, 17, 16, ...); runFor(1000 / 60) drifts
  const dt = Math.round((i + 1) * 1000 / 60) - Math.round(i * 1000 / 60);
  await page.clock.runFor(dt);
  loopTime.push(await page.evaluate(([i, PRE, dt]) => {
    if (i === PRE) window.__start();          // 2. start inside the same evaluate as the seek
    if (i >= PRE) window.__tick(dt / 1000);   // 3. the page clock advances here, never through rAF
    const now = performance.now();
    for (const a of document.getAnimations()) {  // CSS transitions follow the fake clock
      a.__m ??= window.__mark;                    // each one keeps the mark it was created under
      a.pause(); a.currentTime = Math.max(0, now - a.__m);
    }
    return i >= PRE ? window.__lt : 0;
  }, [i, PRE, dt]));
  await page.screenshot({ path: `${out}/${String(i).padStart(5, '0')}.png` });
}
```

Page side, in `?capture`:

- `__start()` adds the `in` class. Every change of the stage's state classes (`in`, `out`, the
  reset) sets `window.__mark = performance.now()`, so each transition is seeked from the moment it
  was created; transition delays (`--d`) are counted inside `currentTime`.
- `__tick(dt)` advances the loop time, runs the cycle phases, draws every story and accent, and
  sets `window.__lt`.
- Loops that never end (shimmer, marquee) run on the JS clock, not infinite CSS keyframes, which
  the seek would restart.

`PRE` is ~15 frames recorded before the start so the page settles. Save `loopTime` beside the
frames.

- Viewport is the frame size; `deviceScaleFactor = min(1920 / W, 1200 / H)` so the long side hits
  the X limit. Screenshots round to whole pixels and can come out one pixel odd (1745×1200 for a
  1440×990 frame); the MP4 crop to even dimensions handles it, so expect 1744×1200.
- **The export window** starts at frame `PRE − 1` (loop time 0, the empty state) and spans exactly
  `cycle × 60` frames. Record at least 10 frames past it for the seam check.

## Checks on the recorded frames — before encoding

- **Overflow.** Test against the containers' real shapes, rounded corners included: render a mask
  from the page itself (every container a solid white shape with its exact radii on black, plus
  its shadow area), grow it by 2 px to skip antialiasing, compare only the black pixels. A `?still`
  used here is rendered at the capture's device scale factor, not the 2x of the fidelity check.
  - App frame: every pixel outside the joined surfaces equals the empty first frame in every frame
    of the cycle (PSNR `inf`).
  - Separate cards: during the story phase every pixel outside the cards (and their shadows) equals
    the `?still` frame. Intro frames are excluded — the cards' own rise moves pixels there; the
    contact sheet must show contents moving with their card, never ahead of it or outside it.
- **Seam.** The first frame of the export window equals the frame one cycle later.
- **Empty beat.** Every frame of the empty beat equals the frame before `__start`. The seam check
  cannot catch JS state that failed to reset — both its frames sit at loop time 0; this one can.
- **Rest.** The last frame before the dissolve equals `?still` at the capture scale, proving every
  story came back to the design.
- **Contact sheet.** Tile frames at key moments (empty, mid intro, landed, several points through
  the stories, mid dissolve, end) and look for overflow, ghosting, pops, and stories too timid to
  notice.

## Formats

| File | Spec |
|---|---|
| `<name>-x.mp4` | H.264, `yuv420p`, 60 fps, CRF 14–15, preset slow, `+faststart`, max 1920×1200, even dimensions |
| `<name>-loop.gif` | 960 px wide, 15–20 fps, about 2–3 MB, for a website |
| `<name>-800x500.gif` | always delivered. Wide empty borders (most card and bento frames): crop to the content with ~40 px margin at exactly 1.6:1. Content filling the frame: fit and pad with the page background colour. On a photo background always crop, so no flat band sits beside the photo. 20 fps, 12 if heavy |

```bash
ffmpeg -start_number $A -framerate 60 -i .frames/%05d.png -frames:v $N \
  -vf "crop=trunc(iw/2)*2:trunc(ih/2)*2" -c:v libx264 -preset slow -crf 15 \
  -pix_fmt yuv420p -movflags +faststart out/name-x.mp4

ffmpeg -start_number $A -framerate 60 -i .frames/%05d.png -filter_complex \
  "trim=end_frame=$N,fps=20,scale=960:-2:flags=lanczos,split[a][b];\
   [a]palettegen=max_colors=192:stats_mode=diff[p];\
   [b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle" -loop 0 out/name-loop.gif
```

For the 800×500 GIF, add
`scale=800:500:force_original_aspect_ratio=decrease,pad=800:500:(ow-iw)/2:(oh-ih)/2:color=<page bg>`
before `split`.

- Keep bayer dithering whenever a photo is in frame; without it photos band.
- A GIF too heavy: lower the frame rate or colours before lowering the size.
