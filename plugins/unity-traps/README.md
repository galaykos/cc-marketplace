# unity-traps

Unity 6 (6000.x) facts that a model gets wrong from memory, and one mechanism. The skill
carries only inverted answers and footguns: renamed APIs, a changed torque formula, Cinemachine 3's
new component types, Input System project-wide actions that enable every map, batch-mode build
traps and save-path limits. It also covers URP 2D and pixel art: URP's own Pixel Perfect Camera,
atlas settings that blur sprites, and 2D lights that ignore normal maps. The script catches the `.meta`/GUID damage an agent does when it
moves, renames or copies files under `Assets/` outside the Editor.

## Install

```bash
claude plugin install unity-traps@cc-plugins-marketplace
```

This plugin was named `unity` through 0.2.1; 0.3.0 is its first release as `unity-traps`. It was renamed so it can load beside Unity's own plugin,
which is also named `unity`. An install of `unity@cc-plugins-marketplace` migrates to `unity-traps`
through the marketplace's `renames` map.

Companions, neither installed for you:

- **Unity's official plugin** ([Unity-Technologies/unity-agent-plugin](https://github.com/Unity-Technologies/unity-agent-plugin),
  Unity Companion License, not MIT). Install it alongside; the two cover different ground:

  | | covers |
  |---|---|
  | `unity-traps` (this plugin) | the narrow set of Unity 6 answers a model gets wrong from memory, and the offline `.meta`/GUID checker, which needs no running Editor |
  | `unity` (Unity's) | breadth across the engine, and the Unity CLI for driving the Editor (see "Driving the Editor") |

  ```bash
  claude plugin marketplace add Unity-Technologies/unity-agent-plugin
  claude plugin install unity@unity-agent-plugin
  ```

  Both have a skill on pixel-perfect rendering and sprite atlases. Where they disagree, this plugin's
  `references/2d.md` names the Unity manual page it was checked against, so check that page.
- **gamedev** carries the engine-agnostic shipping and workflow material:
  `claude plugin install gamedev@cc-plugins-marketplace`.

## What ships

| Artifact | Reach for it when |
|---|---|
| `unity-best-practices` skill | The project has `ProjectSettings/ProjectVersion.txt` and you write or review C#, input, physics, camera, rendering or build code, or set up URP 2D and pixel art. Its body routes to seven references (physics + navigation + 2D colliders, input, scripting, builds + CI + save paths, camera + rendering, and URP 2D: the Pixel Perfect Camera, pixel-art import, Sprite Atlas V2, 2D lights and normal maps, Tilemap Renderer modes, Cinemachine's pixel-perfect extension, `Rigidbody2D` renames). The seventh holds what Unity 6.4 to 6.6 inverted, for projects on 6000.4 or later: URP passes without `RecordRenderGraph`, `GetInstanceID` → `EntityId`, the deprecated finders, dictionary serialization, `DEVELOPMENT_BUILD`, UXML Factory/Traits, Cinemachine 3 as a core package. Each reference is read only when the change touches it. |
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

## Driving the Editor (not shipped here)

This plugin ships no MCP server and no `.mcp.json`. Two third-party options exist. Both were
read on 2026-10-30, and neither was installed or tested here:

- **MCP for Unity** ([CoplayDev/unity-mcp](https://github.com/CoplayDev/unity-mcp), MIT). It is
  a Unity package plus a Python server that runs under [`uv`](https://docs.astral.sh/uv/)
  (Python 3.10+). Install it from Unity → Package Manager → Add package from git URL
  `https://github.com/CoplayDev/unity-mcp.git?path=/MCPForUnity#main`, then run
  Window → MCP for Unity → Configure All Detected Clients, which writes the client configuration
  itself.
- **Unity's own agent plugin**, the companion above. Its plugin is named `unity`, which is why this
  one is `unity-traps`.

Credit: Adapted from [gamedev-skills/awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills) @184b72b (Apache-2.0, © 2026 Abhishek Barali and contributors); prose distilled and rewritten here, scripts copied and modified (see NOTICE). The URP 2D
reference takes its topic list from [scenario-labs/skills](https://github.com/scenario-labs/skills)
@5d68b48 (MIT, © 2026 Scenario Inc.), `skills/game-engines/unity/scenario-unity-2d`. Each fact
was re-read against Unity's docs and rewritten. No text or code was copied.
