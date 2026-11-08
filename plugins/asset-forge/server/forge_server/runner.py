"""Executed inside Blender (blender -b ... --python runner.py -- <request.json>). Reads {op, args, result_path},
runs the op, writes a JSON dict to result_path. Every op returns {"ok": bool, ...}."""
import importlib
import json
import os
import re
import sys
import traceback
from pathlib import Path

import bpy


def _settable_render_engines():
    scene = bpy.context.scene
    original = scene.render.engine
    candidates = {item.identifier for item in scene.render.bl_rna.properties["engine"].enum_items}
    candidates |= {cls.bl_idname for cls in bpy.types.RenderEngine.__subclasses__() if getattr(cls, "bl_idname", "")}
    # The static enum omits built-in engines such as Workbench; the refusal message lists the live set.
    try:
        scene.render.engine = "__asset_forge_probe__"
    except TypeError as exc:
        candidates |= set(re.findall(r"'([A-Z0-9_]+)'", str(exc)))
    settable = []
    for engine in sorted(candidates):
        try:
            scene.render.engine = engine
            settable.append(engine)
        except TypeError:
            pass
    scene.render.engine = original
    return settable


def op_env():
    try:
        import numpy
        numpy_version = numpy.__version__
    except ImportError:
        numpy_version = None
    return {
        "ok": True,
        "version": list(bpy.app.version),
        "version_string": bpy.app.version_string,
        "python": sys.version.split()[0],
        "numpy": numpy_version,
        "render_engines": _settable_render_engines(),
        "file": bpy.data.filepath or None,
    }


LIB = Path(__file__).resolve().parents[2] / "blender_lib"


def op_call(module, function, kwargs=None, save_copy_to=None):
    """Run forge.<module>.<function>(**kwargs) on the opened file. save_copy_to: write the result scene as a copy
    (the opened snapshot itself is never saved over). A result that is not a dict comes back as {"ok": True, "value"}."""
    opened = bpy.data.filepath
    if save_copy_to and opened and Path(save_copy_to).exists() and os.path.samefile(save_copy_to, opened):
        raise ValueError("save_copy_to is the opened file; a headless job never saves over its source")
    if str(LIB) not in sys.path:
        sys.path.insert(0, str(LIB))
    if function.startswith("_") or not re.fullmatch(r"[a-z_]+", module):
        raise ValueError(f"not a public forge function: {module}.{function}")
    fn = getattr(importlib.import_module(f"forge.{module}"), function)
    result = fn(**(kwargs or {}))
    if not isinstance(result, dict):
        result = {"ok": True, "value": result}
    if save_copy_to:
        bpy.ops.wm.save_as_mainfile(filepath=str(save_copy_to), copy=True)
        result["saved_copy"] = str(save_copy_to)
    return result


def op_validate_source(objects, **kwargs):
    """forge.validate.validate_asset(**kwargs) on the first MESH among `objects` (names); "object" names it."""
    mesh = next((n for n in objects if getattr(bpy.data.objects.get(n), "type", None) == "MESH"), None)
    if mesh is None:  # an armature-only animation export has no mesh to validate; that is not a failure
        return {"ok": True, "skipped": f"no mesh among {objects}: nothing to validate", "checks": []}
    return {**op_call("validate", "validate_asset", {"obj": mesh, **kwargs}), "object": mesh}


OPS = {"env": op_env, "call": op_call, "validate_source": op_validate_source}


def main():
    request_path = sys.argv[sys.argv.index("--") + 1]
    with open(request_path, encoding="utf-8") as fh:
        request = json.load(fh)
    op = request.get("op")
    try:
        if op not in OPS:
            raise KeyError(f"unknown op {op!r}; known: {sorted(OPS)}")
        text = json.dumps(OPS[op](**request.get("args", {})), default=repr)
    except Exception as exc:
        text = json.dumps({"ok": False, "stage": getattr(exc, "stage", f"op:{op}"),
                           "error": f"{type(exc).__name__}: {exc}", "traceback": traceback.format_exc(limit=6)})
    with open(request["result_path"], "w", encoding="utf-8") as fh:
        fh.write(text)


main()
