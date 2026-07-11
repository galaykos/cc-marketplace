# intent-guard

Continuous **mid-run intent-vs-action attestation** — a cooperative drift-guard that proves each
action still serves the declared task, and holds turn completion until it does.

## Install

```
/plugin marketplace add galaykos/cc-marketplace
/plugin install intent-guard@cc-plugins-marketplace
```

## Commands

| Command | Does |
|---------|------|
| `/intent-guard:intent <task>` | Set or override the declared intent **X** (with criteria) for this session. |
| `/intent-guard:status` | Show intent, the action ledger, attested vs unattested actions, and open drift. |

## How it works

The gap it fills: existing guards watch only the **boundaries** — `taskmaster:coverage-check` at
entry, `code-architecture:work-verification` at exit, `task-runner` scope.sh on file-membership.
Nothing watches per-action intent in the **middle**, where a model quietly swaps the asked task X
for a cheaper strayed Y. `intent-guard` is that middle tier.

Three hooks + one skill:

- **`capture.sh` (UserPromptSubmit)** records the declared intent for the session and rotates state
  on a new session.
- **`log.sh` (PostToolUse)** appends every state-mutating `Edit/Write/MultiEdit/NotebookEdit/Bash/
  Agent` action to an append-only ledger under `.claude/intent-guard/`. An action's seq is its
  ordinal; subagent actions are captured under the parent session.
- **`gate.sh` (Stop)** holds turn completion while any action is unattested or any drift is
  unresolved, and releases once the reckoning has fired (via `stop_hook_active`).
- **the `intent-attestation` skill** is your side of the contract: at turn end (when the Stop gate
  fires) batch-attest each pending action against X — name the criterion it serves, or flag drift —
  by writing `attest.json`.

## Honest limits

`intent-guard` is a **cooperative** drift-guard, **not tamper-proof and not a security boundary**.
The agent it watches has shell access and owns the state files, so a determined adversary can
defeat it — as it can defeat every in-band guard in this marketplace. What it does well is the case
that actually bites: a cooperating model that *strays* because Y was cheaper. It makes that drift
**recorded, attested per action, and confronted before "done"** — raising the visibility and cost
of casual drift. The gate enforces that a reasoned record *exists*, not that it is *true*.

## Pairs well with

- **task-runner** — scope-lock + file-membership tripwire (intent-guard judges *intent*, not files).
- **taskmaster** — coverage-check binds cards to the spec at entry.
- **code-architecture** — work-verification demands evidence at exit.
