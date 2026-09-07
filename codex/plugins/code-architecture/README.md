# code-architecture for Codex

Generated from `plugins/code-architecture`. Edit source or explicit adapters, then run
`python3 scripts/build_codex.py --write` in the marketplace checkout.

## Skills

- `coding-entry`
- `command-coding-task`
- `command-plan`
- `command-solid`
- `command-verify`
- `command-yagni`
- `drift-review`
- `low-cognitive-load`
- `plan-before-code`
- `solid-principles`
- `work-verification`
- `yagni-check`

## Compatibility

Commands are skills; worker roles are references with native delegation or inline execution.
See [the execution contract](references/codex.md).

Hook events configured: SessionStart.

Source hook limitations and replacements: {"evidence-gate.sh": "Automatic architecture transcript gating is unavailable. Before finalizing architecture work, explicitly verify the evidence checklist in the code-architecture skill."}.

Hooks require host trust. Transcript-dependent source helpers are not Codex verification.
Python 3 and jq are needed for hook adapters; shell and Node helpers retain their own requirements.
