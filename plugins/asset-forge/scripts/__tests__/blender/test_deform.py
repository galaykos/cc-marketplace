import math

import bmesh
import bpy
import numpy as np
from mathutils import Euler, Matrix, Vector

from forge import deform
from forge.util import ForgeError


def _object(name, bm):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def _grid(name="Grid", half=1.0, n=40):
    """A flat n x n quad grid on z = 0 spanning [-half, half] in x and y, normals +Z."""
    bm = bmesh.new()
    step = 2 * half / n
    rows = [[bm.verts.new((-half + i * step, -half + j * step, 0.0)) for i in range(n + 1)] for j in range(n + 1)]
    for j in range(n):
        for i in range(n):
            bm.faces.new((rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i]))
    return _object(name, bm)


def _sphere(name="Ball", radius=1.0):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=48, v_segments=24, radius=radius)
    return _object(name, bm)


def _local(obj):
    co = np.empty(len(obj.data.vertices) * 3)
    obj.data.vertices.foreach_get("co", co)
    return co.reshape(-1, 3)


def _world(obj):
    m = np.array(obj.matrix_world)
    return _local(obj) @ m[:3, :3].T + m[:3, 3]


def _refuses(fn, *args, stage=None, **kwargs):
    try:
        fn(*args, **kwargs)
    except ForgeError as exc:
        if stage is not None:
            assert exc.stage == stage, exc.stage
        return str(exc)
    raise AssertionError(f"{fn.__name__} accepted {args} {kwargs}")


def test_verts_outside_radius_never_move_in_world_space():
    obj = _sphere()
    obj.location = (3.0, -1.0, 2.0)
    obj.rotation_euler = Euler((0.3, 0.2, 1.1))
    obj.scale = (2.0, 2.0, 2.0)
    world = Matrix.LocRotScale(obj.location, obj.rotation_euler, obj.scale)
    center, radius = np.array(world @ Vector((0.0, -1.0, 0.0))), 0.9
    before_local = _local(obj)
    before_world = before_local @ np.array(world)[:3, :3].T + np.array(world)[:3, 3]
    out = deform.grab(obj, center, radius, (0.0, 0.0, 0.5), falloff="constant")
    after = _local(obj)
    outside = np.linalg.norm(before_world - center, axis=1) >= radius
    assert outside.sum() > 1000 and (~outside).sum() > 20
    assert np.array_equal(after[outside], before_local[outside])
    moved = np.any(after != before_local, axis=1)
    assert out["verts_moved"] == moved.sum() == (~outside).sum()
    assert abs(out["max_displacement"] - 0.5) < 1e-6
    shift = _world(obj)[~outside] - before_world[~outside]
    assert np.allclose(shift, [0.0, 0.0, 0.5], atol=1e-5)


def _mirror_error(obj, before, axis):
    """Max difference between each vertex's local displacement and its mirror partner's, mirrored. Measuring
    displacements, not positions, keeps the UV sphere's own float32 asymmetry (about 1.4e-6) out of the result."""
    moved = _local(obj) - before
    flip = np.ones(3)
    flip[axis] = -1.0
    partner = np.array([np.argmin(np.linalg.norm(before - p * flip, axis=1)) for p in before])
    assert np.linalg.norm(before[partner] - before * flip, axis=1).max() < 1e-5
    return np.linalg.norm(moved[partner] - moved * flip, axis=1).max()


def test_symmetry_mirrors_about_the_local_plane():
    obj = _sphere()
    obj.location = (1.0, 2.0, 0.5)
    obj.rotation_euler = Euler((0.0, 0.0, 0.7))
    bpy.context.view_layer.update()
    before = _local(obj)
    center = np.array(obj.matrix_world @ Vector((0.6, 0.5, 0.5)))
    out = deform.grab(obj, center, 0.7, (0.2, -0.1, 0.3), symmetry="X")
    assert out["verts_moved"] > 40
    assert _mirror_error(obj, before, 0) < 1e-6
    deform.inflate(obj, center, 0.5, 0.1, symmetry="X")
    deform.crease_along_curve(obj, [obj.matrix_world @ Vector(p) for p in ((0.7, -0.7, 0.0), (0.7, 0.7, 0.2))], 0.2,
                              0.05, symmetry="X")
    assert _mirror_error(obj, before, 0) < 1e-6
    lone = _sphere("Lone")
    deform.grab(lone, (0.6, 0.5, 0.5), 0.7, (0.2, -0.1, 0.3))
    assert _mirror_error(lone, before, 0) > 0.05


