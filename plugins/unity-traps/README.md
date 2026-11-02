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
| The checker's verdicts and exit codes | **gate** for the script itself: `scripts/__tests__/check_unity_project.test.sh` runs 32 cases in CI. |
| The checker runs after a move | **gate** where the hook fires. `hooks/meta-check.sh` runs it after a Bash call whose `mv`, `cp`, `rm`, `rsync`, `ln`, `git mv`/`git rm`, `find -delete` or Python/Node/.NET move names an `Assets/` path, and after a Write/Edit of an `Assets/*.meta`. It adds errors anywhere and warnings on the touched paths, each once per context, and never blocks. Its firing and silence are pinned in CI by `scripts/smoke/game-checker-hooks-tests.sh`. A move it cannot see (a path in a variable, the Editor, an IDE) still needs a manual run: **recorded**. |
| Every fact in the references | **recorded**. Each reference names which of its items were re-read against Unity's docs on its stamp date and which are carried from the upstream source unread. |
| Version-matching advice to `ProjectVersion.txt` and the package lock | **agent-graded** |

Residual: `Library/` is gitignored. On a fresh clone or a CI runner where Unity has not opened
the project yet, the checker cannot read package script GUIDs, so a missing-script reference
is reported as a warning, not an error. Exit 0 on such a checkout does not prove there are no
missing scripts. It also skips binary-serialized assets and DLL-hosted scripts.

Measured on 2026-11-02, with a control arm (`evals/`, 5 runs per arm, CLI 2.1.316, haiku judge;
`rationale/gamedev-evals-2026-11-02.md`):

| case | with | without | reading |
|---|---|---|---|
| `dictionary-serialization-66` | 5/5 | 0/5 | **+1.00**: without the plugin every run built the pre-6.6 wrapper |
| `rigidbody-renames` | 5/5 | 5/5 | regression guard: the base model already writes `linearVelocity` |
| `cinemachine-3` | 4/5 | 5/5 | −0.20 is one run in five, which five runs cannot tell from a flake; no measured effect |

The other references are unmeasured.

## Driving the Editor (not shipped here)

This plugin ships no MCP server and no `.mcp.json`. Everything in this section was read on
2026-11-02 from Unity's docs and from Unity's plugin at commit `759ad5f` (0.1.8-beta).

**Primary path: the Unity CLI, through Unity's plugin.** Unity's plugin "only ships skills and
doesn't use a Model Context Protocol (MCP) server. Skills that control the Unity Editor run Unity
CLI commands"
([Unity's plugin for Claude Code](https://docs.unity.com/en-us/ai/unity-plugin/claude-code.md)).
The CLI is a standalone binary, `unity`, still in beta (`unity --version` prints
`1.0.0-beta.N`). It drives an open Editor through the `com.unity.pipeline` package, over a server
that accepts localhost connections only:

```bash
curl -fsSL https://unity.com/install.sh | bash   # Windows: irm https://unity.com/install.ps1 | iex
                                                 # or: brew install --cask unity-cli / winget install Unity.CLI
unity pipeline install                           # once per project: adds the Pipeline package
unity status                                     # with the Editor open: lists each Editor the CLI can reach
```

Driving a running Editor needs Unity 6.0 LTS or later. The CLI's other commands work with any
Editor version: installing Editors, headless builds and test runs
([install](https://docs.unity.com/en-us/unity-cli/use-unity-cli.md),
[capabilities](https://docs.unity.com/en-us/unity-cli/replace-mcp-server-unity-cli.md)).

**Deprecated: the MCP server in `com.unity.ai.assistant`.** "Unity has deprecated the MCP server
component of the in-editor AI assistant package." The package manual has said "Unity MCP server is
deprecated. Use the Unity command-line interface (CLI) instead." since 2.18.0-pre.2 (2026-08-18),
and still says it in 2.19. The server still ships, so do not set it up for new work. An agent that
can only speak MCP should use the CLI's own MCP server, which is not deprecated:
`unity mcp configure claude`. When the agent can run shell commands, Unity recommends
`unity command` over MCP, which it calls "faster and use[s] fewer tokens"
([replacement page](https://docs.unity.com/en-us/unity-cli/replace-mcp-server-unity-cli.md),
[2.18 changelog](https://docs.unity3d.com/Packages/com.unity.ai.assistant@2.18/changelog/CHANGELOG.html)).

**Alternative: MCP for Unity** ([CoplayDev/unity-mcp](https://github.com/CoplayDev/unity-mcp),
MIT, v10.3.0 of 2026-10-04). Unity says third-party MCP packages are not affected by the
deprecation. Use this one when the project is older than Unity 6.0: it supports 2021.3 LTS
through 6.x. It is a Unity package plus a Python 3.10+ server run by
[`uv`](https://docs.astral.sh/uv/). To install it, add it from Unity → Package Manager → Add
package from git URL `https://github.com/CoplayDev/unity-mcp.git?path=/MCPForUnity#main`. Then run
Window → MCP for Unity → Configure All Detected Clients, which writes the client configuration.

Tested here on 2026-11-02: Unity's plugin and this one loaded together in one `claude -p` session
(CLI 2.1.316, both passed with `--plugin-dir`). It listed 33 `unity:` skills and
`unity-traps:unity-best-practices`. Not tested here: any Editor command, and either MCP server.
Standing: **recorded**. Nothing re-reads these pages, so treat the versions above as of that date.

Credit: Adapted from [gamedev-skills/awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills) @184b72b (Apache-2.0, © 2026 Abhishek Barali and contributors); prose distilled and rewritten here, scripts copied and modified (see NOTICE). The URP 2D
reference takes its topic list from [scenario-labs/skills](https://github.com/scenario-labs/skills)
@5d68b48 (MIT, © 2026 Scenario Inc.), `skills/game-engines/unity/scenario-unity-2d`. Each fact
was re-read against Unity's docs and rewritten. No text or code was copied.
