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

## Hooks

| Event | Script | What it does |
|-------|--------|--------------|
| `UserPromptSubmit` | `hooks/remind.sh` | one advisory line naming `/debugging:debug` when the prompt head reads like a stuck loop — *still failing / broken / crashing*, *same error*, *didn't work*, *keeps failing*, *failing again*, *nothing works*, *third time* — and is a report, not a question ("why does it keep failing?" stays silent). Fires once per prompt, yields to a better-ranked reminder on the same prompt (approaches' irreversible-command guard), and `CC_REMIND=off` silences every reminder hook in the marketplace. Advisory only: it adds one line of context and blocks nothing. |

## Pairs well with

- **task-runner** — its three-cycle park rule and this plugin's three-failed-fixes escalation are the same discipline
- **testing** — the reproduction script graduates into the regression suite
