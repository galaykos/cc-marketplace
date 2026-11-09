# Changelog — unity-traps

Consumer-facing changes only. Newest first.

## 0.6.0 — 2026-11-09

- **The checker flags C# names your versions deprecated or removed.** `check_unity_project.py` reads the Unity version from `ProjectSettings/ProjectVersion.txt` and the Cinemachine version from `Packages/manifest.json`. For a git, local or embedded Cinemachine it reads the package's own `package.json` (in `Library/PackageCache` or `Packages/`), so a git Cinemachine gets no finding until Unity has filled `Library/PackageCache`. `packages-lock.json` is read only for a Cinemachine pulled in by another package. It reports only names in that version's window:
  - `GetInstanceID()` is deprecated in 6000.4 and removed in 6000.5. `Resources`/`EditorUtility.InstanceIDToObject`, `Selection.activeInstanceID` and `Selection.instanceIDs` are deprecated in 6000.3 and removed in 6000.5. Use the `EntityId` members.
  - UXML `UxmlFactory`/`UxmlTraits` are deprecated in 6000.0 and removed in 6000.6. Use `[UxmlElement]`/`[UxmlAttribute]`.
  - On Cinemachine 3.x, the `Cinemachine` namespace, `CinemachineBlendListCamera` and `CinemachineCore.Instance` are removed. Sixteen 2.x component names, such as `CinemachineVirtualCamera`, are deprecated.

  A removed name is an error (`api-removed`, exit 1). A deprecated name is a warning (`api-deprecated`), which fails `--strict`. The checker skips names in comments, in strings, in a method declaration and inside `#if UNITY_…`/`CINEMACHINE` version guards. Each window was read from Unity's docs on 2026-11-09. `Cinemachine3rdPersonAim` is left out, because its 3.x status could not be confirmed.
- **The meta-check hook ignores these findings.** They are not move damage, so it still reports only `.meta` and GUID problems after a move.
- **Standing:** gate where the checker runs. Nine new harness cases cover both sides of each window, the git, embedded, local and lock-file version sources, and the silent comment, string, guard and declaration cases. Whether Unity's compiler agrees is unverified, because no Editor runs in the tests.

## 0.5.1 — 2026-11-02

- **Control-arm evals.** Three cases in `evals/`, run 5 times per arm on 2026-11-02:
  - `dictionary-serialization-66` scored 5/5 with the plugin and 0/5 without, **+1.00**;
  - `rigidbody-renames` scored 5/5 and 5/5, a regression guard;
  - `cinemachine-3` scored 4/5 and 5/5. That is one failure in five, which this run count cannot
    tell from a flake.

  Spend was $2.54. Results are in `rationale/gamedev-evals-2026-11-02.md` and
  `rationale/evals/2026-11-02-075620-unity-traps.json`. The README's "Measured" paragraph now
  shows the table.
- **Review fixes.**
  - The meta-check hook now also fires on a move made from a shell already inside `Assets/`,
    such as `mv Player.cs Hero.cs` in `Assets/Scripts`.
  - The skill's done-gate row says what clause 7 checks: that a capture and a console read ran
    in the turn. Whether the console was error-free is agent-graded.
  - "gate" rows now read "gate (warn-only hook)".

## 0.5.0 — 2026-11-02

- **Look before calling it done.** The skill has a new section for scene, prefab or gameplay work:
  - capture the camera or scene with
    `unity command capture game_view -- --source camera --save_path …` (or `capture scene_view`);
  - read the console with `unity command console get -- --tail 50 --level error`;
  - treat any error as not done.

  It uses `--source camera` on a locked machine, where a `screen` capture came back one colour
  with no error. With MCP for Unity, `manage_camera` screenshot and `read_console` do the same.
  With no route, say "not captured" and why. Sources: Unity's `unity-cli` skill
  (`references/playmode-verification-loop.md` at `759ad5f`) and the `com.unity.pipeline` 0.9
  capture manual, both read 2026-11-02.
