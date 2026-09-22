# Repository conventions

This is a Claude Code plugin marketplace. Each `plugins/<name>/` directory is a
publishable plugin.

## Mission (convention)

Every change here exists to make a plugin under `plugins/` better for the people
who install it. The bar a plugin must clear is `README.md`'s opening paragraph:
it carries a rule the model gets wrong from memory, or ships a mechanism prose
cannot replace. Gates, project skills, `rationale/` and this file exist to
protect or author those plugins — none of them is the product. Before an edit,
name the plugin it improves or the gate that protects one; if neither exists,
the edit is out of scope, and that includes polishing this file. **Standing:
`recorded`** — no script reads intent.

## Where documentation lives (enforced)

- **Task documentation, specifications, design docs, and task history live ONLY in
  `taskmaster-docs/`** (a gitignored working area). They must **never** be copied
  into `plugins/`.
- A plugin ships **only functional files**:
  - `.claude-plugin/plugin.json`
  - `README.md` (and optionally `CHANGELOG.md` / `ROADMAP.md`) at the plugin root
  - `skills/<name>/SKILL.md` (+ a `references/` dir for material the skill reads)
  - `commands/*.md`, `agents/*.md`, `hooks/`
  - `evals/<case>/case.yaml`, or `evals/<case>/prompt.md` + `graders/*.md`, or both
    (+ an optional `scaffold.sh`) — the case definition `claude plugin eval` reads.
    On CLI 2.1.270 the two suites shipping the `prompt.md` shape loaded zero cases
    (`invalid case.yaml: graders: Required`) because their `graders/*.md` carried no
    `type:` frontmatter — prose from line 1 — so two of the three shipped suites had
    never run and nobody noticed, because nothing runs them in CI. Both were converted
    to `case.yaml`. The shape itself is valid: a `prompt.md` beside a typed grader
    loaded and scored on 2.1.273 (measured 2026-09-16,
    `rationale/marketplace-trend-audit-2026-09-16.md` A1), and `scripts/eval-cases.sh`
    now gates the frontmatter, not the shape. A `.md` under `evals/` is still allowed —
    a grader body may want its own file — but a design doc parked there is a violation
    in spirit and no script can tell the two apart.

    **Standing of the eval surface itself: `recorded`, and now partly measured.**
    Few plugins ship an eval, and the control arm is supplied by the runner's
    `--ablation with-without` flag (its default when a plugin resolves), not by any
    shipped `case.yaml`. The three suites that existed on 2026-09-14 were executed with a
    control arm on CLI 2.1.270 (suites added since have loaded but not run) — the numbers are in
    `rationale/marketplace-endgame-review-2026-09-14.md` §8 wave D, where the one
    NEGATIVE delta was WITHDRAWN a day later: it did not replicate. Read the amendment,
    not the table above it. Nothing runs them in CI, which is how two dead suites
    survived; a `case.yaml` schema check is a CI step, so a suite that loads zero cases
    fails the build even though no eval is executed there. Two rules that cost $10 to
    learn and are cheap to read:

    - **A case whose CONTROL arm passes cannot measure the skill.** It is a regression
      guard — it catches the plugin breaking something and can never show it helping,
      because there is no headroom above 1.00. Every `resilience` case is in that
      state (recount: `ls -d plugins/resilience/evals/*/ | wc -l`), including two written
      specifically to be hard for the base model.
    - **Three runs cannot separate a regression from a flake.** The −1.00 above was three
      runs agreeing; three more runs a day later disagreed. State the run count and the
      vote spread with any delta, or do not state the delta.

    The consequence that matters: a
    grader passing proves nothing about the SKILL unless a control arm shows the
    base model failing the same prompt — and the one time that was measured by
    hand (`rationale/eval-ablation-2026-08-20.md`), the skill under test scored
    **zero delta in every arm**. Count it, don't quote a count:
    `ls -d plugins/*/evals 2>/dev/null | wc -l`.
  - any code the plugin needs to run (e.g. a `template/`)
- Do **not** put a `design/`, `docs/`, or spec dir inside a plugin to "preserve"
  history. If a document truly must be tracked, it goes in **`rationale/`** at
  the repo root — never inside a plugin. (`taskmaster-docs/` and `docs/` are
  both gitignored, so "move it there" is deletion, not preservation.)
