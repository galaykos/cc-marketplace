---
name: vercel-skills-scout
description: Use when hunting third-party skills for the current stack — "search skills.sh", "find a community skill for X", "is there a skill for this framework" — or when this marketplace has no plugin covering a need. Scans manifests, queries the skills.sh directory, suggests with provenance (source repo, installs, URL), previews picked skills, installs only explicit picks via npx skills add — project-level, never global, never auto.
---

## Purpose

Scan the current project, derive stack-matched search queries, query
skills.sh (Vercel Labs' open agent-skills directory), and suggest
third-party skills — each with provenance — then install exactly the ones
the user picks. Nothing installs without an explicit pick, and there is no
auto-install flag: skills.sh content is unvetted third-party instruction
text, so the explicit-pick floor is absolute (deliberate divergence from
plugin-scout's `--yes`).

## Preflight

- Check `npx` is available (`command -v npx`). Absent: report only — print
  the install commands at the end instead of running them.
- Detect already-installed skills.sh skills with `npx -y skills ls` —
  fail-open: on error, mark the installed column unknown and continue.
- Run `claude plugin list` (skip silently if the CLI is absent) — used for
  the overlap column, not for installs.

## Detection

Read composer.json, package.json, tsconfig.json, .env, and
Dockerfile/docker-compose files. Same rules as plugin-scout: read-only,
never run package managers, and a query is earned only by cited evidence
(file plus dependency or line). Map signals to search queries:

| Signal (evidence file) | Query |
|---|---|
| composer.json exists | `php` | <!-- removed-ok --> <!-- registry search query, not a marketplace plugin name -->
| composer.json require laravel/framework | `laravel` |
| composer.json require livewire/livewire | `livewire` | <!-- removed-ok --> <!-- registry search query, not a marketplace plugin name -->
| inertiajs dep (composer or npm) | `inertia` | <!-- removed-ok --> <!-- registry search query, not a marketplace plugin name -->
| package.json dep react (not react-native) | `react` | <!-- removed-ok --> <!-- registry search query, not a marketplace plugin name -->
| package.json dep react-native | `react native` | <!-- removed-ok --> <!-- registry search query, not a marketplace plugin name -->
| package.json dep vue | `vue` |
| package.json dep next | `nextjs` | <!-- removed-ok --> <!-- registry search query, not a marketplace plugin name -->
| package.json dep nuxt | `nuxt` | <!-- removed-ok --> <!-- registry search query, not a marketplace plugin name -->
| package.json dep express / fastify / @nestjs/core | that framework's name |
| package.json dep vite (devDependencies counts) | `vite` | <!-- removed-ok --> <!-- registry search query, not a marketplace plugin name -->
| DB engine in .env DSN or docker image | that engine's name |

**Stacks this marketplace does not cover** — check these BEFORE the vite row,
because a meta-framework that builds on vite will otherwise match `vite` and
return Vite skills for a SvelteKit question. That is the failure mode the
zero-signals branch below cannot rescue: the repo HAS signals, they are just the
wrong ones. When one of these matches, say plainly "no marketplace plugin covers
this — skills.sh is the intended path" rather than leaving it implicit:

| Signal (evidence file) | Query |
|---|---|
| `@sveltejs/kit` dep or `svelte.config.*` | `sveltekit` |
| `astro` dep or `astro.config.*` | `astro` |
| `angular.json` or `@angular/core` dep | `angular` |
| `manage.py`, or pyproject with `django` / `fastapi` | that framework's name |
| `Gemfile` with `rails` | `rails` |
| `pubspec.yaml` | `flutter` |
| `go.mod` | `go` |
| `Cargo.toml` | `rust` |
| `wrangler.toml` / `wrangler.jsonc` | `cloudflare workers` |
| `deno.json` / `deno.jsonc` | `deno` |
| `*.tf` / `*.tofu` | `terraform` |

An explicit query argument (`/vercel-skills-scout:suggest <query>`)
replaces detection entirely. Zero signals and no argument: ask the user
for a free-text query via AskUserQuestion; headless, report "no stack
signals" plus a hint to rerun with a query argument, and stop.

## Search

Per query, fetch `https://www.skills.sh/api/search?q=<query>` (JSON:
`skills[]` of `{skillId, name, installs, source}`, install-ranked, up to
100). Keep the top 5 per query. This API is unofficial and undocumented —
honest limitation: on a non-200 or unparseable response, stop searching
and point the user at browsing <https://www.skills.sh> directly; do not
scrape the HTML.

## Report

Print one numbered table, all queries merged, deduplicated by
`source/skillId`:

| # | Skill | Source repo | Installs | Evidence | Overlap | Installed |
|---|---|---|---|---|---|---|

- Evidence cites the detection signal (`package.json: react ^19`) or says
  `query arg`.
- Overlap: when an installed cc-plugins-marketplace plugin already covers
  the topic (react, laravel, vite, …), name it — those are curated and
  baseline-tested here; a skills.sh row is an addition, not a replacement.
  Install rank measures popularity, not quality; say so once above the
  table.
- Each row links `https://www.skills.sh/<source>/<skillId>`.
- Installed: ✓ when `npx skills ls` shows it, — otherwise, ? when
  detection failed.

## Install

1. Offer rows as explicit options at maximum density — one
   AskUserQuestion call holds up to 4 multiSelect questions x 4 options
   (16 slots); page further calls until every eligible row was offered.
   Installed rows (per `skills ls`) are never options; rows with a
   non-empty Overlap column sort to the final pages, their option text
   naming the overlapped plugin. One slot per call is "Stop — skip
   remaining"; Other accepts numbers and/or `source/skillId`
   (comma-separated, ranges OK; a token matching no row installs
   nothing — re-ask for just the unmatched). No "recommended set" option
   exists here: nothing on skills.sh is vetted. For very long tables the
   TTY picker in `references/mechanics.md` is the unbounded alternative.
   Headless: print the exact commands below and stop.
2. Preview before install — for each pick, fetch the skill's SKILL.md from
   the source repo (raw.githubusercontent.com, main then master) and show
   its frontmatter description plus body line count, so the user can
   interrupt a bad pick. Fetch failure: say the preview is unavailable and
   name the source URL — the install still needs the user's go-ahead in
   that case. Standing: this preview is recorded discipline, not a gate —
   no script blocks a skipped preview.
3. Per confirmed pick:

   ```bash
   npx -y skills add <owner>/<repo> --skill <skillId> -y
   ```

   Project-level (the CLI's default inside a project) — never pass
   `-g`/`--global`. The `-y` only skips the CLI's own prompt; consent
   already happened at the pick.
4. Report per-skill success or failure as each finishes; one failure does
   not abort the rest. Finish with one line: installed n, failed m,
   skipped k (already installed).

## Boundaries

Standing: recorded/agent-graded — nothing in this repo gates any of it (the
authoring-skills "say what has teeth" convention, a project skill of the marketplace repository). Discovers
and installs skills.sh skills only: no audit, update, or removal (`npx skills remove`
/ `update` exist for that), and never touches `.claude/settings.json` — skills.sh
tracks installs in `skills-lock.json`. No curation claim: suggestions rank by installs
and the provenance columns exist so the user can judge. Detection never mutates the
project; the only network calls are the search API and SKILL.md previews.

Mechanics detail — API response shape, URL formats, CLI flags, preview
fallback order: `references/mechanics.md`.
