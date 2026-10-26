# Changelog — godot

Consumer-facing changes only. Newest first.

## 0.1.0 — 2026-10-26

- **New plugin: three Godot 4 skills and one checker.** `godot-best-practices` carries only the advice that inverted between Godot 4.3 and 4.7 — Jolt as the 3D default for new projects since 4.6, the 4.7 GDScript override and packed-array changes, flipped defaults (glow, `area_mask`, input device ids) — plus multiplayer, web-export, C# and data footguns, each re-read against the Godot 4.7 docs on 2026-10-26. `godot-headless-testing` gives a SceneTree test runner that fails CI on a failing check, a runtime error or a hang. `godot-project-check` runs `scripts/check_godot_project.py`, a read-only, standard-library checker for broken `res://` paths, uids, resource ids and scene references (exit 0/1/2), with 44 end-to-end tests.
- **Standing:** the checker's exit code is mechanical once someone runs it; nothing runs it on an edit. Every other rule is recorded. Unmeasured: no control-arm eval covers any skill here.
- **Credit.** Adapted from gamedev-skills/awesome-gamedev-agent-skills @184b72b (Apache-2.0); prose distilled and rewritten, the checker and its tests copied and modified (see `NOTICE`).
