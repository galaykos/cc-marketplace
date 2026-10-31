#!/usr/bin/env python3
"""Catches a sprite-sheet JSON (Aseprite --data, TexturePacker-style hash or array) that disagrees with its PNG or itself:
missing or resized image, frames outside it, tag ranges past the frames array, bad durations, duplicate json-hash keys.
Does NOT read pixels (alpha, colours and size limits are gamedev's asset_report.py) or judge animation. Read-only."""
import argparse
import json
import os
import struct
import sys
from pathlib import Path

TOOL = "check_sprite_sheet"
SCHEMA = 1
SKIP_DIRS = {"node_modules", "vendor", "__pycache__"}
DIRECTIONS = {"forward", "reverse", "pingpong", "pingpong_reverse"}


def png_size(path):
    try:
        with open(path, "rb") as f:
            head = f.read(24)
    except OSError:
        return None
    if len(head) < 24 or head[:8] != b"\x89PNG\r\n\x1a\n" or head[12:16] != b"IHDR":
        return None
    return struct.unpack(">II", head[16:24])


def load(path):
    """Return (document, duplicate frame keys); json.load would keep only the last of a repeated key."""
    duplicates = []

    def pairs(items):
        if any(isinstance(value, dict) and "frame" in value for _, value in items):
            seen = set()
            for key, _ in items:
                if key in seen:
                    duplicates.append(key)
                seen.add(key)
        return dict(items)

    return json.loads(Path(path).read_text(encoding="utf-8-sig"), object_pairs_hook=pairs), duplicates


def is_sheet(doc):
    return (isinstance(doc, dict) and isinstance(doc.get("frames"), (dict, list))
            and isinstance(doc.get("meta"), dict) and ("image" in doc["meta"] or "size" in doc["meta"]))


def rect(value, keys):
    if not isinstance(value, dict) or any(not isinstance(value.get(k), int) for k in keys):
        return None
    return tuple(value[k] for k in keys)


def check_sheet(path, doc, duplicates, add):
    meta = doc["meta"]
    frames = list(doc["frames"].items()) if isinstance(doc["frames"], dict) else \
        [(f.get("filename", str(i)) if isinstance(f, dict) else str(i), f) for i, f in enumerate(doc["frames"])]
    if isinstance(doc["frames"], dict):
        for key in sorted(set(duplicates)):
            add("error", f"frame key '{key}' repeats: a json-hash loader keeps only the last one; put {{layer}} or {{tag}} "
                         "in --filename-format, or export --format json-array")
    declared = rect(meta.get("size"), ("w", "h"))
    image_size = None
    if meta.get("image"):
        image = path.parent / meta["image"]
        if not image.is_file():
            add("error", f"meta.image '{meta['image']}' not found next to the JSON")
        else:
            image_size = png_size(image)
            if image_size is None:
                add("warn", f"meta.image '{meta['image']}' is not a PNG; frame bounds checked against meta.size only")
            elif declared and image_size != declared:
                add("error", f"'{meta['image']}' is {image_size[0]}x{image_size[1]} but meta.size says {declared[0]}x{declared[1]}: "
                             "the sheet and its JSON come from different exports — re-export both")
    else:
        add("warn", "meta.image is absent (exported without --sheet?); frame bounds checked against meta.size only")
    bounds = image_size or declared
    timed = [f for _, f in frames if isinstance(f, dict) and "duration" in f]
    source_sizes = []
    for name, frame in frames:
        where = f"frame '{name}'"
        if not isinstance(frame, dict):
            add("error", f"{where}: not an object")
            source_sizes.append(None)
            continue
        box = rect(frame.get("frame"), ("x", "y", "w", "h"))
        source = rect(frame.get("sourceSize"), ("w", "h"))
        source_sizes.append(source)
        if box is None:
            add("error", f"{where}: 'frame' is missing or not integer x/y/w/h")
        elif box[2] <= 0 or box[3] <= 0 or box[0] < 0 or box[1] < 0:
            add("error", f"{where}: frame rect {box} has a negative origin or no area")
        elif bounds and not frame.get("rotated") and (box[0] + box[2] > bounds[0] or box[1] + box[3] > bounds[1]):
            add("error", f"{where}: frame rect {box} reaches outside the {bounds[0]}x{bounds[1]} sheet")
        trim = rect(frame.get("spriteSourceSize"), ("x", "y", "w", "h"))
        if trim and source and (trim[0] < 0 or trim[1] < 0 or trim[0] + trim[2] > source[0] or trim[1] + trim[3] > source[1]):
            add("error", f"{where}: spriteSourceSize {trim} lies outside sourceSize {source}")
        if timed:
            duration = frame.get("duration")
            if not isinstance(duration, (int, float)) or isinstance(duration, bool) or duration <= 0:
                add("error", f"{where}: duration {duration!r} — every frame needs a positive duration in milliseconds")
    tags = meta.get("frameTags")
    is_aseprite = "aseprite" in str(meta.get("app", "")).lower()
    if tags is None:
        if is_aseprite and len(frames) > 1:
            add("warn", f"{len(frames)} frames and no meta.frameTags: the export ran without --list-tags, so no loader sees animations")
        return
    for tag in tags if isinstance(tags, list) else []:
        name = tag.get("name") if isinstance(tag, dict) else None
        start, end = (tag.get("from"), tag.get("to")) if isinstance(tag, dict) else (None, None)
        where = f"tag '{name}'"
        if not isinstance(start, int) or not isinstance(end, int):
            add("error", f"{where}: from/to are not integers")
            continue
        if start > end:
            add("error", f"{where}: from {start} is after to {end}")
        elif start < 0 or end >= len(frames):
            add("error", f"{where}: frames {start}-{end} but the frames array has {len(frames)} entries — tags index sprite "
                         "frames, so --ignore-empty, --tag or --frame-range exports drift from them")
        else:
            sizes = {s for s in source_sizes[start:end + 1] if s}
            if len(sizes) > 1:
                add("warn", f"{where}: frames have different sourceSize {sorted(sizes)}; the animation's origin jumps between them")
        if tag.get("direction") is not None and tag["direction"] not in DIRECTIONS:
            add("warn", f"{where}: direction '{tag['direction']}' is not one Aseprite writes ({', '.join(sorted(DIRECTIONS))})")
        repeat = tag.get("repeat")
        if repeat is not None and not str(repeat).isdigit():
            add("warn", f"{where}: repeat {repeat!r} is not a whole number (Aseprite writes it as a string such as \"2\")")


