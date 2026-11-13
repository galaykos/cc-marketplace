# Asset plugins: keep, shrink or retire. blender, meshy, asset-forge, pixel-art

Date: 2026-11-13. Branch `review/overseer-necessity`. I edited nothing in the repo. `git status` shows no change under
the four plugin directories. The one untracked file, `rationale/overseer-necessity-review-2026-11-13.md`, is not
from this review.

I ran the test harnesses on `git archive HEAD` copies in `/tmp/assets-review-run` and `/tmp/assets-review-repo`,
not in the checkout. Downloaded READMEs and sources are in `/tmp/assets-review-web` and were never executed.

**verified** = read, fetched or run in this session. **relayed** = taken from a doc or snippet I did not re-check.

## 1. Verdict table

| | blender | meshy | asset-forge | pixel-art |
|---|---|---|---|---|
| **Mechanism ours ships** | `check_bpy_scripts.py`: a stdlib static checker for bpy calls the target version removed (version windows, exit 0/1/2), run by a PostToolUse hook on any written `.py` that imports bpy. `anim_audit.py`: runs the real FBX and glTF exporters and reads what they wrote. `rig_check.py` and `blender_qa.py` also run inside Blender, and both exit 1 on a finding | `inspect_glb.py`: a stdlib GLB/glTF budget checker (triangles; PNG/JPEG/KTX2/WebP texture size; required extensions; extents; exit 0/1/2). The `glb-check.sh` hook runs it when a model lands: a Write, a Bash call naming glb/gltf/meshy, or a Meshy MCP download | A stdlib `forge` MCP server with 9 tools that runs headless jobs on a *snapshot*: fails a job with `source-modified` if the opened file changes; post-export re-import audit. A 14-module bpy library. A review-after-change Stop gate. The `art-reviewer` agent. Engine and platform presets | `check_sprite_sheet.py` (sheet JSON against its PNG) and `check_tilemaps.py` (Tiled/LDtk references, GID masking, layer length, layer formats Phaser/melonJS skip), both run by the `sheet-check.sh` hook |
| **Bytes** (tracked / on disk) | 201,206 / 341,063 | 66,027 / 66,027 | 662,876 / 2,121,601 (includes gitignored eval results and pycache) | 95,073 / 95,073 |
| **Always-on tokens** (baseline file) | 157 | 79 | 1,322 | 125 |
| **Installs / use** | 2 local installs; 0–4 Skill invocations; transcript attribution 336 | 2 local; 0–4 invocations; attribution 22 | **0 installs** on this machine | 2 local; 0–4 invocations; attribution 111 |
| **Best external** | EL4CTEO/blender-skills: MIT, 1,042★, pushed 2026-11-13, v1.3.0 released 2026-11-13. 28 skills and ~37 headless bpy scripts (qa_check, rig_check, loop_check, review_shots, make_lods, bake_maps, export_asset); a 4.x→5.3 API table written as prose. Live control: ahujasid/mcp-for-blender (MIT, 34,289★, pushed 2026-11-13) and Blender Lab MCP (GPL-3.0+, 37★, v1.0.3 of 2026-09-11) | Meshy's own **@meshy-ai/meshy-mcp-server 0.6.11** (MIT, 93★, pushed 2026-11-13, npm latest 2026-11-10) plus **meshy-dev/meshy-3d-agent** (MIT, 108★, pushed 2026-11-12; skills.sh lists 2,761 installs of `meshy-3d-generation`) | elithril/blender-kiln: MIT, 216★, pushed 2026-11-03. A Claude Code plugin on a Blender MCP: brief or photo → validated GLB; fresh-subagent review rounds; headless builds; gltf-transform plus the Khronos validator on export; gltfpack LODs; retarget and auto-rig. Second: EL4CTEO/blender-skills scripts | No equivalent checker exists. Aseprite MCPs: diivi/aseprite-mcp (MIT, 992★, pushed 2026-11-03; 123 tools including `export_spritesheet` and `validate_scene`). 0x0funky/agent-sprite-forge (MIT, 5,682★, pushed 2026-11-13) generates sprites and maps with its own QC and exporters. PixelLab MCP is a hosted generator (all rights reserved, 48★, last push 2025-08-10) |
| **Overlap** | The 5.x API facts. The external carries them as prose, and the base model already knows the headline ones (control arm 5/5). QA and rig scripts: ours were ported from EL4CTEO | Nearly the whole task-lifecycle half of our skill, which the vendor now enforces in code or in its server instructions: no resubmit, Retry-After, both kinds of 429, 409 on deleting a running task, 3-day expiry, smart topology for games, rig/UV limits, CLI exit codes | Review renders and contact sheets, LODs, bakes, retargeting, the fresh reviewer, headless runs, validation on export | The image-model → pixel-art finishing rules: our section was distilled from agent-sprite-forge |
| **What only ours does** | A static checker that needs no Blender and fires on write. An exporter-as-oracle clip audit. QA that exits non-zero on a failed check. EL4CTEO's `_bpyx.cli` still exits 1 only on an exception | A budget gate with an exit code, fired on the vendor MCP's own downloads. KTX2/WebP texture sizing. The required-extension check. The plan-tier licence rule (CC BY 4.0 / CC0 / training opt-out). GLB-for-Godot against the vendor's "FBX for every engine" | Unity/Unreal/Godot presets (naming, UCX collision, LOD chains, packing) with a 20-check validator per platform tier. The snapshot write guard. A Stop gate that forces a review after scene changes. kiln names no engine | Checking an existing Aseprite sheet against its PNG, and a hand-edited Tiled/LDtk map against Phaser's skip rules; a hook on export; the Aseprite CLI/JSON traps |
| **Verdict** | **keep**: add 5.3 rules; run the 3 pending evals | **shrink** to: the checker and its hook, the licence rule, and the engine-handoff rules. Drop the lifecycle, 429, cancel, exit-code and polycount prose. Route lifecycle via a stack-scan framework-native row to Meshy's MCP and `meshy-3d-agent` | **keep on probation**. It is unused and unmeasured (one 3-run lift). Kill-trigger: still no install or real asset by an agreed date → retire and route via stack-scan to blender-kiln (GLB/web) and EL4CTEO (scripts) | **keep** (optional trim: replace the generated-art section with a pointer to agent-sprite-forge) |
| **Confidence** | medium-high. The mechanism is unique and cheap at 157 tokens, but the prose has no measured lift | medium-high. The vendor overlap is verified in its source. The cost saved is small (79 tokens); the gain is less drift | low. The mechanism is real and its tests pass, but there is zero use, one 3-run delta, and a better-starred near-peer | medium. The checkers are unique, but no control-arm eval exists |

