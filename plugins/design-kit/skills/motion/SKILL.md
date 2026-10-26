---
name: motion
description: Use when asked to animate a static design — a Figma frame or link, a dashboard, card set, app screen or screenshot — into a looping showcase, a motion mockup, a loading or appear animation, or an MP4 or GIF of it, even when the ask is only "animate this". Not for interaction motion inside a shipping product (hovers, menus, toasts).
argument-hint: "[figma-url | image path] [--website] [--no-export]"
---

## Entry: /design-kit:motion

Run this section only when a new animation starts; loaded mid-task, skip to the rules.

1. **Context first** — it changes what moves and what ships:

   | | Showcase | Website |
   |---|---|---|
   | Typical ask | "animate this", a Figma link and nothing else | inside a site's codebase, or the ask names a page |
   | Animated | the whole frame | only sections with a visual (bento and feature cards, a product mockup, a logo row) — never a text-only section |
   | Starts | page load, from the empty state | when ~30% of the section is visible (`IntersectionObserver`), once |
   | After the intro | stories, dissolve, repeat | stories forever, paused off screen; no dissolve |
   | Text | exported layers, so the frame is exact | live HTML in the site's font, for SEO and accessibility |
   | Ships | page + three exports | the sections in the site's code; exports only when asked |

   No site and only a design → showcase. Unclear → ask once. On a website, a product or
   dashboard mockup gets the loading intro only; ask before adding stories to it. In a
   craft-layer build, `motion-tiers` owns the tier and budget; this skill owns the choreography.
2. **Toolchain.** Capture needs Node with Playwright's Chromium; export needs `ffmpeg`;
   a Figma source needs a personal access token in the environment. Name what is missing
   before building, never mid-way.
3. **Workspace.** `.design-kit/motion/<slug>/index.html`; exports in `out/`; captured
   frames in `.frames/` — a dot directory the preview server neither lists nor watches, so
   thousands of PNGs never trigger a reload. `bash "${CLAUDE_PLUGIN_ROOT}/scripts/dk.sh"
   serve` prints the URL; never assemble one from a port. On the first design of a session,
   show the live page before recording, so the direction is corrected cheaply.
4. State the plan in six lines (Output format, below), build, verify, then export.

## Part A — the frame must be the design

A showcase is not a redesign: the viewer sees **the exact design**, then sees it is alive.
Figma REST calls, layer placement, background and clipping recipes are in
`references/figma-export.md` — read it before the first export call.

- **Source of truth.** Render the node as the reference PNG; every layer position is
  `absolute bounds − frame origin`. A flat image cannot be separated perfectly: rebuild
  what isolates, and tell the user which parts cannot before animating them. Never fake
  fidelity by animating a screenshot as one block.
- **Text stays an exported layer in a showcase.** Retyped HTML text never matches kerning
  and line metrics.
- **The background is sacred.** It never moves, blurs, scales, fades or recolours — not in
  the intro, the loop, the dissolve or a "simpler" variant. Use the original image fill, not
  a render. Cannot reproduce it → say so and ask; never swap in a flat colour.
- **App frame or separate cards.** Joined surfaces (sidebar + body) are present, opaque and
  still from the first frame, and only their contents load. Separate cards (bento, widgets)
  rise in themselves, and the empty state is the background alone. Each container clips its
  own contents to its exact radii.
- **Verify the still before any motion.** Render `?still` at 2x against the reference: PSNR
  above 35 dB overall and 30 dB per container after a light blur (`gblur sigma≈1.2`). Fix
  structure (a shifted glow, a missing stroke, wrong stacking), never sub-pixel offsets.

## Part B — motion

Every timing, distance and curve comes from `references/motion-system.md`, which also holds
the choreography kinds, the story table, accents and the cycle. Never invent ad hoc values.

- **Start empty.** Every page load and both GIFs open on the empty state; empty becomes
  loaded. The X MP4 is the exception below. Elements rise from below and resolve from blur to sharp, staggered in reading
  order, about 2 to 2.5 s for a full frame.
