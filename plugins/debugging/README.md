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
| `UserPromptSubmit` | `hooks/remind.sh` | one advisory line naming `/debugging:debug` when the prompt head reads like a stuck loop — *still failing / broken / crashing*, *same error*, *didn't work*, *keeps failing*, *failing again*, *nothing works*, *third time* — and is a report, not a question ("why does it keep failing?" stays silent). It holds `arcRank` 10 — the best rank in the marketplace, because a loop that has already failed twice is the one moment where any other nudge is noise. Rank arbitrates only among hooks eligible on the same prompt and in the same arc phase: the best rank always speaks, but a worse-ranked sibling whose hook ran first also prints, so the bound is one line per eligible hook, never a guarantee of exactly one (`hooks/remind.sh`, "MONOTONIC PRECEDENCE"). (Until 2026-09-14 it held 20 and lost these phrases to approaches' consult nudge, contradicting the lane edge that has consult yield to this plugin.) `CC_REMIND=off` silences every reminder hook in the marketplace. Advisory only: it adds one line of context and blocks nothing. |

## Agents

- **debugger** (worker) — the reproduce-and-bisect investigation, handed off by
  `/debugging:debug` unless the triage settles in one read. A bisection burns
  context proportional to how confused the run is, which is exactly the context the
  main thread needs to apply the fix afterwards. It returns the root cause with its
  evidence and the minimal fix; it does not decide whether to ship it.

## Pairs well with

- **task-runner** — its three-cycle park rule and this plugin's three-failed-fixes escalation are the same discipline
- **testing** — the reproduction script graduates into the regression suite
