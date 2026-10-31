"""End-to-end tests of the read-only bpy checker CLI; no Blender needed."""
import gzip
import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "check_bpy_scripts.py"
HEADER_52 = b"BLENDER17-01v0502"  # first 17 bytes of a file saved by Blender 5.2.3 with compression off
HEADER_45 = b"BLENDER-v405"
OLD_SCRIPT = '''import bpy
from bpy_extras import anim_utils
ob = bpy.context.active_object
act = ob.animation_data.action
for fc in act.fcurves:
    print(fc.data_path)
scene = bpy.context.scene
scene.use_nodes = True
tree = scene.node_tree
scene.render.engine = 'BLENDER_EEVEE_NEXT'
mod = ob.modifiers["GeometryNodes"]
mod["Socket_2"] = 1.0
ob.data.use_auto_smooth = True
with_ctx = {"object": ob}
bpy.ops.object.shade_smooth(with_ctx)
ng = bpy.data.node_groups.new("G", "GeometryNodeTree")
ng.inputs.new("NodeSocketFloat", "Scale")
ob.modifiers.new("B", "BOOLEAN").solver = 'FAST'
mat = bpy.data.materials.new("M")
mat.use_nodes = True
'''
NEW_SCRIPT = '''import bpy
from bpy_extras import anim_utils
ob = bpy.context.active_object
cb = anim_utils.action_get_channelbag_for_slot(ob.animation_data.action, ob.animation_data.action_slot)
for fc in cb.fcurves:
    print(fc.data_path)
scene = bpy.context.scene
scene.compositing_node_group = bpy.data.node_groups.new("C", "CompositorNodeTree")
scene.render.engine = 'BLENDER_EEVEE'
mod = ob.modifiers["GeometryNodes"]
getattr(mod.properties.inputs, "Socket_2").value = 1.0
for v in ob.data.vertices:
    print(v.groups)
prefs = bpy.context.preferences.addons["cycles"].preferences
presets = {"cycles": {"samples": 64}}
print(presets["cycles"], ob.pose.bones["root"].select)
with bpy.context.temp_override(object=ob):
    bpy.ops.object.shade_smooth()
bpy.ops.wm.save_as_mainfile('EXEC_DEFAULT', filepath="/tmp/x.blend")
'''


