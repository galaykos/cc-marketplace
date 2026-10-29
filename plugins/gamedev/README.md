# gamedev

Engine-agnostic game shipping: getting a build onto Steam and itch.io, checking game assets
before they land, scripting dialogue in Yarn Spinner or Ink, keeping seeded generation stable
across upgrades, and meeting platform floors for text size and loudness. It carries only what a
model gets wrong from memory — store rules, platform limits, changed defaults — plus two
scripts with exit codes.

It is the companion to this marketplace's engine plugins — godot, unity, unreal, phaser and
pixijs — which carry the per-engine rules and name `gamedev` as
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
| `dialogue-scripting` | Yarn Spinner 3 and Ink facts a 2.x memory gets wrong |
| `seeded-generation` | Which PRNGs change sequences across runtime versions, and what to ship instead |
| `game-platform-floors` | Xbox XAG 101 text-size floors and Sony ASWG-R001 loudness targets |

## Scripts

| Script | What it does |
|---|---|
| `scripts/check_steam_build.py` | Lints a SteamPipe app build script, its depot scripts and content folders before `steamcmd +run_app_build`; prints per-depot file counts. Exit 0 clean, 1 errors (or warnings with `--strict`), 2 unusable input. Standard library only; never logs in or uploads |
| `scripts/asset_report.py` | The `game-assets` checks above, run over files on disk |

## What has teeth

| Rule | Standing |
|---|---|
| A SteamPipe script that maps no files, names a missing root or sets `default` live | **gate** where a CI step or the user runs `check_steam_build.py`; no hook runs it |
| The checker's own behaviour | **gate** — `scripts/__tests__/check_steam_build.test.sh` runs its unittest suite in this marketplace's CI; it proves the checks fire, not that they match what steamcmd does today |
| Store timelines, review order, upload limits, HTML5 limits | **recorded** — dated by each skill's `Last verified` stamp; nothing re-reads the Steamworks or itch.io pages |
| Content Survey answers, store-page feature parity with the build | **agent-graded** — only a reader of the game's assets and store page can judge them |

Measured: nothing — no control-arm eval covers any skill here, so whether each one changes what
the model does is unknown.

Credit: Adapted from [gamedev-skills/awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills) @184b72b (Apache-2.0, © 2026 Abhishek Barali and contributors); prose distilled and rewritten here, scripts copied and modified (see NOTICE).
