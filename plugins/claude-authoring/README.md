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
| `/claude-authoring:new-skill [skill-name] [purpose]` | Scaffold a SKILL.md with a trigger-rich description and a body inside the 150-line ceiling |
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

## Boundary with the built-in `skill-creator`

Claude Code ships a `skill-creator` skill. It is not a competitor to this plugin
and the two do different halves of the job, but until 2026-08-02 nothing here
named it at all — which is how a marketplace ends up re-implementing something the
user already has. <!-- host-ok -->

| Job | Use |
|---|---|
| What a good SKILL.md / agent / command / hook looks like, and this marketplace's conventions | `claude-authoring` |
| Scaffolding a skill, packaging it, structural validation | either — `/claude-authoring:new-skill` follows house layout; `skill-creator` ships `package_skill.py` and `quick_validate.py` |
| Optimising a description so it triggers when it should | **`skill-creator`** — it ships `improve_description.py`; nothing here does |
| **Measuring whether a skill does anything** | **`skill-creator`** — it ships a working control/treatment eval loop: paired with-skill and baseline subagents in one turn, a BLIND comparator that does not know which side produced which output, a grader, and benchmarking with variance |

That last row matters most. `skills/authoring-skills/references/behavioral-testing.md`
describes exactly that loop as a method, and
`rationale/stack-skill-baselines.md` records the one time it was run by hand —
three plugins and five skills removed on the evidence. **Do not build a second
harness for it.** When a skill needs measuring, run the host's loop and record the
verdict; this marketplace's contribution is the doctrine and the ledger, not the
runner.
