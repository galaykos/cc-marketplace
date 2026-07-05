# debugging

Systematic debugging: root cause before any fix — reproduce first, read the
actual error, isolate with hypothesis tests and bisection, one change at a
time, verify against the original symptom; escalation rule after three failed
fixes.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install debugging@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/debugging:debug [error-or-symptom]` | Reproduce, investigate in phases, fix — root cause with evidence, or an explicit "not found" with what was ruled out |

## Example

```bash
/debugging:debug TypeError: Cannot read properties of undefined (reading 'map') in OrderList.tsx
/debugging:debug           # debugs the most recent failure in the conversation
```

The fix only ships after the original reproduction passes again AND the full
suite is green; the reproduction graduates into a regression test. Three
failed fix cycles stop the run and question the diagnosis instead of
attempting a fourth.

## Pairs well with

- **task-runner** — its three-cycle park rule and this plugin's three-failed-fixes escalation are the same discipline
- **testing** — the reproduction script graduates into the regression suite
