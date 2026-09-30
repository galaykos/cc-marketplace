# SubagentStop payload on a hand-back subagent — probe, 2026-09-29

Measured on Claude Code **2.1.284**. Reader affected: candor's Stop/SubagentStop gate,
`plugins/candor/hooks/gate.sh:96-99` (the payload shape it records, last measured on
2.1.267) and `:543-547` (where it picks the report text: `last_assistant_message`, else the
last assistant `text` block of the transcript tail). Standing of this note: **recorded** —
no script reads it back.

## Method

A scratch directory outside every repository held a one-off SubagentStop hook, passed to one
headless session through `--settings` (never written to any settings file, and deleted after
the run). The hook saved each SubagentStop payload and, at the moment it fired, a copy of the
file named by the payload's `agent_transcript_path` — so the copy shows what that transcript
held when the hook ran, not what it held later.

The session's main agent launched two general-purpose subagents with the Agent tool and
replied only after both finished. Subagent A ran with default settings and was told to put
marker A in a one-sentence report, delivering it through `SubagentHandback` if it had that
tool. Subagent B ran with `run_in_background: false` and was told to call no tool and end
with marker B as its final text. Neither marker carries a `:` digit suffix, so candor's
citation clause could not match them. The run produced exactly two SubagentStop payloads,
both with `stop_hook_active` false, so no hook blocked either subagent. Every fact below was
derived with `jq` over field names, types and marker presence. No message text is recorded
here.

## Subagent A — hand-back

- **Payload fields and types:** `session_id` string, `transcript_path` string (the parent's),
  `cwd` string, `prompt_id` string, `permission_mode` string, `agent_id` string, `agent_type`
  string (`general-purpose`), `effort` object (`level` string), `hook_event_name` string,
  `stop_hook_active` boolean (false), `agent_transcript_path` string, `last_assistant_message`
  string, `background_tasks` array of objects (`id`, `type`, `status`, `description`,
  `agent_type`, all strings; one entry, of type `subagent`, status `running`),
  `session_crons` array (empty).
- **New since 2.1.267:** `prompt_id`, `permission_mode`, `effort`, `background_tasks` and
  `session_crons`. No payload field names the hand-back.
- **Marker A in the payload:** only in `last_assistant_message`.
- **Tool names in the subagent's own transcript at hook time:** `SubagentHandback` only. Its
  `input` has one key, `message`, and marker A is in it.
- **Was the hand-back already in the transcript when the hook fired?** Yes. The copy taken
  inside the hook holds the `SubagentHandback` tool_use and its result, 20 lines in all.
- **What `last_assistant_message` holds:** closing text written AFTER the hand-back. It is not
  the hand-back message. It is several times longer, does not contain it, and here restated
  marker A only because the model chose to. The transcript copy taken at hook time holds
  **no** assistant `text` block. A read of the same file after the session ended found two
  more lines than that copy.

## Subagent B — asked for plain final text

- **Payload fields:** the same keys and types as A's, with `background_tasks` empty.
- **Tool names in the subagent's own transcript at hook time:** `SubagentHandback` only, with
  one `input` key, `message`, which carries marker B. B was told to call no tool and handed
  back anyway: here, a general-purpose subagent under `-p` did so despite that instruction.
- **Was the hand-back already in the transcript when the hook fired?** Yes. It is in the
  hook-time copy (21 lines), and that copy has no assistant `text` block, the same as A's.
- **What `last_assistant_message` holds:** closing text ending in marker B. It does not contain
  the hand-back message. Marker B is in no other payload field.
- **The plain-text case was not produced.** B handed back like A, so this run has no subagent
  that ended WITHOUT a hand-back. The fallback for such a subagent (its final text in
  `last_assistant_message`, as measured on 2.1.267) is not re-measured here.

## What this means for gate.sh

For the reader at `plugins/candor/hooks/gate.sh:543-547`:
- It checks the closing text, not the report. The fallback to the transcript tail does not run
  when `last_assistant_message` is non-empty, as it was in both runs here.
- In the one hook-time copy per subagent, the tail held no assistant text block, so the tail
  fallback would have found nothing there.
- The report itself is the last `SubagentHandback` tool_use in `agent_transcript_path`, as
  `input.message`, and it was in the file when the hook fired, in both runs.

## Untested

- a subagent that ends without calling `SubagentHandback` (neither subagent here did);
- a hand-back with no closing text, which would leave `last_assistant_message` empty;
- whether closing text can reach the file before candor's own tail read, which runs in its
  own process beside any other SubagentStop hook (sampled once per subagent here);
- whether exit 2 at SubagentStop withholds a hand-back the tool call already delivered;
- a subagent type other than general-purpose, and an interactive session.

## Verdict

REPORT_LOCATION: agent_transcript tool_use name=SubagentHandback input.message
PRESENT_AT_HOOK_TIME: yes
LAST_ASSISTANT_MESSAGE_ON_HANDBACK: closing-text
