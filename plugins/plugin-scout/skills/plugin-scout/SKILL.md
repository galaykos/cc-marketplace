---
name: plugin-scout
description: Use when setting up Claude Code plugins for a project — "which plugins should I install", "what plugins fit this repo", a repo without plugins, or right after cloning: scans manifests, suggests every marketplace plugin in three tiers; `--yes` auto-installs tiers 1-2, `--full` installs everything stack-relevant after one confirm, `--persist`/`--global` set scope, `--all` pages every row.
---

## Purpose

Scan the current project and suggest **every leaf plugin in the marketplace** in three
tiers — tier 1 stack-specific (signal-earned, evidence cited), tier 2 the curated
any-project core, tier 3 the universal remainder — then install what the user picks.
`--yes` installs tiers 1 and 2 with no picker. Tier 3 never auto-installs — `--full` is the one exception (Flags).

## Preflight

- Run `claude plugin marketplace list`. If `cc-plugins-marketplace` is absent, ask via
  AskUserQuestion: "Add marketplace (Recommended)" / "Stop". On the recommended pick, run
  `claude plugin marketplace add galaykos/cc-marketplace` (add `--scope project` under
  `--persist`) first. Headless: without `--yes` print that command and continue in
  command-printing mode; with `--yes` stop before Detection (flags.md).
- Record the installed set — it drives the installed marks and filters the picker.
  `claude plugin list` alone is **machine-wide**: a plugin installed in an unrelated repo
  would be marked installed here and dropped from the picker. Filter to this project, then
  union all three settings files — the CLI does not always report a `--persist` write it
  made, and never reports a hand-edited entry:

  ```bash
  claude plugin list --json | jq -r --arg root "$PWD" \
    '[.[] | select(.enabled and (.scope=="user" or .projectPath==$root))] | .[].id'
  jq -r '.enabledPlugins // {} | to_entries[] | select(.value) | .key' \
    .claude/settings.json .claude/settings.local.json ~/.claude/settings.json 2>/dev/null
  ```

- No `claude` CLI: mark installed-state unknown and print install commands instead.

## Detection

Resolve `[path]` (default: repo root) as the scan root and read composer.json,
package.json, `.env`/`.env.example`, and Dockerfile/docker-compose there, checking
the table below plus `references/signals.md`. If the root manifest declares
`workspaces`, or a `pnpm-workspace.yaml`/`turbo.json` exists, also scan member
manifests one level deep and cite `<member>/package.json` — otherwise a Turborepo
whose apps hold every framework reports "no stack signals found". Installs always
target the session's project root regardless of `[path]`.

If stack-scan is installed, run `/stack-scan:report` for version truth (EOL majors,
lockfile drift) and fold it into the evidence — but **run the signal table anyway**; it is
not a replacement (nine dependency names, no `.env`, no `react-native`). Take its inventory
only, never its offer to fix red flags: that deletes a lockfile inside a read-only step.

- Detection is read-only: never install anything, never run a package manager (composer,
  npm, yarn, pnpm, bun).
- A signal counts only with evidence: the file plus the dependency or key that triggered it.
  No evidence, no tier-1 suggestion. Missing manifests are fine — no composer.json, no PHP.

## Stack signals (tier 1)

Three framework plugins across six signals — web-dev is earned by any of its three, laravel by either of its two. "dep X" means an **exact key**
in `dependencies` or `devDependencies`, never a substring: `next-auth` is not
`next`, `react-native-web` is not `react-native`.

