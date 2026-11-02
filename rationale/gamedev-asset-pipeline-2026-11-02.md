# gamedev asset-pipeline: vendor facts and their sources (2026-11-02)

The `asset-pipeline` skill (gamedev 0.2.0) covers the handoffs from a Higgsfield concept image to
Meshy image-to-3D, remesh and rig, Blender QA and export, and Unity import. The user's rule for it
was "only include facts you can verify from Higgsfield's and Meshy's docs".

Each fact below was read on 2026-11-02 in this session. Raw Markdown pages were fetched with
`curl` and searched with `grep`. Pages that only render as HTML went through WebFetch, whose quotes
pass through a summarising model; those rows are marked *(WebFetch)*. A background researcher
gathered the first list. Every row kept here was then re-read from the page itself; the
researcher's relayed text was not used as a source.

Standing: `recorded`. No gate reads this file. Nothing re-reads these pages, so treat every number as
true on 2026-11-02.

## Higgsfield

| Fact used in the skill | Source | Quote |
|---|---|---|
| No native credit cap | https://higgsfield.ai/creator-hub/help-center/integrations/how-do-i-connect-higgsfield-to-ai-agent (dateModified 2026-09-24) *(WebFetch)* | "There's no native credit cap." / "This is a prompt-level instruction, not a hard limit." |
| CLI and MCP generations always spend credits | https://higgsfield.ai/creator-hub/help-center/integrations/what-is-higgsfield-mcp (dateModified 2026-10-24) *(WebFetch)* | "MCP always uses credits." Generations from "MCP, CLI, Canvas, Supercomputer, or other automated tools deducts credits at standard rates." |
| `generate cost` estimates without creating a job | `higgsfield generate cost --help`, CLI 1.2.2 (build 53301ea, 2026-10-16) | "Estimate credits without creating a job." |
| `--wait`, `--wait-timeout`, `--wait-interval` | `higgsfield generate create --help`, CLI 1.2.2 | "Use --wait to block until each job finishes and print the result URL(s)." Example: `--wait --wait-timeout 20m --wait-interval 5s` |
| `generate wait <id> --timeout` | `higgsfield generate wait --help`, CLI 1.2.2 | "Poll a job until it finishes" · `--timeout duration    max wait duration (default 10m0s)` |
| Without `--wait`, `--json` prints job ids; one job prefers `--wait` | https://raw.githubusercontent.com/higgsfield-ai/skills/main/higgsfield-generate/SKILL.md | "Without `--wait`, you get the job IDs." / "Pass `--wait` to `generate create` so the command blocks until done" |
| `account status` reads the balance | `higgsfield account --help`, CLI 1.2.2 | "status       Show account email, plan, and available credits" |
| Limit submissions; a full queue costs nothing | https://docs.higgsfield.ai/docs/concepts/rate-limits.md | "Limit generation submissions with a worker pool or semaphore …" · "a new generation request is rejected with `429 Too Many Requests` and a `Retry-After` header, and nothing is created or charged" |
| Failed and nsfw requests are free; files kept seven days | https://docs.higgsfield.ai/docs/concepts/billing-and-retention.md | "Requests ending as `failed` or `nsfw` are not charged." · "Request files are kept for seven days after the request finishes, then deleted." |
| No `max_credits`, no `batch` command, no `jobs wait` | the five `--help` texts above, plus both help-center pages and docs.higgsfield.ai billing and rate-limits | Absent from all of them. A third-party blog (Scalekit) names `jobs_wait` and `*_batch` tools on Higgsfield's hosted MCP; it is not Higgsfield's doc, so the skill does not use it (user decision 2026-11-02) |
| Only 3D models take `--seed` | https://raw.githubusercontent.com/higgsfield-ai/cli/main/MODELS.md | `--seed` rows sit only under `### image_to_3d`, `### multi_image_to_3d` and `### sam_3_3d`. The file says it is "Generated from `higgsfield model list` and `higgsfield model get <job_set_type>`" |
| `--image` repeats; often up to 8 references | https://raw.githubusercontent.com/higgsfield-ai/skills/main/higgsfield-generate/references/media-inputs.md | "Most image models (`nano_banana_flash`, `flux_2`, `seedream_v4_5`, `gpt_image_2`, …) — `image` — 1+ references, often up to 8." |
| Soul ID is for a person's face; non-photo characters use `--image` | https://raw.githubusercontent.com/higgsfield-ai/skills/main/higgsfield-soul-id/SKILL.md | "5–20 face photos, varied angles and lighting." · "NOT for: one-shot face swaps (use higgsfield-generate with --image), named-character / non-photo avatars (use higgsfield-generate with prompt)." |

