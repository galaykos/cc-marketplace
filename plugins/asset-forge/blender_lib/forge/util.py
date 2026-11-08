"""Shared helpers for every forge module. Pure bpy/bmesh/mathutils; works live and in `blender -b`.
Units are Blender units (metres at the default Unit Scale 1.0) unless a name says otherwise."""
import json
import math
import numbers
from contextlib import contextmanager
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

PLUGIN_ROOT = Path(__file__).resolve().parents[2]
PRESETS = PLUGIN_ROOT / "presets"


class ForgeError(Exception):
    """A refusal the caller can act on: bad input, a missing object, an unsupported Blender. `stage` names the step."""

    def __init__(self, message, stage="input"):
        super().__init__(message)
        self.stage = stage


def ok(**fields):
    """The summary dict every public forge function returns."""
    return {"ok": True, **fields}


def positive(value, what):
    """Return float(value) for a real number > 0, else raise ForgeError naming `what` (booleans and NaN refused)."""
    if isinstance(value, bool) or not isinstance(value, numbers.Real) or not value > 0:
        raise ForgeError(f"{what} must be a number > 0, got {value!r}")
    return float(value)


def blender_at_least(major, minor=0):
    return tuple(bpy.app.version[:2]) >= (major, minor)


def get_object(name_or_obj, kind=None):
    """Return the object, or raise ForgeError. kind: an Object.type such as 'MESH' or 'ARMATURE'."""
    obj = bpy.data.objects.get(name_or_obj) if isinstance(name_or_obj, str) else name_or_obj
    if obj is None:
        raise ForgeError(f"no object named {name_or_obj!r}")
    if kind and obj.type != kind:
        raise ForgeError(f"{obj.name} is a {obj.type}, expected {kind}")
    return obj


def load_preset(kind, name):
    """kind: 'engines', 'budgets' or 'bonemaps'. Returns the parsed JSON dict."""
    path = PRESETS / kind / f"{name}.json"
    if not path.is_file():
        known = sorted(p.stem for p in (PRESETS / kind).glob("*.json"))
        raise ForgeError(f"no {kind} preset {name!r}; known: {known}")
    return json.loads(path.read_text(encoding="utf-8"))


def ensure_object_mode():
    if bpy.context.object is not None and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")


def select_only(*objects, active=None):
    """Deselect everything, select `objects`, make `active` (default: the first) active. Object mode only."""
    ensure_object_mode()
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active or (objects[0] if objects else None)


@contextmanager
def kept_state(objects=(), stage="context"):
    """Unhide `objects` for the block, then restore their hide flags, the selection, the active object and its mode.
    Raises ForgeError(stage) before changing anything when one of `objects` is not in the view layer."""
    view_layer = bpy.context.view_layer
    for o in objects:
        was = o.select_get()
        try:
            o.select_set(True)
        except RuntimeError as exc:
            raise ForgeError(str(exc), stage=stage) from exc
        o.select_set(was)
    prev_active = view_layer.objects.active
    prev_mode = prev_active.mode if prev_active else "OBJECT"
    prev_selected = [o for o in view_layer.objects if o.select_get()]
    hidden = {o: (o.hide_get(), o.hide_viewport) for o in objects}
    try:
        for o in objects:
            o.hide_viewport = False
            o.hide_set(False)
        yield
    finally:
        ensure_object_mode()
        for o, (hide, hide_viewport) in hidden.items():
            o.hide_viewport = hide_viewport
            o.hide_set(hide)
        for o in view_layer.objects:
            o.select_set(o in prev_selected)
        view_layer.objects.active = prev_active
        if prev_active is not None and prev_mode != "OBJECT":
            bpy.ops.object.mode_set(mode=prev_mode)


@contextmanager
def edit_bmesh(obj):
    """Yield a bmesh of obj's base mesh (no modifiers); written back and freed on exit. Object mode only."""
    ensure_object_mode()
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    try:
        yield bm
        bm.to_mesh(obj.data)
        obj.data.update()
    finally:
        bm.free()


def evaluated_bmesh(obj):
    """A bmesh of obj with modifiers applied, in object space. Caller frees it."""
    depsgraph = bpy.context.evaluated_depsgraph_get()
    eval_obj = obj.evaluated_get(depsgraph)
    mesh = eval_obj.to_mesh()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    eval_obj.to_mesh_clear()
    return bm


def tri_count(obj, evaluated=True):
    """Triangles the engine will receive: sum of (corners - 2) per face."""
    if evaluated:
        bm = evaluated_bmesh(obj)
        n = sum(len(f.verts) - 2 for f in bm.faces)
        bm.free()
        return n
    return sum(p.loop_total - 2 for p in obj.data.polygons)


