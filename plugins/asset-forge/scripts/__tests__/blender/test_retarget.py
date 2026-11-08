import math

import bpy
from bpy_extras import anim_utils
from mathutils import Vector

import fixtures
from forge import retarget as rt
from forge.util import ForgeError

FRAMES = range(1, 26)


def _refuses(fn, *args, needle="", **kwargs):
    try:
        fn(*args, **kwargs)
    except ForgeError as exc:
        assert needle in str(exc), f"{needle!r} not in {exc}"
    else:
        raise AssertionError(f"{fn.__name__} accepted {args} {kwargs}")


def _direction(rig, bone):
    return (rig.matrix_world.to_3x3() @ rig.pose.bones[bone].matrix.to_3x3()).col[1].normalized()


def _head(rig, bone):
    return rig.matrix_world @ rig.pose.bones[bone].head


def _angle_deg(a, b):
    return math.degrees(a.angle(b))


def _curves(act, rig):
    cb = anim_utils.action_get_channelbag_for_slot(act, rig.animation_data.action_slot)
    return list(cb.fcurves)


def _retargeted():
    target, mesh, source = fixtures.humanoid()
    out = rt.retarget(source, target, "mixamo_to_rigify")
    return target, source, bpy.data.actions[out["action"]], out


def test_bonemap_presets_load_and_refuse_bad_maps():
    for name, prefix in (("mixamo_to_rigify", "DEF-"), ("mixamo_to_ue5", "")):
        out = rt.load_bonemap(name)
        bm = out["bonemap"]
        targets = [e["target"] for e in bm["bones"].values()]
        assert out["pairs"] == 22 and len(set(targets)) == 22
        assert bm["root"]["source"] == "mixamorig:Hips" and bm["root"]["target"] in targets
        assert all(t.startswith(prefix) for t in targets) and bm["notes"]
    norm = rt.load_bonemap({"bones": {"a": {"target": "b", "roll_fix_deg": 90}},
                            "root": {"source": "r", "target": "s"}})
    assert norm["bonemap"]["bones"]["a"] == {"target": "b", "roll_fix_deg": 90.0, "axis_fix": None}
    assert norm["pairs"] == 2 and rt.load_bonemap(norm)["pairs"] == 2
    _refuses(rt.load_bonemap, {"bones": {"a": "x", "b": "x"}}, needle="several")
    _refuses(rt.load_bonemap, {"bones": {"a": {"roll_fix_deg": 3}}}, needle="target")
    _refuses(rt.load_bonemap, {"bones": {"a": {"target": "x", "axis_fix": [1, 2]}}}, needle="axis_fix")
    _refuses(rt.load_bonemap, {"bones": {}}, needle="non-empty")
    meshy = rt.load_bonemap("meshy_to_rigify")
    assert meshy["pairs"] == 22 and meshy["bonemap"]["root"] == {"source": "Hips", "target": "DEF-spine"}
    _refuses(rt.load_bonemap, "bvh_to_rigify", needle="mixamo_to_rigify")


def test_retarget_keys_every_mapped_bone_and_removes_its_constraints():
    target, mesh, source = fixtures.humanoid()
    bm = rt.load_bonemap("mixamo_to_rigify")["bonemap"]["bones"]
    expected = sorted(e["target"] for s, e in bm.items()
                      if s in source.pose.bones and e["target"] in target.pose.bones)
    assert len(expected) == len(fixtures.SKELETON)
    bpy.context.scene.frame_set(5)
    walk = source.animation_data.action
    out = rt.retarget(source, target, "mixamo_to_rigify")
    act = bpy.data.actions[out["action"]]
    assert out["keyed_bones"] == expected and out["frames"] == 25 and out["frame_range"] == [1, 25]
    assert target.animation_data.action == act and source.animation_data.action == walk
    assert bpy.context.scene.frame_current == 5
    curves = _curves(act, target)
    for bone in expected:
        rot = [fc for fc in curves if fc.data_path == f'pose.bones["{bone}"].rotation_quaternion']
        assert len(rot) == 4 and all(len(fc.keyframe_points) == 25 for fc in rot), bone
    assert all(len(pb.constraints) == 0 for pb in target.pose.bones)
    assert out["constraints_removed"] >= len(expected) + 2
    assert {s["source"] for s in out["skipped"]} == {
        "mixamorig:Spine1", "mixamorig:LeftShoulder", "mixamorig:RightShoulder",
        "mixamorig:LeftToeBase", "mixamorig:RightToeBase"}
    assert out["location_bones"] == ["DEF-spine"] and out["unmapped_source"] == [] and out["warnings"] == []
    again = rt.retarget(source, target, "mixamo_to_rigify")
    assert again["action"] == out["action"] and len(_curves(act, target)) == len(curves)


