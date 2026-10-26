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

## Where the traps live

| Topic | What memory says, and is now wrong | Read |
|---|---|---|
| Packaging, cooking | cooked `.uasset`/`.uexp` files under `Saved/Cooked/<Platform>`; Zen Server as an opt-in; an older Visual Studio, MSVC or Xcode being enough for 5.8 | `references/packaging-cook.md` |
| Enhanced Input | adding the mapping context in the pawn's `BeginPlay`; editing the `IMC_` asset at runtime to rebind keys | `references/enhanced-input.md` |
| C++ and AI | automation tests needing the editor UI; UObjects held by raw pointers in plain C++ classes; per-AI state in Behavior Tree task members | `references/cpp-notes.md` |

Read only the row the change touches. Each file says which of its items were re-read against
Epic's docs on 2026-10-26 and which are carried from the upstream source.

## Rules, and who enforces each

| Rule | Standing |
|---|---|
| On 5.8, ship the staging directory's `.pak`/`.utoc`/`.ucas`, never `Saved/Cooked` | **recorded** |
| CI and team machines keep zenserver alive (`LimitProcessLifetime=false`) | **recorded** — nothing checks `DefaultEngine.ini` |
| Assets pass `-run=DataValidation` before a cook | **recorded** — runs only if your pipeline calls it |
| Advice matches `EngineAssociation` | **agent-graded** |
| A mapping context reaches remote clients and respawned pawns | **agent-graded** — only a multiplayer PIE session shows it |

## Anti-patterns

- Treating a `Saved/Cooked/<Platform>` that holds only `ue.projectstore` as a failed 5.8 cook.
- Adding the mapping context in a pawn's `BeginPlay` in a networked game.
- Rewriting the `IMC_` asset at runtime for a "rebind controls" menu.
- Keeping per-AI run state in a non-instanced Behavior Tree task's member variables.
- Adding a Behavior Tree next to existing StateTree assets without asking.
