import math

import bpy
from mathutils import Vector

import fixtures
from forge import util


def test_fixtures_build():
    crate = fixtures.crate()
    assert util.tri_count(crate) == 12
    lo, hi = util.world_bbox(crate)
    assert abs(lo.z) < 1e-6 and abs(hi.z - 1.0) < 1e-6
    bad = fixtures.bad_asset()
    assert len(bad.data.materials) == 5 and tuple(bad.scale) == (2.0, 1.0, 1.0)
    target, mesh, source = fixtures.humanoid()
    assert len(target.data.bones) == len(fixtures.SKELETON) == len(source.data.bones)
    assert source.animation_data.action is not None
    assert mesh.vertex_groups[0].name == target.data.bones[0].name


def test_apply_transforms_keeps_world_shape_and_children():
    obj = fixtures.crate()
    obj.location = (1, 2, 3)
    obj.rotation_euler = (0, 0, math.radians(30))
    obj.scale = (2, 1, 0.5)
    child = fixtures.rock_blockout("child")
    child.parent = obj
    bpy.context.view_layer.update()
    before = [obj.matrix_world @ v.co for v in obj.data.vertices]
    child_before = child.matrix_world.copy()
    out = util.apply_transforms(obj)
    bpy.context.view_layer.update()
    after = [obj.matrix_world @ v.co for v in obj.data.vertices]
    assert out["baked"] == ["scale", "rotation"]
    assert max((a - b).length for a, b in zip(before, after)) < 1e-5
    assert tuple(obj.scale) == (1, 1, 1) and Vector(obj.location) == Vector((1, 2, 3))
    assert (child.matrix_world.translation - child_before.translation).length < 1e-5


def test_apply_transforms_refuses_rotation_without_scale_and_shared_mesh():
    obj = fixtures.crate()
    for kwargs in ({"rotation": True, "scale": False}, {"location": True, "rotation": False}):
        try:
            util.apply_transforms(obj, **kwargs)
        except util.ForgeError:
            pass
        else:
            raise AssertionError(f"accepted {kwargs}")
    twin = obj.copy()
    bpy.context.scene.collection.objects.link(twin)
    try:
        util.apply_transforms(obj)
    except util.ForgeError as exc:
        assert "shared" in str(exc)
    else:
        raise AssertionError("baked into a shared mesh")


def test_presets_load_and_unknown_preset_names_the_known():
    assert util.load_preset("engines", "unity")["format"] == "fbx"
    assert util.load_preset("budgets", "mobile")["lod_ratios"][0] == 1.0
    try:
        util.load_preset("engines", "frostbite")
    except util.ForgeError as exc:
        assert "unity" in str(exc)
    else:
        raise AssertionError("unknown preset accepted")


def test_settable_enum_probes_without_changing_value():
    render = bpy.context.scene.render
    before = render.engine
    assert util.settable_enum(render, "engine", ["NOT_AN_ENGINE", "CYCLES"]) == "CYCLES"
    assert render.engine == before


def test_apply_transforms_mirror_keeps_normals_outward():
    obj = fixtures.crate()
    obj.scale = (-1, 1, 1)
    util.apply_transforms(obj)
    volume = sum(p.normal.dot(obj.data.vertices[p.vertices[0]].co) * p.area for p in obj.data.polygons) / 3
    assert volume > 0.99, volume
