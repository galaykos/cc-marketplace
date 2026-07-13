---
description: Show intent-guard state — declared intent, criteria, this-turn touched targets, session base, and the last done-review verdict.
---

Report the current intent-guard state for this session.

1. State dir: `$cwd/.claude/intent-guard/`. If `intent.json` is missing, say the guard is not
   engaged this session and stop.
2. Read `intent.json` → print the declared intent **X**, its `source`, its `criteria`, and any
   `history` (prior redirects via `/intent-guard:intent`).
3. Read `base` → print the session-base commit sha (the point the done-review diffs against). If
   the file is absent, note the repo is non-git and the review falls back to the touched list.
4. Read `turn.log` → list the targets this turn has touched so far (one per line). If it is empty,
   say nothing has been touched this turn.
5. Report the **last done-review verdict** if you ran one this session — clean, or the open
   `DRIFT` / `CORNER-CUT` findings and how each was resolved. There is no review ledger to read;
   the verdict lives in the review you surfaced, not a file.
6. End with a one-line summary: `intent «X» · N target(s) this turn · base <sha> · <verdict>`.
