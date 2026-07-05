---
description: Scan the project's manifests and suggest which marketplace plugins to install — with an option to install the picked ones
argument-hint: [path]
---

Invoke the plugin-scout skill from this plugin against $ARGUMENTS (or the
repository root if no argument). Steps:

1. Preflight per the skill: check that the marketplace is registered, then
   detect already-installed plugins via `claude plugin list`.
2. Detect the stack per the skill: reuse stack-scan's inventory when that
   plugin is installed, otherwise self-scan the project's manifests.
3. Output the two-tier suggestion table (plugin | tier | evidence |
   installed) as defined by the skill, using its zero-signal fallback when
   nothing matches.
4. Ask via AskUserQuestion (multiSelect) which not-yet-installed suggestions
   to install: "Install picked plugins (Recommended)" — then run
   `claude plugin install <name>@cc-plugins-marketplace` per pick and report
   the results — / "Skip — suggestions only". Headless: print the exact
   install commands and stop.
