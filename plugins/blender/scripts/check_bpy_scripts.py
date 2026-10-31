#!/usr/bin/env python3
"""Catches bpy calls a target Blender version removed or renamed, by AST scan of .py files that import bpy; reads .blend header versions.
Does NOT run Blender or know types: an attribute is judged by its name and its receiver's spelling, so a renamed
variable hides a call and an unrelated object with a matching name is reported. Errors are breaks, warnings deprecations."""
# Rule facts distilled from EL4CTEO/blender-skills@71d031d (MIT) and re-verified; the code is original.
# Why, limits, history: rationale/derivations/plugin-blender.md § plugins/blender/scripts/check_bpy_scripts.py
import argparse
import ast
import gzip
import json
import os
import re
import sys
from pathlib import Path

TOOL = "check_bpy_scripts"
SCHEMA = 1
SKIP_DIRS = {"__pycache__", "node_modules", "venv", "site-packages", "dist", "build"}
BPY_MODULES = {"bpy", "bpy_extras", "bgl", "bmesh", "gpu"}
OK_MARK = "bpy-check: ok"
IMPORT_LINE = re.compile(r"(?m)^\s*(?:import|from)\s+(?:bpy|bpy_extras|bgl|bmesh|gpu)\b")

ACTION = r"(?i)(?:^|\.)(?:act|action|\w+_action)$|actions\[[^\]]*\]$|actions\.(?:new|get)\(.*\)$"
SCENE = r"(?i)(?:^|\.)(?:scene|scn|sc)$|scenes\[[^\]]*\]$"
NODE_GROUP = r"(?i)(?:^|\.)(?:ng|group|node_group|node_tree|tree|\w+_group|\w+_tree)$|node_groups\[[^\]]*\]$|node_groups\.new\(.*\)$"
BONE = r"\.bones\[[^\]]*\]$|\.bones\.active$"
SHADED = r"(?i)(?:^|\.)(?:mat|material|world|scene|scn|sc|\w+_mat|\w+_material)$|(?:materials|worlds|scenes)\[[^\]]*\]$"
ID_LIKE = r"(?i)(?:^|\.)(?:scene|scn|sc|ob|obj|object|world|mat|material|view_layer|camera|light)$|(?:scenes|objects|materials)\[[^\]]*\]$"
FOREVER = None

