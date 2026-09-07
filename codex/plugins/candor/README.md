# candor for Codex

Generated from `plugins/candor`. Edit source or explicit adapters, then run
`python3 scripts/build_codex.py --write` in the marketplace checkout.

## Skills

- `command-check`
- `straight-talk`

## Compatibility

Commands are skills; worker roles are references with native delegation or inline execution.
See [the execution contract](references/codex.md).

Hook events configured: SessionStart.

Source hook limitations and replacements: {"gate.sh": "Automatic candor transcript gating is unavailable. Before finalizing, use the candor skill to verify claims, unresolved risks, and omissions against actual evidence."}.

Hooks require host trust. Transcript-dependent source helpers are not Codex verification.
Python 3 and jq are needed for hook adapters; shell and Node helpers retain their own requirements.
