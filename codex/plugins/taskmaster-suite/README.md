# taskmaster-suite for Codex

Generated from `plugins/taskmaster-suite`. Edit source or explicit adapters, then run
`python3 scripts/build_codex.py --write` in the marketplace checkout.

## Skills

- `manage-suite`

## Compatibility

Suite dependencies require the bundled manage-suite workflow.

Commands are skills; worker roles are references with native delegation or inline execution.
See [the execution contract](references/codex.md).

Hook events configured: none.

Source hook limitations and replacements: {}.

Hooks require host trust. Transcript-dependent source helpers are not Codex verification.
Python 3 and jq are needed for hook adapters; shell and Node helpers retain their own requirements.
