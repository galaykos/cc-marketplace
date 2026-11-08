"""Bake texture maps of a mesh (or of a high-poly onto it) into PNG files with Cycles. Works live and in `blender -b`.
Distances are metres; resolutions are pixels per side. Every render setting touched is restored before returning."""
import colorsys
import math
import re
import time
from contextlib import ExitStack, contextmanager
from pathlib import Path

import bpy
import numpy as np

from .util import ForgeError, get_object, ok, select_only, settable_enum, world_bbox

MAPS = ("normal", "ao", "curvature", "thickness", "id")
_FILL = {"normal": (0.5, 0.5, 1.0, 1.0), "ao": (1.0, 1.0, 1.0, 1.0), "curvature": (0.5, 0.5, 0.5, 1.0),
         "thickness": (1.0, 1.0, 1.0, 1.0), "id": (0.0, 0.0, 0.0, 1.0)}


def _enum(owner, prop, *wanted):
    ident = settable_enum(owner, prop, wanted)
    if ident is None:
        raise ForgeError(f"{type(owner).__name__}.{prop} accepts none of {list(wanted)} in Blender "
                         f"{bpy.app.version_string}", stage="blender")
    setattr(owner, prop, ident)
    return ident


def _probe(owner, prop, *wanted):
    ident = settable_enum(owner, prop, wanted)
    if ident is None:
        raise ForgeError(f"{type(owner).__name__}.{prop} accepts none of {list(wanted)}", stage="blender")
    return ident


@contextmanager
def _temp_attrs(owner, **values):
    """Set attributes for the block; originals come back in the same order (media_type before file_format)."""
    old = {key: getattr(owner, key) for key in values}
    try:
        for key, value in values.items():
            setattr(owner, key, value)
        yield
    finally:
        for key, value in old.items():
            setattr(owner, key, value)


@contextmanager
def _temp_enums(owner, **candidates):
    """_temp_attrs for enums: each value is a tuple of identifiers, set in order through a settable_enum probe."""
    old = {key: getattr(owner, key) for key in candidates}
    try:
        for key, wanted in candidates.items():
            _enum(owner, key, *wanted)
        yield
    finally:
        for key, value in old.items():
            setattr(owner, key, value)


def _gpu_configured():
    addon = bpy.context.preferences.addons.get("cycles")
    prefs = getattr(addon, "preferences", None)
    if prefs is None or getattr(prefs, "compute_device_type", "NONE") == "NONE":
        return False
    return any(d.use and d.type != "CPU" for d in getattr(prefs, "devices", ()))


@contextmanager
def _cycles_session(scene, samples):
    """Cycles on the configured GPU, else CPU, at `samples`; yields the device. Engine, device and samples restored."""
    engine = settable_enum(scene.render, "engine", ["CYCLES"])
    if engine is None:
        raise ForgeError("Cycles is not available (is the add-on disabled?); baking needs it", stage="engine")
    with _temp_attrs(scene.render, engine=engine):
        device = settable_enum(scene.cycles, "device", ["GPU", "CPU"] if _gpu_configured() else ["CPU"])
        with _temp_attrs(scene.cycles, device=device, samples=int(samples)):
            yield device


@contextmanager
def _keep_selection():
    layer = bpy.context.view_layer
    selected = {o.name for o in layer.objects if o.select_get()}
    active = layer.objects.active.name if layer.objects.active else None
    try:
        yield
    finally:
        for o in layer.objects:
            o.select_set(o.name in selected)
        layer.objects.active = layer.objects.get(active) if active else None


@contextmanager
def _slot_materials(obj):
    """Yield one node material per slot; empty slots (or a slotless object) get a temporary one, removed on exit."""
    appended = not obj.material_slots
    if appended:
        obj.data.materials.append(None)
    swapped, temps = [], []
    for slot in obj.material_slots:
        if slot.material is None or slot.material.node_tree is None:
            temp = bpy.data.materials.new("forge_tmp_slot")
            swapped.append((slot, slot.material))
            slot.material = temp
            temps.append(temp)
    try:
        yield [slot.material for slot in obj.material_slots]
    finally:
        for slot, original in swapped:
            slot.material = original
        if appended:
            obj.data.materials.clear()
        for temp in temps:
            bpy.data.materials.remove(temp)


