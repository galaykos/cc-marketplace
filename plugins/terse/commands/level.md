---
description: Set or report the terse output level — lite, full, ultra, wenyan-*, off — a chat-message shape contract that never touches code, files, or how much work the turn does.
argument-hint: "[lite | full | ultra | wenyan-lite | wenyan-full | wenyan-ultra | off | status]"
---

# /terse:level

The level is written by this plugin's `hooks/mode.sh` when it sees this command,
so the switch normally happened before you read this. It can also have failed
silently — an unwritable config dir, or a state file someone replaced with a
symlink, both make the hook exit without writing. **Read the state before you
confirm anything**; announcing a level that was never written is worse than the
switch not happening:

```bash
cat "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/terse-mode" 2>/dev/null || echo none
```

Parse the first token of `$ARGUMENTS`:

## `lite` / `full` / `ultra` (and the `wenyan-*` variants)

The hook wrote the level and re-injected the contract. Confirm in **one line**:
name the level and its two budget numbers (answer / work-done report, in prose
lines of ~100 rendered characters each).

| Level | Answer | Report | Word handling |
| --- | --- | --- | --- |
| lite | 10 | 18 | full sentences, filler dropped |
| full | 6 | 12 | articles and filler dropped, fragments fine |
| ultra | 3 | 6 | plus abbreviated prose nouns and causal arrows |

The three `wenyan-lite` / `wenyan-full` / `wenyan-ultra` levels are the SAME rows
of that table — identical prose-line budgets — with the word layer swapped for a
classical-Chinese register (`terse-output`'s `references/wenyan.md`). `hooks/mode.sh`
has always accepted them; this doc did not branch on them until 2026-08-25, so a
`wenyan-full` argument fell through every case here while the hook wrote the level.
Confirm one of them the same way, naming the register alongside the budgets.

Then apply it from your very next message. Load the `terse-output` skill if the
contract is not already in context.

## `off`

The hook removed the level file. Confirm in one line that normal length resumes.

## `status` or no argument

Report the active level and where it came from, without changing anything:

```bash
printf 'env CC_TERSE=%s\nfile %s: %s\n' "${CC_TERSE:-unset}" \
  "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/terse-mode" \
  "$(cat "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/terse-mode" 2>/dev/null || echo none)"
```

`CC_TERSE` wins over the file when both are set. The level is machine-local and
persists across sessions until changed.

Then print the reference card (display only, change nothing):

| Command | What it does |
|---|---|
| `/terse:level [name\|status]` | Set or report the level; persists across sessions |
| `/terse:check [--last N] [--tokens]` | Measure turn-final messages against the budget |
| `/terse:commit` | Conventional Commits message from the staged diff |
| `/terse:compress <file>` | Compress one prose markdown file, with backup |

Reports use one skeleton: verdict → artifacts → ≤5 findings → skipped (`none` when
nothing was) → blocker → next. Tables, code blocks and trees are free. `wenyan`
alone is an alias for `wenyan-full`. Crew: `terse-investigator` returns `path:line`
rows · `terse-builder` edits at most 2 decided files, returns a receipt ·
`terse-reviewer` returns `path:line: severity: problem. fix.` — routing in the
`terse-crew` skill.

## Never

Do not confuse this with doing less work. Every level compresses the message only:
same tool calls, same verification, same file contents, same commit messages, same
subagent prompts. If a finding does not fit the budget, write it to a file and cite
the path — dropping it is the one failure this plugin counts as worse than verbosity.
