import math

import bmesh
import bpy
from mathutils import Matrix

import fixtures
from forge import util, validate

ENGINES = ("unity", "unreal", "godot", "generic")
DATA = ("objects", "meshes", "materials", "images", "node_groups", "scenes", "collections")
CRATE_IDS = {"tris", "materials", "rotation", "scale", "pivot", "ngons", "non_manifold", "loose_verts", "normals",
             "uv_missing", "uv_degenerate", "uv_overlap", "uv_bounds", "texel_density", "name", "collision_naming",
             "real_world_scale", "texture_resolution", "missing_images"}


def _checks(result):
    return {c["id"]: c for c in result["checks"]}


def _icosphere(name, subdivisions):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdivisions, radius=0.5)
    obj = util.new_mesh_object(name, bm)
    bm.free()
    return obj


def _image_node(obj, image):
    node = obj.data.materials[0].node_tree.nodes.new("ShaderNodeTexImage")
    node.image = image
    return node


def test_crate_passes_every_check_except_texel_density_at_the_budget_texture_size():
    fixtures.crate()
    result = validate.validate_asset("SM_Crate", engine="unity", platform="pc", asset_class="prop_small")
    checks = _checks(result)
    assert set(checks) == CRATE_IDS
    assert {k: c["status"] for k, c in checks.items() if c["status"] != "pass"} == {"texel_density": "warn"}
    assert checks["texel_density"]["measured"] == 256.0 and checks["texel_density"]["limit"] == [384.0, 640.0]
    assert result["passed"] is True and result["summary"]["fail"] == 0 and result["summary"]["pass"] == 18
    assert (checks["tris"]["measured"], checks["tris"]["limit"]) == (12, 1500)
    assert checks["pivot"]["measured"] == 0.0 and checks["real_world_scale"]["measured"] == 1.0
    assert checks["uv_overlap"]["measured"] == 0.0 and checks["uv_bounds"]["measured"] == 0.0
    assert checks["normals"]["measured"] == {"inconsistent_edges": 0, "inside_out": False}


def test_bad_asset_fails_every_planted_fault_and_is_left_untouched():
    bad = fixtures.bad_asset()
    bpy.context.view_layer.update()
    before = ({k: len(getattr(bpy.data, k)) for k in DATA}, bad.matrix_world.copy(), len(bad.data.vertices),
              len(bad.data.polygons), bad.name, bad.data.name)
    result = validate.validate_asset(bad)
    checks = _checks(result)
    planted = ("name", "scale", "ngons", "loose_verts", "normals", "uv_degenerate", "materials", "missing_images")
    for check_id in planted:
        assert checks[check_id]["status"] == "fail" and checks[check_id]["hint"], checks[check_id]
    assert result["passed"] is False and set(planted) <= set(result["summary"]["failed"])
    assert checks["name"]["measured"] == "crate final" and checks["scale"]["measured"] == [2.0, 1.0, 1.0]
    assert checks["ngons"]["measured"] == 1 and checks["loose_verts"]["measured"] == 1
    assert checks["normals"]["measured"] == {"inconsistent_edges": 4, "inside_out": False}
    assert checks["uv_degenerate"]["measured"] == 7
    assert (checks["materials"]["measured"], checks["materials"]["limit"]) == (5, 2)
    assert checks["missing_images"]["measured"] == ["missing_tex"]
    assert checks["non_manifold"]["status"] == "warn" and checks["non_manifold"]["measured"]["boundary"] == 5
    after = ({k: len(getattr(bpy.data, k)) for k in DATA}, bad.matrix_world.copy(), len(bad.data.vertices),
             len(bad.data.polygons), bad.name, bad.data.name)
    assert after == before


def test_each_engine_mesh_naming():
    crate = fixtures.crate()
    for name, passing in (("SM_Crate", set(ENGINES)), ("SK_Hero_Body", set(ENGINES)), ("crate", {"godot", "generic"}),
                          ("SM_crate", {"godot", "generic"}), ("crate final", set()), ("SM-Crate", set())):
        crate.name = name
        for engine in ENGINES:
            check = _checks(validate.validate_asset(crate, engine=engine, asset_class="prop_small"))["name"]
            assert check["status"] == ("pass" if engine in passing else "fail"), (name, engine, check)


