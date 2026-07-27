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

## Say what has teeth (convention)

When a plugin document states a rule, name its standing — **gate** (a script fails
the build), **agent-graded** (a reviewer judges it, real variance), **recorded**
(written down, nothing reads it back), or **unenforceable** (say why). A reader
cannot tell those apart from the sentence alone, which is how a rule gets trusted
as a guarantee while nothing enforces it.

The canonical statement lives in the `claude-authoring` plugin's `authoring-skills`
skill, because that one SHIPS — a convention that exists only in this file reaches
contributors to this repo and nobody who installs from it. Read it there; do not
restate the table here, or the two drift.

Worked examples in-repo: the "What has teeth and what is recorded" table in
`plugins/craft-layer/skills/asset-sourcing/references/component-sourcing.md`.
`craft-layer` and `taskmaster` follow it today; the rest adopt it as they are
touched, not in a sweep. **No script enforces this** — which puts the convention
in its own `recorded` tier, and saying so is the point.

## Plugin change gates

- `scripts/validate.sh` — structure, frontmatter, SKILL.md 100–150-line body budget,
  reference resolution, the description linter (max 500 chars, no "Trigger words:"
  lists), and the doc-location rule above. It also blocks leaked internal taskmaster
  jargon (`card NN` / `Finding #N` / `smoke-test #N` / `the backlog`) in shipped
  plugin `.md` files (`references/` included), excluding the taskmaster + task-runner
  plugins; mark a line legitimately quoting the vocab with `<!-- jargon-ok -->`.
- `scripts/check-version-bumps.sh` — a plugin whose files changed vs the base ref
  must bump its `plugin.json` version (new plugins are exempt).
- `scripts/context-budget.sh` — BLOCKING per-leaf description-token gate vs the
  committed baseline (own CI step); accept intentional growth with
  `--update-baseline`, never in CI.

- `scripts/generate.sh --check` — BLOCKING chassis-drift gate (own CI step): every
  chassis-generated file (review commands, worker agents, suite uninstalls,
  reminder hooks) must byte-match its template output; regenerate with
  `--write` after editing templates or `.chassis.json`.

Run all four before pushing:

```bash
bash scripts/validate.sh
bash scripts/check-version-bumps.sh master
bash scripts/context-budget.sh
bash scripts/generate.sh --check
```
