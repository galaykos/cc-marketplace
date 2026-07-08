---
name: image-ops
description: Use when marketing assets need deterministic image work — resize, crop, optimize, favicon, an OG share image, an app-store frame, or a captioned marketing frame. Detects a generic third-party image MCP (Sharp or ImageMagick based) and delegates raster primitives, then composes the marketing presets those servers do not ship. Never installs anything; degrades to an HTML composite for framing and skips-with-note for raster ops when no image MCP is registered.
---

## What this is

The suite's one place for pixel work. Raster math (resize, optimize, favicon) is
commodity — a published image MCP already does it, so this skill **adopts one and
delegates**, rather than reinventing it. What those servers lack is the
*marketing* presets (share cards, store frames), so this skill **composes** those
from the primitives. It is the single detection point: marketing-capture and
marketing-copy call these ops instead of probing for an MCP themselves.

## Detect a generic image MCP — never install

Probe for an image MCP the user has registered, in this order; use the first
present and state which it is:

1. A Sharp-based server (e.g. `mcp-image-optimizer`) — fast, prebuilt.
2. An ImageMagick-based server (e.g. `mcp-imagemagick`) — 200 formats, true `.ico`.

"Present" = its tools are loadable/callable. Map the server's own tool names onto
the primitives below — stay MCP-agnostic, do not hardcode one server. If NONE is
present, do not install one; drop to the fallback matrix.

Registering an MCP is the user's one-time, out-of-band step (their MCP config);
this skill never runs `npm install`, `npx`, or a system package to conjure one.

## Primitives — delegated to the MCP

| Primitive | Delegates to the MCP |
|-----------|----------------------|
| resize | scale to exact/bounded dims, keep aspect |
| crop | crop box or aspect-fit |
| convert | change format (png/jpg/webp) |
| optimize | lossless/lossy size reduction |
| metadata | dimensions, format, size |

Pass through file paths; let the MCP read/write. Report what it produced.

## Presets — composed here from primitives + templates

These are the marketing knowledge the generic servers don't carry. Build each
from the primitives above plus a shipped template:

- **og_image (1200×630):** resize-to-fit the source → pad/letterbox to exactly
  1200×630 → optional title band rendered from `assets/og-card.html`. The canonical
  social share card.
- **app_store_frame:** pick the target device dimensions → resize the shot →
  composite onto a device bezel. One axis (device) per call.
- **favicon:** emit the standard sizes (16, 32, 48, 180, 512) as PNGs. A true
  multi-resolution `.ico` needs an ImageMagick-class backend — when only a Sharp
  server is present, emit the PNG set and note `.ico` was not produced.
- **frame (captioned):** a marketing frame around one screenshot — reuse
  marketing-capture's `frame-shell.html` composite, or the MCP's composite when it
  offers one. Equal treatment across shots; no per-shot restyling.

Keep presets honest: one variant per call, realistic output, no invented content.

## Fallback matrix — not uniform

When no image MCP is registered, behavior splits by op class:

| Op class | MCP present | MCP absent |
|----------|-------------|------------|
| frame, og_image, app_store_frame (framing) | MCP primitives + template | **HTML-shell + screenshot composite** (render the template at target dims via the caller's browser backend, re-screenshot) |
| resize, crop, optimize, favicon (raster) | MCP | **skip with a clear note** — e.g. "resize needs an image MCP; none registered." No fabrication, no hand-rolled raster. |

The framing-type fallback needs a browser backend (the one marketing-capture
already detects). Raster ops have no honest fallback, so they stop cleanly and
say why — the same posture as the suite's native-GIF-or-skip rule.

## How callers use this

- **marketing-capture** — routes its frame/resize/optimize through these ops
  instead of only the inline HTML composite.
- **marketing-copy** — requests an `og_image` for the recommended slogan.

Detection lives ONLY here. Callers invoke the ops and let this skill decide MCP
vs fallback vs skip — so the "is an image MCP present?" logic is written once.

## Output

Write results next to the caller's other assets (the suite's `marketing/`
directory): `og-image.png`, `favicon-32.png`, framed `shot-NN.png`, etc. Report
each path and whether the MCP or a fallback produced it. Never overwrite a
hand-edited asset without confirming.

## Trusting the adopted MCP

The image MCP is third-party community software that reads and writes local
files. Treat it accordingly: prefer a pinned version (the README says how), point
it only at the project's asset directories, and if the user has not registered
one, say so plainly rather than reaching for an unvetted server on the fly.

## Anti-patterns

- Installing an image MCP, `npx`-ing one, or adding a system package to make an
  op work — detect, or degrade.
- Hardcoding one server's tool names instead of mapping the present server's.
- Faking a raster op (resize/optimize) with a browser screenshot — that is not a
  resize; skip with a note instead.
- Re-detecting the MCP inside marketing-capture or marketing-copy — this skill is
  the single detection point.
- Per-shot restyling of a preset template — equal treatment or it is a sales pitch.
- Declaring the adopted MCP in plugin.json — the manifest is closed; the README
  documents registration.