## 2. Evidence per plugin

### blender

- **verified (ran)**: CI harness on a copy: 60 tests, OK, 18 skipped.
- **verified (ran)**: in-Blender, `BLENDER_EXE` set to `~/Applications/blender-5.2.3` and then to `blender-5.3.0`: 60 tests, OK, 0 skipped on each. The run covers the rule probes, `anim_audit`, `rig_check` and `blender_qa`.
- **verified (ran)**: `scripts/smoke/game-checker-hooks-tests.sh`: 51 passed, 0 failed (all four game hooks). Its bpy hook cases:
  - fires on `action.fcurves`;
  - silent with no version source;
  - a 4.2 `.blend` outranks a 5.2 Blender on PATH;
  - silent outside the project and when switched off.
- **What the checker catches** (verified, SKILL.md and README): calls removed or renamed across 4.0–5.2, each with a version window. Examples: `action.fcurves`, `scene.node_tree`, `BLENDER_EEVEE_NEXT`, bone layers and groups, `bake_action` keywords, `driver_add` modifiers, GN `Socket_N` keys.
- **What it misses** (verified):
  - aliased imports, renamed variables and `getattr`;
  - **no 5.3 rules**. `check_bpy_scripts.py` has none, while EL4CTEO's table lists 5.3 changes: VSE `EXPAND` → `RIPPLE`, and the glTF WebP options becoming compressed-image options.
