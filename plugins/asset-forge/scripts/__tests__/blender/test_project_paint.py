import math
from pathlib import Path

import bpy
import numpy as np
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

import fixtures
from forge import project_paint, util
from test_bake import _face_mask, _png

COLORS = {"front": (1.0, 0.0, 0.0), "back": (0.0, 0.0, 1.0), "left": (0.0, 1.0, 0.0), "right": (1.0, 0.0, 1.0),
          "top": (0.0, 1.0, 1.0)}


def _solid_png(path, rgb, size=48):
    image = bpy.data.images.new("solid", size, size, alpha=True)
    image.pixels.foreach_set(np.tile(np.array([*rgb, 1.0], np.float32), size * size))
    image.save(filepath=str(path))
    bpy.data.images.remove(image)
    return str(path)


def _view_images(cameras, tmp, colors):
    return {name: _solid_png(tmp / f"{bpy.data.objects[name]['forge_view']}.png",
                             colors[bpy.data.objects[name]["forge_view"]]) for name in cameras}


def test_setup_views_frames_the_object_from_blender_viewpoints():
    crate = fixtures.crate()
    scene = bpy.context.scene
    scene.render.resolution_x = scene.render.resolution_y = 128
    out = project_paint.setup_views(crate, resolution=128)
    assert len(out["cameras"]) == 5 and out["cameras"][0] == "forge_view_SM_Crate_front"
    lo, hi = util.world_bbox(crate)
    corners = [Vector((x, y, z)) for x in (lo.x, hi.x) for y in (lo.y, hi.y) for z in (lo.z, hi.z)]
    for name in out["cameras"]:
        cam = bpy.data.objects[name]
        assert cam.data.type == "ORTHO" and cam["forge_resolution"] == 128
        centre = world_to_camera_view(scene, cam, (lo + hi) / 2)
        assert abs(centre.x - 0.5) < 1e-4 and abs(centre.y - 0.5) < 1e-4
        for corner in corners:
            p = world_to_camera_view(scene, cam, corner)
            assert 0.03 < p.x < 0.97 and 0.03 < p.y < 0.97 and cam.data.clip_start < p.z < cam.data.clip_end
    front, top = bpy.data.objects[out["cameras"][0]], bpy.data.objects[out["cameras"][4]]
    assert front.matrix_world.translation.y < -1 and (front.matrix_world.col[1].xyz - Vector((0, 0, 1))).length < 1e-6
    assert top.matrix_world.translation.z > 1 and (top.matrix_world.col[0].xyz - Vector((1, 0, 0))).length < 1e-6
    count = len(bpy.data.objects)
    assert project_paint.setup_views(crate, resolution=128)["cameras"] == out["cameras"]
    assert len(bpy.data.objects) == count


def test_render_guides_isolate_the_object_and_restore_settings(tmp):
    crate = fixtures.crate()
    blocker = fixtures.rock_blockout("blocker", radius=0.3)
    blocker.location = (0, -1.2, 0.5)
    cams = project_paint.setup_views(crate, views=("front", "top"), resolution=64)["cameras"]
    scene = bpy.context.scene
    before = (scene.render.engine, scene.view_settings.view_transform, scene.render.film_transparent,
              scene.render.resolution_x, scene.render.filepath, scene.camera, scene.render.image_settings.color_mode)
    out = project_paint.render_guides(crate, tmp, cams)
    assert set(out["guides"]) == set(cams)
    for files in out["guides"].values():
        assert set(files) == {"normal", "depth", "ao"}
        assert all(Path(p).stat().st_size > 100 for p in files.values())
    front = out["guides"][cams[0]]
    normal, depth, ao = _png(front["normal"]), _png(front["depth"]), _png(front["ao"])
    assert normal.shape == (64, 64, 4)
    assert np.abs(normal[32, 32, :3] - (0.5, 0.5, 1.0)).max() < 0.03, normal[32, 32]
    assert depth[32, 32, 0] > 0.97 and normal[0, 0, 3] == 0 and depth[0, 0, 3] == 0
    assert ao[24:40, 24:40, 0].mean() > 0.9
    top_normal = _png(out["guides"][cams[1]]["normal"])
    assert np.abs(top_normal[32, 32, :3] - (0.5, 0.5, 1.0)).max() < 0.03
    near, far = out["depth_range_m"][cams[0]]
    assert 0 < near < far and math.isclose(far - near, 1.0, abs_tol=1e-4)
    assert blocker.hide_render is False and crate.hide_render is False
    assert before == (scene.render.engine, scene.view_settings.view_transform, scene.render.film_transparent,
                      scene.render.resolution_x, scene.render.filepath, scene.camera,
                      scene.render.image_settings.color_mode)
    assert not [m.name for m in bpy.data.materials if m.name.startswith("forge_")]


