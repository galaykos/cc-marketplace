# Changelog

All notable changes to the session-hud plugin.

## 0.2.0 — 2026-10-25

- **The hint line and the turn line are off by default** (`cc_hud_hint`, `cc_hud_turn`; `CC_HUD_HINT`, `CC_HUD_TURN`). A `statusLine` you wired yourself already shows context, limits, cost, time and branch, and two copies of them is noise; the `/hud` pane and the subagent rows, which no status line can show, stay on. Turn either line back on in `/config`. Gate: `tests/hud.test.ts`, "draws no hint line and no turn line by default".
- **The shared mod kit exports `hostOf` and runs the git-root lookup once per hook call.** `hooks/cc-kit.ts` (byte-identical in every mod plugin) now exports the host adapter that seven feature files pasted, and remembers `stateRoot` per host object, so a hook that asked three times runs `git rev-parse` once. It also carries `countOutcome`, a counts-only `$.store` tally.

## 0.1.2 — 2026-10-15

- **The turn line counts the whole turn across a subagent's turn.** Since Claude Code 2.1.299 a subagent's or teammate's turn raises `turn.start` too, and the module took a new cost and context baseline on every one, so a turn whose subagent started midway showed `$0.03` where it had spent `$0.08`. A `turn.start` carrying `agentId` now leaves the baseline and the footers alone. On 2.1.291–2.1.298 a subagent's turn raises no `turn.start`, so nothing changes there. Standing: gate — `tests/hud.test.ts` "counts the whole turn's cost across a subagent's turn start", red against 0.1.1.
- **The README says the subagent row's type needs 2.1.293.** The host sends `agentType` from 2.1.293; on 2.1.291–2.1.292 the row leaves the type out and shows the rest. Standing: gate — `scripts/__tests__/subagent-statusline.test.sh` "no agentType (CLI below 2.1.293): the row drops the type".

## 0.1.1 — 2026-10-15

- The shared mod kit (`hooks/cc-kit.ts`) is synced to the copy that reads the branch with `git symbolic-ref -q HEAD`. This plugin does not call the changed function (`activeRun`), so nothing it does changes.

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