- **Doctrine with exactly one user — this repository — is a tracked project
  skill**, `.claude/skills/<name>/SKILL.md` (+ `references/`), not a plugin: the
  authoring skills moved there 2026-09-03. `.gitignore` re-includes
  `.claude/skills/*/` as a whole, so a new project skill is tracked the moment it
  exists; `validate.sh` holds every non-symlinked one to the same budget, jargon
  and removed-reference gates as a shipped skill.

`scripts/validate.sh` enforces this: any `.md` under `plugins/` that is not one of
the functional kinds above fails the build (and CI on every PR).

## The four laws (convention)

One-clause glosses so a contributor can act without leaving this file:

- **Proportionality** — size the ceremony to the blast radius.
- **Honest limitation** — a gate names what it does NOT catch; state the residual.
- **The theater test** — name what a check catches that nothing else catches.
- **Admission** — an artifact earns existence by carrying a rule nothing else carries.

The home is the `authoring-skills` project skill, `.claude/skills/authoring-skills/SKILL.md`,
"The four laws", with the derivation in its `references/doctrine.md`. **Cite it; do
not restate it here** — a gloss is a citation aid, a fifth full copy of a law about
not keeping copies would be its own counter-example. It was a shipped plugin until
2026-09-03; it is a tracked project skill now because the doctrine has one user,
this repository, and a plugin with one user is the Admission law's own
counter-example. Installers of any one plugin reach it as a repo path, not as an
installed skill — that is a smaller reach than before, stated, not hidden. (Provenance of
the laws: `rationale/four-laws-provenance.md`.)

## Say what has teeth (convention)

When a plugin document states a rule, name its standing — **gate** (a script fails
the build), **agent-graded** (a reviewer judges it, real variance), **recorded**
(written down, nothing reads it back), or **unenforceable** (say why). A reader
cannot tell those apart from the sentence alone, which is how a rule gets trusted
as a guarantee while nothing enforces it.

The canonical statement lives in the `authoring-skills` project skill
(`.claude/skills/authoring-skills/SKILL.md`) — tracked, gated by the same per-file
checks as a shipped skill, and cited by path from every plugin that applies it.
Read it there; do not restate the table here, or the two drift. (Until 2026-09-03
it shipped as a plugin "because that one SHIPS"; it has one user, so it does not.)

Worked examples in-repo: the "What has teeth and what is recorded" table in
`plugins/craft-layer/skills/asset-sourcing/references/component-sourcing.md`.
Adopted incrementally as plugins are touched, not in a sweep. No count here; recount:

```bash
grep -rl "Standing:" --include='*.md' plugins/ | cut -d/ -f2 | sort -u | wc -l
```

**No script enforces the convention** — which puts it in its own `recorded` tier,
and saying so is the point.

## Plugin change gates

Four scripts. **Every derivation below lives in the check's own header** — each
`pc_*` function in `scripts/lib/plugin-checks.sh` carries a header explaining
what it catches, what it does not, and what shipped that made it exist. **Cite
them; do not restate them here** — the same rule this file already applies to the
four laws and the has-teeth convention. What follows is only what you need in hand
while editing.

**Numbers in this file rot.** Every count ever written here went stale within days,
usually in both directions. The file carries one on purpose (the CI step count,
below) and prints a recount command for every other. The record of how each one
went wrong is `rationale/claude-md-incident-log.md` — read it before adding a number
or restating a check's header here; do not add the story back to this file.

