# code-review for Codex

Generated from `plugins/code-review`. Edit source or explicit adapters, then run
`python3 scripts/build_codex.py --write` in the marketplace checkout.

## Skills

- `code-smells`
- `command-comment-review`
- `command-review`
- `comment-discipline`
- `reuse-hygiene`

## Compatibility

Commands are skills; worker roles are references with native delegation or inline execution.
See [the execution contract](references/codex.md).

Hook events configured: PostToolUse, PreToolUse, SessionStart.

Source hook limitations and replacements: {"verbosity.sh": "Transcript verbosity measurement is unavailable. Keep progress updates brief and focused on decisions and evidence."}.

Hooks require host trust. Transcript-dependent source helpers are not Codex verification.
Python 3 and jq are needed for hook adapters; shell and Node helpers retain their own requirements.
