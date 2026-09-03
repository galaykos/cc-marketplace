---
description: Scan manifests and suggest every marketplace plugin in three tiers, then install the picks; --yes auto-installs tiers 1-2, --full installs everything stack-relevant after one confirm, --all pages every row, --persist/--global set scope.
argument-hint: [path] [--yes] [--all] [--full] [--stack a,b,c] [--persist | --global]
---

Invoke the plugin-scout skill from this plugin against $ARGUMENTS (or the
repository root if no argument), parsing any `--yes`, `--all`, `--full`,
`--stack <tokens>` (also `--stack=<tokens>`), `--persist`, and `--global` flags
out of $ARGUMENTS first — the token after `--stack` is consumed before the
remainder becomes the path. `--persist` and `--global` together are a conflict:
abort before anything else, including the marketplace-add prompt, with one line
asking for exactly one of them. A bare `--stack`, an empty token, a token outside
`references/stack-relevance.md`'s token column aborts the same way, printing the
accepted list; a positional argument that is itself a token (`--stack laravel, react`)
aborts with the hint `did you mean --stack laravel,react`. Steps:

1. Preflight per the skill: check that the marketplace is registered, then
   detect the installed set — `claude plugin list --json` filtered to this
   project (the unfiltered list is machine-wide), unioned with the
   `enabledPlugins` keys of the project's settings files.
2. Detect the stack per the skill: resolve the path argument as the scan
   root, scan its manifests (plus workspace members one level deep), and
   use stack-scan's report as a version-truth supplement when that plugin
   is installed — never as a replacement, and never accepting its offer to
   fix red flags from inside detection.
3. Output the numbered three-tier inventory as defined by the skill's Report
   section and `references/picker.md` — a header line plus one block per
   tier, tier 1 signal-backed with cited evidence, tier 2 the any-project
   core (`references/any-core.md`), tier 3 the universal remainder grouped
   by keyword, including unfired tier-1 candidates from either signal source
   marked "no signal detected". Every catalog leaf except bundles and
   plugin-scout itself appears exactly once, untruncated; if a
   `references/signals.md` `—` row fired, lead with its routing line. Then run
   the tier-3 relevance pass per `references/relevance.md`: lift 3-5 remainder
   rows that fit THIS repo into a `worth a look here` group leading the tier-3
   block, each with a one-line reason rather than evidence — no extra
   questions, no promotion to tier 1, never `--yes`-eligible, and report zero
   rather than pad. Close the inventory with the `Beyond this marketplace`
   block from `references/official-complements.md`: the vendor-agnostic
   `claude-plugins-official` rows whose signal fired or that are `core`, each
   with its overlap sentence and its install command printed, never run.
   Under `--full` this step prints only the header line and any fired `—`
   routing line — the plan in step 4 replaces the inventory.
4. With `--full`: skip the inventory, the relevance pass and the picker. Print
   the plan block per `references/flags.md` `--full` — install list, installed
   count (project-filtered list ∪ settings files ∪ installed suites' members),
   each exclusion with its reason and the `--stack` token that includes it, the
   by-construction count, classes restored by `--stack`, overlap pairs, hooks by
   event, MCP servers local/remote, and the listing-cap cost per skill and
   command entry against 6,000 (200k) and 30,000 (1M) chars with the
   `skillListingBudgetFraction` lever — then the `Beyond this marketplace`
   block, then ONE AskUserQuestion, after Preflight's own ask if any: "Install N
   plugins at scope S (Recommended)" / "Print the commands instead" / "Stop".
   `--full --yes` skips the ask. Headless without `--yes`, or no `claude` CLI:
   print the commands and stop. Then install per leaf with the same `--scope`
   rules and the same exit-0 success rule below.
   Without `--full`: run the picker per the skill's `references/picker.md` contract: by
   default ONE AskUserQuestion call — questions 1-3 hold tier-1 picks with
   evidence then the core rows, 4 options each, and question 4 is the tier-3
   door (browse the remainder / print its install commands / just these /
   stop). With `--all`, page every eligible row as an explicit option
   instead, 15 per call with one "Stop — skip remaining" slot. Installed
   rows (including leaves an installed suite provides) are never options;
   deprioritize only on the named overlap pairs, never on keyword overlap.
   A suite covering 3+ suggested rows earns one shortcut option naming at
   most 4 of them (never under `--yes`; an all-in bundle never). Other takes
   numbers/names/ranges as bulk picks; >30 rows, offer the
   `scripts/pick.sh` TTY picker per the contract and read back its
   `PICKED:` line — an empty one means "picked nothing", not an error.
   Then run `claude plugin install <name>@cc-plugins-marketplace --scope local`
   per pick (`--scope project` when `--persist`, `--scope user` when
   `--global` — always pass `--scope`), treat exit 0 as the only success
   signal, and report the results plus the `/reload-plugins` line. Headless:
   print the exact install commands and stop. With `--yes`: skip this ask
   and auto-install the tier-1 signal-backed plus tier-2 core
   not-yet-installed picks per the skill's Flags section instead, naming the
   write-time hooks that lands.
5. With `--persist`: after installing, verify the project's
   `.claude/settings.json` carries the marketplace entry and one CLI-written
   `enabledPlugins` entry per plugin that installed successfully — report a
   missing entry rather than authoring one. With `--global`: no settings
   step — print the required machine-wide notice instead
   (`references/flags.md` for the full rules of both).
