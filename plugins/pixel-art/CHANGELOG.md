# Changelog — pixel-art

Consumer-facing changes only. Newest first.

## 0.1.0 — 2026-10-30

- New plugin. `pixel-art-pipeline` skill: Aseprite CLI option order, the `json-hash` default, `--list-tags`, tag indices that drift under `--ignore-empty`/`--tag`/`--frame-range`, trimmed-frame offsets, millisecond vs Lua-seconds durations, and finishing image-model output (measure the grid, area downscale, Pillow palette locks without the default dither or WEB palette).
- `tilemaps` skill: Tiled GID flag bits and `firstgid` lookup, layer encodings and what Phaser and melonJS skip, infinite chunks, path bases, tile-object anchors, the 1.9/1.10 `class`/`type` rename; LDtk `__` fields vs `realEditorValues`, layer order, offsets, external levels, multi-worlds, baked auto-layer tiles and removed fields.
- `scripts/check_sprite_sheet.py` and `scripts/check_tilemaps.py`: stdlib checkers (`--json`, `--strict`; the map checker also `--engine phaser|melonjs`), each with a CI harness.
