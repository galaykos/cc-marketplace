# Changelog — godot

Consumer-facing changes only. Newest first.

## 0.2.1 — 2026-11-14

- **`hooks/godot-check.sh` keeps its fallback state under `.cc-artifacts/`.** When the host passes no
  `CLAUDE_PLUGIN_DATA`, the hook's per-project state now goes to `.cc-artifacts/godot/`, not
  `.claude/godot/`: one folder a team can gitignore and leave out of a deploy, outside the
  `.claude/` path Claude Code protects. The state is a cache, so nothing is carried over from
  the old dir. Standing: gate for the path (`templates/blocks/plugin-state.md`, held byte-identical
  by `pc_shared_blocks`).

## 0.2.0 — 2026-11-09

- **The project checker now runs on its own after an edit.** A new PostToolUse hook, `hooks/godot-check.sh`, runs `check_godot_project.py --json` after a Write or Edit of a `.tscn`, `.tres` or `.gd`, on the project that holds the file (the nearest `project.godot` above it). It adds a short note with the new findings: errors anywhere in the project, warnings in the edited file, the edited file's first, at most 5 per edit, and each finding once per session or subagent. It never blocks, and it stays silent outside a Godot project and on a clean scene. It took 0.5 s on a 6,001-file project. Turn it off with `CC_GODOT_CHECK=off` or the new `cc_godot_check` option under `/config`.
- **Standing:** running the checker after a scene, resource or script edit is now a **gate where installed**. A move or rename from a shell is not an edit the hook sees, so a manual run after one is still **recorded**. A new harness, `scripts/__tests__/godot-check-hook.test.sh` (26 cases), pins when it fires and when it stays silent.

## 0.1.0 — 2026-10-26

- **New plugin: three Godot 4 skills and one checker.** `godot-best-practices` carries only the advice that inverted between Godot 4.3 and 4.7 — Jolt as the 3D default for new projects since 4.6, the 4.7 GDScript override and packed-array changes, flipped defaults (glow, `area_mask`, input device ids) — plus multiplayer, web-export, C# and data footguns, each re-read against the Godot 4.7 docs on 2026-10-26. `godot-headless-testing` gives a SceneTree test runner that fails CI on a failing check, a runtime error or a hang. `godot-project-check` runs `scripts/check_godot_project.py`, a read-only, standard-library checker for broken `res://` paths, uids, resource ids and scene references (exit 0/1/2), with 44 end-to-end tests.
- **Standing:** the checker's exit code is mechanical once someone runs it; nothing runs it on an edit. Every other rule is recorded. Unmeasured: no control-arm eval covers any skill here.
- **Credit.** Adapted from gamedev-skills/awesome-gamedev-agent-skills @184b72b (Apache-2.0); prose distilled and rewritten, the checker and its tests copied and modified (see `NOTICE`).