def _sock(sockets, key):
    for s in sockets:
        if s.identifier == key:
            return s
    for s in sockets:
        if s.name == key and s.enabled:
            return s
    raise ForgeError(f"no socket {key!r} among {[s.identifier for s in sockets]}", stage="blender")


def _node(nt, kind, inputs=None, **props):
    """New node; ENUM props go through a settable_enum probe; input values are linked if sockets, else set."""
    node = nt.nodes.new(kind)
    for key, value in props.items():
        if node.bl_rna.properties[key].type == "ENUM":
            _enum(node, key, value)
        else:
            setattr(node, key, value)
    for key, value in (inputs or {}).items():
        sock = _sock(node.inputs, key)
        if isinstance(value, bpy.types.NodeSocket):
            nt.links.new(value, sock)
        else:
            sock.default_value = value
    return node


def _emission(nt, color_socket):
    return _node(nt, "ShaderNodeEmission", {"Color": color_socket, "Strength": 1.0}).outputs["Emission"]


@contextmanager
def _surface(materials, build):
    """Feed each material's Cycles output from build(node_tree, index) -> shader socket; nodes and links restored."""
    patched = []
    try:
        for index, mat in enumerate(dict.fromkeys(materials)):
            nt = mat.node_tree
            before = {n.name for n in nt.nodes}
            out = nt.get_output_node("CYCLES") or _node(nt, "ShaderNodeOutputMaterial")
            surface = out.inputs["Surface"]
            old = surface.links[0].from_socket if surface.links else None
            patched.append((nt, before, surface, old))
            nt.links.new(build(nt, index), surface)
    except Exception:
        _unpatch(patched)
        raise
    try:
        yield
    finally:
        _unpatch(patched)


def _unpatch(patched):
    for nt, before, surface, old in patched:
        for node in [n for n in nt.nodes if n.name not in before]:
            nt.nodes.remove(node)
        if old is not None:
            nt.links.new(old, surface)


@contextmanager
def _target_image(materials, image):
    placed = []
    for mat in dict.fromkeys(materials):
        nt = mat.node_tree
        node = nt.nodes.new("ShaderNodeTexImage")
        node.image = image
        placed.append((nt, node, nt.nodes.active))
        nt.nodes.active = node
    try:
        yield
    finally:
        for nt, node, previous in placed:
            nt.nodes.remove(node)
            if previous is not None:
                nt.nodes.active = previous


def _new_image(name, resolution, data, fill, float_buffer=False, alpha=False):
    image = bpy.data.images.new(name, resolution, resolution, alpha=alpha, float_buffer=float_buffer, is_data=data)
    image.pixels.foreach_set(np.tile(np.asarray(fill, np.float32), resolution * resolution))
    return image


def _pixels(image):
    w, h = image.size
    buf = np.empty(w * h * 4, np.float32)
    image.pixels.foreach_get(buf)
    return buf.reshape(h, w, 4)


def _save_png(image, path):
    _enum(image, "file_format", "PNG")
    image.save(filepath=str(path))


def _safe(name):
    return re.sub(r"[^A-Za-z0-9_.-]+", "_", name)


def _render_uv(obj):
    layers = obj.data.uv_layers
    if not len(layers):
        raise ForgeError(f"{obj.name} has no UV map; unwrap it before baking", stage="uv")
    return next((layer.name for layer in layers if layer.active_render), layers[0].name)


def _texel_size(obj, uv_name, resolution):
    """World metres covered by one texel at `resolution`, from the ratio of 3D area to UV area."""
    me = obj.data
    me.calc_loop_triangles()
    n = len(me.loop_triangles)
    loops = np.empty(n * 3, np.int32)
    verts = np.empty(n * 3, np.int32)
    me.loop_triangles.foreach_get("loops", loops)
    me.loop_triangles.foreach_get("vertices", verts)
    co = np.empty(len(me.vertices) * 3, np.float32)
    me.vertices.foreach_get("co", co)
    mw = np.array(obj.matrix_world)
    co = co.reshape(-1, 3) @ mw[:3, :3].T + mw[:3, 3]
    uv = np.empty(len(me.loops) * 2, np.float32)
    me.uv_layers[uv_name].data.foreach_get("uv", uv)
    p = co[verts].reshape(n, 3, 3)
    t = uv.reshape(-1, 2)[loops].reshape(n, 3, 2)
    area3 = 0.5 * np.linalg.norm(np.cross(p[:, 1] - p[:, 0], p[:, 2] - p[:, 0]), axis=1).sum()
    e1, e2 = t[:, 1] - t[:, 0], t[:, 2] - t[:, 0]
    area2 = 0.5 * np.abs(e1[:, 0] * e2[:, 1] - e1[:, 1] * e2[:, 0]).sum()
    if area2 < 1e-9:
        raise ForgeError(f"{obj.name}'s UV map {uv_name!r} has zero area; unwrap it before baking", stage="uv")
    return math.sqrt(area3 / area2) / resolution


