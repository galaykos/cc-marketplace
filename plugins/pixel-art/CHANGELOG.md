# Changelog — pixel-art

Consumer-facing changes only. Newest first.

## 0.2.0 — 2026-11-02

- **Sheets and maps are checked when they change.** A new hook, `hooks/sheet-check.sh`, runs one
  of two checkers:
  - `check_sprite_sheet.py` on a sheet JSON holding `"frames"`, or the same-stem JSON beside a PNG;
  - `check_tilemaps.py` on a `.tmx`, `.tmj` or `.ldtk`.

  It fires when a Write names the file, or when the file changes during a Bash call naming a sheet
  tool or extension. Such a call is bracketed the way meshy's is, so an `aseprite -b` export is
  seen. Findings are added once per context and the hook never blocks. Off: `CC_PIXEL_CHECK=off`,
  or `/config`.
- **Measured.** The cheap exit took 14–15 ms median and 16 ms max over 20 runs.
- **Standing.** Running the checkers moves from agent-graded to **gate** where the hook fires
  (`scripts/smoke/game-checker-hooks-tests.sh`, in CI). `.tsx`/`.tsj`/`.ldtkl` alone are not watched.

## 0.1.1 — 2026-11-02

- **README names `unity-traps`,** the renamed `unity` plugin, among the engine plugins that own
  texture filtering and pixels-per-unit. Skills and scripts are unchanged.

## 0.1.0 — 2026-10-30

- New plugin. `pixel-art-pipeline` skill: Aseprite CLI option order, the `json-hash` default, `--list-tags`, tag indices that drift under `--ignore-empty`/`--tag`/`--frame-range`, trimmed-frame offsets, millisecond vs Lua-seconds durations, and finishing image-model output (measure the grid, area downscale, Pillow palette locks without the default dither or WEB palette).
- `tilemaps` skill: Tiled GID flag bits and `firstgid` lookup, layer encodings and what Phaser and melonJS skip, infinite chunks, path bases, tile-object anchors, the 1.9/1.10 `class`/`type` rename; LDtk `__` fields vs `realEditorValues`, layer order, offsets, external levels, multi-worlds, baked auto-layer tiles and removed fields.
- `scripts/check_sprite_sheet.py` and `scripts/check_tilemaps.py`: stdlib checkers (`--json`, `--strict`; the map checker also `--engine phaser|melonjs`), each with a CI harness.
