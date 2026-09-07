# resilience for Codex

Generated from `plugins/resilience`. Edit source or explicit adapters, then run
`python3 scripts/build_codex.py --write` in the marketplace checkout.

## Skills

- `command-concurrency-review`
- `command-error-review`
- `command-observability-review`
- `command-performance-review`
- `command-review`
- `concurrency-safety`
- `error-handling-design`
- `observability-design`
- `performance-tuning`
- `resilience-design`

## Compatibility

Commands are skills; worker roles are references with native delegation or inline execution.
See [the execution contract](references/codex.md).

Hook events configured: none.

Source hook limitations and replacements: {}.

Hooks require host trust. Transcript-dependent source helpers are not Codex verification.
Python 3 and jq are needed for hook adapters; shell and Node helpers retain their own requirements.
