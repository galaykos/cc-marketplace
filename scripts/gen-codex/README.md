# gen-codex — Claude Code plugins → Codex marketplace

One-way generator. Reads the canonical Claude Code plugins under `plugins/` and emits
a Codex marketplace tree **outside** `plugins/`. The CC side is the single source of
truth; the Codex side is derived and must never be hand-edited (`../validate-codex.sh`
enforces freshness in CI).

## Run

```bash
node gen.mjs                 # regenerate the Codex tree (clears + rewrites the output roots)
node gen.mjs --dry-run       # list intended writes, touch nothing
npm test                     # unit suite (node:test); `npm test -- <substr>` filters files
```

Output roots (repo-relative): `.agents/plugins/marketplace.json` (catalog),
`codex/<plugin>/**` (per-plugin manifest + bundled skills/hooks/data),
`codex/agents/*.toml` (subagents), `codex/install-agents.sh`, `AGENTS.md`.

## Layout

| File | Role |
|------|------|
| `schema.mjs` | **The only place** Codex field names / paths / enums live. Pinned against live docs + `codex-cli 0.143.0`. Bump `SCHEMA_VERSION` when Codex's schema moves. |
| `gen.mjs` | Entry point: discover → run registered transforms → write. Guards against any write under `plugins/`. Honors `GEN_CODEX_OUT` (the gate regenerates to a temp dir to diff). |
| `lib/discover.mjs` | Walks `marketplace.json` → each plugin's skills/commands/agents/hooks/README/root-data. |
| `lib/frontmatter.mjs` | Parses `---`-fenced YAML frontmatter (simple `key: value`, quoted values). |
| `lib/serialize.mjs` | Deterministic `stableJson` (sorted keys) + `toml` (`'''` literal strings, `"""` fallback). |
| `lib/toml-parse.mjs` | Minimal TOML parser — validates our own emitted agent TOML round-trips. |
| `lib/normalize.mjs` | Rewrites CC-only tokens on the **copy** only: `/plug:cmd` → skill ref, `${CLAUDE_PLUGIN_ROOT}` → `${PLUGIN_ROOT}`; flags `~/.claude`-coupled skills as degraded. |
| `lib/registry.mjs` | Transform registry + shared run context (records + `/plug:cmd` resolver). |
| `lib/transform-skill.mjs` | Skill → `codex/<plugin>/skills/<name>/` (whole dir, normalized, name==dir). |
| `lib/transform-command.mjs` | Portable command → `cmd-<plugin>-<cmd>` auto-trigger skill (CC-runtime commands skipped). |
| `lib/transform-agent.mjs` | Agent → `codex/agents/<name>.toml` (model omitted, effort mapped, read-only sandbox, `[skills.config]`). |
| `lib/transform-hook.mjs` | Hooks: drop `SessionEnd`, rewrite `PLUGIN_ROOT` in json + scripts, remap matcher tools, copy root data. |
| `lib/transform-manifest.mjs` | Per-plugin `.codex-plugin/plugin.json` + catalog + fidelity disclosure (bundles omitted). |
| `lib/transform-installer.mjs` | `codex/install-agents.sh` + `codex/README.md`. |
| `validate.mjs` | Structural half of the gate (invoked by `../validate-codex.sh`): correspondence, name==dir, uniqueness, TOML validity, pointer resolution. |

## Adding / changing a plugin

Just edit the plugin under `plugins/` as usual, then `node gen.mjs` and commit the
regenerated tree alongside it (see `../../CLAUDE.md`). No generator change needed — new
plugins/skills/commands/agents/hooks are picked up by directory convention.

## When Codex's schema changes

Everything Codex-specific is in `schema.mjs`. Re-verify against live docs (and, if you
have `codex` installed, `codex plugin marketplace add .` in a throwaway `CODEX_HOME`),
update the constants + `SCHEMA_VERSION`, regenerate, and confirm the gate is green.
The fidelity map + accepted degradations are recorded in
`../../taskmaster-docs/specs/2026-07-10-codex-marketplace-parity.md`.
