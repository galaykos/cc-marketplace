# Changelog — roblox

Consumer-facing changes only. Newest first.

## 0.1.0 — 2026-10-26

- **New plugin: `roblox-best-practices`.** One skill plus three references, merged from seven upstream Roblox skills (Luau, DataStores, networking, characters, physics, UI, Studio workflow) and cut to what a remembered answer gets wrong.
  - **Skill body:** the remote throttle (~500/s per client, shared across every `RemoteEvent`) and the `UnreliableRemoteEvent` 1000-byte drop; the yield race that lets two requests pass one cooldown; NaN slipping past range checks; a client-`RunContext` Script running twice; `RespectCanCollide`; swept casts; `PreferredInput`; and which collision-group methods are actually deprecated. `RegisterCollisionGroup` is not.
  - **`references/datastores.md`:** the per-CCU request budget shared with Open Cloud, the storage and entry limits, and the footguns that lose data.
  - **`references/server-authority.md`:** what changes when a place sets `AuthorityMode = Server`.
  - **`references/studio-agent.md`:** the `.md` docs twins, Studio's MCP server and `StudioTestService`.
  - Every number and API was re-read from the Creator Hub on 2026-10-26.
- **Standing:** recorded. Roblox changes quotas without a version, and nothing re-reads them. Unmeasured: no eval with a control arm covers it.
- **Credit.** Adapted from gamedev-skills/awesome-gamedev-agent-skills @184b72b (Apache-2.0). The prose was distilled and rewritten; no code was copied.
