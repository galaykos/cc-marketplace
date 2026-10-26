# Camera and rendering: Cinemachine 3, GPU Resident Drawer, SRP Batcher

> Last verified: 2026-10-26 — https://docs.unity3d.com/Packages/com.unity.cinemachine@3.1/manual/whats-new.html

Read `com.unity.cinemachine` and the render pipeline package
(`com.unity.render-pipelines.universal` or `.high-definition`) from
`Packages/packages-lock.json` first. Everything in this file was re-read against Unity's docs on
the stamp date.

## Cinemachine 3 brings new component types, not renames

Cinemachine 3.x moves the namespace from `Cinemachine` to `Unity.Cinemachine`
(`Cinemachine.Editor` becomes `Unity.Cinemachine.Editor`; `Cinemachine.Utility` is folded into
`Unity.Cinemachine`). Its components are new types, not renamed ones. Code copied from a 2.x
tutorial compiles only against the deprecated 2.x classes that 3.x still carries, which Unity
says "might be removed in a future release".

| Cinemachine 2.x | Cinemachine 3.x |
|---|---|
| `CinemachineVirtualCamera`, `CinemachineFreeLook` | `CinemachineCamera` |
| `CinemachineTransposer` | `CinemachineFollow` |
| `CinemachineOrbitalTransposer` | `CinemachineOrbitalFollow` |
| `CinemachineFramingTransposer` | `CinemachinePositionComposer` |
| `CinemachineComposer` | `CinemachineRotationComposer` |
| `CinemachinePOV` | `CinemachinePanTilt` |
| `CinemachineCollider` | `CinemachineDeoccluder` |
| `CinemachineConfiner` | `CinemachineConfiner2D` / `CinemachineConfiner3D` |
| `Cinemachine3rdPersonFollow` | `CinemachineThirdPersonFollow` |
| `CinemachineTrackedDolly` | `CinemachineSplineDolly` |
| `CinemachineDollyCart` | `CinemachineSplineCart` |
| `CinemachinePath`, `CinemachineSmoothPath` | a Spline Container (Unity's Splines package) |
| `CinemachineBlendListCamera` | `CinemachineSequencerCamera` |

- In scripts, type camera references that may be 2.x or 3.x as `CinemachineVirtualCameraBase`.
- Convert content with the Cinemachine Upgrader, opened from a Virtual Camera or FreeLook
  inspector. Only its whole-project mode also updates prefabs, script references and animation
  references, and that mode has no undo. Commit before running it.
- Once migrated, add `CINEMACHINE_NO_CM2_SUPPORT` to Scripting Define Symbols. The deprecated
  2.x classes then disappear, and any straggler fails to compile.

## GPU Resident Drawer (URP) prerequisites

It draws through GPU instancing only when all of these hold. Miss one and objects are drawn
without it.

- The URP renderer's Rendering Path is Forward+.
- The graphics API supports compute shaders and is not OpenGL ES.
- Project Settings → Graphics → Shader Stripping → BatchRendererGroup Variants is Keep All.
- The URP asset has SRP Batcher enabled and GPU Resident Drawer set to Instanced Drawing.
- The GameObject has a Mesh Renderer; anything else falls back to drawing without GPU
  instancing.

## SRP Batcher compatibility

- A shader is SRP Batcher compatible only when it declares every material property in one
  constant buffer named `UnityPerMaterial` (`CBUFFER_START(UnityPerMaterial)` …
  `CBUFFER_END`), and every built-in engine property in one named `UnityPerDraw`.
- A renderer is batched only when it draws a mesh or skinned mesh (not a particle system) and
  uses no `MaterialPropertyBlock`.
