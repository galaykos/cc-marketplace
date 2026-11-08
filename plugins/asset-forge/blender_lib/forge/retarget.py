"""Retarget a clip from one armature onto another through a bonemap, then shape it for an engine: in place, root
motion, loop, trim, NLA naming. Frames are scene frames; locations are Blender units (metres at Unit Scale 1.0);
bonemap angles are degrees. Blender 5.x Actions keep F-curves in a channelbag per slot, read through anim_utils."""
import math
import re
import string
from collections import defaultdict
from contextlib import contextmanager

import bpy
from bpy_extras import anim_utils
from mathutils import Euler, Matrix, Quaternion, Vector

from . import util
from .util import ForgeError, ok

TAG = "forge_retarget"
AXES = {"X": 0, "Y": 1, "Z": 2}


def load_bonemap(name_or_dict):
    """Load presets/bonemaps/<name>.json, or check a dict of the same shape (or a load_bonemap result).
    Each bone entry becomes {"target", "roll_fix_deg", "axis_fix"}: roll_fix_deg twists the target bone about its own
    Y axis, axis_fix is an XYZ Euler in degrees in the target bone's frame (or None); both apply on top of the
    rest-orientation offset retarget computes itself. The root pair is added to the bones when absent.
    Returns ok(name, bonemap, pairs)."""
    if isinstance(name_or_dict, str):
        raw, label = util.load_preset("bonemaps", name_or_dict), name_or_dict
    elif isinstance(name_or_dict, dict):
        raw = name_or_dict["bonemap"] if name_or_dict.get("ok") and "bonemap" in name_or_dict else name_or_dict
        label = name_or_dict.get("name", "<dict>")
    else:
        raise ForgeError(f"bonemap must be a preset name or a dict, not {type(name_or_dict).__name__}")
    bones = raw.get("bones")
    if not isinstance(bones, dict) or not bones:
        raise ForgeError(f"bonemap {label}: 'bones' must be a non-empty object of source bone -> target bone")
    norm = {}
    for src, entry in bones.items():
        entry = {"target": entry} if isinstance(entry, str) else entry
        if not isinstance(entry, dict) or not isinstance(entry.get("target"), str) or not entry["target"]:
            raise ForgeError(f"bonemap {label}: {src!r} needs a target bone name")
        roll = entry.get("roll_fix_deg") or 0
        axis = entry.get("axis_fix")
        if not isinstance(roll, (int, float)):
            raise ForgeError(f"bonemap {label}: {src!r} roll_fix_deg must be a number of degrees")
        if axis is not None and (not isinstance(axis, (list, tuple)) or len(axis) != 3
                                 or not all(isinstance(a, (int, float)) for a in axis)):
            raise ForgeError(f"bonemap {label}: {src!r} axis_fix must be null or [x, y, z] degrees")
        norm[src] = {"target": entry["target"], "roll_fix_deg": float(roll),
                     "axis_fix": [float(a) for a in axis] if axis is not None else None}
    root = raw.get("root")
    if root is not None:
        if not (isinstance(root, dict) and isinstance(root.get("source"), str) and isinstance(root.get("target"), str)):
            raise ForgeError(f"bonemap {label}: root must be {{'source': ..., 'target': ...}}")
        if root["source"] in norm and norm[root["source"]]["target"] != root["target"]:
            raise ForgeError(f"bonemap {label}: root maps {root['source']} to {root['target']}, bones map it to "
                             f"{norm[root['source']]['target']}")
        norm.setdefault(root["source"], {"target": root["target"], "roll_fix_deg": 0.0, "axis_fix": None})
        root = {"source": root["source"], "target": root["target"]}
    targets = [e["target"] for e in norm.values()]
    doubled = sorted({t for t in targets if targets.count(t) > 1})
    if doubled:
        raise ForgeError(f"bonemap {label}: several source bones map onto {doubled}")
    bonemap = {"source": raw.get("source"), "target": raw.get("target"), "root": root, "bones": norm,
               "notes": list(raw.get("notes", []))}
    return ok(name=label, bonemap=bonemap, pairs=len(norm))


