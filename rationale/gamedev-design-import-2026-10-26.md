# Import of two external skill repositories — 2026-10-26

Sources, both cloned read-only to a scratch directory and never executed:

| Repo | Commit | Licence | Size |
|---|---|---|---|
| [elayadesign/ai-design-skills](https://github.com/elayadesign/ai-design-skills) | `a2735a3` | MIT, © 2026 Elaya | 2 skills, 944 lines |
| [gamedev-skills/awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills) | `184b72b` | Apache-2.0, © 2026 Abhishek Barali and contributors | 76 skills + a router, ~26k lines incl. references, 8 scripts, 8 test files |

The user asked to "import the stuff we don't have yet", import-or-migrate at discretion, and
added that the resulting plugins are installed per project. The rule applied is this repo's
own: `README.md`'s admission bar and `rationale/measured-zero-shapes.md`. Per-version idiom
maps, canonical-doctrine checklists, style catalogues and framework restatement measured zero
against a blind control and were removed before; the survivors are **inverted** facts (the
confident answer from training data is now wrong), non-obvious footguns, hard platform limits,
and mechanisms with exit codes. Every file of both repos was read in full — the game repo by
seven parallel readers, one per group, each told to verify its most load-bearing kept facts
against primary docs. Nothing here is measured against a control arm; every KEEP is by
inspection.

Game development was ruled out of scope by `marketplace-coverage-review-2026-08-02.md` (no
worker, reviewer, router row or suite). The user's request reverses that; the plugins below are
skill-only on purpose, with checker scripts where upstream shipped one, and no agents or hooks.

## ai-design-skills

| Skill | Verdict | Where | Why |
|---|---|---|---|
| `design-to-motion` | **migrated** | `design-kit:motion` + 3 references | Mechanism-shaped procedure a model does not produce from memory: Figma REST placement rules (`absoluteRenderBounds`, `use_absolute_bounds` returning null for zero-size strokes, instance children), deterministic fake-clock capture (whole-millisecond steps averaging 1000/60, seeking `document.getAnimations()`), PSNR-gated fidelity, seam/empty-beat/rest checks, `ffmpeg` palette recipes. Adapted to design-kit: workspace under `.design-kit/motion/`, frames in a dot directory the preview server neither lists nor watches, capture via `?capture&static=1` so the reload stream is not injected. |
| `landing-page-design` | **not imported** | — | Part A (intake, one offer/audience/action, page spine, CTA copy, FAQ, risk reversal) is the canonical-doctrine shape and is already carried, deeper, by craft-layer's `offer-contract.md` offer spine. Part B is a taste catalogue whose hard values contradict house doctrine: it mandates Geist and bans Inter (craft-layer's `sameness-fingerprint.md` names Geist as create-next-app's generator default, and craft-layer never names a vendor font); it bans background gradients and fixes six dark-mode hexes (ui-ux's `theming-system` never ships a colour); its B8 "write the copy, invent names and numbers" contradicts `content-source.md`'s visible `{{lorem}}` rule; its mandatory tagline-reveal section contradicts the copy rule the user asked for the same day (below). Two uncovered conversion facts — `noindex` ad-only or time-bound campaign pages, mirror the ad headline when traffic comes from ads — were judged too canonical to earn a craft-layer edit. |

## awesome-gamedev-agent-skills — one plugin per engine

Plugins are split by engine because they are installed per project: a Godot repo installs
`godot` (and optionally `gamedev`), never Unity's skills. `/all-plugins:install` and
`/stack-scan:suggest --full` both skip them unless the engine's manifest is present (the
all-plugins opt-in was the user's choice; the `--full` class rows follow from it).

