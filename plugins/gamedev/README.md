# gamedev

Engine-agnostic game shipping: getting a build onto Steam and itch.io, checking game assets
before they land, scripting dialogue in Yarn Spinner or Ink, keeping seeded generation stable
across upgrades, and meeting platform floors for text size and loudness. It carries only what a
model gets wrong from memory — store rules, platform limits, changed defaults — plus four
scripts with exit codes.

It is the companion to this marketplace's engine plugins — godot, unity-traps, unreal and
phaser — which carry the per-engine rules and name `gamedev` as
theirs. Install it next to the one your project uses; nothing installs the pair for you.

## Install

```bash
claude plugin install gamedev@cc-plugins-marketplace
```

## Skills

| Skill | What it covers |
|---|---|
| `steam-release` | Uploading with steamcmd, editing `app_build`/`depot_build` `.vdf` scripts, setting a build live, the store and review timeline, the Content Survey's AI section, Steam Cloud, Steam Deck / Steam Machine compatibility |
| `itch-release` | `butler push`, channel names, an HTML5 build that shows as a download or loads blank, CI with `BUTLER_API_KEY`, a jam entry on itch.io |
| `game-assets` | `asset_report.py`: fake-transparency, size and colour-count checks; licence redistribution and Steam AI-disclosure classes |
| `asset-pipeline` | A Higgsfield concept taken through Meshy image-to-3D, remesh and rig, Blender QA and export, and Unity import: a triangle and texture budget per asset, the checker at each handoff, credit caps from Higgsfield's and Meshy's documented commands, and references (not seeds) for a consistent character. Vendor facts and sources: `rationale/gamedev-asset-pipeline-2026-11-02.md` in this repository |
| `dialogue-scripting` | Yarn Spinner 3 and Ink facts a 2.x memory gets wrong |
| `seeded-generation` | Which PRNGs change sequences across runtime versions, and what to ship instead |
| `game-platform-floors` | Xbox XAG 101 text-size floors and Sony ASWG-R001 loudness targets, metered by `loudness_meter.py` |

## Scripts

| Script | What it does |
|---|---|
| `scripts/check_steam_build.py` | Lints a SteamPipe app build script, its depot scripts and content folders before `steamcmd +run_app_build`, including a shipped `steam_appid.txt` and AppID 480; prints per-depot file counts. Exit 0 clean, 1 errors (or warnings with `--strict`), 2 unusable input. Standard library only; never logs in or uploads |
| `scripts/check_itch_html5.py` | Checks an HTML5 game zip against itch.io's limits before upload: an `index.html`, ≤1,000 files, ≤500 MB, ≤200 MB per file, ≤240-character names, UTF-8 names. Warns on an `index.html` only in a folder and on a backslash in a name. Exit 0/1/2. Standard library only; never extracts |
| `scripts/loudness_meter.py` | Integrated loudness (LUFS) and true peak (dBTP) per ITU-R BS.1770-5, held to `--target aswg-home`/`aswg-portable` or a number. Exit 0/1/2, and 3 when an OGG or float WAV needs ffmpeg and it is not on PATH. Integer PCM WAV needs only Python |
| `scripts/asset_report.py` | The `game-assets` checks above, run over files on disk |

## What has teeth

| Rule | Standing |
|---|---|
| A SteamPipe script that maps no files, names a missing root, sets `default` live, uploads `steam_appid.txt` or uses AppID 480 | **gate** where a CI step or the user runs `check_steam_build.py`; no hook runs it |
| An HTML5 zip within itch.io's limits | **gate** where `check_itch_html5.py` runs; no hook runs it |
| A mix capture at its ASWG-R001 target, true peak ≤ −1 dBTP | **gate** where `loudness_meter.py --target` runs; whether the capture is the whole mix and long enough is **agent-graded** |
| The checkers' own behaviour | **gate** — `scripts/__tests__/*.test.sh` run their unittest suites in this marketplace's CI; they prove the checks fire, not that steamcmd or itch.io behave the same today. The meter's suite runs EBU Tech 3341 cases 1, 2, 4–6 and 15–19, and compares with ffmpeg's `ebur128` only where ffmpeg is installed |
| Store timelines, review order, upload limits, HTML5 limits | **recorded** — dated by each skill's `Last verified` stamp; nothing re-reads the Steamworks or itch.io pages |
| Content Survey answers, store-page feature parity with the build | **agent-graded** — only a reader of the game's assets and store page can judge them |
| An AI-generated model meets its budget row at each handoff | **gate** where meshy's PostToolUse hook fires (15,000 triangles, 2,048 px); any other row is **agent-graded**, since the agent runs `inspect_glb.py` with its numbers |
| A paid Higgsfield or Meshy call is priced and confirmed first | **agent-graded** — Higgsfield documents no native credit cap, and nothing here refuses a call |

Measured: nothing — no control-arm eval covers any skill here, so whether each one changes what
the model does is unknown.

Credit: Adapted from [gamedev-skills/awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills) @184b72b (Apache-2.0, © 2026 Abhishek Barali and contributors); prose distilled and rewritten here, scripts copied and modified (see NOTICE).
