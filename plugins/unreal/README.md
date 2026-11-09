# unreal

Unreal Engine 5 facts that a model gets wrong from memory. Since UE 5.8, a successful cook
leaves `Saved/Cooked/<Platform>` holding only `ue.projectstore`, because Zen Server became the
default cooked output store. 5.8 also raised the toolchain minimums. The plugin adds the
Enhanced Input placement that breaks on network clients, the supported rebinding path, and a
few C++ and Behavior Tree notes. One script checks a project against the engine version in its
`.uproject`: the Zen and DDC keys 5.8 renamed, and C++ names Epic deprecated or removed.

## Install

```bash
claude plugin install unreal@cc-plugins-marketplace
```

Companion: **gamedev** carries the engine-agnostic shipping and workflow material. Install it
alongside with `claude plugin install gamedev@cc-plugins-marketplace`; nothing installs it for you.

## What ships

| Artifact | Reach for it when |
|---|---|
| `unreal-best-practices` skill | The project has a `*.uproject` and you package, cook, set up a build machine, wire Enhanced Input, add key rebinding, run automation tests headless, hold UObjects from plain C++, or write Behavior Tree tasks. Its body routes to three references: packaging and cooking, Enhanced Input, and C++ with AI. It also points to Epic's own Claude Code plugin and the 5.8 editor MCP, with their setup traps. |
| `scripts/check_unreal_project.py` | `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/check_unreal_project.py" <project-dir> [--json] [--strict] [--engine-version X.Y]`. Read-only, Python 3 standard library, no engine. Exit 0 clean, 1 errors, 2 no single `.uproject` or no readable version |

## What has teeth

| Rule | Standing |
|---|---|
| Every fact in the references | **recorded**. Each reference names which of its items were re-read against Epic's docs on 2026-10-26 and which are carried from the upstream source unread. |
| Ship the staging output | **recorded** — nothing reads your packaging step |
| Keep zenserver alive on CI (`LimitProcessLifetime=false`); no `AllowRemoteNetworkService` or pre-5.8 DDC graph left in `Config/*.ini` on 5.8 | **gate where run** — `check_unreal_project.py` warns. Running it is **recorded**: no hook runs it |
| No C++ name in `Source/` that Epic's release notes deprecate (warning) or remove (error) for the project's version | **gate where run** — 15 name rules, each citing its release-notes URL. A name is matched as written, so an alias or macro hides it, and `Plugins/*/Source` is not scanned. A name in an `#if 0` branch, or in any branch of an `#if` group that names `ENGINE_MAJOR_VERSION`/`ENGINE_MINOR_VERSION`/`ENGINE_PATCH_VERSION` or a `UE_VERSION_*` macro, is skipped |
| The checker's own behaviour | **gate** — `scripts/__tests__/check_unreal_project.test.sh`, 19 end-to-end cases on throwaway projects, runs in this repo's CI. It proves the codes, not that Unreal agrees: no engine or compiler runs |
| The pointer to Epic's Claude Code plugin and the 5.8 MCP | **recorded** — read from Epic's pages on 2026-11-09 |
| Version-matching advice to `EngineAssociation` | **agent-graded** |

Measured: nothing — no control-arm eval. Whether these facts change what the model writes is
unmeasured.

Credit: Adapted from [gamedev-skills/awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills) @184b72b (Apache-2.0, © 2026 Abhishek Barali and contributors); prose distilled and rewritten here; no upstream code or script ships in this plugin.