def retarget(source_rig, target_rig, bonemap, action=None, frame_range=None, use_location_for=("root",)):
    """Bake `action` (default: the source's active action) from source_rig onto target_rig through `bonemap`.
    Each mapped target bone copies its source bone's world rotation times the rest-orientation offset between the
    two bones, so bones point the same way in world space even when the rest poses differ (A-pose vs T-pose).
    Bones in use_location_for ("root" = the bonemap root pair, or a source/target bone name) also copy the source
    bone's world travel from its rest position, in metres, unscaled. Temporary constraints do the mapping; the pose
    is baked with visual keying, one key per whole frame over frame_range (default: the action's range), into the
    action "<target>_<action>", which becomes the target's active action; the constraints are removed. An existing
    action of that name keeps its users and gets the new keys only once the bake succeeds: a failed bake leaves the
    target's action as it was. Pairs with a bone missing on either rig are skipped and listed.
    Returns ok(action, frame_range, frames, keyed_bones, skipped, unmapped_source, unmapped_target,
    rest_offset_deg, location_bones, constraints_removed, warnings)."""
    src = util.get_object(source_rig, "ARMATURE")
    tgt = util.get_object(target_rig, "ARMATURE")
    if src == tgt:
        raise ForgeError("source and target are the same armature")
    for rig in (src, tgt):
        if rig.mode == "EDIT":
            raise ForgeError(f"{rig.name} is in Edit Mode; leave it before retargeting")
    bm = load_bonemap(bonemap)["bonemap"]
    clip = _action(action) if action is not None else (src.animation_data.action if src.animation_data else None)
    if clip is None:
        raise ForgeError(f"{src.name} has no active action; pass action=")
    start, end = _frames(clip, frame_range)
    pairs, skipped = _pairs(bm, src, tgt)
    loc_sources = _location_sources(bm, use_location_for)

    bpy.context.view_layer.update()
    mapped = [t for _, t, _ in pairs]
    warnings = [f"{t}: {n} constraint(s) of its own override the baked keys; bake onto a deform-only skeleton "
                f"or mute them" for t in mapped
                if (n := sum(1 for c in tgt.pose.bones[t].constraints
                             if not c.name.startswith(TAG) and c.enabled and c.influence > 0))]
    _remove_constraints(tgt)
    scene = bpy.context.scene
    frame_back = scene.frame_current
    src_ad = src.animation_data_create()
    src_before = (src_ad.action, src_ad.action_slot)
    selection = {pb.name: pb.select for pb in tgt.pose.bones}
    try:
        if src_ad.action != clip:
            src_ad.action = clip
            if src_ad.action_slot is None:
                src_ad.action_slot = _slot_for(clip, src)
        rest_offsets, location_bones = _add_constraints(src, tgt, pairs, loc_sources)
        for pb in tgt.pose.bones:
            pb.select = pb.name in mapped
        out, kept = _bake_clip(tgt, f"{tgt.name}_{clip.name}", clip, range(start, end + 1))
    finally:
        removed = _remove_constraints(tgt)
        for pb in tgt.pose.bones:
            pb.select = selection.get(pb.name, False)
        if src_ad.action != src_before[0]:
            src_ad.action = src_before[0]
            if src_before[0] is not None:
                src_ad.action_slot = src_before[1]
        scene.frame_set(frame_back)

    cb = _channelbag(out, tgt)
    keyed = sorted({b for b in (_bone_of(fc.data_path) for fc in cb.fcurves) if b})
    src_cb = anim_utils.action_get_channelbag_for_slot(clip, _slot_for(clip, src))
    animated = {b for b in (_bone_of(fc.data_path) for fc in (src_cb.fcurves if src_cb else ())) if b}
    paired = {s for s, _, _ in pairs}
    if kept:
        warnings.append(f"{tgt.name}'s previous action {kept} was kept with a fake user")
    return ok(action=out.name, source=src.name, target=tgt.name, frame_range=[start, end], frames=end - start + 1,
              keyed_bones=keyed, skipped=skipped, unmapped_source=sorted(animated - paired),
              unmapped_target=sorted(b.name for b in tgt.data.bones if b.use_deform and b.name not in mapped),
              rest_offset_deg=rest_offsets, location_bones=location_bones, constraints_removed=removed,
              warnings=warnings)


