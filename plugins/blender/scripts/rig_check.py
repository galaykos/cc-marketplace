"""Catches rig and skin faults that break a game export: extra roots after FBX 'Only Deform Bones', B-Bones and dual-quaternion deform engines ignore,
unweighted verts and empty deform groups (a failed auto-weight), over-limit influences, and shape-key masks the exporters drop; runs inside Blender.
Does NOT judge deformation quality, retarget mapping in the engine, or animation; --profile only reports naming gaps. Exit 0 pass, 1 errors (or warnings with --strict), 2 could not run."""
# Derived from EL4CTEO/blender-skills@fb92cfb skills/blender-character-rigging/scripts/rig_check.py (MIT, see LICENSE); modified.
# Why, limits, history: rationale/derivations/plugin-blender.md § plugins/blender/scripts/rig_check.py
import argparse
import json
import re
import sys

try:
    import bpy
    from mathutils.kdtree import KDTree
except ImportError:
    bpy = None

R15 = ["LowerTorso", "UpperTorso", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm",
       "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg",
       "RightLowerLeg", "RightFoot"]
HUMANOID = {
    "Hips": r"hips|pelvis$|^spine$|root_?hips", "Spine": r"spine(\.001|_01|1)?$|^spine$",
    "Head": r"head$", "LeftUpperLeg": r"(thigh|upleg|upperleg|upper_leg)[._]?l|left.?(up|upper).?leg",
    "LeftLowerLeg": r"(shin|calf|^leg|lowerleg|lower_leg)[._]?l|left.?(lower)?leg$",
    "LeftFoot": r"foot[._]?l|left.?foot", "RightUpperLeg": r"(thigh|upleg|upperleg|upper_leg)[._]?r|right.?(up|upper).?leg",
    "RightLowerLeg": r"(shin|calf|lowerleg|lower_leg)[._]?r|right.?(lower)?leg$",
    "RightFoot": r"foot[._]?r|right.?foot", "LeftUpperArm": r"(upper_?arm|upperarm|^arm)[._]?l|left.?arm",
    "LeftLowerArm": r"(forearm|lowerarm|lower_arm)[._]?l|left.?fore.?arm", "LeftHand": r"hand[._]?l|left.?hand",
    "RightUpperArm": r"(upper_?arm|upperarm|^arm)[._]?r|right.?arm",
    "RightLowerArm": r"(forearm|lowerarm|lower_arm)[._]?r|right.?fore.?arm", "RightHand": r"hand[._]?r|right.?hand",
}
UE = ["root", "pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "head", "clavicle_l", "upperarm_l",
      "lowerarm_l", "hand_l", "clavicle_r", "upperarm_r", "lowerarm_r", "hand_r", "thigh_l", "calf_l",
      "foot_l", "ball_l", "thigh_r", "calf_r", "foot_r", "ball_r"]


def script_args(argv):
    """Arguments after '--'; Blender consumes everything before it."""
    return argv[argv.index("--") + 1:] if "--" in argv else []


def parse_args(args):
    p = argparse.ArgumentParser(prog="rig_check.py", description=__doc__.splitlines()[0])
    p.add_argument("--armature", default=None, help="armature object (default: the only one in the file)")
    p.add_argument("--meshes", nargs="*", default=None, help="skinned meshes (default: every mesh with an Armature modifier on it)")
    p.add_argument("--profile", default="game", choices=["game", "roblox", "unity", "unreal"])
    p.add_argument("--limit", type=int, default=4, help="influences per vertex the engine keeps")
    p.add_argument("--strict", action="store_true", help="warnings fail too")
    p.add_argument("--json", action="store_true")
    return p.parse_args(args)


def mirror(name):
    for a, b in ((".L", ".R"), ("_L", "_R"), (".l", ".r"), ("_l", "_r"), ("Left", "Right"), ("left", "right")):
        if a in name:
            return name.replace(a, b)
        if b in name:
            return name.replace(b, a)
    return None


def deform_only_export(parents, deform):
    """Bones FBX writes with use_armature_deform_only: every deform bone plus each ancestor that has a deforming descendant.
    parents: {bone: parent or None}; deform: set of deform bones. Returns (kept bones, their roots)."""
    kept = set()
    for b in deform:
        while b is not None and b not in kept:
            kept.add(b)
            b = parents.get(b)
    return kept, sorted(b for b in kept if parents.get(b) is None)


