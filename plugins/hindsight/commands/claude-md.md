---
description: Audit every CLAUDE.md — stale paths/scripts by script, six-criterion score, diffs applied on approval.
argument-hint: "[path]"
---

# /hindsight:claude-md

`harvest` writes rules INTO CLAUDE.md from what sessions kept tripping over. This
command reads what is already there and asks whether it still earns its place in
every prompt. Two halves, and they have different standing.

## 1. Mechanical half (gate-shaped)

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/claude-md-check.sh ${ARGUMENTS:-.}
```

Include its output verbatim: per file, line and byte counts, then every backticked
path or `npm run` / `composer` / `make` script that no longer resolves, with the line
it sits on. These are defects, not judgments — a command a reader cannot run is worse
than no command. The script says what it does not read (prose paths, architecture
claims); repeat that line rather than implying the file is clean.

## 2. Judgment half (agent-graded)

For each file the script listed, read it in full and score six criteria — this is
the rubric the official `claude-md-management` plugin uses, kept as weights so a
reader can see what a score is made of:

| Criterion | Weight | The question |
|---|---|---|
| Commands / workflows | 20 | Can a fresh session build, test, lint and run from this file alone? |
| Architecture | 20 | Does it say where things live and which boundaries matter, not just list directories? |
| Non-obvious patterns | 15 | Are the gotchas here — the ordering dependency, the flag that must be set, the thing that bit someone? |
| Conciseness | 15 | Is every line something the code cannot say? Restated code, generic advice and one-off fixes cost tokens every turn. |
| Currency | 15 | Do the script's stale rows and the file's own claims match the tree today? |
| Actionability | 15 | Are instructions copy-pasteable with real paths, or "make sure to configure X"? |

Print one row per file: score out of 100, then the three lowest criteria with one
line each saying what is missing or what is padding. A one-line CLAUDE.md that says
"run `make test`" and is right scores higher on conciseness than a 300-line one that
restates the README; say so when it applies.

## 3. Proposals

For each file, propose at most five changes as unified diffs, each with a one-line
**why** — a stale row fixed, a missing command added from evidence in the tree
(`package.json` scripts, a `Makefile`, CI config), a paragraph cut because the code
carries it. Never add generic advice, and never invent a command you did not find
declared. Route personal preferences to `.claude.local.md` or the user's memory
directory, not the shared file.

Then ask once (AskUserQuestion, multiSelect, one option per diff, plus "apply none")
and apply only the picks with Edit. Headless: report and proposals only, nothing
written.

## Standing

The stale-reference rows are **gate-shaped** — a script produces them and its fixture
tests (`scripts/__tests__/claude-md-check.test.sh`) prove each row type fires and
each clean case stays silent. The scores are **agent-graded**: no script checks that
a criterion was read against the file rather than guessed. Nothing is written
without a pick.
