"""Engine-correct FBX / glTF export of an asset with its LODs and collision, driven by presets/engines/<engine>.json.
Writes only under out_dir; sizes in bytes; positions in metres."""
from pathlib import Path

import bpy
from mathutils import Matrix

from .lod import _base_name, _lod_name, _lod_objects, _name_regex
from .util import ForgeError, get_object, load_preset, ok, select_only

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
    patterns = set(preset["naming"].get("collision", {}).values())
    regexes = [_name_regex(p, name=obj.name) for p in patterns]
    return sorted((o for o in bpy.data.objects if any(r.fullmatch(o.name) for r in regexes)), key=lambda o: o.name)


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
            for n, lod in sorted(_lod_objects(_base_name(root.name, pattern), pattern).items()):
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
        files.extend((_lod_name(pattern, stem, n), by_level[n]) for n in levels)
        log.append(f"LODs in separate files: levels {levels}")
    elif levels:
        main.extend(o for n in levels for o in by_level[n])
        log.append(f"LODs in the main file: levels {levels}")
    return files, levels


def export_asset(objects, engine="unity", out_dir=None, file_stem=None, include_lods=True, include_collision=True,
                 platform="pc"):
    """Export objects (names or objects; the first is the asset) with their LODs and collision, found by the engine
    preset's naming patterns, through the preset's exporter (FBX or glTF). Preset keyword arguments the running
    exporter lacks are dropped and reported; fbx_static_only keys apply only when no armature is in the file. A
    world_origin pivot moves the asset to the world origin for the export. Selection, active object, visibility and
    transforms are restored. platform: the budget whose LOD count is checked. Returns file paths, sizes and a log."""
    if out_dir is None:
        raise ForgeError("out_dir is required")
    names = [objects] if isinstance(objects, (str, bpy.types.Object)) else list(objects)
    if not names:
        raise ForgeError("no objects to export")
    roots = [get_object(o) for o in names]
    preset = load_preset("engines", engine)
    fmt = preset["format"]
    if fmt == "fbx":
        op, wanted = bpy.ops.export_scene.fbx, dict(preset.get("fbx", {}))
        ext = ".fbx"
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
    log = []
    if dropped or static_dropped:
        log.append(f"dropped preset keys this exporter lacks: {dropped + static_dropped}")
    stem = file_stem or _base_name(roots[0].name, preset["naming"]["lod"])
    files, levels = _plan(roots, preset, stem, include_lods, include_collision, log)
    ratios = load_preset("budgets", platform).get("lod_ratios", [])
    if include_lods and roots[0].type == "MESH" and len(levels) + 1 != len(ratios):
        log.append(f"budgets/{platform}.json lists {len(ratios)} LOD levels; found {len(levels) + 1}")
    if include_collision and preset.get("collision_import"):
        log.append(f"collision on import: {preset['collision_import']}")
    folder = Path(out_dir)
    folder.mkdir(parents=True, exist_ok=True)

    exported = {o for _, objs in files for o in objs}
    view_layer = bpy.context.view_layer
    for o in exported:
        was = o.select_get()
        try:
            o.select_set(True)
        except RuntimeError as exc:
            raise ForgeError(str(exc), stage="export") from None
        o.select_set(was)
    prev_active = view_layer.objects.active
    prev_mode = prev_active.mode if prev_active else "OBJECT"
    prev_selected = [o for o in view_layer.objects if o.select_get()]
    hidden = {o: (o.hide_get(), o.hide_viewport) for o in exported}
    tops = [o for o in exported if o.parent not in exported]
    basis = {o: o.matrix_basis.copy() for o in tops}
    written = []
    try:
        for o in exported:
            o.hide_viewport = False
            o.hide_set(False)
        unseen = sorted(o.name for o in exported if not o.visible_get())
        if unseen:
            raise ForgeError(f"{unseen} are hidden by their collection; the exporter would skip them", stage="export")
        if preset.get("pivot") == "world_origin":
            bpy.context.view_layer.update()
            offset = Matrix.Translation(-roots[0].matrix_world.translation)
            for o in tops:
                o.matrix_world = offset @ o.matrix_world
            log.append(f"pivot world_origin: moved by {tuple(round(c, 6) for c in offset.translation)}, restored after")
        for file_stem_n, objs in files:
            path = folder / f"{file_stem_n}{ext}"
            call = dict(kwargs)
            has_armature = any(o.type == "ARMATURE" for o in objs)
            if static_kwargs and not has_armature:
                call.update(static_kwargs)
            select_only(*objs, active=objs[0])
            before = _snapshot(folder)
            try:
                op(filepath=str(path), **call)
            except (RuntimeError, TypeError) as exc:
                raise ForgeError(f"{fmt} export of {path.name} failed: {exc}", stage="export") from None
            after = _snapshot(folder)
            new = sorted(n for n in after if before.get(n) != after[n])
            if path.name not in after:
                raise ForgeError(f"{fmt} exporter wrote no {path.name}", stage="export")
            static_note = ("static-only keys skipped: armature in file" if static_kwargs and has_armature
                           else f"static-only keys applied: {sorted(static_kwargs)}" if static_kwargs else None)
            written.append({"path": str(path), "bytes": after[path.name][0], "objects": sorted(o.name for o in objs),
                            "other_files": [n for n in new if n != path.name], "static_only": static_note})
    finally:
        for o, m in basis.items():
            o.matrix_basis = m
        for o, (hide, hide_viewport) in hidden.items():
            o.hide_viewport = hide_viewport
            o.hide_set(hide)
        for o in view_layer.objects:
            o.select_set(o in prev_selected)
        view_layer.objects.active = prev_active
        if prev_active is not None and prev_mode != "OBJECT":
            bpy.ops.object.mode_set(mode=prev_mode)
        bpy.context.view_layer.update()
    return ok(engine=engine, format=fmt, platform=platform, files=written, dropped_keys=dropped + static_dropped,
              objects_exported=len(exported), log=log)