- **Standing.** **gate** where candor 0.11.0 is installed and a route exists: its Stop-gate clause 7
  sends back the done claim. Elsewhere **agent-graded**. Not run here against a live Editor.

## 0.4.0 — 2026-11-02

- **The `.meta` checker runs on its own.** A new PostToolUse hook, `hooks/meta-check.sh`, runs
  `check_unity_project.py` when either happens:
  - a Bash call moves, copies or deletes an `Assets/` path: `mv`, `cp`, `rm`, `rsync`, `ln`,
    `git mv`/`git rm`, `find -delete`, or a Python, Node or .NET file call;
  - a Write/Edit writes an `Assets/*.meta`.

  It reports errors anywhere in the project, and warnings only on the paths the call touched. Each
  finding is reported once per context, as added context: it warns and never blocks. Off:
  `CC_UNITY_META_CHECK=off`, or the new `/config` switch.
- **Measured.** The checker ran in 0.74 s on a synthetic 40,201-file project. The hook's cheap exit
  on a Bash call that is not a move took 9 ms median and 10 ms max over 20 runs.
- **Standing.** Running the checker after a move moves from recorded to **gate** where the hook
  fires; `scripts/smoke/game-checker-hooks-tests.sh` pins when it fires and when it stays silent, in CI. A move the hook cannot see (a
  path in a variable, the Editor, an IDE) still needs a manual run.

## 0.3.1 — 2026-11-02

- **Driving the Editor: the Unity CLI first.** The README section now leads with the Unity CLI
  (`unity`, beta) used through Unity's plugin. Setup is `unity pipeline install` per project, then
  `unity status`, and driving a running Editor needs Unity 6.0 LTS or later. The section also says
  the MCP server in `com.unity.ai.assistant` is deprecated: the notice has been in the package
  manual since 2.18.0-pre.2 (2026-08-18), and `unity mcp configure` is the MCP route Unity still
  supports. CoplayDev's MCP for Unity (MIT, v10.3.0) is the alternative for projects older than
  Unity 6.0. Every fact was read on 2026-11-02 from Unity's docs, Unity's plugin at `759ad5f` and
  CoplayDev's repo. Standing: recorded.
- **Side-by-side load tested.** Unity's plugin (0.1.8-beta) and this one loaded together in one
  `claude -p` session on CLI 2.1.316, both passed with `--plugin-dir`. No Editor command was run.

## 0.3.0 — 2026-11-02

- **Renamed from `unity` to `unity-traps`.** Unity's official Claude Code plugin
  (Unity-Technologies/unity-agent-plugin) is also named `unity`, so the two could not be told apart
  in one install. The marketplace's `renames` map sends an existing `unity@cc-plugins-marketplace`
  install to `unity-traps`. The skill (`unity-traps:unity-best-practices`), the references and the
  checker are unchanged.
- **README.** It recommends installing Unity's plugin alongside, and says what each covers: this
  plugin carries the traps and the offline `.meta`/GUID checker; Unity's carries breadth and the Unity
  CLI. Standing: recorded. Whether the two load side by side in one session was not tested.

## 0.2.1 — 2026-10-31

- **Unity 6.4 to 6.6.** The skill was stamped against 6000.3. A seventh reference,
  `references/upgrades-6.4-6.6.md`, holds only the answers those releases made wrong. Each one says
  what memory writes, what happens now and what to write instead:
  - 6.4: URP passes need `RecordRenderGraph`, and `OnDisable` now reaches every descendant on `Destroy`;
  - 6.5: `GetInstanceID` gives way to the 8-byte `EntityId`, `FindFirstObjectByType` and `FindObjectsSortMode` are deprecated, `PhysicsCore2D` is the new name, the Editor log is per project, the Built-in RP is deprecated and a custom `RequestLightsDelegate` needs a π fix;
  - 6.6: `[SerializeField] Dictionary` serializes, Cinemachine 2 moves to 3 on open, `DEVELOPMENT_BUILD`/`UNITY_64` and the Development Build diagnostics change, UXML Factory/Traits and `SetRuntimeInputBackend` are gone, and dynamic batching is obsolete.