def _pairs(bm, src, tgt):
    """[(source bone, target bone, entry)] for the bonemap pairs with both bones present, and the skipped ones."""
    pairs, skipped = [], []
    for s_name, entry in bm["bones"].items():
        missing = [side for side, rig, name in (("source", src, s_name), ("target", tgt, entry["target"]))
                   if name not in rig.pose.bones]
        if missing:
            skipped.append({"source": s_name, "target": entry["target"], "missing": missing})
        else:
            pairs.append((s_name, entry["target"], entry))
    if not pairs:
        raise ForgeError(f"no bonemap pair has both bones on {src.name} and {tgt.name}")
    return pairs, skipped


def _location_sources(bm, use_location_for):
    by_target = {e["target"]: s for s, e in bm["bones"].items()}
    sources = set()
    for key in use_location_for:
        if key == "root":
            if bm["root"] is None:
                raise ForgeError("use_location_for names 'root' but the bonemap has no root pair")
            sources.add(bm["root"]["source"])
        elif key in bm["bones"] or key in by_target:
            sources.add(key if key in bm["bones"] else by_target[key])
        else:
            raise ForgeError(f"use_location_for: {key!r} is not 'root' or a bone in the bonemap")
    return sources


def _add_constraints(src, tgt, pairs, loc_sources):
    """Constrain each target bone to its source bone (rotation, plus location for loc_sources) with the rest offset.
    Returns ({target bone: rest offset in degrees}, [target bones that copy location])."""
    rest_offsets, location_bones = {}, []
    for s_name, t_name, entry in pairs:
        pb = tgt.pose.bones[t_name]
        offset = _rest_offset(src, s_name, tgt, t_name, entry)
        rest_offsets[t_name] = round(math.degrees(offset.angle), 3)
        if s_name in loc_sources:
            _constraint(pb, "COPY_LOCATION", "loc", src, s_name)
            shift = tgt.matrix_world @ pb.bone.head_local - src.matrix_world @ src.data.bones[s_name].head_local
            _constant(pb, "LOCATION", shift, src)
            location_bones.append(t_name)
        con = _constraint(pb, "COPY_ROTATION", "rot", src, s_name)
        con.mix_mode = "REPLACE"
        if offset.angle > 1e-6:
            _constant(pb, "ROTATION", offset.to_euler("XYZ"), src)
    return rest_offsets, location_bones


def _bake_clip(tgt, name, clip, frames):
    """Visual-key tgt's selected bones over `frames` into a new action, active on tgt; on success an existing action
    `name` (never the source `clip`) takes the keys instead and keeps its users. A failure restores tgt's action and
    leaves the existing one untouched. Returns (action, name of a previous action given a fake user, or None)."""
    ad = tgt.animation_data_create()
    before = (ad.action, ad.action_slot)
    reuse = bpy.data.actions.get(name)
    if reuse == clip:
        reuse = None
    prev = before[0]
    orphan = prev if prev is not None and prev != reuse and prev.users == 1 and not prev.use_fake_user else None
    out = bpy.data.actions.new(name)
    try:
        ad.action = out
        if ad.action_slot is None:
            ad.action_slot = out.slots.new(id_type="OBJECT", name=tgt.name)
        options = anim_utils.BakeOptions(
            only_selected=True, do_pose=True, do_object=False, do_visual_keying=True, do_constraint_clear=False,
            do_parents_clear=False, do_clean=False, do_location=True, do_rotation=True, do_scale=False,
            do_bbone=False, do_custom_props=False)
        anim_utils.bake_action(tgt, action=out, frames=frames, bake_options=options)
    except BaseException:
        ad.action = before[0]
        if before[0] is not None:
            ad.action_slot = before[1]
        bpy.data.actions.remove(out)
        raise
    if orphan is not None:
        orphan.use_fake_user = True
    if reuse is not None:
        _move_keys(out, reuse, tgt)
        out = reuse
    return out, orphan.name if orphan is not None else None


