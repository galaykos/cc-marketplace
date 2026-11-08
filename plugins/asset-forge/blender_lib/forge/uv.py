"""UV seams, unwrapping, packing and texel density. UV values are 0-1 texture space; lengths are metres (Blender
units times the scene's Unit Scale); texel density is texture pixels per metre."""
import math
from contextlib import contextmanager

import bmesh
import bpy
import numpy as np

from .util import ForgeError, get_object, material, ok, select_only, settable_enum


def _op_enum(op, prop, wanted):
    """First of `wanted` the operator's enum offers at run time (None if none), and the full offered list."""
    offered = [i.identifier for i in op.get_rna_type().properties[prop].enum_items]
    return next((w for w in wanted if w in offered), None), offered


def _mesh_with_faces(obj):
    obj = get_object(obj, "MESH")
    if not obj.data.polygons:
        raise ForgeError(f"{obj.name} has no faces to unwrap")
    return obj


@contextmanager
def _edit_all_faces(obj):
    """obj alone, active and in Edit Mode with every face selected and UV sync selection on; all restored after."""
    view_layer = bpy.context.view_layer
    was_selected = obj.select_get()
    try:
        obj.select_set(True)
    except RuntimeError as exc:
        raise ForgeError(str(exc), stage="context") from None
    obj.select_set(was_selected)
    prev_active = view_layer.objects.active
    prev_mode = prev_active.mode if prev_active else "OBJECT"
    prev_selected = [o for o in view_layer.objects if o.select_get()]
    hidden = (obj.hide_get(), obj.hide_viewport)
    tool_settings = bpy.context.scene.tool_settings
    sync = tool_settings.use_uv_select_sync
    me = obj.data
    masks = [(seq, [e.select for e in seq]) for seq in (me.vertices, me.edges, me.polygons)]
    obj.hide_viewport = False
    obj.hide_set(False)
    select_only(obj)
    try:
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        tool_settings.use_uv_select_sync = True
        yield
    finally:
        if obj.mode != "OBJECT":
            bpy.ops.object.mode_set(mode="OBJECT")
        tool_settings.use_uv_select_sync = sync
        for seq, mask in masks:
            seq.foreach_set("select", mask)
        me.update()
        for o in view_layer.objects:
            o.select_set(o in prev_selected)
        obj.hide_viewport = hidden[1]
        obj.hide_set(hidden[0])
        view_layer.objects.active = prev_active
        if prev_active is not None and prev_mode != "OBJECT":
            bpy.ops.object.mode_set(mode=prev_mode)


def _uv_split(l1, l2, uv, eps=1e-5):
    """True when the two loops of one edge carry different UVs at either end: a seam in the data, marked or not."""
    a = {l1.vert: l1[uv].uv, l1.link_loop_next.vert: l1.link_loop_next[uv].uv}
    b = {l2.vert: l2[uv].uv, l2.link_loop_next.vert: l2.link_loop_next[uv].uv}
    return any((a[v] - b[v]).length > eps for v in a)


def _island_count(bm, uv):
    parent = list(range(len(bm.faces)))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    bm.faces.index_update()
    for e in bm.edges:
        if len(e.link_loops) == 2 and not _uv_split(*e.link_loops, uv):
            a, b = find(e.link_loops[0].face.index), find(e.link_loops[1].face.index)
            parent[a] = b
    return len({find(i) for i in range(len(bm.faces))})


def _uv_summary(obj):
    me = obj.data
    layer = me.uv_layers.active
    coords = np.empty(len(me.loops) * 2, dtype=np.float64)
    layer.data.foreach_get("uv", coords)
    coords = coords.reshape(-1, 2)
    bm = bmesh.new()
    bm.from_mesh(me)
    islands = _island_count(bm, bm.loops.layers.uv.active)
    bm.free()
    lo, hi = coords.min(axis=0), coords.max(axis=0)
    return {"uv_map": layer.name, "islands": islands,
            "uv_bounds": [round(float(x), 6) for x in (*lo, *hi)],
            "in_0_1": bool(lo.min() >= -1e-6 and hi.max() <= 1 + 1e-6)}


