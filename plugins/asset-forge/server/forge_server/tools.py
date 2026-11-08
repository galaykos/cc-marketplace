"""The forge server's tools. Each runs one headless Blender job on a .blend the caller names (normally a snapshot
saved from the live session with save_as_mainfile(copy=True)) and never saves over that file."""
import base64
import os
import platform
import sys
import tempfile
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import headless

INLINE_MAX_BYTES = 6_000_000
ENGINES = ["unity", "unreal", "godot", "generic"]
PLATFORMS = ["pc", "console", "mobile"]
ASSET_CLASSES = ["prop_small", "prop_medium", "prop_large", "hero_prop", "character", "environment_piece"]


class InputError(Exception):
    pass


def _require(args, *names):
    missing = [n for n in names if args.get(n) in (None, "", [])]
    if missing:
        raise InputError(f"missing required argument(s): {', '.join(missing)}")


def _blend(args):
    _require(args, "blend_path")
    path = Path(os.path.expanduser(args["blend_path"])).resolve()
    if not path.is_file():
        raise InputError(f"blend_path does not exist: {path}")
    if path.suffix != ".blend":
        raise InputError(f"blend_path is not a .blend file: {path}")
    return str(path)


def _out_dir(args, kind):
    if args.get("out_dir"):
        out = Path(os.path.expanduser(args["out_dir"])).resolve()
    else:
        out = Path(tempfile.mkdtemp(prefix=f"asset-forge-{kind}-"))
    out.mkdir(parents=True, exist_ok=True)
    return str(out)


def _image(path, label):
    p = Path(path)
    if not p.is_file():
        return None, f"{label}: {path} was not written"
    if p.stat().st_size > INLINE_MAX_BYTES:
        return None, f"{label}: {path} is {p.stat().st_size} bytes, over the inline limit; open it with Read"
    return {"data": base64.b64encode(p.read_bytes()).decode("ascii"), "mimeType": "image/png"}, None


def _call(blend_path, module, function, kwargs, timeout, save_copy_to=None):
    args = {"module": module, "function": function, "kwargs": kwargs}
    if save_copy_to:
        args["save_copy_to"] = save_copy_to
    return headless.run_job("call", args, blend_path=blend_path, timeout=timeout)


def _with_images(result, *pairs):
    images, notes = [], []
    for path, label in pairs:
        if not path:
            continue
        img, note = _image(path, label)
        if img:
            images.append(img)
        if note:
            notes.append(note)
    if notes:
        result.setdefault("notes", []).extend(notes)
    if images:
        result["_images"] = images
    return result


def env_check(_args):
    report = headless.run_job("env", timeout=120)
    report["server"] = {"python": sys.version.split()[0], "platform": platform.platform(),
                        "plugin_data": os.environ.get("CLAUDE_PLUGIN_DATA") or None}
    report["tier2_texturing"] = "Meshy through its own MCP server, driven by the stylized-texturing skill; " \
                                "this server prepares view guides and projects the results back"
    return report


def render_review_set(args):
    blend = _blend(args)
    _require(args, "object")
    kwargs = {"obj": args["object"], "out_dir": _out_dir(args, "review"), "angles": int(args.get("angles", 8)),
              "tile_px": int(args.get("tile_px", 384))}
    if args.get("include"):
        kwargs["include"] = list(args["include"])
    if args.get("game_camera"):
        kwargs["game_camera"] = args["game_camera"]
    result = _call(blend, "review_renders", "render_review_set", kwargs, timeout=600)
    return _with_images(result, (result.get("contact_sheet"), "contact sheet")) if result.get("ok") else result


def validate_asset(args):
    blend = _blend(args)
    _require(args, "object")
    kwargs = {"obj": args["object"]}
    for key in ("engine", "platform", "asset_class", "overrides", "expected_size_m"):
        if args.get(key) is not None:
            kwargs[key] = args[key]
    return _call(blend, "validate", "validate_asset", kwargs, timeout=180)


def bake_maps(args):
    blend = _blend(args)
    _require(args, "low")
    kwargs = {"low": args["low"], "out_dir": _out_dir(args, "bake")}
    for key in ("high", "maps", "resolution", "extrusion", "cage", "samples", "margin_px"):
        if args.get(key) is not None:
            kwargs[key] = args[key]
    return _call(blend, "bake", "bake_maps", kwargs, timeout=1200)


