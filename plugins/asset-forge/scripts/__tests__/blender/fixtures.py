"""Test scenes built in code, so no .blend is committed. Each builder adds objects to the current scene and returns
them. As a script it saves one .blend per fixture:
blender -b --factory-startup --python fixtures.py -- <out_dir>"""
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector


def _mesh(name, bm):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def _material(name, rgb):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*rgb, 1.0)
    return mat


def crate(name="SM_Crate", size=1.0):
    """A clean 1 m crate: 12 tris, one UV map from the cube unwrap, origin at the bottom centre, one material."""
    bm = bmesh.new()
    bm.loops.layers.uv.new("UVMap")
    bmesh.ops.create_cube(bm, size=size, matrix=Matrix.Translation((0, 0, size / 2)), calc_uvs=True)
    obj = _mesh(name, bm)
    obj.data.materials.append(_material("M_Crate", (0.45, 0.28, 0.12)))
    return obj


def bad_asset(name="crate final"):
    """Breaks the validator's rules on purpose: bad name, unapplied scale, an n-gon, a loose vertex, one flipped face,
    all UVs stacked on one point, five material slots, and an image texture whose file is missing."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    bmesh.ops.create_cube(bm, size=1.0, calc_uvs=True)
    ring = [bm.verts.new((3 + math.cos(a), math.sin(a), 0)) for a in (i * 2 * math.pi / 5 for i in range(5))]
    bm.faces.new(ring)
    bm.verts.new((10, 10, 10))
    bm.faces.ensure_lookup_table()
    bm.faces[0].normal_flip()
    for face in bm.faces:
        for loop in face.loops:
            loop[uv].uv = (0.5, 0.5)
    obj = _mesh(name, bm)
    obj.scale = (2.0, 1.0, 1.0)
    for i in range(5):
        obj.data.materials.append(_material(f"mat{i}", (0.5, 0.5, 0.5)))
    image = bpy.data.images.new("missing_tex", 4, 4)
    image.source = "FILE"
    image.filepath = "//textures/does_not_exist.png"
    tex = obj.data.materials[0].node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = image
    return obj


def rock_blockout(name="SM_Rock", radius=1.0):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=3, radius=radius)
    return _mesh(name, bm)


# canonical key -> (head, tail, parent); a 1.8 m T-pose, metres, Z up, facing -Y
SKELETON = {
    "hips": ((0, 0, 1.0), (0, 0, 1.1), None),
    "spine": ((0, 0, 1.1), (0, 0, 1.3), "hips"),
    "chest": ((0, 0, 1.3), (0, 0, 1.45), "spine"),
    "neck": ((0, 0, 1.45), (0, 0, 1.55), "chest"),
    "head": ((0, 0, 1.55), (0, 0, 1.8), "neck"),
    "upper_arm.L": ((0.2, 0, 1.42), (0.48, 0, 1.42), "chest"),
    "forearm.L": ((0.48, 0, 1.42), (0.74, 0, 1.42), "upper_arm.L"),
    "hand.L": ((0.74, 0, 1.42), (0.84, 0, 1.42), "forearm.L"),
    "thigh.L": ((0.1, 0, 1.0), (0.1, 0, 0.55), "hips"),
    "shin.L": ((0.1, 0, 0.55), (0.1, 0, 0.1), "thigh.L"),
    "foot.L": ((0.1, 0, 0.1), (0.1, -0.15, 0.02), "shin.L"),
}
for _k in [k for k in SKELETON if k.endswith(".L")]:
    (h, t, p) = SKELETON[_k]
    SKELETON[_k[:-2] + ".R"] = ((-h[0], h[1], h[2]), (-t[0], t[1], t[2]), p[:-2] + ".R" if p.endswith(".L") else p)

_MIXAMO = {"hips": "Hips", "spine": "Spine", "chest": "Spine2", "neck": "Neck", "head": "Head", "upper_arm": "Arm",
           "forearm": "ForeArm", "hand": "Hand", "thigh": "UpLeg", "shin": "Leg", "foot": "Foot"}
_RIGIFY = {"hips": "spine", "spine": "spine.001", "chest": "spine.003", "neck": "spine.004", "head": "spine.006",
           "upper_arm": "upper_arm", "forearm": "forearm", "hand": "hand", "thigh": "thigh", "shin": "shin", "foot": "foot"}


def bone_name(key, naming):
    """Map a canonical key to 'mixamo' (mixamorig:LeftArm) or 'rigify' (DEF-upper_arm.L) naming."""
    base, side = (key[:-2], key[-1]) if key[-2:] in (".L", ".R") else (key, "")
    if naming == "mixamo":
        return "mixamorig:" + {"L": "Left", "R": "Right", "": ""}[side] + _MIXAMO[base]
    if naming == "rigify":
        return "DEF-" + _RIGIFY[base] + (f".{side}" if side else "")
    return key


def armature(name, naming="rigify", a_pose_deg=0.0):
    """An armature from SKELETON. a_pose_deg rotates both arms down about Y, giving a rest pose unlike a T-pose."""
    arm = bpy.data.armatures.new(name)
    obj = bpy.data.objects.new(name, arm)
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    made = {}
    for key, (head, tail, parent) in SKELETON.items():
        eb = arm.edit_bones.new(bone_name(key, naming))
        h, t = Vector(head), Vector(tail)
        if a_pose_deg and key.split(".")[0] in ("upper_arm", "forearm", "hand"):
            sign = 1 if key.endswith(".L") else -1
            pivot = Vector(SKELETON["upper_arm" + key[-2:]][0])
            rot = Matrix.Rotation(math.radians(-a_pose_deg * sign), 4, "Y")
            h, t = pivot + (rot @ (h - pivot).to_4d()).to_3d(), pivot + (rot @ (t - pivot).to_4d()).to_3d()
        eb.head, eb.tail = h, t
        made[key] = eb
        if parent:
            eb.parent = made[parent]
            eb.use_connect = (eb.head - made[parent].tail).length < 1e-6
    bpy.ops.object.mode_set(mode="OBJECT")
    return obj


def skinned_mesh(rig, name="SK_Hero"):
    """One box per bone, each fully weighted to that bone, parented to `rig` with an Armature modifier."""
    bm = bmesh.new()
    groups = []
    deform = bm.verts.layers.deform.verify()
    for i, bone in enumerate(rig.data.bones):
        axis = bone.tail_local - bone.head_local
        mat = Matrix.Translation(bone.head_local + axis / 2) @ axis.to_track_quat("Z", "Y").to_matrix().to_4x4() \
            @ Matrix.Diagonal((0.06, 0.06, axis.length, 1))
        new = bmesh.ops.create_cube(bm, size=1.0, matrix=mat)["verts"]
        for v in new:
            v[deform][i] = 1.0
        groups.append(bone.name)
    obj = _mesh(name, bm)
    for g in groups:
        obj.vertex_groups.new(name=g)
    obj.parent = rig
    obj.modifiers.new("Armature", "ARMATURE").object = rig
    return obj


def walk_action(rig, frames=24):
    """A looping walk-ish clip on a mixamo-named rig: hips travel 0.8 m along world +Y (keys are in the bone's local frame) and bob, thighs and arms swing."""
    action = bpy.data.actions.new(f"{rig.name}_Walk")
    rig.animation_data_create().action = action
    pb = rig.pose.bones
    for f in range(0, frames + 1, 6):
        phase = 2 * math.pi * f / frames
        hips = pb[bone_name("hips", "mixamo")]
        hips.location = (0, 0.04 * abs(math.sin(phase)), -0.8 * f / frames)
        hips.keyframe_insert("location", frame=f + 1)
        for side, sign in (("L", 1), ("R", -1)):
            for key, amp in ((f"thigh.{side}", 30), (f"upper_arm.{side}", -20)):
                bone = pb[bone_name(key, "mixamo")]
                bone.rotation_mode = "XYZ"
                bone.rotation_euler = (math.radians(amp * sign * math.sin(phase)), 0, 0)
                bone.keyframe_insert("rotation_euler", frame=f + 1)
    return action


def humanoid():
    """Target rig (rigify DEF names, 40° A-pose) with a skinned mesh, and a mixamo-named T-pose source rig with a walk."""
    target = armature("RIG_Hero", "rigify", a_pose_deg=40)
    mesh = skinned_mesh(target)
    source = armature("mixamo_source", "mixamo")
    source.location.x = 2.0
    walk_action(source)
    return target, mesh, source


BUILDERS = {"crate": crate, "bad_asset": bad_asset, "rock": rock_blockout, "humanoid": humanoid}

if __name__ == "__main__" and "--" in sys.argv:
    out = Path(sys.argv[sys.argv.index("--") + 1])
    out.mkdir(parents=True, exist_ok=True)
    for key, build in BUILDERS.items():
        bpy.ops.wm.read_factory_settings(use_empty=True)
        build()
        bpy.ops.wm.save_as_mainfile(filepath=str(out / f"{key}.blend"))
        print(f"wrote {out / (key + '.blend')}")