# A rule fires for targets from the first version of its window up to, not including, the second.
RULES = [
    dict(id="action-fcurves", kind="attr", names={"fcurves", "groups"}, recv=ACTION, window=((5, 0), FOREVER), level="error",
         msg="Action.fcurves/groups removed in 5.0: get a channelbag with bpy_extras.anim_utils.action_get_channelbag_for_slot(action, slot) and use .fcurves/.groups on it"),
    dict(id="action-id-root", kind="attr", names={"id_root"}, window=((5, 0), FOREVER), level="error",
         msg="Action.id_root removed in 5.0: read action_slot.target_id_type"),
    dict(id="scene-node-tree", kind="attr", names={"node_tree"}, recv=SCENE, window=((5, 0), FOREVER), level="error",
         msg="Scene.node_tree removed in 5.0: scene.compositing_node_group = bpy.data.node_groups.new(name, 'CompositorNodeTree')"),
    dict(id="eevee-next", kind="string", values={"BLENDER_EEVEE_NEXT"}, window=((5, 0), FOREVER), level="error",
         msg="'BLENDER_EEVEE_NEXT' is not an engine in 5.0+: the identifier is 'BLENDER_EEVEE' again"),
    dict(id="eevee-4x", kind="string", values={"BLENDER_EEVEE"}, window=((4, 2), (5, 0)), level="error",
         msg="'BLENDER_EEVEE' is not an engine in 4.2-4.5: those versions name it 'BLENDER_EEVEE_NEXT'"),
    dict(id="bgl", kind="import", names={"bgl"}, window=((5, 0), FOREVER), level="error",
         msg="the bgl module was removed in 5.0: draw with the gpu module and gpu_extras"),
    dict(id="image-bindcode", kind="attr", names={"bindcode"}, window=((5, 0), FOREVER), level="error",
         msg="Image.bindcode removed in 5.0: gpu.texture.from_image(image)"),
    dict(id="idprop-addon-settings", kind="key", keys=r"^(?:cycles|eevee)$", recv=ID_LIKE, window=((5, 0), FOREVER), level="error",
         msg="5.0 removed dict access to add-on property groups: obj['cycles'] is a KeyError, use obj.cycles"),
    dict(id="sculpt-tool", kind="attr", names={"sculpt_tool"}, window=((5, 0), FOREVER), level="error",
         msg="Brush.sculpt_tool renamed in 5.0: brush.sculpt_brush_type"),
    dict(id="eevee-gtao", kind="attr", names={"use_gtao", "gtao_distance", "gtao_quality"}, window=((5, 0), FOREVER), level="error",
         msg="SceneEEVEE gtao settings removed in 5.0: view_layer.eevee.ambient_occlusion_distance"),
    dict(id="file-output-slots", kind="attr", names={"file_slots", "layer_slots"}, window=((5, 0), FOREVER), level="error",
         msg="File Output node slots removed in 5.0: node.directory, node.file_name, node.file_output_items"),
    dict(id="grease-pencil-v3", kind="attr", names={"grease_pencils_v3"}, window=((5, 0), FOREVER), level="error",
         msg="bpy.data.grease_pencils_v3 renamed in 5.0: bpy.data.grease_pencils"),
    dict(id="boolean-fast", kind="value", names={"solver"}, values={"FAST"}, window=((5, 0), FOREVER), level="error",
         msg="Boolean solver 'FAST' renamed in 5.0: 'FLOAT' (solvers are FLOAT, EXACT, MANIFOLD)"),
    dict(id="space-action", kind="attr", names={"action"}, recv=r"space_data$", window=((5, 0), FOREVER), level="error",
         msg="context.space_data.action removed in 5.0: context.active_action"),
    dict(id="bone-select", kind="attr", names={"select", "select_head", "select_tail"}, recv=BONE, recv_not=r"pose\.bones", window=((5, 0), FOREVER), level="error",
         msg="Bone.select/select_head/select_tail removed in 5.0: pose_bone.select, or edit_bone.select* in Edit Mode"),
    dict(id="use-nodes-noop", kind="value", names={"use_nodes"}, values={True}, recv=SHADED, window=((5, 0), FOREVER), level="warning",
         msg="use_nodes is deprecated in 5.0 and has no effect (removal planned for 6.0): new materials and worlds already have a node tree"),
    dict(id="brush-stroke-flags", kind="attr", names={"use_airbrush", "use_anchor", "use_space", "use_line", "use_curve", "use_restore_mesh"},
         recv=r"(?i)brush", window=((5, 1), FOREVER), level="error",
         msg="Brush stroke flags folded into brush.stroke_method in 5.1 ('AIRBRUSH', 'ANCHORED', 'SPACE', 'LINE', 'CURVE', 'DRAG_DOT')"),
    dict(id="vse-frame-final", kind="attr", names={"frame_final_start", "frame_final_end", "frame_final_duration", "frame_offset_start", "frame_offset_end"},
         window=((5, 1), FOREVER), level="warning",
         msg="strip time properties deprecated in 5.1 (removal planned for 6.0): left_handle, right_handle, duration, left_handle_offset, right_handle_offset"),
    dict(id="gn-socket-key", kind="key", keys=r"^Socket_\d+(?:_use_attribute|_attribute_name)?$", window=((5, 2), FOREVER), level="error",
         msg="5.2 removed ID-property access on Geometry Nodes modifiers (TypeError): getattr(mod.properties.inputs, identifier).value, .type = 'ATTRIBUTE', .attribute_name"),
    dict(id="automasking", kind="attr", pattern=r"^(?:use_automasking_\w+|automasking_\w+)$", recv=r"(?i)(?:^|\.)(?:\w*brush|sculpt|paint)$",
         window=((5, 2), FOREVER), level="error",
         msg="sculpt automasking settings moved in 5.2 to brush/paint .mesh_automasking_settings (factor names lose the automasking_ prefix)"),
    dict(id="template-palette-color", kind="kwarg", func="template_palette", names={"color"}, window=((5, 2), FOREVER), level="error",
         msg="UILayout.template_palette lost its color argument in 5.2"),
    dict(id="node-group-sockets", kind="call", func="new", recv=r"(?:^|\.)(?:inputs|outputs)$", recv_owner=NODE_GROUP,
         window=((4, 0), FOREVER), level="error",
         msg="NodeTree.inputs/outputs removed in 4.0: tree.interface.new_socket(name, in_out='INPUT', socket_type='NodeSocketFloat')"),
    dict(id="ops-context-dict", kind="ops", window=((4, 0), FOREVER), level="error",
         msg="4.0 removed the context-override argument of bpy.ops: with bpy.context.temp_override(**overrides): bpy.ops..."),
    dict(id="auto-smooth", kind="attr", names={"use_auto_smooth", "auto_smooth_angle"}, window=((4, 1), FOREVER), level="error",
         msg="Mesh auto smooth removed in 4.1: Smooth by Angle (bpy.ops.object.shade_auto_smooth or shade_smooth_by_angle) and the sharp_edge attribute"),
    dict(id="normals-split", kind="attr", names={"calc_normals_split", "free_normals_split", "create_normals_split"}, window=((4, 1), FOREVER), level="error",
         msg="split-normal functions removed in 4.1: read mesh.corner_normals"),
    dict(id="blend-method", kind="attr", names={"blend_method"}, recv_not=r"(?i)gpencil|grease", window=((4, 2), FOREVER), level="warning",
         msg="Material.blend_method is the pre-4.2 EEVEE setting: set material.surface_render_method ('DITHERED' or 'BLENDED')"),
    dict(id="too-new-compositing", kind="attr", names={"compositing_node_group"}, window=((0, 0), (5, 0)), level="error",
         msg="scene.compositing_node_group does not exist before 5.0: use scene.use_nodes and scene.node_tree there"),
    dict(id="too-new-gn-properties", kind="attr", names={"inputs", "outputs"}, recv=r"\.properties$", window=((0, 0), (5, 2)), level="error",
         msg="modifier.properties.inputs does not exist before 5.2: use modifier[identifier] there"),
    dict(id="too-new-channelbag", kind="name", names={"action_get_channelbag_for_slot"}, window=((0, 0), (4, 4)), level="error",
         msg="anim_utils.action_get_channelbag_for_slot does not exist before 4.4: use action.fcurves there"),
]