def test_mask_weight_zero_blocks_motion():
    obj = _grid()
    group = obj.vertex_groups.new(name="paint")
    left = [v.index for v in obj.data.vertices if v.co.x < 0]
    right = [v.index for v in obj.data.vertices if v.co.x >= 0]
    group.add(left, 0.0, "REPLACE")
    group.add(right, 1.0, "REPLACE")
    before = _local(obj)
    out = deform.inflate(obj, (0, 0, 0), 0.8, 0.2, falloff="constant", mask="paint")
    after = _local(obj)
    assert np.array_equal(after[left], before[left])
    inside_right = [i for i in right if np.linalg.norm(before[i]) < 0.8]
    assert out["verts_moved"] == len(inside_right) > 50
    assert np.allclose(after[inside_right, 2], 0.2, atol=1e-6)
    assert "no vertex group" in _refuses(deform.inflate, obj, (0, 0, 0), 0.8, 0.2, mask="nope")


def test_falloff_ordering_at_half_radius():
    measured = {}
    for falloff in deform.FALLOFFS:
        obj = _grid(f"G_{falloff}")
        half = Vector((0.5, 0, 0))
        target = min(range(len(obj.data.vertices)), key=lambda i: (obj.data.vertices[i].co - half).length)
        assert (obj.data.vertices[target].co - half).length < 1e-6
        deform.grab(obj, (0, 0, 0), 1.0, (0, 0, 1.0), falloff=falloff)
        measured[falloff] = obj.data.vertices[target].co.z
    assert measured["sharp"] < measured["smooth"] < measured["constant"]
    expected = {"sharp": 0.25, "smooth": 0.5, "linear": 0.5, "sphere": math.sqrt(0.75), "constant": 1.0}
    for falloff, value in expected.items():
        assert abs(measured[falloff] - value) < 1e-6, (falloff, measured[falloff])


def test_stroke_covers_the_path_and_nothing_beyond_the_radius():
    obj = _grid(n=60)
    path = [(-0.8, -0.3, 0.0), (0.0, 0.3, 0.0), (0.8, -0.3, 0.0)]
    before = _world(obj)
    out = deform.stroke(obj, path, "inflate", [0.12, 0.2], [0.01, 0.02], falloff="sphere")
    after = _world(obj)
    moved = np.any(after != before, axis=1)
    assert out["dabs"] > 20 and out["verts_moved"] == moved.sum()
    samples = [np.array(path[0]) + t * (np.array(path[1]) - path[0]) for t in np.linspace(0, 1, 9)]
    samples += [np.array(path[1]) + t * (np.array(path[2]) - path[1]) for t in np.linspace(0, 1, 9)]
    for p in samples:
        nearest = np.argmin(np.linalg.norm(before - p, axis=1))
        assert after[nearest, 2] > 0.005, p
    dist, _ = deform._polyline(np.array(path, float), before)
    assert not moved[dist >= 0.2].any()
    assert moved[dist < 0.11].all()


def test_stroke_radius_profile_widens_along_the_path():
    obj = _grid(n=80)
    before = _world(obj)
    deform.stroke(obj, [(-0.8, 0, 0), (0.8, 0, 0)], "inflate", [0.05, 0.3], [0.01], falloff="constant")
    moved = np.any(_world(obj) != before, axis=1)

    def width(x):
        return np.ptp(before[moved & (np.abs(before[:, 0] - x) < 0.02), 1])

    assert width(0.7) > 2.5 * width(-0.7)


def test_crease_cuts_in_and_bulge_follows_its_radius_profile():
    obj = _grid(n=60)
    before = _world(obj)
    out = deform.crease_along_curve(obj, [(-0.8, 0, 0), (0.8, 0, 0)], 0.2, 0.05)
    after = _world(obj)
    dist, _ = deform._polyline(np.array([(-0.8, 0, 0), (0.8, 0, 0)], float), before)
    assert not np.any(after[dist >= 0.2] != before[dist >= 0.2])
    on_line = dist < 1e-9
    assert np.allclose(after[on_line, 2], -0.05, atol=1e-6)
    assert out["verts_moved"] == np.any(after != before, axis=1).sum() > 100
    obj2 = _grid("Bulge", n=60)
    deform.bulge_along_curve(obj2, [(-0.8, 0, 0), (0.8, 0, 0)], [0.1, 0.4], 0.1, falloff="linear")
    z = _world(obj2)[:, 2]

    def probe(x, y):
        return z[np.argmin(np.linalg.norm(before[:, :2] - (x, y), axis=1))]

    assert probe(-0.7, 0.15) < 1e-9 < probe(0.7, 0.15)
    assert abs(probe(0.0, 0.0) - 0.1) < 1e-6


def test_pinch_pulls_tangentially_toward_the_centre():
    obj = _grid()
    before = _world(obj)
    deform.pinch(obj, (0, 0, 0.3), 0.6, 0.5, falloff="constant")
    after = _world(obj)
    inside = np.linalg.norm(before - (0, 0, 0.3), axis=1) < 0.6
    assert np.array_equal(after[~inside], before[~inside])
    assert np.allclose(after[:, 2], 0.0)
    ratio = np.linalg.norm(after[inside, :2], axis=1) / np.maximum(np.linalg.norm(before[inside, :2], axis=1), 1e-12)
    assert np.allclose(ratio[np.linalg.norm(before[inside, :2], axis=1) > 0], 0.5, atol=1e-6)
    assert "[-1, 1]" in _refuses(deform.pinch, obj, (0, 0, 0), 0.5, 1.5)


