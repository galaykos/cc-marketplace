import math

import bmesh
import bpy
from mathutils import Matrix, Vector

import fixtures
from forge import collision
from forge.util import ForgeError


def _refused(fn, *args, **kwargs):
    try:
        fn(*args, **kwargs)
    except ForgeError as exc:
        return str(exc)
    raise AssertionError(f"{fn.__name__}{args}{kwargs} was accepted")


def _link(name, bm):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def _u_prism(name="SM_U"):
    """One connected closed mesh shaped like a U: 3 m x 3 m outline, 1 m thick, volume 7 m³, hull volume 9 m³."""
    bm = bmesh.new()
    outline = [(0, 0), (3, 0), (3, 3), (2, 3), (2, 1), (1, 1), (1, 3), (0, 3)]
    face = bm.faces.new([bm.verts.new((x, y, 0)) for x, y in outline])
    face.normal_update()
    if face.normal.z > 0:
        face.normal_flip()
    top = bmesh.ops.extrude_face_region(bm, geom=[face])
    bmesh.ops.translate(bm, vec=(0, 0, 1), verts=[g for g in top["geom"] if isinstance(g, bmesh.types.BMVert)])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return _link(name, bm)


def _boxes(name="SM_Parts", count=3):
    bm = bmesh.new()
    for i in range(count):
        bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation((i * 2.0, 0, 0)))
    return _link(name, bm)


def _sphere(name="SM_Ball"):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=48, v_segments=32, radius=1.0)
    return _link(name, bm)


def _is_convex(obj, eps=1e-5):
    pts = [v.co for v in obj.data.vertices]
    for poly in obj.data.polygons:
        n, p = poly.normal, obj.data.vertices[poly.vertices[0]].co
        side = [(v - p).dot(n) for v in pts]
        if max(side) > eps and min(side) < -eps:
            return False
    return True


def test_box_is_oriented_to_object_space_and_parented():
    crate = fixtures.crate()
    crate.location = (1, 2, 0)
    crate.rotation_euler = (0, 0, math.radians(30))
    crate.scale = (2, 1, 1)
    bpy.context.view_layer.update()
    out = collision.make_collision(crate, kind="box", engine="unity")
    (hull,) = out["hulls"]
    box = bpy.data.objects[hull["name"]]
    assert hull["name"] == "SM_Crate_Collider", hull
    assert (hull["verts"], hull["faces"]) == (8, 6), hull
    assert abs(hull["volume"] - 1.0) < 1e-6 and out["parented"] and box.parent == crate
    assert box.display_type == "WIRE" and len(box.data.materials) == 0
    bpy.context.view_layer.update()
    corners = {tuple(round(c, 5) for c in crate.matrix_world @ Vector(b)) for b in crate.bound_box}
    got = {tuple(round(c, 5) for c in box.matrix_world @ v.co) for v in box.data.vertices}
    assert got == corners
    assert "MeshCollider" in out["engine_note"]


def test_convex_hull_is_convex_and_named_per_engine():
    u = _u_prism()
    expected = {"unreal": "UCX_SM_U_01", "godot": "SM_U-convcolonly", "unity": "SM_U_Collider",
                "generic": "SM_U_COL"}
    for engine, name in expected.items():
        out = collision.make_collision(u, kind="convex", engine=engine)
        (hull,) = out["hulls"]
        assert hull["name"] == name and hull["verts"] == 8 and abs(hull["volume"] - 9.0) < 1e-5
        assert _is_convex(bpy.data.objects[name]) and abs(out["mesh_volume"] - 7.0) < 1e-5


def test_hull_vertex_and_face_caps_keep_the_shape():
    ball = _sphere()
    free = collision.make_collision(ball, kind="convex", engine="unreal", max_hull_verts=None,
                                    max_hull_faces=None)["hulls"][0]
    verts_only = collision.make_collision(ball, kind="convex", engine="unreal", max_hull_faces=None)["hulls"][0]
    capped = collision.make_collision(ball, kind="convex", engine="unreal")["hulls"][0]
    assert free["verts"] > collision.HULL_VERT_CAP and free["capped_from"] is None
    assert verts_only["verts"] <= collision.HULL_VERT_CAP < verts_only["faces"], verts_only
    assert capped["verts"] <= collision.HULL_VERT_CAP and capped["faces"] <= collision.HULL_FACE_CAP, capped
    assert capped["capped_from"] == free["verts"]
    assert capped["volume"] >= 0.95 * free["volume"], (capped, free)
    assert _is_convex(bpy.data.objects[capped["name"]])


def test_multi_slices_a_concave_mesh_into_convex_pieces():
    u = _u_prism()
    out = collision.make_collision(u, kind="multi", engine="unreal", max_hulls=8)
    assert out["method"] == "slices_X" and len(out["hulls"]) == 3
    assert [h["name"] for h in out["hulls"]] == ["UCX_SM_U_01", "UCX_SM_U_02", "UCX_SM_U_03"]
    assert abs(out["total_volume"] - 7.0) < 1e-4 < 9.0 - out["total_volume"]
    assert all(_is_convex(bpy.data.objects[h["name"]]) for h in out["hulls"])
    two = collision.make_collision(u, kind="multi", engine="unreal", max_hulls=2)
    assert len(two["hulls"]) == 2 and 7.0 < two["total_volume"] < 9.0
    assert sorted(two["removed"]) == ["UCX_SM_U_01", "UCX_SM_U_02", "UCX_SM_U_03"]


def test_multi_uses_loose_parts_and_refuses_too_many():
    parts = _boxes(count=3)
    out = collision.make_collision(parts, kind="multi", engine="godot")
    assert out["method"] == "loose_parts" and [h["verts"] for h in out["hulls"]] == [8, 8, 8]
    assert [h["name"] for h in out["hulls"]] == [f"SM_Parts-convcolonly{i:02d}" for i in (1, 2, 3)]
    _, mesh, _ = fixtures.humanoid()
    assert "loose parts" in _refused(collision.make_collision, mesh, kind="multi", max_hulls=8)


def test_rerun_replaces_and_beside_keeps_the_transform():
    crate = fixtures.crate()
    crate.location = (4, 0, 0)
    bpy.context.view_layer.update()
    collision.make_collision(crate, engine="unity")
    count = len(bpy.data.objects)
    again = collision.make_collision(crate, engine="unity", parent=False)
    assert len(bpy.data.objects) == count and again["removed"] == ["SM_Crate_Collider"]
    col = bpy.data.objects["SM_Crate_Collider"]
    assert col.parent is None and (col.matrix_world.translation - Vector((4, 0, 0))).length < 1e-6


def test_refusals():
    crate = fixtures.crate()
    assert "kind must be" in _refused(collision.make_collision, crate, kind="sphere", engine="unreal")
    _refused(collision.make_collision, crate, max_hulls=0)
    _refused(collision.make_collision, crate, max_hull_verts=3)
    assert "max_hull_faces" in _refused(collision.make_collision, crate, max_hull_faces=3)
    _refused(collision.make_collision, crate, engine="frostbite")
    rig = fixtures.armature("RIG")
    assert "expected MESH" in _refused(collision.make_collision, rig)
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=2, y_segments=2, size=1.0)
    plane = _link("SM_Floor", bm)
    assert "flat" in _refused(collision.make_collision, plane, kind="box")
    assert "SM_Floor_Collider" not in bpy.data.objects