def parse_version(text):
    m = re.fullmatch(r"(\d+)\.(\d+)(?:\.\d+)?", text.strip())
    if not m:
        raise ValueError(f"not a Blender version: {text!r} (expected e.g. 5.2)")
    return int(m.group(1)), int(m.group(2))


def decode_header(head):
    """Return (major, minor, format) from the first 17 bytes of an uncompressed .blend, else raise ValueError."""
    if head[:7] != b"BLENDER":
        raise ValueError("not a .blend header")
    if head[7:8] in (b"_", b"-"):
        if head[8:9] not in (b"v", b"V") or not head[9:12].isdigit():
            raise ValueError("unknown legacy header")
        number, fmt = int(head[9:12]), 0
    elif head[7:9] == b"17" and head[9:10] == b"-" and head[10:12] == b"01" and head[12:13] == b"v" and head[13:17].isdigit():
        number, fmt = int(head[13:17]), 1
    else:
        raise ValueError("a .blend from an unknown, probably newer, header format")
    return number // 100, number % 100, fmt


def read_blend_header(path):
    with open(path, "rb") as f:
        raw = f.read(1 << 20)
    if raw[:3] == b"\x1f\x8b\x08":
        with gzip.open(path, "rb") as g:
            raw = g.read(17)
    elif raw[:4] == b"\x28\xb5\x2f\xfd" or (raw[1:4] == b"\x2a\x4d\x18" and raw[0] & 0xF0 == 0x50):
        try:
            from compression import zstd
        except ImportError:
            raise ValueError("zstd-compressed (the 5.0+ default); Python 3.14+ is needed to read it") from None
        raw = zstd.ZstdDecompressor().decompress(raw, max_length=17)
    return decode_header(raw[:17])


def find_files(root, suffix):
    out = []

    def walk_error(error):
        raise error

    for directory, dirs, names in os.walk(root, onerror=walk_error):
        dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS and not d.startswith("."))
        out += [Path(directory) / n for n in sorted(names) if n.endswith(suffix)]
    return out


def imports_bpy(tree):
    for node in ast.walk(tree):
        if isinstance(node, ast.Import) and any(a.name.split(".")[0] in BPY_MODULES for a in node.names):
            return True
        if isinstance(node, ast.ImportFrom) and node.level == 0 and (node.module or "").split(".")[0] in BPY_MODULES:
            return True
    return False


def applies(rule, target):
    lo, hi = rule["window"]
    return target >= lo and (hi is None or target < hi)


