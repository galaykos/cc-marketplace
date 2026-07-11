---
description: Set or override the declared task intent (X) that intent-guard attests actions against.
argument-hint: <one-line description of the current task>
---

Set the intent-guard task intent for this session to: **$ARGUMENTS**

1. State dir: `$cwd/.claude/intent-guard/` — create it if missing.
2. Read the existing `intent.json` if present; keep its `history` array (or start `[]`) and note
   its prior `intent` value.
3. Derive `criteria`: if a taskmaster run is active, read the current
   `taskmaster-docs/tasks/*/00-INDEX.md` card's acceptance criteria; otherwise infer 2–4 concrete,
   checkable criteria from `$ARGUMENTS`.
4. Write `intent.json` with the **Write tool** (a write to the state dir is exempt from the ledger,
   so this records no spurious action):
   ```json
   {
     "session_id": "<current session id if known, else empty string>",
     "intent": "$ARGUMENTS",
     "source": "cmd",
     "criteria": ["…"],
     "declared_at_seq": "<number of action rows currently in ledger.jsonl>",
     "history": ["…prior history…", {"from": "<prior intent or null>", "to": "$ARGUMENTS", "by": "cmd"}]
   }
   ```
5. Confirm the new intent and its criteria back to the user.

A user-initiated redirect is legitimate; it is recorded in `history` (shown by
`/intent-guard:status`) so the change stays visible. Do NOT redirect intent on your own initiative
to make a strayed action fit — that is the drift this guard exists to catch.
