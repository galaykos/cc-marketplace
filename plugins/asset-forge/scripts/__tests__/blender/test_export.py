import os
from pathlib import Path

import bmesh
import bpy

import fixtures
from forge import collision, export, lod, util
from forge.util import ForgeError

LODS = ["SM_Crate_LOD0", "SM_Crate_LOD1", "SM_Crate_LOD2", "SM_Crate_LOD3"]


def _refused(fn, *args, **kwargs):
    try:
        fn(*args, **kwargs)
    except ForgeError as exc:
        return str(exc)
    raise AssertionError(f"{fn.__name__}{args}{kwargs} was accepted")


def _asset(engine):
    """A gridded crate at (2, 1, 0) with the pc LOD chain and a convex hull, built for `engine`. Returns tris by name."""
    crate = fixtures.crate()
    bm = bmesh.new()
    bm.from_mesh(crate.data)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=3, use_grid_fill=True)
    bm.to_mesh(crate.data)
    bm.free()
    crate.location = (2, 1, 0)
    lod.make_lod_chain(crate, engine=engine, platform="pc", protect=("boundary",))
    collision.make_collision(crate, kind="convex", engine=engine)
    return {o.name: util.tri_count(o) for o in bpy.data.objects if o.type == "MESH"}


def _import(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if path.suffix == ".fbx":
        bpy.ops.import_scene.fbx(filepath=str(path))
    else:
        bpy.ops.import_scene.gltf(filepath=str(path))
    bpy.context.view_layer.update()
    return {o.name: o for o in bpy.data.objects}


def _roundtrip(engine, tmp, expected):
    """Export the crate for `engine`, then re-import each file into an empty scene and compare names and tris."""
    tris = _asset(engine)
    bystander = fixtures.rock_blockout("Bystander")
    util.select_only(bystander)
    lod0 = bpy.data.objects["SM_Crate_LOD0"]
    lod0.hide_set(True)
    worlds = {o.name: o.matrix_world.copy() for o in bpy.data.objects}
    out = export.export_asset("SM_Crate_LOD0", engine=engine, out_dir=str(tmp))
    assert set(os.listdir(tmp)) == set(expected), os.listdir(tmp)
    assert bpy.context.view_layer.objects.active == bystander
    assert [o.name for o in bpy.context.view_layer.objects if o.select_get()] == ["Bystander"]
    assert lod0.hide_get()
    assert all((o.matrix_world.translation - worlds[o.name].translation).length < 1e-6 for o in bpy.data.objects)
    for entry in out["files"]:
        path = Path(entry["path"])
        assert entry["bytes"] == path.stat().st_size > 0 and not entry["other_files"]
        assert sorted(expected[path.name]) == entry["objects"]
    assert out["dropped_keys"] == []
    imported = {}
    for name, objects in expected.items():
        scene = _import(Path(tmp) / name)
        assert set(scene) == set(objects), (name, sorted(scene))
        assert all(o.type == "MESH" and not o.name.endswith("_end") for o in scene.values())
        for o in scene.values():
            assert util.tri_count(o) == tris[o.name], (o.name, util.tri_count(o), tris[o.name])
        imported[name] = {n: o.matrix_world.translation.copy() for n, o in scene.items()}
    return out, imported


def test_unity_fbx_holds_lods_and_collider(tmp):
    out, imported = _roundtrip("unity", tmp, {"SM_Crate.fbx": LODS + ["SM_Crate_LOD0_Collider"]})
    assert "bake_space_transform" in out["files"][0]["static_only"]
    assert any("main file" in line for line in out["log"])
    assert any("MeshCollider" in line for line in out["log"])
    assert imported["SM_Crate.fbx"]["SM_Crate_LOD0"].length > 0.5


def test_unreal_fbx_at_world_origin_with_lods_in_separate_files(tmp):
    expected = {"SM_Crate.fbx": ["SM_Crate_LOD0", "UCX_SM_Crate_LOD0_01"], "SM_Crate_LOD1.fbx": ["SM_Crate_LOD1"],
                "SM_Crate_LOD2.fbx": ["SM_Crate_LOD2"], "SM_Crate_LOD3.fbx": ["SM_Crate_LOD3"]}
    out, imported = _roundtrip("unreal", tmp, expected)
    assert any(line.startswith("pivot world_origin") for line in out["log"])
    for name in expected:
        for position in imported[name].values():
            assert position.length < 1e-4, (name, position)


def test_godot_glb_skips_lods_the_engine_generates(tmp):
    out, _ = _roundtrip("godot", tmp, {"SM_Crate.glb": ["SM_Crate_LOD0", "SM_Crate_LOD0-convcolonly"]})
    assert any("generates LODs" in line for line in out["log"])


def test_generic_glb_holds_lods_and_collision(tmp):
    _roundtrip("generic", tmp, {"SM_Crate.glb": LODS + ["SM_Crate_LOD0_COL"]})


def test_armature_file_skips_static_only_keys_and_adds_no_leaf_bones(tmp):
    rig, mesh, source = fixtures.humanoid()
    bones = len(rig.data.bones)
    out = export.export_asset([rig.name, mesh.name], engine="unity", out_dir=str(tmp), file_stem="SK_Hero")
    assert os.listdir(tmp) == ["SK_Hero.fbx"]
    assert out["files"][0]["static_only"] == "static-only keys skipped: armature in file"
    scene = _import(Path(tmp) / "SK_Hero.fbx")
    arms = [o for o in scene.values() if o.type == "ARMATURE"]
    assert len(arms) == 1 and len(arms[0].data.bones) == bones
    assert not any(b.name.endswith("_end") for b in arms[0].data.bones)


def test_unreal_refuses_two_meshes_with_custom_collision(tmp):
    a = fixtures.crate("SM_A")
    b = fixtures.crate("SM_B")
    b.location.x = 3
    for obj in (a, b):
        collision.make_collision(obj, kind="box", engine="unreal")
    assert "first mesh" in _refused(export.export_asset, ["SM_A", "SM_B"], engine="unreal", out_dir=str(tmp))
    assert os.listdir(tmp) == []
    export.export_asset(["SM_A", "SM_B"], engine="unreal", out_dir=str(tmp), include_collision=False)
    assert os.listdir(tmp) == ["SM_A.fbx"]


def test_filter_drops_keys_the_exporter_lacks():
    kwargs, dropped = export._filtered(bpy.ops.export_scene.fbx,
                                       {"add_leaf_bones": False, "object_types": ["MESH"], "no_such_option": 1})
    assert dropped == ["no_such_option"] and kwargs == {"add_leaf_bones": False, "object_types": {"MESH"}}


def test_refusals(tmp):
    crate = fixtures.crate()
    assert "out_dir" in _refused(export.export_asset, crate)
    _refused(export.export_asset, crate, engine="frostbite", out_dir=str(tmp))
    _refused(export.export_asset, "SM_Missing", out_dir=str(tmp))
    _refused(export.export_asset, [], out_dir=str(tmp))
    hidden = bpy.data.collections.new("Hidden")
    bpy.context.scene.collection.children.link(hidden)
    hidden.objects.link(crate)
    bpy.context.scene.collection.objects.unlink(crate)
    hidden.hide_viewport = True
    assert "hidden by their collection" in _refused(export.export_asset, crate, out_dir=str(tmp))
    assert os.listdir(tmp) == []