def test_retarget_matches_world_directions_and_hip_travel():
    target, source, act, out = _retargeted()
    assert out["rest_offset_deg"]["DEF-thigh.L"] < 1e-3
    shift = Vector((-2.0, 0.0, 0.0))
    worst = {"thigh": 0.0, "arm": 0.0, "hips_m": 0.0}
    swing = 0.0
    scene = bpy.context.scene
    for f in FRAMES:
        scene.frame_set(f)
        worst["thigh"] = max(worst["thigh"], _angle_deg(_direction(target, "DEF-thigh.L"),
                                                        _direction(source, "mixamorig:LeftUpLeg")))
        worst["arm"] = max(worst["arm"], _angle_deg(_direction(target, "DEF-upper_arm.L"),
                                                    _direction(source, "mixamorig:LeftArm")))
        hips_error = _head(target, "DEF-spine") - _head(source, "mixamorig:Hips") - shift
        worst["hips_m"] = max(worst["hips_m"], hips_error.length)
        swing = max(swing, _angle_deg(_direction(target, "DEF-thigh.L"), Vector((0, 0, -1))))
    assert swing > 25, f"thigh barely moved ({swing:.1f} deg); the check would be vacuous"
    assert worst["thigh"] < 5 and worst["arm"] < 5 and worst["hips_m"] < 1e-3, worst
    scene.frame_set(13)
    assert _angle_deg(_direction(target, "DEF-upper_arm.L"), Vector((1, 0, 0))) < 5, "A-pose arm not raised to T"


def test_retarget_corrects_a_rest_roll_difference():
    target, mesh, source = fixtures.humanoid()
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.mode_set(mode="EDIT")
    target.data.edit_bones["DEF-thigh.L"].roll += math.radians(90)
    bpy.ops.object.mode_set(mode="OBJECT")
    out = rt.retarget(source, target, "mixamo_to_rigify")
    assert abs(out["rest_offset_deg"]["DEF-thigh.L"] - 90) < 0.01
    bpy.context.scene.frame_set(1)
    pb = target.pose.bones["DEF-thigh.L"]
    twist = math.degrees(pb.matrix.to_quaternion().rotation_difference(pb.bone.matrix_local.to_quaternion()).angle)
    assert twist < 0.5, f"thigh twisted {twist:.2f} deg at the source's rest frame"
    for f in FRAMES:
        bpy.context.scene.frame_set(f)
        assert _angle_deg(_direction(target, "DEF-thigh.L"), _direction(source, "mixamorig:LeftUpLeg")) < 5


def test_retarget_refusals():
    target, mesh, source = fixtures.humanoid()
    _refuses(rt.retarget, source, mesh, "mixamo_to_rigify", needle="ARMATURE")
    _refuses(rt.retarget, source, source, "mixamo_to_rigify", needle="same")
    _refuses(rt.retarget, source, target, {"bones": {"nope": "DEF-spine"}}, needle="no bonemap pair")
    _refuses(rt.retarget, source, target, "mixamo_to_rigify", use_location_for=("tail",), needle="tail")
    _refuses(rt.retarget, target, source, "mixamo_to_rigify", needle="no active action")
    _refuses(rt.retarget, source, target, "mixamo_to_rigify", frame_range=(10, 2), needle="before start")
    assert all(len(pb.constraints) == 0 for pb in target.pose.bones)