- **`scripts/validate.sh`** — structure, frontmatter, reference resolution, README
  structure, routing reachability, the doc-location rule above, and the `pc_*`
  battery in `scripts/lib/plugin-checks.sh` (one source shared with the smoke
  fixtures).

  Numbers you need while writing: **SKILL.md body ≤ 200 lines, ≤ 14,000 bytes,
  ≤ 300 chars per line** (no floor; frontmatter, fenced code and table rows are
  exempt from the line-length check). Frontmatter **`description` + `when_to_use`
  ≤ 500 chars measured TOGETHER** — the CLI lists the pair as one joined string, so
  the gate charges the pair and its FAIL names both keys; no "Trigger words:" list in
  either; `plugin.json` descriptions draw a WARN-only 700-char guideline.

  Escape hatches, when a check is wrong about your line — each needs a reason,
  and the check's header says what a good one looks like:

  | marker | silences |
  |---|---|
  | `<!-- jargon-ok -->` | leaked taskmaster vocabulary (`card NN`, `Finding #N`, `the backlog`) |
  | `<!-- removed-ok -->` | a reference to a plugin/skill removed from this marketplace |
  | `<!-- host-ok -->` | a skill dir or command file whose name collides with one Claude Code ships |
  | `# context-key-ok:` | a PostToolUse one-shot deliberately keyed on `session_id` |
  | `# marker-key-ok:` | a context key deliberately used raw in a path |
  | `# harness-payload-ok:` | a harness deliberately sending no `transcript_path` |
  | `# lane-cofire-ok:` | two artifacts deliberately sharing one `owns` in one phase |
  | `<!-- listing-floor-ok: -->` | a bundle over the floor skill-listing budget that will not declare it |
  | `<!-- false-standing-ok: -->` | a paragraph that names a gate's standing in a way the standing check misreads |
  | `# co-fire-ok: content <a> <b>` | two skills deliberately sharing a body-content trigger |
  | `# prime-ok: <skill>` | a stack skill deliberately primed by more than one entry |
  | `<!-- dispatch-ok -->` | a chassis sample that deliberately dispatches the generic subagent |
  | `<!-- handoff-ok -->` | a line that deliberately hands off to a command outside its bundle |
  | `<!-- scout-name-ok: -->` | a scout catalog row naming a plugin on purpose that the name check rejects |
  | `# env-shebang-ok:` | a registered hook that deliberately keeps `#!/usr/bin/env bash` |
  | `# cwd-mkdir-ok:` | a hook that deliberately `mkdir`s under a payload `cwd` it did not `-d`-test |
  | `# offswitch-ok:` | a hook that reads an off-switch and deliberately omits it from a blocking reason |
  | `<!-- version-tail-ok: -->` | a version-pinning skill whose `Last verified` stamp deliberately carries no `npm:`/`composer:` tail |

  `claude-api` must be described as Claude Code's built-in skill, never as a
  marketplace artifact.

- **`scripts/check-version-bumps.sh`** — a plugin whose **functional** files
  changed vs the base ref must bump `plugin.json`. New plugins are exempt; so are
  doc-only edits to a plugin's root `README.md` / `CHANGELOG.md` / `ROADMAP.md`.
  Changelog coverage is split by tier on purpose: a plugin that HAS a
  `CHANGELOG.md` must carry an entry for the version it just bumped to (**gate**);
  one that has none draws a **WARN** naming the consumer's problem. Adding the file
  opts a plugin in permanently — `code-review` and `devops` are the worked
  examples. It is not hard for everyone because that would demand backfilled
  changelogs describing releases nobody recorded: invented history in the file
  whose job is history. (Recount the split rather than quoting one:
  `ls plugins/*/CHANGELOG.md | wc -l` against `ls -d plugins/*/ | wc -l`.)

- **`scripts/context-budget.sh`** — BLOCKING token gate vs committed baselines,
  three metered channels plus one report-only:

  | channel | baseline | measures |
  |---|---|---|
  | always-on | `scripts/context-budget-baseline.json` | descriptions + SessionStart stdout + local MCP `tools/list` |
  | dynamic | `scripts/context-budget-dynamic-baseline.json` | UserPromptSubmit + per-tool hook stdout, MAX across a prompt corpus and five file shapes |
  | activated | `scripts/context-budget-activated-baseline.json` | the always-on surface with the state its hooks WAIT for |
  | listing (report-only) | — | CLI entry cost (`name + 4 + capped desc`) vs the formula budget: 6,000 chars at the default 200k window, 30,000 at 1M — derivation in the script's `LISTING_*` header |

  Accept intentional growth with `--update-baseline`, **never in CI**, and never
  blanket — a blanket run has moved baselines it should not have (`5192047a`).
  `--reconcile` is local and WARN-only: `claude plugin details` resolves by
  installed name, so a fresh checkout cannot run it.

  Two things it reports rather than scores, and the script names both every run:
  what is unmetered by nature (skill BODIES loaded by a routing rule, remote MCP
  servers, hooks waiting for state the fixture does not create), and why an
  `OVER`/`NEAR` listing status is a **reachability** warning and never a cost one.
  The cost model behind that distinction — and the measurement showing the
  always-on surface is ~1% of a session's spend against 61.8% for cache reads — is
  `rationale/2026-08-31-token-cost-review.md`.

