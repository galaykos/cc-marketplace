"""anim_audit.py: the verdicts in plain Python; the exporters and exit codes inside a real Blender only when BLENDER_EXE is set."""
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "anim_audit.py"
BLENDER = os.environ.get("BLENDER_EXE", "")
spec = importlib.util.spec_from_file_location("anim_audit", SCRIPT)
aa = importlib.util.module_from_spec(spec)
spec.loader.exec_module(aa)


def act(users=(), fake_only=False, curves=1, stale=(), nla=False):
    return {"users": list(users), "fake_only": fake_only, "nla": nla, "curves": curves, "stale": list(stale)}


class Verdicts(unittest.TestCase):
    def test_fbx_stack_names_are_read_from_binary(self):
        raw = b"\x00Hero|Walk\x00\x01AnimStack\x00junk\x00Crate|Slide\x00\x01AnimStack\x00Hero\x00\x01Model"
        self.assertEqual(aa.fbx_stacks(raw), ["Crate|Slide", "Hero|Walk"])

    def test_gltf_clip_range_comes_from_sampler_inputs(self):
        doc = {"accessors": [{"min": [4.2], "max": [5.1]}, {"min": [4.5], "max": [5.3]}],
               "animations": [{"name": "Late", "samplers": [{"input": 0}, {"input": 1}]}]}
        self.assertEqual(aa.gltf_clips(doc), [("Late", 4.2, 5.3)])

    def test_cross_clip_and_stale_drop_are_errors(self):
        actions = {"Walk": act(["Hero"]), "Slide": act(["Crate"]), "Run": act(["Hero"], stale=[("Hero", 'pose.bones["Gone"].location')])}
        errors, _ = aa.judge(actions, ["Hero|Walk", "Crate|Slide", "Hero|Slide"], None, 24)
        kinds = {(c, a) for c, a, _ in errors}
        self.assertEqual(kinds, {("fbx-cross", "Slide"), ("fbx-dropped", "Run")})
        self.assertIn("Gone", next(m for c, a, m in errors if c == "fbx-dropped"))

    def test_nla_strip_stacks_count_and_a_double_ship_warns(self):
        actions = {"Walk": act(["Hero"], nla=True)}
        self.assertEqual(aa.judge(actions, ["Walk"], None, 24), ([], []))
        _, warnings = aa.judge(actions, ["Walk", "Hero|Walk"], None, 24)
        self.assertEqual([(c, a) for c, a, _ in warnings], [("fbx-duplicate", "Walk")])

    def test_all_actions_off_drops_an_action_on_no_nla_track(self):
        errors, _ = aa.judge({"Walk": act(["Hero"])}, [], None, 24, all_actions=False)
        self.assertEqual([(c, a) for c, a, _ in errors], [("fbx-dropped", "Walk")])
        self.assertIn("NLA-track strips only", errors[0][2])

    def test_one_scene_take_is_a_warning_not_a_drop(self):
        errors, warnings = aa.judge({"Walk": act(["Hero"])}, ["Scene"], None, 24, scene="Scene", all_actions=False)
        self.assertEqual((errors, [(c, a) for c, a, _ in warnings]), ([], [("fbx-scene-take", "Scene")]))

    def test_clean_export_has_no_findings(self):
        actions = {"Walk": act(["Hero"]), "Empty": act(curves=0)}
        self.assertEqual(aa.judge(actions, ["Hero|Walk"], [("Walk", 1 / 24, 1.0)], 24, ["Walk"]), ([], []))

    def test_gltf_late_start_and_fake_user_are_warnings(self):
        actions = {"Late": act(["L"]), "Idle": act(fake_only=True)}
        errors, warnings = aa.judge(actions, None, [("Late", 4.208, 5.166)], 24)
        self.assertEqual(errors, [])
        self.assertEqual({(c, a) for c, a, _ in warnings}, {("gltf-late-start", "Late"), ("gltf-fake-user", "Idle")})
        self.assertIn("frame 101", next(m for c, a, m in warnings if c == "gltf-late-start"))

    def test_first_frame_start_is_not_late(self):
        self.assertEqual(aa.judge({"W": act(["H"])}, None, [("W", 1 / 24, 1.0)], 24), ([], []))

    def test_expect_names_missing_and_extra(self):
        errors, _ = aa.judge({"Walk": act(["H"])}, ["H|Walk"], [("Walk", 0.0, 1.0)], 24, ["Walk", "Run"])
        self.assertEqual([(c, a) for c, a, _ in errors], [("expect-missing", "Run")])
        errors, _ = aa.judge({"Walk": act(["H"])}, ["H|Walk"], None, 24, [])
        self.assertEqual([(c, a) for c, a, _ in errors], [("expect-extra", "Walk")])

    def test_loop_verdict_reports_the_worst_channel(self):
        q = (1.0, 0.0, 0.0, 0.0)
        self.assertEqual(aa.loop_verdict("W", {"a": ((0, 0, 0), q)}, {"a": ((0, 0, 0.0005), q)}, 0.001), "")
        self.assertIn("a moves 0.5000 m", aa.loop_verdict("W", {"a": ((0, 0, 0), q)}, {"a": ((0.5, 0, 0), q)}, 0.001))

    def test_override_parser_reads_literals(self):
        self.assertEqual(aa.option("bake_anim_use_all_actions=False"), ("bake_anim_use_all_actions", False))
        self.assertEqual(aa.option("axis_forward=-Z"), ("axis_forward", "-Z"))

    def test_outside_blender_it_exits_two(self):
        result = subprocess.run([sys.executable, "-I", str(SCRIPT), "--"], capture_output=True, text=True)
        self.assertEqual(result.returncode, 2, result.stderr)


