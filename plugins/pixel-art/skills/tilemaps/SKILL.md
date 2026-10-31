---
name: tilemaps
description: Use when loading, writing or debugging Tiled (.tmx/.tmj/.tsx/.tsj) or LDtk (.ldtk/.ldtkl) maps or a loader for them — GID flip bits, firstgid, compressed or infinite layers, tile-object anchors, LDtk __ fields, external levels — plus a map checker.
---

> Last verified: 2026-10-30 — https://doc.mapeditor.org/en/stable/reference/tmx-map-format/
<!-- version-tail-ok: Tiled and LDtk are desktop editors with no npm/composer/pypi package; re-read the Tiled 1.12.2 TMX, JSON and global-tile-ID pages, ldtk.io/files/JSON_SCHEMA.json 1.5.3, and LDtk JSON_DOC and loader source at deepnight/ldtk@2b7b551 -->

This skill is the map-file layer. Engine tile nodes (Godot `TileMapLayer`, Unity Tilemap and its packages) belong
to the engine plugins.

## The rules, and who enforces each

| Rule | Standing |
|---|---|
| Tileset, image, template and level paths resolve; every GID belongs to a tile after masking; layer data has the layer's length | **gate** — `check_tilemaps.py` exit 1; no hook runs it, so whether it runs is agent-graded |
| No layer format the target engine skips | **gate** under `--engine phaser` (melonJS: warning); otherwise zstd is a warning |
| A loader masks all four flag bits and resolves `firstgid` by the largest one not above the GID | recorded — the checker reads map files, not loader code |
| LDtk edits go to non-`__` fields and are re-saved in LDtk | recorded; stale auto-layer tiles are a checker warning |

## Tiled: global tile IDs

- The top four bits of a GID are flags: `0x80000000` horizontal, `0x40000000` vertical, `0x20000000` anti-diagonal
  (with H/V it gives rotation), `0x10000000` hexagonal 120 degrees. Clear all four before the lookup, bit 29 included
  on square maps: Tiled keeps it after a map stops being hexagonal. Render the diagonal flip first, then H and V.

  ```python
  gid = raw & 0x0FFFFFFF                      # 0 = empty cell
  ts = max((t for t in tilesets if t.firstgid <= gid), key=lambda t: t.firstgid)
  local = gid - ts.firstgid
  ```

- The first tileset's `firstgid` is 1 and tilesets are stored by increasing `firstgid`. GIDs are per map: the same
  tile has another GID in a map with other tilesets or another order, so never carry one across maps.
- Tile objects (an object with `gid`) carry the same flag bits.
- Image-collection tilesets can hold local IDs at or above `tilecount` once tiles are removed: look tiles up by
  their `id`, never by array index. Since 1.7 `<tile>` elements are saved in display order, not by id.

## Tiled: layer data

- `encoding` is CSV or base64. Base64 is little-endian uint32, optionally `gzip`, `zlib` or `zstd`; zstd is a
  compile-time option even in Tiled, and Python's stdlib decodes it only from 3.14 (`compression.zstd`).
- Phaser (v4.2.1 source) reads Tiled JSON only, skips every compressed layer with a `console.warn`, and ignores
  external tilesets with "External tilesets unsupported. Use Embed Tileset and re-export". The map loads with holes
  and no error. melonJS throws `No inflate function set` on compressed data until an inflate plugin is registered.
  Save CSV with embedded tilesets unless every consumer reads more.
- `infinite: true` maps store `chunks` (`x`/`y` in tiles, negative allowed) instead of `data`; such a map has no
  fixed size, so take the extent from the chunks. A loader that reads `data` gets empty layers.
- The JSON `version` is a string since 1.6 (`"1.10"`); older files have a number.

## Tiled: paths, objects, properties

- An external tileset's `source` is relative to the map. A tileset `image` is relative to the file that holds it:
  the `.tsx` for an external tileset, the map for an embedded one. File-type properties are relative to the map.
- A `.tmj` may reference an XML `.tsx`; a JSON-only loader cannot read it. Save the tileset as `.tsj`, or embed it.
- Tile objects: in orthogonal maps `x,y` is the image's BOTTOM-left, in isometric its bottom-centre, unless the
  tileset sets `objectalignment`. Rectangles use top-left. Rotation is clockwise degrees around `x,y`.
- An object's or tile's class is `type`. Tiled 1.9 wrote it as `class` and 1.10 renamed it back; maps, layers and
  tilesets keep `class`. Read both.
- Colour properties are `#AARRGGBB`, alpha first.
- Object layers default to `draworder: topdown` (sorted by y); `index` keeps the manual order.
- 1.12 added the `oblique` orientation, capsule objects and a layer blend `mode`; older loaders reject or drop them.