- **`scripts/generate.sh --check`** — BLOCKING chassis-drift gate: every
  chassis-generated file (worker agents, suite uninstalls,
  reminder hooks, boost hooks) must byte-match its template output. Regenerate with `--write`
  after editing anything under `templates/` or a `.chassis.json`. Four repo-level
  steps ride the same gate and are NOT chassis files: stack-scan's scout `catalog.md`,
  and three README blocks — the **bundle table**, the **"Turning things off"** table and
  the **no-suite leaf list** — each between `<!-- generated:<name> -->` and
  `<!-- end:<name> -->` markers; edit those rows by hand and `--check` fails. The
  review-command template was retired 2026-09-22 (it rendered one file); the four
  surviving renderers are worker agents, reminder hooks, boost hooks, suite uninstalls.

## Lanes: who owns what, and when (convention + gate)

Every plugin declares its artifacts' territory in its own `plugins/<name>/lane.tsv`
— six tab-separated fields, `artifact kind phase owns definite_trigger yields_to`.
The file is **per-plugin and shipped**, not a central registry, because the two jobs
separate cleanly: collision detection happens at author time, where `validate.sh`
reads the whole repo, while turn-taking happens at runtime, where an artifact must
resolve its OWN lane from `${CLAUDE_PLUGIN_ROOT}/lane.tsv` even when its plugin is
installed alone. A central file would have privileged `skill-router`, which not every
bundle includes.

`phase` is the arc: `understand shape decide plan build verify review ship`, or
**`any`** for a guard that must fire at every point (a Stop gate, an irreversible-
command warning). Declaring `any` is a real claim, not an escape hatch — it exempts
the artifact from the phase sentinel.

**Standing: `gate` for agents, for plugins shipping a `UserPromptSubmit`/`Stop`
hook, and for Pre/PostToolUse hooks that can return a DENY verdict; `WARN` for
commands and skills** (most commands and skills are not yet
declared — adopting them is incremental, not a sweep). The checks live in
`scripts/lib/plugin-checks.sh` — `pc_lanes_schema`, `pc_lanes_authority` (a plugin
may declare only its OWN artifacts), `pc_lanes_resolve`, `pc_lanes_territory` (two
artifacts must not claim one `owns` in one `phase` without a `yields_to` edge or a
`# lane-cofire-ok:` blessing in either file), `pc_lanes_coverage`, and
`pc_lanes_vocabulary` (an `owns` noun must be declared in
`scripts/lane-vocabulary.txt`). Recount rather than copy a number:
`grep -c '^pc_lanes_[a-z_]*() {' scripts/lib/plugin-checks.sh`. Plus
`pc_phase_guard`: a hook whose lane names a specific phase must read
`.claude/cc-phase.json`. That last one gates the READ only — no gate can prove an
artifact honours the verdict on every branch, so the behaviour half is
**agent-graded**, and saying so is the point.

Run the four gates plus the host validator before pushing:

```bash
bash scripts/validate.sh
bash scripts/check-version-bumps.sh master
bash scripts/context-budget.sh
bash scripts/generate.sh --check
OFFICIAL_VALIDATE_ANY_VERSION=1 bash scripts/official-validate.sh   # the host's validator, --strict; last fail-capable CI step
```

`official-validate.sh` pins the CLI version CI installs and FAILs locally the moment
your CLI auto-updates past it — which it does every few days. The env var skips only
the pin check; CI still asserts it. Bump the pin in the script and in
`.github/workflows/validate.yml` together when the CI version moves.

