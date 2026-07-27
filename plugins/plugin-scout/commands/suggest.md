---
description: Scan the project's manifests and suggest which marketplace plugins to install — install the picked ones, --yes auto-installs tier-1, --persist writes project settings.
argument-hint: [path] [--yes] [--persist]
---

Invoke the plugin-scout skill from this plugin against $ARGUMENTS (or the
repository root if no argument), parsing any `--yes` and `--persist` flags
out of $ARGUMENTS first — the remainder is the path. Steps:

1. Preflight per the skill: check that the marketplace is registered, then
   detect already-installed plugins via `claude plugin list`.
2. Detect the stack per the skill: reuse stack-scan's inventory when that
   plugin is installed, otherwise self-scan the project's manifests.
3. Output the numbered two-tier suggestion table (# | plugin | tier |
   evidence | installed) as defined by the skill, using its zero-signal
   fallback when nothing matches.
4. Run the picker per the skill's `references/picker.md` contract: max
   density — each AskUserQuestion call fills 4 multiSelect questions x 4
   options (16 slots), tier-1 picks first with evidence, one "Stop — skip
   remaining" slot per call, paging until every eligible suggestion was
   offered. Installed rows (including leaves an installed suite provides)
   are never options; overlap-with-installed rows sort last, overlap
   named. Other takes numbers/names/ranges as bulk picks; >32 rows, offer
   the `scripts/pick.sh` TTY picker per the contract. Then run
   `claude plugin install <name>@cc-plugins-marketplace --scope local` per
   pick (repo-only, never user-global; `--scope project` when `--persist`
   was passed) and report the results. Headless: print the exact install
   commands and stop. With `--yes`: skip this ask and auto-install the
   tier-1 signal-backed, not-yet-installed picks per the skill's Flags
   section instead.
5. With `--persist`: after installing, verify the project's
   `.claude/settings.json` carries the installed set and the marketplace
   entry per the skill's Flags section (`references/flags.md` for the full
   rules).
