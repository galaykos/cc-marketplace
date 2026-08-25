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
  - `evals/<case>/prompt.md` + `evals/<case>/graders/*.md` — prose, but functional:
    `claude plugin eval` reads them as the case definition. Allowed since
    2026-08-20; a design doc parked under `evals/` is still a violation in spirit
    and no script can tell the two apart.

    **Standing of the eval surface itself: `recorded`, not verified** — measured
    2026-08-24. **4 of 71** plugins ship an eval (i18n, nextjs, php, resilience),
    **none** defines a control arm, and `claude plugin eval` is early-access gated
    on this account, so no shipped suite has been run against the runner's schema.
    "Functional" above describes the intended contract, not a checked one. The
    consequence that matters: a grader passing proves nothing about the SKILL
    unless a control arm shows the base model failing the same prompt — and the
    one time that was actually measured
    (`rationale/eval-ablation-2026-08-20.md`), the skill under test scored **zero
    delta in every arm**. Recount before trusting any of these numbers:
    `ls -d plugins/*/evals/*/ | wc -l`.
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
Adopted incrementally as plugins are touched, not in a sweep. **Do not copy a
count from this paragraph — recount it**, the way the retirement-queue and CI-step
numbers below say to, and for the same reason: this sentence said "7 plugins" from
2026-07 until 2026-08-23, by which point it was 13. Recount with
`grep -rl "Standing:" --include='*.md' plugins/ | cut -d/ -f2 | sort -u | wc -l`
(drop `--include` to count hook scripts too). As of 2026-08-24 that is **14** in
shipped `.md` and **18** including hook scripts, plus craft-layer's worked table
above — and the first figures written here, 13/17, were already stale when they
were committed, because a later commit on the same branch added command-guard's
marker. Two days, two stale counts: run the command. **No script enforces the convention** — which puts it in its own
`recorded` tier, and saying so is the point.

## Plugin change gates

