"""Shared helpers for every forge module. Pure bpy/bmesh/mathutils; works live and in `blender -b`.
Units are Blender units (metres at the default Unit Scale 1.0) unless a name says otherwise."""
import json
import math
from contextlib import contextmanager
from pathlib import Path

import bmesh
import bpy
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
    """Bake scale, then rotation, then location into a mesh's data without bpy.ops; children keep their world pose.
    Order is fixed (basis = T @ R @ S), so rotation needs scale and location needs both."""
    if (rotation and not scale) or (location and not rotation):
        raise ForgeError("bake scale before rotation and rotation before location (basis = T @ R @ S)")
    if obj.type != "MESH":
        raise ForgeError(f"{obj.name} is a {obj.type}; only mesh data can absorb a transform")
    if obj.data.users > 1:
        raise ForgeError(f"{obj.name}'s mesh is shared by {obj.data.users} users; make it single-user first")
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
    obj.data.transform(baked)
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
