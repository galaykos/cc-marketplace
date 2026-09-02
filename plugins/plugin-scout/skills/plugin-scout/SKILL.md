---
name: plugin-scout
description: Use when setting up Claude Code plugins for a project — "which plugins should I install", "what plugins fit this repo", starting in a repo without marketplace plugins, or right after cloning an unfamiliar codebase: scans manifests, suggests every marketplace plugin in three tiers; `--yes` auto-installs tiers 1-2, `--persist`/`--global` pick project or user scope, `--all` offers every row explicitly.
---

## Purpose

Scan the current project and suggest **every leaf plugin in the marketplace**, in
three tiers — tier 1 stack-specific (signal-earned, evidence cited), tier 2 the
curated any-project core (useful regardless of stack), tier 3 the universal
remainder — then install what the user picks. `--yes` is the auto-installer: it
installs tiers 1 and 2 with no picker. Tier 3 never auto-installs.

## Preflight

- Run `claude plugin marketplace list`. If `cc-plugins-marketplace` is absent, ask via
  AskUserQuestion: "Add marketplace (Recommended)" / "Stop". On the recommended pick, run
  `claude plugin marketplace add galaykos/cc-marketplace` (add `--scope project` under
  `--persist`) first. Headless **without** `--yes`: print that command, continue in
  command-printing mode. Headless **with** `--yes`: stop before Detection (flags.md).
- Record the installed set — it drives the installed marks and filters the
  picker. `claude plugin list` alone is **machine-wide**: a plugin installed in an
  unrelated repo would be marked installed here and silently dropped from the
  picker. Filter to this project, then union all three settings files — the CLI does not
  always report a `--persist` write it made, and never reports a hand-edited entry:

  ```bash
  claude plugin list --json | jq -r --arg root "$PWD" \
    '[.[] | select(.enabled and (.scope=="user" or .projectPath==$root))] | .[].id'
  jq -r '.enabledPlugins // {} | to_entries[] | select(.value) | .key' \
    .claude/settings.json .claude/settings.local.json ~/.claude/settings.json 2>/dev/null
  ```

- No `claude` CLI: mark installed-state unknown and print install commands
  instead of running them.

## Detection

Resolve `[path]` (default: repo root) as the scan root and read composer.json,
package.json, `.env`/`.env.example`, and Dockerfile/docker-compose there, checking
the table below plus `references/signals.md`. If the root manifest declares
`workspaces`, or a `pnpm-workspace.yaml`/`turbo.json` exists, also scan member
manifests one level deep and cite `<member>/package.json` — otherwise a Turborepo
whose apps hold every framework reports "no stack signals found". Installs always
target the session's project root regardless of `[path]`.

If stack-scan is installed, run `/stack-scan:report` for version truth (EOL majors,
lockfile drift) and fold it into the evidence — but **run the signal table anyway**;
it is not a replacement (nine dependency names, no `.env`, no `react-native`). Take
its inventory only, never its offer to fix red flags: that deletes a lockfile inside
a read-only step.

- Detection is read-only: never install anything, never run a package manager (composer,
  npm, yarn, pnpm, bun).
- A signal counts only with evidence: the file plus the dependency or key that triggered
  it. No evidence, no tier-1 suggestion. Missing manifests are fine — no composer.json
  simply means no PHP signals.

## Stack signals (tier 1)

Six framework plugins, each earned by one signal. "dep X" means an **exact key**
in `dependencies` or `devDependencies`, never a substring: `next-auth` is not
`next`, `react-native-web` is not `react-native`.

