import math

import bpy
import numpy as np

from forge import blockout
from forge.util import ForgeError, world_bbox

QUADRUPED = {
    "joints": {
        "pelvis": {"co": [0, 0.4, 0.9], "radius": 0.22}, "chest": {"co": [0, -0.4, 1.0], "radius": 0.26},
        "neck": {"co": [0, -0.7, 1.3], "radius": 0.12}, "head": {"co": [0, -0.9, 1.45], "radius": 0.16},
        "snout": {"co": [0, -1.15, 1.4], "radius": 0.08},
        "tail1": {"co": [0, 0.75, 1.0], "radius": 0.08}, "tail2": {"co": [0, 1.1, 0.9], "radius": 0.05},
        "fl_upper": {"co": [0.18, -0.4, 0.6], "radius": 0.09}, "fl_foot": {"co": [0.18, -0.4, 0.05], "radius": 0.06},
        "fr_upper": {"co": [-0.18, -0.4, 0.6], "radius": 0.09}, "fr_foot": {"co": [-0.18, -0.4, 0.05], "radius": 0.06},
        "bl_upper": {"co": [0.18, 0.4, 0.55], "radius": 0.1}, "bl_foot": {"co": [0.18, 0.45, 0.05], "radius": 0.06},
        "br_upper": {"co": [-0.18, 0.4, 0.55], "radius": 0.1}, "br_foot": {"co": [-0.18, 0.45, 0.05], "radius": 0.06},
    },
    "bones": [["pelvis", "chest"], ["chest", "neck"], ["neck", "head"], ["head", "snout"], ["pelvis", "tail1"],
              ["tail1", "tail2"], ["chest", "fl_upper"], ["fl_upper", "fl_foot"], ["chest", "fr_upper"],
              ["fr_upper", "fr_foot"], ["pelvis", "bl_upper"], ["bl_upper", "bl_foot"], ["pelvis", "br_upper"],
              ["br_upper", "br_foot"]],
}


def _refuses(fn, *args, **kwargs):
    try:
        fn(*args, **kwargs)
    except ForgeError as exc:
        return str(exc)
    raise AssertionError(f"{fn.__name__} accepted {args} {kwargs}")


def _co(obj):
    co = np.empty(len(obj.data.vertices) * 3)
    obj.data.vertices.foreach_get("co", co)
    return co.reshape(-1, 3)


def test_skin_output_is_manifold_and_spans_the_joint_bbox():
    """Subdivision pulls the Skin modifier's flat end caps inward by about 13% of the end radius (measured), so an end
    may stop that far short of its joint; end_slack allows it."""
    end_slack = 0.05
    spec = {"joints": {"root": {"co": [0, 0, 0], "radius": 0.2}, "mid": {"co": [0, 0, 1], "radius": 0.2},
                       "left": {"co": [0.6, 0, 1.6], "radius": 0.15}, "right": {"co": [-0.6, 0.2, 1.5], "radius": 0.1}},
            "bones": [["root", "mid"], ["mid", "left"], ["mid", "right"]]}
    out = blockout.skin_from_skeleton(spec, name="Y")
    obj = bpy.data.objects[out["object"]]
    assert out["manifold"] and out["parts"] == 1 and out["tris"] > 200
    assert not obj.modifiers and out["tris"] == sum(p.loop_total - 2 for p in obj.data.polygons)
    joints = np.array([j["co"] for j in spec["joints"].values()], float)
    lo, hi = (np.array(v) for v in world_bbox(obj))
    assert np.all(lo <= joints.min(axis=0) + end_slack) and np.all(hi >= joints.max(axis=0) - end_slack)
    assert np.all(lo >= joints.min(axis=0) - 0.3) and np.all(hi <= joints.max(axis=0) + 0.3)
    flat = blockout.skin_from_skeleton(spec, name="Y0", subdivisions=0)
    flat_corners = sum(p.loop_total for p in bpy.data.objects[flat["object"]].data.polygons)
    assert flat["manifold"] and out["faces"] == flat_corners
    assert all(p.loop_total == 4 for p in obj.data.polygons)
    assert np.all(np.array(flat["bbox_min"]) <= joints.min(axis=0) + 1e-6)
    assert np.all(np.array(flat["bbox_max"]) >= joints.max(axis=0) - 1e-6)
    pair = {"joints": {k: {"co": [x, 0, z], "radius": 0.1} for k, x, z in
                       (("a", 0, 0), ("b", 0, 1), ("c", 1, 0), ("d", 1, 1))},
            "bones": [["a", "b"], ["c", "d"]]}
    two = blockout.skin_from_skeleton(pair, name="Pair")
    assert two["parts"] == 2 and two["manifold"]
    assert two["bbox_min"][0] < 0 and two["bbox_max"][0] > 1


def test_quadruped_spec_skins_into_one_closed_body():
    out = blockout.skin_from_skeleton(QUADRUPED, name="Quadruped", subdivisions=2)
    assert out["manifold"] and out["parts"] == 1 and out["tris"] > 2000
    lo, hi = out["bbox_min"], out["bbox_max"]
    assert lo[2] < 0.06 and hi[2] > 1.45 and lo[1] < -1.15 + 0.02 and hi[1] > 1.1 - 0.02
    assert abs(lo[0] + hi[0]) < 0.02


