# marketing-image-ops

Deterministic image work for the marketing suite. Detects a generic third-party
image MCP and delegates raster primitives (resize, crop, optimize, convert), then
composes the marketing presets those servers don't ship — OG images, app-store
frames, favicon sets, captioned frames. MCP-agnostic; never installs anything.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install marketing-image-ops@cc-plugins-marketplace
```

## Register an image MCP (required for raster ops)

The raster engine is **not bundled** — this plugin adopts an existing MCP you
register once in your own MCP config. Recommended (Sharp-based, fast):

```jsonc
// e.g. in your project .mcp.json / Claude Code MCP config
{ "mcpServers": { "image": { "command": "npx", "args": ["-y", "mcp-image-optimizer"] } } }
```

An ImageMagick server (e.g. `mcp-imagemagick`) also works and adds true `.ico`
favicons + 200 formats. The skill is MCP-agnostic — it uses whichever is present.

> **Third-party note.** These are community servers that read and write local
> files. Pin a version, point them only at your asset directories, and review
> before adopting. Without a registered MCP, framing ops fall back to an HTML
> composite and pure raster ops (resize/optimize/favicon) skip with a note —
> nothing is installed on your behalf.

## Skills

| Skill | What it does |
|-------|--------------|
| `image-ops` | Detect an image MCP, delegate primitives, compose presets (og_image 1200×630, app_store_frame, favicon, captioned frame), degrade per the fallback matrix. The suite's single image-detection point |

## Pairs well with

- **marketing-capture** — routes frame/resize/optimize through this skill.
- **marketing-copy** — requests an `og_image` for the social card.
- **marketing-suite** — bundles this with capture and copy.
