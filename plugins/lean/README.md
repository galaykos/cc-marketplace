# lean

Every line of code, every test, every comment, every file and every action is a
debit — paid once at write time, then again at every read, review and CI run. This
plugin prices all five and asks the question the surface-specific plugins do not:
**how much**.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install lean@cc-plugins-marketplace
```

## What it carries

| Part | Standing |
|---|---|
| `cost-model` skill — five surfaces, one bar each; the four triggers that buy more; the escalation record; the safety clause | **agent-graded** and **recorded** — a reviewer applies it, nothing reads it back |
| `hooks/budget.sh` — one `PostToolUse` line on the first `Edit`/`Write`/`MultiEdit` of a context | **advisory** — `additionalContext` is not a blocking key |

The hook is keyed on `transcript_path`, falling back to `session_id`, so every
**subagent** gets exactly one copy. A subagent shares its parent's session id but has
its own transcript, and `PostToolUse` is the only hook channel that reaches subagents
at all — which matters because the fan-out is where the writing happens. The message
is 263 bytes against a 300-byte ceiling: `scripts/context-budget.sh` meters it, and
the emitted JSON spends 85 of the ~87 tokens of dynamic headroom that existed when
this shipped.

## What it does NOT do

- **No blocking volume gate, deliberately.** A line-count or test-count threshold
  would be exactly the ratio-chasing the skill rejects: it fires on legitimately
  dense work and waves through a bloated diff that sits under the number. There is
  no correct ratio, so there is nothing honest to gate on.
- **It measures nothing.** The hook states a bar; it does not compute one.
- **It cannot see the aggregate across a fan-out.** Each subagent is reminded in its
  own context; nothing sums the run.
- **It arrives after the first write of a context.** That first file is written
  without it — the cost of using the only channel subagents receive.
- **No `CHANGELOG.md`**, on purpose: a first release has no history to record, and
  adding the file would opt this plugin into the repo's hard changelog-coverage gate
  for no reader benefit.

## Off switches

| Variable | Effect |
|---|---|
| `CC_REMIND=off` | silences every advisory nudge in this marketplace |
| `CC_LEAN=off` | silences only this plugin's hook |

Fail-open on every path: no `jq`, an unwritable state dir, or any error exits 0
silently. It can never wedge a run.

## Pairs well with

- **code-review** (comment-discipline skill) — whether a comment should exist and where the fact belongs
- **testing** — what is worth testing and at which layer; its
  `references/proportionality.md` carries the measured 3x test:code and 8x
  tests-per-integration overshoot this plugin exists to prevent
- **code-architecture** — speculative generality (`yagni-check`) and where a fact
  belongs so a reader finds it (`low-cognitive-load`)
