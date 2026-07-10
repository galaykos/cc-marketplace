# Repository conventions

This is a Claude Code plugin marketplace. Each `plugins/<name>/` directory is a
publishable plugin.

## Where documentation lives (enforced)

- **Task documentation, specifications, design docs, and task history live ONLY in
  `taskmaster-docs/`** (a gitignored working area). They must **never** be copied
  into `plugins/`.
- A plugin ships **only functional files**:
  - `.claude-plugin/plugin.json`
  - `README.md` (and optionally `CHANGELOG.md` / `ROADMAP.md`) at the plugin root
  - `skills/<name>/SKILL.md` (+ a `references/` dir for material the skill reads)
  - `commands/*.md`, `agents/*.md`, `hooks/`
  - any code the plugin needs to run (e.g. a `template/`)
- Do **not** put a `design/`, `docs/`, or spec dir inside a plugin to "preserve"
  history. If a document truly must be tracked, it goes in a repo-level location
  **outside** `plugins/` — never inside one.

`scripts/validate.sh` enforces this: any `.md` under `plugins/` that is not one of
the functional kinds above fails the build (and CI on every PR).

## Plugin change gates

- `scripts/validate.sh` — structure, frontmatter, SKILL.md 100–150-line body budget,
  reference resolution, and the doc-location rule above.
- `scripts/check-version-bumps.sh` — a plugin whose files changed vs the base ref
  must bump its `plugin.json` version (new plugins are exempt).
- `scripts/validate-codex.sh` — the Codex mirror is fresh (see below): regenerating
  yields no diff, correspondence holds, no `CLAUDE_PLUGIN_ROOT`/`SessionEnd` leaks.

Run all three before pushing:

```bash
bash scripts/validate.sh
bash scripts/check-version-bumps.sh master
bash scripts/validate-codex.sh
```

## Codex marketplace (generated — never hand-edit)

This repo is ALSO an OpenAI Codex marketplace. `plugins/` is canonical; the Codex
tree (`.agents/plugins/marketplace.json`, `codex/**`, `AGENTS.md`) is **derived
one-way** by `scripts/gen-codex/` (a Node generator; see its `README.md`). Never edit
those by hand — `validate-codex.sh` fails on any drift.

**When you change a plugin, regenerate and commit the Codex tree in the same commit:**

```bash
node scripts/gen-codex/gen.mjs        # or: bash scripts/validate-codex.sh --regen
git add plugins/<changed> .agents codex AGENTS.md
```

Codex plugin versions mirror the CC `plugin.json` version automatically, so the
version bump you make for `check-version-bumps.sh` propagates. Skip the regen and CI
(the Codex gate) goes red. The generator writes nothing under `plugins/`.
