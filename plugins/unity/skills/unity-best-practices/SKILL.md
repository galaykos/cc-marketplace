---
name: unity-best-practices
description: Use when writing or reviewing Unity C# in a project with `ProjectSettings/ProjectVersion.txt` — Unity 6 renames (`linearVelocity`, `FindObjectsByType`, Cinemachine 3 `CinemachineCamera`), Input System project-wide actions, `Awaitable`, build profiles and `-batchmode` CI builds, NavMeshSurface, blurry pixel art, Pixel Perfect Camera, 2D lights — or after moving, renaming or deleting files under `Assets/` (`.meta`, GUID, "Missing script").
---

> Last verified: 2026-10-26 — https://docs.unity3d.com/6000.3/Documentation/Manual/UpgradeGuideUnity6.html
<!-- version-tail-ok: the Unity Editor ships through Unity Hub, not npm/composer/pypi; the stamp points at Unity's own Unity 6 upgrade guide -->

## Read the editor version first

- Read `m_EditorVersion` in `ProjectSettings/ProjectVersion.txt`, and package versions in
  `Packages/manifest.json` + `Packages/packages-lock.json`, before advising. `6000.x` is Unity 6.
  On 2026-10-31 Unity's release API listed 6000.6.7f1 as the recommended release, 6000.3 as the
  LTS (6000.0 the older one) and 6000.7 in beta. `2022.3` and older predate every Unity 6 item below.
- 7000.x is the Unity 7 alpha; nothing here was re-read against it.
- Keep advice to that version. Never mix snippets across editor majors or package majors:
  Cinemachine 2 vs 3, AI Navigation 1 vs 2, Input System before vs from 1.8.
- The generated `*.csproj` files are Editor output, not the version record.

## Moved, renamed or deleted a file under Assets/? Run the checker

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/check_unity_project.py" <project-dir>
```

- Move or rename an asset together with its `.meta` (`git mv Foo.cs Bar.cs` and
  `git mv Foo.cs.meta Bar.cs.meta`). A new `.meta` is a new GUID, and every scene, prefab and
  asset that referenced the old one shows "Missing script".
- Fix every `ERROR` (`duplicate-guid`, `moved-without-meta`, `malformed-meta`, `missing-script`)
  and re-run until it exits 0. A `missing-meta` warning on a brand-new file needs nothing: Unity
  writes the `.meta` on the next import.
- Exit 0 = no errors, 1 = errors (or, with `--strict`, any warning but `missing-meta`),
  2 = not inside a Unity project. `--json` prints one object for tooling.
- **Residual — read the warnings on a fresh clone.** `Library/` is gitignored, so until Unity
  has opened the project there is no `Library/PackageCache`. Package script GUIDs cannot be read
  then, and every `missing-script` finding drops to a WARNING whenever the manifest lists a
  registry package, which is nearly always. Exit 0 on such a checkout does not mean "no missing
  scripts". The checker also skips binary-serialized assets and DLL-hosted scripts, and it never
  replaces opening the project in Unity.

## Where the traps live

| Topic | What memory says, and is now wrong (Unity 6 unless marked) | Read |
|---|---|---|
| Physics, navigation, 2D colliders | `rb.velocity`/`drag`/`angularDrag`, `PhysicMaterial`; `AddForceAtPosition` torque under Acceleration/VelocityChange; the Navigation window's Bake tab; `OffMeshLink`; `usedByComposite` | `references/physics.md` |
| Input | the legacy Input Manager as a fine choice; PlayerInput enabling only its default map; keeping `StandaloneInputModule` | `references/input-system.md` |
| Scripting | `FindObjectOfType`; `async` work that stops with its GameObject; ScriptableObject `OnEnable` resets with Reload Domain off | `references/scripting-async.md` |
| Builds, CI, saves | `SwitchActiveBuildTarget` in `-batchmode`; the global scene list under Build Profiles; `Debug.LogError` failing a CI build; `persistentDataPath` on tvOS or after a product rename | `references/build-ci.md` |
| Camera, rendering | `CinemachineVirtualCamera` and the `Cinemachine` namespace; GPU Resident Drawer prerequisites; SRP Batcher compatibility | `references/render-camera.md` |
| URP 2D, pixel art | `com.unity.2d.pixel-perfect` in URP; zooming via `orthographicSize` under a Pixel Perfect Camera; a Point sprite blurred by its atlas; setting `Light2D.normalMapQuality` from code; Chunk tilemaps under the SRP Batcher; `Rigidbody2D.velocity` | `references/2d.md` |
| `m_EditorVersion` 6000.4 or later | a URP pass with only `Execute`; `GetInstanceID()` kept as an `int`; `FindFirstObjectByType`; a dictionary wrapper because "Unity cannot serialize dictionaries"; `#if DEVELOPMENT_BUILD`; `UxmlFactory`/`UxmlTraits`; Cinemachine 2 kept on 6.6 | `references/upgrades-6.4-6.6.md` |

Read only the row the change touches. On 6000.4 or later, also read the last row's file: where it
and a topic file disagree, it wins. Each file carries the remedy with the trap, and says which of
its items were re-read against Unity's docs on its stamp date.

## Rules, and who enforces each

| Rule | Standing |
|---|---|
| A file moved outside the Editor keeps its `.meta`; no GUID is duplicated | **recorded** — `check_unity_project.py` exits 1 on a violation, but no hook or CI step runs it; you must |
| Advice matches `ProjectVersion.txt` and the package lock | **agent-graded** |
| New code uses the Unity 6 names (`linearVelocity`, `FindAnyObjectByType`, `PhysicsMaterial`, `CinemachineCamera`; from 6000.5 `GetEntityId`) | **agent-graded** — most old names still compile with obsolete warnings, so a green build proves nothing |
| A failed CI build exits non-zero | **recorded** — only the build method's own throw or `EditorApplication.Exit(1)` makes it so |
| A URP project has no `com.unity.2d.pixel-perfect`; pixel-art sprites, their atlas and the Pixel Perfect Camera agree on PPU, Point filtering and no compression | **agent-graded** — no script reads `manifest.json`, import settings or atlas settings |

## Anti-patterns

- Writing a `.meta` by hand, or copying one from another asset (duplicate GUID).
- `rb.velocity = …` in new Unity 6 code because an older tutorial did it.
- Leaving every project-wide action map enabled, then guarding each gameplay handler with
  "if the menu is open".
- Calling `EditorUserBuildSettings.SwitchActiveBuildTarget` inside an `-executeMethod` build.
- Installing `com.unity.2d.pixel-perfect` in a URP project to "fix" blurry pixel art.
- Reading exit 0 from the checker on a fresh clone as "no missing scripts".
- A URP pass with only `Execute` on 6000.4 or later: it does not render.
