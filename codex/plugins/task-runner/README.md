# task-runner for Codex

Generated from `plugins/task-runner`. Edit source or explicit adapters, then run
`python3 scripts/build_codex.py --write` in the marketplace checkout.

## Skills

- `behavioral-gate`
- `code-redteam`
- `command-plan`
- `command-run`
- `parallel-planning`
- `task-execution`
- `track-orchestration`

## Compatibility

Commands are skills; worker roles are references with native delegation or inline execution.
See [the execution contract](references/codex.md).

Hook events configured: PostToolUse, Stop, PreToolUse, SessionStart.

Source hook limitations and replacements: {"drift.sh": "Transcript drift detection is unavailable. Recheck the user request and active scope before each work batch.", "rv-observe.sh": "Claude Agent dispatch observation is unavailable. Record reviewer results explicitly using task-runner scripts.", "partial": ["Completion state and HEAD checks remain active; transcript-based reduction disclosure checks are unavailable. Explicitly name every reduction and its reason in the closing report."]}.

Hooks require host trust. Transcript-dependent source helpers are not Codex verification.
Python 3 and jq are needed for hook adapters; shell and Node helpers retain their own requirements.