- **verified**: eval `removed-5x-bpy` scored 5/5 with the plugin and 5/5 without (`rationale/evals/2026-11-02-080609-blender.json`), so it is a regression guard only. Three cases written 2026-11-07 have never run: `fbx-all-actions-cross-clips`, `headless-ik-bake`, `masked-shape-key-export`.
- **verified**: `installed_plugins.json` shows 2 local installs of 0.3.1. The installed cache 0.3.1 holds all 4 references, so the 11-05 retro's issue #24 ("references missing from cache") no longer holds for the installed versions.
- **relayed** (necessity review 11-12): 0–4 invocations, attribution 336.
- **verified (2026-11-13)**: EL4CTEO/blender-skills.
  - MIT, 1,042★, pushed 2026-11-13, v1.3.0 the same day; a Claude Code plugin `blender-agent-skills`.
  - 28 skills and 104 `.py` files in the tree; the README says "67 headless Blender tests".
  - Listing cost ≈ 2,569 tokens. That is my estimate: 10,276 B of `description` lines ÷ 4, not measured.
  - Its `_bpyx.cli` exits 1 only when `run()` raises. A check that returns `{"pass": false}` exits 0, which is the defect our port fixed.
- **verified (2026-11-13)**: arjun988/blender-skills: MIT, 2,712★, pushed 2026-11-06. 94+ skills and **0 `.py` files**: prose orchestration over a Blender MCP, with no checker.
- **verified**: MCP servers.
  - ahujasid/mcp-for-blender (the old `blender-mcp` redirects there): MIT, 34,289★, 58 open issues. Live control, multi-angle views, asset and AI generation. An anonymous usage record is sent by default.
  - Blender Lab `lab/blender_mcp` (projects.blender.org API): 37★, 27 open issues, v1.0.3 of 2026-09-11, GPL-3.0. Tools: `execute_blender_code`, `execute_blender_code_for_cli`, blend-file summaries, screenshots, `render_thumbnail_to_path`, `render_viewport_to_path`, API and manual doc search.
  - Neither ships a removed-API or export checker.
- **verified**: no Blender, Meshy, Aseprite or sprite plugin exists in `anthropics/claude-plugins-official` (316 plugins, raw `marketplace.json` read 2026-11-13), nor in `anthropics/skills`.

### meshy

- **verified (ran)**: `inspect_glb.test.sh`: 11 tests, OK. The hook harness cases are among the 51 passes above.
- **verified**: the hook matcher `mcp__.*[Mm]eshy.*` matches both connected servers' download tools, `mcp__meshy__…` and `mcp__meshy-mcp-server__…` (regex test). Our gate therefore fires on the official server's downloads.
- **verified**: where the two servers come from. `~/.claude.json` user `mcpServers` has (env redacted):
  - `meshy` = `npx -y @meshy-ai/meshy-mcp-server@0.6.7`;
  - `meshy-mcp-server` = `npx -y @meshy-ai/meshy-mcp-server`, unpinned (latest is 0.6.11).
  - Nothing under `~/.claude/plugins/cache` provides them.
  - Both inject the workflow guide, and the pinned one is older (no "Choosing Models").
- **verified (source at HEAD, 2026-11-13)**, meshy-mcp-server `src/instructions.ts` and `src/services/error-handler.ts`:
  - Rule 1: cost confirmation; game assets get smart topology.
  - Rule 2: never re-create a task you are unsure about.
  - Create POSTs are never retried, in code (README: "Safe retries (v0.6.3)").
  - 409 on DELETE of an IN_PROGRESS task: "permanent, no refund".
  - Queue-full 429 (`NoMorePendingTasks`/`NoMoreConcurrentTasks`, no Retry-After) handled separately from rate-limit 429.
  - Polls paced by Retry-After.
  - `tasks.ts`: download results carry `expires_at` and the note "results are kept for 3 days".
  - Rig ≤300K faces on a textured humanoid; UV unwrap ≤40K faces; animation ids never guessed.
  - Scenario C asks for FBX for every engine.
- **verified (2026-11-13)**: meshy-3d-agent skill (`troubleshooting.md`, `delivery.md`, `pipelines.md`):
  - CLI 0.8 exit codes 1–14 and 130, the same numbers as our "0.7" table;
  - reconcile on exit 10;
  - 409 / exit 14 on deleting a running task;
  - NoMorePendingTasks;
  - 3-day retention;
  - `meshy inspect faces` (triangles only).
  - `meshy-cli` npm latest is 0.8.5 (2026-11-09), while our skill stamps 0.7.
