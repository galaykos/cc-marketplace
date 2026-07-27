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
4. Ask one AskUserQuestion (multiSelect) per the skill's
   `references/picker.md` contract: "Install recommended set" (all tier-1
   picks with evidence; omitted when tier-1 is empty) / "Skip — report
   only", with any table row selectable via Other as numbers and/or names
   (ranges OK) — full coverage, no suggestion unreachable. Then run
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
