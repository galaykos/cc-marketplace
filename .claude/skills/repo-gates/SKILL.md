---
name: repo-gates
description: Use when a validate.sh check or a CI step fails in this marketplace repo, when a FAIL names an escape-hatch marker, when editing a plugin's lane.tsv, when adding or editing a gate, check or smoke harness, or when asking which check enforces a rule. Holds the marker table, the lane checks, each gate script's details and every enforcement surface by tier.
---

`CLAUDE.md` holds the day-one rules and the pre-push commands. This skill holds what you need
when a check fails or changes. Each check's own header says what it catches and what it misses;
cite the header, do not restate it.

## Escape hatches

Escape hatches, when a check is wrong about your line — each needs a reason, and the check's
header says what a good one looks like:

| marker | silences |
|---|---|
| `<!-- jargon-ok -->` | leaked taskmaster vocabulary (`card NN`, `Finding #N`, `the backlog`) |
| `<!-- removed-ok -->` | a reference to a plugin/skill removed from this marketplace |
| `<!-- host-ok -->` | a skill dir or command file whose name collides with one Claude Code ships |
| `# context-key-ok:` | a PostToolUse one-shot deliberately keyed on `session_id` |
| `# marker-key-ok:` | a context key deliberately used raw in a path |
| `# harness-payload-ok:` | a harness deliberately sending no `transcript_path` |
| `# lane-cofire-ok:` | two artifacts deliberately sharing one `owns` in one phase |
| `<!-- false-standing-ok: -->` | a paragraph that names a gate's standing in a way the standing check misreads |
| `# co-fire-ok: content <a> <b>` | two skills deliberately sharing a body-content trigger |
| `# prime-ok: <skill>` | a stack skill deliberately primed by more than one entry |
| `<!-- dispatch-ok -->` | a chassis sample that deliberately dispatches the generic subagent |
| `<!-- handoff-ok -->` | a line whose `plugin:name` token deliberately resolves to no artifact (a Blade tag, a quoted bad name) |
| `<!-- scout-name-ok: -->` | a scout catalog row naming a plugin on purpose that the name check rejects |
| `# env-shebang-ok:` | a registered hook that deliberately keeps `#!/usr/bin/env bash` |
| `# cwd-mkdir-ok:` | a hook that deliberately `mkdir`s under a payload `cwd` it did not `-d`-test |
| `# state-root-ok:` | a hook whose `.claude/` state is deliberately per-directory, built from the raw payload `cwd` instead of `cc_state_root` |
| `# offswitch-ok:` | a hook that reads an off-switch and deliberately omits it from a blocking reason |
| `<!-- version-tail-ok: -->` | a version-pinning skill whose `Last verified` stamp deliberately carries no `npm:`/`composer:` tail |
| `<!-- shadow-ok: <why> -->` | a command and a skill of the same name in one plugin, kept on purpose (the command's description shadows the skill's in the listing) |
| `<!-- tool-fit-ok: <why> -->` | a paragraph that tells a tool-limited agent to run, hash or write something on purpose (`pc_agent_tool_fit`) |

## The gate scripts

### `scripts/validate.sh`

It checks structure, frontmatter, reference resolution, README structure, routing reachability
and the doc-location rule in `CLAUDE.md`. It also holds the no-`dependencies` rule
(`pc_plugin_dependencies`; the measurement that made it is in
`rationale/derivations/scripts-lib.md` § pc_plugin_dependencies). The rest is the `pc_*` battery
in `scripts/lib/plugin-checks.sh`, one source shared with the smoke fixtures.

### `scripts/check-version-bumps.sh`

`CLAUDE.md` states the bump rule, its exemptions and the changelog entry. Changelog coverage is
split by tier on purpose: a plugin with no `CHANGELOG.md` draws a **WARN** naming the consumer's
problem instead of a FAIL. Adding the file opts a plugin in permanently — `code-review` and
`devops` are the worked examples. It is not hard for everyone because that would demand
backfilled changelogs describing releases nobody recorded: invented history in the file whose job
is history. (Recount the split rather than quoting one: `ls plugins/*/CHANGELOG.md | wc -l`
against `ls -d plugins/*/ | wc -l`.)

### `scripts/context-budget.sh`

BLOCKING token gate vs committed baselines, three metered channels plus one report-only:

| channel | baseline | measures |
|---|---|---|
| always-on | `scripts/context-budget-baseline.json` | descriptions + SessionStart stdout + local MCP `tools/list` |
| dynamic | `scripts/context-budget-dynamic-baseline.json` | UserPromptSubmit + per-tool hook stdout, MAX across a prompt corpus and five file shapes |
| activated | `scripts/context-budget-activated-baseline.json` | the always-on surface with the state its hooks WAIT for |
| listing (report-only) | — | CLI entry cost (`name + 4 + capped desc`) vs the formula budget: 6,000 chars at the default 200k window, 30,000 at 1M — derivation in `rationale/derivations/scripts.md` § scripts/context-budget.sh |

