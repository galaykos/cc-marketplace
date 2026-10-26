# Changelog — unity

Consumer-facing changes only. Newest first.

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