def test_project_and_bake_solid_views_land_on_their_faces_and_fill_every_texel(tmp):
    crate = fixtures.crate()
    cams = project_paint.setup_views(crate, resolution=48)["cameras"]
    out = project_paint.project_and_bake(crate, _view_images(cams, tmp, COLORS), tmp, resolution=128)
    assert Path(out["path"]).name == "SM_Crate_projected.png" and out["notes"]
    img = _png(out["path"])
    expect = {(0, -1, 0): 0, (0, 1, 0): 2, (-1, 0, 0): 1, (1, 0, 0): (0, 2), (0, 0, 1): (1, 2)}
    for poly in crate.data.polygons:
        key = tuple(round(c) for c in poly.normal)
        if key not in expect:
            continue
        texels = img[_face_mask(crate, poly, 128, shrink=0.2)][:, :3]
        channels = np.atleast_1d(expect[key])
        others = [c for c in range(3) if c not in channels]
        assert texels[:, channels].min() > 0.9 and texels[:, others].max() < 0.1, (key, texels.mean(0))
    assert (img[..., 3] == 1.0).all() and img[..., :3].max(axis=2).min() > 0.9
    assert out["texels_filled"] > 0 and out["texels_seen"] + out["texels_filled"] == out["texels_covered"]
    assert all(n > 0 for n in out["view_texels"].values())
    bottom = _face_mask(crate, next(p for p in crate.data.polygons if p.normal.z < -0.9), 128)
    assert out["texels_filled"] >= bottom.sum() and img[bottom][:, :3].max(axis=1).min() > 0.9


def test_seam_blend_cross_fades_views_by_facing_ratio(tmp):
    crate = fixtures.crate()
    crate.rotation_euler.z = math.radians(30)
    bpy.context.view_layer.update()
    cams = project_paint.setup_views(crate, views=("front", "right"), resolution=48)["cameras"]
    images = _view_images(cams, tmp, {"front": (1.0, 0.0, 0.0), "right": (0.0, 0.0, 1.0)})
    front = next(p for p in crate.data.polygons if p.normal.y < -0.9)
    mask = _face_mask(crate, front, 128, shrink=0.2)
    hard = _png(project_paint.project_and_bake(crate, images, tmp / "hard", 128, seam_blend=0.0)["path"])[mask]
    soft = _png(project_paint.project_and_bake(crate, images, tmp / "soft", 128, seam_blend=1.0)["path"])[mask]
    assert hard[:, 2].max() < 0.02 and hard[:, 0].min() > 0.98
    assert 0.2 < soft[:, 2].mean() < 0.4 and soft[:, 0].mean() > soft[:, 2].mean()


def test_project_paint_refuses_bad_input(tmp):
    crate = fixtures.crate()
    rock = fixtures.rock_blockout()
    cam = project_paint.setup_views(crate, views="front", resolution=16)["cameras"][0]
    png = _solid_png(tmp / "front.png", (1, 0, 0))
    cases = [(lambda: project_paint.setup_views(crate, views=("side",)), "unknown views"),
             (lambda: project_paint.setup_views(cam), "CAMERA"),
             (lambda: project_paint.render_guides(crate, tmp / "g", []), "no cameras"),
             (lambda: project_paint.render_guides(crate, tmp / "g", ["SM_Crate"]), "expected CAMERA"),
             (lambda: project_paint.project_and_bake(crate, {}, tmp / "p"), "non-empty"),
             (lambda: project_paint.project_and_bake(crate, {cam: str(tmp / "nope.png")}, tmp / "p"), "not found"),
             (lambda: project_paint.project_and_bake(crate, {"SM_Crate": png}, tmp / "p"), "expected CAMERA"),
             (lambda: project_paint.project_and_bake(rock, {cam: png}, tmp / "p"), "no UV map")]
    for call, words in cases:
        try:
            call()
        except util.ForgeError as exc:
            assert words in str(exc), (words, str(exc))
        else:
            raise AssertionError(f"accepted: {words}")
    assert sorted(p.name for p in tmp.iterdir()) == ["front.png"]
