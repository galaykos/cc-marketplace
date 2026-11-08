"""Technical QA of one mesh object against a platform budget and an engine preset. Read-only: neither the object nor
the scene is changed. Units: metres, square metres, pixels, degrees."""
import math
import re
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix, Vector

from . import util

SCALE_EPS = 1e-4
ROTATION_EPS_DEG = 0.01
PIVOT_TOLERANCE = 0.01
UV_EPS = 1e-4
DEGENERATE_UV_AREA = 1e-9
UV_GRID = 512
SIZE_RANGE_M = (0.01, 500.0)
EXPECTED_SIZE_TOLERANCE = 0.25
COLLISION_TOKEN = re.compile(r"(?i)(^|[_\-.])((ucx|ubx|usp|ucp)|(conv)?col(lider|lision|only)?)(?=$|[_\-.\d])")


def validate_asset(obj, engine="unity", platform="pc", asset_class="prop_medium", overrides=None,
                   expected_size_m=None):
    """Check a mesh object against presets/budgets/<platform>.json and presets/engines/<engine>.json.

    overrides: a dict deep-merged over the budget (e.g. {"tris": {"prop_small": 800}}). expected_size_m: the real
    size of the asset's largest dimension in metres; without it only sizes under 1 cm or over 500 m are flagged.
    The mesh is measured with modifiers applied, in world space. Returns passed (no check failed), checks
    [{id, status: pass|fail|warn, measured, limit, hint}] and summary (counts per status, failed ids)."""
    obj = util.get_object(obj, "MESH")
    bpy.context.view_layer.update()
    preset = util.load_preset("engines", engine)
    budget = _merge(util.load_preset("budgets", platform), overrides or {})
    for key in ("tris", "max_materials", "texture_max_px"):
        if asset_class not in budget.get(key, {}):
            raise util.ForgeError(f"budget {platform!r} has no {key} for {asset_class!r}; "
                                  f"known: {sorted(budget.get('tris', {}))}")
    if expected_size_m is not None and not (isinstance(expected_size_m, (int, float)) and expected_size_m > 0):
        raise util.ForgeError(f"expected_size_m must be a positive number of metres, got {expected_size_m!r}")
    checks = []

    def add(check_id, status, measured, limit, hint=""):
        if isinstance(status, bool):
            status = "pass" if status else "fail"
        checks.append({"id": check_id, "status": status, "measured": measured, "limit": limit,
                       "hint": "" if status == "pass" else hint})

    mesh = _measure(obj)
    images = _material_images(obj)
    naming = preset.get("naming", {})
    base = _base_name(obj.name, naming.get("lod"))

    tri_limit = budget["tris"][asset_class]
    add("tris", mesh["tris"] <= tri_limit, mesh["tris"], tri_limit,
        "over the triangle budget: decimate or retopologise, or pick the right asset_class")
    ratios = budget.get("lod_ratios", [1.0])
    for n, lod in _lods(obj, base, naming.get("lod")):
        count = util.tri_count(lod)
        if n >= len(ratios):
            add(f"tris_lod{n}", "warn", count, None, f"{lod.name}: the budget lists no LOD ratio for LOD{n}")
            continue
        limit = round(tri_limit * ratios[n])
        add(f"tris_lod{n}", count <= limit, count, limit, f"{lod.name} is over budget x {ratios[n]}: reduce it")

    slots, slot_limit = len(obj.material_slots), budget["max_materials"][asset_class]
    add("materials", slots <= slot_limit, slots, slot_limit, "merge materials or atlas the textures")

    world3 = obj.matrix_world.to_3x3()
    scale = [round(world3.col[i].length, 4) for i in range(3)]
    mirrored = world3.determinant() < 0
    unmirrored = world3 @ Matrix.Diagonal((-1.0 if mirrored else 1.0, 1.0, 1.0))
    rotation = round(math.degrees(unmirrored.to_quaternion().angle), 4)
    parent = f" (or on its parent {obj.parent.name})" if obj.parent else ""
    add("rotation", rotation <= ROTATION_EPS_DEG, rotation, 0.0,
        f"apply rotation{parent}: forge.util.apply_transforms(obj)")
    add("scale", not mirrored and all(abs(s - 1) <= SCALE_EPS for s in scale), scale, [1.0, 1.0, 1.0],
        f"apply {'the negative ' if mirrored else ''}scale{parent}: forge.util.apply_transforms(obj)")

    add(*_pivot(preset.get("pivot"), obj.matrix_world.translation, mesh["lo"], mesh["hi"]))
    add("ngons", mesh["ngons"] == 0, mesh["ngons"], 0, "triangulate or quad the faces with more than 4 corners")
    edges = mesh["edges"]
    status = "fail" if edges["multi_face"] or edges["wire"] else "warn" if edges["boundary"] else "pass"
    add("non_manifold", status, edges, {"multi_face": 0, "wire": 0, "boundary": 0},
        "edges with more than two faces or none break baking and tangents; open boundaries are fine for cards")
    add("loose_verts", mesh["loose_verts"] == 0, mesh["loose_verts"], 0, "delete vertices that belong to no edge")
    normals = {"inconsistent_edges": mesh["inconsistent_edges"], "inside_out": mesh["inside_out"]}
    add("normals", not mesh["inconsistent_edges"] and not mesh["inside_out"], normals,
        {"inconsistent_edges": 0, "inside_out": False}, "recalculate normals outside")
    _uv_checks(add, mesh, budget, asset_class, images)

    pattern = naming.get("mesh")
    add("name", bool(pattern and re.match(pattern, obj.name)), obj.name, pattern,
        f"rename to match the {engine} mesh pattern")
    named, misnamed = _collision(obj, base, naming.get("collision", {}))
    add("collision_naming", not misnamed, {"named": named, "misnamed": misnamed},
        sorted(set(naming.get("collision", {}).values())), f"rename collision meshes to the {engine} pattern")

    size = round(max(mesh["hi"] - mesh["lo"]), 4) if mesh["verts"] else 0.0
    if expected_size_m is not None:
        span = [round(expected_size_m * (1 - EXPECTED_SIZE_TOLERANCE), 4),
                round(expected_size_m * (1 + EXPECTED_SIZE_TOLERANCE), 4)]
        add("real_world_scale", span[0] <= size <= span[1], size, span,
            "largest dimension is off the expected real size: check units and scale")
    else:
        add("real_world_scale", "pass" if SIZE_RANGE_M[0] <= size <= SIZE_RANGE_M[1] else "warn", size,
            list(SIZE_RANGE_M), "largest dimension is implausible for a game asset: check units (cm vs m)")

    px_limit = budget["texture_max_px"][asset_class]
    sizes = {i.name: max(i.size) for i in images}
    over = sorted(n for n, px in sizes.items() if px > px_limit)
    add("texture_resolution", not over, max(sizes.values(), default=0), px_limit,
        f"downscale {over} to {px_limit} px or less")
    missing = sorted(i.name for i in images if _missing_on_disk(i))
    add("missing_images", not missing, missing, [], "relink or pack the images whose files are gone")

    counts = {s: sum(c["status"] == s for c in checks) for s in ("pass", "warn", "fail")}
    summary = {"object": obj.name, "engine": engine, "platform": platform, "asset_class": asset_class, **counts,
               "failed": [c["id"] for c in checks if c["status"] == "fail"]}
    return util.ok(passed=counts["fail"] == 0, checks=checks, summary=summary)


