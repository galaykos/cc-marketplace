# unreal

Unreal Engine 5 facts that a model gets wrong from memory. Since UE 5.8, a successful cook
leaves `Saved/Cooked/<Platform>` holding only `ue.projectstore`, because Zen Server became the
default cooked output store. 5.8 also raised the toolchain minimums. The plugin adds the
Enhanced Input placement that breaks on network clients, the supported rebinding path, and a
few C++ and Behavior Tree notes. It is prose only; there is no script.

## Install

```bash
claude plugin install unreal@cc-plugins-marketplace
```

Companion: **gamedev** carries the engine-agnostic shipping and workflow material. Install it
alongside with `claude plugin install gamedev@cc-plugins-marketplace`; nothing installs it for you.

## What ships

| Artifact | Reach for it when |
|---|---|
| `unreal-best-practices` skill | The project has a `*.uproject` and you package, cook, set up a build machine, wire Enhanced Input, add key rebinding, run automation tests headless, hold UObjects from plain C++, or write Behavior Tree tasks. Its body routes to three references: packaging and cooking, Enhanced Input, and C++ with AI. |

## What has teeth

| Rule | Standing |
|---|---|
| Every fact in the references | **recorded**. Each reference names which of its items were re-read against Epic's docs on 2026-10-26 and which are carried from the upstream source unread. |
| Ship the staging output; keep zenserver alive on CI (`LimitProcessLifetime=false`) | **recorded** — nothing reads your `DefaultEngine.ini` or your packaging step |
| Version-matching advice to `EngineAssociation` | **agent-graded** |

Measured: nothing — no control-arm eval. Whether these facts change what the model writes is
unmeasured.

Credit: Adapted from [gamedev-skills/awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills) @184b72b (Apache-2.0, © 2026 Abhishek Barali and contributors); prose distilled and rewritten here; no upstream code or script ships in this plugin.
