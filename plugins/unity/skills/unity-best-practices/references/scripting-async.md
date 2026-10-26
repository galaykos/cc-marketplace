# Scripting: finders, Awaitable, domain reload, GUIDs — Unity 6

> Last verified: 2026-10-26 — https://docs.unity3d.com/6000.3/Documentation/Manual/UpgradeGuideUnity6.html

Re-read against Unity's docs on the stamp date: the finder renames. Carried from the upstream
source without a re-read: the `Awaitable` and domain-reload items.

## Finders

| Obsolete | Use instead | Note |
|---|---|---|
| `FindObjectOfType<T>()` | `FindFirstObjectByType<T>()` | the old behaviour: results sorted by instance ID, so slower |
| `FindObjectOfType<T>()` | `FindAnyObjectByType<T>()` | any match, faster; use it when you do not care which |
| `FindObjectsOfType<T>()` | `FindObjectsByType<T>(FindObjectsSortMode.None)` | pass `FindObjectsSortMode.InstanceID` only if order matters |

All of them scan the loaded scenes. Cache the result; never call one per frame.

## Awaitable (async/await) is not a coroutine

- An `async` method keeps running after its GameObject is disabled or destroyed. Pass
  `destroyCancellationToken` to each wait, e.g.
  `await Awaitable.WaitForSecondsAsync(0.5f, destroyCancellationToken)`, and catch
  `OperationCanceledException`.
- `Awaitable` instances are pooled: await each instance exactly once. To use a result twice,
  store the result, never the `Awaitable`.
- After `await Awaitable.BackgroundThreadAsync()`, Unity APIs are off-limits until
  `await Awaitable.MainThreadAsync()`.
- Background work does not stop when Play mode exits. Pass `Application.exitCancellationToken`.
- Return `async Awaitable` from methods you call yourself, so callers can await them. Keep
  `async void` for Unity messages such as `Start`.

## ScriptableObject state with Reload Domain off

With Enter Play Mode Options set to skip the domain reload, ScriptableObjects that are already
loaded are not re-created on Play. `OnEnable` does not run again, and `[NonSerialized]` runtime
fields keep the previous session's values. Reset them in one of two places:

- `EditorApplication.playModeStateChanged`, on `PlayModeStateChange.ExitingEditMode`, inside
  `#if UNITY_EDITOR`;
- a static method marked
  `[RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]`.

## Files and GUIDs

Unity references an asset by the GUID in its `.meta`, not by its path. Move, rename or delete
the `.meta` with its asset, and never write or copy one by hand. Then run the checker; the
SKILL's checker section has the command and the fresh-clone residual.
