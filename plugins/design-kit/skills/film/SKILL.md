---
name: film
description: Use when asked to make a video from a brief rather than from an existing design — a product demo, launch film, explainer or beat-synced reel rendered from code (HyperFrames, Remotion, or HTML with headless capture) with music, sound effects or voice-over, for X, 16:9 or 9:16. Not for animating a static design (design-kit's motion skill) or editing camera footage.
argument-hint: "[brief.md | product URL] [--run-to-end]"
---

## Entry: /design-kit:film

Run this section only when a new film starts; loaded mid-build, skip to the order.

1. **Brief.** Fill the fields in `references/brief-and-files.md` from `$ARGUMENTS` and the
   conversation. Blanks are yours to decide: write each choice and its reason into `brief.txt`.
   Run mode: stop at every ⏸ (one AskUserQuestion, strongest option first, "(Recommended)") or
   `--run-to-end` (take the strongest yourself and log why in `brief.txt`).
2. **Workspace.** Everything lives in `.design-kit/film/<slug>/`; frames go in its `.frames/`, a
   dot directory the preview server neither lists nor watches.
3. **Tools.** `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/film.py" doctor --renderer <r> --dir <ws>`.
   Exit 3 names what is missing: install it inside the workspace where you can, else stop and
   tell the user. The renderer's own skills carry its API — offer them, never assume them:
   HyperFrames `npx skills add heygen-com/hyperframes`, Remotion `npx skills add remotion-dev/skills`.
   **Remotion needs a paid company licence for a for-profit organisation over 3 employees** — ask
   before choosing it for one. Neither renderer → hand-rolled HTML under the frame contract below,
   captured with the `seek(t)` loop in `references/picture-and-sound.md`.
4. **Facts.** Pull every usable fact from the facts source into `facts.json` with its original
   sentence and link. Every on-screen line will trace to one.
5. **Capture.** The product UI with a headless browser at 2x; the logo as SVG from the site,
   never redrawn; colours sampled from the page; font files copied in (the Latin subset of a split
   web font). A brand colour under 4.5:1 on its background is for shapes, not text. A login wall →
   stop and ask. Then render a **3-second draft** and continue only once it produced an MP4.

## The order is the content

Sound first, then picture cut to it. Skipping a step is how a film ships off-beat, invented or
undelivered.

1. **Sound.** Synthesized: `film.py music --bpm B --bars N --out music.wav --timing timing.json`
   writes the grid you compose on. Supplied: `film.py beats track.mp3 --write` (pass
   `--bpm-hint` from the track's stated tempo — above ~150 BPM detection can read half-time).
   Voice: word timestamps from the TTS or a transcriber cut the scenes. Silent: skip.
2. **Breakdown** (only with a reference video) → **Storyboard**: three directions ⏸.
3. **timing.json** — scenes, text lines with their `fact` ids, actions — then **style lock**:
   `style.json` (six colours at most, easing curves, handoff positions) and three stills ⏸.
4. **Build** one component per scene; every value computed from the frame number.
5. **Full render**, then **review rounds** and the **self-check**; then deliver.

Roles, their inputs and their exact dispatch prompts: `references/roles.md`.

## The frame contract (every renderer)

- A frame is a pure function of its time: no CSS transitions, timers, carried state or unseeded
  random. A spring is its closed form; a value retargeted twice is a sum of two springs.
- Every from-state is set at t=0 so seeking anywhere is safe; wait for image decodes and a video
  element's `seeked` before capturing.
- A loop exports `[0, duration)` — the end frame is the first frame, never written twice.
- Motion blur: render N subframes per frame (4; 8 for fast whips) and blend with ffmpeg `tmix`.
  Counters and text read the frame's time, not the subframe's, or they smear.
- Chromium traps, footage inside a page, and headless WebGL: `references/picture-and-sound.md`.

## The rules, and who enforces each

| Rule | Standing |
|---|---|
| Every on-screen line traces to `facts.json`; no number absent from its source | **gate** — `film.py check` exits 1, for every line `timing.json` declares; that every line IS declared is agent-graded |
| Each line held ≥ 0.7 s and ≥ 0.3 s per word | **gate** — `film.py check` |
| Hard cuts and actions within one frame of a beat | **gate** — `film.py check`; the grid itself by `film.py beats --verify` |
| Text pairs ≥ 4.5:1; six colours at most; text above the bottom 8%; no overlaps | **gate** — `film.py check`, from `style.json` pairs and declared boxes |
| Duration, fps, size, H.264 yuv420p, AAC 48 kHz, moov before mdat | **gate** — `film.py check --video` (ffprobe) |
| −14 LUFS integrated, ≤ −1 dBTP, measured after the AAC encode | **gate** — `film.py loudness` exits 1 off target |
| No single-frame pops | **gate** — `film.py pops` |
| Frame 0 finished, the point within 1 s, ends on name + URL, reads muted | **agent-graded** — the blind reviewer and the muted test |
| Facts are true | **unenforceable** here — the script checks tracing, not truth |

## X and format

X autoplays muted and frame 0 is the thumbnail: frame 0 is a finished picture with the product name
or the point on screen within 1 s. The mobile player covers roughly the bottom 8%. It must make
sense muted. A 9:16 cut is laid out again — move elements, never crop. End on the product name and
URL. Picture and sound rules: `references/picture-and-sound.md`.

## Delivery

One MP4 per format (H.264, yuv420p, `+faststart`, AAC 48 kHz), a music-only track,
`film.py sheet <mp4> --frames 16` as the contact sheet, `brief.txt`, `facts.json`, `timing.json`,
`ledger.txt` with before/after numbers for every round. Then name the seconds the user should
still watch and listen to themselves — every judgement no script makes.

## Anti-patterns

- **Delivering a plan.** A storyboard, a config file or code that compiles is not a film; the
  deliverable is the muxed MP4.
- **The real-time recording.** Screen-capturing a playing page drops frames and breaks sync.
- **The flat screenshot.** Rebuild panels, icons and text in HTML/SVG so each part can move.
- **Self-grading.** The builder never reviews its own render; a fresh reviewer does, every round.
- **Corner chrome.** Timecodes, frame counters, watermarks and corner labels read as generated.
- **Invented proof.** A price, rating, review or figure the facts source does not carry.
