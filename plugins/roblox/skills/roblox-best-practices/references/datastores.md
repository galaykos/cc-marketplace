# DataStores: the budget, and the footguns that lose data

> Last verified: 2026-10-26 — https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits

Read this before writing or reviewing code that calls `DataStoreService`. It skips the
parts any competent answer already gives (wrap calls in `pcall`, prefer `UpdateAsync` to
`SetAsync` for read-modify-write, save on leave and on shutdown, lock sessions) and keeps
the numbers and the failure modes that answer misses. Numbers change without notice —
re-read the stamped page before quoting one to a user.

## The request budget

Per minute, per experience, refilled continuously (CCU = concurrent users across the
whole experience):

| Request type | Budget |
|---|---|
| Reads (`GetAsync`) and removes | 300 + 40 × CCU |
| Writes (`SetAsync`, `IncrementAsync`) | 300 + 20 × CCU |
| Lists | 300 + 2 × CCU |

- `UpdateAsync` spends from the read AND the write budget on every call.
- Game servers and Open Cloud share this budget. A heavy external tool (an admin
  dashboard, a bulk migration) can throttle requests made in-game, and in-game traffic
  can throttle the tool.
- Check headroom before a burst with
  `DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.<type>)`.

## Storage and entry limits

- Storage is per experience, not per key: **500 MB + 1 MB × lifetime user count** (every
  user who ever joined), counting only the latest version of each key. Old versions do not
  count against it.
- Store, key and scope names: at most **50 characters**.
- A value: at most **4,194,304 characters** of serialized JSON — measure with
  `HttpService:JSONEncode`. Only JSON-shaped data survives: numbers, strings, booleans,
  tables with string or number keys. `Vector3`, `CFrame` and `Instance` values do not;
  serialize them to plain tables first.
- Per key, across all servers: **25 MB/min read, 4 MB/min write**. A hot shared key
  throttles even while the experience budget has room — shard it.

## Footguns

- **A failed write is not proof it failed.** The server may have missed the response.
  Re-running an `UpdateAsync` that writes the full state is harmless; re-running
  `IncrementAsync` can add twice. When the outcome matters, confirm with an uncached read
  (`DataStoreGetOptions` with `UseCache = false`, which costs a real request) before
  retrying.
- **`GetAsync` is cached for about four seconds.** An immediate re-read after a write can
  return the cached value; verification reads use `UseCache = false`.
- **The `UpdateAsync` callback can run more than once.** Roblox re-runs it when another
  server wrote the key between read and write. Keep it pure: no `task.wait`, no other Async
  call, no item grants or remote fires inside it — act after it returns. Return `nil` to
  cancel the write.
- **A player can leave mid-load.** `PlayerRemoving` can fire while `GetAsync` is still in
  flight. Gate the save on "load succeeded" (`player:GetAttribute("DataLoaded") == true`),
  not on "load did not fail" (`~= false` lets the in-flight case through), or defaults
  overwrite real data.
- **Metadata and UserIds are wiped by a write that omits them.** Re-supply them on every
  write. The `UpdateAsync` callback receives `(currentValue, keyInfo)` and returns up to
  `(newValue, userIds, metadata)` — return `keyInfo:GetUserIds()` and
  `keyInfo:GetMetadata()` when unchanged.
- **`DataStoreKeyInfo` is nil on an `OrderedDataStore`.** Ordered stores have no
  versioning or metadata; use a regular `DataStore` when you need them.
- **`BindToClose` gets at most 30 seconds.** Save every remaining player in parallel
  (`task.spawn` per player) and yield until all finish; a sequential loop runs out of time
  on a full server.
- **Studio hits live data.** Requests fail until the place enables *Enable Studio Access to
  API Services*; once enabled, Studio reads and writes the same stores players use. Test in
  a separate place.

## Right to be forgotten

Deletion requests are the experience owner's job: keep a list of every store and key a
player touches, so `RemoveAsync` (or the Open Cloud DataStore API, from outside the game)
can remove all of it, including ordered-store entries.
