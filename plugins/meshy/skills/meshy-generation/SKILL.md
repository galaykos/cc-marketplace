---
name: meshy-generation
description: Use when generating, texturing, rigging or downloading 3D models through Meshy (meshy-cli, the Meshy MCP server, api.meshy.ai), or checking a GLB/glTF's triangles, texture size or required extensions before engine import — paid-task resubmit and cancel traps, 3-day file expiry, plan-tier licence, rigging limits.
---

> Last verified: 2026-10-30 — https://docs.meshy.ai/api/task-lifecycle — npm:meshy-cli@0.7

Find which client the project drives Meshy through before advising: `meshy-cli` (`meshy --version`; the
exit codes below are 0.7.x), the MCP server `@meshy-ai/meshy-mcp-server`, or raw HTTPS to
`https://api.meshy.ai/openapi/`. The task, billing and file rules are the API's and hold for all three.

## The rules, and who enforces each

| Rule | Standing |
|---|---|
| Never resend a create after a timeout, a dropped connection, a 5xx or CLI exit 10; reconcile first | **recorded**. meshy-cli and the MCP server already refuse to retry a create (their own code); a hand-written client has no guard, and the API has no idempotency key |
| A running task cannot be cancelled; do not delete to "save credits" | **recorded** — the API answers 409 and the task keeps running |
| Download on `SUCCEEDED`; never keep a signed URL as the only copy | **recorded** — files are gone after 3 days |
| Measure the model file against the target's triangle, texture and extension budget before import or upload | **gate** for what `inspect_glb.py` checks (exit 1); no hook runs it, so whether it runs is **agent-graded** |
| Ship a free-plan model only with credit to Meshy; never post a paid model to Meshy Community | **recorded** — the Terms of Use, below; nothing reads a licence |
| Steam AI-content disclosure and the per-asset licence record | the **gamedev** companion's `game-assets` skill owns both |

## Paid tasks: one create, then reconcile

- A create answers `202` with a task ID and runs in the background. Most creates on the Free plan
  answer `402`: creating API tasks needs a paid plan. A `4xx` means no task was created.
- After a create times out, its connection drops or it gets a `5xx`, the task may exist and be
  billed. Wait about a minute, list that resource's newest tasks (`sort_by=-created_at`), and
  create again only when the task is not there.
  - meshy-cli exit 10 (`submission_unknown`): run `meshy operations list --state unknown`, then
    `meshy operations resolve <op-id> --task-id <id>` or `--not-created`. `--operation-id` replays
    from a local journal on that machine; it is not a server idempotency key.
  - MCP server: the error says the create "was not retried automatically"; check
    `meshy_list_tasks` with that `task_type` before calling the create tool again.
- A failed status poll (timeout, `429`, `5xx`) says nothing about the task: poll again. Pace polls
  by the `Retry-After` header, else 5 s; they count toward the 20 requests/s limit.
- Wait at least 60 minutes from `created_at` before calling a task stuck. meshy-cli's `wait`
  stops at 600 s by default with exit 8 while the task keeps running: run the same `wait` again,
  or pass `--timeout 3600`. The MCP status tool (0.6.7) returns after at most 5 minutes: call it again.
- Only `FAILED` is a failure, and Meshy refunds it. Recreate on `task_error.type` `timeout`,
  `service_unavailable` or `server_error`; on `invalid_input`, fix the input first.
- meshy-cli 0.7 exits: 1 task `FAILED` or unclassified, 2 usage, 3 auth, 4 validation, 5 not found,
  6 rate limit, 7 network, 8 wait timed out, 9 cannot pay (`402`), 10 submission unknown, 11 local
  I/O, 12/13 check failed/unknown, 14 conflict (`409`), 130 interrupted.
- Call `https://` directly. A `POST` to `http://` gets a `301`, which clients replay as a `GET`
  without the body.

## Cancel, delete and the two kinds of 429

- `DELETE` of a `PENDING` task deletes it and refunds it. An `IN_PROGRESS` task answers `409`
  (meshy-cli exit 14): it keeps running, its credits are spent. Deleting a finished task is
  permanent and refunds nothing. The MCP tool `meshy_cancel_task` cannot stop one either.
- `CANCELED` exists only for Creative Lab tasks.
- `429` with the message `Rate limit exceeded` carries `Retry-After`: wait that long and retry;
  nothing was created, so this one is safe to resend even for a create.
- `429` whose message starts `NoMorePendingTasks` (or `NoMoreConcurrentTasks`) is the concurrent-task
  cap (Pro 10, Premium 30, Studio 60 or 20, Ultra and Enterprise 100). It has no `Retry-After`;
  only one of your tasks finishing frees a slot, so retrying at once fails again.

## Files expire: download promptly

- Meshy deletes API output after at most 3 days, Enterprise excepted. The URLs in `model_urls`,
  `texture_urls` and `thumbnail_url` are signed and stop at the task's `expires_at`; getting the
  task again returns the same URL with the same expiry.
- Never send a stored download URL back as `model_url` (remesh, rigging, printability): after
  expiry it fails with `400 failed to download model file`. While the task exists pass
  `input_task_id`; after that it is `404`, so upload your own copy.
