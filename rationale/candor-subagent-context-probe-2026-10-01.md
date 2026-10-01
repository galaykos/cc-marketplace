# How does hook-injected context appear in a subagent's transcript? — probe, 2026-10-01

Measured on Claude Code **2.1.286**, one run. Reader affected: candor's SubagentStop hand-back
read in `plugins/candor/hooks/gate.sh`, whose header named a residual it could not measure — a
hook's `additionalContext` written as a `type:"user"` entry after a hand-back would read as
user-text and hide that hand-back. Standing of this note: **recorded** — no script reads it
back; the header of that hook was written from its Verdict. Extends
`rationale/candor-resumed-subagent-probe-2026-09-30.md`, which recorded no hook `additionalContext`
entry and did not record attachment kinds.

## Method

A scratch directory outside every repository held three hooks, passed only through `--settings`;
no user, project or managed settings file was edited, and nothing disabled the plugins enabled
in the user's own settings. Two hooks injected context, each printing
`hookSpecificOutput.additionalContext` with its own fixed marker and appending one line to a
scratch log (event, tool name, whether the payload carried an `agent_id`): `SubagentStart`, and
`PostToolUse` with matcher `*`. A `SubagentStop` hook saved its payload and a copy of
`agent_transcript_path` at hook time; a second copy of that file was taken after the session
ended. One headless `claude -p` session (`--max-budget-usd 1`, `--allowedTools Agent Read`, prompt
on stdin) told the main agent to launch one general-purpose subagent that makes one Read call and
then reports a marker through SubagentHandback. It replied DONE. Entry kinds were derived by
script; no id, path or message text is recorded here. The scratch directory was deleted
afterwards. Spend: one run under its $1 cap, of a $2 total allowed.

## What fired

Inside the subagent (payload carried an `agent_id`): `SubagentStart` once, `PostToolUse` after the
Read call, and `PostToolUse` after the SubagentHandback call. `PostToolUse` also fired once in the
main thread, after the Agent tool, with no `agent_id`. So every position this note reports on was
exercised; none is "the hook never ran".

## Entries

Each injection produced the same pair of entries, both `type:"attachment"`, never `type:"user"`:

- a `hook_success` attachment holding the hook's raw stdout (the marker sits in its `stdout`
  string), and
- a `hook_additional_context` attachment holding the context itself (the marker sits in its
  `content` list), tagged with the hook event and, for PostToolUse, the tool name.

Positions in the subagent's transcript:

- **SubagentStart:** the pair follows the task prompt (a `type:"user"` string entry) directly,
  before the host's own `<system-reminder>` user entry.
- **PostToolUse after Read:** the pair follows that call's `tool_result` user entry.
- **PostToolUse after the hand-back:** the pair follows the hand-back's `tool_result` user entry.
  Both the `tool_result` and the pair are in the copy taken after the session ended and NOT in the
  copy taken when SubagentStop fired, which ended at the hand-back `tool_use`. That is the same
  lag the 2026-09-30 note measured: the file trails the payload.

The only `type:"user"` entries in the whole transcript were the task prompt, the host's
`<system-reminder>` entry (`isMeta: true`), and the two `tool_result` entries. No user entry
carried either marker, so there was no content shape, leading prefix or `isMeta` value to record
for an injected-context user entry. The SubagentStop payload carried no `last_assistant_message`
key: the turn ended at the hand-back.

## What this means for the scoped read

- The classifier in `plugins/candor/hooks/gate.sh` counts only `type:"user"` entries as a
  boundary. `additionalContext` from these two events landed as attachments in this run — before
  and after a hand-back — so the type test excluded it.
- Not measured: a hook event other than these two; another hook output channel (a blocking
  reason, exit-2 stderr); another agent type; an interactive session; a host that writes the
  context as a user entry; a resumed turn with injected context between the turns. The residual
  stays named for those, narrowed to "a host or event that writes it as a `type:"user"` entry".
- Context after the hand-back exists, and in this run it was absent from the hook-time copy. A
  read that does see it must skip attachments, as the classifier does.

## Verdict

SUBAGENTSTART_CONTEXT_ENTRY: attachment
POSTTOOLUSE_CONTEXT_ENTRY: attachment
CONTEXT_AFTER_HANDBACK: yes