## LDtk

- `__`-prefixed fields are copies made for importers. LDtk's own loader reads a field's `realEditorValues` and never
  its `__value` (`FieldInstance.fromJson`), so a script edit to a `__` field is overwritten on the next save. Edit
  the plain fields, or edit in LDtk.
- `layerInstances` lists the TOP-most layer first: draw it in reverse. Inside one layer `autoLayerTiles` is
  bottom-first.
- Tile `px` is in layer space: add the instance's `__pxTotalOffsetX`/`Y` (instance plus definition offset). Level
  `worldX`/`worldY` matter only in `Free` and `GridVania`; linear layouts write -1.
- Take the tileset from the instance's `__tilesetDefUid`: an instance can override its definition's tileset.
- With "Save levels separately" (`externalLevels`) each level's `layerInstances` is `null` in the project; load the
  `.ldtkl` its `externalRelPath` names, relative to the project.
- With Multi-worlds (1.3.0+) the root `levels` array is empty: read `worlds[].levels`.
- IntGrid: `intGridCsv` is row-major, `0` is empty, values start at 1. Auto-layer tiles are baked into
  `autoLayerTiles`; a game never evaluates rules. A script that edits `intGridCsv` leaves the drawn tiles stale
  until LDtk reopens and saves the project.
- Tile `f`: bit 0 flips X, bit 1 flips Y.
- Fields a from-memory importer still reads, removed in 1.2.0: `LayerDef.autoTilesetDefUid` (now `tilesetDefUid`),
  `EntityDef.tileId` (now `tileRect`), `NeighbourLevel.levelUid` (now `levelIid`). Since 1.5.0 entities carry no
  `__worldX`/`__worldY` outside `Free` and `GridVania`.
- A tileset or level background may be an `.aseprite` file (LDtk 0.9.3+); a game loader needs an exported PNG.
- For an engine with no importer, `simplifiedExport` writes a much simpler export on every save.

## Run the checker

```sh
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/check_tilemaps.py" assets/maps [--engine phaser|melonjs] [--strict] [--json]
```

- Scans `.tmx`, `.tmj`, `.tsj`, `.ldtk`, Tiled-shaped `.json`, and `.tsx` files whose root is `<tileset>` (React
  `.tsx` files are skipped); follows external tilesets, templates and `.ldtkl` levels.
- **Errors (exit 1):** a missing tileset, image, template, level or background file; a GID no tile owns after
  masking; layer or chunk data of the wrong length or undecodable; an `intGridCsv` of the wrong size; an LDtk tile
  read outside its tileset; with `--engine phaser`, a TMX map, a compressed layer or an external tileset.
- **Warnings (exit 1 only with `--strict`):** zstd layers; infinite maps; a `.tmj` on a `.tsx`; a tileset image whose
  size changed under it; an `.aseprite` LDtk tileset; auto-layer rules with no baked tiles; compression under
  `--engine melonjs`.
- Exit 2: bad arguments, an unreadable target, or no map found. Blind to rendering, collision, custom-property
  types, loader code, and zstd data before Python 3.14. Refuses XML with entity declarations (Tiled writes none).

## MCP servers (optional)

- **Tiled:** [shpaker/tiled-mcp](https://github.com/shpaker/tiled-mcp), Tiled 1.12+, installs as a Claude Code
  plugin: `/plugin marketplace add shpaker/tiled-mcp`, then `/plugin install tiled@tiled-mcp`. Its launcher downloads
  a release binary (sha256-checked) to `~/.cache/tiled-mcp/<version>/`, and with consent writes an extension into
  Tiled. `run_script` runs arbitrary code in Tiled, and any local process can reach its hub on 127.0.0.1:47317.
- **LDtk:** [gazure/ldtk-mcp](https://github.com/gazure/ldtk-mcp), Rust: `cargo install --git
  https://github.com/gazure/ldtk-mcp`, then `claude mcp add ldtk ldtk-mcp`. It edits the `.ldtk` JSON, not the GUI,
  and clears `autoLayerTiles` on IntGrid edits, so the game shows no auto tiles until LDtk re-saves.

This plugin ships no `.mcp.json`.

## Anti-patterns

- **Flag-blind lookup**: indexing tilesets with the raw GID, or masking three bits of four.
- **Cross-map GID**: caching GIDs from one map and reusing them in another.
- **Compressed for Phaser**: zlib, gzip or zstd layers, or external tilesets, in a map Phaser loads.
- **Top-left tile object**: drawing a tile object's image with `x,y` as its top-left corner.
- **`__value` edit**: changing LDtk fields through the `__` copies.
- **Stale auto-layer**: editing IntGrid by script and shipping without a save in LDtk.
- **Forward layer draw**: drawing `layerInstances` in array order.
