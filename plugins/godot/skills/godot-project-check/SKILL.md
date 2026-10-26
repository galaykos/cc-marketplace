---
name: godot-project-check
description: Use when Godot scenes, resources or scripts were created, moved or renamed, when `.tscn`/`.tres`/`project.godot` were edited by hand or by a script, or on `Failed loading resource`, `invalid UID`, a missing main scene or autoload, a node path that no longer resolves, or a `res://` path that works on Windows/macOS but breaks on Linux or in an export.
---

> Last verified: 2026-10-26 — https://docs.godotengine.org/en/stable/classes/class_scenetree.html
<!-- version-tail-ok: the stamp points at Godot's class reference; the engine ships as a binary with
     no npm/composer/pypi package, so check-doc-staleness --live has nothing to compare. -->

## Run the checker after every move, rename or hand edit

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/check_godot_project.py" <project-dir>          # text report
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/check_godot_project.py" <project-dir> --json   # one JSON object
```

- `<project-dir>` is the folder holding `project.godot`. Python 3.10+, standard library only,
  no Godot binary; it never writes.
- Exit **0** no errors · **1** errors (or warnings with `--strict`) · **2** not a Godot project
  or bad arguments. Fix every `ERROR` and re-run until it exits 0; each issue prints its fix.
- Read the engine minor from `project.godot` (`config/features`) first. The checker targets
  Godot 4.x text formats; on a 3.x project its findings mean nothing.

## What it catches, and what it does not

| Catches (deterministic, exit 1) | Warns only | Does not see |
|---|---|---|
| `[ext_resource]` whose uid is unknown and whose `path=` is missing | A stale `path=` Godot still finds by uid | Paths built at runtime (`load("res://lv_%d.tscn" % n)`) |
| A `res://` path whose letter case differs from disk — fine on Windows/macOS, broken on Linux and in exports | A uid that may sit inside a compressed `.scn`/`.res` it cannot read | Whether the scene behaves: it parses text, it does not run Godot |
| Undeclared or duplicate `ExtResource`/`SubResource` ids; a sub-resource used before it is declared | A literal `preload`/`load`/`change_scene_to_file` path in a `.gd` that does not exist | Nodes inside imported `.glb`/`.blend` or binary scenes |
| Two files claiming one uid | Orphaned `.uid`/`.import` files left after a move | Anything in folders Godot skips (`.gdignore`, hidden, nested projects) |
| A scene with no root or two roots; a `parent=` or `[connection]` path that resolves nowhere, followed through instanced and inherited scenes | A stale `parent=` that 4.6+ recovers through `parent_id_path` | Script logic, signal argument counts, typos in method names |
| A missing `run/main_scene` or autoload target | `run/main_scene` not set at all | |

Standing: the checks are a **gate** for whoever runs the script — exit 1 is mechanical. Running
it is **recorded** only: no hook in this plugin runs it on an edit, so a session that skips it
ships the break.

## Facts the checker cannot tell you

- **4.6 scene files carry node ids.** From 4.6 every `[node]` stores `unique_id=`, and scenes
  can carry `parent_id_path` / `from_uid_path` so a renamed node is found again. Re-saving a 4.5
  scene in 4.6 rewrites it — large diffs, expected. Convert a whole project at once with
  Project > Tools > Upgrade Project Files instead of letting diffs trickle in per scene.
- **Changing scene is two-phase.** `change_scene_to_file()` / `_packed()` / `_node()` remove
  the current scene from the tree IMMEDIATELY — its `get_tree()` and
  `get_tree().current_scene` are `null` from that line on — then free it at the end of the
  frame, and only then add the new scene. Code after the call must not touch the tree through
  the old scene. Act on the new scene from its own `_ready()`, or from an autoload with
  `await get_tree().scene_changed`.
- **`.uid` sidecars travel with their file.** A script or shader moved outside the editor
  without its `<file>.uid` breaks uid references (the checker reports the orphan); commit them.

## Anti-patterns

- **Rename in the file manager, trust the editor later** — moving `.tscn`/`.gd` files from a
  shell or an agent without moving `.uid`/`.import` siblings and re-running the checker.
- **Case drift** — `res://Player/Player.tscn` against `player/player.tscn` on disk; it passes
  on a Mac and fails on the Linux CI runner and in the exported `.pck`.
- **Touching the old scene after a change** — `get_tree().current_scene.foo()` on the line
  after `change_scene_to_file()`.
