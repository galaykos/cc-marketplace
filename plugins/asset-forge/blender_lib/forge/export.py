"""Engine-correct FBX / glTF export of an asset with its LODs and collision, driven by presets/engines/<engine>.json.
Writes only under out_dir; sizes in bytes; positions in metres."""
from contextlib import contextmanager
from pathlib import Path

import bpy
from mathutils import Matrix

from .naming import COLLISION_TOKEN, collision_objects, format_name, lod0_base, lod_objects, pattern_regex
from .util import ForgeError, get_object, kept_state, load_preset, ok, select_only

GLTF_EXTENSIONS = {"GLB": ".glb", "GLTF_SEPARATE": ".gltf"}


def _filtered(op, wanted):
    """Keep only the keys the operator really has at run time; enum-flag values become sets. Returns (kwargs, dropped)."""
    props = op.get_rna_type().properties
    kwargs, dropped = {}, []
    for key, value in wanted.items():
        if key not in props.keys():
            dropped.append(key)
            continue
        prop = props[key]
        kwargs[key] = set(value) if prop.type == "ENUM" and prop.is_enum_flag else value
    return kwargs, sorted(dropped)


def _collision_of(obj, preset):
    return collision_objects(obj.name, preset["naming"].get("collision", {}).values())


def _snapshot(folder):
    return {p.name: (p.stat().st_size, p.stat().st_mtime_ns) for p in folder.iterdir() if p.is_file()}


def _plan(roots, preset, stem, include_lods, include_collision, log):
    """[(file stem, [objects])]: the main file first, then one file per LOD level when the preset wants that."""
    pattern = preset["naming"]["lod"]
    policy = preset.get("lod", {}).get("export", "same_file")
    main, by_level, with_collision = list(roots), {}, []
    for root in roots:
        if root.type != "MESH":
            continue
        if include_lods:
            for n, lod in sorted(lod_objects(lod0_base(root.name, pattern), pattern).items()):
                if lod is not root and n > 0:
                    by_level.setdefault(n, []).append(lod)
        if include_collision:
            hulls = _collision_of(root, preset)
            if hulls:
                with_collision.append(root.name)
                main.extend(hulls)
    if len(with_collision) > 1 and preset.get("one_custom_collision_mesh_per_file"):
        raise ForgeError(f"{preset['engine']} imports only the first mesh's custom collision per file; "
                         f"{with_collision} all have collision: export each in its own call", stage="export")
    files = [(stem, main)]
    levels = sorted(by_level)
    if levels and policy == "engine_generates":
        log.append(f"LODs not exported: {preset['engine']} generates LODs on import ({preset['lod'].get('note', '')})")
    elif levels and policy == "separate_files":
        files.extend((format_name(pattern, stem, n), by_level[n]) for n in levels)
        log.append(f"LODs in separate files: levels {levels}")
    elif levels:
        main.extend(o for n in levels for o in by_level[n])
        log.append(f"LODs in the main file: levels {levels}")
    return files, levels


def _exporter(engine, preset):
    """(operator, kwargs, static-only kwargs, file extension, dropped preset keys) for the preset's format."""
    fmt = preset["format"]
    if fmt == "fbx":
        op, wanted, ext = bpy.ops.export_scene.fbx, dict(preset.get("fbx", {})), ".fbx"
    elif fmt == "gltf":
        op, wanted = bpy.ops.export_scene.gltf, dict(preset.get("gltf", {}))
        ext = GLTF_EXTENSIONS.get(wanted.get("export_format", "GLB"))
        if ext is None:
            raise ForgeError(f"unsupported glTF export_format {wanted['export_format']!r}; known {list(GLTF_EXTENSIONS)}")
    else:
        raise ForgeError(f"the {engine} preset's format {fmt!r} is neither fbx nor gltf")
    wanted["use_selection"] = True
    kwargs, dropped = _filtered(op, wanted)
    static_kwargs, static_dropped = _filtered(op, preset.get("fbx_static_only", {})) if fmt == "fbx" else ({}, [])
    return op, kwargs, static_kwargs, ext, dropped + static_dropped