def measure_texel_density(obj, texture_px):
    """Texel density of obj's active UV map on a texture_px square, in texture pixels per Blender unit (per metre at
    the default Unit Scale 1.0; the scene's Unit Scale is ignored, as the budgets assume 1 unit = 1 m). Measured on the
    evaluated mesh (modifiers applied) in world space. Returns (mean, min, max): mean is
    texture_px * sqrt(total UV area / total world area), min and max are per face. None without a UV map or area."""
    bpy.context.view_layer.update()
    eval_obj = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = eval_obj.to_mesh()
    try:
        layer = mesh.uv_layers.active
        if layer is None:
            return None
        mesh.calc_loop_triangles()
        tris = mesh.loop_triangles
        loops = np.empty(len(tris) * 3, np.int64)
        tris.foreach_get("loops", loops)
        face = np.empty(len(tris), np.int64)
        tris.foreach_get("polygon_index", face)
        loop_vert = np.empty(len(mesh.loops), np.int64)
        mesh.loops.foreach_get("vertex_index", loop_vert)
        co = np.empty(len(mesh.vertices) * 3, np.float64)
        mesh.vertices.foreach_get("co", co)
        uv = np.empty(len(mesh.loops) * 2, np.float64)
        layer.data.foreach_get("uv", uv)
        n_faces = len(mesh.polygons)
    finally:
        eval_obj.to_mesh_clear()
    world = np.array(obj.matrix_world)
    co = co.reshape(-1, 3) @ world[:3, :3].T + world[:3, 3]
    xyz = co[loop_vert[loops]].reshape(-1, 3, 3)
    st = uv.reshape(-1, 2)[loops].reshape(-1, 3, 2)
    area = np.linalg.norm(np.cross(xyz[:, 1] - xyz[:, 0], xyz[:, 2] - xyz[:, 0]), axis=1) / 2
    e1, e2 = st[:, 1] - st[:, 0], st[:, 2] - st[:, 0]
    uv_area = np.abs(e1[:, 0] * e2[:, 1] - e1[:, 1] * e2[:, 0]) / 2
    face_area = np.bincount(face, area, n_faces)
    face_uv = np.bincount(face, uv_area, n_faces)
    used = face_area > 1e-12
    if not used.any():
        return None
    per_face = texture_px * np.sqrt(face_uv[used] / face_area[used])
    mean = texture_px * math.sqrt(face_uv.sum() / face_area.sum())
    return float(mean), float(per_face.min()), float(per_face.max())


def world_bbox(*objects):
    """(min Vector, max Vector) of the objects' evaluated bounding boxes in world space."""
    bpy.context.view_layer.update()  # matrix_world is stale after a location/rotation/scale write until this runs
    lo = Vector((math.inf,) * 3)
    hi = Vector((-math.inf,) * 3)
    for obj in objects:
        for corner in obj.bound_box:
            w = obj.matrix_world @ Vector(corner)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    return lo, hi


def link_to_scene(obj, collection=None):
    (collection or bpy.context.scene.collection).objects.link(obj)
    return obj


def new_mesh_object(name, bm=None, collection=None):
    """Create a mesh object (from a bmesh when given, which is not freed) and link it."""
    mesh = bpy.data.meshes.new(name)
    if bm is not None:
        bm.to_mesh(mesh)
    return link_to_scene(bpy.data.objects.new(name, mesh), collection)


def apply_transforms(obj, location=False, rotation=True, scale=True):
    """Bake scale, then rotation, then location into a mesh's data and shape keys without bpy.ops; children keep their
    world pose. Order is fixed (basis = T @ R @ S), so rotation needs scale and location needs both. Leaves Edit Mode
    first. Returns the object name and the baked parts."""
    if (rotation and not scale) or (location and not rotation):
        raise ForgeError("bake scale before rotation and rotation before location (basis = T @ R @ S)")
    if obj.type != "MESH":
        raise ForgeError(f"{obj.name} is a {obj.type}; only mesh data can absorb a transform")
    if obj.data.users > 1:
        raise ForgeError(f"{obj.name}'s mesh is shared by {obj.data.users} users; make it single-user first")
    ensure_object_mode()
    bpy.context.view_layer.update()
    loc, rot, scl = obj.matrix_basis.decompose()
    parts = [Matrix.Translation(loc), rot.to_matrix().to_4x4(), Matrix.Diagonal((*scl, 1.0))]
    n_baked = 1 + int(rotation) + int(location) if scale else 0
    kept = parts[0] @ parts[1] @ parts[2] if n_baked == 0 else Matrix.Identity(4)
    baked = Matrix.Identity(4)
    if n_baked:
        for m in parts[:3 - n_baked]:
            kept = kept @ m
        for m in parts[3 - n_baked:]:
            baked = baked @ m
    children = {c: c.matrix_world.copy() for c in obj.children}
    obj.data.transform(baked, shape_keys=True)
    if baked.determinant() < 0:  # Mesh.transform keeps winding, so a mirror would leave the mesh inside-out
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
        bm.to_mesh(obj.data)
        bm.free()
    obj.data.update()
    obj.matrix_basis = kept
    bpy.context.view_layer.update()
    for child, world in children.items():
        child.matrix_world = world
    return ok(object=obj.name, baked=["scale", "rotation", "location"][:n_baked])


def material(name, color=(0.8, 0.8, 0.8, 1.0)):
    """Get or create a node material whose Principled BSDF base colour is `color` (linear RGBA)."""
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    if mat.node_tree is None:
        setattr(mat, "use_nodes", True)  # 4.x only: 5.0+ materials always carry a node tree
    bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is not None:
        bsdf.inputs["Base Color"].default_value = color
    return mat


def settable_enum(owner, prop, wanted):
    """Return the first identifier in `wanted` that `owner.prop` accepts at run time, else None. Never hardcodes
    an identifier's existence: enums changed between 4.x and 5.x."""
    original = getattr(owner, prop)
    for ident in wanted:
        try:
            setattr(owner, prop, ident)
        except (TypeError, ValueError):
            continue
        setattr(owner, prop, original)
        return ident
    return None
