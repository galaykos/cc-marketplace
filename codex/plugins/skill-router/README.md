# skill-router for Codex

Generated from `plugins/skill-router`. Edit source or explicit adapters, then run
`python3 scripts/build_codex.py --write` in the marketplace checkout.

## Skills

- `skill-router`

## Compatibility

Commands are skills; worker roles are references with native delegation or inline execution.
See [the execution contract](references/codex.md).

Hook events configured: SessionStart, UserPromptSubmit.

Source hook limitations and replacements: {"prime.sh": "Claude sibling-cache discovery is replaced by guidance to inspect Codex’s available skills catalog.", "route-prompt.sh": "Claude command catalog discovery is replaced by native prompt guidance to select a relevant available Codex skill.", "route.sh": "Automatic file-signal routing requires Claude cache discovery; consult available skill descriptions when changing a new surface.", "summary.sh": "Claude routing-ledger summaries are unavailable because native routing is skill-driven rather than inferred from tool events."}.

Hooks require host trust. Transcript-dependent source helpers are not Codex verification.
Python 3 and jq are needed for hook adapters; shell and Node helpers retain their own requirements.
