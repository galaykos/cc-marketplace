---
name: asset-pipeline
description: Use when a game character or prop goes from a generated concept image to an engine — a Higgsfield concept, Meshy image-to-3D, remesh or rig, Blender cleanup and export, Unity import — or when a batch of AI assets needs a credit cap, a triangle and texture budget, or one character kept the same across generations.
---

> Last verified: 2026-11-02 — https://docs.meshy.ai/en/api/image-to-3d · https://docs.meshy.ai/en/api/rigging · https://docs.higgsfield.ai/docs/concepts/billing-and-retention · higgsfield CLI 1.2.2 `--help`

This skill owns the handoffs between tools. Each tool's own rules live with its plugin:
`meshy:meshy-generation`, `blender:blender-best-practices`, `unity-traps:unity-best-practices`, and
Higgsfield's own `higgsfield-generate` skill. Every vendor fact below, with its source and quote, is in
`rationale/gamedev-asset-pipeline-2026-11-02.md` in the cc-marketplace repository.

## The rules, and who enforces each

| Rule | Standing |
|---|---|
| Pick the asset's budget row before the first paid call, and measure the model against it at every handoff | **gate** (warn-only hook) where meshy's hook fires (15,000 triangles, 2,048 px). Any other row: run `inspect_glb.py` with its numbers, **agent-graded** |
| State the credit cost of each call, and the total of a batch, and get a yes before submitting | **agent-graded**. Higgsfield's help center: "There's no native credit cap." Nothing refuses a call for you |
| Never create a Meshy task again because your own request timed out; list tasks first | **recorded**. Meshy: "Don't create a new task when your own request times out" |
| Download each result as soon as it succeeds; keep the concept, prompt, references and task ids in a manifest | **recorded**. Meshy keeps API models "at most 3 days", Higgsfield's API keeps request files seven days |
| Rig only a textured humanoid under 380,000 triangles that faces +Z | **agent-graded**. Meshy answers `400` over the limit |

## Budgets: pick the row before you generate

The rows are this skill's starting points, built from Meshy's documented defaults and limits; a
platform's or the project's own budget wins. Pass the row to the checker as
`--max-tris N --max-texture PX`.

| Asset | Triangles | Base colour | Meshy request that lands it |
|---|---|---|---|
| Prop, pickup, background piece | 4,000 | 2,048 px | `model_type: smart-topology`, `ai_model: meshy-t2`; `target_polycount` 100–15,000, default 4,000 |
| Character, enemy (rigged) | 15,000 | 2,048 px | `meshy-t2.5`; 100–30,000, default 15,000. This is meshy's hook budget |
| Hero, close-up | 30,000 | 2,048 px; 4,096 only if the platform budget allows | `meshy-t2.5` at 30,000, or a standard model with `should_remesh: true` (default 30,000) |

- Smart Topology output is triangles only: `topology: quad` with `meshy-t2`/`meshy-t2.5` returns
  `400`. A quad mesh needs a standard model with `should_remesh: true`.
- `texture_resolution` is `2k` (2048×2048) by default. `4k` costs the same as `2k`, `8k` costs 5 more,
  and `meshy-6-lite` supports only `2k`.
- Meshy's rig limit, 380,000 triangles (a quad counts as 2), is far above any row. Remesh to the row
  first, never to the limit.

## The pipeline, and the check at each handoff

1. **Concept image (Higgsfield).** One clear subject on a simple background, evenly lit, 512 × 512
   or larger, as JPG, PNG or WebP under 20 MB. That is what Meshy's image-to-3D accepts and does best
   with. For anything you will rig, draw it in a T or A pose. Check the file with gamedev's
   `asset_report.py` (`--expect-size`, `--require-alpha` when you cut the background).
2. **Image to 3D (Meshy).** Use `pose_mode: "t-pose"` or `"a-pose"` for a character, because Meshy's
   own docs say rigging wants one. Keep `should_texture: true`, since rigging supports only textured
   humanoids. Ask only for the formats you need in `target_formats`. Download on `SUCCEEDED`. meshy's
   hook then runs `inspect_glb.py` on the `.glb`. A different row needs the checker run by hand
   with that row's numbers.
