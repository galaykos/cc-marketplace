"""Level-of-detail chains: collapse-decimated copies of a mesh at ratios of its triangle count, named per engine.
Triangle counts are evaluated (modifiers applied); bounding boxes are world space, metres."""
import bmesh
import bpy

from mathutils.bvhtree import BVHTree

from .naming import format_name, lod0_base, lod_objects
from .util import (ForgeError, ensure_object_mode, evaluated_bmesh, get_object, load_preset, ok, settable_enum,
                   tri_count, world_bbox)
from .uv import _uv_split

PROTECT_GROUP = "FORGE_lod_protect"
SILHOUETTE_TOLERANCE = 0.02
PROTECT_ALL = ("seams", "sharp", "boundary")


def _protected_vertices(obj, protect=PROTECT_ALL):
    """Indices of base-mesh vertices on the edge kinds in `protect`: "seams" (marked or a UV split), "sharp"
    (sharp-marked), "boundary"."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    uv_layers = list(bm.loops.layers.uv.values())
    keep = set()
    for e in bm.edges:
        hit = ("seams" in protect and e.seam) or ("sharp" in protect and not e.smooth) \
            or ("boundary" in protect and e.is_boundary)
        if not hit and "seams" in protect and len(e.link_loops) == 2:
            hit = any(_uv_split(*e.link_loops, layer) for layer in uv_layers)
        if hit:
            keep.update(v.index for v in e.verts)
    total = len(bm.verts)
    bm.free()
    return keep, total


def _check_ratios(ratios):
    if not isinstance(ratios, (list, tuple)) or len(ratios) < 2:
        raise ForgeError("ratios needs LOD0's 1.0 and at least one smaller ratio, e.g. [1.0, 0.5, 0.25]")
    if float(ratios[0]) != 1.0:
        raise ForgeError(f"ratios[0] is LOD0 and must be 1.0, got {ratios[0]}")
    if any(not 0 < b < a for a, b in zip(ratios, ratios[1:])):
        raise ForgeError(f"ratios must fall strictly and stay above 0: {ratios}")
    return [float(r) for r in ratios]


def _decimated_copy(src, name, ratio, protected):
    """A copy of src with every non-Armature modifier plus a collapse Decimate applied; Armature modifiers stay."""
    lod = src.copy()
    lod.data = src.data.copy()
    lod.name = name
    for collection in src.users_collection:
        collection.objects.link(lod)
    group = lod.vertex_groups.new(name=PROTECT_GROUP)
    if protected:
        group.add(sorted(protected), 1.0, "REPLACE")
    mod = lod.modifiers.new("FORGE_LOD", "DECIMATE")
    collapse = settable_enum(mod, "decimate_type", ["COLLAPSE"])
    if collapse is None:
        raise ForgeError("this Blender's Decimate modifier has no COLLAPSE type", stage="blender")
    mod.decimate_type = collapse
    mod.ratio = ratio
    # Collapse skips every edge touching a weight-0 vertex; inverting the group gives the protected verts weight 0.
    mod.vertex_group = PROTECT_GROUP
    mod.invert_vertex_group = True
    deform = {m.name: m.show_viewport for m in lod.modifiers if m.type == "ARMATURE"}
    for key in deform:
        lod.modifiers[key].show_viewport = False
    depsgraph = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(lod.evaluated_get(depsgraph), preserve_all_data_layers=True,
                                           depsgraph=depsgraph)
    old = lod.data
    lod.data = mesh
    bpy.data.meshes.remove(old)
    mesh.name = name
    for key in [m.name for m in lod.modifiers if m.name not in deform]:
        lod.modifiers.remove(lod.modifiers[key])
    for key, shown in deform.items():
        lod.modifiers[key].show_viewport = shown
    lod.vertex_groups.remove(lod.vertex_groups[PROTECT_GROUP])
    return lod


def _bbox_deviation(ref_lo, ref_hi, obj):
    lo, hi = world_bbox(obj)
    size = max(ref_hi - ref_lo)
    if size <= 0:
        return 0.0
    return max(max(abs(a - b) for a, b in zip(lo, ref_lo)), max(abs(a - b) for a, b in zip(hi, ref_hi))) / size


def _world_surface(obj):
    """(BVH tree, sample points) of obj's evaluated mesh in world space; the samples are its vertices and face centres."""
    bm = evaluated_bmesh(obj)
    bm.transform(obj.matrix_world)
    tree = BVHTree.FromBMesh(bm)
    samples = [v.co.copy() for v in bm.verts] + [f.calc_center_median() for f in bm.faces]
    bm.free()
    return tree, samples