def test_each_engine_collision_naming():
    crate = fixtures.crate()
    names = {e: util.load_preset("engines", e)["naming"]["collision"]["convex"].format(name="SM_Crate", nn="00")
             for e in ENGINES}
    assert len(set(names.values())) == len(ENGINES)
    for i, name in enumerate(names.values()):
        collider = fixtures.crate(name, size=0.9)
        if i % 2:
            collider.parent = crate
    fixtures.crate("SM_Crate_Color")
    for engine in ENGINES:
        check = _checks(validate.validate_asset(crate, engine=engine, asset_class="prop_small"))["collision_naming"]
        assert check["status"] == "fail" and check["measured"]["named"] == [names[engine]], (engine, check)
        assert sorted(check["measured"]["misnamed"]) == sorted(n for e, n in names.items() if e != engine), engine
    for name in names.values():
        bpy.data.objects.remove(bpy.data.objects[name])
    check = _checks(validate.validate_asset(crate, asset_class="prop_small"))["collision_naming"]
    assert check["status"] == "pass" and check["measured"] == {"named": [], "misnamed": []}


def test_pivot_rules_bottom_center_and_world_origin():
    crate = fixtures.crate()
    crate.location = (5.0, 0.0, 0.0)
    bpy.context.view_layer.update()
    unity = _checks(validate.validate_asset(crate, engine="unity", asset_class="prop_small"))["pivot"]
    unreal = _checks(validate.validate_asset(crate, engine="unreal", asset_class="prop_small"))["pivot"]
    assert unity["status"] == "pass" and (unreal["status"], unreal["measured"]) == ("fail", 5.0)
    crate.location = (0.0, 0.0, 0.0)
    crate.data.transform(Matrix.Translation((0.0, 0.0, 0.5)))
    bpy.context.view_layer.update()
    unity = _checks(validate.validate_asset(crate, engine="unity", asset_class="prop_small"))["pivot"]
    unreal = _checks(validate.validate_asset(crate, engine="unreal", asset_class="prop_small"))["pivot"]
    assert (unity["status"], unity["measured"]) == ("fail", 0.5) and unreal["status"] == "pass"


def test_rotation_and_mirrored_scale():
    crate = fixtures.crate()
    crate.rotation_euler = (0.0, 0.0, math.radians(30))
    bpy.context.view_layer.update()
    checks = _checks(validate.validate_asset(crate, asset_class="prop_small"))
    assert checks["rotation"]["status"] == "fail" and abs(checks["rotation"]["measured"] - 30) < 1e-3
    assert checks["scale"]["status"] == "pass"
    crate.rotation_euler = (0.0, 0.0, 0.0)
    crate.scale = (-1.0, 1.0, 1.0)
    bpy.context.view_layer.update()
    checks = _checks(validate.validate_asset(crate, asset_class="prop_small"))
    assert checks["rotation"]["status"] == "pass" and checks["scale"]["status"] == "fail"
    assert "negative" in checks["scale"]["hint"] and checks["normals"]["measured"]["inside_out"] is True


def test_inside_out_mesh_fails_normals():
    crate = fixtures.crate()
    with util.edit_bmesh(crate) as bm:
        for face in bm.faces:
            face.normal_flip()
    check = _checks(validate.validate_asset(crate, asset_class="prop_small"))["normals"]
    assert check["status"] == "fail" and check["measured"] == {"inconsistent_edges": 0, "inside_out": True}


