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

A plugin's prose asserts things. Some of those are checked by a script, some are
judged by an agent, and some are only written down. **Those three are not the same
strength, and a reader cannot tell them apart from the sentence alone** — which is
how a rule gets trusted as a guarantee for months before anyone notices nothing
was enforcing it.

Every one of the last review's findings had this shape: a Latin-only copy detector
whose comment described the bug it reintroduced; a composition axis drawn every run
and checked by nothing; a gate copied into builds and silently going stale; a
"never write component details from memory" rule broken three times in one session
by the model that had it loaded. In each case the rule existed and read as binding.

So when a plugin document states a rule, name its standing:

| Standing | Means | Example phrasing |
| --- | --- | --- |
| **gate** | a script fails the build | "`divergence.mjs`, check `spine-register`, exit 1" |
| **agent-graded** | a reviewer agent judges it, with real variance | "`craft-reviewer`, agent-graded — finding, no script" |
| **recorded** | written to an artifact, nothing reads it back | "recorded, not gated — no log column, no assertion" |
| **unenforceable** | cannot be checked as stated; say why | "import-grep cannot discriminate inherited from chosen" |

`craft-layer` and `taskmaster` do this today — see the "What has teeth and what is
recorded" table in `plugins/craft-layer/skills/asset-sourcing/references/component-sourcing.md`
for the shape worth copying. **No script enforces this convention** (which is itself
the `recorded` tier, and stating that is the point). It binds new plugins and any
document being edited; the rest adopt it as they are touched, not in a sweep.

Naming a blind spot is not an admission of weakness — an agent-graded check is a
real check with known variance, and calling it a gate is the over-claim.

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