def _merge(base, over):
    merged = dict(base)
    for key, value in over.items():
        merged[key] = _merge(merged[key], value) if isinstance(value, dict) and isinstance(merged.get(key), dict) \
            else value
    return merged


def _pattern_regex(pattern, name=None):
    """A regex for a preset pattern such as '{name}_LOD{n}' or 'UCX_{name}_{nn}'; name=None captures the name."""
    rx = re.escape(pattern)
    rx = rx.replace(re.escape("{name}"), re.escape(name) if name is not None else "(?P<name>.+?)")
    rx = rx.replace(re.escape("{nn}"), r"(?P<nn>\d{2})").replace(re.escape("{n}"), r"(?P<n>\d+)")
    return re.compile(f"^{rx}$")


def _base_name(name, lod_pattern):
    if lod_pattern:
        match = _pattern_regex(lod_pattern).match(name)
        if match and "n" in match.groupdict() and int(match["n"]) == 0:
            return match["name"]
    return name


def _lods(obj, base, lod_pattern):
    if not lod_pattern:
        return []
    rx = _pattern_regex(lod_pattern, base)
    found = []
    for other in bpy.data.objects:
        match = rx.match(other.name) if other is not obj and other.type == "MESH" else None
        if match and "n" in match.groupdict():
            found.append((int(match["n"]), other))
    return sorted(found, key=lambda pair: pair[0])