def receiver(node):
    try:
        return ast.unparse(node)
    except Exception:
        return ""


def recv_ok(rule, text):
    if "recv" in rule and not re.search(rule["recv"], text):
        return False
    return not ("recv_not" in rule and re.search(rule["recv_not"], text))


def name_ok(rule, name):
    return name in rule["names"] if "names" in rule else bool(re.search(rule["pattern"], name))


def is_bpy_ops(func):
    text = receiver(func)
    return text.startswith("bpy.ops.") and text.count(".") >= 3


def value_hits(node, rule):
    """Assignments `x.solver = 'FAST'` and keywords `solver='FAST'` whose constant is in rule['values']."""
    def hit(value):
        return isinstance(value, ast.Constant) and type(value.value) in (str, bool) and value.value in rule["values"] \
            and isinstance(value.value, bool) == any(isinstance(v, bool) for v in rule["values"])
    if isinstance(node, ast.Assign) and hit(node.value):
        for target in node.targets:
            if isinstance(target, ast.Attribute) and target.attr in rule["names"] and recv_ok(rule, receiver(target.value)):
                yield target
    elif isinstance(node, ast.Call) and "recv" not in rule:
        for k in node.keywords:
            if k.arg in rule["names"] and hit(k.value):
                yield k


def scan_tree(tree, rules):
    """Yield (line, rule) for every rule a node matches."""
    for node in ast.walk(tree):
        line = getattr(node, "lineno", 0)
        for rule in rules:
            kind = rule["kind"]
            if kind == "attr" and isinstance(node, ast.Attribute) and name_ok(rule, node.attr) and recv_ok(rule, receiver(node.value)):
                yield line, rule
            elif kind == "string" and isinstance(node, ast.Constant) and isinstance(node.value, str) and node.value in rule["values"]:
                yield line, rule
            elif kind == "import" and isinstance(node, (ast.Import, ast.ImportFrom)):
                mods = [a.name for a in node.names] if isinstance(node, ast.Import) else [node.module or ""]
                if any(m.split(".")[0] in rule["names"] for m in mods):
                    yield line, rule
            elif kind == "name" and isinstance(node, (ast.Name, ast.Attribute)):
                if (node.id if isinstance(node, ast.Name) else node.attr) in rule["names"]:
                    yield line, rule
            elif kind == "key" and isinstance(node, ast.Subscript) and isinstance(node.slice, ast.Constant) \
                    and isinstance(node.slice.value, str) and re.search(rule["keys"], node.slice.value) and recv_ok(rule, receiver(node.value)):
                yield line, rule
            elif kind == "value":
                for _ in value_hits(node, rule):
                    yield line, rule
            elif kind == "kwarg" and isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) \
                    and node.func.attr == rule["func"] and any(k.arg in rule["names"] for k in node.keywords):
                yield line, rule
            elif kind == "call" and isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) and node.func.attr == rule["func"]:
                owner = node.func.value
                if isinstance(owner, ast.Attribute) and recv_ok(rule, receiver(owner)) and re.search(rule["recv_owner"], receiver(owner.value)):
                    yield line, rule
            elif kind == "ops" and isinstance(node, ast.Call) and is_bpy_ops(node.func) and node.args:
                first = node.args[0]
                if not (isinstance(first, ast.Constant) and isinstance(first.value, (str, bool))) and not isinstance(first, ast.JoinedStr):
                    yield line, rule


def scan_file(path, rules):
    source = path.read_text(encoding="utf-8", errors="replace")
    try:
        tree = ast.parse(source, filename=str(path))
    except SyntaxError as error:
        if not IMPORT_LINE.search(source):
            return False, []
        return True, [("warning", error.lineno or 0, "unparsed", f"not scanned: {error.msg} (Python 2 or a syntax error)")]
    if not imports_bpy(tree):
        return False, []
    lines = source.splitlines()
    seen, found = set(), []
    for line, rule in scan_tree(tree, rules):
        if (line, rule["id"]) in seen or (0 < line <= len(lines) and OK_MARK in lines[line - 1]):
            continue
        seen.add((line, rule["id"]))
        found.append((rule["level"], line, rule["id"], rule["msg"]))
    return True, found