def test_make_in_place_zeroes_horizontal_travel_and_keeps_bob():
    target, source, act, _ = _retargeted()
    scene = bpy.context.scene
    before = []
    for f in FRAMES:
        scene.frame_set(f)
        before.append(_head(target, "DEF-spine"))
    assert (before[-1] - before[0]).xy.length > 0.75
    out = rt.make_in_place(act, "DEF-spine")
    assert out["keys"] == 25 and abs(out["max_removed_m"] - 0.8) < 1e-3
    rest = target.matrix_world @ target.data.bones["DEF-spine"].head_local
    zs = []
    for f, old in zip(FRAMES, before):
        scene.frame_set(f)
        now = _head(target, "DEF-spine")
        assert (now.xy - rest.xy).length < 1e-4, (f, tuple(now))
        assert abs(now.z - old.z) < 1e-5
        zs.append(now.z)
    assert max(zs) - min(zs) > 0.03
    _refuses(rt.make_in_place, act, "DEF-spine", axes=("W",), needle="axes")
    _refuses(rt.make_in_place, act, "tail", needle="no bone")


def test_extract_root_motion_moves_travel_onto_a_new_root():
    target, source, act, _ = _retargeted()
    _refuses(rt.extract_root_motion, target, act, "DEF-spine", "root", needle="create=True")
    scene = bpy.context.scene
    before = []
    for f in FRAMES:
        scene.frame_set(f)
        before.append(_head(target, "DEF-spine"))
    active = bpy.context.view_layer.objects.active
    out = rt.extract_root_motion(target, act, "DEF-spine", "root", create=True)
    assert out["created"] and out["frames"] == 25 and abs(out["travel_m"] - 0.8) < 1e-3
    assert target.data.bones["DEF-spine"].parent.name == "root" and target.mode == "OBJECT"
    assert bpy.context.view_layer.objects.active == active
    for f, old in zip(FRAMES, before):
        scene.frame_set(f)
        hips, root = _head(target, "DEF-spine"), _head(target, "root")
        assert (hips - old).length < 1e-4, (f, tuple(hips), tuple(old))
        assert (hips.xy - root.xy).length < 1e-4 and abs(root.z) < 1e-6
    _refuses(rt.extract_root_motion, target, act, "DEF-spine", "DEF-thigh.L", needle="ancestor")
    _refuses(rt.extract_root_motion, target, act, "tail", "root", needle="no bone")


def test_loop_cleanup_matches_first_and_last_pose():
    target, source, act, _ = _retargeted()
    scene = bpy.context.scene

    def pose_at(frame):
        scene.frame_set(frame)
        return {pb.name: pb.matrix_basis.copy() for pb in target.pose.bones}

    def gap():
        first, last = pose_at(1), pose_at(25)
        return max(max(abs(a - b) for ra, rb in zip(first[n], last[n]) for a, b in zip(ra, rb)) for n in first)

    assert gap() > 0.5
    out = rt.loop_cleanup(act)
    assert out["curves_matched"] > 0 and out["cycles_added"] == out["curves"]
    curves = _curves(act, target)
    assert all(any(m.type == "CYCLES" for m in fc.modifiers) for fc in curves)
    with rt._modifiers_muted(curves):
        assert gap() < 1e-4
    _refuses(rt.loop_cleanup, act, blend_frames=-1, needle="blend_frames")

    travel = bpy.data.actions[rt.retarget(source, target, "mixamo_to_rigify")["action"]]
    rt.loop_cleanup(travel, travel_bones=["DEF-spine"])
    hips = [fc for fc in _curves(travel, target) if fc.data_path == 'pose.bones["DEF-spine"].location']
    assert all(m.mode_after == "REPEAT_OFFSET" for fc in hips for m in fc.modifiers)
    assert max(abs(fc.keyframe_points[-1].co.y - fc.keyframe_points[0].co.y) for fc in hips) > 0.75


