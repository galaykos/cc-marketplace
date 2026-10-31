#!/usr/bin/env python3
"""Measures .glb/.gltf files from their JSON: triangles per drawn mesh instance, PNG/JPEG sizes, required extensions, extents.
Exit 1 on a broken budget, a required extension not allowed, or a missing external file; 2 if a file is not readable glTF 2.0.
Does NOT decode or validate geometry: counts trust accessor counts, extents trust POSITION min/max, skinned meshes in bind pose."""
import argparse
import base64
import binascii
import json
import os
import struct
import sys
from pathlib import Path
from urllib.parse import unquote

TOOL = "inspect_glb"
SCHEMA = 1
CHUNK_JSON = 0x4E4F534A
CHUNK_BIN = 0x004E4942
MAX_JSON_BYTES = 64 * 1024 * 1024
SNIFF_BYTES = 256 * 1024
JPEG_SOF = {0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF}


class Unreadable(Exception):
    pass


def parse_json(raw):
    try:
        doc = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, ValueError) as error:
        raise Unreadable(f"glTF JSON does not parse ({error})")
    if not isinstance(doc, dict):
        raise Unreadable("glTF JSON is not an object")
    version = (doc.get("asset") or {}).get("version") if isinstance(doc.get("asset"), dict) else None
    if not isinstance(version, str) or not version.startswith("2."):
        raise Unreadable(f"asset.version is {version!r}, not 2.x")
    return doc


def load(path):
    """Return (doc, format, bin_chunk) where bin_chunk is (file offset, length) or None."""
    try:
        with open(path, "rb") as f:
            size = os.fstat(f.fileno()).st_size
            head = f.read(12)
            if head[:4] != b"glTF":
                f.seek(0)
                raw = f.read(MAX_JSON_BYTES + 1)
                if len(raw) > MAX_JSON_BYTES:
                    raise Unreadable("a .gltf over 64 MiB is not read")
                return parse_json(raw), "gltf", None
            if len(head) < 12:
                raise Unreadable("truncated GLB header")
            version, length = struct.unpack("<II", head[4:])
            if version != 2:
                raise Unreadable(f"GLB container version {version}, not 2")
            if length > size:
                raise Unreadable(f"GLB header says {length} bytes, the file has {size}")
            chunk = f.read(8)
            if len(chunk) < 8:
                raise Unreadable("GLB has no JSON chunk")
            json_length, json_type = struct.unpack("<II", chunk)
            if json_type != CHUNK_JSON:
                raise Unreadable("the first GLB chunk is not JSON")
            if 20 + json_length > length or json_length > MAX_JSON_BYTES:
                raise Unreadable("the JSON chunk runs past the end of the file")
            doc = parse_json(f.read(json_length))
            bin_chunk, at = None, 20 + json_length
            if at + 8 <= length:
                f.seek(at)
                bin_length, bin_type = struct.unpack("<II", f.read(8))
                if bin_type == CHUNK_BIN:
                    if at + 8 + bin_length > length:
                        raise Unreadable("the BIN chunk runs past the end of the file")
                    bin_chunk = (at + 8, bin_length)
            return doc, "glb", bin_chunk
    except OSError as error:
        raise Unreadable(f"cannot read: {error.strerror or error}")


def item(doc, key, index, owner):
    array = doc.get(key)
    if (not isinstance(index, int) or isinstance(index, bool) or not isinstance(array, list)
            or not 0 <= index < len(array) or not isinstance(array[index], dict)):
        raise Unreadable(f"{owner} references {key}[{index}], which does not exist")
    return array[index]


def numbers(value, n):
    return (isinstance(value, list) and len(value) == n
            and all(isinstance(v, (int, float)) and not isinstance(v, bool) for v in value))


def matmul(a, b):
    return [[sum(a[r][k] * b[k][c] for k in range(4)) for c in range(4)] for r in range(4)]


