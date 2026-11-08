"""Level-of-detail chains: collapse-decimated copies of a mesh at ratios of its triangle count, named per engine.
Triangle counts are evaluated (modifiers applied); bounding boxes are world space, metres."""
import re

import bmesh
import bpy

from .util import ForgeError, get_object, load_preset, ok, settable_enum, tri_count, world_bbox
from .uv import _uv_split

PROTECT_GROUP = "FORGE_lod_protect"
SILHOUETTE_TOLERANCE = 0.02


def _name_regex(pattern, **fixed):
    """Regex for a preset naming pattern; placeholders not in `fixed` become groups ({name} any text, {n} digits,
    {nn} two or more digits)."""
    groups = {"name": r"(?P<name>.+)", "n": r"(?P<n>\d+)", "nn": r"(?P<nn>\d{2,})"}
    out = re.escape(pattern)
    for key, group in groups.items():
        out = out.replace(re.escape("{" + key + "}"), re.escape(str(fixed[key])) if key in fixed else group)
    return re.compile(out)


def _lod_name(pattern, name, n):
    return pattern.replace("{name}", name).replace("{n}", str(n))


def _base_name(obj_name, pattern):
    match = _name_regex(pattern).fullmatch(obj_name)
    if match is None:
        return obj_name
    if int(match["n"]) != 0:
        raise ForgeError(f"{obj_name} is LOD{match['n']}; build the chain from LOD0")
    return match["name"]


def _lod_objects(base, pattern):
    """{n: object} for every object named as a LOD of `base` under `pattern`."""
    regex = _name_regex(pattern, name=base)
    found = {}
    for o in bpy.data.objects:
        match = regex.fullmatch(o.name)
        if match:
            found[int(match["n"])] = o
    return found


def _protected_vertices(obj):
    """Indices of base-mesh vertices on a UV seam (marked or a UV split), a sharp-marked edge or a boundary edge."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    uv_layers = list(bm.loops.layers.uv.values())
    keep = set()
    for e in bm.edges:
        hit = e.seam or not e.smooth or e.is_boundary
        if not hit and len(e.link_loops) == 2:
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


def make_lod_chain(obj, ratios=None, engine="unity", platform="pc"):
    """Build LOD1+ as collapse-decimated copies of obj at each ratio of LOD0's evaluated triangle count. obj becomes
    LOD0 and is renamed per the engine preset's naming.lod. Vertices on UV seams, sharp-marked and boundary edges
    are locked. ratios default to budgets/<platform>.json lod_ratios and must start at 1.0. Re-running replaces the
    chain. Returns per-LOD tris, achieved ratio and bbox deviation (fraction of LOD0's largest dimension)."""
    obj = get_object(obj, "MESH")
    preset = load_preset("engines", engine)
    pattern = preset["naming"]["lod"]
    source = "argument"
    if ratios is None:
        ratios, source = load_preset("budgets", platform)["lod_ratios"], f"budgets/{platform}.json"
    ratios = _check_ratios(ratios)
    base = _base_name(obj.name, pattern)
    lod0_name = _lod_name(pattern, base, 0)
    clash = bpy.data.objects.get(lod0_name)
    if clash is not None and clash is not obj:
        raise ForgeError(f"another object is already named {lod0_name}; rename it or pass it instead")
    lod0_tris = tri_count(obj)
    if lod0_tris == 0:
        raise ForgeError(f"{obj.name} has no faces to decimate")
    removed = []
    for n, stale in sorted(_lod_objects(base, pattern).items()):
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
    protected, total = _protected_vertices(obj)
    lods = [{"name": obj.name, "ratio": 1.0, "tris": lod0_tris, "achieved_ratio": 1.0, "bbox_deviation": 0.0}]
    for n, ratio in enumerate(ratios[1:], start=1):
        lod = _decimated_copy(obj, _lod_name(pattern, base, n), ratio, protected)
        bpy.context.view_layer.update()
        tris = tri_count(lod)
        achieved = tris / lod0_tris
        lods.append({"name": lod.name, "ratio": ratio, "tris": tris, "achieved_ratio": round(achieved, 4),
                     "bbox_deviation": round(_bbox_deviation(ref_lo, ref_hi, lod), 5),
                     "limited_by_protection": achieved > ratio * 1.05 + 1 / lod0_tris})
    lod_rules = preset.get("lod", {})
    return ok(object=obj.name, base_name=base, engine=engine, ratios=ratios, ratios_from=source, lods=lods,
              protected_verts=len(protected), total_verts=total,
              silhouette_ok=all(entry["bbox_deviation"] <= SILHOUETTE_TOLERANCE for entry in lods),
              lod_export=lod_rules.get("export"), lod_note=lod_rules.get("note"), removed=removed)
