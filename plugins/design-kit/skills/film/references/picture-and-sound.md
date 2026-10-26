# Picture and sound

## Picture

- Hold each word at least 0.3 s and each line at least 0.7 s (`film.py check` enforces both for
  every line in `timing.json`); cut words the picture already says.
- Text eases in at reading speed and leaves fast, on curves — never linear. An outgoing line is
  gone before the incoming one takes its space.
- Every click or keystroke causes a visible change. No particles, gradients or glitch effects that
  are not about the content.
- No flat screenshots on screen: rebuild panels, icons and text in HTML/SVG so each part moves.
- Holds keep a little motion; no still frame over 0.5 s.
- Alternate close-ups, wide shots and full-screen type; never one layout in back-to-back scenes.
- Pace slower than your default: creators correcting generated films most often say "too fast".
- No corner chrome — timecodes, frame counters, watermarks, a progress bar, labels in the corners.

## Camera

- Zoom in log space: a linear zoom accelerates visibly as it closes in.
- Zooming toward an off-centre point swings the frame sideways; move the camera's focus first.
- Ease a closing iris by area, not radius, or it snaps shut at the end.

## Chromium traps (each reported by creators rendering this way)

- `will-change` on an element the camera scales rasterises it at its small size: text blurs.
- `opacity` or `filter` on a `transform-style: preserve-3d` element flattens it (CSS groups it), so
  both faces of a card show. Fade a wrapper instead.
- A child set to `visibility: visible` stays visible inside a hidden parent.
- Footage inside the page: design-kit's preview server and `python -m http.server` answer no
  Range requests, so `<video>` cannot seek. Load the clip as a blob URL, re-encode it all-intra
  (`ffmpeg -i in.mp4 -c:v libx264 -g 1 -an clip.mp4`) so every frame is a seek target, and wait
  for `seeked` before each capture.
- WebGL in headless Chromium with no GPU: Chrome no longer falls back to SwiftShader on its own, so
  WebGL context creation fails unless you launch with `--use-gl=angle --use-angle=swiftshader-webgl
  --enable-unsafe-swiftshader` (Chromium's `docs/gpu/swiftshader.md`; the switch exists because the
  fallback is a security risk — use it only for this render). Check one frame renders first.

## Sound

Sound first, then cut the picture to it. With `sound: silent`, skip this section and the sync checks.

- Synthesized music: compose on the grid `film.py music` writes; run `film.py beats music.wav --verify`
  only to confirm the render matches it.
- Supplied music: `film.py beats track --write` stores the beats and the drop; find each key
  action's frame against them.
- Hard cuts only on a beat. An action starting a little early so it LANDS on the beat is fine;
  `check` measures the declared action time.
- Sound effects only for what happens on screen: one quiet swish per scene change, one click or hit
  per action, a little above the music. Place each by its peak, not its file start:
  `film.py peak sfx.wav` gives the offset to subtract.
- Duck the music under any voice. If the narrator pauses, the picture keeps moving.
- Master: `film.py loudness mix.wav --out film.m4a` (two-pass loudnorm to −14 LUFS, ≤ −1 dBTP,
  re-measured after the AAC encode, before/after printed for the ledger).

## Hand-rolled capture (no renderer)

The page exposes `window.seek(t)`, which draws exactly the frame for time `t` and resolves once
images and video have decoded. The recorder walks `t = n / fps` (times `N` for subframes) in any
order — out-of-order calls must give the same pixels, which is how you test the contract:

```js
for (let n = 0; n < Math.round(duration * fps) * N; n++) {  // [0, duration): no duplicated end frame
  await page.evaluate(t => window.seek(t), n / (fps * N));
  await page.screenshot({ path: `.frames/${String(n).padStart(6, '0')}.png` });
}
```

Launch at the format's size with `deviceScaleFactor` 2 for UI text, and load the page with
`?static=1` so design-kit's preview server injects no live-reload stream. design-kit:motion's
recorder steps a fake clock instead; it suits a designed stage, not a film with random access.

## Encode and mux

```bash
# subframes: render at fps×N, blend N, keep one of every N
ffmpeg -framerate 240 -i .frames/%06d.png -vf "tmix=frames=4,select='not(mod(n\,4))'" -r 60 \
  -c:v libx264 -crf 16 -pix_fmt yuv420p -an picture.mp4
# mux the mastered audio
ffmpeg -i picture.mp4 -i film.m4a -c:v copy -c:a aac -ar 48000 -b:a 192k -shortest \
  -movflags +faststart film-16x9.mp4
```

A 9:16 cut is its own layout pass in the same timeline, not a crop of the 16:9 render.
