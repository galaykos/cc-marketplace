# High-level multiplayer: the footguns

> Last verified: 2026-10-26 — https://docs.godotengine.org/en/stable/classes/class_multiplayersynchronizer.html

Only what a competent answer from memory gets wrong. ENet setup, `rpc()` / `rpc_id()`, and
"validate on the server" are assumed known.

## "authority" means the node's authority, not the server

- `@rpc` with no arguments is `@rpc("authority", "call_remote", "reliable", 0)`: only the
  NODE'S multiplayer authority may call it remotely.
- A player avatar whose authority is its owning client (`set_multiplayer_authority(id)`)
  therefore rejects an RPC the server sends it:
  `RPC 'x' is not allowed on node ... from: 1. Mode is "authority"`.
- Remedy: declare the server→client RPC `"any_peer"` and return early unless
  `multiplayer.get_remote_sender_id() == 1`, or move server-driven RPCs to a node the server
  owns (a game manager).

```gdscript
@rpc("any_peer", "call_local", "reliable")
func spawn_projectile(owner_id: int) -> void:
    if multiplayer.get_remote_sender_id() != 1:
        return  # only the server may order this
    _do_spawn(owner_id)
```

## Declarations must match on every peer

- Godot checksums the set of `@rpc` methods in a script and their annotations. Every peer must
  declare the same RPCs — unused ones included. A mismatch produces errors that may name an
  unrelated RPC, so diff the whole script's `@rpc` lines across client and server builds.
- `@rpc` takes mode, sync and transfer mode in any order, but the channel must be the 4th
  argument, so all three come before it: `@rpc("any_peer", "call_remote", "unreliable", 2)`.
- RPC routing goes by node path. Spawn with identical names on every peer — through
  `MultiplayerSpawner`, or `add_child(node, true)` for readable names.

## Spawner and synchronizer

- `MultiplayerSpawner.spawn(data)` errors unless `spawn_function` is set; plain `add_child()`
  under the spawn path of a scene in the spawnable list needs no function.
- Per-property replication is set with `SceneReplicationConfig.property_set_replication_mode()`;
  `property_set_sync` and `property_set_watch` are deprecated. *Always* sends unreliably every
  `replication_interval`; *On Change* sends reliably, checked every `delta_interval` (both
  intervals default to 0 = every network frame).
- `public_visibility` defaults to `true`, so every peer already receives the node and
  `set_visibility_for(peer, true)` changes nothing. For a private node, set
  `public_visibility = false` first, then grant peers one by one.

## Authentication runs on both sides

`SceneMultiplayer` auth is a two-sided handshake; setting it up on the server alone hangs:

- Set `auth_callback` on BOTH peers before assigning `multiplayer_peer` (cast
  `multiplayer as SceneMultiplayer`). A client with no callback skips the handshake and the
  server waits for data that never arrives.
- BOTH sides must call `complete_auth(peer_id)`. `connected_to_server` / `peer_connected` fire
  only after both have; otherwise `auth_timeout` expires and `peer_authentication_failed` fires.
- The client sends its credentials from `peer_authenticating` with `send_auth(peer_id, bytes)`.
