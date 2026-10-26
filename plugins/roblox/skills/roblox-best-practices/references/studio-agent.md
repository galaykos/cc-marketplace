# Studio as an agent: docs, the MCP server, scripted multiplayer tests

> Last verified: 2026-10-26 — https://create.roblox.com/docs/studio/mcp

Read this when you can reach Roblox Studio or the Creator Hub from the session, or when a
change has to be verified in a running place.

## Docs as Markdown

Every Creator Hub page is served twice: as HTML at its normal URL and as Markdown at the
same URL with `.md` appended (`https://create.roblox.com/docs/reference/engine/classes/UnreliableRemoteEvent.md`).
`https://create.roblox.com/docs/llms.txt` is the index. Fetch the `.md` page for an API's
current signature or a limit, rather than recalling it.

## Studio's built-in MCP server

- **Enable:** in Studio, open **Assistant**, then **…** › **Manage MCP Servers**, and turn on
  **Enable Studio as MCP server**. It talks to the client over stdio.
- **Target the right window:** every tool call takes a `studio_id`. With several Studio
  windows open, list them first (`list_roblox_studios`) and pick by place name. If the list
  is empty, Studio is closed, no place is open, or the setting is off.
- **Tools change between Studio releases.** List the tools from the connected server
  instead of relying on names from memory. As of the stamp they included `script_read`,
  `multi_edit`, `execute_luau` (which needs a `datamodel_type` of Edit, Client or Server),
  `start_stop_play`, `get_console_output` and `screen_capture`.
- **Trust:** a connected MCP client can read and modify every open place. Connect only
  clients you trust, and treat an inserted Creator Store model as third-party code —
  inspect its Scripts before keeping it.
- **Evidence:** `get_console_output` and `screen_capture` give the Output log and the
  viewport. Read the Output for both the server and each client context, not only one.

## Scripted multiplayer tests: `StudioTestService`

- `StudioTestService:ExecuteMultiplayerTestAsync(numPlayers, args)` starts one server and
  `numPlayers` client DataModels — **1 to 8** — and returns once the test ends. It can only
  be called from **plugin** code.
- From the server DataModel of the running test: `EndTest(value)` ends it and hands `value`
  back to the caller; `AddPlayers(n)` adds clients mid-test.
- From a client DataModel: `LeaveTest()` disconnects that client, which is how a test
  scripts a player leaving.
- `GetTestArgs()` returns the `args` passed in; the docs warn it may fail when called from a
  client `LocalScript`.

This is the only scripted route to multi-client evidence (joins, leaves, targeted
replication, two players acting at once). Without a plugin harness, use Studio's
**Server & Clients** test mode by hand and say which cases were run.

## Standing

Recorded. Tool names and menu paths are as of the stamp, and nothing checks them.
Reporting a change as "tested in Studio" when only static checks ran is agent-graded:
name what was executed, what was only linted, and what was not run.
