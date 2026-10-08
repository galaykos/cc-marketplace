# Mods UI surfaces — external survey and pane-close probe (2026-10-08)

Purpose: decide which UI mods (status line, pinned panes, per-turn info) this marketplace
should build, from what the host documents, what the most-installed third-party plugins
ship, and what the engine actually does when a person closes a pane.

**Standing: `recorded`** — a one-time survey and measurement; nothing re-runs it.

## 1. What the host allows (doc-stated unless marked)

Sources, accessed 2026-10-08: `https://code.claude.com/docs/en/plugins/mods/{overview,interface,reference,events,api,test}`,
`.../plugins/manifest-reference`, `.../statusline`, `.../changelog`; the CLI-written
`claude-code` type file (2.1.294, `templates/mods/kit-harness/.claude-plugin/types/`).

- **Main `statusLine`: a plugin cannot ship or replace it.** Plugin `settings` honour only
  `agent` and `subagentStatusLine` (manifest-reference). There is no `ui.render` site for the
  status-line row, so a mod cannot add a segment to the user's command output either
  (inferred from the site list: `AskUserQuestion UserMessage AssistantMessage ToolUse
  ToolResult ToolGroup ToolProgress CommandOutput Spinner TurnDuration InfoNotice
  SessionMode PromptHint AbovePrompt Pane`).
- **What a mod can draw instead:**
  - `$.ui.status(text)` — one pinned line per plugin under the prompt.
  - `PromptHint` — `tail` appends to the dim hint line; a rewrite of `hint` replaces it.
  - `TurnDuration` — the line that closes a turn (`word`, `durationMs`).
  - `AbovePrompt` — the band, shared by every mod.
  - `Pane` — opened with `$.ui.open`. Unasked, it waits undrawn below 144 columns (110 once
    the person opened that id).
  - `$.session.usage()` returns `{ startedAt, context, rateLimits, cost }` "as the status
    line has them", so every figure a status-line tool shows is available to a mod with no
    settings.json edit.
- **`subagentStatusLine`** is the one status line a plugin CAN ship (plugin `settings`).
- **`/config`:** `userConfig` fields become rows. `config.describe` relabels or hides any row,
  and `config.set` clamps or denies a change. No API adds a row that is not a `userConfig`
  field (inferred).
- **Pane close:** the type file says "a hook answering without `next` keeps the pane open,
  save on an unload". The prose pages say only that `ui.close` fires when "a pane is about
  to close". §3 measures it.

## 2. What the most-installed third-party plugins ship

Stars from the GitHub API, 2026-10-08. Install counts are as the listing page showed them.

| Item | Size | What users install it for |
|---|---|---|
| obra/superpowers | 296.7k★, 1.0M installs (claude.com/plugins) | brainstorm → plan → subagent build flow; enforced TDD; auto-firing skills behind one SessionStart bootstrap |
| mattpocock/skills | 280.8k★ | `/grill-me` interviews before code; glossary; `/tdd`; user-invoked skills are one-line handoffs to model-invoked primitives |
| DietrichGebert/ponytail | 158.3k★ | "does this need to exist" ladder before code; `/ponytail lite\|full\|ultra\|off` modes; `[PONYTAIL:ULTRA]` status-line badge read from a flag file |
| affaan-m/ECC | 275.3k★ | huge catalogue gated by install profiles, opt-in hooks, `ECC_DISABLED_HOOKS`, a capped SessionStart payload |
| anthropics/claude-plugins-official | 37.5k★ | the official directory; frontend-design at 1.13M installs |
| jarrodwatts/claude-hud | 28.4k★ | status line: model, path and git, context and usage bars; tools, agents and todos from the transcript; `/claude-hud:configure` with a preview |
| ccusage statusline | 18.9k★, 557k npm/month | session, day and 5-hour block cost, burn rate, context |
| sirmalloc/ccstatusline | 13.2k★, 154k npm/month | an Ink TUI configurator, unlimited lines, powerline themes |
| Owloops/claude-powerline | 1.2k★ | setup wizard plus a web configurator, themes, a grid that drops empty segments |

Segments the status-line tools converge on:
- model and effort;
- git branch, dirty marker, ahead/behind;
- context % against the auto-compact window;
- 5-hour and 7-day rate-limit windows with reset countdowns;
- session, day and week cost;
- session duration;
- subagents and todo progress.

Every one of them needs a hand edit to `settings.json`, which is the setup step a plugin
cannot do for the user.

Persistent-pane demand:
- anthropics/claude-code#91870 (mods thread) asks for public prompt-bar, sidebar and
  status-line components;
- anthropics/claude-code#6654 (182 👍, closed) asks for an always-visible task list;
- anthropics/claude-code#99449 asks for fixed regions inside mod panes;
- sirkitree/pinboard pins decisions and todos in the band.

## 3. Probe: can a mod keep a pane open?

Method:
- Two throwaway plugins under `mktemp -d` (`/tmp/pane-pin-probe.pEzPvK`), loaded with
  `--plugin-dir`.
  - `probe-pane-a` opens pane `pa` from a `/pa-open` command.
  - `probe-pane-b` opens `pb` from `/pb-open`, and registers one unmatched `ui.close` hook.
    The hook logs `{id, origin}` and refuses a `person` close of any id in `PIN_IDS`.
