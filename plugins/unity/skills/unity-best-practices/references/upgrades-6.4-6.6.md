# Unity 6.4 to 6.6: what memory writes that is now wrong

> Last verified: 2026-10-31 — https://docs.unity.com/en-us/engine/6000.6/manual/upgrade-guides/upgrade-guide-unity66

Read `m_EditorVersion` in `ProjectSettings/ProjectVersion.txt` first. Each item holds from the
version in its heading onwards; below 6000.4 none of them applies. Every item was re-read on the
stamp date against Unity's upgrade guide for its version, plus the page named in the item. New
features without a wrong remembered answer are left out. 7000.x (the Unity 7 alpha) was not read.

Each item gives three things in order: what memory writes, what happens now, and what to write
instead.

## 6.4 (6000.4)

Source: https://docs.unity3d.com/6000.4/Documentation/Manual/UpgradeGuideUnity64.html

- **A custom URP pass needs `RecordRenderGraph`.** Memory overrides
  `Execute(ScriptableRenderContext, ref RenderingData)` on a `ScriptableRenderPass`, or says to turn
  on Compatibility Mode or add `URP_COMPATIBILITY_MODE`. 6.4 removed Compatibility Mode for custom
  passes and removed the define with it. A pass with `Execute` and no `RecordRenderGraph` does not
  render. Unity's 6.3 render-graph post says it logs only an obsolete warning, so the build stays
  green (https://discussions.unity.com/t/render-graph-updates-in-unity-6-3/1668122). Write
  `RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)`.
- **`Object.Destroy` now calls `OnDisable` on every descendant.** Before 6.4 it reached only the
  GameObject and its direct children, so code forwarded `OnDisable` deeper by hand. That forwarding
  now makes `OnDisable` run twice. Delete it: `Destroy` now matches `DestroyImmediate`.

## 6.5 (6000.5)

Source: https://docs.unity.com/en-us/engine/6000.5/manual/upgrade-guides/upgrade-guide-unity65

- **`GetInstanceID()` is removed, and IDs are 8-byte `EntityId`.** `int id = go.GetInstanceID();`
  is a compile error ("Removed. Use GetEntityId instead.",
  https://docs.unity.com/en-us/engine/6000.5/script-reference/unityengine/object/getinstanceid).
  Write `EntityId id = go.GetEntityId();` and keep the type `EntityId` everywhere, dictionary keys
  included. Never key on `EntityId.GetHashCode()`. Never pass the ID through an `int`: not through
  `EntityId.FromULong((ulong)someInt)`, not through `int.Parse` of a saved string, and not through
  an explicit-layout overlap. Each one drops half the ID, and the lookup fails with "Unexpected
  EntityId … version value". A string saved by `EntityId.ToString()` on 6.2 to 6.4 is 32-bit.
- **The finders that replaced `FindObjectOfType` are deprecated in turn.** `FindFirstObjectByType`
  and every `FindObjectsByType` overload that takes a `FindObjectsSortMode` are deprecated, because
  sorting by instance ID cannot survive `EntityId`. Write `FindAnyObjectByType<T>()` and
  `FindObjectsByType<T>()` or `FindObjectsByType<T>(FindObjectsInactive.Include)`. No overload
  sorts by ID any more
  (https://docs.unity.com/en-us/engine/6000.5/script-reference/unityengine/object/findobjectsbytype).
- **`LowLevelPhysics2D` is now `PhysicsCore2D`.** Write `using Unity.U2D.Physics;`, not
  `using UnityEngine.LowLevelPhysics2D;`. Opening the project migrates the files that already
  exist, but code written from memory afterwards is not migrated. Code that must also compile on
  6.3 or 6.4 picks the namespace under `#if UNITY_6000_5_OR_NEWER`.
- **The Editor log is per project.** CI that collects the global log finds no log from this run:
  `%LOCALAPPDATA%\Unity\Editor\Editor.log` on Windows, or `Library/Logs/Unity/Editor.log` or
  `.config/unity3d/Editor.log` under the home directory. The default is now
  `<Project>/Logs/Editor.log`. Pass `-logFile <path>` and collect that path. Inside Unity, read
  `Application.consoleLogPath`.
- **The Built-in Render Pipeline is deprecated.** Do not start a project on it. It keeps fixes
  through the 6.7 LTS lifecycle and will be made obsolete in a later release.
- **A custom `RequestLightsDelegate` must multiply punctual intensities by π.** The light baker's
  contract changed to undo punctual lights rendering π times too bright. If a delegate returns
  intensities unchanged, it bakes them wrong. For Directional, Point and Spot entries, multiply
  `color.intensity` and `indirectColor.intensity` by `Mathf.PI`. Engine-side intensities did not
  change, and only replaced baking code is affected.

## 6.6 (6000.6)

Source: the stamp URL above.

- **`[SerializeField] Dictionary<TKey, TValue>` serializes.** Memory says Unity cannot serialize
  a dictionary and builds a wrapper with parallel key and value lists. On 6.6,
  `[SerializeField] private Dictionary<string, int> counts = new();` serializes and gets an
  Inspector editor. The rules
  (https://docs.unity.com/en-us/engine/6000.6/manual/programming-environment/code-reload-serialization/script-serialization/dictionaries):
  - the declared type must be exactly `Dictionary<TKey, TValue>`;
  - a public field still needs `[SerializeField]`;
  - a list or array cannot be a key;
  - `List<Dictionary<…>>` needs a `[Serializable]` wrapper.

  Existing wrappers keep working, so leave them. To migrate one, add the new field beside the old
  one, copy the data over with an editor script, check the result, then delete the old field.
  Deleting the old field first loses its data.
- **Cinemachine 2 is replaced by Cinemachine 3 on open.** Cinemachine is now a core package, and
  a project on 2.x is moved to 3. `render-camera.md` says what is still done by hand.
- **`#if DEVELOPMENT_BUILD` and `#if UNITY_64` are deprecated.** They warn (UAC0009, UAC0008),
  they already fail a warnings-as-errors build, and they become compile errors in 6.8. Replace
  them:
  - checks and assertions: `UNITY_ENABLE_CHECKS`;
  - profiling and diagnostic logging, including inside `[Conditional(...)]`:
    `UNITY_INCLUDE_INSTRUMENTATION`;
  - code that must never reach a release player, such as logging a token: the runtime
    `if (Debug.isDebugBuild)`;
  - bitness: `IntPtr.Size == 8`.

  Code that also targets editors older than 6.6 gates with `UNITY_6000_6_OR_NEWER`.
- **Ticking Development Build no longer brings the diagnostics.** SRP debug overlays, the
  Rendering Debugger at runtime, render-graph validation and Entities Journaling now follow
  Project Settings → Player → Other Settings → Managed Code Variant, which defaults to Release.
  Set Checked, or Debug, for the platforms you test on. From a build script, call
  `PlayerSettings.SetManagedCodeVariant(namedBuildTarget, ManagedCodeVariant.Checked)`. That same
  call replaces the obsolete `BuildOptions.ForceEnableAssertions`.
- **UXML Factory/Traits is removed.** A nested `UxmlFactory<T, UxmlTraits>` class and
  `UxmlTraits` with `Uxml*AttributeDescription` fields no longer compile. Write
  `[UxmlElement] public partial class MyControl : VisualElement` with `[UxmlAttribute]` on each
  property, and mark the class `partial`. Rebuild any Asset Bundle that holds the UXML
  (https://docs.unity.com/en-us/engine/6000.6/manual/uitoolkits/uielements/uie-migration-guides/migrate-custom-control).
- **`UIToolkitInputConfiguration.SetRuntimeInputBackend` is a compile error.** Delete the call;
  nothing replaces it.
- **Dynamic batching is obsolete.** Do not enable it to cut draw calls. Unity's "Choose a method
  for optimizing draw calls" page lists the routes that remain.
