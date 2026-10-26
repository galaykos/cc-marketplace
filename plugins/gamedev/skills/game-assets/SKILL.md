---
name: game-assets
description: Use when game art — a sprite, tileset, texture, icon or UI art — comes from an image generator, an asset store or a free pack — a "transparent PNG" that shows a checkerboard, pixel art with too many colours, a purchased pack about to be committed to a public repo, or the Steam Content Survey's AI-generated content section — checks size, alpha and colour count by script and names the licence and disclosure traps.
---

> Last verified: 2026-10-26 — https://partner.steamgames.com/doc/gettingstarted/contentsurvey

Read the engine and its version from the project (`project.godot`,
`ProjectSettings/ProjectVersion.txt`, `*.uproject`, `package.json`) before touching
import settings — filtering, mipmaps and pixels-per-unit are engine-major-specific and
belong to the engine plugin, not this skill. This skill covers what is true in every
engine: the file itself, its licence, and the store disclosure.

## The rules, and who enforces each

| Rule | Standing |
|---|---|
| Run `asset_report.py` on every generated or sourced raster before calling it shippable | **gate** for what it checks (exit 1); no hook runs it, so whether it runs is **agent-graded** |
| A generated "transparent" image is not transparent until its alpha is checked | **gate** via `--require-alpha`, with the one-pixel residual below |
| No purchased pack goes into a public repo unless its licence allows redistributing the files | **agent-graded** — read the licence; no script reads one |
| Every shipped asset made with AI tools is recorded as pre-generated or live-generated | **recorded** — a manifest column; nothing reads it back |

## Check the file, not the prompt

Image generators often return an RGBA PNG with every pixel opaque and a grey-and-white
checkerboard painted where the background should be: the editor's picture of
transparency, baked in. Writing "transparent background" in the prompt does not produce
an alpha channel. Use the tool's native transparent-output option when it has one,
otherwise remove the background with a deterministic tool, then check:

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/asset_report.py" art/player-idle.png \
  --expect-size 64x64 --require-alpha --max-colors 48 --json
```

- `--require-alpha` fails both "no alpha channel" and "alpha channel present, no pixel
  transparent". **Residual:** one transparent pixel anywhere passes, so a checkerboard
  with a cut-out border still passes. Read the image at native scale before approving.
- `--max-colors` is the cheap pixel-art test: a generated "pixel-art" sprite carries
  hundreds of anti-aliased in-between colours, a real one stays inside its palette. Take N
  from the art direction's palette. It counts distinct RGBA values, so fully transparent
  pixels with different RGB underneath count separately; clear the RGB under alpha 0 when
  the count looks inflated.
- `--expect-size` takes `WIDTHxHEIGHT`; generated sheets drift in size and frame grid.
- Exit **0** every asset passed, **1** an asset broke a flag or is missing/unreadable,
  **2** the check could not run (bad arguments, or Pillow missing). Never read exit 2 as
  an asset failure.
- Needs Python 3.10+ and Pillow 10+: `python3 -m pip install Pillow`. Without it the
  script exits 2 and says "install Pillow".

It does not judge style, seams, pivots, frame slicing or palette identity; those are a
look at the asset in the running game.

## Licences: shipping a build is not redistributing files

- "Free", "royalty-free", search-visible or model-generated is not a licence. Read the
  terms at the original source, not a repost or an aggregator's preview.
- A store licence that lets you ship an asset inside a built game often forbids
  publishing the asset's files. Committing a purchased pack to a public repository (an
  open-source game, a public jam repo) is redistribution of those files. Before the
  commit, find the clause on redistributing source or unmodified files; where it forbids
  it, keep the pack out of the public repo (gitignored and fetched by a setup step from
  the buyer's own account) or keep the repo private.
- Attribution survives atlas packing, renaming and format conversion only if it lives
  in a manifest row, not in a file name that the pipeline rewrites.
- Unclear terms on a commercial release go to a human rights review; do not guess.

## Steam: the AI-content disclosure

The Steamworks Content Survey has a required section on AI-generated content with two
classes:

- **Pre-Generated** — made with AI tools during development and shipped with the game.
  Describe how; Valve reviews it like any other content.
- **Live-Generated** — created with AI tools while the game runs. Same rules, plus a
  description of the guardrails that stop it producing illegal content.

Record the class per asset when the asset is made (a manifest column such as
`ai: none | pre-generated | live-generated` beside source, licence and attribution), so
the survey is answered from records rather than memory. Store rules change: re-read the
survey page before each submission.

## Anti-patterns

- **Prompt as proof** — calling an asset done because the generator was asked for 64×64,
  16 colours, transparent. Check the file.
- **Checkerboard alpha** — a sprite whose transparency is painted, shipped because it
  looked right in a viewer with a light background.
- **Public-repo pack** — a purchased asset pack committed to a public repository.
- **Disclosure from memory** — filling in the Content Survey's AI section with no
  per-asset record.