def smart_project(obj, angle_deg=66.0, margin=0.01):
    """Smart UV Project every face of a mesh. angle_deg: island split angle in degrees; margin: island gap as a
    fraction of the 0-1 UV square. Replaces the active UV map's layout. Returns islands, UV bounds."""
    obj = _mesh_with_faces(obj)
    op = bpy.ops.uv.smart_project
    limit = op.get_rna_type().properties["angle_limit"]
    angle = math.radians(angle_deg)
    if not limit.hard_min < angle <= limit.hard_max:
        raise ForgeError(f"angle_deg must be in ({math.degrees(limit.hard_min):g}, {math.degrees(limit.hard_max):g}]")
    if not 0 <= margin < 0.5:
        raise ForgeError("margin is a fraction of the UV square: 0 <= margin < 0.5")
    method, offered = _op_enum(op, "margin_method", ["FRACTION"])
    kwargs = {"angle_limit": angle, "island_margin": margin}
    if method:
        kwargs["margin_method"] = method
    with _edit_all_faces(obj):
        op(**kwargs)
    return ok(object=obj.name, angle_deg=angle_deg, margin=margin, margin_method=method or offered[0],
              **_uv_summary(obj))


def seams_from_sharp(obj, angle_deg=30.0):
    """Mark a UV seam on every edge whose two faces meet at more than angle_deg (degrees between normals) and on
    every edge already marked sharp. Adds seams, never clears one. Returns new and total seam counts."""
    obj = get_object(obj, "MESH")
    if not 0 < angle_deg < 180:
        raise ForgeError("angle_deg must be in (0, 180)")
    limit = math.radians(angle_deg)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    added = by_angle = by_sharp = 0
    for e in bm.edges:
        if e.seam or len(e.link_faces) != 2:
            continue
        sharp = not e.smooth
        steep = e.calc_face_angle(0.0) > limit
        if sharp or steep:
            e.seam = True
            added += 1
            by_sharp += sharp
            by_angle += steep and not sharp
    total = sum(e.seam for e in bm.edges)
    bm.to_mesh(obj.data)
    obj.data.update()
    bm.free()
    return ok(object=obj.name, angle_deg=angle_deg, seams_added=added, from_angle=by_angle, from_sharp=by_sharp,
              seams_total=total)


def unwrap(obj, method="ANGLE_BASED"):
    """Unwrap every face along the mesh's marked seams with the uv.unwrap operator. method: an identifier the
    running Blender's operator offers (probed; refused with the offered list otherwise). Returns islands, bounds."""
    obj = _mesh_with_faces(obj)
    op = bpy.ops.uv.unwrap
    chosen, offered = _op_enum(op, "method", [method])
    if chosen is None:
        raise ForgeError(f"unwrap method {method!r} not offered by this Blender; offered: {offered}")
    seams = sum(e.use_seam for e in obj.data.edges)
    with _edit_all_faces(obj):
        op(method=chosen)
    return ok(object=obj.name, method=chosen, seams=seams, **_uv_summary(obj))


def pack(obj, margin_px=4, texture_px=1024):
    """Pack the active UV map's islands into 0-1 with a gap of margin_px texture pixels at texture_px square
    (margin in UV units = margin_px / texture_px). Returns islands, UV bounds and the margin in UV units."""
    obj = _mesh_with_faces(obj)
    if texture_px <= 0 or margin_px < 0:
        raise ForgeError("texture_px must be > 0 and margin_px >= 0")
    if not obj.data.uv_layers:
        raise ForgeError(f"{obj.name} has no UV map; unwrap it first")
    op = bpy.ops.uv.pack_islands
    method, offered = _op_enum(op, "margin_method", ["FRACTION"])
    if method is None:
        raise ForgeError(f"pack_islands has no FRACTION margin method here; offered: {offered}", stage="blender")
    margin = margin_px / texture_px
    with _edit_all_faces(obj):
        op(margin_method=method, margin=margin)
    return ok(object=obj.name, margin_px=margin_px, texture_px=texture_px, margin_uv=round(margin, 6),
              **_uv_summary(obj))


def _face_areas(obj):
    """Per face: (world area in m², UV area in UV units²) for the active UV map."""
    if not obj.data.uv_layers:
        raise ForgeError(f"{obj.name} has no UV map; unwrap it first")
    bpy.context.view_layer.update()
    unit = bpy.context.scene.unit_settings.scale_length
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.transform(obj.matrix_world)
    uv = bm.loops.layers.uv.active
    rows = []
    for f in bm.faces:
        pts = [l[uv].uv for l in f.loops]
        shoelace = sum(a.x * b.y - b.x * a.y for a, b in zip(pts, pts[1:] + pts[:1]))
        rows.append((f.calc_area() * unit * unit, abs(shoelace) / 2))
    bm.free()
    return np.array(rows, dtype=np.float64).reshape(-1, 2)


