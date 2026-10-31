---
name: pixel-art-pipeline
description: Use when exporting or loading Aseprite sheets (aseprite -b, --sheet/--data, frameTags, --trim, --ignore-empty) or turning image-model output into pixel art (grid downscale, Pillow palette lock) — CLI and JSON traps, plus a sheet-vs-JSON checker.
---

> Last verified: 2026-10-30 — https://www.aseprite.org/docs/cli/
<!-- version-tail-ok: Aseprite is a desktop app with no npm/composer/pypi package; the stamp points at its CLI reference, re-read with the JSON exporter source at aseprite@3669f47 and the Pillow 13.0.0 source -->

This skill is the authoring and export layer. Size, alpha and colour-count checks on the PNG are
`gamedev`'s `asset_report.py`; texture filtering, mipmaps and pixels-per-unit belong to the engine plugin.

## The rules, and who enforces each

| Rule | Standing |
|---|---|
| A sheet JSON agrees with its PNG and itself: image present and the declared size, frames inside it, tag ranges inside the frames array, positive durations, no repeated json-hash key | **gate** for what `check_sprite_sheet.py` reads (exit 1); no hook runs it, so whether it runs is agent-graded |
| Per-file CLI options precede the file; `--list-tags` on every animated export | recorded; a missing `--list-tags` is a checker warning |
| Generated art is reduced by area at the measured grid, never nearest-neighbour on a guessed one | recorded — no script here reads pixels |
| Palette locks run without Pillow's default dither or WEB palette | recorded |

## Aseprite CLI: what the command line does

- Run headless with `-b`. File-selecting options (`--layer`, `--ignore-layer`, `--all-layers`, `--tag`,
  `--frame-range`, `--split-layers`) apply to the NEXT file on the line, so they go before it; `--sheet` packs
  everything named before it. A whole-sprite export with everything a loader needs:

  ```sh
  aseprite -b hero.aseprite --sheet hero.png --data hero.json --format json-array --list-tags --list-slices
  ```

- `--format` defaults to `json-hash`: `frames` is an OBJECT keyed by `--filename-format`, by default
  `"<title> <frame>.<ext>"` (`"hero 0.aseprite"`). Code that indexes `frames[0]` gets nothing. Pass
  `--format json-array`, or set `--filename-format` to a key you control.
- The exporter writes each key as formatted, without de-duplicating (source, not run): a `--filename-format`
  without `{layer}` under `--split-layers` repeats keys, and a JSON parser keeps only the last, so frames vanish
  silently. The checker reports it.
- `meta.frameTags`, `meta.slices` and `meta.layers` are written only with `--list-tags`, `--list-slices`,
  `--list-layers`. Without `--list-tags` no loader sees any animation.
- `frameTags[].from`/`to` are 0-based SPRITE frame indices; they match `frames` only when every frame is exported.
  - `--ignore-empty` drops a wholly empty frame from the sheet and the JSON, so every later tag is off by the
    blanks. Without it an empty frame stays as a 1x1 entry, which is what keeps tag positions (exporter source).
  - `--tag` and `--frame-range` export a subset, yet `--list-tags` still lists every tag with sprite-wide
    indices (read in the exporter source, not run). Export the whole sprite, or one tag without `--list-tags`.
- Tag `direction` is `forward`, `reverse`, `pingpong` or `pingpong_reverse`. `repeat` is a STRING (`"2"`),
  present only when set on the tag.
- `--trim` trims each frame of a `--sheet`: `frame` is the packed rectangle, `spriteSourceSize` is where it sits
  inside the untrimmed `sourceSize`. Draw at the `spriteSourceSize` offset or trimmed frames jump. `--trim-sprite`
  trims the whole sprite once, so every frame keeps one size.
- Frame `duration` is whole milliseconds in the JSON and in the `.aseprite` file. The Lua API's `Frame.duration`
  is SECONDS, and Lua `frameNumber` is 1-based while JSON indices are 0-based.
- `--save-as out.png` on an animation writes one numbered PNG per frame. In names, `{frame}` starts at 0,
  `{frame1}` at 1, `{tagframe}` restarts per tag. `--data=""` prints the JSON to stdout.
- Upstream reports, not re-run here (aseprite-mcp@a89b205): Aseprite can exit 0 having written no file, and
  `--tag` with a misspelt tag exports every frame. After each export check the files exist and count frames.
- Steam installs the binary at `~/.steam/debian-installation/steamapps/common/Aseprite/aseprite` (Linux),
  `~/Library/Application Support/Steam/steamapps/common/Aseprite/Aseprite.app/Contents/MacOS/aseprite` (macOS),
  `C:\Program Files (x86)\Steam\steamapps\common\Aseprite\Aseprite.exe` (Windows).

