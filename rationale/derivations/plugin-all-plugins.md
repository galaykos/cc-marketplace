# all-plugins hooks: the comment text moved out of the code (2026-10-28)

The text below was moved verbatim on 2026-10-28 from the file named in the `##` heading, with only each comment's `# ` leader removed; the lines the file kept are not repeated here. A pointer by name was left in the file, `# Why, limits, history: rationale/derivations/plugin-all-plugins.md § <heading>`. The file's first comment line naming `CC_ALL_PLUGINS_HINT=` is the sentence `scripts/generate.sh` copies into the README's off-switch table, so the kept header still carries it word for word. Standing: `recorded` — no gate reads this file, and its dates, measurements and citations are as they stood on the day it moved.

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