def stylize_texture(args):
    blend = _blend(args)
    _require(args, "object")
    kwargs = {"obj": args["object"], "out_dir": _out_dir(args, "stylize")}
    for key in ("palette", "recipe", "resolution", "maps"):
        if args.get(key) is not None:
            kwargs[key] = args[key]
    result = _call(blend, "stylize", "stylize", kwargs, timeout=1200)
    return _with_images(result, (result.get("albedo"), "albedo")) if result.get("ok") else result


def export_asset(args):
    blend = _blend(args)
    _require(args, "objects", "engine", "out_dir")
    objects = args["objects"] if isinstance(args["objects"], list) else [args["objects"]]
    kwargs = {"objects": objects, "engine": args["engine"], "out_dir": _out_dir(args, "export")}
    for key in ("file_stem", "include_lods", "include_collision", "platform"):
        if args.get(key) is not None:
            kwargs[key] = args[key]
    return _call(blend, "export", "export_asset", kwargs, timeout=600)


def texture_views(args):
    blend = _blend(args)
    _require(args, "object")
    out = _out_dir(args, "views")
    kwargs = {"obj": args["object"], "out_dir": out}
    for key in ("views", "resolution"):
        if args.get(key) is not None:
            kwargs[key] = args[key]
    views_blend = str(Path(out) / f"{Path(blend).stem}_views.blend")
    result = _call(blend, "project_paint", "prepare_views", kwargs, timeout=600, save_copy_to=views_blend)
    if result.get("ok"):
        result["views_blend"] = views_blend
        result["next"] = "generate one image per camera (same framing as its guides), then call project_texture " \
                         "with blend_path = views_blend and view_images = {camera: png}"
    return result


def project_texture(args):
    blend = _blend(args)
    _require(args, "object", "view_images")
    missing = [p for p in args["view_images"].values() if not Path(os.path.expanduser(p)).is_file()]
    if missing:
        raise InputError(f"view image(s) not found: {missing}")
    kwargs = {"obj": args["object"], "view_images": args["view_images"], "out_dir": _out_dir(args, "projected")}
    for key in ("resolution", "seam_blend"):
        if args.get(key) is not None:
            kwargs[key] = args[key]
    result = _call(blend, "project_paint", "project_and_bake", kwargs, timeout=900)
    return _with_images(result, (result.get("path"), "projected texture")) if result.get("ok") else result


def batch_run(args):
    _require(args, "files", "module", "function", "out_dir")
    files = [_blend({"blend_path": f}) for f in args["files"]]
    out = Path(_out_dir(args, "batch"))
    sources = {Path(f).parent for f in files}
    if out in sources:
        raise InputError("out_dir holds a source file; batch copies go to a separate folder")
    stems = [Path(f).stem for f in files]
    if len(set(stems)) != len(stems):
        raise InputError("two files share a name; their copies would overwrite each other in out_dir")
    workers = max(1, min(int(args.get("max_parallel", 4)), len(files)))
    started = time.time()

    def one(path):
        result = _call(path, args["module"], args["function"], args.get("kwargs") or {}, timeout=int(args.get("timeout_s", 600)),
                       save_copy_to=str(out / f"{Path(path).stem}.blend") if args.get("save_copies", True) else None)
        result.pop("traceback", None)
        return {"file": path, **result}

    with ThreadPoolExecutor(max_workers=workers) as pool:
        results = list(pool.map(one, files))
    failed = [r["file"] for r in results if not r.get("ok")]
    return {"ok": not failed, "out_dir": str(out), "results": results, "failed": failed,
            "seconds": round(time.time() - started, 2)}


_BLEND = {"type": "string", "description": "A snapshot .blend (live scene: save_as_mainfile(copy=True) first)"}
_OUT = {"type": "string"}
_OBJ = {"type": "string"}
_INT = {"type": "integer"}


def _schema(props, required):
    return {"type": "object", "properties": props, "required": required}


def _enum(values):
    return {"type": "string", "enum": values}


