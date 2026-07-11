---
name: intent-attestation
description: Use when working mid-run under a declared task and each action must be proven to still serve it — attest every Edit/Write/Bash/Agent action against the intent, catch drift (a cheaper strayed Y instead of the asked X), and clear the intent-guard Stop gate. Triggers on intent, attest, drift, stray, scope creep, or anti-cheat during active execution.
---

# Intent attestation

You are working under `intent-guard`. A declared task **X** exists; a PostToolUse hook records
every state-mutating action to a ledger; a Stop hook holds turn completion until each action is
attested against X and drift is resolved. This skill is your side of that contract.

This is **cooperative integrity, not a wall**. You own the state files — you *can* defeat the
gate. Do not. The value is that drift becomes recorded and confronted; keep it honest.

## INTENT-GUARD ACTIVE — Honor every line

```
- When the Stop gate fires at turn end, batch-attest every pending action against intent X.
- Attest by writing attest.json with the Write tool only — never Bash, never Edit.
- serves = name the specific X-criterion the action advances. drift = no criterion fits.
- On drift: stop, surface it, revert the stray or ask the user — do not paper over it.
- Never a false "serves". Never claim an action is attested that you did not reason about.
- Only the user's /intent-guard:intent may redirect X. A model-authored intent change IS drift.
- Establish a concrete X with criteria before grading. Never grade against a vacuous intent.
```

## 1 — Establish a usable X first

State: `$cwd/.claude/intent-guard/` holds `intent.json`, `ledger.jsonl`, `attest.json`.

Read `intent.json`. If it is **absent, stale, or vacuous** (broad wording, empty `criteria`),
establish a concrete intent before attesting anything:

1. If a taskmaster card is in play, read the active `00-INDEX.md` (the
   `taskmaster-docs/tasks/*/00-INDEX.md` referenced this session, else the most recent) and derive
   `criteria` from the current card's acceptance criteria.
2. Else ask the user for the one-line task and its success criteria.
3. Else state the working criteria explicitly in your reply, then record them.

Write the established intent with the Write tool:
`{"session_id":"<sid>","intent":"<X>","source":"card|prompt|cmd","criteria":["…"],"declared_at_seq":0}`.
A criteria-less X makes every action trivially "serve" — refuse to grade against it.

## 2 — Attest pending actions (at turn end)

When the Stop gate blocks at turn end — or before you declare the work done — batch-attest every
action not yet covered (you may attest earlier too; the gate is the backstop):

1. Read `ledger.jsonl`. Action rows are `{"kind":"action","tool","target","agent_id"}`. **An
   action's `seq` is its 1-based ordinal among action rows** (the first action row is seq 1) — rows
   carry no seq field; you assign it by counting.
2. For each action not yet attested, decide:
   - **serves** — name the exact `criterion` of X it advances.
   - **drift** — no criterion fits (a cheaper or off-task Y). Surface it now; revert the change or
     ask the user. Do not let it ride.
3. Write the whole `attest.json` (cumulative) with the Write tool:
   ```
   {"through_seq":<highest attested ordinal>,
    "attestations":[{"seq":1,"verdict":"serves","criterion":"…","note":"…","accepted":false}, …]}
   ```
   Every entry needs a non-empty `verdict` **and** `criterion` — the gate ignores empty ones.
   `accepted` stays `false` unless the user explicitly accepts a drift.

Writing `attest.json` is exempt from the ledger (the hook skips writes under the state dir), so
attesting never creates new unattested actions. Use **Write** (whole-file overwrite), not Bash.

### Worked example

Ledger after a turn (seq = the ordinal on the right, not stored):
```
{"kind":"action","tool":"Edit","target":"src/auth/login.ts"}     → seq 1
{"kind":"action","tool":"Bash","target":"npm run build"}         → seq 2
{"kind":"action","tool":"Edit","target":"src/theme/colors.css"}  → seq 3
```
X = "add rate-limiting to login", criteria = ["throttle repeated attempts", "return 429 on limit"].
Attest:
```
{"through_seq":3,"attestations":[
  {"seq":1,"verdict":"serves","criterion":"throttle repeated attempts"},
  {"seq":2,"verdict":"serves","criterion":"build the throttling change"},
  {"seq":3,"verdict":"drift","criterion":"unrelated colour tweak","accepted":false}]}
```
seq 3 is drift: revert it (or get user acceptance), then finish. The gate blocks until it clears.

### Drift signals — call it drift when the action

- touches a file or concern no criterion mentions ("while I'm here");
- swaps the asked approach for a cheaper one you did not clear with the user;
- weakens a check to make something pass — that is gaming, not progress;
- would surprise the user reading the diff against X.

## 3 — Clear the Stop gate honestly

At turn end the gate blocks while any action ordinal lacks a real attestation entry, or any
`verdict:"drift"` has `accepted:false`. Its message lists the missing seqs and intent X.

- Clear it by **actually attesting** each listed seq — reason per action, then write `attest.json`.
- Resolve drift by reverting the stray change, or by getting the user to accept it (then set
  `accepted:true` for that entry).
- The gate auto-releases the *second* time it fires in a turn (`stop_hook_active` loop-guard). That
  release is a safety valve against wedging, **not** permission to skip — it means the reckoning
  already happened once. Do not exploit it by stalling.

## 4 — Cooperative integrity (the point)

- Never write a `serves` you do not believe; never invent a `criterion` to fit a stray.
- Never mark `accepted:true` on drift the user did not accept.
- Do not rewrite `intent.json` to make a stray retroactively "serve" X — that is the exact cheat
  this guards against. Redirecting X is the **user's** call via `/intent-guard:intent`; if you
  believe X should change, say so and let them decide.
- The gate enforces that a reasoned record *exists*, not that it is *true*. Its truth is on you.

## 5 — Compose, don't duplicate

intent-guard owns only the **mid-run, per-action intent layer**. Defer the neighbours:

- **Entry** correspondence of cards↔spec → `taskmaster:coverage-check`.
- **Exit** evidence↔claim before "done" → `code-architecture:work-verification`.
- **File-membership** (was this file in scope) → `task-runner` scope.sh. intent-guard judges
  *intent*, not which file — a stray can stay in-scope and still be drift.

Keep attestations terse: one line of reasoning per action is enough. The goal is a truthful trail
from each action back to X, caught while you can still fix it — not ceremony.
