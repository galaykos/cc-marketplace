import bmesh
import bpy
import numpy as np
from mathutils import Vector

from forge import retopo
from forge.util import ForgeError, world_bbox


def _object(name, bm):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def _ico(name, subdivisions=4, radius=1.0):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdivisions, radius=radius)
    return _object(name, bm)


def _refuses(fn, *args, stage=None, **kwargs):
    try:
        fn(*args, **kwargs)
    except ForgeError as exc:
        if stage is not None:
            assert exc.stage == stage, exc.stage
        return str(exc)
    raise AssertionError(f"{fn.__name__} accepted {args} {kwargs}")


def _volume(obj, signed=False):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.transform(obj.matrix_world)
    volume = bm.calc_volume(signed=signed)
    bm.free()
    return volume


FLIPPED = 5


def _messy(name="SM_AI"):
    """An icosphere (1280 tris) as a triangle soup, so every vertex is duplicated, minus one face (a 3-sided hole),
    with FLIPPED faces far from the hole flipped, a 2-triangle speck island far away, a loose edge and a loose vertex;
    object scale 3 at (1, 2, 3)."""
    src = bmesh.new()
    bmesh.ops.create_icosphere(src, subdivisions=4, radius=1.0)
    tris = [[v.co.copy() for v in f.verts] for f in src.faces]
    src.free()
    hole = tris.pop(0)
    hole_centre = sum(hole, Vector()) / 3
    far = [i for i, t in enumerate(tris) if (sum(t, Vector()) / 3 - hole_centre).length > 1.0]
    flip = set(far[::len(far) // FLIPPED][:FLIPPED])
    bm = bmesh.new()
    for i, t in enumerate(tris):
        face = bm.faces.new([bm.verts.new(c) for c in t])
        if i in flip:
            face.normal_flip()
    speck = [Vector((2, 2, 2)), Vector((2.05, 2, 2)), Vector((2.05, 2.05, 2)), Vector((2, 2.05, 2))]
    bm.faces.new([bm.verts.new(c) for c in speck[:3]])
    bm.faces.new([bm.verts.new(c) for c in (speck[0], speck[2], speck[3])])
    bm.edges.new((bm.verts.new((-2, 0, 0)), bm.verts.new((-2, 0, 0.5))))
    bm.verts.new((0, -2, 0))
    obj = _object(name, bm)
    obj.scale = (3, 3, 3)
    obj.location = (1, 2, 3)
    return obj


def test_clean_ai_mesh_fixes_each_defect_and_counts_it():
    obj = _messy()
    sphere_lo, sphere_hi = Vector((-2, -1, 0)), Vector((4, 5, 6))
    out = retopo.clean_ai_mesh(obj)
    assert out["transforms"] == {"scale_before": [3, 3, 3], "scale_after": [1, 1, 1], "baked": ["scale", "rotation"]}
    assert out["merge"] == {"verts_before": 1279 * 3 + 6 + 2 + 1, "verts_after": 642 + 4 + 2 + 1}
    assert out["loose"] == {"edges_before": 1, "verts_before": 3, "edges_after": 0, "verts_after": 0}
    assert out["islands"] == {"before": 2, "after": 1, "faces_removed": 2}
    assert out["holes"] == {"before": 1, "after": 0, "filled": 1}
    assert out["normals"] == {"inconsistent_edges_before": 3 * FLIPPED, "inconsistent_edges_after": 0,
                              "faces_flipped": FLIPPED}
    assert out["faces"] == {"before": 1281, "after": 1280}
    assert len(obj.data.vertices) == 642 and len(obj.data.polygons) == 1280
    lo, hi = world_bbox(obj)
    assert (lo - sphere_lo).length < 1e-4 and (hi - sphere_hi).length < 1e-4
    assert (Vector(out["origin"]["after"]) - Vector((1, 2, 0))).length < 1e-4
    assert out["origin"]["before"] == [1, 2, 3]
    assert min(v.co.z for v in obj.data.vertices) == 0.0
    assert _volume(obj, signed=True) > 0.95 * 4 / 3 * np.pi * 27
    again = retopo.clean_ai_mesh(obj)
    assert again["merge"]["verts_before"] == again["merge"]["verts_after"] == 642
    assert again["normals"]["faces_flipped"] == 0 and again["holes"]["filled"] == 0


def test_clean_ai_mesh_leaves_holes_over_the_side_cap_open():
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=3, radius=1.0)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().z > 0.9], context="FACES")
    boundary = sum(e.is_boundary for e in bm.edges)
    obj = _object("Cup", bm)
    out = retopo.clean_ai_mesh(obj, max_hole_sides=8)
    assert boundary > 8 and out["holes"] == {"before": 1, "after": 1, "filled": 0}
    assert retopo.clean_ai_mesh(obj, max_hole_sides=boundary)["holes"] == {"before": 1, "after": 0, "filled": 1}
    assert all(p.loop_total == 3 for p in obj.data.polygons)
    assert "max_hole_sides" in _refuses(retopo.clean_ai_mesh, obj, max_hole_sides=2)
    twin = bpy.data.objects.new("Twin", obj.data)
    bpy.context.scene.collection.objects.link(twin)
    assert "shared" in _refuses(retopo.clean_ai_mesh, obj)


def _uv_sphere(name):
    bm = bmesh.new()
    bm.loops.layers.uv.new("UVMap")
    bmesh.ops.create_uvsphere(bm, u_segments=64, v_segments=32, radius=1.0, calc_uvs=True)
    return _object(name, bm)