def test_lod_children_get_the_budget_times_their_ratio():
    crate = fixtures.crate("SM_Crate_LOD0")
    _icosphere("SM_Crate_LOD1", 4)
    fixtures.crate("SM_Crate_LOD2")
    fixtures.crate("SM_Crate_LOD5")
    fixtures.rock_blockout("SM_Other_LOD1")
    checks = _checks(validate.validate_asset(crate, platform="pc", asset_class="prop_small"))
    assert {k for k in checks if k.startswith("tris_lod")} == {"tris_lod1", "tris_lod2", "tris_lod5"}
    assert (checks["tris_lod1"]["status"], checks["tris_lod1"]["measured"], checks["tris_lod1"]["limit"]) == \
        ("fail", 1280, 750)
    assert (checks["tris_lod2"]["status"], checks["tris_lod2"]["limit"]) == ("pass", 375)
    assert checks["tris_lod5"]["status"] == "warn" and checks["name"]["status"] == "pass"


def test_uv_overlap_and_bounds_warn_without_failing():
    crate = fixtures.crate()
    uv = crate.data.uv_layers.active.data
    first, second = crate.data.polygons[0], crate.data.polygons[1]
    for dst, src in zip(second.loop_indices, first.loop_indices):
        uv[dst].uv = uv[src].uv
    result = validate.validate_asset(crate, asset_class="prop_small")
    check = _checks(result)["uv_overlap"]
    assert check["status"] == "warn" and abs(check["measured"] - 0.2) < 1e-3 and "mirrored" in check["hint"]
    assert result["passed"] is True
    for i in crate.data.polygons[2].loop_indices:
        uv[i].uv.x += 1.0
    check = _checks(validate.validate_asset(crate, asset_class="prop_small"))["uv_bounds"]
    assert check["status"] == "warn" and 0.1 < check["measured"] < 0.2


def test_texel_density_uses_the_material_image_and_texture_budget():
    crate = fixtures.crate()
    image = bpy.data.images.new("T_Crate_BaseColor", 2048, 2048)
    _image_node(crate, image)
    checks = _checks(validate.validate_asset(crate, asset_class="prop_small"))
    assert (checks["texel_density"]["status"], checks["texel_density"]["measured"]) == ("pass", 512.0)
    assert (checks["texture_resolution"]["status"], checks["texture_resolution"]["measured"]) == ("fail", 2048)
    assert _checks(validate.validate_asset(crate, asset_class="prop_medium"))["texture_resolution"]["status"] == "pass"


def test_overrides_deep_merge_over_the_budget():
    crate = fixtures.crate()
    result = validate.validate_asset(crate, asset_class="prop_small", overrides={"texture_max_px": {"prop_small": 2048}})
    assert all(c["status"] == "pass" for c in result["checks"]), [c for c in result["checks"] if c["status"] != "pass"]
    assert _checks(result)["texture_resolution"]["limit"] == 2048
    small = _checks(validate.validate_asset(crate, asset_class="prop_small", overrides={"tris": {"prop_small": 10}}))
    medium = _checks(validate.validate_asset(crate, asset_class="prop_medium", overrides={"tris": {"prop_small": 10}}))
    assert (small["tris"]["status"], small["tris"]["limit"]) == ("fail", 10)
    assert (medium["tris"]["status"], medium["tris"]["limit"]) == ("pass", 5000) and medium["materials"]["limit"] == 2


def test_missing_images_pass_when_packed(tmp):
    crate = fixtures.crate()
    for name in ("a.png", "b.png", "c.png"):
        image = bpy.data.images.new(name, 8, 8)
        image.filepath_raw = str(tmp / name)
        image.file_format = "PNG"
        image.save()
        bpy.data.images.remove(image)
    packed = bpy.data.images.load(str(tmp / "a.png"))
    packed.pack()
    group = bpy.data.node_groups.new("NG_Tex", "ShaderNodeTree")
    group.nodes.new("ShaderNodeTexImage").image = bpy.data.images.load(str(tmp / "b.png"))
    crate.data.materials[0].node_tree.nodes.new("ShaderNodeGroup").node_tree = group
    _image_node(crate, packed)
    second = bpy.data.materials.new("M_Crate_Trim")
    second.node_tree.nodes.new("ShaderNodeTexImage").image = bpy.data.images.load(str(tmp / "c.png"))
    crate.data.materials.append(second)
    assert _checks(validate.validate_asset(crate, asset_class="prop_small"))["missing_images"]["status"] == "pass"
    for name in ("a.png", "b.png", "c.png"):
        (tmp / name).unlink()
    check = _checks(validate.validate_asset(crate, asset_class="prop_small"))["missing_images"]
    assert (check["status"], check["measured"]) == ("fail", ["b.png", "c.png"])


