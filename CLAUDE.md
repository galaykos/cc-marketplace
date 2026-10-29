# Repository conventions

This is a Claude Code plugin marketplace. Each `plugins/<name>/` directory is a publishable plugin.

## Mission (convention)

Every change here exists to make a plugin under `plugins/` better for the people who install it. The
bar a plugin must clear is `README.md`'s opening paragraph: it carries a rule the model gets wrong
from memory, or ships a mechanism prose cannot replace. Gates, project skills, `rationale/`
and this file exist to protect or author those plugins; none of them is the product. Before an edit,
name the plugin it improves or the gate that protects one. If neither exists, the edit is out of
scope, and that includes polishing this file. **Standing: `recorded`** — no script reads intent.

## Where documentation lives (enforced)

- **Task documentation, specifications, design docs and task history live ONLY in
  `taskmaster-docs/`**, a gitignored working area. Never copy them into `plugins/`.
- A plugin ships **only functional files**:
  - `.claude-plugin/plugin.json`
  - `README.md` (and optionally `CHANGELOG.md` / `ROADMAP.md`) at the plugin root
  - `skills/<name>/SKILL.md` (+ a `references/` dir for material the skill reads)
  - `commands/*.md`, `agents/*.md`, `hooks/`
  - a mod plugin's module: the `hooks/` file its `hooks.json` `modules` entry names, the `hooks/`
    files it imports, its `types/index.d.ts` contract and its `tests/*.test.ts`. One entry per
    plugin; `.ts` `.tsx` `.mts` `.cts` `.js` `.mjs`; nested allowed. **Standing: gate.**
    `pc_mod_modules` checks the entry exists, has an allowed extension and exports `register`.
    `pc_mod_kit` checks every `cc-kit.ts` copy is byte-identical. `scripts/mod-tests.sh` runs
    `claude plugin test` on every mod; a red test, a missing test file or modules turned off fails.
    The host validator fails a `$.state` key the `types` contract does not declare. The
    CLI-generated `.claude-plugin/types/` and root `tsconfig.json` are gitignored, never shipped.
  - `evals/<case>/case.yaml`, or `evals/<case>/prompt.md` + `graders/*.md`, or both (+ an optional
    `scaffold.sh`): the case definition `claude plugin eval` reads. See "Evals" below.
  - any code the plugin needs to run (e.g. a `template/`)
- Do **not** put a `design/`, `docs/` or spec dir inside a plugin to "preserve" history. A document
  that truly must be tracked goes in **`rationale/`** at the repo root, never inside a plugin.
  (`taskmaster-docs/` and `docs/` are both gitignored, so "move it there" is deletion, not
  preservation.)
- **Doctrine with exactly one user, this repository, is a tracked project skill**:
  `.claude/skills/<name>/SKILL.md` (+ `references/`), not a plugin. `.gitignore` re-includes
  `.claude/skills/*/` as a whole, so a new project skill is tracked the moment it exists.
  `validate.sh` holds every non-symlinked one to the same budget, jargon and removed-reference gates
  as a shipped skill.

`scripts/validate.sh` enforces this: any `.md` under `plugins/` that is not one of the functional
kinds above fails the build (and CI on every PR).

## Evals

`scripts/eval-cases.sh` gates each grader's `type:` frontmatter, not the case shape. A `.md` under
`evals/` is allowed, since a grader body may want its own file. A design doc parked there breaks the
doc-location rule in spirit, and no script can tell the two apart. **Standing of the eval surface
itself: `recorded`.** Few plugins ship an eval; count them, do not quote a count:
`ls -d plugins/*/evals 2>/dev/null | wc -l`. The runner's `--ablation with-without` flag supplies
the control arm (its default when a plugin resolves); no shipped `case.yaml` does. Nothing runs
evals in CI. A `case.yaml` schema check is a CI step, so a suite that loads zero cases fails the
build even though no eval runs there. Two rules:

- **A case whose control arm passes cannot measure the skill.** It is a regression guard. It catches
  the plugin breaking something and can never show it helping, because there is no headroom above
  1.00. Every `resilience` case is in that state (recount:
  `ls -d plugins/resilience/evals/*/ | wc -l`).