- `scripts/validate.sh` — structure, frontmatter, the SKILL.md body budget — **150 lines,
  10,000 bytes, and 300 characters per line** (no floor; the byte and line-length
  measures were added 2026-08-20 because the line count had stopped measuring: one
  skill sat at a frozen 154 lines across 20 commits while its bytes grew 31% and its
  >110-char lines went 2 → 29. Frontmatter, fenced code and table rows are exempt from
  the line-length check, by construction and stated in the check),
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
  failure. A third, `pc_harness_payload`, closes the CONDITION rather than the
  instance: a smoke or `__tests__` harness that exercises a context-keyed hook
  must send a `transcript_path`, because a harness sending only `session_id`
  grades the fallback branch and that is the sole reason three broken hooks
  shipped behind a green suite. Bless with `# context-key-ok:` /
  `# marker-key-ok:` / `# harness-payload-ok: <why>`.
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
  CI step), across **three** channels: **always-on**
  (`context-budget-baseline.json` — descriptions + SessionStart stdout + local
  MCP `tools/list`), **dynamic** (`context-budget-dynamic-baseline.json` —
  UserPromptSubmit and per-tool hook stdout, measured with a **five-prompt
  corpus** (it was four until 2026-08-23; count the strings in the script rather
  than trusting this number) summed per prompt and scored MAX, plus a synthetic `Edit`), and
  **activated** (`context-budget-activated-baseline.json`, added 2026-08-20 —
  the always-on surface re-measured with the state its hooks WAIT for: a terse
  level set, a `brain/INDEX.md` present, manifests to sniff). Each omission was
  load-bearing when it existed: the dynamic channel missed ~2.4k tokens of
  skill-router before 2026-08-02; the always-on pass meters the OFF state, so
  terse read 886 while a switched-on install pays 1,928, and the activated
  channel is +1.2k tokens on `everything` that no baseline saw. The dynamic probe
  was ONE fixed prompt until 2026-08-20 — a hook whose trigger vocabulary missed
  that sentence baselined at 0 forever (api-docs-first did, at a real 52 tokens).
  Accept intentional growth with `--update-baseline`, never in CI.
  `--reconcile` / `--update-official` compare against `claude plugin details`,
  the host's own meter, which reads **1.54x higher** than our bytes/4 estimate
  (12,789 vs 19,667 over the 61 leaves, 2026-08-20,
  `scripts/context-budget-official.json`) because the host charges a
  per-component floor. That mode is **local and WARN-only, not a CI step**:
  `details` resolves by installed name, so a fresh checkout cannot run it. Still
  unmetered BY NATURE and reported by name each run rather than scored zero:
  skill BODIES loaded by a routing rule, remote MCP servers, and any hook waiting
  for state the activated fixture does not know to create.

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
hook; `WARN` for commands and skills** (most commands and skills are not yet
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

**The four are not sufficient, and here is the case that proves it.** On
2026-08-25 a change added a `{{skillHome}}` key to
`templates/review-command.md.tmpl` and did not update
`templates/samples/*.json`. All four scripts passed. `scripts/smoke/chassis-template-tests.sh`
— an unguarded CI step — went red, and the branch was pushed that way.

The reason is structural, not carelessness: `generate.sh --check` renders the REAL
`.chassis.json` objects, every one of which carried the key already; the harness
renders the FROZEN sample fixtures, which did not. **The gate you run and the gate
that breaks can read different inputs.** So:

- Touched anything under `templates/` or a `.chassis.json`? Also run
  `bash scripts/smoke/chassis-template-tests.sh`.
- Touched a hook, or a script a harness drives? Run that harness. `bash scripts/gate-coverage.sh`
  maps checks to the harnesses that exercise them.
- Changed a gate's error STRING? Several harnesses assert exact messages — run the smoke set.
- Not sure? Run the lot; it is minutes, and CI red after a green local pass is the
  failure this note exists to prevent:

```bash
for t in scripts/smoke/*.sh; do [ "$(basename "$t")" = canary.sh ] && continue; bash "$t" >/dev/null || echo "FAIL $t"; done
for t in plugins/*/scripts/__tests__/*.test.sh; do bash "$t" >/dev/null || echo "FAIL $t"; done
```

One measured caveat on running them together: `context-budget.sh` failed once and
passed on re-run while the smoke suite ran concurrently — both mutate scratch
state. Run the budget gate on its own before trusting a red from it.

## Every enforcement surface, by tier

Those four are the ones you invoke. They are **not** all the enforcement, and
"run all four" previously read as if they were. Named by filename and standing,
per the has-teeth convention above:

**Blocking — fails CI.** `.github/workflows/validate.yml` has **29 named steps;
28 can fail the build**, and on a push to `master` only **27** can fail
(`check-version-bumps.sh` is gated `if: github.event_name == 'pull_request'`, so
28 of the 29 run). Recounted 2026-08-25, when adding the source-of-truth harness
step moved every one of them. The figures before that were 28/27/26, recounted
2026-08-17, and stale in both directions before THAT — which is why this file
says, of these numbers specifically: **recount them, do not copy them.** The
command, so the next reader does not have to invent it:

```bash
python3 -c "import re;s=open('.github/workflows/validate.yml').read();t=re.split(r'\n      - name:',s)[1:];f=[x for x in t if 'continue-on-error: true' not in x];print(len(t),'named',len(f),'fail-capable',len([x for x in f if 'pull_request' in x]),'PR-gated')"
```
Beyond the four scripts above: the harnesses under `scripts/smoke/`, each its own
named CI step, and the author-time lints — one shared CI step globbing `plugins/*/scripts/__tests__/*.test.sh`, so
ANY plugin shipping a harness is enforced the moment it lands. **Do not record the
count here** — this paragraph used to name 20 and list them, which was stale within
two commits of being written and contradicted the very sentence you are reading.
Recount instead:

```bash
grep -c 'run: bash scripts/smoke/' .github/workflows/validate.yml   # smoke steps
ls plugins/*/scripts/__tests__/*.test.sh | wc -l                    # plugin harnesses
```
 This sentence has now been wrong twice: it said "taskmaster and
task-runner are the two" long after 18 more had landed, and its replacement — a
fresh recount, accurate the hour it was written on 2026-08-17 — was invalidated by
two later commits *on the same branch*. Recount instead:
`ls plugins/*/scripts/__tests__/*.test.sh | wc -l`, and
`bash scripts/gate-coverage.sh` for which author-time checks a harness actually
exercises. The glob is the right fix precisely because a counted list here is not.
Not under `scripts/smoke/`. (`scripts/smoke/canary.sh` is
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
not an edit.

This paragraph used to end "so the bundle table at `README.md` drifts on exactly
the removal the script is for. Nothing gates that table." **That was false, and
had been since 2026-08-02** — the `generate.sh --check` paragraph above says the
opposite about the same table, so this file contradicted itself for three weeks.
The table IS gated, by inheritance: `remove-plugin.sh` deletes the
`marketplace.json` entry, so a suite still listing the removed leaf hard-fails
`validate.sh`'s all-bundle dependency gate; fixing that dep changes the member
count, which `generate.sh --check` then forces into the table.

Two residuals are real and worth keeping. **(1)** The table is not *self*-gating:
immediately post-removal it shows stale counts while `--check` reports no drift,
because it is consistent with a manifest `validate.sh` has already condemned. So
the failure surfaces as a red build, not as table drift — which is why the WARN
above matters. **(2)** `remove-plugin.sh` hand-`sed`s the `everything` row, which
lives *inside* the `<!-- generated:bundle-table -->` region whose own header says
not to edit those rows by hand. Two writers, one generated region; last writer
wins silently. Nothing gates *that*.

The correction is itself the lesson this section teaches, running backwards: a
gate can be mis-tiered as toothless as easily as a habit can be mis-tiered as a
gate, and the toothless direction is more expensive — it makes someone build what
already exists. `pc_version_stamp` carried the same inversion in its own header
for 21 days after it started blocking.
