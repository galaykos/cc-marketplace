---
name: unreal-best-practices
description: Use when working in an Unreal Engine 5 project (`*.uproject`, `Source/**/*.Build.cs`, `Config/DefaultEngine.ini`) — packaging or cooking with `RunUAT BuildCookRun`, a `Saved/Cooked` folder holding only `ue.projectstore` (Zen Server), UE 5.8 Visual Studio/MSVC/Xcode minimums, an Enhanced Input mapping context that works offline but not on clients, player-mappable key rebinding, headless automation tests, or UObjects held from plain C++.
---

> Last verified: 2026-10-26 — https://dev.epicgames.com/documentation/en-us/unreal-engine/unreal-engine-5-8-release-notes
<!-- version-tail-ok: Unreal Engine ships through the Epic launcher and source on GitHub, not npm/composer/pypi; the stamp points at Epic's UE 5.8 release notes -->

## Read the engine version first

- Read `EngineAssociation` in `<Project>.uproject`. A launcher engine shows a version such as
  `"5.8"`. A GUID means a source build registered on this machine; read that engine's
  `Engine/Build/Build.version` for the version.
- Keep advice to that version. The Zen and SDK items below are 5.8 facts that were different
  in 5.5. Never mix in UE4 or pre-5.1 input snippets (Project Settings axis/action mappings).
- After editing `Config/*.ini` or `Source/`, run the checker. It reads the version itself and
  needs `--engine-version 5.8` only for a source build. Exit 0 clean, 1 errors, 2 no single
  `.uproject` or no readable version:

  ```bash
  python3 "${CLAUDE_PLUGIN_ROOT}/scripts/check_unreal_project.py" <project-dir> [--json] [--strict]
  ```

  It flags the Zen and DDC keys 5.8 renamed or wants on CI, and the C++ names Epic's release
  notes deprecate (warning) or remove (error) for that version. With `--json`, each finding
  carries its release-notes URL in `source`.

## Where the traps live

| Topic | What memory says, and is now wrong | Read |
|---|---|---|
| Packaging, cooking | cooked `.uasset`/`.uexp` files under `Saved/Cooked/<Platform>`; Zen Server as an opt-in; an older Visual Studio, MSVC or Xcode being enough for 5.8 | `references/packaging-cook.md` |
| Enhanced Input | adding the mapping context in the pawn's `BeginPlay`; editing the `IMC_` asset at runtime to rebind keys | `references/enhanced-input.md` |
| C++ and AI | automation tests needing the editor UI; UObjects held by raw pointers in plain C++ classes; per-AI state in Behavior Tree task members | `references/cpp-notes.md` |

Read only the row the change touches. Each file says which of its items were re-read against
Epic's docs on 2026-10-26 and which are carried from the upstream source.

## Epic's Claude Code plugin and the 5.8 editor MCP

Read from Epic's pages on 2026-11-09. Standing: **recorded**.

- Plugin: `/plugin install unreal-engine-skills-for-claude-code@claude-plugins-official`.
  It comes from Epic's repo `EpicGames/unreal-engine-skills-for-claude-code-plugin` (MIT, 3.1.2)
  and ships skills `unreal-mcp`, `create-toolset` and `unreal-skill`, plus a SessionStart hook.
  Epic's MCP page calls it "the unreal-mcp Claude Code plugin".
- MCP: the Experimental "Unreal MCP" editor plugin, id `ModelContextProtocol`, documented at
  `https://dev.epicgames.com/documentation/en-us/unreal-engine/unreal-mcp-in-unreal-editor`.

| Trap | What the docs say |
|---|---|
| Server starts, lists no tools | Enable `AllToolsets` as well as `ModelContextProtocol`; `AllToolsets` is off by default |
| Nothing listens | The server is off by default: `ModelContextProtocol.StartServer`, or `bAutoStartServer=True` under `[/Script/ModelContextProtocolEngine.ModelContextProtocolSettings]` in the per-user `Saved/Config/<Platform>Editor/EditorPerProjectUserSettings.ini` |
| Claude Code finds no server | Neither ships `.mcp.json`: run `ModelContextProtocol.GenerateClientConfig ClaudeCode`. A source build writes it at the workspace root beside `Engine/`, a launcher build beside the `.uproject`; start Claude Code there |
| Unreal tools missing from `tools/list` | Tool search is on: only `list_toolsets`, `describe_toolset`, `call_tool` are listed; the rest go through `call_tool` |
| Two editors, one port | Both default to `127.0.0.1:8000/mcp`; the second cannot bind and the client reaches the first. Give each workspace its own `ServerPortNumber` |
| A new C++ tool does not appear | A new `UFUNCTION` needs an editor restart; Live Coding does not add it. Then `ModelContextProtocol.RefreshTools` |
| Localhost treated as safe | HTTP/SSE only, no authentication: any process of the same user can connect. `execute_tool_script` runs arbitrary Python in the editor, so Epic advises against `--dangerously-skip-permissions` with it loaded |

## Rules, and who enforces each

| Rule | Standing |
|---|---|
| On 5.8, ship the staging directory's `.pak`/`.utoc`/`.ucas`, never `Saved/Cooked` | **recorded** |
| CI and team machines keep zenserver alive (`LimitProcessLifetime=false`) | **gate where run** — `check_unreal_project.py` warns `zen-process-lifetime` on 5.8; running it is **recorded** |
| No C++ name the release notes deprecate or remove for the project's version; no Zen/DDC key 5.8 renamed | **gate where run** — the same checker, 15 cited name rules; an alias or macro hides a name |
| Assets pass `-run=DataValidation` before a cook | **recorded** — runs only if your pipeline calls it |
| Advice matches `EngineAssociation` | **agent-graded** |
| A mapping context reaches remote clients and respawned pawns | **agent-graded** — only a multiplayer PIE session shows it |

## Anti-patterns

- Treating a `Saved/Cooked/<Platform>` that holds only `ue.projectstore` as a failed 5.8 cook.
- Adding the mapping context in a pawn's `BeginPlay` in a networked game.
- Rewriting the `IMC_` asset at runtime for a "rebind controls" menu.
- Keeping per-AI run state in a non-instanced Behavior Tree task's member variables.
- Adding a Behavior Tree next to existing StateTree assets without asking.