def _move_keys(src, dst, obj):
    """Replace every F-curve of `dst` with obj's baked curves from `src`, make `dst` obj's action, remove `src`."""
    baked = _channelbag(src, obj)
    for cb in _channelbags(dst):
        cb.fcurves.clear()
    ad = obj.animation_data
    ad.action = dst
    if ad.action_slot is None:
        ad.action_slot = _slot_for(dst, obj) or dst.slots.new(id_type="OBJECT", name=obj.name)
    into = anim_utils.action_ensure_channelbag_for_slot(dst, ad.action_slot)
    for fc in baked.fcurves:
        copy = into.fcurves.ensure(fc.data_path, index=fc.array_index, group_name=fc.group.name if fc.group else "")
        copy.keyframe_points.add(len(fc.keyframe_points))
        for kp, key in zip(copy.keyframe_points, fc.keyframe_points):
            kp.co, kp.interpolation = key.co, key.interpolation
            kp.handle_left_type, kp.handle_right_type = key.handle_left_type, key.handle_right_type
            kp.handle_left, kp.handle_right = key.handle_left, key.handle_right
        copy.update()
    bpy.data.actions.remove(src)


def make_in_place(action, root_bone, axes=("X", "Y"), rig=None):
    """Zero root_bone's travel along the world `axes` (default the horizontal pair; Blender is Z-up) and keep the
    others, such as the vertical bob. Edits the bone's location keys, read through its rest orientation (a posed
    parent's rotation is ignored). rig defaults to the one armature that uses the action.
    Returns ok(action, bone, keys, max_removed_m)."""
    act = _action(action)
    rig = _rig_for(act, rig)
    bone = rig.data.bones.get(root_bone)
    if bone is None:
        raise ForgeError(f"{rig.name} has no bone {root_bone!r}")
    if not axes or any(a not in AXES for a in axes):
        raise ForgeError(f"axes must be a non-empty subset of {sorted(AXES)}, got {axes!r}")
    cb = _channelbag(act, rig)
    bpy.context.view_layer.update()
    path = rig.pose.bones[root_bone].path_from_id("location")
    curves = [cb.fcurves.find(path, index=i) for i in range(3)]
    if not any(curves):
        raise ForgeError(f"{act.name} has no location keys on {root_bone}")
    to_world = rig.matrix_world.to_3x3() @ bone.matrix_local.to_3x3()
    from_world = to_world.inverted()
    frames = sorted({kp.co.x for fc in curves if fc for kp in fc.keyframe_points})
    rows, removed = [], 0.0
    with _modifiers_muted(fc for fc in curves if fc):
        for f in frames:
            world = to_world @ Vector([fc.evaluate(f) if fc else 0.0 for fc in curves])
            removed = max(removed, math.sqrt(sum(world[AXES[a]] ** 2 for a in axes)))
            for a in axes:
                world[AXES[a]] = 0.0
            rows.append((f, from_world @ world))
    for i in range(3):
        if curves[i] is None and all(abs(v[i]) < 1e-9 for _, v in rows):
            continue
        fc = curves[i] or cb.fcurves.ensure(path, index=i, group_name=root_bone)
        for f, v in rows:
            fc.keyframe_points.insert(f, v[i], options={"FAST"})
        fc.update()
    return ok(action=act.name, bone=root_bone, keys=len(rows), max_removed_m=round(removed, 6))