| Signal (evidence file) | Plugin |
|---|---|
| composer.json require laravel/framework | laravel |
| composer.json require inertiajs/inertia-laravel OR package.json @inertiajs/* | laravel |
| package.json dep react-native | web-dev |
| package.json dep next | web-dev |
| package.json dep vite (devDependencies counts) AND a vite.config.* at the scan root | web-dev |
| compose/Dockerfile image matching `mariadb`, `.env.example` DB_CONNECTION=mariadb, or `mariadb` in composer.json/package.json | database |

Read `.env.example`, not just `.env` — `.env` is gitignored in every Laravel and Next
scaffold, so on a fresh clone it is absent. Known miss, inherited from skill-router: a repo
with `DB_CONNECTION=mysql` that actually runs MariaDB earns no database row. Vue, plain
JavaScript and TypeScript map to no plugin — removed after baseline testing
(`rationale/stack-skill-baselines.md`, marketplace repo only); a `vue` dep earns no row.

`references/signals.md` holds the rest of the evidence-bearing signals — CI, compose,
OpenAPI, payment keys, auth deps, Tailwind, SQL, ORMs, LLM keys, otel, perf and retry
libraries, plugin manifests, plus rows for stacks this marketplace does NOT cover. Its
hits are tier-1 signals under the same evidence rule and join the `--yes` set. A `—` in
its Suggest column is an answer, not a gap: route onward instead of padding tier 3.

## Any-project core (tier 2)

Read `references/any-core.md` — plugins judged useful in any project regardless of stack,
each row carrying its why and the two-part membership test. Core rows carry the evidence
string "core", sort after tier 1, and join the `--yes` set. Curated, not derived: re-judge
it against `references/catalog.md` when plugins land or leave.

## Universal remainder (tier 3)

Read `references/catalog.md` (generated — one `name — [keywords] — description` row per
marketplace plugin). Tier 3 is **every catalog plugin not already in tier 1 or 2**, excluding
the bundles (any `*-suite`) and `plugin-scout` itself, plus every unfired tier-1 candidate
from **either** the table above or `references/signals.md` (evidence: "no signal detected" —
a missed signal demotes, never drops). Suggest all of it, "universal" as the evidence for the
rest, reading each row's keywords and description to phrase the suggestion. Do not hard-code
a plugin list here — the catalog is the source of truth. The bundle filter is a name test
(catalog rows carry no `dependencies` key), so a bundle named otherwise is offered as a leaf.

**Then judge, once.** Tier 3 is defined by subtraction, so nothing enters it because of
this project — read `references/relevance.md` and lift 3-5 rows that fit THIS repo into a
`worth a look here` group leading the block, each with a one-line **reason**, never evidence.
No extra questions, no promotion to tier 1, never `--yes`; zero beats padding.

**Beyond this marketplace.** After tier 3, print one block from
`references/official-complements.md`: vendor-agnostic `claude-plugins-official` plugins
carrying a mechanism no plugin here ships (Stop-time security review, rule-file hooks,
language servers, a browser MCP, live docs). A row prints when its Signal fires under the
tier-1 evidence rule or is `core`, with its overlap sentence. Installs there are **printed,
never run** (`claude plugin install <name>@claude-plugins-official`); `--yes` never touches
the block; the file's exclusions (official duplicates of plugins here) are never suggested.

## Report

Print a numbered inventory grouped by tier — a header line (eligible count, installed
count, detected stack), then one block per tier, tier 3 grouped by catalog keyword and
led by its `worth a look here` group. **Not** one five-column table over every row —
sample, layout, and why that table is the wrong rendering: `references/picker.md`.

- Evidence prints only where a signal earned it — the file plus the key that matched, with
  a line number when the scan produced one. Tier 2 is "core" and tier 3 "universal" by
  definition; neither needs a repeated cell. A lifted row prints its reason instead.
- Installed rows carry `✓` inline and are not pickable; the header count replaces a column.
- **Completeness rule:** every catalog plugin except the bundles and plugin-scout itself
  appears exactly once — no leaf omitted, no group truncated with "and N more". Recount
  from `references/catalog.md`, never from a number written here.
- Under the inventory, list each not-installed suite whose dependencies cover 3+
  suggested not-installed rows — rules: `references/picker.md` — then the
  `Beyond this marketplace` block, official rows with `✓` where already installed.
- Zero stack signals → note "no stack signals found"; tiers 2 and 3 still print in full,
  and the relevance pass matters most there. A fired `references/signals.md` `—` row leads.

## Install

1. Without `--yes` or `--full`: **one** AskUserQuestion call. Questions 1-3 hold the tier-1
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

That is the only install command this scout RUNS (official-directory rows are printed,
never run); a suite picked from the under-report shortcut list (`references/picker.md`)
installs by the same command and scope rules, and only `--yes` and `--full` never install a bundle.
`--scope local` keeps installs repo-only (`.claude/settings.local.json`); `--persist` →
`--scope project`, `--global` → `--scope user` (Flags). Always pass `--scope`: the CLI's
own default is `user`.

3. Success is **exit status 0**; a missing plugin or unknown marketplace exits 1 and
   prints `✘ Failed to install`. Never infer success from stdout. Report each result as it
   finishes (a failure does not abort the rest); one summary line: installed n, failed m,
   skipped k (already installed). Then print `Run /reload-plugins to load these in this
   session (or restart Claude Code) — nothing installed this run is active until you do`,
   naming any write-time hooks installed (secret-scanning, command-guard). With
   `--persist`, verify the installed set is reflected in the project's settings — Flags.

## Flags

- `--yes` — the auto-installer: installs every tier-1 signal-backed and tier-2 core plugin
not yet installed, instead of showing the picker; the full report still prints first. Tier
3 never auto-installs under `--yes`, relevance-lifted rows included (`--full` is the exception). Zero auto-installable picks: report
only, with a hint to rerun without `--yes`. Full rules: `references/flags.md`.
- `--full` — installs every leaf that is any-stack or matches the detected stack (`references/stack-relevance.md`), leaves only; a plan (exclusions with reasons, hooks
and MCP servers added, listing-cap cost) replaces the inventory, relevance pass and picker, then one confirm — `--full --yes` skips the confirm, the plan still prints. `--stack a,b,c` restores a class with no manifest evidence. Rules: `references/flags.md`.
- `--all` — offers every eligible row as an explicit picker option, paging until all appeared (the pre-0.12 default). Picker-only; no effect under `--yes` or `--full`.
- `--persist` — switches installs to `--scope project` and verifies the marketplace entry and the CLI's `enabledPlugins` writes
in the project's `.claude/settings.json`, so teammates who clone get the same set; covers only what actually installed this run.
Never hand-author an entry for a failed install. Full rules: `references/flags.md`.
- `--global` — switches installs to `--scope user`: machine-wide, every repo on this machine. Mutually
exclusive with `--persist` — both at once aborts before Preflight. Full rules and the required machine-wide notice: `references/flags.md`.

## Boundaries

Tiered once, in Standing below — not restated here. Installs only cc-plugins-marketplace
plugins — official-directory rows are named and their install command printed, nothing
more; it does not audit, configure, or uninstall (an uninstall command under `--persist`
is printed, never run). Detection and the relevance pass never mutate the project: no
lockfile writes, installs, package-manager invocations, or delegated fix prompts. If every
suggestion is already installed, say so and stop.

## Standing

**Agent-graded.** No script checks that a tier-1 row cited its evidence, that the sweep
ran, that detection stayed read-only, that the picker offered the door, or that the
relevance pass gave reasons instead of padding. Gated by name only: catalog freshness
(`generate.sh --check`), plugin names in the four TABLE lists of this file,
`references/signals.md`, `references/any-core.md` and `references/stack-relevance.md` (`pc_scout_names` — it reads neither
`references/relevance.md` nor `references/official-complements.md`; the latter's names are
foreign to this marketplace by construction and are checked by hand against the live
directory), `scripts/pick.sh` parity (`pc_pick_parity`) and its parser
(`scripts/__tests__/pick.test.sh`), body budget (`pc_skill_budget`), token cost
(`context-budget.sh`). The evidence rule binds tier 1 only.
