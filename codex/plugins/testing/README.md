# testing for Codex

Generated from `plugins/testing`. Edit source or explicit adapters, then run
`python3 scripts/build_codex.py --write` in the marketplace checkout.

## Skills

- `command-flake-hunt`
- `command-review`
- `tdd`
- `testing-best-practices`

## Compatibility

Commands are skills; worker roles are references with native delegation or inline execution.
See [the execution contract](references/codex.md).

Hook events configured: PostToolUse.

Source hook limitations and replacements: {}.

Hooks require host trust. Transcript-dependent source helpers are not Codex verification.
Python 3 and jq are needed for hook adapters; shell and Node helpers retain their own requirements.