@contextmanager
def _kept_transforms(objects):
    """Restore each object's location, rotation (every mode's channels) and scale exactly; writing matrix_basis back
    would re-decompose them (270 degrees reads back as -90, scale (-1, 1, 1) as (-1, -1, -1) plus a turn)."""
    saved = {o: (o.rotation_mode, o.location.copy(), o.rotation_euler.copy(), o.rotation_quaternion.copy(),
                 tuple(o.rotation_axis_angle), o.scale.copy()) for o in objects}
    try:
        yield
    finally:
        for o, (mode, loc, euler, quat, axis_angle, scale) in saved.items():
            o.rotation_mode = mode
            o.location, o.rotation_euler, o.rotation_quaternion = loc, euler, quat
            o.rotation_axis_angle, o.scale = axis_angle, scale


def _write(op, path, kwargs, static_kwargs, objs, fmt):
    """Export objs to path; returns the written-file record."""
    call = dict(kwargs)
    has_armature = any(o.type == "ARMATURE" for o in objs)
    if static_kwargs and not has_armature:
        call.update(static_kwargs)
    select_only(*objs, active=objs[0])
    before = _snapshot(path.parent)
    try:
        op(filepath=str(path), **call)
    except RuntimeError as exc:
        raise ForgeError(f"{fmt} export of {path.name} failed: {exc}", stage="export") from exc
    after = _snapshot(path.parent)
    if path.name not in after:
        raise ForgeError(f"{fmt} exporter wrote no {path.name}", stage="export")
    new = sorted(n for n in after if before.get(n) != after[n])
    static_note = ("static-only keys skipped: armature in file" if static_kwargs and has_armature
                   else f"static-only keys applied: {sorted(static_kwargs)}" if static_kwargs else None)
    return {"path": str(path), "bytes": after[path.name][0], "objects": sorted(o.name for o in objs),
            "other_files": [n for n in new if n != path.name], "static_only": static_note}


def export_asset(objects, engine="unity", out_dir=None, file_stem=None, include_lods=True, include_collision=True,
                 platform="pc"):
    """Export objects (names or objects; the first is the asset) with their LODs and collision, found by the engine
    preset's naming patterns, through the preset's exporter (FBX or glTF). Preset keyword arguments the running
    exporter lacks are dropped and reported; fbx_static_only keys apply only when no armature is in the file. A
    world_origin pivot moves the asset to the world origin for the export. Selection, active object, visibility and
    transform channels are restored. platform: the budget whose LOD count is checked. Returns file paths, sizes and a
    log."""
    if out_dir is None:
        raise ForgeError("out_dir is required")
    names = [objects] if isinstance(objects, (str, bpy.types.Object)) else list(objects)
    if not names:
        raise ForgeError("no objects to export")
    roots = [get_object(o) for o in names]
    preset = load_preset("engines", engine)
    op, kwargs, static_kwargs, ext, dropped = _exporter(engine, preset)
    log = [f"dropped preset keys this exporter lacks: {dropped}"] if dropped else []
    stem = file_stem or lod0_base(roots[0].name, preset["naming"]["lod"])
    files, levels = _plan(roots, preset, stem, include_lods, include_collision, log)
    ratios = load_preset("budgets", platform).get("lod_ratios", [])
    if include_lods and roots[0].type == "MESH" and len(levels) + 1 != len(ratios):
        log.append(f"budgets/{platform}.json lists {len(ratios)} LOD levels; found {len(levels) + 1}")
    if include_collision and preset.get("collision_import"):
        log.append(f"collision on import: {preset['collision_import']}")
    folder = Path(out_dir)
    folder.mkdir(parents=True, exist_ok=True)
    exported = {o for _, objs in files for o in objs}
    tops = [o for o in exported if o.parent not in exported]
    written = []
    with kept_state(exported, stage="export"), _kept_transforms(tops):
        unseen = sorted(o.name for o in exported if not o.visible_get())
        if unseen:
            raise ForgeError(f"{unseen} are hidden by their collection; the exporter would skip them", stage="export")
        if preset.get("pivot") == "world_origin":
            bpy.context.view_layer.update()
            offset = Matrix.Translation(-roots[0].matrix_world.translation)
            for o in tops:
                o.matrix_world = offset @ o.matrix_world
            log.append(f"pivot world_origin: moved by {tuple(round(c, 6) for c in offset.translation)}, restored after")
        for stem_n, objs in files:
            written.append(_write(op, folder / f"{stem_n}{ext}", kwargs, static_kwargs, objs, preset["format"]))
    bpy.context.view_layer.update()
    return ok(engine=engine, format=preset["format"], platform=platform, files=written, dropped_keys=dropped,
              objects_exported=len(exported), log=log)


