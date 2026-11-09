# Changelog — blender

Consumer-facing changes only. Newest first.

## 0.3.1 — 2026-11-09

- **`blender-best-practices` names its near misses.** Generating a model through an AI service,
  its credits and its GLB budget check go to `meshy:meshy-generation`; cleaning up or exporting
  that model in Blender stays here. 2D art goes to `gamedev:game-assets` or
  `pixel-art:pixel-art-pipeline`.
  Skill body only; scripts and hooks are unchanged. Standing: recorded.

## 0.3.0 — 2026-11-07

- **New skill `blender-rig-anim`** for rigging, skinning and animating for a game engine, with `references/rigging.md` and `references/animation.md`. Every exporter fact in them was probed in Blender 5.2.3: FBX "All Actions" writes actions onto objects that never use them; turning it off drops actions that are only active; glTF clips count from frame 0; `nla.bake` defaults to selected bones, no visual keying and frames 1–250; Rigify with "Only Deform Bones" exports two roots. Engine-side setup is routed to `unity-traps`, `godot` and `unreal`. Standing: recorded, gate where the scripts run.
- **New `scripts/anim_audit.py`.** Runs the real FBX and glTF exporters with your `--fbx`/`--gltf` overrides and reads the files. It reports actions that did not ship (with the reason when it can tell: a stale F-curve path, an action on no NLA track with All Actions off, a fake-user-only action), clips written on the wrong object or twice, glTF clips that start late, and `--loop` clips whose first and last poses differ. `--expect` names the clips that must ship. Exit 0/1/2. Standing: gate where run; `scripts/__tests__/test_anim_audit.py`, 22 cases, 7 of them inside Blender. A fake-user clip is checked against the object its 5.x slot names, and skipped when no object matches; `--loop` borrows that object to check a stored clip, and warns when it cannot.
- **New `scripts/rig_check.py`**, ported from EL4CTEO/blender-skills (MIT, see NOTICE) with exit codes added. It also reports the roots left after FBX "Only Deform Bones" (its model matched the exporter's 278-bone set on a Rigify human rig), B-Bones, Preserve Volume and Bone Envelopes, deform bones with no weights, and masked, chained or muted shape keys. Standing: gate where run; `scripts/__tests__/test_rig_check.py`, 8 cases. Deform bones weighted in none of the checked meshes are listed once, not per mesh.
- **`blender_qa.py --compare-uv SRC`.** Compares a decimated or remeshed mesh's UV density with its source: a median UV-to-world area drop over 30%, or flipped UV faces past 1% of faces, is an error. Texel density is printed at `--res`. On a 5° smart-projected Suzanne, decimate 0.05 fails and 0.5 passes. Standing: gate where run; 7 new cases.
- **Seven new checker rules:** `armature-layers` and `bone-groups` (4.0), `bake-action-kwargs` (4.1), `uv-select` and `uv-select-bmesh` (5.0), `driver-fmodifier` (5.0), and `bone-hide` (5.0, warning). Each has an in-Blender probe; all 36 probes pass on 5.2.3. Standing: gate.
- **Three eval cases, not yet run:** `fbx-all-actions-cross-clips`, `headless-ik-bake`, `masked-shape-key-export`. No control-arm result exists, so nothing here claims they measure the skill.

## 0.2.1 — 2026-11-02

- **Control-arm eval.** `evals/removed-5x-bpy` asks for the removed `action.fcurves` and
  `scene.node_tree`. On 2026-11-02 it scored 5/5 with the plugin and 5/5 without, so it is a
  regression guard, not a measure of the skill. Spend was $0.97. Results are in
  `rationale/gamedev-evals-2026-11-02.md`.
- **Review fixes.**
  - The bpy hook splits the checker's output with awk instead of GNU-only sed `\t`, so it no
    longer garbles on macOS. That was not run on BSD awk here.
  - It now also reads `import os, bpy` and `import gpu, bgl` lines.
  - It caps Bash targets after keeping only `.py` files, not before.

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
