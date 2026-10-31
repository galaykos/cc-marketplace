# Changelog — blender

Consumer-facing changes only. Newest first.

## 0.1.0 — 2026-10-30

- New plugin. `blender-best-practices` skill: read the Blender version first (the 5.x `.blend` header is 17 bytes
  and zstd-compressed by default), a rules table naming each rule's standing, the headless exit-code traps, and two
  references: `api-5x.md` (the 4.x→5.2 Python API changes that now raise) and `export.md` (FBX/glTF defaults, where
  the factor 100 hides at Unit Scale 1.0, shape-key loss, Unreal collision naming, Unity and glTF channel packing,
  Godot import hints).
- `scripts/check_bpy_scripts.py`: stdlib scan of `.py` files importing bpy for 29 calls removed, renamed or not yet
  present in the target Blender version (`--blender X.Y`, or the newest `.blend` header); `--blend-version` prints
  the version that saved a file; `--json`, `--strict`; exit 0/1/2.
- `scripts/blender_qa.py`: mesh QA run inside Blender (z-fighting, floating parts, normals, topology, scale, UVs,
  weights), adapted from EL4CTEO/blender-skills to exit 1 on a failed check.
