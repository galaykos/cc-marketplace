"""Catches actions the FBX or glTF exporter drops, FBX clips of one object's action on another, glTF clips that start late, and loop pops; runs inside Blender.
Does NOT judge the engine import (root motion, compression, retargeting) or the motion itself; the exporters run with their defaults plus --fbx/--gltf overrides.
Exit 0 pass, 1 errors (or warnings with --strict), 2 could not run: blender -b f.blend --python-exit-code 2 --python anim_audit.py -- --expect Walk Run --loop Walk"""
# Why, limits, history: rationale/derivations/plugin-blender.md § plugins/blender/scripts/anim_audit.py
import argparse
import ast
import json
import math
import os
import re
import sys
import tempfile

try:
    import bpy
except ImportError:
    bpy = None

STACK = re.compile(rb"([^\x00\x01]{1,200})\x00\x01AnimStack")


def script_args(argv):
    """Arguments after '--'; Blender consumes everything before it."""
    return argv[argv.index("--") + 1:] if "--" in argv else []


def option(text):
    key, sep, value = text.partition("=")
    if not sep or not key.isidentifier():
        raise argparse.ArgumentTypeError(f"want KEY=VALUE, got {text!r}")
    try:
        return key, ast.literal_eval(value)
    except (ValueError, SyntaxError):
        return key, value


def parse_args(args):
    p = argparse.ArgumentParser(prog="anim_audit.py", description=__doc__.splitlines()[0])
    p.add_argument("--format", choices=["fbx", "gltf", "both"], default="both")
    p.add_argument("--expect", nargs="*", default=None, help="action names that must ship, and the only ones that may")
    p.add_argument("--loop", nargs="*", default=[], help="actions that must loop: first and last frame pose must match")
    p.add_argument("--tol", type=float, default=0.001, help="loop tolerance: metres for location, radians for rotation")
    p.add_argument("--fbx", type=option, action="append", default=[], help="export_scene.fbx override, KEY=VALUE (repeatable)")
    p.add_argument("--gltf", type=option, action="append", default=[], help="export_scene.gltf override, KEY=VALUE (repeatable)")
    p.add_argument("--keep", default=None, help="write the exports here instead of a temp dir")
    p.add_argument("--strict", action="store_true", help="warnings fail too")
    p.add_argument("--json", action="store_true")
    return p.parse_args(args)


def fbx_stacks(raw):
    """AnimStack names in a binary FBX, 'Object|Action' as the Blender exporter writes them."""
    return sorted({m.decode("utf-8", "replace") for m in STACK.findall(raw)})


def gltf_clips(doc):
    """(name, start seconds, end seconds) per glTF animation, from its samplers' input accessors."""
    acc = doc.get("accessors", [])
    out = []
    for a in doc.get("animations", []):
        times = [(acc[s["input"]].get("min", [0])[0], acc[s["input"]].get("max", [0])[0]) for s in a.get("samplers", [])]
        out.append((a.get("name", ""), min((t[0] for t in times), default=0.0), max((t[1] for t in times), default=0.0)))
    return out


