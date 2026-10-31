"""Every check_bpy_scripts rule has a probe; with BLENDER_EXE set, each probe runs in that Blender.
For a rule whose window covers the binary, the old API must be gone and the replacement present; otherwise only the replacement."""
import importlib.util
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "check_bpy_scripts.py"
BLENDER = os.environ.get("BLENDER_EXE", "")

PROBES = {
    "action-fcurves": ("not has('Action', 'fcurves', 'groups')", "has('ActionChannelbag', 'fcurves', 'groups') and hasattr(anim_utils, 'action_get_channelbag_for_slot')"),
    "action-id-root": ("not has('Action', 'id_root')", "has('ActionSlot', 'target_id_type')"),
    "scene-node-tree": ("not has('Scene', 'node_tree')", "has('Scene', 'compositing_node_group')"),
    "eevee-next": ("not engine_ok('BLENDER_EEVEE_NEXT')", "engine_ok('BLENDER_EEVEE')"),
    "eevee-4x": ("True", "engine_ok('BLENDER_EEVEE')"),
    "bgl": ("importlib.util.find_spec('bgl') is None", "importlib.util.find_spec('gpu') is not None"),
    "image-bindcode": ("not has('Image', 'bindcode')", "hasattr(gpu.texture, 'from_image')"),
    "idprop-addon-settings": ("raises(lambda: bpy.context.scene['cycles'], KeyError)", "has('Scene', 'cycles')"),
    "sculpt-tool": ("not has('Brush', 'sculpt_tool')", "has('Brush', 'sculpt_brush_type')"),
    "eevee-gtao": ("not has('SceneEEVEE', 'use_gtao') and not has('SceneEEVEE', 'gtao_distance') and not has('SceneEEVEE', 'gtao_quality')",
                   "has('ViewLayerEEVEE', 'ambient_occlusion_distance')"),
    "file-output-slots": ("not has('CompositorNodeOutputFile', 'file_slots') and not has('CompositorNodeOutputFile', 'layer_slots')",
                          "has('CompositorNodeOutputFile', 'directory', 'file_name', 'file_output_items')"),
    "grease-pencil-v3": ("not has('BlendData', 'grease_pencils_v3')", "has('BlendData', 'grease_pencils')"),
    "boolean-fast": ("'FAST' not in enum('BooleanModifier', 'solver')", "'FLOAT' in enum('BooleanModifier', 'solver')"),
    "space-action": ("not has('SpaceDopeSheetEditor', 'action')", "'active_action' in dir(bpy.context) or has('Context', 'active_action')"),
    "bone-select": ("not has('Bone', 'select') and not has('Bone', 'select_head') and not has('Bone', 'select_tail')",
                    "has('PoseBone', 'select') and has('EditBone', 'select_head')"),
    "use-nodes-noop": ("bpy.data.materials.new('P').node_tree is not None and bpy.data.worlds.new('P').node_tree is not None", "True"),
    "brush-stroke-flags": ("not any(has('Brush', n) for n in ('use_airbrush', 'use_anchor', 'use_space', 'use_line', 'use_curve', 'use_restore_mesh'))",
                           "has('Brush', 'stroke_method')"),
    "vse-frame-final": ("has('Strip', 'frame_final_start')", "has('Strip', 'left_handle', 'right_handle', 'duration')"),
    "gn-socket-key": ("raises(gn_idprop, TypeError)", "gn_props()"),
    "automasking": ("not has('Brush', 'use_automasking_cavity') and not has('Sculpt', 'use_automasking_cavity')",
                    "has('Brush', 'mesh_automasking_settings') and has('MeshAutomaskingSettings', 'use_automasking_cavity', 'cavity_factor')"),
    "template-palette-color": ("'color' not in params('UILayout', 'template_palette')", "'property' in params('UILayout', 'template_palette')"),
    "node-group-sockets": ("not has('NodeTree', 'inputs') and not has('NodeTree', 'outputs')", "has('NodeTree', 'interface')"),
    "ops-context-dict": ("raises(lambda: bpy.ops.object.select_all({}, action='SELECT'), (TypeError, ValueError))", "hasattr(bpy.context, 'temp_override')"),
    "auto-smooth": ("not has('Mesh', 'use_auto_smooth') and not has('Mesh', 'auto_smooth_angle')", "hasattr(bpy.ops.object, 'shade_auto_smooth')"),
    "normals-split": ("not any(has('Mesh', n) for n in ('calc_normals_split', 'free_normals_split', 'create_normals_split'))", "has('Mesh', 'corner_normals')"),
    "blend-method": ("True", "has('Material', 'surface_render_method')"),
    "too-new-compositing": ("True", "has('Scene', 'compositing_node_group')"),
    "too-new-gn-properties": ("True", "gn_props()"),
    "too-new-channelbag": ("True", "hasattr(anim_utils, 'action_get_channelbag_for_slot')"),
}