def check_armature(arm, profile):
    errors, warnings, info = [], [], {}
    bones = arm.data.bones
    if any(abs(s - 1) > 1e-4 for s in arm.scale) or any(abs(r) > 1e-4 for r in arm.rotation_euler):
        errors.append(f"armature object transform not applied (scale {tuple(round(s, 4) for s in arm.scale)}, rotation {tuple(round(r, 4) for r in arm.rotation_euler)})")
    roots = [b for b in bones if b.parent is None]
    deform = [b for b in bones if b.use_deform]
    if len([b for b in roots if b.use_deform or b.children]) > 1:
        warnings.append(f"{len(roots)} root bones {[b.name for b in roots][:5]}: engines expect one hierarchy root")
    if roots and (arm.matrix_world @ roots[0].head_local).length > 1e-3:
        warnings.append(f"root bone '{roots[0].name}' is not at the world origin")
    zero = [b.name for b in bones if b.length < 1e-5]
    if zero:
        errors.append(f"zero-length bones: {zero[:10]}")
    unpaired = [b.name for b in bones if (m := mirror(b.name)) and m != b.name and m not in bones]
    if unpaired:
        warnings.append(f"L/R bones without a mirror partner: {unpaired[:10]}")
    roll_bad = []
    for b in bones:
        m = mirror(b.name)
        if m and m in bones and b.name < m:
            za, zb = b.z_axis, bones[m].z_axis
            if abs(za.x + zb.x) > 0.05 or abs(za.y - zb.y) > 0.05 or abs(za.z - zb.z) > 0.05:
                roll_bad.append(b.name)
    if roll_bad:
        warnings.append(f"bone roll not mirrored: {roll_bad[:10]} (recalculate roll or symmetrize)")
    constrained = [pb.name for pb in arm.pose.bones if pb.constraints and bones[pb.name].use_deform]
    if constrained:
        warnings.append(f"{len(constrained)} deform bones carry constraints {constrained[:5]}: bake the animation with visual keying before export")
    kept, kept_roots = deform_only_export({b.name: b.parent.name if b.parent else None for b in bones}, {b.name for b in deform})
    info["deform_only_export"] = {"bones": len(kept), "deform": len(deform), "roots": kept_roots}
    if len(kept_roots) > 1:
        errors.append(f"with FBX 'Only Deform Bones' the export still has {len(kept_roots)} roots {kept_roots[:5]}: non-deform parents of deform bones are kept; "
                      "reparent the deform chain to one deform root (a Rigify rig needs a game-ready deform skeleton)")
    if len(kept) > len(deform):
        warnings.append(f"FBX 'Only Deform Bones' still writes {len(kept) - len(deform)} non-deform bones {sorted(kept - {b.name for b in deform})[:5]}: they parent deform bones")
    bbone = [b.name for b in deform if b.bbone_segments > 1]
    if bbone:
        warnings.append(f"{len(bbone)} deform bones use B-Bone segments {bbone[:5]}: neither FBX nor glTF writes B-Bones, so engines deform them as straight bones")
    names = [b.name for b in deform]
    if profile == "roblox":
        missing = [n for n in R15 if n not in bones]
        info["r15_missing"] = missing
        if missing:
            errors.append(f"R15 bones missing: {missing}")
    elif profile == "unity":
        mapped = {k: next((n for n in names if re.search(p, n, re.I)), None) for k, p in HUMANOID.items()}
        info["humanoid_map"] = mapped
        miss = [k for k, v in mapped.items() if v is None]
        if miss:
            warnings.append(f"Humanoid auto-map may fail for {miss}: map them by hand in the Unity Avatar")
    elif profile == "unreal":
        missing = [n for n in UE if n not in bones]
        info["mannequin_missing"] = missing
        if missing:
            warnings.append(f"{len(missing)} UE mannequin bone names missing: the IK Retargeter needs manual chains")
    if len(deform) > 300:
        warnings.append(f"{len(deform)} deform bones: heavy for a game character")
    return errors, warnings, info, {b.name for b in deform}, {b.name for b in roots}


