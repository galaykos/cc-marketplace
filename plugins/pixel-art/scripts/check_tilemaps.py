#!/usr/bin/env python3
"""Catches broken Tiled (.tmx/.tmj/.tsx/.tsj/.json) and LDtk (.ldtk/.ldtkl) maps: missing tileset, image, template and level
files, GIDs no tileset owns after masking the flip bits, layer data of the wrong length, and layer formats a named engine skips.
Does NOT render, validate a schema or judge art; zstd layers are not decoded before Python 3.14. Read-only."""
import argparse
import base64
import gzip
import json
import os
import struct
import sys
import xml.etree.ElementTree as ET
import zlib
from pathlib import Path

TOOL = "check_tilemaps"
SCHEMA = 1
FLAGS = 0xF0000000
SKIP_DIRS = {"node_modules", "vendor", "__pycache__"}
TILED_EXTS = {".tmx", ".tmj", ".tsx", ".tsj", ".json", ".ldtk"}
ENGINES = ("phaser", "melonjs")

try:
    from compression import zstd as _zstd  # Python 3.14+
except ImportError:
    _zstd = None


class Report:
    def __init__(self, root):
        self.root = root
        self.items = []

    def add(self, severity, path, message):
        try:
            shown = Path(path).resolve().relative_to(self.root).as_posix()
        except ValueError:
            shown = Path(path).as_posix()
        if (severity, shown, message) not in self.items:
            self.items.append((severity, shown, message))


def png_size(path):
    try:
        with open(path, "rb") as f:
            head = f.read(24)
    except OSError:
        return None
    if len(head) < 24 or head[:8] != b"\x89PNG\r\n\x1a\n" or head[12:16] != b"IHDR":
        return None
    return struct.unpack(">II", head[16:24])


def parse_xml(path):
    """Parse a Tiled XML file, refusing entity declarations (Tiled never writes one) so no expansion runs."""
    raw = Path(path).read_bytes()
    if b"<!ENTITY" in raw:
        raise ET.ParseError("entity declarations are not accepted (Tiled never writes them)")
    return ET.fromstring(raw)


def is_tiled_tsx(path):
    """A .tsx is a Tiled tileset only when it is XML rooted at <tileset>; React components share the extension."""
    try:
        with open(path, "rb") as f:
            head = f.read(2048).decode("utf-8", "replace").lstrip("\ufeff \t\r\n")
    except OSError:
        return False
    if head.startswith("<?xml"):
        head = head[head.find("?>") + 2:].lstrip()
    return head.startswith("<tileset")


def decode_data(encoding, compression, payload, where, rep, path):
    """Return a list of raw GIDs, or None when the data cannot be decoded here."""
    if isinstance(payload, list):
        return [int(v) for v in payload]
    text = (payload or "").strip()
    if encoding == "csv":
        return [int(v) for v in text.replace("\n", "").split(",") if v.strip()]
    if encoding != "base64":
        return None
    raw = base64.b64decode(text)
    if compression == "zstd" and _zstd is None:
        rep.add("warn", path, f"{where}: zstd layer data not decoded (needs Python 3.14+); its GIDs were not checked")
        return None
    inflate = {"zlib": zlib.decompress, "gzip": gzip.decompress, "zstd": _zstd and _zstd.decompress}.get(compression)
    if compression and inflate is None:
        rep.add("error", path, f"{where}: unknown compression '{compression}'")
        return None
    if inflate:
        try:
            raw = inflate(raw)
        except Exception as error:  # zlib.error, BadGzipFile, EOFError, ZstdError: all mean corrupt data
            rep.add("error", path, f"{where}: {compression} layer data cannot be decompressed: {error}")
            return None
    if len(raw) % 4:
        rep.add("error", path, f"{where}: base64 data is {len(raw)} bytes, not a whole number of 32-bit GIDs")
        return None
    return list(struct.unpack(f"<{len(raw) // 4}I", raw))


