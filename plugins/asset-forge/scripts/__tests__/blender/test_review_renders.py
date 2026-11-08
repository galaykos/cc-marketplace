import math
import types
from pathlib import Path

import bmesh
import bpy
import numpy as np

import fixtures
from forge import review_renders, util

DATA = ("objects", "meshes", "materials", "images", "cameras", "lights", "worlds", "scenes", "collections",
        "node_groups", "textures")
PERSPECTIVE = {"type": "perspective", "distance_m": 6, "fov_deg": 60, "screen_height_px": 1080, "elevation_deg": 30}


def _counts():
    return {k: len(getattr(bpy.data, k)) for k in DATA}


def _load(path):
    image = bpy.data.images.load(str(path), check_existing=False)
    width, height = image.size
    pixels = np.empty(width * height * 4, np.float32)
    image.pixels.foreach_get(pixels)
    bpy.data.images.remove(image)
    return pixels.reshape(height, width, 4)[::-1]


def _object_mask(pixels):
    return np.abs(pixels[..., :3] - pixels[0, 0, :3]).max(axis=-1) > 0.02


def _user_render_state(scene):
    r = scene.render
    return (r.engine, r.resolution_x, r.resolution_y, r.resolution_percentage, r.filepath,
            scene.view_settings.view_transform, scene.camera, scene.world, scene.display.shading.light)


def test_full_set_on_crate_renders_every_kind_and_leaves_the_scene_alone(tmp):
    crate = fixtures.crate()
    user = bpy.context.scene
    before, render_before = _counts(), _user_render_state(user)
    crate_before = (crate.users, crate.data.users, [c.name for c in crate.users_collection], crate.matrix_world.copy())
    out = review_renders.render_review_set("SM_Crate", tmp / "review", game_camera=PERSPECTIVE)
    print(f"  full review set on the crate at 512 px: {out['seconds']} s")
    assert {k: len(v) for k, v in out["images"].items()} == {
        "beauty": 8, "silhouette": 3, "game_distance": 1, "wireframe": 2, "uv_checker": 2, "matcap": 2}
    assert len(out["layout"]) == 18 and out["layout"][0] == ["beauty", "az000"] and out["layout"][7] == ["beauty", "az315"]
    paths = [p for kind in review_renders.KINDS for p in out["images"][kind]]
    for path in paths:
        assert Path(path).stat().st_size > 0 and _load(path).shape == (512, 512, 4)

    columns, step = out["columns"], 512 + review_renders.GAP_PX
    sheet = _load(out["contact_sheet"])
    assert columns == 5 and sheet.shape == (4 * step - review_renders.GAP_PX, 5 * step - review_renders.GAP_PX, 4)
    for i in (0, 9, 17):
        row, col = divmod(i, columns)
        assert np.array_equal(sheet[row * step:row * step + 512, col * step:col * step + 512], _load(paths[i]))

    front = _load(out["images"]["silhouette"][0])
    black = front[..., 0] < 0.05
    rows, cols = np.nonzero(black)
    width, height = cols.max() - cols.min() + 1, rows.max() - rows.min() + 1
    assert front[0, 0, 0] == 1.0 and 0.05 < black.mean() < 0.6 and abs(width / height - 1) < 0.03

    for kind in ("beauty", "wireframe", "uv_checker", "matcap"):
        assert 0.05 < _object_mask(_load(out["images"][kind][0])).mean() < 0.8, kind
    wire = _load(out["images"]["wireframe"][0])
    assert (wire[..., :3].max(axis=-1) < 0.1).sum() > 300
    checker = _load(out["images"]["uv_checker"][0])
    assert ((checker[..., :3].max(axis=-1) - checker[..., :3].min(axis=-1)) > 0.2).sum() > 1000

    game = out["game_distance"]
    raw, tile = _load(game["raw"]), _load(out["images"]["game_distance"][0])
    assert 200 < game["screen_px_height"] < 300 and raw.shape[:2] == (game["render_px"], game["render_px"])
    index = np.arange(512) * game["render_px"] // 512
    assert np.array_equal(tile, raw[index][:, index])
    assert abs(_object_mask(raw).any(axis=1).sum() - game["screen_px_height"]) <= 3

    assert _counts() == before and _user_render_state(user) == render_before and bpy.context.scene == user
    assert (crate.users, crate.data.users, [c.name for c in crate.users_collection]) == crate_before[:3]
    assert crate.matrix_world == crate_before[3]


