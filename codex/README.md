# Codex marketplace (generated)

This tree is generated one-way from the Claude Code plugins in `plugins/` by
`scripts/gen-codex/`. Do not hand-edit — run `node scripts/gen-codex/gen.mjs`;
`scripts/validate-codex.sh` enforces freshness in CI.

## Install (two parts)

1. **Skills + hooks** — add this repo as a Codex marketplace and install plugins:

   `codex plugin marketplace add galaykos/cc-marketplace`

   then browse/install with `/plugins`.

2. **Subagents** — Codex plugins cannot bundle subagents, so they install out-of-band.
   Clone this repo and run the generated installer:

   ```sh
   git clone https://github.com/galaykos/cc-marketplace
   cd cc-marketplace
   bash codex/install-agents.sh          # copies codex/agents/*.toml -> ~/.codex/agents
   ```

   Re-running is a no-op for unchanged agents; pass `--force` to overwrite local edits.

## Fidelity

Skills, hooks, and MCP port faithfully; commands become auto-trigger skills (no typed
`/plugin:command` verb); subagents install out-of-band; `SessionEnd` hooks, bundle
dependency fan-out, and interactive command branching are dropped. Per-plugin detail is
in each plugin's `.codex-plugin/plugin.json` `fidelity` block and the catalog.
