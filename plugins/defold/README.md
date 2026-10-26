# defold

One skill and one script for Defold projects.

The script, `scripts/check_defold_project.py`, finds every resource reference Bob will
fail to resolve, without Java, `bob.jar` or the editor.

The skill holds the footguns that cost a build or hide a failure: Bob's misleading
errors, the JDK version, a headless engine that keeps running after a Lua error, proxy
socket clashes, port collisions between engines. It also has a smoke-test recipe that
judges a run by its log. Message passing, factories and the script lifecycle are left to
the Defold manual and the model's own knowledge.

## Install

```bash
claude plugin install defold@cc-plugins-marketplace
```

**Pairs with `gamedev`.** That plugin holds the engine-agnostic shipping and workflow
material; this one holds only Defold. Nothing installs the pair for you, because no
plugin here may declare `dependencies`.

## What it ships

| Artifact | Reach for it when |
|---|---|
| `defold-best-practices` (skill) | A project has `game.project`, or Bob or the engine prints `can't be found`, `_generated_….factory`, `ERROR:SCRIPT:`, `ERROR:GAMEOBJECT:` or `Failed to initialize Remotery`. `references/build-and-run.md` holds the Bob commands and the headless smoke test; `references/file-formats.md` holds the editor-file shapes Bob accepts |
| `scripts/check_defold_project.py` | After creating, moving or renaming a resource. Run `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/check_defold_project.py" <project-dir>` (`--json`, `--strict`, `--max-issues N`). It exits 0 when clean, 1 on errors, 2 when there is no `game.project` |

## What has teeth

| Rule | Standing |
|---|---|
| No broken resource reference reaches Bob | **gate** when the checker runs — it exits 1. Nothing runs it automatically: it fires when the skill's loop is followed or someone calls it. It does not compile Lua or see paths built at runtime |
| The checker keeps its contract | **gate** — `scripts/__tests__/check_defold_project.test.sh` runs 25 end-to-end cases in CI. They exercise the checker against its own fixtures, never against Bob |
| A smoke run is judged by the log (a printed marker and no `^ERROR:`), not the exit code | agent-graded |
| Input and rendering are checked in the editor or a desktop build, never headless | unenforceable headless — the headless engine has no input devices and draws nothing |
| Bob needs OpenJDK 25 (as of 1.14.0) | recorded — as of the skill's stamp |

Measured: nothing — no control-arm eval.

Credit: Adapted from [gamedev-skills/awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills) @184b72b (Apache-2.0, © 2026 Abhishek Barali and contributors); prose distilled and rewritten here, scripts copied and modified (see NOTICE).