TOOLS = {
    "env_check": (env_check, "Headless Blender check: path, version, render engines. Run first when a tool fails.",
                  _schema({}, [])),
    "render_review_set": (render_review_set, "Review renders of one object as one contact sheet image (turntable, "
                          "silhouette, game distance, wireframe, UV checker, matcap) for the art-reviewer.",
                          _schema({"blend_path": _BLEND, "object": _OBJ, "out_dir": _OUT, "angles": _INT,
                                   "include": {"type": "array", "items": {"type": "string"}},
                                   "game_camera": {"type": "object"}, "tile_px": _INT},
                                  ["blend_path", "object"])),
    "validate_asset": (validate_asset, "Technical QA against a platform budget and engine preset; `passed` plus "
                       "per-check measured value and fix hint.",
                       _schema({"blend_path": _BLEND, "object": _OBJ, "engine": _enum(ENGINES),
                                "platform": _enum(PLATFORMS), "asset_class": _enum(ASSET_CLASSES),
                                "overrides": {"type": "object"}, "expected_size_m": {"type": "number"}},
                               ["blend_path", "object"])),
    "bake_maps": (bake_maps, "Bake normal/ao/curvature/thickness/id PNGs in Cycles (normal from `high` if given).",
                  _schema({"blend_path": _BLEND, "low": _OBJ, "high": _OBJ, "out_dir": _OUT,
                           "maps": {"type": "array", "items": {"type": "string"}}, "resolution": _INT,
                           "extrusion": {"type": "number"}, "cage": _OBJ, "samples": _INT, "margin_px": _INT},
                          ["blend_path", "low"])),
    "stylize_texture": (stylize_texture, "Procedural hand-painted albedo PNG, no AI; assign it live afterwards.",
                        _schema({"blend_path": _BLEND, "object": _OBJ, "out_dir": _OUT,
                                 "recipe": _enum(["wood", "stone", "metal", "cloth", "foliage"]),
                                 "palette": {"type": "object"}, "resolution": _INT, "maps": {"type": "object"}},
                                ["blend_path", "object"])),
    "export_asset": (export_asset, "Engine export by preset, with LODs and collision found by naming; writes only "
                     "to out_dir.",
                     _schema({"blend_path": _BLEND, "objects": {"type": "array", "items": {"type": "string"}},
                              "engine": _enum(ENGINES), "out_dir": _OUT, "file_stem": {"type": "string"},
                              "include_lods": {"type": "boolean"}, "include_collision": {"type": "boolean"},
                              "platform": _enum(PLATFORMS)},
                             ["blend_path", "objects", "engine", "out_dir"])),
    "texture_views": (texture_views, "AI texturing step 1: per-view cameras and guide renders; returns views_blend "
                      "for project_texture.",
                      _schema({"blend_path": _BLEND, "object": _OBJ, "out_dir": _OUT,
                               "views": {"type": "array", "items": {"type": "string"}}, "resolution": _INT},
                              ["blend_path", "object"])),
    "project_texture": (project_texture, "AI texturing step 2: project {camera: png} back onto the UVs of "
                        "views_blend's object.",
                        _schema({"blend_path": _BLEND, "object": _OBJ, "out_dir": _OUT,
                                 "view_images": {"type": "object"}, "resolution": _INT,
                                 "seam_blend": {"type": "number"}},
                                ["blend_path", "object", "view_images"])),
    "batch_run": (batch_run, "Run forge.<module>.<function>(**kwargs) on many .blend files in parallel; copies go "
                  "to out_dir, sources are never written.",
                  _schema({"files": {"type": "array", "items": {"type": "string"}}, "module": {"type": "string"},
                           "function": {"type": "string"}, "kwargs": {"type": "object"}, "out_dir": _OUT,
                           "save_copies": {"type": "boolean"}, "max_parallel": _INT, "timeout_s": _INT},
                          ["files", "module", "function", "out_dir"])),
}

ANNOTATIONS = {"env_check": {"readOnlyHint": True}, "validate_asset": {"readOnlyHint": True}}


def call(name, args):
    handler = TOOLS[name][0]
    try:
        return handler(args)
    except InputError as exc:
        return {"ok": False, "stage": "input", "error": str(exc)}
