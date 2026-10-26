# Steam Cloud: the settings and timings that lose saves

> Last verified: 2026-10-26 — https://partner.steamgames.com/doc/features/cloud

Depth for `steam-release`. These are the Steam Cloud facts where a save silently fails to sync;
the API itself is in the page the stamp points at.

- **Both quota fields, or nothing syncs.** Steam Cloud stays off until App Admin → Steam Cloud
  has BOTH "Byte quota per user" and "Number of files allowed per user" set. Setting only one
  leaves the cloud off.
- **Auto-Cloud syncs at launch and at exit, never in between.** It downloads when the game
  starts and uploads when it exits. A save written mid-session is not in the cloud until the
  game quits, so another device opened in the meantime does not see it.
- **Keep Root OS at `[Cross-Platform]`.** Root Overrides — the per-OS path remaps that make
  one save follow a player across Windows, macOS and Linux — require it.
- **Dynamic Cloud Sync changes files mid-session.** When a Steam Deck suspends and the player
  continues on another device, Steam can replace save files while the game is suspended. A game
  that opts in must reload them on resume instead of overwriting them from memory.
- **Keep the temp file out of the synced pattern.** A save written as `save.tmp` then renamed
  must not match the Auto-Cloud file pattern, or a half-written file can upload.
