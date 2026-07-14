---
name: plugin-scout
description: Use when setting up Claude Code plugins for a project, when the user asks "which plugins should I install" or "what plugins fit this repo", when starting work in a repo without marketplace plugins, or right after cloning an unfamiliar codebase — scans manifests (composer.json, package.json, tsconfig.json, .env, Dockerfiles) for stack signals, suggests cc-plugins-marketplace plugins in two tiers (stack-matched and always-useful), and installs the picked ones after confirmation. Supports `--yes` (auto-install tier-1 signal-backed picks, skipping the picker) and `--persist` (write the installed set into the project's settings.json).
---

## Purpose

Scan the current project, suggest marketplace plugins in two tiers — tier 1
stack-specific (earned by a detection signal, evidence cited) and tier 2
universal (always useful, no signal needed) — then install exactly the ones
the user picks. Nothing installs without an explicit pick.

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

If the stack-scan plugin is installed, reuse its inventory output (required vs
installed, manifests already parsed) as the detection input — do not re-scan
what it already read. Otherwise self-scan: read composer.json, package.json,
tsconfig.json, .env, and Dockerfile/docker-compose files, checking exactly the
signal table below. Rules:

- Detection is read-only. Never install anything and never run package
  managers (composer, npm, yarn, pnpm, bun) during detection.
- A signal counts only with evidence: the file plus the dependency or line
  that triggered it. No evidence, no tier-1 suggestion.
- Missing manifests are fine — absence of composer.json simply means no PHP
  signals, not a failure.

## Stack signals (tier 1)

Eighteen plugins, each earned by one signal:

| Signal (evidence file) | Plugin |
|---|---|
| composer.json exists | php |
| composer.json require laravel/framework | laravel |
| composer.json require livewire/livewire | livewire |
| composer.json require inertiajs/inertia-laravel OR package.json @inertiajs/* | inertia |
| package.json dep react (and NOT react-native) | react |
| package.json dep react-native | react-native |
| package.json dep vue ^2 | vue2 |
| package.json dep vue ^3 | vue3 |
| package.json dep next | nextjs |
| package.json dep nuxt | nuxt |
| package.json dep typescript OR tsconfig.json exists | typescript |
| package.json exists AND no typescript dep (devDependencies counts) AND no tsconfig.json | javascript |
| package.json dep express OR fastify OR @nestjs/core | node-backend |
| package.json dep vite (devDependencies counts) | vite |
| .env DB_CONNECTION=mysql OR mysql docker image | mysql |
| mariadb docker image or DSN | mariadb |
| pgsql/postgres DSN or docker image | postgresql |
| facebook/graph SDK deps (composer or npm) | meta-api |

When the vue major is ambiguous (constraint spans majors, or lock and manifest
disagree), ask via AskUserQuestion: "Vue 3 (Recommended)" / "Vue 2" — never
guess. Headless: suggest neither vue plugin; add a report line naming the
ambiguous constraint instead.

`sql` has no tier-1 signal and stays in the universal set — it is a
cross-engine floor referenced by the per-dialect skills, not a stack pick.

## Universal set (tier 2)

Read `references/catalog.md` (generated — one `name — [keywords] —
description` row per marketplace plugin). The tier-2 universal set is **every
catalog plugin except** the tier-1 detection plugins in the table above (they
earn a row only when their signal fires), the bundles (`everything` and any
`*-suite`), and `plugin-scout` itself. Suggest that remainder regardless of
stack with "universal" as the evidence; read each row's keywords and
description to phrase the suggestion. Do not hard-code a plugin list here — the
catalog is the source of truth and stays in sync as plugins change.

## Report

Print one table:

| Plugin | Tier | Evidence | Installed |
|---|---|---|---|
| laravel | 1 | composer.json: laravel/framework ^11 | — |
| debugging | 2 | universal | ✓ |

- Evidence cites file and dependency (e.g. `composer.json: laravel/framework
  ^11`); tier-2 rows just say "universal".
- Installed column: ✓ when `claude plugin list` shows it, — otherwise.
- Exclude plugin-scout itself and every bundle (everything and all `*-suite`)
  from the table.
- When 5+ tier-2 plugins are suggested, add one line: taskmaster-suite
  installs the universal set as one bundle, if picking individually feels slow.
- Zero stack signals → print the tier-2-only report with the note "no stack
  signals found".

## Install

1. Without `--yes`: ask via AskUserQuestion with multiSelect over the
   not-yet-installed suggestions, tier-1 picks listed first and
   pre-described with their evidence: "Install selected (Recommended)"
   framing, plus a "Skip — report only" option. Headless: print the exact
   install commands for every not-installed suggestion instead of running
   anything, then stop.
   With `--yes`: skip this picker — see Flags below for the auto-select set.
2. For each pick, run via Bash:

   ```bash
   claude plugin install <name>@cc-plugins-marketplace
   ```

   That is the only install command form — no other syntax, no bundles here.
3. Report per-plugin success or failure as each command finishes; a failure
   does not abort the remaining picks.
4. Finish with a one-line summary: installed n, failed m, skipped k (already
   installed).
5. If `--persist` was passed, write the plugins actually installed this run
   into the project's settings — see Flags below.

## Flags

- `--yes` — auto-installs tier-1 signal-backed, not-yet-installed picks
  instead of showing the picker; the full report table still prints first.
  Tier-2 picks are never auto-installed. Zero tier-1 picks: report only, no
  picker, with a hint to rerun without `--yes` to pick tier-2. The
  marketplace-add preflight prompt is unchanged by `--yes` — still asked
  interactively, and in headless mode with the marketplace absent, stop and
  print the add instructions rather than installing anything. Ambiguous Vue
  major installs neither vue plugin, same as without the flag. Full rules,
  the headless-marketplace-absent wording, and the hooks-may-activate-later
  note: `references/flags.md`.
- `--persist` — after Install, writes the set actually installed this run
  (picker picks, or the `--yes` tier-1 auto-set) into the project's
  `.claude/settings.json` (`enabledPlugins` + `extraKnownMarketplaces`);
  never the full detected set. Combinable with `--yes`. Full merge/create/
  abort rules and the required commit-trust notice: `references/flags.md`.

## Boundaries

- Suggests and installs only cc-plugins-marketplace plugins; it does not
  audit, configure, or uninstall anything.
- Detection never mutates the project — no lockfile writes, no installs, no
  package-manager invocations.
- If every suggestion is already installed, say so and stop; do not invent
  work.
