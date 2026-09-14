# stack-scan

Know what is actually installed, keep it healthy, and find what to add — one manifest
pass, three commands. `/stack-scan:report` inventories the stack from
composer/npm/yarn/pnpm/bun manifests and lockfiles, runtime pins, and docker/CI images
into a required-vs-installed table with drift, missing-lock, and EOL flags.
`/stack-scan:audit` runs the dependency hygiene pass — vulnerabilities, outdated
packages, and licences against the project's distribution mode — from the same
manifests. `/stack-scan:suggest` reads them once more and suggests **every**
cc-plugins-marketplace plugin in three tiers — stack-matched with the evidence file and
key cited, the curated any-project core, and the universal remainder — then installs
your picks; `--skills` turns the same detection outward and searches
[skills.sh](https://www.skills.sh), Vercel Labs' open agent-skills directory, for
third-party skills the marketplace does not cover.

Doctrine: constraint is a wish, lock is a fact — lock beats manifest, runtime beats
lock, and every version claim cites its source. Suggestions cite evidence the same way:
every stack-matched row names the manifest line that earned it, and nothing installs
without your pick unless you passed `--yes`.

The two scouts were separate plugins (`plugin-scout`, `vercel-skills-scout`) until
2026-09-14; they merged into this one because all three commands read the same
manifests, and the per-plugin boundary forced two byte-identical picker scripts.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install stack-scan@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/stack-scan:report` | Produce the required-vs-installed table plus red flags (multiple lockfiles, drift, EOL majors, docker-vs-local divergence) |
| `/stack-scan:audit` | Audit composer/npm dependencies — vulnerabilities, outdated packages, and dependency licences against the project's distribution mode, severity-sorted with a fix lane per finding; report-only, ends by offering the patch-lane fixes as a choice |
| `/stack-scan:suggest [path] [--yes] [--all] [--full] [--stack a,b,c] [--persist \| --global]` | Detect the stack, print the numbered three-tier inventory covering every marketplace plugin, then offer the plugins you pick — one question set for the signal-backed and core rows plus a door into the remainder (`--all` pages every row explicitly), or auto-install tier-1 + core picks (`--yes`), or install the whole stack-relevant set after one plan confirm (`--full`, with `--stack a,b,c` for a stack the manifests do not show yet), at project scope (`--persist`) or machine-wide user scope (`--global`) |
| `/stack-scan:suggest --skills [query]` | Search skills.sh for third-party skills matching the detected stack (or the query) — one provenance table (source repo, installs, evidence, overlap with installed plugins), a picker, a preview of each pick's SKILL.md, then `npx skills add` per confirmed pick. Explicit picks only; no auto-install flag exists in this mode |

```bash
/stack-scan:report
/stack-scan:audit                         # audits composer.json and/or package.json at the project root
/stack-scan:suggest                       # scans your manifests, suggests a set, installs your picks
/stack-scan:suggest --yes                 # stack-matched tier plus the any-project core, without asking
/stack-scan:suggest --full                # everything relevant to the detected stack, leaves only, after a plan and one confirm
/stack-scan:suggest --full --stack laravel,inertia,react   # greenfield: name the stack the manifests do not show yet
/stack-scan:suggest --persist             # project scope: teammates who clone get the same set
/stack-scan:suggest --skills              # third-party skills on skills.sh for the detected stack
/stack-scan:suggest --skills terraform    # skip detection, search this instead
```

Run the report once per session in an unfamiliar repo. The inventory feeds the
version-aware review plugins (laravel, database, web-dev), taskmaster's
context-scout, devops's compose generator, and the suggest command's own detection
(as version truth, never as a replacement for the manifest signal table).

## Skills

| Skill | Reach for it when |
|---|---|
| `installed-versions` | Before version-dependent advice: what the lockfile, runtime binary, and container image actually say |
| `package-hygiene` | Managing dependencies already in the project — semver constraint strategy, lockfile discipline, security-audit triage, licence checks, patch/minor/major upgrade lanes. Whether to add one is approaches' build-vs-buy |
| `plugin-scout` | "Which plugins should I install", a repo without plugins, right after cloning — the three-tier marketplace suggestion behind `/stack-scan:suggest`; flag semantics in `skills/plugin-scout/references/flags.md`, the picker contract in `references/picker.md`, the tier-3 relevance pass in `references/relevance.md` |
| `vercel-skills-scout` | "Search skills.sh", "is there a community skill for X", or the marketplace has no plugin for the stack — the `--skills` mode; API shape, URL formats and the preview fallback order in `skills/vercel-skills-scout/references/mechanics.md` |

## Suggesting plugins: the three tiers

In a Laravel + Inertia repo `/stack-scan:suggest` suggests laravel (tier 1, with its
composer.json evidence), then the any-project core — code-review, debugging, testing,
git-workflow, and the rest of `skills/plugin-scout/references/any-core.md` — then
lists the remaining catalog as numbered rows you can take by number, name or range,
minus whatever is already installed. Where this marketplace has no plugin for your
stack (Terraform, i18n, Django), the scout says so and routes you to `--skills`
instead of padding the list.

Tier 3 is defined by subtraction, so a relevance pass lifts a handful of remainder
plugins that actually fit, each with a one-line **reason** rather than evidence. It
adds no questions, never auto-installs, and says "nothing stands out" rather than
padding.

**Everything for a stack.** `--full` installs every marketplace leaf that is any-stack
or matches the detected stack — leaves only, never a suite — and skips just what is
bound to a stack the repo does not have. The stack→plugin table is
`skills/plugin-scout/references/stack-relevance.md`. Nothing installs until you
confirm: the flag prints a plan first — the install list, what is already installed,
every exclusion with its reason and the `--stack` token that would include it, the
hook-bearing plugins by event, any MCP server the set adds, and the listing cost.
`--full --yes` skips the confirm.

**The listing cap.** Claude Code budgets the skill listing it sends the model at
`contextWindowTokens x bytesPerToken x skillListingBudgetFraction` (default fraction
0.01): **6,000 chars** on the default 200k window, 30,000 on the 1M tier. A full stack
set costs on the order of 35,000 chars over its skill and command entries, so the host
silently reduces entries to name-only and skills stop being reachable. The plan prints
the set's cost against both caps and the smallest fraction that fits, e.g.
`{ "skillListingBudgetFraction": 0.06 }`. The scout never writes it and never trims the
set. Standing of the figures: **recorded** — recompute with `bash scripts/context-budget.sh`
in the marketplace repo before trusting them.

**Picking, and why it is one call.** Offering every eligible row as an explicit checkbox
costs four AskUserQuestion calls in every repo, so the default offers the rows a signal
or the core list earned and puts the remainder behind one door — every row still prints
in the numbered inventory and stays pickable by number, name or range, or through the
unbounded `scripts/pick.sh` TTY picker. `--all` restores exhaustive paging.

**After installing.** Nothing installed during a run is active in that session until
you run `/reload-plugins` (or restart Claude Code); the summary says so and names any
write-time hooks a `--yes` run installed (`secret-scanning`, `command-guard`).

**Beyond this marketplace.** The inventory closes with one block of plugins from
Anthropic's own `claude-plugins-official` directory — only the vendor-agnostic ones that
carry a mechanism nothing here ships — each with the plugin here it overlaps and its
install command printed rather than run. Table, exclusions and recount command:
`skills/plugin-scout/references/official-complements.md`.

## Suggesting third-party skills: the trust model

skills.sh ranks by install count. Popularity is not review: a skill is arbitrary
instruction text injected into future sessions, and this plugin vouches for none of it.
Consequences, all deliberate:

- **No auto-install in `--skills` mode.** `--yes` exists in plugin mode because its
  tier-1 picks are curated in-marketplace; passing it beside `--skills` aborts. Headless
  runs print commands, never execute them.
- **Provenance on every row** — source repo, installs, URL — so you judge the source,
  not the rank.
- **Preview before install** — the picked skill's SKILL.md is fetched and shown before
  `npx -y skills add <owner>/<repo> --skill <skillId> -y` runs, project-level, never
  `--global`.
- Suggests and installs skills.sh skills only; auditing, updating and removal are `npx
  skills update` / `remove`. Never touches `.claude/settings.json`; skills.sh tracks its
  installs in `skills-lock.json`. The search API is unofficial; on failure the mode stops
  and points at browsing the site rather than scraping it.

Standing, per this marketplace's has-teeth convention: all of the above is
recorded/agent-graded — no script gates it. Gated by name only: catalog freshness
(`generate.sh --check`, which renders `skills/plugin-scout/references/catalog.md`),
plugin names in the suggestion tables (`pc_scout_names`), the picker's parser
(`scripts/__tests__/pick.test.sh`).

## Pairs well with

- **taskmaster** — hard constraints for the interrogation come from this inventory
- **devops** — `/devops:init` reuses the report instead of re-scanning
- **approaches** (build-vs-buy skill) — decides whether a dependency should be added at all
- **security** — broader security review beyond the dependency audit surface
- **taskmaster-suite** — pipeline bundle, NOT a shortcut past the scout: it ships the
  clarify→spec→cards→execute workflow plus only 2 of the any-project-core picks
  (testing, code-architecture) — install the other core picks individually