def test_game_distance_ortho_and_top_down_match_the_projection(tmp):
    fixtures.crate()
    for elevation, expected_px in ((45, 1.7071 * 54), (90, math.sqrt(2) * 54)):
        camera = {"type": "ortho", "ortho_height_m": 20, "screen_height_px": 1080, "elevation_deg": elevation}
        out = review_renders.render_review_set("SM_Crate", tmp / f"el{elevation}", include=("game_distance",),
                                               game_camera=camera, tile_px=256)
        game = out["game_distance"]
        # whole pixel rows: a faintly covered row at the top and at the bottom both count, a sub-threshold one does not
        assert -1 <= game["screen_px_height"] - expected_px <= 2, (elevation, game)
        raw = _load(game["raw"])
        assert abs(_object_mask(raw).any(axis=1).sum() - expected_px) <= 3, elevation
        assert out["layout"] == [["game_distance", "game_camera"]] and any("azimuth" in n for n in out["notes"])


def test_game_distance_height_is_the_object_not_its_bounding_box(tmp):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=4, radius=0.5)
    util.new_mesh_object("SM_Ball", bm)
    bm.free()
    camera = {"type": "ortho", "ortho_height_m": 20, "screen_height_px": 1080, "elevation_deg": 30, "azimuth_deg": 45}
    out = review_renders.render_review_set("SM_Ball", tmp, include=("game_distance",), game_camera=camera, tile_px=256)
    game = out["game_distance"]
    print(f"  1 m ball at 54 px/m: screen_px_height {game['screen_px_height']}")
    assert abs(game["screen_px_height"] - 54) <= 2, game


def test_engine_discovery_does_not_need_the_refusal_wording(tmp):
    fixtures.crate()
    real = review_renders.re
    review_renders.re = types.SimpleNamespace(findall=lambda *args: [])
    try:
        ids = review_renders._engine_ids(bpy.context.scene.render)
        out = review_renders.render_review_set("SM_Crate", tmp, include=("silhouette", "beauty"), angles=1, tile_px=64)
    finally:
        review_renders.re = real
    assert "BLENDER_WORKBENCH" in ids and any("EEVEE" in i for i in ids), ids
    assert list(out["images"]) == ["beauty", "silhouette"]


def test_game_distance_far_away_renders_at_the_eight_pixel_floor(tmp):
    fixtures.crate()
    far = dict(PERSPECTIVE, distance_m=300)
    out = review_renders.render_review_set("SM_Crate", tmp, include=("game_distance",), game_camera=far, tile_px=128)
    game = out["game_distance"]
    assert game["screen_px_height"] < 8 and game["render_px"] == review_renders.MIN_GAME_PX
    assert _load(game["raw"]).shape[:2] == (8, 8) and _object_mask(_load(game["raw"])).any()


def test_skips_are_noted_not_raised(tmp):
    fixtures.rock_blockout()
    before = _counts()
    out = review_renders.render_review_set("SM_Rock", tmp, include=("silhouette", "game_distance", "uv_checker"),
                                           tile_px=128)
    assert list(out["images"]) == ["silhouette"] and len(out["layout"]) == 3
    assert any(n.startswith("game_distance skipped") for n in out["notes"])
    assert any(n.startswith("uv_checker skipped") for n in out["notes"])
    assert _counts() == before


def test_skinned_mesh_renders_with_its_armature_parent(tmp):
    rig, mesh, _ = fixtures.humanoid()
    before, rig_scenes = _counts(), list(rig.users_scene)
    out = review_renders.render_review_set(mesh, tmp, include=("silhouette",), tile_px=128)
    front = _load(out["images"]["silhouette"][0])
    rows, cols = np.nonzero(front[..., 0] < 0.05)
    assert (cols.max() - cols.min()) > (rows.max() - rows.min()) * 0.6
    assert _counts() == before and list(rig.users_scene) == rig_scenes


def test_refusals_leave_nothing_behind(tmp):
    fixtures.crate()
    empty = bpy.data.objects.new("Empty", None)
    bpy.context.scene.collection.objects.link(empty)
    before = _counts()
    bad_calls = [
        dict(obj="Empty"),
        dict(obj="SM_Crate", include=("beauty", "xray")),
        dict(obj="SM_Crate", angles=0),
        dict(obj="SM_Crate", game_camera={"type": "fisheye"}),
        dict(obj="SM_Crate", game_camera={"type": "perspective", "distance_m": 6, "fov_deg": 60}),
        dict(obj="SM_Crate", game_camera=dict(PERSPECTIVE, distance_m=0.5)),
    ]
    for kwargs in bad_calls:
        try:
            review_renders.render_review_set(out_dir=tmp / "never", **kwargs)
        except util.ForgeError:
            pass
        else:
            raise AssertionError(f"accepted {kwargs}")
    assert _counts() == before and not (tmp / "never").exists()
