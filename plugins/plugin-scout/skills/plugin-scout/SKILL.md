---
name: plugin-scout
description: Use when setting up Claude Code plugins for a project — "which plugins should I install", "what plugins fit this repo", starting in a repo without marketplace plugins, or right after cloning an unfamiliar codebase: scans manifests, suggests every marketplace plugin in three tiers; `--yes` auto-installs tiers 1-2, `--persist`/`--global` pick project or user scope.
---

## Purpose

Scan the current project and suggest **every leaf plugin in the marketplace**, in
three tiers — tier 1 stack-specific (signal-earned, evidence cited), tier 2 the
curated any-project core (useful regardless of stack), tier 3 the universal
remainder — then install what the user picks, paging the picker until every row
was offered. `--yes` is the auto-installer: it installs tiers 1 and 2 with no
picker. Tier 3 never auto-installs.

## Preflight

- Run `claude plugin marketplace list`. If `cc-plugins-marketplace` is absent,
  ask via AskUserQuestion: "Add marketplace (Recommended)" / "Stop". On the
  recommended pick, run `claude plugin marketplace add galaykos/cc-marketplace`
  before anything else. Headless: print that add command, then continue in
  command-printing mode (see Install).
- Run `claude plugin list` and record the installed set — it drives the
  installed column of the report and filters the install choices.
- If the `claude` CLI is unavailable, continue anyway: skip installed-detection
  (mark the column unknown) and fall back to printing install commands at the
  Install step instead of running them.

## Detection

If the stack-scan plugin is installed, run `/stack-scan:report` and use its inventory output
(required vs installed, manifests already parsed) as the detection input — actually invoke
it; do not re-scan what it already reads. Otherwise self-scan: read composer.json,
package.json, tsconfig.json, .env, and Dockerfile/docker-compose files, checking exactly the
signal table below. Rules:

- Detection is read-only. Never install anything and never run package
  managers (composer, npm, yarn, pnpm, bun) during detection.
- A signal counts only with evidence: the file plus the dependency or line
  that triggered it. No evidence, no tier-1 suggestion.
- Missing manifests are fine — absence of composer.json simply means no PHP
  signals, not a failure.

## Stack signals (tier 1)

Six plugins, each earned by one signal:

| Signal (evidence file) | Plugin |
|---|---|
| composer.json require laravel/framework | laravel |
| composer.json require inertiajs/inertia-laravel OR package.json @inertiajs/* | inertia |
| package.json dep react-native | react-native |
| package.json dep next | nextjs |
| package.json dep vite (devDependencies counts) | vite |
| mariadb docker image or DSN | mariadb |

Vue 2, plain JavaScript, and TypeScript map to no plugin — those plugins were removed
after baseline testing (rationale/stack-skill-baselines.md). On a vue ^2 dep or an
ambiguous vue major (constraint spans majors, or lock and manifest disagree), suggest
nothing for vue; one report line names the constraint — never guess vue3 from ambiguity.

`sql` has no tier-1 signal and stays in the remainder — it is a cross-engine
floor referenced by the per-dialect skills, not a stack pick.

Also read `references/signals.md`: its evidence-bearing rows (CI, compose, OpenAPI,
payment keys, locales, LLM keys, otel — plus rows for stacks this marketplace does NOT
cover) count as tier-1 signals, same evidence rule, and join the `--yes` auto-install set.

## Any-project core (tier 2)

Read `references/any-core.md` — the curated list of plugins judged useful in any
project regardless of stack, each row carrying its one-line why. Core rows carry the
evidence string "core", sort directly after tier 1, and join the `--yes` auto-install
set. The list is curated, not derived: re-judge it against `references/catalog.md`
when plugins land or leave.

## Universal remainder (tier 3)

Read `references/catalog.md` (generated — one `name — [keywords] — description` row per
marketplace plugin). Tier 3 is **every catalog plugin not already in tier 1 or 2**,
excluding the bundles (`everything` and any `*-suite`) and `plugin-scout` itself, plus
every unfired tier-1 table plugin (evidence: "no signal detected" — a missed signal
demotes, never drops). Suggest all of it, with "universal" as the evidence for the rest,
reading each row's keywords and description to phrase the suggestion. Do not hard-code a
plugin list here — the catalog is the source of truth and stays in sync as plugins change.

## Report

Print one table:

| # | Plugin | Tier | Evidence | Installed |
|---|---|---|---|---|
| 1 | laravel | 1 | composer.json: laravel/framework ^11 | — |
| 2 | debugging | 2 | core | ✓ |

- Evidence cites file and line for tier 1; tier-2 rows say "core"; tier-3 rows
  say "universal", or "no signal detected" for an unfired stack plugin.
  Installed column: ✓ when `claude plugin list` shows it, — otherwise.
- **Completeness rule:** every catalog plugin except the bundles and plugin-scout
  itself appears in the table exactly once — no leaf silently omitted. Recount the
  eligible set from `references/catalog.md`, never from a number written here.
- Under the table, list each not-installed suite whose dependency list covers
  3+ suggested not-installed rows, with the rows it bundles (e.g. "php-suite
  bundles #1-#4, #9") — suite-as-shortcut rules: `references/picker.md`.
- Zero stack signals → print the report with the note "no stack signals
  found"; tiers 2 and 3 still print in full.

## Install

1. Without `--yes`: offer rows as explicit options at maximum density — one call holds 4
multiSelect questions x 4 options (16 slots); page until every eligible suggestion was
offered. Installed rows are never options; rows overlapping an installed plugin's
category sort last within their tier. Tier 1 leads the first page with evidence, core
rows follow; one slot per call is
"Stop — skip remaining"; Other accepts numbers/names/ranges. Full contract:
`references/picker.md`. Headless: print install commands for every not-installed
suggestion instead, then stop. With `--yes`: skip this picker — see Flags below for the
auto-select set. 2. For each pick, run via Bash:

   ```bash
   claude plugin install <name>@cc-plugins-marketplace --scope local
   ```

That is the only install command form — no bundles here. `--scope local` keeps installs
repo-only (`.claude/settings.local.json`, gitignored); `--persist` → `--scope project`,
`--global` → `--scope user` (Flags below). 3. Report per-plugin success or failure as
each finishes (a failure does not abort the rest); one summary line: installed n,
failed m, skipped k (already installed). 4. With `--persist`, write what actually
installed this run into the project's settings — see Flags below.

## Flags

- `--yes` — the auto-installer: installs every tier-1 signal-backed and tier-2 core
plugin not yet installed, instead of showing the picker; the full report still prints
first. Tier-3 rows are never auto-installed. Zero auto-installable picks: report only,
with a hint to rerun without `--yes` to pick tier-3. The marketplace-add preflight
prompt is unchanged by `--yes`. Full rules: `references/flags.md`.
- `--persist` — switches installs this run to `--scope project` and ensures the
  marketplace entry in the project's `.claude/settings.json` so teammates who clone
  get the same set; covers only what actually installed this run. Full merge/abort
  rules and the required commit-trust notice: `references/flags.md`.
- `--global` — switches installs this run to `--scope user`: machine-wide user
  settings, enabling each plugin in every repo on this machine. Mutually exclusive
  with `--persist` — both at once aborts before any install. Full rules and the
  required machine-wide notice: `references/flags.md`.

## Boundaries

- Suggests and installs only cc-plugins-marketplace plugins; it does not
  audit, configure, or uninstall anything.
- Detection never mutates the project — no lockfile writes, no installs, no
  package-manager invocations.
- If every suggestion is already installed, say so and stop; do not invent
  work.
