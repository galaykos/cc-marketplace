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

## plugins/godot/hooks/godot-check.sh

Added 2026-11-09 (godot 0.2.0, roadmap row GD3). Until then `check_godot_project.py` was **recorded** only: the README
and the `godot-project-check` skill said no hook ran it, so a broken `res://` path, uid or node path written by an
agent surfaced only when Godot failed to load the scene.

Design:

- **Trigger.** PostToolUse on Write, Edit and MultiEdit whose `tool_input.file_path` ends in `.tscn`, `.tres` or
  `.gd`. Bash is not matched: a shell move or rename is the case `godot-project-check` still asks the agent to run the
  checker for, and parsing shell commands is what made the unity-traps sibling's trigger long.
- **Which project.** Walk up from the edited file's folder, at most 32 folders, to the nearest `project.godot`. A
  nested project is therefore checked on its own, the way Godot treats it. A file in a hidden folder (`.godot/`
  among them) is skipped, because Godot and the checker skip it too.
- **What is said.** Errors anywhere in the project, because editing a scene can break another scene that instances
  it. Warnings only in the edited file. The edited file's findings come first, so the cap cannot hide them. At most
  `MAX_SHOWN=5` per edit. Every finding is recorded as said, including the ones only counted past the cap, so a
  later edit in the same context reports only what is new since the last run. The pointer line names the checker
  command for the full list. Key: `cksum` of `project|finding line`.
- **Untrusted text.** Checker messages quote values from project files. Control characters become spaces, so a node
  name holding `\n` cannot start a line of its own, and each message is capped at 300 characters and each fix line at
  220. That bounds both the context cost and the room a hostile scene has to carry a payload.
- **State.** `cc_plugin_state` (CLAUDE_PLUGIN_DATA, else `<repo>/.claude/godot/` with a `*` `.gitignore`), file
  `check-seen-<cksum of transcript_path // session_id>`, swept after 1440 minutes. Unwritable state means silence: a
  finding that cannot be recorded would repeat on every edit.
- **Cost.** The checker took 0.48 s, on three warm runs on 2026-11-09, on a synthetic project of 6,001 files and 24 MB:
  2,000 scenes of 31 nodes, 2,000 `.gd`, 2,000 `.tres`. The whole hook took 506–540 ms there. An edit of a non-Godot
  file exits in 7.1 ms median and 9.4 ms max over 20 runs. `CHECK_TIMEOUT=10` per run, and hooks.json allows 20 s. A
  killed run prints nothing, and PostToolUse cannot block.
- **Off switch.** `CC_GODOT_CHECK=off`, or the `cc_godot_check` option (default on). The variable wins.
- **Limits** (also in the header): an edit made by Bash or by the Godot editor, a file in a hidden folder, findings
  past the cap (counted once, never repeated), a run past the timeout, and anything the checker itself misses (paths
  built at runtime, compressed binary scenes, script logic).

Standing: the firing and silence cases are a **gate** in `plugins/godot/scripts/__tests__/godot-check-hook.test.sh`
(26 cases, run in CI). The payloads use the host's PostToolUse shape with a path-shaped `transcript_path`. No live
`claude` session was run for this hook, so host delivery of the context is **unverified** here.
