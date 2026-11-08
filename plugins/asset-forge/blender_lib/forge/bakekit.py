"""Cycles bake plumbing shared by bake, stylize and project_paint: shader-node builders, temporary render settings and
selection, bake targets, image I/O. Internal to forge: the skills do not call it, and its helpers take Blender data and
return Blender data, not the object-name / ok() contract of the forge API. Distances are metres; sizes are pixels."""
import math
import re
from contextlib import contextmanager

import bpy
import numpy as np

from .util import ForgeError, select_only, settable_enum


def set_enum(owner, prop, *wanted):
    """Set owner.prop to the first identifier in `wanted` this Blender accepts and return it; ForgeError if none."""
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
def temp_attrs(owner, **values):
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
def temp_enums(owner, **candidates):
    """temp_attrs for enums: each value is a tuple of identifiers, set in order through a settable_enum probe."""
    old = {key: getattr(owner, key) for key in candidates}
    try:
        for key, wanted in candidates.items():
            set_enum(owner, key, *wanted)
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
def cycles_session(scene, samples):
    """Cycles on the configured GPU, else CPU, at `samples`; yields the device. Engine, device and samples restored."""
    engine = settable_enum(scene.render, "engine", ["CYCLES"])
    if engine is None:
        raise ForgeError("Cycles is not available (is the add-on disabled?); baking needs it", stage="engine")
    with temp_attrs(scene.render, engine=engine):
        device = settable_enum(scene.cycles, "device", ["GPU", "CPU"] if _gpu_configured() else ["CPU"])
        with temp_attrs(scene.cycles, device=device, samples=int(samples)):
            yield device


@contextmanager
def keep_selection():
    """Restore the view layer's selection and active object on exit."""
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
def slot_materials(obj):
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


def socket(sockets, key):
    """The socket whose identifier is `key`, else the enabled one named `key`; ForgeError if neither exists."""
    for s in sockets:
        if s.identifier == key:
            return s
    for s in sockets:
        if s.name == key and s.enabled:
            return s
    raise ForgeError(f"no socket {key!r} among {[s.identifier for s in sockets]}", stage="blender")


def node(nt, kind, inputs=None, **props):
    """New node; ENUM props go through a settable_enum probe; input values are linked if sockets, else set."""
    new = nt.nodes.new(kind)
    for key, value in props.items():
        if new.bl_rna.properties[key].type == "ENUM":
            set_enum(new, key, value)
        else:
            setattr(new, key, value)
    for key, value in (inputs or {}).items():
        sock = socket(new.inputs, key)
        if isinstance(value, bpy.types.NodeSocket):
            nt.links.new(value, sock)
        else:
            sock.default_value = value
    return new


def emission(nt, color_socket):
    """An Emission shader of strength 1 fed by `color_socket`; returns its output socket."""
    return node(nt, "ShaderNodeEmission", {"Color": color_socket, "Strength": 1.0}).outputs["Emission"]


@contextmanager
def surface(materials, build):
    """Feed each material's Cycles output from build(node_tree, index) -> shader socket; nodes and links restored."""
    patched = []
    try:
        for index, mat in enumerate(dict.fromkeys(materials)):
            nt = mat.node_tree
            before = {n.name for n in nt.nodes}
            out = nt.get_output_node("CYCLES") or node(nt, "ShaderNodeOutputMaterial")
            sock = out.inputs["Surface"]
            old = sock.links[0].from_socket if sock.links else None
            patched.append((nt, before, sock, old))
            nt.links.new(build(nt, index), sock)
    except Exception:
        _unpatch(patched)
        raise
    try:
        yield
    finally:
        _unpatch(patched)


def _unpatch(patched):
    for nt, before, sock, old in patched:
        for n in [n for n in nt.nodes if n.name not in before]:
            nt.nodes.remove(n)
        if old is not None:
            nt.links.new(old, sock)


@contextmanager
def target_image(materials, image):
    """Put an active Image Texture node holding `image` in each material for the bake; removed on exit."""
    placed = []
    for mat in dict.fromkeys(materials):
        nt = mat.node_tree
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = image
        placed.append((nt, tex, nt.nodes.active))
        nt.nodes.active = tex
    try:
        yield
    finally:
        for nt, tex, previous in placed:
            nt.nodes.remove(tex)
            if previous is not None:
                nt.nodes.active = previous


def new_image(name, resolution, data, fill, float_buffer=False, alpha=False):
    """A square `resolution` px image filled with the RGBA `fill`; data=True marks it non-colour."""
    image = bpy.data.images.new(name, resolution, resolution, alpha=alpha, float_buffer=float_buffer, is_data=data)
    image.pixels.foreach_set(np.tile(np.asarray(fill, np.float32), resolution * resolution))
    return image


def pixels(image):
    """The image's pixels as a float32 (height, width, 4) array, bottom row first."""
    w, h = image.size
    buf = np.empty(w * h * 4, np.float32)
    image.pixels.foreach_get(buf)
    return buf.reshape(h, w, 4)


def save_png(image, path):
    set_enum(image, "file_format", "PNG")
    image.save(filepath=str(path))


def safe_name(name):
    """`name` with every run of characters outside [A-Za-z0-9_.-] replaced by one underscore, for file names."""
    return re.sub(r"[^A-Za-z0-9_.-]+", "_", name)


def render_uv(obj):
    """The name of obj's render UV map (else its first); ForgeError(stage="uv") when it has none."""
    layers = obj.data.uv_layers
    if not len(layers):
        raise ForgeError(f"{obj.name} has no UV map; unwrap it before baking", stage="uv")
    return next((layer.name for layer in layers if layer.active_render), layers[0].name)


def texel_size(obj, uv_name, resolution):
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


def run_bake(target, bake_type, uv_name, margin, source=None, extrusion=0.0, cage=None):
    """bpy.ops.object.bake of `bake_type` onto target's UV map `uv_name`, selected-to-active from `source` when given
    (rays start `extrusion` metres out, or from `cage`); normals tangent space +X +Y +Z. ForgeError(stage="bake")."""
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


def to_linear(c):
    """One sRGB channel value (0-1) in linear light."""
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