def audit_export(files, engine="unity"):
    """Re-import exported files into an empty scene and check what actually shipped, per file: each `files` entry is
    {"path", "objects": [names the export meant to write], "clips": [clip names, optional]}. Checks: the file exists and
    is non-empty, every expected mesh or armature arrived and no unexpected mesh did, the clips (when given) are exactly
    those, by name after the importer's "<object>|" prefix (the importer's own armature/empties aside), every mesh has
    faces and no n-gon, render meshes carry a UV map and a material, and no mesh carries a collision token (UCX_,
    _Collider, -colonly...) without following one of the preset's collision patterns. Headless only (blender -b): it
    clears the current file, so a live session would lose its scene. Returns per-file checks and `passed`."""
    if not bpy.app.background:
        raise ForgeError("audit_export clears the open file: run it headless (blender -b), not in a live session",
                         stage="headless")
    preset = load_preset("engines", engine)
    collision_rx = [pattern_regex(p) for p in set(preset["naming"].get("collision", {}).values())]
    results = []
    for entry in files:
        path = Path(entry["path"])
        checks = []

        def add(check, passed, detail):
            checks.append({"id": check, "status": "pass" if passed else "fail", "detail": detail})

        add("file", path.is_file() and path.stat().st_size > 0, str(path))
        if not path.is_file():
            results.append({"path": str(path), "passed": False, "checks": checks})
            continue
        bpy.ops.wm.read_factory_settings(use_empty=True)
        if path.suffix.lower() == ".fbx":
            bpy.ops.import_scene.fbx(filepath=str(path))
        else:
            bpy.ops.import_scene.gltf(filepath=str(path))
        meshes = {o.name: o for o in bpy.data.objects if o.type == "MESH"}
        arrived = {o.name for o in bpy.data.objects if o.type in ("MESH", "ARMATURE")}
        expected = set(entry.get("objects", []))
        add("objects_present", expected <= arrived, {"missing": sorted(expected - arrived)})
        add("no_extra_meshes", set(meshes) <= expected, {"extra": sorted(set(meshes) - expected)})
        clips = sorted(a.name for a in bpy.data.actions)
        expected_clips = entry.get("clips")
        if expected_clips is not None:
            shipped = sorted({c.split("|")[-1] for c in clips})
            add("clips", sorted(set(expected_clips)) == shipped,
                {"expected": sorted(set(expected_clips)), "shipped": clips})
        collision = sorted(n for n in meshes if any(rx.fullmatch(n) for rx in collision_rx))
        misnamed = sorted(n for n in meshes if n not in collision and COLLISION_TOKEN.search(n))
        add("collision_naming", not misnamed, {"named": collision, "misnamed": misnamed})
        tris = {}
        for name, obj in meshes.items():
            polys = obj.data.polygons
            tris[name] = sum(p.loop_total - 2 for p in polys)
            add(f"{name}:faces", len(polys) > 0, len(polys))
            add(f"{name}:ngons", not any(p.loop_total > 4 for p in polys), sum(p.loop_total > 4 for p in polys))
            if name not in collision:
                add(f"{name}:uv", len(obj.data.uv_layers) > 0, len(obj.data.uv_layers))
                add(f"{name}:material", any(s.material for s in obj.material_slots), len(obj.material_slots))
        results.append({"path": str(path), "passed": all(c["status"] == "pass" for c in checks), "tris": tris,
                        "clips": clips, "checks": checks})
    return ok(engine=engine, passed=all(r["passed"] for r in results), files=results)
