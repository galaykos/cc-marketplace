# claude-authoring

Authoring guides for Claude Code artifacts — skills, agents, commands, hooks,
and plugins — plus a routine-detector that suggests scaffolding a project skill
when work turns repetitive, a project-skill-suggester that proactively offers
one when a task's cards share uncovered repository-specific knowledge, and five
scaffold commands that turn those suggestions into files.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install claude-authoring@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/claude-authoring:new-skill [skill-name] [purpose]` | Scaffold a SKILL.md with a trigger-rich description and a body inside the 100–150 line budget |
| `/claude-authoring:new-agent [agent-name] [purpose]` | Scaffold a subagent .md with name/description/tools/model/effort frontmatter and a role-procedure-checklist body |
| `/claude-authoring:new-command [command-name] [what-it-does]` | Scaffold a slash-command .md with description/argument-hint frontmatter and a numbered $ARGUMENTS-driven body |
| `/claude-authoring:new-hook [hook-name] [purpose]` | Scaffold hooks/hooks.json plus an executable hook script for a chosen event |
| `/claude-authoring:new-plugin [plugin-name] [purpose]` | Scaffold a complete plugin directory — plugin.json and chosen artifact dirs — and register it in marketplace.json when one exists |

Each command is backed by a matching authoring skill (authoring-skills,
authoring-agents, authoring-commands, authoring-hooks, authoring-plugins) that
also fires on its own whenever you write or edit that artifact kind by hand.

## Example

```bash
/claude-authoring:new-skill migration-conventions "how this repo writes and orders DB migrations"
/claude-authoring:new-plugin release-notes "draft release notes from merged PRs"
```

## Pairs well with

- **plugin-scout** — suggests existing marketplace plugins to install; claude-authoring covers the artifacts you build yourself
- **taskmaster** — the project-skill-suggester fires after its spec-to-cards split when cards share uncaptured repo knowledge
- **hindsight** — harvests session friction into skill/plugin ideas that these scaffold commands turn into real files
