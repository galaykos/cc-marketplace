# Game-dev plugins against what others built — 2026-11-13

Branch `review/overseer-necessity`. Report only: no plugin file was changed. The question: for each
game-dev plugin, should the marketplace keep it, or retire it and point users to a tool someone else
maintains? The bar is `README.md`'s opening paragraph: a rule the model gets wrong from memory, or a
mechanism prose cannot replace.

Two read-only agents did the research in parallel. Their full reports are beside this file:

- `engines.md` covers gamedev, godot, unreal, phaser and unity-traps.
- `assets.md` covers blender, meshy, asset-forge and pixel-art.

Each report tags every claim **verified** or **relayed** and ends with its own "Not checked" list.
**No eval was run by either.** Every verdict rests on overlap found by reading and grepping, plus
the usage counts of `rationale/marketplace-necessity-review-2026-11-12.md`, never on a measured
difference.

## Verdicts

| Plugin | Always-on tokens | Best external | What only ours does | Verdict | Confidence |
| --- | ---: | --- | --- | --- | --- |
| unity-traps | 111 | Unity's official `unity` plugin (33 skills, no hooks) + Unity CLI `projects verify` | in-session hook after a file move; checker codes the CLI lacks; the only measured gain of any game plugin (6.6 `[SerializeField] Dictionary`, 5/5 vs 0/5) | **keep**; correct the README's comparison | medium |
| godot | 284 | no vendor tool; upstream `awesome-gamedev-agent-skills` `godot` bundle (same checker, no hooks) | the PostToolUse hook; ~7 Godot 4.6/4.7 changes upstream lacks | **keep**; optionally fold `godot-project-check` into `godot-best-practices` | medium-low |
| unreal | 110 | Epic's official plugin (live-editor MCP driver, no overlap); upstream `unreal` bundle (same facts) | offline Zen/DDC + deprecated-API checker, which nothing runs unasked | **keep with a kill-trigger**: run the Zen-cook control-arm eval; control passes and installs stay 0 → retire to Epic + upstream | low |
| phaser | 102 | Phaser's own 28 skills (`phaserjs/phaser/skills`) | the `scene.launch`-restarts-a-running-scene and `onFloor()` traps | **retire**, after a 3-arm eval (base / vendor skills / ours) on those two traps; add a stack-scan framework-native row | medium-low |
| gamedev | 612 | upstream `workflows` + `disciplines` bundles (prose) | itch zip checker, loudness meter, Steam appid checks, `asset-pipeline` | **keep, shrink**: fold or drop prose-only `dialogue-scripting` and `seeded-generation` | medium |
| blender | 157 | EL4CTEO/blender-skills (scripts and prose; QA exits 0 on failure); ahujasid's Blender MCP (live control, no checker) | static removed-API checker on write; exporter-as-oracle clip audit; QA that exits non-zero | **keep**; add Blender 5.3 rules, run the 3 never-run evals | medium-high |
| meshy | 79 | Meshy's own MCP server 0.6.11 + `meshy-3d-agent` skill (lifecycle rules now in code) | GLB budget checker + hook on the vendor's own downloads; licence rule; engine hand-off rules | **shrink** to the checker, its hook, the licence rule and the hand-off rules; route the lifecycle to Meshy's tools | medium-high |
| asset-forge | 1,322 | elithril/blender-kiln (GLB/web, names no engine) | Unity/Unreal/Godot presets with a per-tier validator; snapshot write guard; review Stop gate | **keep on probation**: 0 installs, one 3-run lift. Kill-trigger: still unused by an agreed date → retire to kiln + EL4CTEO | low |
| pixel-art | 125 | Aseprite MCPs (draw/export); agent-sprite-forge (generate) | checks an existing sheet against its PNG and a Tiled/LDtk map against Phaser's skip rules | **keep**; optionally point the generated-art section at agent-sprite-forge | medium |

Net: no plugin is retired outright. One is retired after an eval (phaser), two shrink (meshy,
gamedev), two get a kill-trigger (unreal, asset-forge). Every keep rests on a mechanism the
external tools lack: a hook, or a checker with an exit code. None rests on prose.

## Re-checked by the orchestrator

Spot checks of the claims a verdict turns on, run in this session:

- `~/.local/bin/unity projects verify --help` prints "Check a project for integrity problems that
  break a build, without launching the Editor". The unity-traps README claims an Editor is
  needed, which is wrong.
- `rationale/evals/2026-11-02-075620-unity-traps.json` `dictionary-serialization-66`: with
  `[1,1,1,1,1]`, without `[0,0,0,0,0]`.
- Phaser's `skills/v3-to-v4-migration/SKILL.md` (GitHub API) has 19 lines naming PI2, TAU,
  setTintFill, BitmapMask or roundPixels.
- Phaser's `skills/scenes/SKILL.md:170` says only that `launch()` "does NOT stop current scene".
  It never says a relaunch restarts a running scene.
- asset-forge `README.md:9` says "Status: 0.6.0" while `plugin.json` is 0.7.0. `README.md:96`
  says "no Meshy bone map" while `presets/bonemaps/meshy_to_rigify.json` ships.
- The meshy skill names credits five times (e.g. `meshy-generation/SKILL.md:21`) but has no rule
  to confirm a cost before spending.
- After both agents finished, `git status` showed no change under `plugins/`.

## Cross-cutting findings

1. Commit `a37aa54d` (2026-10-29) restored six game plugins two days after `ce7c16f2` removed ten.
   No rationale file records why (engines.md § Cross-cutting).
2. `plugins/stack-scan/skills/plugin-scout/references/official-complements.md` has no row for
   Unity's, Epic's or Phaser's own tools, nor for the upstream bundle. Any retirement above
   needs one.
3. The upstream marketplace `awesome-gamedev-agent-skills` names plugins `godot`, `unreal` and
   `gamedev`, the same names as ours. A co-install may collide the way `unity` did before the
   `unity-traps` rename. Untested.
4. On this machine, outside the repo: two Meshy MCP servers are connected at user scope. One is
   pinned to 0.6.7 and one is unpinned (0.6.11), and both inject the workflow guide. Unity's
   plugin is installed twice (`unity-agent-plugin` local, `claude-plugins-official` user). This
   is user config, not a repo defect.
5. The meshy skill is stamped meshy-cli 0.7 while npm latest is 0.8.5; its exit codes are
   unchanged. Its line "the task object documents no face count" conflicts with the vendor
   server printing `face_count` (assets.md § meshy).

## Not checked

- No eval of any kind, and no vendor-arm comparison. The unity-traps +1.00 is against the base
  model, not base + Unity's plugin.
- No external plugin or MCP server was installed or run. The external always-on costs are
  estimates or unmeasured.
- External READMEs and skills were grepped for trap keywords, not read in full. Each report
  names what it read.
- The upstream checker diffs (godot: 74 changed lines; steam: 110) were not read for which side
  has the fixes.
- `scripts/remove-plugin.sh phaser` (dry-run) was denied by the permission check. The sweep was
  sized by grep: about 16 lines in 12 files.
- No Meshy MCP call (it costs credits); Meshy's Terms of Use were not re-read.
- Per-skill usage (`scripts/turn-cost.sh --skills`) was not run, because it reads other
  projects' transcripts.