- Driven with python `pexpect` and the `pyte` VT emulator on CLI 2.1.294, terminal surface,
  docked pane.
- Scratch `CLAUDE_CONFIG_DIR`, a placeholder API key, and `ANTHROPIC_BASE_URL` pointed at a
  closed port. Commands only, so no model request was made.
- A person close is Ctrl+X Tab (focus the pane), then Ctrl+X X. Unfocused, Ctrl+X X raised
  nothing. An SGR mouse click on ✕ also raised nothing in this emulator, so the close mark is
  untested.

| Case | `ui.close` seen by b | Pane after | `$.ui.panes()` after |
|---|---|---|---|
| person closes b's own `pb`; hook returns bare | yes, `origin.kind: person` | **closed** | `[]` |
| same; hook returns `{}` | yes | **closed** | `[]` |
| person closes a's `pa`; b's hook returns `{}` | **yes — another plugin's close is visible** | **closed** | a: `[]` |
| `$.ui.close` from b's own command | yes, `origin.kind: plugin` | closed | — |
| person closes `pb`; hook calls `next`, then `$.ui.open` again 100 ms later, 200 columns | yes | **re-opened, `isPlaced: true`, stays drawn** | `pb` listed |
| same at 130 columns | yes | gone from screen: `isPlaced: false`, "unasked below 144 columns (130 now)" | `pb` listed, `isShown: false`, `isPlaced: false` |

Findings:
- **The type file's veto does not hold on 2.1.294.** Answering a person's `ui.close` without
  `next` still closes the pane.
- **prompt-coach's "He cannot be closed"** (`plugins/prompt-coach/README.md:136`, CHANGELOG
  0.3.0) relies on exactly that veto, with a bare return (`hooks/coach.ts:712`). So the claim
  is false on this CLI. The README already marks it **recorded**; this measures it wrong.
  prompt-coach 0.3.2 switched to reopening, and that was seen live at 200 columns, with the
  pane waiting undrawn at 130.
- **A pane is pinnable only by re-opening it.** That works for the plugin's own panes, and
  only on a terminal of 144 columns or more. Narrower, the pane waits undrawn until the
  terminal widens or the person reopens it.
- **A mod sees another plugin's pane close but cannot keep it.** The veto fails, and
  `$.ui.open` opens only the caller's own panes.
- Untested: the close mark (mouse), the desktop surface, an inline (above-prompt) pane, and
  `closeOnEscape` closes.

## 4. Probe: a plugin's `subagentStatusLine`

Method:
- The same driver against the real logged-in config, `--model haiku`, in a scratch git repo,
  with `CC_PROMPT_COACH=off`.
- Each run is one prompt that spawns an `Explore` subagent.
- The plugin's root `settings.json` names a logging script that appends its environment and
  stdin to a file.

| `command` in the plugin's `settings.json` | Ran? | What it received |
|---|---|---|
| an absolute path | yes, once per tick | the documented `{columns, tasks[]}` plus the base hook fields; **no `CLAUDE_PLUGIN_ROOT`, no `CLAUDE_PLUGIN_OPTION_*`** in its environment |
| `${CLAUDE_PLUGIN_ROOT}/scripts/…` | **no** — the subagent ran, nothing was logged, and the panel kept its default rows | — |

Findings:
- **The default setting applies.** A plugin's `subagentStatusLine` takes effect when the user
  has none of their own.
- **The command cannot find its own script.** It names nothing inside the plugin: neither the
  substitution nor the variable exists.
- **session-hud 0.1.0's workaround:** its module writes `$.plugin.root` to
  `${CLAUDE_CONFIG_DIR:-~/.claude}/plugins/session-hud-root` at session start, and the command
  reads that file.
- **Its options must be read from `settings.json`.** The command gets no
  `CLAUDE_PLUGIN_OPTION_*`, the same reason candor's `statusline.sh` reads its option there.

## 5. session-hud, driven live (2.1.294, terminal, 200 columns)

- **Hint line:** `⏵⏵ auto mode on (shift+tab to cycle) · ← for agents · ctx 4% · 5h 12% ↻2h15m · 7d 8% ↻6d8h · $0.00 · <1m · main*`.
- **Turn line:** `410 out` on a line of its own. The first build drew it beside the engine's
  footer, and the footer's full-width row pushed it to the right edge, where it wrapped. That
  is why it sits on its own line.
- **Pane:** the docked body measured 23 columns, and `columns: 36` on `$.ui.open` did not
  widen it. The rows are sized for 23.
- **Pin:**
  - With `CC_HUD_PIN=on`, Ctrl+X Tab then Ctrl+X X left the pane drawn.
  - With it off, the same keys closed the pane. This is the control that makes the first
    result mean the reopen, not a close that never fired.
- **Subagent rows** were drawn through the pointer:
  `◯ Explore · haiku-5-5 · 50 0% · 4s · List current directory files`.
