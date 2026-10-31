# meshy

Rules for generating game assets with [Meshy](https://www.meshy.ai) that a model gets wrong from
memory: a create whose outcome is unknown is reconciled, never resubmitted, because the API has no
idempotency key; a running task cannot be cancelled; files and their signed URLs are gone after 3
days; free-plan output is owned by Meshy and licensed to you under CC BY 4.0; rigging takes textured
humanoids only. Plus a checker that measures a GLB/glTF's triangles, texture sizes and required
extensions before it goes into an engine, with an exit code.

## Install

```bash
claude plugin install meshy@cc-plugins-marketplace
```

Companions, installed separately (no plugin here may declare `dependencies`):

- **gamedev** — its `game-assets` skill owns the Steam Content Survey AI-content disclosure and the
  per-asset licence record. This plugin says what Meshy's licence is; that skill says how to record
  and disclose it. `claude plugin install gamedev@cc-plugins-marketplace`
- **secret-scanning** — keeps `MESHY_API_KEY` out of committed files: its write guard denies a
  `.mcp.json` carrying a literal `msy_…` key (probed 2026-10-30) and lets `${MESHY_API_KEY}` through.
  `claude plugin install secret-scanning@cc-plugins-marketplace`

## Meshy's own tools (not shipped here)

This plugin ships no MCP server and no `.mcp.json`. Meshy publishes both of these; each line is
taken from the upstream source named beside it.

Meshy MCP server, `@meshy-ai/meshy-mcp-server` (its README's Claude Code line; the README says the
API key "requires Pro plan or above"; keys at https://www.meshy.ai/developers/keys):

```bash
claude mcp add-json meshy '{"command":"npx","args":["-y","@meshy-ai/meshy-mcp-server"],"env":{"MESHY_API_KEY":"msy_YOUR_API_KEY"}}'
```

That writes to `~/.claude.json` (local scope). With `--scope project` the entry lands in the
committed `.mcp.json`: put `${MESHY_API_KEY}` there instead of the key, which Claude Code expands
from the environment.

Meshy's Claude Code plugins (skills that drive `meshy-cli` 0.7; Node 22.12+). The two lines below
come from the repository's `.claude-plugin/marketplace.json` (marketplace `meshy-3d-agent`; the host
validator passes it). Its README names no marketplace line and installs with
`npx -y skills add meshy-dev/meshy-3d-agent --skill meshy-3d-generation --skill meshy-3d-printing -g -y`
and `npm install -g meshy-cli@0.7` instead.

```bash
claude plugin marketplace add meshy-dev/meshy-3d-agent
claude plugin install meshy-3d-generation@meshy-3d-agent
```

## Other generators

[Higgsfield's skills](https://github.com/higgsfield-ai/skills) (MIT) include 3D models among their
image and video ones. They drive the `higgsfield` CLI: its installer downloads a prebuilt binary
from GitHub releases, the public `higgsfield-ai/cli` repository carries no source, and jobs spend
Higgsfield account credits. Install line from its README:

```
/plugin marketplace add higgsfield-ai/skills
/plugin install higgsfield@higgsfield
```

The checker below reads any generator's GLB/glTF; the task and licence rules in the skill are
Meshy's only.

## What ships

| Artifact | Reach for it when |
|---|---|
| `meshy-generation` skill | Creating, polling, deleting or downloading Meshy tasks through any client, rigging or animating a Meshy model, or deciding whether a generated model may ship |
| `scripts/inspect_glb.py` | Before importing a generated model or sending one back to Meshy: `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/inspect_glb.py" model.glb --max-tris 15000 --max-texture 2048` (`--allow-ext NAME`, `--json`) |

The checker is stdlib-only Python 3, reads the files it is given and writes nothing.

## What has teeth

| Rule | Standing |
|---|---|
| Never resend a create after a timeout, dropped connection, `5xx` or meshy-cli exit 10 | **recorded** in the skill. meshy-cli and the MCP server refuse to retry a create in their own code; a hand-written client has nothing |
| A running task cannot be cancelled; files expire after 3 days | **recorded** — the API enforces both, nothing here does |
| Triangle, texture-size and required-extension budget of a GLB/glTF | **gate** for what `inspect_glb.py` checks (exit 1); no hook runs it, so whether it runs is **agent-graded** |
| Free-plan output carries CC BY 4.0 credit to Meshy; a model shared to Meshy Community becomes CC0 | **recorded** — read from Meshy's Terms of Use; no script reads a licence |
| The checker's own contract (counts, transforms, budgets, extensions, exit codes) | **gate** — `scripts/__tests__/inspect_glb.test.sh`, run by CI's plugin-harness step |

The checker trusts the file's own accessor counts and POSITION bounds and does not validate it
against the glTF schema. It sizes PNG and JPEG images only, so a KTX2 or WebP image fails
`--max-texture` as unmeasured. Skinned meshes are measured in bind pose. It has no list of which
extensions an engine supports: every required extension fails unless passed to `--allow-ext`.
Passing it says the counts are within budget, not that an engine imports the file.

Measured: nothing — no control-arm eval.

Credit: facts drawn from Meshy's MIT-licensed [meshy-3d-agent](https://github.com/meshy-dev/meshy-3d-agent) @1acd965, [meshy-cli](https://github.com/meshy-dev/meshy-cli) @80ac347 and [meshy-mcp-server](https://github.com/meshy-dev/meshy-mcp-server) @0f4c10a, each re-checked against docs.meshy.ai and Meshy's Terms of Use on 2026-10-30; prose rewritten, no code copied.
