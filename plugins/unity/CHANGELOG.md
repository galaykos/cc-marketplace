# Changelog — unity

Consumer-facing changes only. Newest first.

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