Accept intentional growth with `--update-baseline`, **never in CI**, and never blanket — a
blanket run has moved baselines it should not have (`5192047a`). `--reconcile` is local and
WARN-only: `claude plugin details` resolves by installed name, so a fresh checkout cannot run it.

It reports two things rather than scoring them, and the script names both every run. One is what
is unmetered by nature: skill BODIES loaded by a routing rule, remote MCP servers, hooks waiting
for state the fixture does not create. The other is why an `OVER`/`NEAR` listing status is a
**reachability** warning and never a cost one. The cost model behind that distinction — and the
measurement showing the always-on surface is ~1% of a session's spend against 61.8% for cache
reads — is `rationale/2026-08-31-token-cost-review.md`.

### `scripts/generate.sh --check`

BLOCKING chassis-drift gate: every chassis-generated file (worker agents, reminder hooks, boost
hooks) must byte-match its template output. `CLAUDE.md` says when to run `--write`. Two
repo-level steps ride the same gate and are NOT chassis files. One is stack-scan's scout
`catalog.md`. The other is one README block, the **"Turning things off"** table, between
`<!-- generated:offswitch-table -->` and `<!-- end:offswitch-table -->`; edit those rows by hand
and `--check` fails.

### `scripts/official-validate.sh`

`official-validate.sh` pins the CLI version CI installs and FAILs locally the moment your CLI
auto-updates past it — which it does every few days. `OFFICIAL_VALIDATE_ANY_VERSION=1` skips only
the pin check; CI still asserts it. Bump the pin in the script and in `.github/workflows/validate.yml` together when
the CI version moves.

## Lanes: who owns what, and when

Every plugin declares its artifacts' territory in its own `plugins/<name>/lane.tsv` — six
tab-separated fields, `artifact kind phase owns definite_trigger yields_to`. The file is
**per-plugin and shipped**, not a central registry, because the two jobs separate cleanly.
Collision detection happens at author time, where `validate.sh` reads the whole repo. Turn-taking
happens at runtime, where an artifact must resolve its OWN lane from
`${CLAUDE_PLUGIN_ROOT}/lane.tsv` even when its plugin is installed alone. A central file would
have privileged `skill-router`, which not every install includes.

`phase` is the arc: `understand shape decide plan build verify review ship`, or **`any`** for a
guard that must fire at every point (a Stop gate, an irreversible-command warning). Declaring
`any` is a real claim, not an escape hatch — it exempts the artifact from the phase sentinel.

**Standing: `gate` for agents, for plugins shipping a `UserPromptSubmit`/`Stop` hook, and for
Pre/PostToolUse hooks that can return a DENY verdict; `WARN` for commands and skills.** Most
commands and skills are not yet declared; adopting them is incremental, not a sweep. The checks
live in `scripts/lib/plugin-checks.sh`:

- `pc_lanes_schema`
- `pc_lanes_authority` — a plugin may declare only its OWN artifacts
- `pc_lanes_resolve`
- `pc_lanes_territory` — two artifacts must not claim one `owns` in one `phase` without a
  `yields_to` edge or a `# lane-cofire-ok:` blessing in either file
- `pc_lanes_adjacency` — WARN: too many artifacts on one file shape in one phase
- `pc_lanes_coverage`
- `pc_lanes_vocabulary` — an `owns` noun must be declared in `scripts/lane-vocabulary.txt`

Recount rather than copy a number: `grep -c '^pc_lanes_[a-z_]*() {' scripts/lib/plugin-checks.sh`.
Plus `pc_phase_guard`: a hook whose lane names a specific phase must read `.claude/cc-phase.json`.
That last one gates the READ only — no gate can prove an artifact honours the verdict on every
branch, so the behaviour half is **agent-graded**, and saying so is the point.

## Every enforcement surface, by tier

The four scripts in `CLAUDE.md` are the ones you invoke; they are **not** all the enforcement.
`references/enforcement-tiers.md` names every surface by file and standing: what else fails CI,
what only warns, the Stop hook, the advisory hook and the maintainer paths. Read it when CI is red
after a green local run, or to answer which check enforces a rule.

A gate can be mis-tiered as toothless as easily as a habit can be mis-tiered as a gate, and the
toothless direction is more expensive — it makes someone build what already exists. Both
directions have happened here; `rationale/claude-md-incident-log.md` has the cases.