class Tileset:
    def __init__(self, firstgid, tilecount, ids, label):
        self.firstgid, self.tilecount, self.ids, self.label = firstgid, tilecount, ids, label

    def owns(self, local):
        if self.ids is not None:
            return local in self.ids
        return self.tilecount is None or local < self.tilecount


def tileset_from_xml(node, base, rep, path, label):
    """Read a <tileset> element (embedded or a whole TSX); check its images exist relative to `base`."""
    tilecount = int(node.get("tilecount")) if node.get("tilecount") else None
    image = node.find("image")
    collection = image is None and node.find("tile/image") is not None
    if image is not None:
        check_image(image.get("source"), image.get("width"), image.get("height"), base, rep, path, label)
    ids = set()
    for tile in node.findall("tile"):
        ids.add(int(tile.get("id", "0")))
        img = tile.find("image")
        if img is not None:
            check_image(img.get("source"), None, None, base, rep, path, f"{label} tile {tile.get('id')}")
    return tilecount, (ids if collection else None)


def tileset_from_json(data, base, rep, path, label):
    tilecount = data.get("tilecount")
    if data.get("image"):
        check_image(data.get("image"), data.get("imagewidth"), data.get("imageheight"), base, rep, path, label)
    tiles = data.get("tiles") or []
    collection = not data.get("image") and any(t.get("image") for t in tiles)
    ids = set()
    for tile in tiles:
        ids.add(int(tile.get("id", 0)))
        if tile.get("image"):
            check_image(tile["image"], None, None, base, rep, path, f"{label} tile {tile.get('id')}")
    return tilecount, (ids if collection else None)


def check_image(source, width, height, base, rep, path, label):
    if not source:
        return
    target = base / source
    if not target.is_file():
        rep.add("error", path, f"{label}: image '{source}' not found (resolved against {base.name or base}/)")
        return
    size = png_size(target)
    if size and width and height and (int(width), int(height)) != size:
        rep.add("warn", path, f"{label}: image '{source}' is {size[0]}x{size[1]}, the tileset declares {width}x{height}; "
                              "loaders that derive columns from the image now map tile IDs to other pixels — reopen it in Tiled")


def load_external(source, base, rep, path, label, map_is_json, engine):
    target = base / source
    if engine == "phaser":
        rep.add("error", path, f"{label}: external tileset '{source}' — Phaser ignores external tilesets with only a "
                               "console.warn; embed it (Tiled: Embed Tileset) and re-export")
    if not target.is_file():
        rep.add("error", path, f"{label}: external tileset '{source}' not found")
        return None, None
    if map_is_json and target.suffix.lower() == ".tsx":
        rep.add("warn", path, f"{label}: JSON map references XML tileset '{source}'; a JSON-only loader cannot read it — "
                              "save the tileset as .tsj or embed it")
    try:
        if target.suffix.lower() in (".tsx", ".xml"):
            return tileset_from_xml(parse_xml(target), target.parent, rep, target, "tileset")
        return tileset_from_json(json.loads(target.read_text(encoding="utf-8-sig")), target.parent, rep, target, "tileset")
    except (ET.ParseError, ValueError, OSError) as error:
        rep.add("error", path, f"{label}: external tileset '{source}' cannot be parsed: {error}")
        return None, None


def check_gids(gids, tilesets, where, rep, path, expected=None):
    if gids is None:
        return
    if expected is not None and len(gids) != expected:
        rep.add("error", path, f"{where}: {len(gids)} tiles of data, expected {expected}")
    bad = []
    for index, raw in enumerate(gids):
        gid = raw & ~FLAGS
        if not gid:
            continue
        owner = None
        for ts in tilesets:
            if ts.firstgid <= gid:
                owner = ts
        if owner is None:
            bad.append((index, raw))
        elif owner.tilecount is not None or owner.ids is not None:
            if not owner.owns(gid - owner.firstgid):
                bad.append((index, raw))
    if bad:
        index, raw = bad[0]
        rep.add("error", path, f"{where}: {len(bad)} GID(s) belong to no tile after masking the flip bits "
                               f"(first: {raw} at index {index} -> {raw & ~FLAGS})")