def _bake(target, bake_type, uv_name, margin, source=None, extrusion=0.0, cage=None):
    scene = bpy.context.scene
    settings = scene.render.bake
    kwargs = {"type": _probe(scene.cycles, "bake_type", bake_type), "margin": int(margin), "use_clear": False,
              "uv_layer": uv_name, "target": _probe(settings, "target", "IMAGE_TEXTURES"),
              "save_mode": _probe(settings, "save_mode", "INTERNAL"), "use_selected_to_active": source is not None}
    if source is not None:
        kwargs.update(cage_extrusion=float(extrusion), max_ray_distance=0.0, use_cage=cage is not None,
                      cage_object=cage.name if cage else "")
    if kwargs["type"] == "NORMAL":
        kwargs.update(normal_space=_probe(settings, "normal_space", "TANGENT"),
                      normal_r=_probe(settings, "normal_r", "POS_X"), normal_g=_probe(settings, "normal_g", "POS_Y"),
                      normal_b=_probe(settings, "normal_b", "POS_Z"))
    select_only(*([source, target] if source is not None else [target]), active=target)
    try:
        bpy.ops.object.bake(**kwargs)
    except RuntimeError as exc:
        raise ForgeError(f"{bake_type} bake of {target.name} failed: {exc}", stage="bake") from exc


def _to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _id_srgb(index):
    return [round(v, 4) for v in colorsys.hsv_to_rgb((index * 0.618034) % 1.0, 0.7, 0.9)]


def _ao_shader(distance, inside=False):
    def build(nt, _index):
        ao = _node(nt, "ShaderNodeAmbientOcclusion", {"Distance": distance}, only_local=True, inside=inside,
                   samples=16)
        return _emission(nt, ao.outputs["AO"])
    return build


def _curvature_shader(radius, sign_distance):
    """0.5 flat, toward 1 on convex edges, toward 0 in concave ones: edge strength from how far a Bevel normal of
    `radius` turns from the surface normal (full at 30 degrees), sign from local AO (a concave edge occludes itself,
    a convex one does not)."""
    def build(nt, _index):
        geo = _node(nt, "ShaderNodeNewGeometry")
        bevel = _node(nt, "ShaderNodeBevel", {"Radius": radius}, samples=16)
        dot = _node(nt, "ShaderNodeVectorMath", {"Vector": bevel.outputs["Normal"],
                                                 "Vector_001": geo.outputs["Normal"]}, operation="DOT_PRODUCT")
        edge = _node(nt, "ShaderNodeMapRange", {"Value": dot.outputs["Value"], "From Min": 1.0,
                                                "From Max": math.cos(math.pi / 6), "To Min": 0.0, "To Max": 1.0})
        ao = _node(nt, "ShaderNodeAmbientOcclusion", {"Distance": sign_distance}, only_local=True, samples=16)
        sign = _node(nt, "ShaderNodeMapRange", {"Value": ao.outputs["AO"], "From Min": 0.75, "From Max": 0.95,
                                                "To Min": -1.0, "To Max": 1.0})
        signed = _node(nt, "ShaderNodeMath", {"Value": edge.outputs["Result"], "Value_001": sign.outputs["Result"]},
                       operation="MULTIPLY")
        curv = _node(nt, "ShaderNodeMapRange", {"Value": signed.outputs["Value"], "From Min": -1.0, "From Max": 1.0,
                                                "To Min": 0.0, "To Max": 1.0})
        return _emission(nt, curv.outputs["Result"])
    return build


def _id_shader(nt, index):
    rgb = [_to_linear(c) for c in _id_srgb(index)]
    return _emission(nt, (*rgb, 1.0))


