# Changelog

All notable changes to the session-hud plugin.

## 0.1.0 — 2026-10-08

- First release: a hooks module (`hooks/hud.tsx`, Claude Code 2.1.291 or newer) and a default `subagentStatusLine`, all drawn without a `settings.json` edit.
- **Hint line.** Context %, the rate-limit windows with reset countdowns, cost, session time and git branch at the end of the hint line under the prompt (`cc_hud_hint`, `cc_hud_segments`).
- **Status line.** The same segments as a status line, off by default because the engine prefixes it with `⚠` (`cc_hud_status`).
- **Turn line.** A turn's output tokens, cost and context growth under its closing line (`cc_hud_turn`).
- **`/hud` pane.** The context by category, the compaction point, the rate-limit windows and the session.
  - Opt-in pin (`cc_hud_pin`): the pane reopens after a hand close.
  - Refusing a close does not keep a pane open on 2.1.294, which is why it reopens instead (`rationale/2026-10-08-mods-ui-survey-and-pane-probe.md`).
- **Subagent rows** (`cc_hud_subagents`).
  - Each row shows the subagent's type, model, effort, tokens and context %, age and label.
  - The rows find their script through a pointer file the module writes, because the command gets no `${CLAUDE_PLUGIN_ROOT}` (measured on 2.1.294).
