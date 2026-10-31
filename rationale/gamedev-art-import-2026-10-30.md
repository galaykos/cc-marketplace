# Game art and tooling import — 2026-10-30

**Standing: `recorded`.** A dated mapping; nothing reads it back. Companion to
`rationale/gamedev-design-import-2026-10-26.md`, whose method it repeats.

## What was asked

Search the web for Claude Code plugins covering game development, Unity, Blender, pixel art, 2D and 3D,
plus Meshy and Higgsfield, and learn from four named repositories (`Jeffallan/claude-skills`,
`majiayu000/claude-skill-registry`, `DavinciDreams/Agent-Team-Plugins`, `phuetz/code-buddy`); then
import into this marketplace.

Owner decisions, asked once after the research (2026-10-30):

| Question | Decision |
|---|---|
| Import mode | rewrite + credit: keep only what clears the README admission bar, copy MIT scripts with LICENSE/NOTICE |
| Scope | new `blender`, `meshy`, `pixel-art` plugins; a 2D reference in `unity` |
| Higgsfield | install pointer only (closed-source CLI, paid credits) |
| MCP servers | install lines in READMEs only, never a bundled `.mcp.json` |

## Method

Three read-only research agents (web search + `gh api`) produced ~65 candidates; the main thread re-checked
licence, stars, push date and archive flag of the 27 load-bearing rows through the GitHub API. Four porting
agents, one per target, each confined to its own plugin directory, read the upstream at a pinned commit in a
scratch directory (never executed from there), applied `rationale/measured-zero-shapes.md`, and verified every
kept fact against a primary source. The main thread was the only writer of shared files and re-verified the
claim each port leaned on hardest (below). Nothing is measured against a control arm; each KEEP is by inspection.

## Sources imported

