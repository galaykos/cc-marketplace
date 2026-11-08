from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix

import fixtures
from forge import bake, util


def _png(path):
    image = bpy.data.images.load(str(path), check_existing=False)
    try:
        w, h = image.size
        buf = np.empty(w * h * 4, np.float32)
        image.pixels.foreach_get(buf)
        return buf.reshape(h, w, 4)
    finally:
        bpy.data.images.remove(image)


def _face_mask(obj, poly, res, shrink=0.0):
    """Texels whose centres fall inside the polygon's UV shape, scaled toward its centre by (1 - shrink)."""
    uv = obj.data.uv_layers.active.data
    pts = np.array([uv[i].uv[:] for i in poly.loop_indices])
    pts = pts.mean(0) + (pts - pts.mean(0)) * (1.0 - shrink)
    ys, xs = np.indices((res, res))
    p = np.stack([(xs + 0.5) / res, (ys + 0.5) / res], -1)

    def cross(a, b):
        return a[..., 0] * b[..., 1] - a[..., 1] * b[..., 0]

    inside = np.zeros((res, res), bool)
    for i in range(1, len(pts) - 1):
        a, b, c = pts[0], pts[i], pts[i + 1]
        d = [cross(b - a, p - a), cross(c - b, p - b), cross(a - c, p - c)]
        inside |= ((d[0] >= 0) & (d[1] >= 0) & (d[2] >= 0)) | ((d[0] <= 0) & (d[1] <= 0) & (d[2] <= 0))
    return inside


def _band(obj, poly, res, width=0.2):
    return _face_mask(obj, poly, res) & ~_face_mask(obj, poly, res, shrink=width)