- **Three runs cannot separate a regression from a flake.** State the run count and the vote spread
  with any delta, or do not state the delta.

So a grader passing proves nothing about the skill unless a control arm shows the base model failing
the same prompt. For measured runs, read the amendment in `rationale/marketplace-endgame-review-2026-09-14.md`
§8 wave D, not the table above it. The story is in `rationale/claude-md-incident-log.md`.

## The four laws (convention)

One-clause glosses, so you can act without leaving this file:

- **Proportionality** — size the ceremony to the blast radius.
- **Honest limitation** — a gate names what it does NOT catch; state the residual.
- **The theater test** — name what a check catches that nothing else catches.
- **Admission** — an artifact earns existence by carrying a rule nothing else carries.

The home is the `authoring-skills` project skill, `.claude/skills/authoring-skills/SKILL.md`, "The
four laws", with the derivation in its `references/doctrine.md`. **Cite it; do not restate it
here.** A gloss is a citation aid. A fifth full copy of a law about not keeping copies would be its
own counter-example. Installers of any one plugin reach it as a repo path, not as an installed
skill. (Provenance of the laws: `rationale/four-laws-provenance.md`.)

## Say what has teeth (convention)

When a plugin document states a rule, name its standing: **gate** (a script fails the build),
**agent-graded** (a reviewer judges it, real variance), **recorded** (written down, nothing reads it
back), or **unenforceable** (say why). A reader cannot tell those apart from the sentence alone.
That is how a rule gets trusted as a guarantee while nothing enforces it. The canonical statement
lives in the `authoring-skills` project skill (`.claude/skills/authoring-skills/SKILL.md`). It is
tracked, gated by the same per-file checks as a shipped skill, and cited by path from every plugin
that applies it. Read it there; do not restate the table here, or the two drift.

Worked example: the "What has teeth and what is recorded" table in
`plugins/craft-layer/skills/asset-sourcing/references/component-sourcing.md`. Adopt the convention
as plugins are touched, not in a sweep. No count here; recount:

```bash
grep -rl "Standing:" --include='*.md' plugins/ | cut -d/ -f2 | sort -u | wc -l
```

**No script enforces the convention**, so it sits in its own `recorded` tier; saying so is the point.

## Before the edit

**Load the authoring skill before the edit.** Editing a hook → `authoring-hooks` (plus
`hook-bash-writes` when it must see Bash writes); a SKILL.md → `authoring-skills`; an agent →
`authoring-agents`; a command → `authoring-commands`; a chassis-generated file → `chassis-workflow`.
Load it in the thread that edits; name its path in a dispatch so a worker reads it. **Standing: `recorded`.**

**Every check, hook and script says in its own header what it catches and what it does not**, in at
most three comment lines. The derivation moves verbatim to `rationale/derivations/<file>.md` under a
`## <path>` heading: what shipped that made it exist, measurements, incident dates. The code keeps
one pointer, `# Why, limits, history: rationale/derivations/<file>.md § <heading>`. Apply it as
files are touched, not in a sweep; existing long headers are debt, not precedent. **Standing:
`recorded`** — no gate reads a header. Recount the files already following it:
`grep -rl 'Why, limits, history: rationale/derivations' plugins scripts | wc -l`. **Cite headers; do
not restate them here**, as this file does for the four laws and the has-teeth convention.

**Numbers in this file rot.** Every count ever written here went stale within days, usually in both
directions. The file carries one on purpose, the CI step count below, and prints a recount command
for every other. Read `rationale/claude-md-incident-log.md` before adding a number or restating a
check's header here. Add the story there, not here.

Numbers and rules you need while writing:

- **SKILL.md body ≤ 200 lines, ≤ 14,000 bytes, ≤ 300 chars per line** (`scripts/validate.sh`,
  gate), with no floor. Frontmatter, fenced code and table rows skip the line-length check.
- **Frontmatter `description` + `when_to_use` ≤ 500 chars, measured TOGETHER** (`scripts/validate.sh`,
  gate). The CLI lists the pair as one joined string, so the gate charges the pair and its FAIL
  names both keys. No "Trigger words:" list in either.