def _collision(obj, base, patterns):
    rxs = [_pattern_regex(p, base) for p in patterns.values()]
    candidates = {o for o in obj.children if o.type == "MESH"}
    candidates |= {o for o in bpy.data.objects
                   if o.type == "MESH" and o is not obj and base.lower() in o.name.lower()}
    named, misnamed = [], []
    for other in sorted(candidates, key=lambda o: o.name):
        if any(rx.match(other.name) for rx in rxs):
            named.append(other.name)
        elif COLLISION_TOKEN.search(other.name):
            misnamed.append(other.name)
    return named, misnamed


def _pivot(rule, origin, lo, hi):
    tolerance = round(max(1e-3, PIVOT_TOLERANCE * max(hi - lo)), 4)
    if rule == "bottom_center":
        target = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
        hint = "set the origin to the bottom centre of the bounding box"
    elif rule == "world_origin":
        target = Vector((0.0, 0.0, 0.0))
        hint = "move the object so its origin sits at the world origin"
    else:
        return "pivot", "warn", None, rule, f"the engine preset names no known pivot rule ({rule!r})"
    offset = round((origin - target).length, 4)
    return "pivot", offset <= tolerance, offset, tolerance, hint


def _measure(obj):
    """Topology, bounds, triangles and UV data of obj's evaluated mesh in world space."""
    bm = util.evaluated_bmesh(obj)
    try:
        bm.transform(obj.matrix_world)
        bm.faces.index_update()
        coords = np.array([v.co[:] for v in bm.verts], np.float64).reshape(-1, 3)
        link_counts = [len(e.link_faces) for e in bm.edges]
        loop_tris = bm.calc_loop_triangles()
        uv_layer = bm.loops.layers.uv.active
        tri_xyz = np.array([[loop.vert.co[:] for loop in tri] for tri in loop_tris], np.float64).reshape(-1, 3, 3)
        tri_face = np.array([tri[0].face.index for tri in loop_tris], np.int64)
        tri_uv = None
        if uv_layer is not None:
            tri_uv = np.array([[loop[uv_layer].uv[:] for loop in tri] for tri in loop_tris], np.float64)
            tri_uv = tri_uv.reshape(-1, 3, 2)
        mesh = {
            "uv_maps": len(bm.loops.layers.uv),
            "verts": len(bm.verts),
            "tris": sum(len(f.verts) - 2 for f in bm.faces),
            "faces": len(bm.faces),
            "ngons": sum(len(f.verts) > 4 for f in bm.faces),
            "loose_verts": sum(not v.link_edges for v in bm.verts),
            "edges": {"multi_face": sum(c > 2 for c in link_counts), "wire": sum(c == 0 for c in link_counts),
                      "boundary": sum(c == 1 for c in link_counts)},
            "inconsistent_edges": sum(len(e.link_faces) == 2 and not e.is_contiguous for e in bm.edges),
        }
    finally:
        bm.free()
    mesh["lo"] = Vector(coords.min(axis=0)) if len(coords) else Vector()
    mesh["hi"] = Vector(coords.max(axis=0)) if len(coords) else Vector()
    a, b, c = tri_xyz[:, 0], tri_xyz[:, 1], tri_xyz[:, 2]
    closed = mesh["faces"] and not any(mesh["edges"].values())
    mesh["inside_out"] = bool(closed and np.einsum("ij,ij->i", a, np.cross(b, c)).sum() < 0)
    mesh["tri_area"] = np.linalg.norm(np.cross(b - a, c - a), axis=1) / 2
    mesh["tri_face"], mesh["tri_uv"] = tri_face, tri_uv
    return mesh


