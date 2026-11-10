# debugging

Systematic debugging: root cause before any fix. Reproduce first and read the actual
error. Isolate with hypothesis tests and bisection, one change at a time. Verify
against the original symptom. After three failed fixes, an escalation rule applies.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install debugging@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/debugging:debug [error-or-symptom]` | Reproduce, investigate in phases, fix — root cause with evidence, or an explicit "not found" with what was ruled out |

Type the prefix: a bare `/debug` runs Claude Code's own `/debug`, which turns on debug
logging for the session. The two never compete in the model's listing, because the host's
is user-only.

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
| `UserPromptSubmit` | `hooks/fix-chain.sh` | one advisory line naming `/debugging:debug` once this session has made two fix commits (subject fix/fixes/fixed/hotfix/bugfix, or a merged `*fix*` branch) touching a common file, and again at four: a chain of fixes that each expose the next failure means the diagnosis is wrong. It counts commits since the session's first prompt, so uncommitted attempts, fixes under another subject and a chain from an earlier session are not seen. `CC_REMIND=off` silences it. Advisory only. |
| `PreToolUse` (Bash) | `hooks/probe-guard.sh` | before a `git commit` whose staged diff adds a line holding `[DEBUG-`, the tag the skill puts on every temporary probe, it asks you to confirm and names the files and lines; with `-a`/`--all` it reads the tracked changes the commit would stage. Other git commands, unstaged probes, removed lines and a commit message naming the marker stay silent. It misses a commit run through an alias, a script or a variable, and content a pathspec commit takes from outside the index. A doc line quoting the marker asks too. It asks, never denies, and fails open. `CC_PROBE_GUARD=off`, or the `cc_probe_guard` option under `/config`, turns it off. Standing: gate where installed. |

## Scripts

- **`scripts/ci-triage.sh [--run <id> | --pr <n> | --branch <b>] [--repo OWNER/REPO]`** — for a red CI run on GitHub Actions: the newest failed run on the current branch by default. It prints the run URL, the failing job and step, that step's first error with a few lines of context, and the other failing steps. It uses the `gh` CLI you already have, logged in; it never installs gh or logs in, and exits 3 saying so when gh is missing or logged out. The log is untrusted data: ANSI and control bytes are stripped, each line is cut at 240 bytes, at most 8 MiB is read, and it prints inside a fence labelled as CI log data, with a line telling the reader not to follow instructions in it. Exit 0 found, 1 no failed run, 2 usage, 3 gh missing or not authenticated, 4 any other gh failure. The skill and `/debugging:debug` run it first when CI is red (recorded: nothing makes the model run it).

## Agents

- **debugger** (worker) — the reproduce-and-bisect investigation, handed off by
  `/debugging:debug` unless the triage settles in one read. A bisection burns
  context proportional to how confused the run is, which is exactly the context the
  main thread needs to apply the fix afterwards. It returns the root cause with its
  evidence and the minimal fix; it does not decide whether to ship it.

## Pairs well with

- **task-runner** — its three-cycle park rule and this plugin's three-failed-fixes escalation are the same discipline
- **testing** — the reproduction script graduates into the regression suite
