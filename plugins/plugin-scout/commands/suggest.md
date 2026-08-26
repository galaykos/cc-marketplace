---
description: Scan the project's manifests and suggest every marketplace plugin in three tiers — install the picked ones; --yes auto-installs tiers 1-2, --persist project scope, --global user scope.
argument-hint: [path] [--yes] [--persist | --global]
---

Invoke the plugin-scout skill from this plugin against $ARGUMENTS (or the
repository root if no argument), parsing any `--yes`, `--persist`, and
`--global` flags out of $ARGUMENTS first — the remainder is the path.
`--persist` and `--global` together are a conflict: abort before anything
else with one line asking for exactly one of them. Steps:

1. Preflight per the skill: check that the marketplace is registered, then
   detect already-installed plugins via `claude plugin list`.
2. Detect the stack per the skill: reuse stack-scan's inventory when that
   plugin is installed, otherwise self-scan the project's manifests.
3. Output the numbered three-tier suggestion table (# | plugin | tier |
   evidence | installed) as defined by the skill — tier 1 signal-backed
   with cited evidence, tier 2 the any-project core
   (`references/any-core.md`), tier 3 the universal remainder including
   unfired stack plugins marked "no signal detected". Every catalog leaf
   except bundles and plugin-scout itself appears exactly once; use the
   skill's zero-signal fallback note when no signal matches.
4. Run the picker per the skill's `references/picker.md` contract: max
   density — each AskUserQuestion call fills 4 multiSelect questions x 4
   options (16 slots), tier-1 picks first with evidence, core rows next,
   one "Stop — skip remaining" slot per call, paging list by list until
   every eligible suggestion across all three tiers was offered.
   Installed rows (including leaves an installed suite provides) are
   never options; overlap-with-installed rows sort last, overlap named.
   A suite covering 3+ suggested rows earns one shortcut option (never
   under `--yes`). Other takes numbers/names/ranges as bulk picks;
   >32 rows, offer the `scripts/pick.sh` TTY picker per the contract.
   Then run
   `claude plugin install <name>@cc-plugins-marketplace --scope local` per
   pick (`--scope project` when `--persist`, `--scope user` when
   `--global`) and report the results. Headless: print the exact install
   commands and stop. With `--yes`: skip this ask and auto-install the
   tier-1 signal-backed plus tier-2 core not-yet-installed picks per the
   skill's Flags section instead.
5. With `--persist`: after installing, verify the project's
   `.claude/settings.json` carries the installed set and the marketplace
   entry per the skill's Flags section. With `--global`: no settings step
   — print the required machine-wide notice instead
   (`references/flags.md` for the full rules of both).
