# pixel-art

The export and file-format layer of 2D game art: Aseprite's command line and the sheet JSON it writes, turning
image-model output into real pixel art, and Tiled and LDtk map files. It carries only what a from-memory answer gets
wrong, such as `json-hash` being Aseprite's default, `frameTags` drifting under `--ignore-empty`, Pillow's dithering
palette defaults, the fourth GID flag bit, Phaser skipping compressed layers with only a warning, tile objects
anchored at their bottom-left, and LDtk's own loader ignoring `__value`. Two stdlib checkers turn the
file-consistency rules into exit codes.

## Install

```bash
claude plugin install pixel-art@cc-plugins-marketplace
```

Companions, installed separately (no plugin here may declare `dependencies`):

- **gamedev**: `claude plugin install gamedev@cc-plugins-marketplace`. Its `asset_report.py` checks the PNG itself
  (size, alpha, colour count) and its `game-assets` skill covers licences and Steam's AI disclosure. This plugin does
  not repeat either.
- Your engine's plugin (`godot`, `unity`, `phaser`, `pixijs`, ...) owns texture filtering, mipmaps, pixels-per-unit
  and the engine's tile nodes.

## What ships

| Artifact | Reach for it when |
|---|---|
| `pixel-art-pipeline` skill | Running or scripting `aseprite -b` exports, loading Aseprite sheet JSON, or reducing and palette-locking generated art |
| `tilemaps` skill | Reading, writing or debugging `.tmx`/`.tmj`/`.tsx`/`.tsj`/`.ldtk`/`.ldtkl` files or a loader for them |
| `scripts/check_sprite_sheet.py` | After an export: `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/check_sprite_sheet.py" art/` (`--json`, `--strict`) |
| `scripts/check_tilemaps.py` | After editing maps or before a build: `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/check_tilemaps.py" maps/` (`--engine phaser\|melonjs`, `--json`, `--strict`) |

Both checkers are stdlib-only Python 3, read-only, and exit 0 (no errors), 1 (errors, or warnings under `--strict`)
or 2 (could not run). Optional MCP servers for Aseprite, Tiled and LDtk are named with their install lines in the
skills; this plugin ships no `.mcp.json`.

## What has teeth

| Rule | Standing |
|---|---|
| A sheet JSON agrees with its PNG: image present at the declared size, frames inside it, tags inside the frames array, positive durations, no repeated hash key | **gate** where `check_sprite_sheet.py` runs (exit 1); nothing runs it unasked, so running it is agent-graded |
| Map references resolve, GIDs belong to a tile after masking, layer data has the right length | **gate** where `check_tilemaps.py` runs (exit 1); same caveat |
| No layer format the target engine skips | **gate** under `--engine phaser`; a warning under `--engine melonjs` and for zstd |
| CLI option order, `--list-tags`, Pillow palette defaults, area downscaling of generated art, LDtk edits through plain fields | recorded: written in the skills, nothing reads it back |
| The checkers' own contracts | **gate**: `scripts/__tests__/check_sprite_sheet.test.sh` and `check_tilemaps.test.sh`, run by CI's plugin-harness step |

Residual limits: neither checker reads pixels, renders a map or runs an engine. The sheet checker skips the bounds of
rotated frames and does not read slices or pivots. The map checker does not validate custom-property types or
collision, decodes zstd only on Python 3.14+, and knows two engine profiles. The Aseprite facts about `--tag` with
`--list-tags` and about repeated hash keys were read in Aseprite's exporter source, not observed in a run; the
grid-drift and colour counts for generated art are upstream measurements this plugin did not repeat.

Measured: nothing — no control-arm eval.

Credit: rules distilled and rewritten, no code copied, from
[0x0funky/agent-sprite-forge](https://github.com/0x0funky/agent-sprite-forge) @5324342,
[Gamezxz/pixel-art-studio](https://github.com/Gamezxz/pixel-art-studio) @f8c2466,
[crsolver/claude-pxl](https://github.com/crsolver/claude-pxl) @21fee41,
[melonjs/melonJS](https://github.com/melonjs/melonJS) `melonjs-tilemaps` skill @a672695,
[diivi/aseprite-mcp](https://github.com/diivi/aseprite-mcp) @a89b205,
[shpaker/tiled-mcp](https://github.com/shpaker/tiled-mcp) @b88fab1 and
[gazure/ldtk-mcp](https://github.com/gazure/ldtk-mcp) @dfed01e (all MIT), each fact re-checked against Aseprite,
Tiled, LDtk, Phaser and Pillow documentation or source on 2026-10-30.