RUNNER = r'''
import bpy, gpu, importlib.util, json, sys
from bpy_extras import anim_utils
def has(t, *names):
    rna = getattr(bpy.types, t).bl_rna
    return all(n in rna.properties or n in rna.functions for n in names)
def enum(t, p):
    return [i.identifier for i in getattr(bpy.types, t).bl_rna.properties[p].enum_items]
def params(t, f):
    return [p.identifier for p in getattr(bpy.types, t).bl_rna.functions[f].parameters]
def raises(fn, exc):
    try:
        fn()
    except exc:
        return True
    return False
def engine_ok(name):
    try:
        bpy.context.scene.render.engine = name
        return True
    except TypeError:
        return False
def gn_mod():
    ng = bpy.data.node_groups.new("Probe", "GeometryNodeTree")
    ng.interface.new_socket("Geometry", in_out="INPUT", socket_type="NodeSocketGeometry")
    ng.interface.new_socket("Geometry", in_out="OUTPUT", socket_type="NodeSocketGeometry")
    sock = ng.interface.new_socket("Scale", in_out="INPUT", socket_type="NodeSocketFloat")
    ob = bpy.data.objects.new("Probe", bpy.data.meshes.new("Probe"))
    bpy.context.scene.collection.objects.link(ob)
    mod = ob.modifiers.new("GN", "NODES")
    mod.node_group = ng
    return mod, sock.identifier
def gn_idprop():
    mod, ident = gn_mod()
    mod[ident] = 2.0
def gn_props():
    mod, ident = gn_mod()
    getattr(mod.properties.inputs, ident).value = 2.0
    return getattr(mod.properties.inputs, ident).value == 2.0
probes = json.loads(open(sys.argv[sys.argv.index("--") + 1]).read())
out = {"version": list(bpy.app.version[:2])}
for rid, (gone, replacement) in probes.items():
    out[rid] = [bool(eval(gone)), bool(eval(replacement))]  # expressions come from PROBES in this test file, never from input
print("@@" + json.dumps(out))
'''


def rules():
    spec = importlib.util.spec_from_file_location("check_bpy_scripts", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class ProbeCoverage(unittest.TestCase):
    def test_every_rule_has_exactly_one_probe(self):
        self.assertEqual(sorted(r["id"] for r in rules().RULES), sorted(PROBES))


@unittest.skipUnless(BLENDER and os.path.isfile(BLENDER), "set BLENDER_EXE to a Blender binary to run")
class RulesAgainstBlender(unittest.TestCase):
    def test_old_api_is_gone_and_the_replacement_exists(self):
        mod = rules()
        with tempfile.TemporaryDirectory() as tmp:
            probes, runner = Path(tmp, "probes.json"), Path(tmp, "runner.py")
            probes.write_text(json.dumps(PROBES))
            runner.write_text(RUNNER)
            result = subprocess.run([BLENDER, "-b", "--factory-startup", "--python-exit-code", "2", "--python", str(runner),
                                     "--", str(probes)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout[-2000:] + result.stderr[-2000:])
        out = json.loads(next(ln[2:] for ln in result.stdout.splitlines() if ln.startswith("@@")))
        version = tuple(out.pop("version"))
        for rule in mod.RULES:
            gone, replacement = out[rule["id"]]
            with self.subTest(rule=rule["id"], blender=version):
                self.assertTrue(replacement, "the replacement the message names is missing")
                if mod.applies(rule, version):
                    self.assertTrue(gone, "the API this rule reports still exists")


if __name__ == "__main__":
    unittest.main()