def check_mesh(ob, arm, deform_names, root_names, profile, limit):
    errors, warnings = [], []
    bones = arm.data.bones
    for m in ob.modifiers:
        if m.type == "ARMATURE" and m.object == arm and (m.use_deform_preserve_volume or m.use_bone_envelopes):
            errors.append(f"{ob.name}: Armature modifier '{m.name}' uses {'Preserve Volume' if m.use_deform_preserve_volume else 'Bone Envelopes'}; "
                          "engines skin with vertex groups and linear blending, so the export deforms differently")
    gi = {g.index: g.name for g in ob.vertex_groups}
    unw = over = unnorm = on_root = 0
    for v in ob.data.vertices:
        ws = [(gi.get(g.group), g.weight) for g in v.groups if g.weight > 1e-4]
        dws = [w for n, w in ws if n in deform_names]
        unw += not dws
        over += len(dws) > limit
        unnorm += bool(dws) and abs(sum(dws) - 1) > 0.01
        on_root += any(n in root_names for n, _ in ws)
    orphan = [g.name for g in ob.vertex_groups if g.name not in bones]
    weighted = {gi.get(g.group) for v in ob.data.vertices for g in v.groups if g.weight > 1e-4}
    asym = 0
    verts = ob.data.vertices
    kd = KDTree(len(verts))
    for v in verts:
        kd.insert(v.co, v.index)
    kd.balance()
    for v in verts[:: max(1, len(verts) // 2000)]:
        co = v.co.copy()
        co.x = -co.x
        _, j, d = kd.find(co)
        if j is None or d > 1e-3 or v.co.x < 1e-4:
            continue
        a = {gi.get(g.group): g.weight for g in v.groups}
        b = {gi.get(g.group): g.weight for g in verts[j].groups}
        if any((m := mirror(n) if n else None) and abs(w - b.get(m, 0)) > 0.1 for n, w in a.items()):
            asym += 1
    if unw:
        errors.append(f"{ob.name}: {unw} unweighted verts: they stay in place, and glTF adds a 'neutral_bone' joint for them. "
                      "A failed automatic-weights run still reports FINISHED and stops at the bone that failed")
    if over:
        errors.append(f"{ob.name}: {over} verts over {limit} influences (the engine keeps the highest {limit})")
    if unnorm:
        warnings.append(f"{ob.name}: {unnorm} verts whose weights do not sum to 1")
    if on_root and profile == "roblox":
        errors.append(f"{ob.name}: {on_root} verts weighted to the root (Roblox rejects them)")
    if orphan:
        warnings.append(f"{ob.name}: vertex groups with no bone {orphan[:5]}")
    if asym:
        warnings.append(f"{ob.name}: about {asym} sampled verts weight L and R differently (mirror the weights?)")
    keys = ob.data.shape_keys
    if keys:
        basis = keys.reference_key
        masked = [k.name for k in keys.key_blocks if k != basis and k.vertex_group]
        if masked:
            errors.append(f"{ob.name}: shape keys {masked[:5]} use a vertex-group mask, which FBX and glTF drop: the whole key ships. "
                          "Bake each masked key into a new one (New Shape from Mix) before export")
        chained = [k.name for k in keys.key_blocks if k != basis and k.relative_key != basis]
        if chained:
            warnings.append(f"{ob.name}: shape keys {chained[:5]} are relative to another key: glTF writes them against the Basis, FBX against their own reference")
        muted = [k.name for k in keys.key_blocks if k.mute]
        if muted:
            warnings.append(f"{ob.name}: muted shape keys {muted[:5]}: glTF skips them")
    return errors, warnings, {"verts": len(verts), "unweighted": unw, f"over_{limit}": over, "not_normalized": unnorm,
                              "groups_without_bone": orphan[:10]}, weighted


def run(armature=None, meshes=None, profile="game", limit=4, **_):
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    if armature:
        arm = bpy.data.objects.get(armature)
        if arm is None or arm.type != "ARMATURE":
            raise LookupError(f"no armature object named {armature!r}")
    else:
        arms = [o for o in bpy.data.objects if o.type == "ARMATURE"]
        if len(arms) != 1:
            raise LookupError(f"{len(arms)} armatures in the file: name one with --armature")
        arm = arms[0]
    errors, warnings, info, deform_names, root_names = check_armature(arm, profile)
    if meshes:
        obs = [bpy.data.objects[n] for n in meshes]
    else:
        obs = [o for o in bpy.data.objects if o.type == "MESH" and any(m.type == "ARMATURE" and m.object == arm for m in o.modifiers)]
    skin, weighted = {}, set()
    for ob in obs:
        e, w, s, hit = check_mesh(ob, arm, deform_names, root_names, profile, limit)
        errors += e
        warnings += w
        skin[ob.name] = s
        weighted |= hit
    empty_deform = sorted(deform_names - weighted) if obs else []
    if empty_deform:
        warnings.append(f"{len(empty_deform)} deform bones weight no vertex in any checked mesh {empty_deform[:5]} (an automatic-weights failure stops early)")
    return {"tool": "rig_check", "armature": arm.name, "bones": len(arm.data.bones), "deform_bones": len(deform_names),
            "deform_bones_without_weights": len(empty_deform), "info": info, "skin": skin, "errors": errors, "warnings": warnings}


def main(argv=None):
    args = parse_args(script_args(sys.argv if argv is None else argv))
    if bpy is None:
        print("rig_check.py: run inside Blender: blender -b f.blend --python-exit-code 2 --python rig_check.py -- …", file=sys.stderr)
        return 2
    try:
        result = run(**vars(args))
    except (LookupError, KeyError) as error:
        print(f"rig_check.py: could not run: {error}", file=sys.stderr)
        return 2
    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print(f"rig_check: {result['armature']}, {result['bones']} bones, {result['deform_bones']} deform, {len(result['skin'])} skinned meshes")
        for level in ("errors", "warnings"):
            for line in result[level]:
                print(f"{level[:-1].upper()} {line}")
        print(f"Summary: {len(result['errors'])} errors, {len(result['warnings'])} warnings")
    return 1 if result["errors"] or (args.strict and result["warnings"]) else 0


if __name__ == "__main__":
    sys.exit(main())