BUILD = '''
import bpy, sys
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene; sc.render.fps = 24
def empty(name):
    ob = bpy.data.objects.new(name, None); sc.collection.objects.link(ob); return ob
def key(ob, name, frames):
    ob.animation_data_create(); a = bpy.data.actions.new(name); ob.animation_data.action = a
    for f, v in frames:
        ob.location[0] = v; ob.keyframe_insert("location", index=0, frame=f)
    return a
key(empty("Hero"), "Walk", [(1, 0), (24, 0.5), (48, 0)])
key(empty("Crate"), "CrateSlide", [(1, 0), (24, 2)])
key(empty("Late"), "LateClip", [(101, 0), (124, 1)])
bpy.ops.wm.save_as_mainfile(filepath=sys.argv[sys.argv.index("--") + 1])
'''
BUILD_NLA = BUILD.replace("ob.animation_data.action = a", "ob.animation_data.action = a").replace(
    "    return a\n", "    ob.animation_data.action = None\n    ob.animation_data.nla_tracks.new().strips.new(name, int(frames[0][0]), a)\n    return a\n")


@unittest.skipUnless(BLENDER and os.path.isfile(BLENDER), "set BLENDER_EXE to a Blender 5.x binary to run")
class InBlender(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.blend = os.path.join(cls.tmp.name, "scene.blend")
        cls.nla = os.path.join(cls.tmp.name, "nla.blend")
        for source, out in ((BUILD, cls.blend), (BUILD_NLA, cls.nla)):
            builder = os.path.join(cls.tmp.name, "build.py")
            Path(builder).write_text(source)
            subprocess.run([BLENDER, "-b", "--factory-startup", "--python-exit-code", "2", "--python", builder, "--", out],
                           check=True, capture_output=True)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def audit(self, *args, blend=None):
        result = subprocess.run([BLENDER, "-b", blend or self.blend, "--factory-startup", "--python-exit-code", "2",
                                 "--python", str(SCRIPT), "--", "--json", *args], capture_output=True, text=True)
        start = result.stdout.find("{\n")
        return result.returncode, json.loads(result.stdout[start:]) if start >= 0 else None

    def test_default_fbx_ships_cross_clips_and_gltf_starts_late(self):
        code, report = self.audit()
        self.assertEqual(code, 1)
        self.assertIn("Hero|CrateSlide", report["fbx_stacks"])
        self.assertIn(("fbx-cross", "CrateSlide"), {(e["check"], e["action"]) for e in report["errors"]})
        late = [w for w in report["warnings"] if w["check"] == "gltf-late-start"]
        self.assertEqual([w["action"] for w in late], ["LateClip"])

    def test_nla_tracks_with_all_actions_off_and_slide_to_zero_is_clean(self):
        code, report = self.audit("--fbx", "bake_anim_use_all_actions=False", "--gltf", "export_anim_slide_to_zero=True",
                                  "--expect", "Walk", "CrateSlide", "LateClip", "--strict", blend=self.nla)
        self.assertEqual((code, report["errors"], report["warnings"]), (0, [], []), report)

    def test_all_actions_off_drops_active_only_actions(self):
        code, report = self.audit("--format", "fbx", "--fbx", "bake_anim_use_all_actions=False")
        self.assertEqual(code, 1)
        self.assertEqual({e["action"] for e in report["errors"] if e["check"] == "fbx-dropped"}, {"Walk", "CrateSlide", "LateClip"})

    def test_loop_pop_is_an_error_and_a_closed_loop_is_not(self):
        code, report = self.audit("--format", "gltf", "--gltf", "export_anim_slide_to_zero=True", "--loop", "Walk", "CrateSlide")
        self.assertEqual(code, 1)
        self.assertEqual([(e["check"], e["action"]) for e in report["errors"]], [("loop-pop", "CrateSlide")])

    def test_a_refused_override_is_a_could_not_run(self):
        code, _ = self.audit("--fbx", "no_such_option=1")
        self.assertEqual(code, 2)


if __name__ == "__main__":
    unittest.main()
