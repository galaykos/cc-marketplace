# asset-forge

Game-asset creation in Blender. The model is weak at four things that a Blender MCP server alone does not fix:
judging its own work, organic shapes, hand-painted textures and retargeting animation. It also does not hold
studio conventions. This plugin adds a headless MCP server that renders, validates, bakes and exports
**snapshots** of the live scene (never the working `.blend`), a pure-bpy library the live session imports, and
pipeline skills with per-engine presets.

**Status: 0.1.0 is a skeleton.** The server answers one tool, `env_check`. The forge library, review renders,
validator, bake, export, hooks and the art-reviewer agent are not built yet. Each skill says so when it loads.

## Install

```bash
claude plugin install asset-forge@cc-plugins-marketplace
```

Needs `python3` on PATH (standard library only; tested on 3.14) and Blender (tested on 5.2.3 only). Nothing is downloaded
or installed: no uv, no pip, no Pillow. Live editing goes through a Blender MCP server you already run (this
plugin calls `execute_blender_code` and the screenshot tools; it ships none of them).

Companion: install **blender** alongside it. Its checkers (`blender_qa.py`, `rig_check.py`, `anim_audit.py`)
and its export rules are what asset-forge calls rather than duplicating. Nothing installs the pair for you: no
plugin here may declare `dependencies`.

```bash
claude plugin install blender@cc-plugins-marketplace
```

## Configure

| Option | Default | What it does |
|---|---|---|
| `blender_path` | empty | Blender executable for headless jobs. Empty: `BLENDER_PATH`, then `blender` on PATH, then `~/Applications/blender-*`, `/opt/blender*`, the macOS app and `C:/Program Files/Blender Foundation` |

Per-project settings (engine, platform tiers, art style, game camera, budgets, folders) will live in the game
project's `asset-forge.json`, written by the `pipeline` skill on first use.

## What ships

| Artifact | Reach for it when |
|---|---|
| `forge` MCP server, tool `env_check` | Before any headless job, or when one fails: which Blender, found how, its version, the render engines it can set, numpy in its Python |
| skills `pipeline`, `new-asset`, `organic-modeling`, `stylized-texturing`, `animation-retarget`, `review` | Stubs that state their status. All six carry `disable-model-invocation: true`, so they cost no listing context and never fire on their own until their content ships; `/asset-forge:<name>` still opens one |

## What has teeth

| Rule | Standing |
|---|---|
| The server speaks MCP over stdio and `env_check` reports the real Blender | gate where run: `scripts/__tests__/forge-server.test.sh` (the Blender cases skip when no Blender is found) |
| Headless jobs open a snapshot or a factory scene, never the working file | recorded: `run_job` takes a path its caller chose; no check enforces that the path is a snapshot until the snapshot step ships |

## Limitations

- The server runs Blender with `--factory-startup`, so the user's add-ons and preferences are not loaded headless.
- `env_check` finds render engines by trying to set each one; a third-party engine that registers only in the
  user's preferences is not listed.
