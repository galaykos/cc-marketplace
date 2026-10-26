# godot: the comment text moved out of the code (2026-10-26)

The text below was moved verbatim on 2026-10-26 from the file named in the `##` heading: it is the module docstring of the upstream script as copied from gamedev-skills/awesome-gamedev-agent-skills@184b72b (Apache-2.0; `plugins/godot/NOTICE`), with only the triple quotes removed. The file kept a 3-line header and a pointer by name, `# Why, limits, history: rationale/derivations/plugin-godot.md § <heading>`. Standing: `recorded` — no gate reads this file, and its claims stand as upstream wrote them on 2026-10-24.

## plugins/godot/scripts/check_godot_project.py

### Module docstring: what it checks, what it skips, exit codes

```text
Check a Godot 4.x project for broken file references. Read-only.

Run it after creating, moving or renaming scenes, resources or scripts. It
reads the project's text files and reports references that Godot will fail
to load. It never edits anything and needs no Godot binary.

What it checks:

* ``[ext_resource]`` entries in ``.tscn``/``.tres`` files. Godot loads the
  ``uid`` first and falls back to ``path`` when the uid is unknown, so:
  uid resolves -> OK (a stale or different ``path`` is only a warning);
  uid unknown and ``path`` missing -> error; ``path`` exists but the uid is
  unknown -> warning (Godot prints "invalid UID" and fixes it on save).
  Uids are read from text headers, ``.import``/``.uid`` files and
  uncompressed binary resources; compressed ``.scn``/``.res`` files hide
  theirs, so a uid that might belong to one is only a warning.
* ``res://`` paths whose letter case differs from the file on disk. This
  works in the editor on Windows and macOS but breaks on Linux and in
  exported ``.pck`` files, which are case-sensitive.
* ``ExtResource("id")`` / ``SubResource("id")`` uses with no matching
  declaration, sub-resources used before they are declared, malformed
  ``[ext_resource]`` headers and duplicate ids in one file.
* The same uid claimed by two files (``.tscn``/``.tres`` headers,
  ``.import`` files and ``.uid`` sidecar files).
* Scene trees: exactly one root node, every ``parent=`` path declared
  earlier in the scene, and every ``[connection]`` ``from``/``to`` node.
  Nodes inside instanced or inherited scenes are followed through their
  ``.tscn`` files; paths inside scenes that cannot be read (imported
  ``.glb``/``.blend`` models, binary ``.scn``) are skipped, not guessed.
  A stale path that Godot 4.6+ can recover through ``parent_id_path`` /
  ``from_uid_path`` / ``to_uid_path`` is a warning.
* ``project.godot``: ``application/run/main_scene`` (``res://`` or
  ``uid://``), ``[autoload]`` entries and other ``res://`` setting values.
* ``.gd`` scripts: string-literal paths in ``preload()``, ``load()``,
  ``change_scene_to_file()`` and ``extends "..."`` (warnings).
* ``.uid`` and ``.import`` files left behind after their source file was
  moved or deleted (warnings).

Folders Godot does not scan are skipped the same way: the project data
folder (``.godot/``), hidden files and folders, folders containing a
``.gdignore`` file and folders containing another ``project.godot``.
Addons are ordinary project files and are checked.

Exit codes: 0 no errors, 1 errors (or warnings with --strict),
2 usage problem or no project.godot found.
```
