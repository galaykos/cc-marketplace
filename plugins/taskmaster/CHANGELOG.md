# Changelog — taskmaster

Consumer-facing changes only. A version bump with nothing here is a number; this
file is what makes an upgrade readable. Newest first. It starts at 0.50.0: earlier
releases were not recorded here.

## 0.50.0 — 2026-10-22

- **The clarify directive names two checkable forms and no skip.** On a work-shaped prompt
  it said "run one batched clarifying round to zero ambiguity, or state in one line why this
  task is trivial enough to skip it"; in the sessions the 2026-10-21 retro read it fired 50
  times in 30 days and was ignored. It now says: before the first code edit, either ask one
  batched AskUserQuestion round, or write one line starting `Assuming:` that names what the
  model decided for you; at a later fork you have not answered, ask, do not default. On a
  prompt naming an auth surface its second line now reads "ask; an Assuming: line does not
  cover it". Standing: gate for the wording — `scripts/__tests__/clarify-gate.test.sh` "the
  reminder says: …" and "the reminder offers no trivial skip", red against 0.49.1, and
  `scripts/smoke/hook-guard-tests.sh` the tm_auth cases; whether the model then asks is
  agent-graded.
- **The clarify gate is on by default and checks the transcript.** It shipped
  `"cc_clarify_gate": "off"`, and when on it refused the first write of a session whatever
  had happened. Now it refuses the main thread's first `Edit`, `Write` or `MultiEdit` after a
  work-shaped prompt unless, since that prompt, the transcript holds an AskUserQuestion call
  or an assistant line starting `Assuming:`; at most once per work-shaped prompt, so the next
  write goes through. A later prompt of yours that is not work-shaped disarms it, and a
  subagent's write is neither judged nor spends it — told apart by the payload's `agent_id`
  as well as a `/subagents/` transcript path, since a worker's payload can carry the parent's
  transcript path (gate: the `agent_id set` case, red against this version's first cut, where
  the worker's write was refused and spent the marker). The refusal names `CC_CLARIFY_GATE=off`,
  which turns it off, as does the `cc_clarify_gate` option. Measured before the default
  changed, replaying the real hooks over three sessions in this marketplace's own repository
  (479f845f, f5492e65, 25f72aab): 3 work-shaped prompts, 1 would have been refused, 0 of
  those followed by an AskUserQuestion in the same turn; over all 11 sessions in that
  project, 9 work-shaped prompts and 4 refusals, 2 of them followed by one. Standing: gate —
  `clarify-gate.test.sh`, 9 more assertions red against 0.49.1 (the default refusal, the bound,
  an allowed write spending the marker, evidence older than the prompt, `Assuming` without the colon or mid-line, the disarm, a
  harness frame keeping the gate armed, the main thread after a worker). Residual: Bash
  writes are not seen; a turn that only delegates is never refused; any `Assuming:` line
  passes, whatever it names, including on an auth-surface prompt; a missing transcript, no
  jq or an unreadable marker time means no refusal.