- `plugin.json` descriptions draw a WARN-only 700-char guideline.
- A plugin whose **functional** files changed vs the base ref must bump `plugin.json`
  (`scripts/check-version-bumps.sh`). New plugins are exempt, and so are doc-only edits to a
  plugin's root `README.md` / `CHANGELOG.md` / `ROADMAP.md`. A plugin that has a `CHANGELOG.md` also
  needs an entry for the new version (**gate**).
- `claude-api` must be described as Claude Code's built-in skill, never as a marketplace artifact.
- A new agent, or a Stop / UserPromptSubmit / DENY-capable hook, needs a `lane.tsv` row (**gate**;
  details in `repo-gates` § Lanes).

## Before you push

Run the four gates plus the host validator:

```bash
bash scripts/validate.sh
bash scripts/check-version-bumps.sh master
bash scripts/context-budget.sh
bash scripts/generate.sh --check
OFFICIAL_VALIDATE_ANY_VERSION=1 bash scripts/official-validate.sh   # the host's validator, --strict; the env var skips only the CLI pin check
```

A FAIL you do not understand → the `repo-gates` skill.

**`check-version-bumps.sh` reads `HEAD`, not your working tree** (its `changed=` line,
`git diff "$base"...HEAD`). Every other gate above reads the files on disk. Before you commit,
it cannot see the commit you are about to make. A plugin file you edited but did not commit draws no
FAIL locally but does draw one in CI. **Run it again after committing, before pushing.**

**The gate you run and the gate that breaks can read different inputs.** So:

- Touched anything under `templates/` or a `.chassis.json`? Regenerate with
  `bash scripts/generate.sh --write`, then also run `bash scripts/smoke/chassis-template-tests.sh`.
  That harness feeds the frozen `templates/samples/*.json` fixtures to the template engine raw, so
  they must carry every key literally.
- Touched a hook, or a script a harness drives? Run that harness. `bash scripts/gate-coverage.sh`
  maps checks to harnesses that MENTION them by name. Its own header says a hit is a mention, not
  proof of exercise, so it over-reports.
- Changed a gate's error STRING? Several harnesses assert exact messages, so run the smoke set.
- Not sure? Run the lot. It takes minutes, and CI red after a green local pass is the failure this
  note exists to prevent:

```bash
for t in scripts/smoke/*.sh scripts/smoke/validate-fixtures/*.sh; do [ "$(basename "$t")" = canary.sh ] && continue; bash "$t" >/dev/null || echo "FAIL $t"; done   # live-model scripts skip themselves; see below
for t in plugins/*/scripts/__tests__/*.test.sh; do bash "$t" >/dev/null || echo "FAIL $t"; done
bash scripts/mod-tests.sh
```

The loop skips exactly one file by name, `canary.sh`. So a live-model script under `scripts/smoke/`
must refuse to run without an explicit opt-in env var; `listing-eviction-probe.sh` needs
`LISTING_PROBE=1`. The skip list is not the mechanism; the script defending itself is.

Run `context-budget.sh` on its own before trusting a red from it. It failed once and passed on
re-run while the smoke suite ran concurrently; both mutate scratch state.

## CI step count

`.github/workflows/validate.yml` has **51 named steps; 49 can fail the build**. On a push to
`master` only **48** can fail: `check-version-bumps.sh` is gated
`if: github.event_name == 'pull_request'`. This is the one count deliberately carried here and
nowhere else (`scripts/done-gate.sh:3` says why). **Recount it, do not copy it:**

```bash
python3 -c "import re;s=open('.github/workflows/validate.yml').read();t=re.split(r'\n      - name:',s)[1:];f=[x for x in t if 'continue-on-error: true' not in x];print(len(t),'named',len(f),'fail-capable',len([x for x in f if 'pull_request' in x]),'PR-gated')"
```

## When a check fails, or you change one

Load the `repo-gates` project skill, `.claude/skills/repo-gates/SKILL.md`: escape-hatch markers, lanes, gate details, every enforcement surface.
