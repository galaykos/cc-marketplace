# Changelog — blender

Consumer-facing changes only. Newest first.

## 0.2.1 — 2026-11-02

- **Control-arm eval.** `evals/removed-5x-bpy` asks for the removed `action.fcurves` and
  `scene.node_tree`. On 2026-11-02 it scored 5/5 with the plugin and 5/5 without, so it is a
  regression guard, not a measure of the skill. Spend was $0.97. Results are in
  `rationale/gamedev-evals-2026-11-02.md`.

## 0.2.0 — 2026-11-02

- **bpy scripts are checked when written.** A new hook, `hooks/bpy-check.sh`, runs
  `check_bpy_scripts.py` on a `.py` under the project that imports `bpy` or `bmesh`. It fires after
  a Write/Edit, or a Bash redirect, `tee` or `sed -i` into the file (the shared `bash-write-targets`
  block). The target version comes from a `.blend` beside the file, else the project's newest
  `.blend`, else `blender --version` on PATH, else the hook stays silent. Findings are added once
  per context and the hook never blocks. Off: `CC_BPY_CHECK=off`, or `/config`.
- **Measured.** The cheap exit took 10 ms median and 11 ms max over 20 runs.
- **Standing.** Running the checker moves from recorded to **gate** where the hook fires (`scripts/smoke/game-checker-hooks-tests.sh`, in
  CI, including the heredoc-body and `>>` cases). An interpreter-written script is still recorded.

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
