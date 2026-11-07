"""rig_check.py: the deform-only export model in plain Python; the rig and skin checks inside a real Blender only when BLENDER_EXE is set."""
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "rig_check.py"
BLENDER = os.environ.get("BLENDER_EXE", "")
spec = importlib.util.spec_from_file_location("rig_check", SCRIPT)
rc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rc)


class Pure(unittest.TestCase):
    def test_deform_only_keeps_non_deform_ancestors_and_their_roots(self):
        parents = {"root": None, "DEF-spine": "MCH-torso", "MCH-torso": None, "DEF-hips": "root", "ctrl": "root"}
        kept, roots = rc.deform_only_export(parents, {"DEF-spine", "DEF-hips"})
        self.assertEqual(kept, {"DEF-spine", "MCH-torso", "DEF-hips", "root"})
        self.assertEqual(roots, ["MCH-torso", "root"])

    def test_a_deform_chain_under_one_deform_root_exports_one_root(self):
        kept, roots = rc.deform_only_export({"hips": None, "spine": "hips", "ik": None}, {"hips", "spine"})
        self.assertEqual((kept, roots), ({"hips", "spine"}, ["hips"]))

    def test_mirror_names(self):
        self.assertEqual((rc.mirror("arm.L"), rc.mirror("hand_r"), rc.mirror("LeftFoot"), rc.mirror("spine")),
                         ("arm.R", "hand_l", "RightFoot", None))

    def test_outside_blender_it_exits_two(self):
        result = subprocess.run([sys.executable, "-I", str(SCRIPT), "--"], capture_output=True, text=True)
        self.assertEqual(result.returncode, 2, result.stderr)


BUILD = '''
import bpy, sys
broken = sys.argv[-1] == "broken"
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
arm_data = bpy.data.armatures.new("Rig"); arm = bpy.data.objects.new("Rig", arm_data); sc.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm; bpy.ops.object.mode_set(mode="EDIT")
def bone(name, head, tail, parent=None, deform=True):
    b = arm_data.edit_bones.new(name); b.head, b.tail = head, tail; b.use_deform = deform
    if parent: b.parent = arm_data.edit_bones[parent]
    return b
bone("hips", (0, 0, 0), (0, 0, 0.5))
bone("spine", (0, 0, 0.5), (0, 0, 1), "hips")
if broken:
    arm_data.edit_bones["hips"].use_deform = False
    bone("MCH-torso", (0, 0.3, 0.5), (0, 0.3, 1), deform=False)
    bone("arm.L", (0.2, 0, 1), (0.6, 0, 1), "MCH-torso").bbone_segments = 4
bpy.ops.object.mode_set(mode="OBJECT")
me = bpy.data.meshes.new("Body"); me.from_pydata([(0, 0, 0), (0.1, 0, 0.5), (0, 0.1, 1), (0.3, 0, 1)], [], [(0, 1, 2), (1, 2, 3)])
body = bpy.data.objects.new("Body", me); sc.collection.objects.link(body)
mod = body.modifiers.new("Armature", "ARMATURE"); mod.object = arm
g = body.vertex_groups.new(name="spine")
if broken:
    mod.use_deform_preserve_volume = True
    g.add([0, 1], 1.0, "REPLACE")
    body.shape_key_add(name="Basis"); smile = body.shape_key_add(name="Smile"); smile.vertex_group = "spine"
elif sys.argv[-1] == "split":
    g.add([0, 1, 2, 3], 1.0, "REPLACE")
    me2 = bpy.data.meshes.new("Legs"); me2.from_pydata([(0, 0, 0), (0.1, 0, 0.2), (0, 0.1, 0.4)], [], [(0, 1, 2)])
    legs = bpy.data.objects.new("Legs", me2); sc.collection.objects.link(legs)
    legs.modifiers.new("Armature", "ARMATURE").object = arm
    legs.vertex_groups.new(name="hips").add([0, 1, 2], 1.0, "REPLACE")
else:
    g.add([2, 3], 1.0, "REPLACE")
    body.vertex_groups.new(name="hips").add([0, 1], 1.0, "REPLACE")
bpy.ops.wm.save_as_mainfile(filepath=sys.argv[sys.argv.index("--") + 1])
'''


@unittest.skipUnless(BLENDER and os.path.isfile(BLENDER), "set BLENDER_EXE to a Blender 5.x binary to run")
class InBlender(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        builder = os.path.join(cls.tmp.name, "build.py")
        Path(builder).write_text(BUILD)
        cls.blends = {}
        for kind in ("clean", "broken", "split"):
            out = os.path.join(cls.tmp.name, kind + ".blend")
            subprocess.run([BLENDER, "-b", "--factory-startup", "--python-exit-code", "2", "--python", builder, "--", out, kind],
                           check=True, capture_output=True)
            cls.blends[kind] = out

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def check(self, kind, *args):
        result = subprocess.run([BLENDER, "-b", self.blends[kind], "--factory-startup", "--python-exit-code", "2",
                                 "--python", str(SCRIPT), "--", "--json", *args], capture_output=True, text=True)
        start = result.stdout.find("{\n")
        return result.returncode, json.loads(result.stdout[start:]) if start >= 0 else None

    def test_clean_rig_passes_strict(self):
        code, report = self.check("clean", "--strict")
        self.assertEqual((code, report["errors"], report["warnings"]), (0, [], []), report)

    def test_broken_rig_names_each_export_trap(self):
        code, report = self.check("broken")
        self.assertEqual(code, 1)
        text = "\n".join(report["errors"] + report["warnings"])
        for needle in ("2 roots", "Preserve Volume", "2 unweighted verts", "vertex-group mask", "B-Bone segments", "non-deform bones",
                       "1 deform bones weight no vertex in any checked mesh ['arm.L']"):
            self.assertIn(needle, text)
        self.assertEqual(report["info"]["deform_only_export"]["roots"], ["MCH-torso", "hips"])

    def test_meshes_that_each_weight_a_different_bone_leave_no_bone_empty(self):
        code, report = self.check("split", "--strict")
        self.assertEqual((code, sorted(report["skin"]), report["errors"], report["warnings"]), (0, ["Body", "Legs"], [], []), report)

    def test_a_missing_armature_is_a_could_not_run(self):
        code, _ = self.check("clean", "--armature", "Nope")
        self.assertEqual(code, 2)


if __name__ == "__main__":
    unittest.main()
