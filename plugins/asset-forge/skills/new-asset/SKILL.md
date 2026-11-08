---
name: new-asset
description: Use when the user runs /asset-forge:new-asset with a brief. Builds one game asset in Blender from blockout to a validated engine export, pausing for approval after the first review and after texturing.
disable-model-invocation: true
---

# /asset-forge:new-asset <brief>

Orchestrates `${CLAUDE_PLUGIN_ROOT}/skills/pipeline/SKILL.md` for one asset. Read that file first; this one only
adds the run's shape. Keep a task list with one item per step below and update it as you go.

## 0. Before anything is built

- `asset-forge.json` exists, or ask and write it (pipeline §1). Never guess the engine.
- From the brief: asset name per the engine's naming (`SM_TreasureChest` for Unity), asset class, real-world size
  in metres, style notes. Ask only what the brief and the config leave open, in one batch.
- Work in the open Blender through the Blender MCP. If the user has unrelated work in the scene, create a new
  scene (`bpy.data.scenes.new("asset_<name>")` and make it the window's scene) and build there.
- Run the forge import snippet (pipeline §3).

## 1. Blockout → review → PAUSE

Build the blockout live (hard surface: primitives, bevels and booleans applied, bmesh; organic:
`${CLAUDE_PLUGIN_ROOT}/skills/organic-modeling/SKILL.md`). Screenshot. Then the review flow
(`${CLAUDE_PLUGIN_ROOT}/skills/review/SKILL.md`) with silhouette, game distance and beauty only.

**Pause 1**: show the contact sheet and the reviewer's verdict; ask the user to approve the blockout or name
changes. Do not refine before the answer (unless the user said to run unattended).

## 2. Refine → UV → texture → review → PAUSE

Refine per the review; retopo to the budget; UVs (seams, unwrap, texel density, pack); snapshot; texture
(`${CLAUDE_PLUGIN_ROOT}/skills/stylized-texturing/SKILL.md`, Tier 1 unless the user asked for AI texturing);
assign live. Full review.

**Pause 2**: show the contact sheet and verdict; ask for approval or changes.

## 3. LODs → collision → validate → export → report

LODs and collision live (pipeline steps 10–11). Snapshot. `validate_asset` for every platform tier in the config;
fix each `fail` live and re-validate; explain each remaining `warn`. `export_asset` to `folders.export_dir`.

Report, as a table: file(s) written with sizes; triangles per LOD against the budget; texture files and sizes;
validator result per tier (passed, with the warns named); the review verdicts before and after revision; anything
skipped. Attach the final contact sheet.

## Rules

- Never claim a step done from a forge `ok` alone: look at the screenshot or the returned image. Standing: recorded.
- Every headless call takes a fresh snapshot made after the last live change. Standing: recorded.
- Credits (Meshy) are spent only after the user confirms the cost. Standing: recorded.

## Limitations

- The two pauses are prose: nothing stops a run that skips them except this file.
- The art reviewer judges renders, not the engine view; a final look in the engine is still the user's.
