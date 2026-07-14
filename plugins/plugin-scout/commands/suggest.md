---
description: Scan the project's manifests and suggest which marketplace plugins to install — with an option to install the picked ones, auto-install tier-1 picks (--yes), or persist the installed set to project settings (--persist)
argument-hint: [path] [--yes] [--persist]
---

Invoke the plugin-scout skill from this plugin against $ARGUMENTS (or the
repository root if no argument), parsing any `--yes` and `--persist` flags
out of $ARGUMENTS first — the remainder is the path. Steps:

1. Preflight per the skill: check that the marketplace is registered, then
   detect already-installed plugins via `claude plugin list`.
2. Detect the stack per the skill: reuse stack-scan's inventory when that
   plugin is installed, otherwise self-scan the project's manifests.
3. Output the two-tier suggestion table (plugin | tier | evidence |
   installed) as defined by the skill, using its zero-signal fallback when
   nothing matches.
4. Ask via AskUserQuestion (multiSelect) which not-yet-installed suggestions
   to install: "Install selected (Recommended)" — then run
   `claude plugin install <name>@cc-plugins-marketplace` per pick and report
   the results — / "Skip — report only". Headless: print the exact
   install commands and stop. With `--yes`: skip this ask and auto-install
   the tier-1 signal-backed, not-yet-installed picks per the skill's Flags
   section instead.
5. With `--persist`: after installing, write the plugins actually installed
   this run into the project's `.claude/settings.json` per the skill's Flags
   section (`references/flags.md` for the full rules).
