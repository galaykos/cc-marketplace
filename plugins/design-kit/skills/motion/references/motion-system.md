# Motion system — kinds, stories, cycle and values

Every timing, distance and curve in a `motion` build comes from the **Values** table at the end.
Edit that table to restyle the system; the rest follows.

## Loading choreography

Elements rise from below and resolve from blur to sharp, staggered.

| Kind | Use for | From |
|---|---|---|
| `card` | separate cards (bento, card sets) as a whole, with their shadow | `translateY(24px)`, `scale(0.985)`, `blur(6px)`, opacity 0 |
| `up` | text, headers, values, rows | `translateY(10px)`, `blur(4px)`, opacity 0 |
| `down` | top toolbars, top bars | `translateY(-8px)`, `blur(4px)` |
| `left` | sidebar items, list rows, labels | `translateX(-10px)`, `blur(4px)` |
| `pop` | icons, badges, avatars, buttons, dots | `scale(0.82–0.88)` from the element's own centre, `blur(4px)` |
| `photo` | images | skeleton shimmer first, then `blur(14px) saturate(0.6)` to sharp |
| `wipe` | bars, fills, highlights | left-to-right `clip-path` reveal in pixels on the full-stage unit: right inset from `stageW − x` (zero width, no sliver) to `stageW − (x + w)`; top and bottom insets stay `y` and `stageH − (y + h)` |
| `line` / `grow` | rules, ticks, timelines | `scaleX(0)` / `scaleY(0)` from their start edge |
| `donut` | rings, gauges | conic mask sweeping clockwise from 12 o'clock |
| `tray` / `rise` | sheets, trays, folders | slide up 40 px from inside the container's bottom edge, clipped by it |
| `fade` | layers that sit under another layer | opacity only |

- **Order.** Containers load in reading order, 80–90 ms apart: for an app frame, the regions
  inside its static surfaces; for separate cards, the cards, each starting ~0.15 s before its own
  contents. Inside a container: header, labels, values, visuals. Items in a group stagger 30–80 ms.
- **Skeletons match the real shape** and sit 1 px inside it, so no halo shows around the loaded
  image.
- Data bars, meters and highlights fill like progress bars: a `wipe` with the in-out curve,
  0.7–1.1 s.

## Stories

| Visual | Story |
|---|---|
| Stack of items (leads, notifications, files) | a new item lands on top with a blur, the others step back one slot, the last one leaves |
| Line or area chart | a scrubber glides across, dots ride the curves, the tooltip value counts; or the line redraws, a marker pops, numbers count with it |
| Bar chart, equalizer, grid of cells | bars breathe like a live feed and settle back to the design heights; a dot and tooltip ride the active bar |
| Donut, gauge | segments ease outward one at a time and back; or the ring sweeps again |
| Table, list | a cursor inspects rows, the row highlights, a preview loads; or a soft highlight steps down the rows |
| Calendar, scheduler | a highlight searches for an open slot, the event glides into it, then back |
| Flow, connectors, pipeline | pulses travel along connectors in flow direction; nodes light as a pulse passes; dashed lines march |
| AI prompt, form | the prompt deletes and retypes, chips evaluate one by one, the result appears with a blur |
| Counters, KPIs | numbers count up together with the chart that drives them |
| Profile, long content | the content scrolls slowly inside its clip, then returns |
| Logo row | a continuous marquee moving exactly one full set per loop, so it repeats seamlessly |
| Media player | the playback handle and progress advance while the play button pulses |

Rules:

- **Helpers the story needs** (a cursor, duplicate stack items, extra pulses) match the design's
  style and are hidden in `?still`.
- **Typing** reveals the exported text layer glyph by glyph: find glyph boundaries from the empty
  alpha columns of the text PNG, step one glyph every 45–70 ms, show a caret at the edge that
  blinks once a second while idle. Deleting runs the same steps backwards, a little faster.
- **Counters** need live text in the design's font at its exact size and weight, landing on the
  design's exact text at rest.
- **Text-only cards get no story** in a showcase; they rise with their card and rest. Calm screens
  (a document dashboard) may rest after load if the user prefers — ask once.
- **One story per card, 3–8 s.** A short story may repeat within one cycle and a second run may
  vary a beat; every run ends at rest before the dissolve.
- Stories are eased keyframe tracks on the JS clock, so capture stays deterministic:

```js
// [[time, value], ...] eased per segment; values may be numbers or arrays
function track(keys, t, ease = easeInOut) {
  if (t <= keys[0][0]) return keys[0][1];
  for (let i = 1; i < keys.length; i++) {
    const [t1, v1] = keys[i], [t0, v0] = keys[i - 1];
    if (t <= t1) {
      const k = ease(Math.min(1, (t - t0) / (t1 - t0 || 1)));
      return Array.isArray(v0) ? v0.map((v, j) => v + (v1[j] - v) * k) : v0 + (v1 - v0) * k;
    }
  }
  return keys[keys.length - 1][1];
}
// a slot that scrubs along a curve and returns to its design position
slot.style.transform = `translate(${track([[0, [0, 0]], [1.2, [46, -18]], [2.6, [46, -18]], [3.8, [0, 0]]], t).join('px,')}px)`;
```

**Accents** sit on top of stories, never instead of them:

| Accent | Use for | Values |
|---|---|---|
| Pulse ring | status dots, live indicators, play buttons | 1.8–2.2 s period, ring scale 1 → 2.6, opacity 0.55 → 0 |
| Heartbeat | hearts, likes, sparkles | +20% over 0.35 s, every 3 s |
| Gentle bob | floating objects | ±2.6 px, 2.8 s sine |
| Sheen sweep | photos, bars, buttons | a band 38% of the element's width peaking at 34% white, 1.5 s pass every 3.4 s; invisible on light grey shapes — use a refill story there |
| Skeleton glimmer | placeholder lines inside the design | 2.4 s shimmer |

Stories and accents start when the intro has landed (~2.4 s). Stories begin from the exact design
and need no fade; accents and helpers fade in over 0.6 s.

## The cycle (showcase)

| Phase | Default |
|---|---|
| Build in | 0 → 2.4 s |
| Stories | 2.4 → 11.0 s |
| Dissolve | 11.0 → 11.6 s (opacity 0.5 s) |
| Empty beat | 11.6 → 12.0 s |

- The story phase holds at least one full story of every card; lengthen the cycle rather than cut
  a story.
- The dissolve returns to the empty state: an app frame's joined surfaces stay, separate cards
  dissolve too, the background never does.
- The live page keeps telling stories forever after its intro; only `?loop` and the exports
  dissolve and restart.
- On a website there is no cycle. Stagger by reading order inside the section, never across the
  page; stop the clock when the section leaves the viewport.

## Easing

| Token | Curve | Use |
|---|---|---|
| `--e` | `cubic-bezier(0.16, 1, 0.3, 1)` | transforms on entrance (1.05 s) |
| `--e2` | `cubic-bezier(0.33, 1, 0.68, 1)` | opacity and blur (0.7–0.8 s) |
| `--io` | `cubic-bezier(0.65, 0, 0.35, 1)` | wipes, fills, sweeps, camera moves |
| linear | `linear` | constant motion only (shimmer, playback) |

Showcase timing is slower than product UI timing on purpose: "under 300 ms" product rules do not
apply here.

## Values

| Value | Default |
|---|---|
| Rise distance | 10 px (`up`), 8 px (`down`), 10 px (`left`) |
| Entrance blur | 4 px, photos 14 px |
| Pop start scale | 0.82–0.88 |
| Transform duration | 1.05 s with `--e` |
| Opacity and blur duration | 0.7–0.8 s with `--e2` |
| Wipe duration | 0.7 s, slow bars 1.1 s, with `--io` |
| Card rise | 24 px, `scale(0.985)`, `blur(6px)`, 0.9 s transform with `--e`, 0.6 s opacity |
| Container stagger | 80–90 ms |
| Tray and folder rise | 40 px |
| Typing | one glyph every 45–70 ms, caret blink 1 s |
| Item stagger | 30–80 ms |
| Story start | 2.4 s |
| Story length | 3–8 s per card, offset between cards |
| Cycle | 12 s (dissolve at 11.0 s, reset at 11.6 s), longer if a story needs it |
| MP4 | 60 fps, CRF 15, max 1920×1200 |
| Website GIF | 960 px wide, 20 fps |
| Small GIF | 800×500, 20 fps |

## Credits

Adapted from `design-to-motion` in [elayadesign/ai-design-skills](https://github.com/elayadesign/ai-design-skills)
@a2735a3, restructured for this plugin:

```
MIT License

Copyright (c) 2026 Elaya

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