def _density(obj, texture_px):
    rows = _face_areas(obj)
    world, uv_area = rows[:, 0], rows[:, 1]
    used = world > 1e-12
    if not used.any():
        raise ForgeError(f"{obj.name} has no surface area")
    per_face = texture_px * np.sqrt(uv_area[used] / world[used])
    mean = float((per_face * world[used]).sum() / world[used].sum())
    return mean, float(per_face.min()), float(per_face.max())


def texel_density(obj, texture_px):
    """Measured texel density of the active UV map in pixels per metre at texture_px square: per-face density
    weighted by world-space face area. Returns the weighted mean and the per-face min and max."""
    obj = _mesh_with_faces(obj)
    if texture_px <= 0:
        raise ForgeError("texture_px must be > 0")
    mean, lo, hi = _density(obj, texture_px)
    return ok(object=obj.name, texture_px=texture_px, px_per_m=round(mean, 3), min_px_per_m=round(lo, 3),
              max_px_per_m=round(hi, 3))


def set_texel_density(obj, px_per_m, texture_px):
    """Scale the active UV map uniformly about its bounding-box centre so the measured texel density becomes
    px_per_m (pixels per metre) at texture_px square. Reports when the result leaves 0-1 and the texture size that
    would hold it at this density, or tiling. Returns densities before and after, the scale and the new bounds."""
    obj = _mesh_with_faces(obj)
    if px_per_m <= 0 or texture_px <= 0:
        raise ForgeError("px_per_m and texture_px must be > 0")
    before, _, _ = _density(obj, texture_px)
    if before <= 0:
        raise ForgeError(f"{obj.name}'s UVs have no area; unwrap it first")
    factor = px_per_m / before
    layer = obj.data.uv_layers.active
    coords = np.empty(len(obj.data.loops) * 2, dtype=np.float64)
    layer.data.foreach_get("uv", coords)
    coords = coords.reshape(-1, 2)
    centre = (coords.min(axis=0) + coords.max(axis=0)) / 2
    coords = centre + (coords - centre) * factor
    layer.data.foreach_set("uv", coords.ravel())
    obj.data.update()
    after, _, _ = _density(obj, texture_px)
    summary = _uv_summary(obj)
    extent = float((coords.max(axis=0) - coords.min(axis=0)).max())
    advice = None
    if not summary["in_0_1"]:
        if extent > 1:
            needed = 2 ** math.ceil(math.log2(texture_px * extent))
            advice = f"UVs span {extent:.3f} of the 0-1 square: use a {needed} px texture at this density, or tile"
        else:
            advice = "UVs fit in one square but sit outside 0-1: re-pack or move them"
    return ok(object=obj.name, before_px_per_m=round(before, 3), after_px_per_m=round(after, 3),
              scale=round(factor, 6), uv_extent=round(extent, 6), advice=advice, **summary)


def checker_material(obj, texture_px=1024):
    """Show a generated UV-grid checker on obj. Every material slot is switched to an object-linked override, so
    the mesh keeps its own materials (set each slot's link back to 'DATA' to undo); a mesh with no slot gets the
    checker as its only material. texture_px: checker image size in pixels. Returns the material and image names."""
    obj = get_object(obj, "MESH")
    if texture_px <= 0:
        raise ForgeError("texture_px must be > 0")
    name = f"FORGE_UVChecker_{texture_px}"
    image = bpy.data.images.get(name)
    if image is None:
        image = bpy.data.images.new(name, texture_px, texture_px)
    kind = settable_enum(image, "generated_type", ["UV_GRID", "COLOR_GRID"])
    if kind is None:
        raise ForgeError("no generated checker pattern available on Image.generated_type", stage="blender")
    image.generated_type = kind
    mat = material(name)
    nodes = mat.node_tree.nodes
    tex = next((n for n in nodes if n.type == "TEX_IMAGE"), None) or nodes.new("ShaderNodeTexImage")
    tex.image = image
    bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    if not bsdf.inputs["Base Color"].is_linked:
        mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    if not obj.material_slots:
        obj.data.materials.append(mat)
        overridden = 0
    else:
        for slot in obj.material_slots:
            slot.link = "OBJECT"
            slot.material = mat
        overridden = len(obj.material_slots)
    return ok(object=obj.name, material=mat.name, image=image.name, pattern=kind, texture_px=texture_px,
              slots_overridden=overridden)