def extract_root_motion(rig, action, hips_bone, root_bone, create=False):
    """Move the hips' horizontal (world X/Y) travel, in metres, onto root_bone: per whole frame of the action, the
    root gains the hips' horizontal offset from where the root carries the hips' rest position, and the hips lose
    it, so the hips' world path is unchanged. Turning stays on the hips. root_bone must be a parentless ancestor of
    the hips; create=True adds it at the armature origin (pointing +Y, non-deforming) and parents every root bone
    to it. Returns ok(action, root, hips, created, frames, travel_m)."""
    rig = util.get_object(rig, "ARMATURE")
    act = _action(action)
    if hips_bone not in rig.data.bones:
        raise ForgeError(f"{rig.name} has no bone {hips_bone!r}")
    created = False
    if root_bone not in rig.data.bones:
        if not create:
            raise ForgeError(f"{rig.name} has no bone {root_bone!r}; pass create=True to add one at the origin")
        _add_root(rig, root_bone)
        created = True
    root, hips = rig.data.bones[root_bone], rig.data.bones[hips_bone]
    if root.parent is not None or root not in hips.parent_recursive:
        raise ForgeError(f"{root_bone} must be a parentless ancestor of {hips_bone} to carry its motion")
    start, end = _frames(act, None)
    bpy.context.view_layer.update()
    world = rig.matrix_world.copy()
    world3_inv = world.to_3x3().inverted()
    root_rest3_inv = root.matrix_local.to_3x3().inverted()
    rel = hips.parent.matrix_local.inverted() @ hips.matrix_local
    scene = bpy.context.scene
    frame_back = scene.frame_current
    samples = []
    with _playing(rig, act):
        for f in range(start, end + 1):
            scene.frame_set(f)
            pbr, pbh = rig.pose.bones[root_bone], rig.pose.bones[hips_bone]
            carried = world @ (pbr.matrix @ root.matrix_local.inverted() @ hips.head_local)
            d = world @ pbh.head - carried
            d.z = 0.0
            d_arm = world3_inv @ d
            hips_frame = (pbh.parent.matrix @ rel).to_3x3()
            samples.append((f, pbr.location + root_rest3_inv @ d_arm, pbh.location - hips_frame.inverted() @ d_arm))
    scene.frame_set(frame_back)
    cb = _channelbag(act, rig)
    for bone_name, column in ((root_bone, 1), (hips_bone, 2)):
        path = rig.pose.bones[bone_name].path_from_id("location")
        for i in range(3):
            fc = cb.fcurves.ensure(path, index=i, group_name=bone_name)
            for row in samples:
                fc.keyframe_points.insert(row[0], row[column][i], options={"FAST"})
            fc.update()
    first = world @ (root.matrix_local @ Matrix.Translation(samples[0][1])).translation
    last = world @ (root.matrix_local @ Matrix.Translation(samples[-1][1])).translation
    return ok(action=act.name, root=root_bone, hips=hips_bone, created=created, frames=len(samples),
              travel_m=round((last - first).length, 6))


def loop_cleanup(action, blend_frames=2, travel_bones=()):
    """Make the action's last frame equal its first and add a Cycles modifier to every F-curve. The gap between them
    is spread linearly over the last blend_frames frames (0: only the last key moves). Location curves of
    travel_bones keep their travel and cycle with offset (REPEAT_OFFSET), for a root-motion clip.
    Returns ok(action, frame_range, curves, curves_matched, max_fix, cycles_added)."""
    act = _action(action)
    if not isinstance(blend_frames, (int, float)) or blend_frames < 0:
        raise ForgeError("blend_frames must be a number of frames >= 0")
    start, end = act.frame_range
    if end - start < 1:
        raise ForgeError(f"{act.name} spans {end - start:g} frames; nothing to loop")
    curves = [fc for cb in _channelbags(act) for fc in cb.fcurves]
    if not curves:
        raise ForgeError(f"{act.name} has no F-curves")
    travel = {f'pose.bones["{bpy.utils.escape_identifier(b)}"].location' for b in travel_bones}
    by_path = defaultdict(dict)
    for fc in curves:
        by_path[fc.data_path][fc.array_index] = fc

    def weight(frame):
        if blend_frames == 0:
            return 1.0 if frame >= end - 1e-4 else 0.0
        return min(1.0, max(0.0, (frame - (end - blend_frames)) / blend_frames))

    matched, max_fix, cycles_added = 0, 0.0, 0
    for path, chans in by_path.items():
        if path not in travel:
            with _modifiers_muted(chans.values()):
                first = {i: fc.evaluate(start) for i, fc in chans.items()}
                last = {i: fc.evaluate(end) for i, fc in chans.items()}
            goal = first
            if path.endswith("rotation_quaternion") and len(chans) == 4 and sum(first[i] * last[i] for i in chans) < 0:
                goal = {i: -v for i, v in first.items()}
            for i, fc in chans.items():
                _ensure_key(fc, start, first[i])
                _ensure_key(fc, end, last[i])
                delta = goal[i] - last[i]
                if abs(delta) > 1e-9:
                    for kp in fc.keyframe_points:
                        shift = delta * weight(kp.co.x)
                        kp.co.y += shift
                        kp.handle_left.y += shift
                        kp.handle_right.y += shift
                    matched += 1
                    max_fix = max(max_fix, abs(delta))
                fc.update()
        mode = "REPEAT_OFFSET" if path in travel else "REPEAT"
        for fc in chans.values():
            mod = next((m for m in fc.modifiers if m.type == "CYCLES"), None)
            if mod is None:
                mod = fc.modifiers.new("CYCLES")
                cycles_added += 1
            mod.mode_before = mod.mode_after = mode
    return ok(action=act.name, frame_range=list(act.frame_range), curves=len(curves), curves_matched=matched,
              max_fix=round(max_fix, 6), cycles_added=cycles_added)


