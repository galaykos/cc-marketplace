# roblox

One skill for Roblox experiences written in Luau, plus three references read on demand.
It holds only what a remembered answer gets wrong: the platform limits and quotas, the
footguns behind them, and the 2025–2026 changes (Server Authority, `PreferredInput`,
Studio's MCP server). The basics are left out on purpose — server authority over client
input, `task.wait`, `WaitForChild`, `pcall` around DataStore calls. They are what the
model already says, and restating them measured at zero elsewhere in this marketplace
(`rationale/measured-zero-shapes.md`).

## Install

```bash
claude plugin install roblox@cc-plugins-marketplace
```

**Pairs with `gamedev`.** That plugin holds the engine-agnostic shipping and workflow
material; this one holds only Roblox. Nothing installs the pair for you, because no
plugin here may declare `dependencies`.

## Skills

| Skill | Reach for it when |
|---|---|
| `roblox-best-practices` | Rojo projects, `.rbxl`/`.rbxlx` places and `.luau` code. Covers remote limits and the yield race, collision groups, `PreferredInput` and static checks in the body. The references cover DataStores (`references/datastores.md`), Server Authority (`references/server-authority.md`) and Studio's MCP server plus `StudioTestService` (`references/studio-agent.md`) |

## What has teeth

| Rule | Standing |
|---|---|
| Read `AuthorityMode`, streaming and each Script's `RunContext` before advising | agent-graded |
| Every limit and quota in the skill | recorded — true as of the 2026-10-26 stamp. Roblox changes quotas without a version, and nothing re-reads them, so the skill sends the reader to the live `.md` docs page before quoting one |
| Remote throttle, payload drop, DataStore budgets | Roblox enforces these at runtime. The skill only predicts the failure |
| Claim a cooldown before the first yield; play effects outside the simulation | agent-graded — no tool detects either |

Measured: nothing — no control-arm eval.

Credit: Adapted from [gamedev-skills/awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills) @184b72b (Apache-2.0, © 2026 Abhishek Barali and contributors); prose distilled and rewritten here; this plugin ships no upstream scripts, so it carries no NOTICE.