def judge(actions, stacks, clips, fps, expect=None, scene=None, all_actions=True):
    """Pure verdicts. actions: {name: {"users": [objects], "owners": [objects its slots name, when it has no user], "fake_only": bool, "nla": bool,
    "curves": int, "stale": [(obj, path)]}}; an action with neither users nor owners is not checked for fbx-cross.
    stacks: FBX stack names ('Object|Action' from All Actions, a bare strip name from NLA, the scene name for one baked take)
    or None when FBX was not checked; clips: glTF (name, t0, t1) or None. Returns (errors, warnings)."""
    errors, warnings = [], []
    if stacks is not None and scene is not None and stacks == [scene]:
        warnings.append(("fbx-scene-take", scene, f"FBX wrote one take, '{scene}', of the whole timeline instead of a clip per action: "
                                                  "both All Actions and NLA Strips are off"))
        stacks = None
    if stacks is not None:
        paired, bare = {}, set()
        for s in stacks:
            ob, sep, act = s.partition("|")
            if sep:
                paired.setdefault(act, set()).add(ob)
            else:
                bare.add(s)
        for name, a in sorted(actions.items()):
            if a["curves"] and (a["users"] or a["fake_only"]) and name not in paired and name not in bare:
                if a["stale"]:
                    why = f": F-curve '{a['stale'][0][1]}' does not resolve on {a['stale'][0][0]}, and All Actions drops an action unless every path does"
                elif not all_actions and not a["nla"]:
                    why = ": with All Actions off FBX exports NLA-track strips only, and this action is on none"
                else:
                    why = ""
                errors.append(("fbx-dropped", name, f"FBX did not export {name}{why}"))
            owners = set(a["users"] or a["owners"])
            for ob in sorted(paired.get(name, set()) - owners if owners else ()):
                errors.append(("fbx-cross", name, f"FBX exports {name} on {ob}, which never uses it: All Actions (bake_anim_use_all_actions, on by default) "
                                                  "writes every action whose paths resolve on an object; push each clip onto its object's NLA track "
                                                  "and export with bake_anim_use_all_actions=False"))
            if name in bare and name in paired:
                warnings.append(("fbx-duplicate", name, f"FBX ships {name} twice, as an NLA strip and as an All Actions take"))
    if clips is not None:
        by_name = {c[0]: c for c in clips}
        for name, a in sorted(actions.items()):
            if not a["curves"]:
                continue
            if a["fake_only"] and name not in by_name:
                warnings.append(("gltf-fake-user", name, f"glTF did not export {name}: kept only by a fake user; the default ACTIONS mode exports active and NLA-track actions"))
            elif a["users"] and name not in by_name:
                errors.append(("gltf-dropped", name, f"glTF did not export {name}"))
        for name, t0, _ in clips:
            if fps and t0 > 1.0 / fps + 1e-6:
                warnings.append(("gltf-late-start", name, f"glTF clip {name} starts at {t0:.3f} s (frame {round(t0 * fps)}): glTF time counts from frame 0; "
                                                          "export_anim_slide_to_zero=True or key the clip from the scene start"))
    if expect is not None:
        out = set()
        if stacks is not None:
            out |= {s.partition("|")[2] or s for s in stacks}
        if clips is not None:
            out |= {c[0] for c in clips}
        for name in sorted(set(expect) - out):
            errors.append(("expect-missing", name, f"{name} is expected but no checked export carries it"))
        for name in sorted(out - set(expect)):
            errors.append(("expect-extra", name, f"{name} ships but is not in --expect"))
    return errors, warnings


def loop_verdict(name, first, last, tol):
    """first/last: {channel: (loc xyz, quat wxyz)}. Returns a message when the end pose does not meet the start."""
    worst = (0.0, "")
    for ch in sorted(set(first) & set(last)):
        (l0, q0), (l1, q1) = first[ch], last[ch]
        d = math.dist(l0, l1)
        dot = min(1.0, abs(sum(a * b for a, b in zip(q0, q1))))
        ang = 2 * math.acos(dot)
        if d > tol and d > worst[0]:
            worst = (d, f"{ch} moves {d:.4f} m")
        if ang > tol and ang > worst[0]:
            worst = (ang, f"{ch} turns {math.degrees(ang):.2f}°")
    return f"{name} does not loop: between its first and last frame {worst[1]}" if worst[1] else ""


def fcurves(action):
    """F-curves of every slot (5.x channelbags), or Action.fcurves before 4.4."""
    if getattr(action, "layers", None):
        for layer in action.layers:
            for strip in layer.strips:
                for bag in getattr(strip, "channelbags", []):
                    yield from bag.fcurves
    else:
        yield from getattr(action, "fcurves", [])


def slot_owners(act):
    """Objects named by a slot identifier ('OB' + name, 4.4+); a slot keeps the name the object had when it was keyed."""
    return sorted(s.identifier[2:] for s in getattr(act, "slots", []) if s.identifier.startswith("OB") and s.identifier[2:] in bpy.data.objects)


def inventory():
    users, on_nla = {}, set()
    for ob in bpy.data.objects:
        ad = ob.animation_data
        if not ad:
            continue
        if ad.action:
            users.setdefault(ad.action.name, set()).add(ob.name)
        for track in ad.nla_tracks:
            for strip in track.strips:
                if strip.action:
                    users.setdefault(strip.action.name, set()).add(ob.name)
                    on_nla.add(strip.action.name)
    out = {}
    for act in bpy.data.actions:
        curves = list(fcurves(act))
        u = sorted(users.get(act.name, set()))
        stale = []
        for ob_name in u:
            ob = bpy.data.objects[ob_name]
            for fc in curves:
                try:
                    ob.path_resolve(fc.data_path)
                except ValueError:
                    stale.append((ob_name, fc.data_path))
                    break
        out[act.name] = {"users": u, "owners": [] if u else slot_owners(act), "fake_only": not u and act.use_fake_user, "nla": act.name in on_nla,
                         "curves": len(curves), "stale": stale, "range": [round(v, 3) for v in act.frame_range]}
    return out


def pose_at(ob, frame):
    bpy.context.scene.frame_set(int(frame), subframe=frame - int(frame))
    if ob.type == "ARMATURE":
        items = [(f"{ob.name}:{pb.name}", pb.matrix_basis) for pb in ob.pose.bones]
    else:
        items = [(ob.name, ob.matrix_basis)]
    out = {}
    for name, m in items:
        loc, rot, _ = m.decompose()
        out[name] = (tuple(loc), (rot.w, rot.x, rot.y, rot.z))
    return out


