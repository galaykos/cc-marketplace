"""blender_qa.py: pure parts in plain Python; exit codes inside a real Blender only when BLENDER_EXE is set."""
import contextlib
import importlib.util
import io
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "blender_qa.py"
BLENDER = os.environ.get("BLENDER_EXE", "")
FIXTURES = r'''
import bmesh, bpy, sys
from mathutils import Matrix
out = sys.argv[sys.argv.index("--") + 1]
def mesh(name, build, location=(0, 0, 0)):
    me = bpy.data.meshes.new(name); bm = bmesh.new(); bm.loops.layers.uv.new("UVMap"); build(bm); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me); ob.location = location; bpy.context.scene.collection.objects.link(ob)
    return ob
def cube(name, size=2.0, location=(0, 0, 0)):
    return mesh(name, lambda bm: bmesh.ops.create_cube(bm, size=size, calc_uvs=True), location)
def plane(name, location=(0, 0, 0)):
    return mesh(name, lambda bm: bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=1.0, calc_uvs=True), location)
bpy.ops.wm.read_factory_settings(use_empty=True)
box = cube("SM_Box", location=(0, 0, 1))
box.data.materials.append(bpy.data.materials.new("M_Box"))
plane("ZF_A", location=(10, 0, 0)); plane("ZF_B", location=(10.5, 0, 0))
def body(bm):
    bmesh.ops.create_cube(bm, size=2)
    bmesh.ops.create_cube(bm, size=0.3, matrix=Matrix.Translation((0, 0, 1.6)))
mesh("Body", body, location=(20, 0, 1))
bpy.ops.wm.save_as_mainfile(filepath=out)
'''


def load():
    spec = importlib.util.spec_from_file_location("blender_qa", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class PureParts(unittest.TestCase):
    def setUp(self):
        self.qa = load()

    def test_imports_without_bpy_and_refuses_to_run_outside_blender(self):
        self.assertIsNone(self.qa.bpy)
        result = subprocess.run([sys.executable, "-I", str(SCRIPT), "--", "--objects", "A"], capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertIn("run inside Blender", result.stderr)

    def test_script_args_take_only_what_follows_the_separator(self):
        argv = ["blender", "-b", "f.blend", "--python", "blender_qa.py", "--", "--objects", "A", "B", "--strict"]
        args = self.qa.parse_args(self.qa.script_args(argv))
        self.assertEqual((args.objects, args.strict, args.profile, args.uv), (["A", "B"], True, "game", True))
        self.assertEqual(self.qa.script_args(["blender", "-b"]), [])
        with self.assertRaises(SystemExit) as caught, contextlib.redirect_stderr(io.StringIO()):
            self.qa.parse_args(["--profile", "film"])
        self.assertEqual(caught.exception.code, 2)

    def test_islands_follow_edges_and_keep_isolated_vertices_apart(self):
        self.assertEqual(self.qa.islands(6, [(0, 1), (1, 2), (3, 4)]), [0, 0, 0, 1, 1, 2])
        self.assertEqual(self.qa.islands(0, []), [])

    def test_exit_status_fails_on_errors_and_on_warnings_only_when_strict(self):
        self.assertEqual(self.qa.exit_status({"errors": [], "warnings": ["w"]}), 0)
        self.assertEqual(self.qa.exit_status({"errors": [], "warnings": ["w"]}, strict=True), 1)
        self.assertEqual(self.qa.exit_status({"errors": ["e"], "warnings": []}), 1)

    def test_every_profile_names_the_same_checks(self):
        keys = {frozenset(p) for p in self.qa.PROFILES.values()}
        self.assertEqual(len(keys), 1)
        self.assertTrue(all(v in ("e", "w", None) for p in self.qa.PROFILES.values() for v in p.values()))


@unittest.skipUnless(BLENDER and os.path.isfile(BLENDER), "set BLENDER_EXE to a Blender 5.x binary to run")
class InsideBlender(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.blend = os.path.join(cls.tmp.name, "fixtures.blend")
        builder = os.path.join(cls.tmp.name, "build.py")
        Path(builder).write_text(FIXTURES)
        subprocess.run([BLENDER, "-b", "--factory-startup", "--python-exit-code", "2", "--python", builder, "--", cls.blend],
                       check=True, capture_output=True)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def qa(self, *args):
        result = subprocess.run([BLENDER, "-b", self.blend, "--factory-startup", "--python-exit-code", "2",
                                 "--python", str(SCRIPT), "--", "--json", *args], capture_output=True, text=True)
        line = next((ln for ln in result.stdout.splitlines() if ln.startswith("{")), "{}")
        return result.returncode, json.loads(line), result

    def test_clean_cube_passes(self):
        code, report, result = self.qa("--objects", "SM_Box")
        self.assertEqual(code, 0, result.stdout + result.stderr)
        self.assertTrue(report["pass"])
        self.assertEqual((report["objects"]["SM_Box"]["tris"], report["ground_z"]), (12, 0.0))

    def test_zfighting_and_floating_parts_exit_one(self):
        code, report, _ = self.qa("--objects", "ZF_A", "ZF_B", "--no-uv")
        self.assertEqual(code, 1)
        self.assertTrue(any("ZF_A<->ZF_B" in z["where"] for z in report["zfighting"]))
        code, report, _ = self.qa("--objects", "Body", "--no-uv")
        self.assertEqual(code, 1)
        self.assertEqual([f["object"] for f in report["floating"]], ["Body"])

    def test_missing_object_and_bad_flag_exit_two(self):
        self.assertEqual(self.qa("--objects", "Nope")[0], 2)
        self.assertEqual(self.qa("--profile", "film")[0], 2)


if __name__ == "__main__":
    unittest.main()