| Signal (evidence file) | Plugin |
|---|---|
| composer.json require laravel/framework | laravel |
| composer.json require inertiajs/inertia-laravel OR package.json @inertiajs/* | inertia |
| package.json dep react-native | react-native |
| package.json dep next | nextjs |
| package.json dep vite (devDependencies counts) AND a vite.config.* at the scan root | vite |
| compose/Dockerfile image matching `mariadb`, `.env.example` DB_CONNECTION=mariadb, or `mariadb` in composer.json/package.json | mariadb |

Read `.env.example`, not just `.env` — `.env` is gitignored in every Laravel and Next
scaffold, so on this skill's headline case (a fresh clone) it is absent. Known miss,
inherited from skill-router: a repo with `DB_CONNECTION=mysql` that actually runs
MariaDB earns no mariadb row. Vue, plain JavaScript and TypeScript map to no plugin —
removed after baseline testing (`rationale/stack-skill-baselines.md`, marketplace repo
only); a `vue` dep of any major earns no row and no note.

`references/signals.md` holds the rest of the evidence-bearing signals — CI, compose,
OpenAPI, payment keys, auth deps, Tailwind, SQL, ORMs, LLM keys, otel, perf and retry
libraries, plugin manifests, plus rows for stacks this marketplace does NOT cover. Its
hits are tier-1 signals under the same evidence rule and join the `--yes` set. A `—` in
its Suggest column is an answer, not a gap: route onward instead of padding tier 3.

## Any-project core (tier 2)

Read `references/any-core.md` — plugins judged useful in any project regardless of stack,
each row carrying its why and the two-part membership test. Core rows carry the evidence
string "core", sort directly after tier 1, and join the `--yes` set. Curated, not derived:
re-judge it against `references/catalog.md` when plugins land or leave.

## Universal remainder (tier 3)

Read `references/catalog.md` (generated — one `name — [keywords] — description` row per
marketplace plugin). Tier 3 is **every catalog plugin not already in tier 1 or 2**,
excluding the bundles (any `*-suite`) and `plugin-scout` itself, plus
every unfired tier-1 candidate from **either** the table above or
`references/signals.md` (evidence: "no signal detected" — a missed signal demotes,
never drops). Suggest all of it, with "universal" as the evidence for the rest, reading
each row's keywords and description to phrase the suggestion. Do not hard-code a plugin
list here — the catalog is the source of truth. The bundle filter is a name test because
catalog rows carry no `dependencies` key; it holds for every bundle shipping today, and a
future bundle named otherwise would be offered as a leaf.

**Then judge, once.** Tier 3 is defined by subtraction, so nothing enters it because of
this project — read `references/relevance.md` and lift 3-5 rows that fit THIS repo into a
`worth a look here` group leading the block, each with a one-line **reason**, never
evidence. No extra questions, no promotion to tier 1, never `--yes`; zero beats padding.

## Report

Print a numbered inventory grouped by tier — a header line (eligible count, installed
count, detected stack), then one block per tier, tier 3 grouped by catalog keyword and
led by its `worth a look here` group. **Not** one five-column table over every row —
sample, layout, and why that table is the wrong rendering: `references/picker.md`.

- Evidence prints only where a signal earned it — the file plus the key that matched,
  with a line number when the scan produced one. Tier 2 is "core" and tier 3 "universal"
  by definition; neither needs a repeated cell. A lifted row prints its reason instead,
  and reasons never appear in an evidence column.
- Installed rows carry `✓` inline and are not pickable; the header count replaces
  a constant column.
- **Completeness rule:** every catalog plugin except the bundles and plugin-scout
  itself appears exactly once — no leaf omitted, no group truncated with "and N
  more". Recount from `references/catalog.md`, never from a number written here.
- Under the inventory, list each not-installed suite whose dependencies cover 3+
  suggested not-installed rows — rules: `references/picker.md`.
- Zero stack signals → note "no stack signals found"; tiers 2 and 3 still print in
  full, and the relevance pass matters most in exactly that repo. If a
  `references/signals.md` `—` row fired, lead with its routing line instead.

## Install

1. Without `--yes`: **one** AskUserQuestion call. Questions 1-3 hold the tier-1
signal-backed rows (evidence cited) then the tier-2 core rows, 4 options each;
question 4 is the tier-3 door — browse the remainder / print its install commands /
just the picks above / stop. Every tier-3 row stays reachable by number, name or range
through any Other, and via `scripts/pick.sh`. `--all` pages every row as an explicit
option instead (~5 calls). Installed rows are never options. Full contract:
`references/picker.md`. Headless: print install commands for every not-installed
suggestion, then stop. With `--yes`: skip the picker — see Flags.

2. For each pick, run via Bash:

   ```bash
   claude plugin install <name>@cc-plugins-marketplace --scope local
   ```

That is the only install command form; a suite picked from the under-report shortcut list
(`references/picker.md`) installs by the same command and scope rules, and only `--yes`
never installs a bundle. `--scope local` keeps installs
repo-only (`.claude/settings.local.json`); `--persist` → `--scope project`, `--global` →
`--scope user` (Flags). Always pass `--scope`: the CLI's own default is `user`.

3. Success is **exit status 0**; a missing plugin or unknown marketplace exits 1
   and prints `✘ Failed to install`. Never infer success from stdout. Report each
   result as it finishes (a failure does not abort the rest); one summary line:
   installed n, failed m, skipped k (already installed). Then print `Run
   /reload-plugins to load these in this session (or restart Claude Code) —
   nothing installed this run is active until you do`, naming any write-time hooks
   installed (secret-scanning, command-guard). With `--persist`, verify what
   actually installed is reflected in the project's settings — Flags below.

## Flags

- `--yes` — the auto-installer: installs every tier-1 signal-backed and tier-2 core plugin
not yet installed, instead of showing the picker; the full report still prints first. Tier
3 never auto-installs, relevance-lifted rows included. Zero auto-installable picks: report
only, with a hint to rerun without `--yes`. Full rules: `references/flags.md`.
- `--all` — offers every eligible row as an explicit picker option, paging until all
appeared (the pre-0.12 default). Picker-only; no effect under `--yes`.
- `--persist` — switches installs to `--scope project` and verifies the marketplace
entry and the CLI's `enabledPlugins` writes in the project's `.claude/settings.json`,
so teammates who clone get the same set; covers only what actually installed this run.
Never hand-author an entry for a failed install. Full rules: `references/flags.md`.
- `--global` — switches installs to `--scope user`: machine-wide, every repo on this
machine. Mutually exclusive with `--persist` — both at once aborts before Preflight.
Full rules and the required machine-wide notice: `references/flags.md`.

## Boundaries

Tiered once, in Standing below — not restated here. Suggests and installs only
cc-plugins-marketplace plugins; it does not audit, configure, or uninstall (an uninstall
command under `--persist` is printed for the user, never run). Detection and the
relevance pass never mutate the project: no lockfile writes, installs, package-manager
invocations, or delegated fix prompts. If every suggestion is already installed, say so
and stop.

## Standing

**Agent-graded.** No script checks that a tier-1 row cited its evidence, that the sweep
ran, that detection stayed read-only, that the picker offered the door, or that the
relevance pass gave reasons instead of padding. Gated by name only: catalog freshness
(`generate.sh --check`), plugin names in the three TABLE lists of this file,
`references/signals.md` and `references/any-core.md` (`pc_scout_names` — it does not read
`references/relevance.md`), `scripts/pick.sh` parity (`pc_pick_parity`) and its parser
(`scripts/__tests__/pick.test.sh`), body budget (`pc_skill_budget`), token cost
(`context-budget.sh`). The evidence rule binds tier 1 only.