## Check the sheet against its JSON

```sh
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/check_sprite_sheet.py" art/ [--strict] [--json] [--max-issues N]
```

- Reads every `.json` holding `frames` + `meta` (Aseprite, or TexturePacker's hash/array shape) and skips other JSON;
  a file named on the command line that is not a sheet exits 2.
- **Errors (exit 1):** `meta.image` missing; the PNG's size differs from `meta.size` (sheet and JSON from different
  exports); a frame rectangle outside the image; `spriteSourceSize` outside `sourceSize`; a tag past the frames array
  or with `from` after `to`; a missing or non-positive `duration`; a repeated json-hash key.
- **Warnings (exit 1 only with `--strict`):** an Aseprite export of several frames with no `frameTags`; frames of one
  tag with different `sourceSize`; an unknown `direction`; a non-numeric `repeat`; a non-PNG image (bounds then come
  from `meta.size`).
- Exit 2 means it could not run: bad arguments, an unreadable target, or no sheet JSON found.
- Blind to: pixels (run `asset_report.py`), rotated frames' bounds, slices and pivots, and whether the frame order
  is the animation you meant.

## Image-model output into pixel art

- Do not prompt for a logical pixel grid ("32x32, every pixel an 8x8 block"). Upstream measured image models
  ignoring it: block sizes drifting from 5.6 to 6.5 px and ~70,000 colours on one "pixel art" sheet
  (agent-sprite-forge@5324342, not re-measured here). The pixel look is made after generation.
- Generators return their own canvas size (about 1254x1254 for a 1:1 request in upstream's runs): ask for an
  aspect and process the size that came back.
- Measure the grid before reducing. Nearest-neighbour is right only when the image already sits on a clean integer
  grid (an editor or engine upscale): sample one pixel per block at the measured period and phase. On generated art
  nearest keeps whichever sample lands, doubling and dropping pixels. Reduce that by area to the logical size
  (`Image.reduce(n)`, or `resize(size, Image.Resampling.BOX)`), then lock a palette. pixel-art-studio samples
  block centres instead; every route is lossy, so look at the result at 1x.
- Pillow defaults that ruin palette work (Pillow 13.0.0 source):
  - `img.convert("P")` on RGB maps to the 216-colour WEB palette with Floyd-Steinberg dither.
  - `img.quantize(palette=pal)` dithers by default and accepts only RGB or L; RGBA raises. Split the alpha,
    threshold it to 0/255, quantize the RGB with `dither=Image.Dither.NONE`, restore the alpha, zero the RGB
    under alpha 0.
  - `quantize()` on RGBA uses fast octree (median cut refuses RGBA), so its colours differ from an RGB run.
  - `resize()` defaults to BICUBIC; upscale pixel art with `Image.Resampling.NEAREST` at whole factors only.
- Quantize an animation with one palette for every frame. Per-frame quantizing flips pixels between two close
  colours each frame (upstream measured on video-derived clips); lock the palette first.
- Then check the file: `asset_report.py --max-colors N --require-alpha` from `gamedev`.

## Aseprite MCP server (optional)

[diivi/aseprite-mcp](https://github.com/diivi/aseprite-mcp) drives a local Aseprite through 123 tools. It needs
Python 3.13+, `uv` and a licensed Aseprite binary on `PATH` or in `ASEPRITE_PATH`. It is not on PyPI; its README's
config, as a Claude Code command:

```sh
git clone https://github.com/diivi/aseprite-mcp
claude mcp add aseprite -e ASEPRITE_PATH=/path/to/aseprite -- uv --directory "$PWD/aseprite-mcp" run -m aseprite_mcp
```

Its `run_lua_script` tool runs unrestricted Lua on the host. This plugin ships no `.mcp.json`.

## Anti-patterns

- **Hash as array**: `json.frames[0]` on a default `json-hash` export.
- **Tagless sheet**: `--data` without `--list-tags`, then frame ranges hand-copied into code.
- **Ignore-empty drift**: `--ignore-empty` on a sprite with blank frames; every later tag now points elsewhere.
- **Trim without offset**: drawing trimmed frames at the packed rectangle's origin.
- **Seconds for milliseconds**: a Lua script writing `frame.duration = 100`.
- **Prompted grid**: trusting "16x16 pixel art" in the prompt instead of measuring the file.
- **Dithered lock**: `quantize(palette=...)` with the default dither.
- **Nearest on noise**: nearest-downscaling generated art at a guessed factor.