class CheckerCli(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name) / "project with spaces"
        self.root.mkdir()

    def write(self, name, content):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        (path.write_bytes if isinstance(content, bytes) else path.write_text)(content)
        return path

    def run_check(self, *args, target=None):
        return subprocess.run([sys.executable, "-I", str(SCRIPT), str(target or self.root), *args],
                              capture_output=True, text=True)

    def report(self, *args, target=None):
        result = self.run_check("--json", *args, target=target)
        self.assertIn(result.returncode, (0, 1), result.stderr)
        return result.returncode, json.loads(result.stdout)

    def test_old_api_at_52_is_reported_by_rule_and_line(self):
        path = self.write("tools/rig.py", OLD_SCRIPT)
        original = path.read_bytes()
        code, report = self.report("--blender", "5.2")
        self.assertEqual(code, 1)
        found = {(e["rule"], e["line"]) for e in report["errors"]}
        self.assertEqual(found, {("action-fcurves", 5), ("scene-node-tree", 9), ("eevee-next", 10), ("gn-socket-key", 12),
                                 ("auto-smooth", 13), ("ops-context-dict", 15), ("node-group-sockets", 17),
                                 ("boolean-fast", 18)})
        self.assertEqual({(w["rule"], w["line"]) for w in report["warnings"]},
                         {("use-nodes-noop", 8), ("use-nodes-noop", 20)})
        self.assertEqual((report["tool"], report["schema"], report["blender"], report["blender_source"]),
                         ("check_bpy_scripts", 1, "5.2", "--blender"))
        self.assertTrue(all(e["file"] == "tools/rig.py" and e["message"] for e in report["errors"]))
        self.assertEqual(path.read_bytes(), original)

    def test_replacement_api_is_clean_at_52(self):
        self.write("tools/rig.py", NEW_SCRIPT)
        code, report = self.report("--blender", "5.2", "--strict")
        self.assertEqual((code, report["error_count"], report["warning_count"]), (0, 0, 0), report)

    def test_version_windows_flip_with_the_target(self):
        self.write("tools/rig.py", NEW_SCRIPT)
        _, report = self.report("--blender", "4.5")
        self.assertEqual(sorted({e["rule"] for e in report["errors"]}),
                         ["eevee-4x", "too-new-compositing", "too-new-gn-properties"])
        _, report = self.report("--blender", "4.3")
        self.assertIn("too-new-channelbag", {e["rule"] for e in report["errors"]})
        self.write("tools/rig.py", OLD_SCRIPT)
        _, report = self.report("--blender", "4.4")
        self.assertEqual(sorted({e["rule"] for e in report["errors"]}), ["auto-smooth", "node-group-sockets", "ops-context-dict"])

    def test_strings_and_comments_do_not_count_and_the_ok_marker_suppresses(self):
        self.write("a.py", 'import bpy\n# act.fcurves and scene.node_tree\nDOC = "act.fcurves"\n'
                           'x = bpy.context.scene.node_tree  # bpy-check: ok\n')
        code, report = self.report("--blender", "5.2")
        self.assertEqual((code, report["error_count"]), (0, 0), report)

    def test_files_without_a_bpy_import_are_not_scanned(self):
        self.write("plain.py", "act = None\nprint(act.fcurves)\n")
        self.write("py2.py", "print 'not blender'\n")
        result = self.run_check("--blender", "5.2")
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertIn("imports bpy", result.stderr)
        self.write("addon.py", "import bpy\nprint 'old'\n")
        code, report = self.report("--blender", "5.2", "--strict")
        self.assertEqual((code, report["files_checked"], [w["rule"] for w in report["warnings"]]), (1, 1, ["unparsed"]))

    def test_vendored_and_hidden_dirs_are_skipped(self):
        self.write("main.py", "import bpy\n")
        for d in ("venv", ".git", "node_modules", "__pycache__"):
            self.write(f"{d}/old.py", OLD_SCRIPT)
        code, report = self.report("--blender", "5.2")
        self.assertEqual((code, report["files_checked"], report["error_count"]), (0, 1, 0))

    def test_target_comes_from_the_newest_blend_header(self):
        self.write("tools/rig.py", OLD_SCRIPT)
        self.write("art/old.blend", HEADER_45 + b"\0" * 64)
        self.write("art/new.blend", HEADER_52 + b"\0" * 64)
        code, report = self.report()
        self.assertEqual((code, report["blender"], report["blender_source"]), (1, "5.2", "art/new.blend"))
        self.write("art/new.blend", gzip.compress(HEADER_45 + b"\0" * 64))
        _, report = self.report()
        self.assertEqual(report["blender"], "4.5")

    def test_blend_version_reads_both_header_layouts_and_gzip(self):
        new = self.write("a.blend", HEADER_52 + b"REND")
        old = self.write("b.blend", HEADER_45 + b"REND")
        packed = self.write("c.blend", gzip.compress(b"BLENDER_v279REND"))
        result = subprocess.run([sys.executable, "-I", str(SCRIPT), "--blend-version", str(new), str(old), str(packed)],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("a.blend: Blender 5.2 (header format 1)", result.stdout)
        self.assertIn("b.blend: Blender 4.5 (header format 0)", result.stdout)
        self.assertIn("c.blend: Blender 2.79 (header format 0)", result.stdout)

    def test_zstd_blend_is_read_or_named_as_unreadable(self):
        try:
            from compression import zstd
            data = zstd.compress(HEADER_52 + b"\0" * 4096)
        except ImportError:
            zstd, data = None, b"\x28\xb5\x2f\xfd" + b"\0" * 64
        path = self.write("z.blend", data)
        result = subprocess.run([sys.executable, "-I", str(SCRIPT), "--blend-version", str(path)], capture_output=True, text=True)
        if zstd:
            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertIn("Blender 5.2", result.stdout)
        else:
            self.assertEqual(result.returncode, 2, result.stdout)
            self.assertIn("zstd-compressed", result.stdout)

    def test_unknown_header_and_bad_arguments_exit_two(self):
        self.write("main.py", "import bpy\n")
        future = self.write("f.blend", b"BLENDER19-02v0601" + b"\0" * 8)
        result = subprocess.run([sys.executable, "-I", str(SCRIPT), "--blend-version", str(future)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertIn("unknown, probably newer", result.stdout)
        for args, target in ((("--blender", "5"), None), ((), None), (("--blender", "5.2"), self.root / "missing"),
                             (("--blender", "5.2"), self.write("notes.txt", "x")), (("--max-issues", "-1"), None)):
            with self.subTest(args=args, target=target):
                result = self.run_check(*args, target=target)
                self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertIn("pass --blender", self.run_check().stderr)

    def test_text_output_and_truncation(self):
        self.write("tools/rig.py", OLD_SCRIPT)
        result = self.run_check("--blender", "5.2", "--max-issues", "2")
        self.assertEqual(result.returncode, 1)
        self.assertIn("target: Blender 5.2 (from --blender)", result.stdout)
        self.assertIn("ERROR tools/rig.py:5: [action-fcurves]", result.stdout)
        self.assertIn("... and 8 more", result.stdout)
        self.assertIn("Summary: 8 errors, 2 warnings in 1 files checked", result.stdout)


class RuleTable(unittest.TestCase):
    def test_rule_ids_unique_and_windows_ordered(self):
        spec = importlib.util.spec_from_file_location("check_bpy_scripts", SCRIPT)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        ids = [r["id"] for r in mod.RULES]
        self.assertEqual(len(ids), len(set(ids)))
        for r in mod.RULES:
            lo, hi = r["window"]
            self.assertTrue(hi is None or lo < hi, r["id"])
            self.assertIn(r["level"], ("error", "warning"))


if __name__ == "__main__":
    unittest.main()
