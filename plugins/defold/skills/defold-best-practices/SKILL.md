---
name: defold-best-practices
description: Use when a project has `game.project` or `.collection`, `.go`, `.script`, `.gui_script` or `.input_binding` files, or the work mentions Defold, `bob.jar`, `msg.post`, `factory.create`, a collection proxy, or a Bob or engine error — `can't be found`, `_generated_….factory`, `ERROR:SCRIPT:`, `ERROR:GAMEOBJECT:`, `already a socket with the same name`, `Failed to initialize Remotery`, `UnsupportedClassVersionError`.
---

> Last verified: 2026-10-26 — https://defold.com/manuals/bob/
<!-- version-tail-ok: Defold ships no npm, composer or pypi package; the stamp points at the Bob manual, and the current release is https://d.defold.com/stable/info.json -->

## Read the version first

`game.project` has no engine-version key. The version is whichever Defold editor or
`bob.jar` the project builds with: a CI file usually pins a release or its sha1, and
`java -jar bob.jar --version` prints version, sha1 and channel. A library declares
`[library] defold_min_version`. Keep that version, use a `bob.jar` that matches it, and do
not migrate unless asked. The examples here were built and run on 1.14.0.

## The loop, and who enforces each step

| Step | Command | Standing |
|---|---|---|
| 1. Check references after creating, moving or renaming any resource | `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/check_defold_project.py" <project-dir>` | **gate** — exits 1 on an error (`--strict`: on a warning too), 2 when there is no `game.project`; re-run until 0 |
| 2. Build | `java -jar bob.jar --root . --variant headless --archive resolve build` | **gate** — Bob exits 1; the useful line starts `ERROR` |
| 3. Smoke-run the build | the bootstrap, `timeout` and log grep in `references/build-and-run.md` | agent-graded — a pass is a printed marker plus no `^ERROR:` line, never the exit code |
| 4. Input, rendering, layout | the editor or a desktop bundle | unenforceable headless — the headless engine has no input devices and draws nothing; say what was not checked |

The checker needs Python 3.10+ and no Defold install. It reads text files only. It does
not compile Lua, see paths built at runtime, or check anything inside the
`/builtins/` tree. Bob 1.14.0 needs **OpenJDK 25**; on Java 21 it stops at once with
`UnsupportedClassVersionError … class file version 69.0`.

## Footguns — symptom, cause, fix

- **`the bootstrap.main_collection '/main/main.collectio' can't be found`** — the setting
  is missing its compiled suffix, and Bob stripped one letter. In `game.project`, paths
  name the COMPILED file: `/main/main.collectionc`, `/input/game.input_bindingc`. With the
  key absent, Defold looks for `/logic/main.collectionc` and `/input/game.input_bindingc`.
- **`ERROR: build/default/_generated_<hash>.factory:0: … the prototype '/main/x.go' can't be
  found`** — the generated name exists nowhere in the sources; an embedded component in some
  `.go` points at a missing file. Search the sources for the quoted path (written
  `\"/main/x.go\"` inside embedded `data:` strings), or run the checker, which names the
  `.go` and the line.
- **`module 'modules.util' not found` at runtime although Bob succeeded** — the `require`
  used slashes. Use the dotted path from the project root: `require "modules.util"` loads
  `/modules/util.lua`.
- **`already a socket with the same name`, and `proxy_loaded` never arrives** — two loaded
  worlds share a collection `name:` (often both `"main"` or `"default"`). The loaded
  collection's `name:` is its socket, so every proxied collection needs a unique one, and a
  smoke bootstrap's name must differ from the main collection's.
- **Input dead inside a proxy-loaded level** — the game object that holds the collection
  proxy never sent `acquire_input_focus`.
- **`fixed_update` never runs, or physics steps at the wrong rate** — set
  `[engine] fixed_update_frequency` above 0 (default 60) AND `[physics] use_fixed_timestep = 1`;
  the manual requires both.
- **A smoke run hangs, or "passes" with a Lua error** — a callback error prints
  `ERROR:SCRIPT: <file>:<line>: …` and the engine KEEPS RUNNING. Always run under
  `timeout` and judge by the log.
- **A second engine logs `ERROR:PROFILER: Failed to initialize Remotery`** — a debug or
  headless engine holds port 8001, a log-server port and Remotery on `ws://127.0.0.1:17815`.
  Run one engine per job, and wait for it to exit before starting the next.
- **`--bundle-output` refused with `Folder '…/build' … is reserved for Defold build system`**
  — bundle to a folder outside the project's `build/`.
- **`tostring(id)` prints `hash: [<unknown:…>]`** — release builds drop hash source
  strings. Compare hashes, never their text.
- **`pairs(self)` or `pprint(self)` shows nothing** — `self` in a script is userdata; store
  fields on it, but iterate a table you keep on it instead.

Version notes: `go.property` accepts strings since 1.13.2. `late_update` runs after every
`update` and before render.

## References

- `references/build-and-run.md` — getting `bob.jar` by version or sha1, the Bob
  commands, platforms and variants, `--settings` overlays, and the headless smoke test:
  three files, a `timeout` and a log grep, all run on 1.14.0.
- `references/file-formats.md` — minimal `game.project`, `.collection`, `.go` and
  `.input_binding` shapes that Bob 1.14.0 built. Copy these when writing editor files by
  hand, because the escaped embedded `data:` strings are where hand-written files break.

## Anti-patterns

- **Calling a build "tested".** Bob proves the resources compile, not that a script runs.
- **Trusting the engine's exit status.** A Lua error keeps the engine alive; only the
  timeout ends it.
- **Reorganizing the project.** Follow its folder layout, ids and message names; Defold
  addresses are paths, and a move breaks every reference to them — run the checker after.