## Meshy

| Fact used in the skill | Source | Quote |
|---|---|---|
| Input image: JPG/PNG/WebP up to 20 MB | https://docs.meshy.ai/en/api/image-to-3d.md | "The image must be a JPG, JPEG, PNG, or WebP file of at most 20 MB." |
| Best input: one subject, simple background, at least 512 × 512, evenly lit | https://docs.meshy.ai/en/webapp/image-to-3d (HTML, read with `curl`) | "A clear subject on a simple background, at 512 × 512 pixels or larger, gives the best result." · "Use an evenly lit photo, or correct the lighting in a 2D editor first." |
| T or A pose before rigging | same page | "For the best results with Animate, which auto-rigs the model and applies animation presets, set the pose to T-Pose or A-Pose." |
| `pose_mode` values | https://docs.meshy.ai/en/api/image-to-3d.md | "`a-pose`: an A pose · `t-pose`: a T pose · `""` (empty string): no specific pose" |
| `target_polycount` ranges and defaults | same page | Remesh "`100` to `300000`", default "`30000`" · `meshy-t2` "`100` to `15000`", default "`4000`" · `meshy-t2.5` "`100` to `30000`", default "`15000`" |
| Smart Topology is triangles only | same page | "With `smart-topology`, Meshy ignores `should_remesh`, `save_pre_remeshed_model`, and `decimation_mode`, and accepts only `topology: triangle`." · "Smart Topology output is triangle-only, so `quad` with `meshy-t2` or `meshy-t2.5` returns `400`." |
| `texture_resolution` 2k is 2048×2048, the default | same page | "`texture_resolution` · *string* · default: `2k`" · "`2k`: 2048×2048" |
| No seed on image-to-3D | same page | The word `seed` appears 0 times in the page (`grep -c -i seed`) |
| Multi-image: one to four views, the first is the front | https://docs.meshy.ai/en/api/multi-image-to-3d.md | "Generate a 3D model from one to four images of the same object, taken from different angles." · "With `meshy-7.1` or `latest`, Meshy uses the first image as the front view" |
| Rigging: textured humanoid, under 380,000 triangles, faces +Z, `height_meters` 1.7 | https://docs.meshy.ai/en/api/rigging.md | "Rigging works well only with standard humanoid (bipedal) characters that have a clearly defined limb and body structure." · "The model can have at most 380,000 triangles (a quad counts as 2)" · "The character's face must point toward the +Z axis" · "`height_meters` · *number* · default: `1.7`" · unsuitable: "Untextured meshes" |
| Rig output: FBX/GLB, optional walking and running | same page | "it returns a rigged character in standard formats and, optionally, basic walking and running animations." |
| Remesh by task id or URL | https://docs.meshy.ai/en/api/remesh.md | "Required unless you send `model_url`. The ID of the task whose model you want to remesh" |
| Signed URLs expire, models kept 3 days | https://docs.meshy.ai/en/api/asset-retention.md | "Meshy keeps the models you generate through the API for at most **3 days**." · "After the signature expires, that request fails with `400 failed to download model file`." |
| Never re-create after your own timeout | https://docs.meshy.ai/en/api/errors.md | "Don't create a new task when your own request times out. The first task might still be running, so check whether it exists before you create another." |
| Credits | https://docs.meshy.ai/en/api/pricing.md (the page carries no date) | Image to 3D: `meshy-7.1` 20 / 30 / 30 / 35, `meshy-t2`/`meshy-t2.5` 5 / 15 / 15 / 20 for mesh only / 2K / 4K / 8K textures; `meshy-6-lite` 4K and 8K "Not supported"; Ultra geometry "+5"; Remesh "5"; Rigging "5 per request"; Animation "3 per action" |

## What the skill states as its own choice, not a vendor fact

- The **budget rows** are the skill's: prop 4,000, character 15,000, hero 30,000 triangles, all at
  2,048 px. Each number is a Meshy default or limit quoted above; tying it to an asset class is the
  skill's call. The character row equals meshy's hook budget, which the user chose on 2026-11-02.
- The **manifest** per asset (`art/<asset>/manifest.json`) is a recorded practice. No vendor asks for
  it, and nothing reads it.
- The **checker at each handoff** points at scripts this marketplace ships: gamedev's
  `asset_report.py`, meshy's `inspect_glb.py`, blender's `blender_qa.py` and `check_bpy_scripts.py`,
  and unity-traps' `check_unity_project.py`. They are not vendor facts.
