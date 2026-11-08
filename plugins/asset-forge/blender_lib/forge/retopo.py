"""Retopology and cleanup for organic and AI-generated meshes, live or in `blender -b`. Modifiers are baked through the
evaluated mesh (no bpy.ops) except QuadriFlow, which only exists as an operator and was run headless on 5.2.3.
Distances are metres. Every function edits the object's mesh in place and returns util.ok(...) with measured counts."""
import uuid
from contextlib import contextmanager

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

from .util import (ForgeError, apply_transforms, ensure_object_mode, evaluated_bmesh, get_object, ok, positive,
                   settable_enum)

MAX_VOXEL_FACES = 5_000_000
DECIMATE_TOLERANCE = 0.10


@contextmanager
def _solo_modifier(obj, kind, **settings):
    """Yield a new `kind` modifier, first in obj's stack with every other modifier hidden from the viewport, so the
    evaluated mesh is base + this modifier. On exit it is removed and the others are shown again."""
    view_layer = bpy.context.view_layer
    view_layer.update()
    if obj.name not in view_layer.objects or obj.hide_viewport:
        raise ForgeError(f"{obj.name} is not evaluated (not in the view layer, or disabled in viewports)")
    ensure_object_mode()
    try:
        mod = obj.modifiers.new(f"forge_{kind.lower()}", kind)
    except TypeError as exc:
        raise ForgeError(f"this Blender has no {kind} modifier", stage="blender") from exc
    shown = [m for m in obj.modifiers if m != mod and m.show_viewport]
    try:
        for key, value in settings.items():
            prop = mod.bl_rna.properties.get(key)
            if prop is None:
                raise ForgeError(f"the {kind} modifier has no setting {key!r}")
            if prop.type == "ENUM" and not prop.is_enum_flag and settable_enum(mod, key, [value]) is None:
                raise ForgeError(f"the {kind} modifier has no {key} {value!r} here", stage="blender")
            setattr(mod, key, value)
        for m in shown:
            m.show_viewport = False
        obj.modifiers.move(len(obj.modifiers) - 1, 0)
        yield mod
    finally:
        for m in shown:
            m.show_viewport = True
        obj.modifiers.remove(mod)


def _write(obj, bm):
    bm.to_mesh(obj.data)
    obj.data.update()
    bm.free()


def _counts(obj):
    mesh = obj.data
    return len(mesh.vertices), len(mesh.polygons), sum(p.loop_total - 2 for p in mesh.polygons)


def bake_modifier(obj, kind, **settings):
    """Bake one new `kind` modifier (a Modifier type such as "SKIN" or "SUBSURF", `settings` its properties) into
    obj's mesh as if it were first in the stack; the existing modifiers stay as they are. Distances in `settings` are
    the modifier's own, in obj's local units. Returns ok(object, modifier, verts, faces) after the bake."""
    obj = get_object(obj, "MESH")
    with _solo_modifier(obj, kind, **settings):
        bm = evaluated_bmesh(obj)
    _write(obj, bm)
    verts, faces, _ = _counts(obj)
    return ok(object=obj.name, modifier=kind, verts=verts, faces=faces)


def voxel_remesh(obj, voxel_size):
    """Rebuild the surface as an even quad grid (Remesh modifier, voxel mode) and bake it. voxel_size: metres in world
    space, converted with the object's mean scale (non-uniform scale gives non-cubic voxels). UVs do not survive.
    Refuses when the estimated output exceeds MAX_VOXEL_FACES. Returns ok(verts/faces before and after)."""
    obj = get_object(obj, "MESH")
    voxel_size = positive(voxel_size, "voxel_size")
    bpy.context.view_layer.update()
    scale = abs(np.linalg.det(np.array(obj.matrix_world)[:3, :3])) ** (1.0 / 3.0)
    if scale == 0:
        raise ForgeError(f"{obj.name} has a zero scale on some axis")
    area = np.empty(len(obj.data.polygons))
    obj.data.polygons.foreach_get("area", area)
    estimate = area.sum() * scale * scale / (voxel_size * voxel_size)
    if estimate > MAX_VOXEL_FACES:
        raise ForgeError(f"voxel_size {voxel_size} m would give about {int(estimate)} faces "
                         f"(limit {MAX_VOXEL_FACES}); use a larger voxel")
    verts, faces, _ = _counts(obj)
    bake_modifier(obj, "REMESH", mode="VOXEL", voxel_size=voxel_size / scale)
    verts_after, faces_after, _ = _counts(obj)
    if faces_after == 0:
        raise ForgeError(f"voxel remesh of {obj.name} produced no faces; is the mesh closed and larger than "
                         f"{voxel_size} m?", stage="remesh")
    return ok(object=obj.name, voxel_size=voxel_size, verts_before=verts, faces_before=faces, verts_after=verts_after,
              faces_after=faces_after)


