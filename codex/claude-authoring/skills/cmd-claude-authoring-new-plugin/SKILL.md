---
name: cmd-claude-authoring-new-plugin
description: "Use when the user asks to scaffold a complete plugin directory — plugin.json, chosen artifact dirs — and register it in marketplace.json when one exists."
---

_This skill wraps the `/claude-authoring:new-plugin` command; pass the command's input as the skill's argument (`$ARGUMENTS`)._


Scaffold a new plugin from $ARGUMENTS. Steps:

1. Parse $ARGUMENTS for the plugin name (kebab-case) and a one-line purpose.
   Ask for whichever is missing before writing anything.
2. Ask 2–3 scoping questions before generating:
   - Which artifacts will it ship: skills, agents, commands, hooks? Create
     only the directories that will hold content — no empty placeholders.
   - One-sentence description for plugin.json: what does the plugin do and
     when should someone install it?
   - Confirm the target root: `plugins/<name>/` in a marketplace repo
     (repo root contains `.claude-plugin/`), or the repo root itself for a
     standalone plugin repo. State which one applies.
3. Compose the directory and write
   `<plugin-root>/.claude-plugin/plugin.json` from the four-key template:

   ```json
   {
     "name": "<name>",
     "version": "0.1.0",
     "description": "<one sentence from step 2>",
     "author": { "name": "<author>", "email": "<email>" }
   }
   ```

   Then create the chosen artifact dirs (`skills/`, `agents/`, `commands/`,
   `hooks/`) and scaffold their contents with the sibling commands from
   this plugin (the `cmd-claude-authoring-new-skill` skill, the `cmd-claude-authoring-new-agent` skill,
   the `cmd-claude-authoring-new-hook` skill) or by hand.
4. Register the plugin — mandatory when `.claude-plugin/marketplace.json`
   exists at the repo root; this marketplace's validator fails on any
   plugin directory not listed there. Append to the plugins array in the
   SAME change (never leave an orphan directory):

   ```json
   {
     "name": "<name>",
     "source": "./plugins/<name>",
     "description": "<same one sentence>"
   }
   ```

   Also update the repo README (plugin table) and CHANGELOG per this
   repo's convention — check how the last plugin addition did it.
5. Print the targeted verification:

   ```bash
   jq empty <plugin-root>/.claude-plugin/plugin.json && echo plugin-json-ok
   jq -r '.name, .version, .description, .author.name' <plugin-root>/.claude-plugin/plugin.json
   jq -e --arg n <name> '.plugins[] | select(.name == $n)' .claude-plugin/marketplace.json && echo registered
   ```
6. Offer the next step as a selectable choice (AskUserQuestion): "Load the
   authoring-plugins skill and finish the release steps now (Recommended)" /
   "Skip — the scaffold is enough". On yes, load the skill and continue;
   plain text only when headless. Deeper rules live there — layout,
   versioning, registration, release conventions.
