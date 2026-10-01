# What does a resumed subagent's transcript look like at SubagentStop? — probe, 2026-09-30

Measured on Claude Code **2.1.286**. Reader affected: candor's SubagentStop hand-back read in
`plugins/candor/hooks/gate.sh` — the `handback=` jq read, which judges the LAST
`SubagentHandback` `input.message` in the last 4000 lines of `agent_transcript_path`
(`plugins/candor/hooks/gate.sh:608-621` at commit `a743bd33`), and the `# Residual:` comment
above it (`plugins/candor/hooks/gate.sh:109-111` at the same commit). Standing of this note:
**recorded** — no script reads it back; the scoped read in that hook was written from its Verdict.
Extends `rationale/candor-subagent-probe-2026-09-29.md`, which recorded field names and tool
names for a single turn but no entry sequence and no resume.

## Method

A scratch directory outside every repository held one SubagentStop hook, passed only through
`--settings`; no user, project or managed settings file was edited, and nothing disabled the
plugins enabled in the user's own settings, so which other hooks ran alongside the dump hook
was not controlled. On every SubagentStop the dump hook saved the payload and a copy
of `agent_transcript_path` taken at hook time. One headless `claude -p` session
(`--max-budget-usd 2`, `--allowedTools Agent SendMessage`, prompt on stdin) told the main agent
to launch one general-purpose subagent that reports a first marker through SubagentHandback,
then to SendMessage the same subagent asking for a second marker as plain closing text with no
tool call, then to reply DONE. It replied DONE. Entry kinds were derived by script from the
saved copies; no id, path or message text is recorded here beyond the first characters of two
host-written frames, quoted below as host constants. The scratch directory was deleted
afterwards. One run: every shape below is one sample.

Three SubagentStop payloads fired, all for the **same `agent_id`: yes**. The transcript file grew
across them (12, 15, then 20 lines): a resumed turn is appended to the same file, not a new one.
A "user-text entry" here is `type:"user"` with string content or a
`text` block, not a `tool_result`, not injected context — and injected context is exactly
four forms (hook additionalContext, `<task-notification>`, `<system-reminder>`,
`Stop hook feedback:`), nothing else.

## First turn

Entries, in order: user entry (string — the task prompt: **user-text**); attachment; user entry
(string starting `<system-reminder>`, `isMeta: true` — **injected context**); eight attachments;
assistant `tool_use` SubagentHandback carrying the first marker. No hook additionalContext entry
appeared anywhere in the subagent's transcript, so its shape there is unobserved.

The first payload's copy ended AT the hand-back — the matching `tool_result` was not yet in the
file when the hook ran — and the payload carried no `last_assistant_message` key, because the
turn ended at the hand-back with no closing text. This differs from the 2.1.284 probe
(`rationale/candor-subagent-probe-2026-09-29.md:41-47`), where the hook-time copy already held
the `tool_result` and `last_assistant_message` held closing text written after the hand-back.
That may be this prompt's turn shape or a 2.1.286 change: both hand-backs in this run ended the
turn before their `tool_result` was in the copy, and one run cannot tell which. Either way, the
header of `plugins/candor/hooks/gate.sh:99-105` (at commit `a743bd33`) — "already written when
the hook fires" — held here for the hand-back itself and not for what follows it.

After the hand-back, the payload-3 copy shows: user entry (`tool_result`); attachment; then the next
turn. **Neither an injected-context entry nor closing text followed hand-back #1.** The harness's
non-resumed case (hand-back, `tool_result`, injected context, closing text) is therefore an
extrapolation built from the 2.1.284 shape, not a shape this probe saw.

## Resumed turn

Entries after the first turn's `tool_result` and attachment: user entry (string, `isMeta: true`
— the SendMessage text inside a host-written frame whose first characters are
`The coordinator se`; not one of the four injected-context forms, so **user-text**); assistant
thinking; assistant text carrying the second marker.

The second payload fired here, with `last_assistant_message` holding that closing text. Its
transcript copy ended at the SendMessage entry: **the closing text was not yet in the file**. So
the tail that payload's hook read held exactly the residual's input: one hand-back, the FIRST
turn's, and a closing text present only in `last_assistant_message`. candor's gate was not run on
that copy, so its verdict there is not recorded, and nor is what the parent received.

The host did not let the turn end there. It appended a user entry (string, `isMeta: true`, a
host-written frame whose first characters are `[handback-send-enf`, asking for a hand-back — not
one of the four forms, so **user-text**), then assistant thinking, then hand-back #2 carrying the
second marker. The third payload fired with `stop_hook_active: true` — whether set by that host
enforcement or by an installed Stop/SubagentStop hook is not recorded — and no
`last_assistant_message` key. Its copy ended at hand-back #2, so the entries after hand-back #2
were not captured; the Verdict's third line rests on hand-back #1.

## What this means for a scoped read

- **`isMeta` does not separate the kinds.** The system reminder, the SendMessage frame and the
  host's hand-back nudge all carry `isMeta: true`; the original task prompt carries none. A rule
  that skips `isMeta` entries would skip the resume boundary itself. Classify by content prefix:
  a string (or first text block) starting `<task-notification>`, `<system-reminder>` or
  `Stop hook feedback:` is injected context. The fourth form, hook additionalContext, has no
  prefix of its own and its shape in a subagent transcript was not observed: it is excluded only
  if it lands as a non-`type:"user"` entry (such as an attachment), and a `type:"user"`
  additionalContext entry would read as user-text — a residual the scoped read's header must
  name. Exclude any other host frame only if it cannot be the boundary: the subagent-side
  SendMessage frame observed here starts `The coordinator se`, which none of the PARENT side's
  frames in `plugins/ask-ledger/hooks/ledger.sh:93-97` matches — but a list copied without that
  check could drop the boundary on a host whose frame reads differently, and the read would then
  judge the earlier hand-back again.
- **The file can lag the payload.** Both hand-backs' `tool_result` entries and the resumed
  turn's closing text were absent from the copy taken when their SubagentStop fired, while the SendMessage
  entry — the boundary — was the LAST line of the payload-2 copy. A scoped read must take the
  closing text from `last_assistant_message`, and its header must name the residual: had the file
  lagged by one more entry, the boundary would be missing and the read would judge hand-back #1
  again.

## Verdict

RESUME_OBSERVED: yes
USER_TEXT_BETWEEN_TURNS: yes
USER_TEXT_AFTER_HANDBACK_IN_ONE_TURN: no