- **verified**: grepping the vendor skill files I fetched and the MCP source found **no** CC BY / CC0 / Terms-of-Use licence rule. The licence rule is ours alone. Its facts are **relayed** from our skill; I did not re-read Meshy's Terms.
- **verified**: eval `no-resubmit-unknown-create` scored 5/5 with and 5/5 without (`rationale/evals/2026-11-02-080953-meshy.json`). The base model plus the vendor server already behave.
- **relayed** (session retro 11-05 #8): without the game plugins loaded, Meshy credits were spent with no confirmation, and a decimation tore textures but was called "clean". Of the two, only the vendor's Rule 1 addresses credit confirmation; our skill carries no cost-confirmation rule.
- **verified, possible drift**: our skill says "The task object documents no face count". The vendor `tasks.ts` prints `task.face_count` when the API returns it. I did not check the API docs.

### asset-forge

- **verified (ran on a copy, Blender 5.2.3)**:
  - `forge-server.test.sh`: 45 passed, 0 failed, 0 skipped. The cases cover the MCP protocol, the source `.blend` staying byte-identical after every tool, and the `out_dir` guards (symlink, bind mount, case).
  - `forge-lib.test.sh`: 136 passed, 0 failed.
  - `review-state.test.sh`: 16 passed.
- **verified**: `installed_plugins.json` has no asset-forge entry.
- **verified**: eval aggregate on disk (`evals/results/2026-11-08T10-18-45-949Z`, `…10-26-05-927Z`), 3 runs per arm:
  - `pipeline-asks-engine` 1.00 with against 0.33 without;
  - `review-structured-verdict` 0.67 against 0.50;
  - the other 4 cases 1.00 against 1.00.
  - By `CLAUDE.md`'s rule, 3 runs cannot separate effect from flake.
- **verified, doc drift in its README**:
  - "Status: 0.6.0", but `plugin.json` says 0.7.0;
  - "there is no Meshy bone map", but `presets/bonemaps/meshy_to_rigify.json` ships (CHANGELOG 0.6.0);
  - the "What has teeth" table cites 44 server cases and 105 library cases; measured today: 45 and 136.
- **verified**: dependents. Only `plugins/candor/hooks/preamble.sh:132` names `asset-forge:art-reviewer`; plus the stack-scan `signals.md` and `catalog.md` rows.
- **verified (2026-11-13)**: elithril/blender-kiln.
  - MIT, 216★, pushed 2026-11-03, listed in awesome-claude-code.
  - Claude Code plugin; works on both Blender MCP servers.
  - "Review rounds — a fresh eye on every model" (a subagent that never sees the build); headless batch; `review_renders`, `uv_check`, `fidelity_check`.
  - `gltf-transform` with the Khronos validator on every export; gltfpack LODs; retarget and auto-rig.
  - Its README never names Unity, Unreal or Godot; it is GLB/web/AR/print-centric.
- **verified**: EL4CTEO ships `review_shots.py` (contact sheet), `make_lods.py`, `bake_maps.py`, `retarget.py` and `export_asset.py`. That is the same surface as forge's library, as skills rather than an MCP server.
- **relayed** (necessity review §5): the asset-forge → blender merge was withdrawn because of the tool renames, the 1,322-token cost, the blocking Stop hook, and because asset-forge runs without blender. I agree, and nothing new changes it.

### pixel-art

- **verified (ran)**: `check_sprite_sheet.test.sh` 9 OK; `check_tilemaps.test.sh` 17 OK; hook harness cases among the 51 passes. The hook fires on:
  - an Aseprite export with a frame outside the sheet;
  - a `.tmj` with a missing tileset;
  - a stale PNG.
- **What it catches** (verified, SKILL.md):
  - missing or mismatched `meta.size`, a frame outside the image, tags past the frames array, durations ≤ 0, repeated hash keys;
  - map references, GID masking with all 4 flag bits, layer length;
  - compressed or external tilesets under `--engine phaser`.
- **What it misses** (verified): pixels, rotated-frame bounds, slices, pivots; zstd on Python < 3.14; `.tsx`/`.tsj`/`.ldtkl` alone through the hook.
- **verified**: no control-arm eval exists ("Measured: nothing").
- **verified (2026-11-13)**, externals:
  - diivi/aseprite-mcp drives Aseprite, with `export_spritesheet` and `validate_scene` (missing layers and cels). It does not check sheet JSON against its PNG, and does not read Tiled/LDtk.
  - MalloyTheDev/aseprite-mcp: 27★, 156 tools, `validate_loop`.
  - willibrandon/pixel-plugin: 422★, stale since 2025-10-19.
  - agent-sprite-forge: generator, `sheet_qc.py`, Tiled/Godot/LDtk exporters; its README says LDtk and Aseprite exports are parse-level only.
  - skills.sh "tiled": nothing over 48 installs (rpgjs/tiled-ai, no licence).

## 3. Dependency sweep

No plugin gets a retire verdict now. These sizes apply if one is retired later. Counts are of files outside the
plugin that use a plugin-reference form, excluding `rationale/`; they over-count slightly because Blender is also
an ordinary word.

- **asset-forge** (the probation kill-trigger): about 7 files.
  - `marketplace.json`, `README.md`;
  - `candor/hooks/preamble.sh:132` plus the candor CHANGELOG;
  - stack-scan `signals.md:57`, `catalog.md:11` plus its CHANGELOG;
  - `scripts/trigger-corpus.tsv`, the two `context-budget*-baseline.json` files;
  - a `removed-plugins.tsv` row and the renames map.
  - No CI step and no smoke harness names it.
  - Add a routing row in `stack-scan/.../official-complements.md` § Framework-native tooling for blender-kiln.
- **meshy** (if retired rather than shrunk): about 21 files plus CI.
  - `scripts/smoke/game-checker-hooks-tests.sh` (16 mentions; CI);
  - `.github/workflows/validate.yml`;
  - `skill-router/rules.tsv`;
  - stack-scan `signals.md`, `stack-relevance.md`, `flags.md`, `catalog.md`;
  - `all-plugins.sh`;
  - the near-miss clauses in blender, pixel-art and asset-forge (pipeline, organic-modeling);
  - `gamedev/skills/asset-pipeline/SKILL.md` (13 mentions; the sibling reviewer's scope).
  - A shrink that keeps the skill name `meshy:meshy-generation` breaks **none** of these.
- **blender**: about 29 files, plus CI (hook harness, `validate.yml`), `scan.sh` and `scan.test.sh`, `skill-router/rules.tsv` (6), and asset-forge's retarget skill, which calls `anim_audit.py` and `rig_check.py`.
- **pixel-art**: about 16 files, plus CI, `skill-router/rules.tsv` (10) and the stack-scan rows.

## 4. Not checked

- **No eval run** (cost):
  - the three blender cases expected to fail control were not run;
  - pixel-art has no case at all.
  - Every "helps" claim is therefore unmeasured.
- **Meshy**:
  - no Meshy MCP tool was called (credits);
  - Meshy's Terms of Use were not re-read, so the licence facts are relayed;
  - API docs for `face_count` were not read.
- **External plugins and skills**:
  - none was installed or run. Their always-on cost is an estimate for EL4CTEO and unmeasured for the rest;
  - no head-to-head output comparison was made;
  - EL4CTEO's own 67 tests were not run.
- **External reading** (partial):
  - EL4CTEO: README, `plugin.json` and 3 of 28 SKILL.md files (core, asset-qa, export, animation) plus `_bpyx.py`;
  - arjun988: README and tree only;
  - blender-kiln: README only, grepped rather than read in full;
  - agent-sprite-forge, diivi, MalloyTheDev and pixel-plugin: READMEs grepped, not read in full;
  - PixelLab: README only;
  - Blender Lab: `readme.md`, `readme_tools.rst` and repo metadata. blender.org/lab/mcp-server returned 403 (Cloudflare), so its install text in our README is relayed.
- **Repo reading** (not read in full):
  - blender references `api-5x.md`, `export.md`, `rigging.md`, `animation.md` (307 lines);
  - pixel-art `tilemaps/SKILL.md`, lines 61–124;
  - asset-forge skills other than `pipeline` (frontmatter only), the agent body, `references/`, `blender_lib/` source and the presets.
  - meshy, both blender SKILL.md files and `pixel-art-pipeline` were read in full.
- **Usage counts** (installs aside) are relayed from `rationale/marketplace-necessity-review-2026-11-12.md`. Hook firing in real sessions is unmeasured; only the harnesses ran.
- **Star counts and dates** are GitHub API values on 2026-11-13. skills.sh install counts come from its search API, with semantics unverified.
- **Sibling plugins** (gamedev, godot, unreal, phaser, unity-traps) were not reviewed. gamedev's `asset-pipeline` is the largest meshy dependent.
