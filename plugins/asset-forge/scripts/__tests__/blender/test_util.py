import math

import bpy
from mathutils import Matrix, Vector

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


def _evaluated_world(obj):
    bpy.context.view_layer.update()
    eval_obj = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    points = [obj.matrix_world @ v.co for v in eval_obj.to_mesh().vertices]
    eval_obj.to_mesh_clear()
    return points


def _max_gap(a, b):
    return max((p - q).length for p, q in zip(a, b))


def _matrix_gap(a, b):
    return max(abs(x - y) for ra, rb in zip(a, b) for x, y in zip(ra, rb))


def test_apply_transforms_keeps_world_shape_and_children():
    obj = fixtures.crate()
    child = fixtures.rock_blockout("child")
    child.parent = obj
    child.location = (0.5, 0, 1)
    bpy.context.view_layer.update()
    obj.location = (1, 2, 3)
    obj.rotation_euler = (0, 0, math.radians(30))
    obj.scale = (2, 1, 0.5)
    parent_world = Matrix.LocRotScale(obj.location, obj.rotation_euler, obj.scale)
    before = [parent_world @ v.co for v in obj.data.vertices]
    child_expected = parent_world @ child.matrix_parent_inverse @ child.matrix_basis
    out = util.apply_transforms(obj)
    bpy.context.view_layer.update()
    after = [obj.matrix_world @ v.co for v in obj.data.vertices]
    assert out["baked"] == ["scale", "rotation"]
    assert _max_gap(before, after) < 1e-5
    assert tuple(obj.scale) == (1, 1, 1) and Vector(obj.location) == Vector((1, 2, 3))
    assert _matrix_gap(child.matrix_world, child_expected) < 1e-5, (child.matrix_world, child_expected)


def test_apply_transforms_bakes_shape_keys():
    for scale in ((2, 1, 0.5), (-2, 1, 0.5)):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        obj = fixtures.crate()
        obj.shape_key_add(name="Basis")
        lid = obj.shape_key_add(name="Lid", from_mix=False)
        for point in lid.data:
            if point.co.z > 0.5:
                point.co.z += 0.3
        lid.value = 0.7
        obj.rotation_euler = (0, 0, math.radians(30))
        obj.scale = scale
        before = _evaluated_world(obj)
        assert max(p.z for p in before) > 0.5 + 0.2 * 0.5, "the shape key does not show in the evaluated mesh"
        util.apply_transforms(obj)
        assert _max_gap(before, _evaluated_world(obj)) < 1e-5, scale
        assert tuple(obj.scale) == (1, 1, 1)


def test_apply_transforms_leaves_edit_mode_first():
    obj = fixtures.crate()
    obj.scale = (2, 2, 2)
    before = _evaluated_world(obj)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    util.apply_transforms(obj)
    assert obj.mode == "OBJECT"
    assert tuple(obj.scale) == (1, 1, 1) and _max_gap(before, _evaluated_world(obj)) < 1e-5


def test_positive_returns_a_float_and_refuses_the_rest():
    assert util.positive(3, "size") == 3.0 and isinstance(util.positive(3, "size"), float)
    assert util.positive(0.25, "size") == 0.25
    for bad in (0, -1, "2", None, True, float("nan")):
        try:
            util.positive(bad, "voxel_size")
        except util.ForgeError as exc:
            assert str(exc) == f"voxel_size must be a number > 0, got {bad!r}", str(exc)
        else:
            raise AssertionError(f"accepted {bad!r}")


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
