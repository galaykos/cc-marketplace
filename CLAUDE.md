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

## The four laws (convention)

Proportionality, honest limitation, the theater test, admission. Each was
independently re-derived across this marketplace under a different subject
heading, by authors who did not know the others had written it. A principle with
no home gets rewritten every time it is needed. The evidence — which sites, how
many, in which vocabularies — lives with the doctrine, not here.

The home is the `claude-authoring` plugin's `authoring-skills` skill, "The four
laws", with the derivation in its `references/doctrine.md`. **Cite it; do not
restate it here** — a fifth copy of a law about not keeping copies would be its
own counter-example. Same reasoning as the teeth convention below: it lives in a
plugin because that one SHIPS.

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
Adopted incrementally as plugins are touched, not in a sweep: explicit
`Standing:` markers ship in 6 plugins today (claude-authoring,
code-architecture, orchestration, task-runner, taskmaster,
vercel-skills-scout), plus craft-layer's worked table above. **No script
enforces this** — which puts the convention in its own `recorded` tier, and
saying so is the point.

## Plugin change gates

- `scripts/validate.sh` — structure, frontmatter, SKILL.md 150-line body ceiling (no floor),
  reference resolution, the description linter (max 500 chars, no "Trigger words:"
  lists), and the doc-location rule above. It also blocks leaked internal taskmaster
  jargon (`card NN` / `Finding #N` / `smoke-test #N` / `the backlog`, plural
  forms like `cards NN` included) in shipped plugin `.md` files —
  `references/` AND the plugin-root docs (`README.md` / `CHANGELOG.md` /
  `ROADMAP.md`) are scanned — excluding the taskmaster + task-runner plugins;
  mark a line legitimately quoting the vocab with `<!-- jargon-ok -->`. Same
  file set, same script: a **removed-artifact guard** fails any reference to a
  plugin or skill removed or merged away from this marketplace (typescript,
  vue2, rollout, react-best-practices, the css-family skills, …) unless the
  line discusses the removal itself or carries `<!-- removed-ok -->`;
  `claude-api` must be described as Claude Code's built-in skill, never as a
  marketplace artifact. Same file set: a **host-overlap guard** fails any plugin
  SKILL whose directory name equals a skill Claude Code itself ships (`dataviz`,
  `skill-creator`, `artifact-design`, `claude-api`, `simplify`, …) unless the
  line carries `<!-- host-ok -->` — commands are out of scope, being namespaced
  at the call site. It also gates **routing reachability**: every
  `plugins/skill-router/rules.tsv` glob row must be able to fire under
  `route.sh`'s `match_glob`, which understands only the `**/dir/**` form and
  basename-matches everything else, and README structure (a `###` heading with a
  table header and zero rows fails; a plugin needs a real table ROW, not a prose
  mention). Patterns and rescue lists live in `scripts/lib/plugin-checks.sh`,
  one source shared with the smoke fixtures. A **version-leverage stamp gate**
  (also `plugin-checks.sh`) fails any plugin whose description claims version
  leverage while no skill of its carries a `> Last verified: YYYY-MM-DD — <url>`
  stamp — the input `check-doc-staleness.sh` needs to see that leverage decay.
- `scripts/check-version-bumps.sh` — a plugin whose **functional** files changed
  vs the base ref must bump its `plugin.json` version. New plugins are exempt, and
  so are doc-only changes to a plugin's root `README.md` / `CHANGELOG.md` /
  `ROADMAP.md` — a typo fix there does not demand a semver bump. Since 2026-08-02 it
  also checks **changelog coverage**, and the tier is split on purpose: a plugin
  that HAS a `CHANGELOG.md` must carry an entry for the version it just bumped to
  (`gate`), and one that has none draws a `WARN` naming the consumer's problem. It
  is not hard for everyone because that would demand ~58 backfilled changelogs
  describing releases nobody recorded — invented history in the file whose job is
  history. Adding the file opts a plugin in; `code-review` and `devops` ship the
  worked examples.
- `scripts/context-budget.sh` — BLOCKING token gate vs committed baselines (own
  CI step), across **two** channels since 2026-08-02: **always-on**
  (`context-budget-baseline.json` — descriptions + SessionStart stdout + local
  MCP `tools/list`) and **dynamic** (`context-budget-dynamic-baseline.json` —
  UserPromptSubmit and per-tool hook stdout, measured with a work-shaped prompt
  and a synthetic `Edit`). The dynamic channel was unmetered before that and the
  omission was load-bearing: skill-router alone injects ~2.4k tokens no baseline
  saw. Accept intentional growth with `--update-baseline`, never in CI. Still
  unmetered BY NATURE and reported by name each run rather than scored zero:
  skill BODIES loaded by a routing rule, and remote MCP servers.

- `scripts/generate.sh --check` — BLOCKING chassis-drift gate (own CI step): every
  chassis-generated file (review commands, worker agents, suite uninstalls,
  reminder hooks) must byte-match its template output; regenerate with
  `--write` after editing templates or `.chassis.json`. Two repo-level steps ride
  the same gate and are NOT chassis files: plugin-scout's `catalog.md`, and the
  README **bundle table** between `<!-- generated:bundle-table -->` and
  `<!-- end:bundle-table -->` (rows and the leaf-count sentence come from each
  bundle's `plugin.json` dependencies plus both context-budget baselines — edit
  them by hand and `--check` fails).

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

**Blocking — fails CI.** `.github/workflows/validate.yml` has **23 named steps;
22 can fail the build**, and on a push to `master` only **21** run
(`check-version-bumps.sh` is gated `if: github.event_name == 'pull_request'`).
Beyond the four scripts above: 16 harnesses under `scripts/smoke/`
(template-engine, chassis-template, preserve-block, hook-guard, hook-syntax,
guard, rules-overlap, route-marker, prompt-route, behavioral-verification,
completion-gate-hook, evidence-gate-hook, comment-discipline-hook,
verbosity-hook, preview-guard, `validate-fixtures/parity-check.sh`),
`scripts/smoke/validate-fixtures/role-floors-check.sh`, and the author-time
lints — one shared CI step globbing `plugins/*/scripts/__tests__/*.test.sh`, so
ANY plugin shipping a harness is enforced the moment it lands (taskmaster and
task-runner are the two that do today; the glob was hardcoded to exactly those
two until 2026-08-02, which meant a third plugin's fixtures would have sat
unrun with nothing saying so). Not under `scripts/smoke/`. (`scripts/smoke/canary.sh` is
deliberately NOT a CI step: its own header says it needs a live model; it
stays a local authoring harness.)
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

**Maintainer path, not a gate.** `scripts/retirement-queue.sh` — ranks shipped
skills by the two usage ledgers written since 2026-08-02
(`~/.claude/skill-router/<slug>/surfaced.jsonl`, what the router OFFERED;
`~/.claude/hindsight/<slug>/skills.jsonl`, what was INVOKED). Always exits 0 and
never proposes a deletion: zero invocations proves nobody used it HERE, non-zero
proves it fired and not that it helped, and "never surfaced" mostly measures the
router's coverage — 102 of 126 skills have no `rules.tsv` row at all. It says
where a control/treatment run is worth spending, nothing more.

**Maintainer path, not a gate.** `scripts/remove-plugin.sh` — the sanctioned
plugin-removal script. It rewrites leaf-derived numbers only. Removing a *leaf*
changes every suite that listed it, and those suites' member counts get a `WARN`,
not an edit — so the bundle table at `README.md` drifts on exactly the removal
the script is for. Nothing gates that table.