def trim(action, start, end):
    """Keep the keys between frames start and end (adding a key at each cut with the curve's value there) and shift
    them so the clip starts at frame 0, not 1: glTF writes time = frame / fps, so a clip at 0 exports from 0 s
    without export_anim_slide_to_zero (blender plugin's animation.md). Run before loop_cleanup, whose matched end
    key a later trim can cut, and before push_to_nla, whose strips keep their old range.
    Returns ok(action, frame_range, removed_keys, shifted_by)."""
    act = _action(action)
    if end <= start:
        raise ForgeError(f"trim needs end > start, got {start}..{end}")
    curves = [fc for cb in _channelbags(act) for fc in cb.fcurves]
    if not curves:
        raise ForgeError(f"{act.name} has no F-curves")
    removed = 0
    for fc in curves:
        with _modifiers_muted([fc]):
            at_start, at_end = fc.evaluate(start), fc.evaluate(end)
        _ensure_key(fc, start, at_start)
        _ensure_key(fc, end, at_end)
        outside = [i for i, kp in enumerate(fc.keyframe_points) if kp.co.x < start - 1e-4 or kp.co.x > end + 1e-4]
        for i in reversed(outside):
            fc.keyframe_points.remove(fc.keyframe_points[i], fast=True)
        removed += len(outside)
        for kp in fc.keyframe_points:
            kp.co.x -= start
            kp.handle_left.x -= start
            kp.handle_right.x -= start
        fc.update()
    if act.use_frame_range:
        act.frame_start, act.frame_end = 0, end - start
    return ok(action=act.name, frame_range=list(act.frame_range), removed_keys=removed, shifted_by=-start)