| Repo | Commit | Licence | Landed in |
|---|---|---|---|
| [EL4CTEO/blender-skills](https://github.com/EL4CTEO/blender-skills) | `71d031d` | MIT | `blender` (skill facts; `blender_qa.py` derived from `qa_check.py` + `_bpyx.py` → LICENSE + NOTICE) |
| [ra100/blender-claude-plugin](https://github.com/ra100/blender-claude-plugin), [MartinRapcan/blender-claude-skill](https://github.com/MartinRapcan/blender-claude-skill), [AiverReaver/blender-unreal-pipeline-skill](https://github.com/AiverReaver/blender-unreal-pipeline-skill) | read at HEAD | MIT | `blender` (gotchas, Unreal FBX rules; ra100 cut whole) |
| [meshy-dev/meshy-3d-agent](https://github.com/meshy-dev/meshy-3d-agent), [meshy-cli](https://github.com/meshy-dev/meshy-cli), [meshy-mcp-server](https://github.com/meshy-dev/meshy-mcp-server) | `1acd965`, `80ac347`, `0f4c10a` | MIT | `meshy` (facts only, no code) |
| [0x0funky/agent-sprite-forge](https://github.com/0x0funky/agent-sprite-forge) | `5324342` | MIT | `pixel-art` finishing rules, Tiled/LDtk export checks |
| [Gamezxz/pixel-art-studio](https://github.com/Gamezxz/pixel-art-studio), [crsolver/claude-pxl](https://github.com/crsolver/claude-pxl), [melonjs/melonJS](https://github.com/melonjs/melonJS) | `f8c2466`, `21fee41`, `a672695` | MIT | `pixel-art` (one fact each from two; claude-pxl cut) |
| [diivi/aseprite-mcp](https://github.com/diivi/aseprite-mcp), [shpaker/tiled-mcp](https://github.com/shpaker/tiled-mcp), [gazure/ldtk-mcp](https://github.com/gazure/ldtk-mcp) | `a89b205`, `b88fab1`, `dfed01e` | MIT | `pixel-art` README install lines + two footguns labelled unverified |
| [scenario-labs/skills](https://github.com/scenario-labs/skills) | `5d68b48` | MIT | `unity` `references/2d.md` (Scenario-MCP dependence stripped) |

No upstream skill was taken whole, and only one script was derived (`blender_qa.py`). `check_bpy_scripts.py`,
`inspect_glb.py`, `check_sprite_sheet.py` and `check_tilemaps.py` are original code; their rule facts come from
the sources above and primary documentation.

## Per-plugin verdicts

| Plugin | Kept | Cut |
|---|---|---|
| `blender` | Blender 5.x calls that now raise or do nothing (checker rules, `api-5x.md`); `--python-exit-code` placement; `.blend` header version reading (5.x saves are zstd-compressed; header `BLENDER17-01v0502`); FBX unit-scale table and shape-key loss under Subdivision, measured at file level; Unreal `UCX_`, Unity URP channel packing, Godot import suffixes | rigging, facial, optimization, hard-surface, lookdev, retopo, scene setup, simulation, baking, time-of-day, recipes (doctrine, budgets, value tables); `export_asset.py`, `review_shots.py` and the AiverReaver FBX inspector (no pass/fail verdict, or out of scope) |
| `meshy` | create → 202, a 4xx means no task, no idempotency key, reconcile after timeout/5xx; ≥60 min wait from `created_at`, poll `Retry-After`; `FAILED` refunded, delete of `IN_PROGRESS` → 409; two kinds of 429; 3-day retention and signed-URL expiry; rigging limits (textured humanoid biped, ≤320,000 faces, +Z); meshopt input refused, Draco >100 MB refused; POST to `http://` 301 drops the body; Terms §3.2/§3.3/§2.5/§2.9 | CLI recipes and login procedure (Meshy's own plugin carries them); 3D printing and OpenClaw plugins; Unity/Unreal import tips (unverified); downgrade effects (source 404) |
| `pixel-art` | Aseprite `json-hash` default, option-before-file order, `frameTags` only with `--list-tags`, `--ignore-empty` dropping frames, duration units; Pillow `convert("P")` dithering defaults; Tiled four flag bits and `firstgid`, zstd as a compile-time option, chunks, tile-object anchors, TSX-relative image paths; Phaser 4.2.1 skipping compressed layers and external tilesets with a `console.warn`; LDtk `__` copies, layer and auto-tile order, `externalLevels` | animation planning, action recipes, LPC layout, pixel craft doctrine, engine export mapping (engine plugins' territory), GIF timing and `--frame-range` base (unverified) |
| `unity` | URP's own Pixel Perfect Camera vs the Built-in package; Retro AA vs Point; atlas filter/compression, Include in Build, a sprite in two atlases; Light2D `normalMapQuality` read-only, defaults on `AddComponent`; one Global light per blend style and layer; Tilemap Chunk mode vs SRP Batcher; `Rigidbody2D.linearVelocity` (dropped 2026-10-26 as unconfirmed; the 6000.3 page now lists it and not `velocity`) | atlas-cuts-textures-not-batches (only a video), the Cinemachine 3.1.7 pin (no primary source), controller feel, animation, camera juice, LowLevelPhysics2D and 6.4 features |

Per-fact sources are in each SKILL.md `Last verified` stamp and, for blender, in
`rationale/derivations/plugin-blender.md`.

## Re-verified by the main thread

| Claim | How |
|---|---|
| A raising `--python` script exits 0; `--python-exit-code 3` before `--python` exits 3; after it, 0 | ran on Blender 5.2.3 (the owner's install) |
| Meshy free-plan output is Meshy-owned under CC BY 4.0; Community posts CC0; API output deleted after 3 days | meshy.ai/terms-of-use §3.2, §3.3, §2.5 (last updated 2026-09-19) |
| Aseprite `--format json-hash` is the default | aseprite.org/docs/cli |
| Tiled flag bits `0x80000000`…`0x10000000` must be cleared; the first `firstgid` is 1 | doc.mapeditor.org global-tile-ids |
| `Rigidbody2D` 6000.3 lists `linearVelocity`/`linearDamping`/`angularDamping`, not `velocity`/`drag`/`isKinematic` | docs.unity.com 6000.3 script reference |
| `meshy-cli`, `@meshy-ai/cli` (0.7.3) and `@meshy-ai/meshy-mcp-server` (0.6.7) exist | registry.npmjs.org |
| The new Python parses at 3.12 syntax (CI's `ubuntu-latest`); `check_tilemaps.py` without `compression.zstd` warns "not decoded" and exits 0 | `ast.parse(feature_version=(3,12))`; a pre-3.14 copy run on a real zstd map |

## Not imported, and why

| Candidate | Reason |
|---|---|
| Unity's official plugin (`Unity-Technologies/unity-agent-plugin`) | Unity Companion License — install pointer in `unity`'s README; its plugin is also named `unity`, side-by-side load untested |
| Blender Lab's official MCP | GPL-3.0 — pointer only |
| `ahujasid/mcp-for-blender` | install line only; its terms send an anonymous usage record unless `DISABLE_TELEMETRY=true` |
| `jfikrat/higgsfield-mcp` | authenticates with session tokens lifted from a logged-in browser; named in no plugin |
| `gamedev-skills/awesome-gamedev-agent-skills` | already the upstream of `gamedev` and the engine plugins (2026-10-26) |
| `Donchitos/Claude-Code-Game-Studios`, `rondorkerin/gamestack`, `HermeticOrmus/claude-code-game-development` | process layers and game-design doctrine (shape 2), not inversions; bodies sampled, not read in full |
| Unity Editor bridges (`CoplayDev/unity-mcp` and others) | MCP servers — CoplayDev is an install pointer in `unity` |
| Scenario, Higgsfield and other paid generation services' skills | vendor-bound; Higgsfield is a pointer in `meshy` |
| NO LICENSE repos (e.g. `PlayableIntelligence/game-creator`, `Yuki001/game-dev-skills`, `ProfRino/Blender-MCP-Assembly-Skill`, `light-vp/pixelart-mcp`) | all rights reserved |
| Hunyuan3D-2 | Tencent Community License excludes the EU, UK and South Korea |

## The four named repositories

| Repo | Licence | Verdict | Worth borrowing (not done here) |
|---|---|---|---|
| `Jeffallan/claude-skills` | MIT | its `game-developer` skill is generic and stale (legacy `BindAxis`, `Input.GetAxis`) | a dist built with `git archive HEAD` so untracked files cannot ship; a CI check that fails on drifted stamped counts — the "numbers rot" problem `CLAUDE.md` solves by recount commands |
| `majiayu000/claude-skill-registry` | MIT for the pipeline, not for `skills/**` | a catalogue of 308,437 copies; copies are bare SKILL.md with no scripts, and 240,191 records say NOASSERTION, some wrongly | never import from a registry copy — go to the source repo at a pinned SHA, which is what this import did |
| `DavinciDreams/Agent-Team-Plugins` (now `MonumentalSystems/Atlas-Agent-Teams`) | MIT | hooks the host validator says are ignored at runtime; eight `.mcp.json` packages that 404 on npm; a CI glob typo that checks nothing | run the host validator and check every `.mcp.json` package exists — `official-validate.sh` already does the first |
| `phuetz/code-buddy` | BUSL-1.1 | no game content; licence forbids copying into an MIT plugin | a headless render wrapper that requires the output file to exist, not just exit 0 |

## What is not done

- No control-arm eval for any new skill.
- No hook runs a checker; each skill says when to run its script.
- CI has no Blender: `test_rules_in_blender.py` and the QA geometry cases skip there.
- No live Meshy call (costs credits), no real Aseprite/Tiled/LDtk binary, no Unity Editor run.
- Not ported: AiverReaver's FBX inspector, an `msy_` secret-scanning provider row (key length unverified).
