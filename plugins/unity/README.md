# unity

Unity 6 (6000.x) facts that a model gets wrong from memory, and one mechanism. The skill
carries only inverted answers and footguns: renamed APIs, a changed torque formula, Cinemachine 3's
new component types, Input System project-wide actions that enable every map, batch-mode build
traps and save-path limits. The script catches the `.meta`/GUID damage an agent does when it
moves, renames or copies files under `Assets/` outside the Editor.

## Install

```bash
claude plugin install unity@cc-plugins-marketplace
```

Companion: **gamedev** carries the engine-agnostic shipping and workflow material. Install it
alongside with `claude plugin install gamedev@cc-plugins-marketplace`; nothing installs it for you.

## What ships

| Artifact | Reach for it when |
|---|---|
| `unity-best-practices` skill | The project has `ProjectSettings/ProjectVersion.txt` and you write or review C#, input, physics, camera, rendering or build code. Its body routes to five references (physics + navigation + 2D, input, scripting, builds + CI + save paths, camera + rendering), each read only when the change touches it. |
| `scripts/check_unity_project.py` | You moved, renamed, copied or deleted anything under `Assets/` outside the Editor. Read-only, stdlib-only Python 3.10+. Exits 1 on duplicate or malformed GUIDs, assets moved without their `.meta`, and scene/prefab references to scripts no `.meta` provides. Warns on leftover `.meta` files, case mismatches and class/file name mismatches. `--json`, `--strict`, `--max-issues`. |

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/check_unity_project.py" path/to/Project --json
```

## What has teeth

| Rule | Standing |
|---|---|
| The checker's verdicts and exit codes | **gate** for the script itself: `scripts/__tests__/check_unity_project.test.sh` runs 32 cases in CI. Running the checker on your project is **recorded** only, because no hook or CI step runs it for you. |
| Every fact in the references | **recorded**. Each reference names which of its items were re-read against Unity's docs on its stamp date and which are carried from the upstream source unread. |
| Version-matching advice to `ProjectVersion.txt` and the package lock | **agent-graded** |

Residual: `Library/` is gitignored. On a fresh clone or a CI runner where Unity has not opened
the project yet, the checker cannot read package script GUIDs, so a missing-script reference
is reported as a warning, not an error. Exit 0 on such a checkout does not prove there are no
missing scripts. It also skips binary-serialized assets and DLL-hosted scripts.

Measured: nothing — no control-arm eval. Whether these facts change what the model writes is
unmeasured.

Credit: Adapted from [gamedev-skills/awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills) @184b72b (Apache-2.0, © 2026 Abhishek Barali and contributors); prose distilled and rewritten here, scripts copied and modified (see NOTICE).
