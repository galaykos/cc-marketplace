# defold: the comment text moved out of the code (2026-10-26)

The text below was moved verbatim on 2026-10-26 from the file named in the `##` heading. It is the module docstring of the upstream checker, gamedev-skills/awesome-gamedev-agent-skills@184b72b `skills/other-engines/defold-core/scripts/check_defold_project.py` (Apache-2.0, see `plugins/defold/NOTICE`), with only the enclosing triple quotes removed. The lines the file kept are not repeated here. A pointer by name was left in the file: `# Why, limits, history: rationale/derivations/plugin-defold.md § <heading>`. Standing: `recorded` — no gate reads this file. Its claims stand as they did in the upstream commit; they were not re-measured here, except that the shipped test suite exercises the behaviour it describes.

## plugins/defold/scripts/check_defold_project.py

### Header: what it checks, what it skips, exit codes

```text
Check a Defold project for broken resource references. Read-only.

Run it after creating, moving or renaming collections, game objects, scripts,
atlases or other resources. It reads the project's text files and reports
references that Bob (the Defold build tool) will fail to resolve. It never
edits anything and needs no Defold editor, Java or bob.jar.

What it checks:

* ``game.project``: ``bootstrap.main_collection`` and ``input.game_binding``
  must name an existing file and carry the compiled suffix (``.collectionc``,
  ``.input_bindingc``). When a key is absent, Defold's default
  (``/logic/main.collectionc``, ``/input/game.input_bindingc``) is checked
  instead. Other settings whose value is a root-absolute path, and the
  ``custom_resources``, ``bundle_resources`` and ``include_dirs`` lists, are
  checked as warnings.
* Every quoted root-absolute resource path (``"/main/player.go"``, also inside
  the escaped ``data:`` strings of embedded components) in collections, game
  objects, atlases, GUI scenes, tile sources and the other Defold text resource
  files. A string is treated as a path only when its last part has a file
  extension and it contains no ``#`` or ``:``, so game object ids and URLs
  are left alone.
* In ``.script``, ``.gui_script``, ``.render_script`` and ``.lua`` files:
  literal ``require "a.b"`` modules (``/a/b.lua``) and literal
  ``resource.*("/path")`` properties; ``sys.load_resource("/path")`` is a
  warning because it reads custom resources at run time. Comments are ignored.
* Paths whose letter case differs from the file on disk. This can work on
  Windows and macOS and break on Linux and in CI.

Bob only builds files reachable from ``game.project``, so a broken reference
in a file nothing uses is reported as a warning, not an error.

Paths under ``/builtins/`` are skipped. Paths provided by library
dependencies are checked against the archives Bob fetched into
``.internal/lib/``; when a dependency has not been fetched, an unresolved path
is only a warning. Skipped while scanning: the ``build/`` folder, hidden files
and folders (``.internal/``, ``.git/``, ``.editor_settings``) and anything
listed in ``.defignore``.

Exit codes: 0 no errors, 1 errors (or warnings with --strict),
2 usage problem or no game.project found.
```
