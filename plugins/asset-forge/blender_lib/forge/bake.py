"""Bake texture maps of a mesh (or of a high-poly onto it) into PNG files with Cycles. Works live and in `blender -b`.
Distances are metres; resolutions are pixels per side. Every render setting touched is restored before returning."""
import colorsys
import math
import time
from contextlib import ExitStack
from pathlib import Path

import bpy

from .bakekit import (cycles_session, emission, keep_selection, new_image, node, render_uv, run_bake, safe_name,
                      save_png, slot_materials, surface, target_image, texel_size, to_linear)
from .util import ForgeError, get_object, ok, world_bbox

MAPS = ("normal", "ao", "curvature", "thickness", "id")
_FILL = {"normal": (0.5, 0.5, 1.0, 1.0), "ao": (1.0, 1.0, 1.0, 1.0), "curvature": (0.5, 0.5, 0.5, 1.0),
         "thickness": (1.0, 1.0, 1.0, 1.0), "id": (0.0, 0.0, 0.0, 1.0)}


def _id_srgb(index):
    return [round(v, 4) for v in colorsys.hsv_to_rgb((index * 0.618034) % 1.0, 0.7, 0.9)]


def _ao_shader(distance, inside=False):
    def build(nt, _index):
        ao = node(nt, "ShaderNodeAmbientOcclusion", {"Distance": distance}, only_local=True, inside=inside,
                   samples=16)
        return emission(nt, ao.outputs["AO"])
    return build


def _curvature_shader(radius, sign_distance):
    """0.5 flat, toward 1 on convex edges, toward 0 in concave ones: edge strength from how far a Bevel normal of
    `radius` turns from the surface normal (full at 30 degrees), sign from local AO (a concave edge occludes itself,
    a convex one does not)."""
    def build(nt, _index):
        geo = node(nt, "ShaderNodeNewGeometry")
        bevel = node(nt, "ShaderNodeBevel", {"Radius": radius}, samples=16)
        dot = node(nt, "ShaderNodeVectorMath", {"Vector": bevel.outputs["Normal"],
                                                 "Vector_001": geo.outputs["Normal"]}, operation="DOT_PRODUCT")
        edge = node(nt, "ShaderNodeMapRange", {"Value": dot.outputs["Value"], "From Min": 1.0,
                                                "From Max": math.cos(math.pi / 6), "To Min": 0.0, "To Max": 1.0})
        ao = node(nt, "ShaderNodeAmbientOcclusion", {"Distance": sign_distance}, only_local=True, samples=16)
        sign = node(nt, "ShaderNodeMapRange", {"Value": ao.outputs["AO"], "From Min": 0.75, "From Max": 0.95,
                                                "To Min": -1.0, "To Max": 1.0})
        signed = node(nt, "ShaderNodeMath", {"Value": edge.outputs["Result"], "Value_001": sign.outputs["Result"]},
                       operation="MULTIPLY")
        curv = node(nt, "ShaderNodeMapRange", {"Value": signed.outputs["Value"], "From Min": -1.0, "From Max": 1.0,
                                                "To Min": 0.0, "To Max": 1.0})
        return emission(nt, curv.outputs["Result"])
    return build


def _id_shader(nt, index):
    rgb = [to_linear(c) for c in _id_srgb(index)]
    return emission(nt, (*rgb, 1.0))


def bake_maps(low, out_dir, high=None, maps=MAPS, resolution=1024, extrusion=0.02, cage=None, samples=16,
              margin_px=8):
    """Bake `maps` of `low` (object or name) into `<out_dir>/<low>_<map>.png`, one image per map across all of its
    material slots, through a temporary image node per material (removed afterwards).

    normal: tangent space, OpenGL (+Y green); from `high` selected-to-active when given (rays start `extrusion`
      metres out, or from `cage`, which needs `high`), else the low's own shading normals, flat unless its materials
      carry bump/normal.
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
    if cage is not None and high is None:
        raise ForgeError("cage only applies to a high-to-low bake; pass high= or drop cage")
    wanted = list(dict.fromkeys([maps] if isinstance(maps, str) else maps))
    unknown = [m for m in wanted if m not in MAPS]
    if not wanted or unknown:
        raise ForgeError(f"unknown maps {unknown or wanted}; choose from {list(MAPS)}")
    if int(resolution) < 1 or int(samples) < 1 or int(margin_px) < 0 or extrusion < 0:
        raise ForgeError("resolution and samples must be >= 1, margin_px and extrusion >= 0")
    resolution = int(resolution)
    uv_name = render_uv(low)
    texel = texel_size(low, uv_name, resolution)
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
        stack.enter_context(keep_selection())
        device = stack.enter_context(cycles_session(scene, samples))
        low_mats = stack.enter_context(slot_materials(low))
        src_mats = stack.enter_context(slot_materials(high)) if high else low_mats
        unique = list(dict.fromkeys(src_mats))
        id_colors = [{"slot": i, "material": m.name, "srgb": _id_srgb(unique.index(m))} for i, m in enumerate(src_mats)]
        for name in wanted:
            start = time.perf_counter()
            image = new_image(f"forge_bake_{name}", resolution, data=name != "id", fill=_FILL[name])
            try:
                with ExitStack() as per_map:
                    if name != "normal":
                        per_map.enter_context(surface(src_mats, shaders[name]))
                    per_map.enter_context(target_image(low_mats, image))
                    run_bake(low, "NORMAL" if name == "normal" else "EMIT", uv_name, margin_px, source=high,
                             extrusion=extrusion, cage=cage)
                path = out / f"{safe_name(low.name)}_{name}.png"
                save_png(image, path)
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