- A text-to-motion clip must be applied to a rig within those 3 days.
- "Now as FBX" is a `convert` of the existing task (1 credit) while it exists, never a new
  generation. `target_formats` limits what a task generates; omitted, it generates every format
  except `3mf`.

## Topology and the engine handoff

- The task object documents no face count: measure the downloaded file (below). Standard models are dense;
  meshy-cli's design log records 982,320 triangles for one image-to-3d result (upstream's
  measurement, not re-run here).
- For a budget, generate with `model_type: "smart-topology"` and `target_polycount`: `meshy-t2.5`
  (the default) takes 100–30,000, default 15,000; `meshy-t2` takes 100–15,000, default 4,000
  (meshy-cli substitutes 10,000). Output is triangles only. Or `should_remesh: true` on a standard
  model (100–300,000, default 30,000), or a `remesh` task (5 credits) per LOD of the existing task.
- Refine (texturing) takes only a `SUCCEEDED` text-to-3d preview; an image-to-3d, remeshed or
  uploaded model is textured with `retexture`. Image-to-3d textures by default: 30 credits
  textured against 20 mesh-only on `meshy-7.1`, so pass `should_texture: false` for a draft.
- glTF is metres, `+Y` up, front facing `+Z` (glTF 2.0 §3.4). Read the extents line before
  scaling in the engine instead of guessing a factor.
- Godot's 4.7 docs mark glTF 2.0 as the recommended format and import FBX through ufbx from 4.3
  on; ask for GLB for Godot and the web. The MCP server's own game-engine flow asks for FBX for
  every engine.
- A file whose `extensionsRequired` names an extension the importer lacks SHOULD NOT load (glTF
  2.0 §3.12). Meshy itself refuses a meshopt-compressed GLB as `invalid_input`, and a Draco GLB
  over 100 MB in remesh, rigging and UV unwrap.

## Rigging and animation limits

- Rigging takes a textured humanoid biped with clear limbs: not props, quadrupeds or untextured
  meshes. At most 320,000 faces; remesh to 300,000 or fewer first. An uploaded model must be GLB
  facing `+Z`; a `422` means Meshy found no humanoid pose in it.
- Leave out the deprecated `texture_image_url`: it replaces the model's textures and drops PBR maps.
- A rigging task can already carry walking and running clips (`basic_animations`); check its
  result before paying for `animate`.
- `animate` takes exactly one of `action_id`, `action_ids` (1–10 unique IDs, one file, clips in
  array order, 3 credits per action) or `motion_task_id` (biped rigs only). Take IDs from the
  live library (`GET /openapi/v1/animations/library`, `meshy animation-catalog list`), never memory.
- UV unwrap takes a GLB of at most 40,000 faces.

## Licence and ownership by plan

From Meshy's Terms of Use (last updated 2026-09-19, https://www.meshy.ai/terms-of-use):

- §3.2: free-plan output is owned by Meshy and made available to you under CC BY 4.0, with credit
  to Meshy. The pricing page's table says "You own the output" on Free; the Terms are the contract.
  A paid plan's output is yours, and you may keep it private.
- §3.3: a 3D model shared to Meshy Community is licensed CC0. Posting a paid model gives it away.
- §2.9: inputs and outputs of non-Enterprise customers may train Meshy's models; opt out through
  support@meshy.ai.
- Unverified: what a downgrade does to earlier paid-plan models (Meshy's help article could not be
  fetched on 2026-10-30).

Record the plan and licence per asset when it is generated. The disclosure itself is gamedev's.

## Check the file: `inspect_glb.py`

```sh
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/inspect_glb.py" assets/hero.glb [more.glb ...] \
  [--max-tris 15000] [--max-texture 2048] [--allow-ext KHR_texture_transform] [--json]
```

- Exit **0** every file within budget; **1** a file broke `--max-tris` or `--max-texture`,
  requires an extension not passed to `--allow-ext`, or names a missing external file; **2** bad
  arguments, or a file that is not readable glTF 2.0. 2 wins over 1. Never read 2 as a measured
  failure.
- Triangles count every drawn instance of the default scene (strips and fans `n − 2`, points and
  lines none), the way Meshy counts faces for its upload limits; accessor counts are read without
  decoding, so a Draco or meshopt file still counts.
- Pass `--allow-ext` once for each required extension the target importer is known to support;
  every other one fails, because nothing here knows your engine's list.
- Residuals: only PNG and JPEG are sized, so a KTX2 or WebP image fails `--max-texture` as
  unmeasured; extents trust POSITION `min`/`max` and measure skinned meshes in bind pose; the
  file is not validated against the glTF schema. Run the engine import for that.
- Meshy's own `meshy inspect faces --model <file> --max-faces N` gives the triangle count alone
  (exit 0 pass, 12 over, 13 unknown) and needs meshy-cli installed.

## Anti-patterns

- **Resubmit on timeout** — creating again after a lost response; the first task is billed and running.
- **Cancel to save credits** — deleting an `IN_PROGRESS` task: `409`, nothing refunded.
- **URL as storage** — keeping only `model_urls` and fetching after 3 days.
- **Regenerate for a format** — paying for a new model when `convert` (1 credit) would do.
- **Raw mesh to the engine** — importing a standard model without measuring its triangles.
- **Unattributed free model** — shipping free-plan output without crediting Meshy.