def test_decimate_lands_within_ten_percent_and_protects_uv_seams():
    for protect in (False, True):
        obj = _uv_sphere(f"Ball_{protect}")
        obj.modifiers.new("Keep", "SUBSURF")
        before = {tuple(round(c, 5) for c in v.co) for v in obj.data.vertices}
        out = retopo.decimate_to_budget(obj, 800, protect_uv_seams=protect)
        tris = sum(p.loop_total - 2 for p in obj.data.polygons)
        assert out["within_tolerance"] and abs(tris - 800) <= 80 and out["achieved_tris"] == tris
        assert out["tris_before"] == 64 * 30 * 2 + 2 * 64
        assert [m.name for m in obj.modifiers] == ["Keep"] and obj.modifiers["Keep"].show_viewport
        assert len(obj.vertex_groups) == 0
        after = {tuple(round(c, 5) for c in v.co) for v in obj.data.vertices}
        if protect:
            assert out["protected_verts"] > 30
            seam = _uv_seam_positions(_uv_sphere("Ref"))
            assert seam and seam <= after, len(seam - after)
        else:
            assert out["protected_verts"] == 0 and len(after & before) < len(before)
    untouched = _ico("Small", 3)
    out = retopo.decimate_to_budget(untouched, 300)
    assert out["achieved_tris"] == 320 and out["ratio"] == 1.0
    assert "target_tris" in _refuses(retopo.decimate_to_budget, untouched, 0)


def _uv_seam_positions(obj):
    """Rounded positions of the vertices on an edge whose two faces give it different UVs."""
    mesh = obj.data
    uv = mesh.uv_layers.active.data
    sides = {}
    for poly in mesh.polygons:
        loops = list(poly.loop_indices)
        for li, lj in zip(loops, loops[1:] + loops[:1]):
            a, b = mesh.loops[li].vertex_index, mesh.loops[lj].vertex_index
            sides.setdefault(frozenset((a, b)), []).append({a: Vector(uv[li].uv), b: Vector(uv[lj].uv)})
    found = set()
    for edge, faces in sides.items():
        if len(faces) == 2 and any((faces[0][v] - faces[1][v]).length > 1e-6 for v in edge):
            found |= edge
    return {tuple(round(c, 5) for c in mesh.vertices[i].co) for i in found}


def test_bake_modifier_bakes_one_modifier_under_the_existing_stack():
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    cube = _object("Cube", bm)
    cube.modifiers.new("Keep", "BEVEL")
    out = retopo.bake_modifier(cube.name, "SUBSURF", levels=1)
    assert out == {"ok": True, "object": "Cube", "modifier": "SUBSURF", "verts": 26, "faces": 24}
    assert len(cube.data.polygons) == 24 and [m.name for m in cube.modifiers] == ["Keep"]
    assert cube.modifiers["Keep"].show_viewport
    assert "no NOPE modifier" in _refuses(retopo.bake_modifier, cube, "NOPE", stage="blender")
    assert "no setting 'level'" in _refuses(retopo.bake_modifier, cube, "SUBSURF", level=2)
    assert [m.name for m in cube.modifiers] == ["Keep"] and len(cube.data.polygons) == 24


def test_voxel_remesh_gives_quads_and_keeps_volume():
    obj = _ico("Ball", 4)
    volume = _volume(obj) * 8
    obj.scale = (2, 2, 2)
    out = retopo.voxel_remesh(obj, 0.05)
    cells = 4 * np.pi * 2 * 2 / 0.05 ** 2
    assert out["faces_before"] == 1280 and 1.2 < out["faces_after"] / cells < 1.8
    assert all(p.loop_total == 4 for p in obj.data.polygons)
    assert abs(_volume(obj) - volume) / volume < 0.03
    assert "voxel_size" in _refuses(retopo.voxel_remesh, obj, 0)
    assert "limit" in _refuses(retopo.voxel_remesh, obj, 1e-4)


def test_quadriflow_runs_headless_and_refuses_non_manifold():
    obj = _ico("Ball", 4)
    out = retopo.quadriflow(obj, 500)
    assert 350 <= out["faces_after"] <= 650 and out["quads"] == out["faces_after"] == len(obj.data.polygons)
    bm = bmesh.new()
    a = [bm.verts.new(p) for p in ((0, 0, 0), (1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1))]
    for third in a[2:]:
        bm.faces.new((a[0], a[1], third))
    fin = _object("Fin", bm)
    _refuses(retopo.quadriflow, fin, 100, stage="quadriflow")
    assert len(fin.data.polygons) == 3
    assert "target_faces" in _refuses(retopo.quadriflow, obj, 0)


def test_shrinkwrap_projects_low_onto_high():
    high = _ico("High", 4, 1.0)
    low = _ico("Low", 2, 1.5)
    out = retopo.shrinkwrap_lowpoly(high, low)
    assert out["mean_distance_before"] > 0.45 and out["max_distance_after"] < 1e-4
    assert not low.modifiers and out["verts"] == len(low.data.vertices) == 42
    padded = _ico("Padded", 2, 1.5)
    out = retopo.shrinkwrap_lowpoly(high, padded, offset=0.1)
    assert abs(out["mean_distance_after"] - 0.1) < 5e-3
    assert "same object" in _refuses(retopo.shrinkwrap_lowpoly, high, high)
    hidden = _ico("Hidden", 2, 1.5)
    hidden.hide_viewport = True
    assert "not evaluated" in _refuses(retopo.shrinkwrap_lowpoly, high, hidden)
