# Changelog — gamedev

Consumer-facing changes only. Newest first.

## 0.3.0 — 2026-11-09

- **`check_steam_build.py` flags two Steam test leftovers.** `steam-appid-txt-shipped` fires when
  a depot uploads a `steam_appid.txt`; Valve's Steamworks API page says "You should not ship this
  with your builds", and while the file is present `SteamAPI_RestartAppIfNecessary` returns false.
  `appid-spacewar` fires on AppID 480, the SDK's Spacewar example. A `steam_appid.txt` that a
  `FileExclusion` drops, or one outside the content root, stays silent. Standing: gate where run.
- **New `scripts/check_itch_html5.py`.** Checks an HTML5 game zip against itch.io's ZIP rules
  before upload: `index.html` at the root (missing, inside a folder, wrong case), more than 1,000
  files, more than 500 MB extracted, a file over 200 MB, a path over 240 characters, a non-UTF-8
  name. It reads the zip's directory and never extracts. Limits re-read from
  https://itch.io/docs/creators/html5 on 2026-11-09. Exit 0/1/2. Standing: gate where run.
- **New `scripts/loudness_meter.py`.** Integrated loudness and true peak per ITU-R BS.1770-5,
  with `--target aswg-home` (−24 ±2 LUFS) or `aswg-portable` (−18 ±2), a true-peak ceiling of
  −1 dBTP, or your own numbers. Integer PCM WAV is read by Python alone; OGG and float WAV go
  through ffmpeg, and exit 3 says when ffmpeg is missing. Its suite runs EBU Tech 3341 cases 1, 2,
  4–6 and 15–19; where ffmpeg is installed it also compares with ffmpeg's `ebur128`. Standing:
  gate where run. `game-platform-floors` now points at it.
- **`game-assets` names its near misses.** A 3D model goes to `meshy` or `blender`, and an Aseprite
  sheet or a pixel-art conversion goes to `pixel-art`. Standing: recorded.

## 0.2.0 — 2026-11-02

- **New skill: `asset-pipeline`.** It takes a Higgsfield concept image through Meshy image-to-3D,
  remesh and rig, then Blender QA and export, then Unity import. It covers:
  - a triangle and texture budget per asset class, built from Meshy's documented
    `target_polycount` defaults and limits;
  - the checker to run at each handoff;
  - credit caps from the commands Higgsfield and Meshy document: `higgsfield generate cost`,
    `generate wait`, `account status`, and Meshy's per-request prices;
  - references, not seeds, for keeping one character the same across generations.
- **Sources.** Every vendor fact was read on 2026-11-02 and is cited with a quote in
  `rationale/gamedev-asset-pipeline-2026-11-02.md`. Not used, because neither Higgsfield's docs nor
  its CLI 1.2.2 `--help` contain them: `max_credits`, a `batch` command, `jobs wait`. The skill says
  so.
- **Standing.** The budget at the meshy handoff is a gate where meshy's hook fires. Credit
  confirmation is agent-graded. The per-asset manifest is recorded. Unmeasured: no control-arm eval
  covers the skill.

## 0.1.2 — 2026-11-02

- **Companion list names `unity-traps`.** The `unity` plugin was renamed, so the description and
  README name `unity-traps`. Skills and scripts are unchanged.

## 0.1.1 — 2026-10-29

- **Companion list matches the marketplace.** The description and README name the engine plugins this marketplace still ships — godot, unity, unreal, phaser and pixijs. roblox, bevy, defold and ebitengine were removed from the marketplace, so they are no longer named. Skills and scripts are unchanged.

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