def borrowed_poses(ob, act, frames):
    """Poses at frames with act assigned to ob through its own slot; ob's previous action and slot are put back."""
    created = ob.animation_data is None
    ad = ob.animation_data or ob.animation_data_create()
    prev = ad.action, ad.action_slot
    ad.action = act
    ad.action_slot = next(s for s in act.slots if s.identifier == "OB" + ob.name)
    try:
        return [pose_at(ob, f) for f in frames]
    finally:
        if created:
            ob.animation_data_clear()
        else:
            ad.action = prev[0]
            if prev[0] is not None:
                ad.action_slot = prev[1]


def check_loops(names, tol):
    errors, warnings = [], []
    for name in names:
        act = bpy.data.actions.get(name)
        if act is None:
            errors.append(("loop-unchecked", name, f"no action is named {name}, so its loop was not checked"))
            continue
        start, end = act.frame_range
        ob = next((o for o in bpy.data.objects if o.animation_data and o.animation_data.action == act), None)
        owners = slot_owners(act) if ob is None else []
        if ob is not None:
            first, last = pose_at(ob, start), pose_at(ob, end)
        elif len(owners) == 1:
            first, last = borrowed_poses(bpy.data.objects[owners[0]], act, (start, end))
        else:
            warnings.append(("loop-unchecked", name, f"{name} is no object's active action and its slots name {len(owners)} objects, "
                                                     "so its loop was not checked"))
            continue
        msg = loop_verdict(name, first, last, tol)
        if msg:
            errors.append(("loop-pop", name, msg))
    return errors, warnings


def export(fmt, folder, overrides):
    path = os.path.join(folder, "audit." + ("fbx" if fmt == "fbx" else "gltf"))
    if fmt == "fbx":
        bpy.ops.export_scene.fbx(filepath=path, **overrides)
        with open(path, "rb") as f:
            return fbx_stacks(f.read())
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLTF_SEPARATE", **overrides)
    with open(path, encoding="utf-8") as f:
        return gltf_clips(json.load(f))


def run(args):
    scene = bpy.context.scene
    fps = scene.render.fps / (scene.render.fps_base or 1.0)
    actions = inventory()
    folder = args.keep or tempfile.mkdtemp(prefix="anim_audit_")
    stacks = export("fbx", folder, dict(args.fbx)) if args.format in ("fbx", "both") else None
    clips = export("gltf", folder, dict(args.gltf)) if args.format in ("gltf", "both") else None
    fbx = dict(args.fbx)
    errors, warnings = judge(actions, stacks, clips, fps, args.expect, scene.name, fbx.get("bake_anim_use_all_actions", True))
    loop_errors, loop_warnings = check_loops(args.loop, args.tol)
    errors += loop_errors
    warnings += loop_warnings
    return {"tool": "anim_audit", "blender": bpy.app.version_string, "fps": round(fps, 3), "actions": actions,
            "fbx_stacks": stacks, "gltf_clips": clips, "exports": folder if args.keep else None,
            "errors": [dict(check=c, action=a, message=m) for c, a, m in errors],
            "warnings": [dict(check=c, action=a, message=m) for c, a, m in warnings]}


def main(argv=None):
    args = parse_args(script_args(sys.argv if argv is None else argv))
    if bpy is None:
        print("anim_audit.py: run inside Blender: blender -b f.blend --python-exit-code 2 --python anim_audit.py -- …", file=sys.stderr)
        return 2
    try:
        result = run(args)
    except Exception as error:  # an exporter refusing an override is a could-not-run, not a verdict
        print(f"anim_audit.py: could not run: {error}", file=sys.stderr)
        return 2
    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print(f"anim_audit: Blender {result['blender']}, {result['fps']} fps, {len(result['actions'])} actions")
        if result["fbx_stacks"] is not None:
            print(f"  FBX clips: {', '.join(result['fbx_stacks']) or 'none'}")
        if result["gltf_clips"] is not None:
            print("  glTF clips: " + (", ".join(f"{n} {a:.3f}-{b:.3f} s" for n, a, b in result["gltf_clips"]) or "none"))
        for level in ("errors", "warnings"):
            for f in result[level]:
                print(f"{level[:-1].upper()} [{f['check']}] {f['message']}")
        print(f"Summary: {len(result['errors'])} errors, {len(result['warnings'])} warnings")
    return 1 if result["errors"] or (args.strict and result["warnings"]) else 0


if __name__ == "__main__":
    sys.exit(main())
