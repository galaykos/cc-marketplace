---
name: game-platform-floors
description: Use when choosing or reviewing a game's default text size, subtitle size, a text-size or UI-scale setting, button-glyph size, or its audio loudness — a LUFS/LKFS target, true peak, a mix louder or quieter than other games — the Xbox XAG 101 text floors and Sony ASWG-R001 loudness numbers, and how each is measured.
---

> Last verified: 2026-10-26 — https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/101

## Read the targets first

Read which platforms the game ships to (export presets, build targets, planned store
pages). Both sets of numbers differ by platform class: a console game held to the PC text
floor is too small on a TV, and a PC game held to the console floor wastes the screen.

## The rules, and who enforces each

| Rule | Standing |
|---|---|
| Default text body height meets the XAG 101 floor for each target platform | **agent-graded** — measured on a screenshot; nothing in this plugin measures text |
| Players can scale text to 200% of the floor without losing content | **agent-graded** |
| The full mix sits at its platform class's loudness target, true peak at or below −1 dBTP | **agent-graded** — needs a BS.1770 meter on a capture; nothing here meters audio |

XAG are Microsoft's accessibility guidelines and ASWG-R001 is a Sony recommendation; this
skill states neither as a certification requirement.

## Text: the XAG 101 floors

| Platform | Minimum default size |
|---|---|
| Console | 26 px at 1080p · 52 px at 4K |
| PC / VR | 18 px at 1080p · 36 px at 4K |
| Mobile, game streaming | 18 px at 100 DPI · 36 px at 200 DPI · 72 px at 400 DPI, linear in DPI (a 5.5-inch 1080p phone is about 400 DPI) |

- "px" is **body height**, not the engine's font size: on a screenshot at the target
  resolution, the pixel distance from the lowest descender to the highest ascender of a
  rendered word. Edge pixels whose contrast with the background is below 2:1 (soft
  anti-aliasing, a faint outline) do not count. The same font size renders different
  body heights in different typefaces, so measure the rendered text.
- Text inside button glyphs and icons meets the same floor. When a glyph will not fit
  the line, enlarge the line, not shrink the glyph.
- Players can scale text to 200% of the floor (26 → 52 px on console at 1080p) without
  losing content, function or meaning. Scrolling in one direction is acceptable; needing
  both is not. Icons and glyphs scale with the text.
- OS screen magnification does not count as a mitigation for small default text.

## Loudness: ASWG-R001

ASWG-R001 v1.10 (August 2013), from Sony Worldwide Studios' Audio Standards Working
Group, is the reference most game teams cite. It is written for Sony's PlayStation
platforms, home and portable. Using its home number for PC and its portable number for
phones is industry convention, not something the document says.

| Platform class | Integrated loudness |
|---|---|
| Home (console on a TV or speakers) | −24 LKFS, ±2 |
| Portable (handheld; phones by convention) | −18 LKFS, ±2 |
| True peak, every platform | at or below −1 dBTP |

- Meter with ITU-R BS.1770-3 or later; LKFS and LUFS are the same unit. Measure the whole
  mix, not dialogue, music or effects on their own, over at least 30 minutes of gameplay
  that represents the whole title, in stereo and in surround, and keep the two
  consistent.
- In practice: record the game's output while playing (loopback), then run the capture
  through a BS.1770 meter, such as ffmpeg's `ebur128` filter or a DAW loudness meter.
- v1.10 moved the home target from −23 to −24 LKFS to match ATSC and ARIB broadcast.
  Sources quoting −23 predate it.
- −14 LUFS is a music-streaming normalisation level, not a game target. A console game
  mixed to it sits about 10 LU above the reference.
- The −1 dBTP ceiling exists because runtime resampling, filtering and surround-to-stereo
  downmixing all raise peaks after the mix is rendered. Do not spend that headroom.

## Anti-patterns

- **Font-size floor** — comparing the engine's font-size property with 26 or 18 instead
  of measuring rendered body height.
- **Streaming loudness** — a game mastered to −14 LUFS like a music release.
- **Stem metering** — measuring the dialogue or music bus alone and calling the mix
  compliant.
- **Magnifier as accessibility** — pointing at OS zoom instead of shipping a text-size
  option.
