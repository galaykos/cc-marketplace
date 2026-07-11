---
description: Show intent-guard state — declared intent, action ledger, attested vs unattested, open drift.
---

Report the current intent-guard state for this session.

1. State dir: `$cwd/.claude/intent-guard/`. If `intent.json` is missing, say the guard is not
   engaged this session and stop.
2. Read `intent.json` → print the declared intent **X**, its `source`, its `criteria`, and any
   `history` (prior redirects via `/intent-guard:intent`).
3. Read `ledger.jsonl` → count action rows and number them **1..N by file order** (an action's seq
   is its ordinal; rows carry no seq field). List each seq with its `tool` and `target`.
4. Read `attest.json` → for each action seq, show `verdict` + `criterion` if a matching attestation
   entry has both non-empty, else mark it **UNATTESTED**. Separately list open drift (entries with
   `verdict:"drift"` and `accepted` not true).
5. End with a one-line summary: `N actions · A attested · U unattested · D open drift` — this is
   exactly what the Stop gate blocks on when `U > 0` or `D > 0`.