def test_flatten_fits_a_plane_or_uses_the_given_one():
    obj = _grid(n=40)
    deform.noise_displace(obj, 0.3, 0.05, seed=3)
    bumpy = _world(obj)
    region = np.linalg.norm(bumpy[:, :2], axis=1) < 0.4
    def off_plane(points):
        centred = points - points.mean(axis=0)
        return np.abs(centred @ np.linalg.svd(centred)[2][2]).max()

    assert off_plane(bumpy[region]) > 0.01
    deform.flatten(obj, (0, 0, 0), 0.6, falloff="constant")
    assert off_plane(_world(obj)[region]) < 1e-5
    deform.flatten(obj, (0, 0, 0), 0.6, plane=((0, 0, 0.1), (0, 0, 2)), falloff="constant")
    assert np.allclose(_world(obj)[region, 2], 0.1, atol=1e-6)
    assert "zero length" in _refuses(deform.flatten, obj, (0, 0, 0), 0.6, plane=((0, 0, 0), (0, 0, 0)))


def test_smooth_reduces_roughness_and_respects_the_mask():
    obj = _sphere()
    deform.noise_displace(obj, 0.2, 0.08, seed=1)

    def roughness():
        return np.std(np.linalg.norm(_local(obj), axis=1))

    rough = roughness()
    assert rough > 0.005
    out = deform.smooth(obj, iterations=5, factor=0.5)
    assert roughness() < 0.5 * rough and out["verts_moved"] > 1000
    group = obj.vertex_groups.new(name="keep")
    group.add(list(range(len(obj.data.vertices))), 0.0, "REPLACE")
    before = _local(obj)
    assert deform.smooth(obj, iterations=3, mask="keep")["verts_moved"] == 0
    assert np.array_equal(_local(obj), before)
    assert "iterations" in _refuses(deform.smooth, obj, iterations=0)


def test_noise_displace_is_deterministic_and_along_normals():
    a, b, c = _sphere("A"), _sphere("B"), _sphere("C")
    out = deform.noise_displace(a, 0.25, 0.05, octaves=4, seed=7)
    deform.noise_displace(b, 0.25, 0.05, octaves=4, seed=7)
    deform.noise_displace(c, 0.25, 0.05, octaves=4, seed=8)
    assert np.abs(_local(a) - _local(b)).max() < 1e-6
    assert np.abs(_local(a) - _local(c)).max() > 0.01
    rest = _sphere("Rest")
    normals = np.empty(len(rest.data.vertices) * 3)
    rest.data.vertex_normals.foreach_get("vector", normals)
    normals = normals.reshape(-1, 3)
    moved = _local(a) - _local(rest)
    tangential = moved - np.sum(moved * normals, axis=1)[:, None] * normals
    assert np.abs(tangential).max() < 1e-6
    assert 0.01 < out["max_displacement"] <= 0.05


def test_refusals():
    obj = _grid()
    assert "falloff" in _refuses(deform.grab, obj, (0, 0, 0), 1, (0, 0, 1), falloff="bumpy")
    assert "symmetry" in _refuses(deform.grab, obj, (0, 0, 0), 1, (0, 0, 1), symmetry="W")
    assert "radius" in _refuses(deform.inflate, obj, (0, 0, 0), 0, 0.1)
    assert "at least 2" in _refuses(deform.crease_along_curve, obj, [(0, 0, 0)], 0.1, 0.1)
    assert "zero length" in _refuses(deform.bulge_along_curve, obj, [(0, 0, 0), (0, 0, 0)], [0.1], 0.1)
    assert "op" in _refuses(deform.stroke, obj, [(0, 0, 0), (1, 0, 0)], "smudge", [0.1], [1])
    assert "offset" in _refuses(deform.stroke, obj, [(0, 0, 0), (1, 0, 0)], "grab", [0.1], [1])
    assert "[0.0, 1.0]" in _refuses(deform.stroke, obj, [(0, 0, 0), (1, 0, 0)], "flatten", [0.1], [0.5, 2.0])
    assert "scale" in _refuses(deform.noise_displace, obj, 0, 0.1)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    assert "expected MESH" in _refuses(deform.grab, cam, (0, 0, 0), 1, (0, 0, 1))
    obj.shape_key_add(name="Basis")
    assert "shape keys" in _refuses(deform.grab, obj, (0, 0, 0), 1, (0, 0, 1))
    _refuses(deform.experimental_brush_stroke, _sphere(), [(0, 0, 1)], stage="headless")