def layer_formats(encoding, compression, where, rep, path, engine):
    if compression and engine == "phaser":
        rep.add("error", path, f"{where}: {compression}-compressed layer — Phaser skips compressed layers with only a console.warn; save as CSV")
    elif compression and engine == "melonjs":
        rep.add("warn", path, f"{where}: {compression}-compressed layer — melonJS throws 'No inflate function set' unless an inflate plugin is registered")
    elif compression == "zstd":
        rep.add("warn", path, f"{where}: zstd-compressed layer — zstd is a compile-time option even in Tiled; many loaders cannot read it")


def check_tmx(path, rep, engine):
    root = parse_xml(path)
    if root.tag != "map":
        rep.add("error", path, "not a Tiled map: root element is <" + root.tag + ">")
        return
    if engine == "phaser":
        rep.add("error", path, "TMX map — Phaser's tilemap loader reads Tiled JSON only; export as .tmj/.json")
    base = path.parent
    tilesets = []
    for node in root.findall("tileset"):
        firstgid = int(node.get("firstgid", "1"))
        label = f"tileset firstgid={firstgid}"
        if node.get("source"):
            count, ids = load_external(node.get("source"), base, rep, path, label, False, engine)
        else:
            count, ids = tileset_from_xml(node, base, rep, path, label)
        tilesets.append(Tileset(firstgid, count, ids, label))
    tilesets.sort(key=lambda t: t.firstgid)
    infinite = root.get("infinite") == "1"
    if infinite and engine != "phaser":
        rep.add("warn", path, "infinite map: tile data is in <chunk> elements; a loader that reads plain layer data gets empty layers")

    def walk(parent, trail):
        for node in parent:
            name = f"{trail}{node.get('name', node.tag)}"
            if node.tag == "layer":
                data = node.find("data")
                if data is None:
                    continue
                enc, comp = data.get("encoding"), data.get("compression")
                layer_formats(enc, comp, f"layer '{name}'", rep, path, engine)
                chunks = data.findall("chunk")
                if chunks:
                    for chunk in chunks:
                        where = f"layer '{name}' chunk ({chunk.get('x')},{chunk.get('y')})"
                        gids = decode_xml_data(chunk, enc, comp, where, rep, path)
                        check_gids(gids, tilesets, where, rep, path, int(chunk.get("width")) * int(chunk.get("height")))
                else:
                    gids = decode_xml_data(data, enc, comp, f"layer '{name}'", rep, path)
                    expected = None if infinite else int(node.get("width")) * int(node.get("height"))
                    check_gids(gids, tilesets, f"layer '{name}'", rep, path, expected)
            elif node.tag == "objectgroup":
                for obj in node.findall("object"):
                    where = f"layer '{name}' object {obj.get('id')}"
                    if obj.get("template") and not (base / obj.get("template")).is_file():
                        rep.add("error", path, f"{where}: template '{obj.get('template')}' not found")
                    if obj.get("gid"):
                        check_gids([int(obj.get("gid"))], tilesets, where, rep, path)
            elif node.tag == "imagelayer":
                img = node.find("image")
                if img is not None:
                    check_image(img.get("source"), None, None, base, rep, path, f"image layer '{name}'")
            elif node.tag == "group":
                walk(node, name + "/")

    walk(root, "")


def decode_xml_data(node, enc, comp, where, rep, path):
    if enc is None:
        return [int(t.get("gid", "0")) for t in node.findall("tile")]
    return decode_data(enc, comp, node.text, where, rep, path)


