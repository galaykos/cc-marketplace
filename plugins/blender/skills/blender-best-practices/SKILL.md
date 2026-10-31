---
name: blender-best-practices
description: Use when writing, reviewing or running Blender Python — a .py importing bpy, an add-on, a .blend, blender -b headless or CI runs, mesh QA — or exporting FBX/glTF from Blender to Unreal, Unity or Godot; covers the 5.x breaks (action.fcurves, scene.node_tree, BLENDER_EEVEE_NEXT, bgl, GN Socket_N keys) and exit-code traps.
---

> Last verified: 2026-10-30 — https://developer.blender.org/docs/release_notes/5.0/python_api/
<!-- version-tail-ok: Blender ships as a binary, not an npm/composer/pypi package; the stamp points at the 5.0 Python API notes, re-read with the 5.1 and 5.2 notes and probed in a local Blender 5.2.3 LTS -->

## Read the Blender version first

- Inside Blender: `bpy.app.version` is the running binary. Without Blender, read the version that saved a file:
  `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/check_bpy_scripts.py" --blend-version path/to/file.blend`.
- `head -c 12 file.blend` no longer answers. Since 5.0 a save is zstd-compressed by default (it starts `28 b5 2f fd`),
  and the uncompressed 5.x header is 17 bytes, `BLENDER17-01v0502`, where 4.x wrote 12, `BLENDER-v405`.
- The header names the version that last saved the file, not the one the project targets; a version pinned in CI
  or stated by the team wins over it. For an add-on, check at its `blender_manifest.toml` `blender_version_min`
  and at the newest version it claims to support.
- A file saved by 5.0 or later opens only in 4.5 LTS or later.
- "4.x" is not one target: 4.2–4.5 name the EEVEE engine `BLENDER_EEVEE_NEXT`, 5.x names it `BLENDER_EEVEE`.
  Advise for the version you read, and say which one you assumed when you could not read one.

## The rules, and who enforces each

| Rule | Standing |
|---|---|
| No bpy call the target version removed or renamed | **gate** for whoever runs `check_bpy_scripts.py`: exit 1. No hook runs it, so running it is **agent-graded** |
| Deprecated-but-working calls (`use_nodes = True`, VSE `frame_final_*`, `blend_method`) | checker **warning**; `--strict` exits 1 |
| A headless run that must fail on a Python exception passes `--python-exit-code N` **before** `--python` | **recorded** — nothing reads the command line you wrote |
| A generated or edited mesh passes `blender_qa.py` before it is called done | **gate** when it runs inside Blender (exit 1); whether it runs is **agent-graded** |
| Export settings and engine packing in `references/export.md` | **recorded** |

## Run the checker

```sh
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/check_bpy_scripts.py" . --blender 5.2 [--strict] [--json] [--max-issues N]
```

- It scans every `.py` that imports `bpy`, `bpy_extras`, `bmesh`, `bgl` or `gpu`, skipping hidden, `venv`,
  `node_modules`, `build` and `dist` directories. Without `--blender` it targets the newest `.blend` header it finds.
- Exit 0 no errors, 1 errors (or warnings under `--strict`), 2 bad arguments, no target version, or no bpy file.
- Errors are calls that raise on the target (removed, renamed, or newer than it); warnings are deprecations.
- A trailing `# bpy-check: ok` silences one line. Say why in the same comment.
- **It reads names, not types.** `act.fcurves` is reported because the receiver is spelled like an Action;
  `x.fcurves` is not. Aliased imports (`from bpy import ops`), renamed variables and calls built with
  `getattr` are invisible to it. It reported nothing on Blender 5.2.3's 601 bundled scripts at `--blender 5.2`.

## Headless runs: the exit code lies

Measured on Blender 5.2.3; `--python-exit-code` is documented on the manual's command-line page.

- Without `--python-exit-code`, an uncaught exception exits **0** — so does a script that fails to compile.
- Arguments run left to right, and the flag is one of them: `--python x.py --python-exit-code 1` sets it after the
  script already failed, and the run exits 0. Put the flag first.
- `sys.exit(n)` in the script exits Blender with `n`, flag or not. A check that fails without raising — a QA
  verdict, a validation report — must call `sys.exit(1)` itself; printing `"pass": false` exits 0.
- A `.blend` path that cannot be opened exits 1 before any script runs.
- Load the `.blend` before `--python`; script arguments go after `--` (`sys.argv[sys.argv.index("--") + 1:]`).

```sh
blender -b asset.blend --factory-startup --python-exit-code 2 --python script.py -- --your-args
```

## Mesh QA inside Blender

```sh
blender -b asset.blend --factory-startup --python-exit-code 2 \
  --python "${CLAUDE_PLUGIN_ROOT}/scripts/blender_qa.py" -- --objects Body Head --profile game [--strict] [--json]
```

- Pass all objects of ONE asset together: a part far from every other part is reported as floating.
- Profiles `game` (default), `render` (lenient), `print` (watertight), `roblox` (20k tris per mesh, no n-gons).
- Exit 0 pass, 1 errors (or warnings under `--strict`), 2 could not run (missing object, bad flag, run outside
  Blender). It checks the evaluated mesh unless `--no-modifiers`.
- It finds z-fighting, floating or enclosed parts, inside-out islands, inconsistent winding, non-manifold, open,
  degenerate and duplicate geometry, n-gons, unapplied or negative scale, missing or zero-area UVs, unweighted or
  over-4-influence vertices. It cannot judge silhouette, proportions, deformation, shading or which material is
  right; above `--max-tris` (300k) it skips the z-fight and floating checks. Look at the asset as well.

## What a from-memory answer gets wrong

`references/api-5x.md` carries only the 4.x→5.2 changes where the confident answer now raises, plus three
footguns. Read its section before writing or reviewing:

- keyframes, F-curves or actions — 5.0 removed `action.fcurves`; F-curves live in a slot's channelbag;
- a compositor tree — 5.0 removed `scene.node_tree` and the Composite node;
- render engine, passes or video output — engine id, pass names, `media_type` order;
- a Geometry Nodes modifier input from Python — 5.2 removed `mod["Socket_2"]`;
- node lookups by name — names are translated on a localized install;
- an add-on, `gpu` drawing or brush settings — `bgl`, `bindcode`, `sculpt_tool`, stroke and automasking moves.

`references/export.md` carries the FBX and glTF exporter traps and the per-engine rules. Read it before an
export to Unreal, Unity, Godot or the web: default FBX settings, where the factor 100 hides at Unit Scale 1.0,
when shape keys are dropped, `UCX_` naming, and the Unity smoothness packing that is not the glTF one.

Asset licence, AI-generation records and the Steam disclosure are not here: they are the `gamedev` plugin's
`game-assets` skill.

## Anti-patterns

- **Exit-code theatre** — a CI step `blender -b f.blend --python check.py` with no `--python-exit-code`, or with it
  after `--python`: every failure is green.
- **Printed verdict** — a validation script that prints errors and returns normally; Blender exits 0.
- **Name lookup** — `nodes["Principled BSDF"]` instead of `next(n for n in nodes if n.type == "BSDF_PRINCIPLED")`.
- **4.x animation code on 5.x** — `obj.animation_data.action.fcurves.new(...)`; use the channelbag.
- **One "4.x" answer** — `BLENDER_EEVEE` on 4.2–4.5 or `BLENDER_EEVEE_NEXT` on 5.x.
- **Unit Scale 1.0 for Unreal skeletal export** — the factor 100 moves into the armature node; see `references/export.md`.
- **Mesh called done unchecked** — a generated or AI mesh exported without `blender_qa.py` and a look.
