# Codex execution contract for craft-layer

This package adapts the source workflow to Codex. The following host bindings
supersede Claude-specific mechanics in inherited reference material.

- Resolve this package root from the loaded skill's path (two parents above its
  directory). Before shell examples export `CLAUDE_PLUGIN_ROOT` and `PLUGIN_ROOT`
  to that absolute package path. They are provided automatically to hooks, but
  must not be assumed in an ordinary shell tool. Resolve helper paths there.
- Use Codex's available skill catalog as the authority for installed skills.
  `plugin:command-name` refers to the `command-name` skill of that plugin. Load
  its SKILL.md using the provided path. Never invoke a legacy slash command.
- Role definitions are resources in `references/agents/`, not registered agents.
  Read the relevant role rubric. When delegation is available and appropriate,
  send its instructions and bounded task to a fresh worker; otherwise do the
  work inline. Never request Claude model names or apply a Claude model ranking.
  Inherit the user's configured model unless they selected another available one.
- TaskCreate/TaskUpdate/TaskList, teams, mailboxes, Skill tools, and EnterPlanMode
  are source-host concepts. Use available Codex planning/delegation tools; if
  absent, track tasks and dependencies explicitly in project task documents and
  execute sequentially. Do not issue invented tools or CLI equivalents.
- Use the user-supplied arguments as workflow inputs. For missing required inputs,
  ask a short question. Tool availability never grants authorization for publishing,
  installation, deletion, or communication with others.
- Project workflow state is under `.codex/cc-marketplace/`. Keep existing Claude
  state separate. AGENTS.md is the project instruction file; preserve its existing
  content and scope when proposing or applying changes. When a source state schema
  records session_id, use `codex-` followed by the actual session ID to match the
  hook adapter namespace. Do not invent an ID if the host does not expose one.
- Source transcript scanners expect Claude JSONL and are not Codex evidence.
  Use observed tool outputs, current diffs, and executed checks. Never claim a
  Stop gate passed solely because an inherited scanner returned success.
- Read this package's README for the exact hooks enabled and limitations. Hooks
  require host trust and Python 3 plus any source helper dependencies (usually jq).
  An instruction or reminder is advisory; only a tested blocking hook is a gate.