def check_tiled_json(path, doc, rep, engine):
    base = path.parent
    tilesets = []
    for entry in doc.get("tilesets") or []:
        firstgid = int(entry.get("firstgid", 1))
        label = f"tileset firstgid={firstgid}"
        if entry.get("source"):
            count, ids = load_external(entry["source"], base, rep, path, label, True, engine)
        else:
            count, ids = tileset_from_json(entry, base, rep, path, label)
        tilesets.append(Tileset(firstgid, count, ids, label))
    tilesets.sort(key=lambda t: t.firstgid)
    infinite = bool(doc.get("infinite"))
    if infinite and engine != "phaser":
        rep.add("warn", path, "infinite map: tile data is in layer 'chunks'; a loader that reads layer 'data' gets empty layers")

    def walk(layers, trail):
        for layer in layers or []:
            name = f"{trail}{layer.get('name', '?')}"
            kind = layer.get("type")
            if kind == "tilelayer":
                enc, comp = layer.get("encoding", "csv"), layer.get("compression") or None
                layer_formats(enc, comp, f"layer '{name}'", rep, path, engine)
                if layer.get("chunks"):
                    for chunk in layer["chunks"]:
                        where = f"layer '{name}' chunk ({chunk.get('x')},{chunk.get('y')})"
                        gids = decode_data(enc, comp, chunk.get("data"), where, rep, path)
                        check_gids(gids, tilesets, where, rep, path, int(chunk["width"]) * int(chunk["height"]))
                elif "data" in layer:
                    gids = decode_data(enc, comp, layer["data"], f"layer '{name}'", rep, path)
                    expected = None if infinite else int(layer["width"]) * int(layer["height"])
                    check_gids(gids, tilesets, f"layer '{name}'", rep, path, expected)
            elif kind == "objectgroup":
                for obj in layer.get("objects") or []:
                    where = f"layer '{name}' object {obj.get('id')}"
                    if obj.get("template") and not (base / obj["template"]).is_file():
                        rep.add("error", path, f"{where}: template '{obj['template']}' not found")
                    if obj.get("gid"):
                        check_gids([int(obj["gid"])], tilesets, where, rep, path)
            elif kind == "imagelayer":
                check_image(layer.get("image"), None, None, base, rep, path, f"image layer '{name}'")
            elif kind == "group":
                walk(layer.get("layers"), name + "/")

    walk(doc.get("layers"), "")


def check_ldtk(path, doc, rep):
    base = path.parent
    defs = doc.get("defs") or {}
    tilesets = {}
    for ts in defs.get("tilesets") or []:
        tilesets[ts.get("uid")] = ts
        rel = ts.get("relPath")
        label = f"tileset '{ts.get('identifier')}'"
        if not rel or ts.get("embedAtlas"):
            continue
        target = base / rel
        if not target.is_file():
            rep.add("error", path, f"{label}: image '{rel}' not found")
            continue
        if target.suffix.lower() in (".aseprite", ".ase"):
            rep.add("warn", path, f"{label}: image is an Aseprite file '{rel}'; LDtk reads it, a game loader needs an exported PNG")
            continue
        size = png_size(target)
        if size and (ts.get("pxWid"), ts.get("pxHei")) != size:
            rep.add("warn", path, f"{label}: '{rel}' is {size[0]}x{size[1]}, the project says {ts.get('pxWid')}x{ts.get('pxHei')}; "
                                  "tile src rects now point at other pixels — reopen and save in LDtk")
    layer_defs = {d.get("uid"): d for d in defs.get("layers") or []}
    levels = list(doc.get("levels") or [])
    for world in doc.get("worlds") or []:
        levels += world.get("levels") or []
    for level in levels:
        name = f"level '{level.get('identifier')}'"
        body, origin = level, path
        if level.get("bgRelPath") and not (base / level["bgRelPath"]).is_file():
            rep.add("error", path, f"{name}: background '{level['bgRelPath']}' not found")
        if level.get("layerInstances") is None:
            rel = level.get("externalRelPath")
            if not rel:
                rep.add("error", path, f"{name}: layerInstances is null and no externalRelPath names a .ldtkl file")
                continue
            target = base / rel
            if not target.is_file():
                rep.add("error", path, f"{name}: external level file '{rel}' not found (externalLevels is on)")
                continue
            try:
                body, origin = json.loads(target.read_text(encoding="utf-8-sig")), target
            except (ValueError, OSError) as error:
                rep.add("error", path, f"{name}: external level file '{rel}' cannot be parsed: {error}")
                continue
        check_ldtk_layers(body.get("layerInstances") or [], name, layer_defs, tilesets, rep, origin)


