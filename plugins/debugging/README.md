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
suite is green; the reproduction graduates into a regression test, and one
that can only sit at a seam shallower than the bug's real call pattern ships with
that missing seam reported as a structural finding. Three
failed fix cycles stop the run and question the diagnosis instead of
attempting a fourth.

Credit: the caller rule in `systematic-debugging`'s fix section adapts a rule from [dietrichgebert/ponytail](https://github.com/dietrichgebert/ponytail) v4.10.0 (MIT), rewritten here rather than copied.

Credit: the symptom-asserting repro and its failure-rate step, the shrink step, rival explanations before the one hypothesis and the regression-test seam adapt rules from [mattpocock/skills](https://github.com/mattpocock/skills) v1.2.3 (MIT, © 2026 Matt Pocock); the probe tags and the credential redaction came from an earlier (2026-09-02) read of mattpocock/skills. Rewritten here rather than copied; effect unmeasured.

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

## Mods (Claude Code ≥ 2.1.291)

Since 0.8.0 the plugin also ships a hooks module, `hooks/suggest.ts`, listed under
`modules` in `hooks/hooks.json` beside the classic reminder, which fires with or without it.

- **What.** At the end of a turn in which the main loop (not a subagent) ran the same `Bash`
  command a second time and it failed again, with no passing run of that command between,
  the prompt box offers ``/debugging:debug `<command>` failed twice`` as a next-step
  suggestion: Tab accepts it, and nothing runs until you send it. Whitespace does not make
  a command another one; a command over 80 characters is cut with `…`. A refused or
  interrupted command does not count.
- **How it differs from the reminder above.** The reminder reads your prompt for a phrase
  ("still failing"); this reads what the commands did, and speaks to you, not the model.
- **When it stays silent.** While a phase sentinel is live (a taskmaster or task-runner run
  owns the turn). Once the prompt box has shown it for a command, not again for that
  command in this session; one the host did not show is offered again at the next turn end.
- **Off switch.** `CC_SUGGEST=off`, environment only, silences this and every other
  next-step suggestion of this marketplace together.
- **CLI.** With mods off in the host, on a CLI below 2.1.287 (which loads no module), on
  2.1.288-2.1.290, or with `CC_SUGGEST=off`, the module offers nothing and the classic hooks
  work as before. On CLI 2.1.287 with mods on, the module still registers its `tool.call`
  hook (the version check runs inside it), and that CLI's own bug — a plugin's `tool.call`
  hook breaking Bash and file search in worktree subagents, fixed in 2.1.288 — applies even
  with `CC_SUGGEST=off`: upgrade the CLI or turn mods off.
- **Limits.** The prompt box holds one suggestion: when another plugin offers one at the
  same turn end the later replaces the earlier, and Claude Code's own suggestion is not
  suppressed. What was shown is kept in memory, so a new session offers it again. A failed
  command is one the CLI answers as an error; how a non-zero exit reaches a hook was not
  observed live (**recorded**, from the mods API's result shape).
- **Standing.** The conditions above are a **gate**: `tests/suggest.test.ts` runs under
  `claude plugin test` in CI. Whether the suggestion shortens a debugging loop is unmeasured.

## Pairs well with

- **task-runner** — its three-cycle park rule and this plugin's three-failed-fixes escalation are the same discipline
- **testing** — the reproduction script graduates into the regression suite
