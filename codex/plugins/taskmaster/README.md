# taskmaster for Codex

Generated from `plugins/taskmaster`. Edit source or explicit adapters, then run
`python3 scripts/build_codex.py --write` in the marketplace checkout.

## Skills

- `brainstorm`
- `command-brainstorm`
- `command-coverage`
- `command-redteam`
- `command-task`
- `command-taskmaster`
- `coverage-check`
- `erd`
- `experience-walkthrough`
- `grill`
- `spec-redteam`
- `task-cards`
- `ultra`
- `verify-teeth`
- `visual-decisions`

## Compatibility

Commands are skills; worker roles are references with native delegation or inline execution.
See [the execution contract](references/codex.md).

Hook events configured: UserPromptSubmit, PreToolUse, PostToolUse, SessionStart.

Source hook limitations and replacements: {"preview-guard.sh": "Codex has no Claude Artifact event. Follow the taskmaster preview protocol before presenting artifacts."}.

Hooks require host trust. Transcript-dependent source helpers are not Codex verification.
Python 3 and jq are needed for hook adapters; shell and Node helpers retain their own requirements.