| Group | Upstream skills | Result |
|---|---|---|
| Godot (16) | gdscript, nodes-scenes, signals-groups, 2d-movement, tilemap, physics, ui-control, animation, shaders, 3d-essentials, resources, audio, multiplayer, export, csharp, gdscript-headless-testing | `godot`: `godot-best-practices` (distilled + merged), `godot-headless-testing` (kept), `godot-project-check` (+ `check_godot_project.py`). CUT: 2d-movement, 3d-essentials, animation, ui-control (restatement or new features, not inversions). |
| Unity (8) | csharp-scripting, input-system, physics, animation, scriptableobjects, tilemap-2d, navmesh, build-pipeline | `unity`: `unity-best-practices` (+ `check_unity_project.py`). CUT: animation. Merged: scriptableobjects, tilemap-2d. |
| Unreal (6) | blueprints, cpp-gameplay, enhanced-input, behavior-trees, niagara, packaging | `unreal`: `unreal-best-practices`. CUT: blueprints, niagara. Strongest fact: UE 5.8 makes Zen the default cooked store. |
| Roblox (7) | luau, datastores, ui, networking, characters, physics, studio-workflow | `roblox`: one skill, three references. |
| Bevy, Defold | bevy-ecs, defold-core | `bevy`, `defold` (+ `check_defold_project.py`). |
| pygame, LÖVE | pygame-core, love2d-core | CUT — stable APIs, nothing inverted. |
| Ebitengine | ebitengine-game (15 references, Go starter, 3 scripts) | `ebitengine`: distilled skill + `check_ebitengine.py` with a new Draw/Update-body test. CUT: the starter and its scaffolder, the macOS packager, the doctrine references. |
| Web engines (6) | phaser-core, phaser-arcade-physics, pixijs-rendering, threejs-scene-setup, threejs-gltf-loading, threejs-materials-lighting | `phaser`, `pixijs`. three.js: no plugin — the facts craft-layer lacked were merged into `threejs-best-practices`, `compressed-gltf.md` and `webgl-effects`' `effect-pipeline.md`. |
| Router | router + engine-detection + routing-table | CUT as a skill (it routes to ~70 skills that do not exist here); its detection signals became plugin-scout rows, `--full` class rows and skill-router rows. |
| Disciplines (15) | ai-behavior-trees-utility-ai, audio-design, camera-systems, create-game-assets, dialogue-systems, game-ai, game-feel, game-ui-ux, input-systems, level-design, performance-optimization, physics-tuning, procedural-gen, save-systems, shader-programming | `gamedev`: `game-assets` (+ `asset_report.py`), `dialogue-scripting`, `seeded-generation`, `game-platform-floors`. Engine-specific facts routed into the engine plugins. CUT: game-ai, ai-behavior-trees, game-feel, level-design, camera-systems, performance-optimization (duplicates `resilience:performance-tuning`), physics-tuning, shader-programming. |
| Genres (9) | card-game, fps-shooter, platformer, puzzle, roguelike, rpg, survival-crafting, tower-defense, visual-novel | All CUT — canonical doctrine. Their engine facts (RichTextLabel shaping, `Array.shuffle` seed, `platform_on_leave`, ray query flags, Unity `Random.Range` bounds) were routed to the engine plugins. |
| Workflows (4) | game-jam, itch-publish, prototype-fast, steam-publish | `gamedev`: `steam-release` (+ `check_steam_build.py`), `itch-release` (game-jam's submission footgun merged in). CUT: prototype-fast. |

## Verified against primary sources (by the readers, 2026-10-26)

Phaser 4 migration and the 4.2.1 dist (preFX/postFX gone, `setTintFill` a console.error stub,
`TAU` = 2π, `roundPixels` false) · PixiJS v8 migration and events guides, 8.22.0 release ·
three.js migration guide and r186 loader sources · Godot 4.6 and 4.7 upgrade guides, Jolt
physics page, Resource, SceneTree, C# basics, the 4.4 UID article · Unity 6000.3 command-line
arguments, build profiles, Unity 6 upgrade guide, legacy Input Manager deprecation · UE 5.8
release notes and Zen cooked-output page · Bevy 0.18→0.19 and 0.19→0.20 migration guides ·
Roblox Server Authority docs and release post, DataStore limits, UnreliableRemoteEvent,
PhysicsService, UserInputService · Defold Bob manual · Ebitengine install and Steam pages,
pkg.go.dev for ebiten v2.10.5 (audio, text/v2, vector, wav), Go 1.24 release notes ·
Steamworks uploading, onboarding, releasing, builds, Content Survey, Steam Hardware compat,
Steam Cloud · itch.io HTML5 and butler pushing docs · Sony ASWG-R001 v1.10 · Xbox XAG 101 ·
Python `random` and .NET `System.Random` docs · Yarn Spinner presenter API.

One upstream claim was **refuted** and corrected on port: Roblox's `PhysicsService`
`RegisterCollisionGroup`/`CollisionGroupSetCollidable` are not deprecated (only `Create*`,
`SetPartCollisionGroup`, `GetCollisionGroupId` and siblings are). Dropped as unverifiable or
suspect: Steam's 3-day post-security-change delay, the macOS launch-architecture reason, UE 5.8
"Combo deprecated", the UE Blueprint local-name rule, the UE arm64 flag, the TObjectPtr GC
claim, Phaser "Canvas deprecated", a Vite ≤6.0.6 pin, per-event jam rules, volatile tool
version strings, and the per-plugin lists below.

### Dropped at port time, per plugin (could not be confirmed against a primary source that day)

| Plugin | Dropped |
|---|---|
| godot | `randi_range` inclusivity; `AStarGrid2D.set_point_solid` needing no `update()`; `set_bus_volume_linear`, the beat-clock formula, `AudioStreamInteractive` bpm on Ogg/MP3; `get_display_safe_area`; `set_process_input(false)` vs GUI input; every rebinding fact (`physical_keycode`, `keyboard_get_label_from_physical`, `device=-1`, `is_match`, `get_vector` deadzone); `str_to_var`/`ConfigFile`/`.tres` object loading; `use_custom_user_dir`; Web `user://` in IndexedDB; `solver_iterations`, `reset_physics_interpolation`, `continuous_cd`, `Camera2D.ignore_rotation`, `create_timer`'s 4th argument, `TIME_PROCESS` units; COLOR in spatial shaders; `scene_changed` version tags; `call_group` silence; export exit codes (replaced by "check the artifact exists"); where export credentials live; the 4.7 new-feature APIs |
| unity | the `Random`/`PerlinNoise`/`Unity.Mathematics.Random` items; CharacterController riders; every audio item; ProfilerRecorder "GPU Frame Time"; `tex2D` being Built-in only; "SRP Batcher overrides GPU instancing"; unverified package version pins; `Rigidbody2D.linearVelocity` |
| unreal | Combo trigger deprecation; Blueprint local-variable naming; the arm64 client flag; the TObjectPtr GC claim |
| roblox | the New Type Solver GA flags; `PlayerScriptsUseInputActionSystem`; Character Controller Library; the GuiService selection-group deprecation; `GetInsetArea`'s required argument; StyleSheet/StyleQuery; `MicroGamepad`; `UseWorkspaceCollisionGroups`; `BatchGetAsync`; `SetRateLimitForRequestType`; `KeyThrottled`; "start_stop_play is solo only"; Network Simulator; the UI style catalogue |
| bevy | the 2024–25 renames (`delta_secs`, bundles, `single()`, recursive despawn) as well known; `summary_tick`, `despawn_all` as new features |
| ebitengine | `FinalScreenDrawer` input conversion; go-steamworks loading at package init (replaced by the verified README sample); Android minimum API 21 (the page says SDK 16); the `KeyShift` just-pressed claim; `exp/textinput` Field→Composer; default final-screen filtering; Explorer console hiding; exe icons as window icons; audio loop seam blending |
| phaser, pixijs | Phaser "Canvas deprecated"; Arcade "max 32 categories"; `scene.run` restarting a running scene; HMR double-canvas advice; Pixi's Vite ≤6.0.6 pin; cancelling `rightdown`/`rightclick`; the v7 `Loader` row |
| gamedev | Steam's 3-day post-security-change delay and the macOS launch-architecture reason; build-account permission names; itch's "Most Recent once" and asset-page AI-disclosure claims; the wharf/latest update API and butler credential paths; `licenses_for_app`; which branch build review reads; the Steam Direct fee; per-event jam rules; Steam Input's emulated-Xbox glyph claim and face-button mapping; Yarn `<<detour>>`, its version-3 error string and undeclared-variable warning; Yarn/Ink package ids; an `ebur128` command line |

Each porter also kept a few upstream facts it could not re-read and labelled them unverified
in place (Godot's headless assert-hang behaviour, most multiplayer footguns, Defold's Bob and
headless-engine measurements, Ebitengine's ALSA error text and `exp/vmhost` API, Unreal's
`enhanced-input.md` and `cpp-notes.md`, Steam Cloud facts relayed from the disciplines reader).

## Licensing

Prose was distilled and rewritten, not copied; each plugin README credits the source. Scripts
and their tests were copied and modified: every plugin shipping one carries Apache-2.0
`LICENSE` and a `NOTICE` (upstream NOTICE + what changed), and each script names its origin in
its header. `design-kit:motion`'s references carry the MIT notice.

## What is not done

- No control-arm eval for any imported skill. Per `measured-zero-shapes.md`, each KEEP is a
  falsifiable prediction, not a measurement.
- No hook runs any checker; the skills tell the model when to run it.
- `stack-scan:installed-versions` was not taught engine version authorities
  (`project.godot` `config/features`, `ProjectVersion.txt`, `EngineAssociation`).