def push_to_nla(rig, action, track_name=None, engine="unity", asset=None, clip=None):
    """Name the action per the engine preset's animation.clip_naming ({asset} defaults to the rig's name, {clip} to
    the action's, or to its clip part when the action already carries this preset's name for that asset, so a second
    call keeps Hero@Walk), add the preset's loop_suffix when the action loops (a Cycles modifier from loop_cleanup),
    push it onto its own NLA track (once; a second call renames in place) with the rig's slot, and clear the active
    action as Push Down does: FBX with All Actions off ships strips only.
    Returns ok(action, track, strip, loop, frame_start)."""
    obj = util.get_object(rig)
    act = _action(action)
    anim = util.load_preset("engines", engine).get("animation") or {}
    pattern, suffix = anim.get("clip_naming") or "{clip}", anim.get("loop_suffix")
    asset = asset or obj.name
    loops = any(m.type == "CYCLES" and not m.mute
                for cb in _channelbags(act) for fc in cb.fcurves for m in fc.modifiers)
    try:
        clip = clip or _clip_in(act.name, pattern, asset, suffix if loops else None) or act.name
        name = pattern.format(asset=asset, clip=clip)
    except (KeyError, IndexError) as exc:
        raise ForgeError(f"engine preset {engine}: clip_naming uses an unknown field {exc}") from exc
    if suffix and loops and not name.endswith(suffix):
        name += suffix
    if act.name != name:
        clash = bpy.data.actions.get(name)
        if clash is not None:
            raise ForgeError(f"another action is already named {name!r}")
        act.name = name
    ad = obj.animation_data_create()
    slot = _slot_for(act, obj)
    if slot is None:
        raise ForgeError(f"{act.name} has no slot that can animate an object")
    strip = next((s for t in ad.nla_tracks for s in t.strips if s.action == act), None)
    if strip is None:
        track = ad.nla_tracks.new()
        strip = track.strips.new(name, int(act.frame_range[0]), act)
    else:
        track = next(t for t in ad.nla_tracks if strip in t.strips[:])
    track.name = track_name or name
    strip.name = name
    strip.action_slot = slot
    if ad.action == act:
        ad.action = None
    return ok(action=act.name, track=track.name, strip=strip.name, loop=loops, frame_start=strip.frame_start)


def _clip_in(name, pattern, asset, suffix):
    """The {clip} part of `name` when `pattern` rendered for `asset` (plus `suffix`) produced it, else None."""
    if suffix and name.endswith(suffix):
        name = name[:-len(suffix)]
    regex, named = "", False
    for literal, field, _, _ in string.Formatter().parse(pattern):
        regex += re.escape(literal)
        if field == "asset":
            regex += re.escape(asset)
        elif field == "clip":
            regex += "(?P=clip)" if named else "(?P<clip>.+)"
            named = True
        elif field is not None:
            return None
    match = re.fullmatch(regex, name) if named else None
    return match["clip"] if match else None


def _action(action):
    act = bpy.data.actions.get(action) if isinstance(action, str) else action
    if not isinstance(act, bpy.types.Action):
        raise ForgeError(f"no action {action!r}")
    return act


def _frames(act, frame_range):
    start, end = frame_range if frame_range is not None else act.frame_range
    start, end = int(math.floor(start)), int(math.ceil(end))
    if end < start:
        raise ForgeError(f"frame_range end {end} is before start {start}")
    return start, end


def _channelbags(act):
    for layer in act.layers:
        for strip in layer.strips:
            yield from strip.channelbags


def _slot_for(act, obj):
    ad = obj.animation_data
    if ad is not None and ad.action == act and ad.action_slot is not None:
        return ad.action_slot
    if ad is not None:
        for track in ad.nla_tracks:
            for strip in track.strips:
                if strip.action == act and strip.action_slot is not None:
                    return strip.action_slot
    named = next((s for s in act.slots if s.identifier == "OB" + obj.name), None)
    return named or anim_utils.action_get_first_suitable_slot(act, "OBJECT")


def _channelbag(act, obj):
    cb = anim_utils.action_get_channelbag_for_slot(act, _slot_for(act, obj))
    if cb is None:
        raise ForgeError(f"{act.name} has no keys for {obj.name}")
    return cb


def _rig_for(act, rig):
    if rig is not None:
        return util.get_object(rig, "ARMATURE")
    users = [o for o in bpy.data.objects if o.type == "ARMATURE" and o.animation_data
             and (o.animation_data.action == act
                  or any(s.action == act for t in o.animation_data.nla_tracks for s in t.strips))]
    if not users:
        users = [o for s in act.slots if (o := bpy.data.objects.get(s.identifier[2:])) and o.type == "ARMATURE"]
    if len(users) != 1:
        raise ForgeError(f"{act.name} is used by {len(users)} armatures; pass rig=")
    return users[0]


def _bone_of(data_path):
    if not data_path.startswith('pose.bones["'):
        return None
    end = data_path.find('"]', len('pose.bones["'))
    return data_path[len('pose.bones["'):end].replace('\\"', '"').replace("\\\\", "\\") if end > 0 else None


