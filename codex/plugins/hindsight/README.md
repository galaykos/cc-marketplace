# hindsight for Codex

Generated from `plugins/hindsight`. Edit source or explicit adapters, then run
`python3 scripts/build_codex.py --write` in the marketplace checkout.

## Skills

- `command-claude-md`
- `harvest`

## Compatibility

Commands are skills; worker roles are references with native delegation or inline execution.
See [the execution contract](references/codex.md).

Hook events configured: SessionStart.

Source hook limitations and replacements: {"collect.sh": "Automatic transcript collection is unavailable. Use the hindsight reflection skill to record outcomes explicitly.", "skill-use.sh": "Codex does not emit Claude Skill tool events. Record useful skill outcomes explicitly with hindsight."}.

Hooks require host trust. Transcript-dependent source helpers are not Codex verification.
Python 3 and jq are needed for hook adapters; shell and Node helpers retain their own requirements.