- **Never `scale(0)` an object.** Only lines and bars grow from zero, because they draw.
  Bars and meters fill as left-to-right `clip-path` wipes. Never add a loading line or any
  shape the design does not have.
- **Covered layers arrive last and leave first,** or they ghost through.
- **Stories are the main act.** Every visual acts out what it does — a list receives an
  item, a chart is read, a prompt is typed. Name each story in one sentence before building.
  A frame that loads and then sits with a few pulses is not finished.
- **Every story starts and ends on the exact design,** uses the design's own elements, and
  changes text only for counters and typing. Typing reveals glyph by glyph, never a wipe.
- **Obvious, not busy, and offset.** A clear beat every one to two seconds; cards never act
  in unison; anything under ~4 px in the 800×500 GIF is enlarged or replaced.
- **Reset everything at the cycle's end** — CSS by a no-transition class, and every JS value
  (masks, tracks, typed text, helpers) by hand. The last frame must equal the first.
- **One JS clock** drives everything time-based, from loop time, never wall clock, so
  capture is deterministic. CSS transitions only for the intro.
- **Cheap properties only:** `transform`, `opacity`, `filter`, `clip-path`; animated blur
  ≤ 14 px. No zoom or pan unless asked, and then the background still never moves.
  `prefers-reduced-motion: reduce` renders the still frame.

## Part C — capture and export (showcase, or when asked)

Recorder, page-side contract, checks and `ffmpeg` lines: `references/capture-export.md`.

- **Never screen-record in real time.** Step Playwright's fake clock and screenshot every
  frame. Load `?capture&static=1`: the preview server injects its live-reload snippet into
  pages, and an open event stream keeps a capture from settling.
- **Run the checks on the recorded frames before encoding:** overflow (nothing outside the
  containers changes), seam (first frame equals the frame one cycle later), empty beat, rest
  (the frame before the dissolve equals `?still`), and a contact sheet read by eye.
- **Three files:** `<name>-x.mp4` (H.264, `yuv420p`, 60 fps, even dimensions, ≤ 1920×1200),
  `<name>-loop.gif` (960 px wide), `<name>-800x500.gif` (cropped to content at exactly 1.6:1).
- **The X MP4 opens loaded.** X autoplays muted and shows frame 0 as the thumbnail, so an empty
  first frame posts a blank card. The loop is seamless, so rotate that file's export window to
  start at the rest frame (loop time = the intro's end); the GIFs keep the empty start.

## The rules, and who enforces each

| Rule | Standing |
|---|---|
| The still matches the reference above the PSNR floor | agent-graded — you run the comparison; nothing re-runs it |
| Seam, empty-beat, rest and overflow checks pass before encoding | agent-graded — the frame diffs are yours to run |
| The background never changes in any frame | agent-graded — the overflow check is the evidence |
| The Figma token is never printed, echoed or committed | agent-graded; the secret-scanning plugin's write guard catches a committed literal when installed |
| Exports are deterministic (fake clock, loop time) | recorded — nothing compares two captures |

No script in this plugin captures or encodes yet; the recorder in the reference is code you
write per project.

## Output format

Before building, six lines: **Context** (website: each section and what it gets) ·
**Layout** (app frame or separate cards, the clip shapes) · **Background** (kept exactly, or
what cannot be) · **Choreography** (load order, kind per group) · **Stories** (one sentence
per visual, plus accents) · **Cycle** (length and phases).

After: still fidelity (overall and worst container PSNR), overflow and seam results, the
three files with size, dimensions, fps and duration, and anything not reproduced exactly.

## Anti-patterns

- **The pulse-only loop.** Load in, then a few pulsing dots. The stories are the job.
- **Retyped showcase text.** Fonts and metrics drift; export the layer.
- **The convenient background.** A flat colour or a blurred photo because the fill was hard.
- **Real-time recording.** Dropped frames and a visible seam; step the clock.
- **Story drift.** A loop that ends a pixel away from the design pops at every restart.