def test_real_world_scale():
    crate = fixtures.crate()
    assert _checks(validate.validate_asset(crate, asset_class="prop_small", expected_size_m=1.2))[
        "real_world_scale"]["status"] == "pass"
    check = _checks(validate.validate_asset(crate, asset_class="prop_small", expected_size_m=2.0))["real_world_scale"]
    assert (check["status"], check["measured"], check["limit"]) == ("fail", 1.0, [1.5, 2.5])
    pebble = fixtures.crate("SM_Pebble", size=0.005)
    check = _checks(validate.validate_asset(pebble, asset_class="prop_small"))["real_world_scale"]
    assert (check["status"], check["measured"]) == ("warn", 0.005)


def test_refusals():
    fixtures.crate()
    empty = bpy.data.objects.new("Empty", None)
    bpy.context.scene.collection.objects.link(empty)
    for kwargs, needle in ((dict(obj="Empty"), "EMPTY"), (dict(obj="Nope"), "Nope"),
                           (dict(obj="SM_Crate", asset_class="spaceship"), "prop_small"),
                           (dict(obj="SM_Crate", engine="frostbite"), "unity"),
                           (dict(obj="SM_Crate", platform="switch"), "mobile"),
                           (dict(obj="SM_Crate", expected_size_m=-1), "expected_size_m")):
        try:
            validate.validate_asset(**kwargs)
        except util.ForgeError as exc:
            assert needle in str(exc), (kwargs, str(exc))
        else:
            raise AssertionError(f"accepted {kwargs}")


def test_mesh_without_uvs_fails_uv_missing_and_skips_the_uv_checks():
    rock = fixtures.rock_blockout()
    checks = _checks(validate.validate_asset(rock, asset_class="prop_small"))
    assert (checks["uv_missing"]["status"], checks["uv_missing"]["measured"]) == ("fail", 0)
    for check_id in ("uv_degenerate", "uv_overlap", "uv_bounds", "texel_density"):
        assert checks[check_id]["status"] == "warn" and checks[check_id]["measured"] is None, check_id
    assert (checks["tris"]["measured"], checks["non_manifold"]["status"], checks["normals"]["status"]) == \
        (320, "pass", "pass")



def test_collision_named_from_the_lod0_mesh_passes():
    from forge import collision, lod
    crate = fixtures.crate()
    lod.make_lod_chain(crate, ratios=[1.0, 0.5], engine="unity", protect=("boundary",))
    collision.make_collision(crate, kind="box", engine="unity")
    checks = {c["id"]: c for c in validate.validate_asset(crate, engine="unity", platform="pc", asset_class="prop_small")["checks"]}
    assert checks["collision_naming"]["status"] == "pass", checks["collision_naming"]
    assert checks["collision_naming"]["measured"]["named"] == ["SM_Crate_LOD0_Collider"]


def test_skinned_mesh_pivot_is_ground_inside_footprint_not_bbox_centre():
    rig, mesh, _ = fixtures.humanoid()
    mesh.location.y = 0.0
    checks = {c["id"]: c for c in validate.validate_asset(mesh, engine="unity", platform="pc", asset_class="character")["checks"]}
    assert checks["pivot"]["status"] == "pass", checks["pivot"]
    mesh.data.transform(Matrix.Translation((0, 0, 0.3)))
    checks = {c["id"]: c for c in validate.validate_asset(mesh, engine="unity", platform="pc", asset_class="character")["checks"]}
    assert checks["pivot"]["status"] == "fail", checks["pivot"]