3. **Remesh, rig (Meshy).** Send the earlier task as `input_task_id` while Meshy still has it. Do not
   send its signed URL: the signature expires and the call fails with `400`. Rigging needs a
   textured humanoid (biped) with clear limbs, under 380,000 triangles, face toward +Z, with
   `height_meters` set (default 1.7). It returns the rigged FBX and GLB and, optionally, walking and
   running clips. Run `inspect_glb.py` on the rigged GLB too; it measures in bind pose.
4. **Blender QA and export.** Run `blender_qa.py` inside Blender (exit 1 on a failed check). Put
   `--python-exit-code` before `--python` in a headless run. blender's hook checks the export
   script for removed `bpy` calls. Run `inspect_glb.py` on the exported file: the export, not the
   download, is what ships.
5. **Unity import.** Copy the model into `Assets/` without a `.meta`, and let Unity create one. Never
   copy a `.meta` from another project, because it carries that project's GUID. unity-traps' hook
   runs `check_unity_project.py` after the copy. Before calling the import done, capture the scene
   and read the console, as unity-traps' done-gate says.

## Credit caps: the cap is yours

- **Higgsfield.** Read the balance with `higgsfield account status`. Price each job with
  `higgsfield generate cost <model> --prompt "…" --image ref.png`, which "estimate[s] credits without
  creating a job". Multiply by the batch size, then ask. Generations through the CLI or MCP always
  spend credits at standard rates; free and unlimited generation exists only on the website.
- **Batch, then wait.** For one job, add `--wait`; Higgsfield's own skill prefers it. For a batch,
  submit each job with `higgsfield generate create <model> … --json` and no `--wait`. That prints
  the job ids; record every one. Then run `higgsfield generate wait <id> --timeout 20m` for each, or
  check them with `higgsfield generate list --image`. Higgsfield's API docs say to limit submissions "with a worker
  pool or semaphore". A full queue returns `429`, and nothing is created or charged. Failed and
  `nsfw` requests are not charged.
- **Meshy** bills per request:

  | Request | Credits |
  |---|---|
  | Image to 3D, `meshy-7.1`, 2K textures | 30 |
  | Image to 3D, `meshy-t2`/`meshy-t2.5`, 2K textures | 15 |
  | Remesh | 5 |
  | Rigging | 5 |
  | Animation | 3 per action |

  Read `docs.meshy.ai/en/api/pricing` for current figures, since the page carries no date. Ultra
  geometry costs +5.
- These names are not in Higgsfield's docs or in CLI 1.2.2's `--help` (checked 2026-11-02):
  `max_credits`, a `batch` command, `jobs wait`. Do not call them. Run `higgsfield <command> --help`
  on the installed version instead.

## One character, many generations: references, not seeds

- No Higgsfield image model lists `--seed` in the CLI's model reference. Only the 3D models do
  (`image_to_3d`, `multi_image_to_3d`, `sam_3_3d`). Re-running a prompt does not give the same
  character. Keep the approved concept and pass it to each new view or pose as `--image`. The flag
  repeats, and most image models take one or more references, often up to 8.
- Soul ID trains on 5–20 photos of a real person's face. Higgsfield's own skill sends
  "named-character / non-photo avatars" to `generate --image` instead, so do not train one for a
  game character.
- Meshy's image-to-3D request has no seed. The same concept image is the consistency. For a
  character drawn from several sides, use Multi-Image to 3D: one to four images "of the same object,
  taken from different angles", where `meshy-7.1` reads the first image as the front.
- Keep one manifest per asset, for example `art/<asset>/manifest.json`. Record the concept file,
  prompt, reference ids, model, Higgsfield job id, Meshy task ids, budget row, and each checker's
  result. Nothing reads it back; it is how the next generation of the same character starts from
  the same inputs.

## Anti-patterns

- **Generate big, decimate later.** You pay for 8K textures or Ultra geometry that the budget row
  then throws away. Generate at the row with Smart Topology.
- **The signed URL as the asset.** It stops working at `expires_at`, and the model is gone after 3
  days.
- **Resubmit on a timeout.** Meshy says the first task "might still be running". List the tasks,
  then poll the same id.
- **A seed in place of a reference.** There is no image seed to rely on. Pass the reference.
- **Rigging the raw download.** It has an unknown pose and an unknown facing axis, and it can be
  well over the triangle budget. Remesh to the row, check that it faces +Z, then rig.