def _tray(name="SM_Tray"):
    """A 1 m box with a 0.4 m deep recess in its top: convex rim edges and concave recess edges, smart-projected UVs."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    top = next(f for f in bm.faces if f.normal.z > 0.9)
    bmesh.ops.inset_individual(bm, faces=[top], thickness=0.25)
    ext = bmesh.ops.extrude_face_region(bm, geom=[top])
    bmesh.ops.translate(bm, verts=[e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)], vec=(0, 0, -0.4))
    bmesh.ops.delete(bm, geom=[top], context="FACES_ONLY")
    bm.normal_update()
    obj = util.new_mesh_object(name, bm)
    bm.free()
    util.select_only(obj)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")
    return obj


def _rna_values(struct):
    return {p.identifier: getattr(struct, p.identifier) for p in struct.bl_rna.properties
            if p.type not in ("POINTER", "COLLECTION") and p.identifier != "rna_type"}


def test_bake_all_maps_on_crate_measures_and_restores(tmp):
    crate = fixtures.crate()
    scene = bpy.context.scene
    engine, bake_settings, cycles = scene.render.engine, _rna_values(scene.render.bake), _rna_values(scene.cycles)
    nodes = len(crate.data.materials[0].node_tree.nodes)
    counts = (len(bpy.data.images), len(bpy.data.materials))
    out = bake.bake_maps(crate, tmp / "maps", resolution=128, samples=8)
    assert set(out["paths"]) == set(bake.MAPS) == set(out["seconds"])
    assert out["device"] in ("CPU", "GPU") and out["high"] is None
    for name, path in out["paths"].items():
        assert Path(path).name == f"SM_Crate_{name}.png" and Path(path).stat().st_size > 100, path
    polys = list(crate.data.polygons)
    centres = np.any([_face_mask(crate, p, 128, shrink=0.5) for p in polys], axis=0)
    normal = _png(out["paths"]["normal"])[..., :3]
    assert np.abs(normal[centres].mean(0) - (0.5, 0.5, 1.0)).max() < 0.02, normal[centres].mean(0)
    ao = _png(out["paths"]["ao"])[..., 0]
    assert ao[centres].mean() > 0.95, ao[centres].mean()
    curv = _png(out["paths"]["curvature"])[..., 0]
    assert abs(curv[centres].mean() - 0.5) < 0.03, curv[centres].mean()
    for poly in polys:
        assert curv[_band(crate, poly, 128)].mean() > curv[_face_mask(crate, poly, 128, shrink=0.5)].mean() + 0.05
    ids = _png(out["paths"]["id"])[..., :3]
    assert np.abs(ids[centres] - out["id_colors"][0]["srgb"]).max() < 2 / 255
    assert scene.render.engine == engine and _rna_values(scene.render.bake) == bake_settings
    assert _rna_values(scene.cycles) == cycles
    assert len(crate.data.materials[0].node_tree.nodes) == nodes
    assert (len(bpy.data.images), len(bpy.data.materials)) == counts


def test_thickness_is_dark_on_a_thin_slab_and_bright_on_a_block(tmp):
    measured = {}
    for name, height in (("SM_Block", 1.0), ("SM_Slab", 0.05)):
        obj = fixtures.crate(name)
        obj.data.transform(Matrix.Diagonal((1.0, 1.0, height, 1.0)))
        out = bake.bake_maps(obj, tmp, maps="thickness", resolution=128)
        broad = [p for p in obj.data.polygons if abs(p.normal.z) > 0.9]
        mask = np.any([_face_mask(obj, p, 128, shrink=0.5) for p in broad], axis=0)
        measured[name] = _png(out["paths"]["thickness"])[..., 0][mask].mean()
    assert measured["SM_Slab"] < 0.1 and measured["SM_Block"] > 0.3, measured


def test_curvature_is_signed_convex_rim_bright_concave_recess_dark(tmp):
    tray = _tray()
    out = bake.bake_maps(tray, tmp, maps=["curvature"], resolution=256)
    curv = _png(out["paths"]["curvature"])[..., 0]
    up = [p for p in tray.data.polygons if p.normal.z > 0.9]
    floor = next(p for p in up if p.center.z < 0.2)
    rim = [p for p in up if p.center.z > 0.4]
    floor_band, floor_mid = curv[_band(tray, floor, 256)].mean(), curv[_face_mask(tray, floor, 256, 0.5)].mean()
    assert floor_band < floor_mid - 0.015 and floor_band < 0.49, (floor_band, floor_mid)
    rim_band = np.mean([curv[_band(tray, p, 256)].mean() for p in rim])
    assert rim_band > 0.52, rim_band
    assert curv[_face_mask(tray, floor, 256, 0.5)].min() > 0.45


def test_high_to_low_normal_carries_the_high_shape(tmp):
    low = fixtures.crate()
    high = fixtures.crate("SM_Crate_high")
    high.data.shade_smooth()
    mod = high.modifiers.new("Subdivision", "SUBSURF")
    mod.levels = mod.render_levels = 3
    out = bake.bake_maps(low, tmp, high=high, maps=("normal", "ao"), resolution=128, extrusion=0.05)
    assert out["high"] == high.name
    normal = _png(out["paths"]["normal"])[..., :3]
    faces = np.any([_face_mask(low, p, 128, shrink=0.1) for p in low.data.polygons], axis=0)
    tilted = np.abs(normal[faces] - (0.5, 0.5, 1.0)).max(axis=1) > 0.1
    assert tilted.mean() > 0.2, tilted.mean()
    assert high.select_get() is False and low.select_get() is False


def test_id_map_separates_slots_and_slotless_object_is_left_slotless(tmp):
    crate = fixtures.crate()
    crate.data.materials.append(bpy.data.materials.new("M_Lid"))
    top = next(p for p in crate.data.polygons if p.normal.z > 0.9)
    side = next(p for p in crate.data.polygons if p.normal.x > 0.9)
    top.material_index = 1
    out = bake.bake_maps(crate, tmp, maps="id", resolution=64)
    colors = {c["material"]: c["srgb"] for c in out["id_colors"]}
    assert set(colors) == {"M_Crate", "M_Lid"} and colors["M_Crate"] != colors["M_Lid"]
    ids = _png(out["paths"]["id"])[..., :3]
    assert np.abs(ids[_face_mask(crate, top, 64, 0.5)] - colors["M_Lid"]).max() < 2 / 255
    assert np.abs(ids[_face_mask(crate, side, 64, 0.5)] - colors["M_Crate"]).max() < 2 / 255
    bare = fixtures.crate("SM_Bare")
    bare.data.materials.clear()
    out = bake.bake_maps(bare, tmp, maps=("ao",), resolution=32)
    assert Path(out["paths"]["ao"]).is_file() and len(bare.material_slots) == 0
    assert not [m.name for m in bpy.data.materials if m.name.startswith("forge_")]


def test_bake_refuses_bad_input(tmp):
    crate = fixtures.crate()
    rock = fixtures.rock_blockout()
    stacked = fixtures.bad_asset()
    cases = [(lambda: bake.bake_maps(rock, tmp), "no UV map"),
             (lambda: bake.bake_maps(stacked, tmp), "zero area"),
             (lambda: bake.bake_maps(crate, tmp, maps=("albedo",)), "unknown maps"),
             (lambda: bake.bake_maps(crate, tmp, high=crate), "same object"),
             (lambda: bake.bake_maps(crate, tmp, cage=rock), "pass high="),
             (lambda: bake.bake_maps(crate, tmp, resolution=0), "resolution"),
             (lambda: bake.bake_maps("SM_Missing", tmp), "no object")]
    for call, words in cases:
        try:
            call()
        except util.ForgeError as exc:
            assert words in str(exc), (words, str(exc))
        else:
            raise AssertionError(f"accepted: {words}")
    assert not list(tmp.iterdir())
