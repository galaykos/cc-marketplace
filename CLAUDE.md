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
  history. If a document truly must be tracked, it goes in **`rationale/`** at
  the repo root — never inside a plugin. (`taskmaster-docs/` and `docs/` are
  both gitignored, so "move it there" is deletion, not preservation. Until
  `rationale/` existed this rule named no reachable destination.)

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

- `scripts/validate.sh` — structure, frontmatter, SKILL.md 150-line body ceiling (no floor),
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

## Every enforcement surface, by tier

Those four are the ones you invoke. They are **not** all the enforcement, and
"run all four" previously read as if they were. Named by filename and standing,
per the has-teeth convention above:

**Blocking — fails CI.** `.github/workflows/validate.yml` has **19 named steps;
18 can fail the build**, and on a push to `master` only **17** run
(`check-version-bumps.sh` is gated `if: github.event_name == 'pull_request'`).
Beyond the four scripts above: 12 harnesses under `scripts/smoke/`
(template-engine, chassis-template, hook-guard, hook-syntax, guard,
rules-overlap, route-marker, behavioral-verification, completion-gate-hook,
comment-discipline-hook, preview-guard, `validate-fixtures/parity-check.sh`),
`role-floors-check.sh`, and the taskmaster author-time lints, which live at
`plugins/taskmaster/scripts/__tests__/*.test.sh` — not under `scripts/smoke/`.
A local four-script pass can still be red on merge: several of those harnesses
assert **exact gate message strings**, so rewording a gate's error breaks CI.

**Warn-only in CI.** `scripts/check-doc-staleness.sh` — its step carries
`continue-on-error: true` and the script `exit 0`s on every path by contract.
It reports; it never fails anything.

**Blocking — fails the turn.** `scripts/done-gate.sh`, a `Stop` hook wired in
`.claude/settings.json`. A Stop hook can reach the model two ways — stdout
`{"decision":"block","reason":…}` with exit 0, or exit 2 with a reason on
stderr. This one uses exit 2, printing that JSON blob to stderr, so the model
receives it as raw prose.

**Advisory — never blocks.** `scripts/authoring-guard.sh`, a `PostToolUse` hook
on every `Edit`/`Write`, fail-open by its own declaration (`:2-3`). It warns; it
cannot stop anything. Counting it as enforcement is the tier over-claim this
file's own convention forbids.

**Maintainer path, not a gate.** `scripts/remove-plugin.sh` — the sanctioned
plugin-removal script. It rewrites leaf-derived numbers only. Removing a *leaf*
changes every suite that listed it, and those suites' member counts get a `WARN`,
not an edit — so the bundle table at `README.md` drifts on exactly the removal
the script is for. Nothing gates that table.