def _uv_checks(add, mesh, budget, asset_class, images):
    tri_uv = mesh["tri_uv"]
    if tri_uv is None:
        add("uv_missing", "fail", mesh["uv_maps"], 1, "unwrap the mesh: it has no UV map")
        for check_id in ("uv_degenerate", "uv_overlap", "uv_bounds", "texel_density"):
            add(check_id, "warn", None, None, "skipped: no UV map")
        return
    add("uv_missing", "pass", mesh["uv_maps"], 1)
    e1, e2 = tri_uv[:, 1] - tri_uv[:, 0], tri_uv[:, 2] - tri_uv[:, 0]
    uv_area = np.abs(e1[:, 0] * e2[:, 1] - e1[:, 1] * e2[:, 0]) / 2
    n_faces = mesh["faces"]
    face_uv = np.bincount(mesh["tri_face"], uv_area, n_faces)
    face_xyz = np.bincount(mesh["tri_face"], mesh["tri_area"], n_faces)
    degenerate = int(((face_uv < DEGENERATE_UV_AREA) & (face_xyz > 1e-12)).sum())
    add("uv_degenerate", degenerate == 0, degenerate, 0,
        f"{degenerate} faces have no UV area (stacked on a point or a line): re-unwrap them")
    keep = uv_area >= DEGENERATE_UV_AREA / 2
    ratio = round(_overlap_ratio(tri_uv[keep], mesh["tri_face"][keep]), 4)
    add("uv_overlap", "pass" if ratio == 0 else "warn", ratio, 0.0,
        "overlapping UV area: fine for intentional mirrored or stacked islands, wrong for a unique bake")
    outside = float(((tri_uv < -UV_EPS) | (tri_uv > 1 + UV_EPS)).any(axis=2).mean()) if len(tri_uv) else 0.0
    add("uv_bounds", "pass" if outside == 0 else "warn", round(outside, 4), 0.0,
        "UVs outside 0-1: fine for tiling or trim materials, wrong for a unique baked map")
    tex_px = max((max(i.size) for i in images), default=0) or budget["texture_max_px"][asset_class]
    target = budget["texel_density_px_per_m"]
    tolerance = budget.get("texel_density_tolerance", 0.25)
    span = [round(target * (1 - tolerance), 1), round(target * (1 + tolerance), 1)]
    area = float(mesh["tri_area"].sum())
    density = round(tex_px * math.sqrt(float(uv_area.sum()) / area), 1) if area > 0 else 0.0
    add("texel_density", "pass" if span[0] <= density <= span[1] else "warn", density, span,
        f"{density} px/m at a {tex_px} px texture: scale the UV islands or change the texture size")


def _overlap_ratio(tri_uv, tri_face):
    """Share of the covered UV area (rasterised on a UV_GRID square grid over 0-1) covered by two or more faces."""
    owner = np.full(UV_GRID * UV_GRID, -1, np.int64)
    overlap = np.zeros(UV_GRID * UV_GRID, bool)
    for tri, face in zip(tri_uv * UV_GRID, tri_face):
        (x0, y0), (x1, y1), (x2, y2) = tri
        cols = np.arange(max(0, math.ceil(min(x0, x1, x2) - 0.5)),
                         min(UV_GRID - 1, math.floor(max(x0, x1, x2) - 0.5)) + 1)
        rows = np.arange(max(0, math.ceil(min(y0, y1, y2) - 0.5)),
                         min(UV_GRID - 1, math.floor(max(y0, y1, y2) - 0.5)) + 1)
        det = (y1 - y2) * (x0 - x2) + (x2 - x1) * (y0 - y2)
        if not len(cols) or not len(rows) or abs(det) < 1e-12:
            continue
        x, y = np.meshgrid(cols + 0.5, rows + 0.5)
        a = ((y1 - y2) * (x - x2) + (x2 - x1) * (y - y2)) / det
        b = ((y2 - y0) * (x - x2) + (x0 - x2) * (y - y2)) / det
        inside = (a > 1e-9) & (b > 1e-9) & (1 - a - b > 1e-9)
        cells = (y[inside] - 0.5).astype(np.int64) * UV_GRID + (x[inside] - 0.5).astype(np.int64)
        previous = owner[cells]
        overlap[cells[(previous >= 0) & (previous != face)]] = True
        owner[cells] = face
    covered = int((owner >= 0).sum())
    return float(overlap.sum()) / covered if covered else 0.0


def _material_images(obj):
    images, seen = {}, set()

    def walk(tree):
        # Every material's embedded tree is named "Shader Nodetree", so a name would merge them.
        if tree is None or tree.as_pointer() in seen:
            return
        seen.add(tree.as_pointer())
        for node in tree.nodes:
            if node.type == "TEX_IMAGE" and node.image is not None:
                images[node.image.name] = node.image
            elif node.type == "GROUP":
                walk(node.node_tree)

    for slot in obj.material_slots:
        if slot.material is not None:
            walk(slot.material.node_tree)
    return list(images.values())


def _missing_on_disk(image):
    if image.packed_file is not None or image.source not in ("FILE", "SEQUENCE", "MOVIE", "TILED"):
        return False
    path = bpy.path.abspath(image.filepath, library=image.library)
    if image.source == "TILED":
        return not all(Path(path.replace("<UDIM>", str(t.number))).is_file() for t in image.tiles)
    return not Path(path).is_file()
