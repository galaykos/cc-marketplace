"""Tier-1 stylized texturing: a procedural hand-painted albedo baked from AO and curvature maps. No AI, no network.
Palette colours are sRGB in 0-1 (what a colour picker shows); the albedo PNG is sRGB."""
import colorsys
import re
import time
from contextlib import ExitStack, contextmanager
from pathlib import Path

import bpy
import numpy as np

from . import bake
from .util import ForgeError, get_object, material, ok

RECIPES = {
    "wood": {"palette": {"base": [[0.56, 0.37, 0.21], [0.42, 0.27, 0.15], [0.66, 0.49, 0.30]],
                         "shadow": [0.24, 0.16, 0.36], "highlight": [1.0, 0.87, 0.62]},
             "top_light": 0.35, "ao_strength": 0.8, "edge_strength": 0.6, "cavity_strength": 0.6,
             "noise_strength": 0.18, "noise_scale": 5.0, "stroke_stretch": 6.0, "roughness": 0.85},
    "stone": {"palette": {"base": [[0.53, 0.53, 0.50], [0.45, 0.47, 0.51], [0.61, 0.57, 0.51]],
                          "shadow": [0.22, 0.24, 0.40], "highlight": [0.96, 0.93, 0.82]},
              "top_light": 0.4, "ao_strength": 0.85, "edge_strength": 0.55, "cavity_strength": 0.7,
              "noise_strength": 0.2, "noise_scale": 3.0, "stroke_stretch": 1.5, "roughness": 0.9},
    "metal": {"palette": {"base": [[0.56, 0.59, 0.63], [0.43, 0.45, 0.49]],
                          "shadow": [0.14, 0.16, 0.32], "highlight": [1.0, 1.0, 0.95]},
              "top_light": 0.3, "ao_strength": 0.75, "edge_strength": 0.85, "cavity_strength": 0.6,
              "noise_strength": 0.1, "noise_scale": 8.0, "stroke_stretch": 4.0, "roughness": 0.5},
    "cloth": {"palette": {"base": [[0.62, 0.25, 0.23], [0.25, 0.42, 0.52], [0.80, 0.70, 0.50]],
                          "shadow": [0.27, 0.14, 0.36], "highlight": [1.0, 0.91, 0.76]},
              "top_light": 0.3, "ao_strength": 0.75, "edge_strength": 0.2, "cavity_strength": 0.5,
              "noise_strength": 0.12, "noise_scale": 12.0, "stroke_stretch": 1.0, "roughness": 0.95},
    "foliage": {"palette": {"base": [[0.33, 0.55, 0.21], [0.23, 0.45, 0.19], [0.46, 0.62, 0.23]],
                            "shadow": [0.11, 0.23, 0.33], "highlight": [0.95, 1.0, 0.56]},
                "top_light": 0.5, "ao_strength": 0.8, "edge_strength": 0.3, "cavity_strength": 0.5,
                "noise_strength": 0.2, "noise_scale": 5.0, "stroke_stretch": 2.5, "roughness": 0.9},
}
_NEEDED = ("ao", "curvature")
_HUE_TURN_MAX = 0.06


def _rgb(value, what):
    try:
        rgb = [float(c) for c in value]
    except (TypeError, ValueError):
        rgb = []
    if len(rgb) != 3 or not all(0.0 <= c <= 1.0 for c in rgb):
        raise ForgeError(f"{what} must be three sRGB values in 0-1, got {value!r}")
    return rgb


def _palette(recipe, palette):
    palette = dict(palette or {})
    unknown = set(palette) - {"base", "shadow", "highlight"}
    if unknown:
        raise ForgeError(f"unknown palette keys {sorted(unknown)}; use base, shadow, highlight")
    merged = {**RECIPES[recipe]["palette"], **palette}
    if isinstance(merged["base"], (str, bytes)) or not len(merged["base"]):
        raise ForgeError("palette base must be a non-empty list of sRGB colours")
    return {"base": [_rgb(c, "palette base colour") for c in merged["base"]],
            "shadow": _rgb(merged["shadow"], "palette shadow"),
            "highlight": _rgb(merged["highlight"], "palette highlight")}


def _linear(rgb):
    return (*[bake._to_linear(c) for c in rgb], 1.0)


