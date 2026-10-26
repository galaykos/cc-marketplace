# Figma export, placement and the page — the fidelity half of `motion`

Read before the first Figma call. Everything here exists so the finished still is
indistinguishable from the source frame.

## Source of truth: the Figma REST API

- The token comes from a secure store — an environment variable or the OS keychain — and is
  sent as the `X-Figma-Token` header. Never print it, echo it, paste it into chat, or write it
  into a file under the project.
- `GET /v1/files/:key/nodes?ids=:node&geometry=paths` — the tree, bounds, fills, effects,
  radii, and stroke/fill geometry.
- `GET /v1/images/:key?ids=:node&format=png&scale=2` — the **reference frame**. The finished
  still must match this image.
- `GET /v1/files/:key/images` — the RAW image fills (photos, textures); use these for the
  background, never a render.
- Note the frame's absolute origin. Every layer position is `absolute bounds − origin`.
- The image URLs the API returns point at a CDN that sometimes resets connections. Retry every
  download and check each PNG's byte size before using it.

**Flat image only.** The image is the reference. Rebuild what you can isolate and tell the user,
before animating, which parts cannot be separated.

## Layer export

Export every element that will move as its own PNG at **3x** through `/v1/images`, batched 20 to
25 ids per call.

| Case | Placement |
|---|---|
| PNG size equals `absoluteRenderBounds` (text layers always do) | place at the render bounds |
| PNG larger than the render bounds (a parent clipped it), effects overhanging evenly | `x = bbox.x − (pngW − bbox.w) / 2`; `renderBounds.y` when the top was not clipped, else derive it from the effect radius and offset |
| Uneven overhang (a line with an arrowhead, a stroke with one square cap) | the bounds of `strokeGeometry` / `fillGeometry` from the `geometry=paths` response, not the formula |
| Rotated vectors with a large layer blur (soft colour blobs) | export with `use_absolute_bounds=true`, place at the bounding box; run a PSNR offset search only if that region scores below ~45 dB; blobs may be stored at 1x |
| Zero-height or zero-width stroked vectors | `use_absolute_bounds=true` returns null for them — export without it |
| Mask group with blurred content | anchor on the edge that was not clipped (usually the mask's bottom plus its stroke) |
| Arcs, donuts, partial ellipses | `use_absolute_bounds=true` |
| Patterns or overlays far larger than their surface | `use_absolute_bounds=true`, then crop to the surface rectangle |
| Instance children (ids like `I12:34;56:78`) | often return null — export the parent instance |
| Lines that should draw on | Figma outlines strokes into filled shapes, so there is no centerline: write it yourself and use it as a mask over the PNG (below) |
| A photo baked inside a larger exported layer | also export the photo node alone; cover the baked photo with a skeleton and put the separate layer on top for the `photo` resolve. At rest it must equal the reference |

Rules that keep the frame exact:

- **Keep Figma's z order.** Static layers sit between animated ones in the tree's order.
- **Frame strokes usually draw above children.** Render a card's stroke as an overlay above
  its clipped content, then confirm against the reference — a glow inside the card can tint
  the stroke in Figma's render.
- **Containers whose children move on their own** are rebuilt in CSS from the node data
  (fills, corner radii, inside strokes including `individualStrokeWeights`, effects), because
  exporting a frame always bakes in its children. Then export each child separately.
- **Shadow mapping.** A Figma drop shadow with blur `R` is `box-shadow` blur `R` on one element,
  or `filter: drop-shadow()` blur ≈ `R / 2` on a group. Verify against the reference.
- **A group shadow is the shadow of the union.** On joined surfaces (an app frame), put every
  surface shape in one static container with `filter: drop-shadow()`; per-element `box-shadow`
  darkens neighbours where surfaces overlap. Separate cards each carry their own shadow.
- **Skip hidden layers** (`visible: false`) and stray layers buried under opaque shapes.

### Drawing a line on

Read corner points and arc radii from the outline in `strokeGeometry`: the centerline sits
halfway across the stroke width, and a rounded corner's centerline radius is the outline's inner
radius plus half the stroke.

```html
<svg class="ly" viewBox="0 0 1440 990" style="left:0;top:0;width:1440px;height:990px">
  <mask id="draw1">
    <path d="M193 832 V700 A45 45 0 0 1 238 655 H380" fill="none" stroke="#fff" stroke-width="8"
          pathLength="1" stroke-dasharray="1" stroke-dashoffset="1"/>
  </mask>
  <image href="data:image/png;base64,..." x="192" y="653" width="190" height="181" mask="url(#draw1)"/>
</svg>
```

Animate `stroke-dashoffset` from 1 to 0 on the JS clock. `pathLength="1"` means no length
measuring; the wide mask stroke covers the line's antialiasing. Pulses that travel along it read
positions with `getPointAtLength` on the same path.

## Background

- Export the original image fill and apply its scale mode and `imageTransform` as CSS: for a
  stretch fill with a transform, `background-size` is the frame size divided by the transform
  scale and `background-position` is the negative offset.
- Compare the background region of the still against the reference; aim above 45 dB PSNR. A
  crop or offset error shows instantly.
- **Frosted panels must see the photo.** A `backdrop-filter: blur()` surface is its own element,
  a sibling above the background, never inside an ancestor with `filter` or `opacity` below 1.
  Headless Chrome renders it only with `transform: translateZ(0)` and a `z-index` on that element.
- Store photos as high-quality JPEG or WebP, not PNG.

## Clipping

Each container clips its own contents to its exact shape, per-corner radii included. This pattern
keeps stage coordinates valid inside the clip; for separate cards the card's unit wraps its clip,
so card and contents move together:

```html
<div class="clip" style="left:113px;top:138px;width:305px;height:907px;border-radius:16px 0 0 16px">
  <div class="cin" style="left:-113px;top:-138px"><!-- units in stage coordinates --></div>
</div>
```

```css
.clip { position: absolute; overflow: hidden; isolation: isolate; }
.cin  { position: absolute; width: var(--stage-w); height: var(--stage-h); }
```

When a container's silhouette is a photo (a cover header, a full-bleed card image), give it a
placeholder in the image's average colour; the photo loads into it.

## Page architecture (showcase)

On a website, build inside the site's code with its components, tokens, radii and fonts; the
clock, units and modes below still apply per section.

- One self-contained HTML file: a fixed-size stage at the frame's exact size, scaled to fit the
  viewport; images inline as base64, deduplicated. Wait for decode on `<img>` elements only.
- **Modes:** `?still` renders the exact frame with no motion (also the reduced-motion render).
  `?loop` repeats the cycle like the exports. `?capture` turns off `requestAnimationFrame` and
  exposes `window.__start()`, `window.__tick(dt)` and the loop time `window.__lt`.
- **Units.** Every animated element is wrapped in a full-stage layer `.u` carrying its delay
  `--d`; the intro is CSS transitions keyed on `.stage.in`. Because a unit covers the whole
  stage, a percentage in `clip-path` or `transform-origin` refers to the stage — use pixel values
  computed from the element's rectangle.
- **Static layers stay composited.** `transform: translateZ(0)` on clips and stroke overlays, or
  a 1 px edge flickers at every cycle start as nearby transitions begin.
- Default behaviour: wait for decode, play the intro once (when the frame scrolls into view on a
  longer page), then keep the stories running.
