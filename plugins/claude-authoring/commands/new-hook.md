---
description: Scaffold hooks/hooks.json plus an executable hook script for a chosen event.
argument-hint: [hook-name] [purpose]
---

Scaffold a new hook from $ARGUMENTS. Steps:

1. Parse $ARGUMENTS for the hook name (kebab-case) and a one-line purpose.
   Ask for whichever is missing before writing anything.
   First, warn: a hook is a mechanical guarantee that runs every time,
   costs latency, and cannot use judgment. Prefer a skill unless the
   behavior must be enforced unconditionally (blocking a tool call,
   injecting context on every prompt). Confirm a hook is really wanted.
2. Ask 2–3 scoping questions before generating:
   - Which event? One of: UserPromptSubmit, SessionStart, PreToolUse,
     PostToolUse, Stop.
   - For PreToolUse/PostToolUse: which tool matcher (e.g. `Bash`,
     `Write|Edit`, or empty for all tools)?
   - Target location. In a plugin/marketplace repo (repo root contains
     `.claude-plugin/`): `plugins/<plugin>/hooks/hooks.json` plus
     `plugins/<plugin>/hooks/<name>.sh`, referenced via
     `${CLAUDE_PLUGIN_ROOT}`. In a plain project repo: a hooks entry in
     `.claude/settings.json` plus `.claude/hooks/<name>.sh`, referenced via
     `$CLAUDE_PROJECT_DIR`. State which one applies.
3. Write hooks.json from this template (merge into the existing file if one
   already exists — never clobber other hooks):

   ```json
   {
     "hooks": {
       "<Event>": [
         {
           "matcher": "<matcher, omit key for events without one>",
           "hooks": [
             {
               "type": "command",
               "command": "${CLAUDE_PLUGIN_ROOT}/hooks/<name>.sh"
             }
           ]
         }
       ]
     }
   }
   ```
4. Create the script and make it executable — this step is mandatory; this
   marketplace's validator fails any hooks.json whose referenced script is
   missing or not executable:

   ```bash
   cat > <hooks-dir>/<name>.sh <<'EOF'
   #!/usr/bin/env bash
   set -euo pipefail
   input=$(cat)   # hook payload arrives as JSON on stdin
   # TODO: hook logic. Exit 0 to allow; exit 2 to block (PreToolUse).
   EOF
   chmod +x <hooks-dir>/<name>.sh
   ```
5. Print the targeted verification:

   ```bash
   jq empty <hooks-dir>/hooks.json && echo json-ok
   test -x <hooks-dir>/<name>.sh && echo script-executable
   ```
6. Remind the user: load the authoring-hooks skill from this plugin for the
   deeper rules — event semantics, matchers, exit codes, and when NOT to
   use a hook.