- **SKILL.md.** A router row sends a project on `m_EditorVersion` 6000.4 or later to that file,
  and the file wins where it disagrees with a topic file. The version lines name the release lines
  Unity's release API listed on 2026-10-31: 6000.6.7f1 recommended, 6000.3 LTS, 6000.7 beta,
  7000.x the Unity 7 alpha, against which nothing was re-read. The rules row names
  `FindAnyObjectByType`, not `FindFirstObjectByType`.
- **`render-camera.md`.** On 6.6 the package moves to Cinemachine 3 by itself, while the script
  fixes and the Upgrader stay manual. `scripting-async.md` points at the 6.5 finder deprecation.
- **Standing.** Every item was re-read on 2026-10-31 against Unity's upgrade guides and the pages
  each item names. They are recorded only. Unmeasured: no eval with a control arm covers them.

## 0.2.0 — 2026-10-30

- **URP 2D and pixel art.** A sixth reference, `references/2d.md`, covers:
  - URP's own Pixel Perfect Camera: never `com.unity.2d.pixel-perfect`, the obsolete boolean API, and why a zoom through `orthographicSize` is undone;
  - Filter Mode and Grid Snapping, and which of them blur, shimmer or smooth pixels;
  - pixel-art import: pixel pivots, Max Size downscaling, platform overrides;
  - Sprite Atlas V2: atlas filter and compression, Include in Build, a sprite packed into two atlases;
  - 2D lights: the Renderer 2D requirement, get-only `normalMapQuality`, secondary textures, light batching;
  - Tilemap Renderer: Chunk under the SRP Batcher;
  - Cinemachine 3: `CinemachinePixelPerfect`;
  - `Rigidbody2D` names in Unity 6.
- **Standing.** Every fact in the new reference was re-read on 2026-10-30 against Unity's docs,
  or Unity's URP source where marked. They are recorded only. A new rules row covers PPU,
  filtering and the pixel-perfect package; it is agent-graded, because no script reads import or
  atlas settings.
- **Skill trigger.** The description now names blurry pixel art, the Pixel Perfect Camera and 2D
  lights, and no longer names NavMeshLink.
- **README.** New install pointers for two Editor bridges, neither shipped nor tested here: MCP
  for Unity (MIT) and Unity's own agent plugin (Unity Companion License).
- **Credit and effect.** The topic list comes from scenario-labs/skills @5d68b48 (MIT). The prose
  is rewritten and no code was copied. Unmeasured: no eval with a control arm covers it.

## 0.1.0 — 2026-10-26

- **First release.** The `unity-best-practices` skill covers Unity 6 (6000.x). It has five
  references:
  - physics: the Rigidbody renames, the Unity 6 torque change for `AddForceAtPosition`/`AddExplosionForce`, collision-detection modes, NavMeshSurface/NavMeshLink, `compositeOperation`;
  - input: the legacy Input Manager's deprecation, project-wide actions enabling every map, `InputSystemUIInputModule`;
  - scripting: the finder renames, `Awaitable` cancellation and pooling, ScriptableObject state with Reload Domain off;
  - builds and CI: `-buildTarget` instead of `SwitchActiveBuildTarget`, Build Profile scene lists, CI exit codes, Addressables, `persistentDataPath` limits;
  - camera and rendering: Cinemachine 3 class names, GPU Resident Drawer prerequisites, SRP Batcher compatibility.
- **`scripts/check_unity_project.py`.** A read-only `.meta`/GUID checker, with its 32-case test
  suite run by `scripts/__tests__/check_unity_project.test.sh`.
- **Standing.** The checker's behaviour is gated by its tests. Running it on a project is
  recorded only. The facts are recorded, each reference saying which items were re-read on
  2026-10-26. Residual: on a checkout without `Library/`, missing-script findings are warnings
  only.
- **Credit and effect.** Adapted from gamedev-skills/awesome-gamedev-agent-skills @184b72b
  (Apache-2.0): prose rewritten, script and tests copied and modified (see NOTICE). Unmeasured:
  no eval with a control arm covers it.