def quadriflow(obj, target_faces):
    """Quad remesh with QuadriFlow (bpy.ops.object.quadriflow_remesh, mode FACES) toward `target_faces` quads. The
    input must be manifold with consistent normals (run clean_ai_mesh or voxel_remesh first). UVs and vertex groups do
    not survive. Returns ok(faces_before, faces_after, quads); QuadriFlow lands near, not on, the target."""
    obj = get_object(obj, "MESH")
    if int(target_faces) != target_faces or target_faces < 1:
        raise ForgeError(f"target_faces must be a whole number >= 1, got {target_faces!r}")
    modes = {i.identifier for i in bpy.ops.object.quadriflow_remesh.get_rna_type().properties["mode"].enum_items}
    if "FACES" not in modes:
        raise ForgeError(f"QuadriFlow has no FACES mode here (modes: {sorted(modes)})", stage="blender")
    ensure_object_mode()
    faces = len(obj.data.polygons)
    with bpy.context.temp_override(object=obj, active_object=obj, selected_objects=[obj],
                                   selected_editable_objects=[obj]):
        result = bpy.ops.object.quadriflow_remesh(mode="FACES", target_faces=int(target_faces))
    if "FINISHED" not in result:
        raise ForgeError(f"QuadriFlow refused {obj.name}: it needs a manifold mesh with consistent normals; "
                         f"run clean_ai_mesh or voxel_remesh first", stage="quadriflow")
    polys = obj.data.polygons
    return ok(object=obj.name, target_faces=int(target_faces), faces_before=faces, faces_after=len(polys),
              quads=sum(p.loop_total == 4 for p in polys))


def _uv_seam_verts(bm):
    """Indices of vertices on a marked seam or on an edge whose two faces disagree on the active UV map."""
    uv = bm.loops.layers.uv.active
    found = set()
    for edge in bm.edges:
        if edge.seam:
            found.update(v.index for v in edge.verts)
            continue
        if uv is None or len(edge.link_loops) != 2:
            continue
        sides = [{loop.vert: loop[uv].uv, loop.link_loop_next.vert: loop.link_loop_next[uv].uv}
                 for loop in edge.link_loops]
        if any((sides[0][v] - sides[1][v]).length > 1e-6 for v in edge.verts):
            found.update(v.index for v in edge.verts)
    return found