def _surface_deviation(ref, obj, size):
    """Largest distance from either surface's samples to the other surface, as a fraction of `size`."""
    if size <= 0:
        return 0.0
    ref_tree, ref_samples = ref
    tree, samples = _world_surface(obj)
    far = max([ref_tree.find_nearest(p)[3] for p in samples] + [tree.find_nearest(p)[3] for p in ref_samples],
              default=0.0)
    return far / size


def make_lod_chain(obj, ratios=None, engine="unity", platform="pc", protect=PROTECT_ALL):
    """Build LOD1+ as collapse-decimated copies of obj at each ratio of LOD0's evaluated triangle count. obj becomes
    LOD0 and is renamed per the engine preset's naming.lod. Vertices on UV seams, sharp-marked and boundary edges
    are locked; `protect` narrows that to a subset of ("seams", "sharp", "boundary") — a hard-surface mesh whose every
    edge is a seam locks every vertex, so pass ("boundary",) there. A level that would not reduce the previous one is
    not built and is listed in `skipped`. ratios default to budgets/<platform>.json lod_ratios and must start at
    1.0. Re-running replaces the chain; Edit Mode is left first. Returns per-LOD tris, achieved ratio, bbox deviation
    and surface deviation (world space, fractions of LOD0's largest dimension; the surface one is the farthest vertex or
    face centre of either mesh from the other's surface), and silhouette_ok when every surface deviation is within
    SILHOUETTE_TOLERANCE."""
    obj = get_object(obj, "MESH")
    preset = load_preset("engines", engine)
    pattern = preset["naming"]["lod"]
    source = "argument"
    if ratios is None:
        ratios, source = load_preset("budgets", platform)["lod_ratios"], f"budgets/{platform}.json"
    ratios = _check_ratios(ratios)
    unknown = set(protect) - set(PROTECT_ALL)
    if unknown:
        raise ForgeError(f"protect takes a subset of {PROTECT_ALL}, got {sorted(unknown)}")
    base = lod0_base(obj.name, pattern)
    lod0_name = format_name(pattern, base, 0)
    clash = bpy.data.objects.get(lod0_name)
    if clash is not None and clash is not obj:
        raise ForgeError(f"another object is already named {lod0_name}; rename it or pass it instead")
    ensure_object_mode()
    lod0_tris = tri_count(obj)
    if lod0_tris == 0:
        raise ForgeError(f"{obj.name} has no faces to decimate")
    removed = []
    for n, stale in sorted(lod_objects(base, pattern).items()):
        if n == 0:
            continue
        removed.append(stale.name)
        data = stale.data
        bpy.data.objects.remove(stale)
        if data is not None and data.users == 0:
            bpy.data.meshes.remove(data)
    obj.name = lod0_name
    bpy.context.view_layer.update()
    ref_lo, ref_hi = world_bbox(obj)
    size = max(ref_hi - ref_lo)
    ref_surface = _world_surface(obj)
    protected, total = _protected_vertices(obj, tuple(protect))
    lods = [{"name": obj.name, "ratio": 1.0, "tris": lod0_tris, "achieved_ratio": 1.0, "bbox_deviation": 0.0,
             "surface_deviation": 0.0}]
    skipped = []
    n = 0
    for ratio in ratios[1:]:
        lod = _decimated_copy(obj, format_name(pattern, base, n + 1), ratio, protected)
        bpy.context.view_layer.update()
        tris = tri_count(lod)
        if tris >= lods[-1]["tris"]:
            skipped.append({"ratio": ratio, "tris": tris, "reason": "no reduction over the previous level: protected "
                            f"vertices {len(protected)}/{total}; narrow `protect`, or the mesh is already minimal"})
            data = lod.data
            bpy.data.objects.remove(lod)
            if data is not None and data.users == 0:
                bpy.data.meshes.remove(data)
            continue
        n += 1
        achieved = tris / lod0_tris
        lods.append({"name": lod.name, "ratio": ratio, "tris": tris, "achieved_ratio": round(achieved, 4),
                     "bbox_deviation": round(_bbox_deviation(ref_lo, ref_hi, lod), 5),
                     "surface_deviation": round(_surface_deviation(ref_surface, lod, size), 5),
                     "limited_by_protection": achieved > ratio * 1.05 + 1 / lod0_tris})
    lod_rules = preset.get("lod", {})
    return ok(object=obj.name, base_name=base, engine=engine, ratios=ratios, ratios_from=source, lods=lods,
              protected_verts=len(protected), total_verts=total, protect=list(protect), skipped=skipped,
              silhouette_ok=all(entry["surface_deviation"] <= SILHOUETTE_TOLERANCE for entry in lods),
              lod_export=lod_rules.get("export"), lod_note=lod_rules.get("note"), removed=removed)
