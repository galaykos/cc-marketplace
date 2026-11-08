import bmesh
import bpy
from mathutils import Vector

import fixtures
from forge import lod, util
from forge.util import ForgeError


def _refused(fn, *args, **kwargs):
    try:
        fn(*args, **kwargs)
    except ForgeError as exc:
        return str(exc)
    raise AssertionError(f"{fn.__name__}{args}{kwargs} was accepted")


def _dense_crate(cuts=8):
    """The fixture crate with each face gridded: 972 tris, the fixture's UV layout split along cube edges."""
    crate = fixtures.crate()
    bm = bmesh.new()
    bm.from_mesh(crate.data)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=cuts, use_grid_fill=True)
    bm.to_mesh(crate.data)
    bm.free()
    return crate


def _world_points(obj):
    return [obj.matrix_world @ v.co for v in obj.data.vertices]


def test_chain_from_pc_budget_is_named_decimated_and_keeps_silhouette():
    crate = _dense_crate()
    crate.location = (3, 0, 0)
    out = lod.make_lod_chain(crate.name, engine="unity", platform="pc")
    names = [entry["name"] for entry in out["lods"]]
    assert names == ["SM_Crate_LOD0", "SM_Crate_LOD1", "SM_Crate_LOD2", "SM_Crate_LOD3"]
    assert crate.name == "SM_Crate_LOD0" and out["ratios_from"] == "budgets/pc.json"
    assert out["lods"][0]["tris"] == 972 and out["lod_export"] == "same_file"
    for entry in out["lods"][1:]:
        obj = bpy.data.objects[entry["name"]]
        assert entry["tris"] == util.tri_count(obj) < 972
        assert entry["achieved_ratio"] <= entry["ratio"] + 0.02 or entry["limited_by_protection"]
        assert entry["bbox_deviation"] <= 0.02
        assert obj.data.uv_layers and obj.data.materials[0].name == "M_Crate"
        assert not obj.modifiers and lod.PROTECT_GROUP not in obj.vertex_groups
        assert (obj.matrix_world.translation - Vector((3, 0, 0))).length < 1e-6
    assert abs(out["lods"][1]["achieved_ratio"] - 0.5) <= 0.02
    assert abs(out["lods"][2]["achieved_ratio"] - 0.25) <= 0.02
    assert out["silhouette_ok"] and 0 < out["protected_verts"] < out["total_verts"]


def test_protected_seam_vertices_survive_unmoved():
    rock = fixtures.rock_blockout()
    bm = bmesh.new()
    bm.from_mesh(rock.data)
    ring = [e for e in bm.edges if abs(e.verts[0].co.z) < 0.35 and abs(e.verts[1].co.z) < 0.35]
    for e in ring:
        e.seam = True
    seam_points = {v.index for e in ring for v in e.verts}
    bm.to_mesh(rock.data)
    bm.free()
    seam_points = [rock.data.vertices[i].co.copy() for i in seam_points]
    raw = rock.copy()
    raw.data = rock.data.copy()
    bpy.context.scene.collection.objects.link(raw)
    mod = raw.modifiers.new("d", "DECIMATE")
    mod.ratio = 0.25
    bpy.context.view_layer.update()
    raw_mesh = raw.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
    raw_points = [v.co.copy() for v in raw_mesh.vertices]
    raw.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh_clear()
    lost_without = sum(1 for p in seam_points if min((p - q).length for q in raw_points) > 1e-5)
    assert lost_without > 0, "an unprotected decimate kept every seam vertex: the test cannot show protection"
    out = lod.make_lod_chain(rock, ratios=[1.0, 0.25], engine="unreal")
    lod1 = bpy.data.objects[out["lods"][1]["name"]]
    kept = [v.co for v in lod1.data.vertices]
    assert all(min((p - q).length for q in kept) < 1e-5 for p in seam_points)
    assert out["lods"][1]["tris"] < 320 and out["protected_verts"] == len(seam_points)


def test_mobile_godot_chain_reports_engine_generates():
    rock = fixtures.rock_blockout()
    out = lod.make_lod_chain(rock, engine="godot", platform="mobile")
    assert [e["name"] for e in out["lods"]] == ["SM_Rock_LOD0", "SM_Rock_LOD1", "SM_Rock_LOD2"]
    assert out["lod_export"] == "engine_generates" and "Godot" in out["lod_note"]
    assert out["lods"][1]["tris"] < 320 and out["lods"][2]["tris"] < out["lods"][1]["tris"]


def test_rerun_replaces_the_chain_and_drops_stale_lods():
    crate = _dense_crate(cuts=4)
    first = lod.make_lod_chain(crate, engine="unity")
    count = len(bpy.data.objects)
    again = lod.make_lod_chain(crate.name, engine="unity")
    assert len(bpy.data.objects) == count
    assert [e["tris"] for e in again["lods"]] == [e["tris"] for e in first["lods"]]
    shorter = lod.make_lod_chain("SM_Crate_LOD0", ratios=[1.0, 0.5], engine="unity")
    assert shorter["removed"] == ["SM_Crate_LOD1", "SM_Crate_LOD2", "SM_Crate_LOD3"]
    assert "SM_Crate_LOD2" not in bpy.data.objects and len(bpy.data.objects) == 2


def test_skinned_mesh_lods_keep_rig_binding():
    rig, mesh, _ = fixtures.humanoid()
    out = lod.make_lod_chain(mesh, ratios=[1.0, 0.5], engine="unreal")
    lod1 = bpy.data.objects[out["lods"][1]["name"]]
    assert lod1.parent == rig and [m.type for m in lod1.modifiers] == ["ARMATURE"]
    assert lod1.modifiers[0].object == rig and lod1.modifiers[0].show_viewport
    assert [g.name for g in lod1.vertex_groups] == [g.name for g in mesh.vertex_groups]
    assert any(len(v.groups) for v in lod1.data.vertices)
    assert out["lods"][1]["tris"] < out["lods"][0]["tris"]


def test_refusals():
    crate = _dense_crate(cuts=2)
    assert "must be 1.0" in _refused(lod.make_lod_chain, crate, ratios=[0.5, 0.25])
    assert "strictly" in _refused(lod.make_lod_chain, crate, ratios=[1.0, 0.5, 0.5])
    _refused(lod.make_lod_chain, crate, ratios=[1.0])
    _refused(lod.make_lod_chain, crate, engine="frostbite")
    _refused(lod.make_lod_chain, crate, platform="toaster")
    lod.make_lod_chain(crate, ratios=[1.0, 0.5])
    assert "LOD1" in _refused(lod.make_lod_chain, "SM_Crate_LOD1")
    rig = fixtures.armature("RIG")
    assert "expected MESH" in _refused(lod.make_lod_chain, rig)
    fixtures.crate("SM_Box_LOD0")
    other = fixtures.crate("SM_Box")
    assert "already named" in _refused(lod.make_lod_chain, other, ratios=[1.0, 0.5])
    assert other.name == "SM_Box"