**`check-version-bumps.sh` reads `HEAD`, not your working tree** (`:36`,
`git diff "$base"...HEAD`). Every other gate above reads the files on disk. So running it
before you commit is structurally blind to the commit you are about to make: a plugin file
you have edited but not committed draws no FAIL locally and does draw one in CI. **Run it
again after committing, before pushing.** Measured 2026-09-15 — a `generate.sh --write`
regenerated stack-scan's scout catalog, the local pass was green because the change was
still uncommitted, and CI went red on the next push. This is the same "the gate you run and
the gate that breaks can read different inputs" lesson as the chassis-sample case below,
reached by a different route: there the INPUTS differ, here the REVISION does.

**The four are not sufficient, and here is the case that proves it.** On
2026-08-25 a change added a `{{skillHome}}` key to
`templates/review-command.md.tmpl` and did not update
`templates/samples/*.json`. All four scripts passed. `scripts/smoke/chassis-template-tests.sh`
— an unguarded CI step — went red, and the branch was pushed that way.

The reason is structural, not carelessness: `generate.sh` ENRICHES every chassis
manifest before rendering — `skillHome` is computed and injected by the script
(grep `skillHome` in `generate.sh`; a line number here went stale once already),
so `--check` never sees a manifest missing it, and no
`.chassis.json` on disk contains the key at all. The harness feeds the FROZEN
sample fixtures to the template engine raw, so those must carry every key
literally, and did not. **The gate you run and the gate
that breaks can read different inputs.** So:

- Touched anything under `templates/` or a `.chassis.json`? Also run
  `bash scripts/smoke/chassis-template-tests.sh`.
- Touched a hook, or a script a harness drives? Run that harness. `bash scripts/gate-coverage.sh`
  maps checks to harnesses that MENTION them by name — its own header says a hit
  is a mention, not proof of exercise, so it over-reports.
- Changed a gate's error STRING? Several harnesses assert exact messages — run the smoke set.
- Not sure? Run the lot; it is minutes, and CI red after a green local pass is the
  failure this note exists to prevent:

```bash
for t in scripts/smoke/*.sh scripts/smoke/validate-fixtures/*.sh; do [ "$(basename "$t")" = canary.sh ] && continue; bash "$t" >/dev/null || echo "FAIL $t"; done   # live-model scripts skip themselves; see below
for t in plugins/*/scripts/__tests__/*.test.sh; do bash "$t" >/dev/null || echo "FAIL $t"; done
```

One measured caveat on running them together: `context-budget.sh` failed once and
passed on re-run while the smoke suite ran concurrently — both mutate scratch
state. Run the budget gate on its own before trusting a red from it.

## Every enforcement surface, by tier

Those four are the ones you invoke. They are **not** all the enforcement. Named
by filename and standing,
per the has-teeth convention above:

**Blocking — fails CI.** `.github/workflows/validate.yml` has **39 named steps;
37 can fail the build**, and on a push to `master` only **36** can fail
(`check-version-bumps.sh` is gated `if: github.event_name == 'pull_request'`).
This is the one count deliberately carried here and nowhere else
(`scripts/done-gate.sh:7` says why); **recount it, do not copy it**:

```bash
python3 -c "import re;s=open('.github/workflows/validate.yml').read();t=re.split(r'\n      - name:',s)[1:];f=[x for x in t if 'continue-on-error: true' not in x];print(len(t),'named',len(f),'fail-capable',len([x for x in f if 'pull_request' in x]),'PR-gated')"
```
Beyond the four scripts above: the harnesses under `scripts/smoke/`, each its own
named CI step; the author-time lints — one shared CI step globbing `plugins/*/scripts/__tests__/*.test.sh`, so
ANY plugin shipping a harness is enforced the moment it lands; and the host's own
validator, `claude plugin validate --strict` over every plugin and the marketplace
manifest, run through `scripts/official-validate.sh` (pinned CLI version asserted;
it catches manifest SCHEMA errors `validate.sh` never models, and nothing about
SKILL.md frontmatter — its header says why). **Do not record the count here**;
recount:

```bash
grep -c 'run: bash scripts/smoke/' .github/workflows/validate.yml   # smoke steps
ls plugins/*/scripts/__tests__/*.test.sh | wc -l                    # plugin harnesses
bash scripts/gate-coverage.sh   # which author-time checks a harness exercises
```

