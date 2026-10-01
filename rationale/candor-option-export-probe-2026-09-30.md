# Does a saved plugin option reach the Bash tool? — probe, 2026-09-30

Measured on Claude Code **2.1.286**. Reader affected: candor's `/candor:level`, `/candor:check`,
`plugins/candor/scripts/measure.sh` and the statusline, which cannot see a level set only through the `cc_terse`
/config option. Standing of this note: **recorded** — no script reads it back;
`plugins/candor/scripts/level.sh` was written from its Verdict.

## Method

A scratch directory outside every repository held a copy of `plugins/candor`, loaded with
`--plugin-dir` (plugin id `candor@inline`), and a scratch settings file passed with `--settings`
that saved `pluginConfigs["candor@inline"].options.cc_terse` as a level. No user, project or managed
settings file was edited. The candor copy carried one extra UserPromptSubmit hook, the positive
control: it recorded whether `CLAUDE_PLUGIN_OPTION_CC_TERSE` was set in its own environment. The
2026-09-29 note measured each declaring plugin's hook seeing only its own value
(rationale/host-features-2026-09-29.md:271-274); whether a hook outside candor sees it is
unmeasured, so the control was placed inside candor. One headless `claude -p` session (`--max-budget-usd 1`, `--allowedTools Bash`) asked the
model to run a single Bash command that prints PRESENT or ABSENT for the same variable, and to
reply with that word. The scratch directory was deleted afterwards.

## Result

- **Positive control: yes.** candor's own UserPromptSubmit hook saw the saved option. This also
  extends the 2026-09-29 measurement (rationale/host-features-2026-09-29.md), which had seen
  `CLAUDE_PLUGIN_OPTION_*` only in a SessionStart hook: a UserPromptSubmit hook receives it too.
- **Bash tool: ABSENT.** The model's Bash tool environment did not carry
  `CLAUDE_PLUGIN_OPTION_CC_TERSE`, although the option was saved and the plugin's hook received it
  in the same session.

So a command (run through the model's Bash tool) cannot rely on the variable; it must read the
option from settings, as `plugins/candor/scripts/level.sh` does. Scope measured: one `-p` session, a `--plugin-dir` load, the
option saved through `--settings`. Not probed: a statusLine process, an interactive session, and a
marketplace-installed plugin with the option saved in user settings.

## Verdict

OPTION_IN_BASH_TOOL: no
POSITIVE_CONTROL: yes