def discover(target):
    if target.is_file():
        return [target]
    found = []
    for directory, dirs, names in os.walk(target):
        dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS and not d.startswith("."))
        found += [Path(directory) / n for n in sorted(names) if n.lower().endswith(".json")]
    return found


def main(argv=None):
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(errors="backslashreplace")
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter,
                                 epilog="exit status: 0 = no errors (warnings allowed), 1 = errors, or warnings with --strict,\n"
                                        "2 = bad arguments, unreadable target, or no sprite-sheet JSON found.\n"
                                        "examples:\n  check_sprite_sheet.py art/\n  check_sprite_sheet.py hero.json --strict --json")
    ap.add_argument("paths", nargs="+", help="sheet JSON files or directories to scan")
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
    issues, checked = [], 0
    for target in targets:
        for path in discover(target):
            try:
                doc, duplicates = load(path)
            except (ValueError, OSError) as error:
                if target.is_file():
                    print(f"error: {path.name} cannot be read as JSON: {error}", file=sys.stderr)
                    return 2
                continue
            if not is_sheet(doc):
                if target.is_file():
                    print(f"error: {path.name} has no frames + meta: not a sprite-sheet JSON", file=sys.stderr)
                    return 2
                continue
            checked += 1
            try:
                shown = path.relative_to(root).as_posix()
            except ValueError:
                shown = path.as_posix()
            check_sheet(path, doc, duplicates, lambda sev, msg, f=shown: issues.append((sev, f, msg)))
    if not checked:
        print("error: no sprite-sheet JSON (frames + meta) found", file=sys.stderr)
        return 2
    issues.sort(key=lambda i: (i[0] != "error", i[1]))
    errors = [{"file": f, "message": m} for s, f, m in issues if s == "error"]
    warnings = [{"file": f, "message": m} for s, f, m in issues if s == "warn"]
    limit = args.max_issues or len(issues)
    shown_errors = errors[:limit]
    shown_warnings = warnings[:max(0, limit - len(shown_errors))]
    truncated = len(shown_errors) + len(shown_warnings) < len(issues)
    if args.json:
        print(json.dumps({"tool": TOOL, "schema": SCHEMA, "root": root.as_posix(), "files_checked": checked,
                          "error_count": len(errors), "warning_count": len(warnings),
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