def decimate_to_budget(obj, target_tris, protect_uv_seams=True):
    """Collapse-decimate to `target_tris` triangles (within ±10%), searching the Decimate ratio by measuring each try.
    protect_uv_seams locks vertices on marked seams and on UV-map splits so UV islands keep their borders; with many
    such vertices the target may be out of reach, and within_tolerance says so. A mesh already at or under
    target * 1.1 is left alone. Returns ok(tris_before, target_tris, achieved_tris, ratio, within_tolerance,
    protected_verts)."""
    obj = get_object(obj, "MESH")
    if int(target_tris) != target_tris or target_tris < 1:
        raise ForgeError(f"target_tris must be a whole number >= 1, got {target_tris!r}")
    _, _, before = _counts(obj)
    summary = {"object": obj.name, "tris_before": before, "target_tris": int(target_tris)}
    if before <= target_tris * (1 + DECIMATE_TOLERANCE):
        return ok(**summary, achieved_tris=before, ratio=1.0, within_tolerance=True, protected_verts=0)
    protected = []
    if protect_uv_seams:
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bm.verts.index_update()
        protected = sorted(_uv_seam_verts(bm))
        bm.free()
    group = obj.vertex_groups.new(name=f"forge_protect_{uuid.uuid4().hex[:8]}") if protected else None
    try:
        settings = {"decimate_type": "COLLAPSE", "use_collapse_triangulate": True}
        if group is not None:
            group.add(protected, 1.0, "REPLACE")
            settings.update(vertex_group=group.name, invert_vertex_group=True)
        with _solo_modifier(obj, "DECIMATE", **settings) as mod:
            ratio, best = target_tris / before, None
            for _ in range(8):
                mod.ratio = min(max(ratio, 1e-5), 1.0)
                bm = evaluated_bmesh(obj)
                tris = sum(len(f.verts) - 2 for f in bm.faces)
                if best is None or abs(tris - target_tris) < abs(best[1] - target_tris):
                    if best is not None:
                        best[2].free()
                    best = (mod.ratio, tris, bm)
                else:
                    bm.free()
                if abs(tris - target_tris) <= DECIMATE_TOLERANCE * target_tris or tris == 0:
                    break
                ratio = mod.ratio * target_tris / tris
        ratio, achieved, bm = best
        _write(obj, bm)
    finally:
        if group is not None:
            obj.vertex_groups.remove(group)
    return ok(**summary, achieved_tris=achieved, ratio=ratio,
              within_tolerance=abs(achieved - target_tris) <= DECIMATE_TOLERANCE * target_tris,
              protected_verts=len(protected))


def _world_bvh(obj):
    bm = evaluated_bmesh(obj)
    bm.transform(obj.matrix_world)
    tree = BVHTree.FromBMesh(bm)
    bm.free()
    return tree


def _distances(tree, obj):
    m = obj.matrix_world
    return np.array([tree.find_nearest(m @ v.co)[3] for v in obj.data.vertices])


def shrinkwrap_lowpoly(high, low, offset=0.0):
    """Project `low`'s vertices onto `high`'s surface (Shrinkwrap modifier, nearest surface point) and bake it.
    offset: distance kept from the surface, in low's local units (metres when its scale is applied). Returns
    ok(mean_distance_before, mean_distance_after, max_distance_after) in world metres, measured to high's surface."""
    high, low = get_object(high, "MESH"), get_object(low, "MESH")
    if high == low:
        raise ForgeError("high and low are the same object")
    bpy.context.view_layer.update()
    tree = _world_bvh(high)
    before = _distances(tree, low)
    bake_modifier(low, "SHRINKWRAP", target=high, offset=float(offset))
    after = _distances(tree, low)
    return ok(object=low.name, target=high.name, verts=len(after), mean_distance_before=float(before.mean()),
              mean_distance_after=float(after.mean()), max_distance_after=float(after.max()))


def _face_islands(bm):
    """Lists of faces, one per edge-connected island."""
    seen, islands = set(), []
    for start in bm.faces:
        if start in seen:
            continue
        seen.add(start)
        island, stack = [], [start]
        while stack:
            face = stack.pop()
            island.append(face)
            for edge in face.edges:
                for other in edge.link_faces:
                    if other not in seen:
                        seen.add(other)
                        stack.append(other)
        islands.append(island)
    return islands


def _boundary_loops(bm):
    """Number of connected chains of boundary edges (one per hole or open border)."""
    parent = {}

    def root(v):
        while parent.setdefault(v, v) is not v:
            v = parent[v]
        return v

    edges = [e for e in bm.edges if e.is_boundary]
    for e in edges:
        a, b = root(e.verts[0]), root(e.verts[1])
        if a is not b:
            parent[a] = b
    return len({root(e.verts[0]) for e in edges})


def _inconsistent_edges(bm):
    """Manifold edges whose two faces wind the same way along them (one of the pair is flipped)."""
    return sum(1 for e in bm.edges if len(e.link_loops) == 2 and e.link_loops[0].vert == e.link_loops[1].vert)