def check_ldtk_layers(instances, name, layer_defs, tilesets, rep, path):
    by_def = {inst.get("layerDefUid"): inst for inst in instances}
    for inst in instances:
        where = f"{name} layer '{inst.get('__identifier')}'"
        csv = inst.get("intGridCsv") or []
        cells = (inst.get("__cWid") or 0) * (inst.get("__cHei") or 0)
        if csv and len(csv) != cells:
            rep.add("error", path, f"{where}: intGridCsv has {len(csv)} cells, __cWid x __cHei is {cells}")
        definition = layer_defs.get(inst.get("layerDefUid")) or {}
        has_rules = any(rule.get("active", True) and rule.get("tileRectsIds")
                        for group in definition.get("autoRuleGroups") or [] if group.get("active", True)
                        for rule in group.get("rules") or [])
        source = inst if definition.get("type") == "IntGrid" else by_def.get(definition.get("autoSourceLayerDefUid"))
        if has_rules and source and any(source.get("intGridCsv") or []) and not inst.get("autoLayerTiles"):
            rep.add("warn", path, f"{where}: auto-layer rules and IntGrid cells but no autoLayerTiles — "
                                  "the IntGrid was edited outside LDtk; open and save the project in LDtk so the tiles are rebuilt")
        ts = tilesets.get(inst.get("__tilesetDefUid"))
        if not ts:
            continue
        grid = ts.get("tileGridSize") or inst.get("__gridSize") or 0
        tiles = (inst.get("gridTiles") or []) + (inst.get("autoLayerTiles") or [])
        outside = [t for t in tiles if t.get("src") and (t["src"][0] + grid > (ts.get("pxWid") or 0)
                                                           or t["src"][1] + grid > (ts.get("pxHei") or 0))]
        if outside:
            rep.add("error", path, f"{where}: {len(outside)} tile(s) read outside the {ts.get('pxWid')}x{ts.get('pxHei')} "
                                   f"tileset '{ts.get('identifier')}' (first src {outside[0]['src']})")


def check_file(path, rep, engine):
    """Return True when the file was a map or tileset this tool checks."""
    ext = path.suffix.lower()
    if ext == ".tsx" and not is_tiled_tsx(path):
        return False
    kind = {".tmx": "tmx", ".tsx": "tsx"}.get(ext)
    if ext in (".tmj", ".tsj", ".json", ".ldtk"):
        try:
            doc = json.loads(path.read_text(encoding="utf-8-sig"))
        except (ValueError, OSError) as error:
            if ext == ".json":
                return False
            rep.add("error", path, f"cannot be read as JSON: {error}")
            return True
        if not isinstance(doc, dict):
            return False
        if ext == ".ldtk" or ("jsonVersion" in doc and "defs" in doc):
            kind = "ldtk"
        elif doc.get("type") == "map" or (ext == ".tmj" and "layers" in doc):
            kind = "tiled-map"
        elif doc.get("type") == "tileset" or ext == ".tsj":
            kind = "tiled-tileset"
    if kind is None:
        return False
    try:
        if kind == "tmx":
            check_tmx(path, rep, engine)
        elif kind == "tsx":
            tileset_from_xml(parse_xml(path), path.parent, rep, path, "tileset")
        elif kind == "ldtk":
            check_ldtk(path, doc, rep)
        elif kind == "tiled-map":
            check_tiled_json(path, doc, rep, engine)
        else:
            tileset_from_json(doc, path.parent, rep, path, "tileset")
    except ET.ParseError as error:
        rep.add("error", path, f"XML cannot be parsed: {error}")
    except (ValueError, KeyError, TypeError, AttributeError, zlib.error, OSError, EOFError) as error:
        rep.add("error", path, f"malformed map data: {type(error).__name__}: {error}")
    return True


