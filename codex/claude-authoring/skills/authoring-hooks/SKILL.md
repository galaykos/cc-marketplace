---
name: authoring-hooks
description: Use when writing or editing hooks.json or hook scripts — event choice (UserPromptSubmit, SessionStart, PreToolUse, PostToolUse, Stop), matchers, ${PLUGIN_ROOT} paths, executable-script rules, and when NOT to use a hook.
---

## Anatomy

A plugin's hooks live in one JSON file:

    plugins/<plugin>/hooks/hooks.json

The file declares event → matcher → command. The top level is a "hooks"
object keyed by event name; each event holds an array of matcher groups;
each group holds a "hooks" array of command entries:

    {
      "hooks": {
        "<EventName>": [
          {
            "matcher": "<optional tool-name pattern>",
            "hooks": [
              { "type": "command",
                "command": "${PLUGIN_ROOT}/hooks/<script>.sh" }
            ]
          }
        ]
      }
    }

Reference scripts through ${PLUGIN_ROOT}, never absolute paths —
the plugin installs at a path you do not control. Every referenced script
must exist and be executable (chmod +x).

This marketplace's validator (scripts/validate.sh:74-82) enforces both
rules mechanically: hooks.json must parse as JSON, and every
${PLUGIN_ROOT} command it references must resolve to an
executable file.

## Choosing the event

- UserPromptSubmit — fires on every prompt the user submits. Use for
  per-prompt context injection: reminders, routing nudges, short state
  summaries.
- SessionStart — fires once when a session begins. Use for one-time
  setup context: environment facts, project state, standing rules.
- PreToolUse — fires before a matched tool call runs. Use to guard:
  warn on or block dangerous commands before the tool acts.
- PostToolUse — fires after a matched tool call. Use to react: lint the
  file just written, record the command just run.
- Stop — fires when the model tries to finish its turn. Use for
  completion gates: refuse "done" until verification evidence exists.

Matchers belong to the tool events. Set "matcher" to a tool-name
pattern ("Bash", "Edit|Write") so PreToolUse/PostToolUse fire only for
those tools; omit it and the hook fires for every tool. Prompt and
session events take no matcher — note the extra nesting stays either
way: each event maps to groups, each group to a "hooks" array.

## A real example

All three hook-bearing plugins in this repo — taskmaster, meta-api,
api-docs-first — share this exact hooks.json shape:

    {
      "hooks": {
        "UserPromptSubmit": [
          {
            "hooks": [
              { "type": "command",
                "command": "${PLUGIN_ROOT}/hooks/remind.sh" }
            ]
          }
        ]
      }
    }

Their scripts share a discipline worth copying — fail open, filter
hard, print at most one short line:

    #!/usr/bin/env bash
    # Fail open: never block the prompt.
    {
      input=$(cat)
      prompt=$(printf '%s' "$input" | jq -r '.prompt // empty') || exit 0
      case "$prompt" in "/"*) exit 0 ;; esac  # slash commands opt out
      # ...narrow trigger test here...
      echo "one short, actionable reminder"
    } 2>/dev/null
    exit 0

The script reads a JSON payload on stdin, exits 0 no matter what goes
wrong, and prints nothing unless its narrow trigger matches.

## Discipline

Hooks fire mechanically on every match — no judgment sits between the
event and your script. Design for that:

- Keep output short. Whatever a hook prints lands in context on every
  firing; a noisy hook taxes every single prompt in every session.
- Make silence the common case. Filter aggressively and print only when
  the trigger genuinely matches; most firings should emit nothing.
- Keep it fast. The script runs inline with the user's action; a slow
  hook is latency added to everything, forever.
- Keep it deterministic. Same input, same output — no network calls, no
  clock-dependent branches, nothing that makes firings unreproducible.
- Fail open. Wrap the body, swallow stderr, exit 0 on any error. A
  buggy hook must degrade to a no-op, never block the user.

## When NOT to hook

If a skill description can trigger the behavior contextually, prefer
the skill. Hooks are for guarantees, skills for judgment:

- Guarantee — "this check must run on every matching event, no
  exceptions" — is a hook.
- Judgment — "when doing X, apply this knowledge" — is a skill; the
  dispatcher weighs relevance instead of firing blindly.

A hook that encodes judgment fires when it should not and pays its
context tax anyway. Reach for a hook only when missing even one firing
is unacceptable.

## Failure modes

- Non-executable script. The file exists but was never chmod +x; the
  hook silently does nothing and validation fails.
- Absolute paths instead of ${PLUGIN_ROOT}. Works on the
  author's machine, breaks on every install.
- Output flooding. Multi-line dumps on UserPromptSubmit bury the
  user's actual prompt under boilerplate, every single time.
- Failing closed. A script that exits non-zero on an internal error
  can block the very action the user asked for.
- Invalid JSON. A trailing comma in hooks.json disables every hook in
  the plugin at once; run jq empty on it before committing.
