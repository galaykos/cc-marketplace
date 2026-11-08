import itertools

import bmesh
import bpy
import numpy as np

import fixtures
from forge import uv
from forge.util import ForgeError


def _refused(fn, *args, **kwargs):
    try:
        fn(*args, **kwargs)
    except ForgeError as exc:
        return str(exc)
    raise AssertionError(f"{fn.__name__}{args}{kwargs} was accepted")


def _plane(name="Plane", half=1.0):
    bm = bmesh.new()
    bm.loops.layers.uv.new("UVMap")
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=half, calc_uvs=True)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def _island_boxes(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    layer = bm.loops.layers.uv.active
    boxes = []
    for face in bm.faces:
        pts = np.array([tuple(l[layer].uv) for l in face.loops])
        boxes.append((*pts.min(axis=0), *pts.max(axis=0)))
    bm.free()
    return boxes


def test_smart_project_runs_headless_and_restores_context():
    rock = fixtures.rock_blockout()
    other = fixtures.crate()
    view_layer = bpy.context.view_layer
    other.select_set(True)
    view_layer.objects.active = other
    tool_settings = bpy.context.scene.tool_settings
    tool_settings.use_uv_select_sync = False
    rock.data.polygons[0].select = False
    rock.data.polygons[1].select = True
    out = uv.smart_project(rock.name, angle_deg=66.0, margin=0.02)
    assert bpy.app.background
    assert rock.data.uv_layers.active is not None
    assert out["islands"] > 1 and out["in_0_1"]
    lo_u, lo_v, hi_u, hi_v = out["uv_bounds"]
    assert min(lo_u, lo_v) >= 0.02 - 1e-4 and max(hi_u, hi_v) <= 1.0
    assert rock.mode == "OBJECT"
    assert view_layer.objects.active == other and other.select_get() and not rock.select_get()
    assert tool_settings.use_uv_select_sync is False
    assert rock.data.polygons[0].select is False and rock.data.polygons[1].select is True


def test_seams_from_sharp_then_unwrap_honours_them():
    crate = fixtures.crate()
    assert uv.unwrap(crate)["islands"] == 1
    out = uv.seams_from_sharp(crate, angle_deg=30.0)
    assert (out["seams_added"], out["from_angle"], out["seams_total"]) == (12, 12, 12)
    assert uv.seams_from_sharp(crate)["seams_added"] == 0
    wrapped = uv.unwrap(crate, method="ANGLE_BASED")
    assert wrapped["method"] == "ANGLE_BASED" and wrapped["seams"] == 12 and wrapped["islands"] == 6
    plane = _plane()
    bm = bmesh.new()
    bm.from_mesh(plane.data)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=1, use_grid_fill=True)
    next(e for e in bm.edges if len(e.link_faces) == 2).smooth = False
    bm.to_mesh(plane.data)
    bm.free()
    flat = uv.seams_from_sharp(plane, angle_deg=30.0)
    assert (flat["seams_added"], flat["from_sharp"], flat["from_angle"]) == (1, 1, 0)


def test_pack_leaves_the_pixel_margin():
    crate = fixtures.crate()
    uv.seams_from_sharp(crate)
    uv.unwrap(crate)
    out = uv.pack(crate, margin_px=8, texture_px=512)
    margin = 8 / 512
    assert out["margin_uv"] == round(margin, 6) and out["islands"] == 6 and out["in_0_1"]
    assert min(out["uv_bounds"][:2]) >= margin - 1e-4
    boxes = _island_boxes(crate)
    gaps = [max(b[0] - a[2], a[0] - b[2], b[1] - a[3], a[1] - b[3]) for a, b in itertools.combinations(boxes, 2)]
    assert min(gaps) >= margin - 1e-4, min(gaps)


def test_texel_density_is_measured_in_world_space_and_set():
    plane = _plane(half=1.0)
    assert abs(uv.texel_density(plane, 1024)["px_per_m"] - 512) < 1e-3
    plane.scale = (2, 2, 1)
    assert abs(uv.texel_density(plane, 1024)["px_per_m"] - 256) < 1e-3
    plane.scale = (1, 1, 1)
    down = uv.set_texel_density(plane, 128, 1024)
    assert abs(down["after_px_per_m"] - 128) < 1e-3 and down["in_0_1"] and down["advice"] is None
    assert abs(down["uv_extent"] - 0.25) < 1e-6
    up = uv.set_texel_density(plane, 2048, 1024)
    assert abs(up["after_px_per_m"] - 2048) < 1e-2
    assert not up["in_0_1"] and abs(up["uv_extent"] - 4.0) < 1e-5 and "4096 px" in up["advice"]


def test_checker_material_overrides_slots_and_keeps_mesh_materials():
    crate = fixtures.crate()
    out = uv.checker_material(crate, texture_px=256)
    image = bpy.data.images[out["image"]]
    assert out["pattern"] == "UV_GRID" and tuple(image.size) == (256, 256)
    assert crate.material_slots[0].link == "OBJECT" and crate.active_material.name == out["material"]
    assert crate.data.materials[0].name == "M_Crate"
    counts = (len(bpy.data.materials), len(bpy.data.images))
    uv.checker_material(crate, texture_px=256)
    assert (len(bpy.data.materials), len(bpy.data.images)) == counts
    rock = fixtures.rock_blockout()
    assert uv.checker_material(rock)["slots_overridden"] == 0 and rock.data.materials[0].name.startswith("FORGE_")


def test_refusals():
    crate = fixtures.crate()
    rock = fixtures.rock_blockout()
    assert "offered" in _refused(uv.unwrap, crate, method="NOT_A_METHOD")
    _refused(uv.smart_project, crate, angle_deg=0)
    _refused(uv.smart_project, crate, angle_deg=120)
    assert "no UV map" in _refused(uv.pack, rock)
    assert "no UV map" in _refused(uv.texel_density, rock, 1024)
    _refused(uv.set_texel_density, crate, 0, 1024)
    _refused(uv.seams_from_sharp, crate, angle_deg=0)
    _refused(uv.checker_material, crate, texture_px=0)
    empty = bpy.data.objects.new("Empty", None)
    bpy.context.scene.collection.objects.link(empty)
    assert "expected MESH" in _refused(uv.smart_project, empty)
    stacked = fixtures.bad_asset()
    assert "no area" in _refused(uv.set_texel_density, stacked, 512, 1024)
    unlinked = bpy.data.objects.new("Unlinked", crate.data.copy())
    assert "View Layer" in _refused(uv.unwrap, unlinked)
