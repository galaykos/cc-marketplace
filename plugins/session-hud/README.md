# session-hud

A session HUD for the terminal that needs no `settings.json` edit. A plugin cannot ship or
change your `statusLine`, so every status-line tool asks you to wire a command in by hand.
This plugin draws the same figures through the surfaces a plugin does own:

- the dim hint line under the prompt:
  `⏵⏵ auto mode on · ctx 4% · 5h 12% ↻2h15m · 7d 8% ↻6d8h · $0.01 · <1m · main*`
- a line under each turn's closing line with what that turn added: `410 out · $0.08 · ctx +6%`
- a `/hud` pane with the context window by category, the compaction point, each rate-limit
  window and the session. It can be pinned so it comes back after you close it.
- each subagent row in the agent panel: `◯ Explore · haiku-5-5 · low · 12k 1% · 1m05s · Reading README.md`

It needs Claude Code 2.1.291 or newer with mods allowed. It draws in the terminal only,
because the hint-line tail and the turn line exist only there. It makes no model calls.

```bash
claude plugin install session-hud@cc-plugins-marketplace -s local
```

## What it ships

| Artifact | Kind | Does |
| --- | --- | --- |
| `hooks/hud.tsx` | hooks module, the only `modules` entry | reads `$.session.usage()` and git; draws the hint-line tail, the optional status line, the turn line and the `/hud` pane; reopens a pinned pane |
| `/hud` | command the module registers | shows the pane, or hides it if it is showing |
| `settings.json` → `subagentStatusLine` | plugin default setting | runs `scripts/subagent-statusline.sh` for the agent panel's rows |
| `scripts/subagent-statusline.sh` | script | one row per subagent: name, type, model, effort, tokens and context %, age, label; ✓ completed, ✗ failed or killed |

## Segments

`cc_hud_segments` picks which segments show and in what order. The default is
`context,limits,cost,time,git`.

| Segment | Shows | Source |
| --- | --- | --- |
| `context` | `ctx 43%`, once the first answer has arrived | `$.session.usage().context.percent` |
| `limits` | `5h 61% ↻2h05m`, `7d 12%`: each rate-limit window, with a countdown to its reset | `rateLimits` from the last API response |
| `cost` | `$1.20`, the session's cost as `/cost` totals it | `cost.usd` |
| `time` | `42m`, how long the session has run | `startedAt` |
| `git` | `main*`, the branch, starred when tracked files have changes | `git rev-parse` and `git status --porcelain --untracked-files=no`; runs only when the segment is picked for a shown line, or while the `/hud` pane is open |

The figures refresh:
- at session start;
- after a main-agent tool call, at most once every 2 s;
- at each turn's end;
- every 30 s, so countdowns and the session time move between turns.

If your own `statusLine` already shows these figures, set `cc_hud_segments` to what it
lacks, or turn the hint line off.

## Options

Each is a `/config` row. The environment variable named in its title overrides it.

| Option | Default | Does |
| --- | --- | --- |
| `cc_hud_hint` (`CC_HUD_HINT`) | on | the segments on the hint line |
| `cc_hud_status` (`CC_HUD_STATUS`) | off | the segments as a status line under the prompt as well. The engine starts every plugin status line with `⚠ session-hud:`, so it reads like a warning, which is why it is off by default |
| `cc_hud_turn` (`CC_HUD_TURN`) | on | the line under each turn's closing line |
| `cc_hud_segments` (`CC_HUD_SEGMENTS`) | `context,limits,cost,time,git` | which segments, comma-separated, in order; unknown names are ignored |
| `cc_hud_pin` (`CC_HUD_PIN`) | off | reopen the `/hud` pane after you close it by hand |
| `cc_hud_subagents` (`CC_HUD_SUBAGENTS`) | on | the subagent rows; off leaves the panel's default rows |

## Pinning the pane

With `cc_hud_pin` on, closing the pane yourself (its ✕, or Ctrl+X then X while it has
focus) lets the close happen, then reopens the pane 100 ms later. `/hud` still closes it
for good.

- **The engine has no way to refuse a close.** The CLI's type file says a `ui.close` hook
  that answers without calling `next` keeps the pane open. On 2.1.294 it does not: the pane
  closed every time (`rationale/2026-10-08-mods-ui-survey-and-pane-probe.md` §3). Reopening
  is the only pin that works.
- **The 144-column floor.** A pane the plugin opens without being asked is drawn only on a
  terminal at least 144 columns wide. Narrower, the reopened pane waits undrawn until the
  terminal widens or you run `/hud`.
- **Only this plugin's pane.** A mod sees another plugin's pane close, but it can reopen
  only its own panes.

## Standing

- **Gate:** the segments, their order and their off-switches, the hint-line tail added after
  another plugin's tail, the status line off by default, the turn line and when it is left
  out, `/hud` opening and closing, and the pane's rows fitting the 23-column docked body
  (`tests/*.test.ts`, run by `claude plugin test` in CI's `scripts/mod-tests.sh`); the
  subagent rows, the width cut, and the three off sources
  (`scripts/__tests__/subagent-statusline.test.sh`).
- **Recorded:** the reopen after a person's close. The test kit cannot raise a person's close.
  It was driven live once on 2.1.294 at 200 columns: the pane stayed with the pin on, and the
  same keys closed it with the pin off.
- **Recorded:** the rest of what was seen live on 2.1.294 in the terminal:
  - the hint-line tail;
  - the turn line, shown under the engine's line because a sibling drawn beside it was
    pushed to the edge;
  - the pane's 23-column body;
  - the subagent rows drawn through the pointer below.

## Residuals, stated

- **The subagent command cannot find its own script without help.** On 2.1.294 a plugin's
  `subagentStatusLine` command gets no `${CLAUDE_PLUGIN_ROOT}`: it is neither substituted in
  the command text nor exported (measured).
  - The module therefore writes its install path to
    `${CLAUDE_CONFIG_DIR:-~/.claude}/plugins/session-hud-root` at session start, and the
    command reads it.
  - Before the first session with the plugin enabled, the rows stay default.
  - Uninstalling leaves that one-line file behind.
- **The subagent option is read in three places only.** The command does not receive
  `CLAUDE_PLUGIN_OPTION_*` either (measured). So `cc_hud_subagents` is read from
  `CC_HUD_SUBAGENTS`, then from `CLAUDE_PLUGIN_OPTION_CC_HUD_SUBAGENTS` if a host exports it,
  then from the user `settings.json`. An option saved at project or local scope is not read.
  The rows need `jq`; without it the panel keeps its default rows.
- **A turn line is matched to its turn by duration.** The footer has no turn id, so the first
  footer drawn within 1 s of the last turn's duration gets that turn's line.
  - Footers already drawn when the turn started never take it.
  - An earlier turn's footer scrolled into view for the first time after that, with a
    duration within 1 s, still could.
- **The cost is the API cost the session reports.** Model calls made by other plugins' mods
  (`$.model.complete`) are not in it, and neither are they in `/cost`.
- **Not seen live:** the desktop app, a mouse click on the pane's ✕, and the status line
  with `cc_hud_status` on.