def _rest_offset(src, s_name, tgt, t_name, entry):
    rs = (src.matrix_world @ src.data.bones[s_name].matrix_local).to_3x3().normalized().to_quaternion()
    rt = (tgt.matrix_world @ tgt.data.bones[t_name].matrix_local).to_3x3().normalized().to_quaternion()
    y = Vector((0.0, 1.0, 0.0))
    swing = (rt @ y).rotation_difference(rs @ y)
    offset = rs.inverted() @ swing @ rt
    if entry["axis_fix"]:
        offset = offset @ Euler([math.radians(a) for a in entry["axis_fix"]], "XYZ").to_quaternion()
    if entry["roll_fix_deg"]:
        offset = offset @ Quaternion(y, math.radians(entry["roll_fix_deg"]))
    return offset


def _constraint(pb, kind, suffix, target, subtarget):
    con = pb.constraints.new(kind)
    con.name = f"{TAG}_{suffix}"
    con.target, con.subtarget = target, subtarget
    con.target_space = con.owner_space = "WORLD"
    return con


def _constant(pb, channel, value, any_target):
    # A zero-width from-range makes a Transformation constraint output its to_min whatever the target does.
    con = pb.constraints.new("TRANSFORM")
    con.name = f"{TAG}_rest_{channel.lower()}"
    con.target = any_target
    con.owner_space = "WORLD"
    con.map_from, con.map_to = "LOCATION", channel
    if channel == "LOCATION":
        con.mix_mode = "ADD"
        con.to_min_x, con.to_min_y, con.to_min_z = value
    else:
        con.to_euler_order = "XYZ"
        con.mix_mode_rot = "AFTER"
        con.to_min_x_rot, con.to_min_y_rot, con.to_min_z_rot = value
    return con


def _remove_constraints(rig):
    n = 0
    for pb in rig.pose.bones:
        for con in [c for c in pb.constraints if c.name.startswith(TAG)]:
            pb.constraints.remove(con)
            n += 1
    return n


def _ensure_key(fc, frame, value):
    if not any(abs(kp.co.x - frame) < 1e-4 for kp in fc.keyframe_points):
        fc.keyframe_points.insert(frame, value, options={"FAST"})


@contextmanager
def _modifiers_muted(curves):
    """Evaluate F-curves without their modifiers: a Cycles modifier wraps the last frame onto the first."""
    mods = [m for fc in curves for m in fc.modifiers if not m.mute]
    for m in mods:
        m.mute = True
    try:
        yield
    finally:
        for m in mods:
            m.mute = False


@contextmanager
def _playing(rig, act):
    ad = rig.animation_data_create()
    before = (ad.action, ad.action_slot)
    if ad.action != act:
        ad.action = act
        ad.action_slot = _slot_for(act, rig)
    try:
        yield
    finally:
        if ad.action != before[0]:
            ad.action = before[0]
            if before[0] is not None:
                ad.action_slot = before[1]


def _add_root(rig, name):
    view_layer = bpy.context.view_layer
    active = view_layer.objects.active
    mode = active.mode if active is not None else "OBJECT"
    selected = [o for o in view_layer.objects if o.select_get()]
    util.select_only(rig)
    bpy.ops.object.mode_set(mode="EDIT")
    try:
        bones = rig.data.edit_bones
        length = 0.25 * max((b.length for b in bones), default=0.4)
        eb = bones.new(name)
        eb.head, eb.tail, eb.roll = (0.0, 0.0, 0.0), (0.0, length, 0.0), 0.0
        eb.use_deform = False
        for other in bones:
            if other.parent is None and other != eb:
                other.parent = eb
    finally:
        bpy.ops.object.mode_set(mode="OBJECT")
        rig.select_set(False)
        for o in selected:
            o.select_set(True)
        view_layer.objects.active = active
        if active is not None and mode != "OBJECT":
            bpy.ops.object.mode_set(mode=mode)
