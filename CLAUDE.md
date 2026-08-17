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
  both gitignored, so "move it there" is deletion, not preservation.)

`scripts/validate.sh` enforces this: any `.md` under `plugins/` that is not one of
the functional kinds above fails the build (and CI on every PR).

## The four laws (convention)

One-clause glosses so a contributor can act without leaving this file:

- **Proportionality** — size the ceremony to the blast radius.
- **Honest limitation** — a gate names what it does NOT catch; state the residual.
- **The theater test** — name what a check catches that nothing else catches.
- **Admission** — an artifact earns existence by carrying a rule nothing else carries.

The home is the `claude-authoring` plugin's `authoring-skills` skill, "The four
laws", with the derivation in its `references/doctrine.md`. **Cite it; do not
restate it here** — a gloss is a citation aid, a fifth full copy of a law about
not keeping copies would be its own counter-example. Same reasoning as the teeth
convention below: it lives in a plugin because that one SHIPS. (Provenance of
the laws: `rationale/four-laws-provenance.md`.)

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
`Standing:` markers ship in 7 plugins today (claude-authoring,
code-architecture, orchestration, task-runner, taskmaster, terse,
vercel-skills-scout), plus craft-layer's worked table above. **No script
enforces this** — which puts the convention in its own `recorded` tier, and
saying so is the point.

## Plugin change gates

- `scripts/validate.sh` — structure, frontmatter, SKILL.md 150-line body ceiling (no floor),
  reference resolution, the description linter (max 500 chars for frontmatter
  descriptions, no "Trigger words:" lists; plugin.json descriptions get a
  WARN-only 700-char clarity guideline), and the doc-location rule above. It also blocks leaked internal taskmaster
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
  stamp — the stamp is the input `check-doc-staleness.sh` reads to detect that
  leverage decaying. Two paired checks guard hook **one-shot state**:
  `pc_context_key` fails a PostToolUse hook that keys on `session_id` (a subagent
  shares its parent's, so the worker gets deduped against nudges it never saw),
  and `pc_marker_key` fails a hook that then interpolates that key **raw into a
  filesystem path** — `transcript_path` is an absolute path, so the marker lands
  nowhere and the bound it records silently stops existing. The first gates the
  read, the second gates that the value is usable; neither can see the other's
  failure. Bless with `# context-key-ok:` / `# marker-key-ok: <why>`.
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
  omission was load-bearing: at the time skill-router alone injected ~2.4k
  tokens no baseline saw (~2.6k as of 2026-08-11). Accept intentional growth
  with `--update-baseline`, never in CI. Still
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

## Lanes: who owns what, and when (convention + gate)

Every plugin declares its artifacts' territory in its own `plugins/<name>/lane.tsv`
— six tab-separated fields, `artifact kind phase owns definite_trigger yields_to`.
The file is **per-plugin and shipped**, not a central registry, because the two jobs
separate cleanly: collision detection happens at author time, where `validate.sh`
reads the whole repo, while turn-taking happens at runtime, where an artifact must
resolve its OWN lane from `${CLAUDE_PLUGIN_ROOT}/lane.tsv` even when its plugin is
installed alone. A central file would have privileged `skill-router`, which ships in
only 5 of 10 bundles.

`phase` is the arc: `understand shape decide plan build verify review ship`, or
**`any`** for a guard that must fire at every point (a Stop gate, an irreversible-
command warning). Declaring `any` is a real claim, not an escape hatch — it exempts
the artifact from the phase sentinel.

**Standing: `gate` for agents and for plugins shipping a `UserPromptSubmit`/`Stop`
hook; `WARN` for commands and skills** (99 commands and 129 skills are not yet
declared — adopting them is incremental, not a sweep). Five checks in
`scripts/lib/plugin-checks.sh`: `pc_lanes_schema`, `pc_lanes_authority` (a plugin
may declare only its OWN artifacts), `pc_lanes_resolve`, `pc_lanes_territory` (two
artifacts must not claim one `owns` in one `phase` without a `yields_to` edge or a
`# lane-cofire-ok:` blessing in either file), and `pc_lanes_coverage`. Plus
`pc_phase_guard`: a hook whose lane names a specific phase must read
`.claude/cc-phase.json`. That last one gates the READ only — no gate can prove an
artifact honours the verdict on every branch, so the behaviour half is
**agent-graded**, and saying so is the point.

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

**Blocking — fails CI.** `.github/workflows/validate.yml` has **28 named steps;
27 can fail the build**, and on a push to `master` only **26** can fail
(`check-version-bumps.sh` is gated `if: github.event_name == 'pull_request'`, so
27 of the 28 run). Recounted 2026-08-17 — the previous figures were stale in
both directions, which is the same trap this file names for the retirement-queue
number below: **recount these, do not copy them.**
Beyond the four scripts above: 20 harnesses under `scripts/smoke/`
(template-engine, chassis-template, preserve-block, hook-guard, hook-syntax,
guard, rules-overlap, route-marker, prompt-route, lanes, prime-map, behavioral-verification,
completion-gate-hook, evidence-gate-hook, comment-discipline-hook,
verbosity-hook, preview-guard, versioned-layout, marker-key,
`validate-fixtures/parity-check.sh`),
`scripts/smoke/validate-fixtures/role-floors-check.sh`, and the author-time
lints — one shared CI step globbing `plugins/*/scripts/__tests__/*.test.sh`, so
ANY plugin shipping a harness is enforced the moment it lands (**20 plugins ship
28 harness files** as of 2026-08-17; the glob was hardcoded to exactly taskmaster
and task-runner until 2026-08-02, which meant a third plugin's fixtures would
have sat unrun with nothing saying so — and this sentence still said "the two
that do today" long after 18 more had landed, which is why the glob was the right
fix and a counted list here is not). Not under `scripts/smoke/`. (`scripts/smoke/canary.sh` is
deliberately NOT a CI step: its own header says it needs a live model; it
stays a local authoring harness.)
CI can still be red after a green local four-script pass: several of those
harnesses assert **exact gate message strings**, so rewording a gate's error
breaks CI even when the gate itself still works.

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
router's coverage — **91 of 129** skills have no `rules.tsv` row at all (recounted
2026-08-16; the previous "99 of 126" was stale, and a recorded-tier number in the
conventions file getting trusted as a measurement is exactly what this file warns
about — recount it, do not copy it). It says
where a control/treatment run is worth spending, nothing more.

**Maintainer path, not a gate.** `scripts/remove-plugin.sh` — the sanctioned
plugin-removal script. It rewrites leaf-derived numbers only. Removing a *leaf*
changes every suite that listed it, and those suites' member counts get a `WARN`,
not an edit — so the bundle table at `README.md` drifts on exactly the removal
the script is for. Nothing gates that table.