def test_trim_shifts_the_clip_to_frame_zero():
    target, source, act, _ = _retargeted()
    scene = bpy.context.scene
    scene.frame_set(7)
    at7 = {pb.name: pb.matrix_basis.copy() for pb in target.pose.bones}
    scene.frame_set(19)
    at19 = {pb.name: pb.matrix_basis.copy() for pb in target.pose.bones}
    out = rt.trim(act, 7, 19)
    assert out["frame_range"] == [0.0, 12.0] and out["removed_keys"] > 0 and out["shifted_by"] == -7
    assert all(len(fc.keyframe_points) == 13 for fc in _curves(act, target))
    for frame, want in ((0, at7), (12, at19)):
        scene.frame_set(frame)
        for name, m in want.items():
            got = target.pose.bones[name].matrix_basis
            assert max(abs(a - b) for ra, rb in zip(got, m) for a, b in zip(ra, rb)) < 1e-5, (frame, name)
    _refuses(rt.trim, act, 5, 5, needle="end > start")


def test_push_to_nla_names_per_unity_and_godot():
    target, source, act, _ = _retargeted()
    slot = target.animation_data.action_slot
    out = rt.push_to_nla(target, act, engine="unity", asset="Hero", clip="Walk")
    ad = target.animation_data
    assert out["action"] == act.name == "Hero@Walk" and out["track"] == "Hero@Walk" and not out["loop"]
    assert len(ad.nla_tracks) == 1 and ad.nla_tracks[0].strips[0].action == act and ad.action is None
    assert ad.nla_tracks[0].strips[0].action_slot == slot and out["frame_start"] == 1
    rt.push_to_nla(target, act, engine="unity", asset="Hero", clip="Walk")
    assert len(ad.nla_tracks) == 1 and len(ad.nla_tracks[0].strips) == 1

    looped = bpy.data.actions[rt.retarget(source, target, "mixamo_to_rigify")["action"]]
    rt.loop_cleanup(looped)
    out = rt.push_to_nla(target, looped, engine="godot", clip="Walk")
    assert out["action"] == "Walk-loop" and out["loop"] and len(ad.nla_tracks) == 2
    once = bpy.data.actions[rt.retarget(source, target, "mixamo_to_rigify")["action"]]
    assert rt.push_to_nla(target, once, engine="godot", clip="Turn")["action"] == "Turn"
    clash = bpy.data.actions[rt.retarget(source, target, "mixamo_to_rigify")["action"]]
    _refuses(rt.push_to_nla, target, clash, engine="godot", clip="Turn", needle="already named")
    _refuses(rt.push_to_nla, target, clash, engine="frostbite", needle="unity")


def test_retarget_keeps_user_constraints_and_the_previous_action():
    target, mesh, source = fixtures.humanoid()
    own = target.pose.bones["DEF-shin.L"].constraints.new("LIMIT_ROTATION")
    old = bpy.data.actions.new("Hero_Idle")
    target.animation_data_create().action = old
    out = rt.retarget(source, target, "mixamo_to_rigify")
    assert [c.name for c in target.pose.bones["DEF-shin.L"].constraints] == [own.name]
    assert sum(len(pb.constraints) for pb in target.pose.bones) == 1
    assert any(w.startswith("DEF-shin.L: 1 constraint") for w in out["warnings"])
    assert old.use_fake_user and any("Hero_Idle" in w for w in out["warnings"])


def test_retarget_applies_a_bonemap_roll_fix():
    target, mesh, source = fixtures.humanoid()
    bm = rt.load_bonemap("mixamo_to_rigify")["bonemap"]
    bm["bones"]["mixamorig:LeftUpLeg"]["roll_fix_deg"] = 30.0
    out = rt.retarget(source, target, bm)
    assert abs(out["rest_offset_deg"]["DEF-thigh.L"] - 30) < 0.01
    bpy.context.scene.frame_set(1)
    pb = target.pose.bones["DEF-thigh.L"]
    twist = pb.matrix.to_quaternion().rotation_difference(pb.bone.matrix_local.to_quaternion())
    assert abs(math.degrees(twist.angle) - 30) < 0.5
    assert _angle_deg(_direction(target, "DEF-thigh.L"), _direction(source, "mixamorig:LeftUpLeg")) < 0.5