def test_skin_refusals():
    joints = {"a": {"co": [0, 0, 0], "radius": 0.1}, "b": {"co": [0, 0, 1], "radius": 0.1}}
    assert "unknown joint" in _refuses(blockout.skin_from_skeleton, {"joints": joints, "bones": [["a", "c"]]})
    assert "in no bone" in _refuses(blockout.skin_from_skeleton,
                                    {"joints": {**joints, "c": {"co": [1, 0, 0], "radius": 0.1}},
                                     "bones": [["a", "b"]]})
    assert "radius" in _refuses(blockout.skin_from_skeleton,
                                {"joints": {**joints, "b": {"co": [0, 0, 1], "radius": 0}}, "bones": [["a", "b"]]})
    assert "twice" in _refuses(blockout.skin_from_skeleton, {"joints": joints, "bones": [["a", "b"], ["b", "a"]]})
    assert not bpy.data.objects


def test_metaball_blob_converts_and_leaves_no_metaball_behind():
    spec = [{"co": [0, 0, 0], "radius": 1.0}, {"co": [1.2, 0, 0], "radius": 0.8, "type": "BALL"}]
    out = blockout.metaball_blob(spec, name="Blob", resolution=0.05)
    obj = bpy.data.objects[out["object"]]
    assert obj.type == "MESH" and out["manifold"] and out["tris"] > 500
    assert len(bpy.data.metaballs) == 0 and [o.name for o in bpy.data.objects] == ["Blob"]
    assert abs(out["bbox_min"][0] + 0.575) < 0.05 and abs(out["bbox_max"][2] - 0.575) < 0.08
    assert out["bbox_max"][0] > 1.2 + 0.4
    assert "type" in _refuses(blockout.metaball_blob, [{"co": [0, 0, 0], "radius": 1, "type": "TORUS"}])
    assert len(bpy.data.metaballs) == 0 and len(bpy.data.objects) == 1


def test_rock_is_deterministic_per_seed_and_style():
    a = blockout.rock(seed=3, size=2.0, name="A")
    b = blockout.rock(seed=3, size=2.0, name="B")
    c = blockout.rock(seed=4, size=2.0, name="C")
    ca, cb, cc = (_co(bpy.data.objects[r["object"]]) for r in (a, b, c))
    assert ca.shape == cb.shape and np.array_equal(ca, cb)
    assert ca.shape != cc.shape or np.abs(ca - cc).max() > 0.01
    dims = {}
    for style in blockout.ROCK_STYLES:
        for seed in range(4):
            out = blockout.rock(seed=seed, size=1.5, style=style, name=f"R_{style}_{seed}")
            lo, hi = np.array(out["bbox_min"]), np.array(out["bbox_max"])
            assert out["manifold"], (style, seed)
            assert abs((hi - lo).max() - 1.5) < 1e-5 and abs(lo[2]) < 1e-6
            assert abs(lo[0] + hi[0]) < 1e-5 and abs(lo[1] + hi[1]) < 1e-5
            dims.setdefault(style, []).append(hi - lo)
    height = {s: np.mean([d[2] / max(d[0], d[1]) for d in v]) for s, v in dims.items()}
    assert height["slab"] < 0.5 < height["boulder"] < 1.0 < height["shard"]
    assert "style" in _refuses(blockout.rock, style="pebble")


def _frustum_volume(profile):
    return sum(math.pi * (z1 - z0) * (r0 * r0 + r0 * r1 + r1 * r1) / 3
               for (r0, z0), (r1, z1) in zip(profile, profile[1:]))


def test_lathe_vase_volume_matches_the_solid_of_revolution():
    vase = [(0, 0), (0.3, 0), (0.45, 0.25), (0.35, 0.6), (0.2, 0.8), (0.25, 1.0), (0, 1.0)]
    out = blockout.lathe(vase, segments=16, name="Vase")
    exact = _frustum_volume(vase)
    assert out["closed"] and out["manifold"]
    assert abs(out["volume"] - exact) / exact < 0.05, (out["volume"], exact)
    assert out["verts"] == 2 + 5 * 16 and out["faces"] == 6 * 16
    finer = blockout.lathe(vase, segments=64, name="Vase64")
    assert abs(finer["volume"] - exact) < abs(out["volume"] - exact)
    tube = blockout.lathe([(0.3, 0, 0), (0.3, 0, 1)], segments=8, name="Tube")
    assert not tube["closed"] and tube["volume"] is None and not tube["manifold"] and tube["faces"] == 8
    assert "axis" in _refuses(blockout.lathe, [(0.2, 0), (0, 0.5), (0.2, 1)])
    assert ">= 0" in _refuses(blockout.lathe, [(-0.2, 0), (0.2, 1)])


def test_loft_joins_equal_sections():
    ring = [(math.cos(a), math.sin(a)) for a in np.linspace(0, 2 * math.pi, 6, endpoint=False)]
    sections = [[(x * r, y * r, z) for x, y in ring] for z, r in ((0, 1.0), (1, 0.6), (2, 0.8))]
    out = blockout.loft(sections, name="Trunk")
    assert out["faces"] == 2 * 6 and out["verts"] == 18 and not out["manifold"]
    assert abs(out["bbox_max"][2] - 2) < 1e-6
    strip = blockout.loft(sections, name="Strip", closed=False)
    assert strip["faces"] == 2 * 5
    assert "same number" in _refuses(blockout.loft, [sections[0], sections[1][:5]])
