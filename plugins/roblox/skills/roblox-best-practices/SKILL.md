---
name: roblox-best-practices
description: Use when writing, reviewing or debugging Roblox Luau — a Rojo `*.project.json`, `.rbxl`/`.rbxlx`, `wally.toml` or `.luau` files, or code using `RemoteEvent`, `UnreliableRemoteEvent`, `DataStoreService`, `UpdateAsync`, `Workspace.AuthorityMode`, `BindToSimulation`, `PreferredInput`, collision groups or Studio's MCP server — the platform limits, quotas and 2025–2026 API changes a remembered answer gets wrong.
---

> Last verified: 2026-10-26 — https://create.roblox.com/docs
<!-- version-tail-ok: Roblox is a rolling platform with no package or version to pin; the stamp points at the Creator Hub, and every number below was re-read from its pages on 2026-10-26 -->

## Read the place's settings first

Roblox has no engine version to pin; what changes the answer is what the place opted
into. Before advising, read `Workspace.AuthorityMode`, `Workspace.StreamingEnabled` and
the `RunContext` of each `Script` involved — from the Rojo `*.project.json` and model
files when the project has them, otherwise ask or check in Studio.

The docs are machine-readable: append `.md` to any `https://create.roblox.com/docs/...`
URL for the Markdown page, and `https://create.roblox.com/docs/llms.txt` indexes them.
Fetch the page before quoting a limit — the numbers below are as of the stamp, and
Roblox changes quotas without a version bump.

## Limits memory gets wrong

| Limit | Value (2026-10-26) |
|---|---|
| `UnreliableRemoteEvent` payload | over **1000 bytes** is dropped; so is traffic over the throttle, or with no handler connected |
| Client → server remote throttle | ~**500 requests/s per client**, shared by every `RemoteEvent` in the experience (separately, by every `UnreliableRemoteEvent`). A reliable event over it is delayed, not dropped — the queued events still arrive, in order |
| DataStore request budget | per minute, per experience: reads and removes 300 + 40×CCU, writes 300 + 20×CCU, lists 300 + 2×CCU; `UpdateAsync` spends a read AND a write; Open Cloud traffic shares the same budget |
| DataStore storage | 500 MB + 1 MB × lifetime users, per experience, latest versions only |
| DataStore entry | value ≤ 4,194,304 characters; store, key and scope names ≤ 50 characters; per key ≤ 25 MB/min read, 4 MB/min write |
| Attributes under Server Authority | only the first 64 on an instance replicate |

Full DataStore budget and the footguns that lose data: `references/datastores.md`.

## Footguns — symptom, cause, fix

- **One cooldown lets two requests through.** Reliable remotes from one player arrive in
  order, but a handler that yields (`task.wait`, `WaitForChild`, a DataStore call) lets
  the next one start before it resumes. Claim the cooldown, or mark the request in
  progress, before the first yield. A `RemoteFunction` and a `RemoteEvent` are not
  ordered relative to each other; use one kind or a sequence number when order matters.
- **NaN slips past a range check.** `x ~= x` is true only for NaN, and `NaN < limit` is
  false, so `if x > limit then reject` lets it in. Check `x == x` and
  `math.abs(x) ~= math.huge` before the range.
- **A client `Script` runs twice.** A `Script` with `RunContext = Client` inside
  `StarterPlayerScripts`, `StarterCharacterScripts` or `StarterGui` runs as the original
  and again as the clone. Keep those in `ReplicatedStorage`.
- **An overlap query ignores `CanQuery`.** `OverlapParams.RespectCanCollide = true`
  switches the query to honour `CanCollide` instead. Set it deliberately.
- **A fast projectile passes through.** `.Touched` samples discretely; use a swept
  `Workspace:Blockcast`, `Spherecast` or `Shapecast` for the path.
- **UI picks the wrong controls.** `TouchEnabled`/`GamepadEnabled` report capability (a
  touch laptop says touch) and `GetLastInputType()` flips on every input. Decide with
  `UserInputService.PreferredInput` (`Touch`, `Gamepad`, `KeyboardAndMouse`) and re-check
  on `GetPropertyChangedSignal("PreferredInput")`.

## Deprecated, and what replaced it

- **Collision groups.** Deprecated on `PhysicsService`: `CreateCollisionGroup`,
  `RemoveCollisionGroup`, `GetCollisionGroups`, `SetPartCollisionGroup`,
  `GetCollisionGroupId`, `GetCollisionGroupName`, `CollisionGroupContainsPart`. Use
  `RegisterCollisionGroup`, `UnregisterCollisionGroup`, `GetRegisteredCollisionGroups`
  and `CollisionGroupSetCollidable`, and assign a part by name through
  `BasePart.CollisionGroup`. Those current methods exist on `PhysicsService` and on every
  `WorldRoot` (`Workspace`, a `WorldModel`), where they register groups for that world.
  Do not "migrate" a working `PhysicsService:RegisterCollisionGroup` call — it is not
  deprecated.

## Server Authority

With `Workspace.AuthorityMode = Server` (fully released July 2026) the engine predicts,
rolls back and resimulates, and gameplay code has to run inside
`RunService:BindToSimulation()`. Flipping it also switches on five other settings, among
them streaming. Before touching prediction, physics or input in such a place, read
`references/server-authority.md`. Never switch a place's `AuthorityMode` as a side
effect of another task — it is a project-wide migration; offer it instead.

## Static checks and Studio

- When the project already has the tools: `selene .` with `std = "roblox"` in
  `selene.toml`; for Rojo, `rojo sourcemap default.project.json --output sourcemap.json`,
  then `luau-lsp analyze --sourcemap=sourcemap.json --definitions=<roblox definitions> src`
  (`luau-lsp analyze --help` lists the flags).
- Studio ships a built-in MCP server, and `StudioTestService` drives scripted multi-client
  tests from a plugin. Setup, the tools and what each can prove:
  `references/studio-agent.md`.

## Who enforces what

| Rule | Standing |
|---|---|
| Read `AuthorityMode`, streaming and `RunContext` before advising | agent-graded |
| The limits table | recorded — as of the stamp; Roblox changes quotas silently, and no script re-reads them |
| Remote throttle, payload drop, DataStore budget | Roblox enforces them at runtime — the rules here only predict the failure |
| Claim the cooldown before the first yield | agent-graded — nothing detects a yield between check and apply |
| Never flip `AuthorityMode` as a side effect | recorded |

## Anti-patterns

- **Per-frame reliable remotes.** A legitimate player hits the shared ~500/s throttle
  before any exploiter does; send state through replication, or cosmetics through an
  unreliable event.
- **Quoting a quota from memory.** Fetch the `.md` page; limits move without notice.
- **Building your own prediction in a Server Authority place.** The engine already
  predicts and resimulates; a parallel scheme fights it.