def clean_ai_mesh(obj, merge_distance=1e-4, min_island_fraction=0.002, max_hole_sides=8):
    """Clean a generated (e.g. Meshy) mesh in place. Order: bake scale and rotation (util.apply_transforms) so every
    distance below is world metres and a negative scale cannot leave normals inverted; merge vertices closer than
    merge_distance; delete loose edges and vertices; delete edge-connected islands with fewer than
    min_island_fraction of all faces (the largest island always stays); fill holes of at most max_hole_sides edges
    (bmesh holes_fill), triangulating fills over 4 sides; recalculate normals outward; move the origin to the bottom
    centre of the bounding box, keeping the mesh where it is in the world. Returns ok(...) with before/after counts per
    fix."""
    obj = get_object(obj, "MESH")
    if merge_distance < 0:
        raise ForgeError(f"merge_distance must be >= 0, got {merge_distance!r}")
    if not 0 <= min_island_fraction < 1:
        raise ForgeError(f"min_island_fraction must be in [0, 1), got {min_island_fraction!r}")
    if int(max_hole_sides) != max_hole_sides or max_hole_sides < 3:
        raise ForgeError(f"max_hole_sides must be a whole number >= 3, got {max_hole_sides!r}")
    if len(obj.data.polygons) == 0:
        raise ForgeError(f"{obj.name} has no faces")
    ensure_object_mode()
    scale_before = [round(s, 6) for s in obj.scale]
    baked = apply_transforms(obj)["baked"]
    report = {"object": obj.name,
              "transforms": {"scale_before": scale_before, "scale_after": [round(s, 6) for s in obj.scale],
                             "baked": baked}}
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    faces_before = len(bm.faces)

    verts = len(bm.verts)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=merge_distance)
    report["merge"] = {"verts_before": verts, "verts_after": len(bm.verts)}

    loose_edges = [e for e in bm.edges if not e.link_faces]
    loose = {"edges_before": len(loose_edges)}
    for e in loose_edges:
        bm.edges.remove(e)
    loose_verts = [v for v in bm.verts if not v.link_edges]
    loose["verts_before"] = len(loose_verts)
    for v in loose_verts:
        bm.verts.remove(v)
    loose.update(edges_after=sum(1 for e in bm.edges if not e.link_faces),
                 verts_after=sum(1 for v in bm.verts if not v.link_edges))
    report["loose"] = loose

    islands = _face_islands(bm)
    largest = max(islands, key=len)
    small = [i for i in islands if i is not largest and len(i) < min_island_fraction * len(bm.faces)]
    removed = sum(len(i) for i in small)
    if small:
        bmesh.ops.delete(bm, geom=[f for i in small for f in i], context="FACES")
    report["islands"] = {"before": len(islands), "after": len(_face_islands(bm)), "faces_removed": removed}

    holes = _boundary_loops(bm)
    filled = bmesh.ops.holes_fill(bm, edges=[e for e in bm.edges if e.is_boundary], sides=int(max_hole_sides))["faces"]
    big = [f for f in filled if len(f.verts) > 4]
    if big:
        bmesh.ops.triangulate(bm, faces=big)
    report["holes"] = {"before": holes, "after": _boundary_loops(bm), "filled": len(filled)}

    bm.normal_update()
    inconsistent = _inconsistent_edges(bm)
    normals = {f: f.normal.copy() for f in bm.faces}
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.normal_update()
    report["normals"] = {"inconsistent_edges_before": inconsistent, "inconsistent_edges_after": _inconsistent_edges(bm),
                         "faces_flipped": sum(1 for f in bm.faces if f.normal.dot(normals[f]) < 0)}

    lo = Vector([min(v.co[k] for v in bm.verts) for k in range(3)])
    hi = Vector([max(v.co[k] for v in bm.verts) for k in range(3)])
    bottom = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    bmesh.ops.translate(bm, verts=bm.verts[:], vec=-bottom)
    report["faces"] = {"before": faces_before, "after": len(bm.faces)}
    _write(obj, bm)
    origin_before = obj.matrix_world.translation.copy()
    children = {c: c.matrix_world.copy() for c in obj.children}
    obj.matrix_basis = obj.matrix_basis @ Matrix.Translation(bottom)
    bpy.context.view_layer.update()
    for child, world in children.items():
        child.matrix_world = world
    report["origin"] = {"before": [round(c, 6) for c in origin_before],
                        "after": [round(c, 6) for c in obj.matrix_world.translation]}
    return ok(**report)