def _paint(nt, base, pal, params, uv_name, ao_image, curv_image, mapping_scale):
    """The painted colour as an Emission socket; palette colours arrive as sRGB and are linearised here."""
    node = bake._node
    uv = node(nt, "ShaderNodeUVMap", uv_map=uv_name).outputs["UV"]
    ao = node(nt, "ShaderNodeTexImage", {"Vector": uv}, image=ao_image).outputs["Color"]
    curv = node(nt, "ShaderNodeTexImage", {"Vector": uv}, image=curv_image).outputs["Color"]
    geo = node(nt, "ShaderNodeNewGeometry")
    up = node(nt, "ShaderNodeSeparateXYZ", {"Vector": geo.outputs["Normal"]}).outputs["Z"]
    top = params["top_light"]
    light = node(nt, "ShaderNodeMapRange", {"Value": up, "From Min": -1.0, "From Max": 1.0, "To Min": 1.0 - top,
                                            "To Max": 1.0 + top}).outputs["Result"]
    lit = node(nt, "ShaderNodeVectorMath", {"Vector": _linear(base)[:3], "Scale": light},
               operation="SCALE").outputs["Vector"]
    occluded = node(nt, "ShaderNodeMapRange", {"Value": ao, "From Min": 1.0, "From Max": 0.0, "To Min": 0.0,
                                               "To Max": params["ao_strength"]}).outputs["Result"]
    underside = node(nt, "ShaderNodeMapRange", {"Value": up, "From Min": 0.0, "From Max": -1.0, "To Min": 0.0,
                                                "To Max": top}).outputs["Result"]
    shade = node(nt, "ShaderNodeMath", {"Value": occluded, "Value_001": underside}, operation="ADD",
                 use_clamp=True).outputs["Value"]
    turn = (colorsys.rgb_to_hsv(*pal["shadow"])[0] - colorsys.rgb_to_hsv(*base)[0] + 0.5) % 1.0 - 0.5
    turn = max(-_HUE_TURN_MAX, min(_HUE_TURN_MAX, turn))
    hue = node(nt, "ShaderNodeMapRange", {"Value": shade, "To Min": 0.5, "To Max": 0.5 + turn}).outputs["Result"]
    sat = node(nt, "ShaderNodeMapRange", {"Value": shade, "To Min": 1.0, "To Max": 1.1}).outputs["Result"]
    val = node(nt, "ShaderNodeMapRange", {"Value": shade, "To Min": 1.0, "To Max": 0.5}).outputs["Result"]
    turned = node(nt, "ShaderNodeHueSaturation", {"Color": lit, "Hue": hue, "Saturation": sat, "Value": val,
                                                   "Fac": 1.0}).outputs["Color"]
    shadow = _linear(pal["shadow"])
    tint = node(nt, "ShaderNodeMath", {"Value": shade, "Value_001": 0.35}, operation="MULTIPLY").outputs["Value"]
    mix = node(nt, "ShaderNodeMix", {"Factor_Float": tint, "A_Color": turned, "B_Color": shadow}, data_type="RGBA",
               blend_type="MIX")
    color = bake._sock(mix.outputs, "Result_Color")
    cavity = node(nt, "ShaderNodeMapRange", {"Value": curv, "From Min": 0.5, "From Max": 0.0, "To Min": 0.0,
                                             "To Max": params["cavity_strength"]}).outputs["Result"]
    edge = node(nt, "ShaderNodeMapRange", {"Value": curv, "From Min": 0.5, "From Max": 1.0, "To Min": 0.0,
                                           "To Max": params["edge_strength"]}).outputs["Result"]
    dark = (*[c * 0.5 for c in shadow[:3]], 1.0)
    for blend, factor, value in (("MIX", cavity, dark), ("SCREEN", edge, _linear(pal["highlight"]))):
        mix = node(nt, "ShaderNodeMix", {"Factor_Float": factor, "A_Color": color, "B_Color": value},
                   data_type="RGBA", blend_type=blend)
        color = bake._sock(mix.outputs, "Result_Color")
    if params["noise_strength"] > 0:
        coords = node(nt, "ShaderNodeTexCoord").outputs["Object"]
        mapped = node(nt, "ShaderNodeMapping", {"Vector": coords, "Scale": mapping_scale}).outputs["Vector"]
        noise = node(nt, "ShaderNodeTexNoise", {"Vector": mapped, "Scale": params["noise_scale"], "Detail": 3.0})
        strength = params["noise_strength"]
        stroke = node(nt, "ShaderNodeMapRange", {"Value": noise.outputs["Fac"], "From Min": 0.3, "From Max": 0.7,
                                                 "To Min": 1.0 - strength, "To Max": 1.0 + strength}).outputs["Result"]
        color = node(nt, "ShaderNodeVectorMath", {"Vector": color, "Scale": stroke},
                     operation="SCALE").outputs["Vector"]
    return bake._emission(nt, color)


