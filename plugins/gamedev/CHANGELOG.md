# Changelog — gamedev

Consumer-facing changes only. Newest first.

## 0.1.0 — 2026-10-26

- **New plugin: engine-agnostic game shipping.** Six skills: `steam-release`, `itch-release`,
  `game-assets`, `dialogue-scripting`, `seeded-generation` and `game-platform-floors`. It is
  the companion to the engine plugins; install it next to the one your project uses.
- **`check_steam_build.py`**: lints a SteamPipe app build script, its depot scripts and the
  content folders before an upload — parse errors, bad or duplicate IDs, missing roots,
  `LocalPath`s that match nothing, empty depots, `SetLive` on `default` — and prints per-depot
  file counts. Exit 0/1/2; `--json` and `--strict` for CI.
- **Store and platform facts re-read on 2026-10-26** from the Steamworks and itch.io docs: the
  21-day wait for first titles, review order and timings, `SetLive` never reaching `default`,
  the authenticator step on a released app, the Content Survey's AI classes, Steam Cloud's two
  quota fields, the Deck / Machine checklist, itch.io's HTML5 and 30 GB limits and butler's
  channel rules. Standing: recorded — nothing re-reads the pages.
- **Credit and effect.** Adapted from gamedev-skills/awesome-gamedev-agent-skills @184b72b
  (Apache-2.0); prose rewritten, scripts copied and modified (see NOTICE). Unmeasured: no eval
  with a control arm covers it.