def bake_maps(low, out_dir, high=None, maps=MAPS, resolution=1024, extrusion=0.02, cage=None, samples=16,
              margin_px=8):
    """Bake `maps` of `low` (object or name) into `<out_dir>/<low>_<map>.png`, one image per map across all of its
    material slots, through a temporary image node per material (removed afterwards).

    normal: tangent space, OpenGL (+Y green); from `high` selected-to-active when given (rays start `extrusion`
      metres out, or from `cage`), else the low's own shading normals, flat unless its materials carry bump/normal.
    ao: Ambient Occlusion of the source alone (other objects ignored), distance 0.25 x its bbox diagonal.
    curvature: 0.5 flat, brighter on convex edges, darker in concave ones (Bevel-normal turn, signed by local AO);
      band radius max(1% of diagonal, 2 texels). Chosen over Pointiness, which is per vertex and reads constant
      across a 12-tri crate.
    thickness: AO with Inside on, distance 0.5 x diagonal: 1 thick, toward 0 thin.
    id: a flat colour per material of the source (sRGB values in `id_colors`).
    `high` supplies ao/curvature/thickness/id too. Requires a UV map with area. Returns paths, per-map seconds,
    the distances used (metres) and the device."""
    low = get_object(low, "MESH")
    high = get_object(high, "MESH") if high is not None else None
    cage = get_object(cage, "MESH") if cage is not None else None
    if high is low:
        raise ForgeError("high and low are the same object")
    wanted = list(dict.fromkeys([maps] if isinstance(maps, str) else maps))
    unknown = [m for m in wanted if m not in MAPS]
    if not wanted or unknown:
        raise ForgeError(f"unknown maps {unknown or wanted}; choose from {list(MAPS)}")
    if int(resolution) < 1 or int(samples) < 1 or int(margin_px) < 0 or extrusion < 0:
        raise ForgeError("resolution and samples must be >= 1, margin_px and extrusion >= 0")
    resolution = int(resolution)
    uv_name = _render_uv(low)
    texel = _texel_size(low, uv_name, resolution)
    source = high or low
    lo, hi = world_bbox(source)
    diag = max((hi - lo).length, 1e-6)
    distances = {"ao": 0.25 * diag, "thickness": 0.5 * diag, "curvature_radius": max(0.01 * diag, 2.0 * texel)}
    shaders = {"ao": _ao_shader(distances["ao"]), "thickness": _ao_shader(distances["thickness"], inside=True),
               "curvature": _curvature_shader(distances["curvature_radius"], 3 * distances["curvature_radius"]),
               "id": _id_shader}
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    paths, seconds, id_colors = {}, {}, []
    scene = bpy.context.scene
    with ExitStack() as stack:
        stack.enter_context(_keep_selection())
        device = stack.enter_context(_cycles_session(scene, samples))
        low_mats = stack.enter_context(_slot_materials(low))
        src_mats = stack.enter_context(_slot_materials(high)) if high else low_mats
        unique = list(dict.fromkeys(src_mats))
        id_colors = [{"slot": i, "material": m.name, "srgb": _id_srgb(unique.index(m))} for i, m in enumerate(src_mats)]
        for name in wanted:
            start = time.perf_counter()
            image = _new_image(f"forge_bake_{name}", resolution, data=name != "id", fill=_FILL[name])
            try:
                with ExitStack() as per_map:
                    if name != "normal":
                        per_map.enter_context(_surface(src_mats, shaders[name]))
                    per_map.enter_context(_target_image(low_mats, image))
                    _bake(low, "NORMAL" if name == "normal" else "EMIT", uv_name, margin_px, source=high,
                          extrusion=extrusion, cage=cage)
                path = out / f"{_safe(low.name)}_{name}.png"
                _save_png(image, path)
            finally:
                bpy.data.images.remove(image)
            paths[name] = str(path)
            seconds[name] = round(time.perf_counter() - start, 3)
    for entry in id_colors:
        if entry["material"] and entry["material"].startswith("forge_tmp_slot"):
            entry["material"] = None
    summary = ok(object=low.name, high=high.name if high else None, uv_layer=uv_name, resolution=resolution,
                 samples=int(samples), device=device, paths=paths, seconds=seconds,
                 distances_m={k: round(v, 4) for k, v in distances.items()})
    if "id" in wanted:
        summary["id_colors"] = id_colors
    return summary
