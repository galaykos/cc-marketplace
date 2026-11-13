# Game-engine plugin review: gamedev, godot, unreal, phaser, unity-traps

Date: 2026-11-13. Repo: cc-marketplace on branch `review/overseer-necessity`, HEAD 16669f73. Read-only review; nothing in the repo was edited.
The bar (README.md, opening paragraph, read this session): a plugin must carry a rule the model gets wrong from memory, or ship a mechanism prose cannot replace (a hook that fires unasked, a script with an exit code, a gate).

Evidence tags: **V** means verified, i.e. read, fetched or run in this session. **R** means relayed: taken from a doc, prior review or search snippet that was not re-checked here.

---

## 1. Verdict table

| Plugin | What ours ships | Bytes (du -sb) | Always-on tokens | Use (necessity review 2026-11-12; installs on this machine) | Best external alternative | Overlap | What ONLY ours does | Verdict | Confidence |
|---|---|---|---|---|---|---|---|---|---|
| **unity-traps** 0.6.0 | 1 skill, 7 references; `check_unity_project.py` (1,081 lines, stdlib) with 41 harness cases; PostToolUse/PostToolUseFailure hook `meta-check.sh` (smoke: 51/51 game-hook cases); 3 control-arm evals | 173,658 | 111 | Skill invocations 0–4 (range), 0 agent rows, transcript attribution 256 (R). Installs here: 3 (local) (V) | **Unity's official plugin** `unity`, [Unity-Technologies/unity-agent-plugin](https://github.com/Unity-Technologies/unity-agent-plugin) (also listed as `unity@claude-plugins-official`). Owner: Unity. 636★, pushed 2026-11-12, Unity Companion License (GitHub shows NOASSERTION), 4 open issues. 0.1.9-beta has 33 skills, no hooks and 2.7 MB. It works with the **Unity CLI** 1.0.0-beta.17, whose `unity projects verify` checks .meta/GUID problems without launching the Editor. Editor bridge: [CoplayDev/unity-mcp](https://github.com/CoplayDev/unity-mcp): 15,948★, MIT, pushed 2026-10-30, 130 open issues | Partial overlap. Pixel-perfect/URP (`2d-pixel-perfect`), Cinemachine 2→3 (`craft-game-floors`), UXML factory deprecation (`ui-uitk`), NavMeshSurface/OffMeshLink (`initialize-ai-navigation`), `RecordRenderGraph`. `projects verify` covers 3 of our checker's codes: META_MISSING, META_ORPHAN, GUID_DUPLICATE | **A hook that runs the checker in-session after an agent moves files** (Unity ships no hook). Checker codes Unity lacks: `moved-without-meta`, `missing-script`, `malformed-meta`, `class-name-mismatch`, `meta-name-case`, and the version-windowed C# API scan (`EntityId`/`GetInstanceID`, UXML factories, Cinemachine 2 names). It is stdlib Python and needs no beta binary. Prose the official plugin has no hits for: `linearVelocity` renames, `EntityId`, `FindAnyObjectByType`, `SwitchActiveBuildTarget`, `Awaitable`, `persistentDataPath`, `AddForceAtPosition` torque, **6.6 `[SerializeField] Dictionary`**. That last one is the only measured lift in any game plugin: +1.00, 5/5 vs 0/5 | **KEEP.** Fix the README comparison: name `unity projects verify` and say what ours adds. Optional: replace the 2d.md pixel-perfect/atlas and Cinemachine sections with pointers to Unity's skills, to remove the double doctrine | **medium**. Overlap is measured by grep, not by eval. The +1.00 delta is against the base model, not base model + Unity's plugin. Unity's plugin has no dictionary item (V, grep), so the delta probably survives |
| **godot** 0.2.0 | 3 skills, 4 references; `check_godot_project.py` (1,221 lines, 44 cases); PostToolUse hook `godot-check.sh` (26 cases); headless GDScript runner recipe | 148,596 | 284 | 0 invocations, 0 agents, 0 installs; no Godot project in the sample (R). Installs here: 0 (V) | **No vendor tool exists.** Upstream bundle `godot@awesome-gamedev-agent-skills` from [gamedev-skills/awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills): 8,717★, Apache-2.0, pushed 2026-11-12, 2 open issues. It has 16 Godot skills pinned to 4.7.2 (checked 2026-11-11), about 11k skills.sh installs per skill, and ships the same `check_godot_project.py` (1,273 lines). Editor MCP: [Coding-Solo/godot-mcp](https://github.com/Coding-Solo/godot-mcp): 6,632★, MIT, last push 2026-04-16 | High overlap with upstream: Jolt as the 4.6 default, `duplicate_deep`, `.uid`, `set_visibility_for`, `area_mask`, glow defaults, COOP/COEP, PCK encryption, TileMapLayer, headless runner, the same checker. The MCPs drive a live editor and carry no version rules | **The PostToolUse hook** (upstream has no hooks). A few 4.6/4.7 inversions upstream lacks: typed-return overrides on 4.7, mouse/keyboard `device` ids, `MeshInstance3D.skeleton` default, per-node `unique_id`, JSON numbers coming back as floats, `VC_CHARS_AFTER_SHAPING`, `hit_from_inside`. Smaller footprint: 3 skills against 16 | **KEEP.** Optional shrink: fold `godot-project-check` into `godot-best-practices`, since the hook runs the checker anyway. Diff the upstream checker (74 changed lines) for fixes worth porting | **medium-low**. No eval and no usage. The keep rests on the hook alone |
| **unreal** 0.2.0 | 1 skill, 3 references; `check_unreal_project.py` (418 lines, 19 cases): 5.8 Zen/DDC ini keys plus 15 cited deprecated/removed C++ names. **No hook runs it** | 54,617 | 110 | 0 / 0 / 0 (R). Installs here: 0 (V) | **Epic's official plugin** `unreal-engine-skills-for-claude-code@claude-plugins-official`, [EpicGames/unreal-engine-skills-for-claude-code-plugin](https://github.com/EpicGames/unreal-engine-skills-for-claude-code-plugin): 1,961★, MIT, v3.1.2, pushed 2026-10-27, 14 open issues. It is an MCP driver for a live editor plus a SessionStart hook. Prose: `unreal@awesome-gamedev-agent-skills`, 6 skills, about 9.3k installs each | **None with Epic.** Its skills and hook have 0 hits for Zen, projectstore, BuildCookRun, Enhanced Input, mapping context, TStrongObjectPtr, FGCObject, deprecat or 5.8. **High with upstream**, which covers Zen/`ue.projectstore`, `LimitProcessLifetime`, `PawnClientRestart`, `TStrongObjectPtr`/`FGCObject`, Enhanced Input User Settings and the MSVC minimums | **The offline checker**, which nothing external has, and the table of setup traps for Epic's MCP (AllToolsets, no `.mcp.json`, one port per editor, no auth) | **KEEP, with a kill-trigger.** Add an Epic row to stack-scan official-complements. Run the Zen-cook control-arm eval the 10-31 review proposed. If its control arm passes and installs stay at 0 at the next review, retire and route to Epic's plugin + the upstream `unreal` bundle | **low**. The mechanism is real but nothing runs it unasked. No eval and no use |
| **phaser** 0.2.0 | 1 skill, 1 reference; `check_phaser_v4.py` (442 lines, 13 cases) with 3 rules (`Math.PI2`, `type: Phaser.CANVAS`, a drawn RenderTexture with no `render()`). **No hook** | 47,082 | 102 | 0 invocations, 0 agents, 1 install (R). Installs here: 1 (local) (V) | **Phaser's own 28 skills**, in [phaserjs/phaser](https://github.com/phaserjs/phaser) `skills/` and the npm package: 40,707★, MIT, repo pushed 2026-08-21, skills last committed 2026-06-03, about 1.1–1.4k skills.sh installs each. Install with `npx skills add phaserjs/phaser`, or point the agent at `node_modules/phaser/skills/`. Also `web-engines@awesome-gamedev-agent-skills` (`phaser-core`, about 10.2k installs) and the Phaser Editor v5 MCP (needs the desktop app running; price and licence are not stated on its docs page) | **Near-total.** The vendor `v3-to-v4-migration` skill carries every row of our v3→v4 table: TAU, PI2, setTintFill, BitmapMask, setLighting, roundPixels, Point, compressed textures re-made Y-up. `render-textures` covers `render()`/`setRenderMode`, and `physics-arcade` covers drag-only-at-zero-acceleration and the category helpers | Three footguns the vendor does not flag: `scene.launch` on a running scene restarts it (the vendor `scenes` skill says only that launch "does NOT stop current scene"), `onFloor()` on dynamic bodies (0 vendor hits), and the two-sided mask/group defaults (not confirmed absent). Plus a 3-rule checker whose rules the vendor's migration skill already states | **RETIRE.** Route through a new stack-scan framework-native row to Phaser's skills. Precondition, cheap: a 3-arm eval (base / vendor / ours) on the launch-restart and `onFloor` cases. If ours lifts, shrink to those footguns + the checker instead | **medium-low**. This follows the pixijs precedent (retired 2026-11-12, no lift on opus). Phaser itself has no eval |
| **gamedev** 0.3.1 | 7 skills; 4 scripts: `check_steam_build.py` (56 cases), `check_itch_html5.py` (12), `loudness_meter.py` (16, including EBU Tech 3341 cases), `asset_report.py` (5). No hook | 223,799 | **612**, the largest of the five | Invocations 0–4, transcript attribution **381**, the highest of the game plugins (R). Installs here: 3 (local) (V) | Upstream [gamedev-skills/awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills) `workflows` + `disciplines` bundles: `steam-publish` (+ its own `check_steam_build.py`, 996 lines), `itch-publish`, `dialogue-systems`, `procedural-gen`, `audio-design`, `game-ui-ux`, and `create-game-assets` (+ `asset_report.py`). Same stars, licence and push date as above | **High on prose.** Upstream has the 21-day wait, the Content Survey, SetLive, broth, `--hidden`, the itch HTML5 limits, Yarn 3 Dialogue Presenters, SplitMix/PCG32/PYTHONHASHSEED, ASWG −24/−18 LUFS and XAG. Its scripts are older copies of two of ours | `check_itch_html5.py` and `loudness_meter.py` (upstream has neither). `check_steam_build.py`'s `steam-appid-txt-shipped`/`appid-spacewar` checks (upstream: 0 hits). The `asset-pipeline` skill, which glues meshy → blender → unity-traps hooks. Skill-router rows | **KEEP, SHRINK.** Fold the prose-only `dialogue-scripting` and `seeded-generation` into references, or drop them (upstream covers both, and neither ships a mechanism). Keep `steam-release`, `itch-release`, `game-assets`, `asset-pipeline` and `game-platform-floors` (which drives the meter) | **medium**. No per-skill usage was read and no eval exists |

---

## 2. Evidence per plugin

### 2.1 unity-traps

- **V**: README, CHANGELOG, SKILL.md and hooks.json read in full. Reference sizes: 32,859 B over 7 files. `check_unity_project.py --help` lists errors `duplicate-guid, moved-without-meta, malformed-meta, missing-script, api-removed` and warnings `missing-meta, orphan-meta, meta-name-case, class-name-mismatch, api-deprecated`.
- **V**: `check_unity_project.test.sh` gives 41 tests OK. `scripts/smoke/game-checker-hooks-tests.sh` gives 51 passed, 0 failed (this covers the unity-traps, meshy, blender and pixel-art hooks).
- **V**: `rationale/evals/2026-11-02-075620-unity-traps.json` holds three cases. `dictionary-serialization-66` scored with [1,1,1,1,1] and without [0,0,0,0,0], Δ +1.00. `rigidbody-renames` scored 5/5 in both arms. `cinemachine-3` scored 4/5 with and 5/5 without. Cost was $2.54 on CLI 2.1.316. There is no vendor arm.
- **V**: the installed official plugin (`~/.claude/plugins/cache/unity-agent-plugin/unity/0.1.9-beta`) has 33 skills, no `hooks/` and a `LicenseRef-Unity-Companion-License` licence. A grep of its skills found:
  - 0 hits for `linearVelocity`, `EntityId`, `GetInstanceID`, `FindAnyObjectByType`, `SwitchActiveBuildTarget`, `Awaitable`, `persistentDataPath`, `AddForceAtPosition`, `Reload Domain` or `normalMapQuality`;
  - no 6.6 dictionary-serialization statement (the dictionary hits are JSON/UGS code);
  - hits for `2d.pixel-perfect` (`2d-pixel-perfect/SKILL.md:20` "Do not install `com.unity.2d.pixel-perfect` in a URP project."), Cinemachine 2 vs 3 (`craft-game-floors/references/camera-rigs.md:9-11`), `UxmlFactory` deprecated (`ui-uitk/references/custom-elements.md:18`), `NavMeshSurface`/`OffMeshLink` (`initialize-ai-navigation`) and `RecordRenderGraph` (`validate-urp-render-graph-renderer-feature`).
- **V**: the `unity` CLI is installed at `~/.local/bin/unity` and reports `1.0.0-beta.17`. `unity projects verify --help` says "Check a project for integrity problems that break a build, without launching the Editor". Its checks are `META_MISSING, META_ORPHAN, GUID_DUPLICATE, CONFLICT_MARKERS, MANIFEST_INVALID, EDITOR_VERSION_DRIFT`.
- **V**: Unity's `unity-cli/references/projects-templates.md:453-496` documents those codes, exit 6 on error, and `--format github`. `version-control.md` documents `unity vcs status` (flags "meta-file pairing problems") and `unity vcs hooks install` (git pre-commit integrity checks). 0.1.8-beta, the version unity-traps compared against on 11-02, already documented `projects verify` (7 hits).
- **V, finding**: the unity-traps README "covers" table says its offline `.meta`/GUID checker "needs no running Editor", which implies Unity's tooling does. `rationale/plugin-landscape-comparison-2026-10-31.md:139` says "every vendor tool needs a running Editor". Both are wrong against Unity CLI `projects verify`. The real differences are the in-session hook, the extra codes and the API scan, and no beta binary install (`curl … | bash`).
- **V**: GitHub API reports unity-agent-plugin at 636★, pushed 2026-11-12T21:44Z, 4 issues. Unity-Technologies/skills: 1,250★, pushed 2026-11-06. CoplayDev/unity-mcp: 15,948★, MIT, pushed 2026-10-30, 130 issues. The official directory `marketplace.json` lists `unity` at sha 81b6079.
- **R**: necessity review §2 gives attribution 256 and installs "2–3" for this group of plugins.

### 2.2 godot

- **V**: all 3 SKILL.md files read in full, plus `version-changes.md`, README, CHANGELOG and the hooks. Reference sizes: 13,731 B.
- **V**: `check_godot_project.test.sh` gives 44 OK. `godot-check-hook.test.sh` gives 26 passed.
- **V**: upstream `skills/godot/godot-nodes-scenes/scripts/check_godot_project.py` is 1,273 lines against our 1,221, with 74 changed lines in the diff. Upstream has no hooks file anywhere in its tree, and its `.claude-plugin/marketplace.json` names a `godot` plugin with 16 skills.
- **V**: a grep of upstream Godot skills:
  - hits for Jolt as the 4.6 default, `duplicate_deep`, `.uid`, `set_visibility_for`, `area_mask`, glow, TileMapLayer, Thread Support, COOP/COEP, encrypt and `@export_tool_button`;
  - 0 hits for typed-return override, `DEVICE_ID_MOUSE`/`device == 0`, `MeshInstance3D.skeleton`, `unique_id`, JSON floats, `VC_CHARS_AFTER_SHAPING` and `hit_from_inside`.
- **V**: skills.sh API puts upstream godot-* skills at about 11.0–11.6k installs each, and `wshobson/agents/godot-gdscript-patterns` at 18,415.
- **V**: GitHub API: Coding-Solo/godot-mcp 6,632★, MIT, pushed 2026-04-16; youichi-uda/godot-mcp-pro 642★, NOASSERTION; HaD0Yun/Doyunha-Gopeak 273★, MIT, pushed 2026-11-13; godotengine/godot-mcp returns 404.
- **R**: web search found no official Godot Foundation MCP or skill. godot-mcp-pro's full server is described as paid.
- **R**: necessity review: 0 / 0 / 0, with "opt-in, so zero is not evidence".

### 2.3 unreal

- **V**: SKILL.md, README and CHANGELOG read. References total 6,865 B. `check_unreal_project.py --help` read; its test harness gives 19 OK.
- **V**: Epic's repo tree is `skills/{unreal-mcp,create-toolset,unreal-skill}` + `hooks/unreal-context.sh` (SessionStart). `plugin.json` is v3.1.2, MIT, author at epicgames.com. A grep of all its skill and hook text gives 0 hits for `zen|projectstore|BuildCookRun|Enhanced Input|mapping context|TStrongObjectPtr|FGCObject|deprecat|5\.8`. Its README requires a running editor with the ModelContextProtocol + AllToolsets plugins enabled.
- **V**: the official directory lists `unreal-engine-skills-for-claude-code` at sha 0e27bde.
- **V**: upstream `unreal` skills hit `projectstore`, `LimitProcessLifetime`, `PawnClientRestart`, `TStrongObjectPtr|FGCObject`, `User Settings` and `MSVC`. There is no `scripts/` directory under `skills/unreal/`.
- **V**: chongdashu/unreal-mcp has 2,117★, no licence and a last push on 2025-04-22. flopperam/unreal-engine-mcp has 1,117★ and no licence; it is "now owned by Aura".
- **V**: `stack-scan/.../official-complements.md` has no Unreal, Unity, Godot or Phaser row.

### 2.4 phaser

- **V**: SKILL.md, README and CHANGELOG read. The test harness gives 13 OK.
- **V**: `phaserjs/phaser/skills` lists 28 folders, last commit 2026-06-03. Its README says "Point your AI coding agent at the `skills/` folder".
- **V**: a grep of the vendor skills:
  - `v3-to-v4-migration` hits TAU (6), setTintFill (3), PI2 (3), BitmapMask (4), setLighting (2), roundPixels (6) and the Y-up line ("must be re-compressed with the Y axis starting at the bottom");
  - `render-textures` has `render()` (23) and `setRenderMode` (4);
  - `physics-arcade` has `nextCategory|setCollidesWith` (12) and "drag (applied only when acceleration is zero)";
  - `scenes` line 170 reads "launch() -- starts another scene in parallel (does NOT stop current scene)", with no relaunch-restart warning;
  - `onFloor|blocked.down` has 0 hits.
- **V**: upstream `phaser-core` hits TAU, setTintFill, preFX/enableFilters, roundPixels, Geom.Point, setLighting and BitmapMask. It has no PI2 or `render()` hits.
- **V**: skills.sh: `phaserjs/phaser/*` at 1,136–1,410 installs; `awesome-gamedev/phaser-core` at 10,197.
- **V**: the Phaser Editor MCP docs page says the server connects to a running Phaser Editor v5 desktop app and is "still under development". The page states no price or licence and does not mention Claude Code.
- **R**: pixijs retirement, necessity review §5 and `official-complements.md:74`: "on opus its v7→v8 table showed no lift (4 cases, 3 runs per arm)".

### 2.5 gamedev

- **V**: all 7 SKILL.md files read in full, plus README and CHANGELOG. The 4 harnesses give 5 + 12 + 56 + 16 tests, all OK. `--help` read for all 4 scripts.
- **V**: upstream `check_steam_build.py` is 996 lines against our 970 (110 changed lines) and has 0 hits for `steam_appid`/`appid-spacewar`. Upstream `asset_report.py` is 140 lines against our 166. Upstream has no itch zip checker or loudness meter in its tree.
- **V**: upstream prose hits: `steam-publish` (21 days, Content Survey, steam_appid, SetLive, 480), `itch-publish` (broth, `--hidden`, the 1,000-file/500 MB limits), `dialogue-systems` (DialoguePresenter), `procedural-gen` (SplitMix/PCG32, PYTHONHASHSEED), `audio-design` (ASWG, −24/−18 LUFS) and `game-ui-ux` (XAG/26 px).
- **V**: our `dialogue-scripting` says "every rule below is agent-graded. No script in this plugin parses `.yarn` or `.ink`". `seeded-generation` ships only an example PRNG and pinned test, with no script.
- **R**: necessity review: transcript attribution 381; the 10-31 landscape review called gamedev's checkers "better here".

### Cross-cutting

- **V**: always-on cost from `scripts/context-budget-baseline.json` is 612 + 284 + 111 + 110 + 102 = **1,219 tokens** for the five. The dynamic baseline is 0 for all five.
- **V**: commit ce7c16f2 (2026-10-27) removed all ten game plugins ("always-on context 12,341 -> 10,711 tokens"). a37aa54d (2026-10-29) restored six of them. **No rationale file records why they were restored**; root CHANGELOG 0.125.0 records only what. Retirement since then: pixijs, 2026-11-12.
- **V**: upstream's marketplace names its plugins `gamedev`, `godot`, `unity`, `unreal` and `web-engines`. Three of those names equal ours (gamedev, godot, unreal).
- **R**: per `removed-plugins.tsv`, the `unity` → `unity-traps` rename was made so the two could load side by side.
- Not tested here: whether installing both `godot@cc-plugins-marketplace` and `godot@awesome-gamedev-agent-skills` collides in the same `godot:` namespace.

---

## 3. Dependency sweep (retire verdicts)

Method (**V**): `grep -rn -w <name>` outside `plugins/<name>/`, excluding `rationale/`, CHANGELOG history and `.git`. `scripts/remove-plugin.sh <name>` (dry-run) was **not** run: the auto-mode classifier denied it.

**phaser** (recommended retire): about 16 lines in 12 files outside the plugin, touching 5 plugins.
- `.claude-plugin/marketplace.json:188-189`, plus the gamedev description at :195.
- `README.md:582`, `:598`.
- `plugins/all-plugins/scripts/all-plugins.sh:128` (opt-in case list) and `all-plugins/README.md:11`.
- `plugins/skill-router/rules.tsv:330` (one content row).
- `plugins/stack-scan/.../signals.md:52`, `stack-relevance.md:37` and `catalog.md:30`. The catalog's gamedev line :23 is regenerated.
- `plugins/gamedev/.claude-plugin/plugin.json:4` and `README.md:10` (companion lists): gamedev needs a version bump and a CHANGELOG entry.
- `plugins/pixel-art/README.md:21`, which names `phaser` as an engine plugin. `check_tilemaps.py --engine phaser` uses the engine name and stays.
- `scripts/lane-vocabulary.txt:87`, `scripts/context-budget-baseline.json:25` and `scripts/context-budget-dynamic-baseline.json:25`.
- New pieces: a `removed-plugins.tsv` row plus a renames entry (remove-plugin.sh writes these), and a **new framework-native row** in `official-complements.md`.
- Version bumps: skill-router, stack-scan, all-plugins, gamedev and pixel-art, each with a CHANGELOG entry. That is the same shape as the pixijs removal (e3939dd3).

**unreal** (only if its kill-trigger fires): about 17 lines.
- `marketplace.json:183-184`, `README.md:597`.
- `all-plugins.sh:128` and its README:11.
- `rules.tsv:328-329`.
- stack-scan `signals.md:51`, `stack-relevance.md:36` and `catalog.md:46`. `scan.sh:120` and `scan.test.sh:117` are engine detection and stay.
- gamedev `README.md:9` and `plugin.json`.
- **blender `skills/blender-rig-anim/references/rigging.md:57`**, which says "Unreal IK Retargeter and root motion → `unreal`".
- `lane-vocabulary.txt:109` and the two baselines.
- The asset-forge and blender `rig_check.py` hits are engine names, not plugin references.

---

## 4. Not checked

- **No eval was run.** Every verdict rests on overlap by grep plus usage, not on a measured delta. In particular, I ran no vendor-arm eval: the unity dictionary delta was not checked against base + Unity's plugin, and the phaser 3-arm eval was not run.
- **No head-to-head run** of `unity projects verify` against `check_unity_project.py` on one broken fixture. The brief allowed only the report file as a write. To reproduce: build a fixture with a moved-without-meta, a duplicate GUID and a missing script, then run both tools.
- `scripts/remove-plugin.sh phaser` dry-run: denied by the auto-mode classifier. The sweep above is from grep.
- Per-skill usage (`scripts/turn-cost.sh --skills`) was not run, because it reads other projects' transcripts. The usage numbers are relayed from the 11-12 necessity review.
- Whether the upstream checker diffs (godot: 74 changed lines; steam: 110) are fixes we lack or edits we made. Only the line counts were compared.
- The co-install collision of same-named plugins across marketplaces (`godot`, `unreal`, `gamedev`) was not tested.
- Whether CoplayDev/unity-mcp, Coding-Solo/godot-mcp and the Phaser Editor MCP work with Claude Code today: READMEs and metadata only, nothing installed. Phaser Editor's price and licence are unknown (not on its docs page).
- Godot Foundation official tooling: absence is relayed from a web search, plus one 404 on `godotengine/godot-mcp`. Not exhaustive.
- Upstream `awesome-gamedev-agent-skills` content was compared by grep for our trap keywords, not read in full. It is 79 skills; its Unity skills are pinned to 6.3 LTS.
- Donchitos/Claude-Code-Game-Studios (38,855★, MIT, pushed 2026-11-09) was read only to the README head. It is a clone-the-repo project template whose engine route its own README calls "Not yet shown", so it is not treated as a plugin alternative.
- Unrelated, seen on this machine: Unity's plugin is installed twice, as `unity@unity-agent-plugin` (local) and `unity@claude-plugins-official` (user). This was not investigated.