def local_matrix(node, index):
    if "matrix" in node:
        m = node["matrix"]
        if not numbers(m, 16):
            raise Unreadable(f"node {index} has a matrix that is not 16 numbers")
        return [[m[c * 4 + r] for c in range(4)] for r in range(4)]
    t, q, s = node.get("translation", [0, 0, 0]), node.get("rotation", [0, 0, 0, 1]), node.get("scale", [1, 1, 1])
    if not (numbers(t, 3) and numbers(q, 4) and numbers(s, 3)):
        raise Unreadable(f"node {index} has a malformed translation, rotation or scale")
    x, y, z, w = q
    rot = [[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
           [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
           [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]]
    return [[rot[i][j] * s[j] for j in range(3)] + [t[i]] for i in range(3)] + [[0, 0, 0, 1]]


IDENTITY = [[1 if r == c else 0 for c in range(4)] for r in range(4)]


def measure_mesh(doc, mesh_index, matrix, bounds, owner):
    mesh = item(doc, "meshes", mesh_index, owner)
    triangles, unbounded = 0, 0
    for primitive in mesh.get("primitives") or []:
        attributes = primitive.get("attributes") or {}
        indices, position_index = primitive.get("indices"), attributes.get("POSITION")
        if position_index is None:
            unbounded += 1
            continue
        counted = item(doc, "accessors", indices if indices is not None else position_index, f"mesh {mesh_index}")
        count, mode = counted.get("count"), primitive.get("mode", 4)
        if not isinstance(count, int) or isinstance(count, bool) or count < 0:
            raise Unreadable(f"mesh {mesh_index} has an accessor without a count")
        if mode == 4:
            triangles += count // 3
        elif mode in (5, 6):
            triangles += max(0, count - 2)
        position = item(doc, "accessors", position_index, f"mesh {mesh_index}")
        low, high = position.get("min"), position.get("max")
        if not (numbers(low, 3) and numbers(high, 3)):
            unbounded += 1
            continue
        for corner in ((a, b, c) for a in (low[0], high[0]) for b in (low[1], high[1]) for c in (low[2], high[2])):
            point = [sum(matrix[r][k] * corner[k] for k in range(3)) + matrix[r][3] for r in range(3)]
            for axis in range(3):
                bounds[0][axis] = min(bounds[0][axis], point[axis])
                bounds[1][axis] = max(bounds[1][axis], point[axis])
    return triangles, unbounded


def drawn_meshes(doc):
    """Yield (mesh index, world matrix, owner) for every mesh instance of the default scene."""
    scenes = doc.get("scenes")
    if not isinstance(scenes, list) or not scenes:
        for index in range(len(doc.get("meshes") or [])):
            yield index, IDENTITY, f"mesh {index}"
        return
    scene = item(doc, "scenes", doc.get("scene", 0), "the document")
    stack, seen = [(n, IDENTITY) for n in reversed(scene.get("nodes") or [])], set()
    while stack:
        index, parent = stack.pop()
        node = item(doc, "nodes", index, "the scene graph")
        if index in seen:
            raise Unreadable(f"node {index} is reached twice in the scene graph")
        seen.add(index)
        world = matmul(parent, local_matrix(node, index))
        if "mesh" in node:
            yield node["mesh"], IDENTITY if "skin" in node else world, f"node {index}"
        stack.extend((child, world) for child in reversed(node.get("children") or []))


def image_size(data):
    if data[:8] == b"\x89PNG\r\n\x1a\n" and data[12:16] == b"IHDR" and len(data) >= 24:
        return struct.unpack(">II", data[16:24])
    if data[:2] != b"\xff\xd8":
        return None
    i = 2
    while i + 4 <= len(data):
        if data[i] != 0xFF:
            return None
        marker = data[i + 1]
        if marker == 0xFF:
            i += 1
        elif marker == 0x01 or 0xD0 <= marker <= 0xD8:
            i += 2
        elif marker in JPEG_SOF:
            if i + 9 > len(data):
                return None
            height, width = struct.unpack(">HH", data[i + 5:i + 9])
            return width, height
        else:
            i += 2 + struct.unpack(">H", data[i + 2:i + 4])[0]
    return None


def data_uri(uri, offset=0, length=SNIFF_BYTES):
    header, _, payload = uri.partition(",")
    if not header.endswith(";base64"):
        return unquote(payload).encode("latin-1", "replace")[offset:offset + length]
    start, end = offset // 3 * 4, -(-(offset + length) // 3) * 4
    try:
        return base64.b64decode(payload[start:end])[offset % 3:offset % 3 + length]
    except (binascii.Error, ValueError):
        return b""


class Source:
    def __init__(self, path, doc, bin_chunk):
        self.path, self.doc, self.bin_chunk, self.missing = path, doc, bin_chunk, []

    def external(self, uri):
        """Path of a relative file URI, or None for data: and remote URIs."""
        if uri.startswith("data:") or "://" in uri:
            return None
        return self.path.parent / unquote(uri)

    def read(self, uri, offset, length):
        local = self.external(uri)
        if local is None:
            return data_uri(uri, offset, length) if uri.startswith("data:") else None
        if not local.is_file():
            self.missing.append(uri)
            return None
        with open(local, "rb") as f:
            f.seek(offset)
            return f.read(length)

    def buffer_bytes(self, buffer_index, offset, length, owner):
        buffer = item(self.doc, "buffers", buffer_index, owner)
        if "uri" in buffer:
            return self.read(buffer["uri"], offset, length)
        if buffer_index != 0 or self.bin_chunk is None:
            raise Unreadable(f"buffer {buffer_index} has no uri and no GLB BIN chunk")
        with open(self.path, "rb") as f:
            f.seek(self.bin_chunk[0] + offset)
            return f.read(min(length, max(0, self.bin_chunk[1] - offset)))


def measure_images(doc, source):
    images, embedded = [], 0
    for index, image in enumerate(doc.get("images") or []):
        if not isinstance(image, dict):
            raise Unreadable(f"images[{index}] is not an object")
        if "bufferView" in image:
            view = item(doc, "bufferViews", image["bufferView"], f"image {index}")
            data = source.buffer_bytes(view.get("buffer"), view.get("byteOffset", 0),
                                       min(view.get("byteLength", 0), SNIFF_BYTES), f"image {index}")
            embedded += 1
        elif isinstance(image.get("uri"), str):
            data = source.read(image["uri"], 0, SNIFF_BYTES)
            embedded += image["uri"].startswith("data:")
        else:
            raise Unreadable(f"image {index} has neither a uri nor a bufferView")
        size = image_size(data) if data else None
        images.append({"index": index, "width": size[0] if size else None, "height": size[1] if size else None})
    return images, embedded


def inspect(path, args):
    doc, fmt, bin_chunk = load(path)
    source, bounds = Source(path, doc, bin_chunk), [[float("inf")] * 3, [float("-inf")] * 3]
    triangles = instances = unbounded = 0
    for mesh_index, matrix, owner in drawn_meshes(doc):
        count, missing_bounds = measure_mesh(doc, mesh_index, matrix, bounds, owner)
        triangles, instances, unbounded = triangles + count, instances + 1, unbounded + missing_bounds
    for buffer in doc.get("buffers") or []:
        if isinstance(buffer, dict) and "uri" in buffer and (local := source.external(buffer["uri"])) and not local.is_file():
            source.missing.append(buffer["uri"])
    images, embedded = measure_images(doc, source)
    measured = [max(i["width"], i["height"]) for i in images if i["width"] is not None]
    required = [e for e in doc.get("extensionsRequired") or [] if isinstance(e, str)]
    failures = []
    if args.max_tris is not None and triangles > args.max_tris:
        failures.append(f"triangles {triangles:,} > --max-tris {args.max_tris:,}")
    if args.max_texture is not None:
        failures += [f"image {i['index']} is {i['width']}x{i['height']} > --max-texture {args.max_texture}"
                     for i in images if i["width"] is not None and max(i["width"], i["height"]) > args.max_texture]
        failures += [f"image {i['index']} size unknown (not PNG/JPEG or not found): not counted as within budget"
                     for i in images if i["width"] is None]
    failures += [f"requires extension {e}; pass --allow-ext {e} if the importer supports it"
                 for e in required if e not in args.allow_ext]
    failures += [f"external file missing: {uri}" for uri in dict.fromkeys(source.missing)]
    have_bounds = bounds[0][0] != float("inf")
    return {
        "path": str(path), "format": fmt, "generator": (doc.get("asset") or {}).get("generator"),
        "triangles": triangles, "mesh_instances": instances, "meshes": len(doc.get("meshes") or []),
        "materials": len(doc.get("materials") or []), "textures": len(doc.get("textures") or []),
        "images": {"total": len(images), "embedded": embedded, "external": len(images) - embedded,
                   "largest_px": max(measured) if measured else None, "sizes": images},
        "animations": len(doc.get("animations") or []), "skins": len(doc.get("skins") or []),
        "extensions_required": required,
        "extensions_used": [e for e in doc.get("extensionsUsed") or [] if isinstance(e, str)],
        "extents_m": {"size": [round(bounds[1][a] - bounds[0][a], 6) for a in range(3)],
                      "min": [round(v, 6) for v in bounds[0]], "max": [round(v, 6) for v in bounds[1]]} if have_bounds else None,
        "primitives_without_bounds": unbounded, "failures": failures,
    }


def print_text(report):
    print(f"{report['path']} ({report['format']}, generator {report['generator']!r})")
    print(f"  triangles {report['triangles']:,} in {report['mesh_instances']} drawn mesh instances ({report['meshes']} meshes)")
    if report["extents_m"]:
        x, y, z = report["extents_m"]["size"]
        print(f"  extents {x:.3f} x {y:.3f} x {z:.3f} m (x, y, z; glTF is metres, +Y up)")
    if report["primitives_without_bounds"]:
        print(f"  {report['primitives_without_bounds']} primitives have no POSITION min/max; extents leave them out")
    img = report["images"]
    print(f"  materials {report['materials']}, textures {report['textures']}, images {img['total']} "
          f"({img['embedded']} embedded, {img['external']} external), largest {img['largest_px'] or '-'} px")
    print(f"  animations {report['animations']}, skins {report['skins']}")
    print(f"  extensions required: {', '.join(report['extensions_required']) or 'none'}; "
          f"used: {', '.join(report['extensions_used']) or 'none'}")
    for failure in report["failures"]:
        print(f"  FAIL {failure}")


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter,
                                 epilog="exit status: 0 = every file within budget, 1 = a file failed a check,\n"
                                        "2 = bad arguments or a file that is not readable glTF 2.0 (2 wins over 1).")
    ap.add_argument("files", nargs="+", type=Path, help=".glb or .gltf files")
    ap.add_argument("--max-tris", type=int, metavar="N", help="fail when the drawn triangle count exceeds N")
    ap.add_argument("--max-texture", type=int, metavar="PX", help="fail when an image side exceeds PX, or its size is unknown")
    ap.add_argument("--allow-ext", action="append", default=[], metavar="NAME",
                    help="a required extension the target importer supports (repeatable); any other fails")
    ap.add_argument("--json", action="store_true", help="print one JSON object instead of text")
    args = ap.parse_args(argv)
    for flag, value in (("--max-tris", args.max_tris), ("--max-texture", args.max_texture)):
        if value is not None and value < 1:
            ap.error(f"{flag} must be 1 or more")
    reports, unreadable = [], 0
    for path in args.files:
        try:
            reports.append(inspect(path, args))
        except Unreadable as error:
            unreadable += 1
            reports.append({"path": str(path), "error": str(error)})
        except Exception as error:  # a malformed file must never exit 1, which reads as a measured failure
            unreadable += 1
            reports.append({"path": str(path), "error": f"malformed glTF ({type(error).__name__}: {error})"})
    failed = sum(1 for r in reports if r.get("failures"))
    if args.json:
        print(json.dumps({"tool": TOOL, "schema": SCHEMA, "files": reports,
                          "failed": failed, "unreadable": unreadable}, indent=2))
    else:
        for report in reports:
            if "error" in report:
                print(f"{report['path']}\n  ERROR {report['error']}")
            else:
                print_text(report)
        print(f"Summary: {failed} failed, {unreadable} unreadable, {len(reports)} files")
    return 2 if unreadable else 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