@contextmanager
def _painted_slots(obj, pal, params, uv_name, ao_image, curv_image):
    """Swap every slot to a temporary painting material (palette base cycles per slot); originals back on exit."""
    extent = np.ptp(np.array([c[:] for c in obj.bound_box]), axis=0)
    size = max(float(extent.max()), 1e-6)
    scale = [1.0 / size] * 3
    scale[int(extent.argmax())] /= params["stroke_stretch"]
    appended = not obj.material_slots
    if appended:
        obj.data.materials.append(None)
    originals = [slot.material for slot in obj.material_slots]
    temps = []
    try:
        for index, slot in enumerate(obj.material_slots):
            temp = bpy.data.materials.new(f"forge_paint_{index}")
            temps.append(temp)
            nt = temp.node_tree
            for n in [n for n in nt.nodes if n.type != "OUTPUT_MATERIAL"]:
                nt.nodes.remove(n)
            out = nt.get_output_node("CYCLES") or bake._node(nt, "ShaderNodeOutputMaterial")
            base = pal["base"][index % len(pal["base"])]
            nt.links.new(_paint(nt, base, pal, params, uv_name, ao_image, curv_image, scale), out.inputs["Surface"])
            slot.material = temp
        yield temps
    finally:
        for slot, original in zip(obj.material_slots, originals):
            slot.material = original
        if appended:
            obj.data.materials.clear()
        for temp in temps:
            bpy.data.materials.remove(temp)


def _final_material(obj, albedo, roughness):
    name = "M_" + re.sub(r"^(SM|SK)_", "", bake._safe(obj.name)) + "_Stylized"
    mat = material(name)
    nt = mat.node_tree
    bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
        out = nt.get_output_node("CYCLES") or nt.nodes.new("ShaderNodeOutputMaterial")
        nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    tex = nt.nodes.get("forge_albedo") or nt.nodes.new("ShaderNodeTexImage")
    tex.name = "forge_albedo"
    image = bpy.data.images.load(str(albedo), check_existing=True)
    image.reload()
    tex.image = image
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = roughness
    if not obj.material_slots:
        obj.data.materials.append(mat)
    for slot in obj.material_slots:
        slot.material = mat
    return mat


def stylize(obj, out_dir, palette=None, recipe="stone", resolution=1024, maps=None):
    """Paint a hand-painted albedo for `obj` (object or name) and assign it as one simple material on every slot.

    Per slot: palette base colour (cycling through `base`), lit from world +Z (top brighter, underside shaded), and
    shade (AO plus underside) that darkens, turns hue toward `shadow`'s by up to 22 degrees and mixes 35% toward
    `shadow`, so shadows are tinted, not grey; cavity tint where curvature < 0.5; edge highlight (screen with
    `highlight`) where curvature > 0.5; optional brush-stroke noise stretched along the longest axis. The result is
    baked (Cycles EMIT) into `<out_dir>/<obj>_albedo.png` at `resolution` px.
    `recipe`: a key of RECIPES. `palette`: {"base": [rgb, ...], "shadow": rgb, "highlight": rgb}, sRGB 0-1, any key
    overriding the recipe's. `maps`: {"ao": png, "curvature": png} as bake_maps returns in `paths`; missing ones are
    baked into out_dir first. Returns the albedo path, material name, map paths, which maps it baked, seconds."""
    obj = get_object(obj, "MESH")
    if recipe not in RECIPES:
        raise ForgeError(f"unknown recipe {recipe!r}; choose from {sorted(RECIPES)}")
    params = RECIPES[recipe]
    pal = _palette(recipe, palette)
    if int(resolution) < 1:
        raise ForgeError("resolution must be >= 1")
    resolution = int(resolution)
    uv_name = bake._render_uv(obj)
    given = dict(maps or {})
    absent = [k for k in _NEEDED if k in given and not Path(given[k]).is_file()]
    if absent:
        raise ForgeError(f"map files not found: {[given[k] for k in absent]}")
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    start = time.perf_counter()
    missing = [k for k in _NEEDED if k not in given]
    map_paths = {k: str(given[k]) for k in _NEEDED if k in given}
    if missing:
        map_paths.update(bake.bake_maps(obj, out, maps=missing, resolution=resolution)["paths"])
    maps_seconds = time.perf_counter() - start
    albedo = out / f"{bake._safe(obj.name)}_albedo.png"
    scene = bpy.context.scene
    with ExitStack() as stack:
        stack.enter_context(bake._keep_selection())
        stack.enter_context(bake._cycles_session(scene, 16))
        loaded = {}
        for key in _NEEDED:
            image = bpy.data.images.load(map_paths[key], check_existing=False)
            stack.callback(bpy.data.images.remove, image)
            bake._enum(image.colorspace_settings, "name", "Non-Color")
            loaded[key] = image
        temps = stack.enter_context(_painted_slots(obj, pal, params, uv_name, loaded["ao"], loaded["curvature"]))
        target = bake._new_image("forge_albedo_bake", resolution, data=False, fill=(0.0, 0.0, 0.0, 1.0))
        stack.callback(bpy.data.images.remove, target)
        with bake._target_image(temps, target):
            bake._bake(obj, "EMIT", uv_name, margin=8)
        bake._save_png(target, albedo)
    mat = _final_material(obj, albedo, params["roughness"])
    return ok(object=obj.name, recipe=recipe, albedo=str(albedo), material=mat.name, maps=map_paths,
              baked_maps=missing, palette=pal, resolution=resolution,
              seconds={"maps": round(maps_seconds, 3), "albedo": round(time.perf_counter() - start - maps_seconds, 3)})
