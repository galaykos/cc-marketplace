# ui-ux for Codex

Generated from `plugins/ui-ux`. Edit source or explicit adapters, then run
`python3 scripts/build_codex.py --write` in the marketplace checkout.

## Skills

- `a11y-audit`
- `aceternity-best-practices`
- `astryx-best-practices`
- `command-audit`
- `command-build`
- `command-review`
- `command-theme`
- `component-libraries`
- `design-tokens`
- `motion-best-practices`
- `mui-best-practices`
- `reui-best-practices`
- `shadcn-best-practices`
- `shadcn-theming`
- `tailwind-best-practices`
- `theming-system`

## Compatibility

Commands are skills; worker roles are references with native delegation or inline execution.
See [the execution contract](references/codex.md).

Hook events configured: PostToolUse, SessionStart.

Source hook limitations and replacements: {"preview-guard.sh": "Codex has no Claude Artifact event. Run a rendered preview and verify the UI before presenting it."}.

Hooks require host trust. Transcript-dependent source helpers are not Codex verification.
Python 3 and jq are needed for hook adapters; shell and Node helpers retain their own requirements.