def resolve_target(args, root):
    if args.blender:
        return parse_version(args.blender), "--blender"
    best, source = None, None
    for blend in find_files(root, ".blend"):
        try:
            major, minor, _ = read_blend_header(blend)
        except (OSError, ValueError) as error:
            print(f"note: {blend.relative_to(root).as_posix()}: {error}", file=sys.stderr)
            continue
        if best is None or (major, minor) > best:
            best, source = (major, minor), blend.relative_to(root).as_posix()
    if best is None:
        raise ValueError("no target version: pass --blender X.Y (no readable .blend header under the path)")
    return best, source


def print_versions(paths):
    status = 0
    for p in paths:
        try:
            major, minor, fmt = read_blend_header(p)
            print(f"{p}: Blender {major}.{minor} (header format {fmt})")
        except (OSError, ValueError) as error:
            print(f"{p}: unreadable: {error}")
            status = 2
    return status


def main(argv=None):
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(errors="backslashreplace")
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter,
                                 epilog="exit status: 0 = no errors, 1 = errors (or warnings with --strict), 2 = bad arguments,\n"
                                        "no target version, no .py file importing bpy, or (with --blend-version) an unreadable header.\n"
                                        "suppress one line with a trailing comment: # bpy-check: ok\n"
                                        "examples:\n  check_bpy_scripts.py . --blender 5.2\n  check_bpy_scripts.py --blend-version assets/hero.blend")
    ap.add_argument("path", nargs="?", default=".", help="project directory or a single .py file (default: .)")
    ap.add_argument("--blender", metavar="X.Y", help="target Blender version; default: the newest .blend header under the path")
    ap.add_argument("--blend-version", nargs="+", metavar="FILE", help="print the version that saved each .blend, then exit")
    ap.add_argument("--json", action="store_true", help="print one JSON object instead of text")
    ap.add_argument("--strict", action="store_true", help="exit 1 on warnings too")
    ap.add_argument("--max-issues", type=int, default=50, metavar="N", help="show at most N issues (default: 50; 0 = no limit)")
    args = ap.parse_args(argv)
    if args.max_issues < 0:
        ap.error("--max-issues must be 0 or more")
    if args.blend_version:
        return print_versions(args.blend_version)

    target = Path(args.path).expanduser().resolve()
    if not target.exists():
        print(f"error: {target} does not exist", file=sys.stderr)
        return 2
    if target.is_file() and target.suffix != ".py":
        print("error: not a .py file", file=sys.stderr)
        return 2
    root = target if target.is_dir() else target.parent
    try:
        version, version_source = resolve_target(args, root)
        files = [target] if target.is_file() else find_files(target, ".py")
    except (OSError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 2
    rules = [r for r in RULES if applies(r, version)]
    findings, checked = [], 0
    for path in files:
        try:
            scanned, found = scan_file(path, rules)
        except OSError as error:
            print(f"error: cannot read {path}: {error}", file=sys.stderr)
            return 2
        checked += scanned
        rel = path.relative_to(root).as_posix()
        findings += [{"level": lvl, "file": rel, "line": line, "rule": rid, "message": msg} for lvl, line, rid, msg in found]
    if not checked:
        print("error: no .py file under the path imports bpy, bpy_extras, bmesh, bgl or gpu", file=sys.stderr)
        return 2
    findings.sort(key=lambda f: (f["file"], f["line"], f["rule"]))
    errors = [f for f in findings if f["level"] == "error"]
    warnings = [f for f in findings if f["level"] == "warning"]
    shown = findings[:args.max_issues] if args.max_issues else findings
    blender = f"{version[0]}.{version[1]}"
    if args.json:
        print(json.dumps({"tool": TOOL, "schema": SCHEMA, "root": root.as_posix(), "blender": blender,
                          "blender_source": version_source, "files_checked": checked,
                          "error_count": len(errors), "warning_count": len(warnings),
                          "errors": [f for f in shown if f["level"] == "error"],
                          "warnings": [f for f in shown if f["level"] == "warning"],
                          "truncated": len(shown) < len(findings)}, indent=2))
    else:
        print(f"target: Blender {blender} (from {version_source})")
        for f in shown:
            print(f"{f['level'].upper()} {f['file']}:{f['line']}: [{f['rule']}] {f['message']}")
        if len(shown) < len(findings):
            print(f"... and {len(findings) - len(shown)} more")
        print(f"Summary: {len(errors)} errors, {len(warnings)} warnings in {checked} files checked")
    return 1 if errors or (args.strict and warnings) else 0


if __name__ == "__main__":
    sys.exit(main())
