# approaches for Codex

Generated from `plugins/approaches`. Edit source or explicit adapters, then run
`python3 scripts/build_codex.py --write` in the marketplace checkout.

## Skills

- `approach-deliberation`
- `build-vs-buy`
- `command-compare`
- `command-opinions`
- `command-pattern`
- `command-rollout`
- `command-size`
- `estimation`
- `pattern-selection`
- `rollout-planning`

## Compatibility

Commands are skills; worker roles are references with native delegation or inline execution.
See [the execution contract](references/codex.md).

Hook events configured: UserPromptSubmit, SessionStart.

Source hook limitations and replacements: {}.

Hooks require host trust. Transcript-dependent source helpers are not Codex verification.
Python 3 and jq are needed for hook adapters; shell and Node helpers retain their own requirements.
