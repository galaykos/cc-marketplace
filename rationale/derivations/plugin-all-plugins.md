# all-plugins hooks and scripts: the comment text moved out of the code (2026-10-28)

The text below was moved verbatim on 2026-10-28 from the files named in the `##` headings, with only each comment's `# ` leader (and the indentation before it) removed; the lines each file kept are not repeated here. A pointer by name was left in each file, `# Why, limits, history: rationale/derivations/plugin-all-plugins.md § <heading>`. hint.sh's first comment line naming `CC_ALL_PLUGINS_HINT=` is the sentence `scripts/generate.sh` copies into the README's off-switch table, so the kept header still carries it word for word. Standing: `recorded` — no gate reads this file, and its dates, measurements and citations are as they stood on the day it moved.

## plugins/all-plugins/hooks/hint.sh

### Header

```text
SessionStart (startup only) hint: all-plugins is enabled and no other plugin of its marketplace is.
all-plugins installs the leaves and adds nothing itself; a user once ran days of sessions with zero
leaves, believing the marketplace was on. One line to the person (systemMessage, never model context).
CC_ALL_PLUGINS_HINT=off hides the startup line naming all-plugins as the only plugin enabled.
"Enabled" is the enabledPlugins map merged from the settings files the CLI writes, later wins: user
(${CLAUDE_CONFIG_DIR:-~/.claude}/settings.json), then project and local (<project>/.claude/settings.json,
settings.local.json), the project being CLAUDE_PROJECT_DIR, else the payload cwd.
Misses: managed policy settings, --settings files and --plugin-dir loads. Unseen all-plugins: silent;
leaves enabled only through a channel unread here: a wrong line.
Fail open: no jq, unreadable settings or any error prints nothing.
```

## plugins/all-plugins/scripts/all-plugins.sh

### Header

```text
all-plugins.sh — install every plugin of this marketplace at one scope with
zero prompts, uninstall them again, or list their state. A "leaf" is every plugin in
the marketplace.json: since 2026-09-26 no plugin here may declare `dependencies`
(the repo's validate.sh fails the key), so there is no bundle to skip. all-plugins
itself is on the list — `install` covers it (normally already there: `skip`),
`uninstall` keeps it unless --self, and removes it LAST with --self. `install` alone skips
what `opt_in` names (installed only when the person names it); `uninstall` and `list` walk it.

It installs what the marketplace holds WHEN IT RUNS. A plugin added later is not
installed by a marketplace update; run `install` again — installed ones are skipped. A mechanism, not prose:
the exit code is the contract. 0 = done (including nothing to do); 1 = at least
one per-plugin command failed — the list is still walked to the end and every
failure is reported; 2 = usage error or a missing prerequisite.

Usage: all-plugins.sh <install|uninstall|list> [--scope local|project|user]
                      [--dry-run] [--self] [--budget|--no-budget] [--marketplace NAME]

The listing budget is opt-in (--budget). Claude Code caps the skill+command listing
it sends the model at contextWindowTokens x bytesPerToken x skillListingBudgetFraction
(default 0.01 — 6,000 chars at 200k on a 3-byte model) and past it drops entries to
name-only. Every leaf here costs several times that, so `install` computes the
listing cost the way scripts/lib/plugin-checks.sh's pc_listing_entry_cost does
(name + 4 + min(description, 1536) per skill/command — and `description` is the
JOINED pair the CLI lists, `description + " - " + when_to_use` when the frontmatter
carries both, capped once after the join, not twice; see the walk near the bottom of
this file), and raises skillListingBudgetFraction
in the SCOPE's settings file to the smallest 0.01 step that covers it at the 200k
floor — a cap, not a fill, so a 1M window pays nothing extra. `uninstall` removes
the key again, but only when it still holds the value this script would set; any
other value is somebody's and is left alone. --no-budget skips the removal too.
`install` raises only under --budget; `uninstall` removes by default, so a value an
older install wrote unasked is still cleaned up.

What it does NOT do: never touches another marketplace; never
prompts — this marketplace declares no install commands, so nothing asks and `-y`
is never passed; does not reload the session (the hint names /reload-plugins).

Whether an overflowed listing changes what fires was measured once at zero delta,
n=50 (rationale/2026-09-15-listing-eviction-probe.md), so the raise is not worth
about 12,000 system-prompt tokens per turn by default; --budget buys it for whoever
wants the question moot (rationale/marketplace-taskforce-review-2026-10-11.md).

Discovery is never a hardcoded list: `claude plugin marketplace list --json`
locates the clone, its marketplace.json names the plugins, and `claude plugin
list --json` says what is installed WHERE — the same id appears once per project
at local/project scope, so an entry only counts when its projectPath is this one.

Standing: mechanism — exit code is the contract; nothing in CI runs it against a
live CLI, the harness (scripts/__tests__/all-plugins.test.sh) drives a shim.
```

### No dependencies filter

```text
No `dependencies` filter: the bundles it skipped were retired 2026-09-26 and the
repo's validate.sh now fails any plugin.json that declares the key.
```

### run_cli

```text
run_cli <verb> <name> — `claude plugin <verb> <name>@MARKETPLACE -s SCOPE`, or the
DRY line under --dry-run. On failure REASON holds the first stderr line. stdin is
/dev/null so a prompt, should the host ever grow one here, fails instead of hanging.
```

### The 1536 cap

```text
1536 is the host's skillListingMaxDescChars default. SOURCE OF TRUTH:
scripts/host-constants.sh in the marketplace repo, which re-reads it out of the
pinned CLI binary. This copy cannot source it — this script ships inside the
plugin and runs on an installer's disk where that repo path does not exist.
```

### main on the last line

```text
`main` is the last line on purpose: `uninstall --self` removes the plugin whose
cache dir holds this very file. bash parses a function body in full before running
it but reads top-level lines as it reaches them, so everything above is a function
and nothing past this point is ever read from a file that may already be gone.
```