def discover(target):
    if target.is_file():
        return [target]
    found = []
    for directory, dirs, names in os.walk(target):
        dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS and not d.startswith("."))
        for name in sorted(names):
            if Path(name).suffix.lower() in TILED_EXTS:
                found.append(Path(directory) / name)
    return found


def main(argv=None):
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(errors="backslashreplace")
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter,
                                 epilog="exit status: 0 = no errors (warnings allowed), 1 = errors, or warnings with --strict,\n"
                                        "2 = bad arguments, unreadable target, or no map or tileset found.\n"
                                        "examples:\n  check_tilemaps.py assets/maps\n  check_tilemaps.py level1.tmj --engine phaser --json")
    ap.add_argument("paths", nargs="+", help="map/tileset/project files or directories to scan")
    ap.add_argument("--engine", choices=ENGINES, help="also fail what this engine's loader skips or rejects")
    ap.add_argument("--json", action="store_true", help="print one JSON object instead of text")
    ap.add_argument("--strict", action="store_true", help="exit 1 on warnings too")
    ap.add_argument("--max-issues", type=int, default=50, metavar="N", help="show at most N issues (default 50; 0 = all)")
    args = ap.parse_args(argv)
    if args.max_issues < 0:
        ap.error("--max-issues must be 0 or more")
    targets = [Path(p).expanduser().resolve() for p in args.paths]
    for target in targets:
        if not target.exists():
            print(f"error: {target} does not exist", file=sys.stderr)
            return 2
    root = targets[0] if targets[0].is_dir() else targets[0].parent
    rep = Report(root)
    checked = 0
    try:
        for target in targets:
            for path in discover(target):
                checked += check_file(path, rep, args.engine)
    except OSError as error:
        print(f"error: cannot scan target: {error}", file=sys.stderr)
        return 2
    if not checked:
        print("error: no Tiled map/tileset or LDtk project found", file=sys.stderr)
        return 2
    issues = sorted(rep.items, key=lambda i: (i[0] != "error", i[1], i[2]))
    errors = [{"file": f, "message": m} for s, f, m in issues if s == "error"]
    warnings = [{"file": f, "message": m} for s, f, m in issues if s == "warn"]
    limit = args.max_issues or len(issues)
    shown_errors = errors[:limit]
    shown_warnings = warnings[:max(0, limit - len(shown_errors))]
    truncated = len(shown_errors) + len(shown_warnings) < len(issues)
    if args.json:
        print(json.dumps({"tool": TOOL, "schema": SCHEMA, "root": root.as_posix(), "engine": args.engine,
                          "files_checked": checked, "error_count": len(errors), "warning_count": len(warnings),
                          "errors": shown_errors, "warnings": shown_warnings, "truncated": truncated}, indent=2))
    else:
        for item in shown_errors:
            print(f"ERROR {item['file']}: {item['message']}")
        for item in shown_warnings:
            print(f"WARNING {item['file']}: {item['message']}")
        if truncated:
            print(f"... and {len(issues) - len(shown_errors) - len(shown_warnings)} more")
        print(f"Summary: {len(errors)} errors, {len(warnings)} warnings in {checked} files checked")
    return 1 if errors or (args.strict and warnings) else 0


if __name__ == "__main__":
    sys.exit(main())