The glob is the right fix precisely because a counted list here is not.
(`scripts/smoke/canary.sh` is deliberately NOT a CI step: its own header says it
needs a live model; it stays a local authoring harness. **A live-model script under
`scripts/smoke/` must refuse to run without an explicit opt-in env var** —
`listing-eviction-probe.sh` needs `LISTING_PROBE=1` — because the pre-push loop above
skips exactly one file BY NAME, so the second such script silently spent real model
calls on anyone who followed the instruction. The skip list is not the mechanism; the
script defending itself is.)
CI can still be red after a green local four-script pass: several of those
harnesses assert **exact gate message strings**, so rewording a gate's error
breaks CI even when the gate itself still works.

**Warn-only in CI.** `scripts/check-doc-staleness.sh` — its step carries
`continue-on-error: true` and the script `exit 0`s on every path by contract.
It reports; it never fails anything. Age is its only default signal, and age
missed the Astryx digest (49 days old, materially wrong after a 0.x minor).
`--live` compares the stamp's `npm:<pkg>@<major>[.<minor>]` tail against npm
and HEADs the URL; `--inventory` prints one row per stamp. The re-read no
script can do is the `digest-refresh` project skill,
`.claude/skills/digest-refresh/SKILL.md` — invoke it when a row warns or a
user asks whether something is stale.

**Blocking — fails the turn.** `scripts/done-gate.sh`, a `Stop` hook wired in
`.claude/settings.json`. A Stop hook can reach the model two ways — stdout
`{"decision":"block","reason":…}` with exit 0, or exit 2 with a reason on
stderr. This one uses exit 2, printing that JSON blob to stderr, so the model
receives it as raw prose.

**Advisory — never blocks.** `scripts/authoring-guard.sh`, a `PostToolUse` hook
on every `Edit`/`Write`, fail-open by its own declaration (`:2-3`). It warns; it
cannot stop anything. Counting it as enforcement is the tier over-claim this
file's own convention forbids.

**Maintainer path, not a gate.** `scripts/turn-cost.sh` — the only instrument
here that meters something other than bytes: **turn blocks**, one human
instruction and the model requests it took. Always exits 0; withholds any
per-plugin ratio below `--min-blocks`; prints its own attribution coverage and
its blind spots (subagent turns are invisible and are billed). **`--skills` is
the retirement queue** — it absorbed `scripts/retirement-queue.sh` (deleted
2026-08-31: it defaulted to the current project, where neither ledger had records,
and answered with an empty table — the records existed in the projects where plugins
are used, which that default never read). The mode joins
shipped skills against the router ledger, the hindsight ledger AND transcript
`attributionSkill` records, names which sources had data, and keeps the original
doctrine: zero proves nobody used it HERE, non-zero proves it fired and not that
it helped, and it says where a control/treatment run is worth spending — nothing
more. Why this channel and not the byte ones, and what it measured:
`rationale/2026-08-31-token-cost-review.md`. Cite it; do not restate its numbers
here. The unrouted count is not recorded here — recount:

```bash
python3 -c "import glob,os;s={os.path.basename(os.path.dirname(p)) for p in glob.glob('plugins/*/skills/*/SKILL.md')};r=open('plugins/skill-router/rules.tsv').read();print(sum(1 for x in s if f'\t{x}\t' not in r),'of',len(s),'unrouted')"
```

**Maintainer path, not a gate.** `scripts/remove-plugin.sh` — the sanctioned
plugin-removal script; dry-run by default, edits with `--apply`. It rewrites
leaf-derived numbers only. Removing a *leaf* changes every suite that listed it,
and those suites' member counts get a `WARN`, not an edit.

The README bundle table **is** gated, by inheritance rather than directly:
`remove-plugin.sh` deletes the `marketplace.json` entry, so a suite still listing
the removed leaf hard-fails `validate.sh`'s all-bundle dependency gate; fixing
that dep changes the member count, which `generate.sh --check` then forces into
the table. One residual is real: the table is not *self*-gating, so immediately
post-removal it shows stale counts while `--check` reports no drift — the failure
surfaces as a red build rather than as table drift, which is why the WARN above
matters.

A gate can be mis-tiered as toothless as easily as a habit can be mis-tiered as a
gate, and the toothless direction is more expensive — it makes someone build what
already exists. Both directions have happened here; the incident log has the cases.
